// ============================================================================
// Staff Module — PII Crypto & Masking Service unit tests (Task 3.1)
// ----------------------------------------------------------------------------
// Covers the pure masking primitives (Aadhaar → last 4; other IDs/bank/UPI →
// list-view mask) and the fail-closed full-Aadhaar-capture feature flag.
// KMS-backed encrypt/decrypt are integration-tested against AWS elsewhere; here
// we assert the masking contract and the flag default-OFF behaviour.
// _Requirements: 2.3, 2.4, 2.6, 2.8_
// ============================================================================

// The feature-flag service reaches DynamoDB; mock it so flag resolution is
// deterministic and offline. The KMS service opens AWS clients at import time,
// so mock it too — these unit tests exercise the pure masking + flag logic.
jest.mock('../../../../services/kms.service');
jest.mock('../../../../services/feature-flag.service');

import * as featureFlagService from '../../../../services/feature-flag.service';
import {
    mask,
    isFullAadhaarCaptureEnabled,
    assertFullAadhaarCaptureAllowed,
    FULL_AADHAAR_CAPTURE_FLAG,
    PiiFieldKind,
} from '../pii-crypto.service';

const mockedGetFlag = featureFlagService.getFeatureFlag as jest.MockedFunction<
    typeof featureFlagService.getFeatureFlag
>;

describe('pii-crypto.service — mask()', () => {
    describe('Aadhaar (Req 2.3) — reveals only the last 4 digits', () => {
        it('masks all but the last 4 digits of a 12-digit Aadhaar', () => {
            expect(mask('123456789012', 'aadhaar')).toBe('XXXXXXXX9012');
        });

        it('normalises formatting and still reveals the last 4 digits', () => {
            expect(mask('1234 5678 9012', 'aadhaar')).toBe('XXXXXXXX9012');
            expect(mask('1234-5678-9012', 'aadhaar')).toBe('XXXXXXXX9012');
        });

        it('never reveals more than the digits present', () => {
            expect(mask('12', 'aadhaar')).toBe('XX');
        });
    });

    describe('list-view masks (Req 2.4, 2.6) — reveal only last 4 chars', () => {
        const cases: Array<[PiiFieldKind, string, string]> = [
            ['pan', 'ABCDE1234F', 'XXXXXX234F'],
            ['passport', 'M1234567', 'XXXX4567'],
            ['driving_licence', 'DL0420110149646', 'XXXXXXXXXXX9646'],
            ['bank_account', '000123456789', 'XXXXXXXX6789'],
        ];

        it.each(cases)('masks %s to a list-view value', (kind, input, expected) => {
            expect(mask(input, kind)).toBe(expected);
        });

        it('fully masks a value shorter than the reveal length', () => {
            expect(mask('AB', 'pan')).toBe('XX');
            expect(mask('123', 'bank_account')).toBe('XXX');
        });
    });

    describe('UPI (Req 2.6) — keeps the @provider, masks the VPA local part', () => {
        it('masks the local part and preserves the provider', () => {
            expect(mask('john.doe@okhdfc', 'upi')).toBe('XXXXXXXX@okhdfc');
            expect(mask('9876543210@ybl', 'upi')).toBe('XXXXXXXXXX@ybl');
        });

        it('falls back to reveal-last-4 when there is no @', () => {
            expect(mask('abcdef', 'upi')).toBe('XXcdef');
        });
    });

    describe('empty / nullish input', () => {
        it('returns an empty string', () => {
            expect(mask('', 'aadhaar')).toBe('');
            expect(mask(null, 'pan')).toBe('');
            expect(mask(undefined, 'upi')).toBe('');
        });
    });

    it('never contains the full original value for a long input', () => {
        const kinds: PiiFieldKind[] = [
            'aadhaar',
            'pan',
            'passport',
            'driving_licence',
            'bank_account',
            'upi',
        ];
        const value = '123456789012';
        for (const kind of kinds) {
            const masked = mask(value, kind);
            expect(masked).not.toBe(value);
            expect(masked).toContain('X');
        }
    });
});

describe('pii-crypto.service — full Aadhaar capture flag (Req 2.8, fail-closed)', () => {
    afterEach(() => jest.clearAllMocks());

    it('is OFF when the flag does not exist', async () => {
        mockedGetFlag.mockResolvedValue(null);
        await expect(isFullAadhaarCaptureEnabled()).resolves.toBe(false);
        expect(mockedGetFlag).toHaveBeenCalledWith(FULL_AADHAAR_CAPTURE_FLAG);
    });

    it('is OFF when the flag exists but is inactive', async () => {
        mockedGetFlag.mockResolvedValue({
            is_active: false,
            default_value: true,
        } as any);
        await expect(isFullAadhaarCaptureEnabled()).resolves.toBe(false);
    });

    it('is OFF when active but default_value is not explicitly true', async () => {
        mockedGetFlag.mockResolvedValue({
            is_active: true,
            default_value: false,
        } as any);
        await expect(isFullAadhaarCaptureEnabled()).resolves.toBe(false);
    });

    it('is ON only when active AND default_value === true', async () => {
        mockedGetFlag.mockResolvedValue({
            is_active: true,
            default_value: true,
        } as any);
        await expect(isFullAadhaarCaptureEnabled()).resolves.toBe(true);
    });

    it('is OFF (fail-closed) when the lookup throws', async () => {
        mockedGetFlag.mockRejectedValue(new Error('dynamo down'));
        await expect(isFullAadhaarCaptureEnabled()).resolves.toBe(false);
    });

    it('assertFullAadhaarCaptureAllowed throws 403 while the flag is OFF', async () => {
        mockedGetFlag.mockResolvedValue(null);
        await expect(assertFullAadhaarCaptureAllowed()).rejects.toMatchObject({
            statusCode: 403,
            code: 'FULL_AADHAAR_CAPTURE_DISABLED',
        });
    });

    it('assertFullAadhaarCaptureAllowed resolves when the flag is ON', async () => {
        mockedGetFlag.mockResolvedValue({
            is_active: true,
            default_value: true,
        } as any);
        await expect(assertFullAadhaarCaptureAllowed()).resolves.toBeUndefined();
    });
});
