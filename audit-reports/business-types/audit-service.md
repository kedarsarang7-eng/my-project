# DukanX Business-Type Audit — Service Business (`BusinessType.service`)

> **Audit type:** READ-ONLY, evidence-based. No source files were modified.
> **Scope:** The `service` business type only (Service Business). Every "missing/broken/orphaned" claim cites the file/function checked. Where a claim could not be fully verified it is marked **unverified**.
>
> **Sampled (read in full or near-full):**
> - `Dukan_x/lib/models/business_type.dart` (enum + displayName/icon)
> - `Dukan_x/lib/core/billing/business_type_config.dart` (`service` config + extensions; partially loaded 1022/1162 lines — service block read in full)
> - `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` (`_getSectionsForBusiness`, full `_getServiceSections()`, full `_getCommonSections()`)
> - `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart` (full `getScreenForItem`)
> - `Dukan_x/lib/widgets/desktop/content_host.dart` (full `DesktopContentHost`)
> - `Dukan_x/lib/core/isolation/business_capability.dart` (`'service'` registry key + full enum)
> - `Dukan_x/lib/core/config/business_capabilities.dart` (`BusinessCapabilities.get` flags)
> - `Dukan_x/lib/features/service/**` — all models, services, repositories (service_job), and screens (service_job_list, create_service_job, service_job_detail, exchange_list); `service.dart` barrel; `imei_validation_service.dart`
> - `Dukan_x/lib/features/dashboard/v2/widgets/business_quick_actions.dart`, `business_alerts_widget.dart` (service branches)
> - `Dukan_x/lib/app/routes.dart` (service/`/job/*` route guards)
> - `Dukan_x/lib/core/session/session_manager.dart` (RBAC roles, via grep)
>
> **Sampled lightly (grep/listing, internals not fully opened):** `exchange_service.dart`, `exchange_repository.dart`, `warranty_claim_service.dart`, `warranty_claim_repository.dart`, `imei_serial_repository.dart`, `service_job_statement_screen.dart`, `create_exchange_screen.dart`, `exchange_detail_screen.dart`, `service_job_notification_service.dart` (read in full but SDK plumbing tail truncated), backend `my-backend/src/handlers/service.ts`.
>
> **Skipped (out of scope):** Other business types; Node/DynamoDB backend correctness; `.archive/` trees; generated `app_database.g.dart` internals; full RBAC `RolePermissions`/`Permission` matrix internals; test suites.

---

## 1. Header — Sidebar resolution, config, capabilities

**Business type:** `BusinessType.service` → displayName `'Service Business'`, icon `Icons.miscellaneous_services_rounded`, emoji `🧾`, primary color `0xFF7C3AED` (purple). (`models/business_type.dart`, `core/billing/business_type_config.dart` extensions.)

**Billing config** (`BusinessTypeRegistry._configs[BusinessType.service]` in `core/billing/business_type_config.dart`):
- `requiredFields: [itemName, laborCharge]`
- `optionalFields: [partsCharge, notes, gst]`
- `defaultGstRate: 18.0`, `gstEditable: true`
- `unitOptions: [pcs, hr, nos]`
- `itemLabel: 'Service'`, `addItemLabel: 'Add Service'`, `priceLabel: 'Labor'`
- `modules: ['jobs', 'invoices', 'customers', 'reports']`

**Sidebar:** Dedicated `_getServiceSections()` (`sidebar_configuration.dart`) → 3 dedicated sections + `_getCommonSections(startingIndex: 3)`:
1. **Service Dashboard:** `executive_dashboard`, `daily_activity` (badge), `daily_snapshot`
2. **Billing Desk:** `new_sale`, `revenue_overview`, `receipt_entry`, `sales_register`, `proforma_bids`
3. **Service & Repairs:** `service_jobs`, `exchanges`
4. **Parties & Ledger** (common): `customers`, `suppliers`, `party_ledger`, `outstanding`
5. **Reports & Analytics** (common): `analytics_hub`, `product_performance`, `invoice_margin`, `gstr1`
6. **System** (common): `print_settings`, `backup`, `error_logs`, `device_settings`

**Capabilities** (`businessCapabilityRegistry['service']` in `core/isolation/business_capability.dart`):
`useInvoiceList`, `useInvoiceSearch`, `useInvoiceCreate`, `useDailySnapshot`, `useRevenueOverview`, `useJobSheets`, `useServiceStatus`, `useLaborCharges`, `useAppointments`.
Hard isolation **denies** all product/inventory/purchase capabilities for `service` (explicitly commented out in the registry). Note the prompt's guess of `useRepairStatus` is **not** in the service set — service has `useServiceStatus` (the `useRepairStatus` key belongs to mobileShop/computerShop/autoParts).

**Resolution status:** All 20 sidebar IDs resolve to a real screen in `getScreenForItem` (no `default`/placeholder hit). Detailed per-ID table in §6.

---

## 2. Missing generic features (vs Vyapar benchmark)

For each: priority + recommendation. Benchmark item numbers reference the 17-point list in the request.

| # | Vyapar feature | Status for `service` | Priority | Recommendation |
|---|---|---|---|---|
| 2 | Inventory/Stock | **Absent.** Service registry denies all inventory capabilities (`business_capability.dart`); no inventory in sidebar. But spare-parts repair shops need parts stock. | High | Introduce an optional "spare parts" inventory scoped to service, or wire `ServiceJobPart` to the existing products inventory (see §13/§3 parts gap). |
| 3 | Barcode/POS | **Absent** for service (no `useBarcodeScanner` in registry; no scan action in `business_quick_actions.dart` service branch). | Low | Optional for parts lookup only. |
| 4 | Accounting depth | **Partial.** `invoice_margin`→`PnlScreen`, `income_statement`→`PnlScreen` (duplicate mapping in `sidebar_navigation_handler.dart`). No trial balance/daybook in service sidebar. | Medium | Add Day Book / accounting reports to service common section (screens exist: `DayBookScreen`, `AccountingReportsScreen`). |
| 5 | Receivables/Payables | **Partial.** `outstanding`→`PartyLedgerListScreen(receivable)` present; payables limited (suppliers shown but no purchase flow). | Low | Acceptable; service is receivable-heavy. |
| 6 | Bank/Cash | **Absent from service sidebar.** `bank_accounts`→`BankScreen` exists in handler but is not in `_getServiceSections`/`_getCommonSections`. `cash_bank` also absent. | Medium | Add `bank_accounts`/`cash_bank` to the common System or Reports section. |
| 7 | Orders/Delivery | **Absent.** No booking/dispatch in service sidebar (those are retail-only). | Low | Optional. |
| 8 | OCR | **Absent** (`useScanOCR` not granted to service). | Low | Optional. |
| 9 | Reports (37+) | **Reduced set.** Service gets `analytics_hub`, `product_performance`, `invoice_margin`, `gstr1` only. `product_performance` is product-centric and of low value to a labor business. | Medium | Replace `product_performance` with service-relevant reports (jobs-by-status, technician productivity, labor-vs-parts revenue). |
| 10 | RBAC + audit | **Partial/over-restrictive** — see §11. | High | See §11. |
| 11 | Multi-firm | **Unverified** (not inspected). | — | Verify separately. |
| 12 | Backup | **Present** (`backup`→`BackupScreen`). | — | OK. |
| 13 | Online store | **Absent.** | Low | Optional. |
| 14 | e-Way bill | **Absent.** | Low | Service rarely needs it. |
| 15 | Loyalty | **Absent** (`useLoyaltyPoints` not granted to service). | Low | Optional for repeat-service customers. |
| 16 | Service-business (appointments, service+tip) | **Largely missing** — see §3. | Critical | See §3. |
| 17 | Offline-first sync | **Present** at data layer (Drift + `isSynced`); see §12. | — | Verify sync correctness. |

---

## 3. Missing industry-specific features (Service Business)

| Need | Evidence | Priority | Recommendation |
|---|---|---|---|
| **Appointment / booking scheduling** | `businessCapabilityRegistry['service']` grants `useAppointments`, but there is **no appointment screen wired for service**. `AppointmentScreen` exists only under `features/doctor/...` and is gated to `BusinessType.clinic` in `routes.dart` (`/clinic/appointment` BusinessGuard). No service sidebar entry. → capability granted but **orphaned**. | Critical | Build/relink an appointment-scheduling screen for service and add to `_getServiceSections`, or remove `useAppointments` from the registry to avoid a dead capability. |
| **Estimate → approval → invoice workflow** | `service_job_service.dart` has `addEstimate()` (sets status `waitingApproval`) and `approveEstimate()` (sets `approved`), but the UI in `service_job_detail_screen.dart` shows a PopupMenu item `value: 'estimate'` only when status==`diagnosed` and the `_handleMenuAction` switch has **no `'estimate'` case and no `'approve'` case** → selecting "Add Estimate" does nothing; `approveEstimate` is never reachable. The workflow is broken end-to-end in the UI. | Critical | Add `'estimate'` and `'approve'` handlers wired to `addEstimate`/`approveEstimate` with an estimate-entry form. |
| **Technician assignment & productivity** | `ServiceJob` model has `assignedTechnicianId`/`assignedTechnicianName` and the repository persists them (`service_job_repository.dart` `updateServiceJob`), but **no UI sets them** — neither `create_service_job_screen.dart` nor `service_job_detail_screen.dart` exposes technician assignment. No technician productivity report. Also no `technician` RBAC role (§11). | High | Add technician picker in create/detail and a technician-productivity report. |
| **Spare-parts consumption + parts billing split** | `ServiceJobPart` model + DB table (`ServiceJobPartsCompanion`/`ServiceJobPartEntity` in `app_database.g.dart`) exist, but `service_job_repository.dart._entityToModel` hardcodes `partsUsed: []` ("Parts are fetched separately") and there is **no repository method to insert/fetch parts and no UI to add them**. Consequently `_generateInvoice` in the detail screen iterates `_job.partsUsed` which is always empty → invoices only ever contain a labor line. (Backend `my-backend/src/handlers/service.ts` has `addJobParts`, but it is commented out in `my-backend/serverless.yml`.) | High | Implement parts CRUD (repo + UI) and deduct from inventory where applicable. |
| **AMC / recurring service contracts** | No AMC model/screen in `features/service/`. Only a redirect stub: `modules/computer_shop/routes/computer_shop_routes.dart` maps `/computer/amc`→`LegacyRouteRedirect('/service_jobs')`. | High | Add AMC contract model + recurring-reminder support. |
| **Service-status notifications to customer** | `service_job_notification_service.dart` is fully implemented (status/created/warranty/exchange/payment-reminder via Notifications SDK) but is **never instantiated or called** from any UI (grep for `ServiceJobNotificationService(` returns only its own constructor). The detail screen calls `_service.updateStatus(...)` directly, which does **not** dispatch a notification. → notifications are dead code. | High | Wire `dispatchStatusChangeNotification` into `ServiceJobService.updateStatus` (or the detail screen) and register `NotificationsSdk` in DI. |
| **Signature / photo capture** | Model supports `deliverySignature` (persisted via `markDelivered`) and `devicePhotos`, but no UI captures either (create/detail screens have no photo/signature widgets). | Medium | Add photo capture on intake and signature capture on delivery. |
| **Callback / follow-up reminders** | No follow-up reminder model/UI. | Medium | Add follow-up reminder after delivery. |
| **Non-device service support** | The entire `ServiceJob` model is device-repair-centric: `DeviceType {mobile, laptop, desktop, tablet, other}`, `brand`, `model`, `imeiOrSerial`, warranty-from-IMEI lookup. A generic service business (salon, plumbing, AC, electrician, consultancy) has no asset/device — yet `brand`/`model` are **required** in `create_service_job_screen.dart` (validators "Required"). | High | Make device fields optional / add a "general service" job mode driven by `BusinessType.service`. |
| **Tip tracking (Vyapar service+tip)** | No tip field anywhere in `ServiceJob`. | Low | Optional. |

---

## 4. Missing UI components

- **Estimate-entry form** — `addEstimate` exists in service layer but no form to enter labor/parts/tax; the menu action is dead (§3, §13). Priority: Critical.
- **Technician picker** — no widget in create/detail (§3). Priority: High.
- **Parts line-item editor** — no widget to add `ServiceJobPart` (§3). Priority: High.
- **Photo/signature capture** — no widget (§3). Priority: Medium.
- **Status overview cards are non-interactive** — `service_job_list_screen.dart` `_buildStatusCard` `onTap` body is empty (`// Filter by this status`), so tapping a count card does nothing. Priority: Medium.
- **Appointment calendar/booking view** — absent for service (§3). Priority: Critical.

---

## 5. Missing widgets & dashboard / KPI cards

- **Hardcoded dashboard alert counts (not real data).** `business_alerts_widget.dart` `_buildAlertsForBusiness` `case BusinessType.service:` emits two cards with **hardcoded** counts: `'Open Service Jobs'` count `'6'` and `'Pending Quotes'` count `'4'`. These ignore the `counts` map and never call `ServiceJobService.getJobCounts`. The title `_getTitle` returns `'Service Job Alerts'` for service (correct). Priority: **High** — replace with live counts from `ServiceJobService.getJobCounts(userId)` / active-jobs stream.
- **No service KPI cards on the dashboard.** The dashboard has no service-specific KPI (jobs received today, overdue jobs, ready-for-pickup, labor-vs-parts revenue). The only status cards live inside `service_job_list_screen.dart`, not the dashboard. Priority: Medium.
- **Quick actions are redundant.** `business_quick_actions.dart` `case BusinessType.service:` adds **two** buttons ("New Job Sheet" and "Open Jobs") that both call `nav.navigateTo(AppScreen.serviceJobs)` — same destination, no "create new job" deep-link and no appointment/estimate action. Priority: Medium.

---

## 6. Navigation & route gaps

**Per-ID resolution** (every `service` sidebar id → `getScreenForItem` in `sidebar_navigation_handler.dart`):

| Section | Sidebar ID | Resolves to | OK? |
|---|---|---|---|
| Dashboard | `executive_dashboard` | `DashboardController` | ✅ |
| Dashboard | `daily_activity` | `AllTransactionsScreen` | ✅ (generic, not service-specific) |
| Dashboard | `daily_snapshot` | `DailySnapshotScreen` | ✅ |
| Billing | `new_sale` | `BillCreationScreenV2` | ✅ |
| Billing | `revenue_overview` | `RevenueOverviewScreen` | ✅ |
| Billing | `receipt_entry` | `ReceiptEntryScreen` | ✅ |
| Billing | `sales_register` | `SalesRegisterScreen` | ✅ |
| Billing | `proforma_bids` | `ProformaScreen` | ✅ (this is the "Quotes/Estimates" entry) |
| Service & Repairs | `service_jobs` | `ServiceJobListScreen` | ✅ |
| Service & Repairs | `exchanges` | `ExchangeListScreen` | ✅ (but miscategorized — see below) |
| Parties | `customers` | `CustomersListScreen` | ✅ |
| Parties | `suppliers` | `PartyLedgerListScreen(initialFilter:'supplier')` | ✅ (but service has no purchase capability) |
| Parties | `party_ledger` | `PartyLedgerListScreen` | ✅ |
| Parties | `outstanding` | `PartyLedgerListScreen(initialFilter:'receivable')` | ✅ |
| Reports | `analytics_hub` | `ReportsHubScreen` | ✅ |
| Reports | `product_performance` | `ProductPerformanceScreen` | ✅ (product-centric; low value for labor business) |
| Reports | `invoice_margin` | `PnlScreen` | ✅ |
| Reports | `gstr1` | `GstReportsScreen(initialIndex:0)` | ✅ |
| System | `print_settings` | `PrintMenuScreen` | ✅ |
| System | `backup` | `BackupScreen` | ✅ |
| System | `error_logs` | `ErrorLogsScreen` | ✅ |
| System | `device_settings` | `DeviceSettingsScreen` | ✅ |

**No dead links / no placeholder hits** for service. Findings:

- **Capability gating not applied to any service sidebar item.** None of the `SidebarMenuItem`s in `_getServiceSections`/`_getCommonSections` set a `capability:` field, so the `FeatureResolver.canAccess` filter in `sidebarSectionsProvider` (`sidebar_configuration.dart`) is a no-op for service. Hard isolation is therefore **not enforced at the sidebar** for this type. Priority: Medium.
- **Miscategorized: `exchanges` (Device Exchanges).** Trade-in/buyback is a mobile-shop concept. `useExchange`/`useBuyback` are granted only to `mobileShop` in `business_capability.dart`; the service registry does **not** grant them. Yet the service sidebar shows `exchanges`→`ExchangeListScreen` (a device trade-in screen, per `exchange_list_screen.dart` "Trade-in and exchange management"). Capability mismatch + irrelevant for general service. Priority: High.
- **Orphaned service screens (exist, not reachable for service):**
  - `features/statements/presentation/screens/service_job_statement_screen.dart` (`ServiceJobStatementScreen`) — a service-job statement/PDF report; **no service sidebar entry**. Priority: Medium.
  - Warranty-claim stack: `services/warranty_claim_service.dart`, `data/repositories/warranty_claim_repository.dart`, `models/warranty_claim.dart` — **no UI screen anywhere** (no warranty-claim screen in `features/service/presentation/screens/`). Dead feature. Priority: Medium.
- **Reachable (not orphaned):** `create_service_job_screen.dart`, `service_job_detail_screen.dart` (pushed from `ServiceJobListScreen`); `create_exchange_screen.dart`, `exchange_detail_screen.dart` (pushed from `ExchangeListScreen`). Confirmed via `Navigator.push` in those list screens.
- **Capability mismatch — `accessServiceStatus`:** `BusinessCapabilities.get` computes `accessServiceStatus` from `useServiceStatus` (granted to service) but this flag is not consumed by any service sidebar/dashboard branch inspected. Priority: Low (unused flag).

---

## 7. Backend integration gaps

- **Customer notifications never reach the backend.** `service_job_notification_service.dart` emits via the Notifications SDK, but it is never called from the app (§3). Even if called, `_resolveSdk()` returns `null` and logs a warning when `NotificationsSdk` is not registered in `core/di/service_locator.dart` — registration status **unverified**. Priority: High.
- **Backend parts endpoint disabled.** `my-backend/src/handlers/service.ts` implements job-parts recording (`SERVICEJOBPART#`), but `serviceAddParts` is **commented out** in `my-backend/serverless.yml` — so even a future parts UI has no deployed endpoint. Priority: High.
- **Local-first, sync correctness unverified.** Service jobs are written to local Drift DB with `isSynced: false` flags (`service_job_repository.dart`); the actual push-to-DynamoDB sync path for `service_jobs` was not traced. **Unverified.** Priority: Medium.

---

## 8. Database & API issues (real vs mock; hardcoded counts)

- **Real data:** `ServiceJobListScreen` and `ServiceJobDetailScreen` use **real** local data via `ServiceJobService`/`ServiceJobRepository` over Drift (`AppDatabase.instance`): `watchAllServiceJobs`, `watchActiveServiceJobs`, `getJobCountsByStatus` are genuine queries. `ExchangeListScreen` uses real `ExchangeService.watchExchanges`/`getExchangeStats`. ✅
- **Mock/hardcoded:** Dashboard service alerts are **hardcoded** (`'6'`, `'4'`) in `business_alerts_widget.dart` (§5). The list-screen status counts are real; the dashboard counts are fake. Priority: High.
- **`getJobCountsByStatus` loads all rows into memory** and counts in Dart (`service_job_repository.dart`) rather than a `GROUP BY` aggregate — fine for small data, inefficient at scale (§10). Priority: Low.
- **Parts never persisted/queried** (§3) — DB table exists but is unused on the Flutter side. Priority: High.

---

## 9. Responsive design

- Service screens use `BoundedBox(maxWidth: 800)` and `responsiveValue<double>(context, mobile/tablet/desktop)` for font sizes (`service_job_list_screen.dart`, `create_service_job_screen.dart`, `service_job_detail_screen.dart`, `exchange_list_screen.dart`). Reasonable desktop behavior. ✅
- Status overview cards in the list are a fixed-height (100px) horizontal `ListView` with 100px-wide cards — acceptable but not adaptive to very wide screens. Priority: Low.
- `exchange_list_screen.dart` uses a full-bleed gradient inside `BoundedBox`; layout is column-based and should reflow acceptably. Not deeply tested. **Unverified** for extreme widths. Priority: Low.

---

## 10. Performance

- **Search re-runs the count query on every keystroke.** In `service_job_list_screen.dart`, the search `TextField.onChanged` calls `setState(() => _searchQuery = value)`, which rebuilds the `FutureBuilder<Map<ServiceJobStatus,int>>(future: _service.getJobCounts(_userId!))`. Because `future:` is a fresh call each build, `getJobCounts` (which reads **all** jobs) re-executes on each character typed. Priority: Medium — cache the future or use a stream/`AsyncMemoizer`.
- **Client-side filtering over full stream.** Search/status filtering happens in Dart over the entire `watchAllJobs` result, not at the DB layer. Fine for small datasets; scales poorly. Priority: Low.
- **New `ServiceJobService(AppDatabase.instance)` per screen** (list/detail/create) — cheap (wraps existing DB), acceptable. Priority: Low.

---

## 11. Security (RBAC, capability-bypass, content_host route-guard bypass)

- **No `technician` role exists.** `core/session/session_manager.dart` `_parseRoleString` only maps `owner | manager | staff/cashier | accountant | unknown`. The service domain models technicians (`assignedTechnicianId`) but there is no RBAC role for them. Priority: High.
- **Over-restrictive named-route guard.** In `routes.dart`, `/service_jobs`, `/exchanges`, `/job/create`, `/job/status`, `/job/deliver` all require `requiredPermission: Permissions.manageStaff` (an admin-level permission). A front-desk `staff`/`cashier` could not create or view repair jobs through these routes. Priority: High — should use a service-specific permission (e.g. `manageServiceJobs`), not `manageStaff`.
- **content_host bypasses route guards (RBAC + BusinessGuard bypass).** `DesktopContentHost._buildScreen` (`content_host.dart`) resolves screens via `_screenBuilders` and falls back to `SidebarNavigationHandler.getScreenForItem(screen.id, context)` — wrapping only in a `FeatureErrorBoundary`, with **no `VendorRoleGuard`, no `BusinessGuard`, and no capability check**. So opening `service_jobs`/`exchanges` from the desktop sidebar bypasses the `Permissions.manageStaff` guard and the `BusinessGuard` that protect the equivalent named routes (`/service_jobs`, `/job/status`). Any logged-in user of any role/business type can reach these screens in the desktop shell. Priority: **Critical** — apply role/capability/business guards inside `getScreenForItem` or the content host.
- **Inconsistent isolation for `exchanges`.** Named route `/exchanges` requires `manageStaff` but has **no `BusinessGuard`**, while `/job/status` has a `BusinessGuard([mobileShop, computerShop, service, electronics])`. Combined with the content-host bypass, isolation for exchanges is effectively unenforced. Priority: High.
- **PII handling.** `ServiceJob` stores `customerPhone`, `customerEmail`, `customerAddress`, and `deliverySignature`; no field-level access control or masking observed. Priority: Low (note for compliance).

---

## 12. Offline mode gaps

- **Offline-capable data layer.** `service_job_repository.dart` writes to local Drift with `isSynced: false` on create/update/status-change/cancel/deliver, and exposes `watch*` streams — so create/read/update of service jobs works offline. ✅
- **Notifications require network and silently no-op offline.** `service_job_notification_service.dart` `_emit` logs and returns when the SDK is unavailable; SDK `emit` relies on an outbox (per comments) but this path is currently unreachable (§3/§7). Priority: Medium.
- **Sync conflict handling unverified.** No conflict-resolution logic for `service_jobs` was inspected. **Unverified.** Priority: Medium.

---

## 13. Business logic inconsistencies (job status workflow)

- **Status workflow is not enforced.** The model defines a 10-state lifecycle (`ServiceJobStatus`: received→diagnosed→waitingApproval→approved→waitingParts→inProgress→completed→ready→delivered/cancelled), but `service_job_detail_screen.dart` `_showUpdateStatusSheet` renders **all** statuses (except cancelled/delivered) as free-choice `ActionChip`s and calls `updateStatus` with no transition validation. A user can jump `received`→`ready`, skipping diagnosis/estimate/approval/parts/work. Priority: High — enforce allowed transitions in `ServiceJobService.updateStatus`.
- **Estimate/approval path is unreachable** (dead menu action) — see §3. Critical.
- **`completeJob` uses estimates as actuals.** `service_job_detail_screen.dart` `case 'complete'` calls `_service.completeJob(actualLaborCost: _job.estimatedLaborCost, actualPartsCost: _job.estimatedPartsCost)`. Since the estimate flow is broken, both default to `0`, so `grandTotal` stays `0` and "Record Payment"/invoice show no amount. Priority: High.
- **Invoice tax hardcoded.** `_generateInvoice` builds `BillItem`s with `gstRate: 18.0` and `cgst = amount*0.09`, `sgst = amount*0.09` **regardless** of config `gstEditable`, customer state (no IGST path), or per-part GST. Contradicts `gstEditable: true` in the service config. Priority: Medium.
- **IMEI validation excludes service.** `imei_validation_service.dart._requiresIMEIValidation` matches `mobile|computer|electronics|phone|laptop` but **not** `service`. So service-business bills skip IMEI duplicate checks even though `create_service_job_screen.dart` collects an IMEI/Serial and the job-create path does a warranty lookup. Minor inconsistency. Priority: Low.

---

## 14. Data validation issues

- **Weak phone validation.** `create_service_job_screen.dart` phone validator is `(v?.length ?? 0) < 10 ? 'Invalid' : null` — accepts any ≥10-character string (non-numeric allowed, no max, no format). Priority: Medium.
- **Device fields wrongly required for non-device services.** `Brand*` and `Model*` are required validators, blocking generic service jobs (§3). Priority: High.
- **No IMEI format validation.** IMEI field accepts free text; `imei_validation_service._guessIMEIType` only post-hoc guesses 15-digit. No Luhn/length check at entry. Priority: Low.
- **Payment overpayment allowed.** `service_job_detail_screen.dart` `_recordPayment` accepts any `amount > 0` with no cap at `balanceAmount`; `ServiceJobService.recordPayment` then sets status `PAID` when `amountPaid >= grandTotal`, so overpayment is silently accepted. Priority: Medium.
- **No duplicate-job guard.** Nothing prevents creating multiple open jobs for the same device/customer. Priority: Low.

---

## 15. UX problems

- **"Add Estimate" does nothing** (dead menu action) — §3/§13. Critical for UX trust.
- **Status count cards are non-interactive** (empty `onTap`) — §4. Medium.
- **Redundant quick actions** — both dashboard quick actions go to the same screen — §5. Medium.
- **No create-job deep link from dashboard** — the "New Job Sheet" quick action opens the list, not the create form (`CreateServiceJobScreen`); user must tap the FAB afterward. Medium.
- **Device-centric labels for all service businesses** — a salon/plumbing service sees "Device", "Brand", "Model", "IMEI/Serial", warranty badges — confusing for non-device services. High.
- **`expectedDelivery` shows truncated date** — `create_service_job_screen.dart` renders `'${day}/${month}'` only (no year). Low.

---

## 16. Accessibility

- **Icon-only buttons lack semantics/tooltips.** The filter `IconButton(icon: Icon(Icons.filter_list))` in `service_job_list_screen.dart` has no `tooltip`/semantics label. Priority: Medium.
- **Exchange back affordance is not a semantic button.** `exchange_list_screen.dart` `_buildHeader` uses a `GestureDetector` wrapping an arrow icon as the back control — no `Semantics`/`tooltip`, not announced as a button. Priority: Medium.
- **Status conveyed primarily by color** — status chips do include text labels (good), but the priority indicator is a bare red `Icons.priority_high` with no label. Priority: Low.
- **No explicit `Semantics` on KPI/stat cards.** Counts are visual only. Priority: Low.
- WCAG conformance overall **unverified** (requires assistive-tech testing).

---

## 17. Bugs / errors / crash scenarios

| Bug | Evidence | Priority |
|---|---|---|
| "Add Estimate" menu item is a no-op (missing switch case) | `service_job_detail_screen.dart` menu `value:'estimate'` vs `_handleMenuAction` switch (no `estimate`/`approve`) | Critical |
| Parts never load → invoices miss all parts lines | `service_job_repository.dart` `partsUsed: []`; `_generateInvoice` loops empty list | High |
| Status workflow can be violated (skip states) | `_showUpdateStatusSheet` free-choice chips | High |
| `completeJob` produces ₹0 totals when no estimate | `case 'complete'` passes `estimated*` (0) as actuals | High |
| Customer notifications silently never fire | `ServiceJobNotificationService` never instantiated; `updateStatus` doesn't dispatch | High |
| Status count cards do nothing on tap | empty `onTap` in `_buildStatusCard` | Medium |
| Possible "BuildContext across async gap" | dialog/sheet callbacks (`_recordPayment`, `_handleMenuAction`) call `Navigator.pop`/`ScaffoldMessenger` after `await`; some `_refreshJob` paths lack `mounted` re-checks before `setState` (though `_refreshJob` checks `mounted`). Lower risk but present in `_showUpdateStatusSheet`/`_recordPayment` flows. | Low/Medium |
| Hardcoded dashboard counts mislead operators | `business_alerts_widget.dart` service branch | High (data integrity) |

No null-deref crash found in the sampled service screens; `_userId` is guarded before queries.

---

## 18. Unnecessary / irrelevant features shown to `service`

- **Device Exchanges (`exchanges`)** — trade-in/buyback; mobile-shop feature shown to service without the `useExchange` capability (§6). Priority: High (remove or gate).
- **Product Performance report (`product_performance`)** — product/SKU analytics, low value for a labor business (§2/§6). Priority: Medium.
- **Suppliers (`suppliers`)** — service has no purchase/inventory capabilities yet a supplier ledger is shown via the common section. Priority: Low.
- **IMEI/Serial + warranty-from-IMEI on intake** — device-specific; irrelevant for non-device service businesses (§3). Priority: Medium.

---

## 19. Recommendations & prioritized implementation plan

**Critical (fix first)**
1. Apply RBAC/Business/capability guards inside `DesktopContentHost`/`getScreenForItem` so the desktop shell stops bypassing route guards (§11).
2. Wire the **estimate→approval** workflow (`addEstimate`/`approveEstimate`) into the detail-screen menu; fix the dead `'estimate'` action (§3, §13, §17).
3. Add **appointment/booking** UI for service (capability already granted) or remove the orphaned `useAppointments` (§3).
4. Replace **hardcoded dashboard alert counts** with live `ServiceJobService.getJobCounts` data (§5, §8).

**High**
5. Implement **spare-parts** persistence + UI and include parts in invoices; re-enable backend `serviceAddParts` (§3, §7, §8).
6. Add **technician assignment** UI + a `technician`/`manageServiceJobs` RBAC role; stop using `manageStaff` for service routes (§3, §11).
7. Make **device fields optional** / add a general-service job mode for non-device service businesses (§3, §14, §15).
8. Enforce **status-transition validation** in `updateStatus`; fix `completeJob` to capture real actual costs (§13).
9. Wire **customer status notifications** into `updateStatus` and register `NotificationsSdk` (§3, §7).
10. Gate or remove **Device Exchanges** for service (capability mismatch) (§6, §18).

**Medium**
11. Add **Bank/Cash** and Day Book/accounting entries to the service sidebar; swap `product_performance` for service reports (jobs-by-status, technician productivity, labor-vs-parts) (§2, §6).
12. Correct **invoice GST** (respect config, support IGST, per-part rates) (§13).
13. Cache the **counts future** so search no longer re-queries per keystroke (§10).
14. Make **status count cards interactive**; de-duplicate dashboard quick actions; add a create-job deep link (§4, §5, §15).
15. Add **photo/signature capture**; harden **phone/payment** validation (§3, §14).
16. Surface or remove the **orphaned warranty-claim stack** and `ServiceJobStatementScreen` (§6).

**Low**
17. Accessibility: tooltips/semantics on icon buttons and the exchange back control (§16).
18. Add IMEI format validation; show full date for expected delivery; reconsider showing Suppliers (§14, §15, §18).

---

## 20. Confidence & Coverage

- **High confidence (read in full):** service billing config; full `_getServiceSections` + `_getCommonSections`; complete per-ID resolution via `getScreenForItem`; `DesktopContentHost` guard-bypass; service capability registry entry; dashboard service quick-actions & alerts branches (hardcoded counts confirmed); `ServiceJob` model + `ServiceJobService` + `ServiceJobRepository`; create/detail/list service screens; exchange list screen; `imei_validation_service`; RBAC role set (`session_manager.dart`); routes guard blocks for `/service_jobs`, `/exchanges`, `/job/*`.
- **Medium confidence (read in full but cross-feature wiring inferred / SDK tail truncated):** `service_job_notification_service.dart` (verified never called via grep; SDK plumbing tail truncated); orphaned status of warranty-claim and statement screens (verified no service sidebar/route entry; internals of warranty service only grepped).
- **Lightly sampled (grep/listing only):** `exchange_service.dart`/`exchange_repository.dart` internals, `imei_serial_repository.dart`, `warranty_claim_*` internals, `create_exchange_screen.dart`/`exchange_detail_screen.dart` internals, backend `service.ts`.
- **Unverified:** multi-firm support; offline **sync** correctness/conflict handling for service jobs; whether `NotificationsSdk` is registered in `service_locator.dart`; whether GoRouter modules (`computer_shop`) are mounted live; deep responsive/accessibility behavior; full `RolePermissions`/`Permission` matrix internals; `business_type_config.dart` lines 1022–1162 (service block was within the loaded range).
- **Skipped (out of scope):** non-service business types; Node/DynamoDB backend correctness; `.archive/` trees; generated Drift code internals; test suites.
