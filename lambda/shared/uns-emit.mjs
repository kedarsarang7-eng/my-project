/**
 * lambda/shared/uns-emit.mjs
 *
 * Tiny, dependency-free UNS Event_Contract emitter for the `.mjs` lambdas
 * (trial provisioning, trial scheduler, trial expiry cron, etc.) that live
 * outside the `my-backend` TypeScript project and therefore cannot import
 * `my-backend/src/notifications/event-bus`.
 *
 * Behaviour:
 *   - Builds an Event_Contract envelope with the same field shape as
 *     `packages/notifications-sdk/event-contract.schema.json`.
 *   - Generates `id`, `created_at`, and a sha256 `dedup_key` over
 *     `(event_name, actor_id, target_id, dedup_scope_fields...)` so the
 *     server-side `by-dedup-key` GSI lookup works the same as for backend
 *     producers.
 *   - Publishes to `UNS_SNS_TOPIC_ARN` (the canonical UNS topic). If the
 *     env var is not set the emit is silently dropped — these handlers
 *     can run in environments that don't have UNS wired up yet.
 *   - Errors are caught and logged; they do NOT throw to the caller. This
 *     matches the fire-and-forget contract that backend producers use
 *     for their `wsService.emitEvent(...).catch(...)` calls.
 *
 * Validates: REQ 10.7, REQ 10.8, REQ 19.5 — the trial Lambdas (T-PLN-1,
 * T-PLN-2, T-PLN-3) emit a canonical UNS envelope alongside their
 * existing `SNS_TRIAL_TOPIC_ARN` publish during the migration window.
 */

import { randomUUID, createHash } from 'crypto';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

const sns = new SNSClient({});
const UNS_TOPIC_ARN = process.env.UNS_SNS_TOPIC_ARN;

/**
 * Compute the canonical dedup_key — must match
 * `my-backend/src/notifications/service/dedup.ts::computeDedupKey`.
 */
function computeDedupKey({ event_name, actor_id, target_id, dedup_scope_fields, payload }) {
  const SEP = '\x1f';
  const parts = [event_name, actor_id, target_id ?? ''];
  if (Array.isArray(dedup_scope_fields) && dedup_scope_fields.length > 0) {
    const p = payload ?? {};
    for (const field of dedup_scope_fields) {
      const raw = p[field];
      const serialized = serializeScopeValue(raw);
      parts.push(`${field}=${serialized}`);
    }
  }
  return createHash('sha256').update(parts.join(SEP)).digest('hex');
}

function serializeScopeValue(v) {
  if (v === null || v === undefined) return '';
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  try { return JSON.stringify(v); } catch { return String(v); }
}

/**
 * Build an Event_Contract envelope.
 */
export function buildUnsEnvelope({
  eventName,
  category,
  subCategory,
  priority,
  actorId,
  targetId,
  recipients,
  payload,
  channels,
  sourceModule,
  sourceApp = 'dukanx_backend',
  dedupScopeFields,
}) {
  const dedupKey = computeDedupKey({
    event_name: eventName,
    actor_id: actorId,
    target_id: targetId ?? null,
    dedup_scope_fields: dedupScopeFields,
    payload,
  });

  return {
    id: randomUUID(),
    event_name: eventName,
    category,
    sub_category: subCategory,
    priority,
    actor_id: actorId,
    target_id: targetId ?? null,
    recipients: (recipients || []).map((r) => ({
      user_id: r.user_id,
      role: r.role,
      ...(r.channels ? { channels: r.channels } : {}),
      ...(r.target_id !== undefined ? { target_id: r.target_id } : {}),
    })),
    payload: { ...(payload || {}) },
    channels: (channels && channels.length > 0) ? [...channels] : ['in_app'],
    source_module: sourceModule,
    source_app: sourceApp,
    created_at: new Date().toISOString(),
    dedup_key: dedupKey,
    ...(dedupScopeFields ? { dedup_scope_fields: [...dedupScopeFields] } : {}),
  };
}

/**
 * Publish a UNS event to the canonical topic. Fire-and-forget;
 * errors are logged but never thrown.
 */
export async function emitUnsEvent(input) {
  if (!UNS_TOPIC_ARN) {
    // UNS topic not configured in this environment — silently skip.
    return;
  }
  let envelope;
  try {
    envelope = buildUnsEnvelope(input);
  } catch (e) {
    console.warn('[UNS] buildUnsEnvelope failed:', e?.message ?? e);
    return;
  }

  try {
    await sns.send(new PublishCommand({
      TopicArn: UNS_TOPIC_ARN,
      Message: JSON.stringify(envelope),
      MessageAttributes: {
        event_name: { DataType: 'String', StringValue: envelope.event_name },
        priority: { DataType: 'String', StringValue: envelope.priority },
        delivery_mode: {
          DataType: 'String',
          StringValue:
            envelope.priority === 'critical' || envelope.priority === 'high'
              ? 'at_least_once'
              : 'at_most_once_with_dedup',
        },
        source_app: { DataType: 'String', StringValue: envelope.source_app },
        dedup_key: { DataType: 'String', StringValue: envelope.dedup_key },
      },
    }));
  } catch (e) {
    console.warn('[UNS] SNS publish failed:', e?.message ?? e, {
      eventId: envelope?.id,
      eventName: envelope?.event_name,
    });
  }
}
