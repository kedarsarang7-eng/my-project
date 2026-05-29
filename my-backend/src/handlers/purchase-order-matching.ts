// ============================================================================
// Purchase Order Matching Handler
// ============================================================================
// P1: Match received items against open purchase orders
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../middleware/auth';
import { UserRole } from '../types/auth.types';
import { response, withRequestContext } from '../utils/response';
import { logger } from '../utils/logger';
import { dynamoDb, TableNames, Keys } from '../config/dynamodb.config';
import { QueryCommand } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';

// Match schema
const matchSchema = z.object({
    supplierId: z.string(),
    items: z.array(z.object({
        productId: z.string().optional(),
        productName: z.string(),
        quantity: z.number().positive(),
        unitPrice: z.number().nonnegative(),
    })),
});

/**
 * POST /purchase/scan-bill/match-po
 * Match extracted items against open POs
 */
export const matchPurchaseOrderHandler = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const body = JSON.parse(event.body || '{}');
                const parsed = matchSchema.safeParse(body);
                
                if (!parsed.success) {
                    return response.error(400, 'VALIDATION_ERROR', 'Invalid request body');
                }
                
                const { supplierId, items } = parsed.data;
                
                // Find open purchase orders for this supplier
                const openPOs = await findOpenPurchaseOrders(auth.tenantId, supplierId);
                
                if (openPOs.length === 0) {
                    return response.success({
                        hasMatchingPO: false,
                        message: 'No open purchase orders found for this supplier',
                    });
                }
                
                // Match items against each PO
                const matchResults: POMatchResult[] = [];
                
                for (const po of openPOs) {
                    const match = calculatePOMatch(po, items);
                    matchResults.push(match);
                }
                
                // Sort by match percentage
                matchResults.sort((a, b) => b.matchPercentage - a.matchPercentage);
                
                const bestMatch = matchResults[0];
                const hasGoodMatch = bestMatch.matchPercentage >= 80;
                
                logger.info('PO matching complete', {
                    rid,
                    tenantId: auth.tenantId,
                    supplierId,
                    poCount: openPOs.length,
                    bestMatch: bestMatch.matchPercentage,
                });
                
                return response.success({
                    hasMatchingPO: hasGoodMatch,
                    bestMatchPO: hasGoodMatch ? {
                        poId: bestMatch.poId,
                        poNumber: bestMatch.poNumber,
                        matchPercentage: bestMatch.matchPercentage,
                        matchedItems: bestMatch.matchedItems,
                        unmatchedItems: bestMatch.unmatchedItems,
                        quantityVariance: bestMatch.quantityVariance,
                        priceVariance: bestMatch.priceVariance,
                    } : undefined,
                    allMatches: matchResults.map(m => ({
                        poId: m.poId,
                        poNumber: m.poNumber,
                        matchPercentage: m.matchPercentage,
                    })),
                    warning: hasGoodMatch && (bestMatch.quantityVariance > 0 || bestMatch.priceVariance > 0)
                        ? `PO match found but with ${bestMatch.quantityVariance > 0 ? 'quantity' : 'price'} variance`
                        : undefined,
                });
                
            } catch (error: any) {
                logger.error('PO matching failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'MATCH_ERROR', 'Failed to match purchase orders');
            }
        });
    },
    { requiredFeature: 'STANDARD_POS' }
);

interface POMatchResult {
    poId: string;
    poNumber: string;
    matchPercentage: number;
    matchedItems: MatchedItem[];
    unmatchedItems: UnmatchedItem[];
    quantityVariance: number;
    priceVariance: number;
}

interface MatchedItem {
    poItemId: string;
    poItemName: string;
    receivedItemName: string;
    poQuantity: number;
    receivedQuantity: number;
    quantityDiff: number;
    poPrice: number;
    receivedPrice: number;
    priceDiff: number;
}

interface UnmatchedItem {
    receivedItemName: string;
    receivedQuantity: number;
    reason: 'not_in_po' | 'quantity_exceeded' | 'price_mismatch';
}

/**
 * Find open purchase orders for supplier
 */
async function findOpenPurchaseOrders(tenantId: string, supplierId: string): Promise<any[]> {
    try {
        const result = await dynamoDb.send(new QueryCommand({
            TableName: TableNames.PURCHASE_ORDERS,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :pk',
            FilterExpression: 'supplierId = :supplierId AND #status = :status',
            ExpressionAttributeNames: {
                '#status': 'status',
            },
            ExpressionAttributeValues: {
                ':pk': { S: Keys.purchaseOrderStatusPK(tenantId, 'open') },
                ':supplierId': { S: supplierId },
                ':status': { S: 'open' },
            },
        }));
        
        return result.Items?.map(i => unmarshall(i)) || [];
    } catch (error) {
        logger.error('Failed to find open POs', { error, tenantId, supplierId });
        return [];
    }
}

/**
 * Calculate match between PO and received items
 */
function calculatePOMatch(po: any, receivedItems: any[]): POMatchResult {
    const poItems = po.items || [];
    const matchedItems: MatchedItem[] = [];
    const unmatchedItems: UnmatchedItem[] = [];
    
    // Track which PO items have been matched
    const matchedPOItemIds = new Set<string>();
    
    for (const received of receivedItems) {
        // Find best matching PO item by name similarity
        let bestMatch: any = null;
        let bestScore = 0;
        
        for (const poItem of poItems) {
            if (matchedPOItemIds.has(poItem.id)) continue;
            
            const score = calculateStringSimilarity(
                received.productName,
                poItem.name
            );
            
            if (score > bestScore && score > 0.6) {
                bestScore = score;
                bestMatch = poItem;
            }
        }
        
        if (bestMatch) {
            matchedPOItemIds.add(bestMatch.id);
            
            const quantityDiff = received.quantity - bestMatch.quantity;
            const priceDiff = received.unitPrice - bestMatch.unitPrice;
            
            matchedItems.push({
                poItemId: bestMatch.id,
                poItemName: bestMatch.name,
                receivedItemName: received.productName,
                poQuantity: bestMatch.quantity,
                receivedQuantity: received.quantity,
                quantityDiff,
                poPrice: bestMatch.unitPrice,
                receivedPrice: received.unitPrice,
                priceDiff,
            });
            
            // Check for quantity or price variance
            if (quantityDiff > 0) {
                unmatchedItems.push({
                    receivedItemName: received.productName,
                    receivedQuantity: quantityDiff,
                    reason: 'quantity_exceeded',
                });
            }
        } else {
            unmatchedItems.push({
                receivedItemName: received.productName,
                receivedQuantity: received.quantity,
                reason: 'not_in_po',
            });
        }
    }
    
    // Calculate match percentage
    const totalPOItems = poItems.length;
    const matchedCount = matchedItems.length;
    const matchPercentage = totalPOItems > 0 
        ? Math.round((matchedCount / totalPOItems) * 100)
        : 0;
    
    // Calculate variances
    const quantityVariance = matchedItems.reduce((sum, m) => 
        sum + Math.abs(m.quantityDiff), 0);
    const priceVariance = matchedItems.reduce((sum, m) => 
        sum + Math.abs(m.priceDiff * m.receivedQuantity), 0);
    
    return {
        poId: po.id,
        poNumber: po.poNumber,
        matchPercentage,
        matchedItems,
        unmatchedItems,
        quantityVariance,
        priceVariance,
    };
}

/**
 * Simple string similarity (Levenshtein-based)
 */
function calculateStringSimilarity(a: string, b: string): number {
    const longer = a.length > b.length ? a : b;
    const shorter = a.length > b.length ? b : a;
    
    if (longer.length === 0) return 1.0;
    
    const distance = levenshteinDistance(longer.toLowerCase(), shorter.toLowerCase());
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
 * Update PO status to received/partial
 */
export async function updatePOStatus(
    tenantId: string,
    poId: string,
    matchedItems: MatchedItem[]
): Promise<void> {
    try {
        // Check if all items fully received
        const allReceived = matchedItems.every(m => m.quantityDiff <= 0);
        const newStatus = allReceived ? 'received' : 'partial';
        
        logger.info('Updating PO status', { tenantId, poId, newStatus });
        
        // In production: update DynamoDB
        // await dynamoDb.send(new UpdateItemCommand({...}));
        
    } catch (error) {
        logger.error('Failed to update PO status', { error, tenantId, poId });
    }
}
