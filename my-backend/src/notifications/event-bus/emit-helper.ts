// ============================================================================
// UNS Event_Bus — Producer Emit Helper
// ============================================================================
// Thin convenience wrapper around `publishEvent(...)` for backend Producers
// (handlers/lambdas) that are being migrated from `wsService.emitEvent`/
// `wsService.broadcastToBusiness` etc. to the canonical UNS bus.
//
// This helper exists to keep the migration of every Trigger_Point in
// task 14.9 a small, repeatable diff:
//
//   import { emitUnsEvent } from '../notifications/event-bus/emit-helper';
//   ...
//   emitUnsEvent({
//     eventName: 'billing.invoice.created',
//     category: 'billing',
//     priority: 'normal',
//     actorId: auth.sub,
//     targetId: result.id,
//     recipients: [{ user_id: auth.tenantId, role: 'admin' }],
//     payload: { invoiceId: result.id, ... },
//     sourceModule: 'my-backend/src/handlers/invoices.ts',
//   }).catch(() => { /* non-fatal */ });
//
// Behaviour:
//   - Generates a fresh UUID v4 and ISO-8601 `created_at`.
//   - Computes the canonical `dedup_key` via `computeDedupKey(...)`.
//   - Defaults `channels` to `['in_app']` (the conservative choice for
//     transparent migration — preserves the legacy WS-only delivery
//     surface; per-event registry channel overrides land later).
//   - Defaults `sourceApp` to `dukanx_backend`.
//   - Catches Event_Contract validation and SNS-unavailable errors and
//     logs them as warnings — emit failures must NEVER break the calling
//     handler's business flow during the migration window. This matches
//     the existing `wsService.emitEvent(...).catch(...)` pattern that
//     producers already use.
//
// Note on triple validation: payloads are validated by the SDK
// (`schema_validator.dart`), again at the bus publisher
// (`schema-validator.ts`), and a third time at the Notification_Service
// surface. This is INTENTIONAL defense-in-depth — REQ 16.3 explicitly
// names producer + bus + consumer as three independent gates so a
// schema-rolled-out producer cannot persist garbage if the bus is in a
// rolling-update window where the new schema hasn't reached every Lambda.
//
// The legacy emit (`wsService.emitEvent` / `wsService.broadcastToBusiness`)
// is intentionally kept alongside the new emit during the rollout window
// so that connected DukanX desktop clients on older builds keep working.
// `migration_status.md` flips each row to `uns` when the equivalence test
// for that producer commits.
//
// Validates: REQ 10.7 (single canonical path per Trigger_Point at any time),
//            REQ 10.8 (Trigger_Points wired through Notification_Service),
//            REQ 19.5 (single active path invariant).
// ============================================================================

import { randomUUID } from 'crypto';
import { logger } from '../../utils/logger';
import { computeDedupKey } from '../service/dedup';
import { publishEvent } from './publisher';
import {
    EventBusUnavailableError,
    EventContractValidationError,
    ProducerRateLimitExceededError,
} from './errors';
import type {
    Category,
    Channel,
    EventContract,
    Priority,
    Recipient,
    SourceApp,
} from './types';

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

export interface EmitUnsEventInput {
    /** Canonical registry-defined event name (`<domain>.<entity>.<action>`). */
    readonly eventName: string;
    /** Top-level category — must match the registry row. */
    readonly category: Category;
    /** Sub-category (`invoice`, `kot`, `attendance`, ...). Optional. */
    readonly subCategory?: string;
    /** Priority tier — drives the delivery mode and quiet-hours behaviour. */
    readonly priority: Priority;
    /** ID of the user / system component that triggered the event. */
    readonly actorId: string;
    /** Domain object ID this event is about (invoice_id, order_id, ...). */
    readonly targetId?: string | null;
    /** Resolved recipients. The Notification_Service re-authorizes each. */
    readonly recipients: readonly Recipient[];
    /** Event payload (JSON-serialisable record). */
    readonly payload: Record<string, unknown>;
    /** Channels to deliver on. Defaults to `['in_app']`. */
    readonly channels?: readonly Channel[];
    /** Canonical workspace path of the producing module. */
    readonly sourceModule: string;
    /** Source app — defaults to `dukanx_backend` for backend producers. */
    readonly sourceApp?: SourceApp;
    /** Ordered list of payload field names that participate in dedup_key. */
    readonly dedupScopeFields?: readonly string[];
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Build an `EventContract` envelope from the given inputs.
 *
 * Exposed separately from `emitUnsEvent` so callers that need to inspect
 * the envelope (e.g. logging, batching, tests) can do so without tripling
 * the publish surface.
 */
export function buildEventContract(input: EmitUnsEventInput): EventContract {
    const channels: Channel[] = (input.channels && input.channels.length > 0)
        ? [...input.channels]
        : ['in_app'];

    const dedupKey = computeDedupKey({
        event_name: input.eventName,
        actor_id: input.actorId,
        target_id: input.targetId ?? null,
        dedup_scope_fields: input.dedupScopeFields,
        payload: input.payload,
    });

    return {
        id: randomUUID(),
        event_name: input.eventName,
        category: input.category,
        sub_category: input.subCategory,
        priority: input.priority,
        actor_id: input.actorId,
        target_id: input.targetId ?? null,
        recipients: input.recipients.map((r) => ({
            user_id: r.user_id,
            role: r.role,
            channels: r.channels ? [...r.channels] : undefined,
            target_id: r.target_id ?? undefined,
        })),
        payload: { ...input.payload },
        channels,
        source_module: input.sourceModule,
        source_app: input.sourceApp ?? 'dukanx_backend',
        created_at: new Date().toISOString(),
        dedup_key: dedupKey,
        dedup_scope_fields: input.dedupScopeFields ? [...input.dedupScopeFields] : undefined,
    };
}

/**
 * Publish a UNS event. Errors are caught and logged — they DO NOT propagate
 * to the caller. This is intentional: every backend producer in task 14.9
 * already wraps its legacy `wsService.emitEvent(...)` call in `.catch(...)`
 * so that a transport failure cannot break the business flow. The UNS
 * emit must obey the same "fire-and-forget on the hot path" contract.
 *
 * Producers that need stronger guarantees (e.g. critical events that must
 * be persisted before the HTTP 200 returns) should call `publishEvent`
 * directly and decide their own error handling.
 */
export async function emitUnsEvent(input: EmitUnsEventInput): Promise<void> {
    let envelope: EventContract;
    try {
        envelope = buildEventContract(input);
    } catch (err) {
        logger.warn('[UNS] buildEventContract failed — dropping emit', {
            eventName: input.eventName,
            error: err instanceof Error ? err.message : String(err),
        });
        return;
    }

    try {
        await publishEvent(envelope);
    } catch (err) {
        if (err instanceof ProducerRateLimitExceededError) {
            // REQ 12.4 floods are recorded once at the publisher boundary;
            // here we degrade to a debug-level note so a misbehaving caller
            // does not also flood the warn-stream from this layer. The
            // original warn line in `publisher.ts` is the canonical record.
            logger.debug('[UNS] Emit dropped — Producer publish rate limit hit', {
                eventName: input.eventName,
                eventId: envelope.id,
                producerId: err.producerId,
                retryAfterMs: err.retryAfterMs,
            });
            return;
        }
        if (err instanceof EventContractValidationError) {
            logger.warn('[UNS] Event_Contract validation failed — emit dropped', {
                eventName: input.eventName,
                eventId: envelope.id,
                issues: err.issues,
            });
            return;
        }
        if (err instanceof EventBusUnavailableError) {
            logger.warn('[UNS] Event_Bus unavailable — emit dropped (no outbox configured for handler)', {
                eventName: input.eventName,
                eventId: envelope.id,
                error: err.message,
            });
            return;
        }
        logger.warn('[UNS] Event_Bus publish failed', {
            eventName: input.eventName,
            eventId: envelope.id,
            error: err instanceof Error ? err.message : String(err),
        });
    }
}
