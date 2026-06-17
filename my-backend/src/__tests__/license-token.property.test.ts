// ============================================================================
// Property-Based Test — License_Token / Local-Auth JWT Sign & Verify
// ============================================================================
// Feature: offline-license-activation, Property 9: Token sign/verify round trip
//          with the configured TTL
//
// Validates: Requirements 4.1, 5.5, 9.1
//
// Property 9 (design.md): For any token issued by the signing layer — the
// 365-day License_Token over the UNCHANGED LicenseKeyPayload, OR the 12-hour
// local-auth JWT — verifying the token under the corresponding public key
// succeeds, the verified claims equal the issued claims, the difference between
// `exp` and `iat` equals the configured time-to-live, and verification fails
// for any tampered token.
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { generateKeyPairSync } from 'crypto';
import { PlanTier } from '../config/plan-feature-registry';
import type { LicenseKeyPayload } from '../types/license.types';
import type * as LicenseTokenServiceModule from '../services/license-token.service';

// Silence the logger and avoid async logger work racing test teardown
// (mirrors the existing test conventions in this package).
jest.mock('../utils/logger', () => ({
    logger: { debug: jest.fn(), info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

// ── Provide RS256 key material BEFORE the signing service (and its frozen
//    config) are loaded. The config module reads process.env once at import,
//    so the keys must be present in the environment first. None of the static
//    imports above load config/environment, so it is safe to set them here and
//    require the service afterwards. ────────────────────────────────────────
const { publicKey, privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});
process.env.LICENSE_TOKEN_PRIVATE_KEY = privateKey;
process.env.LICENSE_TOKEN_PUBLIC_KEY = publicKey;
// LOCAL_AUTH_* keys intentionally left unset → the service falls back to the
// License_Token key pair, which is sufficient for exercising both helpers.

// eslint-disable-next-line @typescript-eslint/no-var-requires
const {
    signLicenseToken,
    verifyLicenseToken,
    signLocalAuthToken,
    verifyLocalAuthToken,
    LICENSE_TOKEN_TTL_SECONDS,
    LOCAL_AUTH_TTL_SECONDS,
} = require('../services/license-token.service') as typeof LicenseTokenServiceModule;

const NUM_RUNS = 200; // >= 100 generated cases per property

// ── Generators ──────────────────────────────────────────────────────────────

// Realistic ISO timestamp within a sane range (avoids Invalid Date).
const isoDateArb = fc
    .date({
        min: new Date('2020-01-01T00:00:00.000Z'),
        max: new Date('2035-12-31T23:59:59.000Z'),
    })
    .map((d) => d.toISOString());

// The UNCHANGED LicenseKeyPayload — every field is generated within its real
// domain. No field is added, removed, renamed, or retyped (Req 2.2).
const licensePayloadArb: fc.Arbitrary<LicenseKeyPayload> = fc.record({
    tenantId: fc.uuid(),
    plan: fc.constantFrom(
        PlanTier.BASIC,
        PlanTier.PRO,
        PlanTier.PREMIUM,
        PlanTier.ENTERPRISE,
    ),
    allowedBusinessTypes: fc.array(fc.string(), { maxLength: 8 }),
    maxUsers: fc.integer({ min: 1, max: 10000 }),
    maxDevices: fc.integer({ min: 1, max: 3 }),
    features: fc.array(fc.string(), { maxLength: 12 }),
    expiresAt: fc.option(isoDateArb, { nil: null }),
    issuedAt: isoDateArb,
    keyVersion: fc.integer({ min: 1, max: 100 }),
    superAdminOverride: fc.boolean(),
});

// Fingerprint_Hash binding — SHA256 hex is 64 chars, but the signer accepts any
// non-empty, non-whitespace string. Hex strings satisfy that intelligently.
const fingerprintHashArb = fc.hexaString({ minLength: 8, maxLength: 64 });

// Local-auth session claims (Offline_Auth_Service token).
const localAuthClaimsArb: fc.Arbitrary<LicenseTokenServiceModule.LocalAuthClaims> = fc.record({
    userId: fc.string({ minLength: 1, maxLength: 40 }),
    tenantId: fc.string({ minLength: 1, maxLength: 40 }),
    role: fc.constantFrom('owner', 'manager', 'cashier', 'viewer'),
    sessionId: fc.option(fc.string({ maxLength: 32 }), { nil: undefined }),
});

// ── Tamper helper ─────────────────────────────────────────────────────────
// Flip exactly one fully-significant base64url character of the compact JWT.
// We deliberately avoid the two '.' separators and the trailing character of
// each segment (whose unused low bits could let a different character decode to
// the same bytes). Mutating any fully-significant char changes the signed bytes
// or the signature, so RS256 verification must fail.
function tamper(token: string, indexSeed: number, replacementSeed: number): string {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    const [header, payload] = token.split('.');
    const firstDot = header.length;
    const secondDot = header.length + 1 + payload.length;
    const forbidden = new Set<number>([
        firstDot,
        secondDot,
        header.length - 1, // last char of header
        secondDot - 1, // last char of payload
        token.length - 1, // last char of signature
    ]);

    let i = indexSeed % token.length;
    let guard = 0;
    while (forbidden.has(i) && guard < token.length) {
        i = (i + 1) % token.length;
        guard++;
    }

    const original = token[i];
    let replacement = alphabet[replacementSeed % alphabet.length];
    if (replacement === original) {
        replacement = alphabet[(replacementSeed + 1) % alphabet.length];
    }
    return token.slice(0, i) + replacement + token.slice(i + 1);
}

// ── Property 9 ───────────────────────────────────────────────────────────────

describe('Feature: offline-license-activation, Property 9: Token sign/verify round trip with the configured TTL', () => {
    test('License_Token: sign→verify round-trips claims verbatim, exp-iat == 365d, tampered tokens fail (Req 5.5)', () => {
        fc.assert(
            fc.property(
                licensePayloadArb,
                fingerprintHashArb,
                fc.nat(),
                fc.nat(),
                (payload, fingerprintHash, indexSeed, replacementSeed) => {
                    const token = signLicenseToken(payload, fingerprintHash);

                    // (1) Verifying under the public key succeeds and
                    // (2) verified claims equal the issued claims.
                    const verified = verifyLicenseToken(token);
                    expect(verified.tenantId).toBe(payload.tenantId);
                    expect(verified.plan).toBe(payload.plan);
                    expect(verified.allowedBusinessTypes).toEqual(payload.allowedBusinessTypes);
                    expect(verified.maxUsers).toBe(payload.maxUsers);
                    expect(verified.maxDevices).toBe(payload.maxDevices);
                    expect(verified.features).toEqual(payload.features);
                    expect(verified.expiresAt).toEqual(payload.expiresAt);
                    expect(verified.issuedAt).toBe(payload.issuedAt);
                    expect(verified.keyVersion).toBe(payload.keyVersion);
                    expect(verified.superAdminOverride).toBe(payload.superAdminOverride);
                    expect(verified.fingerprintHash).toBe(fingerprintHash);

                    // (3) exp - iat equals the configured TTL (365 days).
                    expect(verified.exp - verified.iat).toBe(LICENSE_TOKEN_TTL_SECONDS);

                    // (4) Any tampered token fails verification.
                    const tampered = tamper(token, indexSeed, replacementSeed);
                    expect(tampered).not.toBe(token);
                    expect(() => verifyLicenseToken(tampered)).toThrow();
                },
            ),
            { numRuns: NUM_RUNS },
        );
    });

    test('Local-auth JWT: sign→verify round-trips claims verbatim, exp-iat == 12h, tampered tokens fail (Req 4.1, 9.1)', () => {
        fc.assert(
            fc.property(
                localAuthClaimsArb,
                fc.nat(),
                fc.nat(),
                (claims, indexSeed, replacementSeed) => {
                    const token = signLocalAuthToken(claims);

                    // (1) + (2): verification succeeds; claims round-trip verbatim.
                    const verified = verifyLocalAuthToken(token);
                    expect(verified.userId).toBe(claims.userId);
                    expect(verified.tenantId).toBe(claims.tenantId);
                    expect(verified.role).toBe(claims.role);
                    if (claims.sessionId !== undefined) {
                        expect(verified.sessionId).toBe(claims.sessionId);
                    }

                    // (3) exp - iat equals the configured TTL (12 hours).
                    expect(verified.exp - verified.iat).toBe(LOCAL_AUTH_TTL_SECONDS);

                    // (4) Any tampered token fails verification.
                    const tampered = tamper(token, indexSeed, replacementSeed);
                    expect(tampered).not.toBe(token);
                    expect(() => verifyLocalAuthToken(tampered)).toThrow();
                },
            ),
            { numRuns: NUM_RUNS },
        );
    });

    // ── Anchored example checks (unit) — concrete, human-readable cases ──────
    test('example: a concrete License_Token round-trips and carries a 365-day TTL', () => {
        const payload: LicenseKeyPayload = {
            tenantId: '11111111-2222-4333-8444-555566667777',
            plan: PlanTier.PRO,
            allowedBusinessTypes: ['grocery', 'pharmacy'],
            maxUsers: 5,
            maxDevices: 2,
            features: ['dashboard', 'reports'],
            expiresAt: null, // lifetime
            issuedAt: '2025-01-01T00:00:00.000Z',
            keyVersion: 1,
            superAdminOverride: false,
        };
        const fingerprintHash = 'a'.repeat(64);

        const token = signLicenseToken(payload, fingerprintHash);
        const verified = verifyLicenseToken(token);

        expect(verified).toMatchObject({ ...payload, fingerprintHash });
        expect(verified.exp - verified.iat).toBe(365 * 24 * 60 * 60);
        expect(() => verifyLicenseToken(`${token}x`)).toThrow();
    });

    test('example: a concrete local-auth JWT round-trips and carries a 12-hour TTL', () => {
        const claims = {
            userId: 'user-123',
            tenantId: 'tenant-abc',
            role: 'cashier',
            sessionId: 'sess-9',
        };

        const token = signLocalAuthToken(claims);
        const verified = verifyLocalAuthToken(token);

        expect(verified.userId).toBe(claims.userId);
        expect(verified.tenantId).toBe(claims.tenantId);
        expect(verified.role).toBe(claims.role);
        expect(verified.sessionId).toBe(claims.sessionId);
        expect(verified.exp - verified.iat).toBe(12 * 60 * 60);
        expect(() => verifyLocalAuthToken(`${token}x`)).toThrow();
    });
});
