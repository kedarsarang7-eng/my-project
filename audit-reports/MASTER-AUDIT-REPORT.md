# DukanX — Master Business-Type Audit Report

> READ-ONLY discovery audit. No source files were modified. This master report consolidates the 18 per-business-type reports in `audit-reports/business-types/`. Every systemic claim below is traceable to at least one per-type report (which carries the file-path citations). Items not directly verified are marked **unverified**.

**Scope:** All 18 functional `BusinessType` values in `Dukan_x/lib/models/business_type.dart` (excluding `other`): grocery, pharmacy, restaurant, clothing, electronics, mobileShop, computerShop, hardware, service, wholesale, petrolPump, vegetablesBroker, clinic, bookStore, jewellery, autoParts, decorationCatering, schoolErp.

**Per-type reports:** `audit-grocery.md`, `audit-pharmacy.md`, `audit-restaurant.md`, `audit-clothing.md`, `audit-electronics.md`, `audit-mobileShop.md`, `audit-computerShop.md`, `audit-hardware.md`, `audit-service.md`, `audit-wholesale.md`, `audit-petrolPump.md`, `audit-vegetablesBroker.md`, `audit-clinic.md`, `audit-bookStore.md`, `audit-jewellery.md`, `audit-autoParts.md`, `audit-decorationCatering.md`, `audit-schoolErp.md`.

---

## 1. Executive Summary

DukanX has a **strong generic core** (billing, inventory, parties/ledger, GST reports, dashboards) that is largely backed by real local-first data (Drift) for the retail-style types. It also contains a **surprising amount of well-built, industry-specific code** — jewellery (8 screens), decoration & catering (16 screens), academic/school (34 screens), petrol pump (tanks/dispensers/shifts/fuel reports), computer-shop job cards, restaurant tables/KOT, pharmacy registers, and more.

The central problem is **not missing code — it is missing wiring and isolation.** Across the majority of business types, the specialized modules that already exist are **unreachable** from the running app, dashboards show **fabricated numbers**, and the capability/RBAC layers that are supposed to tailor and secure each vertical are **not enforced at the navigation layer**.

**Headline systemic findings (each affects many business types):**

1. **Two-tier sidebar reality.** Only 5 types have a dedicated sidebar (`clinic`, `pharmacy`, `restaurant`, `petrolPump`, `service`); `electronics`/`mobileShop`/`computerShop` share the generic retail sidebar; and **10 types fall through `default: _getRetailSections()`** (`grocery`, `clothing`, `hardware`, `wholesale`, `vegetablesBroker`, `bookStore`, `jewellery`, `autoParts`, `decorationCatering`, `schoolErp`). Source: `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` `_getSectionsForBusiness()`.

2. **Orphaned vertical modules (the biggest theme).** The live app runs the legacy `MaterialApp.routes` map (`app/app.dart`), while the rich `lib/modules/*` GoRouter modules and many `lib/features/*` screens are **never mounted/linked**. Confirmed orphaned (fully or partially): jewellery, decoration_catering, auto_parts, book_store, hardware, wholesale, school_erp/academic_coaching, computer_shop, mobile_shop, clothing. Net effect: vendors in these verticals see a generic retail app with their real tools hidden.

3. **Fabricated dashboard data.** `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart` returns **hardcoded literal counts** for almost every business type (e.g., pharmacy `'5'/'3'/'15'`, restaurant `'7'/'12'/'4'`, clinic `'18'/'7'`, wholesale `'15'/'7'`). **Only `grocery` reads live data** from `alertCountsProvider`. Several dashboard quick actions are dead (`onTap: () {}`): IMEI Lookup, Scan Barcode (grocery), Gold Rate / Custom Order (jewellery), ISBN Scan (bookStore).

4. **Capability & RBAC are not enforced where it matters.** Generic retail sidebar items carry **no `permission`** and almost no `capability`, so granted vertical capabilities gate nothing and sensitive items (financials, tax, audit, bank, backup) show to every role. `DesktopContentHost`/`getScreenForItem` render screens **without** the `VendorRoleGuard`/`BusinessGuard` that protect the equivalent named routes — a route-guard bypass.

5. **No vertical-specific roles.** `UserRole` (`core/models/user_role.dart`) is only `owner/manager/staff/accountant/unknown`. Missing: pharmacist, waiter/chef/captain, technician, doctor/receptionist/nurse, attendant/shift-operator, teacher/parent/student.

6. **Domain-correctness bugs.** Petrol fuel taxed at 18% GST (petrol/diesel are outside GST → VAT/excise) — **Critical**; clothing 5%/12% slab not implemented; books exempt vs 12% conflict; restaurant service charge/split-bill built but unwired; auto-parts job-status enum mismatch across UI/rules/backend; IMEI uniqueness not enforced (electronics/mobileShop).

**Overall product readiness: NOT production-ready as a multi-vertical product.** The generic retail/billing experience is broadly functional; the specialized verticals are mostly demo-grade (built but unreachable, with fake dashboards and unenforced isolation). See §7 for the scorecard.

---

## 2. Coverage & Methodology

- **Method:** Static, read-only source inspection of `Dukan_x/lib` (config, sidebar, navigation handler, capability registry, dashboard widgets, per-vertical `features/*` and `modules/*`), with grep-based reachability checks. No app was run; no build/test executed; no files changed.
- **Per type, each report covers 20 dimensions:** missing generic features, missing industry features, missing UI components, missing widgets/dashboards/KPIs, navigation/route gaps, backend integration, DB/API (real vs mock), responsive, performance, security/RBAC, offline/sync, business-logic inconsistencies, validation, UX, accessibility, bugs/crashes, unnecessary features, recommendations, and confidence/coverage.
- **Confidence:** High for structural findings (navigation, config, capability, dashboard wiring, orphaning) — these were read directly and grep-verified. Medium/Unverified for backend (Node/Lambda/DynamoDB) endpoint existence, runtime/responsive behavior, full RBAC matrices, and accessibility (which requires manual assistive-technology testing). Each per-type report has its own Confidence & Coverage section.
- **Not assessed:** the separate root-level apps (`school_admin_app/`, `school_teacher_app/`, `school_student_app/`, `school_common/`) beyond confirming they exist; backend handler internals; generated Drift code; test suites.

---

## 3. Systemic Issues (ranked, with affected business types)

### S1 — Orphaned vertical modules / dual-router split (CRITICAL)
The live app uses `MaterialApp.routes` (`app/app.dart`); the `lib/modules/*` GoRouter routes and `ModuleRegistry.buildNavItems()` are not consumed by the shell, and many `features/*` screens are not referenced by `sidebar_navigation_handler.getScreenForItem`.
- **Fully/largely orphaned:** jewellery (8 screens), decorationCatering (16 screens), autoParts (job cards), bookStore (5 screens), hardware (command center/operations/credit/supplier/delivery-challan), wholesale (module is redirect facade), schoolErp/academic_coaching (34 screens, 21 guarded routes never navigated to), clothing (variant matrix, tailoring).
- **Partially orphaned:** computerShop (job-cards/warranty/serial reachable only by typed route), mobileShop (repair/exchange reachable only via dashboard quick action; warranty/serial guarded to computerShop), restaurant (floor/recipe/KOT-report/pricing/owner-command screens not in sidebar).
- **Impact:** large amounts of built functionality are dead/unreachable; vendors get generic retail instead of their vertical.

### S2 — Fabricated dashboard alerts + dead quick actions (HIGH)
`business_alerts_widget.dart` hardcodes counts for all types except grocery; `_getTitle`/`_buildAlertsForBusiness` have **no case** for decorationCatering or schoolErp (fall to "No Active Alerts"). Dead `onTap: () {}` quick actions in grocery, electronics, mobileShop, computerShop, jewellery, bookStore.
- **Affected:** every type except grocery (alerts); electronics/mobile/computer/jewellery/bookStore/grocery (dead buttons).

### S3 — Capability & RBAC not enforced at navigation (HIGH / security)
Retail sidebar items have no `permission` and (except `batch_tracking`) no `capability`, so `sidebarSectionsProvider` filtering is a near-no-op; granted vertical capabilities gate nothing. `DesktopContentHost`/`getScreenForItem` renders screens without `VendorRoleGuard`/`BusinessGuard`, bypassing the protection applied to named routes.
- **Affected:** all retail-default + retail-trio types; route-guard bypass explicitly noted for service, mobileShop, hardware, clinic, bookStore (latent).

### S4 — Missing vertical RBAC roles (HIGH)
`UserRole` lacks pharmacist, waiter/chef/captain, technician, doctor/receptionist/nurse, attendant, teacher/parent/student. Capabilities like `useWaiterLinking` exist with no role to bind.
- **Affected:** pharmacy, restaurant, service, clinic, petrolPump, schoolErp.

### S5 — Tenant-scoping / `'SYSTEM'` constant bugs (CRITICAL where present)
Hardcoded tenant ids break multi-firm isolation and sync attribution.
- restaurant: 4 wired screens constructed with `vendorId:'SYSTEM'` → all restaurants share one bucket.
- clinic: `PatientRepository`/`AppointmentRepository` write `userId:'SYSTEM'`; `getPatientStats` has no tenant filter (cross-tenant patient leak).
- session_manager RBAC fallback to **owner** on auth/Firestore error (privilege escalation) — flagged in grocery audit.

### S6 — Offline-first inconsistency (HIGH)
Several vertical repositories are API-only with no Drift cache/queue, contradicting the app's offline-first claim: computerShop (`ComputerRepository`), hardware (`HardwareOpsRepository`), decorationCatering (`dc_repository`), schoolErp (`ac_repository`), jewellery custom orders (online-only while rest of module is offline), clothing screens (direct ApiClient), autoParts job cards. petrolPump has a **split datastore** (Drift vs API-via-firestore_compat) for different entities.

### S7 — Domain/tax & business-logic correctness (CRITICAL/HIGH)
- **petrolPump:** petrol/diesel hardcoded to 18% GST (should be outside GST / VAT) — Critical; fuel billing pipeline (`createFuelBill`) is dead code; meter-reading UI missing.
- **clothing:** 5%/12% value slab is only a comment, not implemented.
- **bookStore:** config 12% vs strategy "0% exempt"; POS computes no tax line.
- **jewellery:** flat 3% on entire subtotal; per-10g vs per-gram rate mismatch (10× risk); two divergent pricing engines.
- **restaurant:** service charge, split bill, happy-hour built but never wired into billing; `OrderType` lacks delivery/parcel; `isHalf`/`isParcel` config fields not rendered.
- **autoParts:** job-status enum mismatch across UI (`IN_PROGRESS/WAITING_PARTS/QUALITY_CHECK`) vs backend (`REPAIRING/AWAITING_PARTS/QC`) → server rejects updates.
- **service/computerShop:** status workflow not enforced; estimate→approval path broken (service).

### S8 — Real vs mock data (HIGH where present)
- bookStore inventory is a hardcoded sample list; POS product grid `itemCount: 0`.
- Dashboard alert counts (S2) are the most widespread mock-data instance.
- vegetablesBroker has two data stacks; the richer Stack A is fully orphaned.

### S9 — Duplicate/parallel implementations (MEDIUM/HIGH maintenance risk)
- clinic: `features/doctor/*` (sidebar) vs `features/clinic/*` (routes) — duplicate patient history/lab/consultation/dashboard.
- computerShop repair (`features/computer_shop`) vs generic service (`features/service`) — two job systems with different permissions.
- vegetablesBroker: orphaned API stack vs live Drift stack.

### S10 — Misleading/duplicate navigation mappings (MEDIUM)
Across all retail-default types, many ids collapse to the same screen: `audit_trail`/`activity_logs`/`transaction_reports`/`turnover_analysis`/`daily_activity`/`ledger_history` → `AllTransactionsScreen` (so "Audit Trail" is not a real audit log); `invoice_margin`+`income_statement` → `PnlScreen`; `funds_flow`+`cash_bank` → `CashflowScreen`; `print_settings`+`doc_templates` → `PrintMenuScreen`; `sync_status` → `BackupScreen`.

### S11 — Likely runtime crash (HIGH)
computerShop `WarrantyScreen`/`MultiUnitScreen`/`JobCardDetailScreen` use `TabBar` with no `TabController`/`DefaultTabController` → Flutter throws "No TabController" on open (flagged from code reading, not executed).

### S12 — Privacy/compliance for sensitive data (CRITICAL pre-production)
- clinic: patient PHI (allergies, conditions, diagnosis, private notes) stored plaintext, no consent flag, no access logging; "doctor-only" notes unenforced (no doctor role); no allergy↔prescription contraindication check.
- schoolErp: minors' PII (students, siblings, ID cards, documents) with generic retail permissions and no special controls.
- jewellery: old-gold-exchange KYC (PMLA) PII stored without redaction/encryption.
- pharmacy: schedule H/H1/X Rx enforcement half-wired (validation exists, POS never captures prescriptionId).

### S13 — Validation gaps (MEDIUM, widespread)
Silent `?? 0` / `?? 1` parsing, unclamped discount %, no IMEI/ISBN checksum at entry, no gross≥tare guard (mandi), no serial uniqueness, free-text vitals, etc. — present in most verticals.

---

## 4. Common Issues by Category (consolidated)

- **Navigation/Route gaps:** orphaned vertical screens (S1); dead dashboard links (S2); placeholder/duplicate id mappings (S10); module navItems never rendered.
- **Backend integration:** real REST/Lambda surfaces exist (auto-parts, dc, ac, computer, hardware, jewellery, book_store) but are unconsumed or consumed only by orphaned screens; several sync handlers point at collections with no producing UI.
- **Database/API:** hardcoded dashboard counts (S2); bookStore mock inventory; paise↔rupee display bugs (autoParts `estimatedCostPaisa`, computerShop); `'SYSTEM'` tenant ids (S5).
- **Responsive:** generally uses shared `responsive.dart`/`BoundedBox`; specific risks — restaurant KDS fixed 3-column, bookStore POS `maxWidth:800` for a 3-pane POS, several hardcoded light-theme screens (clothing, computerShop, mandi sheet).
- **Performance:** per-keystroke full-list refilter (service, clothing, mobileShop, computerShop); N+1 fetches (clothing variants, dc adjustInventory, hardware refreshAll sequential); load-all-then-count queries (clinic, service).
- **Security/RBAC:** S3, S4, S5, S12; "audit trail" is a transaction list, not a real audit log.
- **Offline/sync:** S6; conflict resolution largely unverified; broker tables lack sync columns.
- **Business logic:** S7; status-enum/workflow mismatches; estimate/advance/commission math inconsistencies.
- **Validation:** S13.
- **UX:** vertical vendors land in generic retail; fake counts erode trust; dead buttons; misleading labels.
- **Accessibility:** icon-only buttons without semantics/tooltips; color-only status cues; hardcoded low-contrast palettes; **full WCAG conformance not validated (requires manual AT testing)**.

---

## 5. Business-Type-Specific Critical Gaps (one line each)

- **grocery:** Weighing-scale widget orphaned; expiry self-contradiction (`useBatchExpiry` granted but `supportsExpiry` hardcoded false); dead "Scan Barcode" dashboard button. (Best dashboard data fidelity of all types.)
- **pharmacy:** Schedule-drug Rx enforcement half-wired (POS never sets `prescriptionId`); dedicated PharmacyDashboard/SaltSearch/PatientRegistry orphaned; H1 Register dead link; no `pharmacist` role; MRP not enforced; single fixed 12% GST.
- **restaurant:** `vendorId:'SYSTEM'` tenant bug; service charge/split-bill/half-portion/parcel built but unwired; no delivery order type; ~11 owner screens orphaned; fake alert counts; no waiter/chef roles.
- **clothing:** Variant matrix/tailoring orphaned; variant grid `onQuantitiesChanged` discards edits (data loss); GST slab not implemented; `/clothing/variants` API key mismatch (`items` vs `variants`).
- **electronics:** Warranty/serial screens guarded to computerShop only (electronics denied despite capabilities); IMEI uniqueness not enforced; `ImeiTrackingStatementScreen` orphaned; no `features/electronics/`.
- **mobileShop:** `IMEIValidationService` never injected (IMEIs silently unrecorded); warranty/serial guarded out; repair/exchange only via dashboard; no second-hand inventory; fake counts.
- **computerShop:** Entire job-card/warranty/serial module reachable only by typed route (dedicated sidebar widget never wired); likely TabBar crash; status cannot be advanced from UI; online-only (no offline).
- **hardware:** Two dead dashboard CTAs ("Projects", "Delivery Challan" → "Feature Not Found"); full hardware ops/credit/supplier suite orphaned; `returns`/`quotations` modules advertised but capabilities denied.
- **service:** Route-guard bypass via content_host; estimate→approval workflow dead (missing menu handler); parts never loaded (invoices labor-only); notifications service never called; device fields wrongly required for non-device services.
- **wholesale:** No dedicated UI; `modules/wholesale` is a redirect facade ("tiered pricing"→proforma, "e-Way"→challan); no slab pricing/rate lists/credit-limit/e-Way; fake counts.
- **petrolPump:** Fuel GST wrong (18% vs VAT) — Critical; fuel billing pipeline dead; split datastore; no dispenser/nozzle/meter-reading UI; rich RevenueDashboard orphaned; fake counts.
- **vegetablesBroker:** No presentation layer at all; two disconnected data stacks (orphaned API stack + local Drift); commission flat↔% round-trip; labor/market-fee dropped; no patti/settlement screen.
- **clinic:** Cross-tenant patient leak + `userId:'SYSTEM'`; PHI plaintext + no consent; no clinical roles; duplicate doctor/clinic stacks; `patient_history` miswired; inventory three-way contradiction.
- **bookStore:** All 5 book screens orphaned; inventory is mock sample data; POS computes no GST; 3 inconsistent ISBN validators; fake counts; fake loyalty (uses `totalPaid`).
- **jewellery:** Entire 8-screen module orphaned (`jewellery_integration.dart` dead code with shadow GoRoute classes); no jewellery domain capabilities; per-10g vs per-gram 10× risk; dead quick actions; mojibake in calculator output.
- **autoParts:** Job-card module orphaned + "New Job Card" dead link; status enum mismatch (server rejects); warranty alert gated on wrong capability (`useIMEI` not `useWarranty`); paise→rupee 100× display bug; fitment/OEM cross-ref backend unused.
- **decorationCatering:** 16-screen vertical has no entry point; 8 screens have no route at all; `/dc/vendors`→`DcStaffScreen` bug + self-redirect loop; no DC dashboard/quick-action/alert cases; `rentalPrice` hardcoded 0; discount % unclamped → negative totals.
- **schoolErp:** Retail sidebar for a school (fundamentally wrong); 34 academic_coaching screens + 21 guarded routes unreachable; no school roles; minors' PII under retail permissions; real product lives in separate `school_*_app/` projects.

---

## 6. Consolidated Prioritized Implementation Roadmap

> Phase 2 detailed planning should be done per business type. This is the cross-cutting sequence.

### P0 — Critical (correctness, security, data integrity)
1. **Fix tenant scoping:** eliminate literal `vendorId:'SYSTEM'`/`userId:'SYSTEM'` (restaurant, clinic); use `SessionManager.currentBusinessId`; add tenant filter to `getPatientStats`. Review the owner-on-error RBAC fallback in `session_manager`.
2. **Fix petrol fuel taxation** (VAT/non-GST, not 18% GST) and wire the fuel billing pipeline so sales move tank stock/readings.
3. **Apply route guards on the in-shell path** (`DesktopContentHost`/`getScreenForItem`) so capability/role/business isolation is actually enforced.
4. **Resolve confirmed crash/data-loss bugs:** computerShop TabBar-without-controller; clothing variant grid discarding edits; mobileShop IMEIValidationService injection; autoParts job-status enum unification.
5. **PHI/minor-PII safeguards** (clinic, schoolErp, jewellery KYC): consent flags, access logging, role-scoped access before any production use.

### P1 — High (make the product actually multi-vertical)
6. **Add dedicated sidebar sections** for the 10 retail-default types (and split the electronics/mobile/computer trio) via `_getSectionsForBusiness`, and **wire the orphaned screens** into `getScreenForItem` (or decide GoRouter migration). This single workstream un-orphans jewellery, dc, autoParts, bookStore, hardware, wholesale, schoolErp, clothing, computerShop.
7. **Replace hardcoded dashboard alert counts** with live queries per type; add missing `business_alerts_widget`/`business_quick_actions` cases (dc, schoolErp); fix all dead `onTap: () {}` actions.
8. **Add vertical RBAC roles** (pharmacist, waiter/chef, technician, doctor/receptionist, attendant, teacher/parent) and gate sidebar items with `permission:`/`capability:`.
9. **Wire built-but-unconnected logic:** restaurant service-charge/split-bill/half-portion/parcel + delivery order type; pharmacy Rx gate + MRP enforcement; service estimate→approval + parts; clothing GST slab.
10. **Offline-first parity:** add Drift cache/sync to API-only vertical repos (computerShop, hardware, dc, ac, jewellery custom orders, autoParts); unify petrolPump datastore.

### P2 — Medium
11. De-duplicate parallel stacks (clinic doctor/clinic; computerShop repair vs service; mandi stack A/B).
12. De-duplicate/relabel misleading nav mappings; implement a real audit-trail screen.
13. Fix money-unit bugs (paise↔rupee), validation gaps (clamp discounts, checksum IMEI/ISBN, gross≥tare), and per-keystroke/N+1 performance issues.
14. Industry depth: e-Way bill (wholesale/electronics/hardware), fitment/OEM (autoParts), rental lifecycle (dc), gold rate feed + repricing (jewellery), weighbridge/density (petrol), multi-day events (dc).

### P3 — Low
15. Accessibility pass (semantics/tooltips, contrast, text scaling) across verticals — then commission manual WCAG validation.
16. Theme-aware colors (remove hardcoded light palettes); fix mojibake (jewellery, petrol); trim irrelevant retail items behind sign-off.

---

## 7. Overall Product Readiness Assessment

**Readiness tiers (based on: dedicated UX, reachable features, real data, isolation, domain correctness):**

| Tier | Meaning | Business types |
|---|---|---|
| **B — Usable generic core; vertical depth thin** | Dedicated or shared sidebar, real data for core flows, but missing/auto-only vertical features and fake dashboard alerts | grocery, pharmacy, restaurant, clinic, petrolPump, service |
| **C — Generic-retail shell; vertical exists but mostly unreachable** | Falls to retail sidebar or shares it; specialized module built but orphaned; fake dashboards; isolation not enforced | electronics, mobileShop, computerShop, clothing, hardware, bookStore, jewellery, autoParts, decorationCatering, wholesale |
| **D — Misclassified / wrong shell** | Fundamentally wrong UX or no presentation layer | vegetablesBroker (no UI layer), schoolErp (retail sidebar for a school; real product in separate apps) |

No business type reaches an "A — production-ready vertical" tier under this audit. The **generic retail/billing core** (Tier B types' shared flows) is the strongest asset and is closest to production; the **specialized verticals** are predominantly demo-grade due to orphaning, fake dashboards, and unenforced isolation.

**Bottom line:** DukanX is best described as a solid generic-retail billing app with a large library of **unwired** vertical features. The fastest path to a credible multi-vertical product is **wiring and isolation work (P0–P1)** — not new feature development. Most "missing" industry features already exist in code; they are unreachable, unsecured, or fed by mock data.

---

## 8. Confidence & Coverage (master)

- **High confidence:** sidebar resolution per type, config/capability registries, dashboard widget wiring (hardcoded counts), navigation-handler mappings, and orphaned-module findings — all read directly and grep-verified across the 18 reports.
- **Medium/Unverified:** backend (Lambda/DynamoDB/Node) endpoint existence and correctness; runtime/responsive behavior; whether any loader mounts the GoRouter modules at runtime; full `RolePermissions` matrices; conflict-resolution in sync engines.
- **Explicitly not validated:** accessibility/WCAG conformance (requires manual assistive-technology testing and expert review); the standalone `school_*_app/` projects' internals; performance under production data volumes.
- **Per-type detail:** each `audit-{type}.md` contains its own file-cited findings, priorities, recommended solutions, and a Confidence & Coverage section. This master report does not restate every citation; it aggregates and ranks.

*End of master report. No source files were modified during this audit — deliverables are the 18 per-type reports plus this summary, all under `audit-reports/`.*
