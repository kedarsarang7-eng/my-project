// ============================================================================
// WhatsApp Automation — Engine Lambda (Task 9.3)
// ============================================================================
// The central Automation_Engine Lambda that orchestrates the full pipeline:
//   EventBridge event → idempotency check → config resolution → rule evaluation
//   → template rendering → durable enqueue
//
// TRIGGER: EventBridge (source: dukanx.billing, dukanx.inventory, dukanx.whatsapp)
//
// DESIGN CONTRACTS:
// - ASYNCHRONOUS: returns before dispatch completes (Req 14.2) — the originating
//   transaction is never blocked by this Lambda.
// - Within 5 seconds of event receipt (Req 3.1, 14.1).
// - Dedup via idempotency.service.ts `checkAndMarkProcessed` per (eventId, recipientId).
// - Resolve enabled automations via automation-config.service.ts.
// - Evaluate rules via rule-engine.service.ts (ensures correct recipient resolution).
// - Render templates via template-render.service.ts (fail-closed on missing placeholders).
// - Durably enqueue via durable-enqueue.service.ts (persist to DynamoDB before ack).
// - The recipientNumber in each enqueued message MUST come from the CustomerProfile.
// - If ANY validation fails along the way, stop the delivery and log the reason.
//
// Requirements: 3.1, 3.2, 3.6, 3.9, 14.1, 14.2
// ============================================================================

import { logger } from '../../../utils/logger';
import { checkAndMarkProcessed } from '../services/idempotency.service';
import {
  resolveEnabledAutomations,
  type AutomationResolution,
} from '../services/automation-config.service';
import {
  evaluateRules,
  type BusinessEvent,
  type OutboundPlan,
  type RuleEvaluationResult,
} from '../services/rule-engine.service';
import {
  render,
  type TemplateInput,
  type RenderResult,
  type RenderFailure,
} from '../services/template-render.service';
import {
  DurableEnqueueService,
  createDurableEnqueueService,
  type DurableEnqueueInput,
  type DurableEnqueueResult,
} from '../services/durable-enqueue.service';
import { AutomationConfigRepository } from '../repositories/automation-config.repository';
import { AutomationRuleRepository } from '../repositories/automation-rule.repository';
import { CustomerProfileRepository } from '../repositories/customer-profile.repository';
import { MessageTemplateRepository } from '../repositories/message-template.repository';
import { DeliveryLogRepository } from '../repositories/delivery-log.repository';
import type { AutomationRule, CustomerProfile, MessageTemplate } from '../schemas/entities';
import type { SubscriptionTier } from '../schemas/entities';
import { normalizeBusinessType } from '../../../types/tenant.types';

// ── Types ─────────────────────────────────────────────────────────────────────

/**
 * EventBridge event envelope as delivered to this Lambda.
 * Follows the standard EventBridge event structure.
 */
interface EventBridgeEvent {
  readonly id: string;
  readonly source: string;
  readonly 'detail-type': string;
  readonly detail: {
    readonly eventId: string;
    readonly businessId: string;
    readonly tenantId: string;
    readonly eventType: string;
    readonly businessType?: string;
    readonly tier?: string;
    readonly branchId?: string;
    readonly payload: Record<string, unknown>;
  };
  readonly time?: string;
  readonly region?: string;
  readonly account?: string;
}

/**
 * Result returned by the engine for each processed event.
 * Summarizes what happened during the pipeline execution.
 */
export interface EngineResult {
  /** The unique event identifier processed. */
  eventId: string;
  /** Whether the event was valid and processing completed. */
  processed: boolean;
  /** Number of messages successfully enqueued. */
  enqueued: number;
  /** Number of recipients skipped (consent, idempotency, branch, etc.). */
  skipped: number;
  /** Number of recipients that failed (template render, enqueue failure). */
  failed: number;
  /** If the event was discarded, the reason. */
  discardReason?: string;
  /** Per-recipient outcomes for debugging. */
  outcomes: RecipientOutcome[];
}

interface RecipientOutcome {
  recipientId: string;
  status: 'enqueued' | 'duplicate' | 'template_failed' | 'enqueue_failed' | 'suppressed';
  reason?: string;
}

// ── Repository / Service Instances ────────────────────────────────────────────

const configRepo = new AutomationConfigRepository();
const ruleRepo = new AutomationRuleRepository();
const customerRepo = new CustomerProfileRepository();
const templateRepo = new MessageTemplateRepository();
const deliveryLogRepo = new DeliveryLogRepository();
const enqueueService: DurableEnqueueService = createDurableEnqueueService();

// ── Lambda Handler ────────────────────────────────────────────────────────────

/**
 * Main Lambda handler for the whatsappEngine.
 *
 * Triggered by EventBridge matched events (dukanx.billing, dukanx.inventory,
 * dukanx.whatsapp). Processes each event through the full automation pipeline.
 *
 * EventBridge may deliver a batch of events, but typically delivers one at a time
 * for this pattern. The handler supports both a single event and an array.
 *
 * CRITICAL: This Lambda returns BEFORE dispatch occurs (Req 14.2).
 * Messages are durably enqueued; the dispatcher Lambda handles actual sending.
 */
export async function handler(
  event: EventBridgeEvent | EventBridgeEvent[],
): Promise<EngineResult | EngineResult[]> {
  const events = Array.isArray(event) ? event : [event];
  const results: EngineResult[] = [];

  for (const ebEvent of events) {
    const result = await processEvent(ebEvent);
    results.push(result);
  }

  return events.length === 1 ? results[0] : results;
}

// ── Core Pipeline ─────────────────────────────────────────────────────────────

/**
 * Processes a single EventBridge event through the full automation pipeline.
 *
 * Pipeline steps:
 * 1. Extract and validate the Business_Event from the EventBridge envelope
 * 2. Resolve the Automation_Config for this business
 * 3. Fetch matching automation rules for this event type
 * 4. Fetch customer profiles for the business
 * 5. Evaluate rules → OutboundPlans (with consent gating, branch scoping)
 * 6. For each plan:
 *    a. Idempotency check (eventId, recipientId)
 *    b. Fetch and render the template
 *    c. Durably enqueue the outbound message
 * 7. Log suppressions and failures in the Delivery_Log
 */
async function processEvent(ebEvent: EventBridgeEvent): Promise<EngineResult> {
  const startTime = Date.now();

  // ── Step 1: Extract the Business_Event from the EventBridge envelope ──
  const businessEvent = extractBusinessEvent(ebEvent);
  if (!businessEvent) {
    const reason = 'Invalid EventBridge event: missing or malformed detail';
    logger.error('[WhatsAppEngine] Discarded malformed event', {
      eventBridgeId: ebEvent?.id,
      reason,
    });
    return {
      eventId: ebEvent?.id || 'unknown',
      processed: false,
      enqueued: 0,
      skipped: 0,
      failed: 0,
      discardReason: reason,
      outcomes: [],
    };
  }

  const { eventId, businessId, tenantId, eventType, businessType, tier, branchId } = businessEvent;

  logger.info('[WhatsAppEngine] Processing event', {
    eventId,
    businessId,
    tenantId,
    eventType,
    businessType,
    tier,
    branchId,
  });

  // ── Step 2: Resolve Automation_Config ─────────────────────────────────
  const resolvedBusinessType = normalizeBusinessType(businessType);
  const resolvedTier = (tier || 'basic') as SubscriptionTier;

  const automationConfig = await configRepo.get(
    tenantId,
    businessId,
    resolvedBusinessType,
    resolvedTier,
  );

  const resolution: AutomationResolution = resolveEnabledAutomations(
    resolvedBusinessType,
    resolvedTier,
    automationConfig,
  );

  // If config is invalid/missing and all automations are disabled, stop early
  if (!resolution.configValid && resolution.automations.length === 0) {
    logger.info('[WhatsAppEngine] No valid config — all automations disabled', {
      eventId,
      businessId,
      condition: resolution.condition,
    });
    return {
      eventId,
      processed: true,
      enqueued: 0,
      skipped: 0,
      failed: 0,
      discardReason: resolution.condition,
      outcomes: [],
    };
  }

  // Build the enabled automation keys set for the rule engine
  const enabledAutomationKeys = new Set(
    resolution.automations
      .filter((a) => a.enabled)
      .map((a) => a.key),
  );

  // ── Step 3: Fetch automation rules matching this event type ────────────
  const rules: AutomationRule[] = await ruleRepo.listByEventType(
    tenantId,
    businessId,
    eventType,
  );

  if (rules.length === 0) {
    logger.info('[WhatsAppEngine] No matching rules for event type', {
      eventId,
      businessId,
      eventType,
    });
    return {
      eventId,
      processed: true,
      enqueued: 0,
      skipped: 0,
      failed: 0,
      outcomes: [],
    };
  }

  // ── Step 4: Fetch customer profiles for the business ──────────────────
  const profilesList: CustomerProfile[] = await customerRepo.list(tenantId, businessId);
  const profiles = new Map<string, CustomerProfile>(
    profilesList.map((p) => [p.id, p]),
  );

  // ── Step 5: Evaluate rules → OutboundPlans ────────────────────────────
  const ruleEvent: BusinessEvent = {
    eventId,
    businessId,
    eventType,
    branchId,
    payload: businessEvent.payload,
  };

  const evalResult: RuleEvaluationResult = evaluateRules(
    ruleEvent,
    rules,
    { enabledAutomationKeys },
    profiles,
  );

  // If event was malformed (Req 3.9) — discard
  if (!evalResult.valid) {
    logger.error('[WhatsAppEngine] Event discarded by rule engine', {
      eventId,
      businessId,
      discardReason: evalResult.discardReason,
    });

    // Log suppression in delivery log
    await safeLogSuppression(tenantId, businessId, eventId, evalResult.discardReason || 'malformed_event');

    return {
      eventId,
      processed: true,
      enqueued: 0,
      skipped: 0,
      failed: 0,
      discardReason: evalResult.discardReason,
      outcomes: [],
    };
  }

  // Log suppressions from rule evaluation (consent blocks, branch mismatches)
  for (const suppression of evalResult.suppressions) {
    await safeLogSuppression(
      tenantId,
      businessId,
      suppression.recipientId,
      suppression.reason,
    );
  }

  // If no plans produced, nothing to enqueue
  if (evalResult.plans.length === 0) {
    logger.info('[WhatsAppEngine] No eligible recipients after rule evaluation', {
      eventId,
      businessId,
      suppressionCount: evalResult.suppressions.length,
    });
    return {
      eventId,
      processed: true,
      enqueued: 0,
      skipped: evalResult.suppressions.length,
      failed: 0,
      outcomes: evalResult.suppressions.map((s) => ({
        recipientId: s.recipientId,
        status: 'suppressed' as const,
        reason: s.reason,
      })),
    };
  }

  // ── Step 6: Process each OutboundPlan ─────────────────────────────────
  const outcomes: RecipientOutcome[] = [];
  let enqueued = 0;
  let skipped = evalResult.suppressions.length;
  let failed = 0;

  // Pre-fetch templates needed by all plans (deduplicate by templateId)
  const templateIds = Array.from(new Set(evalResult.plans.map((p) => p.templateId)));
  const templates = new Map<string, MessageTemplate>();
  for (const templateId of templateIds) {
    const template = await templateRepo.get(tenantId, businessId, templateId);
    if (template) {
      templates.set(templateId, template);
    }
  }

  for (const plan of evalResult.plans) {
    const outcome = await processPlan(
      tenantId,
      businessId,
      plan,
      templates,
      ruleEvent.payload,
    );
    outcomes.push(outcome);

    switch (outcome.status) {
      case 'enqueued':
        enqueued++;
        break;
      case 'duplicate':
        skipped++;
        break;
      case 'template_failed':
      case 'enqueue_failed':
        failed++;
        break;
    }
  }

  // Add suppression outcomes
  for (const suppression of evalResult.suppressions) {
    outcomes.push({
      recipientId: suppression.recipientId,
      status: 'suppressed',
      reason: suppression.reason,
    });
  }

  const elapsed = Date.now() - startTime;
  logger.info('[WhatsAppEngine] Event processing complete', {
    eventId,
    businessId,
    enqueued,
    skipped,
    failed,
    elapsedMs: elapsed,
  });

  return {
    eventId,
    processed: true,
    enqueued,
    skipped,
    failed,
    outcomes,
  };
}

// ── Plan Processing (per-recipient) ──────────────────────────────────────────

/**
 * Processes a single OutboundPlan: idempotency check → template render → enqueue.
 *
 * For each eligible recipient produced by the rule engine:
 * 1. Dedup check: has this (eventId, recipientId) already been processed?
 * 2. Template lookup: is the referenced template active and available?
 * 3. Template render: resolve all placeholders (fail-closed on missing)
 * 4. Durable enqueue: persist to DynamoDB + SQS before acknowledging
 */
async function processPlan(
  tenantId: string,
  businessId: string,
  plan: OutboundPlan,
  templates: Map<string, MessageTemplate>,
  eventPayload: Record<string, unknown>,
): Promise<RecipientOutcome> {
  const { eventId, recipientId, recipientNumber, templateId, schedule, branchId } = plan;

  // ── 6a. Idempotency check (Req 3.4, 9.3) ─────────────────────────────
  try {
    const idempResult = await checkAndMarkProcessed(
      tenantId,
      businessId,
      eventId,
      recipientId,
    );

    if (idempResult.status === 'duplicate') {
      logger.info('[WhatsAppEngine] Duplicate event+recipient — skipping', {
        eventId,
        recipientId,
        businessId,
      });
      return { recipientId, status: 'duplicate', reason: 'Already processed (idempotent)' };
    }
  } catch (err) {
    // Idempotency check failed (e.g., DynamoDB error). Fail closed — do not enqueue.
    const reason = err instanceof Error ? err.message : String(err);
    logger.error('[WhatsAppEngine] Idempotency check failed — fail closed', {
      eventId,
      recipientId,
      businessId,
      error: reason,
    });
    return { recipientId, status: 'enqueue_failed', reason: `Idempotency check error: ${reason}` };
  }

  // ── 6b. Template lookup ────────────────────────────────────────────────
  const template = templates.get(templateId);
  if (!template || template.status !== 'active') {
    const reason = template
      ? `Template '${templateId}' is inactive`
      : `Template '${templateId}' not found`;

    logger.error('[WhatsAppEngine] Template unavailable — suppressing send', {
      eventId,
      recipientId,
      templateId,
      businessId,
      reason,
    });

    // Log suppression in delivery log (Req 7.8)
    await safeLogSuppression(tenantId, businessId, recipientId, reason);
    return { recipientId, status: 'template_failed', reason };
  }

  // ── 6c. Template rendering (Req 7.3, 7.4, 13.6) ───────────────────────
  const templateInput: TemplateInput = {
    body: template.body,
    placeholders: template.placeholders,
  };

  const renderResult: RenderResult = render(templateInput, eventPayload);

  if (!renderResult.success) {
    const failure = renderResult as RenderFailure;
    logger.error('[WhatsAppEngine] Template render failed — suppressing send', {
      eventId,
      recipientId,
      templateId,
      businessId,
      error: failure.error,
      missingPlaceholders: failure.missingPlaceholders,
    });

    // Log suppression in delivery log (Req 7.4)
    await safeLogSuppression(tenantId, businessId, recipientId, failure.error);
    return { recipientId, status: 'template_failed', reason: failure.error };
  }

  // ── 6d. Durable enqueue (Req 9.1, 14.4, 14.7) ────────────────────────
  const enqueueInput: DurableEnqueueInput = {
    eventId,
    recipientId,
    recipientNumber, // MUST come from CustomerProfile (enforced by rule-engine)
    businessId,
    tenantId,
    templateId,
    templateVersion: template.currentVersion,
    renderedBody: renderResult.text,
    branchId,
    // If scheduled, the scheduler lambda handles the delay; the message is
    // still enqueued immediately with metadata for the scheduler to pick up.
    // Immediate messages go straight to the dispatch queue.
  };

  try {
    const enqueueResult: DurableEnqueueResult = await enqueueService.enqueue(enqueueInput);

    if (!enqueueResult.success) {
      const reason = enqueueResult.error?.reason || 'Unknown enqueue failure';
      logger.error('[WhatsAppEngine] Durable enqueue failed', {
        eventId,
        recipientId,
        businessId,
        stage: enqueueResult.error?.stage,
        reason,
      });
      return { recipientId, status: 'enqueue_failed', reason };
    }

    logger.info('[WhatsAppEngine] Message enqueued successfully', {
      eventId,
      recipientId,
      businessId,
      outboundMessageId: enqueueResult.message?.id,
    });

    return { recipientId, status: 'enqueued' };
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    logger.error('[WhatsAppEngine] Enqueue threw unexpectedly', {
      eventId,
      recipientId,
      businessId,
      error: reason,
    });
    return { recipientId, status: 'enqueue_failed', reason };
  }
}

// ── Event Extraction ──────────────────────────────────────────────────────────

/**
 * Extracts and validates the Business_Event from the EventBridge envelope.
 * Returns null if the event is malformed or missing required fields.
 */
function extractBusinessEvent(
  ebEvent: EventBridgeEvent,
): {
  eventId: string;
  businessId: string;
  tenantId: string;
  eventType: string;
  businessType: string;
  tier: string;
  branchId?: string;
  payload: Record<string, unknown>;
} | null {
  if (!ebEvent || typeof ebEvent !== 'object') {
    return null;
  }

  const detail = ebEvent.detail;
  if (!detail || typeof detail !== 'object') {
    return null;
  }

  const { eventId, businessId, tenantId, eventType, payload } = detail;

  // Required fields (Req 3.9: malformed events are discarded)
  if (!eventId || typeof eventId !== 'string' || eventId.trim().length === 0) return null;
  if (!businessId || typeof businessId !== 'string' || businessId.trim().length === 0) return null;
  if (!tenantId || typeof tenantId !== 'string' || tenantId.trim().length === 0) return null;
  if (!eventType || typeof eventType !== 'string' || eventType.trim().length === 0) return null;
  if (!payload || typeof payload !== 'object') return null;

  return {
    eventId,
    businessId,
    tenantId,
    eventType,
    businessType: detail.businessType || '',
    tier: detail.tier || 'basic',
    branchId: detail.branchId,
    payload: payload as Record<string, unknown>,
  };
}

// ── Delivery Log Helpers ──────────────────────────────────────────────────────

/**
 * Safely log a suppression/failure to the Delivery_Log.
 * Does not throw — failures to write the log are non-fatal.
 */
async function safeLogSuppression(
  tenantId: string,
  businessId: string,
  outboundMessageId: string,
  reason: string,
): Promise<void> {
  try {
    await deliveryLogRepo.create(tenantId, businessId, {
      outboundMessageId,
      state: 'suppressed',
      reason,
    });
  } catch (err) {
    // Log write failure is non-fatal — the pipeline continues
    logger.warn('[WhatsAppEngine] Failed to write delivery log suppression entry', {
      businessId,
      tenantId,
      outboundMessageId,
      reason,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}
