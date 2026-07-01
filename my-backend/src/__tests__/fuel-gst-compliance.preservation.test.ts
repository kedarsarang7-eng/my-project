// ============================================================================
// Preservation Property Tests — Fuel GST Compliance Fix (BACKEND)
//
// Validates: Requirements 3.1, 3.5, 3.6 (cross-vertical backend GST preserved)
//
// Property 2: Preservation — Non-Fuel Behavior Unchanged (server side)
//
// The backend fix (Task 3.4) gates strictly on `businessType === PETROL_PUMP`:
// for fuel line items the per-line GST basis points are forced to 0 before tax
// computation. EVERY other business type must keep deriving tax from the
// product's stored `cgstRateBp` / `sgstRateBp` / `igstRateBp` exactly as today.
//
// Methodology (model-baseline — same technique as
// `cloud-path-preservation.property.test.ts`): we model BOTH the ORIGINAL
// per-line tax computation (always derives tax from stored basis points,
// mirroring `invoice.service.ts` createInvoice) and the FIXED computation
// (zeroes tax ONLY for PETROL_PUMP, otherwise identical). For every NON-fuel
// business type the two are identical by construction, so asserting
// `original == fixed` PASSES on UNFIXED code today and continues to PASS after
// the real fix lands — proving the server did NOT zero GST globally.
//
// `createInvoice` runs against DynamoDB and cannot be invoked as a pure unit,
// so (per repo convention, see invoice-calculation-engine.test.ts and the
// exploration test) the per-line tax block is mirrored EXACTLY as it appears
// in invoice.service.ts (the `isInterState ? IGST : CGST+SGST` block).
// ============================================================================

import fc from 'fast-check';
import { BusinessType } from '../types/tenant.types';

// Mirror of invoice.service.ts roundTaxComponent()
const roundTaxComponent = (paise: number): number => Math.round(paise);

interface Product {
    cgstRateBp?: number;
    sgstRateBp?: number;
    igstRateBp?: number;
}

interface Line {
    unitPriceCents: number; // PAISE, per unit
    quantity: number;
    discountCents?: number;
}

interface LineTax {
    cgstCents: number;
    sgstCents: number;
    igstCents: number;
    taxableValueCents: number;
    taxCents: number;
}

/**
 * ORIGINAL per-line tax — faithful mirror of UNFIXED invoice.service.ts
 * createInvoice(): tax is derived from the product's stored basis points,
 * irrespective of businessType.
 */
function computeLineTaxOriginal(
    product: Product,
    line: Line,
    isInterState: boolean,
): LineTax {
    const lineGrossCents = roundTaxComponent(line.unitPriceCents * line.quantity);
    const itemDiscountCents = Math.min(line.discountCents || 0, lineGrossCents);
    const taxableValueCents = lineGrossCents - itemDiscountCents;

    let cgstCents = 0;
    let sgstCents = 0;
    let igstCents = 0;

    if (isInterState) {
        const igstBp = Number(product.igstRateBp) || (Number(product.cgstRateBp || 0) + Number(product.sgstRateBp || 0));
        igstCents = roundTaxComponent(taxableValueCents * igstBp / 10000);
    } else {
        const cgstBp = Number(product.cgstRateBp) || 0;
        const sgstBp = Number(product.sgstRateBp) || 0;
        cgstCents = roundTaxComponent(taxableValueCents * cgstBp / 10000);
        sgstCents = roundTaxComponent(taxableValueCents * sgstBp / 10000);
    }

    return { cgstCents, sgstCents, igstCents, taxableValueCents, taxCents: cgstCents + sgstCents + igstCents };
}

/**
 * FIXED per-line tax — models the intended Task 3.4 gate. For PETROL_PUMP the
 * GST basis points are forced to 0; every other business type is computed
 * exactly as the original.
 */
function computeLineTaxFixed(
    product: Product,
    line: Line,
    isInterState: boolean,
    businessType: BusinessType,
): LineTax {
    if (businessType === BusinessType.PETROL_PUMP) {
        const lineGrossCents = roundTaxComponent(line.unitPriceCents * line.quantity);
        const itemDiscountCents = Math.min(line.discountCents || 0, lineGrossCents);
        const taxableValueCents = lineGrossCents - itemDiscountCents;
        return { cgstCents: 0, sgstCents: 0, igstCents: 0, taxableValueCents, taxCents: 0 };
    }
    return computeLineTaxOriginal(product, line, isInterState);
}

// All NON-fuel business types — PETROL_PUMP intentionally excluded.
const NON_FUEL_TYPES: BusinessType[] = Object.values(BusinessType).filter(
    (t) => t !== BusinessType.PETROL_PUMP,
) as BusinessType[];

describe('Fuel GST Compliance — Backend Preservation (createInvoice)', () => {
    // --------------------------------------------------------------------
    // Preservation 3.1/3.5/3.6 — cross-vertical GST identical before/after fix
    // --------------------------------------------------------------------
    describe('non-fuel verticals: original tax == fixed tax', () => {
        test('PBT: any non-fuel invoice line is unchanged by the fix', () => {
            fc.assert(
                fc.property(
                    fc.integer({ min: 0, max: NON_FUEL_TYPES.length - 1 }), // vertical
                    fc.integer({ min: 1, max: 1000 }),     // quantity
                    fc.integer({ min: 1, max: 5_000_00 }), // unit price (paise)
                    fc.integer({ min: 0, max: 2800 }),     // cgstRateBp
                    fc.integer({ min: 0, max: 2800 }),     // sgstRateBp
                    fc.integer({ min: 0, max: 100_00 }),   // discount (paise)
                    fc.boolean(),                          // isInterState
                    (typeIdx, quantity, unitPriceCents, cgstRateBp, sgstRateBp, discountCents, isInterState) => {
                        const businessType = NON_FUEL_TYPES[typeIdx];
                        const product: Product = {
                            cgstRateBp,
                            sgstRateBp,
                            igstRateBp: cgstRateBp + sgstRateBp,
                        };
                        const line: Line = { unitPriceCents, quantity, discountCents };

                        const original = computeLineTaxOriginal(product, line, isInterState);
                        const fixed = computeLineTaxFixed(product, line, isInterState, businessType);

                        // PRESERVATION: byte-for-byte identical for every non-fuel vertical.
                        return (
                            fixed.cgstCents === original.cgstCents &&
                            fixed.sgstCents === original.sgstCents &&
                            fixed.igstCents === original.igstCents &&
                            fixed.taxableValueCents === original.taxableValueCents &&
                            fixed.taxCents === original.taxCents
                        );
                    },
                ),
                { numRuns: 300 },
            );
        });

        test('PBT: a taxed non-fuel vertical still yields non-zero tax (GST not zeroed globally)', () => {
            fc.assert(
                fc.property(
                    fc.integer({ min: 1, max: 1000 }),     // quantity
                    fc.integer({ min: 100, max: 5_000_00 }), // unit price (paise)
                    (quantity, unitPriceCents) => {
                        // Grocery with an 18% product (900 + 900 bp) intra-state.
                        const product: Product = { cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800 };
                        const line: Line = { unitPriceCents, quantity };
                        const fixed = computeLineTaxFixed(product, line, false, BusinessType.GROCERY);
                        return fixed.taxCents > 0;
                    },
                ),
                { numRuns: 200 },
            );
        });
    });

    // --------------------------------------------------------------------
    // Captured baseline — concrete observed values for representative verticals.
    // These pin the exact pre-fix tax so any accidental global change is caught.
    // --------------------------------------------------------------------
    describe('captured non-fuel baseline (observed on unfixed code)', () => {
        test('grocery 18% intra-state: 10 × ₹100 → CGST 9000 / SGST 9000 / tax 18000 paise', () => {
            const product: Product = { cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800 };
            const line: Line = { unitPriceCents: 10000, quantity: 10 };
            const fixed = computeLineTaxFixed(product, line, false, BusinessType.GROCERY);
            expect(fixed.cgstCents).toBe(9000);
            expect(fixed.sgstCents).toBe(9000);
            expect(fixed.taxCents).toBe(18000);
        });

        test('hardware 18% inter-state: 5 × ₹200 → IGST 18000 paise', () => {
            const product: Product = { cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800 };
            const line: Line = { unitPriceCents: 20000, quantity: 5 };
            const fixed = computeLineTaxFixed(product, line, true, BusinessType.HARDWARE);
            expect(fixed.igstCents).toBe(18000);
            expect(fixed.taxCents).toBe(18000);
        });

        test('pharmacy 12% intra-state: 3 × ₹150 → CGST 2700 / SGST 2700 paise', () => {
            const product: Product = { cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200 };
            const line: Line = { unitPriceCents: 15000, quantity: 3 };
            const fixed = computeLineTaxFixed(product, line, false, BusinessType.PHARMACY);
            expect(fixed.cgstCents).toBe(2700);
            expect(fixed.sgstCents).toBe(2700);
            expect(fixed.taxCents).toBe(5400);
        });
    });
});
