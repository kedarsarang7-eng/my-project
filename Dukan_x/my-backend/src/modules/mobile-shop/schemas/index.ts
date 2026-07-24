/**
 * MobileShop Domain Schemas — Barrel Export
 *
 * Versioned TypeScript schemas for IMEI units, invoice associations,
 * service jobs, exchanges, warranties, second-hand intake, returns,
 * reservations, finance, recharge, audit, synchronization, idempotency,
 * conflicts, and AuthoritativeConfirmation.
 *
 * Requirements: 3.3–3.8, 4.1–4.9, 5.1–5.7, 6.3–6.4, 6.18, 6.27, 6.33, 6.42, 10.4–10.12; GR-2
 */

// Common shared types
export {
  CANONICAL_BUSINESS_TYPE,
  normalizeMobileShopBusinessType,
  isMobileShopBusinessType,
  type TenantContextWire,
  type Money,
  type Versioned,
  type EntityVersion,
  type TenantScopedEntity,
  type Timestamps,
  type PaginatedRequest,
  type PaginatedResponse,
  type EvidenceReference,
} from './common.schema';

// AuthoritativeConfirmation
export {
  type ConfirmationAuthority,
  type ConfirmationState,
  type AuthoritativeConfirmation,
  type MutationOutcomeState,
  type MutationOutcome,
  type MutationError,
} from './confirmation.schema';

// IMEI Unit
export {
  type DeviceLifecycleState,
  type DeviceCondition,
  type OwnershipSource,
  type ImeiUnit,
  type DeviceLifecycleTransitionCommand,
} from './imei-unit.schema';

// Invoice
export {
  type InvoiceStatus,
  type InvoiceLineType,
  type Invoice,
  type InvoiceDeviceLine,
} from './invoice.schema';

// Service Job
export {
  type ServiceJobStatus,
  type ServicePriority,
  type ServiceJob,
  type ServiceJobTransitionCommand,
} from './service-job.schema';

// Exchange
export {
  type ExchangeStatus,
  type Exchange,
} from './exchange.schema';

// Warranty
export {
  type WarrantyStatus,
  type WarrantyClaimStatus,
  type WarrantyType,
  type Warranty,
  type WarrantyClaim,
} from './warranty.schema';

// Second-Hand Intake
export {
  type IntakeStatus,
  type InspectionResult,
  type SecondHandIntake,
} from './second-hand-intake.schema';

// Return
export {
  type ReturnStatus,
  type ReturnDisposition,
  type Return,
} from './return.schema';

// Reservation
export {
  type ReservationStatus,
  type Reservation,
} from './reservation.schema';

// Finance
export {
  type FinancePlanStatus,
  type EmiStatus,
  type FinancePlan,
  type EmiInstallment,
} from './finance.schema';

// Recharge
export {
  type RechargeStatus,
  type RechargeType,
  type RechargeRequest,
  type RechargeResponse,
  type RechargeRecord,
} from './recharge.schema';

// Audit Event
export {
  type AuditAction,
  type AuditEvent,
} from './audit-event.schema';

// Synchronization
export {
  type PushMutation,
  type PushBatchRequest,
  type PushMutationResultStatus,
  type PushMutationResult,
  type PushBatchResponse,
  type PullRequest,
  type ChangeEvent,
  type PullResponse,
  type ServerHint,
} from './sync.schema';

// Idempotency
export {
  type IdempotencyStatus,
  type IdempotencyRecord,
  type MutationEnvelope,
} from './idempotency.schema';

// Conflict
export {
  type ConflictReason,
  type ConflictResolutionState,
  type ConflictRecord,
} from './conflict.schema';
