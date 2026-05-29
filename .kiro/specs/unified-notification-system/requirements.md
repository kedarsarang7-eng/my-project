# Requirements Document

## Introduction

The Unified Notification System (UNS) is a single, real-time notification platform serving DukanX (the Flutter desktop billing and business management core) and all of its connected sub-applications (school_admin_app, school_student_app, school_teacher_app, archived restaurant POS/chef apps, and any future sub-apps in the workspace). It replaces the current set of fragmented, per-feature notification helpers (service_job_notification_service, restaurant_notification_service, security_notification_service, customer_notifications_repository, ac_notifications_screen, school-notifications.ts, etc.) with one canonical event bus, one notification service, one delivery layer, one notification store, one preference engine, and one shared SDK consumed by all front-ends.

The system MUST be delivered in five sequential phases. Phase 1 is a discovery deliverable (a structured project scan report) and is itself a tracked requirement. Phase 2 produces a Notification Event Registry that justifies every notification by recipient, reason, and resulting action. Phase 3 fixes a single canonical architecture (event bus, services, schemas, reliability tier per priority, and cross-app sync). Phase 4 implements production-ready code with no stubs and wires every approved trigger point. Phase 5 enforces non-functional guarantees: security, performance at 10,000 concurrent users, observability, automated testing, and documentation.

This document expresses each phase as testable requirements using EARS patterns and INCOSE quality rules. Correctness properties (deduplication window, no event loss across event-bus restart, recipient authorization on every dispatch, parser/serializer round-trip for the shared event contract, preference idempotence) are stated explicitly so they can be verified with property-based tests and integration tests downstream.

## Glossary

- **Notification**: A persisted, addressed message produced by the Notification_System describing a state change or action that one or more Recipients need to know about. Each Notification has a unique `notification_id`, an `event_name`, a `payload`, a `priority`, a `category`, a recipient list, a per-channel selection, and a lifecycle status.
- **Event**: An Event_Contract-conformant message published by a Producer onto the Event_Bus that describes something that happened (state change, user action, system condition). One Event MAY result in zero, one, or many Notifications, depending on rule evaluation, deduplication, and Preference_Engine resolution.
- **Dispatch**: The act of resolving Recipients, evaluating preferences and deduplication, and forwarding a Notification to one or more channel adapters in the Delivery_Layer for delivery. A Notification is dispatched when its lifecycle transitions to `dispatched`.
- **Channel**: A transport mechanism through which a Notification reaches a Recipient. The supported Channels are `in_app`, `push`, `sms`, `email`, and `webhook`. Each Channel has its own adapter, retry policy, rate limit, and authentication mechanism.
- **Role**: A named permission group assigned to a user (for example `admin`, `cashier`, `accountant`, `delivery_agent`, `vendor`, `customer`, `chef`, `kitchen_staff`, `waiter`, `school_admin`, `teacher`, `student`, `parent`, `clinic_doctor`, `pharmacist`, `jewellery_artisan`, `service_technician`). Roles drive default Channel selection, default opt-ins, and authorization checks at dispatch time.
- **Deduplication**: The process by which the Notification_Service prevents the same logical Notification from being delivered to the same Recipient more than once within the Deduplication_Window, using the Deduplication_Key.
- **Mute**: A user-configured suppression rule that disables Notifications whose `target_id` (or `event_name`, where so specified) matches the muted value. Mutes apply across all Channels for the muted target and SHALL NOT be overridden except by `priority` `critical` events that the Notification_Event_Registry explicitly marks as un-mutable.
- **Fatigue_Suppression**: The set of mechanisms that prevent notification overload for a Recipient: per-event batching with a `batch_window_seconds`, per-Recipient per-event hourly caps documented in the `notification_fatigue_risks` section of the Notification_Event_Registry, per-channel rate limits, and coalescing of repeated identical events into summaries.
- **DukanX**: The Flutter desktop application at `Dukan_x/` that hosts billing, inventory, customers, payments, jewellery, restaurant, clinic, pharmacy, academic_coaching, auto_parts, computer_shop, clothing, hardware, decoration_catering, vegetable_broker, delivery_challan, purchase, revenue, refund, and service warranty modules.
- **Sub_App**: Any Flutter application other than DukanX that participates in the notification system, including `school_admin_app`, `school_student_app`, `school_teacher_app`, archived `dukan_restro_pos`, archived `dukan_restro_chef`, and any future sub-apps registered with the system.
- **Backend**: The Node.js/AWS Lambda services under `my-backend/`, `voice-backend/`, `lambda/`, and `lambda/staff-attendance/` that host the server-side logic.
- **Notification_System** (or **UNS**): The full unified notification stack: event bus, Notification_Service, Delivery_Layer, Notification_Store, Preference_Engine, Sub_App_Sync_Layer, and shared SDK.
- **Event_Bus**: The single, canonical asynchronous message broker chosen in Phase 3 that all producers publish to and all internal consumers subscribe to.
- **Notification_Service**: The backend service that owns notification creation, rule evaluation, deduplication, persistence, and dispatch decisions. Exposes `createNotification`, `dispatch`, `markAsRead`, `getUserPreferences`, and `getReplay`.
- **Delivery_Layer**: The set of channel adapters that transport notifications to recipients: WebSocket/SSE for in-app, FCM for push, SMTP for email, Twilio (or equivalent) for SMS, and signed HTTPS for webhook.
- **Notification_Store**: The DynamoDB-backed persistent store of notifications, audit log records, and preferences.
- **Preference_Engine**: The component that resolves per-user, per-role, per-channel, per-category opt-in/out and quiet-hours rules at dispatch time.
- **Sub_App_Sync_Layer**: The cross-app integration surface providing the shared event contract, authentication, retry, acknowledgment, and offline replay endpoint for sub-apps.
- **Shared_SDK**: The `@dukanx/notifications` package consumed by DukanX and every Sub_App; exposes `subscribe`, `emit`, `onNotification`, and `replay` APIs.
- **Event_Contract**: The JSON Schema definition of a notification event payload that every producer and consumer MUST conform to.
- **Notification_Event_Registry**: The Phase 2 deliverable enumerating every notification type, its trigger, source, consumers, priority, channels, deduplication rule, and silence conditions.
- **Project_Scan_Report**: The Phase 1 deliverable: a structured audit of architecture, modules, workflows, candidate trigger points, existing notification code, and gaps.
- **Recipient**: A user (admin, cashier, accountant, delivery_agent, school_admin, teacher, student, parent, chef, kitchen_staff, vendor, customer, etc.) or sub-app target identified by `user_id` and/or `role` who is intended to receive a notification.
- **Producer**: Any module, service, controller, Lambda handler, or sub-app that emits an event to the Event_Bus.
- **Consumer**: Any module, service, sub-app, or external system that receives notifications from the Notification_System.
- **Trigger_Point**: A specific code location (file + symbol) where a state change, action, or event MUST emit an event onto the Event_Bus.
- **Priority_Tier**: One of `critical`, `high`, `normal`, `low`. Tier determines reliability mode and rate-limit profile.
- **Delivery_Mode**: `at_least_once` for `critical`/`high`, and `at_most_once_with_dedup` for `normal`/`low`. The Notification_System provides effective exactly-once semantics at the Recipient by combining at-least-once delivery with the deduplication mechanism.
- **Deduplication_Key**: The deterministic key `(event_name, actor_id, target_id, dedup_scope_fields)` used to suppress duplicate deliveries within the deduplication window.
- **Deduplication_Window**: The time interval within which a Notification with the same Deduplication_Key MUST NOT be delivered to the same Recipient more than once. Default 60 seconds; configurable per event type in the Notification_Event_Registry.
- **Quiet_Hours**: A user-configured time range during which non-`critical` notifications MUST NOT be delivered through push, SMS, or email channels.
- **Replay_Window**: The configurable lookback period (default 7 days) within which a Sub_App MAY request missed events via the replay endpoint.
- **Archive_Period**: The retention period for notifications in the Notification_Store before they are moved to cold storage. Default 90 days, configurable.
- **Audit_Log**: The append-only record of every notification lifecycle transition: `emitted → queued → dispatched → delivered → read` (and `failed` on failure).
- **DLQ**: Dead-letter queue holding events that exceed the retry policy, for manual or scheduled reprocessing.
- **NFR**: Non-functional requirement.

## Requirements

### Requirement 1: Phase 1 — Project Scan Report Deliverable

**User Story:** As the project owner, I want a structured Project_Scan_Report produced before any code is written, so that every later phase decision is grounded in the actual state of DukanX and its sub-apps and no notification is duplicated or missed.

#### Acceptance Criteria

1. THE Notification_System project SHALL produce a Project_Scan_Report file at `.kiro/specs/unified-notification-system/phase1-scan-report.md` as a mandatory deliverable of the Notification_System project, regardless of whether Phase 4 implementation has begun.
2. THE Project_Scan_Report SHALL list every Flutter screen file under `Dukan_x/lib/`, `school_admin_app/lib/`, `school_student_app/lib/`, and `school_teacher_app/lib/`, grouped by application and feature module.
3. THE Project_Scan_Report SHALL list every backend module, service, controller, and API endpoint defined under `my-backend/`, `voice-backend/`, `lambda/`, and `lambda/staff-attendance/`, grouped by service.
4. THE Project_Scan_Report SHALL document each end-to-end user workflow that crosses two or more modules, including at minimum: invoice creation to payment reconciliation, purchase order to inventory update, service job creation to warranty claim, restaurant order to kitchen to billing, school fee assignment to payment to receipt, leave application to approval to attendance, and exam creation to result publication to report card.
5. THE Project_Scan_Report SHALL identify each Trigger_Point as a tuple of (file_path, symbol, event_name_candidate, observed_state_change) for every place in the codebase where a state change, action, or event occurs that another user, role, or sub-app would need to know about.
6. THE Project_Scan_Report SHALL enumerate every existing event emitter, webhook, socket, or pub/sub usage already present in the workspace, including but not limited to: `service_job_notification_service.dart`, `restaurant_notification_service.dart`, `security_notification_service.dart`, `customer_notifications_repository.dart`, `customer_notifications_screen.dart`, `alerts_notifications_screen.dart`, `ac_notifications_screen.dart`, `school_student_app/.../notifications_screen.dart`, and `my-backend/src/handlers/modules/school-erp/school-notifications.ts`.
7. THE Project_Scan_Report SHALL list every distinct user role identified in the workspace and, for each role, the set of candidate event names from the Trigger_Point enumeration that the role has a legitimate need to receive.
8. THE Project_Scan_Report SHALL include an Architecture_Overview section that classifies the workspace as monolith, microservices, or API-first, and SHALL state the existing tech stack: frontend framework, backend runtime, database, and any existing real-time technology found.
9. THE Project_Scan_Report SHALL include a Sub_Apps section listing each Sub_App with its primary domain, its `pubspec.yaml` location, and its current authentication mechanism with the Backend.
10. THE Project_Scan_Report SHALL include a Gaps section listing missing event hooks, missing integrations, and code paths where polling currently substitutes for real-time events.
11. WHERE a candidate Trigger_Point cannot justify a recipient, a reason, and a resulting user action, THE Project_Scan_Report SHALL mark it `rejected` with the justification recorded inline.
11a. THE Project_Scan_Report SHALL NOT be considered complete until every identified Trigger_Point carries an explicit status of `justified` (with recipient, reason, and action recorded) or `rejected` (with the rejection reason recorded).
12. IF the Project_Scan_Report contains any unresolved `TODO` or `unknown` entry under Architecture_Overview, Tech_Stack, or Sub_Apps, THEN THE Notification_System project SHALL block progression to Phase 2 until those entries are resolved.

### Requirement 2: Phase 2 — Notification Event Registry

**User Story:** As the project owner, I want a complete Notification_Event_Registry that defines every notification type with its category, recipients, priority, channels, and suppression rules, so that no unjustified notifications reach users and notification fatigue is prevented by design.

#### Acceptance Criteria

1. THE Notification_System project SHALL produce a Notification_Event_Registry file at `.kiro/specs/unified-notification-system/phase2-event-registry.md` before any Phase 4 implementation code is written.
2. THE Notification_Event_Registry SHALL define each notification type with the following fields: `category`, `sub_category`, `event_name`, `trigger_condition`, `source_module`, `consumer_roles`, `consumer_apps`, `priority`, `channels_per_role`, `deduplication_rule`, and `silence_conditions`.
3. THE Notification_Event_Registry SHALL restrict the value of `category` to exactly one of: `billing`, `orders`, `payments`, `inventory`, `users`, `system`, `delivery`, `reports`.
4. THE Notification_Event_Registry SHALL restrict the value of `priority` to exactly one of: `critical`, `high`, `normal`, `low`.
5. THE Notification_Event_Registry SHALL restrict each entry of `channels_per_role` to a subset of: `in_app`, `push`, `sms`, `email`, `webhook`.
6. THE Notification_Event_Registry SHALL express every `event_name` in `snake_case` using the form `<domain>.<entity>.<action>` (for example `invoice.payment.received`, `inventory.stock.low`, `school.fee.overdue`).
7. THE Notification_Event_Registry SHALL include for every entry a `justification` field that names the recipient role, the reason the recipient needs the event, and the action the recipient is expected to take upon receipt.
8. IF an event candidate from the Phase 1 Trigger_Point list cannot supply all three justification elements (recipient, reason, action), THEN THE Notification_Event_Registry SHALL exclude it and record the exclusion in a `rejected_candidates` section.
9. THE Notification_Event_Registry SHALL allow an entry whose trigger is a generic CRUD operation (`*.create`, `*.update`, `*.delete`) only when the entry carries a complete `justification` field (recipient role, reason, expected action) per clause 7 and a domain-specific qualifier in the `event_name`. Non-CRUD events (for example system health checks or login attempts) SHALL also carry the complete `justification` field per clause 7.
10. WHERE a notification class would otherwise emit one event per item in a multi-item operation, THE Notification_Event_Registry SHALL define a batched event with an explicit `batch_window_seconds` and a `summary_payload` schema instead of per-item events.
11. THE Notification_Event_Registry SHALL define a `notification_fatigue_risks` section that lists each event type with elevated frequency risk, the suppression rule that mitigates it, and the maximum allowed deliveries per Recipient per hour for that event type.
12. THE Notification_Event_Registry SHALL define a `deduplication_rule` for every entry, expressed as the ordered list of payload fields that compose the Deduplication_Key together with the Deduplication_Window in seconds.
13. THE Notification_Event_Registry SHALL define a `silence_conditions` field for every entry that lists the contexts in which the notification MUST be suppressed (for example, when the Recipient is the Actor, when the Recipient has muted the source entity, or when Quiet_Hours apply and the priority is not `critical`).
14. THE Notification_Event_Registry SHALL cover at minimum the following domain areas: billing and invoicing, payments and refunds, inventory and stock, purchase and goods receipt, customer and vendor management, jewellery operations (gold rate alerts, custom orders, repair status, gold scheme maturity), restaurant operations (KOT, order ready, table status), clinic and pharmacy operations (appointments, prescriptions, low-stock medicine), academic_coaching/school operations (admission, fee assignment, fee payment, attendance, exam, result, leave, transport, library, hostel, announcements), service jobs and warranty claims, delivery_challan and dispatch, auto_parts/computer_shop job cards, decoration_catering quote conversion, vegetable_broker reconciliation, security and audit events, and system health.

### Requirement 3: Phase 3 — Single Canonical Event Bus

**User Story:** As an architect, I want exactly one event bus selected and documented for the entire system, so that all producers and consumers integrate against a single, well-defined transport with predictable semantics.

#### Acceptance Criteria

1. THE Notification_System SHALL select exactly one Event_Bus implementation from the candidate set {Redis Pub/Sub, Apache Kafka, BullMQ, Amazon SNS+SQS}, and SHALL document the choice with rationale in `.kiro/specs/unified-notification-system/phase3-architecture.md`.
2. THE Event_Bus SHALL accept publish operations from Producers in DukanX, in any Sub_App, and in any Backend service.
3. WHEN a Producer publishes an event to the Event_Bus, THE Event_Bus SHALL persist the event durably before acknowledging the publish call.
4. WHEN a Consumer subscribes to the Event_Bus, THE Event_Bus SHALL deliver every event matching the subscription topic that occurred after the consumer's last committed offset or replay cursor.
5. IF the Event_Bus restarts, THEN THE Event_Bus SHALL resume delivery to every Consumer from each Consumer's last committed offset without losing any persisted event.
6. WHEN a Producer publishes an event whose payload does not validate against the Event_Contract JSON Schema, THE Event_Bus SHALL reject the publish call with a structured validation error and SHALL NOT deliver the event to any Consumer.
7. THE Event_Bus SHALL guarantee `at_least_once` delivery for events with `priority` in {`critical`, `high`}.
8. THE Event_Bus SHALL guarantee `at_most_once_with_dedup` delivery for events with `priority` in {`normal`, `low`} when combined with the Notification_Service deduplication step.
9. WHEN an event delivery to a Consumer fails, THE Event_Bus SHALL retry delivery using exponential backoff with a configured maximum of 5 retries.
10. IF an event has been retried 5 times without successful delivery, THEN THE Event_Bus SHALL move the event to the DLQ with the original payload, error reason, retry count, and timestamps preserved.

### Requirement 4: Phase 3 — Notification Service API and Behavior

**User Story:** As a backend developer integrating a feature module, I want a single Notification_Service with a stable API for creating, dispatching, reading, and configuring notifications, so that I never write a one-off notification helper again.

#### Acceptance Criteria

1. THE Notification_Service SHALL expose the operation `createNotification(event)` that accepts an Event_Contract-conformant payload and returns a unique `notification_id`.
2. WHEN `createNotification` is called with a valid event, THE Notification_Service SHALL persist a notification record in the Notification_Store with status `emitted` before returning.
3. THE Notification_Service SHALL expose the operation `dispatch(notification_id)` that resolves Recipients, applies the Preference_Engine, applies the deduplication step, and forwards the notification to the Delivery_Layer for each enabled channel.
4. WHEN `dispatch` is called for a notification whose Deduplication_Key has been delivered to the same Recipient within the Deduplication_Window, THE Notification_Service SHALL skip dispatch to that Recipient and SHALL record a `skipped_duplicate` audit entry.
5. THE Notification_Service SHALL expose the operation `markAsRead(notification_id, user_id)` that updates the per-recipient state to `read` and records the `read_at` timestamp.
6. WHEN `markAsRead` is called twice for the same `(notification_id, user_id)` pair, THE Notification_Service SHALL leave the `read_at` timestamp unchanged on the second and subsequent calls.
7. THE Notification_Service SHALL expose the operation `getUserPreferences(user_id)` that returns the user's per-channel and per-category preferences and Quiet_Hours configuration.
8. THE Notification_Service SHALL expose the operation `setUserPreferences(user_id, preferences)` that validates the preferences against the preferences schema and persists them atomically.
9. WHEN `setUserPreferences` is called with the same preferences payload more than once, THE Notification_Service SHALL produce the same stored state on every call (idempotent preference update).
10. IF the caller of `createNotification` is not authorized to emit on behalf of the supplied `actor_id` and `source_module`, THEN THE Notification_Service SHALL reject the call with an authorization error and SHALL NOT persist a notification record.
11. WHEN `dispatch` resolves a Recipient list, THE Notification_Service SHALL evaluate the recipient-authorization check for every Recipient and SHALL include every Recipient that passes the check while omitting only those that fail; the authorization check SHALL be performed against the supplied `event_name` and `target_id`.

### Requirement 5: Phase 3 — Delivery Layer and Channels

**User Story:** As a recipient (admin, cashier, delivery agent, accountant, school admin, teacher, student, chef, customer), I want notifications delivered through the channel that is appropriate for my role and preferences, so that I am informed without being overwhelmed.

#### Acceptance Criteria

1. THE Delivery_Layer SHALL provide an in-app channel that delivers notifications to authenticated DukanX and Sub_App clients over WebSocket or Server-Sent Events.
2. THE Delivery_Layer SHALL provide a push channel that delivers notifications to mobile Sub_Apps using Firebase Cloud Messaging.
3. THE Delivery_Layer SHALL provide an email channel that delivers notifications using SMTP.
4. THE Delivery_Layer SHALL provide an SMS channel that delivers notifications using Twilio or an equivalent SMS provider configured per environment.
5. THE Delivery_Layer SHALL provide a webhook channel that posts notifications to a configured HTTPS endpoint with a signed payload.
6. WHEN the in-app channel client connects, THE Delivery_Layer SHALL authenticate the client using the same JWT mechanism used by the existing DukanX and Sub_App APIs.
7. WHEN a connected in-app client is online and a notification targets that client, THE Delivery_Layer SHALL push the notification within 500 milliseconds at the 95th percentile under nominal load up to 10,000 concurrent in-app connections.
8. IF an in-app client is offline at dispatch time, THEN THE Delivery_Layer SHALL persist the notification in the Notification_Store with status `dispatched` and SHALL deliver pending notifications when the client reconnects, in order of `created_at` ascending. THE Delivery_Layer SHALL NOT mark a notification as `delivered` for an offline Recipient until the client has reconnected and acknowledged receipt of that specific `notification_id`.
8a. THE Delivery_Layer SHALL persist every notification destined for an offline in-app Recipient at dispatch time regardless of any prediction or expectation that the client will reconnect imminently.
9. WHEN the push channel encounters a transient FCM error for a Recipient, THE Delivery_Layer SHALL retry up to 3 times using exponential backoff before recording a `failed` lifecycle event.
10. WHEN the email channel encounters a transient SMTP error, THE Delivery_Layer SHALL retry up to 3 times using exponential backoff before recording a `failed` lifecycle event.
11. WHEN the SMS channel encounters a transient provider error, THE Delivery_Layer SHALL retry up to 3 times using exponential backoff before recording a `failed` lifecycle event.
12. WHEN the webhook channel posts a payload, THE Delivery_Layer SHALL include an `X-Signature` header computed over the payload using a per-consumer shared secret.
13. IF a webhook endpoint returns a non-2xx response, THEN THE Delivery_Layer SHALL retry up to 5 times with exponential backoff and SHALL move the event to the DLQ on persistent failure.

### Requirement 6: Phase 3 — Notification Store Schema

**User Story:** As an operator, I want notifications, preferences, and audit records persisted in DynamoDB with indexes that support the access patterns the front-ends need, so that history queries and unread counts remain fast at scale.

#### Acceptance Criteria

1. THE Notification_Store SHALL persist a `Notification` record with the fields: `notification_id`, `event_name`, `category`, `sub_category`, `priority`, `actor_id`, `target_id`, `recipients` (list of `{user_id, role, channels, status, delivered_at, read_at}`), `payload`, `channels`, `status`, `created_at`, `dispatched_at`, `delivered_at`, `read_at`, `dedup_key`, `source_module`, and `source_app`.
2. THE Notification_Store SHALL persist a `UserPreference` record with the fields: `user_id`, `role`, `per_category_channels`, `per_event_channels`, `quiet_hours_start`, `quiet_hours_end`, `quiet_hours_timezone`, `mute_targets`, `updated_at`, and `version`.
3. THE Notification_Store SHALL persist an `AuditLog` record with the fields: `audit_id`, `notification_id`, `lifecycle_state`, `recipient_id`, `channel`, `attempt`, `outcome`, `error_reason`, and `timestamp`.
4. THE Notification_Store SHALL provide a Global Secondary Index keyed by `(user_id, status, created_at)` that supports retrieving a Recipient's unread notifications in `O(1)` per page.
5. THE Notification_Store SHALL provide a Global Secondary Index keyed by `(user_id, category, created_at)` that supports filtered history queries per user per category.
6. THE Notification_Store SHALL provide a Global Secondary Index keyed by `(dedup_key, created_at)` that supports deduplication lookups in constant time.
7. THE Notification_Store SHALL maintain a per-user `unread_count` projection that is updated within 100 milliseconds of a `delivered` or `read` lifecycle transition under nominal load; under load spikes the projection update SHALL continue processing rather than be dropped, and the elapsed time SHALL be recorded in the `delivery_latency_ms` histogram.
7a. THE Notification_Store SHALL maintain the lifecycle ordering invariant `created_at <= dispatched_at <= delivered_at <= read_at` for every Notification record (with `null` permitted for any unset trailing timestamp), and SHALL reject any state transition that would violate this ordering.
8. THE Notification_Store SHALL retain `Notification` and `AuditLog` records for the configured Archive_Period (default 90 days) and SHALL move records older than the Archive_Period to a cold storage bucket.
9. THE Notification_Store SHALL support cursor-based pagination for notification history queries using an opaque cursor that encodes `(user_id, created_at, notification_id)`.

### Requirement 7: Phase 3 — Preference Engine

**User Story:** As a recipient, I want to control which categories and channels I receive notifications on, with quiet hours, so that I am not interrupted outside the times I choose to be reachable.

#### Acceptance Criteria

1. THE Preference_Engine SHALL evaluate, for every Recipient and every channel of every notification, whether delivery is allowed by combining the Recipient's `UserPreference` record, role-level defaults, and the notification's `silence_conditions`.
2. WHERE a Recipient has set `per_event_channels` for the notification's `event_name`, THE Preference_Engine SHALL deliver to that Recipient on a given channel if and only if that channel is listed in the Recipient's `per_event_channels` for that event, and SHALL ignore the `per_category_channels` value for that event.
2a. WHERE a Recipient has not set `per_event_channels` for the notification's `event_name`, THE Preference_Engine SHALL fall back to the Recipient's `per_category_channels` for the notification's `category`, then to the role-level default Channel set, then to the system default Channel set, in that order.
3. WHILE the current local time at the Recipient is within the Recipient's Quiet_Hours range, THE Preference_Engine SHALL suppress delivery on `push`, `sms`, and `email` channels for notifications whose `priority` is not `critical`.
4. IF a notification has `priority` equal to `critical`, THEN THE Preference_Engine SHALL allow delivery on every channel that the channel adapter supports for the Recipient regardless of Quiet_Hours.
5. WHEN the Recipient is also the Actor of the event (the `actor_id` equals the Recipient's `user_id`), THE Preference_Engine SHALL suppress delivery to that Recipient.
6. WHERE a Recipient has muted a `target_id`, THE Preference_Engine SHALL suppress every notification whose `target_id` matches the muted value.
7. WHEN `setUserPreferences` is called with the same payload more than once, THE Preference_Engine SHALL produce identical resolved preferences on every subsequent evaluation (idempotence).
8. THE Preference_Engine SHALL evaluate every preference resolution in less than 10 milliseconds at the 95th percentile under nominal load.

### Requirement 8: Phase 3 — Sub-App Sync Layer and Shared Event Contract

**User Story:** As a Sub_App developer, I want a single shared event contract and a single auth and replay mechanism, so that any Sub_App can produce and consume events with predictable behavior even when temporarily offline.

#### Acceptance Criteria

1. THE Sub_App_Sync_Layer SHALL define the Event_Contract as a single JSON Schema published at `packages/notifications-sdk/event-contract.schema.json` and consumed by every Producer and every Consumer.
2. WHEN a Sub_App connects to the Notification_System, THE Sub_App_Sync_Layer SHALL authenticate the connection using JWT bearer tokens issued by the Backend's existing auth service.
3. WHEN the Notification_System dispatches a notification to a Sub_App, THE Sub_App_Sync_Layer SHALL require the Sub_App to acknowledge receipt by `notification_id` within 30 seconds; otherwise the dispatch SHALL be retried under the channel's retry policy.
4. WHEN a Sub_App reconnects after being offline, THE Sub_App_Sync_Layer SHALL accept a request to `GET /notifications/replay?since=<ISO_DATE>&app=<sub_app_name>` and SHALL return every notification targeted at users of that Sub_App with `created_at >= since`, in `created_at` ascending order.
5. THE Sub_App_Sync_Layer SHALL bound the replay window so that `now() - since` does not exceed the Replay_Window (default 7 days); requests beyond the bound SHALL return a structured error with code `replay_window_exceeded`, regardless of whether matching notifications happen to exist.
5a. WHEN a replay request is within the bounded Replay_Window and no notifications match the supplied `since` and `app` parameters, THE Sub_App_Sync_Layer SHALL return HTTP 200 with an empty `notifications` array and the next-cursor field set to the request's `since` value.
6. THE Sub_App_Sync_Layer SHALL serialize and deserialize Event_Contract payloads such that for every valid event `e`, `parse(serialize(e))` is structurally equivalent to `e` (round-trip property over the Event_Contract).
7. IF a Sub_App publishes an event whose payload fails JSON Schema validation, THEN THE Sub_App_Sync_Layer SHALL reject the publish with a structured validation error naming the offending fields and SHALL NOT enqueue the event.
8. WHEN a Sub_App emits an event while offline, THE Shared_SDK SHALL queue the event locally and SHALL flush the queue in `created_at` ascending order on next successful connect.

### Requirement 9: Phase 3 — Reliability, DLQ, and Rate Limiting

**User Story:** As an operator, I want explicit reliability guarantees per priority tier, a managed dead-letter queue, and per-user per-channel rate limits, so that the system survives failures without losing critical events and never floods a Recipient.

#### Acceptance Criteria

1. THE Notification_System SHALL apply `at_least_once` delivery semantics to every event with `priority` in {`critical`, `high`}.
2. THE Notification_System SHALL apply `at_most_once_with_dedup` delivery semantics to every event with `priority` in {`normal`, `low`}, ensuring effective once-per-Recipient delivery via the Deduplication_Key.
3. WHEN an event exceeds the configured retry budget on any channel, THE Notification_System SHALL move the event to the DLQ with the original payload, last error, retry count, and last attempt timestamp.
4. THE Notification_System SHALL provide an operator endpoint to list, inspect, and replay DLQ entries.
5. THE Notification_System SHALL enforce a per-user per-channel rate limit configurable per channel; default limits SHALL be: `in_app` 60 per minute, `push` 20 per minute, `email` 10 per minute, `sms` 5 per minute, `webhook` 60 per minute.
6. WHEN a Recipient exceeds the per-channel rate limit, THE Notification_System SHALL coalesce subsequent notifications of the same `event_name` for that Recipient into a single batched summary delivered after the limit window resets.
7. IF the Event_Bus is unavailable at publish time, THEN THE Notification_System SHALL buffer the event in a local outbox on the producing service and SHALL replay buffered events in order on Event_Bus recovery.
8. THE Notification_System SHALL guarantee that no event accepted by the Event_Bus is permanently lost at any time, including across an Event_Bus restart, an Event_Bus failover, a Notification_Service restart, a channel-adapter crash, or any combination of the above.

### Requirement 10: Phase 4 — Implementation Scope and Wiring

**User Story:** As the project owner, I want the implementation to deliver production-ready code with no stubs and to wire every approved Trigger_Point from Phase 1 to the canonical Notification_System, so that the existing fragmented helpers are replaced by one path.

#### Acceptance Criteria

1. THE Notification_System implementation SHALL deliver the Event_Bus setup as a single canonical module under `my-backend/src/notifications/event-bus/`.
2. THE Notification_System implementation SHALL deliver the Notification_Service under `my-backend/src/notifications/service/` exposing the API defined in Requirement 4 with rule-engine and deduplication logic in production-ready code with no stub functions.
3. THE Notification_System implementation SHALL deliver real-time delivery via WebSocket or SSE under `my-backend/src/notifications/realtime/`, integrated with DukanX and every Sub_App.
4. THE Notification_System implementation SHALL deliver channel adapters under `my-backend/src/notifications/channels/` as pluggable modules, one file per channel: `in-app.ts`, `push.ts`, `email.ts`, `sms.ts`, `webhook.ts`.
5. THE Notification_System implementation SHALL deliver the `@dukanx/notifications` Shared_SDK under `packages/notifications-sdk/` exposing `subscribe(eventName, handler)`, `emit(event)`, `onNotification(handler)`, and `replay(sinceIso)`.
6. THE Notification_System implementation SHALL deliver shared frontend components under `packages/notifications-ui/` (or the Flutter equivalent shared package) including a notification bell, a notification drawer, an in-app toast, and a preferences page, consumable by DukanX and every Sub_App.
7. WHEN the Phase 4 implementation is complete, THE Notification_System SHALL replace every existing notification helper listed in the Project_Scan_Report (including `service_job_notification_service.dart`, `restaurant_notification_service.dart`, `security_notification_service.dart`, `customer_notifications_repository.dart`, and `school-notifications.ts`) with calls into the canonical Notification_Service, and SHALL leave no parallel notification path in the codebase.
8. WHEN the Phase 4 implementation is complete, THE Notification_System SHALL wire every Trigger_Point approved in the Notification_Event_Registry to a `createNotification` call on the Notification_Service, and SHALL include an integration test that exercises the path from Trigger_Point to delivered notification for each notification type defined in the Notification_Event_Registry.
9. WHEN a feature module previously emitted a notification through a removed legacy helper, THE Notification_System SHALL preserve the existing user-visible behavior (recipient set, channel set, message content) for that module unless the Notification_Event_Registry explicitly defines a different behavior with documented justification. The behavior-preservation guarantee SHALL apply per-module starting from the timestamp at which the module's migration is recorded as complete in `migration_status.md`; behavior of unmigrated modules continues to be governed by their existing legacy helpers until the per-module migration is complete.
9a. IF the behavior-preservation check for a feature module's migration has not produced a recorded equivalence test result, THEN THE Notification_System SHALL block removal of the legacy helper for that module until the equivalence test result is committed and reviewed.
10. WHEN the Phase 4 implementation is complete, THE Notification_System SHALL provide a single integration test suite under `my-backend/tests/notifications/integration/` that, when executed, exercises the end-to-end path for every notification type in the Notification_Event_Registry. THE Notification_System SHALL NOT consider Phase 4 complete until this integration test suite is committed and passing.

### Requirement 11: Phase 4 — Shared Frontend Components

**User Story:** As a DukanX or Sub_App user, I want consistent notification UI (bell, drawer, toast, preferences) across every app I use, so that my notification experience is the same wherever I sign in.

#### Acceptance Criteria

1. THE Shared_SDK SHALL provide a notification bell widget that displays the current unread count for the signed-in user.
2. THE Shared_SDK SHALL provide a notification drawer widget that lists notifications in `created_at` descending order, supports cursor-based pagination, and supports filtering by category.
3. THE Shared_SDK SHALL provide an in-app toast widget that surfaces newly arrived `critical` and `high` priority notifications immediately.
4. THE Shared_SDK SHALL provide a preferences page widget that allows the signed-in user to configure per-category channels, per-event channels, Quiet_Hours, and `mute_targets`.
5. WHEN the user opens a notification in the drawer, THE Shared_SDK SHALL call `markAsRead` on the Notification_Service for that notification.
6. WHEN a server-side change to the unread count occurs, THE Shared_SDK SHALL update the bell widget within 1 second at the 95th percentile under nominal load on a connected client; if the propagation of any specific server-side change exceeds 1 second on a given client (regardless of load), THE Shared_SDK SHALL display a `stale` indicator on the bell widget for that client until the change is reflected.
6a. THE Shared_SDK SHALL display the `stale` indicator only when there is an outstanding server-side change that has not yet been reflected in the bell widget; THE Shared_SDK SHALL NOT display the `stale` indicator when no server-side change is pending.

### Requirement 12: Phase 5 — Security

**User Story:** As a security reviewer, I want recipient authorization enforced on every dispatch, payload sanitization, sub-app authentication, abuse prevention, and a complete audit log, so that the Notification_System cannot be used as a vector for data leakage or abuse.

#### Acceptance Criteria

1. WHEN the Notification_Service dispatches a notification to a Recipient, THE Notification_System SHALL verify that the Recipient is authorized to receive the event's `event_name` and `target_id` against the existing role-based access control rules; an unauthorized Recipient SHALL NOT receive the notification.
2. THE Notification_System SHALL apply payload sanitization unconditionally to every notification `payload` field before persistence and before delivery, removing scripting tags and control characters that could enable XSS in in-app rendering or injection in email templates, regardless of the apparent safety of the input.
3. WHEN a Sub_App or external Producer connects to the Event_Bus or to the Notification_Service, THE Notification_System SHALL authenticate the connection using JWT or an environment-scoped shared secret, and SHALL reject connections that fail authentication.
4. THE Notification_System SHALL apply per-Producer rate limits at the publish endpoint to prevent abusive event flooding; default limit SHALL be 1000 events per minute per Producer, configurable. Per-Producer rate limiting SHALL be evaluated independently of authorization checks and SHALL apply to every publish attempt regardless of whether the request is subsequently authorized or denied.
5. THE Notification_System SHALL write an Audit_Log entry for every lifecycle transition of every notification: `emitted`, `queued`, `dispatched`, `delivered`, `read`, and `failed`.
6. THE Audit_Log SHALL be append-only; the Notification_System SHALL NOT permit update or delete operations on existing Audit_Log records.
7. IF a request to read or modify a notification is made by a user who is not a Recipient or an authorized administrator, THEN THE Notification_System SHALL deny the request and SHALL record an `unauthorized_access_attempt` Audit_Log entry; the Audit_Log entry SHALL be written only when the request is denied, and SHALL NOT be written for requests that are ultimately granted via a permitted path.
8. THE Notification_System SHALL never include secret values, full payment card numbers, or full government-issued identifiers in notification payloads; instead, it SHALL include redacted references.

### Requirement 13: Phase 5 — Performance and Scale Targets

**User Story:** As an operator, I want measurable performance targets at 100, 1000, and 10,000 concurrent users, so that the system's capacity is known and verified.

#### Acceptance Criteria

1. THE Notification_System SHALL serve unread-count queries for any Recipient in less than 50 milliseconds at the 95th percentile under nominal load up to 10,000 concurrent users.
2. THE Notification_System SHALL serve cursor-based notification history queries returning up to 50 notifications in less than 200 milliseconds at the 95th percentile under nominal load up to 10,000 concurrent users.
3. THE Notification_System SHALL deliver in-app notifications with end-to-end latency from `createNotification` to client receipt of less than 500 milliseconds at the 95th percentile under a sustained load of 500 concurrent users emitting events at the rate prescribed by the Phase 5 load test plan.
4. THE Notification_System SHALL retain notifications for the configured Archive_Period (default 90 days, configurable) and SHALL permit the configured retention to be shortened or lengthened only via an authenticated configuration change that is recorded in an Audit_Log entry naming the actor, the previous value, the new value, and the timestamp.
4a. IF the Audit_Log subsystem is unavailable at the time of a retention configuration change, THEN THE Notification_System SHALL reject the configuration change and SHALL leave the previous Archive_Period in effect.
5. THE Notification_System SHALL be benchmarked at 100, 1000, and 10,000 concurrent users using a documented load-test plan stored at `.kiro/specs/unified-notification-system/phase5-load-plan.md`, with results recorded at `.kiro/specs/unified-notification-system/phase5-load-results.md`.
6. WHEN concurrent user count is at any value up to and including 10,000 in the benchmark, THE Notification_System SHALL maintain availability above 99.9% over the benchmark window with no event loss; the no-event-loss guarantee SHALL apply across the full range from 0 to 10,000 concurrent users.

### Requirement 14: Phase 5 — Observability

**User Story:** As an operator, I want structured lifecycle logs, named metrics, and an actionable failure-rate alert, so that operational health is visible and incidents are caught quickly.

#### Acceptance Criteria

1. THE Notification_System SHALL emit a structured log line for every lifecycle transition: `emitted`, `queued`, `dispatched`, `delivered`, `read`, and `failed`, including `notification_id`, `event_name`, `recipient_id`, `channel`, and `timestamp`.
2. THE Notification_System SHALL expose the metric `events_emitted_total` as a counter labeled by `event_name`, `priority`, and `source_app`.
3. THE Notification_System SHALL expose the metric `notifications_dispatched_total` as a counter labeled by `event_name`, `channel`, and `priority`.
4. THE Notification_System SHALL expose the metric `notifications_failed_total` as a counter labeled by `event_name`, `channel`, and `error_reason`.
5. THE Notification_System SHALL expose the metric `delivery_latency_ms` as a histogram labeled by `channel` and SHALL report a `p95` value over a rolling 5-minute window.
6. WHEN the rolling 5-minute failure rate `notifications_failed_total / notifications_dispatched_total` exceeds 5%, AND `notifications_dispatched_total` over the same rolling window is at least 1, THE Notification_System SHALL fire an `alert.notifications.high_failure_rate` alert to the configured operator channel; if `notifications_dispatched_total` over the rolling window is 0, THE alert SHALL NOT fire.

### Requirement 15: Phase 5 — Testing Strategy

**User Story:** As a quality engineer, I want unit, integration, load, and chaos tests covering the Notification_System, with property-based tests for the correctness invariants, so that the documented guarantees are verified continuously.

#### Acceptance Criteria

1. THE Notification_System test suite SHALL include unit tests for the Notification_Service, the rule engine, the deduplication step, the Preference_Engine, and each channel adapter.
2. THE Notification_System test suite SHALL include integration tests that exercise each major notification type end to end from Producer through Event_Bus and Notification_Service to Delivery_Layer, covering at minimum one event per category in the Notification_Event_Registry.
3. THE Notification_System test suite SHALL include a load test executing 500 concurrent users for at least 5 minutes and SHALL assert end-to-end p95 delivery latency in the range `[1 ms, 500 ms]`; a measured p95 below 1 ms SHALL be treated as a measurement error and SHALL fail the test.
4. THE Notification_System test suite SHALL include a chaos test that actually terminates the Event_Bus process during in-flight event delivery and SHALL assert that, after Event_Bus recovery, every event accepted by the Event_Bus before the kill is eventually delivered to every authorized Recipient (no permanent event loss).
5. THE Notification_System test suite SHALL include a property-based test asserting that for any sequence of `createNotification` calls and any pair of duplicates within the Deduplication_Window, no Recipient receives more than one delivery for that Deduplication_Key.
6. THE Notification_System test suite SHALL include a property-based test asserting that for every valid Event_Contract event `e`, `parse(serialize(e))` is structurally equivalent to `e` (Event_Contract round-trip).
7. THE Notification_System test suite SHALL include a property-based test asserting that `setUserPreferences` is idempotent: invoking it with the same payload more than once produces the same stored state and the same resolved preferences.
8. THE Notification_System test suite SHALL include a property-based test asserting that for every dispatched notification, every Recipient that ultimately receives it satisfies the recipient-authorization check (no unauthorized delivery).
9. THE Notification_System test suite SHALL include a property-based test asserting that `markAsRead` is idempotent: the `read_at` timestamp is set on the first call and unchanged on subsequent calls.
10. THE Notification_System test suite SHALL include a property-based test asserting that for every batched event with batch window `W`, no individual item triggers a separate delivery within `W` (batching invariant).
11. THE Notification_System test suite SHALL include a property-based test asserting at-least-once delivery for every event with `priority` in {`critical`, `high`}: for any randomly generated sequence of valid `critical` or `high` events `E` and any randomly injected transient channel failures within the configured retry budget, every authorized Recipient of every event in `E` SHALL eventually receive at least one delivery for that event on at least one channel allowed by the Preference_Engine.
12. THE Notification_System test suite SHALL include a property-based test asserting the preference-respect invariant: for any randomly generated `UserPreference` payload `P` (including `per_category_channels`, `per_event_channels`, `quiet_hours_*`, and `mute_targets`) and any randomly generated event `e`, no Recipient receives a delivery on any channel that `P` suppresses for `e` (mute, opted-out channel, or non-`critical` event during Quiet_Hours).
13. THE Notification_System test suite SHALL include a property-based test asserting replay completeness: for any randomly generated sequence of events `E` produced while a Sub_App is offline and then reconnected, the result of `GET /notifications/replay?since=<sub_app_disconnect_time>&app=<sub_app_name>` SHALL contain exactly the subset of `E` that targets users of that Sub_App, in `created_at` ascending order, with no event omitted and with no duplicate beyond the deduplication mechanism's allowed boundary.
14. THE Notification_System test suite SHALL include a property-based test asserting unread-count consistency: for every Recipient `r` and every randomly generated sequence of `createNotification`, `dispatch`, and `markAsRead` operations, the value returned by the unread-count endpoint for `r` SHALL be equal to the cardinality of the set of `r`'s notifications whose lifecycle status is `delivered` and whose `read_at` is null.
15. THE Notification_System test suite SHALL include a property-based test asserting that authorization is monotonic: revoking a Recipient's authorization to receive an `event_name` SHALL prevent that Recipient from receiving any notification of that `event_name` emitted strictly after the revocation, and SHALL NOT retroactively withdraw prior deliveries.

### Requirement 16: Phase 5 — Documentation

**User Story:** As a developer onboarding to the project, I want a single architecture document with a system diagram, the event registry, and how-to-add guides, so that I can integrate a new Trigger_Point without re-deriving the system from code.

#### Acceptance Criteria

1. THE Notification_System SHALL provide a documentation file `docs/NOTIFICATION_ARCHITECTURE.md` containing the system diagram, the chosen Event_Bus rationale, the data models, the reliability tier table, and the channel matrix.
2. THE Notification_Architecture documentation SHALL include the full Notification_Event_Registry as a referenced table.
3. THE Notification_Architecture documentation SHALL include a "How to add a new notification" guide covering: defining the event in the Notification_Event_Registry, emitting from a feature module, registering Recipients, choosing channels, and adding tests.
4. THE Notification_Architecture documentation SHALL include a "How to add a new Sub_App" guide covering: SDK install, JWT acquisition, subscribing to events, handling replay, and registering channels.
5. THE Notification_System code SHALL include inline comments in every place where logic is non-obvious (rule resolution, deduplication evaluation, retry policy, preference resolution, lifecycle ordering, replay cursor handling) regardless of whether a reviewer might consider the comment redundant in isolation, and SHALL NOT include comments that solely restate the literal behavior of trivial code.

### Requirement 17: Roles and Recipient Coverage

**User Story:** As the project owner, I want every distinct user role across DukanX and the sub-apps mapped to the events they care about, so that no role is forgotten in the rollout.

#### Acceptance Criteria

1. THE Notification_Event_Registry SHALL include explicit Recipient mappings for at minimum the following roles: `admin`, `cashier`, `accountant`, `delivery_agent`, `vendor`, `customer`, `chef`, `kitchen_staff`, `waiter`, `school_admin`, `teacher`, `student`, `parent`, `clinic_doctor`, `pharmacist`, `jewellery_artisan`, and `service_technician`.
2. WHERE a workspace role is identified in the Project_Scan_Report but is not represented as a Recipient for any event (whether unmapped, intentionally excluded, or pending evaluation), THE Notification_Event_Registry SHALL record an explicit `no_events` justification for that role naming the reason for the exclusion.
3. WHEN a new Sub_App is registered with the Notification_System, THE Notification_System SHALL accept a roles manifest from the Sub_App and SHALL include those roles in subsequent recipient resolution.

### Requirement 18: Sequential Phase Execution

**User Story:** As the project owner, I want phases executed strictly in order, so that earlier deliverables actually inform later ones.

#### Acceptance Criteria

1. THE Notification_System project SHALL NOT begin Phase 2 work until the Project_Scan_Report from Phase 1 is committed and reviewed.
2. THE Notification_System project SHALL NOT begin Phase 3 work until the Notification_Event_Registry from Phase 2 is committed and reviewed.
3. THE Notification_System project SHALL NOT begin Phase 4 implementation work until the architecture document from Phase 3 is committed and reviewed.
4. THE Notification_System project SHALL NOT mark the feature complete until the Phase 5 testing, load benchmark, observability, security checks, and documentation are committed.
5. WHERE Phase 5 deliverables (load test plan, observability setup, security review, documentation) can be authored against the Phase 3 architecture document without the Phase 4 implementation, THE Notification_System project MAY proceed with those Phase 5 deliverables in parallel with Phase 4 implementation, with no additional preconditions, provided each Phase 5 deliverable is re-validated against the final Phase 4 implementation before the feature is marked complete.
6. THE Notification_System project SHALL treat Phase deliverables as completion-eligible only when committed to the repository; reviewed-but-uncommitted deliverables SHALL NOT count toward Phase completion.

### Requirement 19: Integration With Existing Patterns

**User Story:** As a maintainer, I want the Notification_System to integrate with the existing authentication, database, and API patterns used by DukanX and the backend, so that I do not have to maintain a parallel infrastructure.

#### Acceptance Criteria

1. THE Notification_System SHALL authenticate end-user requests using the same JWT mechanism that the existing DukanX and Sub_App APIs use.
2. THE Notification_System SHALL persist data in DynamoDB using the same AWS account, region, and table-naming conventions used by `my-backend/`.
3. THE Notification_System SHALL expose its HTTP endpoints under the existing API gateway that hosts the current Backend services and SHALL follow the same request/response envelope used by current handlers under `my-backend/src/handlers/`.
4. WHEN a feature module currently uses an existing notification helper, THE Notification_System SHALL replace the helper with a call into the Shared_SDK or Notification_Service rather than duplicating logic.
5. WHERE a phased migration is in progress, THE Notification_System MAY allow a legacy helper and the canonical Notification_Service to coexist temporarily across feature modules, provided that (a) every emission path is recorded in a `migration_status.md` document, (b) only one path is active for any given Trigger_Point at any given time, and (c) for any feature module whose migration window has been declared in `migration_status.md`, the legacy helper for that module SHALL be removed immediately upon entering the migration window for that module rather than waiting for the window to expire.

### Requirement 20: Canonical, Single Implementation

**User Story:** As the project owner, I want exactly one canonical implementation of every notification component, so that future contributors do not introduce parallel systems.

#### Acceptance Criteria

1. THE Notification_System SHALL provide exactly one Event_Bus implementation, exactly one Notification_Service implementation, exactly one Delivery_Layer implementation, exactly one Notification_Store implementation, exactly one Preference_Engine implementation, exactly one Sub_App_Sync_Layer implementation, and exactly one Shared_SDK package.
2. WHEN a contributor proposes a second implementation of any of the components in clause 1, THE Notification_System architecture document SHALL require that the existing implementation be replaced rather than duplicated, and SHALL record the migration plan; THE Notification_System SHALL NOT ship a release containing the second implementation until the migration plan has been documented and committed.
3. THE Notification_System SHALL NOT ship multiple options for any component; the Phase 3 architecture document SHALL state the single chosen option for every component and SHALL move alternatives to a `rejected_alternatives` section with rationale. THE Phase 3 architecture document MAY be authored, reviewed, and committed independently of, and prior to, the Phase 4 implementation that fulfills it.
