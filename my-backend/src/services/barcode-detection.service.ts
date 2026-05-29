// ============================================================================
// Barcode/QR Detection Service
// ============================================================================
// P2: Detects and decodes barcodes/QR codes in bill images
// ============================================================================

import { logger } from '../utils/logger';

export interface DetectedBarcode {
    type: 'barcode' | 'qrcode';
    format: string; // EAN-13, UPC-A, QR_CODE, etc.
    data: string;
    boundingBox: {
        left: number;
        top: number;
        width: number;
        height: number;
    };
    confidence: number;
}

export interface BarcodeDetectionResult {
    barcodes: DetectedBarcode[];
    productMatches: BarcodeProductMatch[];
}

export interface BarcodeProductMatch {
    barcode: string;
    productId?: string;
    productName?: string;
    matched: boolean;
    source: 'inventory' | 'master_catalog' | 'none';
}

/**
 * Detect barcodes in bill image
 * Uses AWS Textract or external service
 */
export async function detectBarcodes(
    imageBuffer: Buffer,
    tenantId: string
): Promise<BarcodeDetectionResult> {
    try {
        logger.info('Detecting barcodes', { tenantId, imageSize: imageBuffer.length });
        
        // In production, this would:
        // 1. Call AWS Textract with barcodes feature
        // 2. Or use ZXing/ML Kit via Lambda layer
        // 3. Or call Amazon Rekognition
        
        // Placeholder implementation
        const detectedBarcodes = await performBarcodeDetection(imageBuffer);
        
        // Match against inventory
        const productMatches = await matchBarcodesToProducts(
            detectedBarcodes.map(b => b.data),
            tenantId
        );
        
        logger.info('Barcode detection complete', {
            tenantId,
            detectedCount: detectedBarcodes.length,
            matchedCount: productMatches.filter(m => m.matched).length,
        });
        
        return {
            barcodes: detectedBarcodes,
            productMatches,
        };
    } catch (error) {
        logger.error('Barcode detection failed', { error, tenantId });
        return {
            barcodes: [],
            productMatches: [],
        };
    }
}

/**
 * Perform actual barcode detection
 * In production: uses Textract or barcode library
 */
async function performBarcodeDetection(imageBuffer: Buffer): Promise<DetectedBarcode[]> {
    // Placeholder - would integrate with actual barcode detection
    // Options:
    // 1. AWS Textract AnalyzeDocument with FeatureTypes.BARCODE
    // 2. Google Vision API
    // 3. Dynamsoft Barcode Reader
    // 4. ZXing via Lambda layer
    
    return [];
}

/**
 * Match detected barcodes to tenant's products
 */
async function matchBarcodesToProducts(
    barcodes: string[],
    tenantId: string
): Promise<BarcodeProductMatch[]> {
    const matches: BarcodeProductMatch[] = [];
    
    for (const barcode of barcodes) {
        // Clean barcode
        const cleanBarcode = barcode.trim();
        
        // Try to find in tenant inventory
        const inventoryMatch = await findInInventory(cleanBarcode, tenantId);
        
        if (inventoryMatch) {
            matches.push({
                barcode: cleanBarcode,
                productId: inventoryMatch.id,
                productName: inventoryMatch.name,
                matched: true,
                source: 'inventory',
            });
        } else {
            // Try master catalog (if enabled)
            const catalogMatch = await findInMasterCatalog(cleanBarcode);
            
            if (catalogMatch) {
                matches.push({
                    barcode: cleanBarcode,
                    productId: catalogMatch.id,
                    productName: catalogMatch.name,
                    matched: true,
                    source: 'master_catalog',
                });
            } else {
                matches.push({
                    barcode: cleanBarcode,
                    matched: false,
                    source: 'none',
                });
            }
        }
    }
    
    return matches;
}

/**
 * Find product in tenant inventory by barcode
 */
async function findInInventory(
    barcode: string,
    tenantId: string
): Promise<{ id: string; name: string } | null> {
    // In production: query DynamoDB by barcode GSI
    // const result = await dynamoDb.send(new QueryCommand({
    //     TableName: TableNames.PRODUCTS,
    //     IndexName: 'BarcodeGSI',
    //     KeyConditionExpression: 'barcode = :barcode AND PK = :pk',
    //     ...
    // }));
    
    return null;
}

/**
 * Find product in master catalog (global product database)
 */
async function findInMasterCatalog(
    barcode: string
): Promise<{ id: string; name: string } | null> {
    // In production: query global product catalog
    // Could use:
    // - Open Food Facts API
    // - UPC Database
    // - GS1 database
    
    return null;
}

/**
 * Validate barcode format
 */
export function validateBarcode(barcode: string): { valid: boolean; type: string } {
    // EAN-13: 13 digits
    if (/^\d{13}$/.test(barcode)) {
        return { valid: true, type: 'EAN-13' };
    }
    
    // UPC-A: 12 digits
    if (/^\d{12}$/.test(barcode)) {
        return { valid: true, type: 'UPC-A' };
    }
    
    // EAN-8: 8 digits
    if (/^\d{8}$/.test(barcode)) {
        return { valid: true, type: 'EAN-8' };
    }
    
    // Code 128: Variable length alphanumeric
    if (/^[A-Z0-9\-\.\s]{1,48}$/i.test(barcode)) {
        return { valid: true, type: 'CODE-128' };
    }
    
    return { valid: false, type: 'UNKNOWN' };
}

/**
 * Calculate EAN-13 check digit
 */
export function calculateEAN13CheckDigit(digits: string): number {
    let sum = 0;
    for (let i = 0; i < 12; i++) {
        const digit = parseInt(digits[i], 10);
        sum += i % 2 === 0 ? digit : digit * 3;
    }
    const checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit;
}

/**
 * Verify EAN-13 check digit
 */
export function verifyEAN13(barcode: string): boolean {
    if (barcode.length !== 13) return false;
    if (!/^\d+$/.test(barcode)) return false;
    
    const digits = barcode.substring(0, 12);
    const providedCheck = parseInt(barcode[12], 10);
    const calculatedCheck = calculateEAN13CheckDigit(digits);
    
    return providedCheck === calculatedCheck;
}

/**
 * Extract barcodes from Textract blocks
 */
export function extractBarcodesFromTextract(blocks: any[]): DetectedBarcode[] {
    const barcodes: DetectedBarcode[] = [];
    
    for (const block of blocks) {
        if (block.BlockType === 'BARCODE') {
            barcodes.push({
                type: 'barcode',
                format: block.DetectedBarcode?.Format || 'UNKNOWN',
                data: block.DetectedBarcode?.Text || '',
                boundingBox: {
                    left: block.Geometry?.BoundingBox?.Left || 0,
                    top: block.Geometry?.BoundingBox?.Top || 0,
                    width: block.Geometry?.BoundingBox?.Width || 0,
                    height: block.Geometry?.BoundingBox?.Height || 0,
                },
                confidence: block.Confidence || 0,
            });
        }
    }
    
    return barcodes;
}
