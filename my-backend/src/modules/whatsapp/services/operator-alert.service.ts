// ============================================================================
// WhatsApp Automation Module — Operator Alert Service (Task 5.10)
// ============================================================================
// CRITICAL SAFETY COMPONENT:
// When a validation failure prevents delivery (recipient mismatch, phone
// number changed, profile deleted, consent violation, template render failure),
// the system STOPS the delivery and alerts the software operator instead of
// sending a document to the wrong person.
//
// Responsibilities:
// 1. Log the full failure details (what failed, which customer, which
//    document, what data was wrong)
// 2. Record an Audit_Log entry capturing the blocked delivery
// 3. Notify the operator via the existing Notification_Delivery_Layer
//    (push/email/in-app via `src/notifications`)
//
// Alert categories:
// - recipient_mismatch:   Event customer ID resolves to a different profile
// - phone_number_changed: Event-carried number does not match stored number
// - profile_deleted:      Customer profile has been soft-deleted
// - consent_violation:    Customer consent state forbids the message category
// - template_render_failure: Template placeholder unresolved or template missing
//
// Integration:
// - Uses WaAuditService for append-only audit trail writes
// - Uses NotificationService from `src/notifications` for operator delivery
// - Retries on transient failures (at-least-once delivery guarantee)
// - Never exposes another customer's data beyond operator authorization
//
// Requirements: 16.6, 16.7
// ============================================================================

import { randomUUID } from 'crypto';
import { logger } from '../../../utils/logger';
import {
  NotificationService,
  getDefaultNotificationService,
  type CreateNotificationInput,
  type CreateNotificationCaller,
} from '../../../notifications/service';
import {
  WaAuditService,
  buildAuditTarget,
} from './wa-audit.service';

// ── Alert Category Constants ──────────────────────────────────────────────────

/**
 * Well-known alert categories for operator alerts.
 * Each category maps to a specific validation failure type that blocks delivery.
 */
export const ALERT_CATEGORIES = {
  RECIPIENT_MISMATCH: 'recipient_mismatch',
  PHONE_NUMBER_CHANGED: 'phone_number_changed',
  PROFILE_DELETED: 'profile_deleted',
  CONSENT_VIOLATION: 'consent_violation',
  TEMPLATE_RENDER_FAILURE: 'template_render_failure',
} as const;

export type AlertCategory = (typeof ALERT_CATEGORIES)[keyof typeof ALERT_CATEGORIES];

// ── Audit Action ──────────────────────────────────────────────────────────────

/** Audit action recorded when a delivery is blocked and an operator alert is raised. */
export const AUDIT_ACTION_DELIVERY_BLOCKED = 'delivery.blocked_operator_alerted';

// ── Input Types ───────────────────────────────────────────────────────────────

/**
 * Input for raising an operator alert when a validation failure blocks delivery.
 *
 * Contains enough context for the operator to diagnose and resolve the issue
 * without exposing another customer's data beyond what the operator is
 * authorized to see (Req 16.7).
 */
export interface OperatorAlertInput {
  /** The Business_Event ID that triggered the automation. */
  eventId: string;
  /** The authenticated business scope. */
  businessId: string;
  /** The tenant scope. */
  tenantId: string;
  /** The type of document that was being delivered (e.g. 'invoice', 'receipt'). */
  documentType: string;
  /** The customer identifier referenced by the event. */
  customerId: string;
  /** The category of failure that blocked delivery. */
  category: AlertCategory;
  /** Human-readable reason describing what went wrong. */
  reason: string;
  /** Optional additional details for operator diagnosis. */
  details?: OperatorAlertDetails;
}

/**
 * Optional details providing additional context for the operator.
 * Designed to aid diagnosis without leaking data across customer boundaries.
 */
export interface OperatorAlertDetails {
  /** The event-carried phone number (when relevant). */
  eventPhoneNumber?: string;
  /** The stored profile phone number (when relevant). */
  storedPhoneNumber?: string;
  /** The template ID that failed (when relevant). */
  templateId?: string;
  /** The specific placeholder(s) that were unresolved (when relevant). */
  missingPlaceholders?: string[];
  /** Number of matching profiles found (for ambiguity cases). */
  matchCount?: number;
  /** The customer consent state (for consent violations). */
  consentState?: string;
  /** The message category that was blocked (for consent violations). */
  messageCategory?: string;
}

/**
 * Result of raising an operator alert.
 */
export interface OperatorAlertResult {
  /** Whether the alert was successfully dispatched to the notification layer. */
  alertDispatched: boolean;
  /** The notification ID from the notification service (if dispatched). */
  notificationId?: string;
  /** The audit log entry ID recording the blocked delivery. */
  auditEntryId: string;
}

// ── Retry Configuration ───────────────────────────────────────────────────────

/** Maximum number of retry attempts for transient notification failures. */
const MAX_RETRY_ATTEMPTS = 3;

/** Base backoff delay in milliseconds between retry attempts. */
const BASE_BACKOFF_MS = 500;

// ── OperatorAlertService ──────────────────────────────────────────────────────

/**
 * Service responsible for notifying the software operator when a validation
 * failure prevents document delivery.
 *
 * At-least-once delivery guarantee: on transient failures, the service retries
 * notification dispatch up to MAX_RETRY_ATTEMPTS times with exponential backoff.
 * The audit entry is always written first (regardless of notification outcome)
 * so there is a durable record even if the notification fails.
 *
 * Requirements: 16.6, 16.7
 */
export class OperatorAlertService {
  private readonly auditService: WaAuditService;
  private readonly notificationService: NotificationService;

  constructor(deps?: {
    auditService?: WaAuditService;
    notificationService?: NotificationService;
  }) {
    this.auditService = deps?.auditService ?? new WaAuditService();
    this.notificationService =
      deps?.notificationService ?? getDefaultNotificationService();
  }

  /**
   * Raise an operator alert when a validation failure blocks delivery.
   *
   * Steps:
   * 1. Log the full failure details for debugging/ops monitoring
   * 2. Record an immutable Audit_Log entry capturing the blocked delivery
   * 3. Dispatch a notification to the operator role through the
   *    Notification_Delivery_Layer (push/email/in-app) with retry on
   *    transient failures
   *
   * The audit entry is always written first — even if notification dispatch
   * fails after all retries, the blocked delivery is permanently recorded.
   *
   * @throws Never — errors are caught and logged. The caller should not fail
   *         because the alert could not be sent; the delivery is already blocked.
   */
  async raiseOperatorAlert(input: OperatorAlertInput): Promise<OperatorAlertResult> {
    const {
      eventId,
      businessId,
      tenantId,
      documentType,
      customerId,
      category,
      reason,
      details,
    } = input;

    // ─── Step 1: Log the full failure details ──────────────────────────────
    logger.warn('[operator-alert] Delivery blocked — alerting operator', {
      eventId,
      businessId,
      tenantId,
      documentType,
      customerId,
      category,
      reason,
      details: details ? sanitizeDetailsForLog(details) : undefined,
    });

    // ─── Step 2: Record Audit_Log entry ────────────────────────────────────
    // This MUST succeed first so there is always a durable record of the
    // blocked delivery regardless of notification outcome.
    let auditEntryId: string;
    try {
      const auditEntry = await this.auditService.record(
        { tenantId, businessId, actor: 'system:operator-alert' },
        AUDIT_ACTION_DELIVERY_BLOCKED,
        buildAuditTarget('document_delivery', `${documentType}:${eventId}`),
        /* before */ undefined,
        /* after */ {
          eventId,
          documentType,
          customerId,
          category,
          reason,
          // Include only operator-safe details (no cross-customer data leak)
          ...(details ? buildAuditDetails(details) : {}),
          blockedAt: new Date().toISOString(),
        },
      );
      auditEntryId = auditEntry.id;
    } catch (auditErr) {
      // Audit write failure is critical but should not prevent the alert.
      // Log and generate a synthetic ID for tracking.
      logger.error('[operator-alert] Failed to write audit entry', {
        eventId,
        businessId,
        error: auditErr instanceof Error ? auditErr.message : String(auditErr),
      });
      auditEntryId = `failed-${randomUUID()}`;
    }

    // ─── Step 3: Dispatch notification to operator via Notification_Delivery_Layer ──
    let alertDispatched = false;
    let notificationId: string | undefined;

    try {
      notificationId = await this.dispatchOperatorNotification(input, auditEntryId);
      alertDispatched = true;

      logger.info('[operator-alert] Operator alert dispatched successfully', {
        eventId,
        businessId,
        notificationId,
        category,
      });
    } catch (dispatchErr) {
      // All retries exhausted — log the failure. The audit entry ensures
      // the blocked delivery is still recorded for later discovery.
      logger.error('[operator-alert] Failed to dispatch operator notification after retries', {
        eventId,
        businessId,
        category,
        auditEntryId,
        error: dispatchErr instanceof Error ? dispatchErr.message : String(dispatchErr),
      });
    }

    return {
      alertDispatched,
      notificationId,
      auditEntryId,
    };
  }

  // ── Private: Dispatch notification with retry ─────────────────────────────

  /**
   * Dispatch the operator notification through the NotificationService with
   * at-least-once delivery semantics (retry on transient failure).
   */
  private async dispatchOperatorNotification(
    input: OperatorAlertInput,
    auditEntryId: string,
  ): Promise<string> {
    const notificationInput = this.buildNotificationInput(input, auditEntryId);
    const caller = this.buildSystemCaller();

    let lastError: Error | undefined;

    for (let attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
      try {
        const result = await this.notificationService.createNotification(
          notificationInput,
          caller,
        );
        return result.notification_id;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));

        // On permanent/authorization errors, do not retry
        if (isPermanentError(lastError)) {
          throw lastError;
        }

        // On transient errors, backoff and retry
        if (attempt < MAX_RETRY_ATTEMPTS) {
          const backoffMs = BASE_BACKOFF_MS * Math.pow(2, attempt - 1);
          logger.warn('[operator-alert] Transient failure, retrying', {
            eventId: input.eventId,
            attempt,
            maxAttempts: MAX_RETRY_ATTEMPTS,
            backoffMs,
            error: lastError.message,
          });
          await sleep(backoffMs);
        }
      }
    }

    // All attempts exhausted
    throw lastError ?? new Error('Operator notification dispatch failed');
  }

  // ── Private: Build notification payload ────────────────────────────────────

  /**
   * Build the CreateNotificationInput for the operator alert.
   *
   * The notification is:
   * - Category: 'system' (operational alert)
   * - Priority: 'high' (at_least_once delivery mode)
   * - Recipients: the operator role (admin/super_admin) for the business
   * - Channels: in_app + push + email (maximum visibility)
   * - Payload: enough context to diagnose without leaking cross-customer data
   */
  private buildNotificationInput(
    input: OperatorAlertInput,
    auditEntryId: string,
  ): CreateNotificationInput {
    const { eventId, businessId, documentType, customerId, category, reason, details } = input;

    return {
      id: randomUUID(),
      event_name: 'whatsapp.delivery.blocked',
      category: 'system',
      sub_category: 'operator_alert',
      priority: 'high',
      actor_id: `system:whatsapp-automation`,
      target_id: businessId,
      recipients: [
        {
          user_id: `operator:${businessId}`,
          role: 'admin',
          channels: ['in_app', 'push', 'email'],
        },
      ],
      payload: {
        alert_type: 'delivery_blocked',
        category,
        document_type: documentType,
        customer_id: customerId,
        event_id: eventId,
        reason,
        audit_entry_id: auditEntryId,
        // Include safe details for operator diagnosis
        ...(details ? buildNotificationDetails(details) : {}),
        blocked_at: new Date().toISOString(),
      },
      channels: ['in_app', 'push', 'email'],
      source_module: 'modules/whatsapp',
      source_app: 'dukanx_backend',
      created_at: new Date().toISOString(),
    };
  }

  /**
   * Build the system-level caller context for creating notifications.
   * The operator alert is emitted by the system (automation engine), not
   * by a human user.
   */
  private buildSystemCaller(): CreateNotificationCaller {
    return {
      user_id: 'system:whatsapp-automation',
      role: 'system',
      allowed_actor_ids: ['system:whatsapp-automation'],
    };
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Sanitize alert details for structured logging.
 * Masks phone numbers partially so they're recognizable but not fully exposed
 * in log aggregation systems.
 */
function sanitizeDetailsForLog(details: OperatorAlertDetails): Record<string, unknown> {
  const sanitized: Record<string, unknown> = {};

  if (details.eventPhoneNumber) {
    sanitized.eventPhoneNumber = maskPhone(details.eventPhoneNumber);
  }
  if (details.storedPhoneNumber) {
    sanitized.storedPhoneNumber = maskPhone(details.storedPhoneNumber);
  }
  if (details.templateId) {
    sanitized.templateId = details.templateId;
  }
  if (details.missingPlaceholders) {
    sanitized.missingPlaceholders = details.missingPlaceholders;
  }
  if (details.matchCount !== undefined) {
    sanitized.matchCount = details.matchCount;
  }
  if (details.consentState) {
    sanitized.consentState = details.consentState;
  }
  if (details.messageCategory) {
    sanitized.messageCategory = details.messageCategory;
  }

  return sanitized;
}

/**
 * Build audit entry details (Req 16.7 — don't expose another customer's data).
 * Only includes information the operator is authorized to see within this
 * business scope.
 */
function buildAuditDetails(details: OperatorAlertDetails): Record<string, unknown> {
  const result: Record<string, unknown> = {};

  if (details.templateId) {
    result.templateId = details.templateId;
  }
  if (details.missingPlaceholders) {
    result.missingPlaceholders = details.missingPlaceholders;
  }
  if (details.matchCount !== undefined) {
    result.matchCount = details.matchCount;
  }
  if (details.consentState) {
    result.consentState = details.consentState;
  }
  if (details.messageCategory) {
    result.messageCategory = details.messageCategory;
  }
  // Phone numbers in the audit trail are safe — they belong to the same
  // business's customer and the operator is authorized to view them.
  if (details.eventPhoneNumber) {
    result.eventPhoneNumber = details.eventPhoneNumber;
  }
  if (details.storedPhoneNumber) {
    result.storedPhoneNumber = details.storedPhoneNumber;
  }

  return result;
}

/**
 * Build notification payload details safe for operator viewing.
 * Phone numbers are masked in the notification payload since it may be
 * rendered in push notifications visible on lock screens (Req 16.7).
 */
function buildNotificationDetails(details: OperatorAlertDetails): Record<string, unknown> {
  const result: Record<string, unknown> = {};

  if (details.eventPhoneNumber) {
    result.event_phone_masked = maskPhone(details.eventPhoneNumber);
  }
  if (details.storedPhoneNumber) {
    result.stored_phone_masked = maskPhone(details.storedPhoneNumber);
  }
  if (details.templateId) {
    result.template_id = details.templateId;
  }
  if (details.missingPlaceholders) {
    result.missing_placeholders = details.missingPlaceholders;
  }
  if (details.matchCount !== undefined) {
    result.match_count = details.matchCount;
  }
  if (details.consentState) {
    result.consent_state = details.consentState;
  }
  if (details.messageCategory) {
    result.message_category = details.messageCategory;
  }

  return result;
}

/**
 * Mask a phone number for display, preserving country code and last 4 digits.
 * E.g. "+919876543210" → "+91******3210"
 */
function maskPhone(phone: string): string {
  if (phone.length <= 6) return phone; // too short to meaningfully mask
  const prefix = phone.slice(0, 3);    // "+" + first 2 digits (country code)
  const suffix = phone.slice(-4);      // last 4 digits
  const masked = '*'.repeat(phone.length - 7);
  return `${prefix}${masked}${suffix}`;
}

/**
 * Determine if an error is permanent (should not be retried).
 * Authorization errors and validation errors are permanent.
 * Network/timeout errors are transient.
 */
function isPermanentError(err: Error): boolean {
  const name = err.name || '';
  const message = err.message || '';

  // Authorization errors — the system caller should always be authorized,
  // but if something is misconfigured, retrying won't help.
  if (name === 'AuthorizationError') return true;

  // Validation errors — payload shape is wrong, retrying won't help.
  if (name === 'PreferenceValidationError') return true;
  if (message.includes('event_name') && message.includes('pattern')) return true;

  // Everything else (network, timeout, throttle) is transient.
  return false;
}

/**
 * Async sleep utility for backoff delays.
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
