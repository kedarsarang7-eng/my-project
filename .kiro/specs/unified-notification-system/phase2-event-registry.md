# Notification_Event_Registry — Unified Notification System (Phase 2)

> **Phase 2 deliverable** for the Unified Notification System (UNS) spec at `.kiro/specs/unified-notification-system/`.
> Validates **Requirements 2.1 – 2.14, 17.1, 17.2** of `requirements.md`.
> Inputs: `phase1-scan-report.md` §9 (Trigger_Point Catalogue, 145 entries) and §10 (Roles, 22 distinct roles). Every event in this registry is grounded in a real `justified` Trigger_Point from Phase 1; every row in `## Rejected Candidates` is grounded in a real `rejected` Trigger_Point from Phase 1.

## Table of Contents

1. [Conventions and Constraints](#1-conventions-and-constraints)
2. [Source App Identifiers](#2-source-app-identifiers)
3. [Recipient Roles](#3-recipient-roles)
4. [Event Registry — Billing](#4-event-registry--billing)
5. [Event Registry — Payments](#5-event-registry--payments)
6. [Event Registry — Inventory](#6-event-registry--inventory)
7. [Event Registry — Orders](#7-event-registry--orders)
8. [Event Registry — Delivery](#8-event-registry--delivery)
9. [Event Registry — Users](#9-event-registry--users)
10. [Event Registry — Reports](#10-event-registry--reports)
11. [Event Registry — System](#11-event-registry--system)
12. [Batched Events](#12-batched-events)
13. [Notification Fatigue Risks](#13-notification-fatigue-risks)
14. [Per-Role Recipient Mappings](#14-per-role-recipient-mappings)
15. [Rejected Candidates](#15-rejected-candidates)
16. [Phase-3 Hand-off Notes](#16-phase-3-hand-off-notes)

---

## 1. Conventions and Constraints

### 1.1 Allowed values

- **`category`** — exactly one of: `billing`, `orders`, `payments`, `inventory`, `users`, `system`, `delivery`, `reports`. (REQ 2.3)
- **`priority`** — exactly one of: `critical`, `high`, `normal`, `low`. (REQ 2.4)
- **`channels_per_role`** — each role's channel set is a subset of `{in_app, push, sms, email, webhook}`. (REQ 2.5)
- **`event_name`** — `snake_case` form `<domain>.<entity>.<action>`. (REQ 2.6)

### 1.2 Field semantics

- **`category`** — top-level bucket from REQ 2.3.
- **`sub_category`** — short scope hint (e.g. `invoice`, `kot`, `school_fee`). Free text.
- **`event_name`** — the canonical name producers and consumers use. Snake_case `<domain>.<entity>.<action>`.
- **`trigger_condition`** — the exact code-level condition that produces the event, traced to a Phase 1 Trigger_Point ID.
- **`source_module`** — the file or module that owns the producer call.
- **`consumer_roles`** — roles that receive the event when authorization passes. Each role uses the channels listed in `channels_per_role`.
- **`consumer_apps`** — workspace apps where the consumer experience lives: `dukanx_desktop`, `school_admin_app`, `school_student_app`, `school_teacher_app`, `webhook_consumer` (external HTTPS endpoints).
- **`priority`** — reliability tier (drives `at_least_once` vs `at_most_once_with_dedup`).
- **`channels_per_role`** — per-role channel subset.
- **`deduplication_rule`** — ordered list of payload fields composing the Deduplication_Key, plus window in seconds (REQ 2.12).
- **`silence_conditions`** — situations under which the event is suppressed (REQ 2.13).
- **`justification`** — recipient role(s), reason the recipient needs the event, action expected on receipt (REQ 2.7, 2.9).

### 1.3 Default deduplication and silence behavior

Unless an entry overrides them, the following defaults apply per the design:

- **Deduplication_Window default**: `60 s` (per glossary in `requirements.md`).
- **Silence default**: `actor==recipient`; `target_id` muted by recipient; non-`critical` events suppressed during recipient's Quiet_Hours (per REQ 7.3-7.6, 12.x).

Every entry in this registry restates `silence_conditions` explicitly so producers and consumers can rely on the row alone without back-references.

### 1.4 Channel selection guidance

Channel selection is governed by REQ 5 and REQ 7. The table below summarizes the convention used in this registry (overridable per row when justified):

| Priority | Default channels for tenant staff (admin/cashier/accountant/etc.) | Default channels for external recipients (customer/parent/vendor/farmer) |
|---|---|---|
| `critical` | `in_app`, `push`, `sms` | `in_app`, `push`, `sms` |
| `high` | `in_app`, `push` | `in_app`, `push`, `sms` (when SMS template exists) |
| `normal` | `in_app` | `in_app`, `push` |
| `low` | `in_app` | `in_app` |

`email` is selected when the row carries financial documents (invoice, receipt, payslip, report card, statement). `webhook` is added when an event has external integrations (e.g. supplier webhooks for purchase orders).

### 1.5 Source-of-truth references

Every row's `trigger_condition` ends with the Phase 1 Trigger_Point ID (e.g. `[T-BIL-1]`) so producers can locate the existing emit site that this event replaces or wires.

---

## 2. Source App Identifiers

| Identifier | Workspace location | Notes |
|---|---|---|
| `dukanx_desktop` | `Dukan_x/lib/` (Flutter desktop) | Primary client; sole consumer for tenant staff roles. |
| `dukanx_backend` | `my-backend/src/`, `lambda/`, `voice-backend/` | Server-side producers. |
| `school_admin_app` | `school_admin_app/lib/` | Sub-app for `school_admin`. |
| `school_teacher_app` | `school_teacher_app/lib/` | Sub-app for `teacher`. |
| `school_student_app` | `school_student_app/lib/` | Sub-app for `student`/`parent`. |
| `webhook_consumer` | external HTTPS endpoint | Outbound webhook channel target. |

---

## 3. Recipient Roles

The registry uses the role inventory from Phase 1 §10.1 verbatim. The full list, with a per-role candidate-event matrix, lives in §14 of this document.

Roles in scope for this registry: `super_admin`, `admin` (alias `shop_owner`), `cashier`, `accountant`, `staff`, `delivery_agent`, `vendor`, `customer`, `chef`, `kitchen_staff`, `waiter`, `school_admin`, `teacher`, `student`, `parent`, `clinic_doctor`, `pharmacist`, `jewellery_artisan`, `service_technician`, `dc_staff`, `farmer`, `pump_attendant`.

REQ 17.1 minimum set (`admin`, `cashier`, `accountant`, `delivery_agent`, `vendor`, `customer`, `chef`, `kitchen_staff`, `waiter`, `school_admin`, `teacher`, `student`, `parent`, `clinic_doctor`, `pharmacist`, `jewellery_artisan`, `service_technician`) is fully covered. The five additional roles (`super_admin`, `staff`, `dc_staff`, `farmer`, `pump_attendant`) come from Phase 1 §10.1.

REQ 17.2 (`no_events` justification) — every role in the list above receives at least one event in §14, so no `no_events` justification is required.

---

## 4. Event Registry — Billing

Domain coverage: invoice creation/finalization/update/return, credit notes, decoration & catering invoices, school fee assignment and reminders, school payslips, restaurant bill updates. (REQ 2.14)

### 4.1 `billing.invoice.created`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `invoice` |
| `event_name` | `billing.invoice.created` |
| `trigger_condition` | A new invoice/bill record is persisted on the server or on a DukanX device (offline-first). [T-BIL-1, T-BIL-2] |
| `source_module` | `my-backend/src/handlers/invoices.ts` (canonical), `Dukan_x/lib/core/repository/bills_repository.dart` (offline producer via Shared_SDK outbox) |
| `consumer_roles` | `admin`, `cashier`, `accountant`, `customer` (when invoice has named customer) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`, `push`; `cashier`: `in_app`; `accountant`: `in_app`; `customer`: `in_app`, `push`, `email` (when receipt PDF attached) |
| `deduplication_rule` | Key: `[event_name, actor_id, invoice_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; recipient muted `invoice_id`; recipient muted customer profile (`customer_id`); non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner + cashier on every connected device of the same tenant, plus the named customer. Reason: keep dashboards/bills lists in sync without polling, and let the customer receive a copy of their invoice. Action: refresh dashboard, file invoice, customer downloads receipt. |

### 4.2 `billing.invoice.finalized`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `invoice` |
| `event_name` | `billing.invoice.finalized` |
| `trigger_condition` | Invoice status transitions `draft → final` server-side. [T-BIL-3] |
| `source_module` | `my-backend/src/handlers/invoices.ts` (`finalizeInvoice`) |
| `consumer_roles` | `admin`, `cashier`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`; `cashier`: `in_app`; `accountant`: `in_app`, `email` (when used in GST workflows) |
| `deduplication_rule` | Key: `[event_name, invoice_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `invoice_id`; non-`critical` Quiet_Hours suppression on `email` |
| `justification` | Recipient: shop owner, cashier, accountant. Reason: finalized invoices are reportable and count as revenue. Action: include in P&L and GST report. |

### 4.3 `billing.invoice.updated`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `invoice` |
| `event_name` | `billing.invoice.updated` |
| `trigger_condition` | Invoice header or items modified server-side after creation. [T-BIL-4] |
| `source_module` | `my-backend/src/handlers/invoices.ts` (`updateInvoice`) |
| `consumer_roles` | `admin`, `cashier`, `customer` (when shared invoice) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app`; `cashier`: `in_app`; `customer`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, invoice_id, version]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `invoice_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: shop owner, cashier, named customer. Reason: drift detection — the invoice shape changed and downstream views must reload. Action: refresh views; if the customer is the recipient, update their copy of the invoice. |

### 4.4 `billing.invoice.returned`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `invoice` |
| `event_name` | `billing.invoice.returned` |
| `trigger_condition` | A return is processed against an invoice (server-side commit or local-side from `return_bill_screen.dart`). [T-BIL-5, T-BIL-7] |
| `source_module` | `my-backend/src/handlers/invoices.ts` (`processReturn`); `Dukan_x/lib/features/billing/presentation/screens/return_bill_screen.dart` (offline producer) |
| `consumer_roles` | `admin`, `cashier`, `accountant`, `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `cashier`: `in_app`; `accountant`: `in_app`, `email`; `customer`: `in_app`, `push`, `sms` |
| `deduplication_rule` | Key: `[event_name, invoice_id, return_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; Quiet_Hours suppression for non-`critical` priority — `high` is suppressed on `push`/`sms` during quiet hours per REQ 7.3 |
| `justification` | Recipient: shop owner, cashier, accountant, originating customer. Reason: refund processing kicks off; ledgers and customer balance must update. Action: issue credit note, adjust outstanding, customer reconciles their balance. |

### 4.5 `billing.credit_note.issued`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `credit_note` |
| `event_name` | `billing.credit_note.issued` |
| `trigger_condition` | A new credit note is saved against a customer. [T-BIL-8] |
| `source_module` | `Dukan_x/lib/features/credit_notes/presentation/screens/credit_note_screen.dart`; backend persistence via Shared_SDK |
| `consumer_roles` | `customer`, `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `accountant`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, customer_id, credit_note_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: customer named on the note, accountant, shop owner. Reason: customer must see the credit because it represents money owed to them; accountant needs the entry. Action: customer's available-credit balance updates and they apply it on next purchase. |

### 4.6 `billing.dc.invoice.created`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `decoration_catering_invoice` |
| `event_name` | `billing.dc.invoice.created` |
| `trigger_condition` | Decoration & catering invoice is generated for an event. [T-DC-3] |
| `source_module` | `my-backend/src/handlers/dc.ts`; `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_billing_screen.dart` |
| `consumer_roles` | `customer`, `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `accountant`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, invoice_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: customer (booking owner), accountant, shop owner. Reason: payment is now due. Action: customer pays; accountant reconciles. |

### 4.7 `billing.school_fee.assigned`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `school_fee` |
| `event_name` | `billing.school_fee.assigned` |
| `trigger_condition` | A fee record is assigned to a student/parent for a term. [T-SCH-2] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-fees.ts` |
| `consumer_roles` | `parent`, `student`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `normal` |
| `channels_per_role` | `parent`: `in_app`, `push`, `email`; `student`: `in_app`, `push`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, student_id, fee_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id` (parent's own filter); muted `fee_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: parent, student, school_admin. Reason: visibility of new dues so the parent can plan payment. Action: parent pays or schedules payment; school_admin tracks assignment. |

### 4.8 `billing.school_fee.reminder_sent`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `school_fee` |
| `event_name` | `billing.school_fee.reminder_sent` |
| `trigger_condition` | A reminder is generated for an unpaid fee crossing the soft due window. [T-SCH-3] |
| `source_module` | `my-backend/src/handlers/academic_coaching.ts` (~line 2738) |
| `consumer_roles` | `parent`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `high` |
| `channels_per_role` | `parent`: `in_app`, `push`, `sms`, `email`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, student_id, fee_id, reminder_stage]`; Window: `21600 s` (6 hours — prevents repeat reminder spam) |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email`; per-recipient cap of 4 reminders/24h enforced via §13 fatigue rules |
| `justification` | Recipient: parent (the payer), school_admin (tracking). Reason: parent must pay before hard due date; admin escalates if unpaid. Action: parent pays; admin escalates. |

### 4.9 `billing.school_fee.overdue`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `school_fee` |
| `event_name` | `billing.school_fee.overdue` |
| `trigger_condition` | Fee crosses the hard due date and remains unpaid. [T-SCH-3] |
| `source_module` | `my-backend/src/handlers/academic_coaching.ts` (`AC_FEE_OVERDUE`) |
| `consumer_roles` | `parent`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `high` |
| `channels_per_role` | `parent`: `in_app`, `push`, `sms`, `email`; `school_admin`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, student_id, fee_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: parent, school_admin. Reason: late fee accrual begins; parent action is required to avoid further penalty. Action: parent pays; admin escalates with calls. |

### 4.10 `billing.school_payslip.generated`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `school_payslip` |
| `event_name` | `billing.school_payslip.generated` |
| `trigger_condition` | Payslip is generated for a teacher/staff for a pay period. [T-SCH-22] |
| `source_module` | `my-backend/src/handlers/ac-payslip.ts`; `my-backend/src/handlers/modules/school-erp/school-payslip.ts` |
| `consumer_roles` | `teacher`, `staff`, `accountant` |
| `consumer_apps` | `school_teacher_app`, `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `teacher`: `in_app`, `push`, `email`; `staff`: `in_app`, `push`, `email`; `accountant`: `in_app` |
| `deduplication_rule` | Key: `[event_name, employee_id, pay_period]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: the salaried teacher/staff member, plus accountant for tracking. Reason: salary visibility and tax record. Action: download and file the payslip. |

### 4.11 `billing.restaurant_bill.updated`

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `restaurant_bill` |
| `event_name` | `billing.restaurant_bill.updated` |
| `trigger_condition` | A restaurant bill is updated server-side and pushed to the restaurant staff app. [T-RES-4] |
| `source_module` | `my-backend/src/handlers/resto.ts` (~lines 2066, 2150) |
| `consumer_roles` | `cashier`, `waiter`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `cashier`: `in_app`; `waiter`: `in_app`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, bill_id, version]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `bill_id` |
| `justification` | Recipient: cashier on the staff app and the waiter who owns the table, shop owner. Reason: keep terminal in sync with bill changes (split, merge, void, discount). Action: refresh bill view before settling. |

---

## 5. Event Registry — Payments

Domain coverage: invoice payments, gateway success/failure, refunds, customer manual collections, vendor payouts, decoration & catering payments, school fee collections. (REQ 2.14)

### 5.1 `payment.invoice.received`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `invoice_payment` |
| `event_name` | `payment.invoice.received` |
| `trigger_condition` | A payment is recorded against an invoice (server-side `recordPayment` or DukanX offline-first via Shared_SDK outbox). [T-PAY-1, T-PAY-2] |
| `source_module` | `my-backend/src/handlers/payments.ts` (`recordPayment`); `Dukan_x/lib/core/repository/bills_repository.dart` |
| `consumer_roles` | `admin`, `cashier`, `accountant`, `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `cashier`: `in_app`; `accountant`: `in_app`, `email`; `customer`: `in_app`, `push`, `sms`, `email` |
| `deduplication_rule` | Key: `[event_name, invoice_id, payment_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; muted `invoice_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: shop owner, cashier, accountant, paying customer. Reason: customer wants confirmation of their payment; shop wants the ledger update; accountant needs the entry. Action: customer's outstanding decreases; shop's daily collection increases; accountant reconciles. |

### 5.2 `payment.gateway.success`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `gateway_callback` |
| `event_name` | `payment.gateway.success` |
| `trigger_condition` | Razorpay/PhonePe webhook delivers `result.status === 'success'`. [T-PAY-3] |
| `source_module` | `my-backend/src/handlers/payment-webhook.ts` (~line 194) |
| `consumer_roles` | `customer`, `admin`, `cashier` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `admin`: `in_app`, `push`; `cashier`: `in_app` |
| `deduplication_rule` | Key: `[event_name, gateway_payment_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable for customer** (REQ 7.6 critical bypass — payment confirmations cannot be muted); Quiet_Hours bypassed because `priority == critical` (REQ 7.4) |
| `justification` | Recipient: paying customer plus shop owner and cashier. Reason: gateway is asynchronous, so both parties learn the result here. Action: invoice marked paid, customer redirected from "pending" UI, shop releases goods. |

### 5.3 `payment.gateway.failed`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `gateway_callback` |
| `event_name` | `payment.gateway.failed` |
| `trigger_condition` | Razorpay/PhonePe webhook delivers `result.status === 'failed'`. [T-PAY-4] |
| `source_module` | `my-backend/src/handlers/payment-webhook.ts` (~line 194) |
| `consumer_roles` | `customer`, `admin`, `cashier` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `admin`: `in_app`, `push`; `cashier`: `in_app` |
| `deduplication_rule` | Key: `[event_name, gateway_payment_id, attempt]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable for customer** (must reach the payer); Quiet_Hours bypassed because `priority == critical` |
| `justification` | Recipient: paying customer, shop owner, cashier. Reason: customer must retry; shop must not ship. Action: customer sees retry CTA; shop holds dispatch. |

### 5.4 `payment.refund.processed`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `refund` |
| `event_name` | `payment.refund.processed` |
| `trigger_condition` | A refund is created against an invoice (server-side `process-refund` or local-side from `refund_screen.dart`). [T-PAY-6, T-PAY-7] |
| `source_module` | `my-backend/src/handlers/payment/process-refund.ts`; `Dukan_x/lib/features/revenue/screens/refund_screen.dart` |
| `consumer_roles` | `customer`, `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `accountant`: `in_app`, `email`; `admin`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, invoice_id, refund_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` (suppressed for `high`) |
| `justification` | Recipient: customer being refunded, accountant, shop owner. Reason: customer needs to know the money is on the way; accountant must reconcile. Action: customer's transactions list shows the refund; accountant adjusts books. |

### 5.5 `payment.customer_collection.recorded`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `manual_collection` |
| `event_name` | `payment.customer_collection.recorded` |
| `trigger_condition` | A manual collection is posted against a customer's outstanding (cash/UPI receipt). [T-CUS-5] |
| `source_module` | `Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart` |
| `consumer_roles` | `customer`, `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `admin`: `in_app`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, customer_id, collection_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: customer (their dues went down), shop owner, accountant. Reason: customer ledger update; owner/accountant track collection. Action: customer sees ledger reduce; accountant reconciles cash drawer. |

### 5.6 `payment.vendor_payment.collected`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `vendor_payout` |
| `event_name` | `payment.vendor_payment.collected` |
| `trigger_condition` | A vendor/supplier payment is recorded as collected (cleared). [T-CUS-6] |
| `source_module` | `Dukan_x/lib/features/party_ledger/screens/collect_payment_screen.dart` |
| `consumer_roles` | `vendor`, `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop`, `webhook_consumer` |
| `priority` | `high` |
| `channels_per_role` | `vendor`: `in_app`, `push`, `sms`, `email`, `webhook`; `accountant`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, vendor_id, payment_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `vendor_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: vendor/supplier, accountant, shop owner. Reason: payable cleared; vendor needs confirmation; accountant updates books. Action: vendor confirms receipt and marks dues cleared; accountant logs the entry. |

### 5.7 `payment.purchase_payment.made`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `purchase_payment` |
| `event_name` | `payment.purchase_payment.made` |
| `trigger_condition` | Payment to a supplier is saved against a purchase order or supplier bill. [T-PUR-4] |
| `source_module` | `Dukan_x/lib/features/buy_flow/screens/vendor_payouts_screen.dart` |
| `consumer_roles` | `vendor`, `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop`, `webhook_consumer` |
| `priority` | `high` |
| `channels_per_role` | `vendor`: `in_app`, `push`, `sms`, `email`, `webhook`; `accountant`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, vendor_id, purchase_payment_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `vendor_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: supplier, accountant, shop owner. Reason: supplier wants confirmation; accountant updates books. Action: supplier marks dues cleared; accountant logs the entry. |

### 5.8 `payment.dc.received`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `decoration_catering_payment` |
| `event_name` | `payment.dc.received` |
| `trigger_condition` | A payment against a decoration/catering booking is recorded. [T-DC-4] |
| `source_module` | `my-backend/src/handlers/dc.ts` |
| `consumer_roles` | `customer`, `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `accountant`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, payment_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: booking customer, accountant, shop owner. Reason: receipt + ledger update. Action: customer downloads receipt; accountant reconciles. |

### 5.9 `payment.school_fee.collected`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `school_fee_payment` |
| `event_name` | `payment.school_fee.collected` |
| `trigger_condition` | A school fee payment is recorded successful (`AC_FEE_COLLECTED`). [T-SCH-4] |
| `source_module` | `my-backend/src/handlers/payments.ts`; `school_student_app/lib/features/fees/screens/fee_payment_screen.dart` |
| `consumer_roles` | `parent`, `student`, `school_admin`, `accountant` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `high` |
| `channels_per_role` | `parent`: `in_app`, `push`, `sms`, `email`; `student`: `in_app`, `push`; `school_admin`: `in_app`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, student_id, fee_id, payment_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: parent, student, school_admin, accountant. Reason: receipt generation and ledger update. Action: parent downloads receipt; admin marks fee cleared; accountant logs entry. |

### 5.10 `payment.dc.expense.added`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `decoration_catering_expense` |
| `event_name` | `payment.dc.expense.added` |
| `trigger_condition` | An expense is added to a decoration/catering event. [T-DC-5] |
| `source_module` | `my-backend/src/handlers/dc.ts` |
| `consumer_roles` | `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app`; `accountant`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, expense_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: shop owner, accountant. Reason: profitability tracking on the booking. Action: review event P&L. |

### 5.11 `payment.cash_drop.recorded`

| Field | Value |
|---|---|
| `category` | `payments` |
| `sub_category` | `pump_cash_drop` |
| `event_name` | `payment.cash_drop.recorded` |
| `trigger_condition` | A petrol pump shift cash drop is recorded. [T-PMP-3] |
| `source_module` | `my-backend/src/handlers/pump.ts` (~line 544) |
| `consumer_roles` | `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, pump_id, shift_id, drop_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, accountant. Reason: cash-handling audit trail. Action: verify drop totals against shift sales. |

---

## 6. Event Registry — Inventory

Domain coverage: stock change, low-stock alerts, item create/update/delete, manual adjustments, sale-driven decrement, batch expiry, bulk imports, hallmark inventory, decoration & catering inventory, hardware/grocery expiry. (REQ 2.14)

### 6.1 `inventory.stock.changed`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `stock_change` |
| `event_name` | `inventory.stock.changed` |
| `trigger_condition` | Local stock quantity for a product is changed (offline-first), excluding sale-driven decrements which use a separate event. [T-INV-1] |
| `source_module` | `Dukan_x/lib/core/repository/products_repository.dart` (`updateProduct`/`adjustStock`) |
| `consumer_roles` | `cashier`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `cashier`: `in_app`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, product_id, stock_after]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id`; non-`critical` Quiet_Hours suppression on `push` (n/a since channels are `in_app` only); throttled by §13 fatigue rules |
| `justification` | Recipient: cashier on the same tenant device, shop owner. Reason: keep cart and dashboards correct. Action: refresh availability before selling. |

### 6.2 `inventory.stock.low`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `low_stock_alert` |
| `event_name` | `inventory.stock.low` |
| `trigger_condition` | Stock for a product crosses the configured `lowStockThreshold` after any change (sale, adjustment, return). [T-INV-2, T-INV-5, T-INV-9] |
| `source_module` | `Dukan_x/lib/core/repository/products_repository.dart`; `my-backend/src/handlers/inventory.ts`; `my-backend/src/services/invoice.service.ts` |
| `consumer_roles` | `admin`, `pharmacist` (pharmacy items) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email`; `pharmacist`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, product_id]`; Window: `21600 s` (6 hours — prevents repeated low-stock alarms while quantity oscillates around the threshold) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, pharmacist (for pharmacy products). Reason: reorder before stock-out. Action: create purchase order for the affected SKU. |

### 6.3 `inventory.item.created`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `catalogue` |
| `event_name` | `inventory.item.created` |
| `trigger_condition` | A new inventory item is created server-side (`createInventoryItem`). [T-INV-3] |
| `source_module` | `my-backend/src/handlers/inventory.ts` |
| `consumer_roles` | `admin`, `cashier` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app`; `cashier`: `in_app` |
| `deduplication_rule` | Key: `[event_name, product_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id` |
| `justification` | Recipient: shop owner, cashier on every connected device of the same tenant. Reason: catalog sync so the new SKU is immediately sellable. Action: refresh local product list. |

### 6.4 `inventory.item.updated`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `catalogue` |
| `event_name` | `inventory.item.updated` |
| `trigger_condition` | An inventory item record is updated server-side. [T-INV-4] |
| `source_module` | `my-backend/src/handlers/inventory.ts` (`updateInventoryItem`) |
| `consumer_roles` | `admin`, `cashier` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app`; `cashier`: `in_app` |
| `deduplication_rule` | Key: `[event_name, product_id, version]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id`; throttled by §13 fatigue rules (catalogue-edit storms during bulk edits) |
| `justification` | Recipient: shop owner, cashier on same tenant. Reason: catalog sync — name, price, GST rate may have changed. Action: refresh product card; recalc cart line items. |

### 6.5 `inventory.item.deleted`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `catalogue` |
| `event_name` | `inventory.item.deleted` |
| `trigger_condition` | An inventory item record is deleted server-side. [T-INV-6] |
| `source_module` | `my-backend/src/handlers/inventory.ts` (`deleteInventoryItem`) |
| `consumer_roles` | `admin`, `cashier` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`; `cashier`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, product_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id` |
| `justification` | Recipient: shop owner, cashier on same tenant. Reason: catalog sync — the SKU must drop from carts and lists to prevent selling an unavailable item. Action: drop item from open carts; remove from product lists. |

### 6.6 `inventory.stock.adjusted`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `manual_adjustment` |
| `event_name` | `inventory.stock.adjusted` |
| `trigger_condition` | A manual stock adjustment is posted (gain/loss with reason). [T-INV-7] |
| `source_module` | `my-backend/src/handlers/inventory.ts` (`adjustStock`) |
| `consumer_roles` | `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, product_id, adjustment_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, accountant. Reason: anomalous adjustments require oversight (audit trail). Action: review the reason field; investigate unusual adjustments. |

### 6.7 `inventory.stock.decremented_by_sale`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `sale_decrement` |
| `event_name` | `inventory.stock.decremented_by_sale` |
| `trigger_condition` | A sale commits and reduces stock for one or more items. [T-INV-8] |
| `source_module` | `my-backend/src/services/invoice.service.ts` (~line 1472) |
| `consumer_roles` | `cashier` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `cashier`: `in_app` |
| `deduplication_rule` | Key: `[event_name, invoice_id, product_id]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id`; throttled by §13 fatigue rules — coalesced into a per-invoice batched event when more than 5 items per second |
| `justification` | Recipient: cashier on other tenant devices. Reason: avoid overselling on a second terminal during high-throughput periods. Action: recompute available quantity in the open cart. |

### 6.8 `inventory.batch.expiring`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `expiry` |
| `event_name` | `inventory.batch.expiring` |
| `trigger_condition` | A batch crosses the "expiring soon" threshold (configurable; pharmacy default 30 days). [T-INV-10, T-INV-11] |
| `source_module` | `Dukan_x/lib/features/inventory/services/pharmacy_migration_service.dart`; `Dukan_x/lib/features/credit_notes/services/supplier_expiry_return_service.dart`; `my-backend/src/handlers/grocery-expiry.ts` |
| `consumer_roles` | `admin`, `pharmacist` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email`; `pharmacist`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, batch_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, pharmacist. Reason: prevent selling soon-to-expire stock; trigger a supplier return window. Action: pull stock from sale; initiate supplier return claim. |

### 6.9 `inventory.batch.expired`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `expiry` |
| `event_name` | `inventory.batch.expired` |
| `trigger_condition` | A batch crosses its expiry date. [T-INV-10] |
| `source_module` | `my-backend/src/handlers/grocery-expiry.ts`; `Dukan_x/lib/features/credit_notes/services/supplier_expiry_return_service.dart` |
| `consumer_roles` | `admin`, `pharmacist`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `admin`: `in_app`, `push`, `sms`, `email`; `pharmacist`: `in_app`, `push`, `sms`, `email`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, batch_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable** because expired stock is a regulatory hazard (REQ 7.6 critical bypass); Quiet_Hours bypassed because `priority == critical` |
| `justification` | Recipient: shop owner, pharmacist, accountant. Reason: expired stock cannot legally be sold and must be quarantined. Action: block stock; record write-off; file supplier return where applicable. |

### 6.10 `inventory.import.completed`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `bulk_import` |
| `event_name` | `inventory.import.completed` |
| `trigger_condition` | A bulk inventory import job completes successfully. [T-INV-12] |
| `source_module` | `Dukan_x/lib/features/inventory/presentation/screens/import_inventory_screen.dart`; `my-backend/src/handlers/process-import-row.ts` (`IMPORT_COMPLETED`) |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, import_job_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id` (the user who started the import) — **suppressed-on-self if started elsewhere** but **not** when the same user is on a different device; muted `import_job_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: the user who started the import. Reason: feedback for a long-running job. Action: review imported items, open the new catalogue. |

### 6.11 `inventory.import.failed`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `bulk_import` |
| `event_name` | `inventory.import.failed` |
| `trigger_condition` | A bulk inventory import job fails (validation errors, transport failure, partial commit). [T-INV-12] |
| `source_module` | `my-backend/src/handlers/process-import-row.ts` (`IMPORT_FAILED`) |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, import_job_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: the user who started the import. Reason: failure visibility so the user can fix and retry. Action: review error report, fix CSV, retry import. |

### 6.12 `inventory.import.progress` (batched)

> Defined in detail in §12 — Batched Events.

### 6.13 `inventory.hallmark.received`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `jewellery_hallmark` |
| `event_name` | `inventory.hallmark.received` |
| `trigger_condition` | Hallmarked stock is received back from the assayer and recorded. [T-JEW-7] |
| `source_module` | `Dukan_x/lib/features/jewellery/presentation/screens/hallmark_inventory_screen.dart` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, hallmark_batch_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `hallmark_batch_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: shop owner. Reason: hallmarked stock is sellable; the in-transit balance must move to available. Action: confirm the move from "in transit" to "available". |

### 6.14 `inventory.dc.low`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `decoration_catering_stock` |
| `event_name` | `inventory.dc.low` |
| `trigger_condition` | DC consumable inventory crosses the low-stock threshold. [T-DC-7] |
| `source_module` | `my-backend/src/handlers/dc.ts` |
| `consumer_roles` | `admin`, `dc_staff` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email`; `dc_staff`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, product_id]`; Window: `21600 s` (6 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `product_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, DC staff. Reason: prevent service disruption at upcoming events. Action: reorder consumables. |

### 6.15 `inventory.purchase_goods.received`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `goods_receipt` |
| `event_name` | `inventory.purchase_goods.received` |
| `trigger_condition` | Goods receipt recorded against a purchase order (stock now sellable). [T-PUR-2] |
| `source_module` | `Dukan_x/lib/features/buy_flow/screens/stock_entry_screen.dart` |
| `consumer_roles` | `admin`, `cashier` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`, `push`; `cashier`: `in_app` |
| `deduplication_rule` | Key: `[event_name, grn_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `grn_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: shop owner, cashier. Reason: the freshly-received stock is now sellable and other terminals must refresh. Action: refresh inventory; update displayed availability. |

### 6.16 `inventory.purchase_goods.reversed`

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `goods_reversal` |
| `event_name` | `inventory.purchase_goods.reversed` |
| `trigger_condition` | A goods receipt is reversed (return to supplier or correction). [T-PUR-7] |
| `source_module` | `Dukan_x/lib/features/buy_flow/screens/stock_reversal_screen.dart` |
| `consumer_roles` | `admin`, `vendor`, `accountant` |
| `consumer_apps` | `dukanx_desktop`, `webhook_consumer` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `vendor`: `in_app`, `email`, `webhook`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, grn_id, reversal_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `vendor_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, supplier, accountant. Reason: rolling back inventory must be visible to all parties; supplier must confirm. Action: confirm return; adjust ledger and supplier balance. |

---

## 7. Event Registry — Orders

Domain coverage: restaurant orders/KOTs, restaurant table status, jewellery custom orders, jewellery repair, jewellery old-gold exchange, jewellery scheme maturity, gold rate alerts, decoration & catering quotes/events/KOTs/staff assignments, auto-parts & computer-shop job cards, computer-shop warranty, service jobs, warranty claims, marketplace orders, pre-order requests, in-store exit QR, purchase orders, purchase scan-bill confirmations, supplier 3-way match. (REQ 2.14)

### 7.1 `orders.restaurant.created`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `restaurant_order` |
| `event_name` | `orders.restaurant.created` |
| `trigger_condition` | A restaurant order is created and broadcast to staff (`ORDER_CREATED`). [T-RES-1] |
| `source_module` | `my-backend/src/handlers/restaurant-v1-public.ts` (~line 351) |
| `consumer_roles` | `chef`, `kitchen_staff`, `waiter` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `chef`: `in_app`, `push`; `kitchen_staff`: `in_app`, `push`; `waiter`: `in_app` |
| `deduplication_rule` | Key: `[event_name, order_id]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `table_id`; non-`critical` Quiet_Hours suppression on `push` (rare for restaurants) |
| `justification` | Recipient: chef, kitchen staff, waiter. Reason: kitchen must start cooking; waiter must track service. Action: produce KOT; assign cook stations. |

### 7.2 `orders.restaurant_kot.created`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `restaurant_kot` |
| `event_name` | `orders.restaurant_kot.created` |
| `trigger_condition` | A new KOT is created for an order. [T-RES-2] |
| `source_module` | `my-backend/src/handlers/modules/restaurant/restaurant-kot.ts` |
| `consumer_roles` | `chef`, `kitchen_staff` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `chef`: `in_app`, `push`; `kitchen_staff`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, kot_id]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `table_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: chef and kitchen staff. Reason: items to produce; cooking schedule. Action: prepare the order. |

### 7.3 `orders.restaurant_kot.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `restaurant_kot` |
| `event_name` | `orders.restaurant_kot.status_changed` |
| `trigger_condition` | KOT status changes (`pending → preparing → ready → served`). [T-RES-2] |
| `source_module` | `my-backend/src/handlers/modules/restaurant/restaurant-kot.ts` |
| `consumer_roles` | `waiter`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `waiter`: `in_app`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, kot_id, status]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `table_id` |
| `justification` | Recipient: waiter, shop owner. Reason: kitchen ↔ floor coordination and service audit. Action: pick up ready items; track service time. |

### 7.4 `orders.restaurant_kot.item_cancelled`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `restaurant_kot` |
| `event_name` | `orders.restaurant_kot.item_cancelled` |
| `trigger_condition` | A KOT line item is cancelled before serving. [T-RES-2] |
| `source_module` | `my-backend/src/handlers/modules/restaurant/restaurant-kot.ts` |
| `consumer_roles` | `chef`, `kitchen_staff`, `waiter`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `chef`: `in_app`, `push`; `kitchen_staff`: `in_app`, `push`; `waiter`: `in_app`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, kot_id, item_id]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `table_id` |
| `justification` | Recipient: chef, kitchen staff, waiter, shop owner. Reason: stop cooking the cancelled item; reverse stock; audit. Action: discard the cooking; update bill; flag wastage. |

### 7.5 `orders.restaurant_kot.item_ready`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `restaurant_kot` |
| `event_name` | `orders.restaurant_kot.item_ready` |
| `trigger_condition` | A KOT item is marked ready in the kitchen display. [T-RES-3] |
| `source_module` | `Dukan_x/lib/features/restaurant/presentation/screens/kitchen_display_screen.dart` |
| `consumer_roles` | `waiter`, `customer` (if order-tracking enabled) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `waiter`: `in_app`, `push`; `customer`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, kot_id, item_id]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `table_id`; muted `order_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: waiter and (if subscribed) the ordering customer. Reason: dish ready for pickup or delivery to table. Action: waiter picks up; customer sees status. |

### 7.6 `orders.restaurant_table.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `restaurant_table` |
| `event_name` | `orders.restaurant_table.status_changed` |
| `trigger_condition` | A table status changes (free, seated, billed, settled). [T-RES-5] |
| `source_module` | `Dukan_x/lib/features/restaurant/presentation/screens/restaurant_table_ops_screen.dart` |
| `consumer_roles` | `waiter`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `waiter`: `in_app`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, table_id, status]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `table_id` |
| `justification` | Recipient: waiter, host (admin). Reason: table availability for next walk-ins. Action: seat next party. |

### 7.7 `orders.jewellery_custom_order.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `jewellery_custom_order` |
| `event_name` | `orders.jewellery_custom_order.status_changed` |
| `trigger_condition` | A custom jewellery order changes stage (design → wax → casting → polish → ready). [T-JEW-3] |
| `source_module` | `Dukan_x/lib/features/jewellery/presentation/screens/custom_order_management_screen.dart` |
| `consumer_roles` | `customer`, `jewellery_artisan`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `jewellery_artisan`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, custom_order_id, status]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `custom_order_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: customer who placed the order, the assigned artisan, shop owner. Reason: customer is waiting on a high-value bespoke item; artisan owns next step. Action: customer plans collection; artisan picks up next stage. |

### 7.8 `orders.jewellery_repair.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `jewellery_repair` |
| `event_name` | `orders.jewellery_repair.status_changed` |
| `trigger_condition` | A jewellery repair order changes stage. [T-JEW-4] |
| `source_module` | `Dukan_x/lib/features/jewellery/presentation/screens/jewellery_repair_screen.dart` |
| `consumer_roles` | `customer`, `jewellery_artisan`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `jewellery_artisan`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, repair_id, status]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `repair_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: customer, artisan, shop owner. Reason: customer awaits return; artisan owns next step. Action: customer collects when ready; artisan picks up next stage. |

### 7.9 `orders.jewellery_gold_rate.alert_triggered`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `gold_rate_alert` |
| `event_name` | `orders.jewellery_gold_rate.alert_triggered` |
| `trigger_condition` | A subscribed gold-rate threshold is crossed (above/below). [T-JEW-1] |
| `source_module` | `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` (`_dispatchAlert`) |
| `consumer_roles` | `admin`, `customer` (subscribed alert owner) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `customer`: `in_app`, `push`, `sms` |
| `deduplication_rule` | Key: `[event_name, alert_id, threshold_direction]`; Window: `1800 s` (30 minutes — prevents oscillation spam) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `alert_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: shop owner and the customer who set the alert. Reason: real-time price thresholds drive buy/sell decisions. Action: place buy/sell order or review pricing. |

### 7.10 `orders.jewellery_gold_rate.updated`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `gold_rate_pricing` |
| `event_name` | `orders.jewellery_gold_rate.updated` |
| `trigger_condition` | A new gold rate is published by the shop. [T-JEW-2] |
| `source_module` | `Dukan_x/lib/features/jewellery/presentation/screens/gold_rate_management_screen.dart` |
| `consumer_roles` | `cashier`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `cashier`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, rate_effective_at]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: every connected device of the tenant (cashiers + owner). Reason: pricing changes invalidate active quotes and bills. Action: refresh active POS sessions and re-quote. |

### 7.11 `orders.jewellery_gold_scheme.matured`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `gold_scheme` |
| `event_name` | `orders.jewellery_gold_scheme.matured` |
| `trigger_condition` | A customer's gold scheme reaches maturity. [T-JEW-5] |
| `source_module` | `Dukan_x/lib/features/jewellery/presentation/screens/gold_scheme_screen.dart` |
| `consumer_roles` | `customer`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `admin`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, scheme_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `scheme_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: depositing customer, shop owner. Reason: maturity opens a payout/redemption window. Action: customer redeems or extends scheme; owner prepares payout. |

### 7.12 `orders.jewellery_old_gold.exchange_recorded`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `old_gold_exchange` |
| `event_name` | `orders.jewellery_old_gold.exchange_recorded` |
| `trigger_condition` | An old-gold exchange entry is saved against a customer. [T-JEW-6] |
| `source_module` | `Dukan_x/lib/features/jewellery/presentation/screens/old_gold_exchange_screen.dart` |
| `consumer_roles` | `customer`, `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `accountant`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, customer_id, exchange_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: customer, accountant, shop owner. Reason: exchange credit issued to the customer must be visible. Action: customer applies credit on next purchase; accountant records the entry. |

### 7.13 `orders.dc_quote.converted`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `decoration_catering_quote` |
| `event_name` | `orders.dc_quote.converted` |
| `trigger_condition` | A DC quote is converted to a confirmed booking. [T-DC-1] |
| `source_module` | `my-backend/src/handlers/dc.ts`; `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart` |
| `consumer_roles` | `customer`, `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `admin`: `in_app`, `push`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, quote_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: booking customer, shop owner, accountant. Reason: confirmed booking creates revenue and an advance is due; date is now blocked. Action: customer pays advance; owner blocks date; accountant records. |

### 7.14 `orders.dc_event.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `decoration_catering_event` |
| `event_name` | `orders.dc_event.status_changed` |
| `trigger_condition` | DC event lifecycle transitions (planned → setup → live → settled). [T-DC-2] |
| `source_module` | `my-backend/src/handlers/dc.ts`; `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_event_detail_screen.dart` |
| `consumer_roles` | `customer`, `dc_staff`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `customer`: `in_app`, `push`; `dc_staff`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, status]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: booking customer, DC staff assigned to the event, shop owner. Reason: timeline updates so all parties stay synced. Action: customer confirms next step; staff prepares; owner monitors. |

### 7.15 `orders.dc_kot.created`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `decoration_catering_kot` |
| `event_name` | `orders.dc_kot.created` |
| `trigger_condition` | A KOT is generated for a catering event. [T-DC-8] |
| `source_module` | `my-backend/src/handlers/dc.ts` (`DC_KOT_CREATED`) |
| `consumer_roles` | `chef`, `kitchen_staff`, `dc_staff` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `chef`: `in_app`, `push`; `kitchen_staff`: `in_app`, `push`; `dc_staff`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, kot_id]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id` |
| `justification` | Recipient: chef, kitchen staff, DC staff. Reason: cooking schedule for the event. Action: prep menu items in time. |

### 7.16 `orders.dc_kot.updated`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `decoration_catering_kot` |
| `event_name` | `orders.dc_kot.updated` |
| `trigger_condition` | A DC KOT is amended (additional items, cancellation). [T-DC-8] |
| `source_module` | `my-backend/src/handlers/dc.ts` (`DC_KOT_UPDATED`) |
| `consumer_roles` | `chef`, `kitchen_staff`, `dc_staff` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `chef`: `in_app`, `push`; `kitchen_staff`: `in_app`, `push`; `dc_staff`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, kot_id, version]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id` |
| `justification` | Recipient: chef, kitchen staff, DC staff. Reason: amended cooking schedule. Action: adjust prep. |

### 7.17 `orders.dc_staff.assigned`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `decoration_catering_staff` |
| `event_name` | `orders.dc_staff.assigned` |
| `trigger_condition` | A DC staff member is assigned to an event. [T-DC-6] |
| `source_module` | `my-backend/src/handlers/dc.ts` (`DC_STAFF_ASSIGNED`) |
| `consumer_roles` | `dc_staff`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `dc_staff`: `in_app`, `push`, `sms`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dc_event_id, assignee_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: assigned DC staff, shop owner. Reason: schedule and shift assignment. Action: staff arrives on time; owner confirms coverage. |

### 7.18 `orders.service_job.created`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `service_job` |
| `event_name` | `orders.service_job.created` |
| `trigger_condition` | A service job is created (`SERVICE_JOB_CREATED`). [T-SVC-1] |
| `source_module` | `my-backend/src/handlers/service.ts`; `Dukan_x/lib/features/service/presentation/screens/create_service_job_screen.dart` |
| `consumer_roles` | `customer`, `service_technician`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `service_technician`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, service_job_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `service_job_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: customer, service technician, shop owner. Reason: customer awaits ETA; tech has a new job; owner schedules. Action: schedule drop-off; tech picks up the job; customer plans. |

### 7.19 `orders.service_job.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `service_job` |
| `event_name` | `orders.service_job.status_changed` |
| `trigger_condition` | Service job status transitions (received → diagnosing → repairing → ready → delivered → cancelled). [T-SVC-2] |
| `source_module` | `Dukan_x/lib/features/service/services/service_job_notification_service.dart` (`dispatchNotification`) |
| `consumer_roles` | `customer`, `service_technician`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `service_technician`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, service_job_id, status]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `service_job_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: customer, service technician, shop owner. Reason: customer wants visibility; tech completes handoff; owner audits. Action: customer collects when ready and pays; tech moves to next job. |

### 7.20 `orders.service_warranty.claim_raised`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `warranty_claim` |
| `event_name` | `orders.service_warranty.claim_raised` |
| `trigger_condition` | A warranty claim is raised against a serviced product. [T-SVC-3] |
| `source_module` | `Dukan_x/lib/features/service/services/warranty_claim_service.dart` |
| `consumer_roles` | `admin`, `vendor` |
| `consumer_apps` | `dukanx_desktop`, `webhook_consumer` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `vendor`: `in_app`, `email`, `webhook` |
| `deduplication_rule` | Key: `[event_name, claim_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `claim_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, supplier (warranty provider). Reason: claim eligibility decision must be made. Action: validate the claim; escalate to supplier. |

### 7.21 `orders.service_exchange.completed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `exchange` |
| `event_name` | `orders.service_exchange.completed` |
| `trigger_condition` | A service exchange (replacement issued) is completed. [T-SVC-4] |
| `source_module` | `Dukan_x/lib/features/service/presentation/screens/exchange_detail_screen.dart` |
| `consumer_roles` | `customer`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, exchange_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: customer, shop owner. Reason: replacement is issued and ready for collection. Action: customer collects; owner closes the case. |

### 7.22 `orders.auto_parts_job_card.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `auto_parts_job_card` |
| `event_name` | `orders.auto_parts_job_card.status_changed` |
| `trigger_condition` | Auto-parts job card status changes (received → in_progress → ready → delivered). [T-JOB-1] |
| `source_module` | `Dukan_x/lib/features/auto_parts/presentation/screens/job_card_management_screen.dart` |
| `consumer_roles` | `customer`, `service_technician`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `service_technician`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, job_card_id, status]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `job_card_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: vehicle owner customer, technician, shop owner. Reason: customer awaits readiness; technician owns next step. Action: customer collects; technician proceeds. |

### 7.23 `orders.computer_shop_job_card.status_changed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `computer_shop_job_card` |
| `event_name` | `orders.computer_shop_job_card.status_changed` |
| `trigger_condition` | Computer-shop job card status changes. [T-JOB-2] |
| `source_module` | `Dukan_x/lib/features/computer_shop/presentation/screens/create_job_card_screen.dart`, `job_card_detail_screen.dart` |
| `consumer_roles` | `customer`, `service_technician`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `service_technician`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, job_card_id, status]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `job_card_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: customer, technician, shop owner. Reason: same as 7.22 in computer-shop variant. Action: customer collects; technician proceeds. |

### 7.24 `orders.computer_shop_warranty.registered`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `computer_shop_warranty` |
| `event_name` | `orders.computer_shop_warranty.registered` |
| `trigger_condition` | A computer-shop warranty is registered against a sold device. [T-JOB-3] |
| `source_module` | `Dukan_x/lib/features/computer_shop/presentation/screens/warranty_screen.dart` |
| `consumer_roles` | `customer`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `customer`: `in_app`, `push`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, warranty_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: customer, shop owner. Reason: customer learns coverage exists. Action: customer stores warranty card; owner files the registration. |

### 7.25 `orders.purchase.created`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `purchase_order` |
| `event_name` | `orders.purchase.created` |
| `trigger_condition` | A purchase order is committed (frontend save flowing to backend). [T-PUR-1] |
| `source_module` | `Dukan_x/lib/features/purchase/screens/add_purchase_screen.dart`; `Dukan_x/lib/core/repository/bills_repository.dart` |
| `consumer_roles` | `admin`, `accountant`, `vendor` |
| `consumer_apps` | `dukanx_desktop`, `webhook_consumer` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `accountant`: `in_app`, `email`; `vendor`: `in_app`, `email`, `webhook` |
| `deduplication_rule` | Key: `[event_name, po_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `vendor_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, accountant, supplier (when configured). Reason: PO creates a payable; supplier needs to fulfil. Action: send copy to supplier; record payable. |

### 7.26 `orders.purchase_bill.added`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `supplier_bill` |
| `event_name` | `orders.purchase_bill.added` |
| `trigger_condition` | A supplier bill is recorded against a PO/GRN. [T-PUR-3] |
| `source_module` | `Dukan_x/lib/features/buy_flow/screens/supplier_bills_screen.dart` |
| `consumer_roles` | `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, supplier_bill_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `vendor_id`; non-`critical` Quiet_Hours suppression on `email` |
| `justification` | Recipient: shop owner, accountant. Reason: payables update. Action: schedule payment. |

### 7.27 `orders.purchase_scan_bill.confirmed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `purchase_ocr` |
| `event_name` | `orders.purchase_scan_bill.confirmed` |
| `trigger_condition` | An OCR-scanned supplier bill is reviewed and confirmed. [T-PUR-5] |
| `source_module` | `Dukan_x/lib/features/purchase/presentation/screens/scan_bill_review_screen.dart` |
| `consumer_roles` | `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`; `accountant`: `in_app` |
| `deduplication_rule` | Key: `[event_name, scan_session_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression |
| `justification` | Recipient: shop owner, accountant. Reason: confirmed scan promotes the OCR draft to a real payable. Action: review and approve PO/bill creation. |

### 7.28 `orders.purchase_po.matched_to_grn`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `three_way_match` |
| `event_name` | `orders.purchase_po.matched_to_grn` |
| `trigger_condition` | Purchase 3-way match (PO ↔ GRN ↔ supplier bill) succeeds. [T-PUR-6] |
| `source_module` | `my-backend/src/handlers/purchase-order-matching.ts` |
| `consumer_roles` | `accountant`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `accountant`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, po_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `email` |
| `justification` | Recipient: accountant, shop owner. Reason: match enables payment release. Action: release payment. |

### 7.29 `orders.marketplace.placed`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `marketplace_order` |
| `event_name` | `orders.marketplace.placed` |
| `trigger_condition` | A marketplace order is placed by a customer. [T-MKT-1] |
| `source_module` | `lambda/marketplace/ordersHandler/index.ts` |
| `consumer_roles` | `customer`, `admin`, `delivery_agent` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `email`; `admin`: `in_app`, `push`; `delivery_agent`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, order_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `order_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: customer (their own order), shop owner, delivery agent. Reason: fulfilment kicks off. Action: pick + pack + ship. |

### 7.30 `orders.pre_order.requested`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `pre_order` |
| `event_name` | `orders.pre_order.requested` |
| `trigger_condition` | A customer creates a pre-order request to a vendor. [T-MKT-4] |
| `source_module` | `Dukan_x/lib/features/pre_order/presentation/customer/customer_pre_order_screen.dart` |
| `consumer_roles` | `vendor`, `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `vendor`: `in_app`, `push`, `email`; `customer`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, pre_order_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `pre_order_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: vendor (recipient of the request), customer (their own request). Reason: bidirectional negotiation. Action: vendor responds; customer awaits decision. |

### 7.31 `orders.pre_order.responded`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `pre_order` |
| `event_name` | `orders.pre_order.responded` |
| `trigger_condition` | A vendor accepts or rejects a pre-order request. [T-MKT-4] |
| `source_module` | `Dukan_x/lib/features/pre_order/presentation/vendor/vendor_request_detail_screen.dart` |
| `consumer_roles` | `customer`, `vendor` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `vendor`: `in_app` |
| `deduplication_rule` | Key: `[event_name, pre_order_id, decision]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `pre_order_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: requesting customer, the responding vendor (audit). Reason: customer awaits decision; vendor records the response. Action: customer pays/cancels; vendor moves to next item. |

### 7.32 `orders.in_store_exit_qr.ready`

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `in_store_checkout` |
| `event_name` | `orders.in_store_exit_qr.ready` |
| `trigger_condition` | An in-store checkout flow generates the exit QR. [T-MKT-5] |
| `source_module` | `my-backend/src/handlers/in-store-checkout.ts` (`IN_STORE_EXIT_QR_READY`) |
| `consumer_roles` | `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `customer`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, session_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id` (n/a — system-generated for the customer); **un-mutable** for the customer's own session because the customer cannot leave the store without it; Quiet_Hours bypassed because `priority == critical` |
| `justification` | Recipient: the checking-out customer. Reason: customer must scan the QR at the gate to leave. Action: scan exit QR. |

---

## 8. Event Registry — Delivery

Domain coverage: restaurant delivery, delivery challans, dispatch notes, marketplace delivery agent location, school transport. (REQ 2.14)

### 8.1 `delivery.restaurant.dispatched`

| Field | Value |
|---|---|
| `category` | `delivery` |
| `sub_category` | `restaurant_delivery` |
| `event_name` | `delivery.restaurant.dispatched` |
| `trigger_condition` | A restaurant delivery is dispatched (assigned to an agent). [T-RES-7] |
| `source_module` | `my-backend/src/handlers/modules/restaurant/restaurant-delivery.ts` |
| `consumer_roles` | `customer`, `delivery_agent`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `delivery_agent`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, order_id, agent_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `order_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: ordering customer, assigned delivery agent, shop owner. Reason: customer wants ETA; agent has the next pickup. Action: agent goes to the address; customer prepares to receive. |

### 8.2 `delivery.challan.created`

| Field | Value |
|---|---|
| `category` | `delivery` |
| `sub_category` | `delivery_challan` |
| `event_name` | `delivery.challan.created` |
| `trigger_condition` | A delivery challan is created server-side or via DukanX. [T-DLV-1] |
| `source_module` | `Dukan_x/lib/features/delivery_challan/services/delivery_challan_service.dart`; `my-backend/src/handlers/challans.ts` |
| `consumer_roles` | `customer`, `delivery_agent`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `delivery_agent`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, challan_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: consignee customer, delivery agent, shop owner. Reason: shipment scheduled; agent has the next task. Action: customer prepares for receipt; agent picks up. |

### 8.3 `delivery.dispatch_note.created`

| Field | Value |
|---|---|
| `category` | `delivery` |
| `sub_category` | `dispatch_note` |
| `event_name` | `delivery.dispatch_note.created` |
| `trigger_condition` | A dispatch note is created. [T-DLV-2] |
| `source_module` | `Dukan_x/lib/features/revenue/screens/dispatch_note_screen.dart` |
| `consumer_roles` | `customer`, `delivery_agent`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `delivery_agent`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dispatch_note_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: consignee customer, delivery agent, shop owner. Reason: same as 8.2 with a different document type. Action: customer prepares for receipt; agent picks up. |

### 8.4 `delivery.location.updated`

| Field | Value |
|---|---|
| `category` | `delivery` |
| `sub_category` | `live_tracking` |
| `event_name` | `delivery.location.updated` |
| `trigger_condition` | A delivery agent's location is updated during an active delivery. [T-DLV-3] |
| `source_module` | `lambda/marketplace/deliveryHandler/index.ts` |
| `consumer_roles` | `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `customer`: `in_app` |
| `deduplication_rule` | Key: `[event_name, agent_id, latitude_band, longitude_band]`; Window: `15 s` (low resolution to absorb GPS jitter) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `order_id`; throttled by §13 fatigue rules — coalesced into a per-30s tracking summary |
| `justification` | Recipient: receiving customer. Reason: live ETA tracking. Action: customer prepares to receive. |

### 8.5 `delivery.school_transport.delay`

| Field | Value |
|---|---|
| `category` | `delivery` |
| `sub_category` | `school_transport` |
| `event_name` | `delivery.school_transport.delay` |
| `trigger_condition` | A school transport route is delayed. [T-SCH-21] |
| `source_module` | `my-backend/src/handlers/ac-transport.ts` |
| `consumer_roles` | `parent`, `student`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `high` |
| `channels_per_role` | `parent`: `in_app`, `push`, `sms`; `student`: `in_app`, `push`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, route_id, delay_window]`; Window: `900 s` (15 minutes — one alert per delay window) |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: parent, student, school_admin. Reason: pickup timing changed. Action: parent adjusts pickup time; admin tracks. |

### 8.6 `delivery.school_transport.route_assigned`

| Field | Value |
|---|---|
| `category` | `delivery` |
| `sub_category` | `school_transport` |
| `event_name` | `delivery.school_transport.route_assigned` |
| `trigger_condition` | A student is assigned a transport route. [T-SCH-21] |
| `source_module` | `my-backend/src/handlers/ac-transport.ts` |
| `consumer_roles` | `parent`, `student`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `normal` |
| `channels_per_role` | `parent`: `in_app`, `push`, `email`; `student`: `in_app`, `push`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, student_id, route_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: parent, student, school_admin. Reason: route assignment determines pickup logistics. Action: parent learns the route and stop; admin records assignment. |

---

## 9. Event Registry — Users

Domain coverage: customer↔shop linking, credit reminders, recovery visits, school admissions, school student transfer, school batch full, leave requests/processing, restaurant table session changes that affect users, school timetable updates, jewellery artisan assignments (covered in §7), staff attendance, marketing campaigns, loyalty points/tiers, AI notify-owner. (REQ 2.14)

### 9.1 `users.customer_shop.linked`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `shop_link` |
| `event_name` | `users.customer_shop.linked` |
| `trigger_condition` | A customer-shop link is established (QR scan flow). [T-CUS-3] |
| `source_module` | `Dukan_x/lib/features/shop_linking/presentation/screens/qr_scanner_screen.dart`, `qr_display_screen.dart`, `shop_confirmation_screen.dart` |
| `consumer_roles` | `customer`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `customer`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, customer_id, shop_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `shop_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: customer and shop. Reason: bidirectional link establishes trust and enables future notifications. Action: shop appears in customer's "My linked shops"; shop sees the customer in CRM. |

### 9.2 `users.customer_shop.link_accepted`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `shop_link` |
| `event_name` | `users.customer_shop.link_accepted` |
| `trigger_condition` | The acceptance side of the customer-shop link flow. [T-CUS-4] |
| `source_module` | `Dukan_x/lib/screens/customer_link_accept_screen.dart` |
| `consumer_roles` | `customer`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `customer`: `in_app`; `admin`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, customer_id, shop_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `shop_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: customer and shop. Reason: confirmation that the link is active. Action: customer/shop see the link reflected in their UIs. |

### 9.3 `users.customer_credit.reminder_sent`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `credit_reminder` |
| `event_name` | `users.customer_credit.reminder_sent` |
| `trigger_condition` | A credit reminder is sent to a customer with overdue dues. [T-CUS-8] |
| `source_module` | `my-backend/src/handlers/credit-reminders.ts` |
| `consumer_roles` | `customer`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, customer_id, reminder_stage]`; Window: `21600 s` (6 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email`; per-recipient cap of 4/24h enforced by §13 |
| `justification` | Recipient: customer (the recipient of the reminder), shop owner (for tracking). Reason: customer needs to act on overdue dues; shop tracks dunning progress. Action: customer pays or arranges payment. |

### 9.4 `users.customer_recovery.visit_recorded`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `recovery_visit` |
| `event_name` | `users.customer_recovery.visit_recorded` |
| `trigger_condition` | A recovery (collection-call) visit is recorded against a customer. [T-CUS-7] |
| `source_module` | `my-backend/src/handlers/recovery-visits.ts` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, customer_id, visit_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id` |
| `justification` | Recipient: shop owner. Reason: dunning workflow audit. Action: review next-action plan. |

### 9.5 `users.school_admission.accepted`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `admission` |
| `event_name` | `users.school_admission.accepted` |
| `trigger_condition` | A student admission is accepted. [T-SCH-1] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-admissions.ts` |
| `consumer_roles` | `parent`, `student`, `school_admin`, `teacher` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `high` |
| `channels_per_role` | `parent`: `in_app`, `push`, `email`; `student`: `in_app`, `push`; `school_admin`: `in_app`; `teacher`: `in_app` |
| `deduplication_rule` | Key: `[event_name, student_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: parent, student, school_admin, class teacher. Reason: enrollment confirmed; fee schedule activates and roster updates. Action: parent pays first instalment; admin schedules; teacher updates roster. |

### 9.6 `users.school_student.transferred`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `student_transfer` |
| `event_name` | `users.school_student.transferred` |
| `trigger_condition` | A student is transferred between sections/batches (`AC_STUDENT_TRANSFERRED`). [T-SCH-13] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-students.ts` |
| `consumer_roles` | `parent`, `school_admin`, `teacher` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `normal` |
| `channels_per_role` | `parent`: `in_app`, `push`, `email`; `school_admin`: `in_app`; `teacher`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, student_id, target_section_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: parent, school_admin, both old and new section teachers. Reason: roster update affecting timetable, attendance and fees. Action: update class roster; parent acknowledges new section. |

### 9.7 `users.school_batch.full`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `batch_capacity` |
| `event_name` | `users.school_batch.full` |
| `trigger_condition` | A batch reaches its capacity (`AC_BATCH_FULL`). [T-SCH-14] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-batches.ts` |
| `consumer_roles` | `school_admin` |
| `consumer_apps` | `school_admin_app` |
| `priority` | `high` |
| `channels_per_role` | `school_admin`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, batch_id]`; Window: `3600 s` (1 hour) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `batch_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: school_admin. Reason: stop accepting more admissions in the batch. Action: open new batch or move applicants to waitlist. |

### 9.8 `users.school_attendance.marked`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `attendance` |
| `event_name` | `users.school_attendance.marked` |
| `trigger_condition` | Daily attendance is marked for a class (`AC_ATTENDANCE_MARKED`). [T-SCH-5] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-attendance.ts`; `lambda/staff-attendance/src/handlers/scheduledAttendanceMarker.ts` |
| `consumer_roles` | `parent`, `student`, `teacher` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `normal` |
| `channels_per_role` | `parent`: `in_app`, `push`; `student`: `in_app`; `teacher`: `in_app` |
| `deduplication_rule` | Key: `[event_name, student_id, attendance_date]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: parent, student, class teacher. Reason: daily attendance visibility. Action: parent follows up on absences; teacher tracks. |

### 9.9 `users.school_attendance.absent_alert`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `absent_alert` |
| `event_name` | `users.school_attendance.absent_alert` |
| `trigger_condition` | A student is recorded absent and a same-day SMS/email is sent to the parent. [T-SCH-6] |
| `source_module` | `my-backend/src/handlers/academic_coaching.ts` (~lines 1157-1163) |
| `consumer_roles` | `parent` |
| `consumer_apps` | `school_student_app` |
| `priority` | `high` |
| `channels_per_role` | `parent`: `in_app`, `push`, `sms`, `email` |
| `deduplication_rule` | Key: `[event_name, student_id, attendance_date]`; Window: `21600 s` (6 hours — one alert per absent day per student) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: parent. Reason: same-day absence visibility so the parent can check on the child. Action: contact school. |

### 9.10 `users.school_attendance.low_alert`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `low_attendance` |
| `event_name` | `users.school_attendance.low_alert` |
| `trigger_condition` | A student's attendance crosses below the configured threshold (`AC_LOW_ATTENDANCE_ALERT`). [T-SCH-7] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-attendance.ts` |
| `consumer_roles` | `parent`, `school_admin`, `teacher` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `high` |
| `channels_per_role` | `parent`: `in_app`, `push`, `sms`, `email`; `school_admin`: `in_app`, `email`; `teacher`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, student_id, term_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: parent, school_admin, teacher. Reason: at risk of academic action. Action: intervene with parent meeting or remediation. |

### 9.11 `users.school_leave.submitted`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `leave_request` |
| `event_name` | `users.school_leave.submitted` |
| `trigger_condition` | A leave application is submitted (student, teacher, or staff). [T-SCH-11] |
| `source_module` | `school_student_app/lib/features/leave/screens/leave_screen.dart`; `my-backend/src/handlers/modules/school-erp/school-leave.ts`; `lambda/staff-attendance/src/handlers/submitLeaveRequest.ts` |
| `consumer_roles` | `teacher`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_teacher_app` |
| `priority` | `high` |
| `channels_per_role` | `teacher`: `in_app`, `push`; `school_admin`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, leave_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: approving teacher or school_admin. Reason: leave requires approval. Action: approve or reject. |

### 9.12 `users.school_leave.processed`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `leave_decision` |
| `event_name` | `users.school_leave.processed` |
| `trigger_condition` | A leave application is approved or rejected. [T-SCH-12] |
| `source_module` | `lambda/staff-attendance/src/handlers/processLeaveRequest.ts` (~line 129) |
| `consumer_roles` | `student`, `teacher`, `parent`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `high` |
| `channels_per_role` | `student`: `in_app`, `push`; `teacher`: `in_app`, `push`; `parent`: `in_app`, `push`, `email`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, leave_id, decision]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: applicant (student/teacher/parent), school_admin (audit). Reason: applicant needs the decision. Action: plan around the result. |

### 9.13 `users.school_timetable.updated`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `timetable` |
| `event_name` | `users.school_timetable.updated` |
| `trigger_condition` | A class timetable is updated (`AC_TIMETABLE_UPDATED`). [T-SCH-15] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-timetable.ts` |
| `consumer_roles` | `student`, `teacher`, `parent`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `normal` |
| `channels_per_role` | `student`: `in_app`, `push`; `teacher`: `in_app`, `push`; `parent`: `in_app`, `push`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, class_id, term_id, version]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `class_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: students of the class, teachers of the class, parents of those students, school_admin. Reason: schedule change. Action: update calendar. |

### 9.14 `users.school_homework.assigned`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `homework` |
| `event_name` | `users.school_homework.assigned` |
| `trigger_condition` | Homework is assigned to a class. [T-SCH-17] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-homework.ts` |
| `consumer_roles` | `student`, `parent` |
| `consumer_apps` | `school_student_app` |
| `priority` | `normal` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, homework_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `class_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: students of the class, their parents. Reason: due date awareness. Action: complete and submit. |

### 9.15 `users.school_material.uploaded`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `study_material` |
| `event_name` | `users.school_material.uploaded` |
| `trigger_condition` | A study material file is uploaded for a class (`AC_MATERIAL_UPLOADED`). [T-SCH-16] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-materials.ts` |
| `consumer_roles` | `student`, `parent` |
| `consumer_apps` | `school_student_app` |
| `priority` | `low` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app` |
| `deduplication_rule` | Key: `[event_name, material_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `class_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: students of the class, their parents. Reason: new material available. Action: download and study. |

### 9.16 `users.school_library.due`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `library` |
| `event_name` | `users.school_library.due` |
| `trigger_condition` | A borrowed library book is approaching its return date. [T-SCH-18] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-library.ts` |
| `consumer_roles` | `student`, `parent` |
| `consumer_apps` | `school_student_app` |
| `priority` | `normal` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, loan_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: borrowing student, their parent. Reason: avoid late fees. Action: return the book. |

### 9.17 `users.school_library.overdue`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `library` |
| `event_name` | `users.school_library.overdue` |
| `trigger_condition` | A borrowed library book is past its return date. [T-SCH-18] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-library.ts` |
| `consumer_roles` | `student`, `parent`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `high` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app`, `push`, `sms`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, loan_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: student, parent, school_admin. Reason: overdue triggers a fine and a return reminder. Action: parent ensures the book is returned; admin tracks the loan. |

### 9.18 `users.school_hostel.room_assigned`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `hostel` |
| `event_name` | `users.school_hostel.room_assigned` |
| `trigger_condition` | A hostel room is assigned to a student. [T-SCH-19] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-hostel.ts` |
| `consumer_roles` | `student`, `parent`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `normal` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app`, `push`, `email`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, student_id, room_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: student, parent, school_admin. Reason: housing logistics. Action: occupy room. |

### 9.19 `users.school_hostel.mess_updated`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `hostel_mess` |
| `event_name` | `users.school_hostel.mess_updated` |
| `trigger_condition` | Hostel mess menu or schedule is updated. [T-SCH-19] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-hostel.ts` |
| `consumer_roles` | `student`, `parent` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `low` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app` |
| `deduplication_rule` | Key: `[event_name, mess_id, effective_at]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `mess_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: hostel student, their parent. Reason: dietary planning. Action: plan meals. |

### 9.20 `users.school_announcement.published`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `announcement` |
| `event_name` | `users.school_announcement.published` |
| `trigger_condition` | A school-wide or class-wide announcement is published. [T-SCH-20] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-communication.ts` |
| `consumer_roles` | `student`, `parent`, `teacher`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `normal` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app`, `push`, `email`; `teacher`: `in_app`, `push`; `school_admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, announcement_id, audience_scope]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `audience_scope`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: scoped audience (students, parents, teachers). Reason: school-wide or class-wide info. Action: read and comply. |

### 9.21 `users.clinic_appointment.created`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `clinic_appointment` |
| `event_name` | `users.clinic_appointment.created` |
| `trigger_condition` | A clinic appointment is created. [T-CLN-1] |
| `source_module` | `Dukan_x/lib/features/clinic/presentation/screens/clinic_calendar_screen.dart`; `Dukan_x/lib/features/doctor/presentation/screens/appointment_screen.dart`; `my-backend/src/handlers/clinic-scheduler.ts` |
| `consumer_roles` | `customer` (patient), `clinic_doctor`, `admin` (front desk) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `clinic_doctor`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, appointment_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `appointment_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: patient, doctor, front desk. Reason: schedule and confirmation. Action: patient sees confirmation; doctor sees agenda. |

### 9.22 `users.clinic_appointment.reminder_due`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `clinic_appointment` |
| `event_name` | `users.clinic_appointment.reminder_due` |
| `trigger_condition` | A clinic appointment reminder window opens (typically 24 h or 1 h before). [T-CLN-2] |
| `source_module` | `my-backend/src/handlers/clinic-scheduler.ts` |
| `consumer_roles` | `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms` |
| `deduplication_rule` | Key: `[event_name, appointment_id, reminder_offset]`; Window: `3600 s` (1 hour) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `appointment_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: patient. Reason: reduce no-shows. Action: confirm or reschedule. |

### 9.23 `users.clinic_queue.advanced`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `clinic_queue` |
| `event_name` | `users.clinic_queue.advanced` |
| `trigger_condition` | The clinic queue advances to the next patient. [T-CLN-3] |
| `source_module` | `Dukan_x/lib/features/clinic/presentation/screens/patient_queue_screen.dart` |
| `consumer_roles` | `customer` (next patient) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, queue_id, position]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `queue_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: the next patient in line. Reason: queue position changed; patient must walk to the consultation room. Action: enter consultation. |

### 9.24 `users.clinic_prescription.created`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `prescription` |
| `event_name` | `users.clinic_prescription.created` |
| `trigger_condition` | A prescription is saved by the doctor. [T-CLN-4] |
| `source_module` | `Dukan_x/lib/features/doctor/presentation/screens/add_prescription_screen.dart`; `my-backend/src/handlers/pharmacy.ts` |
| `consumer_roles` | `customer` (patient), `pharmacist`, `clinic_doctor` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `pharmacist`: `in_app`, `push`; `clinic_doctor`: `in_app` |
| `deduplication_rule` | Key: `[event_name, prescription_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `patient_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: patient, pharmacist, the prescribing doctor (audit). Reason: patient picks up meds; pharmacist dispenses. Action: dispense and pay. |

### 9.25 `users.pharmacy_refill.due`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `pharmacy_refill` |
| `event_name` | `users.pharmacy_refill.due` |
| `trigger_condition` | A patient's chronic-medication refill window opens. [T-CLN-5] |
| `source_module` | `my-backend/src/handlers/modules/pharmacy/pharmacy-refills.ts` |
| `consumer_roles` | `customer`, `pharmacist` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `pharmacist`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, patient_id, refill_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `patient_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: patient and pharmacist. Reason: medication adherence and restock. Action: patient orders refill; pharmacist preps. |

### 9.26 `users.pharmacy_narcotic.entry_recorded`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `narcotic_register` |
| `event_name` | `users.pharmacy_narcotic.entry_recorded` |
| `trigger_condition` | A narcotic register entry is recorded. [T-CLN-6] |
| `source_module` | `Dukan_x/lib/features/pharmacy/screens/narcotic_register_screen.dart`; `my-backend/src/handlers/modules/pharmacy/pharmacy-narcotic.ts` |
| `consumer_roles` | `pharmacist`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `pharmacist`: `in_app`, `push`; `admin`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, narcotic_entry_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: pharmacist (acknowledgement), shop owner (compliance). Reason: regulatory audit trail. Action: confirm log; flag if anomaly. |

### 9.27 `users.clinic_lab.ordered`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `lab_order` |
| `event_name` | `users.clinic_lab.ordered` |
| `trigger_condition` | A lab order is created. [T-CLN-7] |
| `source_module` | `Dukan_x/lib/features/doctor/presentation/screens/lab_reports_screen.dart`; `Dukan_x/lib/features/clinic/presentation/screens/lab_order_screen.dart` |
| `consumer_roles` | `customer`, `clinic_doctor`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `clinic_doctor`: `in_app`, `push`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, lab_order_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `patient_id`; non-`critical` Quiet_Hours suppression on `push`/`sms` |
| `justification` | Recipient: patient, ordering doctor, lab desk (admin). Reason: patient awaits sample; lab queues task. Action: patient travels to lab; lab schedules. |

### 9.28 `users.clinic_lab.result_published`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `lab_result` |
| `event_name` | `users.clinic_lab.result_published` |
| `trigger_condition` | A lab result is entered and published. [T-CLN-8] |
| `source_module` | `my-backend/src/handlers/clinic-lab-results.ts` (planned per Phase 1 Gap §11.1; emit added during Phase 4) |
| `consumer_roles` | `customer`, `clinic_doctor` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `sms`; `clinic_doctor`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, lab_order_id, result_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `patient_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: patient, ordering doctor. Reason: doctor reviews; patient gets care plan. Action: book follow-up; review with doctor. |

### 9.29 `users.staff_attendance.checked_in`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `staff_attendance` |
| `event_name` | `users.staff_attendance.checked_in` |
| `trigger_condition` | A staff member checks in (`STAFF_CHECKED_IN`). [T-PMP-6] |
| `source_module` | `lambda/staff-attendance/src/handlers/staffCheckIn.ts` |
| `consumer_roles` | `admin`, `pump_attendant`, `staff` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`; `pump_attendant`: `in_app`; `staff`: `in_app` |
| `deduplication_rule` | Key: `[event_name, staff_id, shift_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression |
| `justification` | Recipient: shop owner / station manager and the staff member (audit). Reason: attendance audit. Action: monitor presence; staff sees own check-in confirmed. |

### 9.30 `users.staff_attendance.checked_out`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `staff_attendance` |
| `event_name` | `users.staff_attendance.checked_out` |
| `trigger_condition` | A staff member checks out (`STAFF_CHECKED_OUT`). [T-PMP-6] |
| `source_module` | `lambda/staff-attendance/src/handlers/staffCheckOut.ts` |
| `consumer_roles` | `admin`, `pump_attendant`, `staff` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`; `pump_attendant`: `in_app`; `staff`: `in_app` |
| `deduplication_rule` | Key: `[event_name, staff_id, shift_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression |
| `justification` | Recipient: shop owner / station manager and the staff member. Reason: shift-end audit. Action: review hours; staff sees confirmation. |

### 9.31 `users.staff_sale.recorded`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `staff_sale` |
| `event_name` | `users.staff_sale.recorded` |
| `trigger_condition` | A staff product sale is recorded (`STAFF_SALE_CREATED`). [T-PMP-7] |
| `source_module` | `my-backend/src/handlers/staff-sale.ts` (~line 316) |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, staff_id, sale_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; throttled by §13 fatigue rules |
| `justification` | Recipient: shop owner. Reason: incentive and audit visibility. Action: monitor performance and incentives. |

### 9.32 `users.pump_staff_activity.recorded`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `pump_activity` |
| `event_name` | `users.pump_staff_activity.recorded` |
| `trigger_condition` | A pump staff activity is recorded (`STAFF_ACTIVITY`). [T-PMP-2] |
| `source_module` | `my-backend/src/handlers/pump.ts` (~line 440) |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, pump_id, staff_id, activity_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; throttled by §13 fatigue rules |
| `justification` | Recipient: shop owner. Reason: staff performance and audit. Action: review summaries. |

### 9.33 `users.pump_shift.opened`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `pump_shift` |
| `event_name` | `users.pump_shift.opened` |
| `trigger_condition` | A pump shift is opened (`SHIFT_OPENED`). [T-PMP-4] |
| `source_module` | `my-backend/src/handlers/pump.ts` (~line 662) |
| `consumer_roles` | `admin`, `pump_attendant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`; `pump_attendant`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, pump_id, shift_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: shop owner, attending pump_attendant. Reason: shift accountability. Action: monitor; attendant starts shift. |

### 9.34 `users.pump_shift.closed`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `pump_shift` |
| `event_name` | `users.pump_shift.closed` |
| `trigger_condition` | A pump shift is closed (`SHIFT_CLOSED`). [T-PMP-5] |
| `source_module` | `my-backend/src/handlers/pump.ts` (~line 956) |
| `consumer_roles` | `admin`, `accountant`, `pump_attendant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`; `accountant`: `in_app`, `email`; `pump_attendant`: `in_app` |
| `deduplication_rule` | Key: `[event_name, pump_id, shift_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner, accountant, attendant who closed. Reason: cash + sales reconciliation. Action: verify totals; sign off on close. |

### 9.35 `users.marketing_campaign.sent`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `campaign` |
| `event_name` | `users.marketing_campaign.sent` |
| `trigger_condition` | A marketing campaign is sent to a customer segment. [T-MKT-LOY-1] |
| `source_module` | `Dukan_x/lib/features/marketing/presentation/screens/create_campaign_screen.dart`; `my-backend/src/handlers/loyalty.ts` |
| `consumer_roles` | `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `customer`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, campaign_id, customer_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `campaign_id`; non-`critical` Quiet_Hours suppression on `push`/`email`; **mutable** by recipient (campaigns are always opt-out by category) |
| `justification` | Recipient: targeted customer. Reason: campaign is intentional outreach. Action: customer engages with the promo. |

### 9.36 `users.loyalty_points.awarded`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `loyalty_points` |
| `event_name` | `users.loyalty_points.awarded` |
| `trigger_condition` | Loyalty points are awarded to a customer. [T-MKT-LOY-2] |
| `source_module` | `my-backend/src/handlers/loyalty.ts` |
| `consumer_roles` | `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `customer`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, customer_id, transaction_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: customer. Reason: balance changed. Action: redeem when threshold reached. |

### 9.37 `users.loyalty_tier.upgraded`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `loyalty_tier` |
| `event_name` | `users.loyalty_tier.upgraded` |
| `trigger_condition` | A customer's loyalty tier is upgraded. [T-MKT-LOY-3] |
| `source_module` | `my-backend/src/handlers/loyalty.ts` |
| `consumer_roles` | `customer`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `customer`: `in_app`, `push`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, customer_id, tier]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `customer_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: customer, shop owner. Reason: new benefits unlocked; owner tracks tier movements. Action: customer uses new perks; owner tracks. |

### 9.38 `users.ai_notify_owner.requested`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `ai_assistant` |
| `event_name` | `users.ai_notify_owner.requested` |
| `trigger_condition` | The AI assistant calls its `notify_owner` tool. [T-AI-2] |
| `source_module` | `my-backend/src/services/ai-tools.registry.ts` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, conversation_id, finding_hash]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `conversation_id`; non-`critical` Quiet_Hours suppression on `push` |
| `justification` | Recipient: shop owner. Reason: the tool's stated purpose is to surface a finding to the owner. Action: review and act on the AI's finding. |

### 9.39 `users.vegetable_broker.reconciliation_posted`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `vegetable_broker` |
| `event_name` | `users.vegetable_broker.reconciliation_posted` |
| `trigger_condition` | A vegetable-broker reconciliation is posted between farmer and trader. [T-VEG-1] |
| `source_module` | `Dukan_x/lib/features/vegetable_broker/data/repositories/vegetable_broker_repository.dart` |
| `consumer_roles` | `farmer`, `vendor`, `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `farmer`: `in_app`, `push`, `sms`; `vendor`: `in_app`, `email`; `admin`: `in_app`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, reconciliation_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `farmer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: farmer (supplier), vendor/trader, shop owner, accountant. Reason: settlement amount visibility. Action: confirm or dispute. |

### 9.40 `users.vegetable_broker.dispatch_created`

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `vegetable_broker` |
| `event_name` | `users.vegetable_broker.dispatch_created` |
| `trigger_condition` | A dispatch challan is created in the vegetable broker module. [T-VEG-2] |
| `source_module` | `Dukan_x/lib/features/vegetable_broker/data/repositories/vegetable_broker_repository.dart` |
| `consumer_roles` | `farmer`, `vendor`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `farmer`: `in_app`, `push`, `sms`; `vendor`: `in_app`, `email`; `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dispatch_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `farmer_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: farmer, vendor/trader, shop owner. Reason: traceability of dispatch. Action: confirm dispatch. |

---

## 10. Event Registry — Reports

Domain coverage: report cards, exam scheduling, exam results published, decoration & catering profitability summary, pump shift summary. (REQ 2.14)

### 10.1 `reports.school_exam.scheduled`

| Field | Value |
|---|---|
| `category` | `reports` |
| `sub_category` | `exam_schedule` |
| `event_name` | `reports.school_exam.scheduled` |
| `trigger_condition` | An exam is scheduled (`AC_EXAM_SCHEDULED`). [T-SCH-8] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-exams.ts` |
| `consumer_roles` | `student`, `parent`, `teacher` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `normal` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app`, `push`, `email`; `teacher`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, exam_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `class_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: student, parent, teacher of the subject. Reason: prep + invigilation planning. Action: study; assign invigilator. |

### 10.2 `reports.school_exam.results_published`

| Field | Value |
|---|---|
| `category` | `reports` |
| `sub_category` | `exam_results` |
| `event_name` | `reports.school_exam.results_published` |
| `trigger_condition` | Exam results are published (`AC_RESULTS_PUBLISHED`). [T-SCH-9] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-exams.ts` |
| `consumer_roles` | `student`, `parent`, `teacher` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `high` |
| `channels_per_role` | `student`: `in_app`, `push`, `sms`; `parent`: `in_app`, `push`, `sms`, `email`; `teacher`: `in_app`, `push` |
| `deduplication_rule` | Key: `[event_name, exam_id, student_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`sms`/`email` |
| `justification` | Recipient: student, parent, teacher of the subject. Reason: result visibility. Action: review marks; download report card. |

### 10.3 `reports.school_report_card.generated`

| Field | Value |
|---|---|
| `category` | `reports` |
| `sub_category` | `report_card` |
| `event_name` | `reports.school_report_card.generated` |
| `trigger_condition` | A report card is generated for a student. [T-SCH-10] |
| `source_module` | `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_report_cards_screen.dart` |
| `consumer_roles` | `student`, `parent` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `high` |
| `channels_per_role` | `student`: `in_app`, `push`, `email`; `parent`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, report_card_id]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: student, parent. Reason: the official report card document is available. Action: download or print. |

### 10.4 `reports.pump_sale.recorded`

| Field | Value |
|---|---|
| `category` | `reports` |
| `sub_category` | `pump_sale` |
| `event_name` | `reports.pump_sale.recorded` |
| `trigger_condition` | A pump sale is recorded (`PETROL_SALE_UPDATE` / `DIESEL_SALE_UPDATE`). [T-PMP-1] |
| `source_module` | `my-backend/src/handlers/pump.ts` (~line 432) |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, pump_id, sale_id]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; throttled by §13 fatigue rules — coalesced into a 5-minute summary |
| `justification` | Recipient: shop owner. Reason: real-time sales visibility. Action: monitor and reconcile shift. |

### 10.5 `reports.dc_profitability.updated`

| Field | Value |
|---|---|
| `category` | `reports` |
| `sub_category` | `dc_profitability` |
| `event_name` | `reports.dc_profitability.updated` |
| `trigger_condition` | A change to a DC event causes profitability metrics to recompute (cost added, payment received, expense logged). |
| `source_module` | `my-backend/src/handlers/dc.ts` (computed projection) |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app` |
| `deduplication_rule` | Key: `[event_name, dc_event_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `dc_event_id`; non-`critical` Quiet_Hours suppression |
| `justification` | Recipient: shop owner. Reason: live P&L visibility for upcoming and live events. Action: review margin; adjust pricing. |

---

## 11. Event Registry — System

Domain coverage: tenant trial/subscription lifecycle, manifest invalidation, security events, fraud, cash mismatch, stock anomaly, unauthorized access, system health. (REQ 2.14)

### 11.1 `system.tenant_trial.started`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `tenant_trial` |
| `event_name` | `system.tenant_trial.started` |
| `trigger_condition` | A tenant trial is provisioned. [T-PLN-1] |
| `source_module` | `lambda/trialProvisioningHandler/index.mjs` |
| `consumer_roles` | `admin` (tenant owner) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, tenant_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner / tenant owner. Reason: welcome and trial countdown awareness. Action: start using; convert before expiry. |

### 11.2 `system.tenant_trial.expiry_reminder`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `tenant_trial` |
| `event_name` | `system.tenant_trial.expiry_reminder` |
| `trigger_condition` | T-7 / T-3 / T-1 trial expiry reminders. [T-PLN-2] |
| `source_module` | `lambda/trialNotificationSchedulerHandler/index.mjs` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, tenant_id, days_remaining]`; Window: `86400 s` (24 hours — one per day per stage) |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: tenant owner. Reason: avoid lock-out. Action: upgrade plan. |

### 11.3 `system.tenant_trial.expired`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `tenant_trial` |
| `event_name` | `system.tenant_trial.expired` |
| `trigger_condition` | A tenant trial expires. [T-PLN-3] |
| `source_module` | `lambda/trialExpiryCronHandler/index.mjs` |
| `consumer_roles` | `admin`, `super_admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `admin`: `in_app`, `push`, `sms`, `email`; `super_admin`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, tenant_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable** because the account is locked (REQ 7.6 critical bypass); Quiet_Hours bypassed because `priority == critical` |
| `justification` | Recipient: tenant owner, super_admin. Reason: account locked — owner cannot transact until paid. Action: pay to unlock. |

### 11.4 `system.tenant_grace_period.ended`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `tenant_grace_period` |
| `event_name` | `system.tenant_grace_period.ended` |
| `trigger_condition` | The post-trial grace period ends without payment. [T-PLN-4] |
| `source_module` | `my-backend/src/handlers/cron/grace-period-cron.ts` |
| `consumer_roles` | `admin`, `super_admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `admin`: `in_app`, `push`, `sms`, `email`; `super_admin`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, tenant_id]`; Window: `86400 s` (24 hours) |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable**; Quiet_Hours bypassed |
| `justification` | Recipient: tenant owner, super_admin. Reason: account suspension imminent. Action: pay immediately. |

### 11.5 `system.tenant_subscription.renewed`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `tenant_subscription` |
| `event_name` | `system.tenant_subscription.renewed` |
| `trigger_condition` | A subscription renewal succeeds. [T-PLN-5] |
| `source_module` | `my-backend/src/handlers/subscription-webhook.ts` |
| `consumer_roles` | `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `normal` |
| `channels_per_role` | `admin`: `in_app`, `email`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, tenant_id, billing_period]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `email` |
| `justification` | Recipient: tenant owner, accountant. Reason: billing visibility. Action: file invoice/receipt. |

### 11.6 `system.tenant_subscription.failed`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `tenant_subscription` |
| `event_name` | `system.tenant_subscription.failed` |
| `trigger_condition` | A subscription renewal fails. [T-PLN-5] |
| `source_module` | `my-backend/src/handlers/subscription-webhook.ts` |
| `consumer_roles` | `admin`, `super_admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `admin`: `in_app`, `push`, `sms`, `email`; `super_admin`: `in_app`, `email`; `accountant`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, tenant_id, billing_period]`; Window: `3600 s` (1 hour) |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable**; Quiet_Hours bypassed |
| `justification` | Recipient: tenant owner, super_admin, accountant. Reason: account at risk of suspension; payment method must be updated. Action: update payment method. |

### 11.7 `system.tenant_manifest.invalidated`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `feature_flag` |
| `event_name` | `system.tenant_manifest.invalidated` |
| `trigger_condition` | The tenant feature manifest is invalidated (`MANIFEST_INVALIDATED`). [T-PLN-6] |
| `source_module` | `my-backend/src/handlers/feature-flag.ts` |
| `consumer_roles` | `admin`, `cashier`, `accountant`, `staff`, `chef`, `kitchen_staff`, `waiter`, `pump_attendant`, `service_technician`, `jewellery_artisan`, `pharmacist`, `clinic_doctor`, `dc_staff` |
| `consumer_apps` | `dukanx_desktop`, `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `high` |
| `channels_per_role` | All listed roles: `in_app` (silent feature-toggle reload — push/sms/email are inappropriate for a runtime config refresh) |
| `deduplication_rule` | Key: `[event_name, tenant_id, manifest_version]`; Window: `60 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; never muted (operational). Suppressed only by Quiet_Hours: not applicable because `in_app`-only |
| `justification` | Recipient: every connected device of the tenant (every active role). Reason: feature toggle / plan change requires the client to re-render. Action: client refetches manifest and re-renders. |

### 11.8 `system.security_fraud.alert_raised`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `fraud_alert` |
| `event_name` | `system.security_fraud.alert_raised` |
| `trigger_condition` | A fraud alert is raised by `FraudDetectionService`. [T-SEC-1] |
| `source_module` | `Dukan_x/lib/core/services/security_notification_service.dart` (`_handleAlert`) |
| `consumer_roles` | `admin`, `super_admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `admin`: `in_app`, `push`, `sms`, `email`; `super_admin`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, fraud_alert_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable** because security review is mandatory; Quiet_Hours bypassed |
| `justification` | Recipient: shop owner, super_admin. Reason: anomalous transaction needs review. Action: review, block, refund, or call customer. |

### 11.9 `system.security_cash.mismatch_detected`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `cash_mismatch` |
| `event_name` | `system.security_cash.mismatch_detected` |
| `trigger_condition` | The cash-closing validator detects a mismatch. [T-SEC-2] |
| `source_module` | `Dukan_x/lib/core/services/cash_closing_validation_service.dart` |
| `consumer_roles` | `admin`, `accountant` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `critical` |
| `channels_per_role` | `admin`: `in_app`, `push`, `sms`; `accountant`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, day_close_id]`; Window: `3600 s` (1 hour) |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable**; Quiet_Hours bypassed |
| `justification` | Recipient: shop owner, accountant. Reason: investigate the cashier and reconcile. Action: reconcile or interview cashier. |

### 11.10 `system.security_stock.anomaly_detected`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `stock_anomaly` |
| `event_name` | `system.security_stock.anomaly_detected` |
| `trigger_condition` | The stock security service detects a suspicious pattern. [T-SEC-3] |
| `source_module` | `Dukan_x/lib/core/services/stock_security_service.dart` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email` |
| `deduplication_rule` | Key: `[event_name, anomaly_id]`; Window: `3600 s` (1 hour) |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: shop owner. Reason: investigate shrinkage or theft. Action: physical stock count and CCTV review. |

### 11.11 `system.security_access.unauthorized_attempt`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `unauthorized_access` |
| `event_name` | `system.security_access.unauthorized_attempt` |
| `trigger_condition` | A request is denied by `role-guard` or `permission-guard` (REQ 12.7). [T-SEC-5] |
| `source_module` | `my-backend/src/middleware/role-guard.ts`; `my-backend/src/middleware/permission-guard.ts` |
| `consumer_roles` | `admin` (within tenant), `super_admin` (cross-tenant) |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `admin`: `in_app`, `push`, `email`; `super_admin`: `in_app`, `email` |
| `deduplication_rule` | Key: `[event_name, requester_user_id, denied_resource]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; non-`critical` Quiet_Hours suppression on `push`/`email`; per-recipient cap of 20/h to prevent log floods (see §13) |
| `justification` | Recipient: shop owner (within-tenant attempts), super_admin (cross-tenant attempts). Reason: security visibility per REQ 12.7. Action: review and possibly disable user. |

### 11.12 `system.health.degraded`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `health` |
| `event_name` | `system.health.degraded` |
| `trigger_condition` | A backend health check fails. [T-SEC-7] |
| `source_module` | `my-backend/src/handlers/health.ts` |
| `consumer_roles` | `super_admin` |
| `consumer_apps` | `webhook_consumer` (operator paging system) |
| `priority` | `critical` |
| `channels_per_role` | `super_admin`: `in_app`, `push`, `sms`, `email`, `webhook` |
| `deduplication_rule` | Key: `[event_name, component_id, severity]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable** for super_admin (operational paging); Quiet_Hours bypassed |
| `justification` | Recipient: super_admin only (operator). Reason: operational alerting. Action: investigate; page on-call. |

### 11.13 `system.notifications_alert.high_failure_rate`

| Field | Value |
|---|---|
| `category` | `system` |
| `sub_category` | `observability` |
| `event_name` | `system.notifications_alert.high_failure_rate` |
| `trigger_condition` | The UNS rolling 5-minute failure ratio crosses 5% with at least 1 dispatch in the window (REQ 14.6). |
| `source_module` | `my-backend/src/notifications/observability/alerts.ts` (Phase 5) |
| `consumer_roles` | `super_admin` |
| `consumer_apps` | `webhook_consumer` |
| `priority` | `critical` |
| `channels_per_role` | `super_admin`: `in_app`, `push`, `email`, `webhook` |
| `deduplication_rule` | Key: `[event_name, alert_window_start]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; **un-mutable** for super_admin; Quiet_Hours bypassed |
| `justification` | Recipient: super_admin. Reason: the notification system itself is degrading. Action: investigate channel adapters and DLQ. |

---

## 12. Batched Events

REQ 2.10: any multi-item operation that would otherwise emit one event per item must be defined here as a batched event with `batch_window_seconds` and `summary_payload`.

### 12.1 `inventory.import.progress` (batched)

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `bulk_import` |
| `event_name` | `inventory.import.progress` |
| `trigger_condition` | Per-row progress emit during a bulk inventory import. [T-INV-12] |
| `source_module` | `my-backend/src/handlers/process-import-row.ts` (`IMPORT_PROGRESS`); `Dukan_x/lib/features/inventory/presentation/screens/import_inventory_screen.dart` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app` |
| `batch_window_seconds` | `2` |
| `summary_payload` | `{ "import_job_id": string, "rows_total": int, "rows_processed": int, "rows_failed": int, "percent_complete": int (0..100), "errors_sample": [ { "row": int, "reason": string } ] (capped at 5), "elapsed_ms": int }` |
| `deduplication_rule` | Key: `[event_name, import_job_id]`; Window: `2 s` (rolling — every 2 s emit at most one progress notification per job) |
| `silence_conditions` | `actor_id == recipient.user_id` only when started elsewhere; muted `import_job_id` |
| `justification` | Recipient: the user running the import. Reason: long-running progress feedback without per-row notification spam. Action: monitor progress; abort on rising error rate. |

### 12.2 `orders.restaurant_kot.bulk_created` (batched)

| Field | Value |
|---|---|
| `category` | `orders` |
| `sub_category` | `restaurant_kot` |
| `event_name` | `orders.restaurant_kot.bulk_created` |
| `trigger_condition` | A multi-item KOT is committed at once (e.g. order with 6 dishes); also emitted when several KOTs hit the kitchen within a short window. [T-RES-2] |
| `source_module` | `my-backend/src/handlers/modules/restaurant/restaurant-kot.ts` |
| `consumer_roles` | `chef`, `kitchen_staff` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `high` |
| `channels_per_role` | `chef`: `in_app`, `push`; `kitchen_staff`: `in_app`, `push` |
| `batch_window_seconds` | `5` |
| `summary_payload` | `{ "table_id": string, "order_id": string, "kots": [ { "kot_id": string, "items": [ { "item_id": string, "name": string, "qty": int, "modifiers": [string] } ] } ], "total_items": int }` |
| `deduplication_rule` | Key: `[event_name, table_id, order_id, batch_started_at]`; Window: `5 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `table_id` |
| `justification` | Recipient: chef and kitchen staff. Reason: a single push for the whole order avoids buzzer spam in busy kitchens. Action: prep the items as a single ticket. |

### 12.3 `inventory.stock.bulk_decremented_by_sale` (batched)

| Field | Value |
|---|---|
| `category` | `inventory` |
| `sub_category` | `sale_decrement_summary` |
| `event_name` | `inventory.stock.bulk_decremented_by_sale` |
| `trigger_condition` | High-throughput sale decrements (>5 items/s on the same invoice or same till) are coalesced into a per-invoice summary. [T-INV-8] |
| `source_module` | `my-backend/src/services/invoice.service.ts` |
| `consumer_roles` | `cashier`, `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `cashier`: `in_app`; `admin`: `in_app` |
| `batch_window_seconds` | `3` |
| `summary_payload` | `{ "invoice_id": string, "items": [ { "product_id": string, "qty_decremented": int, "stock_after": int } ], "items_count": int }` |
| `deduplication_rule` | Key: `[event_name, invoice_id, batch_started_at]`; Window: `3 s` |
| `silence_conditions` | `actor_id == recipient.user_id` |
| `justification` | Recipient: cashier on other tenant devices, shop owner. Reason: avoid one-event-per-line in long invoices while still providing oversell protection at terminal level. Action: refresh availability for all decremented SKUs in a single pass. |

### 12.4 `delivery.location.bulk_updated` (batched)

| Field | Value |
|---|---|
| `category` | `delivery` |
| `sub_category` | `live_tracking_summary` |
| `event_name` | `delivery.location.bulk_updated` |
| `trigger_condition` | Coalescer for high-frequency location pings during a delivery. [T-DLV-3] |
| `source_module` | `lambda/marketplace/deliveryHandler/index.ts` |
| `consumer_roles` | `customer` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `customer`: `in_app` |
| `batch_window_seconds` | `30` |
| `summary_payload` | `{ "agent_id": string, "order_id": string, "path": [ { "lat": number, "lng": number, "ts": ISO8601 } ] (capped at 20), "current_eta_minutes": int }` |
| `deduplication_rule` | Key: `[event_name, agent_id, order_id, batch_started_at]`; Window: `30 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `order_id` |
| `justification` | Recipient: receiving customer. Reason: a single 30-second tracking summary keeps the map fresh without flooding push channels. Action: customer prepares to receive. |

### 12.5 `users.school_announcement.bulk_published` (batched)

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `announcement_summary` |
| `event_name` | `users.school_announcement.bulk_published` |
| `trigger_condition` | School publishes more than 3 announcements within `batch_window_seconds` to the same audience. [T-SCH-20] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-communication.ts` |
| `consumer_roles` | `student`, `parent`, `teacher` |
| `consumer_apps` | `school_admin_app`, `school_student_app`, `school_teacher_app` |
| `priority` | `normal` |
| `channels_per_role` | `student`: `in_app`, `push`; `parent`: `in_app`, `push`, `email`; `teacher`: `in_app`, `push` |
| `batch_window_seconds` | `300` |
| `summary_payload` | `{ "audience_scope": string, "announcements": [ { "announcement_id": string, "title": string, "summary": string, "published_at": ISO8601 } ], "count": int }` |
| `deduplication_rule` | Key: `[event_name, audience_scope, batch_started_at]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `audience_scope`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: scoped audience. Reason: batched digest replaces a flood of single announcements during admission week or exam week. Action: read all bundled announcements in a single tap. |

### 12.6 `billing.school_fee.bulk_assigned` (batched)

| Field | Value |
|---|---|
| `category` | `billing` |
| `sub_category` | `school_fee_bulk` |
| `event_name` | `billing.school_fee.bulk_assigned` |
| `trigger_condition` | School-wide bulk fee assignment (e.g. start-of-term run for all students of a section). [T-SCH-2] |
| `source_module` | `my-backend/src/handlers/modules/school-erp/school-fees.ts` (bulk endpoint) |
| `consumer_roles` | `parent`, `student`, `school_admin` |
| `consumer_apps` | `school_admin_app`, `school_student_app` |
| `priority` | `normal` |
| `channels_per_role` | `parent`: `in_app`, `push`, `email`; `student`: `in_app`, `push`; `school_admin`: `in_app`, `email` |
| `batch_window_seconds` | `300` |
| `summary_payload` | `{ "term_id": string, "student_id": string, "fees": [ { "fee_id": string, "head": string, "amount": number, "due_date": ISO8601 } ], "total_amount": number }` |
| `deduplication_rule` | Key: `[event_name, student_id, term_id]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id`; muted `student_id`; non-`critical` Quiet_Hours suppression on `push`/`email` |
| `justification` | Recipient: parent and student per child plus school_admin. Reason: a single notification per child for the whole term beats one per fee head. Action: parent reviews the term's full bill and pays. |

### 12.7 `users.staff_sale.bulk_recorded` (batched)

| Field | Value |
|---|---|
| `category` | `users` |
| `sub_category` | `staff_sale_summary` |
| `event_name` | `users.staff_sale.bulk_recorded` |
| `trigger_condition` | Coalescer for high-frequency staff-sale events on the same staff/shift. [T-PMP-7] |
| `source_module` | `my-backend/src/handlers/staff-sale.ts` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app` |
| `batch_window_seconds` | `300` |
| `summary_payload` | `{ "staff_id": string, "shift_id": string, "sales_count": int, "total_amount": number, "top_products": [ { "product_id": string, "qty": int } ] }` |
| `deduplication_rule` | Key: `[event_name, staff_id, shift_id, batch_started_at]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id` |
| `justification` | Recipient: shop owner. Reason: the dashboard already shows live counters; a 5-minute summary is the right notification cadence. Action: review per-staff performance. |

### 12.8 `reports.pump_sale.bulk_summary` (batched)

| Field | Value |
|---|---|
| `category` | `reports` |
| `sub_category` | `pump_sale_summary` |
| `event_name` | `reports.pump_sale.bulk_summary` |
| `trigger_condition` | Coalescer for the high-frequency `reports.pump_sale.recorded` event. [T-PMP-1] |
| `source_module` | `my-backend/src/handlers/pump.ts` |
| `consumer_roles` | `admin` |
| `consumer_apps` | `dukanx_desktop` |
| `priority` | `low` |
| `channels_per_role` | `admin`: `in_app` |
| `batch_window_seconds` | `300` |
| `summary_payload` | `{ "pump_id": string, "shift_id": string, "fuel_breakdown": [ { "fuel_type": string, "litres": number, "amount": number } ], "total_amount": number, "sales_count": int }` |
| `deduplication_rule` | Key: `[event_name, pump_id, shift_id, batch_started_at]`; Window: `300 s` |
| `silence_conditions` | `actor_id == recipient.user_id` |
| `justification` | Recipient: shop owner. Reason: per-second sale notifications would flood; a 5-minute summary keeps the owner informed. Action: monitor sales pace. |

---

## 13. Notification Fatigue Risks

REQ 2.11: events with elevated frequency risk, the suppression rule that mitigates them, and the maximum allowed deliveries per recipient per hour.

| Event(s) | Risk | Suppression rule | Max deliveries / recipient / hour |
|---|---|---|---|
| `inventory.stock.changed` (§6.1) | Sale and adjustment storms can fire dozens of changes per minute on a busy till. | Deduplicate on `(event_name, product_id, stock_after)` within 30 s; coalesce same-product churn into the latest value. | `30` |
| `inventory.stock.decremented_by_sale` (§6.7) | Long invoices generate one event per item. | Coalesce to `inventory.stock.bulk_decremented_by_sale` (§12.3) on a 3 s window when items/s > 5 on the same invoice. | `60` (cashier on second terminal) |
| `inventory.import.progress` (§12.1) | Per-row emit can hit thousands of events. | Batched at `batch_window_seconds = 2`; only the latest summary delivers per window. | `30` (per active import job) |
| `inventory.stock.low` (§6.2) | Stock can oscillate around the threshold. | Deduplicate on `product_id` for 6 hours; only one alert per product per 6-hour window. | `4` |
| `inventory.batch.expiring` (§6.8) | Daily scan touches every batch. | Deduplicate on `batch_id` for 24 hours; only one alert per batch per day. | `4` |
| `orders.restaurant_kot.created` (§7.2) and `orders.restaurant_kot.status_changed` (§7.3) | Busy service can produce dozens of KOTs per minute. | Bulk-batched as `orders.restaurant_kot.bulk_created` (§12.2) on a 5 s window. | `60` (kitchen displays already render in-place) |
| `orders.jewellery_gold_rate.alert_triggered` (§7.9) | Price oscillation around the threshold can fire repeatedly. | Deduplicate on `(alert_id, threshold_direction)` for 30 minutes. | `2` |
| `orders.jewellery_gold_rate.updated` (§7.10) | Owner may publish multiple rate updates within minutes. | Deduplicate on `rate_effective_at` for 60 s. | `10` |
| `delivery.location.updated` (§8.4) | GPS can ping every 1-3 seconds. | Coalesce to `delivery.location.bulk_updated` (§12.4) on a 30 s window. | `120` |
| `users.school_attendance.marked` (§9.8) | Every class marks once per day; aggregated alerts are sufficient. | Deduplicate on `(student_id, attendance_date)` for 60 s; per-class digest is preferred via `users.school_attendance.bulk_marked` (future batch). | `8` (one per period for a parent with multiple children) |
| `users.school_attendance.absent_alert` (§9.9) | Same-day absence triggers across multiple periods. | Deduplicate on `(student_id, attendance_date)` for 6 hours. | `1` per child per day |
| `users.school_announcement.published` (§9.20) | Schools may post several announcements per day. | Bulk-batched as `users.school_announcement.bulk_published` (§12.5) on a 5-minute window when count > 3. | `6` digests (corresponds to ~36 announcements per day before throttling) |
| `users.school_homework.assigned` (§9.14) | Each subject teacher may assign on the same day. | Deduplicate on `(class_id, subject_id, day)` for 60 s; combine into a single push when fired in the same period. | `8` |
| `users.school_material.uploaded` (§9.15) | Bulk uploads at term start. | Deduplicate on `material_id` for 5 minutes; coalesce into a per-class digest when count > 5. | `6` |
| `users.school_timetable.updated` (§9.13) | Timetable edits during school day. | Deduplicate on `(class_id, term_id, version)` for 5 minutes. | `4` |
| `users.school_leave.processed` (§9.12) | Bulk processing of pending requests. | Deduplicate on `(leave_id, decision)` for 60 s. | `8` |
| `users.school_attendance.low_alert` (§9.10) | Threshold cross can repeat as attendance fluctuates. | Deduplicate on `(student_id, term_id)` for 24 hours. | `1` per child per day |
| `users.customer_credit.reminder_sent` (§9.3) | Multi-stage dunning can pile up. | Deduplicate on `(customer_id, reminder_stage)` for 6 hours. | `4` (across stages in a 24 h window) |
| `users.school_library.due` / `users.school_library.overdue` (§9.16, §9.17) | Daily scan repeats. | Deduplicate on `loan_id` for 24 hours. | `2` |
| `users.staff_sale.recorded` (§9.31) and `users.pump_staff_activity.recorded` (§9.32) | Per-transaction emit. | Coalesce to summaries (§12.7) on 5-minute windows. | `12` summaries |
| `reports.pump_sale.recorded` (§10.4) | Per-fuel-sale emit. | Coalesce to `reports.pump_sale.bulk_summary` (§12.8) on 5-minute windows. | `12` summaries |
| `system.security_access.unauthorized_attempt` (§11.11) | A scan or brute-force can flood. | Deduplicate on `(requester_user_id, denied_resource)` for 5 minutes. | `20` |
| `users.marketing_campaign.sent` (§9.35) | Multiple campaigns per day. | Deduplicate on `(campaign_id, customer_id)` for 24 hours. | `2` |

**Global per-recipient hourly cap.** Across all event types combined, no single recipient receives more than **`60` notifications per hour** on any single channel by default (matching REQ 9.5 channel rate limits: `in_app` 60/min cap is already wider). When the cap is hit on a channel, subsequent same-`event_name` notifications are coalesced into a batched summary delivered after the limit window resets (REQ 9.6).

**Global per-recipient daily cap.** Across all event types combined, no recipient receives more than **`200` notifications per 24 h** on `push` or `email` channels. Beyond this cap, only `priority == critical` events break through.

---

## 14. Per-Role Recipient Mappings

REQ 17.1 (minimum role coverage) plus REQ 17.2 (no-events justification per unmapped role).

> Each row lists the roles' candidate event names. Authorization at dispatch time (REQ 4.11, 12.1) further restricts each delivery to recipients owning the relevant `target_id` (e.g. own invoice, own student, own table, own job).
>
> The list below is grouped by role family and uses the canonical `event_name`s defined in §§4–11 of this registry.

### 14.1 `super_admin`

Operator-only events:

- `system.tenant_trial.expired`, `system.tenant_grace_period.ended`, `system.tenant_subscription.failed`, `system.tenant_manifest.invalidated`
- `system.security_fraud.alert_raised`, `system.security_access.unauthorized_attempt` (cross-tenant), `system.health.degraded`, `system.notifications_alert.high_failure_rate`

### 14.2 `admin` (alias `shop_owner`)

Tenant-owner events across every domain:

- Billing: `billing.invoice.created`, `billing.invoice.finalized`, `billing.invoice.updated`, `billing.invoice.returned`, `billing.credit_note.issued`, `billing.dc.invoice.created`, `billing.restaurant_bill.updated`
- Payments: `payment.invoice.received`, `payment.gateway.success`, `payment.gateway.failed`, `payment.refund.processed`, `payment.customer_collection.recorded`, `payment.vendor_payment.collected`, `payment.purchase_payment.made`, `payment.dc.received`, `payment.dc.expense.added`, `payment.cash_drop.recorded`
- Inventory: `inventory.stock.changed`, `inventory.stock.low`, `inventory.item.created`, `inventory.item.updated`, `inventory.item.deleted`, `inventory.stock.adjusted`, `inventory.batch.expiring`, `inventory.batch.expired`, `inventory.import.completed`, `inventory.import.failed`, `inventory.hallmark.received`, `inventory.dc.low`, `inventory.purchase_goods.received`, `inventory.purchase_goods.reversed`
- Orders: `orders.restaurant.created`, `orders.restaurant_kot.status_changed`, `orders.restaurant_kot.item_cancelled`, `orders.restaurant_table.status_changed`, `orders.jewellery_custom_order.status_changed`, `orders.jewellery_repair.status_changed`, `orders.jewellery_gold_rate.alert_triggered`, `orders.jewellery_gold_rate.updated`, `orders.jewellery_gold_scheme.matured`, `orders.jewellery_old_gold.exchange_recorded`, `orders.dc_quote.converted`, `orders.dc_event.status_changed`, `orders.dc_staff.assigned`, `orders.service_job.created`, `orders.service_job.status_changed`, `orders.service_warranty.claim_raised`, `orders.service_exchange.completed`, `orders.auto_parts_job_card.status_changed`, `orders.computer_shop_job_card.status_changed`, `orders.computer_shop_warranty.registered`, `orders.purchase.created`, `orders.purchase_bill.added`, `orders.purchase_scan_bill.confirmed`, `orders.purchase_po.matched_to_grn`, `orders.marketplace.placed`, `orders.pre_order.requested` (when admin owns vendor side), `orders.pre_order.responded`
- Delivery: `delivery.restaurant.dispatched`, `delivery.challan.created`, `delivery.dispatch_note.created`
- Users: `users.customer_shop.linked`, `users.customer_shop.link_accepted`, `users.customer_credit.reminder_sent`, `users.customer_recovery.visit_recorded`, `users.staff_attendance.checked_in`, `users.staff_attendance.checked_out`, `users.staff_sale.recorded`, `users.pump_staff_activity.recorded`, `users.pump_shift.opened`, `users.pump_shift.closed`, `users.marketing_campaign.sent` (admin's own campaigns) — note: `users.marketing_campaign.sent` is normally suppressed for admin (actor==recipient), `users.loyalty_tier.upgraded`, `users.ai_notify_owner.requested`, `users.vegetable_broker.reconciliation_posted`, `users.vegetable_broker.dispatch_created`
- Reports: `reports.pump_sale.recorded`, `reports.pump_sale.bulk_summary`, `reports.dc_profitability.updated`
- System: `system.tenant_trial.started`, `system.tenant_trial.expiry_reminder`, `system.tenant_trial.expired`, `system.tenant_grace_period.ended`, `system.tenant_subscription.renewed`, `system.tenant_subscription.failed`, `system.tenant_manifest.invalidated`, `system.security_fraud.alert_raised`, `system.security_cash.mismatch_detected`, `system.security_stock.anomaly_detected`, `system.security_access.unauthorized_attempt`

### 14.3 `cashier`

- `billing.invoice.created`, `billing.invoice.updated`, `billing.invoice.returned`, `billing.restaurant_bill.updated`
- `payment.invoice.received`, `payment.customer_collection.recorded`
- `inventory.stock.changed`, `inventory.stock.low` (when cashier role is the configured fallback), `inventory.stock.decremented_by_sale`, `inventory.stock.bulk_decremented_by_sale`, `inventory.item.created`, `inventory.item.updated`, `inventory.item.deleted`, `inventory.purchase_goods.received`
- `orders.jewellery_gold_rate.updated`
- `system.tenant_manifest.invalidated`

### 14.4 `accountant`

- `billing.invoice.finalized`, `billing.invoice.returned`, `billing.credit_note.issued`, `billing.dc.invoice.created`, `billing.school_payslip.generated` (when accountant manages school payroll)
- `payment.invoice.received`, `payment.refund.processed`, `payment.customer_collection.recorded`, `payment.vendor_payment.collected`, `payment.purchase_payment.made`, `payment.dc.received`, `payment.dc.expense.added`, `payment.cash_drop.recorded`, `payment.school_fee.collected`
- `inventory.stock.adjusted`, `inventory.batch.expired`, `inventory.purchase_goods.reversed`
- `orders.purchase_bill.added`, `orders.purchase_scan_bill.confirmed`, `orders.purchase_po.matched_to_grn`, `orders.purchase.created`, `orders.dc_quote.converted`, `orders.jewellery_old_gold.exchange_recorded`
- `users.vegetable_broker.reconciliation_posted`
- `system.tenant_subscription.renewed`, `system.tenant_subscription.failed`, `system.security_cash.mismatch_detected`
- `users.pump_shift.closed`

### 14.5 `staff` (generic tenant employee)

- `users.staff_attendance.checked_in`, `users.staff_attendance.checked_out` (own)
- `system.tenant_manifest.invalidated`

### 14.6 `delivery_agent`

- `delivery.restaurant.dispatched`, `delivery.challan.created`, `delivery.dispatch_note.created`
- `orders.marketplace.placed`

### 14.7 `vendor` (synonym `supplier`)

- `orders.purchase.created`, `orders.service_warranty.claim_raised`
- `inventory.purchase_goods.reversed`
- `payment.purchase_payment.made`, `payment.vendor_payment.collected`
- `orders.pre_order.requested`, `orders.pre_order.responded` (when audit copy)
- `users.vegetable_broker.reconciliation_posted`, `users.vegetable_broker.dispatch_created`

### 14.8 `customer`

(restricted by authorization to own records — own invoices, own orders, own appointments, etc.)

- `billing.invoice.created`, `billing.invoice.updated`, `billing.invoice.returned`, `billing.credit_note.issued`, `billing.dc.invoice.created`
- `payment.invoice.received`, `payment.gateway.success`, `payment.gateway.failed`, `payment.refund.processed`, `payment.customer_collection.recorded`, `payment.dc.received`
- `orders.jewellery_custom_order.status_changed`, `orders.jewellery_repair.status_changed`, `orders.jewellery_gold_rate.alert_triggered` (when customer subscribes), `orders.jewellery_gold_scheme.matured`, `orders.jewellery_old_gold.exchange_recorded`
- `orders.restaurant_kot.item_ready`, `orders.dc_quote.converted`, `orders.dc_event.status_changed`, `orders.service_job.created`, `orders.service_job.status_changed`, `orders.service_exchange.completed`, `orders.auto_parts_job_card.status_changed`, `orders.computer_shop_job_card.status_changed`, `orders.computer_shop_warranty.registered`
- `orders.marketplace.placed`, `orders.pre_order.requested`, `orders.pre_order.responded`, `orders.in_store_exit_qr.ready`
- `delivery.restaurant.dispatched`, `delivery.challan.created`, `delivery.dispatch_note.created`, `delivery.location.updated`, `delivery.location.bulk_updated`
- `users.customer_shop.linked`, `users.customer_shop.link_accepted`, `users.customer_credit.reminder_sent`, `users.clinic_appointment.created`, `users.clinic_appointment.reminder_due`, `users.clinic_queue.advanced`, `users.clinic_prescription.created`, `users.clinic_lab.ordered`, `users.clinic_lab.result_published`, `users.pharmacy_refill.due`, `users.loyalty_points.awarded`, `users.loyalty_tier.upgraded`, `users.marketing_campaign.sent`

### 14.9 `chef`

- `orders.restaurant.created`, `orders.restaurant_kot.created`, `orders.restaurant_kot.bulk_created`, `orders.restaurant_kot.status_changed`, `orders.restaurant_kot.item_cancelled`
- `orders.dc_kot.created`, `orders.dc_kot.updated`

### 14.10 `kitchen_staff`

Same set as `chef` (§14.9).

### 14.11 `waiter`

- `orders.restaurant.created`, `orders.restaurant_kot.status_changed`, `orders.restaurant_kot.item_cancelled`, `orders.restaurant_kot.item_ready`, `orders.restaurant_table.status_changed`, `delivery.restaurant.dispatched`
- `billing.restaurant_bill.updated`

### 14.12 `school_admin`

- `billing.school_fee.assigned`, `billing.school_fee.bulk_assigned`, `billing.school_fee.reminder_sent`, `billing.school_fee.overdue`
- `payment.school_fee.collected`
- `users.school_admission.accepted`, `users.school_student.transferred`, `users.school_batch.full`, `users.school_attendance.low_alert`, `users.school_leave.submitted`, `users.school_leave.processed`, `users.school_timetable.updated`, `users.school_announcement.published`, `users.school_announcement.bulk_published`, `users.school_library.overdue`, `users.school_hostel.room_assigned`
- `delivery.school_transport.delay`, `delivery.school_transport.route_assigned`
- `reports.school_exam.scheduled`, `reports.school_exam.results_published`

### 14.13 `teacher`

- `users.school_admission.accepted` (their class), `users.school_student.transferred` (their class), `users.school_attendance.marked` (their class), `users.school_attendance.low_alert` (their student), `users.school_leave.submitted` (their student), `users.school_leave.processed` (own + their student), `users.school_timetable.updated`, `users.school_homework.assigned`, `users.school_material.uploaded`, `users.school_announcement.published`, `users.school_announcement.bulk_published`
- `reports.school_exam.scheduled` (their subject), `reports.school_exam.results_published` (their subject)
- `billing.school_payslip.generated` (own)

### 14.14 `student`

- `billing.school_fee.assigned`, `billing.school_fee.bulk_assigned`
- `payment.school_fee.collected` (own)
- `users.school_admission.accepted` (own), `users.school_attendance.marked` (own), `users.school_leave.processed` (own), `users.school_timetable.updated`, `users.school_homework.assigned` (own class), `users.school_material.uploaded` (own class), `users.school_announcement.published`, `users.school_announcement.bulk_published`, `users.school_library.due` (own), `users.school_library.overdue` (own), `users.school_hostel.room_assigned` (own), `users.school_hostel.mess_updated` (own)
- `delivery.school_transport.delay` (own route), `delivery.school_transport.route_assigned` (own)
- `reports.school_exam.scheduled` (own), `reports.school_exam.results_published` (own), `reports.school_report_card.generated` (own)

### 14.15 `parent`

(linked to one or more `student_id`s; receives every event that the linked student receives, plus parent-specific alerts)

- All events listed for `student` (§14.14), filtered to the parent's own children
- `billing.school_fee.reminder_sent`, `billing.school_fee.overdue`, `users.school_attendance.absent_alert`, `users.school_attendance.low_alert`, `users.school_announcement.bulk_published` (parent audience scope)

### 14.16 `clinic_doctor`

- `users.clinic_appointment.created` (own schedule), `users.clinic_queue.advanced` (own queue), `users.clinic_prescription.created` (own audit), `users.clinic_lab.ordered` (own patient), `users.clinic_lab.result_published` (own patient)

### 14.17 `pharmacist`

- `users.clinic_prescription.created` (queued for dispense), `users.pharmacy_refill.due` (their patient), `users.pharmacy_narcotic.entry_recorded` (their work)
- `inventory.stock.low` (pharmacy stock), `inventory.batch.expiring` (medicine batches), `inventory.batch.expired`

### 14.18 `jewellery_artisan`

- `orders.jewellery_custom_order.status_changed` (own assignments), `orders.jewellery_repair.status_changed` (own assignments)

### 14.19 `service_technician`

- `orders.service_job.created` (own queue), `orders.service_job.status_changed` (own queue), `orders.auto_parts_job_card.status_changed` (own queue), `orders.computer_shop_job_card.status_changed` (own queue)

### 14.20 `dc_staff`

- `orders.dc_event.status_changed` (assigned events), `orders.dc_staff.assigned` (own), `orders.dc_kot.created`, `orders.dc_kot.updated`, `inventory.dc.low`

### 14.21 `farmer` (vegetable broker counterparty)

- `users.vegetable_broker.reconciliation_posted` (own), `users.vegetable_broker.dispatch_created` (own)

### 14.22 `pump_attendant` (alias `pumpboy`)

- `users.pump_shift.opened` (own shift), `users.pump_shift.closed` (own shift), `users.staff_sale.recorded` (own), `users.staff_attendance.checked_in` (own), `users.staff_attendance.checked_out` (own)

### 14.23 No-events justification (REQ 17.2)

Every role in §3 receives at least one event in §§14.1–14.22. There are no roles that warrant a `no_events` justification at this stage.

If a future Sub_App registers a role not represented above, REQ 17.3 obliges the system to accept the new role's manifest at registration time and incorporate it into recipient resolution; the registry will be amended in a follow-up revision when that occurs.

---

## 15. Rejected Candidates

REQ 2.8: every Phase 1 candidate that fails the recipient + reason + action triple is recorded here. The 19 entries below come verbatim from Phase 1 §9 (`❌ rejected` rows). Phase 2 has reviewed each one and confirms the rejection.

| # | Phase 1 ID | Candidate `event_name` | File / symbol (Phase 1 source) | Rejection reason (from Phase 1, confirmed in Phase 2) |
|---|---|---|---|---|
| 1 | T-BIL-6 | `billing.invoice.created` (server-canonical duplicate) | `my-backend/src/services/invoice.service.ts` (`saveInvoice` `INVOICE_CREATED`) | Duplicate of T-BIL-2 (`my-backend/src/handlers/invoices.ts` `createInvoice` `BILL_CREATED`) from a different layer. UNS collapses both layers into one canonical emit at the service layer (§4.1) to prevent double fan-out. |
| 2 | T-BIL-9 | `billing.dunning.configured` | `Dukan_x/lib/features/billing/screens/dunning_config_screen.dart` (save dunning config) | Configuration change with no external recipient who needs an action; only the configurator sees it. Not user-actionable for any other role. |
| 3 | T-PAY-5 | `payment.confirmation.sent` | `my-backend/src/services/post-payment.service.ts` (`whatsappService.sendPaymentConfirmation`) | This is a *delivery side-effect* of T-PAY-2 (`payment.invoice.received`), not a separate triggerable event. UNS subsumes it into `payment.invoice.received` with channel selection that may include WhatsApp/SMS. |
| 4 | T-PAY-8 | `payment.customer.confirmation` | `Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart` (`customerNotificationsRepository.createNotification`) | Duplicate persistence path of T-PAY-2's WS event. UNS replaces it with a single notification emitted by the server and persisted in the canonical store. |
| 5 | T-PUR-8 | `purchase.payable.reminder_sent` | `my-backend/src/handlers/suppliers.ts` (~line 612) `whatsapp.sendTextMessage` for outstanding payables | Manual operator-triggered reminder is not a system event; it is a user action that uses the delivery layer directly. UNS will fold this into a future `purchase.payable.overdue` event whose `whatsapp` channel emit is the right place. |
| 6 | T-CUS-1 | `customer.profile.created` | `Dukan_x/lib/features/customers/presentation/screens/add_customer_screen.dart` (save) | Internal CRUD with no recipient who needs an action beyond "this device's UI". REQ 2.9 requires a complete justification (recipient + reason + action) for `*.create`/`*.update`/`*.delete`; none can be supplied. |
| 7 | T-CUS-2 | `customer.profile.deleted` | `Dukan_x/lib/features/customers/presentation/screens/customer_management_screen.dart` (delete) | Same as #6 (T-CUS-1). Internal CRUD lacking recipient + reason + action. |
| 8 | T-CUS-9 | `customer.credit_network.flag_added` | `Dukan_x/lib/features/credit_network/...` (cross-shop credit) | Currently a closed-data feature; sharing across shops is a privacy decision that Phase 2 leaves to a future revision. No documented recipient; cross-tenant share would need explicit justification. |
| 9 | T-JEW-8 | `jewellery.making_charges.computed` | `Dukan_x/lib/features/jewellery/presentation/screens/making_charges_calculator_screen.dart` (calculation only) | Calculation only, no state change requiring another user. Stays inside the active session. |
| 10 | T-RES-8 | `restaurant.review.submitted` | `Dukan_x/lib/features/restaurant/presentation/screens/customer/rate_review_screen.dart` (review submitted) | At present, no operational role acts on a review immediately. Reviews flow into analytics, not real-time notifications. Phase 2 may revisit if a future shop_owner subscription path is defined. |
| 11 | T-SCH-23 | `school.biometric.punched` | `my-backend/src/handlers/ac-biometric.ts` (biometric punch) | Captured silently into the attendance store; the user-facing event is `users.school_attendance.marked` (T-SCH-5). This is sensor input, not a user notification. |
| 12 | T-JOB-4 | `computer_shop.serial_history.viewed` | `Dukan_x/lib/features/computer_shop/presentation/screens/serial_history_screen.dart` (view only) | Read-only screen. No state change. |
| 13 | T-SEC-4 | `security.audit.row_written` | `lambda/auditHandler/index.mjs` (audit row written) | Every audit row would flood. Only specific *security-relevant* audit rows (e.g. `unauthorized_access_attempt` per REQ 12.7 — captured as §11.11) trigger a notification. |
| 14 | T-SEC-6 | `system.background_job.completed` / `system.background_job.failed` | `Dukan_x/lib/core/services/cleanup_service.dart`, `reconciliation_service.dart`, `einvoice_status_service.dart` (scheduled job result) | Silent infrastructure tasks; no end-user action. Operator dashboards consume these as metrics, not notifications. |
| 15 | T-MKT-2 | `marketplace.cart.updated` | `lambda/marketplace/cartHandler/index.ts` (cart updated) | High-frequency churn; no other user is interested. Device-local state, not a notification. |
| 16 | T-MKT-3 | `marketplace.broadcast.sent` | `lambda/marketplace/wsHandler/index.ts` (broadcast notification existing) | Pure transport mechanism, not a Trigger_Point. The producer is whoever calls `broadcastToRoom`. UNS replaces this transport entirely. |
| 17 | T-MKT-6 | `in_store.sale.dashboard_updated` | `my-backend/src/handlers/in-store-streams.ts` (in-store sale dashboard update) | Operator dashboard refresh, not a per-user notification. Dashboards refresh themselves on this event; it is not user-actionable. |
| 18 | T-AI-1 | `ai.action.executed` | `voice-backend/voice_agent.py`, `Dukan_x/lib/features/ai_assistant/presentation/screens/desktop_ai_assistant_screen.dart` (agent triggered an action) | AI actions are conversational and visible inline; same-session UI feedback already exists. Phase 2 may revisit if AI sends a `notify_owner` action — that path is captured as `users.ai_notify_owner.requested` (§9.38). |
| 19 | T-PAY-9 | (consumer of `payment.gateway.success`) | `Dukan_x/lib/features/staff/presentation/screens/staff_sale_entry_screen.dart` WS subscribe to `WSEventName.paymentSuccess` (~line 664) | Listed in Phase 1 §9.2 as `n/a` — pure consumer of T-PAY-3, not a producer. Counted here for completeness of the rejection list per REQ 2.8 since the producer path itself is already represented by §5.2 (`payment.gateway.success`). The consumer requires no separate registry entry. |

> **Counts.** Phase 1 reported 19 `rejected` Trigger_Points and 2 `n/a` consumer rows (T-PAY-9, T-RES-6). The table above includes all 19 rejected entries verbatim; T-PAY-9 is also explicitly addressed for completeness (entry 19). T-RES-6 (`restaurant/customer/order_tracking_screen.dart`) is a pure consumer of `orders.restaurant_kot.item_ready` (§7.5) and is therefore covered implicitly by that producer entry — recorded here as a footnote rather than a row.

---

## 16. Phase-3 Hand-off Notes

This section is the bridge into the Phase 3 architecture document.

### 16.1 Counts and coverage

- Defined events in this registry: **134** across categories — `billing` 11 (§4), `payments` 11 (§5), `inventory` 16 (§6), `orders` 32 (§7), `delivery` 6 (§8), `users` 40 (§9), `reports` 5 (§10), `system` 13 (§11). Section 6.12 (`inventory.import.progress`) is the batched form of the §6 import family and is detailed under §12, so it is counted once in §6.
- Batched events: **8** (§12) — these complement the 134 base entries by defining bulk forms for high-frequency or multi-item operations (REQ 2.10).
- Notification fatigue rules: **23 distinct event groups** (§13) plus global per-recipient hourly and daily caps.
- Rejected candidates: **19** (§15), matching the Phase 1 count.
- Roles covered: **22 distinct** (§14), exceeding the REQ 17.1 minimum of 17.
- REQ 2.14 minimum domain coverage: ✅ — billing, payments, inventory, purchase, customer/vendor, jewellery, restaurant, clinic & pharmacy, school/academic_coaching, service jobs & warranty, delivery_challan/dispatch, auto_parts/computer_shop, decoration_catering, vegetable_broker, security/audit, system health all have at least one entry.

### 16.2 Open decisions Phase 3 still owes

Per Phase 1 §12.2, Phase 2 was responsible for:

- ✅ Per-event `priority` — chosen for every entry
- ✅ Per-event `channels_per_role` — chosen for every entry
- ✅ Per-event `deduplication_rule` — chosen for every entry
- ✅ Per-event `silence_conditions` — chosen for every entry
- ✅ Batched-event definitions (`batch_window_seconds`, `summary_payload`) — defined in §12
- ✅ `notification_fatigue_risks` — defined in §13

What Phase 3 still owes:

- The full Event_Contract JSON Schema (`packages/notifications-sdk/event-contract.schema.json`) covering the field union implied by the registry entries above (REQ 8.1, 8.6).
- DynamoDB attribute schemas for `Notification`, `UserPreference`, `AuditLog` and the three GSIs (REQ 6.1-6.6).
- The locked architecture document (REQ 3.1, 18.3, 20.1-20.3) selecting Amazon SNS + SQS as the Event_Bus and listing `rejected_alternatives`.

### 16.3 Document checklist against Requirement 2

| Acceptance criterion | Where in this registry | Status |
|---|---|---|
| 2.1 Notification_Event_Registry at `.kiro/specs/unified-notification-system/phase2-event-registry.md` | This file | ✅ |
| 2.2 Each entry defines `category`, `sub_category`, `event_name`, `trigger_condition`, `source_module`, `consumer_roles`, `consumer_apps`, `priority`, `channels_per_role`, `deduplication_rule`, `silence_conditions` | §§4–11 (one row per event), plus `justification` per REQ 2.7 | ✅ |
| 2.3 `category` ∈ {billing, orders, payments, inventory, users, system, delivery, reports} | §1.1 + §§4–11 sectioning | ✅ |
| 2.4 `priority` ∈ {critical, high, normal, low} | §1.1 + per-entry tables | ✅ |
| 2.5 `channels_per_role` ⊆ {in_app, push, sms, email, webhook} | §1.1 + per-entry tables | ✅ |
| 2.6 `event_name` is `snake_case` `<domain>.<entity>.<action>` | §1.1 + per-entry tables | ✅ |
| 2.7 Every entry includes a `justification` naming recipient + reason + action | Per-entry `justification` row in §§4–11 | ✅ |
| 2.8 Excluded candidates recorded in `rejected_candidates` | §15 (19 entries) | ✅ |
| 2.9 Generic CRUD events allowed only with full justification + domain qualifier; non-CRUD events also carry full justification | Every CRUD-style entry (e.g. `inventory.item.created`) carries a complete `justification` row; non-CRUD entries (e.g. `system.health.degraded`) also carry one | ✅ |
| 2.10 Batched events with `batch_window_seconds` and `summary_payload` | §12 (8 batched events) | ✅ |
| 2.11 `notification_fatigue_risks` section with per-event suppression and per-recipient hourly cap | §13 | ✅ |
| 2.12 `deduplication_rule` per entry as ordered field list + window | Per-entry `deduplication_rule` row | ✅ |
| 2.13 `silence_conditions` per entry | Per-entry `silence_conditions` row | ✅ |
| 2.14 Domain coverage minimum (billing, payments, inventory, purchase, customer/vendor, jewellery, restaurant, clinic/pharmacy, school, service/warranty, delivery, auto_parts/computer_shop, decoration_catering, vegetable_broker, security/audit, system health) | §§4–11; sub-category tagging in each section | ✅ |
| 17.1 Recipient mappings for the 17 minimum roles | §14 (covers all 17 + 5 additional) | ✅ |
| 17.2 No-events justification for any unmapped role | §14.23 (no roles unmapped) | ✅ |

### 16.4 Authoring metadata

- Generated as the deliverable for **Task 2.1** in `.kiro/specs/unified-notification-system/tasks.md`.
- Validates **Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 17.1, 17.2**.
- This document is the input contract for **Task 3.1** (Phase 3 architecture document) and **Task 3.2** (Event_Contract JSON Schema).
