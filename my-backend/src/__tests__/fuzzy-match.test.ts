/// <reference types="jest" />
// ============================================================================
// Unit tests: src/utils/fuzzy-match.ts
// ============================================================================

import {
    normalizeName,
    levenshteinSimilarity,
    trigramSimilarity,
    combinedSimilarity,
    findBestMatch,
    vendorNameSimilarity,
    FUZZY_THRESHOLD,
} from '../utils/fuzzy-match';
import type { FuzzyCandidate } from '../utils/fuzzy-match';

// ── normalizeName ─────────────────────────────────────────────────────────────

describe('normalizeName', () => {
    it('lowercases and trims', () => {
        expect(normalizeName('  Amoxicillin  ')).toBe('amoxicillin');
    });

    it('removes special characters', () => {
        expect(normalizeName('Paracetamol-500mg (tab)')).toBe('paracetamol 500mg tab');
    });

    it('collapses multiple spaces', () => {
        expect(normalizeName('rice   basmati   1kg')).toBe('rice basmati 1kg');
    });

    it('handles empty string', () => {
        expect(normalizeName('')).toBe('');
    });

    it('handles already normalized input', () => {
        expect(normalizeName('sugar 1kg')).toBe('sugar 1kg');
    });
});

// ── levenshteinSimilarity ────────────────────────────────────────────────────

describe('levenshteinSimilarity', () => {
    it('returns 1.0 for identical strings', () => {
        expect(levenshteinSimilarity('amoxicillin', 'amoxicillin')).toBe(1);
    });

    it('returns 0 for completely different strings', () => {
        const s = levenshteinSimilarity('abc', 'xyz');
        expect(s).toBeLessThan(0.5);
    });

    it('returns high score for one-char typo', () => {
        // "amoxicilin" vs "amoxicillin" — one missing 'l'
        expect(levenshteinSimilarity('amoxicilin', 'amoxicillin')).toBeGreaterThan(0.85);
    });

    it('handles empty strings — both empty = 1', () => {
        expect(levenshteinSimilarity('', '')).toBe(1);
    });

    it('handles one empty string = 0', () => {
        expect(levenshteinSimilarity('abc', '')).toBe(0);
    });
});

// ── trigramSimilarity ────────────────────────────────────────────────────────

describe('trigramSimilarity', () => {
    it('returns 1.0 for identical strings', () => {
        expect(trigramSimilarity('paracetamol', 'paracetamol')).toBe(1);
    });

    it('returns high score for close strings', () => {
        expect(trigramSimilarity('paracetamol', 'paracetamo')).toBeGreaterThan(0.7);
    });

    it('returns low score for different strings', () => {
        expect(trigramSimilarity('sugar', 'cement')).toBeLessThan(0.3);
    });

    it('handles short strings (< 3 chars) gracefully', () => {
        expect(() => trigramSimilarity('ab', 'abc')).not.toThrow();
    });
});

// ── combinedSimilarity ───────────────────────────────────────────────────────

describe('combinedSimilarity', () => {
    it('returns 1.0 for identical strings', () => {
        expect(combinedSimilarity('tata salt 1kg', 'tata salt 1kg')).toBe(1);
    });

    it('is above threshold for minor variant', () => {
        // "aashirvaad atta 5kg" vs "ashirvaad atta 5 kg"
        const score = combinedSimilarity('aashirvaad atta 5kg', 'ashirvaad atta 5 kg');
        expect(score).toBeGreaterThan(FUZZY_THRESHOLD);
    });

    it('is below threshold for different products', () => {
        expect(combinedSimilarity('tata salt 1kg', 'fortune soyabean oil 1l')).toBeLessThan(FUZZY_THRESHOLD);
    });
});

// ── findBestMatch ────────────────────────────────────────────────────────────

describe('findBestMatch', () => {
    const catalog: FuzzyCandidate[] = [
        { id: 'p1', normalizedName: 'amoxicillin 500mg capsule' },
        { id: 'p2', normalizedName: 'paracetamol 500mg tablet' },
        { id: 'p3', normalizedName: 'cetirizine 10mg tablet' },
        { id: 'p4', normalizedName: 'tata salt 1kg' },
    ];

    it('finds exact match with score 1', () => {
        const result = findBestMatch('amoxicillin 500mg capsule', catalog);
        expect(result).not.toBeNull();
        expect(result!.candidate.id).toBe('p1');
        expect(result!.score).toBe(1);
    });

    it('finds near-match with typo', () => {
        // "amoxicilin 500mg capsule" — one missing 'l'
        const result = findBestMatch('amoxicilin 500mg capsule', catalog);
        expect(result).not.toBeNull();
        expect(result!.candidate.id).toBe('p1');
    });

    it('returns null when no match above threshold', () => {
        const result = findBestMatch('completely unrelated product xyz', catalog);
        expect(result).toBeNull();
    });

    it('returns null for empty catalog', () => {
        const result = findBestMatch('anything', []);
        expect(result).toBeNull();
    });

    it('returns the best candidate when multiple are close', () => {
        // Both paracetamol entries are similar but one is identical
        const candidates: FuzzyCandidate[] = [
            { id: 'a', normalizedName: 'paracetamol 500mg tablet' },
            { id: 'b', normalizedName: 'paracetamol 650mg tablet' },
        ];
        const result = findBestMatch('paracetamol 500mg tablet', candidates);
        expect(result!.candidate.id).toBe('a');
    });
});

// ── vendorNameSimilarity ─────────────────────────────────────────────────────

describe('vendorNameSimilarity', () => {
    it('returns high score when both name and vendor match closely', () => {
        const score = vendorNameSimilarity(
            'tata salt 1kg', 'tata',
            'tata salt 1kg', 'tata',
        );
        expect(score).toBeGreaterThanOrEqual(FUZZY_THRESHOLD);
    });

    it('returns lower score when vendor differs', () => {
        const score = vendorNameSimilarity(
            'salt 1kg', 'tata',
            'salt 1kg', 'patanjali',
        );
        // Name matches but vendor differs — compound score should be lower
        expect(score).toBeLessThan(1);
    });

    it('handles undefined vendors gracefully', () => {
        expect(() =>
            vendorNameSimilarity('product a', undefined, 'product a', undefined),
        ).not.toThrow();
    });
});
