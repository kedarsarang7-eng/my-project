// @ts-nocheck
// ============================================================================
// Feature: offline-license-activation, Property 8: Device allowance is
//          range-validated and enforced
// ----------------------------------------------------------------------------
// Validates: Requirements 5.8, 5.9, 5.10
//
// Property 8 (design.md): For any proposed device allowance, the configured
// allowance updates if and only if the value is an integer in [1, 3], otherwise
// the previously configured allowance is retained; and for any license with a
// configured allowance n, activation succeeds for the first n distinct machines
// and is rejected for any additional machine.
//
// This suite proves both halves of the property with fast-check (>=100 runs):
//   • Part A — pure range validation via isValidDeviceAllowance /
//     resolveDeviceAllowance (the single source of truth for Req 5.10 / 5.8).
//   • Part B — activation enforcement via activateOfflineLicense: the first n
//     distinct machines bind successfully, the (n+1)th distinct machine is
//     rejected with DEVICE_ALLOWANCE_EXHAUSTED, and re-activating an already
//     bound machine is idempotent (Req 5.9). The DynamoDB data layer is mocked
//     so no real persistence happens.
// ============================================================================

import fc from 'fast-check';

// -- Mock the data layer so no real DynamoDB / network access happens --------
// A single in-memory license record is the "store". getItem reads it,
// updateItem appends a bound device (faithfully enforcing the list_append
// conditional check the real code relies on), and putItem (audit) is inert.
const licenseRecords = new Map<string, any>();

jest.mock('../config/dynamodb.config', () => ({
    TABLE_NAME: 'test-table',
    Keys: {
        licensePK: (k: string) => `LICENSE#${k}`,
        licenseMetaSK: () => 'META',
        licenseActivationSK: (ts: string) => `ACTIVATION#${ts}`,
        tenantPK: (id: string) => `TENANT#${id}`,
        tenantProfileSK: () => 'PROFILE',
    },
    getItem: jest.fn(async (pk: string, sk: string) => {
        if (typeof pk === 'string' && pk.startsWith('LICENSE#') && sk === 'META') {
            const key = pk.slice('LICENSE#'.length);
            const rec = licenseRecords.get(key);
            if (!rec) return undefined;
            // Return a copy so internal reads cannot mutate the store directly;
            // only updateItem mutates persisted state.
            return { ...rec, activatedDevices: [...(rec.activatedDevices || [])] };
        }
        return undefined;
    }),
    updateItem: jest.fn(async (pk: string, _sk: string, opts: any) => {
        const key = pk.slice('LICENSE#'.length);
        const rec = licenseRecords.get(key);
        if (!rec) return;
        const expr: string = opts?.updateExpression || '';
        const vals: Record<string, any> = opts?.expressionAttributeValues || {};
        if (expr.includes('activatedDevices = list_append')) {
            const current: string[] = Array.isArray(rec.activatedDevices) ? rec.activatedDevices : [];
            const allowance: number = vals[':allowance'];
            // Mirror the real conditionExpression: size(activatedDevices) < :allowance
            if (typeof allowance === 'number' && current.length >= allowance) {
                const err: any = new Error('The conditional request failed');
                err.name = 'ConditionalCheckFailedException';
                throw err;
            }
            const toAdd: string[] = Array.isArray(vals[':dev']) ? vals[':dev'] : [];
            rec.activatedDevices = [...current, ...toAdd];
        }
        if (vals[':now']) rec.updatedAt = vals[':now'];
    }),
    putItem: jest.fn(async () => undefined),
    queryItems: jest.fn(async () => ({ items: [], lastKey: undefined })),
    transactWrite: jest.fn(async () => undefined),
}));

// Denylist is fail-closed in production; for allowance enforcement we keep keys
// clean so the only rejection under test is the device-allowance gate.
jest.mock('../services/license-denylist.service', () => ({
    isKeyDenylisted: jest.fn().mockResolvedValue(false),
}));

// Signing requires RS256 keys that are not present in the test env; stub the
// signing layer so activation reaches its allowance logic without real keys.
jest.mock('../services/license-token.service', () => ({
    LICENSE_TOKEN_TTL_SECONDS: 365 * 24 * 60 * 60,
    signLicenseToken: jest.fn(() => 'signed.license.token'),
}));

// Keep CloudWatch metrics fast and offline.
jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({}),
    })),
    PutMetricDataCommand: jest.fn().mockImplementation((input: unknown) => ({ input })),
}));

import {
    isValidDeviceAllowance,
    resolveDeviceAllowance,
    activateOfflineLicense,
    computeFingerprintHash,
    clearLicenseCache,
    DEFAULT_DEVICE_ALLOWANCE,
    MIN_DEVICE_ALLOWANCE,
    MAX_DEVICE_ALLOWANCE,
} from '../services/license.service';

// Oracle for the range rule (independent re-statement of Req 5.10).
const isAllowanceValidOracle = (v: unknown): boolean =>
    typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= 3;

beforeEach(() => {
    licenseRecords.clear();
    clearLicenseCache();
    jest.clearAllMocks();
});

describe('Feature: offline-license-activation, Property 8: Device allowance is range-validated and enforced', () => {
    // ------------------------------------------------------------------ Part A
    describe('Part A — configuration is range-validated (Req 5.8, 5.10)', () => {
        // A proposed value spanning every interesting shape: in/out-of-range
        // integers, non-integers, NaN/Infinity, negatives, large magnitudes,
        // and non-number types (the parameter is typed `unknown`).
        const proposedArb = fc.oneof(
            fc.integer(),
            fc.integer({ min: 1, max: 3 }),
            fc.integer({ min: -10, max: 10 }),
            fc.double(),
            fc.double({ min: -1e12, max: 1e12 }),
            fc.constantFrom(
                0, 1, 2, 3, 4, -1, 2.5, 1.0001,
                NaN, Infinity, -Infinity,
                Number.MAX_SAFE_INTEGER, Number.MIN_SAFE_INTEGER,
            ),
            fc.string(),
            fc.boolean(),
            fc.constant(null),
            fc.constant(undefined),
        );

        // The previously configured allowance is always a valid stored value.
        const previousArb = fc.integer({ min: MIN_DEVICE_ALLOWANCE, max: MAX_DEVICE_ALLOWANCE });

        it('updates iff the value is an integer in [1,3], else retains the previous allowance', () => {
            fc.assert(
                fc.property(proposedArb, previousArb, (proposed, previous) => {
                    const valid = isValidDeviceAllowance(proposed);
                    // isValidDeviceAllowance agrees with the independent oracle.
                    expect(valid).toBe(isAllowanceValidOracle(proposed));

                    const resolved = resolveDeviceAllowance(proposed, previous);
                    if (valid) {
                        // Accepted: the configured allowance becomes the proposal,
                        // and it is necessarily within range.
                        expect(resolved).toBe(proposed);
                        expect(resolved).toBeGreaterThanOrEqual(MIN_DEVICE_ALLOWANCE);
                        expect(resolved).toBeLessThanOrEqual(MAX_DEVICE_ALLOWANCE);
                    } else {
                        // Rejected: the previously configured allowance is retained.
                        expect(resolved).toBe(previous);
                    }
                }),
                { numRuns: 300 },
            );
        });

        it('falls back to the default allowance of 1 when no previous value is supplied', () => {
            fc.assert(
                fc.property(proposedArb, (proposed) => {
                    const resolved = resolveDeviceAllowance(proposed);
                    expect(resolved).toBe(
                        isValidDeviceAllowance(proposed) ? proposed : DEFAULT_DEVICE_ALLOWANCE,
                    );
                }),
                { numRuns: 300 },
            );
        });
    });

    // ------------------------------------------------------------------ Part B
    describe('Part B — activation enforces the configured allowance (Req 5.9)', () => {
        // A machine fingerprint with non-empty bound components. The selector
        // used by uniqueArray is exactly the Fingerprint_Hash input string, so
        // distinct entries are guaranteed to produce distinct hashes.
        const fingerprintArb = fc.record({
            cpuId: fc.string({ minLength: 1, maxLength: 8 }),
            macAddress: fc.string({ minLength: 1, maxLength: 8 }),
            hddSerial: fc.string({ minLength: 1, maxLength: 8 }),
            osType: fc.constantFrom('windows', 'macos', 'linux'),
            hostname: fc.string({ minLength: 0, maxLength: 12 }),
        });

        // At least 4 distinct machines so there is always an extra machine
        // beyond the maximum allowance of 3 to prove rejection.
        const distinctMachinesArb = fc.uniqueArray(fingerprintArb, {
            minLength: 4,
            maxLength: 8,
            selector: (fp) => `${fp.cpuId}${fp.macAddress}${fp.hddSerial}`,
        });

        const allowanceArb = fc.integer({ min: MIN_DEVICE_ALLOWANCE, max: MAX_DEVICE_ALLOWANCE });

        let keyCounter = 0;

        const seedLicense = (allowance: number): string => {
            const licenseKey = `DKX-PROP-${++keyCounter}`;
            licenseRecords.set(licenseKey, {
                licenseKey,
                tenantId: 'TNX-PROP',
                plan: 'basic',
                status: 'ACTIVE',
                businessType: 'general',
                features: ['core'],
                allowedBusinessTypes: ['general'],
                maxDevices: allowance,
                maxUsers: 10,
                expiryDate: null,
                activatedDevices: [],
                issuedAt: '2024-01-01T00:00:00.000Z',
                createdAt: '2024-01-01T00:00:00.000Z',
                keyVersion: 1,
            });
            return licenseKey;
        };

        const expectThrowsAllowanceExhausted = async (key: string, fp: any) => {
            let thrown: any = null;
            try {
                await activateOfflineLicense(key, fp);
            } catch (err) {
                thrown = err;
            }
            expect(thrown).not.toBeNull();
            expect(thrown.code).toBe('DEVICE_ALLOWANCE_EXHAUSTED');
            expect(thrown.statusCode).toBe(403);
        };

        it('binds the first n distinct machines, rejects the (n+1)th, and is idempotent for bound machines', async () => {
            await fc.assert(
                fc.asyncProperty(allowanceArb, distinctMachinesArb, async (n, machines) => {
                    const licenseKey = seedLicense(n);

                    // 1. The first n distinct machines all activate successfully,
                    //    each incrementing the bound-device count by one.
                    for (let i = 0; i < n; i++) {
                        const result = await activateOfflineLicense(licenseKey, machines[i]);
                        expect(result.success).toBe(true);
                        expect(result.maxDevices).toBe(n);
                        expect(result.activatedDeviceCount).toBe(i + 1);
                        expect(result.fingerprintHash).toBe(computeFingerprintHash(machines[i]));
                    }

                    // After n bindings the store holds exactly n devices.
                    expect(licenseRecords.get(licenseKey).activatedDevices).toHaveLength(n);

                    // 2. The (n+1)th distinct machine is rejected and binds nothing.
                    await expectThrowsAllowanceExhausted(licenseKey, machines[n]);
                    expect(licenseRecords.get(licenseKey).activatedDevices).toHaveLength(n);

                    // 3. Re-activating an already-bound machine is idempotent:
                    //    it succeeds, the count is unchanged, and no new device
                    //    is appended to the store.
                    const reactivate = await activateOfflineLicense(licenseKey, machines[0]);
                    expect(reactivate.success).toBe(true);
                    expect(reactivate.activatedDeviceCount).toBe(n);
                    expect(reactivate.fingerprintHash).toBe(computeFingerprintHash(machines[0]));
                    expect(licenseRecords.get(licenseKey).activatedDevices).toHaveLength(n);

                    // 4. Any further brand-new distinct machine is still rejected.
                    for (let j = n + 1; j < machines.length; j++) {
                        await expectThrowsAllowanceExhausted(licenseKey, machines[j]);
                    }
                    expect(licenseRecords.get(licenseKey).activatedDevices).toHaveLength(n);
                }),
                { numRuns: 150 },
            );
        });
    });

    // ----------------------------------------------------- Concrete unit cases
    describe('concrete examples (Req 5.8, 5.9, 5.10)', () => {
        it('isValidDeviceAllowance accepts only integers 1..3', () => {
            for (const v of [1, 2, 3]) expect(isValidDeviceAllowance(v)).toBe(true);
            for (const v of [0, 4, -1, 2.5, NaN, Infinity, -Infinity, '2', null, undefined, true, {}]) {
                expect(isValidDeviceAllowance(v as unknown)).toBe(false);
            }
        });

        it('resolveDeviceAllowance retains the previous value for out-of-range input', () => {
            expect(resolveDeviceAllowance(2, 1)).toBe(2);
            expect(resolveDeviceAllowance(3, 1)).toBe(3);
            expect(resolveDeviceAllowance(0, 3)).toBe(3);
            expect(resolveDeviceAllowance(4, 2)).toBe(2);
            expect(resolveDeviceAllowance(2.5, 2)).toBe(2);
            expect(resolveDeviceAllowance(5)).toBe(DEFAULT_DEVICE_ALLOWANCE);
        });

        it('enforces an allowance of 2 across three machines', async () => {
            licenseRecords.set('DKX-UNIT-2', {
                licenseKey: 'DKX-UNIT-2',
                tenantId: 'TNX-UNIT',
                plan: 'basic',
                status: 'ACTIVE',
                businessType: 'general',
                features: ['core'],
                allowedBusinessTypes: ['general'],
                maxDevices: 2,
                maxUsers: 10,
                expiryDate: null,
                activatedDevices: [],
                issuedAt: '2024-01-01T00:00:00.000Z',
                createdAt: '2024-01-01T00:00:00.000Z',
                keyVersion: 1,
            });
            const m = (n: number) => ({ cpuId: `cpu${n}`, macAddress: `mac${n}`, hddSerial: `hdd${n}` });

            const r1 = await activateOfflineLicense('DKX-UNIT-2', m(1));
            expect(r1.activatedDeviceCount).toBe(1);
            const r2 = await activateOfflineLicense('DKX-UNIT-2', m(2));
            expect(r2.activatedDeviceCount).toBe(2);

            let thrown: any = null;
            try {
                await activateOfflineLicense('DKX-UNIT-2', m(3));
            } catch (e) {
                thrown = e;
            }
            expect(thrown?.code).toBe('DEVICE_ALLOWANCE_EXHAUSTED');

            // Re-activating machine 1 stays idempotent.
            const again = await activateOfflineLicense('DKX-UNIT-2', m(1));
            expect(again.activatedDeviceCount).toBe(2);
        });
    });
});
