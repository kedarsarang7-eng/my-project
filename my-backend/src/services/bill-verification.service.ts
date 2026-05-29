// ============================================================================
// AI-Powered Bill Verification Service
// ============================================================================
// P1: Detects OCR errors and validates extracted data
// ============================================================================

import { logger } from '../utils/logger';

// Type definition for parsed line items
interface ParsedLineItem {
    rawText: string;
    productName: string;
    quantity: number;
    unit: string;
    unitPrice: number;
    totalPrice: number;
    hsnCode?: string;
    batchNo?: string;
    expiryDate?: string;
    confidence: 'high' | 'medium' | 'low';
    parseWarnings: string[];
}

export interface VerificationResult {
    isValid: boolean;
    confidence: number;
    warnings: BillWarning[];
    suggestions: BillSuggestion[];
    correctedItems?: ParsedLineItem[];
}

export interface BillWarning {
    type: 'price_mismatch' | 'quantity_anomaly' | 'ocr_error' | 'duplicate_line' | 'suspicious_total';
    severity: 'error' | 'warning' | 'info';
    message: string;
    itemIndex?: number;
    field?: string;
    originalValue?: any;
    suggestedValue?: any;
}

export interface BillSuggestion {
    type: 'price_correction' | 'quantity_correction' | 'unit_correction' | 'name_correction';
    itemIndex: number;
    originalValue: string;
    suggestedValue: string;
    confidence: number;
    reason: string;
}

/**
 * Verify extracted bill data for common OCR errors
 */
export function verifyBillData(
    items: ParsedLineItem[],
    billTotal?: number,
    verticalType: string = 'grocery'
): VerificationResult {
    const warnings: BillWarning[] = [];
    const suggestions: BillSuggestion[] = [];
    const correctedItems = [...items];
    
    // Check each item
    for (let i = 0; i < items.length; i++) {
        const item = items[i];
        
        // 1. Check for common OCR errors in product names
        const nameWarnings = checkNameOcrErrors(item.productName, i);
        warnings.push(...nameWarnings);
        
        // 2. Validate price calculations
        const calculatedTotal = item.quantity * item.unitPrice;
        const priceDiff = Math.abs(calculatedTotal - item.totalPrice);
        const priceDiffPercent = item.totalPrice > 0 ? priceDiff / item.totalPrice : 0;
        
        if (priceDiffPercent > 0.05 && priceDiff > 1) {
            // Significant price mismatch
            warnings.push({
                type: 'price_mismatch',
                severity: 'warning',
                message: `Price calculation mismatch: ${item.quantity} × ${item.unitPrice} = ${calculatedTotal.toFixed(2)}, but bill shows ${item.totalPrice.toFixed(2)}`,
                itemIndex: i,
                field: 'totalPrice',
                originalValue: item.totalPrice,
                suggestedValue: calculatedTotal,
            });
            
            suggestions.push({
                type: 'price_correction',
                itemIndex: i,
                originalValue: item.totalPrice.toString(),
                suggestedValue: calculatedTotal.toFixed(2),
                confidence: 0.9,
                reason: 'Calculated from quantity × unit price',
            });
            
            correctedItems[i] = {
                ...item,
                totalPrice: calculatedTotal,
            };
        }
        
        // 3. Check for quantity anomalies
        if (item.quantity > 1000 && verticalType !== 'wholesale') {
            warnings.push({
                type: 'quantity_anomaly',
                severity: 'warning',
                message: `Unusually high quantity: ${item.quantity} ${item.unit}. Please verify.`,
                itemIndex: i,
                field: 'quantity',
            });
        }
        
        // 4. Check for 0/O confusion in numbers
        const quantityStr = item.rawText.match(/(\d+)/);
        if (quantityStr) {
            const hasZeroOhConfusion = /[0O]/.test(quantityStr[0]) && quantityStr[0].length > 1;
            if (hasZeroOhConfusion && item.quantity > 100) {
                warnings.push({
                    type: 'ocr_error',
                    severity: 'info',
                    message: 'Possible 0/O confusion detected in quantity',
                    itemIndex: i,
                    field: 'quantity',
                });
            }
        }
        
        // 5. Check for 1/I/l confusion
        if (/[1Il]/.test(item.rawText)) {
            const oneEyeElMatches = item.rawText.match(/[1Il]/g);
            if (oneEyeElMatches && oneEyeElMatches.length > 2) {
                warnings.push({
                    type: 'ocr_error',
                    severity: 'info',
                    message: 'Multiple 1/I/l characters detected - possible OCR error',
                    itemIndex: i,
                });
            }
        }
    }
    
    // 6. Check for duplicate lines
    const seenNames = new Map<string, number>();
    for (let i = 0; i < items.length; i++) {
        const normalizedName = items[i].productName.toLowerCase().trim();
        if (seenNames.has(normalizedName)) {
            warnings.push({
                type: 'duplicate_line',
                severity: 'warning',
                message: `Duplicate product detected: "${items[i].productName}" also appears at line ${seenNames.get(normalizedName)! + 1}`,
                itemIndex: i,
            });
        } else {
            seenNames.set(normalizedName, i);
        }
    }
    
    // 7. Validate bill total if provided
    if (billTotal && billTotal > 0) {
        const calculatedTotal = items.reduce((sum, item) => sum + item.totalPrice, 0);
        const totalDiff = Math.abs(calculatedTotal - billTotal);
        const totalDiffPercent = totalDiff / billTotal;
        
        if (totalDiffPercent > 0.02) {
            warnings.push({
                type: 'suspicious_total',
                severity: 'error',
                message: `Bill total mismatch: Sum of items is ${calculatedTotal.toFixed(2)}, but bill shows ${billTotal.toFixed(2)} (diff: ${totalDiff.toFixed(2)})`,
                originalValue: billTotal,
                suggestedValue: calculatedTotal,
            });
        }
    }
    
    // Calculate overall confidence
    const errorCount = warnings.filter(w => w.severity === 'error').length;
    const warningCount = warnings.filter(w => w.severity === 'warning').length;
    const confidence = Math.max(0, 100 - errorCount * 20 - warningCount * 5) / 100;
    
    logger.info('Bill verification complete', {
        itemCount: items.length,
        warningCount: warnings.length,
        suggestionCount: suggestions.length,
        confidence,
    });
    
    return {
        isValid: errorCount === 0,
        confidence,
        warnings,
        suggestions,
        correctedItems: suggestions.length > 0 ? correctedItems : undefined,
    };
}

/**
 * Check for common OCR errors in product names
 */
function checkNameOcrErrors(name: string, itemIndex: number): BillWarning[] {
    const warnings: BillWarning[] = [];
    
    // Common substitutions
    const suspiciousPatterns = [
        { pattern: /[0O]/g, char: '0/O', message: 'Zero/Oh confusion possible' },
        { pattern: /[1Il]/g, char: '1/I/l', message: 'One/Eye/El confusion possible' },
        { pattern: /[5S]/g, char: '5/S', message: 'Five/Ess confusion possible' },
        { pattern: /[8B]/g, char: '8/B', message: 'Eight/Bee confusion possible' },
        { pattern: /rn/g, char: 'r+n', message: 'rn/m confusion possible' },
        { pattern: /cl/g, char: 'c+l', message: 'cl/d confusion possible' },
    ];
    
    for (const { pattern, char, message } of suspiciousPatterns) {
        if (pattern.test(name)) {
            warnings.push({
                type: 'ocr_error',
                severity: 'info',
                message: `${message} in "${name}"`,
                itemIndex,
                field: 'productName',
            });
        }
    }
    
    return warnings;
}

/**
 * Auto-correct common OCR errors
 */
export function autoCorrectOcrErrors(text: string): string {
    return text
        // Common substitutions
        .replace(/[0]/g, 'O')  // Assume product codes use O not 0
        .replace(/[5]/g, 'S')  // In context of product names
        // Fix spacing issues
        .replace(/\s+/g, ' ')
        .trim();
}

/**
 * Validate HSN code format
 */
export function validateHsnCode(hsnCode: string): boolean {
    // HSN codes are 4, 6, or 8 digits
    return /^\d{4}(\d{2})?(\d{2})?$/.test(hsnCode);
}

/**
 * Suggest corrections for extracted data
 */
export function suggestCorrections(
    items: ParsedLineItem[],
    historicalData?: any[]
): BillSuggestion[] {
    const suggestions: BillSuggestion[] = [];
    
    // If we have historical data, use it for suggestions
    if (historicalData) {
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            
            // Find similar products in history
            const similarProducts = historicalData.filter(p => 
                p.name && calculateStringSimilarity(p.name, item.productName) > 0.8
            );
            
            if (similarProducts.length > 0) {
                const avgPrice = similarProducts.reduce((sum, p) => sum + (p.price || 0), 0) / similarProducts.length;
                const priceDiff = Math.abs(item.unitPrice - avgPrice);
                const priceDiffPercent = avgPrice > 0 ? priceDiff / avgPrice : 0;
                
                if (priceDiffPercent > 0.3) {
                    suggestions.push({
                        type: 'price_correction',
                        itemIndex: i,
                        originalValue: item.unitPrice.toString(),
                        suggestedValue: avgPrice.toFixed(2),
                        confidence: 0.7,
                        reason: `Historical avg price for similar products is ${avgPrice.toFixed(2)}`,
                    });
                }
            }
        }
    }
    
    return suggestions;
}

/**
 * Calculate string similarity (simple implementation)
 */
function calculateStringSimilarity(a: string, b: string): number {
    const longer = a.length > b.length ? a : b;
    const shorter = a.length > b.length ? b : a;
    
    if (longer.length === 0) return 1.0;
    
    const distance = levenshteinDistance(longer.toLowerCase(), shorter.toLowerCase());
    return (longer.length - distance) / longer.length;
}

/**
 * Calculate Levenshtein distance
 */
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
