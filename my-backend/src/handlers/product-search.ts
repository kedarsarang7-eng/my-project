// ============================================================================
// Product Search Handler
// ============================================================================
// P0: Product Search Integration - Backend API
// Provides real-time product search for scan bill review
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../middleware/auth';
import { UserRole } from '../types/auth.types';
import { response, withRequestContext } from '../utils/response';
import { logger } from '../utils/logger';
import { dynamoDb, TableNames } from '../config/dynamodb.config';
import { QueryCommand, ScanCommand } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import { calculateSimilarity } from '../services/product-matcher.service';

// Search schema
const searchSchema = z.object({
    query: z.string().min(1).max(100),
    category: z.string().optional(),
    limit: z.number().min(1).max(50).default(10),
    includeOutOfStock: z.boolean().default(false),
});

/**
 * GET /products/search?q={query}&limit={limit}&category={category}
 * Real-time product search endpoint
 */
export const searchProductsHandler = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const query = event.queryStringParameters?.q || '';
                const category = event.queryStringParameters?.category;
                const limit = parseInt(event.queryStringParameters?.limit || '10', 10);
                const includeOutOfStock = event.queryStringParameters?.includeOutOfStock === 'true';

                if (!query || query.length < 1) {
                    return response.error(400, 'MISSING_QUERY', 'Search query is required');
                }

                logger.info('Product search', { 
                    rid, 
                    tenantId: auth.tenantId, 
                    query, 
                    category,
                    limit 
                });

                // Normalize search query
                const normalizedQuery = query.toLowerCase().trim();
                const queryWords = normalizedQuery.split(/\s+/).filter(w => w.length > 1);

                // Search products using GSI on tenantId
                // First try: Exact prefix match on name
                const prefixResults = await searchByPrefix(
                    auth.tenantId,
                    normalizedQuery,
                    limit * 2,
                    category,
                    includeOutOfStock
                );

                // Second try: Contains match
                let results = prefixResults;
                if (results.length < limit) {
                    const containsResults = await searchByContains(
                        auth.tenantId,
                        normalizedQuery,
                        queryWords,
                        limit * 2,
                        category,
                        includeOutOfStock
                    );
                    
                    // Merge and deduplicate
                    const seen = new Set(results.map(r => r.id));
                    for (const r of containsResults) {
                        if (!seen.has(r.id)) {
                            results.push(r);
                            seen.add(r.id);
                        }
                    }
                }

                // Calculate relevance scores and sort
                results = results.map(r => ({
                    ...r,
                    relevanceScore: calculateRelevanceScore(r, normalizedQuery, queryWords),
                })).sort((a, b) => (b.relevanceScore || 0) - (a.relevanceScore || 0));

                // Return top results
                const finalResults = results.slice(0, limit);

                logger.info('Product search complete', { 
                    rid, 
                    tenantId: auth.tenantId,
                    query,
                    resultCount: finalResults.length 
                });

                return response.success({
                    query,
                    results: finalResults,
                    totalCount: results.length,
                });

            } catch (error: any) {
                logger.error('Product search failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'SEARCH_ERROR', 'Failed to search products', { 
                    detail: error.message 
                });
            }
        });
    },
    { requiredFeature: 'STANDARD_POS' }
);

/**
 * Search by prefix match (most relevant)
 */
async function searchByPrefix(
    tenantId: string,
    query: string,
    limit: number,
    category?: string,
    includeOutOfStock: boolean = false
): Promise<any[]> {
    try {
        // Use Scan with filter for prefix match
        // In production, this should use a GSI on name
        const params: any = {
            TableName: TableNames.PRODUCTS,
            FilterExpression: 'begins_with(#name, :query) AND PK = :pk',
            ExpressionAttributeNames: {
                '#name': 'name',
            },
            ExpressionAttributeValues: {
                ':query': { S: query },
                ':pk': { S: `TENANT#${tenantId}` },
            },
            Limit: limit,
        };

        if (!includeOutOfStock) {
            params.FilterExpression += ' AND stockQuantity > :zero';
            params.ExpressionAttributeValues[':zero'] = { N: '0' };
        }

        const result = await dynamoDb.send(new ScanCommand(params));
        
        return result.Items?.map(item => formatProduct(unmarshall(item))) || [];
    } catch (error) {
        logger.error('Prefix search failed', { error, tenantId, query });
        return [];
    }
}

/**
 * Search by contains (broader match)
 */
async function searchByContains(
    tenantId: string,
    query: string,
    queryWords: string[],
    limit: number,
    category?: string,
    includeOutOfStock: boolean = false
): Promise<any[]> {
    try {
        // Build OR expression for query words
        const wordConditions = queryWords.map((_, i) => `contains(#name, :word${i})`).join(' OR ');
        
        let filterExpression = `PK = :pk AND (${wordConditions})`;
        
        const expressionValues: any = {
            ':pk': { S: `TENANT#${tenantId}` },
        };
        
        queryWords.forEach((word, i) => {
            expressionValues[`:word${i}`] = { S: word };
        });

        if (!includeOutOfStock) {
            filterExpression += ' AND stockQuantity > :zero';
            expressionValues[':zero'] = { N: '0' };
        }

        const params: any = {
            TableName: TableNames.PRODUCTS,
            FilterExpression: filterExpression,
            ExpressionAttributeNames: {
                '#name': 'name',
            },
            ExpressionAttributeValues: expressionValues,
            Limit: limit,
        };

        const result = await dynamoDb.send(new ScanCommand(params));
        
        return result.Items?.map(item => formatProduct(unmarshall(item))) || [];
    } catch (error) {
        logger.error('Contains search failed', { error, tenantId, query });
        return [];
    }
}

/**
 * Calculate relevance score for sorting
 */
function calculateRelevanceScore(
    product: any,
    query: string,
    queryWords: string[]
): number {
    const name = (product.name || '').toLowerCase();
    let score = 0;

    // Exact match gets highest score
    if (name === query) {
        score += 100;
    }

    // Starts with query
    if (name.startsWith(query)) {
        score += 50;
    }

    // Contains query as phrase
    if (name.includes(query)) {
        score += 30;
    }

    // Contains individual words
    let wordMatches = 0;
    for (const word of queryWords) {
        if (name.includes(word)) {
            wordMatches++;
        }
    }
    score += wordMatches * 10;

    // Prefer in-stock items
    if (product.stockQuantity > 0) {
        score += 5;
    }

    return score;
}

/**
 * Format product for response
 */
function formatProduct(item: any): any {
    return {
        id: item.SK?.replace('PRODUCT#', ''),
        name: item.name,
        description: item.description,
        category: item.category,
        hsnCode: item.hsnCode,
        barcode: item.barcode,
        sku: item.sku,
        unit: item.unit || 'pcs',
        salePrice: item.salePrice,
        purchasePrice: item.purchasePrice,
        mrp: item.mrp,
        gstRate: item.gstRate,
        stockQuantity: item.stockQuantity || 0,
        batchTracking: item.batchTracking || false,
        expiryTracking: item.expiryTracking || false,
        imageUrl: item.imageUrl,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
    };
}

/**
 * GET /products/{productId}
 * Get single product by ID
 */
export const getProductHandler = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        return withRequestContext(auth.tenantId, async (rid) => {
            try {
                const productId = event.pathParameters?.productId;

                if (!productId) {
                    return response.error(400, 'MISSING_ID', 'Product ID is required');
                }

                const result = await dynamoDb.send(new QueryCommand({
                    TableName: TableNames.PRODUCTS,
                    KeyConditionExpression: 'PK = :pk AND SK = :sk',
                    ExpressionAttributeValues: {
                        ':pk': { S: `TENANT#${auth.tenantId}` },
                        ':sk': { S: `PRODUCT#${productId}` },
                    },
                }));

                if (!result.Items || result.Items.length === 0) {
                    return response.error(404, 'NOT_FOUND', 'Product not found');
                }

                const product = formatProduct(unmarshall(result.Items[0]));

                return response.success({ product });

            } catch (error: any) {
                logger.error('Get product failed', {
                    error: error.message,
                    rid,
                    tenantId: auth.tenantId,
                });
                return response.error(500, 'FETCH_ERROR', 'Failed to fetch product');
            }
        });
    },
    { requiredFeature: 'STANDARD_POS' }
);
