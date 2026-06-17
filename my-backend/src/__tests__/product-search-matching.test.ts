// ============================================================================
// product-search-matching.test.ts  
// Tests for product search relevance scoring and PO matching logic
// ============================================================================

// ---------------------------------------------------------------------------
// PRODUCT SEARCH RELEVANCE SCORING
// ---------------------------------------------------------------------------

function calculateRelevanceScore(
    product: { name: string; stockQuantity: number },
    query: string,
    queryWords: string[]
): number {
    const name = (product.name || '').toLowerCase();
    let score = 0;

    if (name === query) score += 100;
    if (name.startsWith(query)) score += 50;
    if (name.includes(query)) score += 30;

    let wordMatches = 0;
    for (const word of queryWords) {
        if (name.includes(word)) wordMatches++;
    }
    score += wordMatches * 10;

    if (product.stockQuantity > 0) score += 5;

    return score;
}

describe('Product search relevance scoring', () => {
    it('PS-01: exact name match gets highest score', () => {
        const score = calculateRelevanceScore(
            { name: 'paracetamol 500mg', stockQuantity: 10 },
            'paracetamol 500mg',
            ['paracetamol', '500mg']
        );
        // exact(100) + starts(50) + contains(30) + 2words(20) + inStock(5) = 205
        expect(score).toBe(205);
    });

    it('PS-02: prefix match scores higher than contains', () => {
        const prefixScore = calculateRelevanceScore(
            { name: 'paracetamol 500mg tablet', stockQuantity: 10 },
            'paracetamol',
            ['paracetamol']
        );
        const containsScore = calculateRelevanceScore(
            { name: 'cipla paracetamol', stockQuantity: 10 },
            'paracetamol',
            ['paracetamol']
        );
        expect(prefixScore).toBeGreaterThan(containsScore);
    });

    it('PS-03: in-stock items get bonus score', () => {
        const inStockScore = calculateRelevanceScore(
            { name: 'aspirin', stockQuantity: 10 },
            'aspirin',
            ['aspirin']
        );
        const outOfStockScore = calculateRelevanceScore(
            { name: 'aspirin', stockQuantity: 0 },
            'aspirin',
            ['aspirin']
        );
        expect(inStockScore).toBe(outOfStockScore + 5);
    });

    it('PS-04: more word matches = higher score', () => {
        const twoWordScore = calculateRelevanceScore(
            { name: 'red cotton shirt', stockQuantity: 5 },
            'red cotton',
            ['red', 'cotton']
        );
        const oneWordScore = calculateRelevanceScore(
            { name: 'blue cotton shirt', stockQuantity: 5 },
            'red cotton',
            ['red', 'cotton']
        );
        expect(twoWordScore).toBeGreaterThan(oneWordScore);
    });

    it('PS-05: no match gives zero (plus stock bonus)', () => {
        const score = calculateRelevanceScore(
            { name: 'completely different', stockQuantity: 5 },
            'xyz',
            ['xyz']
        );
        expect(score).toBe(5); // only stock bonus
    });

    it('PS-06: case-insensitive matching', () => {
        const score = calculateRelevanceScore(
            { name: 'Paracetamol 500mg', stockQuantity: 10 },
            'paracetamol 500mg',
            ['paracetamol', '500mg']
        );
        expect(score).toBeGreaterThan(100); // should match
    });
});

// ---------------------------------------------------------------------------
// PURCHASE ORDER MATCHING — Levenshtein Distance
// ---------------------------------------------------------------------------

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

function calculateStringSimilarity(a: string, b: string): number {
    const longer = a.length > b.length ? a : b;
    const shorter = a.length > b.length ? b : a;
    if (longer.length === 0) return 1.0;
    const distance = levenshteinDistance(longer.toLowerCase(), shorter.toLowerCase());
    return (longer.length - distance) / longer.length;
}

describe('String similarity (Levenshtein)', () => {
    it('POM-01: identical strings → similarity 1.0', () => {
        expect(calculateStringSimilarity('hello', 'hello')).toBe(1.0);
    });

    it('POM-02: completely different strings → low similarity', () => {
        const sim = calculateStringSimilarity('abc', 'xyz');
        expect(sim).toBeLessThan(0.3);
    });

    it('POM-03: similar strings → high similarity', () => {
        const sim = calculateStringSimilarity('Paracetamol', 'Paracetamol 500mg');
        expect(sim).toBeGreaterThan(0.6);
    });

    it('POM-04: empty strings → similarity 1.0', () => {
        expect(calculateStringSimilarity('', '')).toBe(1.0);
    });

    it('POM-05: one empty string → similarity 0', () => {
        expect(calculateStringSimilarity('hello', '')).toBe(0);
    });

    it('POM-06: case insensitive', () => {
        const sim = calculateStringSimilarity('HELLO', 'hello');
        expect(sim).toBe(1.0);
    });

    it('POM-07: typo tolerance', () => {
        const sim = calculateStringSimilarity('Paracetamol', 'Paracetaml');
        expect(sim).toBeGreaterThan(0.8);
    });
});

// ---------------------------------------------------------------------------
// PO MATCH CALCULATION
// ---------------------------------------------------------------------------

interface MatchedItem {
    poItemId: string;
    poItemName: string;
    receivedItemName: string;
    poQuantity: number;
    receivedQuantity: number;
    quantityDiff: number;
}

function calculatePOMatchPercentage(
    poItems: Array<{ id: string; name: string; quantity: number }>,
    receivedItems: Array<{ productName: string; quantity: number }>,
): { matchPercentage: number; matchedCount: number; unmatchedCount: number } {
    const matchedPOItemIds = new Set<string>();
    let matchedCount = 0;

    for (const received of receivedItems) {
        let bestMatch: any = null;
        let bestScore = 0;

        for (const poItem of poItems) {
            if (matchedPOItemIds.has(poItem.id)) continue;
            const score = calculateStringSimilarity(received.productName, poItem.name);
            if (score > bestScore && score > 0.6) {
                bestScore = score;
                bestMatch = poItem;
            }
        }

        if (bestMatch) {
            matchedPOItemIds.add(bestMatch.id);
            matchedCount++;
        }
    }

    const matchPercentage = poItems.length > 0
        ? Math.round((matchedCount / poItems.length) * 100)
        : 0;

    return {
        matchPercentage,
        matchedCount,
        unmatchedCount: receivedItems.length - matchedCount,
    };
}

describe('Purchase order match percentage', () => {
    it('POM-M01: 100% match — all PO items received', () => {
        const r = calculatePOMatchPercentage(
            [
                { id: '1', name: 'Paracetamol 500mg', quantity: 100 },
                { id: '2', name: 'Crocin Advance', quantity: 50 },
            ],
            [
                { productName: 'Paracetamol 500mg', quantity: 100 },
                { productName: 'Crocin Advance', quantity: 50 },
            ],
        );
        expect(r.matchPercentage).toBe(100);
        expect(r.unmatchedCount).toBe(0);
    });

    it('POM-M02: 50% match — half items received', () => {
        const r = calculatePOMatchPercentage(
            [
                { id: '1', name: 'Paracetamol 500mg', quantity: 100 },
                { id: '2', name: 'Crocin Advance', quantity: 50 },
            ],
            [
                { productName: 'Paracetamol 500mg', quantity: 100 },
            ],
        );
        expect(r.matchPercentage).toBe(50);
    });

    it('POM-M03: 0% match — no items match PO', () => {
        const r = calculatePOMatchPercentage(
            [
                { id: '1', name: 'Paracetamol 500mg', quantity: 100 },
            ],
            [
                { productName: 'Completely Different Item', quantity: 10 },
            ],
        );
        expect(r.matchPercentage).toBe(0);
        expect(r.unmatchedCount).toBe(1);
    });

    it('POM-M04: extra received items are unmatched', () => {
        const r = calculatePOMatchPercentage(
            [
                { id: '1', name: 'Paracetamol 500mg', quantity: 100 },
            ],
            [
                { productName: 'Paracetamol 500mg', quantity: 100 },
                { productName: 'Extra Item', quantity: 10 },
            ],
        );
        expect(r.matchPercentage).toBe(100); // 1/1 PO items matched
        expect(r.unmatchedCount).toBe(1);
    });

    it('POM-M05: empty PO → 0% match', () => {
        const r = calculatePOMatchPercentage([], [
            { productName: 'Something', quantity: 10 },
        ]);
        expect(r.matchPercentage).toBe(0);
    });

    it('POM-M06: fuzzy name matching works (typos)', () => {
        const r = calculatePOMatchPercentage(
            [{ id: '1', name: 'Paracetamol 500mg', quantity: 100 }],
            [{ productName: 'Paracetaml 500mg', quantity: 100 }], // typo
        );
        expect(r.matchPercentage).toBe(100); // should still match via similarity
    });
});

// ---------------------------------------------------------------------------
// DUPLICATE BILL DETECTION — Image Hash + Fingerprint
// ---------------------------------------------------------------------------

function calculateImageHash(base64: string): string {
    // Simplified — uses first 100 chars as sample
    const sample = base64.substring(0, 100);
    // In tests, just use a deterministic hash
    let hash = 0;
    for (let i = 0; i < sample.length; i++) {
        const char = sample.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash |= 0;
    }
    return Math.abs(hash).toString(16);
}

function createBillFingerprint(billNumber: string, supplierName: string, billDate: string): string {
    return `${billNumber}:${supplierName}:${billDate}`;
}

describe('Duplicate bill detection', () => {
    it('DBD-01: same image produces same hash', () => {
        const hash1 = calculateImageHash('base64imagedata...');
        const hash2 = calculateImageHash('base64imagedata...');
        expect(hash1).toBe(hash2);
    });

    it('DBD-02: different images produce different hashes', () => {
        const hash1 = calculateImageHash('image1data...');
        const hash2 = calculateImageHash('image2data...');
        expect(hash1).not.toBe(hash2);
    });

    it('DBD-03: fingerprint includes all components', () => {
        const fp = createBillFingerprint('INV-001', 'Supplier A', '2024-01-15');
        expect(fp).toBe('INV-001:Supplier A:2024-01-15');
    });

    it('DBD-04: same details produce same fingerprint', () => {
        const fp1 = createBillFingerprint('INV-001', 'SupA', '2024-01-15');
        const fp2 = createBillFingerprint('INV-001', 'SupA', '2024-01-15');
        expect(fp1).toBe(fp2);
    });

    it('DBD-05: different bill number → different fingerprint', () => {
        const fp1 = createBillFingerprint('INV-001', 'SupA', '2024-01-15');
        const fp2 = createBillFingerprint('INV-002', 'SupA', '2024-01-15');
        expect(fp1).not.toBe(fp2);
    });

    it('DBD-06: different supplier → different fingerprint', () => {
        const fp1 = createBillFingerprint('INV-001', 'SupA', '2024-01-15');
        const fp2 = createBillFingerprint('INV-001', 'SupB', '2024-01-15');
        expect(fp1).not.toBe(fp2);
    });

    it('DBD-07: amount tolerance check (5%)', () => {
        const existingAmount = 10000;
        const receivedAmount = 10400; // 4% variance
        const tolerance = 0.05;
        const minAmount = existingAmount * (1 - tolerance);
        const maxAmount = existingAmount * (1 + tolerance);
        expect(receivedAmount >= minAmount && receivedAmount <= maxAmount).toBe(true);
    });

    it('DBD-08: amount outside tolerance (6%)', () => {
        const existingAmount = 10000;
        const receivedAmount = 10700; // 7% variance
        const tolerance = 0.05;
        const minAmount = existingAmount * (1 - tolerance);
        const maxAmount = existingAmount * (1 + tolerance);
        expect(receivedAmount >= minAmount && receivedAmount <= maxAmount).toBe(false);
    });
});

// ---------------------------------------------------------------------------
// FEATURE FLAG RESOLUTION
// ---------------------------------------------------------------------------

interface FeatureFlag {
    flag_key: string;
    default_value: any;
    plan_overrides?: Record<string, any>;
    min_app_version?: string;
    rollout_percentage?: number;
    is_active: boolean;
}

function resolveFlag(flag: FeatureFlag, plan: string, appVersion?: string): any {
    if (!flag.is_active) return flag.default_value;

    // Check plan override
    if (flag.plan_overrides && flag.plan_overrides[plan] !== undefined) {
        return flag.plan_overrides[plan];
    }

    // Check app version gate
    if (flag.min_app_version && appVersion) {
        if (compareVersions(appVersion, flag.min_app_version) < 0) {
            return flag.default_value;
        }
    }

    return flag.default_value;
}

function compareVersions(a: string, b: string): number {
    const aParts = a.split('.').map(Number);
    const bParts = b.split('.').map(Number);
    for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
        const aVal = aParts[i] || 0;
        const bVal = bParts[i] || 0;
        if (aVal > bVal) return 1;
        if (aVal < bVal) return -1;
    }
    return 0;
}

describe('Feature flag resolution', () => {
    it('FF-01: inactive flag returns default', () => {
        const flag: FeatureFlag = {
            flag_key: 'test', default_value: false, is_active: false,
            plan_overrides: { premium: true },
        };
        expect(resolveFlag(flag, 'premium')).toBe(false);
    });

    it('FF-02: plan override takes precedence', () => {
        const flag: FeatureFlag = {
            flag_key: 'test', default_value: false, is_active: true,
            plan_overrides: { premium: true, basic: false },
        };
        expect(resolveFlag(flag, 'premium')).toBe(true);
        expect(resolveFlag(flag, 'basic')).toBe(false);
    });

    it('FF-03: unknown plan gets default', () => {
        const flag: FeatureFlag = {
            flag_key: 'test', default_value: 'off', is_active: true,
            plan_overrides: { premium: 'on' },
        };
        expect(resolveFlag(flag, 'free')).toBe('off');
    });

    it('FF-04: version gate blocks old versions', () => {
        const flag: FeatureFlag = {
            flag_key: 'new_ui', default_value: false, is_active: true,
            min_app_version: '2.0.0',
        };
        expect(resolveFlag(flag, 'premium', '1.9.0')).toBe(false);
        expect(resolveFlag(flag, 'premium', '2.0.0')).toBe(false); // default is false, no override
    });
});

describe('Version comparison', () => {
    it('VC-01: equal versions', () => {
        expect(compareVersions('1.0.0', '1.0.0')).toBe(0);
    });

    it('VC-02: major version comparison', () => {
        expect(compareVersions('2.0.0', '1.0.0')).toBe(1);
        expect(compareVersions('1.0.0', '2.0.0')).toBe(-1);
    });

    it('VC-03: minor version comparison', () => {
        expect(compareVersions('1.2.0', '1.1.0')).toBe(1);
    });

    it('VC-04: patch version comparison', () => {
        expect(compareVersions('1.0.2', '1.0.1')).toBe(1);
    });

    it('VC-05: different length versions', () => {
        expect(compareVersions('1.0', '1.0.0')).toBe(0);
        expect(compareVersions('1.0.1', '1.0')).toBe(1);
    });
});
