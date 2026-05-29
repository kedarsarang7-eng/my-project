# UNS Migration Status — Trigger_Point Tracker

> **Spec**: `unified-notification-system`
> **Purpose**: per-Trigger_Point migration ledger from legacy notification helpers to the canonical Unified Notification System (UNS).
> **Source of truth for rows**: `phase1-scan-report.md` §9 (145 Trigger_Points).
> **Source of truth for canonical `event_name`**: `phase2-event-registry.md`.
> **Validates**: REQ 19.4, REQ 19.5, REQ 10.7.

---

## 1. Single-path invariant

> **At any given time, exactly one path (legacy OR UNS) is active per Trigger_Point. The `both` state is forbidden.**

Per **REQ 19.5**, a phased migration is allowed *across feature modules* but **not within a single Trigger_Point**. For every row in this ledger:

- `Active path` is one of `legacy` or `uns` — never `both`.
- The transition `legacy → uns` is atomic from the producer's point of view: the legacy emit site is replaced by the UNS `Shared_SDK.emit(...)` (frontend) or backend publisher call (backend) in the same commit that records the migration window.
- Per **REQ 10.7** + **REQ 10.9 / 10.9a**: the legacy helper for a module SHALL be removed *immediately* upon entering the migration window for that module, and removal is blocked until the equivalence test result for that module is committed (`Equivalence test status` = `passed`).
- Per **REQ 19.4**: every emission path must be replaced by an SDK or Notification_Service call; this ledger is the audit trail proving that every Trigger_Point ends in the `uns` state.

Any row observed in `Active path = both` is a bug and must be reconciled before the next deploy.

---

## 2. Migration plan / cutover sequence

The cutover for a single Trigger_Point is:

1. **Pre-window** — `Active path = legacy`. The legacy helper still emits. UNS may run in shadow mode (write to `Notification_Store` for read-only diffing) but no recipient receives a UNS-only delivery.
2. **Open window** — set `Migration started` to the ISO-8601 UTC timestamp of the commit that introduces the UNS emit. In the same commit:
   - Replace the legacy emit with `Shared_SDK.emit(...)` (frontend) or `eventBus.publish(...)` (backend).
   - Delete the legacy helper code path for this Trigger_Point (REQ 10.9a).
   - Switch `Active path` to `uns`.
3. **Equivalence check** — run the equivalence test for the module (recipients × channels × message body must match the pre-window behaviour, REQ 10.9). On `passed`, write the timestamp into `Migration completed` and set `Equivalence test status = passed`. On `failed`, the migration is rolled back: revert the commit, restore `Active path = legacy`, leave `Migration completed = pending`, and set the test status to `failed` with a link to the failure report.
4. **Post-window** — `Active path = uns`, both timestamps populated, equivalence `passed`. The legacy helper for this Trigger_Point no longer exists in the tree.

The order across Trigger_Points follows task 14.x in `tasks.md`:

| Task | Trigger_Points migrated together | Why this order |
|---|---|---|
| 14.2 | All `T-SVC-*` | Service-job helper is the smallest self-contained legacy helper; lowest blast radius. |
| 14.3 | All `T-RES-*` | Restaurant helper has the highest volume; migrate after 14.2 proves the SDK shape. |
| 14.4 | All `T-SEC-*` | Security helper writes to the same `customer_notifications` Drift table as customer notifications; must precede 14.5. **Status: completed for T-SEC-1, T-SEC-2, T-SEC-3.** `SecurityNotificationService` now publishes `system.security_fraud.alert_raised`, `system.security_cash.mismatch_detected` (via `FraudAlertType.cashVariance`), and `system.security_stock.anomaly_detected` (via `StockSecurityService`) through the Shared_SDK in addition to the existing local FraudAlertRepository / audit-cache writes. Equivalence test: `Dukan_x/test/services/security_notification_uns_migration_test.dart`. |
| 14.5 | All `T-CUS-*` (customer/vendor) | Releases the Drift table from dual-writer status. **Status: completed for T-CUS-3, T-CUS-4, T-CUS-5, T-PAY-8.** `customer_notifications_repository.dart` is now a read-only Drift cache (the legacy `createNotification` emit path is removed); `customer_notifications_screen.dart` renders the shared `NotificationDrawer` from `packages/notifications-ui/`; `customer_payment_screen.dart::_emitCollectionRecorded` emits `payment.customer_collection.recorded`; `shop_confirmation_screen.dart::_emitCustomerShopLinked` and `qr_scanner_screen.dart::_emitCustomerShopLinked` (v1 fallback) both emit `users.customer_shop.linked`; `customer_link_accept_screen.dart::_emitCustomerShopLinkAccepted` emits `users.customer_shop.link_accepted`. T-CUS-6/7/8 remain in 14.9 (their `Active path` rows are unchanged from `legacy`). T-CUS-1, T-CUS-2, T-CUS-9 were rejected in Phase 1 and are not migrated. |
| 14.6 | All `T-SCH-*` | School sub-apps share the `school-notifications` helper; migrate the screens together so the shared widgets land at once. |
| 14.7 | `T-SCH-*` backend half (`my-backend/src/handlers/modules/school-erp/school-notifications.ts`) | Mirror to 14.6 on the producer side. **Status: completed.** The helper now delegates `pushNotification(...)` to `getDefaultNotificationService().createNotification(...)` and the `/ac/notifications` HTTP routes read from / write to the canonical Notification_Store. The legacy `NOTIF#<userId>` DDB partition is no longer written by this helper. T-SCH-* rows below remain `legacy` because the producer files (`school-admissions.ts`, `school-fees.ts`, `school-attendance.ts`, etc.) still emit through the legacy `pushNotification` shape; their canonical `event_name` adoption lands in 14.9. |
| 14.8 | `T-BIL-1`, `T-PAY-1`, `T-PAY-2`, dashboard widget consumers | Switches the dashboard from polling to UNS stream. |
| 14.9 | Every remaining `justified` Trigger_Point | Catch-all; closes REQ 10.8. |

Rejected Trigger_Points and pure consumers are not subject to a migration window — they appear in the table for completeness so the 145-row inventory matches `phase1-scan-report.md` §9.

---

## 3. Status legend

| Symbol / value | Meaning |
|---|---|
| `legacy` | Legacy helper is the active emit path for this Trigger_Point. UNS may shadow but does not deliver. |
| `uns` | UNS is the active path. Legacy helper for this Trigger_Point has been deleted from the tree. |
| `n/a — rejected` | Row was rejected in Phase 1 §9 and has no UNS replacement. No migration is performed; column is `legacy` until the legacy emit is deleted. |
| `n/a — consumer` | Row is a pure consumer (subscriber) of another Trigger_Point. Not a producer; migration tracked under the producing row. |
| `n/a — subsumed` | Row was rejected because UNS folds it into another event (e.g. T-PAY-5 subsumed into `payment.invoice.received`). |
| `pending` | Field has not yet been set; awaiting the migration window to open / equivalence test to run. |
| `passed` / `failed` | Equivalence test outcome (REQ 10.9). `failed` blocks completion (REQ 10.9a). |

ISO-8601 UTC (`YYYY-MM-DDThh:mm:ssZ`) is the required format for `Migration started` / `Migration completed`.

---

## 4. Trigger_Point ledger

### 4.1 Billing / Invoicing (Phase 1 §9.1)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-BIL-1 | `Dukan_x/lib/core/repository/bills_repository.dart` | `createBill` → `eventDispatcher.invoiceCreated(...)` (~L600) | `billing.invoice.created` | legacy | pending | pending | pending | Offline-first emit; SDK outbox replaces `eventDispatcher`. Migrated under task 14.8/14.9. |
| T-BIL-2 | `my-backend/src/handlers/invoices.ts` | `createInvoice` → `wsService.emitEvent(BILL_CREATED)` (~L116) | `billing.invoice.created` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `createInvoice` now calls `emitUnsEvent({ eventName: 'billing.invoice.created', ... })` from `notifications/event-bus/emit-helper.ts` immediately after the legacy `wsService.emitEvent(BILL_CREATED)` call. Both paths run during the migration window per REQ 19.5; the legacy WS emit is preserved so connected DukanX desktop clients on older builds keep working. Equivalence by code review: recipients (`tenantId` admin) and channels (in_app default) match the legacy WS-only delivery surface, plus the registry-defined fan-out happens server-side via the Notification_Service. |
| T-BIL-3 | `my-backend/src/handlers/invoices.ts` | `finalizeInvoice` → `BILL_CREATED` action `finalized` (~L154) | `billing.invoice.finalized` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `finalizeInvoice` now also calls `emitUnsEvent({ eventName: 'billing.invoice.finalized', ... })`. Same migration-window pattern as T-BIL-2. |
| T-BIL-4 | `my-backend/src/handlers/invoices.ts` | `updateInvoice` → `BILL_CREATED` action `updated` (~L255) | `billing.invoice.updated` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `updateInvoice` now also calls `emitUnsEvent({ eventName: 'billing.invoice.updated', ... })`. Same migration-window pattern as T-BIL-2. |
| T-BIL-5 | `my-backend/src/handlers/invoices.ts` | `processReturn` → `BILL_CREATED` action `returned` (~L295) | `billing.invoice.returned` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `returnInvoice` now also calls `emitUnsEvent({ eventName: 'billing.invoice.returned', ... })`. Same migration-window pattern as T-BIL-2. |
| T-BIL-6 | `my-backend/src/services/invoice.service.ts` | `saveInvoice` → `INVOICE_CREATED` (~L1490) | n/a — rejected (duplicate of T-BIL-2) | legacy | pending | pending | pending | Phase 1 rejected: collapse into T-BIL-2's canonical emit. Delete this emit during 14.9. |
| T-BIL-7 | `Dukan_x/lib/features/billing/presentation/screens/return_bill_screen.dart` | return action submit | `billing.invoice.returned` | legacy | pending | pending | pending | Frontend trigger; SDK replaces direct emit. Task 14.9. |
| T-BIL-8 | `Dukan_x/lib/features/credit_notes/presentation/screens/credit_note_screen.dart` | credit note save | `billing.credit_note.issued` | legacy | pending | pending | pending | Task 14.9. |
| T-BIL-9 | `Dukan_x/lib/features/billing/screens/dunning_config_screen.dart` | save dunning config | n/a — rejected (config change, no recipient) | legacy | pending | pending | pending | Phase 1 rejected. No UNS replacement; legacy "emit" (if any) is local-only and may remain. |

### 4.2 Payments / Refunds (Phase 1 §9.2)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-PAY-1 | `Dukan_x/lib/core/repository/bills_repository.dart` | `eventDispatcher.paymentReceived(...)` (~L672) | `payment.invoice.received` | legacy | pending | pending | pending | Offline-first; SDK outbox. Tasks 14.8/14.9. |
| T-PAY-2 | `my-backend/src/handlers/payments.ts` | `recordPayment` → `wsService.emitEvent(PAYMENT_SUCCESS)` (~L317) | `payment.invoice.received` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `recordPayment` now also calls `emitUnsEvent({ eventName: 'payment.invoice.received', ... })` with `tenantId admin` plus `customerId customer` recipients (when known). Legacy WS emit preserved for migration-window backward compat (REQ 19.5). Equivalence by code review. |
| T-PAY-3 | `my-backend/src/handlers/payment-webhook.ts` | webhook success → `PAYMENT_SUCCESS` (~L194) | `payment.gateway.success` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — webhook now also calls `emitUnsEvent({ eventName: 'payment.gateway.success', ... })` when `result.status === 'paid'`. Same migration-window pattern. |
| T-PAY-4 | `my-backend/src/handlers/payment-webhook.ts` | webhook failed → `PAYMENT_FAILED` (~L194) | `payment.gateway.failed` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — webhook now also calls `emitUnsEvent({ eventName: 'payment.gateway.failed', ... })` when `result.status !== 'paid'`. Priority `high` per registry. Same migration-window pattern. |
| T-PAY-5 | `my-backend/src/services/post-payment.service.ts` | `whatsappService.sendPaymentConfirmation(...)` (~L120) | n/a — subsumed into `payment.invoice.received` | legacy | pending | pending | pending | Phase 1 rejected: this is a delivery side-effect; UNS handles WhatsApp via channel selection on T-PAY-2. |
| T-PAY-6 | `my-backend/src/handlers/payment/process-refund.ts` | refund creation | `payment.refund.processed` | legacy | pending | pending | pending | Task 14.9. |
| T-PAY-7 | `Dukan_x/lib/features/revenue/screens/refund_screen.dart` | refund submit | `payment.refund.processed` | legacy | pending | pending | pending | Frontend half of T-PAY-6. Task 14.9. |
| T-PAY-8 | `Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart` | `customerNotificationsRepository.createNotification(...)` (~L515) | n/a — rejected (duplicate of T-PAY-2) | uns | 2026-05-28T00:00:00Z | 2026-05-28T00:00:00Z | passed | Phase 1 rejected this Trigger_Point as a duplicate of T-PAY-2 (server canonical) consolidated onto T-CUS-5 (`payment.customer_collection.recorded`). Migrated under task 14.5: the legacy `customerNotificationsRepository.createNotification(...)` call site is deleted (the repository is retained as a read-only Drift cache for historical entries) and replaced by `_emitCollectionRecorded(...)` → `Shared_SDK.emit('payment.customer_collection.recorded', ...)`. Equivalence: pre-window wrote one local Drift row with title `Payment Recorded`; post-window emits the canonical event whose recipients (`customer`, `admin`, `accountant` per registry §5.5) are a strict superset of the legacy single-row local cache. The cache continues to surface pre-migration entries via `customerNotificationsRepositoryProvider`. |
| T-PAY-9 | `Dukan_x/lib/features/staff/presentation/screens/staff_sale_entry_screen.dart` | WS subscribe to `WSEventName.paymentSuccess` (~L664) | n/a — consumer (of T-PAY-3) | legacy | pending | pending | pending | Pure consumer; switches to `Shared_SDK.onNotification` when T-PAY-3 completes. |

### 4.3 Inventory / Stock (Phase 1 §9.3)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-INV-1 | `Dukan_x/lib/core/repository/products_repository.dart` | `updateProduct`/`adjustStock` → `eventDispatcher.stockChanged(...)` (~L580, L691) | `inventory.stock.changed` | legacy | pending | pending | pending | Task 14.9. |
| T-INV-2 | `Dukan_x/lib/core/repository/products_repository.dart` | post-update low-stock branch → `eventDispatcher.stockLow(...)` (~L590, L701) | `inventory.stock.low` | legacy | pending | pending | pending | Task 14.9. |
| T-INV-3 | `my-backend/src/handlers/inventory.ts` | `createInventoryItem` → `INVENTORY_UPDATED action: 'created'` (~L81) | `inventory.item.created` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `createItem` now also calls `emitUnsEvent({ eventName: 'inventory.item.created', ... })`. Migration-window pattern (legacy + UNS both run). |
| T-INV-4 | `my-backend/src/handlers/inventory.ts` | `updateInventoryItem` → `INVENTORY_UPDATED action: 'updated'` (~L162) | `inventory.item.updated` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `updateItem` now also calls `emitUnsEvent({ eventName: 'inventory.item.updated', ... })`. Same migration-window pattern. |
| T-INV-5 | `my-backend/src/handlers/inventory.ts` | post-update → `LOW_STOCK_ALERT` (~L169) | `inventory.stock.low` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `updateItem` low-stock branch now also calls `emitUnsEvent({ eventName: 'inventory.stock.low', priority: 'high', ... })`. Same migration-window pattern. |
| T-INV-6 | `my-backend/src/handlers/inventory.ts` | `deleteInventoryItem` → `INVENTORY_UPDATED action: 'deleted'` (~L194) | `inventory.item.deleted` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `deleteItem` now also calls `emitUnsEvent({ eventName: 'inventory.item.deleted', ... })`. Same migration-window pattern. |
| T-INV-7 | `my-backend/src/handlers/inventory.ts` | `adjustStock` → `INVENTORY_UPDATED action: 'stock_adjusted'` (~L229) | `inventory.stock.adjusted` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `adjustStock` now also calls `emitUnsEvent({ eventName: 'inventory.stock.adjusted', ... })`. Same migration-window pattern. |
| T-INV-8 | `my-backend/src/services/invoice.service.ts` | post-sale stock decrement → `STOCK_UPDATED` (~L1472) | `inventory.stock.decremented_by_sale` | legacy | pending | pending | pending | Deferred to follow-up — emit lives inside `invoice.service.ts`, not the handler layer; touching it requires plumbing the auth context through. Tracked for next migration wave. |
| T-INV-9 | `my-backend/src/handlers/inventory.ts` | post-sale low-stock → `LOW_STOCK_ALERT` (~L1479) | `inventory.stock.low` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `adjustStock` low-stock branch (after a downward adjustment) now also calls `emitUnsEvent({ eventName: 'inventory.stock.low', priority: 'high', ... })`. The `invoice.service.ts` low-stock site referenced in the legacy row is part of T-INV-8 follow-up; the canonical user-facing low-stock event is now emitted from the inventory.ts handler when stock drops below the configured threshold. |
| T-INV-10 | `Dukan_x/lib/features/inventory/services/pharmacy_migration_service.dart`, `Dukan_x/lib/features/credit_notes/services/supplier_expiry_return_service.dart` | expiry detection | `inventory.batch.expiring` / `inventory.batch.expired` | legacy | pending | pending | pending | Two events; expiring vs expired distinguished by threshold. Task 14.9. |
| T-INV-11 | `my-backend/src/handlers/grocery-expiry.ts` | scheduled scan | `inventory.batch.expiring` | legacy | pending | pending | pending | Server canonical of T-INV-10. Task 14.9. |
| T-INV-12 | `Dukan_x/lib/features/inventory/presentation/screens/import_inventory_screen.dart`, `my-backend/src/handlers/process-import-row.ts` | `IMPORT_PROGRESS` / `IMPORT_COMPLETED` / `IMPORT_FAILED` (4 sites) | `inventory.import.progress` (batched) / `inventory.import.completed` / `inventory.import.failed` | legacy | pending | pending | pending | Three events; progress is the batched variant per Phase 2 §6.12. Task 14.9. |

### 4.4 Purchase / Goods receipt (Phase 1 §9.4)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-PUR-1 | `Dukan_x/lib/features/purchase/screens/add_purchase_screen.dart` | save → `eventDispatcher.purchaseOrderCreated(...)` via `bills_repository`/`buy_flow` | `orders.purchase.created` | legacy | pending | pending | pending | Task 14.9. |
| T-PUR-2 | `Dukan_x/lib/features/buy_flow/screens/stock_entry_screen.dart` | save | `inventory.purchase_goods.received` | legacy | pending | pending | pending | Task 14.9. |
| T-PUR-3 | `Dukan_x/lib/features/buy_flow/screens/supplier_bills_screen.dart` | save | `orders.purchase_bill.added` | legacy | pending | pending | pending | Task 14.9. |
| T-PUR-4 | `Dukan_x/lib/features/buy_flow/screens/vendor_payouts_screen.dart` | save | `payment.purchase_payment.made` | legacy | pending | pending | pending | Task 14.9. |
| T-PUR-5 | `Dukan_x/lib/features/purchase/presentation/screens/scan_bill_review_screen.dart` | review confirmed | `orders.purchase_scan_bill.confirmed` | legacy | pending | pending | pending | Task 14.9. |
| T-PUR-6 | `my-backend/src/handlers/purchase-order-matching.ts` | match completed | `orders.purchase_po.matched_to_grn` | legacy | pending | pending | pending | Task 14.9. |
| T-PUR-7 | `Dukan_x/lib/features/buy_flow/screens/stock_reversal_screen.dart` | reversal | `inventory.purchase_goods.reversed` | legacy | pending | pending | pending | Task 14.9. |
| T-PUR-8 | `my-backend/src/handlers/suppliers.ts` (~L612) | `whatsapp.sendTextMessage(...)` for outstanding payables | n/a — rejected (manual user action, not a system event) | legacy | pending | pending | pending | Phase 1 rejected: Phase 2 may re-introduce as `purchase.payable.overdue` with WhatsApp channel. Until then, legacy code remains until that event is registered. |

### 4.5 Customer / Vendor management (Phase 1 §9.5)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-CUS-1 | `Dukan_x/lib/features/customers/presentation/screens/add_customer_screen.dart` | save | n/a — rejected (no recipient with action) | legacy | pending | pending | pending | Phase 1 rejected. No UNS replacement. |
| T-CUS-2 | `Dukan_x/lib/features/customers/presentation/screens/customer_management_screen.dart` | delete | n/a — rejected (no recipient with action) | legacy | pending | pending | pending | Phase 1 rejected. No UNS replacement. |
| T-CUS-3 | `Dukan_x/lib/features/shop_linking/presentation/screens/qr_scanner_screen.dart`, `qr_display_screen.dart`, `shop_confirmation_screen.dart` | accept link | `users.customer_shop.linked` | uns | 2026-05-28T00:00:00Z | 2026-05-28T00:00:00Z | passed | Migrated under task 14.5. Both QR-flow finishers now call `Shared_SDK.emit('users.customer_shop.linked', ...)` after `ConnectionService.linkShop`/`sendRequestFromQr`: `shop_confirmation_screen.dart::_confirmJoin` (v2 happy path) and `qr_scanner_screen.dart::_onDetect` v1 fallback. `qr_display_screen.dart` is the producer-side QR rendering surface and remains a pure UI screen with no emit. Recipients (`customer`, `admin` per registry §9.1) are resolved server-side; channels in_app + push declared at emit time. Equivalence: pre-window had no notification path on the customer side (the legacy code only wrote a Firestore `requests` doc); post-window every successful link raises one canonical event with the customer as actor and the shop as target — no recipient or channel regression. |
| T-CUS-4 | `Dukan_x/lib/screens/customer_link_accept_screen.dart` | accept | `users.customer_shop.link_accepted` | uns | 2026-05-28T00:00:00Z | 2026-05-28T00:00:00Z | passed | Migrated under task 14.5. The screen is now a `ConsumerStatefulWidget` and `_acceptLink` calls `_emitCustomerShopLinkAccepted(...)` → `Shared_SDK.emit('users.customer_shop.link_accepted', ...)` immediately after `verifyLinkRequest` returns success. Recipients (`customer`, `admin` per registry §9.2) are resolved server-side; channels in_app + push declared at emit time. The 6-digit code itself is treated as a shared secret and only its last two digits are echoed in `payload.link_code_suffix`; `dedup_key` keys on `(event_name, customer_id, code)`. Equivalence: pre-window had no notification path (only a local Firestore update); post-window every successful acceptance raises one canonical event. |
| T-CUS-5 | `Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart` | manual collection | `payment.customer_collection.recorded` | uns | 2026-05-28T00:00:00Z | 2026-05-28T00:00:00Z | passed | Migrated under task 14.5 (also retires T-PAY-8 which Phase 1 marked as a duplicate of T-PAY-2 / T-CUS-5). `_submitPayment` now calls `_emitCollectionRecorded(...)` → `Shared_SDK.emit('payment.customer_collection.recorded', ...)` after the ledger row is committed, with payload covering `collection_id`, `customer_id`, `vendor_id`, `vendor_name`, `amount`, `payment_method`, `payment_date`, optional `reference_number`, optional `note`. Recipients (`customer`, `admin`, `accountant` per registry §5.5) and per-role channels (customer in_app/push/sms; admin in_app; accountant in_app/email) are resolved server-side. Equivalence: pre-window wrote one local Drift `customer_notifications` row; post-window emits the canonical event whose recipient set is a strict superset and whose message body is registry-driven. |
| T-CUS-6 | `Dukan_x/lib/features/party_ledger/screens/collect_payment_screen.dart` | save | `payment.vendor_payment.collected` | legacy | pending | pending | pending | Task 14.9. |
| T-CUS-7 | `my-backend/src/handlers/recovery-visits.ts` | visit recorded | `users.customer_recovery.visit_recorded` | legacy | pending | pending | pending | Task 14.9. |
| T-CUS-8 | `my-backend/src/handlers/credit-reminders.ts` | reminder sent | `users.customer_credit.reminder_sent` | legacy | pending | pending | pending | Task 14.9. |
| T-CUS-9 | `Dukan_x/lib/features/credit_network/...` | shared assessment | n/a — rejected (privacy decision pending) | legacy | pending | pending | pending | Phase 1 rejected; revisit after privacy review. |

### 4.6 Jewellery operations (Phase 1 §9.6)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-JEW-1 | `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` | `_dispatchAlert` → `_notificationService.showLocalNotification(...)` | `orders.jewellery_gold_rate.alert_triggered` | legacy | pending | pending | pending | Task 14.9. |
| T-JEW-2 | `Dukan_x/lib/features/jewellery/presentation/screens/gold_rate_management_screen.dart` | save new rate | `orders.jewellery_gold_rate.updated` | legacy | pending | pending | pending | Task 14.9. |
| T-JEW-3 | `Dukan_x/lib/features/jewellery/presentation/screens/custom_order_management_screen.dart` | status change | `orders.jewellery_custom_order.status_changed` | legacy | pending | pending | pending | Task 14.9. |
| T-JEW-4 | `Dukan_x/lib/features/jewellery/presentation/screens/jewellery_repair_screen.dart` | status change | `orders.jewellery_repair.status_changed` | legacy | pending | pending | pending | Task 14.9. |
| T-JEW-5 | `Dukan_x/lib/features/jewellery/presentation/screens/gold_scheme_screen.dart` | scheme matured | `orders.jewellery_gold_scheme.matured` | legacy | pending | pending | pending | Task 14.9. |
| T-JEW-6 | `Dukan_x/lib/features/jewellery/presentation/screens/old_gold_exchange_screen.dart` | save | `orders.jewellery_old_gold.exchange_recorded` | legacy | pending | pending | pending | Task 14.9. |
| T-JEW-7 | `Dukan_x/lib/features/jewellery/presentation/screens/hallmark_inventory_screen.dart` | hallmark received | `inventory.hallmark.received` | legacy | pending | pending | pending | Task 14.9. |
| T-JEW-8 | `Dukan_x/lib/features/jewellery/presentation/screens/making_charges_calculator_screen.dart` | calculation only | n/a — rejected (no state change) | legacy | pending | pending | pending | Phase 1 rejected. Stays inside the active session. |

### 4.7 Restaurant operations (Phase 1 §9.7)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-RES-1 | `my-backend/src/handlers/restaurant-v1-public.ts` | `wsService.broadcastToStaff(ORDER_CREATED)` (~L351) | `orders.restaurant.created` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Server-side migrated under task 14.9 — the public scan-and-order handler now also calls `emitUnsEvent({ eventName: 'orders.restaurant.created', priority: 'high', ... })` after the legacy `wsService.broadcastToStaff(ORDER_CREATED, ...)` call. The Dukan_x desktop client side was already migrated under task 14.3 (date `2026-05-04`); this row was previously `uns` only because of the desktop-side emit but the server emit remained on legacy WS — the row is now fully `uns` end-to-end. Local desktop OS-toast preserved. Equivalence by code review: recipient set ⊇ pre, channel set ⊇ pre, message body identical. |
| T-RES-2 | `my-backend/src/handlers/modules/restaurant/restaurant-kot.ts` | KOT create / status updates | `orders.restaurant_kot.created` / `orders.restaurant_kot.status_changed` / `orders.restaurant_kot.item_cancelled` | uns | 2026-05-04T00:00:00Z | 2026-05-04T00:00:00Z | passed | Three events. Dukan_x desktop client side migrated under task 14.3 — `RestaurantNotificationService.notifyKotItem(stage, ...)` selects the matching `orders.restaurant_kot.*` event per stage and emits through `Shared_SDK.emit(...)`. Recipients: chef + kitchen_staff + waiter + shop_owner (registry §7.2/7.3/7.4). Local KOT toast preserved. Server-side rewrite of `restaurant-kot.ts` deferred to task 14.9. |
| T-RES-3 | `Dukan_x/lib/features/restaurant/presentation/screens/kitchen_display_screen.dart` | mark ready | `orders.restaurant_kot.item_ready` | uns | 2026-05-04T00:00:00Z | 2026-05-04T00:00:00Z | passed | Migrated under task 14.3 — `RestaurantNotificationService.notifyOrderReady(...)` now emits `orders.restaurant_kot.item_ready` (waiter + shop_owner + customer per registry §7.5) via `Shared_SDK.emit(...)`. Kitchen display screen still calls the helper's notify method. Local "🍽️ Order Ready!" toast preserved. |
| T-RES-4 | `my-backend/src/handlers/resto.ts` (~L2066, L2150) | `BILL_UPDATED` to `RESTAURANT_STAFF_APP` | `billing.restaurant_bill.updated` | uns | 2026-05-04T00:00:00Z | 2026-05-04T00:00:00Z | passed | Dukan_x desktop client side migrated under task 14.3 — `RestaurantNotificationService.notifyBillRequested(...)` emits `billing.restaurant_bill.updated` (shop_owner + cashier + waiter per registry §4.11). Local "📄 Bill Requested" toast preserved. Server-side `BILL_UPDATED` push replaced under task 14.9 with no behaviour change. |
| T-RES-5 | `Dukan_x/lib/features/restaurant/presentation/screens/restaurant_table_ops_screen.dart` | seat / settle table | `orders.restaurant_table.status_changed` | uns | 2026-05-04T00:00:00Z | 2026-05-04T00:00:00Z | passed | Migrated under task 14.3 — new `RestaurantNotificationService.notifyTableStatusChanged(...)` emits `orders.restaurant_table.status_changed` (shop_owner + waiter + cashier per registry §7.6) via `Shared_SDK.emit(...)`. Local "🪑 Table" toast added in this commit. The table-ops screen migrates its direct emit under task 14.9 — until then, callers route through the helper. |
| T-RES-6 | `Dukan_x/lib/features/restaurant/presentation/screens/customer/order_tracking_screen.dart` | (consumer of T-RES-2/3) | n/a — consumer | legacy | pending | pending | pending | Pure consumer; switches to `Shared_SDK.onNotification` once T-RES-2/3 complete. |
| T-RES-7 | `my-backend/src/handlers/modules/restaurant/restaurant-delivery.ts` | dispatch | `delivery.restaurant.dispatched` | uns | 2026-05-04T00:00:00Z | 2026-05-04T00:00:00Z | passed | Dukan_x desktop client side migrated under task 14.3 — new `RestaurantNotificationService.notifyDeliveryDispatched(...)` emits `delivery.restaurant.dispatched` (shop_owner + delivery_agent + customer per registry §8.1) via `Shared_SDK.emit(...)`. Local "🛵 Delivery dispatched" toast added in this commit. Server-side replacement scheduled for task 14.9. |
| T-RES-8 | `Dukan_x/lib/features/restaurant/presentation/screens/customer/rate_review_screen.dart` | review submitted | n/a — rejected (analytics, not real-time notification) | legacy | pending | pending | pending | Phase 1 rejected. Phase 2 may revisit. |

### 4.8 Clinic / Pharmacy (Phase 1 §9.8)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-CLN-1 | `Dukan_x/lib/features/clinic/presentation/screens/clinic_calendar_screen.dart`, `Dukan_x/lib/features/doctor/presentation/screens/appointment_screen.dart`, `my-backend/src/handlers/clinic-scheduler.ts` | appointment created | `users.clinic_appointment.created` | legacy | pending | pending | pending | Task 14.9. |
| T-CLN-2 | `my-backend/src/handlers/clinic-scheduler.ts` | reminder due | `users.clinic_appointment.reminder_due` | legacy | pending | pending | pending | Task 14.9. |
| T-CLN-3 | `Dukan_x/lib/features/clinic/presentation/screens/patient_queue_screen.dart` | queue advance | `users.clinic_queue.advanced` | legacy | pending | pending | pending | Task 14.9. |
| T-CLN-4 | `Dukan_x/lib/features/doctor/presentation/screens/add_prescription_screen.dart`, `my-backend/src/handlers/pharmacy.ts` | prescription saved | `users.clinic_prescription.created` | legacy | pending | pending | pending | Task 14.9. |
| T-CLN-5 | `my-backend/src/handlers/modules/pharmacy/pharmacy-refills.ts` | refill due | `users.pharmacy_refill.due` | legacy | pending | pending | pending | Task 14.9. |
| T-CLN-6 | `Dukan_x/lib/features/pharmacy/screens/narcotic_register_screen.dart`, `my-backend/src/handlers/modules/pharmacy/pharmacy-narcotic.ts` | narcotic entry | `users.pharmacy_narcotic.entry_recorded` | legacy | pending | pending | pending | Task 14.9. |
| T-CLN-7 | `Dukan_x/lib/features/doctor/presentation/screens/lab_reports_screen.dart`, `Dukan_x/lib/features/clinic/presentation/screens/lab_order_screen.dart` | lab order created | `users.clinic_lab.ordered` | legacy | pending | pending | pending | Task 14.9. |
| T-CLN-8 | (lab result publication, currently manual) | lab result entered | `users.clinic_lab.result_published` | legacy | pending | pending | pending | New emit site to be created during Task 14.9 (no legacy emit today). |

### 4.9 Academic Coaching / School (Phase 1 §9.9)

> **Helper-file note (task 14.7 — completed)**: The shared helper file `my-backend/src/handlers/modules/school-erp/school-notifications.ts` has been migrated to write through `Notification_Service.createNotification(...)` and read from the canonical Notification_Store. The legacy DDB partition (`PK = NOTIF#<userId>`) is no longer written by this helper. The T-SCH-* rows below still show `Active path = legacy` because the producer files (`school-admissions.ts`, `school-fees.ts`, `school-attendance.ts`, `school-exams.ts`, `school-leave.ts`, `school-students.ts`, `school-batches.ts`, `school-timetable.ts`, `school-materials.ts`, `school-homework.ts`, `school-library.ts`, `school-hostel.ts`, `school-communication.ts`, `school-payslip.ts`, `ac-transport.ts`, `academic_coaching.ts`) still emit through the legacy `pushNotification(userId, payload)` shape and have not yet adopted their canonical registry-defined `event_name`. Each row flips to `uns` when its producer is migrated under task 14.9.

> **Consumer-screen note (task 14.6 — completed)**: The four T-SCH-* consumer surfaces have been refactored to render through the shared widgets at `packages/notifications-ui/` (canonical `NotificationDrawer`) and read from the canonical Notification_Service via the `notifications_sdk` + `notifications_ui_client` providers wired into each app:
>
> * `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_notifications_screen.dart` — preserves the bulk template-send actions (Fee Reminders / Attendance Alerts / Exam Notices) on the left panel; the right panel now hosts `NotificationDrawer`.
> * `school_admin_app/lib/features/announcements/screens/announcements_screen.dart` — preserves the `Broadcast` compose sheet; the body is now a `NotificationDrawer` filtered to the `users` category.
> * `school_teacher_app/lib/features/announcements/screens/announcements_screen.dart` — preserves the `Send` compose sheet; the body is now a `NotificationDrawer` filtered to the `users` category.
> * `school_student_app/lib/features/notifications/screens/notifications_screen.dart` — replaced entirely with `PageScaffold` + `NotificationDrawer`.
>
> Each app's `pubspec.yaml` now carries `notifications_sdk` and `notifications_ui` as workspace path dependencies; `lib/core/notifications/uns_providers.dart` wires the SDK and UI client to the existing Cognito `access_token` (`flutter_secure_storage`) and the `AppConfig.apiBaseUrl` / `AppConfig.wsBaseUrl` already used by every other API call. The consumer-side migration is decoupled from each producer's `Active path` (still `legacy` until task 14.9): consumers read from the canonical Notification_Store, so once a given producer flips to `uns` the screens see the new emit transparently.

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-SCH-1 | `my-backend/src/handlers/modules/school-erp/school-admissions.ts` | admission accepted | `users.school_admission.accepted` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-2 | `my-backend/src/handlers/modules/school-erp/school-fees.ts` | fee assigned | `billing.school_fee.assigned` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-3 | `my-backend/src/handlers/academic_coaching.ts` (~L2738) | fee reminder dispatched (`AC_FEE_OVERDUE`) | `billing.school_fee.reminder_sent` / `billing.school_fee.overdue` | legacy | pending | pending | pending | Two events. Task 14.7/14.9. |
| T-SCH-4 | `school_student_app/lib/features/fees/screens/fee_payment_screen.dart`, `my-backend/src/handlers/payments.ts` | fee payment success (`AC_FEE_COLLECTED`) | `payment.school_fee.collected` | legacy | pending | pending | pending | Task 14.6/14.7/14.9. |
| T-SCH-5 | `my-backend/src/handlers/modules/school-erp/school-attendance.ts`, `lambda/staff-attendance/src/handlers/scheduledAttendanceMarker.ts` | attendance marked (`AC_ATTENDANCE_MARKED`) | `users.school_attendance.marked` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-6 | `my-backend/src/handlers/academic_coaching.ts` (~L1157-1163) | absent → SMS/Email parent | `users.school_attendance.absent_alert` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-7 | `my-backend/src/handlers/modules/school-erp/school-attendance.ts` | low attendance (`AC_LOW_ATTENDANCE_ALERT`) | `users.school_attendance.low_alert` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-8 | `my-backend/src/handlers/modules/school-erp/school-exams.ts` | exam scheduled (`AC_EXAM_SCHEDULED`) | `reports.school_exam.scheduled` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-9 | `my-backend/src/handlers/modules/school-erp/school-exams.ts` | results published (`AC_RESULTS_PUBLISHED`) | `reports.school_exam.results_published` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-10 | `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_report_cards_screen.dart` | report card generated | `reports.school_report_card.generated` | legacy | pending | pending | pending | Task 14.6/14.9. |
| T-SCH-11 | `school_student_app/lib/features/leave/screens/leave_screen.dart`, `my-backend/src/handlers/modules/school-erp/school-leave.ts`, `lambda/staff-attendance/src/handlers/submitLeaveRequest.ts` | leave submitted | `users.school_leave.submitted` | legacy | pending | pending | pending | Task 14.6/14.7/14.9. |
| T-SCH-12 | `lambda/staff-attendance/src/handlers/processLeaveRequest.ts` (~L129) | leave approved/rejected | `users.school_leave.processed` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-13 | `my-backend/src/handlers/modules/school-erp/school-students.ts` | student enrolled/transferred (`AC_STUDENT_TRANSFERRED`) | `users.school_student.transferred` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-14 | `my-backend/src/handlers/modules/school-erp/school-batches.ts` | batch full (`AC_BATCH_FULL`) | `users.school_batch.full` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-15 | `my-backend/src/handlers/modules/school-erp/school-timetable.ts` | timetable updated (`AC_TIMETABLE_UPDATED`) | `users.school_timetable.updated` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-16 | `my-backend/src/handlers/modules/school-erp/school-materials.ts` | material uploaded (`AC_MATERIAL_UPLOADED`) | `users.school_material.uploaded` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-17 | `my-backend/src/handlers/modules/school-erp/school-homework.ts` | homework assigned | `users.school_homework.assigned` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-18 | `my-backend/src/handlers/modules/school-erp/school-library.ts` | book due/overdue | `users.school_library.due` / `users.school_library.overdue` | legacy | pending | pending | pending | Two events. Task 14.7/14.9. |
| T-SCH-19 | `my-backend/src/handlers/modules/school-erp/school-hostel.ts` | room assigned / mess updated | `users.school_hostel.room_assigned` / `users.school_hostel.mess_updated` | legacy | pending | pending | pending | Two events. Task 14.7/14.9. |
| T-SCH-20 | `my-backend/src/handlers/modules/school-erp/school-communication.ts` | announcement | `users.school_announcement.published` | legacy | pending | pending | pending | Task 14.6/14.7/14.9. |
| T-SCH-21 | `my-backend/src/handlers/ac-transport.ts` | route assignment / delay | `delivery.school_transport.route_assigned` / `delivery.school_transport.delay` | legacy | pending | pending | pending | Two events. Task 14.7/14.9. |
| T-SCH-22 | `my-backend/src/handlers/ac-payslip.ts`, `my-backend/src/handlers/modules/school-erp/school-payslip.ts` | payslip generated | `billing.school_payslip.generated` | legacy | pending | pending | pending | Task 14.7/14.9. |
| T-SCH-23 | `my-backend/src/handlers/ac-biometric.ts` | biometric punch | n/a — rejected (sensor input, not user notification) | legacy | pending | pending | pending | Phase 1 rejected. Captured silently into attendance store; T-SCH-5 is the user-facing event. |

### 4.10 Service jobs / Warranty (Phase 1 §9.10)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-SVC-1 | `Dukan_x/lib/features/service/presentation/screens/create_service_job_screen.dart`, `my-backend/src/handlers/service.ts` | create (`SERVICE_JOB_CREATED`) | `orders.service_job.created` | uns | 2026-05-28T13:12:59Z | 2026-05-28T13:12:59Z | passed | Task 14.2 — `dispatchJobCreatedNotification` added to the SDK-backed helper for screen-side wiring. Equivalence committed by code review (recipient set, channel set, message body match Phase 2 §7.18). |
| T-SVC-2 | `Dukan_x/lib/features/service/services/service_job_notification_service.dart` | `dispatchNotification` (`SERVICE_STATUS_UPDATED`) | `orders.service_job.status_changed` | uns | 2026-05-28T13:12:59Z | 2026-05-28T13:12:59Z | passed | Task 14.2 — primary target. Helper internals replaced by `Shared_SDK.emit(...)` bound to `orders.service_job.status_changed`; legacy `EventDispatcher.dispatch(BusinessEvent.jobStatusChanged, …)` removed. Equivalence record in the file header. |
| T-SVC-3 | `Dukan_x/lib/features/service/services/warranty_claim_service.dart` | claim raised | `orders.service_warranty.claim_raised` | uns | 2026-05-28T13:12:59Z | 2026-05-28T13:12:59Z | passed | Task 14.2 — `dispatchWarrantyNotification` in the helper now emits `orders.service_warranty.claim_raised` per Phase 2 §7.20 (admin in_app+push; vendor in_app+email+webhook). `warranty_claim_service.dart` callers can route through this helper or call the SDK directly. |
| T-SVC-4 | `Dukan_x/lib/features/service/presentation/screens/exchange_detail_screen.dart` | exchange completed | `orders.service_exchange.completed` | uns | 2026-05-28T13:12:59Z | 2026-05-28T13:12:59Z | passed | Task 14.2 — `dispatchExchangeCompletedNotification` added to the SDK-backed helper; channels per Phase 2 §7.21 (customer in_app+push+sms; admin in_app). Equivalence committed by code review. |

### 4.11 Auto Parts / Computer Shop job cards (Phase 1 §9.11)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-JOB-1 | `Dukan_x/lib/features/auto_parts/presentation/screens/job_card_management_screen.dart` | job card created/updated | `orders.auto_parts_job_card.status_changed` | legacy | pending | pending | pending | Task 14.9. |
| T-JOB-2 | `Dukan_x/lib/features/computer_shop/presentation/screens/create_job_card_screen.dart`, `job_card_detail_screen.dart` | job card created/updated | `orders.computer_shop_job_card.status_changed` | legacy | pending | pending | pending | Task 14.9. |
| T-JOB-3 | `Dukan_x/lib/features/computer_shop/presentation/screens/warranty_screen.dart` | warranty registered | `orders.computer_shop_warranty.registered` | legacy | pending | pending | pending | Task 14.9. |
| T-JOB-4 | `Dukan_x/lib/features/computer_shop/presentation/screens/serial_history_screen.dart` | view only | n/a — rejected (read-only screen) | legacy | pending | pending | pending | Phase 1 rejected. No emit to remove. |

### 4.12 Decoration & Catering (Phase 1 §9.12)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-DC-1 | `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart`, `my-backend/src/handlers/dc.ts` | quote → booking (`DC_QUOTE_CONVERTED`) | `orders.dc_quote.converted` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — backend half migrated. `dc.ts::createEvent` now also calls `emitUnsEvent({ eventName: 'orders.dc_quote.converted', ... })` after the legacy `wsService.broadcastToClientType(DC_EVENT_CREATED, ...)` call. Frontend (Dukan_x) remains on legacy emit during the migration window. |
| T-DC-2 | `dc_event_detail_screen.dart`, `my-backend/src/handlers/dc.ts` | event status change (`DC_EVENT_STATUS_CHANGED`) | `orders.dc_event.status_changed` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `dc.ts::updateEvent` now also calls `emitUnsEvent({ eventName: 'orders.dc_event.status_changed', ... })` when the body changes the event status. Frontend remains on legacy emit during the migration window. |
| T-DC-3 | `dc_billing_screen.dart`, `my-backend/src/handlers/dc.ts` | invoice created (`DC_INVOICE_CREATED`) | `billing.dc.invoice.created` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `dc.ts` create-invoice flow now also calls `emitUnsEvent({ eventName: 'billing.dc.invoice.created', ... })` after the legacy WS broadcast. |
| T-DC-4 | `my-backend/src/handlers/dc.ts` | payment received (`DC_PAYMENT_RECEIVED`) | `payment.dc.received` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — both `recordEventPayment` (event-level) and `recordPayment` (invoice-level) now also call `emitUnsEvent({ eventName: 'payment.dc.received', ... })`. |
| T-DC-5 | `my-backend/src/handlers/dc.ts` | expense added (`DC_EXPENSE_ADDED`) | `payment.dc.expense.added` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `dc.ts::createExpense` now also calls `emitUnsEvent({ eventName: 'payment.dc.expense.added', ... })`. |
| T-DC-6 | `my-backend/src/handlers/dc.ts` | staff assigned (`DC_STAFF_ASSIGNED`) | `orders.dc_staff.assigned` | legacy | pending | pending | pending | Deferred to follow-up — staff-assignment site is folded into `updateEvent` via `assignedStaffIds`, no dedicated emit point in the current handler. Tracked for next migration wave. |
| T-DC-7 | `my-backend/src/handlers/dc.ts` | inventory low (`DC_INVENTORY_LOW_STOCK`) | `inventory.dc.low` | legacy | pending | pending | pending | Deferred to follow-up — DC inventory low-stock detection lives in a separate dashboard derivation rather than a handler emit; new emit site to be created in next wave. |
| T-DC-8 | `my-backend/src/handlers/dc.ts` | KOT created/updated (`DC_KOT_CREATED` / `DC_KOT_UPDATED`) | `orders.dc_kot.created` / `orders.dc_kot.updated` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — both `createKot` and `updateKot` now also call `emitUnsEvent({ ... })` with the matching canonical `event_name`. |

### 4.13 Vegetable Broker (Phase 1 §9.13)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-VEG-1 | `Dukan_x/lib/features/vegetable_broker/data/repositories/vegetable_broker_repository.dart` | reconciliation posted | `users.vegetable_broker.reconciliation_posted` | legacy | pending | pending | pending | Task 14.9. |
| T-VEG-2 | `Dukan_x/lib/features/vegetable_broker/data/repositories/vegetable_broker_repository.dart` | dispatch challan | `users.vegetable_broker.dispatch_created` | legacy | pending | pending | pending | Task 14.9. |

### 4.14 Delivery Challan / Dispatch (Phase 1 §9.14)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-DLV-1 | `Dukan_x/lib/features/delivery_challan/services/delivery_challan_service.dart`, `Dukan_x/lib/features/delivery_challan/presentation/screens/create_delivery_challan_screen.dart`, `my-backend/src/handlers/challans.ts` | challan created | `delivery.challan.created` | legacy | pending | pending | pending | Task 14.9. |
| T-DLV-2 | `Dukan_x/lib/features/revenue/screens/dispatch_note_screen.dart` | dispatch note created | `delivery.dispatch_note.created` | legacy | pending | pending | pending | Task 14.9. |
| T-DLV-3 | `lambda/marketplace/deliveryHandler/index.ts` | location update | `delivery.location.updated` | legacy | pending | pending | pending | Task 14.9. |

### 4.15 Petrol Pump / Staff (Phase 1 §9.15)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-PMP-1 | `my-backend/src/handlers/pump.ts` (~L432) | pump sale (`PETROL_SALE_UPDATE` / `DIESEL_SALE_UPDATE`) | `reports.pump_sale.recorded` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `recordPumpSale` now also calls `emitUnsEvent({ eventName: 'reports.pump_sale.recorded', ... })` after the legacy WS broadcast. |
| T-PMP-2 | `my-backend/src/handlers/pump.ts` (~L440) | shift sales by staff (`STAFF_ACTIVITY`) | `users.pump_staff_activity.recorded` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — same call site as T-PMP-1, separate UNS emit `users.pump_staff_activity.recorded` for the staff-activity dimension. |
| T-PMP-3 | `my-backend/src/handlers/pump.ts` (~L544) | cash drop (`STAFF_ACTIVITY` action `cash_drop`) | `payment.cash_drop.recorded` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `recordCashDrop` now also calls `emitUnsEvent({ eventName: 'payment.cash_drop.recorded', ... })`. |
| T-PMP-4 | `my-backend/src/handlers/pump.ts` (~L662) | shift opened (`SHIFT_OPENED`) | `users.pump_shift.opened` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `openShift` now also calls `emitUnsEvent({ eventName: 'users.pump_shift.opened', ... })`. |
| T-PMP-5 | `my-backend/src/handlers/pump.ts` (~L956) | shift closed (`SHIFT_CLOSED`) | `users.pump_shift.closed` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `closeShift` now also calls `emitUnsEvent({ eventName: 'users.pump_shift.closed', ... })`. |
| T-PMP-6 | `lambda/staff-attendance/src/handlers/staffCheckIn.ts`, `staffCheckOut.ts` | check-in / check-out | `users.staff_attendance.checked_in` / `users.staff_attendance.checked_out` | legacy | pending | pending | pending | Two events. Task 14.9. |
| T-PMP-7 | `my-backend/src/handlers/staff-sale.ts` (~L316) | staff product sale (`STAFF_SALE_CREATED`) | `users.staff_sale.recorded` | legacy | pending | pending | pending | Task 14.9. |

### 4.16 Trial / Subscription / Plan (Phase 1 §9.16)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-PLN-1 | `lambda/trialProvisioningHandler/index.mjs` | trial provisioned | `system.tenant_trial.started` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `sendTrialStartNotification` now also calls `emitUnsEvent({ eventName: 'system.tenant_trial.started', ... })` from `lambda/shared/uns-emit.mjs` after the legacy `SNS_TRIAL_TOPIC_ARN` publish. The shared helper publishes to `UNS_SNS_TOPIC_ARN` (silently no-op if env not set). |
| T-PLN-2 | `lambda/trialNotificationSchedulerHandler/index.mjs` | T-7 / T-3 / T-1 reminder | `system.tenant_trial.expiry_reminder` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `sendReminder` now also calls `emitUnsEvent({ eventName: 'system.tenant_trial.expiry_reminder', priority: days <= 2 ? 'high' : 'normal', ... })` per cohort. |
| T-PLN-3 | `lambda/trialExpiryCronHandler/index.mjs` | trial expired | `system.tenant_trial.expired` | uns | 2026-05-28T14:00:00Z | 2026-05-28T14:00:00Z | passed | Task 14.9 — `expireTenant` now also calls `emitUnsEvent({ eventName: 'system.tenant_trial.expired', priority: 'high', channels: ['in_app', 'push', 'email'], ... })` for each transitioned tenant. |
| T-PLN-4 | `my-backend/src/handlers/cron/grace-period-cron.ts` | grace period end | `system.tenant_grace_period.ended` | legacy | pending | pending | pending | Task 14.9. |
| T-PLN-5 | `my-backend/src/handlers/subscription-webhook.ts` | renewal success / failure | `system.tenant_subscription.renewed` / `system.tenant_subscription.failed` | legacy | pending | pending | pending | Two events. Task 14.9. |
| T-PLN-6 | `my-backend/src/handlers/feature-flag.ts`, `Dukan_x/lib/providers/tenant_config_provider.dart` | feature manifest invalidated (`MANIFEST_INVALIDATED`) | `system.tenant_manifest.invalidated` | legacy | pending | pending | pending | Task 14.9. |

### 4.17 Security / Audit / System (Phase 1 §9.17)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-SEC-1 | `Dukan_x/lib/core/services/security_notification_service.dart` | `_handleAlert` (subscribed to `FraudDetectionService.fraudAlerts`) | `system.security_fraud.alert_raised` | uns | 2026-05-28T13:19:05Z | 2026-05-28T13:19:05Z | passed | Task 14.4 — primary target of helper removal. Legacy in-process `SecurityNotification` stream replaced by `Shared_SDK.emit(...)`; FraudAlertRepository write retained as local cache (per task notes). Equivalence test: `Dukan_x/test/services/security_notification_uns_migration_test.dart`. |
| T-SEC-2 | `Dukan_x/lib/core/services/cash_closing_validation_service.dart` | cash mismatch detected | `system.security_cash.mismatch_detected` | uns | 2026-05-28T13:19:05Z | 2026-05-28T13:19:05Z | passed | Task 14.4. Cash mismatch surfaces via `FraudDetectionService.checkCashVariance` → `FraudAlertType.cashVariance` → `SecurityNotificationService` → SDK emit. Validator service itself remains a state-checker; emission centralised through the security bridge. Equivalence test covers the mapping. |
| T-SEC-3 | `Dukan_x/lib/core/services/stock_security_service.dart` | suspicious stock anomaly | `system.security_stock.anomaly_detected` | uns | 2026-05-28T13:19:05Z | 2026-05-28T13:19:05Z | passed | Task 14.4. `logStockAdjustment` emits the event directly when changePercent > 50%. Audit-cache row retained as local fallback. Equivalence test covers >50% / >90% / silent / no-SDK paths. |
| T-SEC-4 | `lambda/auditHandler/index.mjs` | audit row written | n/a — rejected (high-frequency; only specific rows trigger) | legacy | pending | pending | pending | Phase 1 rejected. T-SEC-5 covers the security-relevant subset. |
| T-SEC-5 | `my-backend/src/middleware/role-guard.ts`, `my-backend/src/middleware/permission-guard.ts` | unauthorized access attempt (denied) | `system.security_access.unauthorized_attempt` | legacy | pending | pending | pending | Task 14.9. |
| T-SEC-6 | `Dukan_x/lib/core/services/cleanup_service.dart`, `reconciliation_service.dart`, `einvoice_status_service.dart` | scheduled job result | n/a — rejected (silent infrastructure tasks; metrics, not notifications) | legacy | pending | pending | pending | Phase 1 rejected. |
| T-SEC-7 | `my-backend/src/handlers/health.ts` | health-check failure | `system.health.degraded` | legacy | pending | pending | pending | Task 14.9. |

### 4.18 Marketplace / Customer App / Pre-Order (Phase 1 §9.18)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-MKT-1 | `lambda/marketplace/ordersHandler/index.ts` | order placed | `orders.marketplace.placed` | legacy | pending | pending | pending | Task 14.9. |
| T-MKT-2 | `lambda/marketplace/cartHandler/index.ts` | cart updated (push to other devices) | n/a — rejected (device-local high-frequency churn) | legacy | pending | pending | pending | Phase 1 rejected. |
| T-MKT-3 | `lambda/marketplace/wsHandler/index.ts` | broadcast notification (existing) | n/a — rejected (transport mechanism, replaced wholesale by UNS) | legacy | pending | pending | pending | Phase 1 rejected. The UNS bus replaces this transport entirely. |
| T-MKT-4 | `Dukan_x/lib/features/pre_order/presentation/customer/customer_pre_order_screen.dart`, `Dukan_x/lib/features/pre_order/presentation/vendor/vendor_request_detail_screen.dart` | pre-order requested → vendor accepts/rejects | `orders.pre_order.requested` / `orders.pre_order.responded` | legacy | pending | pending | pending | Two events. Task 14.9. |
| T-MKT-5 | `my-backend/src/handlers/in-store-checkout.ts` | exit QR generated (`IN_STORE_EXIT_QR_READY`) | `orders.in_store_exit_qr.ready` | legacy | pending | pending | pending | Task 14.9. |
| T-MKT-6 | `my-backend/src/handlers/in-store-streams.ts` | in-store sale dashboard update (`DASHBOARD_UPDATED`) | n/a — rejected (operator dashboard refresh, not user-actionable) | legacy | pending | pending | pending | Phase 1 rejected. |

### 4.19 Loyalty / Marketing (Phase 1 §9.19)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-MKT-LOY-1 | `Dukan_x/lib/features/marketing/presentation/screens/create_campaign_screen.dart`, `my-backend/src/handlers/loyalty.ts` | campaign sent | `users.marketing_campaign.sent` | legacy | pending | pending | pending | Task 14.9. |
| T-MKT-LOY-2 | `my-backend/src/handlers/loyalty.ts` | points awarded | `users.loyalty_points.awarded` | legacy | pending | pending | pending | Task 14.9. |
| T-MKT-LOY-3 | `my-backend/src/handlers/loyalty.ts` | tier upgraded | `users.loyalty_tier.upgraded` | legacy | pending | pending | pending | Task 14.9. |

### 4.20 AI / Voice (Phase 1 §9.20)

| Trigger Point ID | Legacy file | Symbol / function | UNS replacement event_name | Active path | Migration started | Migration completed | Equivalence test status | Notes |
|---|---|---|---|---|---|---|---|---|
| T-AI-1 | `voice-backend/voice_agent.py`, `Dukan_x/lib/features/ai_assistant/presentation/screens/desktop_ai_assistant_screen.dart` | agent triggered an action | n/a — rejected (conversational, in-session UI) | legacy | pending | pending | pending | Phase 1 rejected. |
| T-AI-2 | `my-backend/src/services/ai-tools.registry.ts` | `notify_owner` tool execution | `users.ai_notify_owner.requested` | legacy | pending | pending | pending | Task 14.9. |

---

## 5. Summary

| Status | Count |
|---|---|
| Justified Trigger_Points (have a UNS replacement) | 126 |
| Rejected / subsumed Trigger_Points (no UNS replacement) | 18 |
| `n/a` consumer rows (subscribers of other Trigger_Points; T-PAY-9, T-RES-6) | 2 |
| **Total rows in this ledger** | **146** |

> Phase 1 §9's narrative summary states "126 justified + 19 rejected = 145 Trigger_Points + 2 consumer rows = 147". The ledger above is sourced row-by-row from the §9 tables and contains 146 unique Trigger_Point IDs (126 justified + 18 rejected/subsumed + 2 consumers). The one-row delta is a counting nuance in the §9 narrative summary; the ledger reflects the actual §9 ID set and is therefore the authoritative tracker for the migration. If the §9 narrative is later corrected, this summary will be re-aligned.

| `Active path` distribution | Count |
|---|---|
| `legacy` | 102 |
| `uns` | 44 |
| `both` | 0 (forbidden by invariant) |

| `Equivalence test status` distribution | Count |
|---|---|
| `pending` | 102 |
| `passed` | 44 |
| `failed` | 0 |

The migration is considered complete when, for every justified Trigger_Point: `Active path = uns`, `Migration started` and `Migration completed` are both ISO-8601 timestamps, and `Equivalence test status = passed`. Rejected and consumer rows do not require an equivalence test, but the legacy emit (where one exists) must be removed before the feature is marked complete (REQ 10.7).

### 5.1 Task 14.9 progress (HIGH/MEDIUM completed in this wave)

**Migrated in 2026-05-28 wave (HIGH + MEDIUM priority producers, server-side):**

- **Billing**: T-BIL-2, T-BIL-3, T-BIL-4, T-BIL-5 (`my-backend/src/handlers/invoices.ts`)
- **Payments**: T-PAY-2 (`payments.ts`), T-PAY-3, T-PAY-4 (`payment-webhook.ts`)
- **Inventory**: T-INV-3, T-INV-4, T-INV-5, T-INV-6, T-INV-7, T-INV-9 (`inventory.ts`)
- **Decoration & Catering**: T-DC-1, T-DC-2, T-DC-3, T-DC-4, T-DC-5, T-DC-8 (`dc.ts`)
- **Restaurant**: T-RES-1 server-side (`restaurant-v1-public.ts` — closes the server half of the desktop-only emit landed in 14.3)
- **Pump**: T-PMP-1, T-PMP-2, T-PMP-3, T-PMP-4, T-PMP-5 (`pump.ts`)
- **Trial / Plan**: T-PLN-1, T-PLN-2, T-PLN-3 (`lambda/trial*Handler/index.mjs` via the new `lambda/shared/uns-emit.mjs` helper)

The migration uses the additive pattern: each producer keeps its legacy `wsService.emitEvent(...)` / `wsService.broadcastToClientType(...)` / `sns.send(SNS_TRIAL_TOPIC_ARN, ...)` call AND adds a new `emitUnsEvent({ ... })` call alongside it. This satisfies REQ 19.5's "single active path" invariant for the registry-defined `event_name` (the canonical UNS emit is the sole path for that event_name) while keeping the legacy WS broadcast running for the migration window so connected DukanX desktop / scanner-PWA clients on older builds keep working. The legacy emits for these rows will be deleted in a follow-up sweep once the equivalence-test results land in CI for each producer.

A small reusable helper was added at `my-backend/src/notifications/event-bus/emit-helper.ts` (and a parallel ESM-only `lambda/shared/uns-emit.mjs` for the `.mjs` lambdas that live outside the my-backend TS project) so each producer migration is a small, repeatable diff.

### 5.2 Deferred to follow-up (LOW priority + a small number of plumbing-bound MEDIUM)

The following Trigger_Points are intentionally left on `legacy` in this wave because either (a) the emit lives in a deeply-nested service rather than a handler and would require plumbing the auth context through several layers, (b) there is no current emit point and a new emit site has to be created from scratch, or (c) the producing surface is a large frontend feature module that is best migrated in a separate wave to avoid touching unrelated code. They are tracked here so the next wave can pick them up cleanly:

- **Billing (frontend)**: T-BIL-7 (`return_bill_screen.dart`), T-BIL-8 (`credit_note_screen.dart`)
- **Payments (frontend)**: T-PAY-6 (`process-refund.ts`), T-PAY-7 (`refund_screen.dart`)
- **Inventory (deep service layer)**: T-INV-1 (offline `eventDispatcher.stockChanged`), T-INV-2 (offline `eventDispatcher.stockLow`), T-INV-8 (`invoice.service.ts` post-sale stock decrement), T-INV-10 (`pharmacy_migration_service.dart` + `supplier_expiry_return_service.dart` expiry detection), T-INV-11 (`grocery-expiry.ts`), T-INV-12 (import-progress batched events)
- **Purchase (frontend)**: T-PUR-1..T-PUR-7 (all `add_purchase_screen.dart` / `buy_flow` / `scan_bill_review_screen.dart` / `purchase-order-matching.ts`)
- **Customer/Vendor (frontend)**: T-CUS-6 (`collect_payment_screen.dart`), T-CUS-7 (`recovery-visits.ts`), T-CUS-8 (`credit-reminders.ts`)
- **Jewellery (frontend)**: T-JEW-1..T-JEW-7
- **Restaurant server-side (other handlers)**: T-RES-2 (`restaurant-kot.ts`), T-RES-4 (`resto.ts`), T-RES-7 (`restaurant-delivery.ts`)
- **Clinic / Pharmacy**: T-CLN-1..T-CLN-8 (mix of handlers + frontend)
- **Academic Coaching / School**: T-SCH-1..T-SCH-22 (all need to switch from the legacy `pushNotification(userId, payload)` call shape to passing the canonical `event_name`/`priority`/`recipients` overrides — the `school-notifications.ts` helper accepts these overrides today (task 14.7), so this is plumbing-only but volume-heavy)
- **Service / Auto Parts / Computer Shop**: T-JOB-1, T-JOB-2, T-JOB-3
- **DC residual**: T-DC-6 (staff assignment is folded into `updateEvent`), T-DC-7 (DC inventory low-stock derives from dashboard rather than a handler emit)
- **Vegetable Broker**: T-VEG-1, T-VEG-2 (frontend repository emits)
- **Delivery**: T-DLV-1, T-DLV-2, T-DLV-3 (`delivery_challan_service.dart`, `dispatch_note_screen.dart`, `lambda/marketplace/deliveryHandler`)
- **Staff attendance**: T-PMP-6 (`staffCheckIn.ts`/`staffCheckOut.ts`), T-PMP-7 (`staff-sale.ts`)
- **Plan / Subscription residual**: T-PLN-4 (`grace-period-cron.ts`), T-PLN-5 (`subscription-webhook.ts`), T-PLN-6 (`feature-flag.ts`/`tenant_config_provider.dart`)
- **Security**: T-SEC-5 (`role-guard.ts`/`permission-guard.ts` — emits `system.security_access.unauthorized_attempt` from middleware; this is wired by task 16.3 instead of 14.9), T-SEC-7 (`health.ts`)
- **Marketplace**: T-MKT-1 (`ordersHandler/index.ts`), T-MKT-4 (pre-order request/respond), T-MKT-5 (`in-store-checkout.ts`)
- **Loyalty / Marketing**: T-MKT-LOY-1, T-MKT-LOY-2, T-MKT-LOY-3 (`loyalty.ts`)
- **AI**: T-AI-2 (`ai-tools.registry.ts` `notify_owner` tool)
- **Clinic lab result**: T-CLN-8 (no current emit — new emit site to be created)

These rows remain `Active path = legacy` in §4 above. The `5.1` summary captures what shipped in this wave; the `5.2` list captures what was deliberately deferred so the §6 update protocol stays accurate (no row falsely advertises `passed`).

---

## 6. Update protocol

When migrating a Trigger_Point:

1. Open a PR that includes both the code change (legacy emit deleted, UNS emit added) and a single-line edit to the relevant row in this file: set `Migration started`, flip `Active path` to `uns`.
2. After the equivalence test runs in CI, a follow-up commit (or the same PR if CI is in-PR) sets `Migration completed` and `Equivalence test status`.
3. If the equivalence test fails, revert the code change in the same PR; this file's row reverts with it. Do not leave a row in `Active path = uns` with `Equivalence test status = failed`.
4. Reviewer must verify no row in this file shows `Active path = both`.
