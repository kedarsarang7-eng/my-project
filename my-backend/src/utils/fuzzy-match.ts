import { config } from '../config/environment';
// ============================================================================
// Fuzzy Match Utility — Levenshtein + Trigram Similarity
// ============================================================================
// Used by processImportRow to match uploaded product names against existing
// tenant inventory.
//
// Similarity score: 0.0 (no match) → 1.0 (identical)
// Threshold: FUZZY_THRESHOLD = 0.85 (configurable via env FUZZY_THRESHOLD)
//
// Algorithm choice:
//   - Levenshtein distance normalized by max(len(a), len(b)) — O(m*n), fast
//     for product names which are typically ≤ 60 chars.
//   - Trigram overlap as a secondary signal; combined as max(lev, trigram) so
//     either alone can satisfy the threshold (conservative: reduces false negatives).
//
// No external packages — zero cold-start cost.
// ============================================================================

export const FUZZY_THRESHOLD = parseFloat(config.search.fuzzyThreshold.toString() ?? '0.85');

// ── Normalization ────────────────────────────────────────────────────────────

/**
 * Normalize a product name for comparison:
 *   - Lowercase
 *   - Trim whitespace
 *   - Strip diacritics (NFD decompose + remove combining marks)
 *   - Collapse multiple spaces
 *   - Remove common noise tokens: 'brand', 'new', 'pack of', etc.
 */
export function normalizeName(name: string): string {
    return name
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')   // strip combining diacritics
        .toLowerCase()
        .replace(/[^\w\s]/g, ' ')           // replace punctuation with space
        .replace(/\b(pack of|pack|new|box of|box|set of|set|nos|no\.|pcs|pc|kg|gm|ml|ltr|liter)\b/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

// ── Levenshtein Distance ─────────────────────────────────────────────────────

/**
 * Compute the Levenshtein edit distance between two strings.
 * Uses a space-optimized single-row DP approach: O(min(m,n)) space.
 */
export function levenshtein(a: string, b: string): number {
    if (a === b) return 0;
    if (a.length === 0) return b.length;
    if (b.length === 0) return a.length;

    // Keep shorter string as 'a' for memory efficiency
    if (a.length > b.length) [a, b] = [b, a];

    let prev = Array.from({ length: a.length + 1 }, (_, i) => i);
    let curr = new Array<number>(a.length + 1);

    for (let j = 1; j <= b.length; j++) {
        curr[0] = j;
        for (let i = 1; i <= a.length; i++) {
            const cost = a[i - 1] === b[j - 1] ? 0 : 1;
            curr[i] = Math.min(
                prev[i] + 1,       // deletion
                curr[i - 1] + 1,   // insertion
                prev[i - 1] + cost // substitution
            );
        }
        [prev, curr] = [curr, prev];
    }

    return prev[a.length];
}

/**
 * Levenshtein similarity: 1 - (distance / max_length).
 * Returns a value in [0, 1].
 */
export function levenshteinSimilarity(a: string, b: string): number {
    const maxLen = Math.max(a.length, b.length);
    if (maxLen === 0) return 1.0;
    return 1 - levenshtein(a, b) / maxLen;
}

// ── Trigram Similarity ───────────────────────────────────────────────────────

/**
 * Extract all trigrams (3-char substrings) from a string.
 * Pads with spaces: " ab" + "abc" + "bc " for string "abc".
 */
function trigrams(s: string): Set<string> {
    const padded = `  ${s} `;
    const result = new Set<string>();
    for (let i = 0; i < padded.length - 2; i++) {
        result.add(padded.slice(i, i + 3));
    }
    return result;
}

/**
 * Trigram (Jaccard) similarity: |intersection| / |union|.
 * Returns a value in [0, 1].
 */
export function trigramSimilarity(a: string, b: string): number {
    const ta = trigrams(a);
    const tb = trigrams(b);

    let intersection = 0;
    for (const tri of ta) {
        if (tb.has(tri)) intersection++;
    }

    const union = ta.size + tb.size - intersection;
    if (union === 0) return 1.0;
    return intersection / union;
}

// ── Combined Similarity ──────────────────────────────────────────────────────

/**
 * Combined similarity: max(levenshtein, trigram).
 * Either signal alone can satisfy the threshold, reducing false negatives
 * for products with significant re-ordering (e.g. "Red Bull 250ml" vs "250ml Red Bull").
 */
export function combinedSimilarity(a: string, b: string): number {
    const lev = levenshteinSimilarity(a, b);
    const tri = trigramSimilarity(a, b);
    return Math.max(lev, tri);
}

// ── Best Match ───────────────────────────────────────────────────────────────

export interface FuzzyCandidate {
    id: string;
    normalizedName: string;
    vendor?: string;
}

export interface FuzzyMatchResult {
    candidate: FuzzyCandidate;
    score: number;
}

/**
 * Find the best matching candidate from a list using combined similarity.
 * Returns null if no candidate meets FUZZY_THRESHOLD.
 *
 * @param query       Normalized name to search for
 * @param candidates  Pool of existing products (pre-normalized)
 * @param threshold   Override threshold (default: FUZZY_THRESHOLD)
 */
export function findBestMatch(
    query: string,
    candidates: FuzzyCandidate[],
    threshold: number = FUZZY_THRESHOLD,
): FuzzyMatchResult | null {
    let bestScore = 0;
    let bestCandidate: FuzzyCandidate | null = null;

    for (const candidate of candidates) {
        const score = combinedSimilarity(query, candidate.normalizedName);
        if (score > bestScore) {
            bestScore = score;
            bestCandidate = candidate;
        }
    }

    if (bestCandidate && bestScore >= threshold) {
        return { candidate: bestCandidate, score: bestScore };
    }

    return null;
}

/**
 * Vendor + name compound similarity.
 * Combines vendor prefix with product name, then runs combinedSimilarity.
 * Useful for wholesale / auto parts where vendor uniquely disambiguates products.
 *
 * @param queryName      Normalized product name
 * @param queryVendor    Vendor string (may be undefined)
 * @param candidateName  Normalized candidate product name
 * @param candidateVendor Candidate vendor
 */
export function vendorNameSimilarity(
    queryName: string,
    queryVendor: string | undefined,
    candidateName: string,
    candidateVendor: string | undefined,
): number {
    if (!queryVendor || !candidateVendor) {
        // Fall back to name-only match if either vendor is missing
        return combinedSimilarity(queryName, candidateName);
    }

    const qCompound = normalizeName(`${queryVendor} ${queryName}`);
    const cCompound = normalizeName(`${candidateVendor} ${candidateName}`);
    return combinedSimilarity(qCompound, cCompound);
}
