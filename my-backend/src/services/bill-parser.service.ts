// ============================================================================
// Bill Parser Service — OCR Line Item Extraction
// ============================================================================
// Converts raw Textract OCR lines into structured purchase line items.
// Supports: Grocery, Pharmacy, Hardware, Wholesale, Restaurant, Clothing verticals
//
// Key features:
// - Skip non-product lines (headers, totals, addresses, GSTIN)
// - Indian unit detection (kg, gm, ltr, pcs, nos, doz, bag, bora, peti, etc.)
// - Price extraction with Indian number format (1,000.00, ₹ symbol)
// - HSN code detection (4-8 digit GST codes)
// - Batch/Expiry for pharmacy ("Batch: XYZ123", "Exp: 12/26")
// - Confidence scoring (high/medium/low)
// ============================================================================

import { logger } from '../utils/logger';

export interface ParsedLineItem {
    rawText: string;
    productName: string;
    quantity: number | null;
    unit: string | null;
    unitPrice: number | null;
    totalPrice: number | null;
    hsnCode: string | null;
    batchNo: string | null;
    expiryDate: string | null;
    confidence: 'high' | 'medium' | 'low';
    parseWarnings: string[];
}

export interface RawLine {
    text: string;
    lineIndex: number;
    confidence: number;
}

// Common patterns to skip (headers, totals, metadata)
const SKIP_PATTERNS = [
    // Headers and labels
    /^(item|product|description|qty|quantity|rate|price|amount|total|subtotal|gst|tax|discount)\s*$/i,
    /^(sr\s*no|s\.?no|serial|#|no\.?)$/i,
    /^(bill\s*to|ship\s*to|sold\s*to|supplier|vendor|customer)$/i,
    /^(invoice|bill|receipt|challan|order)$/i,
    /^(date|time|terms|conditions|note|remarks)$/i,
    
    // Totals and summaries
    /^(grand\s*total|net\s*total|total\s*amount|bill\s*total)$/i,
    /^(sub\s*total|cart\s*total|gross\s*total)$/i,
    /^(total\s*items|item\s*count|no\.?\s*of\s*items)$/i,
    
    // GST and tax
    /^(gstin|gst|cgst|sgst|igst|tax|vat|tin|cin)$/i,
    /^(hsn|sac|tax\s*rate|gst\s*rate)$/i,
    /^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}$/, // GSTIN format
    
    // Contact info
    /^(phone|tel|mobile|email|fax|website|www)$/i,
    /^(address|city|state|pin|pincode|zip)$/i,
    
    // Payment
    /^(payment|paid|balance|due|credit|debit|cash|upi|neft|rtgs)$/i,
    
    // Thank you messages
    /^(thank|thanks|visit\s*again|please\s*come|have\s*a\s*nice)/i,
    
    // Bill metadata
    /^(bill\s*no|invoice\s*no|ref\s*no|po\s*no|order\s*no)$/i,
    /^(dated|period|month|year|fy)$/i,
];

// Indian unit patterns and their normalized forms
const UNIT_PATTERNS: Array<{ pattern: RegExp; normalized: string }> = [
    { pattern: /\b(kgs?|kilos?|kilograms?)\b/i, normalized: 'kg' },
    { pattern: /\b(gms?|grams?|g\s)\b/i, normalized: 'g' },
    { pattern: /\b(ltrs?|litres?|liters?|l\s)\b/i, normalized: 'L' },
    { pattern: /\b(mls?|millilitres?)\b/i, normalized: 'ml' },
    { pattern: /\b(pcs?|pieces?|pics?)\b/i, normalized: 'pcs' },
    { pattern: /\b(nos?|no\.?|numbers?)\b/i, normalized: 'nos' },
    { pattern: /\b(doz|dozens?)\b/i, normalized: 'dozen' },
    { pattern: /\b(bags?|bora)\b/i, normalized: 'bag' },
    { pattern: /\b(peti|cartons?|ctns?)\b/i, normalized: 'carton' },
    { pattern: /\b(boxes?|bx)\b/i, normalized: 'box' },
    { pattern: /\b(btls?|bottles?)\b/i, normalized: 'btl' },
    { pattern: /\b(strips?|str)\b/i, normalized: 'strip' },
    { pattern: /\b(packets?|pks?|pkt)\b/i, normalized: 'pkt' },
    { pattern: /\b(rolls?|rls?)\b/i, normalized: 'roll' },
    { pattern: /\b(sheets?|shts?)\b/i, normalized: 'sheet' },
    { pattern: /\b(meters?|mtrs?|mt)\b/i, normalized: 'm' },
    { pattern: /\b(feet|ft)\b/i, normalized: 'ft' },
    { pattern: /\b(inches?|ins?)\b/i, normalized: 'in' },
    { pattern: /\b(pairs?|prs?)\b/i, normalized: 'pair' },
    { pattern: /\b(sets?)\b/i, normalized: 'set' },
    { pattern: /\b(bundle|bdl)\b/i, normalized: 'bundle' },
    { pattern: /\b(drum)\b/i, normalized: 'drum' },
    { pattern: /\b(jar)\b/i, normalized: 'jar' },
    { pattern: /\b(tin)\b/i, normalized: 'tin' },
    { pattern: /\b(can)\b/i, normalized: 'can' },
];

// Batch number patterns
const BATCH_PATTERNS = [
    /batch[:\s]+([A-Z0-9\-]+)/i,
    /batch\s*#?\s*[:\s]+([A-Z0-9\-]+)/i,
    /b\.?\s*no\.?[:\s]+([A-Z0-9\-]+)/i,
    /batch\s*number[:\s]+([A-Z0-9\-]+)/i,
];

// Expiry date patterns
const EXPIRY_PATTERNS = [
    /exp[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /exp\.?\s*date[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /expiry[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /best\s*before[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /b\.?\s*b\.?[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /use\s*by[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
];

// MFG date patterns (to exclude from expiry)
const MFG_PATTERNS = [
    /mfg[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /mfg\.?\s*date[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /manufacturing[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
    /made\s*on[:\s]+(\d{1,2}[\/\-]\d{2,4})/i,
];

/**
 * Check if a line should be skipped (header, total, metadata)
 */
function shouldSkipLine(text: string): boolean {
    const trimmed = text.trim();
    
    // Empty or too short
    if (trimmed.length < 3) return true;
    
    // All caps labels (likely headers)
    if (/^[A-Z\s\d\-_]{3,}$/.test(trimmed) && !trimmed.includes(' ')) return true;
    
    // Check against skip patterns
    for (const pattern of SKIP_PATTERNS) {
        if (pattern.test(trimmed)) return true;
    }
    
    // Lines with no alphabetic characters (just numbers/symbols)
    if (!/[a-zA-Z]/.test(trimmed)) return true;
    
    // Lines that are just dates
    if (/^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}$/.test(trimmed)) return true;
    
    return false;
}

/**
 * Extract unit from text and return normalized unit + remaining text
 */
function extractUnit(text: string): { unit: string | null; remainingText: string } {
    for (const { pattern, normalized } of UNIT_PATTERNS) {
        const match = text.match(pattern);
        if (match) {
            // Remove the unit from text
            const remainingText = text.replace(pattern, ' ').replace(/\s+/g, ' ').trim();
            return { unit: normalized, remainingText };
        }
    }
    return { unit: null, remainingText: text };
}

/**
 * Extract HSN code (4 or 8 digit number)
 */
function extractHsnCode(text: string): string | null {
    // Look for 4 or 8 digit standalone numbers
    const hsnMatch = text.match(/\b(\d{4}|\d{8})\b/);
    if (hsnMatch) {
        const num = hsnMatch[1];
        // Verify it's not a price or quantity (shouldn't have decimal or be too large)
        const numVal = parseInt(num, 10);
        if (numVal > 100 && numVal < 99999999) {
            return num;
        }
    }
    return null;
}

/**
 * Extract batch number
 */
function extractBatchNo(text: string): string | null {
    for (const pattern of BATCH_PATTERNS) {
        const match = text.match(pattern);
        if (match && match[1]) {
            return match[1].trim().toUpperCase();
        }
    }
    return null;
}

/**
 * Extract expiry date
 */
function extractExpiryDate(text: string): string | null {
    // First check if it's actually an MFG date
    for (const pattern of MFG_PATTERNS) {
        if (pattern.test(text)) return null;
    }
    
    for (const pattern of EXPIRY_PATTERNS) {
        const match = text.match(pattern);
        if (match && match[1]) {
            return normalizeDate(match[1]);
        }
    }
    return null;
}

/**
 * Normalize date to MM/YY or MM/YYYY format
 */
function normalizeDate(dateStr: string): string {
    const cleaned = dateStr.replace(/[-]/g, '/');
    const parts = cleaned.split('/');
    if (parts.length === 2) {
        const [month, year] = parts;
        // Ensure month is 2 digits
        const normalizedMonth = month.padStart(2, '0');
        // Normalize year to 2 digits
        const normalizedYear = year.length === 4 ? year.slice(2) : year.padStart(2, '0');
        return `${normalizedMonth}/${normalizedYear}`;
    }
    return cleaned;
}

/**
 * Extract numeric values (prices and quantities)
 * Returns: { values: number[], remainingText: string }
 */
function extractNumbers(text: string): { values: number[]; remainingText: string } {
    const values: number[] = [];
    
    // Pattern for Indian currency: optional ₹, commas allowed, optional decimal
    // Matches: 1,234.56, ₹500, 1250, 1,250.00
    const numberPattern = /₹?\s*([\d,]+(?:\.\d{1,2})?)/g;
    let match;
    let remainingText = text;
    
    while ((match = numberPattern.exec(text)) !== null) {
        const numStr = match[1].replace(/,/g, '');
        const num = parseFloat(numStr);
        if (!isNaN(num) && num >= 0) {
            values.push(num);
        }
        // Replace this occurrence in remaining text
        remainingText = remainingText.replace(match[0], ' ');
    }
    
    return { values, remainingText: remainingText.replace(/\s+/g, ' ').trim() };
}

/**
 * Determine quantity and price from extracted numbers
 * Heuristic: rightmost number is usually price, leftmost is usually quantity
 */
function determineQuantityAndPrice(
    values: number[],
    text: string
): { quantity: number | null; unitPrice: number | null; totalPrice: number | null } {
    if (values.length === 0) {
        return { quantity: null, unitPrice: null, totalPrice: null };
    }
    
    if (values.length === 1) {
        // Single number - likely total price
        return { quantity: null, unitPrice: null, totalPrice: values[0] };
    }
    
    if (values.length === 2) {
        // Two numbers - could be quantity + total, or unit price + total
        const [first, second] = values;
        
        // If first is small (likely quantity) and second is larger (likely total)
        if (first <= 100 && second > first) {
            return { quantity: first, unitPrice: null, totalPrice: second };
        }
        
        // If both are similar magnitude, first might be unit price, second total
        if (first > 10 && second > first * 0.8) {
            return { quantity: null, unitPrice: first, totalPrice: second };
        }
        
        // Default: first as quantity, second as total
        return { quantity: first, unitPrice: null, totalPrice: second };
    }
    
    // 3+ numbers - likely: qty, unit price, total (or discount scenarios)
    // Take first reasonable number as qty, middle as unit price, last as total
    let quantity: number | null = null;
    let unitPrice: number | null = null;
    let totalPrice: number | null = null;
    
    // First small number as quantity
    for (let i = 0; i < values.length - 1; i++) {
        if (values[i] <= 1000 && values[i] > 0) {
            quantity = values[i];
            break;
        }
    }
    
    // Last number as total
    totalPrice = values[values.length - 1];
    
    // Try to find unit price (middle value that makes sense)
    if (quantity !== null && quantity > 0) {
        const expectedUnitPrice = totalPrice / quantity;
        // Find closest value to expected unit price
        let closestDiff = Infinity;
        for (let i = 0; i < values.length - 1; i++) {
            const diff = Math.abs(values[i] - expectedUnitPrice);
            if (diff < closestDiff) {
                closestDiff = diff;
                unitPrice = values[i];
            }
        }
    }
    
    return { quantity, unitPrice, totalPrice };
}

/**
 * Extract product name from remaining text after removing numbers and units
 */
function extractProductName(text: string): string {
    // Remove common noise words
    const noiseWords = /\b(batch|exp|mfg|mrp|rate|rs|inr|price|qty|quantity|total|amount)\b/gi;
    let cleaned = text.replace(noiseWords, ' ');
    
    // Remove standalone numbers and special chars
    cleaned = cleaned.replace(/\b\d+\b/g, ' ');
    cleaned = cleaned.replace(/[^\w\s\-]/g, ' ');
    
    // Normalize spaces
    cleaned = cleaned.replace(/\s+/g, ' ').trim();
    
    // Capitalize first letter of each word
    cleaned = cleaned.replace(/\b\w/g, c => c.toUpperCase());
    
    return cleaned || 'Unknown Product';
}

/**
 * Calculate confidence score based on extracted fields
 */
function calculateConfidence(
    productName: string,
    quantity: number | null,
    unitPrice: number | null,
    totalPrice: number | null
): { confidence: 'high' | 'medium' | 'low'; warnings: string[] } {
    const warnings: string[] = [];
    
    const hasName = productName && productName !== 'Unknown Product';
    const hasQty = quantity !== null && quantity > 0;
    const hasPrice = (unitPrice !== null && unitPrice > 0) || (totalPrice !== null && totalPrice > 0);
    
    if (!hasName) {
        warnings.push('Could not extract product name');
    }
    if (!hasQty) {
        warnings.push('Could not extract quantity');
    }
    if (!hasPrice) {
        warnings.push('Could not extract price');
    }
    
    if (hasName && hasQty && hasPrice) {
        return { confidence: 'high', warnings };
    }
    
    if (hasName && (hasQty || hasPrice)) {
        return { confidence: 'medium', warnings };
    }
    
    return { confidence: 'low', warnings };
}

/**
 * Parse a single raw line into a structured line item
 */
export function parseLineItem(rawLine: RawLine): ParsedLineItem {
    const { text, lineIndex, confidence: ocrConfidence } = rawLine;
    const warnings: string[] = [];
    
    // Check if should skip
    if (shouldSkipLine(text)) {
        return {
            rawText: text,
            productName: '',
            quantity: null,
            unit: null,
            unitPrice: null,
            totalPrice: null,
            hsnCode: null,
            batchNo: null,
            expiryDate: null,
            confidence: 'low',
            parseWarnings: ['Skipped: appears to be header or metadata'],
        };
    }
    
    // Extract HSN code
    const hsnCode = extractHsnCode(text);
    
    // Extract batch number
    const batchNo = extractBatchNo(text);
    
    // Extract expiry date
    const expiryDate = extractExpiryDate(text);
    
    // Extract and remove unit
    const { unit, remainingText: textAfterUnit } = extractUnit(text);
    
    // Extract numbers
    const { values, remainingText: textAfterNumbers } = extractNumbers(textAfterUnit);
    
    // Determine quantity and prices
    const { quantity, unitPrice, totalPrice } = determineQuantityAndPrice(values, text);
    
    // Extract product name from remaining text
    const productName = extractProductName(textAfterNumbers);
    
    // Calculate confidence
    const { confidence, warnings: confidenceWarnings } = calculateConfidence(
        productName,
        quantity,
        unitPrice,
        totalPrice
    );
    warnings.push(...confidenceWarnings);
    
    // Add OCR confidence warning if low
    if (ocrConfidence < 60) {
        warnings.push(`Low OCR confidence (${ocrConfidence.toFixed(1)}%)`);
    }
    
    return {
        rawText: text,
        productName,
        quantity,
        unit,
        unitPrice,
        totalPrice,
        hsnCode,
        batchNo,
        expiryDate,
        confidence,
        parseWarnings: warnings,
    };
}

/**
 * Parse multiple raw lines, filtering out skipped lines
 */
export function parseBillLines(rawLines: RawLine[]): ParsedLineItem[] {
    const results: ParsedLineItem[] = [];
    
    for (const rawLine of rawLines) {
        const parsed = parseLineItem(rawLine);
        
        // Skip lines marked as header/metadata
        if (parsed.parseWarnings.some(w => w.includes('Skipped'))) {
            continue;
        }
        
        results.push(parsed);
    }
    
    logger.info('Bill parsing complete', {
        inputLines: rawLines.length,
        outputItems: results.length,
        highConfidence: results.filter(r => r.confidence === 'high').length,
        mediumConfidence: results.filter(r => r.confidence === 'medium').length,
        lowConfidence: results.filter(r => r.confidence === 'low').length,
    });
    
    return results;
}

/**
 * Parse bill text with vertical-specific rules
 */
export function parseBillLinesForVertical(
    rawLines: RawLine[],
    verticalType: string
): ParsedLineItem[] {
    const baseResults = parseBillLines(rawLines);
    
    // Apply vertical-specific adjustments
    switch (verticalType.toLowerCase()) {
        case 'pharmacy':
        case 'medical':
            return applyPharmacyRules(baseResults);
        
        case 'wholesale':
        case 'distribution':
            return applyWholesaleRules(baseResults);
        
        case 'hardware':
            return applyHardwareRules(baseResults);
        
        case 'grocery':
        case 'supermarket':
            return applyGroceryRules(baseResults);
        
        default:
            return baseResults;
    }
}

function applyPharmacyRules(items: ParsedLineItem[]): ParsedLineItem[] {
    return items.map(item => {
        // Pharmacy items typically have batch and expiry
        if (!item.batchNo && !item.expiryDate) {
            item.parseWarnings.push('Missing batch/expiry - required for pharmacy');
        }
        return item;
    });
}

function applyWholesaleRules(items: ParsedLineItem[]): ParsedLineItem[] {
    return items.map(item => {
        // Wholesale often uses larger units
        if (item.unit && ['bag', 'carton', 'box'].includes(item.unit)) {
            // Adjust quantity interpretation if needed
            if (item.quantity && item.quantity < 1) {
                item.parseWarnings.push('Verify quantity - bulk unit detected');
            }
        }
        return item;
    });
}

function applyHardwareRules(items: ParsedLineItem[]): ParsedLineItem[] {
    return items.map(item => {
        // Hardware often uses length-based units
        if (item.unit && ['m', 'ft', 'in'].includes(item.unit)) {
            item.parseWarnings.push('Verify length/measurement units');
        }
        return item;
    });
}

function applyGroceryRules(items: ParsedLineItem[]): ParsedLineItem[] {
    return items.map(item => {
        // Grocery items often have MRP that should be checked
        if (item.unitPrice && item.totalPrice && item.quantity) {
            const calculatedTotal = item.unitPrice * item.quantity;
            if (Math.abs(calculatedTotal - item.totalPrice) > 0.01) {
                item.parseWarnings.push('Price mismatch - verify calculations');
            }
        }
        return item;
    });
}
