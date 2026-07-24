/**
 * Offline Eligibility Configuration
 *
 * Defines which MobileShop operations can be queued offline (locally accepted
 * and synced later) versus which require online authorization or external verification.
 *
 * Requirements: 7.2–7.3
 */

/** Operation eligibility for offline queuing */
export interface OfflineOperationEntry {
  /** Operation type identifier */
  readonly operation: string;
  /** Whether this operation can be queued offline */
  readonly offlineEligible: boolean;
  /** Reason if not eligible */
  readonly reason?: string;
  /** Additional constraints when eligible offline */
  readonly constraints?: string;
}

export interface OfflineEligibilityConfig {
  /** Operations and their offline eligibility */
  readonly operations: readonly OfflineOperationEntry[];
  /** Maximum offline queue depth per tenant */
  readonly maxQueueDepth: number;
  /** Maximum age of a queued mutation before it is considered expired (seconds) */
  readonly maxQueueAgeSeconds: number;
}

export const OFFLINE_ELIGIBILITY_CONFIG: OfflineEligibilityConfig = {
  maxQueueDepth: 100,
  maxQueueAgeSeconds: 7 * 24 * 60 * 60, // 7 days

  operations: [
    // === Eligible offline ===
    {
      operation: 'DEVICE_SALE',
      offlineEligible: true,
      constraints: 'Requires locally cached IMEI state; authoritative confirmation deferred to sync',
    },
    {
      operation: 'INVOICE_CREATE',
      offlineEligible: true,
      constraints: 'Saved as local draft/pending until backend confirmation',
    },
    {
      operation: 'INVOICE_CANCEL',
      offlineEligible: true,
      constraints: 'Requires prior sale to exist in local state',
    },
    {
      operation: 'SERVICE_JOB_CREATE',
      offlineEligible: true,
      constraints: 'Unit must exist in local cache',
    },
    {
      operation: 'SERVICE_JOB_STATUS_CHANGE',
      offlineEligible: true,
      constraints: 'Requires expected version from local state',
    },
    {
      operation: 'DEVICE_RETURN',
      offlineEligible: true,
      constraints: 'Originating sale must be locally confirmed',
    },
    {
      operation: 'SECOND_HAND_INTAKE',
      offlineEligible: true,
      constraints: 'Policy/uniqueness check deferred to backend; local draft only',
    },
    {
      operation: 'WARRANTY_REGISTER',
      offlineEligible: true,
      constraints: 'Associated sale must exist locally',
    },
    {
      operation: 'DEMO_ASSIGN',
      offlineEligible: true,
      constraints: 'Unit must exist in local cache',
    },
    {
      operation: 'RESERVATION_CREATE',
      offlineEligible: true,
      constraints: 'Unit must be locally in saleable state; claim confirmation deferred',
    },

    // === Online required ===
    {
      operation: 'EXCHANGE_ACCEPT',
      offlineEligible: false,
      reason: 'Requires real-time valuation confirmation and dual lifecycle transition',
    },
    {
      operation: 'WARRANTY_CLAIM',
      offlineEligible: false,
      reason: 'Requires provider verification and evidence upload',
    },
    {
      operation: 'FINANCE_PLAN_CREATE',
      offlineEligible: false,
      reason: 'Requires online authorization from finance provider',
    },
    {
      operation: 'SIM_RECHARGE',
      offlineEligible: false,
      reason: 'Requires real-time provider submission',
    },
    {
      operation: 'PROVIDER_SUBMISSION',
      offlineEligible: false,
      reason: 'External provider requires network connectivity',
    },
    {
      operation: 'RECONCILIATION_RESOLVE',
      offlineEligible: false,
      reason: 'Requires authoritative backend state verification',
    },
  ],
} as const;
