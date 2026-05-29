// ============================================================================
// Product Matcher Service — Fuzzy Match OCR Products to Catalog
// ============================================================================
// Matches parsed product names from OCR against tenant's DynamoDB inventory.
// Uses multiple matching strategies with priority-based confidence scoring.
//
// Matching strategies (in priority order):
// 1. HSN code exact match → confidence: exact
// 2. Barcode/SKU exact match → confidence: exact
// 3. Exact string match (case-insensitive) → confidence: exact
// 4. Normalized match (remove noise words) → confidence: high
// 5. Token overlap (70%+ token match) → confidence: medium
// 6. Phonetic match for OCR errors → confidence: low
// 7. No match → flag for manual selection
// ============================================================================

import { InventoryItem } from '../types/inventory.types';
import { 
    Keys, 
    queryItems, 
    queryAllItems,
    getItem,
} from '../config/dynamodb.config';
import { 
    normalizeName, 
    combinedSimilarity, 
    FUZZY_THRESHOLD,
    FuzzyCandidate,
    FuzzyMatchResult,
    findBestMatch,
    vendorNameSimilarity,
} from '../utils/fuzzy-match';
import { ParsedLineItem } from './bill-parser.service';
import { logger } from '../utils/logger';

export interface MatchResult {
    parsedItem: ParsedLineItem;
    matchedProduct: InventoryItem | null;
    matchConfidence: 'exact' | 'high' | 'medium' | 'low' | 'none';
    alternativeSuggestions: InventoryItem[];
    requiresManualReview: boolean;
}

export interface ProductMatchOptions {
    verticalType: string;
    tenantId: string;
    preferHsnMatch?: boolean;
    supplierName?: string;
}

// Cache for catalog lookup (per-request, not across invocations)
interface CatalogCache {
    products: InventoryItem[];
    byHsn: Map<string, InventoryItem[]>;
    byBarcode: Map<string, InventoryItem>;
    bySku: Map<string, InventoryItem>;
    normalizedNames: Map<string, FuzzyCandidate>;
}

/**
 * Build catalog cache for fast lookups
 */
async function buildCatalogCache(tenantId: string): Promise<CatalogCache> {
    const pk = Keys.tenantPK(tenantId);
    
    // Query all active products for the tenant
    const result = await queryAllItems<Record<string, any>>(pk, 'PRODUCT#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND isActive = :true',
        expressionAttributeValues: { ':false': false, ':true': true },
        maxPages: 50, // Reasonable limit for most tenants
    });
    
    const products: InventoryItem[] = result.map(mapToInventoryItem);
    
    // Build lookup indexes
    const byHsn = new Map<string, InventoryItem[]>();
    const byBarcode = new Map<string, InventoryItem>();
    const bySku = new Map<string, InventoryItem>();
    const normalizedNames = new Map<string, FuzzyCandidate>();
    
    for (const product of products) {
        // Index by HSN
        if (product.hsnCode) {
            const existing = byHsn.get(product.hsnCode) || [];
            existing.push(product);
            byHsn.set(product.hsnCode, existing);
        }
        
        // Index by barcode
        if (product.barcode) {
            byBarcode.set(product.barcode, product);
        }
        
        // Index by SKU
        if (product.sku) {
            bySku.set(product.sku, product);
        }
        
        // Pre-normalize name for fuzzy matching
        const normalized = normalizeName(product.name);
        normalizedNames.set(product.id, {
            id: product.id,
            normalizedName: normalized,
            vendor: product.brand || undefined,
        });
    }
    
    logger.info('Catalog cache built', {
        tenantId,
        productCount: products.length,
        hsnCount: byHsn.size,
        barcodeCount: byBarcode.size,
    });
    
    return {
        products,
        byHsn,
        byBarcode,
        bySku,
        normalizedNames,
    };
}

/**
 * Map DynamoDB row to InventoryItem
 */
function mapToInventoryItem(row: Record<string, any>): InventoryItem {
    return {
        id: row.id,
        tenantId: row.tenantId,
        productType: row.productType || 'general',
        name: row.name,
        displayName: row.displayName || undefined,
        sku: row.sku || undefined,
        barcode: row.barcode || undefined,
        category: row.category || undefined,
        subcategory: row.subcategory || undefined,
        brand: row.brand || undefined,
        hsnCode: row.hsnCode || undefined,
        unit: row.unit || 'pcs',
        description: row.description || undefined,
        imageUrl: row.imageUrl || undefined,
        salePriceCents: row.salePriceCents || 0,
        purchasePriceCents: row.purchasePriceCents || undefined,
        mrpCents: row.mrpCents || undefined,
        wholesalePriceCents: row.wholesalePriceCents || undefined,
        pricingTiers: row.pricingTiers || undefined,
        cgstRateBp: row.cgstRateBp || 0,
        sgstRateBp: row.sgstRateBp || 0,
        igstRateBp: row.igstRateBp || 0,
        currentStock: row.currentStock || 0,
        lowStockThreshold: row.lowStockThreshold || 5,
        reorderQty: row.reorderQty || undefined,
        locationStock: row.locationStock || undefined,
        variantGroupId: row.variantGroupId || undefined,
        attributes: row.attributes || {},
        isActive: row.isActive !== false,
        isArchived: row.isArchived || false,
        createdAt: new Date(row.createdAt || Date.now()),
        updatedAt: new Date(row.updatedAt || Date.now()),
    };
}

/**
 * Try exact HSN code match
 */
function tryHsnMatch(
    parsedItem: ParsedLineItem,
    cache: CatalogCache
): { product: InventoryItem | null; confidence: 'exact' | 'none' } {
    if (!parsedItem.hsnCode) {
        return { product: null, confidence: 'none' };
    }
    
    const matches = cache.byHsn.get(parsedItem.hsnCode);
    if (matches && matches.length > 0) {
        // Return first match (or could apply additional filtering)
        return { product: matches[0], confidence: 'exact' };
    }
    
    return { product: null, confidence: 'none' };
}

/**
 * Try barcode exact match
 */
function tryBarcodeMatch(
    parsedItem: ParsedLineItem,
    cache: CatalogCache
): { product: InventoryItem | null; confidence: 'exact' | 'none' } {
    // Check if product name contains what looks like a barcode
    // Barcodes are typically 8-14 digit numbers
    const barcodeMatch = parsedItem.rawText.match(/\b(\d{8,14})\b/);
    if (!barcodeMatch) {
        return { product: null, confidence: 'none' };
    }
    
    const potentialBarcode = barcodeMatch[1];
    const product = cache.byBarcode.get(potentialBarcode);
    
    if (product) {
        return { product, confidence: 'exact' };
    }
    
    return { product: null, confidence: 'none' };
}

/**
 * Try SKU exact match
 */
function trySkuMatch(
    parsedItem: ParsedLineItem,
    cache: CatalogCache
): { product: InventoryItem | null; confidence: 'exact' | 'none' } {
    // Check if product name contains what looks like an SKU
    // SKUs often contain letters and numbers
    const skuPatterns = [
        /\b([A-Z]{2,}\d+[A-Z0-9]*)\b/,  // ABC123, SKU456XYZ
        /\b(SKU[\-]?[A-Z0-9]+)\b/i,      // SKU-123, SKU456
    ];
    
    for (const pattern of skuPatterns) {
        const skuMatch = parsedItem.rawText.match(pattern);
        if (skuMatch) {
            const potentialSku = skuMatch[1].toUpperCase();
            const product = cache.bySku.get(potentialSku);
            if (product) {
                return { product, confidence: 'exact' };
            }
        }
    }
    
    return { product: null, confidence: 'none' };
}

/**
 * Try exact string match (case-insensitive, trimmed)
 */
function tryExactMatch(
    parsedItem: ParsedLineItem,
    cache: CatalogCache
): { product: InventoryItem | null; confidence: 'exact' | 'none' } {
    const searchName = parsedItem.productName.toLowerCase().trim();
    
    for (const product of cache.products) {
        const productName = product.name.toLowerCase().trim();
        if (productName === searchName) {
            return { product, confidence: 'exact' };
        }
        // Also check display name if available
        if (product.displayName) {
            const displayName = product.displayName.toLowerCase().trim();
            if (displayName === searchName) {
                return { product, confidence: 'exact' };
            }
        }
    }
    
    return { product: null, confidence: 'none' };
}

/**
 * Try normalized fuzzy match
 */
function tryNormalizedMatch(
    parsedItem: ParsedLineItem,
    cache: CatalogCache,
    supplierName?: string
): { product: InventoryItem | null; confidence: 'high' | 'medium' | 'none' } {
    const normalizedQuery = normalizeName(parsedItem.productName);
    
    // Convert cache to candidates array
    const candidates = Array.from(cache.normalizedNames.values());
    
    if (supplierName) {
        // Use vendor+name compound matching
        let bestMatch: { candidate: FuzzyCandidate; score: number } | null = null;
        let bestScore = 0;
        
        for (const candidate of candidates) {
            const score = vendorNameSimilarity(
                normalizedQuery,
                supplierName,
                candidate.normalizedName,
                candidate.vendor
            );
            if (score > bestScore) {
                bestScore = score;
                bestMatch = { candidate, score };
            }
        }
        
        if (bestMatch && bestMatch.score >= FUZZY_THRESHOLD) {
            const product = cache.products.find(p => p.id === bestMatch!.candidate.id)!;
            return { product, confidence: 'high' };
        }
    } else {
        // Use name-only matching
        const match = findBestMatch(normalizedQuery, candidates, FUZZY_THRESHOLD);
        
        if (match) {
            const product = cache.products.find(p => p.id === match.candidate.id)!;
            
            // Determine confidence based on score
            if (match.score >= 0.95) {
                return { product, confidence: 'high' };
            } else if (match.score >= FUZZY_THRESHOLD) {
                return { product, confidence: 'medium' };
            }
        }
    }
    
    return { product: null, confidence: 'none' };
}

/**
 * Try token overlap match (for reordered words)
 */
function tryTokenOverlapMatch(
    parsedItem: ParsedLineItem,
    cache: CatalogCache
): { product: InventoryItem | null; confidence: 'medium' | 'low' | 'none' } {
    const queryTokens = normalizeName(parsedItem.productName).split(/\s+/);
    
    let bestMatch: { product: InventoryItem; score: number } | null = null;
    let bestScore = 0;
    
    for (const product of cache.products) {
        const productTokens = normalizeName(product.name).split(/\s+/);
        
        // Calculate token overlap
        const querySet = new Set(queryTokens);
        const productSet = new Set(productTokens);
        
        let intersection = 0;
        for (const token of querySet) {
            if (productSet.has(token)) intersection++;
        }
        
        const union = querySet.size + productSet.size - intersection;
        const tokenScore = union > 0 ? intersection / union : 0;
        
        if (tokenScore > bestScore) {
            bestScore = tokenScore;
            bestMatch = { product, score: tokenScore };
        }
    }
    
    if (bestMatch) {
        if (bestMatch.score >= 0.7) {
            return { product: bestMatch.product, confidence: 'medium' };
        } else if (bestMatch.score >= 0.5) {
            return { product: bestMatch.product, confidence: 'low' };
        }
    }
    
    return { product: null, confidence: 'none' };
}

/**
 * Get alternative suggestions for a product
 */
function getAlternativeSuggestions(
    parsedItem: ParsedLineItem,
    cache: CatalogCache,
    excludeProductId?: string
): InventoryItem[] {
    const normalizedQuery = normalizeName(parsedItem.productName);
    const candidates = Array.from(cache.normalizedNames.values())
        .filter(c => c.id !== excludeProductId);
    
    // Score all candidates
    const scored = candidates.map(candidate => ({
        candidate,
        score: combinedSimilarity(normalizedQuery, candidate.normalizedName),
    }));
    
    // Sort by score and take top 3
    scored.sort((a, b) => b.score - a.score);
    
    return scored
        .slice(0, 3)
        .map(s => cache.products.find(p => p.id === s.candidate.id)!)
        .filter(p => p !== undefined);
}

/**
 * Match a single parsed line item to the product catalog
 */
async function matchLineItem(
    parsedItem: ParsedLineItem,
    cache: CatalogCache,
    options: ProductMatchOptions
): Promise<MatchResult> {
    const { verticalType, preferHsnMatch, supplierName } = options;
    
    // Skip items with no product name
    if (!parsedItem.productName || parsedItem.productName === 'Unknown Product') {
        return {
            parsedItem,
            matchedProduct: null,
            matchConfidence: 'none',
            alternativeSuggestions: getAlternativeSuggestions(parsedItem, cache),
            requiresManualReview: true,
        };
    }
    
    // Try matching strategies in priority order
    
    // 1. HSN code match (for pharmacy, prioritize this)
    if (preferHsnMatch && parsedItem.hsnCode) {
        const hsnResult = tryHsnMatch(parsedItem, cache);
        if (hsnResult.product) {
            return {
                parsedItem,
                matchedProduct: hsnResult.product,
                matchConfidence: 'exact',
                alternativeSuggestions: [],
                requiresManualReview: false,
            };
        }
    }
    
    // 2. Barcode exact match
    const barcodeResult = tryBarcodeMatch(parsedItem, cache);
    if (barcodeResult.product) {
        return {
            parsedItem,
            matchedProduct: barcodeResult.product,
            matchConfidence: 'exact',
            alternativeSuggestions: [],
            requiresManualReview: false,
        };
    }
    
    // 3. SKU exact match
    const skuResult = trySkuMatch(parsedItem, cache);
    if (skuResult.product) {
        return {
            parsedItem,
            matchedProduct: skuResult.product,
            matchConfidence: 'exact',
            alternativeSuggestions: [],
            requiresManualReview: false,
        };
    }
    
    // 4. Exact string match
    const exactResult = tryExactMatch(parsedItem, cache);
    if (exactResult.product) {
        return {
            parsedItem,
            matchedProduct: exactResult.product,
            matchConfidence: 'exact',
            alternativeSuggestions: [],
            requiresManualReview: false,
        };
    }
    
    // 5. Normalized fuzzy match
    const normalizedResult = tryNormalizedMatch(parsedItem, cache, supplierName);
    if (normalizedResult.product) {
        return {
            parsedItem,
            matchedProduct: normalizedResult.product,
            matchConfidence: normalizedResult.confidence,
            alternativeSuggestions: getAlternativeSuggestions(parsedItem, cache, normalizedResult.product.id),
            requiresManualReview: normalizedResult.confidence !== 'high',
        };
    }
    
    // 6. Token overlap match
    const tokenResult = tryTokenOverlapMatch(parsedItem, cache);
    if (tokenResult.product) {
        return {
            parsedItem,
            matchedProduct: tokenResult.product,
            matchConfidence: tokenResult.confidence,
            alternativeSuggestions: getAlternativeSuggestions(parsedItem, cache, tokenResult.product.id),
            requiresManualReview: true,
        };
    }
    
    // 7. HSN fallback (if not already tried)
    if (!preferHsnMatch && parsedItem.hsnCode) {
        const hsnResult = tryHsnMatch(parsedItem, cache);
        if (hsnResult.product) {
            return {
                parsedItem,
                matchedProduct: hsnResult.product,
                matchConfidence: 'exact',
                alternativeSuggestions: [],
                requiresManualReview: false,
            };
        }
    }
    
    // No match found
    return {
        parsedItem,
        matchedProduct: null,
        matchConfidence: 'none',
        alternativeSuggestions: getAlternativeSuggestions(parsedItem, cache),
        requiresManualReview: true,
    };
}

/**
 * Match multiple parsed line items to the product catalog
 */
export async function matchProducts(
    parsedItems: ParsedLineItem[],
    tenantId: string,
    options: ProductMatchOptions
): Promise<MatchResult[]> {
    // Build catalog cache once for all items
    const cache = await buildCatalogCache(tenantId);
    
    // Match each item
    const results: MatchResult[] = [];
    for (const item of parsedItems) {
        const match = await matchLineItem(item, cache, options);
        results.push(match);
    }
    
    // Log summary
    const summary = {
        tenantId,
        totalItems: results.length,
        exact: results.filter(r => r.matchConfidence === 'exact').length,
        high: results.filter(r => r.matchConfidence === 'high').length,
        medium: results.filter(r => r.matchConfidence === 'medium').length,
        low: results.filter(r => r.matchConfidence === 'low').length,
        none: results.filter(r => r.matchConfidence === 'none').length,
        requiresReview: results.filter(r => r.requiresManualReview).length,
    };
    logger.info('Product matching complete', summary);
    
    return results;
}

/**
 * Search products by name (for manual selection)
 */
export async function searchProductsByName(
    tenantId: string,
    searchTerm: string,
    limit: number = 10
): Promise<InventoryItem[]> {
    const normalizedSearch = normalizeName(searchTerm);
    const cache = await buildCatalogCache(tenantId);
    
    // Score all products
    const scored = cache.products.map(product => ({
        product,
        score: combinedSimilarity(normalizedSearch, normalizeName(product.name)),
    }));
    
    // Sort by score and take top N
    scored.sort((a, b) => b.score - a.score);
    
    return scored
        .slice(0, limit)
        .filter(s => s.score > 0.3) // Minimum relevance threshold
        .map(s => s.product);
}
