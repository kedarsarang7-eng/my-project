// ============================================================================
// License Contract — mirrors my-backend/src/types/license.types.ts
// ============================================================================
// The offline License_Token wraps the UNCHANGED LicenseKeyPayload (Req 2.2).
// This file re-declares the payload shape so the packaged backend's activation
// and validation route stubs share the exact same field set, types, and names
// as the AWS license subsystem. NO field is added, removed, renamed, or
// retyped relative to the AWS `LicenseKeyPayload`.
//
// The RS256 signing layer that actually produces License_Token values is added
// additively in my-backend during task 3 and is intentionally NOT duplicated
// here — this is a transport-agnostic shape only.
// ============================================================================

/** Plan tiers — mirrors my-backend/src/config/plan-feature-registry.ts. */
export type PlanTier = 'basic' | 'pro' | 'premium' | 'enterprise';

/**
 * JWT License Key Payload — decoded contents of a license key.
 * Field set is identical to the AWS `LicenseKeyPayload`.
 */
export interface LicenseKeyPayload {
    /** UUID — links the key to exactly one tenant */
    tenantId: string;

    /** Plan tier */
    plan: PlanTier;

    /** Subset of all supported business types this license permits */
    allowedBusinessTypes: string[];

    /** Maximum number of users under this license */
    maxUsers: number;

    /** Maximum number of devices that can activate this license */
    maxDevices: number;

    /** Explicit feature flags — overrides plan defaults when present */
    features: string[];

    /** ISO timestamp — when the license expires (null = lifetime) */
    expiresAt: string | null;

    /** ISO timestamp — when the license was issued */
    issuedAt: string;

    /** Key version for rotation support */
    keyVersion: number;

    /** Allows Super Admin to bypass all feature/plan checks */
    superAdminOverride: boolean;
}

/**
 * Claim set of the offline License_Token (Req 5.5). Extends the unchanged
 * payload with the machine binding and standard JWT TTL claims. Declared here
 * so route stubs can type their responses against the eventual signed token.
 */
export interface LicenseTokenClaims extends LicenseKeyPayload {
    /** Machine binding — SHA256(cpuId + macAddress + hddSerial) */
    fingerprintHash: string;
    /** issued-at (epoch seconds) */
    iat: number;
    /** expiry (epoch seconds) — iat + 365 days for the License_Token */
    exp: number;
}
