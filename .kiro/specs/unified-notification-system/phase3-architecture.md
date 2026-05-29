# Phase 3 — Unified Notification System Architecture

> Locked architecture for the Unified Notification System (UNS). This document fixes exactly one canonical implementation per component (REQ 20.1), records the single Event_Bus choice with rationale and a `rejected_alternatives` section (REQ 3.1, REQ 20.3), and pins the reliability tiers, deduplication semantics, retry budgets, DLQ routing, channel matrix, performance targets, and security model that the Phase 4 implementation must fulfill.
>
> Inputs: `requirements.md` (REQ 3, REQ 18.3, REQ 20.1-20.3 are the primary validation targets), `design.md` (already commits to Amazon SNS + SQS), `phase1-scan-report.md` §9 (Trigger_Point Catalogue, 145 entries) and §10 (Roles, 22 distinct roles), `phase2-event-registry.md` §16 (Phase-3 hand-off notes, 134 events + 8 batched events + 19 rejected candidates).

## Table of Contents

1. [Conventions and Constraints](#1-conventions-and-constraints)
2. [Canonical Component List](#2-canonical-component-list)
3. [Architecture Diagram](#3-architecture-diagram)
4. [Event_Bus Choice — Amazon SNS + SQS](#4-event_bus-choice--amazon-sns--sqs)
5. [Rejected Alternatives](#5-rejected-alternatives)
6. [Reliability Tiers and Delivery Modes](#6-reliability-tiers-and-delivery-modes)
7. [Deduplication Semantics](#7-deduplication-semantics)
8. [Retry Budgets and DLQ Routing](#8-retry-budgets-and-dlq-routing)
9. [Channel Matrix](#9-channel-matrix)
10. [Performance Targets](#10-performance-targets)
11. [Security Model](#11-security-model)
12. [Data Model and Storage](#12-data-model-and-storage)
13. [Sub_App_Sync_Layer and Shared_SDK Surface](#13-sub_app_sync_layer-and-shared_sdk-surface)
14. [Integration With Existing Patterns](#14-integration-with-existing-patterns)
15. [Phase-4 Hand-off Notes](#15-phase-4-hand-off-notes)
16. [Document Checklist Against Requirements 3, 18.3, 20.1-20.3](#16-document-checklist-against-requirements-3-183-201-203)

---

## 1. Conventions and Constraints

### 1.1 Single-implementation rule (REQ 20.1)

The Notification_System SHALL provide exactly one of each component listed in §2. Future contributors proposing a second implementation of any component MUST replace the existing implementation rather than ship in parallel; the migration plan MUST be documented and committed before any release containing the replacement (REQ 20.2).

### 1.2 Single-option rule (REQ 20.3)

This document SHALL state the single chosen option for every component. Alternatives SHALL live only in §5 `Rejected Alternatives` with rationale. The system SHALL NOT ship multiple options for any component.

### 1.3 Independence from Phase 4 (REQ 20.3 second sentence, REQ 18.5)

This document is authored, reviewed, and committed independently of, and prior to, the Phase 4 implementation. Phase 5 deliverables (load test plan, observability, security review, documentation) MAY proceed in parallel with Phase 4 against this document, with each Phase 5 deliverable re-validated against the final Phase 4 implementation before the feature is marked complete.

### 1.4 Sequencing gate (REQ 18.3)

Phase 4 implementation work SHALL NOT begin until this document is committed and reviewed.

### 1.5 Document is the source of truth

Where this document and `design.md` agree, both stand. Where they would conflict, this document wins for Phase 4 onward. The numerical targets, retry budgets, channel matrix, and security model below are the pinned values Phase 4 must implement.

---

## 2. Canonical Component List

Per REQ 20.1, the system has exactly one of each:

| # | Component | Single chosen implementation | Code location (Phase 4) | Validates |
|---|---|---|---|---|
| 1 | **Event_Bus** | Amazon SNS (fan-out topic) + SQS (per-consumer queue, with managed DLQ) | `my-backend/src/notifications/event-bus/` | REQ 3.1, 10.1, 20.1 |
| 2 | **Notification_Service** | TypeScript service on AWS Lambda exposing `createNotification`, `dispatch`, `markAsRead`, `getUserPreferences`, `setUserPreferences`, `getReplay` | `my-backend/src/notifications/service/` | REQ 4, 10.2, 20.1 |
| 3 | **Delivery_Layer** | Pluggable adapter façade fronting five channel adapters (`in-app`, `push`, `email`, `sms`, `webhook`) with failure isolation between adapters | `my-backend/src/notifications/channels/` (one file per channel) | REQ 5, 10.4, 20.1 |
| 4 | **Notification_Store** | DynamoDB-backed store persisting `Notification`, `UserPreference`, and `AuditLog` records with three GSIs and an unread-count projection | `my-backend/src/notifications/store/` | REQ 6, 19.2, 20.1 |
| 5 | **Preference_Engine** | Stateless resolver (reads only `UserPreference` records) applying the resolution order in §1.5 of `design.md` | `my-backend/src/notifications/preferences/` | REQ 7, 20.1 |
| 6 | **Sub_App_Sync_Layer** | JWT-authenticated WebSocket/SSE entry plus `GET /notifications/replay?since=&app=` endpoint | `my-backend/src/notifications/sync/` | REQ 8, 20.1 |
| 7 | **Shared_SDK** | `@dukanx/notifications` Dart/Flutter package consumed by DukanX and every Sub_App, with a parallel TypeScript surface for backend producers | `packages/notifications-sdk/` | REQ 8.1, 10.5, 11, 20.1 |

Two supporting packages are shipped alongside the seven canonical components but are not themselves Notification_System components in the REQ 20.1 sense:

- `packages/notifications-ui/` — the shared Flutter widgets (notification bell, drawer, in-app toast, preferences page) consumed by every front-end (REQ 11, 10.6).
- `packages/notifications-sdk/event-contract.schema.json` — the Event_Contract JSON Schema that every Producer and every Consumer validates against (REQ 8.1, 8.6, REQ 3.6).

---

## 3. Architecture Diagram

```mermaid
flowchart LR
  subgraph Producers
    DX[DukanX feature modules]
    SA[Sub-apps<br/>school_admin / student / teacher]
    BE[Backend Lambdas<br/>my-backend / voice-backend / lambda]
  end

  subgraph UNS_Core
    EB[Event_Bus<br/>Amazon SNS + SQS<br/>schema-validated · durable]
    NS[Notification_Service<br/>createNotification · dispatch · markAsRead<br/>getUserPreferences · setUserPreferences · getReplay]
    PE[Preference_Engine<br/>per_event → per_category → role → system<br/>quiet hours · mute · self-suppression]
    DL[Delivery_Layer<br/>5 channel adapters<br/>failure-isolated]
    NSTORE[(Notification_Store<br/>DynamoDB<br/>3 GSIs + unread-count projection)]
    SYNC[Sub_App_Sync_Layer<br/>JWT · per-id ack · replay]
    DLQ[(Dead-Letter Queue<br/>SQS-managed)]
  end

  subgraph Channels
    INAPP[in-app<br/>WebSocket / SSE]
    PUSH[push<br/>FCM]
    EMAIL[email<br/>SMTP]
    SMS[sms<br/>Twilio]
    HOOK[webhook<br/>signed HTTPS]
  end

  subgraph Recipients
    USER[Users<br/>22 roles · 17 minimum-coverage roles]
    EXT[External webhook consumers]
  end

  SDK[/Shared_SDK<br/>@dukanx/notifications/]

  DX -->|emit| SDK
  SA -->|emit| SDK
  BE -->|publish| EB
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

The diagram shows producers on the left, the UNS core in the middle (one box per canonical component), the five channel adapters in the Delivery_Layer, and recipients on the right. The Shared_SDK is the only contact surface for Flutter apps. Backend Lambdas may publish directly to the Event_Bus.

---

## 4. Event_Bus Choice — Amazon SNS + SQS

### 4.1 Decision (REQ 3.1)

The Notification_System SHALL use **Amazon SNS + SQS** as the single canonical Event_Bus:

- **SNS** is the fan-out topic every Producer publishes to.
- **SQS** is the per-Consumer durable queue, one per logical consumer (Notification_Service ingestor, in-app fan-out worker, push worker, email worker, sms worker, webhook worker, replay indexer).
- Each SQS queue has a **managed dead-letter queue (DLQ)** attached.

This decision was made in `design.md` §"Event_Bus Selection" and is locked here for Phase 4 implementation work to begin (REQ 18.3). It SHALL NOT be re-litigated except via the migration-plan procedure in REQ 20.2.

### 4.2 Why SNS + SQS — Acceptance-criteria alignment

Each acceptance criterion in REQ 3 maps to a specific managed feature of SNS+SQS:

| Acceptance criterion | How SNS + SQS satisfies it |
|---|---|
| **REQ 3.2** — Accept publishes from DukanX, Sub_Apps, and Backend services | SNS publish API is callable from every IAM-authenticated principal in the existing `my-backend/`, `voice-backend/`, and `lambda/` accounts. The Shared_SDK uses the API Gateway publish endpoint backed by the Notification_Service publisher Lambda. |
| **REQ 3.3** — Persist durably before acknowledging the publish | SNS + SQS guarantees the message is durably persisted across multiple AZs before returning success on the publish call. The Notification_Service publisher Lambda only returns after the SDK call resolves. |
| **REQ 3.4** — Deliver every event matching the subscription topic that occurred after the consumer's last committed offset | Each consumer's SQS queue is the ordered cursor; SQS only deletes a message after the consumer explicitly acknowledges by deleting it (post-processing). Unacknowledged messages remain available after visibility-timeout expiry. |
| **REQ 3.5** — Resume after Event_Bus restart from last committed offset, no event loss | SNS and SQS are managed services; "restart" maps to AWS-managed failover. Persisted SQS messages survive failover; consumers resume from their queue cursor. Property 2 (no event loss across Event_Bus restart) is covered by `tasks.md` task 5.2. |
| **REQ 3.6** — Reject publishes whose payload fails Event_Contract JSON Schema validation, do not deliver to any Consumer | The publisher Lambda validates payload against `packages/notifications-sdk/event-contract.schema.json` before calling `sns:Publish`. Rejected payloads return a structured validation error and never reach SNS. |
| **REQ 3.7** — `at_least_once` for `critical` and `high` priority | SQS provides at-least-once delivery natively; the Notification_Service maps `critical`/`high` events to this mode (see §6). |
| **REQ 3.8** — `at_most_once_with_dedup` for `normal` and `low` priority | SQS at-least-once + Notification_Service deduplication step on the `by-dedup-key` GSI yields `at_most_once_with_dedup` semantics at the recipient (see §6, §7). |
| **REQ 3.9** — Retry up to 5 times with exponential backoff on delivery failure | SQS visibility-timeout-driven redelivery + per-channel retry policy in the Delivery_Layer (3 retries for push/email/sms, 5 retries for webhook; see §8 and §9). |
| **REQ 3.10** — Move to DLQ on retry exhaustion with original payload, error reason, retry count, timestamps preserved | SQS managed DLQ preserves the original message payload; the Notification_Service writes the error reason, retry count, and timestamps to the `AuditLog` and copies them onto the DLQ message attributes. |

### 4.3 Why SNS + SQS — Operational fit

- The backend already runs on **AWS Lambda + DynamoDB** under `my-backend/`, `voice-backend/`, and `lambda/`. SNS+SQS is the native fit — no new infrastructure to operate, no separate cluster, no fresh ops burden (REQ 19.2, 19.3).
- **Per-Lambda IAM policies** plug into the existing JWT/role infrastructure for per-Producer authentication (REQ 12.3, 12.4).
- **Same AWS account, region, table-naming conventions** used by `my-backend/` (REQ 19.2).
- **Same API Gateway** hosts the Notification_Service HTTP endpoints (REQ 19.3).

---

## 5. Rejected Alternatives

Per REQ 20.3, the alternatives below are recorded here only and SHALL NOT ship.

### 5.1 Apache Kafka

**Rejected.**

- **Operational weight.** Kafka requires a managed cluster (Amazon MSK or self-hosted Confluent). The workspace runs entirely on managed AWS Lambda + DynamoDB; introducing Kafka would add a stateful broker tier and zookeeper/kraft management that no other workload in the workspace requires.
- **Cost profile.** The smallest production-grade MSK cluster is materially more expensive per month than the SNS+SQS request-pricing model for the volume implied by 134 events × 10 000 concurrent users.
- **No correctness gap addressed.** Kafka's strengths (ordered log replay over long horizons, high-throughput stream processing) are not needed by UNS: the replay window is 7 days (REQ 8.5), the per-event throughput is bounded by the per-channel rate limits in §9, and ordering is required only per `(user_id, created_at)` not globally — SQS message-ordering plus `created_at` sort on the unread query already covers this.
- **Operational mismatch with the existing stack.** The team operates Lambda + DynamoDB; adding a stateful broker that requires its own observability, partition rebalancing, and capacity planning is out of scope for the Phase 5 ops budget.

### 5.2 Redis Pub/Sub

**Rejected — disqualifying.**

- **Violates REQ 3.5.** Redis Pub/Sub is fire-and-forget: messages published while a subscriber is disconnected are lost. UNS requires durability across an Event_Bus restart and across consumer downtime (REQ 3.5, REQ 9.8 — "no event accepted by the Event_Bus is permanently lost ... including across an Event_Bus restart, an Event_Bus failover, a Notification_Service restart, a channel-adapter crash, or any combination of the above").
- **Violates REQ 3.3.** Redis Pub/Sub has no durable persistence. Even Redis Streams, which does add persistence, would only mitigate this at the cost of putting the team back into self-hosted state management for a workload AWS already provides as a managed service.
- **No native DLQ.** REQ 3.10 requires a DLQ that preserves the original payload, error reason, retry count, and timestamps. Redis would require the team to build and operate this layer themselves.
- **No native at-least-once with retry/visibility-timeout.** REQ 3.7 and REQ 3.9 would require additional middleware on top of Redis to provide guarantees SQS provides natively.

### 5.3 BullMQ

**Rejected.**

- **Wrong shape.** BullMQ is a job-queue model (one producer → one queue → one worker pool), not a fan-out pub/sub bus. UNS requires SNS-style fan-out from one producer to many consumer queues (in-app, push, email, sms, webhook, replay indexer all subscribe to the same logical event). Adapting BullMQ to fan-out would require running one queue per consumer with custom multi-publish logic — re-implementing what SNS does natively.
- **Requires Redis.** BullMQ runs on top of Redis, which inherits the durability and operational concerns above (and adds operational cost the team currently does not pay).
- **No native cross-AZ persistence guarantee.** Without a managed Redis cluster across AZs, BullMQ would not satisfy REQ 9.8's no-permanent-loss guarantee under Redis-host failover.
- **No native DLQ semantics for fan-out.** BullMQ's failed-job mechanism is per-queue, so a fan-out would require manually reconciling DLQs across consumer queues.

### 5.4 Why no fourth option

REQ 3.1 restricts the candidate set to `{Redis Pub/Sub, Apache Kafka, BullMQ, Amazon SNS+SQS}`. The chosen option (SNS + SQS) is the only candidate from that set that satisfies REQ 3.3 (durable persistence before ack), REQ 3.5 (no event loss across restart), REQ 3.7-3.8 (priority-tiered delivery semantics), REQ 3.9-3.10 (retry-with-DLQ), and REQ 19.2-19.3 (existing AWS account, region, API gateway) without adding a new operational tier.

---

## 6. Reliability Tiers and Delivery Modes

Pinned from `design.md` §"Reliability Tiers and Deduplication" and from REQ 9.

### 6.1 Tier matrix

| Priority tier | Delivery mode | Source of guarantee | Validates |
|---|---|---|---|
| `critical` | `at_least_once` — every authorized recipient eventually receives at least one delivery on at least one allowed channel | SQS at-least-once + retry budget | REQ 3.7, 9.1, 15.11 |
| `high` | `at_least_once` — same as `critical`, with quiet hours respected (no critical bypass) | SQS at-least-once + retry budget | REQ 3.7, 9.1 |
| `normal` | `at_most_once_with_dedup` — effective once-per-recipient via Deduplication_Key | SQS at-least-once + dedup step on `by-dedup-key` GSI | REQ 3.8, 9.2 |
| `low` | `at_most_once_with_dedup` — same as `normal` | SQS at-least-once + dedup step | REQ 3.8, 9.2 |

### 6.2 Effective-exactly-once at the recipient

The combination of SQS at-least-once delivery and the deduplication step in the Notification_Service yields effective exactly-once-per-recipient semantics for all four tiers. This is the property covered by **Property 1: Deduplication-window correctness** in `design.md` and by `tasks.md` task 6.2.

### 6.3 Critical bypass of preferences

`priority == critical` overrides the Quiet_Hours suppression rule (REQ 7.4). It does NOT override the recipient-authorization check (REQ 4.11, 12.1) and it does NOT override mutes the registry explicitly marks as un-mutable (`design.md` Preference Resolution Order, item "Mute behavior").

### 6.4 No event loss across any failure (REQ 9.8)

No event accepted by the Event_Bus SHALL be permanently lost — across Event_Bus restart, Event_Bus failover, Notification_Service restart, channel-adapter crash, or any combination of the above. This is enforced by:

- SQS multi-AZ persistence between publish-ack and consumer-delete.
- The local-outbox shim in every Producer (`design.md` §"Reliability Tiers and Deduplication", REQ 9.7) that buffers events when the Event_Bus is unavailable and replays in `created_at` ascending order on recovery.
- The DLQ as terminal state for retry-exhausted events; DLQ entries remain inspectable and replayable until an operator acts on them (REQ 9.4).

---

## 7. Deduplication Semantics

Pinned from `design.md` §"Reliability Tiers and Deduplication" and from REQ 4.4 and the glossary.

### 7.1 Deduplication_Key

```
Deduplication_Key = (event_name, actor_id, target_id, dedup_scope_fields)
```

`dedup_scope_fields` is declared per event in the Phase 2 Notification_Event_Registry under the `deduplication_rule` field. The key is deterministic: the same logical event with the same actor and same target produces the same key.

### 7.2 Deduplication_Window

- **Default: 60 seconds.** This is the value listed in the requirements.md glossary and used unless an event in the Notification_Event_Registry overrides it.
- **Overridable per event** via the `deduplication_rule` field of the registry. Phase 2 has assigned the override for high-frequency event groups in §13 (Notification Fatigue Risks).

### 7.3 Deduplication step

When `Notification_Service.dispatch(notification_id)` runs, for each prospective recipient R it:

1. Computes the Deduplication_Key from the event payload.
2. Queries the `by-dedup-key` GSI on the Notification_Store for any record with the same key delivered to R within the Deduplication_Window.
3. If a hit exists: SKIP dispatch to R, write a `skipped_duplicate` AuditLog entry, do NOT count toward the recipient's per-channel rate-limit window (REQ 4.4).
4. If no hit: proceed to the Preference_Engine and to the Delivery_Layer.

### 7.4 No-double-delivery property

For any sequence of `createNotification` calls and any pair sharing a Deduplication_Key K and a recipient R within the Deduplication_Window W, R receives at most 1 delivery for K within any rolling window of length W. This is **Property 1** in `design.md` §Correctness Properties; verified by `tasks.md` task 6.2.

---

## 8. Retry Budgets and DLQ Routing

Pinned from REQ 3.9-3.10, REQ 5.9-5.13, REQ 9.3.

### 8.1 Retry budgets per channel

| Channel | Max retries | Backoff | Source of guarantee | Validates |
|---|---|---|---|---|
| `in-app` | 5 (Event_Bus level) | Exponential, SQS visibility-timeout-driven | Bus retry budget, then ack-required-before-delivered | REQ 3.9, 5.6, 5.8 |
| `push` (FCM) | 3 (per-adapter, transient errors) | Exponential | Channel adapter retry policy | REQ 5.9 |
| `email` (SMTP) | 3 (per-adapter, transient errors) | Exponential | Channel adapter retry policy | REQ 5.10 |
| `sms` (Twilio or env-configured equivalent) | 3 (per-adapter, transient errors) | Exponential | Channel adapter retry policy | REQ 5.11 |
| `webhook` (signed HTTPS) | 5 (per-adapter, on non-2xx) | Exponential | Channel adapter retry policy | REQ 5.13 |

The Event_Bus-level retry budget of 5 attempts (REQ 3.9) is the outer envelope. Inner per-channel budgets (3 for push/email/sms, 5 for webhook) are nested inside that envelope; once an inner budget is exhausted, the failure escalates to the bus-level retry, and the outer 5-attempt budget governs the final escalation to DLQ.

### 8.2 DLQ routing

When retry budget is exhausted on any channel, the Notification_Service:

1. Writes a `failed` lifecycle transition to the AuditLog with `error_reason`, `attempt`, and `timestamp` (REQ 12.5, 14.1).
2. Routes the original payload to the SQS managed DLQ with the original payload, error reason, retry count, and timestamps preserved as message attributes (REQ 3.10, 9.3).
3. Updates the metric `notifications_failed_total{event_name, channel, error_reason}` (REQ 14.4).

### 8.3 DLQ inspection and replay

Operators have a single endpoint to list, inspect, and replay DLQ entries (REQ 9.4). The endpoint is JWT-authenticated and authorized to operator role only, and replays push the message back to the originating SQS queue with `retry_count` reset.

### 8.4 Producer-side outbox

If the Event_Bus is unavailable at publish time, the producing service buffers the event in a local outbox and replays in `created_at` ascending order on recovery (REQ 9.7). The Shared_SDK owns this outbox on the Flutter side; backend Producers use a per-Lambda outbox-via-DynamoDB shim.

---

## 9. Channel Matrix

Pinned from REQ 5 and REQ 9.5-9.6.

### 9.1 Channels

| Channel | Transport | Authentication | Default per-user per-channel rate limit | Coalescing on limit hit |
|---|---|---|---|---|
| `in_app` | WebSocket / Server-Sent Events | Existing JWT, same as DukanX/Sub_App APIs (REQ 5.6, 19.1) | 60 / minute (REQ 9.5) | Same-`event_name` notifications coalesce into a batched summary delivered after the window resets (REQ 9.6) |
| `push` | Firebase Cloud Messaging | FCM device token + per-app server key | 20 / minute (REQ 9.5) | Same-`event_name` coalesce |
| `email` | SMTP | SMTP credentials in env-scoped secret | 10 / minute (REQ 9.5) | Same-`event_name` coalesce |
| `sms` | Twilio (or env-configured equivalent) | Twilio API key in env-scoped secret | 5 / minute (REQ 9.5) | Same-`event_name` coalesce |
| `webhook` | Signed HTTPS POST | Per-consumer shared secret used to compute the `X-Signature` header (REQ 5.12) | 60 / minute (REQ 9.5) | Same-`event_name` coalesce |

### 9.2 Per-channel adapter behavior

- **`in-app`** — Persist for offline recipients. On reconnect replay in `created_at` ascending order. Require per-`notification_id` ack within 30 seconds before marking `delivered` (REQ 5.8, 5.8a, 8.3). Target 500 ms p95 push latency under nominal load up to 10 000 concurrent connections (REQ 5.7, 13.3).
- **`push`** — Up to 3 retries with exponential backoff on transient FCM errors. On exhaustion: write `failed` lifecycle event and route to DLQ (REQ 5.9, 9.3).
- **`email`** — Up to 3 retries with exponential backoff on transient SMTP errors (REQ 5.10).
- **`sms`** — Up to 3 retries with exponential backoff on transient provider errors (REQ 5.11).
- **`webhook`** — Up to 5 retries with exponential backoff on persistent non-2xx, then DLQ (REQ 5.13). Every payload carries an `X-Signature` header computed over the body using the per-consumer shared secret (REQ 5.12).

### 9.3 Failure isolation

The five adapters run as separate consumer Lambdas behind separate SQS queues. A failure in one adapter (e.g. an SMTP outage on `email`) does NOT block the others. This isolation is the load-bearing reason the Delivery_Layer is structured as a façade over five files rather than one combined dispatcher.

### 9.4 Channel selection

The Preference_Engine resolves the allowed channel set per recipient per notification (`design.md` §Preference Resolution Order). The resolution order is:

1. `per_event_channels` — wins if set; ignores per-category for that event (REQ 7.2).
2. `per_category_channels` — fallback for the notification's `category` (REQ 7.2a).
3. Role-level default channel set.
4. System default channel set.

Quiet_Hours, critical bypass, mute behavior, and self-suppression then apply on top of the resolved set (REQ 7.3-7.6).

---

## 10. Performance Targets

Pinned from REQ 5.7, REQ 6.7, REQ 7.8, REQ 11.6, REQ 13. These are the numerical targets Phase 4 must hit and Phase 5 must benchmark.

### 10.1 Latency targets

| Operation | Target | Load condition | Validates |
|---|---|---|---|
| In-app notification delivery (createNotification → client receipt) | **500 ms p95** | Sustained 500 concurrent users emitting at the Phase 5 load-test rate | REQ 5.7, 13.3, 15.3 |
| In-app push to a connected client | **500 ms p95** | Up to 10 000 concurrent in-app connections, nominal load | REQ 5.7 |
| Unread-count query for any recipient | **50 ms p95** | Up to 10 000 concurrent users, nominal load | REQ 13.1 |
| Cursor-based history query (≤ 50 records) | **200 ms p95** | Up to 10 000 concurrent users, nominal load | REQ 13.2 |
| Unread-count projection update on `delivered`/`read` transition | **100 ms** | Nominal load; under spike, processing continues rather than dropping | REQ 6.7 |
| Preference_Engine resolution per recipient per channel | **< 10 ms p95** | Nominal load | REQ 7.8 |
| Bell widget update on server-side change | **1 s p95** on a connected client; otherwise display `stale` indicator | REQ 11.6 |

### 10.2 Capacity targets

- **10 000 concurrent in-app connections** is the design target (REQ 5.7, 13.1, 13.2).
- Benchmarks at **100, 1000, and 10 000 concurrent users** (REQ 13.5) with availability **> 99.9%** and **zero event loss across the full range** (REQ 13.6).
- The load-test plan lives at `.kiro/specs/unified-notification-system/phase5-load-plan.md`; results at `.kiro/specs/unified-notification-system/phase5-load-results.md` (REQ 13.5).

### 10.3 Lower bounds (sanity check)

The 500 concurrent-user load test (REQ 15.3) asserts end-to-end p95 delivery latency in `[1 ms, 500 ms]`. A measured p95 below 1 ms is treated as a measurement error and fails the test.

---

## 11. Security Model

Pinned from REQ 4.10-4.11, REQ 5.12, REQ 12, REQ 19.1.

### 11.1 Authentication

- **End-user requests** authenticate via the existing JWT mechanism used by DukanX and Sub_App APIs (REQ 12.3, 19.1). Same Cognito-issued JWT, same verification middleware, same token expiry rules.
- **Sub_App and external Producers** connect to the Event_Bus or Notification_Service with JWT or an environment-scoped shared secret; failed auth is rejected (REQ 12.3).
- **Webhook deliveries** carry an `X-Signature` header computed over the payload from a per-consumer shared secret (REQ 5.12).

### 11.2 Authorization

- **Caller authorization on `createNotification`** — `Notification_Service.createNotification` rejects without persisting if the caller is not authorized to emit on behalf of the supplied `actor_id` and `source_module` (REQ 4.10).
- **Per-recipient authorization on `dispatch`** — for every prospective recipient R, `Notification_Service.dispatch` runs the recipient-authorization predicate against the supplied `(event_name, target_id)` under the existing RBAC rules. Recipients that fail the check are silently omitted from the dispatch (REQ 4.11, 12.1). This is **Property 3** in `design.md` §Correctness Properties; verified by `tasks.md` task 6.3.
- **Authorization monotonicity** — revoking a recipient's authorization for an `event_name` prevents that recipient from receiving any subsequent notification of that `event_name`, and does not retroactively withdraw prior deliveries (REQ 15.15; verified by `tasks.md` task 16.6).
- **Read/modify access on existing notifications** — only Recipients of a notification or authorized administrators may read or modify it; denials are recorded as `unauthorized_access_attempt` AuditLog entries (REQ 12.7).

### 11.3 Payload sanitization

The Notification_Service applies sanitization unconditionally to every notification `payload` field before persistence and before delivery, removing scripting tags and control characters that could enable XSS in in-app rendering or injection in email templates (REQ 12.2). Sanitization runs regardless of the apparent safety of the input.

### 11.4 Redaction of sensitive data

The Notification_System SHALL never include secret values, full payment card numbers, or full government-issued identifiers in notification payloads; instead, it SHALL include redacted references (REQ 12.8). The redaction pass runs before persistence and before delivery; events that try to embed raw values are rejected by the Event_Contract validator at the bus boundary.

### 11.5 Per-Producer publish rate limit

Per-Producer rate limiting at the publish endpoint defaults to **1000 events / minute** per Producer, configurable (REQ 12.4). The rate limit is evaluated independently of authorization checks and applies to every publish attempt regardless of whether the request is subsequently authorized or denied.

### 11.6 Audit_Log

The AuditLog is append-only (REQ 12.6). Every lifecycle transition (`emitted`, `queued`, `dispatched`, `delivered`, `read`, `failed`) writes a record carrying `notification_id`, `lifecycle_state`, `recipient_id`, `channel`, `attempt`, `outcome`, `error_reason`, and `timestamp` (REQ 6.3, 12.5, 14.1). Update and delete operations on existing AuditLog records are rejected.

### 11.7 Retention and configuration

The Archive_Period default is 90 days, configurable (REQ 13.4, glossary). Configuration changes require an authenticated configuration-change endpoint; every change writes an AuditLog entry naming actor, previous value, new value, timestamp (REQ 13.4). If the AuditLog subsystem is unavailable at the time of a retention configuration change, the change is rejected and the previous Archive_Period remains in effect (REQ 13.4a).

---

## 12. Data Model and Storage

Pinned from REQ 6 and REQ 19.2. The full DynamoDB attribute schemas are owed by `tasks.md` task 4.1; this section locks the table set, the GSI set, and the lifecycle invariant.

### 12.1 Tables

Three logical tables in the Notification_Store, persisted in DynamoDB in the same AWS account, region, and table-naming conventions used by `my-backend/` (REQ 19.2):

| Table | Purpose | Key fields | Validates |
|---|---|---|---|
| `Notification` | One record per notification | `notification_id`, `event_name`, `category`, `sub_category`, `priority`, `actor_id`, `target_id`, `recipients` (list of `{user_id, role, channels, status, delivered_at, read_at}`), `payload`, `channels`, `status`, `created_at`, `dispatched_at`, `delivered_at`, `read_at`, `dedup_key`, `source_module`, `source_app` | REQ 6.1 |
| `UserPreference` | One record per user | `user_id`, `role`, `per_category_channels`, `per_event_channels`, `quiet_hours_start`, `quiet_hours_end`, `quiet_hours_timezone`, `mute_targets`, `updated_at`, `version` | REQ 6.2 |
| `AuditLog` | Append-only lifecycle log | `audit_id`, `notification_id`, `lifecycle_state`, `recipient_id`, `channel`, `attempt`, `outcome`, `error_reason`, `timestamp` | REQ 6.3 |

### 12.2 Global Secondary Indexes

| GSI | Key shape | Access pattern | Validates |
|---|---|---|---|
| `by-user-status` | `(user_id, status, created_at)` | Recipient unread list, paginated | REQ 6.4 |
| `by-user-category` | `(user_id, category, created_at)` | Filtered history per user per category | REQ 6.5 |
| `by-dedup-key` | `(dedup_key, created_at)` | Constant-time deduplication lookup | REQ 6.6 |

### 12.3 Lifecycle ordering invariant

For every `Notification` record at all times:

```
created_at ≤ dispatched_at ≤ delivered_at ≤ read_at
```

with `null` permitted for any unset trailing timestamp. Any state transition that would violate this ordering is rejected with a structured error. This is **Property 6** in `design.md` §Correctness Properties; verified by `tasks.md` task 4.3 (REQ 6.7a).

### 12.4 Unread-count projection

A per-user `unread_count` projection is maintained via DynamoDB Streams. The projection updates within **100 ms** of any `delivered`/`read` lifecycle transition under nominal load. Under load spikes, the projection update continues processing rather than being dropped, and the elapsed update time is recorded in the `delivery_latency_ms` histogram (REQ 6.7).

### 12.5 Pagination

All notification history queries use cursor-based pagination with an opaque cursor encoding `(user_id, created_at, notification_id)` (REQ 6.9).

### 12.6 Retention

Notification and AuditLog records are retained for the Archive_Period (default 90 days, configurable) and then moved to a cold storage bucket (REQ 6.8, 13.4). The eviction job runs as a scheduled Lambda; it does NOT delete records, only relocates them.

---

## 13. Sub_App_Sync_Layer and Shared_SDK Surface

Pinned from REQ 8 and REQ 11.

### 13.1 Sub_App_Sync_Layer

- **Connection** — JWT-authenticated WebSocket/SSE entry, same Cognito JWT as the existing DukanX/Sub_App APIs (REQ 8.2, 19.1).
- **Per-id ack** — every dispatched notification requires a per-`notification_id` ack within 30 s; missing acks trigger a retry under the channel's policy (REQ 8.3).
- **Replay endpoint** — `GET /notifications/replay?since=<ISO_DATE>&app=<sub_app_name>` returns notifications targeted at users of that Sub_App with `created_at >= since`, in `created_at` ascending order, bounded by the Replay_Window default of **7 days** (REQ 8.4-8.5a).
- **Out-of-window error** — requests beyond the bound return a structured error with code `replay_window_exceeded`, regardless of whether matching notifications exist (REQ 8.5).
- **In-window-with-no-matches** — returns HTTP 200 with empty `notifications` array and next-cursor field set to the request's `since` value (REQ 8.5a).
- **Schema-invalid Sub_App publishes** — rejected with a structured validation error naming the offending fields; the event is NOT enqueued (REQ 8.7).

### 13.2 Shared_SDK API

The `@dukanx/notifications` package exposes exactly four public methods (REQ 10.5):

- `subscribe(eventName, handler)` — register a handler for events of the given name.
- `emit(event)` — publish an event; client-side validates against the Event_Contract JSON Schema before publishing.
- `onNotification(handler)` — register a handler called for every notification delivered to the signed-in user.
- `replay(sinceIso)` — call the replay endpoint and return the result.

The SDK owns the **offline outbox**: while disconnected the SDK queues emitted events locally and flushes them in `created_at` ascending order on next successful connect (REQ 8.8). The outbox survives a process restart.

### 13.3 Shared UI widgets (consumed by every front-end)

Provided by `packages/notifications-ui/` (REQ 10.6, 11):

- **Notification bell** — current unread count for the signed-in user; updates within 1 s p95 on a connected client; displays a `stale` indicator when an outstanding server-side change has not propagated within 1 s (REQ 11.1, 11.6, 11.6a).
- **Notification drawer** — `created_at` descending order with cursor-based pagination and category filter; calls `markAsRead` when an item is opened (REQ 11.2, 11.5).
- **In-app toast** — surfaces newly arrived `critical` and `high` priority notifications immediately (REQ 11.3).
- **Preferences page** — per-category channels, per-event channels, Quiet_Hours, `mute_targets` (REQ 11.4).

### 13.4 Event_Contract round-trip

For any valid Event_Contract event `e`, `parse(serialize(e))` is structurally equivalent to `e`. This is **Property 4** in `design.md` §Correctness Properties; verified on both the Dart SDK side (`tasks.md` task 11.2) and the TypeScript backend side (`tasks.md` task 11.3) (REQ 8.6, 15.6).

---

## 14. Integration With Existing Patterns

Pinned from REQ 19 and the Phase 1 Tech_Stack (`phase1-scan-report.md` §3).

### 14.1 Authentication

Notification_System end-user requests authenticate via the same JWT mechanism the existing DukanX and Sub_App APIs use (REQ 19.1). Same Cognito user pool, same token verification middleware. Sub_App connections, Backend Lambda producers, and Shared_SDK clients all use the same JWT path.

### 14.2 Storage

Notification_System persists data in DynamoDB using the same AWS account, same region (configured per environment), and same table-naming conventions used by `my-backend/` (REQ 19.2). Every Notification_System table name is prefixed per the existing convention.

### 14.3 API Gateway

Notification_System HTTP endpoints (`POST /notifications`, `GET /notifications/replay`, `POST /notifications/preferences`, `POST /notifications/{id}/read`, etc.) are exposed under the existing API Gateway that hosts the current Backend services and follow the same request/response envelope used by current handlers under `my-backend/src/handlers/` (REQ 19.3).

### 14.4 Replacement of legacy helpers

Every existing notification helper listed in the Phase 1 scan (`phase1-scan-report.md` §8 and the explicit list in REQ 1.6) is replaced by calls into the canonical Notification_Service or Shared_SDK. The migration plan is recorded in `migration_status.md` (REQ 19.5):

- Exactly one path (legacy or UNS) is active for any given Trigger_Point at any given time.
- Per-module migration window timestamps record start and end.
- Each module's legacy helper is removed immediately on entering that module's migration window.
- An equivalence test (recipient set, channel set, message content) is committed and reviewed before the legacy helper is removed; the test result is recorded in `migration_status.md` (REQ 10.9, 10.9a).
- When Phase 4 is complete, no parallel notification path remains in the codebase (REQ 10.7, 20.1).

### 14.5 Observability surface

- **Structured lifecycle logs** — one log line per transition (`emitted`, `queued`, `dispatched`, `delivered`, `read`, `failed`) carrying `notification_id`, `event_name`, `recipient_id`, `channel`, `timestamp` (REQ 14.1).
- **Metrics** — counters `events_emitted_total{event_name, priority, source_app}`, `notifications_dispatched_total{event_name, channel, priority}`, `notifications_failed_total{event_name, channel, error_reason}`; histogram `delivery_latency_ms{channel}` with rolling-5-minute p95 (REQ 14.2-14.5).
- **Failure-rate alert** — `alert.notifications.high_failure_rate` fires when the rolling 5-minute ratio `notifications_failed_total / notifications_dispatched_total > 5%` AND the denominator is `≥ 1`; does not fire when the denominator is 0 (REQ 14.6).

---

## 15. Phase-4 Hand-off Notes

This section is the bridge into the Phase 4 implementation tasks (`tasks.md` task groups 4 through 14).

### 15.1 What Phase 4 inherits from this document

- **Single Event_Bus choice** — Amazon SNS + SQS (§4); `tasks.md` task 5.1 implements the canonical Event_Bus module under `my-backend/src/notifications/event-bus/`.
- **Single Notification_Store schema** — three tables, three GSIs, one projection (§12); `tasks.md` task 4.1 implements the repositories under `my-backend/src/notifications/store/`.
- **Single Notification_Service surface** — six methods (§2); `tasks.md` task 6.1 implements the service under `my-backend/src/notifications/service/`.
- **Single Preference_Engine** — stateless resolver with a fixed resolution order (§9.4); `tasks.md` task 7.1 implements it under `my-backend/src/notifications/preferences/`.
- **Five channel adapters** with pinned retry budgets and rate limits (§9); `tasks.md` task group 9 implements them under `my-backend/src/notifications/channels/`.
- **Sub_App_Sync_Layer** with JWT, per-id ack, replay endpoint (§13.1); `tasks.md` task 10.1 implements it under `my-backend/src/notifications/sync/`.
- **Shared_SDK surface** — four methods, offline outbox, schema validation (§13.2); `tasks.md` task 11.1 implements it at `packages/notifications-sdk/`.
- **Shared UI widgets** — bell, drawer, toast, preferences page (§13.3); `tasks.md` task 12.1 implements them at `packages/notifications-ui/`.
- **Lifecycle ordering invariant**, **deduplication semantics**, **no-event-loss guarantee** (§7, §12.3, §6.4) — verified by Properties 1, 2, 6 in the design document.

### 15.2 What this document does NOT lock

These decisions remain owed by Phase 4 implementation tasks; this document deliberately does not pin them so the implementation has room to use idiomatic patterns:

- **Full Event_Contract JSON Schema** field-by-field — owed by `tasks.md` task 3.2 (`packages/notifications-sdk/event-contract.schema.json`).
- **Full DynamoDB attribute schemas** with key/sort/projection details — owed by `tasks.md` task 4.1.
- **Full AuditLog field tables beyond REQ 6.3** — owed by `tasks.md` task 4.1.
- **Per-channel rate-limit numerical tuning beyond the defaults in §9.1** — owed by `tasks.md` task 9.6.
- **Detailed sequence diagrams per operation** — out of scope for this document; the architecture diagram in §3 plus the operation list in §2 is sufficient for Phase 4 to begin.
- **Per-helper migration mapping** — recorded in `migration_status.md` per module (`tasks.md` task 14.1), not in this document.

### 15.3 Sequencing gate (REQ 18.3)

Per REQ 18.3, Phase 4 implementation work SHALL NOT begin until this document is committed and reviewed. Per REQ 18.5 and REQ 20.3, Phase 5 deliverables (load test plan, observability, security review, documentation) MAY proceed in parallel with Phase 4 against this document, with each Phase 5 deliverable re-validated against the final Phase 4 implementation before the feature is marked complete.

---

## 16. Document Checklist Against Requirements 3, 18.3, 20.1-20.3

| Acceptance criterion | Where in this document | Status |
|---|---|---|
| **REQ 3.1** — Single Event_Bus chosen from `{Redis Pub/Sub, Apache Kafka, BullMQ, Amazon SNS+SQS}`, documented with rationale at `.kiro/specs/unified-notification-system/phase3-architecture.md` | §4 (decision + rationale), §5 (rejected alternatives) | ✅ |
| **REQ 3.2** — Event_Bus accepts publishes from DukanX, Sub_Apps, Backend services | §4.2 row 1 | ✅ |
| **REQ 3.3** — Durable persistence before publish-ack | §4.2 row 2 | ✅ |
| **REQ 3.4** — Deliver every event after consumer's last committed offset | §4.2 row 3 | ✅ |
| **REQ 3.5** — Resume after Event_Bus restart with no event loss | §4.2 row 4, §6.4 | ✅ |
| **REQ 3.6** — Reject schema-invalid publishes; do not deliver | §4.2 row 5 | ✅ |
| **REQ 3.7** — `at_least_once` for `critical`/`high` | §6.1, §4.2 row 6 | ✅ |
| **REQ 3.8** — `at_most_once_with_dedup` for `normal`/`low` | §6.1, §4.2 row 7 | ✅ |
| **REQ 3.9** — Up to 5 retries with exponential backoff on delivery failure | §8.1, §4.2 row 8 | ✅ |
| **REQ 3.10** — DLQ on retry exhaustion preserving original payload, error reason, retry count, timestamps | §8.2, §4.2 row 9 | ✅ |
| **REQ 18.3** — Phase 4 work blocked until this document is committed and reviewed | §1.4, §15.3 | ✅ |
| **REQ 20.1** — Exactly one Event_Bus, Notification_Service, Delivery_Layer, Notification_Store, Preference_Engine, Sub_App_Sync_Layer, Shared_SDK | §1.1, §2 (canonical component table) | ✅ |
| **REQ 20.2** — Second implementations require migration plan documented and committed before release | §1.1 | ✅ |
| **REQ 20.3** — Single chosen option per component; alternatives in `rejected_alternatives` with rationale; document MAY be authored independently of Phase 4 | §1.2, §1.3, §5 | ✅ |

---

## Authoring metadata

- Generated as the deliverable for **Task 3.1** in `.kiro/specs/unified-notification-system/tasks.md`.
- Validates **Requirements 3.1, 18.3, 20.1, 20.2, 20.3**.
- This document is the input contract for **Task 3.2** (Event_Contract JSON Schema) and the entire Phase 4 implementation (`tasks.md` task groups 4 through 14).
