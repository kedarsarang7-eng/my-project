// ============================================================================
// Variant Detector — Extract size/color/edition tokens from product names
// ============================================================================
// Supported verticals:
//   clothing  → size (XS/S/M/L/XL/XXL/XXXL or numeric 28–50) + color
//   book_store → edition (1st/2nd/3rd/2024/etc.) + author pattern
// Other verticals pass through with no variant tokens.
// ============================================================================

import { VariantSpec, VariantToken } from '../types/import.types';

// ── Clothing: Size tokens ────────────────────────────────────────────────────

const CLOTHING_SIZES_ALPHA = [
    'XXXL', 'XXL', 'XL', 'XS', 'S', 'M', 'L',   // order matters: longest first
    'Free Size', 'Free', 'OS',
];

// Numeric waist/chest sizes: 24–60 (even numbers typical in Indian clothing)
const CLOTHING_SIZE_NUMERIC_RE = /\b([2-5][0-9])\b/;

// ── Clothing: Color tokens ───────────────────────────────────────────────────

const CLOTHING_COLORS = [
    'Red', 'Blue', 'Green', 'Yellow', 'Orange', 'Purple', 'Pink', 'Black',
    'White', 'Grey', 'Gray', 'Brown', 'Beige', 'Maroon', 'Navy', 'Teal',
    'Olive', 'Cream', 'Gold', 'Silver', 'Violet', 'Indigo', 'Cyan', 'Lime',
    'Magenta', 'Turquoise', 'Peach', 'Lavender', 'Khaki', 'Burgundy',
    'Off White', 'Off-White', 'Dark Green', 'Dark Blue', 'Sky Blue', 'Royal Blue',
    'Light Blue', 'Light Pink', 'Dark Red', 'Dark Brown',
];

// ── Book: Edition tokens ─────────────────────────────────────────────────────

// Matches: "1st Edition", "2nd Ed", "3rd Ed.", "2024 Edition", "4th", etc.
const BOOK_EDITION_RE = /\b(\d+(?:st|nd|rd|th)?)\s*(?:edition|ed\.?|revised|reprint)\b/i;

// Matches 4-digit year 1900–2099 as standalone edition indicator
const BOOK_YEAR_RE = /\b(19[0-9]{2}|20[0-9]{2})\b/;

// ── Book: Author tokens ──────────────────────────────────────────────────────
// Pattern: "by <Name>" or "- <Name>" at end of string, 2–4 words
const BOOK_AUTHOR_RE = /(?:by|–|-)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+){1,3})\s*$/;

// ── Helpers ──────────────────────────────────────────────────────────────────

function stripToken(name: string, token: string): string {
    // Remove token and clean up surrounding delimiters and whitespace
    return name
        .replace(new RegExp(`[,\\s-]*${escapeRegex(token)}[,\\s-]*`, 'gi'), ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function escapeRegex(s: string): string {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// ── Clothing Detector ────────────────────────────────────────────────────────

function detectClothingVariants(name: string): VariantSpec {
    const tokens: VariantToken[] = [];
    let remaining = name;

    // 1. Alpha sizes (XXXL → XS, longest first to avoid partial matches)
    for (const size of CLOTHING_SIZES_ALPHA) {
        const re = new RegExp(`\\b${escapeRegex(size)}\\b`, 'i');
        const match = remaining.match(re);
        if (match) {
            tokens.push({ dimension: 'size', value: size.toUpperCase(), rawToken: match[0] });
            remaining = stripToken(remaining, match[0]);
            break; // only one size per product name
        }
    }

    // 2. Numeric sizes (only if no alpha size found)
    if (!tokens.some(t => t.dimension === 'size')) {
        const numMatch = remaining.match(CLOTHING_SIZE_NUMERIC_RE);
        if (numMatch) {
            tokens.push({ dimension: 'size', value: numMatch[1], rawToken: numMatch[0] });
            remaining = stripToken(remaining, numMatch[0]);
        }
    }

    // 3. Colors (longest match first)
    const sortedColors = [...CLOTHING_COLORS].sort((a, b) => b.length - a.length);
    for (const color of sortedColors) {
        const re = new RegExp(`\\b${escapeRegex(color)}\\b`, 'i');
        const match = remaining.match(re);
        if (match) {
            tokens.push({ dimension: 'color', value: color, rawToken: match[0] });
            remaining = stripToken(remaining, match[0]);
            break; // one color per name
        }
    }

    return {
        parentName: remaining.trim(),
        tokens,
        vertical: 'clothing',
    };
}

// ── Bookstore Detector ───────────────────────────────────────────────────────

function detectBookVariants(name: string): VariantSpec {
    const tokens: VariantToken[] = [];
    let remaining = name;

    // 1. Author ("by Author Name" or "- Author Name" at end)
    const authorMatch = remaining.match(BOOK_AUTHOR_RE);
    if (authorMatch) {
        tokens.push({ dimension: 'author', value: authorMatch[1], rawToken: authorMatch[0] });
        remaining = remaining.slice(0, authorMatch.index).trim();
    }

    // 2. Edition ("2nd Edition", "Revised Ed.")
    const editionMatch = remaining.match(BOOK_EDITION_RE);
    if (editionMatch) {
        tokens.push({ dimension: 'edition', value: editionMatch[1], rawToken: editionMatch[0] });
        remaining = stripToken(remaining, editionMatch[0]);
    } else {
        // 3. Year as edition fallback (e.g. "NCERT Physics 2024")
        const yearMatch = remaining.match(BOOK_YEAR_RE);
        if (yearMatch) {
            tokens.push({ dimension: 'edition', value: yearMatch[1], rawToken: yearMatch[0] });
            remaining = stripToken(remaining, yearMatch[0]);
        }
    }

    return {
        parentName: remaining.trim(),
        tokens,
        vertical: 'book_store',
    };
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Detect variant tokens from a product name for the given business vertical.
 * Returns null if the vertical does not support variants or no tokens are found.
 */
export function detectVariants(name: string, vertical: string): VariantSpec | null {
    switch (vertical) {
        case 'clothing': {
            const spec = detectClothingVariants(name);
            return spec.tokens.length > 0 ? spec : null;
        }
        case 'book_store': {
            const spec = detectBookVariants(name);
            return spec.tokens.length > 0 ? spec : null;
        }
        default:
            return null;
    }
}
