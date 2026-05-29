// ============================================================================
// UNS Event_Bus — Shared Types
// ============================================================================
// TypeScript types for the canonical Event_Contract envelope and supporting
// publish/consume primitives. The Event_Contract envelope mirrors
// `packages/notifications-sdk/event-contract.schema.json` field-for-field so
// the JSON Schema is the single source of truth at runtime (see schema-validator.ts).
//
// Validates: REQ 3.2, 3.6 (envelope structure), 8.1 (single event contract),
//            9.1, 9.2 (delivery modes per priority).
// ============================================================================

/**
 * Channel literals supported by the Delivery_Layer (REQ 5.1-5.5).
 */
export type Channel = 'in_app' | 'push' | 'sms' | 'email' | 'webhook';

/**
 * Priority tier (REQ 9.1, 9.2). Drives the delivery mode chosen by the
 * Event_Bus and the critical-bypass rule of the Preference_Engine.
 */
export type Priority = 'critical' | 'high' | 'normal' | 'low';

/**
 * Delivery mode applied per priority tier (REQ 9.1, 9.2).
 *  - `at_least_once` for `critical`/`high`
 *  - `at_most_once_with_dedup` for `normal`/`low`
 *
 * The actual deduplication (the "with_dedup" half) is performed by the
 * Notification_Service via the `by-dedup-key` GSI lookup, not by the
 * Event_Bus itself. The Event_Bus only tags messages with the chosen mode.
 */
export type DeliveryMode = 'at_least_once' | 'at_most_once_with_dedup';

/**
 * Top-level domain bucket (REQ 2.3).
 */
export type Category =
    | 'billing'
    | 'orders'
    | 'payments'
    | 'inventory'
    | 'users'
    | 'system'
    | 'delivery'
    | 'reports';

/**
 * Source app identifiers — the workspace app the event originated from
 * (Phase 2 §2). Used to attribute events for the metric label
 * `events_emitted_total{source_app}` (REQ 14.2).
 */
export type SourceApp =
    | 'dukanx_desktop'
    | 'dukanx_backend'
    | 'school_admin_app'
    | 'school_teacher_app'
    | 'school_student_app'
    | 'webhook_consumer';

/**
 * Recipient role inventory (Phase 2 §3).
 */
export type RecipientRole =
    | 'super_admin'
    | 'admin'
    | 'shop_owner'
    | 'cashier'
    | 'accountant'
    | 'staff'
    | 'delivery_agent'
    | 'vendor'
    | 'customer'
    | 'chef'
    | 'kitchen_staff'
    | 'waiter'
    | 'school_admin'
    | 'teacher'
    | 'student'
    | 'parent'
    | 'clinic_doctor'
    | 'pharmacist'
    | 'jewellery_artisan'
    | 'service_technician'
    | 'dc_staff'
    | 'farmer'
    | 'pump_attendant';

/**
 * A single resolved recipient on the event envelope.
 * The Notification_Service re-authorizes every recipient at dispatch time
 * (REQ 4.11) and silently omits unauthorized entries.
 */
export interface Recipient {
    user_id: string;
    role: RecipientRole;
    /** Optional per-recipient channel override; falls back to envelope `channels`. */
    channels?: Channel[];
    /** Optional per-recipient target override; falls back to envelope `target_id`. */
    target_id?: string | null;
}

/**
 * The canonical Event_Contract envelope.
 * Every Producer publishes objects of this shape; every Consumer receives
 * objects of this shape after Ajv validation against the JSON Schema.
 */
export interface EventContract {
    /** UUID v4. Producers MUST generate client-side so outbox replays preserve identity. */
    id: string;
    /** snake_case `<domain>.<entity>.<action>` (REQ 2.6). */
    event_name: string;
    category: Category;
    sub_category?: string;
    priority: Priority;
    actor_id: string;
    target_id?: string | null;
    recipients: Recipient[];
    payload: Record<string, unknown>;
    channels: Channel[];
    /** Canonical workspace path of the producing module. */
    source_module: string;
    source_app: SourceApp;
    /** RFC 3339 / ISO 8601 with explicit UTC offset (e.g. '2025-01-31T14:23:45.123Z'). */
    created_at: string;
    /** Deterministic hash over (event_name, actor_id, target_id, dedup_scope_fields). */
    dedup_key: string;
    /** Ordered list of payload field names that participated in dedup_key. */
    dedup_scope_fields?: string[];
}

/**
 * A field-level validation issue surfaced by Ajv.
 */
export interface ValidationIssue {
    /** JSON Pointer or dotted path of the offending field. */
    field: string;
    /** Human-readable description of the violation. */
    message: string;
    /** Optional schema keyword that failed (e.g. 'required', 'enum', 'pattern'). */
    keyword?: string;
}

/**
 * Per-event failure entry returned by `publishBatch`.
 */
export interface PublishFailure {
    /** Index of the offending event in the input batch. */
    index: number;
    /** Event id, when available. */
    eventId?: string;
    /** Error code: `validation_error` | `publish_error` | `outbox_buffered` | `rate_limited`. */
    code: 'validation_error' | 'publish_error' | 'outbox_buffered' | 'rate_limited';
    /** Human-readable failure message. */
    message: string;
    /** Validation issues, when `code === 'validation_error'`. */
    issues?: ValidationIssue[];
    /** Producer identifier, when `code === 'rate_limited'`. */
    producerId?: string;
    /** Suggested cool-off in ms before retry, when `code === 'rate_limited'`. */
    retryAfterMs?: number;
}

/**
 * Successful publish acknowledgement.
 * Returned only after SNS has durably persisted the message (REQ 3.3).
 */
export interface PublishAck {
    /** SNS-assigned message id. */
    messageId: string;
}

/**
 * Bus-level message attributes attached to every SNS publish.
 * SQS preserves these attributes on consume so subscribers can route on them
 * without re-parsing the payload body.
 */
export interface BusMessageAttributes {
    event_name: string;
    priority: Priority;
    delivery_mode: DeliveryMode;
    source_app: SourceApp;
    dedup_key: string;
}

/**
 * Outbox entry persisted while the Event_Bus is unavailable (REQ 9.7).
 * Replayed in `created_at` ascending order on recovery.
 */
export interface OutboxEntry {
    /** Same id as the event so replays remain idempotent. */
    id: string;
    /** Full Event_Contract serialized as a JSON string for forward-compatible storage. */
    payload: string;
    /** Created-at copy from the event for replay ordering. */
    created_at: string;
    /** When the entry was buffered into the outbox. */
    buffered_at: string;
    /** Last error that caused the outbox write, for operator triage. */
    last_error?: string;
    /** Optional retry counter incremented on each failed flush attempt. */
    retry_count?: number;
}
