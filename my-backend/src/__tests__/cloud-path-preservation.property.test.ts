// ============================================================================
// Feature: offline-license-activation, Property 4: Shared cloud/license code
//          preserves baseline outcomes
// ----------------------------------------------------------------------------
// Validates: Requirements 2.1, 2.4
//
// Property 4 (design.md):
//   "For any valid input to shared license or cloud code, the output produced
//    on the cloud path WITH this feature present equals the output of the
//    frozen pre-change baseline reference (identical request contract,
//    response contract, and authentication outcome)."
//
// The offline-license-activation feature adds an additive RS256 signing layer
// (license-token.service.ts) and additive offline-only helpers in
// license.service.ts (activateOfflineLicense / resolveDeviceAllowance /
// isValidDeviceAllowance / computeFingerprintHash). NONE of these may alter the
// behavior of the shared cloud-path functions.
//
// `validateLicenseKey` is the representative SHARED cloud function: it is the
// pre-auth validation the Flutter cloud app calls on first launch AND the
// building block the new offline activation endpoint reuses. If the additive
// offline changes had perturbed it, the cloud path would regress.
//
// This is a MODEL/BASELINE test: `baselineValidateLicenseKey` encodes the frozen
// pre-change contract (response shape + authentication outcome). For arbitrary
// valid inputs we assert the LIVE (feature-present) function produces exactly
// the model's outcome — proving the shared cloud path is unchanged.
//
// The data layer is mocked deterministically so the test pins pure
// contract/auth behavior, not DynamoDB I/O.
// ============================================================================

import fc from 'fast-check';

// -- Deterministic data-layer + AWS mocks ------------------------------------
// validateLicenseKey reads exactly one record via getItem(LICENSE#key, META).
// We control that record per generated case; everything else is a harmless stub.
let currentRecord: Record<string, any> | null = null;
const mockGetItem = jest.fn(async (..._args: any[]) => currentRecord);

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'DukanX-Table',
    Keys: {
        licensePK: (key: string) => `LICENSE#${key}`,
        licenseMetaSK: () => 'META',
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: jest.fn().mockResolvedValue(undefined),
    queryItems: jest.fn().mockResolvedValue({ items: [] }),
    updateItem: jest.fn().mockResolvedValue(undefined),
    transactWrite: jest.fn().mockResolvedValue(undefined),
}));

// CloudWatch is touched on the not-found metric path; keep it offline + silent.
jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({}),
    })),
    PutMetricDataCommand: jest.fn().mockImplementation((input) => ({ input })),
}));

jest.mock('../utils/logger', () => ({
    logger: { debug: jest.fn(), info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

import {
    validateLicenseKey,
    clearLicenseCache,
    LicenseValidationResult,
} from '../services/license.service';
import { AppError } from '../utils/errors';

// ============================================================================
// Frozen baseline reference model
// ----------------------------------------------------------------------------
// This is the pre-change contract of `validateLicenseKey`, transcribed as a
// pure function. It is intentionally INDEPENDENT of the production source so a
// regression in the live code surfaces as a divergence from this model.
// ============================================================================

/** A rejection in the baseline model: the authentication outcome is "denied". */
class BaselineRejection {
    constructor(
        public readonly statusCode: number,
        public readonly code: string,
    ) {}
}

/**
 * Frozen pre-change behavior of validateLicenseKey.
 * Returns the response contract on success, or throws a BaselineRejection
 * describing the authentication-failure outcome.
 */
function baselineValidateLicenseKey(
    record: Record<string, any> | null,
): LicenseValidationResult {
    // Missing license → not found (pre-auth rejection).
    if (!record) {
        throw new BaselineRejection(404, 'KEY_NOT_FOUND');
    }

    const status = (record.status || '').toUpperCase();

    if (status === 'REVOKED') throw new BaselineRejection(403, 'KEY_REVOKED');
    if (status === 'SUSPENDED') throw new BaselineRejection(403, 'KEY_SUSPENDED');
    // Expiry is checked BEFORE the inactive/deactivated gate (order matters).
    if (record.expiryDate && new Date(record.expiryDate).getTime() < Date.now()) {
        throw new BaselineRejection(402, 'LICENSE_EXPIRED');
    }
    if (status === 'INACTIVE' || status === 'DEACTIVATED') {
        throw new BaselineRejection(403, 'KEY_INACTIVE');
    }

    // features: arrays pass through verbatim; absent → plan defaults (excluded
    // from this model's input space — see featuresArb, which always supplies an
    // array so the contract under test stays on the deterministic branch).
    let features: string[] = [];
    if (Array.isArray(record.features)) {
        features = record.features;
    }

    return {
        valid: true,
        businessType: record.businessType || 'general',
        plan: record.plan || 'basic',
        features,
        expiresAt: record.expiryDate ? new Date(record.expiryDate).toISOString() : null,
        maxDevices: record.maxDevices || 5,
        maxUsers: record.maxUsers || 10,
        tenantId: record.tenantId,
    };
}

// ============================================================================
// Smart generators — constrained to the valid input space of validateLicenseKey
// ============================================================================

const planArb = fc.constantFrom('basic', 'pro', 'premium', 'enterprise', undefined);
const businessTypeArb = fc.constantFrom('grocery', 'pharmacy', 'restaurant', 'hardware', 'general', undefined);
// Exercises every status branch, including blank/undefined (treated as ACTIVE-like).
const statusArb = fc.constantFrom(
    'ACTIVE', 'ACTIVATED', 'active', 'Activated',
    'REVOKED', 'SUSPENDED', 'INACTIVE', 'DEACTIVATED',
    '', undefined,
);
// Always an array so we stay on the deterministic (non plan-default) branch.
const featuresArb = fc.array(fc.string({ maxLength: 12 }), { maxLength: 6 });
// null = lifetime; otherwise a clearly-future or clearly-past ISO timestamp
// (>= 1 day away) so the live/model Date.now() skew can never flip the result.
const expiryArb = fc.oneof(
    fc.constant<null>(null),
    fc.integer({ min: 1, max: 3650 }).map((d) => new Date(Date.now() + d * 86_400_000).toISOString()),
    fc.integer({ min: 1, max: 3650 }).map((d) => new Date(Date.now() - d * 86_400_000).toISOString()),
);
const optCountArb = fc.option(fc.integer({ min: 0, max: 500 }), { nil: undefined });
const tenantArb = fc.string({ minLength: 1, maxLength: 24 }).map((s) => `TNX-${s}`);

/** A generated license record, or null to model the not-found path. */
const recordArb = fc.option(
    fc.record({
        status: statusArb,
        plan: planArb,
        businessType: businessTypeArb,
        features: featuresArb,
        expiryDate: expiryArb,
        maxDevices: optCountArb,
        maxUsers: optCountArb,
        tenantId: tenantArb,
    }),
    { nil: null, freq: 6 }, // mostly present records, occasionally not-found
);

// ============================================================================
// Property 4
// ============================================================================

describe('Feature: offline-license-activation, Property 4: Shared cloud/license code preserves baseline outcomes', () => {
    let keyCounter = 0;

    beforeEach(() => {
        jest.clearAllMocks();
        clearLicenseCache();
        currentRecord = null;
    });

    test('validateLicenseKey (shared cloud path) matches the frozen baseline for any valid input [Validates: Requirements 2.1, 2.4]', async () => {
        await fc.assert(
            fc.asyncProperty(recordArb, async (record) => {
                // Isolate each case: unique key + cleared cache so no prior
                // success leaks through the in-memory validation cache.
                clearLicenseCache();
                currentRecord = record;
                const licenseKey = `DKNX-TEST-${keyCounter++}`;

                // --- Live (feature-present) cloud path ---
                let liveResult: LicenseValidationResult | undefined;
                let liveError: unknown;
                try {
                    liveResult = await validateLicenseKey(licenseKey);
                } catch (e) {
                    liveError = e;
                }

                // --- Frozen baseline reference ---
                let modelResult: LicenseValidationResult | undefined;
                let modelRejection: BaselineRejection | undefined;
                try {
                    modelResult = baselineValidateLicenseKey(record);
                } catch (e) {
                    modelRejection = e as BaselineRejection;
                }

                if (modelRejection) {
                    // Authentication outcome must be "denied" with the same
                    // status + error code as the baseline.
                    expect(liveResult).toBeUndefined();
                    expect(liveError).toBeInstanceOf(AppError);
                    expect((liveError as AppError).statusCode).toBe(modelRejection.statusCode);
                    expect((liveError as AppError).code).toBe(modelRejection.code);
                } else {
                    // Authentication outcome must be "granted" and the response
                    // contract must equal the baseline byte-for-byte.
                    expect(liveError).toBeUndefined();
                    expect(liveResult).toEqual(modelResult);
                    // Response contract shape is exactly the documented keys.
                    expect(Object.keys(liveResult!).sort()).toEqual(
                        [
                            'businessType',
                            'expiresAt',
                            'features',
                            'maxDevices',
                            'maxUsers',
                            'plan',
                            'tenantId',
                            'valid',
                        ],
                    );
                }
            }),
            { numRuns: 200 },
        );
    });

    // -- Example-based unit tests for each documented branch (complements PBT) --

    test('valid active license returns the documented defaults', async () => {
        clearLicenseCache();
        currentRecord = { status: 'ACTIVATED', plan: 'pro', businessType: 'grocery', features: ['a'], tenantId: 'TNX-1' };
        const res = await validateLicenseKey('DKNX-EX-1');
        expect(res).toEqual({
            valid: true,
            businessType: 'grocery',
            plan: 'pro',
            features: ['a'],
            expiresAt: null,
            maxDevices: 5,
            maxUsers: 10,
            tenantId: 'TNX-1',
        });
    });

    test('missing license is rejected as 404 KEY_NOT_FOUND', async () => {
        clearLicenseCache();
        currentRecord = null;
        await expect(validateLicenseKey('DKNX-EX-2')).rejects.toMatchObject({ statusCode: 404, code: 'KEY_NOT_FOUND' });
    });

    test('revoked license is rejected as 403 KEY_REVOKED', async () => {
        clearLicenseCache();
        currentRecord = { status: 'REVOKED', plan: 'basic', tenantId: 'TNX-3' };
        await expect(validateLicenseKey('DKNX-EX-3')).rejects.toMatchObject({ statusCode: 403, code: 'KEY_REVOKED' });
    });

    test('suspended license is rejected as 403 KEY_SUSPENDED', async () => {
        clearLicenseCache();
        currentRecord = { status: 'SUSPENDED', plan: 'basic', tenantId: 'TNX-4' };
        await expect(validateLicenseKey('DKNX-EX-4')).rejects.toMatchObject({ statusCode: 403, code: 'KEY_SUSPENDED' });
    });

    test('expired license is rejected as 402 LICENSE_EXPIRED (before the inactive gate)', async () => {
        clearLicenseCache();
        const past = new Date(Date.now() - 86_400_000).toISOString();
        currentRecord = { status: 'INACTIVE', plan: 'basic', expiryDate: past, tenantId: 'TNX-5' };
        await expect(validateLicenseKey('DKNX-EX-5')).rejects.toMatchObject({ statusCode: 402, code: 'LICENSE_EXPIRED' });
    });

    test('inactive license is rejected as 403 KEY_INACTIVE', async () => {
        clearLicenseCache();
        currentRecord = { status: 'INACTIVE', plan: 'basic', tenantId: 'TNX-6' };
        await expect(validateLicenseKey('DKNX-EX-6')).rejects.toMatchObject({ statusCode: 403, code: 'KEY_INACTIVE' });
    });
});
