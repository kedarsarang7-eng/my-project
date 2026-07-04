// ============================================================================
// WhatsApp Automation Module — Audit Service (Task 5.8)
// ============================================================================
// Append-only Audit_Log writes for compliance and debugging traceability.
//
// Every entry captures:
// - actor:     WHO performed the action (user ID, system ID, or webhook source)
// - action:    WHAT action was taken (e.g., 'consent.changed', 'template.updated')
// - target:    WHICH entity was affected (entity type + ID)
// - before:    State before the change (or undefined for creations)
// - after:     State after the change (or undefined for deletions/rejections)
// - timestamp: UTC ISO-8601 timestamp of when the action occurred
//
// APPEND-ONLY CONTRACT:
// Once an audit entry is written, it CANNOT be modified or deleted.
// This is enforced by the AuditLogRepository's conditional PutItem and the
// absence of any update/delete methods.
//
// COVERED EVENTS (Requirements 2.7, 7.6, 8.5):
// - Consent state changes (opted_in → opted_out, pending → opted_in, etc.)
// - Automation_Config changes (create, update)
// - Message_Template changes (create, update, deactivate, version)
// - Automation_Rule changes (create, update, enable, disable)
// - Webhook signature verification rejections
//
// Requirements: 2.7, 7.6, 8.5
// ============================================================================

import {
  AuditLogRepository,
  type AuditLogCreateInput,
} from '../repositories/audit-log.repository';
import type { AuditLogEntry } from '../schemas/entities';

// ── Audit Action Constants ────────────────────────────────────────────────────

/** Well-known audit action identifiers for consistent querying and filtering. */
export const AUDIT_ACTIONS = {
  // Consent changes (Req 2.7)
  CONSENT_CHANGED: 'consent.changed',

  // Config changes (Req 7.6)
  CONFIG_CREATED: 'config.created',
  CONFIG_UPDATED: 'config.updated',

  // Template changes (Req 7.6)
  TEMPLATE_CREATED: 'template.created',
  TEMPLATE_UPDATED: 'template.updated',
  TEMPLATE_DEACTIVATED: 'template.deactivated',
  TEMPLATE_VERSION_CREATED: 'template.version_created',

  // Rule changes (Req 7.6)
  RULE_CREATED: 'rule.created',
  RULE_UPDATED: 'rule.updated',
  RULE_ENABLED: 'rule.enabled',
  RULE_DISABLED: 'rule.disabled',

  // Webhook rejections (Req 8.5)
  WEBHOOK_REJECTED: 'webhook.signature_rejected',
} as const;

export type AuditAction = (typeof AUDIT_ACTIONS)[keyof typeof AUDIT_ACTIONS];

// ── Audit Target Builders ─────────────────────────────────────────────────────

/**
 * Builds a target string identifying the audited entity.
 * Format: `{entityType}:{entityId}` for consistent filtering/lookup.
 */
export function buildAuditTarget(entityType: string, entityId: string): string {
  return `${entityType}:${entityId}`;
}

// ── Input Types ───────────────────────────────────────────────────────────────

/** Context for performing an audit write (tenant + business scope). */
export interface AuditContext {
  tenantId: string;
  businessId: string;
  actor: string;
}

/** Input for recording a consent change audit entry (Req 2.7). */
export interface ConsentChangeAuditInput {
  customerId: string;
  previousState: string;
  newState: string;
  source: string; // e.g. 'user_action', 'opt_out_keyword', 'api'
}

/** Input for recording a config change audit entry. */
export interface ConfigChangeAuditInput {
  configId: string;
  action: 'created' | 'updated';
  before?: unknown;
  after: unknown;
}

/** Input for recording a template change audit entry (Req 7.6). */
export interface TemplateChangeAuditInput {
  templateId: string;
  action: 'created' | 'updated' | 'deactivated' | 'version_created';
  before?: unknown;
  after?: unknown;
}

/** Input for recording a rule change audit entry (Req 7.6). */
export interface RuleChangeAuditInput {
  ruleId: string;
  action: 'created' | 'updated' | 'enabled' | 'disabled';
  before?: unknown;
  after?: unknown;
}

/** Input for recording a webhook rejection audit entry (Req 8.5). */
export interface WebhookRejectionAuditInput {
  source: string;       // IP or identifier of the request origin
  reason: string;       // e.g. 'hmac_mismatch', 'missing_signature'
  requestMeta?: unknown; // Non-sensitive request metadata for debugging
}

// ── WaAuditService ────────────────────────────────────────────────────────────

/**
 * Service responsible for recording append-only audit log entries.
 *
 * All methods are fire-and-forget safe: they throw on I/O errors so callers
 * can decide whether to swallow or propagate. The underlying repository
 * guarantees immutability — once written, an entry is never modified.
 */
export class WaAuditService {
  private readonly repo: AuditLogRepository;

  constructor(repo?: AuditLogRepository) {
    this.repo = repo ?? new AuditLogRepository();
  }

  // ── Consent Changes (Req 2.7) ─────────────────────────────────────────────

  /**
   * Records an audit entry when a customer's consent state changes.
   *
   * Captures the previous and new consent states along with the source
   * that triggered the change (user action, opt-out keyword, API call).
   */
  async recordConsentChange(
    ctx: AuditContext,
    input: ConsentChangeAuditInput,
  ): Promise<AuditLogEntry> {
    const data: AuditLogCreateInput = {
      actor: ctx.actor,
      action: AUDIT_ACTIONS.CONSENT_CHANGED,
      target: buildAuditTarget('customer', input.customerId),
      before: {
        consentState: input.previousState,
      },
      after: {
        consentState: input.newState,
        source: input.source,
      },
    };

    return this.repo.create(ctx.tenantId, ctx.businessId, data);
  }

  // ── Config Changes ────────────────────────────────────────────────────────

  /**
   * Records an audit entry when an Automation_Config is created or updated.
   */
  async recordConfigChange(
    ctx: AuditContext,
    input: ConfigChangeAuditInput,
  ): Promise<AuditLogEntry> {
    const actionMap = {
      created: AUDIT_ACTIONS.CONFIG_CREATED,
      updated: AUDIT_ACTIONS.CONFIG_UPDATED,
    } as const;

    const data: AuditLogCreateInput = {
      actor: ctx.actor,
      action: actionMap[input.action],
      target: buildAuditTarget('config', input.configId),
      before: input.before,
      after: input.after,
    };

    return this.repo.create(ctx.tenantId, ctx.businessId, data);
  }

  // ── Template Changes (Req 7.6) ────────────────────────────────────────────

  /**
   * Records an audit entry when a Message_Template is created, updated,
   * deactivated, or a new version is created.
   */
  async recordTemplateChange(
    ctx: AuditContext,
    input: TemplateChangeAuditInput,
  ): Promise<AuditLogEntry> {
    const actionMap = {
      created: AUDIT_ACTIONS.TEMPLATE_CREATED,
      updated: AUDIT_ACTIONS.TEMPLATE_UPDATED,
      deactivated: AUDIT_ACTIONS.TEMPLATE_DEACTIVATED,
      version_created: AUDIT_ACTIONS.TEMPLATE_VERSION_CREATED,
    } as const;

    const data: AuditLogCreateInput = {
      actor: ctx.actor,
      action: actionMap[input.action],
      target: buildAuditTarget('template', input.templateId),
      before: input.before,
      after: input.after,
    };

    return this.repo.create(ctx.tenantId, ctx.businessId, data);
  }

  // ── Rule Changes (Req 7.6) ────────────────────────────────────────────────

  /**
   * Records an audit entry when an Automation_Rule is created, updated,
   * enabled, or disabled.
   */
  async recordRuleChange(
    ctx: AuditContext,
    input: RuleChangeAuditInput,
  ): Promise<AuditLogEntry> {
    const actionMap = {
      created: AUDIT_ACTIONS.RULE_CREATED,
      updated: AUDIT_ACTIONS.RULE_UPDATED,
      enabled: AUDIT_ACTIONS.RULE_ENABLED,
      disabled: AUDIT_ACTIONS.RULE_DISABLED,
    } as const;

    const data: AuditLogCreateInput = {
      actor: ctx.actor,
      action: actionMap[input.action],
      target: buildAuditTarget('rule', input.ruleId),
      before: input.before,
      after: input.after,
    };

    return this.repo.create(ctx.tenantId, ctx.businessId, data);
  }

  // ── Webhook Rejections (Req 8.5) ──────────────────────────────────────────

  /**
   * Records an audit entry when an incoming OpenWA webhook fails HMAC-SHA256
   * signature verification. The webhook payload is NOT stored (may be
   * tampered), only non-sensitive metadata for debugging.
   */
  async recordWebhookRejection(
    ctx: AuditContext,
    input: WebhookRejectionAuditInput,
  ): Promise<AuditLogEntry> {
    const data: AuditLogCreateInput = {
      actor: `webhook:${input.source}`,
      action: AUDIT_ACTIONS.WEBHOOK_REJECTED,
      target: buildAuditTarget('webhook', 'openwa'),
      before: undefined,
      after: {
        reason: input.reason,
        requestMeta: input.requestMeta,
      },
    };

    return this.repo.create(ctx.tenantId, ctx.businessId, data);
  }

  // ── Generic Audit Write ───────────────────────────────────────────────────

  /**
   * Records a generic audit entry for actions not covered by the specific
   * methods above. Useful for extensibility without modifying the service.
   */
  async record(
    ctx: AuditContext,
    action: string,
    target: string,
    before?: unknown,
    after?: unknown,
  ): Promise<AuditLogEntry> {
    const data: AuditLogCreateInput = {
      actor: ctx.actor,
      action,
      target,
      before,
      after,
    };

    return this.repo.create(ctx.tenantId, ctx.businessId, data);
  }
}
