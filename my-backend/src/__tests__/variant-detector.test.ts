/// <reference types="jest" />
// ============================================================================
// Unit tests: src/utils/variant-detector.ts
// ============================================================================

import { detectVariants } from '../utils/variant-detector';

// ── Clothing vertical ────────────────────────────────────────────────────────

describe('detectVariants — clothing', () => {
    it('detects alpha size L', () => {
        const spec = detectVariants('Levi Jeans L Blue', 'clothing');
        expect(spec).not.toBeNull();
        const sizeToken = spec!.tokens.find(t => t.dimension === 'size');
        expect(sizeToken?.value).toBe('L');
    });

    it('detects alpha size XL (not confused with L)', () => {
        const spec = detectVariants('Cotton Shirt XL White', 'clothing');
        expect(spec).not.toBeNull();
        const sizeToken = spec!.tokens.find(t => t.dimension === 'size');
        expect(sizeToken?.value).toBe('XL');
    });

    it('detects XXXL correctly (longest prefix wins)', () => {
        const spec = detectVariants('T-Shirt XXXL Red', 'clothing');
        const sizeToken = spec!.tokens.find(t => t.dimension === 'size');
        expect(sizeToken?.value).toBe('XXXL');
    });

    it('detects numeric size 32', () => {
        const spec = detectVariants('Levi 501 Jeans 32 Blue', 'clothing');
        expect(spec).not.toBeNull();
        const sizeToken = spec!.tokens.find(t => t.dimension === 'size');
        expect(sizeToken?.value).toBe('32');
    });

    it('detects color Red', () => {
        const spec = detectVariants('Polo T-Shirt M Red', 'clothing');
        const colorToken = spec!.tokens.find(t => t.dimension === 'color');
        expect(colorToken?.value).toBe('Red');
    });

    it('detects multi-word color "Royal Blue"', () => {
        // Use a name without an alpha-size token so L is not consumed first
        const spec = detectVariants('Formal Shirt 38 Royal Blue', 'clothing');
        const colorToken = spec?.tokens.find(t => t.dimension === 'color');
        // Royal Blue is a multi-word color — it should be detected
        expect(colorToken?.value).toBe('Royal Blue');
    });

    it('strips size and color from parentName', () => {
        const spec = detectVariants('Cotton T-Shirt M White', 'clothing');
        expect(spec!.parentName).not.toContain('M');
        expect(spec!.parentName).not.toContain('White');
    });

    it('returns null when no clothing tokens found', () => {
        const spec = detectVariants('Plain Product No Variants', 'clothing');
        expect(spec).toBeNull();
    });
});

// ── Book_store vertical ───────────────────────────────────────────────────────

describe('detectVariants — book_store', () => {
    it('detects ordinal edition "2nd Edition"', () => {
        const spec = detectVariants('Operating System Concepts 2nd Edition', 'book_store');
        expect(spec).not.toBeNull();
        const edToken = spec!.tokens.find(t => t.dimension === 'edition');
        expect(edToken?.value).toBe('2nd');
    });

    it('detects year-as-edition "NCERT Physics 2024"', () => {
        const spec = detectVariants('NCERT Physics 2024', 'book_store');
        expect(spec).not.toBeNull();
        const edToken = spec!.tokens.find(t => t.dimension === 'edition');
        expect(edToken?.value).toBe('2024');
    });

    it('detects author pattern with standard name', () => {
        // Author regex matches "by FirstName LastName" (2+ capitalized words, no dots)
        const spec = detectVariants('Engineering Thermodynamics by Robert Rajput', 'book_store');
        expect(spec).not.toBeNull();
        const authorToken = spec!.tokens.find(t => t.dimension === 'author');
        expect(authorToken?.value).toBe('Robert Rajput');
    });

    it('returns null when no book tokens found', () => {
        const spec = detectVariants('A Generic Book Title', 'book_store');
        expect(spec).toBeNull();
    });
});

// ── Unsupported verticals ────────────────────────────────────────────────────

describe('detectVariants — unsupported verticals', () => {
    it('returns null for grocery', () => {
        expect(detectVariants('Tata Salt 1kg', 'grocery')).toBeNull();
    });

    it('returns null for pharmacy', () => {
        expect(detectVariants('Amoxicillin 500mg', 'pharmacy')).toBeNull();
    });

    it('returns null for unknown vertical', () => {
        expect(detectVariants('Some Product XL Red', 'unknown_vertical')).toBeNull();
    });

    it('handles empty string without throwing', () => {
        expect(() => detectVariants('', 'clothing')).not.toThrow();
    });
});
