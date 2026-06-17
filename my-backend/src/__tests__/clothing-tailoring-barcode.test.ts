// ============================================================================
// clothing-tailoring-barcode.test.ts
// Tests for clothing vertical: variant management, tailoring workflow, barcode
// ============================================================================

// ---------------------------------------------------------------------------
// VARIANT SIZE-COLOR MATRIX
// ---------------------------------------------------------------------------

interface VariantMatrix {
    sizes: string[];
    colors: string[];
}

function generateVariantCombinations(matrix: VariantMatrix): Array<{ size: string; color: string }> {
    const combinations: Array<{ size: string; color: string }> = [];
    for (const size of matrix.sizes) {
        for (const color of matrix.colors) {
            combinations.push({ size, color });
        }
    }
    return combinations;
}

function generateSKU(productCode: string, size: string, color: string): string {
    const sizeCode = size.substring(0, 2).toUpperCase();
    const colorCode = color.substring(0, 3).toUpperCase();
    return `${productCode}-${sizeCode}-${colorCode}`;
}

describe('Variant size-color matrix generation', () => {
    it('CLV-01: 3 sizes × 2 colors = 6 variants', () => {
        const combos = generateVariantCombinations({
            sizes: ['S', 'M', 'L'],
            colors: ['Red', 'Blue'],
        });
        expect(combos).toHaveLength(6);
    });

    it('CLV-02: single size × single color = 1 variant', () => {
        const combos = generateVariantCombinations({
            sizes: ['Free'],
            colors: ['Black'],
        });
        expect(combos).toHaveLength(1);
        expect(combos[0]).toEqual({ size: 'Free', color: 'Black' });
    });

    it('CLV-03: empty sizes = 0 variants', () => {
        const combos = generateVariantCombinations({
            sizes: [],
            colors: ['Red'],
        });
        expect(combos).toHaveLength(0);
    });

    it('CLV-04: 5 sizes × 5 colors = 25 variants (DynamoDB batch limit)', () => {
        const sizes = ['XS', 'S', 'M', 'L', 'XL'];
        const colors = ['Red', 'Blue', 'Green', 'Black', 'White'];
        const combos = generateVariantCombinations({ sizes, colors });
        expect(combos).toHaveLength(25);
    });

    it('CLV-05: variant contains correct size and color', () => {
        const combos = generateVariantCombinations({
            sizes: ['M'],
            colors: ['Blue'],
        });
        expect(combos[0].size).toBe('M');
        expect(combos[0].color).toBe('Blue');
    });
});

describe('SKU generation', () => {
    it('CLV-S01: generates correct SKU format', () => {
        expect(generateSKU('SHIRT001', 'Medium', 'Blue')).toBe('SHIRT001-ME-BLU');
    });

    it('CLV-S02: handles short size codes', () => {
        expect(generateSKU('TSH001', 'S', 'Red')).toBe('TSH001-S-RED');
    });

    it('CLV-S03: handles single char color', () => {
        expect(generateSKU('TSH001', 'XL', 'R')).toBe('TSH001-XL-R');
    });
});

// ---------------------------------------------------------------------------
// TAILORING STATUS STATE MACHINE
// ---------------------------------------------------------------------------

type TailoringStatus = 
    | 'measurement_taken' 
    | 'cutting' 
    | 'stitching' 
    | 'finishing' 
    | 'quality_check' 
    | 'ready_for_delivery' 
    | 'delivered' 
    | 'cancelled';

const TAILORING_TRANSITIONS: Record<TailoringStatus, TailoringStatus[]> = {
    measurement_taken:     ['cutting', 'cancelled'],
    cutting:               ['stitching', 'cancelled'],
    stitching:             ['finishing', 'cancelled'],
    finishing:             ['quality_check', 'cancelled'],
    quality_check:         ['ready_for_delivery', 'stitching'], // can reject back to stitching
    ready_for_delivery:    ['delivered'],
    delivered:             [], // terminal
    cancelled:             [], // terminal
};

function canTailoringTransition(from: TailoringStatus, to: TailoringStatus): boolean {
    return TAILORING_TRANSITIONS[from]?.includes(to) ?? false;
}

describe('Tailoring status transitions', () => {
    it('CLT-01: measurement_taken → cutting', () => {
        expect(canTailoringTransition('measurement_taken', 'cutting')).toBe(true);
    });

    it('CLT-02: cutting → stitching', () => {
        expect(canTailoringTransition('cutting', 'stitching')).toBe(true);
    });

    it('CLT-03: stitching → finishing', () => {
        expect(canTailoringTransition('stitching', 'finishing')).toBe(true);
    });

    it('CLT-04: finishing → quality_check', () => {
        expect(canTailoringTransition('finishing', 'quality_check')).toBe(true);
    });

    it('CLT-05: quality_check → ready_for_delivery (pass)', () => {
        expect(canTailoringTransition('quality_check', 'ready_for_delivery')).toBe(true);
    });

    it('CLT-06: quality_check → stitching (reject/rework)', () => {
        expect(canTailoringTransition('quality_check', 'stitching')).toBe(true);
    });

    it('CLT-07: ready_for_delivery → delivered', () => {
        expect(canTailoringTransition('ready_for_delivery', 'delivered')).toBe(true);
    });

    it('CLT-08: any active status → cancelled', () => {
        expect(canTailoringTransition('measurement_taken', 'cancelled')).toBe(true);
        expect(canTailoringTransition('cutting', 'cancelled')).toBe(true);
        expect(canTailoringTransition('stitching', 'cancelled')).toBe(true);
        expect(canTailoringTransition('finishing', 'cancelled')).toBe(true);
    });

    it('CLT-09: delivered is terminal', () => {
        expect(canTailoringTransition('delivered', 'measurement_taken')).toBe(false);
        expect(canTailoringTransition('delivered', 'cancelled')).toBe(false);
    });

    it('CLT-10: cancelled is terminal', () => {
        expect(canTailoringTransition('cancelled', 'measurement_taken')).toBe(false);
    });

    it('CLT-11: cannot skip states (measurement → stitching)', () => {
        expect(canTailoringTransition('measurement_taken', 'stitching')).toBe(false);
    });

    it('CLT-12: cannot go backwards (stitching → cutting)', () => {
        expect(canTailoringTransition('stitching', 'cutting')).toBe(false);
    });
});

// ---------------------------------------------------------------------------
// TAILORING PRIORITY SORTING
// ---------------------------------------------------------------------------

type Priority = 'urgent' | 'high' | 'normal' | 'low';

const PRIORITY_WEIGHT: Record<Priority, number> = {
    urgent: 4,
    high: 3,
    normal: 2,
    low: 1,
};

interface TailoringOrder {
    id: string;
    priority: Priority;
    deliveryDate: string;
}

function sortTailoringQueue(orders: TailoringOrder[]): TailoringOrder[] {
    return [...orders].sort((a, b) => {
        // Primary: priority (higher first)
        const priorityDiff = PRIORITY_WEIGHT[b.priority] - PRIORITY_WEIGHT[a.priority];
        if (priorityDiff !== 0) return priorityDiff;
        
        // Secondary: delivery date (earlier first)
        return a.deliveryDate.localeCompare(b.deliveryDate);
    });
}

describe('Tailoring queue priority sorting', () => {
    it('CLQ-01: urgent before normal', () => {
        const sorted = sortTailoringQueue([
            { id: '1', priority: 'normal', deliveryDate: '2024-01-10' },
            { id: '2', priority: 'urgent', deliveryDate: '2024-01-15' },
        ]);
        expect(sorted[0].id).toBe('2'); // urgent first
    });

    it('CLQ-02: same priority, earlier delivery first', () => {
        const sorted = sortTailoringQueue([
            { id: '1', priority: 'normal', deliveryDate: '2024-01-15' },
            { id: '2', priority: 'normal', deliveryDate: '2024-01-10' },
        ]);
        expect(sorted[0].id).toBe('2'); // earlier date first
    });

    it('CLQ-03: full priority ordering', () => {
        const sorted = sortTailoringQueue([
            { id: '1', priority: 'low', deliveryDate: '2024-01-01' },
            { id: '2', priority: 'urgent', deliveryDate: '2024-01-20' },
            { id: '3', priority: 'high', deliveryDate: '2024-01-05' },
            { id: '4', priority: 'normal', deliveryDate: '2024-01-10' },
        ]);
        expect(sorted.map(s => s.id)).toEqual(['2', '3', '4', '1']);
    });
});

// ---------------------------------------------------------------------------
// BARCODE VALIDATION
// ---------------------------------------------------------------------------

function isValidBarcode(barcode: string): boolean {
    if (!barcode || barcode.length < 8) return false;
    if (barcode.length > 14) return false;
    // Must be numeric for standard barcodes
    return /^\d+$/.test(barcode);
}

function isValidEAN13(barcode: string): boolean {
    if (barcode.length !== 13) return false;
    if (!/^\d+$/.test(barcode)) return false;
    
    // EAN-13 check digit validation
    let sum = 0;
    for (let i = 0; i < 12; i++) {
        const digit = parseInt(barcode[i]);
        sum += (i % 2 === 0) ? digit : digit * 3;
    }
    const checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit === parseInt(barcode[12]);
}

describe('Barcode validation', () => {
    it('CLB-01: valid 13-digit barcode', () => {
        expect(isValidBarcode('1234567890123')).toBe(true);
    });

    it('CLB-02: valid 8-digit barcode', () => {
        expect(isValidBarcode('12345678')).toBe(true);
    });

    it('CLB-03: reject short barcode (<8)', () => {
        expect(isValidBarcode('12345')).toBe(false);
    });

    it('CLB-04: reject too long barcode (>14)', () => {
        expect(isValidBarcode('123456789012345')).toBe(false);
    });

    it('CLB-05: reject non-numeric', () => {
        expect(isValidBarcode('ABC12345678')).toBe(false);
    });

    it('CLB-06: reject empty', () => {
        expect(isValidBarcode('')).toBe(false);
    });
});

describe('EAN-13 check digit validation', () => {
    it('CLB-E01: valid EAN-13 (4006381333931)', () => {
        expect(isValidEAN13('4006381333931')).toBe(true);
    });

    it('CLB-E02: invalid check digit', () => {
        expect(isValidEAN13('4006381333932')).toBe(false);
    });

    it('CLB-E03: wrong length', () => {
        expect(isValidEAN13('400638133393')).toBe(false);
    });

    it('CLB-E04: non-numeric', () => {
        expect(isValidEAN13('400638133393A')).toBe(false);
    });
});
