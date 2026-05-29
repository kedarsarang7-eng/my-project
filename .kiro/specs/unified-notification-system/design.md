# Design Document — Unified Notification System (UNS)

> Slim, high-level design pass. Detailed schemas, per-channel rate-limit tables, full Event_Contract JSON Schema, and per-helper migration mapping are explicitly deferred — see "Out of Scope for This Design Pass" at the end.

## Overview

The Unified Notification System (UNS) is the single, real-time notification platform for DukanX (Flutter desktop) and every connected sub-app (school_admin_app, school_student_app, school_teacher_app, archived restaurant POS/chef apps, future sub-apps). It replaces the fragmented per-feature helpers (`service_job_notification_service`, `restaurant_notification_service`, `security_notification_service`, `customer_notifications_repository`, `ac_notifications_screen`, `school-notifications.ts`, etc.) with one canonical pipeline:

producers → Event_Bus → Notification_Service → Preference_Engine → Delivery_Layer → recipients, backed by a Notification_Store and exposed to sub-apps through a Sub_App_Sync_Layer and a Shared_SDK.

### Design goals (traced to requirements)

- **One canonical pipeline** — no parallel notification paths (REQ 3.1, REQ 19.4, REQ 20.1).
- **Reliability per priority tier** — `at_least_once` for `critical`/`high`, `at_most_once_with_dedup` for `normal`/`low` (REQ 3.7-3.8, REQ 9.1-9.2).
- **No event loss across restart** — durability is a hard invariant (REQ 3.5, REQ 9.8).
- **User control without overload** — preferences, quiet hours, mute, fatigue suppression (REQ 7, REQ 9.5-9.6).
- **Cross-app parity** — same SDK, same contract, same UI widgets in every Flutter app (REQ 8, REQ 11).
- **Performance at 10k concurrent users** — 500 ms p95 in-app delivery, 50 ms p95 unread count, 100 ms unread-count projection update (REQ 5.7, REQ 6.7, REQ 13).
- **Observability + audit** — full lifecycle log, metrics, append-only Audit_Log (REQ 12.5-12.6, REQ 14).
- **Reuse existing infra** — same JWT, same DynamoDB account/region, same API Gateway as `my-backend/` (REQ 19).

## Architecture

```mermaid
flowchart LR
  subgraph Producers
    DX[DukanX feature modules]
    SA[Sub-apps<br/>school_admin / student / teacher]
    BE[Backend Lambdas<br/>my-backend / voice-backend / lambda]
  end

  subgraph UNS_Core
    EB[Event_Bus<br/>SNS + SQS]
    NS[Notification_Service<br/>createNotification · dispatch · markAsRead · prefs · replay]
    PE[Preference_Engine]
    DL[Delivery_Layer<br/>channel adapters]
    NSTORE[(Notification_Store<br/>DynamoDB)]
    SYNC[Sub_App_Sync_Layer<br/>JWT · ack · replay]
    DLQ[(DLQ)]
  end

  subgraph Channels
    INAPP[in-app<br/>WebSocket / SSE]
    PUSH[push<br/>FCM]
    EMAIL[email<br/>SMTP]
    SMS[sms<br/>Twilio]
    HOOK[webhook<br/>signed HTTPS]
  end

  subgraph Recipients
    USER[Users<br/>admin · cashier · teacher · student · …]
    EXT[External webhook consumers]
  end

  SDK[/Shared_SDK<br/>@dukanx/notifications/]

  DX -->|emit| SDK
  SA -->|emit| SDK
  BE -->|emit| EB
  SDK -->|publish| EB
  EB --> NS
  NS <--> NSTORE
  NS --> PE
  PE --> NS
  NS --> DL
  DL --> INAPP --> USER
  DL --> PUSH --> USER
  DL --> EMAIL --> USER
  DL --> SMS --> USER
  DL --> HOOK --> EXT
  NS -. retries exhausted .-> DLQ
  SYNC <-->|connect · ack · replay| SDK
  SYNC <--> NS
```

The diagram shows producers on the left, the UNS core in the middle, channel adapters in the Delivery_Layer, and recipients on the right. The Shared_SDK is the only contact surface for Flutter apps. Backend Lambdas may publish directly to the Event_Bus.

## Components and Interfaces

### Event_Bus

The single asynchronous transport that every producer publishes to and every internal consumer subscribes to. Owns durability, ordering, retry semantics, and DLQ routing. Validates every payload against the Event_Contract before accepting a publish (REQ 3.6) and persists durably before acknowledging (REQ 3.3).

### Notification_Service

The brain. Owns notification creation, recipient resolution, deduplication, persistence, and the dispatch decision. Consumes events from the Event_Bus, calls the Preference_Engine for each prospective recipient, and forwards to the Delivery_Layer per enabled channel. Records every lifecycle transition in the Audit_Log.

### Preference_Engine

A pure resolver that, given a notification and a recipient, returns the allowed channel set. Applies per-event channels, per-category channels, role defaults, system defaults, quiet hours, mute targets, actor-equals-recipient suppression, and the critical-bypass rule. Targets <10 ms p95 (REQ 7.8). Stateless apart from reading `UserPreference` records.

### Delivery_Layer

A thin façade over five pluggable channel adapters (`in-app`, `push`, `email`, `sms`, `webhook`). Each adapter owns its transport-specific retry/backoff, rate limit, and authentication. Adapters are isolated so a failure in one (e.g. SMTP outage) does not block the others.

### Notification_Store

DynamoDB-backed persistent store for `Notification`, `UserPreference`, and `AuditLog` records. Provides cursor-based pagination, the unread-count projection, and the GSIs needed for the front-end's three primary access patterns.

### Sub_App_Sync_Layer

The cross-app integration surface. Authenticates sub-app connections with JWT, requires per-`notification_id` ack within 30 s (REQ 8.3), exposes the `GET /notifications/replay` endpoint, and bounds replays by the configured Replay_Window.

### Shared_SDK (`@dukanx/notifications`)

The single client package consumed by DukanX and every sub-app. Exposes `subscribe`, `emit`, `onNotification`, `replay`. Owns the offline outbox: while disconnected the SDK queues emitted events locally and flushes them in `created_at` ascending order on next successful connect (REQ 8.8).

## Event_Bus Selection

**Chosen: Amazon SNS + SQS** (REQ 3.1).

Rationale matched to the existing stack:

- The backend already runs on **AWS Lambda + DynamoDB** under `my-backend/`, `voice-backend/`, and `lambda/`. SNS+SQS is the native fit — no new infrastructure to operate, no separate cluster, no fresh ops burden.
- **SQS provides durable persistence and at-least-once delivery natively** (covers REQ 3.3, REQ 3.5, REQ 9.1) with built-in visibility-timeout-driven retry and a managed DLQ (REQ 3.10, REQ 9.3).
- **SNS fan-out** maps cleanly to the producer→multi-consumer pattern needed for in-app realtime, push, email, sms, and webhook adapters running in parallel.
- **Per-Lambda IAM policies** plug into the existing JWT/role infrastructure for per-Producer authentication (REQ 12.3).
- Rejected alternatives (recorded here only as a one-liner; a longer rationale belongs in the future Phase 3 architecture artifact):
  - Apache Kafka — operationally heavy for a workspace already on managed AWS.
  - Redis Pub/Sub — no durable persistence; loses events on restart, which directly violates REQ 3.5 and REQ 9.8.
  - BullMQ — requires Redis, and is a job-queue model rather than a pub/sub bus.

## Notification_Service API Surface

Method names and one-line purposes only. Parameter and response schemas are deferred (see Out of Scope).

- `createNotification(event)` — validate, resolve dedup key, persist a `Notification` record with status `emitted`, return `notification_id`.
- `dispatch(notification_id)` — resolve recipients, run Preference_Engine, run deduplication step, forward to enabled channel adapters, transition lifecycle to `dispatched`.
- `markAsRead(notification_id, user_id)` — set per-recipient `read_at` once; subsequent calls are no-ops (idempotent, REQ 4.6).
- `getUserPreferences(user_id)` — return resolved preferences and quiet-hours config.
- `setUserPreferences(user_id, preferences)` — validate and persist atomically; same-payload writes are idempotent (REQ 4.9, REQ 7.7).
- `getReplay(since, app)` — return notifications targeted at users of the given sub-app with `created_at >= since`, bounded by the Replay_Window.

## Reliability Tiers and Deduplication

- `critical` and `high` priority events use **at_least_once** delivery (REQ 9.1). Combined with deduplication at the recipient, the effective semantic is exactly-once-per-recipient.
- `normal` and `low` priority events use **at_most_once_with_dedup** (REQ 9.2).
- The **Deduplication_Key** is the deterministic tuple `(event_name, actor_id, target_id, dedup_scope_fields)`; `dedup_scope_fields` is declared per event in the Notification_Event_Registry.
- The **Deduplication_Window** defaults to **60 s** (REQ glossary), overridable per event.
- A failed delivery on any channel is retried with exponential backoff up to **5 attempts**; on exhaustion the event moves to the **DLQ** with original payload, last error, retry count, and timestamps preserved (REQ 3.9-3.10, REQ 9.3). The DLQ is operator-replayable (REQ 9.4).
- If the Event_Bus is unavailable at publish time, the producing service buffers in a **local outbox** and replays in order on recovery (REQ 9.7).

## Preference Resolution Order

For each recipient and each channel, evaluation proceeds in this strict order until one rule yields a decision:

1. **`per_event_channels`** for the notification's `event_name` — wins if set; ignores per-category for that event (REQ 7.2).
2. **`per_category_channels`** for the notification's `category` (REQ 7.2a).
3. **Role-level default** channel set for the recipient's role.
4. **System default** channel set.

Then, regardless of which level matched:

- **Quiet_Hours rule** — while the recipient's local time is inside their quiet-hours range, suppress `push`, `sms`, and `email` for any non-`critical` notification (REQ 7.3).
- **Critical bypass** — `priority == critical` overrides quiet hours and reaches every channel the recipient supports (REQ 7.4).
- **Mute behavior** — if the recipient has muted the notification's `target_id` (or `event_name` where the registry permits), suppress on every channel; mutes are overridable only by `critical` events the registry explicitly marks un-mutable (REQ 7.6, glossary `Mute`).
- **Self-suppression** — if `actor_id == recipient.user_id`, suppress (REQ 7.5).

## Channel Adapters

- **in-app** — WebSocket or SSE. Authenticated with the existing JWT. Persists for offline recipients and replays on reconnect, in order, requiring per-`notification_id` ack before marking `delivered` (REQ 5.1, 5.6, 5.8).
- **push** — Firebase Cloud Messaging. Up to 3 retries with exponential backoff on transient errors (REQ 5.2, 5.9).
- **email** — SMTP. Up to 3 retries with exponential backoff on transient SMTP errors (REQ 5.3, 5.10).
- **sms** — Twilio (or env-configured equivalent). Up to 3 retries with exponential backoff (REQ 5.4, 5.11).
- **webhook** — signed HTTPS POST with `X-Signature` header computed from a per-consumer shared secret; up to 5 retries before DLQ (REQ 5.5, 5.12-5.13).

## Data Models

### Notification_Store (conceptual)

Three logical tables/collections:

- **Notification** — one record per notification (lifecycle, recipients, payload, channels, dedup_key, source).
- **UserPreference** — one record per user (per-event, per-category, quiet hours, mutes, role, version).
- **AuditLog** — append-only, one record per lifecycle transition.

Three required access patterns / GSIs (named only; full key/sort/projection details deferred):

- **`by-user-status`** — supports the unread-list query for a recipient (REQ 6.4).
- **`by-user-category`** — supports filtered history per user per category (REQ 6.5).
- **`by-dedup-key`** — supports constant-time deduplication lookups (REQ 6.6).

**Lifecycle ordering invariant:** every `Notification` record at all times satisfies

```
created_at ≤ dispatched_at ≤ delivered_at ≤ read_at
```

with `null` allowed for any unset trailing timestamp. State transitions that would violate the ordering are rejected with a structured error (REQ 6.7a). Records are retained for the Archive_Period (default 90 days) and then moved to cold storage (REQ 6.8).

## Sub_App_Sync_Layer and Shared_SDK

**Sub_App_Sync_Layer.** Sub-apps connect over the in-app channel using a JWT bearer token issued by the Backend's existing auth service (REQ 8.2, REQ 19.1). Every dispatched notification requires the sub-app to ack by `notification_id` within 30 s; missing acks trigger a retry under the channel's policy (REQ 8.3). The replay endpoint `GET /notifications/replay?since=<ISO_DATE>&app=<sub_app_name>` returns notifications targeted at users of that sub-app with `created_at >= since`, in `created_at` ascending order, bounded by the **Replay_Window default of 7 days** (REQ 8.4-8.5a). Out-of-window requests fail with a structured `replay_window_exceeded` error.

**Shared_SDK (`@dukanx/notifications`).** The single client package; methods listed by name only:

- `subscribe(eventName, handler)`
- `emit(event)`
- `onNotification(handler)`
- `replay(sinceIso)`

The SDK owns the offline outbox (queues emits locally while disconnected and flushes in `created_at` order on reconnect, REQ 8.8) and powers the shared UI widgets (bell, drawer, toast, preferences page) referenced in REQ 11.

## Security Model

End-user requests authenticate with the same **JWT** mechanism used by DukanX and existing sub-app APIs (REQ 19.1). Sub-apps and external producers connect to the Event_Bus / Notification_Service with JWT or an environment-scoped shared secret; failed auth is rejected (REQ 12.3). Webhook deliveries carry an **`X-Signature`** header computed over the payload from a per-consumer shared secret (REQ 5.12). On every dispatch the Notification_Service runs a **per-recipient authorization check** against the existing RBAC rules using `(event_name, target_id)`; recipients that fail are silently omitted from the dispatch (REQ 4.11, REQ 12.1). All payloads are sanitized before persistence and delivery (REQ 12.2). Per-Producer publish rate limit defaults to 1000 events/minute, evaluated independently of authorization (REQ 12.4). Secrets, full PAN, and full government IDs never appear in payloads — redacted references only (REQ 12.8).

## Performance and Observability

**Performance.** The system targets **10 000 concurrent in-app connections** with **500 ms p95** end-to-end in-app delivery (REQ 5.7, REQ 13.3), **50 ms p95** unread-count queries, **200 ms p95** cursor-paginated history queries returning up to 50 records (REQ 13.1-13.2), and **100 ms** unread-count projection update on a `delivered` or `read` transition under nominal load (REQ 6.7). The Preference_Engine targets <10 ms p95 (REQ 7.8). Capacity is verified with a load-test plan covering 100, 1000, and 10 000 concurrent users with availability >99.9% and zero event loss across that full range (REQ 13.5-13.6).

**Observability.** Every lifecycle transition (`emitted`, `queued`, `dispatched`, `delivered`, `read`, `failed`) emits a structured log line carrying `notification_id`, `event_name`, `recipient_id`, `channel`, and `timestamp` (REQ 14.1). The metrics surface includes `events_emitted_total`, `notifications_dispatched_total`, `notifications_failed_total`, and `delivery_latency_ms` (histogram with rolling p95). A high-failure-rate alert fires when the rolling 5-minute failure ratio exceeds 5% with at least one dispatch in the window (REQ 14.6). The Audit_Log is append-only and is the system of record for every lifecycle transition and every denied access attempt (REQ 12.5-12.7).

## Error Handling

- **Schema-invalid publishes** are rejected at the Event_Bus boundary with a structured validation error; nothing is persisted, nothing is delivered (REQ 3.6, REQ 8.7).
- **Transient channel failures** are retried per channel policy (3 retries for push/email/sms, 5 for webhook); on exhaustion the event lands in the DLQ (REQ 5.9-5.13, REQ 9.3).
- **Notification_Service authorization failures** at `createNotification` reject without persisting; per-recipient authorization failures at `dispatch` silently omit only the failing recipient (REQ 4.10-4.11).
- **Out-of-order lifecycle transitions** are rejected to preserve the ordering invariant (REQ 6.7a).
- **Audit_Log unavailability** at the time of a retention configuration change causes the change to be rejected, leaving the previous Archive_Period in effect (REQ 13.4a).
- **Event_Bus unavailability** at publish time causes the producing service to buffer in its local outbox and replay in order on recovery (REQ 9.7).
- **DLQ entries** are inspectable and replayable through an operator endpoint (REQ 9.4).

## Migration Approach

A staged, behavior-preserving cutover from the fragmented helpers to UNS:

- **Phase A — Inventory.** The Phase 1 Project_Scan_Report enumerates every legacy emitter (`service_job_notification_service`, `restaurant_notification_service`, `security_notification_service`, `customer_notifications_repository`, `school-notifications.ts`, etc.) as Trigger_Points (REQ 1.6).
- **Phase B — Coexistence per module.** A `migration_status.md` document records, per Trigger_Point, exactly one active path (legacy or UNS), never both, during the migration window (REQ 19.5).
- **Phase C — Equivalence test before removal.** Each module's legacy helper is removed only after a recorded equivalence test confirms the recipient set, channel set, and message content match (REQ 10.9, REQ 10.9a).
- **Phase D — Single-path enforcement.** When Phase 4 implementation is complete, no parallel notification path remains in the codebase (REQ 10.7, REQ 20.1).
- The detailed per-helper mapping is intentionally deferred (see Out of Scope).

## Phase 1 and Phase 2 Deliverables (referenced, not redesigned)

These artifacts live as separate documents in the spec folder; this design does not redesign their content:

- **Phase 1 — Project_Scan_Report** at `.kiro/specs/unified-notification-system/phase1-scan-report.md` (REQ 1).
- **Phase 2 — Notification_Event_Registry** at `.kiro/specs/unified-notification-system/phase2-event-registry.md` (REQ 2).

The full Trigger_Point inventory across DukanX modules and the per-event registry rows are produced by those phases, not by this design.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Deduplication-window correctness

*For any* sequence of `createNotification` calls and *for any* pair of those calls sharing a Deduplication_Key K and a recipient R whose timestamps fall within the configured Deduplication_Window W, the number of deliveries of K to R within any rolling window of length W is at most 1.

**Validates: Requirements 4.4, 9.2, 15.5**

### Property 2: No event loss across Event_Bus restart

*For any* sequence of events accepted (publish-acknowledged) by the Event_Bus and *for any* restart of the Event_Bus injected at any point during in-flight delivery, every accepted event is eventually delivered to every authorized recipient after recovery — no permanently lost event.

**Validates: Requirements 3.5, 9.8, 15.4**

### Property 3: Recipient authorization on every dispatch

*For any* dispatched notification N and *for any* recipient R who actually receives a delivery for N on any channel, R satisfies the recipient-authorization predicate against N's `event_name` and `target_id` under the prevailing RBAC rules.

**Validates: Requirements 4.11, 12.1, 15.8, 15.15**

### Property 4: Event_Contract parser/serializer round-trip

*For any* valid Event_Contract event `e`, `parse(serialize(e))` is structurally equivalent to `e`.

**Validates: Requirements 8.6, 15.6**

### Property 5: Preference idempotence

*For any* user `u` and *for any* valid `UserPreference` payload P, invoking `setUserPreferences(u, P)` one or more times yields the same stored record and the same resolved preference output for any subsequent event evaluation.

**Validates: Requirements 4.9, 7.7, 15.7**

### Property 6: Lifecycle ordering invariant

*For any* `Notification` record at any time during its life, `created_at ≤ dispatched_at ≤ delivered_at ≤ read_at` holds (with `null` permitted for any unset trailing timestamp), and any attempted state transition that would violate this ordering is rejected.

**Validates: Requirements 6.7**

Also validates the explicit lifecycle-ordering sub-requirement 6.7a, which states the same invariant and the rejection rule.

## Testing Strategy

Testing operates at four levels and uses both example-based and property-based approaches as appropriate.

- **Unit tests** cover the Notification_Service operations, the rule engine, the deduplication step, the Preference_Engine resolution order, and each channel adapter in isolation, including edge cases and error conditions (REQ 15.1).
- **Property-based tests** verify the six universal invariants in the Correctness Properties section above. Each property test runs a minimum of 100 iterations and is tagged with a comment of the form `Feature: unified-notification-system, Property N: <property text>`. The property-based testing library is the idiomatic choice for the target language (e.g. `fast-check` for the Node.js backend, `glados` or equivalent for Flutter/Dart) and is consumed as a dependency rather than implemented from scratch.
- **Integration tests** exercise end-to-end paths from producer through Event_Bus and Notification_Service to Delivery_Layer, with at minimum one event per category in the Notification_Event_Registry (REQ 15.2, REQ 10.10).
- **Load tests** drive 500 concurrent users for ≥5 minutes asserting end-to-end p95 delivery latency in `[1 ms, 500 ms]`, plus 100/1000/10 000-user benchmarks for capacity verification (REQ 15.3, REQ 13.5).
- A **chaos test** terminates the Event_Bus process during in-flight delivery and asserts no permanent event loss after recovery (REQ 15.4).

Property-based testing is appropriate here because the system's correctness invariants (deduplication, durability, authorization, round-tripping, idempotence, ordering) are universally quantified over inputs that vary meaningfully (event sequences, restart timings, recipient/role tables, payload shapes, preference payloads, transition sequences). UI-rendering checks for the bell, drawer, toast, and preferences widgets use snapshot tests rather than property tests, which is the appropriate tool for that layer.

## Out of Scope for This Design Pass

The following are intentionally deferred to a later iteration:

- Full **Event_Contract JSON Schema** (field-by-field).
- Full **DynamoDB attribute schemas** with key/sort/projection details for `Notification`, `UserPreference`, and `AuditLog`.
- Full **Audit_Log field tables**.
- **Per-channel rate-limit numerical tuning tables** beyond the defaults already named in REQ 9.5.
- The **full Trigger_Point inventory** across all DukanX modules — this is produced as a Phase 1/Phase 4 task, not in this design.
- **Detailed sequence diagrams** for every operation (the high-level architecture diagram above is sufficient for this pass; one or two illustrative sequence diagrams may be added in a follow-up).
- The **detailed migration mapping** from each existing legacy helper to its UNS equivalent — recorded in `migration_status.md` per module rather than in this design.
