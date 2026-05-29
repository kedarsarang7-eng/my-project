// ============================================================================
// Scan Bill Handler — OCR-based Purchase Entry
// ============================================================================
// Endpoints:
//   POST /purchase/scan-bill/extract  — Upload image, run Textract, parse lines
//   POST /purchase/scan-bill/match    — Match parsed lines to products
//   POST /purchase/entries            — Create confirmed purchase entry
//   GET  /purchase/entries            — List purchase entries
//   GET  /purchase/entries/{rid}    — Get single entry
//
// Uses AWS Textract for OCR, S3 for image storage, DynamoDB for persistence.
// All endpoints use RID (Request ID) pattern for tracing.
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { z } from 'zod';
import { 
    TextractClient, 
    AnalyzeDocumentCommand,
    FeatureType,
    Block,
} from '@aws-sdk/client-textract';
import { 
    S3Client, 
    PutObjectCommand,
    GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody } from '../middleware/validation';
import { 
    Keys, 
    putItem, 
    getItem, 
    queryItems,
    transactWrite,
} from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { UserRole } from '../types/tenant.types';
import { withRequestContext, generateRID } from '../utils/context';
import { InventoryItem } from '../types/inventory.types';
import { 
    parseBillLinesForVertical,
    ParsedLineItem,
    RawLine,
} from '../services/bill-parser.service';
import { 
    matchProducts,
    MatchResult,
    searchProductsByName,
} from '../services/product-matcher.service';
import { InventoryService } from '../services/inventory.service';
import { recordRevision } from '../services/revision-history.service';
import { config } from '../config/environment';
import { FeatureKey } from '../config/plan-feature-registry';

// ============================================================================
// Constants
// ============================================================================

const TEXTRACT_MAX_RETRIES = 3;
const TEXTRACT_RETRY_DELAY_MS = 1000;
const MAX_IMAGE_SIZE_MB = 5;
const SUPPORTED_FORMATS = ['jpeg', 'jpg', 'png', 'pdf'];
const PRESIGNED_URL_EXPIRY_SECONDS = 900; // 15 minutes

// ============================================================================
// Validation Schemas
// ============================================================================

const extractSchema = z.object({
    imageBase64: z.string().optional(),
    imageBase64List: z.array(z.string()).optional(),
    s3Key: z.string().optional(),
    verticalType: z.string().default('grocery'),
    filename: z.string().optional(),
    isMultiPage: z.boolean().default(false),
}).refine(data => data.imageBase64 || data.imageBase64List || data.s3Key, {
    message: 'Either imageBase64, imageBase64List, or s3Key must be provided',
});

const matchSchema = z.object({
    rid: z.string(),
    parsedLines: z.array(z.object({
        rawText: z.string(),
        productName: z.string(),
        quantity: z.number().nullable(),
        unit: z.string().nullable(),
        unitPrice: z.number().nullable(),
        totalPrice: z.number().nullable(),
        hsnCode: z.string().nullable(),
        batchNo: z.string().nullable(),
        expiryDate: z.string().nullable(),
        confidence: z.enum(['high', 'medium', 'low']),
        parseWarnings: z.array(z.string()),
    })),
    verticalType: z.string().default('grocery'),
    supplierName: z.string().optional(),
});

const confirmedLineItemSchema = z.object({
    productId: z.string().optional(),
    productName: z.string(),
    quantity: z.number().positive(),
    unit: z.string(),
    unitPrice: z.number().nonnegative(),
    totalPrice: z.number().nonnegative(),
    hsnCode: z.string().optional(),
    batchNo: z.string().optional(),
    expiryDate: z.string().optional(),
    isNewProduct: z.boolean().default(false),
    newProductData: z.object({
        category: z.string().optional(),
        gstRate: z.number().optional(),
        hsnCode: z.string().optional(),
    }).optional(),
});

const createEntrySchema = z.object({
    rid: z.string(),
    supplierId: z.string().optional(),
    supplierName: z.string().optional(),
    billNumber: z.string().optional(),
    billDate: z.string(),
    billImageS3Key: z.string(),
    lineItems: z.array(confirmedLineItemSchema).min(1),
    totalAmount: z.number().positive(),
    gstAmount: z.number().optional(),
    paymentStatus: z.enum(['unpaid', 'paid', 'partial']).default('unpaid'),
    verticalType: z.string(),
    idempotencyKey: z.string().optional(),
});

const listEntriesSchema = z.object({
    from: z.string().optional(),
    to: z.string().optional(),
    supplierId: z.string().optional(),
    limit: z.coerce.number().min(1).max(100).default(50),
    cursor: z.string().optional(),
});

// ============================================================================
// Clients
// ============================================================================

const textractClient = new TextractClient({ 
    region: config.aws.region 
});
const s3Client = new S3Client({ 
    region: config.aws.region 
});

// Get S3 bucket name from environment
const S3_BUCKET_NAME = process.env.S3_BUCKET_NAME || '';
const inventoryService = new InventoryService();

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Detect MIME type from base64 data or filename
 */
function detectMimeType(base64Data?: string, filename?: string): string | null {
    // Check base64 prefix
    if (base64Data) {
        if (base64Data.startsWith('/9j/')) return 'image/jpeg';
        if (base64Data.startsWith('iVBOR')) return 'image/png';
        if (base64Data.startsWith('JVBER')) return 'application/pdf';
    }
    
    // Check filename extension
    if (filename) {
        const ext = filename.split('.').pop()?.toLowerCase();
        switch (ext) {
            case 'jpg':
            case 'jpeg': return 'image/jpeg';
            case 'png': return 'image/png';
            case 'pdf': return 'application/pdf';
        }
    }
    
    return null;
}

/**
 * Validate image size (base64 is ~33% larger than binary)
 */
function validateImageSize(base64Data: string): { valid: boolean; error?: string } {
    // Base64 encoded size
    const base64SizeBytes = Buffer.byteLength(base64Data, 'base64');
    const estimatedBinarySize = base64SizeBytes * 0.75;
    const maxSizeBytes = MAX_IMAGE_SIZE_MB * 1024 * 1024;
    
    if (estimatedBinarySize > maxSizeBytes) {
        return {
            valid: false,
            error: `Image too large: ${(estimatedBinarySize / 1024 / 1024).toFixed(2)}MB (max ${MAX_IMAGE_SIZE_MB}MB)`,
        };
    }
    
    return { valid: true };
}

/**
 * Upload image to S3
 */
async function uploadToS3(
    tenantId: string,
    rid: string,
    imageBuffer: Buffer,
    mimeType: string
): Promise<string> {
    const extension = mimeType.split('/')[1] || 'jpg';
    const key = `tenants/${tenantId}/purchase-bills/${rid}.${extension}`;
    
    await s3Client.send(new PutObjectCommand({
        Bucket: S3_BUCKET_NAME,
        Key: key,
        Body: imageBuffer,
        ContentType: mimeType,
        Metadata: {
            'tenant-id': tenantId,
            'rid': rid,
            'uploaded-at': new Date().toISOString(),
        },
    }));
    
    logger.info('Bill image uploaded to S3', { tenantId, rid, key, size: imageBuffer.length });
    return key;
}

/**
 * Generate pre-signed URL for S3 image
 */
async function getPresignedImageUrl(s3Key: string): Promise<string> {
    const command = new GetObjectCommand({
        Bucket: S3_BUCKET_NAME,
        Key: s3Key,
    });
    
    return getSignedUrl(s3Client, command, { expiresIn: PRESIGNED_URL_EXPIRY_SECONDS });
}

/**
 * Call AWS Textract with retry logic
 */
async function callTextractWithRetry(
    imageBuffer: Buffer,
    mimeType: string,
    retryCount = 0
): Promise<Block[]> {
    try {
        const command = new AnalyzeDocumentCommand({
            Document: {
                Bytes: imageBuffer,
            },
            FeatureTypes: [FeatureType.TABLES, FeatureType.FORMS],
        });
        
        const result = await textractClient.send(command);
        return result.Blocks || [];
    } catch (error: any) {
        // Check if it's a throttling error
        if (error.name === 'ThrottlingException' || error.name === 'TooManyRequestsException') {
            if (retryCount < TEXTRACT_MAX_RETRIES) {
                logger.warn('Textract throttled, retrying', { retryCount, maxRetries: TEXTRACT_MAX_RETRIES });
                await new Promise(resolve => setTimeout(resolve, TEXTRACT_RETRY_DELAY_MS * (retryCount + 1)));
                return callTextractWithRetry(imageBuffer, mimeType, retryCount + 1);
            }
        }
        throw error;
    }
}

/**
 * Process Textract blocks into raw lines
 */
function processTextractBlocks(blocks: Block[]): RawLine[] {
    const lines: RawLine[] = [];
    
    // Filter LINE and CELL blocks
    const lineBlocks = blocks.filter(b => 
        b.BlockType === 'LINE' || b.BlockType === 'CELL'
    );
    
    // Sort by vertical position (top to bottom)
    lineBlocks.sort((a, b) => {
        const aY = a.Geometry?.BoundingBox?.Top || 0;
        const bY = b.Geometry?.BoundingBox?.Top || 0;
        return aY - bY;
    });
    
    for (let i = 0; i < lineBlocks.length; i++) {
        const block = lineBlocks[i];
        if (block.Text) {
            lines.push({
                text: block.Text.trim(),
                lineIndex: i,
                confidence: block.Confidence || 0,
            });
        }
    }
    
    return lines;
}

/**
 * Calculate average confidence from parsed lines
 */
function calculateAverageConfidence(lines: RawLine[]): number {
    if (lines.length === 0) return 0;
    const sum = lines.reduce((acc, line) => acc + line.confidence, 0);
    return sum / lines.length;
}

// ============================================================================
// API Handlers
// ============================================================================

/**
 * POST /purchase/scan-bill/extract
 * Upload image, run Textract, parse bill lines
 */
export const extractBill = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const body = JSON.parse(event.body || '{}');
                const parsed = extractSchema.safeParse(body);
                
                if (!parsed.success) {
                    return response.error(400, 'VALIDATION_ERROR', 'Invalid request body', parsed.error.format());
                }
                
                const { imageBase64, imageBase64List, s3Key: existingS3Key, verticalType, filename } = parsed.data;
                
                let s3Key: string;
                let allRawLines: any[] = [];
                const s3Keys: string[] = [];
                
                // Handle multi-image case
                if (imageBase64List && imageBase64List.length > 0) {
                    logger.info('Processing multi-image bill', { 
                        rid, 
                        tenantId: auth.tenantId, 
                        imageCount: imageBase64List.length 
                    });
                    
                    // Process each image
                    for (let i = 0; i < imageBase64List.length; i++) {
                        const base64Image = imageBase64List[i];
                        
                        // Validate size
                        const sizeCheck = validateImageSize(base64Image);
                        if (!sizeCheck.valid) {
                            return response.error(400, 'IMAGE_TOO_LARGE', 
                                `Image ${i + 1}: ${sizeCheck.error}`);
                        }
                        
                        // Detect MIME type
                        const mimeType = detectMimeType(base64Image, filename);
                        if (!mimeType) {
                            return response.error(400, 'UNSUPPORTED_FORMAT', 
                                `Image ${i + 1}: Could not detect image format`);
                        }
                        
                        if (!SUPPORTED_FORMATS.includes(mimeType.split('/')[1])) {
                            return response.error(400, 'UNSUPPORTED_FORMAT', 
                                `Image ${i + 1}: Format not supported`);
                        }
                        
                        // Decode and upload
                        const imageBuffer = Buffer.from(base64Image, 'base64');
                        const pageS3Key = await uploadToS3(auth.tenantId, `${rid}_page_${i + 1}`, imageBuffer, mimeType);
                        s3Keys.push(pageS3Key);
                        
                        // Call Textract
                        logger.info('Calling Textract for page', { rid, page: i + 1, tenantId: auth.tenantId });
                        const blocks = await callTextractWithRetry(imageBuffer, 'application/octet-stream');
                        
                        // Process and append lines
                        const pageRawLines = processTextractBlocks(blocks);
                        allRawLines = allRawLines.concat(pageRawLines.map(line => ({
                            ...line,
                            pageNumber: i + 1,
                        })));
                    }
                    
                    // Use first S3 key as primary
                    s3Key = s3Keys[0];
                    
                } else if (imageBase64) {
                    // Single image case
                    const sizeCheck = validateImageSize(imageBase64);
                    if (!sizeCheck.valid) {
                        return response.error(400, 'IMAGE_TOO_LARGE', sizeCheck.error!);
                    }
                    
                    const mimeType = detectMimeType(imageBase64, filename);
                    if (!mimeType) {
                        return response.error(400, 'UNSUPPORTED_FORMAT', 'Could not detect image format');
                    }
                    
                    if (!SUPPORTED_FORMATS.includes(mimeType.split('/')[1])) {
                        return response.error(400, 'UNSUPPORTED_FORMAT', `Format ${mimeType} not supported`);
                    }
                    
                    const imageBuffer = Buffer.from(imageBase64, 'base64');
                    s3Key = await uploadToS3(auth.tenantId, rid, imageBuffer, mimeType);
                    s3Keys.push(s3Key);
                    
                    const blocks = await callTextractWithRetry(imageBuffer, 'application/octet-stream');
                    allRawLines = processTextractBlocks(blocks);
                    
                } else if (existingS3Key) {
                    // Existing S3 key
                    s3Key = existingS3Key;
                    s3Keys.push(s3Key);
                    
                    const getCommand = new GetObjectCommand({
                        Bucket: S3_BUCKET_NAME,
                        Key: s3Key,
                    });
                    const s3Result = await s3Client.send(getCommand);
                    const imageBuffer = await streamToBuffer(s3Result.Body as any);
                    
                    const blocks = await callTextractWithRetry(imageBuffer, 'application/octet-stream');
                    allRawLines = processTextractBlocks(blocks);
                } else {
                    return response.error(400, 'MISSING_IMAGE', 'Either imageBase64, imageBase64List, or s3Key required');
                }
                
                // Check confidence
                const avgConfidence = calculateAverageConfidence(allRawLines);
                const lowConfidenceWarning = avgConfidence < 60 ? 
                    'Low OCR confidence detected. Please review carefully.' : undefined;
                
                // Parse bill lines
                const parsedLines = parseBillLinesForVertical(allRawLines, verticalType);
                
                // Log analytics event
                logger.info('SCAN_BILL_EXTRACTED', {
                    tenantId: auth.tenantId,
                    rid,
                    lineItemCount: parsedLines.length,
                    avgConfidence,
                    verticalType,
                    isMultiPage: s3Keys.length > 1,
                });
                
                return response.success({
                    rid,
                    s3ImageKey: s3Key,
                    s3ImageKeys: s3Keys,
                    presignedUrl: await getPresignedImageUrl(s3Key),
                    rawLines: allRawLines,
                    parsedLines,
                    warning: lowConfidenceWarning,
                    extractionStats: {
                        totalLines: allRawLines.length,
                        productLines: parsedLines.length,
                        avgConfidence: Math.round(avgConfidence * 100) / 100,
                    },
                });
                
            } catch (error: any) {
                logger.error('Textract extraction failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                
                if (error.message?.includes('Image')) {
                    return response.error(400, 'EXTRACTION_FAILED', 'Could not read image. Please try a clearer photo.');
                }
                
                return response.error(500, 'EXTRACTION_ERROR', 'Failed to process image', { detail: error.message });
            }
        });
    },
    { requiredFeature: FeatureKey.STANDARD_POS } // Any paid plan
);

/**
 * POST /purchase/scan-bill/match
 * Match parsed lines to tenant's product catalog
 */
export const matchProductsHandler = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const body = JSON.parse(event.body || '{}');
                const parsed = matchSchema.safeParse(body);
                
                if (!parsed.success) {
                    return response.error(400, 'VALIDATION_ERROR', 'Invalid request body', parsed.error.format());
                }
                
                const { parsedLines, verticalType, supplierName } = parsed.data;
                
                // Convert schema format to ParsedLineItem format
                const items: ParsedLineItem[] = parsedLines.map(line => ({
                    rawText: line.rawText,
                    productName: line.productName,
                    quantity: line.quantity,
                    unit: line.unit,
                    unitPrice: line.unitPrice,
                    totalPrice: line.totalPrice,
                    hsnCode: line.hsnCode,
                    batchNo: line.batchNo,
                    expiryDate: line.expiryDate,
                    confidence: line.confidence,
                    parseWarnings: line.parseWarnings,
                }));
                
                // Match products
                const matchResults = await matchProducts(items, auth.tenantId, {
                    verticalType,
                    tenantId: auth.tenantId,
                    preferHsnMatch: verticalType.toLowerCase() === 'pharmacy',
                    supplierName,
                });
                
                // Calculate match statistics
                const stats = {
                    exact: matchResults.filter(r => r.matchConfidence === 'exact').length,
                    high: matchResults.filter(r => r.matchConfidence === 'high').length,
                    medium: matchResults.filter(r => r.matchConfidence === 'medium').length,
                    low: matchResults.filter(r => r.matchConfidence === 'low').length,
                    none: matchResults.filter(r => r.matchConfidence === 'none').length,
                    requiresReview: matchResults.filter(r => r.requiresManualReview).length,
                };
                
                // Log analytics event
                logger.info('SCAN_BILL_MATCH_COMPLETE', {
                    tenantId: auth.tenantId,
                    rid,
                    ...stats,
                });
                
                return response.success({
                    rid,
                    matchResults: matchResults.map(r => ({
                        parsedItem: r.parsedItem,
                        matchedProduct: r.matchedProduct ? mapProductToResponse(r.matchedProduct) : null,
                        matchConfidence: r.matchConfidence,
                        alternativeSuggestions: r.alternativeSuggestions.map(mapProductToResponse),
                        requiresManualReview: r.requiresManualReview,
                    })),
                    matchStats: stats,
                });
                
            } catch (error: any) {
                logger.error('Product matching failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'MATCH_ERROR', 'Failed to match products', { detail: error.message });
            }
        });
    },
    { requiredFeature: FeatureKey.STANDARD_POS }
);

/**
 * POST /purchase/entries
 * Create confirmed purchase entry with stock update
 */
export const createPurchaseEntry = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const body = JSON.parse(event.body || '{}');
                const parsed = createEntrySchema.safeParse(body);
                
                if (!parsed.success) {
                    return response.error(400, 'VALIDATION_ERROR', 'Invalid request body', parsed.error.format());
                }
                
                const {
                    supplierId,
                    supplierName,
                    billNumber,
                    billDate,
                    billImageS3Key,
                    lineItems,
                    totalAmount,
                    gstAmount,
                    paymentStatus,
                    verticalType,
                    idempotencyKey,
                } = parsed.data;
                
                // Idempotency check
                const effectiveRid = idempotencyKey || rid;
                const existingEntry = await getItem<Record<string, any>>(
                    Keys.tenantPK(auth.tenantId),
                    Keys.purchaseBillSK(effectiveRid)
                );
                
                if (existingEntry) {
                    logger.info('Duplicate purchase entry detected', { rid: effectiveRid, tenantId: auth.tenantId });
                    return response.success({
                        message: 'Purchase entry already exists',
                        entry: mapPurchaseEntryToResponse(existingEntry),
                        isDuplicate: true,
                    });
                }
                
                // Prepare transaction items
                const transactionItems: any[] = [];
                const processedLineItems: any[] = [];
                
                for (const lineItem of lineItems) {
                    let productId = lineItem.productId;
                    
                    // Create new product if needed
                    if (lineItem.isNewProduct || !productId) {
                        const newProduct = await inventoryService.createItem(auth.tenantId, {
                            name: lineItem.productName,
                            unit: lineItem.unit,
                            hsnCode: lineItem.newProductData?.hsnCode || lineItem.hsnCode,
                            cgstRateBp: lineItem.newProductData?.gstRate ? lineItem.newProductData.gstRate * 100 : 0,
                            sgstRateBp: lineItem.newProductData?.gstRate ? lineItem.newProductData.gstRate * 100 : 0,
                            salePriceCents: Math.round(lineItem.unitPrice * 100),
                            purchasePriceCents: Math.round(lineItem.unitPrice * 100),
                            currentStock: 0, // Will be updated by purchase
                        }, auth.sub);
                        
                        productId = newProduct.id;
                    }
                    
                    // Add stock update to transaction
                    const updateExpression = 'SET currentStock = currentStock + :qty, updatedAt = :now, updatedBy = :userId';
                    transactionItems.push({
                        Update: {
                            TableName: process.env.DYNAMODB_TABLE,
                            Key: {
                                PK: Keys.tenantPK(auth.tenantId),
                                SK: Keys.productSK(productId!),
                            },
                            UpdateExpression: updateExpression,
                            ExpressionAttributeValues: {
                                ':qty': lineItem.quantity,
                                ':now': new Date().toISOString(),
                                ':userId': auth.sub,
                            },
                        },
                    });
                    
                    processedLineItems.push({
                        productId,
                        productName: lineItem.productName,
                        quantity: lineItem.quantity,
                        unit: lineItem.unit,
                        unitPrice: lineItem.unitPrice,
                        totalPrice: lineItem.totalPrice,
                        hsnCode: lineItem.hsnCode,
                        batchNo: lineItem.batchNo,
                        expiryDate: lineItem.expiryDate,
                        isNewProduct: lineItem.isNewProduct,
                    });
                }
                
                // Create purchase entry
                const purchaseEntry: Record<string, any> = {
                    PK: Keys.tenantPK(auth.tenantId),
                    SK: Keys.purchaseBillSK(effectiveRid),
                    entityType: 'PURCHASE_BILL',
                    rid: effectiveRid,
                    tenantId: auth.tenantId,
                    supplierId: supplierId || null,
                    supplierName: supplierName || null,
                    billNumber: billNumber || null,
                    billDate,
                    billImageS3Key,
                    lineItems: processedLineItems,
                    totalAmount,
                    gstAmount: gstAmount || null,
                    paymentStatus,
                    verticalType,
                    entryMethod: 'scan',
                    createdBy: auth.sub,
                    createdAt: new Date().toISOString(),
                    updatedAt: new Date().toISOString(),
                    isDeleted: false,
                };
                
                // Add purchase entry to transaction
                transactionItems.unshift({
                    Put: {
                        TableName: process.env.DYNAMODB_TABLE,
                        Item: purchaseEntry,
                        ConditionExpression: 'attribute_not_exists(PK)',
                    },
                });
                
                // Execute transaction
                await transactWrite(transactionItems);
                
                // Record revision history
                await recordRevision(
                    auth.tenantId,
                    'purchase',
                    effectiveRid,
                    'create',
                    auth.sub,
                    null,
                    {
                        rid: effectiveRid,
                        supplierName,
                        billNumber,
                        totalAmount,
                        itemCount: lineItems.length,
                    },
                    { source: 'scan-bill.createPurchaseEntry' }
                );
                
                // Log analytics event
                logger.info('SCAN_BILL_CONFIRMED', {
                    tenantId: auth.tenantId,
                    rid: effectiveRid,
                    finalItemCount: lineItems.length,
                    supplierSet: !!supplierId || !!supplierName,
                    totalAmount,
                    newProducts: lineItems.filter(i => i.isNewProduct).length,
                });
                
                return response.success({
                    rid: effectiveRid,
                    entry: mapPurchaseEntryToResponse(purchaseEntry),
                    stockUpdated: true,
                    itemsProcessed: processedLineItems.length,
                }, 201);
                
            } catch (error: any) {
                logger.error('Purchase entry creation failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'CREATE_ERROR', 'Failed to create purchase entry', { detail: error.message });
            }
        });
    },
    { requiredFeature: FeatureKey.STANDARD_POS }
);

/**
 * GET /purchase/entries
 * List purchase entries with filters
 */
export const listPurchaseEntries = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const queryParams = event.queryStringParameters || {};
                const parsed = listEntriesSchema.safeParse(queryParams);
                
                if (!parsed.success) {
                    return response.error(400, 'VALIDATION_ERROR', 'Invalid query parameters', parsed.error.format());
                }
                
                const { from, to, supplierId, limit, cursor } = parsed.data;
                
                // Build filter expression
                const filterParts: string[] = ['(attribute_not_exists(isDeleted) OR isDeleted = :false)'];
                const exprValues: Record<string, any> = { ':false': false };
                const exprNames: Record<string, string> = {};
                
                if (supplierId) {
                    filterParts.push('supplierId = :supplierId');
                    exprValues[':supplierId'] = supplierId;
                }
                
                if (from && to) {
                    filterParts.push('billDate BETWEEN :from AND :to');
                    exprValues[':from'] = from;
                    exprValues[':to'] = to;
                } else if (from) {
                    filterParts.push('billDate >= :from');
                    exprValues[':from'] = from;
                } else if (to) {
                    filterParts.push('billDate <= :to');
                    exprValues[':to'] = to;
                }
                
                const result = await queryItems<Record<string, any>>(
                    Keys.tenantPK(auth.tenantId),
                    'PBILL#',
                    {
                        filterExpression: filterParts.join(' AND '),
                        expressionAttributeValues: exprValues,
                        expressionAttributeNames: Object.keys(exprNames).length > 0 ? exprNames : undefined,
                        limit,
                        exclusiveStartKey: cursor ? JSON.parse(Buffer.from(cursor, 'base64').toString()) : undefined,
                        scanIndexForward: false, // Newest first
                    }
                );
                
                // Generate next cursor if more results
                const nextCursor = result.lastKey ? 
                    Buffer.from(JSON.stringify(result.lastKey)).toString('base64') : 
                    undefined;
                
                return response.success({
                    items: result.items.map(mapPurchaseEntryToResponse),
                    total: result.items.length,
                    limit,
                    nextCursor,
                });
                
            } catch (error: any) {
                logger.error('List purchase entries failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'LIST_ERROR', 'Failed to list entries', { detail: error.message });
            }
        });
    },
    { requiredFeature: FeatureKey.STANDARD_POS }
);

/**
 * GET /purchase/entries/{rid}
 * Get single purchase entry
 */
export const getPurchaseEntry = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const entryRid = event.pathParameters?.rid;
                
                if (!entryRid) {
                    return response.error(400, 'MISSING_RID', 'Entry RID is required');
                }
                
                const entry = await getItem<Record<string, any>>(
                    Keys.tenantPK(auth.tenantId),
                    Keys.purchaseBillSK(entryRid)
                );
                
                if (!entry || entry.isDeleted) {
                    return response.error(404, 'NOT_FOUND', 'Purchase entry not found');
                }
                
                // Generate fresh presigned URL for image
                let presignedUrl: string | undefined;
                if (entry.billImageS3Key) {
                    presignedUrl = await getPresignedImageUrl(entry.billImageS3Key);
                }
                
                return response.success({
                    entry: mapPurchaseEntryToResponse(entry),
                    presignedUrl,
                });
                
            } catch (error: any) {
                logger.error('Get purchase entry failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'GET_ERROR', 'Failed to get entry', { detail: error.message });
            }
        });
    },
    { requiredFeature: FeatureKey.STANDARD_POS }
);

// ============================================================================
// Helper Functions
// ============================================================================

async function streamToBuffer(stream: any): Promise<Buffer> {
    const chunks: Buffer[] = [];
    for await (const chunk of stream) {
        chunks.push(Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
}

function mapProductToResponse(product: InventoryItem) {
    return {
        id: product.id,
        name: product.name,
        displayName: product.displayName,
        sku: product.sku,
        barcode: product.barcode,
        category: product.category,
        brand: product.brand,
        hsnCode: product.hsnCode,
        unit: product.unit,
        currentStock: product.currentStock,
        salePrice: product.salePriceCents / 100,
        purchasePrice: product.purchasePriceCents ? product.purchasePriceCents / 100 : null,
        gstRate: (product.cgstRateBp + product.sgstRateBp) / 100,
    };
}

function mapPurchaseEntryToResponse(entry: Record<string, any>) {
    return {
        rid: entry.rid,
        supplierId: entry.supplierId,
        supplierName: entry.supplierName,
        billNumber: entry.billNumber,
        billDate: entry.billDate,
        billImageS3Key: entry.billImageS3Key,
        lineItems: entry.lineItems,
        totalAmount: entry.totalAmount,
        gstAmount: entry.gstAmount,
        paymentStatus: entry.paymentStatus,
        verticalType: entry.verticalType,
        entryMethod: entry.entryMethod,
        createdBy: entry.createdBy,
        createdAt: entry.createdAt,
    };
}
