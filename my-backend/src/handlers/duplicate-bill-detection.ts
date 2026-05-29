// ============================================================================
// Duplicate Bill Detection Handler
// ============================================================================
// P1: Detects if same bill has already been processed
// Uses image hash comparison and bill number matching
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import crypto from 'crypto';
import { authorizedHandler } from '../middleware/auth';
import { UserRole } from '../types/auth.types';
import { response, withRequestContext } from '../utils/response';
import { logger } from '../utils/logger';
import { dynamoDb, TableNames, Keys } from '../config/dynamodb.config';
import { QueryCommand, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';

// Check schema
const checkSchema = z.object({
    imageBase64: z.string().optional(),
    s3Key: z.string().optional(),
    billNumber: z.string().optional(),
    supplierName: z.string().optional(),
    billDate: z.string().optional(),
    totalAmount: z.number().optional(),
});

/**
 * POST /purchase/scan-bill/check-duplicate
 * Check if bill has already been processed
 */
export const checkDuplicateBillHandler = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const body = JSON.parse(event.body || '{}');
                const parsed = checkSchema.safeParse(body);
                
                if (!parsed.success) {
                    return response.error(400, 'VALIDATION_ERROR', 'Invalid request body');
                }
                
                const { imageBase64, s3Key, billNumber, supplierName, billDate, totalAmount } = parsed.data;
                
                const checks: DuplicateCheckResult[] = [];
                
                // 1. Check by image hash if image provided
                if (imageBase64) {
                    const imageHash = calculateImageHash(imageBase64);
                    const existingByHash = await findByImageHash(auth.tenantId, imageHash);
                    
                    if (existingByHash) {
                        checks.push({
                            type: 'image_hash',
                            matched: true,
                            confidence: 0.99,
                            existingEntry: existingByHash,
                            message: 'Identical image found - bill already processed',
                        });
                    }
                }
                
                // 2. Check by bill fingerprint (number + supplier + date)
                if (billNumber && supplierName && billDate) {
                    const existingByFingerprint = await findByFingerprint(
                        auth.tenantId,
                        billNumber,
                        supplierName,
                        billDate
                    );
                    
                    if (existingByFingerprint) {
                        const amountMatch = totalAmount 
                            ? Math.abs(existingByFingerprint.totalAmount - totalAmount) < 1
                            : false;
                        
                        checks.push({
                            type: 'bill_fingerprint',
                            matched: true,
                            confidence: amountMatch ? 0.95 : 0.75,
                            existingEntry: existingByFingerprint,
                            message: amountMatch 
                                ? 'Same bill number, supplier, date AND amount - likely duplicate'
                                : 'Same bill number, supplier, and date - verify if duplicate',
                        });
                    }
                }
                
                // 3. Check by similar amount and date
                if (totalAmount && billDate) {
                    const similarEntries = await findSimilarEntries(
                        auth.tenantId,
                        totalAmount,
                        billDate,
                        0.05  // 5% tolerance
                    );
                    
                    if (similarEntries.length > 0) {
                        checks.push({
                            type: 'similar_amount_date',
                            matched: true,
                            confidence: 0.6,
                            existingEntry: similarEntries[0],
                            message: 'Similar amount and date found - may be duplicate',
                        });
                    }
                }
                
                const isDuplicate = checks.some(c => c.matched && c.confidence > 0.8);
                const warning = checks.length > 0 ? checks[0].message : undefined;
                
                logger.info('Duplicate bill check complete', {
                    rid,
                    tenantId: auth.tenantId,
                    isDuplicate,
                    checkCount: checks.length,
                });
                
                return response.success({
                    isDuplicate,
                    confidence: checks.length > 0 ? Math.max(...checks.map(c => c.confidence)) : 0,
                    checks,
                    warning,
                });
                
            } catch (error: any) {
                logger.error('Duplicate check failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'CHECK_ERROR', 'Failed to check for duplicates');
            }
        });
    },
    { requiredFeature: 'STANDARD_POS' }
);

interface DuplicateCheckResult {
    type: 'image_hash' | 'bill_fingerprint' | 'similar_amount_date';
    matched: boolean;
    confidence: number;
    existingEntry?: any;
    message: string;
}

/**
 * Calculate image hash (simplified - uses base64 prefix)
 * In production, use perceptual hashing (pHash)
 */
function calculateImageHash(base64Image: string): string {
    // Use first 100 chars of base64 as simple hash
    // In production, resize image and compute pHash
    const sample = base64Image.substring(0, 100);
    return crypto.createHash('md5').update(sample).digest('hex');
}

/**
 * Find entry by image hash
 */
async function findByImageHash(tenantId: string, imageHash: string): Promise<any | null> {
    try {
        // Query by GSI on imageHash
        const result = await dynamoDb.send(new QueryCommand({
            TableName: TableNames.PURCHASE_ENTRIES,
            IndexName: 'GSI2',
            KeyConditionExpression: 'GSI2PK = :pk AND GSI2SK = :sk',
            ExpressionAttributeValues: {
                ':pk': { S: Keys.imageHashPK(tenantId) },
                ':sk': { S: Keys.imageHashSK(imageHash) },
            },
            Limit: 1,
        }));
        
        if (result.Items && result.Items.length > 0) {
            return unmarshall(result.Items[0]);
        }
        
        return null;
    } catch (error) {
        logger.error('Failed to find by image hash', { error, tenantId, imageHash });
        return null;
    }
}

/**
 * Find entry by bill fingerprint
 */
async function findByFingerprint(
    tenantId: string,
    billNumber: string,
    supplierName: string,
    billDate: string
): Promise<any | null> {
    try {
        const fingerprint = `${billNumber}:${supplierName}:${billDate}`;
        
        const result = await dynamoDb.send(new QueryCommand({
            TableName: TableNames.PURCHASE_ENTRIES,
            IndexName: 'GSI3',
            KeyConditionExpression: 'GSI3PK = :pk AND GSI3SK = :sk',
            ExpressionAttributeValues: {
                ':pk': { S: Keys.billFingerprintPK(tenantId) },
                ':sk': { S: Keys.billFingerprintSK(fingerprint) },
            },
            Limit: 1,
        }));
        
        if (result.Items && result.Items.length > 0) {
            return unmarshall(result.Items[0]);
        }
        
        return null;
    } catch (error) {
        logger.error('Failed to find by fingerprint', { error, tenantId, billNumber });
        return null;
    }
}

/**
 * Find entries with similar amount and date
 */
async function findSimilarEntries(
    tenantId: string,
    totalAmount: number,
    billDate: string,
    tolerance: number
): Promise<any[]> {
    try {
        // Calculate range
        const minAmount = totalAmount * (1 - tolerance);
        const maxAmount = totalAmount * (1 + tolerance);
        
        // Query by date range then filter by amount
        const result = await dynamoDb.send(new QueryCommand({
            TableName: TableNames.PURCHASE_ENTRIES,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :date)',
            ExpressionAttributeValues: {
                ':pk': { S: Keys.purchaseEntryDatePK(tenantId) },
                ':date': { S: billDate.substring(0, 10) },
            },
        }));
        
        if (!result.Items) return [];
        
        const entries = result.Items.map(i => unmarshall(i));
        
        // Filter by amount within tolerance
        return entries.filter(e => {
            const amount = e.totalAmount || 0;
            return amount >= minAmount && amount <= maxAmount;
        });
    } catch (error) {
        logger.error('Failed to find similar entries', { error, tenantId });
        return [];
    }
}

/**
 * Store bill fingerprint for future duplicate detection
 * Call this when creating purchase entry
 */
export async function storeBillFingerprint(
    tenantId: string,
    rid: string,
    s3ImageKey: string,
    billNumber: string,
    supplierName: string,
    billDate: string,
    totalAmount: number
): Promise<void> {
    try {
        const imageHash = calculateImageHashFromKey(s3ImageKey);
        const fingerprint = `${billNumber}:${supplierName}:${billDate}`;
        
        await dynamoDb.send(new PutItemCommand({
            TableName: TableNames.PURCHASE_ENTRIES,
            Item: {
                PK: { S: Keys.purchaseEntryPK(tenantId, rid) },
                SK: { S: Keys.purchaseEntryMetadataSK() },
                GSI2PK: { S: Keys.imageHashPK(tenantId) },
                GSI2SK: { S: Keys.imageHashSK(imageHash) },
                GSI3PK: { S: Keys.billFingerprintPK(tenantId) },
                GSI3SK: { S: Keys.billFingerprintSK(fingerprint) },
                imageHash: { S: imageHash },
                billFingerprint: { S: fingerprint },
                createdAt: { S: new Date().toISOString() },
            },
        }));
        
        logger.info('Bill fingerprint stored', { tenantId, rid, fingerprint });
    } catch (error) {
        logger.error('Failed to store bill fingerprint', { error, tenantId, rid });
    }
}

function calculateImageHashFromKey(s3Key: string): string {
    // Use S3 key as hash proxy (since image is already stored)
    return crypto.createHash('md5').update(s3Key).digest('hex');
}
