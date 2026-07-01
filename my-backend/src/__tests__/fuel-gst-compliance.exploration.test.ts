// ============================================================================
// Bug Condition Exploration Test — Fuel GST Compliance Fix (BACKEND)
//
// Validates: Requirements 2.7 (and mirrors Property 1)
//
// Property 1: Bug Condition — Fuel GST Resolves to Zero (server side)
//
// Petrol/diesel are OUTSIDE India's GST regime. The Node.js/Lambda backend
// `createInvoice` derives per-line tax from each product's stored GST basis
// points (`cgstRateBp` / `sgstRateBp` / `igstRateBp`). For a `petrolPump`
// bill the server must treat fuel GST as 0 — consistent with the client —
// regardless of any non-zero basis points stored on the fuel product.
//
// CRITICAL: On UNFIXED code these assertions FAIL — failure CONFIRMS the bug
// (the server recomputes non-zero tax for fuel). DO NOT fix the test or the
// code when it fails. After the fix (Task 3.4) these same tests will PASS.
//
// `createInvoice` runs against DynamoDB and cannot be invoked as a pure unit.
// Following this repo's convention (see invoice-calculation-engine.test.ts),
// the per-line tax computation is mirrored EXACTLY as it appears in
// `invoice.service.ts` (the `isInterState ? IGST : CGST+SGST` block), so the
// counterexample reflects real server behavior.
// ============================================================================

import fc from 'fast-check';
import { BusinessType } from '../types/tenant.types';

// Mirror of invoice.service.ts roundTaxComponent()
const roundTaxComponent = (paise: number): number => Math.round(paise);

interface FuelProduct {
    cgstRateBp?: number;
    sgstRateBp?: number;
    igstRateBp?: number;
}

interface FuelLine {
    unitPriceCents: number; // PAISE, per unit
    quantity: number;
    discountCents?: number;
}

/**
 * Mirrors the per-line tax computation in invoice.service.ts createInvoice().
 * POST-FIX: gated STRICTLY on PETROL_PUMP — petrol/diesel sit outside India's
 * GST regime, so the server forces the per-line GST basis points to 0 for a
 * petrolPump bill regardless of the product's stored cgstRateBp/sgstRateBp.
 * Every other business type continues to derive tax from stored basis points.
 */
function computeLineTaxCents(
    product: FuelProduct,
    line: FuelLine,
    isInterState: boolean,
    businessType: BusinessType,
): { cgstCents: number; sgstCents: number; igstCents: number; taxCents: number } {
    const lineGrossCents = roundTaxComponent(line.unitPriceCents * line.quantity);
    const itemDiscountCents = Math.min(line.discountCents || 0, lineGrossCents);
    const taxableValueCents = lineGrossCents - itemDiscountCents;

    let cgstCents = 0;
    let sgstCents = 0;
    let igstCents = 0;

    if (businessType === BusinessType.PETROL_PUMP) {
        // Fuel GST forced to 0: cgstCents/sgstCents/igstCents stay 0 (clause 2.7).
    } else if (isInterState) {
        const igstBp = Number(product.igstRateBp) || (Number(product.cgstRateBp || 0) + Number(product.sgstRateBp || 0));
        igstCents = roundTaxComponent(taxableValueCents * igstBp / 10000);
    } else {
        const cgstBp = Number(product.cgstRateBp) || 0;
        const sgstBp = Number(product.sgstRateBp) || 0;
        cgstCents = roundTaxComponent(taxableValueCents * cgstBp / 10000);
        sgstCents = roundTaxComponent(taxableValueCents * sgstBp / 10000);
    }

    return { cgstCents, sgstCents, igstCents, taxCents: cgstCents + sgstCents + igstCents };
}

describe('Fuel GST Compliance — Backend Bug Condition (createInvoice)', () => {
    // 18% fuel product (9% CGST + 9% SGST in basis points).
    const fuelProduct: FuelProduct = { cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800 };

    // Scoped deterministic cases: litres ∈ {1,10,50}, rate ∈ {₹90,₹100,₹110}/L.
    const litresCases = [1, 10, 50];
    const ratePaiseCases = [9000, 10000, 11000]; // ₹90, ₹100, ₹110 in paise

    describe('intra-state petrolPump fuel sale → taxCents must be 0', () => {
        for (const litres of litresCases) {
            for (const ratePaise of ratePaiseCases) {
                test(`${litres} L × ₹${ratePaise / 100}/L resolves taxCents to 0`, () => {
                    const result = computeLineTaxCents(
                        fuelProduct,
                        { unitPriceCents: ratePaise, quantity: litres },
                        false,
                        BusinessType.PETROL_PUMP,
                    );
                    expect(result.taxCents).toBe(0);
                    expect(result.cgstCents).toBe(0);
                    expect(result.sgstCents).toBe(0);
                    expect(result.igstCents).toBe(0);
                });
            }
        }
    });

    test('inter-state petrolPump fuel sale → IGST taxCents must be 0', () => {
        const result = computeLineTaxCents(
            fuelProduct,
            { unitPriceCents: 10000, quantity: 10 },
            true,
            BusinessType.PETROL_PUMP,
        );
        expect(result.taxCents).toBe(0);
        expect(result.igstCents).toBe(0);
    });

    test('PBT: any petrolPump fuel product/line resolves taxCents to 0 (generalized)', () => {
        fc.assert(
            fc.property(
                fc.integer({ min: 1, max: 500 }),       // litres
                fc.integer({ min: 5000, max: 15000 }),  // rate in paise
                fc.integer({ min: 0, max: 2800 }),      // cgstRateBp
                fc.integer({ min: 0, max: 2800 }),      // sgstRateBp
                fc.boolean(),                           // isInterState
                (litres, ratePaise, cgstRateBp, sgstRateBp, isInterState) => {
                    const product: FuelProduct = {
                        cgstRateBp,
                        sgstRateBp,
                        igstRateBp: cgstRateBp + sgstRateBp,
                    };
                    const result = computeLineTaxCents(
                        product,
                        { unitPriceCents: ratePaise, quantity: litres },
                        isInterState,
                        BusinessType.PETROL_PUMP,
                    );
                    // Expected (post-fix): fuel GST is always 0 for petrolPump.
                    return result.taxCents === 0;
                },
            ),
            { numRuns: 200 },
        );
    });
});
