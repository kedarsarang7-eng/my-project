# DukanX Business-Type Audit — Decoration & Catering (`decorationCatering`)

**Scope:** READ-ONLY, evidence-based audit of the `decorationCatering` (Decoration & Catering / Events) business type.
**Method:** Every "missing/broken/orphaned" claim cites the file/function inspected. Items not verified are marked **unverified**.
**Date sampled:** generated from source tree under `g:\desktop app genuine\Dukan_x\lib`.

---

## 1. Header — Resolution, Config, Capabilities

### 1.1 Enum & display
- `BusinessType.decorationCatering` is declared in `Dukan_x/lib/models/business_type.dart` (enum entry `decorationCatering`), with `displayName` = "Decoration & Catering", `icon` = `Icons.celebration_rounded`.
- Emoji/colors in `Dukan_x/lib/core/billing/business_type_config.dart` (`BusinessTypeConfigExtension`): emoji `🎪`, `primaryColor` Rose `0xFFE11D48`, `pdfPrimaryColor` `#E11D48`.

### 1.2 Billing config (verified)
`Dukan_x/lib/core/billing/business_type_config.dart`, `BusinessTypeRegistry._configs[BusinessType.decorationCatering]`:
- `requiredFields`: `itemName`, `quantity`, `price`
- `optionalFields`: `notes`, `gst`, `discount`
- `defaultGstRate`: `18.0`, `gstEditable`: `true`
- `unitOptions`: `pcs`, `set`, `nos`
- `itemLabel`: `'Service/Item'`, `addItemLabel`: `'Add Service/Item'`, `priceLabel`: `'Charge'`
- `modules`: `['events','sales','caterers','inventory','reports']`

### 1.3 Sidebar resolution (verified)
`Dukan_x/lib/widgets/desktop/sidebar_configuration.dart`, `_getSectionsForBusiness(BusinessType type)` has **no `case BusinessType.decorationCatering`** → falls to `default: return _getRetailSections();`. So a Decoration & Catering tenant sees the full **generic retail** sidebar (Revenue Desk, BuyFlow, Inventory & Stock, Parties & Ledger, Business Intelligence, Financial Reports, Tax & Compliance, Operations & Logs, Utilities).

### 1.4 Capabilities (verified)
`Dukan_x/lib/core/isolation/business_capability.dart`, `businessCapabilityRegistry['decorationCatering']` grants:
- Invoice: `useInvoiceCreate`, `useInvoiceList`, `useInvoiceSearch`, `useProformaInvoice`
- Vertical: `useDecorationThemes`, `useCateringMenu`, `useCateringKitchen`, `useVenueManagement`, `useEventBooking`, `useEventInventory`, `useEventStaffAllocation`, `useEventReports`, `useAppointments`, `useLaborCharges`
- Comment in source: *"Service-only: no product or inventory capabilities"* — so NO `useProductAdd`, `useInventoryList`, `useStockEntry`, `useLowStockAlert`, `useDailySnapshot`, `useRevenueOverview`, etc.

### 1.5 Rich feature folder (verified) — 16 screens
`Dukan_x/lib/features/decoration_catering/` contains a complete vertical:
- **Models:** `data/models/dc_models.dart`
- **Repository:** `data/repositories/dc_repository.dart` (real API, `/dc/*`)
- **Service:** `services/dc_pdf_service.dart`
- **Utils:** `utils/decoration_catering_business_rules.dart`
- **Screens (16):** `dc_billing_screen`, `dc_bookings_screen`, `dc_calendar_screen`, `dc_catering_screen`, `dc_dashboard_screen`, `dc_decoration_screen`, `dc_event_detail_screen`, `dc_inventory_screen`, `dc_profitability_screen`, `dc_quote_conversion_screen`, `dc_quotes_screen`, `dc_reports_screen`, `dc_shopping_list_screen`, `dc_staff_attendance_screen`, `dc_staff_screen`, `dc_vendor_payments_screen`
- **Widgets (4):** `dc_booking_form`, `dc_status_badge`, `dc_ui_kit`, `dc_vendor_rating_dialog`

**Headline finding:** This is one of the richest verticals in the app, yet it is **almost entirely unreachable** from the running UI because the sidebar resolves to generic retail and nothing surfaces the `/dc/*` routes. Details in §6.

---

## 2. Missing Generic Features (Vyapar benchmark)

Evaluated against the running sidebar (`_getRetailSections`) + handler (`sidebar_navigation_handler.dart`) + capability registry.

| # | Vyapar feature | Status for DC | Evidence |
|---|----------------|---------------|----------|
| 1 | Billing | Present (generic `new_sale` → `BillCreationScreenV2`; DC-specific `DcBillingScreen` exists but orphaned) | `sidebar_navigation_handler.dart` `case 'new_sale'`; `dc_billing_screen.dart` |
| 2 | Inventory | Present generically but **forbidden by capability** (`decorationCatering` has no inventory capability) — inconsistency | `business_capability.dart` registry; sidebar Inventory section still shown |
| 3 | Barcode/POS | Not relevant; `useBarcodeScanner` not granted | `business_capability.dart` |
| 4 | Accounting | Generic screens exposed (`accounting_reports`, `daybook`) | `sidebar_navigation_handler.dart` |
| 5 | Receivables/Payables | Generic `outstanding`/`party_ledger`; DC `dc_vendor_payments_screen` exists but orphaned | handler + §6 |
| 6 | Bank/Cash | Generic `bank_accounts`, `cash_bank` | handler |
| 7 | Orders/Delivery | Event bookings exist (`dc_bookings_screen`) but orphaned; generic `booking_orders` shown | §6 |
| 8 | OCR | `useScanOCR` not granted | `business_capability.dart` |
| 9 | Reports | `dc_reports_screen` exists but orphaned; generic reports shown | §6 |
| 10 | RBAC + audit | Present via `VendorRoleGuard`/`BusinessGuard` on `/dc/*` routes; audit trail generic | `app/routes.dart` |
| 11 | Multi-firm | **unverified** (not inspected) | — |
| 12 | Backup | Generic `backup` item | handler |
| 13 | Online store | **unverified** | — |
| 14 | e-Way bill | Not applicable to services; absent | — |
| 15 | Loyalty | `useLoyaltyPoints` not granted to DC | `business_capability.dart` |
| 16 | Service | Strong vertical exists (events/catering/staff) but orphaned | §6 |
| 17 | Offline-first sync | **Gap** — `dc_repository.dart` is API-only, no Drift/local cache | §12 |

**Priority — Critical:** The generic billing path (`new_sale` → `BillCreationScreenV2`) uses product/line-item retail billing, not the event/quote/advance model the DC config implies (`itemLabel 'Service/Item'`, `priceLabel 'Charge'`). The DC-native billing (`DcBillingScreen`) is not wired into the sidebar.

---

## 3. Missing Industry-Specific Features (Decoration & Catering)

The vertical code mostly implements these, but reachability is the blocker (§6). Functional gaps within the existing code:

| Need | Implemented? | Evidence / Gap | Priority |
|------|--------------|----------------|----------|
| Event booking (date/venue/guests) | Yes (model + screen) | `dc_models.dart` `EventBooking` (customer, eventType, eventDate, venue, guestCount); `dc_bookings_screen.dart` | — |
| Event calendar | Yes (screen) | `dc_calendar_screen.dart` (orphaned) | High (orphaned) |
| Quotation → advance → final invoice | Partial | `dc_quotes_screen.dart`, `dc_quote_conversion_screen.dart`, `dc_billing_screen.dart`; conversion does not record a discrete payment ledger entry (sets `advancePaid` only) | High |
| Menu/package builder (per-plate) | Yes | `dc_catering_screen.dart`, `CateringPackage.pricePerPlate`, `CateringMenuItem.pricePerPlate` in `dc_models.dart` | — |
| Decoration rental inventory (in/out, damage) | **Partial/Weak** | `dc_inventory_screen.dart` + `DcRepository.adjustInventory(id, delta)`; **`rentalPrice` hardcoded `0`** in `_inventoryFromJson` (`dc_repository.dart`); no rent-out/return or damage-loss tracking per event | High |
| Staff/labor scheduling & attendance | Yes | `dc_staff_screen.dart`, `dc_staff_attendance_screen.dart`, `DcRepository.markAttendance` | — |
| Vendor/sub-contractor mgmt & payments | Yes | `dc_vendor_payments_screen.dart`, `dc_vendor_rating_dialog.dart`, `DcRepository.getVendors/createVendor` | High (orphaned) |
| Procurement/shopping list per event | Yes | `dc_shopping_list_screen.dart`, `DcRepository.getShoppingList(eventId)` | High (orphaned) |
| Event profitability (cost vs revenue) | Yes | `dc_profitability_screen.dart`, `DcRepository.getEventProfitability(eventId)` | High (orphaned) |
| Advance/installment payments | Partial | `DcRepository.recordPayment(DcPayment)`; `getPayments` derives "payments" from `advancePaidPaisa` on invoices — single-advance model, not true installment ledger | Medium |
| Multi-day events | **Missing** | `EventBooking` in `dc_models.dart` has a single `eventDate` (no end date / day range) | Medium |
| Guest-count-based scaling | Partial | `dc_billing_screen.dart` `_addDefaultItems` sets catering line qty = `booking.guestCount`; no auto package `minGuests` enforcement at billing | Medium |
| Rental return tracking | **Missing** | No return/overdue tracking; `adjustInventory` is a raw delta only | High |

---

## 4. Missing UI Components

- **No DC entry point in the desktop shell.** `sidebar_configuration.dart` has no DC section; users cannot open any DC screen from the chrome. (Critical — see §6.)
- **Event date/venue/guest pickers** exist only inside orphaned screens (`dc_booking_form.dart`); not surfaced.
- **Generic billing UI mismatch:** `BillCreationScreenV2` (reached via `new_sale`) is product/stock oriented; no per-plate or per-event composer in the reachable path. (High)
- **Placeholder fallback:** any unknown sidebar id renders `_PlaceholderScreen` ("Feature Not Found") — `sidebar_navigation_handler.dart` `default:`. No DC ids exist there, so even if DC ids were added to a sidebar they would hit the placeholder. (High)

---

## 5. Missing Widgets & Dashboard/KPI Cards

### 5.1 Quick Actions (verified)
`Dukan_x/lib/features/dashboard/v2/widgets/business_quick_actions.dart`, `_buildActionsForBusiness`:
- **No `case BusinessType.decorationCatering`** → falls to `default:` which renders only generic "Add Customer" + "Reports".
- The leading "New Sale" appears because `caps.accessInvoiceCreate` is true; the trailing "Alerts" does **not** appear because `caps.accessLowStockAlert` is false for DC (`business_capability.dart` grants no `useLowStockAlert`).
- **Result:** DC dashboard quick actions = New Sale + Add Customer + Reports. No "New Booking", "Add Staff", "Menu", "Themes", "Quote". (High)

### 5.2 Alerts Widget (verified)
`Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart`:
- `_getTitle`: **no `decorationCatering` case** → default `'Business Alerts'`.
- `_buildAlertsForBusiness`: **no `decorationCatering` case** → default single item `'No Active Alerts' / 'Business running smoothly'` (count `0`).
- **Hardcoded counts confirmed** for most non-grocery types (e.g. pharmacy `'5'`,`'3'`,`'15'`; restaurant `'7'`,`'12'`,`'4'`; clinic `'18'`,`'7'`). Only `grocery` uses live counts from `alertCountsProvider`. DC gets no event-specific alerts (e.g. "Events This Week", "Advance Pending", "Rentals Due Back"). (High)

### 5.3 DC dashboard KPIs (exist but orphaned)
`dc_dashboard_screen.dart` consumes `dcStatsProvider` → `DcRepository.getDashboardStats()` (`GET /dc/dashboard`) — real KPI cards exist, but the screen is unreachable (§6).

---

## 6. Navigation & Route Gaps (Critical Section)

### 6.1 Retail sidebar ids → do they resolve?
All ids produced by `_getRetailSections()` resolve to real screens in `sidebar_navigation_handler.getScreenForItem` (e.g. `executive_dashboard`→`DashboardController`, `new_sale`→`BillCreationScreenV2`, `stock_summary`→`StockSummaryScreen`, `gstr1`→`GstReportsScreen`). No DC id is present in the handler `switch`; unknown ids → `_PlaceholderScreen`. **So the reachable screens for a DC tenant are entirely generic retail screens.**

### 6.2 Are the 16 DC screens reachable? — Largely ORPHANED
- **Legacy named-routes exist** in `Dukan_x/lib/app/routes.dart` (`MaterialApp.routes`) for DC, each wrapped in `VendorRoleGuard` + `BusinessGuard(allowedTypes:[decorationCatering])`:
  `/dc/dashboard`→`DcDashboardScreen`, `/dc/bookings`(+`/new`)→`DcBookingsScreen`, `/dc/decoration`→`DcDecorationScreen`, `/dc/catering`→`DcCateringScreen`, `/dc/staff`→`DcStaffScreen`, `/dc/vendors`→**`DcStaffScreen`** (bug, see §17), `/dc/inventory`(+`_low`)→`DcInventoryScreen`, `/dc/reports`→`DcReportsScreen`, `/dc/expense_report`→`DcReportsScreen`, `/dc/billing`→`DcBillingScreen`, `/dc/kitchen`→`DcCateringScreen`, `/dc/venue`→`DcDecorationScreen`.
- **No code navigates to `/dc/dashboard` (or any DC entry) from outside the feature.** `grep "/dc/dashboard"` and `grep DcDashboardScreen` (across `lib/**`) return only: the route definition in `app/routes.dart`, the repository API string, and the class definition. **Nothing pushes the DC home route.** → The DC vertical has **no entry point** in the running app.
- **In-feature navigation does exist:** `dc_dashboard_screen.dart` pushes `/dc/bookings/new`, `/dc/billing`, `/dc/staff`, `/dc/inventory`, `/dc/catering`, `/dc/decoration`, `/dc/reports`. So *if* a user reached the DC dashboard, intra-vertical nav works. But they can't reach it.
- **Screens with NO legacy route at all** (orphaned even by deep-link): `dc_calendar_screen` (`DcCalendarScreen`), `dc_quotes_screen` (`DcQuotesScreen`), `dc_profitability_screen` (`DcProfitabilityScreen`), `dc_shopping_list_screen` (`DcShoppingListScreen`), `dc_vendor_payments_screen` (`DcVendorPaymentsScreen`), `dc_event_detail_screen` (`DcEventDetailScreen`), `dc_quote_conversion_screen` (`DcQuoteConversionScreen`), `dc_staff_attendance_screen` (`DcStaffAttendanceScreen`). Confirmed via `grep` of each class name — references only in their own files + `test/`. (Critical)
- **Barrel omission:** `decoration_catering.dart` barrel does **not** export `dc_event_detail_screen`, `dc_quote_conversion_screen`, `dc_staff_attendance_screen`, or `dc_vendor_rating_dialog` — only referenced in `test/dc_enhancements_test.dart`. (Medium)

### 6.3 The go_router module is not the active router
`Dukan_x/lib/modules/decoration_catering/decoration_catering_module.dart` defines 8 `navItems` (Events/Themes/Menu/Staff/Vendors/Billing/Expenses/Reports) and `routes` (`decoration_catering_routes.dart`). But `legacy_route_redirect.dart` documents that the app still uses `MaterialApp.routes` (legacy), not `routerConfig`. The desktop sidebar is the hardcoded retail one (`sidebar_configuration.dart`), which does **not** render module `navItems`. So the module's nav is **dormant**. (Critical)

### 6.4 Redirect defects in the module routes
`decoration_catering_routes.dart`:
- `/dc/vendors` → `LegacyRouteRedirect(legacyRoute: '/dc/vendors')` — **redirects to itself** (potential loop / no-op). (High)
- `/dc/events`→`/dc/bookings`, `/dc/themes`→`/dc/decoration`, `/dc/menu`→`/dc/catering`, `/dc/invoices`→`/dc/billing`, `/dc/expenses`→`/dc/expense_report` rely on legacy targets that exist only in `MaterialApp.routes`; under a pure go_router build these legacy `Navigator.pushReplacementNamed` targets would not resolve. (Medium, conditional on migration)

### 6.5 Capability vs route mismatch
- Capability registry says DC is "service-only: no product or inventory", yet `app/routes.dart` exposes `/dc/inventory` and the retail sidebar exposes full Inventory/BuyFlow/Stock — see §11 capability-bypass.

---

## 7. Backend Integration Gaps

`Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart` (header: "REPOSITORY (Real API)") wires a broad `/dc/*` surface via `sl<ApiClient>()`:
- Bookings: `GET/POST/PUT/DELETE /dc/events`, `PUT /dc/events/{id}` (status, staff), `POST /dc/events/{id}/payments`, `POST /dc/events/{id}/notes`, `GET /dc/events/{id}/shopping-list`, `GET /dc/events/{id}/profitability` (path truncated in read but method `getEventProfitability` present).
- Staff: `GET/POST/DELETE /dc/staff`, `POST /dc/staff/attendance`.
- Vendors: `GET/POST/DELETE /dc/vendors`.
- Inventory: `GET/POST/PUT /dc/inventory`.
- Menu/Packages/Themes: `GET/POST /dc/menu`, `/dc/packages`, `/dc/themes`.
- Expenses: `GET/POST /dc/expenses`.
- Invoices: `POST/GET /dc/invoices`.
- Quotes: `GET/POST/PUT/DELETE /dc/quotes`.

**Gaps:**
- **No DC backend handler verified in this audit.** The presence of `/dc/*` calls does not confirm a deployed Lambda. The actual backend endpoints are **unverified** (server code not inspected). (High — verify deployment)
- `DcRepository.adjustInventory` does a **read-all-then-PUT** (`getInventory()` then `PUT /dc/inventory/{id}`) — N+1 / race-prone; no atomic delta endpoint. (Medium)
- `getPayments` reuses `GET /dc/invoices` and maps `advancePaidPaisa` as the payment amount — no dedicated payments-ledger endpoint. (Medium)

---

## 8. Database & API Issues (real vs mock, hardcoded)

- **Real API, not mock:** `dc_repository.dart` uses `ApiClient` against `/dc/*`. Amounts handled in paise (`_toPaisa`/`_paisa`). (Good)
- **Hardcoded alert counts:** `business_alerts_widget.dart` uses literal strings for nearly all business types; DC falls to default "0/No Active Alerts" (see §5.2). (High)
- **`rentalPrice` hardcoded to `0`** in `_inventoryFromJson` (`dc_repository.dart`) — rental pricing field exists in `DcInventoryItem` but is never populated from the API. (High for a rental-centric business)
- **Lossy field mapping:** `_expenseFromJson` hardcodes `paymentMethod: PaymentMethod.cash`; `_vendorPaymentFromJson`/`getPayments` also default `paymentMode`/`method` to cash regardless of stored value. (Medium — data fidelity)
- **No local persistence:** repository has no Drift/`AppDatabase` usage; all providers are `FutureProvider.autoDispose` hitting the network. (Offline gap — §12.)
- **Date truncation:** booking create/update sends `eventDate.toIso8601String().substring(0,10)` — drops time-of-day; setup/service times are separate string fields, so date+time coherence is **unverified**. (Low/Medium)

---

## 9. Responsive Design

- DC screens use the project `responsive` helpers: `dc_billing_screen.dart` imports `core/responsive/responsive.dart` and uses `responsiveValue<T>(context, mobile/tablet/desktop)` plus `BoundedBox(maxWidth: 800)`; layout switches Row↔Column by breakpoint. (Good, where reachable)
- `back_affordance_enumeration_test.dart` includes several DC screens in responsive back-affordance enumeration — indicates responsive coverage is tracked. (Good)
- **unverified:** pixel-level overflow behavior on small screens (not run).

---

## 10. Performance

- `DcRepository.adjustInventory` fetches the **entire** inventory list to find one item before a PUT — O(n) network + race window. (Medium)
- Dashboard/list providers are `autoDispose` with no caching → re-fetch on each screen entry; acceptable but no offline/stale-while-revalidate. (Low/Medium)
- `dc_billing_screen.dart` `_addDefaultItems` performs sequential `getThemes()` then `getPackages()` awaits on event selection — two serial round-trips on the UI path. (Low)
- No obvious heavy build loops; lists use `Table`/`map`. (Low)

---

## 11. Security (RBAC, capability-bypass)

- **Route RBAC present:** every `/dc/*` legacy route in `app/routes.dart` is wrapped in `VendorRoleGuard(requiredPermission: …)` + `BusinessGuard(allowedTypes:[BusinessType.decorationCatering])`. Permissions used: `viewInvoices`, `createInvoices`, `viewReports`. (Good)
- **Capability-bypass via retail sidebar (High):** `business_capability.dart` declares DC has **no** product/inventory/purchase capabilities, but the reachable retail sidebar (`_getRetailSections`) exposes Inventory, BuyFlow (Purchase Orders, Stock Entry, Supplier Bills), Stock Valuation, etc. Most of these `SidebarMenuItem`s carry **no `capability:`**, so `sidebarSectionsProvider`'s `FeatureResolver.canAccess` filter never excludes them, and `getScreenForItem` returns real screens (`InventoryDashboardScreen`, `StockEntryScreen`, …) with **no `BusinessGuard`**. → A DC tenant can operate product/inventory features that hard-isolation says are forbidden. (High)
- **Permission semantics mismatch (Low):** DC functional actions (create booking, assign staff, mark attendance) are gated by invoice permissions (`viewInvoices`/`createInvoices`) rather than event/staff-specific permissions. (Low)

---

## 12. Offline Mode Gaps

- **No offline support for DC.** `dc_repository.dart` calls `ApiClient` directly with no Drift cache, no queue, no optimistic local store. Compare with the alerts widget, which reads Drift (`db.productBatches`) for retail. (High)
- The module declares a `DecorationCateringSyncHandler` (`collection: 'dc_events'`, `apiBasePath: '/dc/events'`) and `DecorationCateringWsHandler` (events `dc.event.confirmed`, `dc.payment.received`, `dc.staff.assigned`) — but these belong to the dormant module system (§6.3) and there is **no verified local table** they sync into. (High — sync is scaffolding, not wired to UI)

---

## 13. Business Logic Inconsistencies (quote/advance/profitability math)

- **Quote total math** (`utils/decoration_catering_business_rules.dart` `computeQuoteTotal`): `perHeadPrice × headcount − discount + taxAmount`, half-up rounded via `MoneyMath.roundTo2`. Guards `headcount < 0 → 0`. (Correct, but `discount`/`tax` are absolute amounts here, while billing screen uses **percentages** — two different models, see below.) (Medium)
- **Billing screen math** (`dc_billing_screen.dart`): `subtotal = Σ qty×rate`; `discountAmt = subtotal × discount%/100`; `taxableAmt = subtotal − discountAmt`; `gstAmt = taxableAmt × gstPct/100`; `total = taxableAmt + gstAmt`; `balance = (total − advancePaid).clamp(0, ∞)`. Internally consistent, but **discount/GST are percentages** whereas `DecorationCateringBusinessRules.computeQuoteTotal` treats them as **absolute amounts** — divergent quote vs invoice math. (Medium)
- **Advance default = 100% of total** (`dc_quote_conversion_screen.dart` `initState`: `_advanceCtrl.text = widget.quote.total.toStringAsFixed(0)`). Defaulting an "advance" to the full amount is unusual and error-prone. (Medium)
- **Advance not validated against total:** `_convertToBooking` only rejects `advance < 0`; an advance greater than the quote total is accepted. (Medium)
- **Advance is not recorded as a payment ledger entry on conversion** — only stored as `EventBooking.advancePaid` and sent as `advanceAmountPaisa`. `recordPayment`/`/dc/events/{id}/payments` is a separate flow not invoked here. (Medium)
- **Profitability math unverified** — `getEventProfitability` returns a server-computed `Map`; the cost/revenue formula lives server-side (not inspected). (unverified)
- **`advanceForfeitedOnCancel`** (business rules) implements a 7-day lock-in forfeit policy but is **not referenced** by any screen in the reachable/booking flow (grep shows usage only in `test/`). (Low — dead policy)

---

## 14. Data Validation Issues

`dc_billing_screen.dart`:
- Qty field: `int.tryParse(v) ?? 1` — empty/invalid silently becomes 1; **negative quantities accepted** (no `>0` check). (Medium)
- Rate field: `double.tryParse(v) ?? 0` — negatives accepted. (Medium)
- Discount %: `double.tryParse(v) ?? 0` — **no clamp to 0–100**; >100% would make `taxableAmt` negative. (High)
- GST %: `double.tryParse(v) ?? 18` — unbounded. (Medium)
- "Generate Invoice" enabled when `_items.isNotEmpty` even if **no event is selected** (`eventId` sent as `''`). (Medium)
- No validation that line-item descriptions are non-empty. (Low)

`dc_quote_conversion_screen.dart`:
- Only `advance < 0` is rejected; no upper bound; `eventDate` defaults to `now + 7 days` if quote has no date. (Medium)

---

## 15. UX Problems

- **Dead-end vertical:** the entire DC experience is invisible to users (no sidebar entry). A Decoration & Catering owner logs in and sees a generic retail dashboard with irrelevant BuyFlow/GST/Stock menus. (Critical UX)
- **Quick actions irrelevant:** New Sale / Add Customer / Reports only (§5.1) — none event-oriented.
- **Alerts uninformative:** "No Active Alerts / Business running smoothly" regardless of pending advances, upcoming events, or rentals due (§5.2).
- **Self-redirect** `/dc/vendors` shows a redirect splash that targets itself (§6.4) — confusing if ever hit.
- **Empty-state handling is decent** within screens (e.g. `dc_billing_screen` invoice history shows "No invoices found"). (Good, where reachable)

---

## 16. Accessibility

- DC screens rely on default Material widgets (buttons, `TextField`, `DropdownButtonFormField`) which carry baseline semantics. (Neutral)
- Status conveyed by **color** in invoice history (`statusColor` green/blue/orange in `dc_billing_screen.dart`) with a text label alongside — acceptable but small font (10px) may fail contrast/size guidance. (Low)
- Icon-only `IconButton`s (delete row, refresh) — refresh has `tooltip`, delete row does **not** (`dc_billing_screen.dart` `Icon(Icons.delete_outline)` button has no tooltip/semantic label). (Low)
- **unverified:** screen-reader traversal, focus order, and contrast ratios (no assistive-tech testing performed; full WCAG validation requires manual testing).

---

## 17. Bugs / Errors / Crash Scenarios

- **`/dc/vendors` maps to `DcStaffScreen`** in `app/routes.dart` (should be a vendor screen such as `DcVendorPaymentsScreen`). Vendors are unreachable; staff screen shown instead. (High)
- **`/dc/vendors` go_router self-redirect** in `decoration_catering_routes.dart` (`legacyRoute: '/dc/vendors'`) — infinite-redirect risk under go_router. (High)
- **`dc_event_detail_screen` requires `eventId`** but has no route registration; any attempt to deep-link would have no constructor wiring — effectively dead. (Medium)
- **`_bookingFromJson` non-null assumptions:** `j['id']`, `j['customerName']`, `j['customerPhone']`, `j['guestCount']`, `j['eventDate']`, `j['createdAt']` are cast/parsed without null guards — a malformed/partial API row throws and the `FutureProvider` surfaces an error state (screens show "Error: …"). (Medium — robustness)
- **Discount >100%** produces negative totals with no guard (§14). (High)
- **`adjustInventory` race:** read-all then PUT can clobber concurrent updates (§7). (Medium)

---

## 18. Unnecessary / Irrelevant Features Shown

Because DC falls to `_getRetailSections()` (`sidebar_configuration.dart`), the following retail-only sections are shown to a service/events business and are largely irrelevant:
- **BuyFlow** (Purchase Orders, Stock Entry, Stock Reversal, Supplier Bills, Purchase Register) — DC has no product procurement model. (High noise)
- **Inventory & Stock** (Stock Summary, Item-wise Stock, Batch/Variant Tracking, Stock Valuation) — contradicts "service-only, no inventory" capability. (High)
- **Tax & Compliance** (GSTR-1, B2B/B2C, HSN) — limited relevance to a small events business. (Medium)
- **Business Intelligence / Financial Reports** generic set — partially relevant but not event-centric. (Medium)
- `batch_tracking` item carries `capability: useBatchExpiry` and **is** correctly hidden (DC lacks it) — the only capability-filtered item; everything else without a `capability` stays visible. (Evidence that the filter works but is under-applied.)

---

## 19. Recommendations & Prioritized Implementation Plan

### Critical
1. **Add a dedicated DC sidebar section** in `sidebar_configuration.dart` (`case BusinessType.decorationCatering: return _getDecorationCateringSections();`) with ids for Dashboard, Bookings, Calendar, Quotes, Catering/Menu, Decoration/Themes, Staff, Attendance, Vendors/Payments, Inventory(rentals), Shopping List, Billing, Profitability, Reports.
2. **Wire those ids in `sidebar_navigation_handler.getScreenForItem`** to the existing DC screens (import `decoration_catering.dart`), so the 13 barrel-exported screens become reachable; add the 3 non-barrel screens to the barrel first.
3. **Provide a DC home/dashboard entry** (route the post-login dashboard for `decorationCatering` to `DcDashboardScreen`, or surface `/dc/dashboard` from the dashboard selector). Today nothing navigates to it.

### High
4. **Fix `/dc/vendors`** in `app/routes.dart` to point to a vendor screen (e.g. `DcVendorPaymentsScreen`) instead of `DcStaffScreen`; fix the self-redirect in `decoration_catering_routes.dart`.
5. **Resolve capability-bypass:** either grant DC the inventory/billing capabilities it actually uses, or add `capability:`/`BusinessGuard` gating so retail Inventory/BuyFlow screens are hidden for DC. Reconcile `business_capability.dart` "service-only" comment with the exposed retail sidebar.
6. **Add DC cases to `business_quick_actions.dart` and `business_alerts_widget.dart`** (title + event-specific alerts: upcoming events, advance pending, rentals due back; sourced from `DcRepository`, not hardcoded).
7. **Implement rental lifecycle:** populate `rentalPrice` from API, add rent-out/return + damage tracking per event in `dc_inventory_screen.dart`/repository.
8. **Offline-first:** add Drift tables + sync for `/dc/*` so the vertical works offline (mirror retail pattern), and connect the dormant `DecorationCateringSyncHandler`.

### Medium
9. **Unify quote vs invoice math** (percentage vs absolute discount/tax) between `DecorationCateringBusinessRules.computeQuoteTotal` and `dc_billing_screen.dart`.
10. **Validation:** clamp discount 0–100, GST ≥0, qty>0, rate≥0; require an event selection before invoicing; cap advance ≤ total.
11. **Multi-day events:** add `eventEndDate` to `EventBooking` and propagate through booking/calendar/profitability.
12. **Record advance as a payment ledger entry** on conversion (call `recordPayment` or a dedicated endpoint) instead of storing only `advancePaid`.
13. **Harden `_bookingFromJson`** with null-safe parsing/defaults.

### Low
14. Add tooltips/semantic labels to icon-only buttons; raise small (10–11px) status font sizes.
15. Wire or remove `advanceForfeitedOnCancel` (currently test-only).
16. Replace `adjustInventory` read-all-then-PUT with an atomic delta endpoint.

---

## 20. Confidence & Coverage

### Files fully read
- `Dukan_x/lib/models/business_type.dart`
- `Dukan_x/lib/core/billing/business_type_config.dart`
- `Dukan_x/lib/features/decoration_catering/decoration_catering.dart` (barrel)
- `Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart` (≈733/814 lines; profitability tail truncated)
- `Dukan_x/lib/features/decoration_catering/utils/decoration_catering_business_rules.dart`
- `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_billing_screen.dart` (large; read through PDF section)
- `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart`
- `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart`
- `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` (≈1022/1162 lines; tail of pharmacy/other sections truncated but DC default path confirmed)
- `Dukan_x/lib/features/dashboard/v2/widgets/business_quick_actions.dart`
- `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
- `Dukan_x/lib/core/config/business_capabilities.dart`
- `Dukan_x/lib/core/isolation/business_capability.dart` (≈955/1129 lines; DC registry block fully read)
- `Dukan_x/lib/modules/decoration_catering/decoration_catering_module.dart`
- `Dukan_x/lib/modules/decoration_catering/routes/decoration_catering_routes.dart`
- `Dukan_x/lib/core/module/legacy_route_redirect.dart`
- `Dukan_x/lib/core/module/module_loader.dart`

### Verified via targeted grep
- Reachability of all 16 DC screen classes (`grep` of each class name across `lib/**`).
- `/dc/*` route definitions and navigation usages.
- `decorationCatering` references across the codebase (selection screen, providers, l10n, PDF theme, feature_resolver).

### Sampled but NOT fully read
- `dc_models.dart` (fields inferred from repository `fromJson`/constructors, not the full class file).
- DC screens: `dc_bookings`, `dc_calendar`, `dc_catering`, `dc_dashboard`, `dc_decoration`, `dc_event_detail`, `dc_inventory`, `dc_profitability`, `dc_quotes`, `dc_reports`, `dc_shopping_list`, `dc_staff`, `dc_staff_attendance`, `dc_vendor_payments` (existence + class signatures confirmed; internal logic not line-read).
- Widgets `dc_booking_form.dart`, `dc_status_badge.dart`, `dc_ui_kit.dart`, `dc_vendor_rating_dialog.dart` (referenced, not line-read).
- `dc_pdf_service.dart` (referenced from billing; not read).
- Tail of `dc_repository.dart` (profitability/return endpoints) — partially truncated.

### Not inspected (explicitly unverified)
- Server/Lambda implementation of `/dc/*` endpoints (real deployment, profitability formula, payments ledger).
- Multi-firm, online-store behaviors.
- Runtime rendering/responsive overflow and accessibility (no app run, no assistive-tech testing).

### Confidence
- **High** for: sidebar resolution to retail, capability registry contents, dashboard quick-actions/alerts DC fallback, route table contents, orphaned-screen finding, repository being real-API + offline gap, billing/quote validation gaps.
- **Medium** for: claims depending on screens sampled by signature only (e.g. exact internal logic of calendar/profitability/shopping-list).
- **Low/unverified** for: backend endpoint existence/behavior, profitability math correctness, accessibility/WCAG, multi-firm/online-store.
