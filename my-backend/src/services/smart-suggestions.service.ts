// ============================================================================
// Smart Suggestions Engine
// ============================================================================
// P2: Learns from operator corrections to improve future matching
// ============================================================================

import { logger } from '../utils/logger';
import { dynamoDb, TableNames, Keys } from '../config/dynamodb.config';
import { PutItemCommand, QueryCommand } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';

export interface OperatorCorrection {
    tenantId: string;
    rid: string;
    originalOcrText: string;
    correctedProductId: string;
    correctedProductName: string;
    verticalType: string;
    createdAt: string;
}

export interface Suggestion {
    ocrText: string;
    suggestedProductId: string;
    suggestedProductName: string;
    confidence: number;
    matchReason: 'historical_correction' | 'name_similarity' | 'category_match';
}

/**
 * Store operator correction for learning
 */
export async function storeCorrection(
    tenantId: string,
    rid: string,
    originalOcrText: string,
    correctedProductId: string,
    correctedProductName: string,
    verticalType: string
): Promise<void> {
    try {
        const correction: OperatorCorrection = {
            tenantId,
            rid,
            originalOcrText: normalizeText(originalOcrText),
            correctedProductId,
            correctedProductName,
            verticalType,
            createdAt: new Date().toISOString(),
        };
        
        await dynamoDb.send(new PutItemCommand({
            TableName: TableNames.SCAN_BILL_CORRECTIONS,
            Item: {
                PK: { S: Keys.correctionPK(tenantId, correction.originalOcrText) },
                SK: { S: Keys.correctionSK(rid) },
                ...marshallCorrection(correction),
            },
        }));
        
        logger.info('Operator correction stored', {
            tenantId,
            originalText: originalOcrText,
            correctedTo: correctedProductName,
        });
    } catch (error) {
        logger.error('Failed to store correction', { error, tenantId, rid });
    }
}

/**
 * Get smart suggestions for OCR text
 */
export async function getSmartSuggestions(
    tenantId: string,
    ocrText: string,
    existingMatches: any[],
    limit: number = 3
): Promise<Suggestion[]> {
    const suggestions: Suggestion[] = [];
    const normalizedOcr = normalizeText(ocrText);
    
    // 1. Check historical corrections
    const historical = await findHistoricalCorrections(tenantId, normalizedOcr);
    for (const h of historical) {
        // Skip if already in existing matches
        if (existingMatches.some(m => m.productId === h.correctedProductId)) {
            continue;
        }
        
        suggestions.push({
            ocrText: h.originalOcrText,
            suggestedProductId: h.correctedProductId,
            suggestedProductName: h.correctedProductName,
            confidence: 0.95,
            matchReason: 'historical_correction',
        });
    }
    
    // 2. Check similar historical corrections
    if (suggestions.length < limit) {
        const similar = await findSimilarCorrections(tenantId, normalizedOcr);
        for (const s of similar) {
            if (existingMatches.some(m => m.productId === s.correctedProductId)) {
                continue;
            }
            if (suggestions.some(sug => sug.suggestedProductId === s.correctedProductId)) {
                continue;
            }
            
            suggestions.push({
                ocrText: s.originalOcrText,
                suggestedProductId: s.correctedProductId,
                suggestedProductName: s.correctedProductName,
                confidence: 0.75,
                matchReason: 'name_similarity',
            });
            
            if (suggestions.length >= limit) break;
        }
    }
    
    return suggestions.slice(0, limit);
}

/**
 * Find exact historical corrections
 */
async function findHistoricalCorrections(
    tenantId: string,
    normalizedOcr: string
): Promise<OperatorCorrection[]> {
    try {
        const result = await dynamoDb.send(new QueryCommand({
            TableName: TableNames.SCAN_BILL_CORRECTIONS,
            KeyConditionExpression: 'PK = :pk',
            ExpressionAttributeValues: {
                ':pk': { S: Keys.correctionPK(tenantId, normalizedOcr) },
            },
            Limit: 5,
        }));
        
        return result.Items?.map(i => unmarshallCorrection(unmarshall(i))) || [];
    } catch (error) {
        logger.error('Failed to find historical corrections', { error, tenantId });
        return [];
    }
}

/**
 * Find similar corrections (fuzzy match)
 */
async function findSimilarCorrections(
    tenantId: string,
    normalizedOcr: string
): Promise<OperatorCorrection[]> {
    try {
        // Get recent corrections for tenant
        const result = await dynamoDb.send(new QueryCommand({
            TableName: TableNames.SCAN_BILL_CORRECTIONS,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :pk',
            ExpressionAttributeValues: {
                ':pk': { S: Keys.correctionTenantPK(tenantId) },
            },
            Limit: 100,
        }));
        
        if (!result.Items) return [];
        
        const corrections = result.Items.map(i => unmarshallCorrection(unmarshall(i)));
        
        // Calculate similarity and filter
        return corrections
            .map(c => ({
                correction: c,
                similarity: calculateSimilarity(normalizedOcr, c.originalOcrText),
            }))
            .filter(item => item.similarity > 0.6)
            .sort((a, b) => b.similarity - a.similarity)
            .map(item => item.correction);
    } catch (error) {
        logger.error('Failed to find similar corrections', { error, tenantId });
        return [];
    }
}

/**
 * Calculate string similarity
 */
function calculateSimilarity(a: string, b: string): number {
    if (a === b) return 1.0;
    if (a.length === 0 || b.length === 0) return 0.0;
    
    const longer = a.length > b.length ? a : b;
    const shorter = a.length > b.length ? b : a;
    
    const distance = levenshteinDistance(longer, shorter);
    return (longer.length - distance) / longer.length;
}

function levenshteinDistance(a: string, b: string): number {
    const matrix: number[][] = [];
    
    for (let i = 0; i <= b.length; i++) {
        matrix[i] = [i];
    }
    
    for (let j = 0; j <= a.length; j++) {
        matrix[0][j] = j;
    }
    
    for (let i = 1; i <= b.length; i++) {
        for (let j = 1; j <= a.length; j++) {
            if (b.charAt(i - 1) === a.charAt(j - 1)) {
                matrix[i][j] = matrix[i - 1][j - 1];
            } else {
                matrix[i][j] = Math.min(
                    matrix[i - 1][j - 1] + 1,
                    Math.min(matrix[i][j - 1] + 1, matrix[i - 1][j] + 1)
                );
            }
        }
    }
    
    return matrix[b.length][a.length];
}

/**
 * Normalize text for comparison
 */
function normalizeText(text: string): string {
    return text
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

/**
 * Marshall correction for DynamoDB
 */
function marshallCorrection(correction: OperatorCorrection): any {
    return {
        tenantId: { S: correction.tenantId },
        rid: { S: correction.rid },
        originalOcrText: { S: correction.originalOcrText },
        correctedProductId: { S: correction.correctedProductId },
        correctedProductName: { S: correction.correctedProductName },
        verticalType: { S: correction.verticalType },
        createdAt: { S: correction.createdAt },
        GSI1PK: { S: Keys.correctionTenantPK(correction.tenantId) },
        GSI1SK: { S: correction.createdAt },
    };
}

/**
 * Unmarshall correction from DynamoDB
 */
function unmarshallCorrection(item: any): OperatorCorrection {
    return {
        tenantId: item.tenantId,
        rid: item.rid,
        originalOcrText: item.originalOcrText,
        correctedProductId: item.correctedProductId,
        correctedProductName: item.correctedProductName,
        verticalType: item.verticalType,
        createdAt: item.createdAt,
    };
}

/**
 * Get analytics on operator corrections
 */
export async function getCorrectionAnalytics(
    tenantId: string,
    days: number = 30
): Promise<{
    totalCorrections: number;
    mostCorrectedProducts: { productId: string; productName: string; count: number }[];
    averageConfidenceBefore: number;
}> {
    try {
        const sinceDate = new Date();
        sinceDate.setDate(sinceDate.getDate() - days);
        
        const result = await dynamoDb.send(new QueryCommand({
            TableName: TableNames.SCAN_BILL_CORRECTIONS,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :pk AND GSI1SK >= :since',
            ExpressionAttributeValues: {
                ':pk': { S: Keys.correctionTenantPK(tenantId) },
                ':since': { S: sinceDate.toISOString() },
            },
        }));
        
        const corrections = result.Items?.map(i => unmarshallCorrection(unmarshall(i))) || [];
        
        // Aggregate by product
        const productCounts = new Map<string, { name: string; count: number }>();
        for (const c of corrections) {
            const existing = productCounts.get(c.correctedProductId);
            if (existing) {
                existing.count++;
            } else {
                productCounts.set(c.correctedProductId, {
                    name: c.correctedProductName,
                    count: 1,
                });
            }
        }
        
        const mostCorrected = Array.from(productCounts.entries())
            .map(([productId, data]) => ({
                productId,
                productName: data.name,
                count: data.count,
            }))
            .sort((a, b) => b.count - a.count)
            .slice(0, 10);
        
        return {
            totalCorrections: corrections.length,
            mostCorrectedProducts: mostCorrected,
            averageConfidenceBefore: 0.6, // Placeholder
        };
    } catch (error) {
        logger.error('Failed to get correction analytics', { error, tenantId });
        return {
            totalCorrections: 0,
            mostCorrectedProducts: [],
            averageConfidenceBefore: 0,
        };
    }
}
