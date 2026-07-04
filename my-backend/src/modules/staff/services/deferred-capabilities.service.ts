// ============================================================================
// Staff Module — Deferred Capabilities Service (Task 14.1)
// ============================================================================
// Typed interfaces behind OFF feature flags for capabilities deferred to
// Phase 11 (AD-7). Each interface:
//   1. Is typed so consumers can code against a stable contract.
//   2. Is gated by an OFF feature flag using the SAME mechanism as
//      pii-crypto.service.ts and attendance.service.ts.
//   3. Returns a not-available/flagged-off response when invoked.
//   4. NEVER fabricates, simulates, or returns placeholder data (Req 15.5).
//
// ALREADY IMPLEMENTED ELSEWHERE (not duplicated here):
//   • Face/Biometric attendance → attendance.service.ts (task 5.1)
//   • Full Aadhaar capture     → pii-crypto.service.ts (task 3.1)
//
// THIS FILE ADDS THE REMAINING deferred interfaces:
//   • SMS notification adapter for staff module (Req 8.6, 15.4)
//   • ML/predictive capabilities (Req 9.2, 15.2)
//   • Gamification (XP, badges, leaderboards) (Req 15.1)
//
// Requirements: 15.1, 15.2, 15.3, 15.4, 15.5.
// ============================================================================

import * as featureFlagService from '../../../services/feature-flag.service';
import { logger } from '../../../utils/logger';

// ────────────────────────────────────────────────────────────────────────────
// Common types
// ────────────────────────────────────────────────────────────────────────────

/**
 * Standard response returned by every deferred capability when invoked while
 * the flag is OFF. Consumers can pattern-match on `available: false` to show
 * appropriate UI (e.g. "Coming soon in Phase 11") without mistaking a
 * not-available response for real data.
 */
export interface DeferredCapabilityUnavailableResult {
    /** Always false — the capability is not available. */
    available: false;
    /** Machine-readable reason code. */
    reason: 'FLAGGED_OFF' | 'DEFERRED_PHASE_11';
    /** The feature flag key governing this capability. */
    flagKey: string;
    /** Human-readable explanation. */
    message: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Helper: resolve a feature flag with fail-closed semantics
// ────────────────────────────────────────────────────────────────────────────

/**
 * Resolve whether a deferred-capability feature flag is enabled.
 * FAIL-CLOSED: returns `false` unless the flag exists, is active, and has an
 * explicit `true` default value. On any lookup error, returns `false`.
 */
async function isDeferredFlagEnabled(flagKey: string): Promise<boolean> {
    try {
        const flag = await featureFlagService.getFeatureFlag(flagKey);
        if (!flag || !flag.is_active) {
            return false;
        }
        return flag.default_value === true;
    } catch (err) {
        logger.warn('Deferred capability flag lookup failed; defaulting OFF', {
            flagKey,
            error: (err as Error).message,
        });
        return false;
    }
}

/**
 * Build the standard unavailable result for a deferred capability.
 */
function buildUnavailableResult(
    flagKey: string,
    capabilityName: string,
): DeferredCapabilityUnavailableResult {
    return {
        available: false,
        reason: 'DEFERRED_PHASE_11',
        flagKey,
        message: `${capabilityName} is not available (deferred to Phase 11)`,
    };
}

// ════════════════════════════════════════════════════════════════════════════
// 1. SMS Notification Adapter (Req 8.6, 15.4)
// ════════════════════════════════════════════════════════════════════════════
// The platform already has a general SMS channel adapter
// (notifications/channels/sms.ts). This interface is specifically for the
// STAFF module's SMS notification capability — sending staff-specific SMS
// messages (leave approvals, roster notifications, payslip alerts). The real
// SMS provider integration for staff is deferred to Phase 11.

/** Feature flag key controlling staff SMS notifications. Stays OFF. */
export const STAFF_SMS_NOTIFICATION_FLAG = 'staff_sms_notifications';

/**
 * Input for sending a staff-related SMS notification.
 * Typed so future implementers have a stable contract.
 */
export interface StaffSmsNotificationInput {
    /** Recipient employee ID. */
    employeeId: string;
    /** Recipient phone number (E.164 format). */
    phoneNumber: string;
    /** Notification template identifier. */
    templateId: string;
    /** Template variables to interpolate. */
    templateVars?: Record<string, string>;
    /** Business context for tenant scoping. */
    businessId: string;
    /** Tenant context. */
    tenantId: string;
}

/**
 * Typed interface for the staff SMS notification adapter (Req 8.6, 15.4).
 * Phase 11 will provide a concrete implementation wired to a real SMS provider.
 */
export interface StaffSmsAdapter {
    /**
     * Send an SMS notification to a staff member.
     * While the flag is OFF, returns an unavailable result — never sends or
     * fabricates a delivery confirmation.
     */
    send(input: StaffSmsNotificationInput): Promise<DeferredCapabilityUnavailableResult>;

    /**
     * Check whether SMS delivery is available for this business.
     * While the flag is OFF, always returns false.
     */
    isAvailable(): Promise<boolean>;
}

/**
 * Resolve whether staff SMS notifications are enabled. FAIL-CLOSED.
 */
export async function isStaffSmsEnabled(): Promise<boolean> {
    return isDeferredFlagEnabled(STAFF_SMS_NOTIFICATION_FLAG);
}

/**
 * Create the flagged-off SMS adapter stub (Req 8.6, 15.4, 15.5).
 * Invoking `send()` while the flag is OFF returns an unavailable result —
 * it NEVER fabricates a delivery confirmation or sends a real message.
 */
export function createDeferredSmsAdapter(): StaffSmsAdapter {
    return {
        async send(input: StaffSmsNotificationInput): Promise<DeferredCapabilityUnavailableResult> {
            const enabled = await isStaffSmsEnabled();
            if (!enabled) {
                logger.info('Staff SMS notification invoked while flagged OFF', {
                    employeeId: input.employeeId,
                    businessId: input.businessId,
                    templateId: input.templateId,
                });
                return buildUnavailableResult(
                    STAFF_SMS_NOTIFICATION_FLAG,
                    'Staff SMS notifications',
                );
            }
            // Even if the flag were toggled ON, there is no real provider yet.
            // Refuse rather than fabricate (Req 15.5).
            logger.warn('Staff SMS flag is ON but no provider implementation exists', {
                employeeId: input.employeeId,
                businessId: input.businessId,
            });
            return buildUnavailableResult(
                STAFF_SMS_NOTIFICATION_FLAG,
                'Staff SMS notifications (no provider configured)',
            );
        },

        async isAvailable(): Promise<boolean> {
            return isStaffSmsEnabled();
        },
    };
}

// ════════════════════════════════════════════════════════════════════════════
// 2. ML/Predictive Capabilities (Req 9.2, 15.2)
// ════════════════════════════════════════════════════════════════════════════
// Attrition prediction, fraud prediction, salary/promotion recommendations,
// and workforce planning are all deferred to Phase 11. The module uses ONLY
// rule-based and statistical methods for insights (Req 9.2).

/** Feature flag key controlling ML/predictive features. Stays OFF. */
export const STAFF_ML_PREDICTIVE_FLAG = 'staff_ml_predictive';

/**
 * Types of ML/predictive capability the module will eventually support.
 * Listed here as typed constants so the UI can reference them.
 */
export const ML_PREDICTIVE_CAPABILITIES = [
    'attrition_prediction',
    'fraud_prediction',
    'salary_recommendation',
    'promotion_recommendation',
    'workforce_planning',
] as const;
export type MlPredictiveCapability = (typeof ML_PREDICTIVE_CAPABILITIES)[number];

/**
 * Input for requesting an ML/predictive insight.
 */
export interface MlPredictiveInput {
    /** Which predictive capability is being requested. */
    capability: MlPredictiveCapability;
    /** Employee ID (if the prediction is employee-scoped). */
    employeeId?: string;
    /** Business context. */
    businessId: string;
    /** Tenant context. */
    tenantId: string;
    /** Arbitrary parameters for the prediction model. */
    params?: Record<string, unknown>;
}

/**
 * Typed interface for ML/predictive capabilities (Req 15.2, 15.5).
 * Phase 11 will provide concrete model implementations.
 */
export interface MlPredictiveService {
    /**
     * Request a predictive insight. While the flag is OFF, returns an
     * unavailable result — never fabricates predictions or scores.
     */
    predict(input: MlPredictiveInput): Promise<DeferredCapabilityUnavailableResult>;

    /**
     * List all predictive capabilities and their availability status.
     * While the flag is OFF, every capability reports unavailable.
     */
    listCapabilities(): Promise<{
        capabilities: Array<{
            id: MlPredictiveCapability;
            available: boolean;
        }>;
    }>;

    /**
     * Check whether any ML/predictive capability is available.
     * While the flag is OFF, always returns false.
     */
    isAvailable(): Promise<boolean>;
}

/**
 * Resolve whether ML/predictive features are enabled. FAIL-CLOSED.
 */
export async function isMlPredictiveEnabled(): Promise<boolean> {
    return isDeferredFlagEnabled(STAFF_ML_PREDICTIVE_FLAG);
}

/**
 * Create the flagged-off ML/predictive service stub (Req 15.2, 15.5).
 * Every method returns an unavailable result — no fabricated predictions.
 */
export function createDeferredMlPredictiveService(): MlPredictiveService {
    return {
        async predict(input: MlPredictiveInput): Promise<DeferredCapabilityUnavailableResult> {
            const enabled = await isMlPredictiveEnabled();
            logger.info('ML/predictive capability invoked while flagged OFF', {
                capability: input.capability,
                businessId: input.businessId,
                employeeId: input.employeeId,
            });
            if (!enabled) {
                return buildUnavailableResult(
                    STAFF_ML_PREDICTIVE_FLAG,
                    `ML/predictive: ${input.capability}`,
                );
            }
            // Flag ON but no model exists — still refuse (Req 15.5).
            return buildUnavailableResult(
                STAFF_ML_PREDICTIVE_FLAG,
                `ML/predictive: ${input.capability} (no model deployed)`,
            );
        },

        async listCapabilities(): Promise<{
            capabilities: Array<{ id: MlPredictiveCapability; available: boolean }>;
        }> {
            const enabled = await isMlPredictiveEnabled();
            return {
                capabilities: ML_PREDICTIVE_CAPABILITIES.map((id) => ({
                    id,
                    available: enabled, // false while OFF; no fabricated availability
                })),
            };
        },

        async isAvailable(): Promise<boolean> {
            return isMlPredictiveEnabled();
        },
    };
}

// ════════════════════════════════════════════════════════════════════════════
// 3. Gamification (XP, Badges, Leaderboards) (Req 15.1)
// ════════════════════════════════════════════════════════════════════════════
// Gamification features (experience points, badges, team/individual
// leaderboards) are explicitly excluded from the current scope and deferred
// to Phase 11.

/** Feature flag key controlling gamification features. Stays OFF. */
export const STAFF_GAMIFICATION_FLAG = 'staff_gamification';

/**
 * Types of gamification capabilities.
 */
export const GAMIFICATION_CAPABILITIES = [
    'xp_tracking',
    'badges',
    'leaderboards',
] as const;
export type GamificationCapability = (typeof GAMIFICATION_CAPABILITIES)[number];

/**
 * Input for a gamification action (awarding XP, checking badge eligibility, etc.).
 */
export interface GamificationInput {
    /** Which gamification capability is being requested. */
    capability: GamificationCapability;
    /** Employee receiving the gamification action. */
    employeeId: string;
    /** Business context. */
    businessId: string;
    /** Tenant context. */
    tenantId: string;
    /** Action-specific parameters. */
    params?: Record<string, unknown>;
}

/**
 * Typed interface for gamification capabilities (Req 15.1, 15.5).
 * Phase 11 will provide concrete gamification implementations.
 */
export interface GamificationService {
    /**
     * Execute a gamification action (award XP, grant badge, update leaderboard).
     * While the flag is OFF, returns an unavailable result — never fabricates
     * XP values, badge grants, or leaderboard positions.
     */
    execute(input: GamificationInput): Promise<DeferredCapabilityUnavailableResult>;

    /**
     * Get an employee's gamification profile (XP, badges, rank).
     * While the flag is OFF, returns an unavailable result — never fabricates
     * a profile.
     */
    getProfile(
        tenantId: string,
        businessId: string,
        employeeId: string,
    ): Promise<DeferredCapabilityUnavailableResult>;

    /**
     * Get a leaderboard for a business.
     * While the flag is OFF, returns an unavailable result — never fabricates
     * leaderboard data.
     */
    getLeaderboard(
        tenantId: string,
        businessId: string,
    ): Promise<DeferredCapabilityUnavailableResult>;

    /**
     * Check whether gamification is available.
     * While the flag is OFF, always returns false.
     */
    isAvailable(): Promise<boolean>;
}

/**
 * Resolve whether gamification features are enabled. FAIL-CLOSED.
 */
export async function isGamificationEnabled(): Promise<boolean> {
    return isDeferredFlagEnabled(STAFF_GAMIFICATION_FLAG);
}

/**
 * Create the flagged-off gamification service stub (Req 15.1, 15.5).
 * Every method returns an unavailable result — no fabricated data.
 */
export function createDeferredGamificationService(): GamificationService {
    return {
        async execute(input: GamificationInput): Promise<DeferredCapabilityUnavailableResult> {
            const enabled = await isGamificationEnabled();
            logger.info('Gamification capability invoked while flagged OFF', {
                capability: input.capability,
                employeeId: input.employeeId,
                businessId: input.businessId,
            });
            if (!enabled) {
                return buildUnavailableResult(
                    STAFF_GAMIFICATION_FLAG,
                    `Gamification: ${input.capability}`,
                );
            }
            // Flag ON but no implementation — still refuse (Req 15.5).
            return buildUnavailableResult(
                STAFF_GAMIFICATION_FLAG,
                `Gamification: ${input.capability} (not implemented)`,
            );
        },

        async getProfile(
            tenantId: string,
            businessId: string,
            employeeId: string,
        ): Promise<DeferredCapabilityUnavailableResult> {
            logger.info('Gamification profile requested while flagged OFF', {
                employeeId,
                businessId,
            });
            return buildUnavailableResult(
                STAFF_GAMIFICATION_FLAG,
                'Gamification profile',
            );
        },

        async getLeaderboard(
            tenantId: string,
            businessId: string,
        ): Promise<DeferredCapabilityUnavailableResult> {
            logger.info('Gamification leaderboard requested while flagged OFF', {
                businessId,
            });
            return buildUnavailableResult(
                STAFF_GAMIFICATION_FLAG,
                'Gamification leaderboard',
            );
        },

        async isAvailable(): Promise<boolean> {
            return isGamificationEnabled();
        },
    };
}

// ════════════════════════════════════════════════════════════════════════════
// Convenience: Summary of ALL deferred capabilities and their flags
// ════════════════════════════════════════════════════════════════════════════

/**
 * Registry of all deferred-capability feature flags in the staff module.
 * Useful for startup checks, admin dashboards, and Phase_Report generation.
 */
export const DEFERRED_CAPABILITY_FLAGS = {
    /** Face/Biometric attendance (task 5.1, attendance.service.ts). */
    faceBiometricAttendance: 'staff_face_biometric_attendance',
    /** Full Aadhaar capture (task 3.1, pii-crypto.service.ts). */
    fullAadhaarCapture: 'staff_full_aadhaar_capture',
    /** Staff SMS notifications (this file). */
    staffSmsNotifications: STAFF_SMS_NOTIFICATION_FLAG,
    /** ML/predictive features (this file). */
    mlPredictive: STAFF_ML_PREDICTIVE_FLAG,
    /** Gamification features (this file). */
    gamification: STAFF_GAMIFICATION_FLAG,
} as const;

/**
 * Check that ALL deferred-capability flags are OFF. Returns the status of each.
 * Intended for Phase_Report generation and startup validation (Req 15.5).
 */
export async function auditDeferredCapabilityFlags(): Promise<
    Array<{ key: string; name: string; enabled: boolean }>
> {
    const entries: Array<{ key: string; name: string; enabled: boolean }> = [];

    for (const [name, key] of Object.entries(DEFERRED_CAPABILITY_FLAGS)) {
        const enabled = await isDeferredFlagEnabled(key);
        entries.push({ key, name, enabled });
    }

    return entries;
}
