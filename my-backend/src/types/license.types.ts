// ============================================================================
// License Key Types — JWT Payload & Metadata
// ============================================================================
// Defines the structure of JWT-based license keys used for plan-based
// feature gating. All license validation derives from these types.
// ============================================================================

import { PlanTier } from '../config/plan-feature-registry';

/**
 * JWT License Key Payload — decoded contents of a license key.
 * This is the single source of truth for what a tenant is allowed to do.
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
 * Full license record stored in DynamoDB.
 * Extends the JWT payload with metadata fields.
 */
export interface LicenseKeyRecord extends LicenseKeyPayload {
    /** The license key string (DKX-xxx or DKNX-xxx format) */
    licenseKey: string;

    /** Current status of the license */
    status: 'ACTIVE' | 'ACTIVATED' | 'SUSPENDED' | 'REVOKED' | 'EXPIRED';

    /** Who created this license */
    createdBy: string;

    /** Devices currently activated */
    activatedDevices: string[];

    /** Owner info */
    ownerName?: string | null;
    ownerEmail?: string | null;
    ownerPhone?: string | null;
    businessName?: string | null;
    notes?: string | null;

    /** Timestamps */
    createdAt: string;
    updatedAt: string;
}

/**
 * License audit log entry — immutable record of license events.
 */
export interface LicenseAuditEntry {
    /** Who performed the action */
    actorId: string;
    actorEmail?: string;

    /** What action was performed */
    action: 'generate' | 'activate' | 'revoke' | 'reissue' | 'upgrade' | 'downgrade' | 'extend' | 'suspend' | 'reactivate' | 'transfer';

    /** When the action occurred (ISO timestamp) */
    timestamp: string;

    /** Which tenant was affected */
    tenantId: string;

    /** The license key involved */
    licenseKey: string;

    /** Previous state (for state changes) */
    previousState?: Record<string, unknown>;

    /** New state (for state changes) */
    newState?: Record<string, unknown>;

    /** IP address of the actor */
    ipAddress?: string;

    /** Additional context */
    details?: string;
}

/**
 * Denylist entry — revoked keys that must be rejected on every API call.
 */
export interface DenylistEntry {
    /** The revoked license key */
    licenseKey: string;

    /** When it was revoked */
    revokedAt: string;

    /** Who revoked it */
    revokedBy: string;

    /** Reason for revocation */
    reason: string;

    /** The tenant this key belonged to */
    tenantId: string;
}
