// ============================================================================
// GST Interstate Tax Logic Test Suite
// ============================================================================

import { extractStateCode, isValidStateCode } from '../utils/gstin.utils';
import { createInvoiceSchema } from '../schemas/index';

describe('GSTIN Utils & Validation', () => {
    it('should correctly validate valid Indian state codes', () => {
        expect(isValidStateCode('27')).toBe(true); // Maharashtra
        expect(isValidStateCode('07')).toBe(true); // Delhi
        expect(isValidStateCode('38')).toBe(true); // Ladakh
        expect(isValidStateCode('01')).toBe(true); // J&K
    });

    it('should correctly reject invalid state codes', () => {
        expect(isValidStateCode('00')).toBe(false);
        expect(isValidStateCode('39')).toBe(false);
        expect(isValidStateCode('AA')).toBe(false);
        expect(isValidStateCode('')).toBe(false);
    });

    it('should extract state code from GSTIN correctly', () => {
        expect(extractStateCode('27AAAAA0000A1Z5')).toBe('27');
        expect(extractStateCode('07BBBBB1111B2Z6')).toBe('07');
    });

    it('should return null for invalid or missing GSTINs', () => {
        expect(extractStateCode(null)).toBeNull();
        expect(extractStateCode(undefined)).toBeNull();
        expect(extractStateCode('')).toBeNull();
        expect(extractStateCode('1')).toBeNull(); // Less than 2 chars
        expect(extractStateCode('99CCCCC2222C3Z7')).toBeNull(); // 99 is invalid code
    });
});

describe('Invoice Schema GST Flags', () => {
    it('should accept missing isInterState and isInterStateOverride', () => {
        const input = {
            items: [
                { productId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479', name: 'Test', quantity: 1, unitPriceCents: 100 }
            ],
            paymentMode: 'cash'
        };
        const result = createInvoiceSchema.safeParse(input);
        expect(result.success).toBe(true);
        if (result.success) {
            expect(result.data.isInterState).toBeUndefined();
            expect(result.data.isInterStateOverride).toBeUndefined();
        }
    });

    it('should accept provided isInterState and isInterStateOverride flags', () => {
        const input = {
            isInterState: true,
            isInterStateOverride: true,
            items: [
                { productId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479', name: 'Test', quantity: 1, unitPriceCents: 100 }
            ],
            paymentMode: 'cash'
        };
        const result = createInvoiceSchema.safeParse(input);
        expect(result.success).toBe(true);
        if (result.success) {
            expect(result.data.isInterState).toBe(true);
            expect(result.data.isInterStateOverride).toBe(true);
        }
    });
});
