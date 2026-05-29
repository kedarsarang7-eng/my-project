# Implementation Plan: Unified Notification System (UNS)

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step with incremental progress. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

## Overview

The implementation uses the existing stack:

- **Backend (canonical UNS core):** Node.js + TypeScript on AWS Lambda under `my-backend/src/notifications/`, persisting to DynamoDB and using SNS + SQS as the Event_Bus, matching the conventions already used by `my-backend/`.
- **Shared SDK:** Dart/Flutter package at `packages/notifications-sdk/` (Event_Contract JSON Schema lives there too) consumed by DukanX and every Sub_App, plus a parallel TypeScript surface where backend producers need it.
- **Shared UI widgets:** Flutter package at `packages/notifications-ui/` (bell, drawer, toast, preferences page).
- **Property-based tests:** `fast-check` for the TypeScript backend and `glados` (or equivalent idiomatic Dart PBT library) for the Dart SDK round-trip property.

The plan is incremental: contracts and storage first, then the service, then channels, then the SDK, then UI, then migration of legacy helpers, then NFRs (security hardening, observability, load + chaos tests, docs). Each property from the design is its own optional sub-task placed next to the implementation it validates, so failing properties surface early.

Phase 1 (`phase1-scan-report.md`) and Phase 2 (`phase2-event-registry.md`) are discovery deliverables and are scheduled first; they gate downstream registry-driven work per Requirement 18.

## Tasks

- [x] 1. Phase 1 — Project_Scan_Report deliverable
  - [x] 1.1 Generate the Project_Scan_Report at `.kiro/specs/unified-notification-system/phase1-scan-report.md`
    - Enumerate every Flutter screen file under `Dukan_x/lib/`, `school_admin_app/lib/`, `school_student_app/lib/`, `school_teacher_app/lib/`, grouped by app and feature module
    - Enumerate every backend module/service/controller/endpoint under `my-backend/`, `voice-backend/`, `lambda/`, `lambda/staff-attendance/`
    - Document each cross-module end-to-end workflow (invoice→payment, purchase→inventory, service-job→warranty, restaurant order→kitchen→billing, school fee→payment→receipt, leave→approval→attendance, exam→result→report card)
    - List every Trigger_Point as `(file_path, symbol, event_name_candidate, observed_state_change)` and mark each `justified` (with recipient, reason, action) or `rejected` (with reason)
    - List every existing notification helper / emitter (`service_job_notification_service.dart`, `restaurant_notification_service.dart`, `security_notification_service.dart`, `customer_notifications_repository.dart`, `customer_notifications_screen.dart`, `alerts_notifications_screen.dart`, `ac_notifications_screen.dart`, `school_student_app/.../notifications_screen.dart`, `my-backend/src/handlers/modules/school-erp/school-notifications.ts`)
    - List every distinct user role and the candidate events it should receive
    - Add Architecture_Overview, Sub_Apps, and Gaps sections; resolve every `TODO`/`unknown` before marking complete
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.11a, 1.12_

- [x] 2. Phase 2 — Notification_Event_Registry deliverable
  - [x] 2.1 Author the Notification_Event_Registry at `.kiro/specs/unified-notification-system/phase2-event-registry.md`
    - Define every event with: `category`, `sub_category`, `event_name` (snake_case `<domain>.<entity>.<action>`), `trigger_condition`, `source_module`, `consumer_roles`, `consumer_apps`, `priority`, `channels_per_role`, `deduplication_rule`, `silence_conditions`, `justification`
    - Restrict `category` to {billing, orders, payments, inventory, users, system, delivery, reports} and `priority` to {critical, high, normal, low}
    - Define batched events (with `batch_window_seconds` and `summary_payload` schema) for any multi-item operation
    - Add `notification_fatigue_risks`, `rejected_candidates`, and per-role recipient mappings (admin, cashier, accountant, delivery_agent, vendor, customer, chef, kitchen_staff, waiter, school_admin, teacher, student, parent, clinic_doctor, pharmacist, jewellery_artisan, service_technician)
    - Cover every domain area listed in 2.14 (billing, payments, inventory, purchase, customer/vendor, jewellery, restaurant, clinic/pharmacy, school, service/warranty, delivery, auto_parts/computer_shop, decoration_catering, vegetable_broker, security/audit, system health)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 17.1, 17.2_

- [x] 3. Phase 3 — Architecture document and Event_Contract schema
  - [x] 3.1 Author the Phase 3 architecture document at `.kiro/specs/unified-notification-system/phase3-architecture.md`
    - Record the single Event_Bus choice (Amazon SNS + SQS) with rationale and a `rejected_alternatives` section (Kafka, Redis Pub/Sub, BullMQ)
    - Lock the canonical component list (one Event_Bus, one Notification_Service, one Delivery_Layer, one Notification_Store, one Preference_Engine, one Sub_App_Sync_Layer, one Shared_SDK)
    - Pin reliability tiers, deduplication semantics, retry budgets, DLQ routing, channel matrix, performance targets, and security model from `design.md`
    - _Requirements: 3.1, 18.3, 20.1, 20.2, 20.3_

  - [x] 3.2 Define the Event_Contract JSON Schema at `packages/notifications-sdk/event-contract.schema.json`
    - Field-by-field schema for every event payload (id, event_name, category, sub_category, priority, actor_id, target_id, recipients, payload, channels, source_module, source_app, created_at, dedup_key, dedup_scope_fields)
    - Cover the union of event shapes implied by the Phase 2 registry
    - _Requirements: 8.1, 8.6_

- [x] 4. Notification_Store (DynamoDB) — schemas, GSIs, and projections
  - [x] 4.1 Implement DynamoDB table definitions and GSIs under `my-backend/src/notifications/store/`
    - `notification.repo.ts` — CRUD + cursor pagination for `Notification` records (fields per REQ 6.1) with the lifecycle ordering invariant `created_at ≤ dispatched_at ≤ delivered_at ≤ read_at` enforced on every transition
    - `user-preference.repo.ts` — CRUD for `UserPreference` records (fields per REQ 6.2) with optimistic `version` updates
    - `audit-log.repo.ts` — append-only `AuditLog` writes (fields per REQ 6.3); reject any update/delete attempts
    - GSIs: `by-user-status` on `(user_id, status, created_at)`, `by-user-category` on `(user_id, category, created_at)`, `by-dedup-key` on `(dedup_key, created_at)`
    - Cursor-based pagination encoding `(user_id, created_at, notification_id)`
    - Archive_Period (90 d default) eviction job hook (cold-storage move only — no business logic in this task)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7a, 6.8, 6.9, 19.2_

  - [x] 4.2 Implement the unread-count projection under `my-backend/src/notifications/store/unread-count.projection.ts`
    - DynamoDB Streams (or equivalent) handler that updates per-user `unread_count` within 100 ms p95 of any `delivered`/`read` transition
    - Record elapsed update time into the `delivery_latency_ms` histogram surface defined in task 11.1
    - Continue processing under load spikes rather than dropping updates
    - _Requirements: 6.7, 13.1_

  - [x] 4.3* Write property test for lifecycle ordering invariant
    - **Property 6: Lifecycle ordering invariant** — for any sequence of state-transition operations on a `Notification` record, `created_at ≤ dispatched_at ≤ delivered_at ≤ read_at` always holds (with `null` permitted for any unset trailing timestamp), and any out-of-order transition is rejected
    - Use `fast-check`; minimum 100 iterations; tag the test with `Feature: unified-notification-system, Property 6: Lifecycle ordering invariant`
    - **Validates: Requirements 6.7, 6.7a**

  - [x] 4.4* Write unit tests for repositories and projection
    - GSI access patterns return correct records; cursor pagination round-trips; `AuditLog` rejects update/delete; unread-count projection updates within 100 ms on a synthetic stream event
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9_

- [x] 5. Event_Bus (SNS + SQS) wiring
  - [x] 5.1 Implement the canonical Event_Bus module under `my-backend/src/notifications/event-bus/`
    - `publisher.ts` — accepts a publish from any Producer, validates the payload against the Event_Contract JSON Schema before acknowledging, persists durably via SNS+SQS, returns acknowledgement only after durable persistence
    - `consumer.ts` — subscribes consumers from each consumer's last committed offset (SQS cursor), resumes correctly after restart, applies exponential backoff up to 5 retries, routes exhausted events to the DLQ with original payload, last error, retry count, and timestamps preserved
    - `delivery-modes.ts` — apply `at_least_once` for `critical`/`high`, `at_most_once_with_dedup` for `normal`/`low`
    - Local outbox shim that producers can use when SNS is unavailable; replays buffered events in `created_at` ascending order on recovery
    - Reject schema-invalid publishes with a structured validation error and persist nothing
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 9.1, 9.2, 9.3, 9.7, 9.8_

  - [x] 5.2* Write property test for no-event-loss across Event_Bus restart
    - **Property 2: No event loss across Event_Bus restart** — for any sequence of accepted (publish-acknowledged) events and any restart injected at any point during in-flight delivery, every accepted event is eventually delivered to every authorized recipient after recovery
    - Use `fast-check` with a fault-injection harness that simulates SNS/SQS unavailability and consumer restart; minimum 100 iterations; tag with `Feature: unified-notification-system, Property 2: No event loss across Event_Bus restart`
    - **Validates: Requirements 3.5, 9.8, 15.4**

  - [x] 5.3* Write unit tests for publisher / consumer / delivery modes
    - Schema validation rejection path; durable-persist-before-ack ordering; backoff math; DLQ payload preservation
    - _Requirements: 3.3, 3.6, 3.9, 3.10_

- [x] 6. Notification_Service core (rule engine, deduplication, lifecycle)
  - [x] 6.1 Implement `Notification_Service` under `my-backend/src/notifications/service/`
    - `notification.service.ts` exposing `createNotification(event)`, `dispatch(notification_id)`, `markAsRead(notification_id, user_id)`, `getUserPreferences(user_id)`, `setUserPreferences(user_id, preferences)`, `getReplay(since, app)`
    - `dedup.ts` — Deduplication_Key = `(event_name, actor_id, target_id, dedup_scope_fields)`; Deduplication_Window default 60 s, overridable per event; lookups use the `by-dedup-key` GSI
    - `authz.ts` — caller authorization on `createNotification`; per-recipient authorization at `dispatch` against `(event_name, target_id)`; failed callers rejected without persisting; failed recipients silently omitted
    - `lifecycle.ts` — transitions `emitted → queued → dispatched → delivered → read` (and `failed`) with the ordering invariant from task 4.1; idempotent `markAsRead`; idempotent `setUserPreferences`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11_

  - [x] 6.2* Write property test for deduplication-window correctness
    - **Property 1: Deduplication-window correctness** — for any sequence of `createNotification` calls and any pair sharing a Deduplication_Key K and a recipient R within the configured Deduplication_Window W, R receives at most 1 delivery for K within any rolling window of length W
    - Use `fast-check`; minimum 100 iterations; tag with `Feature: unified-notification-system, Property 1: Deduplication-window correctness`
    - **Validates: Requirements 4.4, 9.2, 15.5**

  - [x] 6.3* Write property test for recipient-authorization on every dispatch
    - **Property 3: Recipient authorization on every dispatch** — for any dispatched notification N and any recipient R that actually receives a delivery on any channel, R satisfies the recipient-authorization predicate against N's `event_name` and `target_id` under the prevailing RBAC rules
    - Generate random RBAC tables, recipient sets, and event sequences; assert no unauthorized delivery; minimum 100 iterations; tag with `Feature: unified-notification-system, Property 3: Recipient authorization on every dispatch`
    - **Validates: Requirements 4.11, 12.1, 15.8, 15.15**

  - [x] 6.4* Write property test for `markAsRead` idempotence
    - For any sequence of `markAsRead(notification_id, user_id)` calls, the `read_at` timestamp is set on the first call and unchanged on subsequent calls
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property: markAsRead idempotence`
    - **Validates: Requirements 4.6, 15.9**

  - [x] 6.5* Write unit tests for the service
    - `createNotification` rejects unauthorized callers without persisting; duplicate dispatch records `skipped_duplicate` audit entry; `setUserPreferences` validates against schema and writes atomically
    - _Requirements: 4.2, 4.4, 4.8, 4.10_

- [x] 7. Preference_Engine
  - [x] 7.1 Implement the `Preference_Engine` under `my-backend/src/notifications/preferences/`
    - `resolver.ts` — resolution order: `per_event_channels` → `per_category_channels` → role-level default → system default; quiet-hours suppression of `push`/`sms`/`email` for non-`critical`; `critical` bypass; mute on `target_id` (and `event_name` where the registry permits) overridable only by un-mutable critical events; self-suppression when `actor_id == recipient.user_id`
    - `quiet-hours.ts` — local-time evaluation against `quiet_hours_start`/`quiet_hours_end`/`quiet_hours_timezone`
    - Stateless apart from reading `UserPreference` records; target <10 ms p95
    - _Requirements: 7.1, 7.2, 7.2a, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_

  - [x] 7.2* Write property test for preference idempotence
    - **Property 5: Preference idempotence** — for any user `u` and any valid `UserPreference` payload P, invoking `setUserPreferences(u, P)` one or more times yields the same stored record and the same resolved preference output for any subsequent event evaluation
    - Use `fast-check`; minimum 100 iterations; tag with `Feature: unified-notification-system, Property 5: Preference idempotence`
    - **Validates: Requirements 4.9, 7.7, 15.7**

  - [x] 7.3* Write property test for the preference-respect invariant
    - For any randomly generated `UserPreference` payload P (per_category_channels, per_event_channels, quiet_hours_*, mute_targets) and any randomly generated event `e`, no recipient receives a delivery on any channel that P suppresses for `e` (mute, opted-out channel, or non-`critical` event during quiet hours)
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property: preference-respect`
    - **Validates: Requirements 7.1, 7.2, 7.2a, 7.3, 7.4, 7.5, 7.6, 15.12**

  - [x] 7.4* Write unit tests for the resolver
    - Each rule in resolution order; quiet-hours edge cases at boundary minutes; un-mutable critical event override; `actor==recipient` suppression
    - _Requirements: 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 8. Checkpoint — Core service + storage + bus integration
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Delivery_Layer channel adapters
  - [x] 9.1 Implement the in-app adapter at `my-backend/src/notifications/channels/in-app.ts`
    - WebSocket / SSE transport authenticated with the existing JWT
    - Persist for offline recipients; on reconnect replay in `created_at` ascending order; require per-`notification_id` ack before marking `delivered`
    - 500 ms p95 push latency target under nominal load
    - _Requirements: 5.1, 5.6, 5.7, 5.8, 5.8a_

  - [x] 9.2 Implement the push adapter at `my-backend/src/notifications/channels/push.ts`
    - Firebase Cloud Messaging client; up to 3 retries with exponential backoff on transient errors; on exhaustion record a `failed` lifecycle event and route to the DLQ
    - _Requirements: 5.2, 5.9, 9.3_

  - [x] 9.3 Implement the email adapter at `my-backend/src/notifications/channels/email.ts`
    - SMTP client; up to 3 retries with exponential backoff on transient SMTP errors
    - _Requirements: 5.3, 5.10_

  - [x] 9.4 Implement the SMS adapter at `my-backend/src/notifications/channels/sms.ts`
    - Twilio (or env-configured equivalent) client; up to 3 retries with exponential backoff
    - _Requirements: 5.4, 5.11_

  - [x] 9.5 Implement the webhook adapter at `my-backend/src/notifications/channels/webhook.ts`
    - Signed HTTPS POST with `X-Signature` header computed over the payload using a per-consumer shared secret; up to 5 retries with exponential backoff before DLQ on persistent non-2xx
    - _Requirements: 5.5, 5.12, 5.13_

  - [x] 9.6 Wire the `Delivery_Layer` façade at `my-backend/src/notifications/channels/index.ts`
    - Pluggable adapter registry consumed by `Notification_Service.dispatch`; failure isolation between adapters (an SMTP outage must not block other channels)
    - Per-user per-channel rate limits (defaults: in_app 60/min, push 20/min, email 10/min, sms 5/min, webhook 60/min); on limit hit, coalesce subsequent same-`event_name` notifications into a batched summary delivered after the window resets
    - _Requirements: 5.1–5.5, 9.5, 9.6_

  - [x] 9.7* Write property test for at-least-once delivery on critical/high
    - For any sequence of valid `critical`/`high` events and any randomly injected transient channel failures within the configured retry budget, every authorized recipient eventually receives at least one delivery on at least one channel allowed by the Preference_Engine
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property: at-least-once delivery for critical/high`
    - **Validates: Requirements 9.1, 15.11**

  - [x] 9.8* Write property test for batching invariant
    - For every batched event with batch window W, no individual item triggers a separate delivery within W
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property: batching invariant`
    - **Validates: Requirements 9.6, 15.10**

  - [x] 9.9* Write unit tests per adapter
    - Retry math, signature header for webhook, JWT auth for in-app, ack-required-before-delivered, rate-limit coalescing
    - _Requirements: 5.6, 5.8, 5.9, 5.10, 5.11, 5.12, 5.13, 9.5, 9.6_

- [x] 10. Sub_App_Sync_Layer (replay endpoint and ack handling)
  - [x] 10.1 Implement the replay endpoint and ack pipeline at `my-backend/src/notifications/sync/`
    - JWT-authenticated WebSocket/SSE entry; per-`notification_id` ack required within 30 s, otherwise retry under channel policy
    - `GET /notifications/replay?since=<ISO_DATE>&app=<sub_app_name>` — returns notifications targeted at users of that Sub_App with `created_at >= since` in ascending order
    - Bound by Replay_Window default 7 days; out-of-window requests return structured error `replay_window_exceeded`; in-window-with-no-matches returns HTTP 200 with empty `notifications` array and next-cursor = `since`
    - Reject Sub_App publishes whose payload fails Event_Contract validation with a structured error naming the offending fields
    - _Requirements: 8.2, 8.3, 8.4, 8.5, 8.5a, 8.7_

  - [x] 10.2* Write property test for replay completeness
    - For any randomly generated sequence of events produced while a Sub_App is offline and then reconnected, the replay endpoint returns exactly the subset targeting users of that Sub_App, in `created_at` ascending order, with no event omitted and no duplicate beyond the deduplication boundary
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property: replay completeness`
    - **Validates: Requirement 15.13**

  - [x] 10.3* Write unit tests for the sync layer
    - Out-of-window error code; empty-result happy path; ack-timeout retry; auth rejection
    - _Requirements: 8.2, 8.3, 8.5, 8.5a, 8.7_

- [x] 11. Shared_SDK (`@dukanx/notifications`) — Dart/Flutter package
  - [x] 11.1 Implement the SDK at `packages/notifications-sdk/`
    - Public API: `subscribe(eventName, handler)`, `emit(event)`, `onNotification(handler)`, `replay(sinceIso)`
    - Bundle and consume the JSON Schema at `packages/notifications-sdk/event-contract.schema.json` for client-side validation before `emit`
    - Offline outbox: queue emitted events locally while disconnected; flush in `created_at` ascending order on next successful connect
    - JWT-bearer auth, identical to existing DukanX/Sub_App APIs
    - _Requirements: 8.1, 8.8, 10.5, 19.1_

  - [x] 11.2* Write property test for Event_Contract round-trip (SDK side, Dart)
    - **Property 4: Event_Contract parser/serializer round-trip** — for any valid Event_Contract event `e`, `parse(serialize(e))` is structurally equivalent to `e`
    - Use `glados` (or equivalent idiomatic Dart PBT library); minimum 100 iterations; tag with `Feature: unified-notification-system, Property 4: Event_Contract parser/serializer round-trip`
    - **Validates: Requirements 8.6, 15.6**

  - [x] 11.3* Write the matching Event_Contract round-trip property test on the backend (TS)
    - Same property, `fast-check` against the TypeScript serializer/parser pair so backend-side compatibility is locked in
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property 4 (TS): Event_Contract parser/serializer round-trip`
    - **Validates: Requirements 8.6, 15.6**

  - [x] 11.4* Write unit tests for the SDK
    - Outbox flush ordering on reconnect; emit-while-offline survives a process restart; schema-validation rejection before emit
    - _Requirements: 8.8, 10.5_

- [x] 12. Shared UI widgets package
  - [x] 12.1 Implement shared Flutter widgets at `packages/notifications-ui/`
    - Notification bell widget showing the current unread count for the signed-in user; updates within 1 s p95 on a connected client; shows a `stale` indicator when an outstanding server-side change has not propagated within 1 s
    - Notification drawer in `created_at` descending order with cursor-based pagination and category filter; calls `markAsRead` when an item is opened
    - In-app toast surfacing newly arrived `critical`/`high` notifications immediately
    - Preferences page: per-category channels, per-event channels, Quiet_Hours, `mute_targets`
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.6a_

  - [x] 12.2* Write widget snapshot/unit tests
    - Bell stale-indicator only when an outstanding pending change exists; drawer pagination and `markAsRead` call on open; toast triggers only for `critical`/`high`; preferences page round-trips through `getUserPreferences`/`setUserPreferences`
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.6a_

- [x] 13. Checkpoint — End-to-end UNS path live (no consumers wired yet)
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Migration — replace legacy notification helpers
  - [x] 14.1 Initialize `migration_status.md` at `.kiro/specs/unified-notification-system/migration_status.md`
    - One row per Trigger_Point listed in the Phase 1 scan: legacy file, UNS replacement, migration window timestamps, equivalence-test status
    - Enforce the invariant that exactly one path (legacy OR UNS) is active per Trigger_Point at any time
    - _Requirements: 19.4, 19.5, 10.7_

  - [x] 14.2 Migrate `Dukan_x/lib/.../service_job_notification_service.dart` to the Shared_SDK
    - Replace direct emissions with `Shared_SDK.emit(...)` calls bound to the registry-defined event names
    - Record before/after recipient set, channel set, message content; commit the equivalence test result; remove the legacy helper for this module immediately upon entering the migration window
    - _Requirements: 10.7, 10.8, 10.9, 10.9a, 19.4, 19.5_

  - [x] 14.3 Migrate `Dukan_x/lib/.../restaurant_notification_service.dart` to the Shared_SDK
    - Same pattern as 14.2 (emit through SDK, record equivalence, remove legacy helper)
    - _Requirements: 10.7, 10.8, 10.9, 10.9a, 19.4, 19.5_

  - [x] 14.4 Migrate `Dukan_x/lib/.../security_notification_service.dart` to the Shared_SDK
    - Same pattern as 14.2
    - _Requirements: 10.7, 10.8, 10.9, 10.9a, 19.4, 19.5_

  - [x] 14.5 Migrate `Dukan_x/lib/features/customers/.../customer_notifications_repository.dart` and `customer_notifications_screen.dart`
    - Replace repository emissions with SDK calls; refactor screen to consume the shared drawer/bell widgets from `packages/notifications-ui/`
    - _Requirements: 10.6, 10.7, 10.8, 10.9, 10.9a, 11.2_

  - [x] 14.6 Migrate `Dukan_x/lib/features/academic_coaching/.../ac_notifications_screen.dart` and the school sub-app notification screens
    - Refactor `school_admin_app/.../announcements_screen.dart`, `school_teacher_app/.../announcements_screen.dart`, `school_student_app/.../notifications_screen.dart` to consume the shared widgets and SDK
    - _Requirements: 10.6, 10.7, 10.8, 10.9, 11.2, 11.4_

  - [x] 14.7 Migrate `my-backend/src/handlers/modules/school-erp/school-notifications.ts`
    - Replace direct emissions with publishes through the Event_Bus publisher
    - _Requirements: 10.7, 10.8, 10.9, 19.5_

  - [x] 14.8 Migrate `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart` and `Dukan_x/lib/features/dashboard/presentation/widgets/upcoming_payments_panel.dart`
    - Source data from the SDK's `onNotification` stream rather than ad-hoc polling
    - _Requirements: 10.6, 10.7, 11.2_

  - [x] 14.9 Wire every remaining Trigger_Point from the registry to a `createNotification` call
    - For each registry row, add the `Shared_SDK.emit(...)` (frontend) or backend publisher call (backend) at the producing site
    - _Requirements: 10.8_

  - [x] 14.10* Write end-to-end integration tests under `my-backend/tests/notifications/integration/`
    - At least one test per category in the registry; each test exercises Producer → Event_Bus → Notification_Service → Delivery_Layer → recipient acknowledgement
    - _Requirements: 10.8, 10.10, 15.2_

- [x] 15. Checkpoint — All legacy helpers removed, single path enforced
  - Ensure all tests pass, ask the user if questions arise.

- [x] 16. Phase 5 — Security hardening
  - [x] 16.1 Add per-Producer publish rate-limit middleware to the Event_Bus publisher
    - Default 1000 events/minute per Producer, configurable; evaluated independently of and prior to authorization
    - _Requirements: 12.4_

  - [x] 16.2 Add unconditional payload sanitization to `Notification_Service.createNotification` and to channel adapters
    - Strip scripting tags and control characters that could enable XSS in in-app rendering or injection in email templates
    - _Requirements: 12.2_

  - [x] 16.3 Add `unauthorized_access_attempt` Audit_Log writes
    - Write only when a notification read/modify request is denied; never on permitted paths
    - _Requirements: 12.7_

  - [x] 16.4 Enforce redaction of secrets, full PAN, and full government IDs in payloads
    - Add a redaction pass before persistence and before delivery; reject events that try to embed raw values
    - _Requirements: 12.8_

  - [x] 16.5 Implement authenticated retention-configuration endpoint
    - Configurable Archive_Period; every change writes an Audit_Log entry naming actor, previous value, new value, timestamp; reject the change if the Audit_Log subsystem is unavailable
    - _Requirements: 13.4, 13.4a_

  - [x] 16.6* Write property test for authorization monotonicity
    - Revoking a recipient's authorization for an `event_name` prevents that recipient from receiving any subsequent notification of that `event_name`, and does not retroactively withdraw prior deliveries
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property: authorization monotonicity`
    - **Validates: Requirement 15.15**

  - [x] 16.7* Write unit tests for security middleware
    - Rate-limit triggers under floods regardless of auth outcome; sanitization removes `<script>` and control bytes; redaction round-trip
    - _Requirements: 12.2, 12.3, 12.4, 12.8_

- [x] 17. Phase 5 — Observability
  - [x] 17.1 Implement structured lifecycle logging at `my-backend/src/notifications/observability/logger.ts`
    - One log line per transition (`emitted`, `queued`, `dispatched`, `delivered`, `read`, `failed`) including `notification_id`, `event_name`, `recipient_id`, `channel`, `timestamp`
    - _Requirements: 14.1_

  - [x] 17.2 Implement metrics surface at `my-backend/src/notifications/observability/metrics.ts`
    - Counters: `events_emitted_total{event_name,priority,source_app}`, `notifications_dispatched_total{event_name,channel,priority}`, `notifications_failed_total{event_name,channel,error_reason}`
    - Histogram: `delivery_latency_ms{channel}` with rolling-5-minute p95
    - _Requirements: 14.2, 14.3, 14.4, 14.5_

  - [x] 17.3 Implement the failure-rate alert at `my-backend/src/notifications/observability/alerts.ts`
    - Fire `alert.notifications.high_failure_rate` when the rolling 5-minute ratio `notifications_failed_total / notifications_dispatched_total > 5%` AND the denominator is `≥ 1`; do not fire when the denominator is 0
    - _Requirements: 14.6_

  - [x] 17.4* Write property test for unread-count consistency
    - For any sequence of `createNotification`, `dispatch`, `markAsRead` operations on a recipient `r`, the unread-count endpoint returns exactly the cardinality of `r`'s notifications with status `delivered` and `read_at == null`
    - Minimum 100 iterations; tag with `Feature: unified-notification-system, Property: unread-count consistency`
    - **Validates: Requirement 15.14**

  - [x] 17.5* Write unit tests for observability surface
    - Log line shape; counter labels; histogram bucketing; alert non-fire when denominator is 0
    - _Requirements: 14.1, 14.5, 14.6_

- [x] 18. Phase 5 — Load and chaos tests
  - [x] 18.1 Author the load-test plan at `.kiro/specs/unified-notification-system/phase5-load-plan.md`
    - 100 / 1 000 / 10 000 concurrent users; 500 sustained-concurrent + 5 minutes; thresholds: in-app p95 ≤ 500 ms, unread-count p95 ≤ 50 ms, history p95 ≤ 200 ms; availability > 99.9%; zero event loss
    - _Requirements: 13.1, 13.2, 13.3, 13.5, 13.6_

  - [x] 18.2 Implement the load test runner under `my-backend/tests/notifications/load/`
    - Drive 500 concurrent users for ≥5 minutes; assert end-to-end p95 in `[1 ms, 500 ms]` (a measured p95 below 1 ms fails the test as a measurement error)
    - _Requirements: 15.3_

  - [x] 18.3 Implement the chaos test under `my-backend/tests/notifications/chaos/`
    - Actually terminate the Event_Bus process during in-flight delivery; assert every accepted event is eventually delivered to every authorized recipient after recovery
    - _Requirements: 15.4_

- [x] 19. Phase 5 — Documentation
  - [x] 19.1 Author `docs/NOTIFICATION_ARCHITECTURE.md`
    - System diagram (mirroring the `design.md` Mermaid diagram), the chosen Event_Bus rationale, data models, reliability tier table, channel matrix
    - Reference the full Notification_Event_Registry as a table
    - "How to add a new notification" guide (registry entry → emit from feature module → recipients → channels → tests)
    - "How to add a new Sub_App" guide (SDK install → JWT acquisition → subscribe → handle replay → register channels)
    - _Requirements: 16.1, 16.2, 16.3, 16.4_

  - [x] 19.2 Add inline comments at non-obvious sites
    - Rule resolution, deduplication evaluation, retry policy, preference resolution, lifecycle ordering, replay cursor handling
    - Do not add comments that solely restate trivial behavior
    - _Requirements: 16.5_

- [x] 20. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP; they include all unit, property, integration, load, and chaos tests.
- Each task references specific requirements (granular sub-requirements like `7.2a`, `8.5a`, `13.4a`, `6.7a`, `1.11a`, `10.9a`, where applicable) for traceability.
- The six universal correctness properties from `design.md` each appear as their own optional sub-task placed close to the implementation that satisfies them, so a failing property surfaces early. Additional property-based tests required by REQ 15.9–15.15 are also included as separate sub-tasks.
- Property tests use `fast-check` on the TypeScript backend and `glados` (or equivalent idiomatic Dart PBT library) on the Dart SDK side; each test runs at least 100 iterations and is tagged `Feature: unified-notification-system, Property N: <text>` per the design's testing strategy.
- Migration tasks (section 14) preserve user-visible behavior per Requirement 10.9 / 10.9a and are gated by the equivalence-test record in `migration_status.md`. The legacy helper for a module is removed immediately upon entering the migration window for that module, per Requirement 19.5.
- Phase 5 deliverables (security, observability, load, chaos, docs) are scheduled after migration in this plan but, per Requirement 18.5, may proceed in parallel with Phase 4 implementation against the Phase 3 architecture document, with re-validation against the final Phase 4 implementation before the feature is marked complete.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["3.1", "3.2"] },
    { "id": 3, "tasks": ["4.1", "5.1"] },
    { "id": 4, "tasks": ["4.2", "4.3", "4.4", "5.2", "5.3"] },
    { "id": 5, "tasks": ["6.1"] },
    { "id": 6, "tasks": ["6.2", "6.3", "6.4", "6.5", "7.1"] },
    { "id": 7, "tasks": ["7.2", "7.3", "7.4"] },
    { "id": 8, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.5", "10.1", "11.1"] },
    { "id": 9, "tasks": ["9.6", "10.2", "10.3", "11.2", "11.3", "11.4"] },
    { "id": 10, "tasks": ["9.7", "9.8", "9.9", "12.1"] },
    { "id": 11, "tasks": ["12.2", "14.1"] },
    { "id": 12, "tasks": ["14.2", "14.3", "14.4", "14.5", "14.6", "14.7", "14.8"] },
    { "id": 13, "tasks": ["14.9"] },
    { "id": 14, "tasks": ["14.10", "16.1", "16.2", "16.3", "16.4", "16.5", "17.1", "17.2", "17.3", "18.1", "19.1", "19.2"] },
    { "id": 15, "tasks": ["16.6", "16.7", "17.4", "17.5", "18.2", "18.3"] }
  ]
}
```
