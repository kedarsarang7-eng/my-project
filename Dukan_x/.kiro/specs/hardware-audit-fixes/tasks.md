# Implementation Plan

## Overview

Scope: all 25 `HARDWARE-*` issues for `BusinessType.hardware` **only**. No task may alter observable behavior for any other business type (clothing, grocery, electronics, mobileShop, wholesale, bookStore, jewellery, vegetablesBroker, decorationCatering, schoolErp, computerShop, service). Every shared-file change (`business_type_config.dart`, `manual_item_entry_sheet.dart`, `return_inwards_screen.dart`, `delivery_challan_repository.dart`, `HardwarePermissionMatrix`) MUST be verified change-by-change against all other verticals that use it. No task may alter hardware's existing **online** behavior.

Testing mandate: for each fix, first write a Flutter test (unit for logic/services, widget for UI) that FAILS on the current code, then apply the fix so it PASSES. Preservation clauses (Section 3 of `bugfix.md`) are covered by tests that PASS unchanged before and after. Task 1 (Property 1: Bug Condition) is the failing-first exploration suite; task 2 (Property 2: Preservation) is the observation-first baseline suite; both are written and run BEFORE any fix.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "description": "Failing-first and observation-first test suites, written and run on UNFIXED code before any fix",
      "tasks": ["1", "2"]
    },
    {
      "wave": 2,
      "description": "Independent defect fixes with no dependency on the Root Cause A/B refactors",
      "tasks": ["3.3", "3.4", "3.6", "3.7", "3.8", "3.9", "3.10", "3.14", "3.16", "3.17", "3.19", "3.20", "3.22", "3.23"]
    },
    {
      "wave": 3,
      "description": "Root Cause A local-first repository refactor (foundational; other tasks build on it)",
      "tasks": ["3.1"]
    },
    {
      "wave": 4,
      "description": "Root Cause B and fixes that build on the Root Cause A local-first infrastructure",
      "tasks": ["3.2", "3.11", "3.12", "3.13", "3.15", "3.18", "3.21"]
    },
    {
      "wave": 5,
      "description": "Fixes that depend on the loose-quantity/dimension work (wave 4) or are otherwise UI-layer polish",
      "tasks": ["3.5"]
    },
    {
      "wave": 6,
      "description": "Re-run the same tests to confirm bugs fixed and no regressions",
      "tasks": ["3.23", "3.24"]
    },
    {
      "wave": 7,
      "description": "Final checkpoint - full suite green",
      "tasks": ["4"]
    }
  ]
}
```

## Tasks

- [x] 1. Write bug condition exploration tests (BEFORE implementing any fix)
  - **Property 1: Bug Condition** - Hardware Defect Surfaces (all 25 issues)
  - **CRITICAL**: These tests MUST FAIL on unfixed code - failure confirms each defect exists
  - **DO NOT attempt to fix the test or the code when it fails at this stage**
  - **NOTE**: These tests encode the expected behavior - they will validate the fix when they pass after implementation
  - **GOAL**: Surface counterexamples that demonstrate each defect and confirm/refute the root-cause analysis
  - **Scoped PBT Approach**: These are deterministic defects - scope each property to the concrete failing case (active `BusinessType.hardware` on the specific surface) for reproducibility
  - Bug condition: `isBugCondition(input)` is true only when `input.businessType == BusinessType.hardware` AND the surface matches a defect below (from Bug Condition in design)
  - Write the following exploration assertions (run all on UNFIXED code):
    - Root Cause A - offline reads: mock offline connectivity, call `HardwareOpsRepository.listProjects()`/`listIndents()`/`listDeposits()`/`listPurchaseOrders()`/`listParties()`/`listSalesOrders()`, assert data is served from a local store (fails: throws or returns stale in-memory cache) - covers HARDWARE-001
    - Root Cause A - offline writes: mock offline connectivity, call `createProject()`/`createIndent()`/`createDeposit()`/`settleDeposit()`/`closeProject()`, assert the mutation is enqueued via `HardwareSyncHandler.enqueue()` (fails: nothing enqueued, mutation silently lost) - covers HARDWARE-019
    - Root Cause A - architecture: assert `HardwareOpsRepository` extends/uses `BaseRepository` and returns typed models, not raw `Map<String,dynamic>` (fails: direct `ApiClient` usage, raw maps) - covers HARDWARE-025
    - Root Cause B - GRN/Bill methods: assert `HardwareOpsRepository` exposes `listGrn()`, `createGrn()`, `listPurchaseBills()`, `createPurchaseBill()`, `returnPurchaseBill()` (fails: methods don't exist) - covers HARDWARE-005
    - Root Cause B - GRN/Bill UI: assert a GRN/Purchase-Bill screen exists reachable from a purchase order in the workspace (fails: no such screen) - covers HARDWARE-015
    - Dimension calculator on quick-add (HARDWARE-002): add a `sqft`-unit item via the quick-add/barcode-scan sale path and assert `DimensionCalculator` is surfaced (fails: not shown, only in `ManualItemEntrySheet`)
    - E-Way Bill persistence (HARDWARE-003): generate an E-Way Bill and assert the Part-A record persists to a local table linked to the delivery challan (fails: only a SnackBar + in-memory ref string)
    - Endpoint health-check (HARDWARE-004): mock a missing hardware endpoint and assert a distinct "endpoint unavailable" state renders (fails: indistinguishable from empty-data state)
    - Module manifest desync (HARDWARE-006): assert hardware's `modules` list includes every module the Command Center surfaces (fails: `'purchase'`,`'credit'`,`'delivery_challans'`,`'supplier_management'`,`'projects'`,`'gst'` missing)
    - Currency label (HARDWARE-007): render the Record Payment dialog and assert the max-payment label uses `'₹'` (fails: `'Amount (Rs)'`)
    - Scroll physics (HARDWARE-008): render `HardwarePhase12WorkspaceScreen` on a mobile viewport, simulate pull-to-refresh, assert `RefreshIndicator` triggers (fails: gesture not detected due to `NeverScrollableScrollPhysics`)
    - Sequential load (HARDWARE-009): mock 7 delayed API calls (e.g. 500ms each) and assert `_load()` completes in ≈ 500ms, not ≈ 3500ms (fails: sequential sum)
    - Debounce (HARDWARE-010): fire 5 rapid filter `onChanged` events and assert exactly 1 `_load()` call after settling (fails: 5 calls)
    - Loose-quantity selling (HARDWARE-011): assert a loose-quantity/cut-to-length selling widget exists integrated with `cutToSizeCharge()` (fails: no such widget)
    - Credit-limit enforcement (HARDWARE-012): create an invoice that would push a contractor's balance over their `creditLimit` and assert it is warned/blocked (fails: allowed silently)
    - Dimension-aware return (HARDWARE-013): return a dimension-billed item via `ReturnInwardsScreen` and assert dimension metadata/partial-area entry is available (fails: generic quantity-only return)
    - Low-stock indent check (HARDWARE-014): create an indent for an item below its reorder point and assert a low-stock warning is surfaced (fails: no warning, no stock check)
    - Barcode scan actions (HARDWARE-016): scan a barcode on the Deposits tab and assert an "Add to Deposit" action is offered; scan on the Projects tab and assert "Create Indent for Project" is offered (fails: informational dialog only, no action)
    - Cut-to-size disclosure (HARDWARE-017): bill a 1.1ft cut and assert the invoice line item displays the rounding disclosure note (fails: rounds to 2ft silently, no disclosure shown)
    - Deposit settlement bounds (HARDWARE-018): settle a deposit with `refund > outstandingDepositCents` or `returnedQty > originalQty` and assert rejection (fails: accepted, only non-negative checked)
    - Sync comment accuracy (HARDWARE-020): assert the comment at `delivery_challan_repository.dart` line 68 does not say "Firestore collection" (fails: contains the stale reference)
    - Invoice profile offline cache (HARDWARE-021): save invoice profiles online, then mock offline and call `_load()`, assert profiles are served from a local cache (fails: fetch throws/fails offline, no cache)
    - Reminder RBAC gate (HARDWARE-022): with a "view"-only role active, assert the Reminders trigger button is absent or disabled (fails: visible and triggerable by any role)
    - CSV export cross-platform (HARDWARE-023): mock a web platform and call `_exportSuppliersCsv()`, assert it completes without `UnsupportedError` (fails: throws, uses `dart:io` `File`/`Directory` directly)
    - Rate comparison drill-down (HARDWARE-024): assert a dedicated rate-comparison table/view exists beyond the count card (fails: only "Supplier Rate Comparison: N records" shown)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct - it proves each defect exists)
  - Document counterexamples found (e.g., offline reads throwing; offline writes never reaching `HardwareSyncHandler`; missing GRN/Bill methods; sequential-sum load time; `'Rs'` label; over-refund accepted; ungated reminder trigger; `UnsupportedError` on web CSV export)
  - Mark task complete when tests are written, run, and failures are documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25 / 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15, 2.16, 2.17, 2.18, 2.19, 2.20, 2.21, 2.22, 2.23, 2.24, 2.25_

- [x] 2. Write preservation property tests (BEFORE implementing any fix)
  - **Property 2: Preservation** - Non-Hardware and Hardware-Online Behavior Unchanged
  - **IMPORTANT**: Follow observation-first methodology - run UNFIXED code for non-buggy inputs (`isBugCondition == false`), record actual outputs, then assert them
  - **Why property-based**: the non-hardware input space is large (12 other business types x many shared surfaces), plus hardware's own connected-mode surface; generated cases cover the shared-file blast radius and hardware's online behavior, catching edge cases manual tests miss
  - Observe and capture on UNFIXED code, then assert:
    - Non-hardware module manifests: generate every non-hardware `BusinessType` and assert `business_type_config.dart`'s `modules` list is unchanged (3.6)
    - Non-hardware RBAC/permission matrices: assert other verticals' permission matrices and reminder/trigger-style actions (where applicable) are unaffected (3.22 for non-hardware roles)
    - Hardware online reads/writes: with connectivity mocked online, assert `HardwareOpsRepository` calls return identical data/shapes to today, for every entity type (3.1, 3.19)
    - Existing PO create/list: assert unaffected by the future addition of GRN/Bill methods (3.5, 3.15)
    - Non-dimension quick-add/scan sales: assert unaffected by the future dimension-calculator surfacing (3.2)
    - Non-loose-quantity billing: assert unaffected by the future loose-quantity widget (3.11)
    - In-limit / no-limit credit sales: assert still allowed (3.12)
    - Non-dimension-billed returns and other verticals' `ReturnInwardsScreen` usage: assert unchanged (3.13)
    - Sufficient-stock indent creation: assert no low-stock warning shown (3.14)
    - Existing Indents-tab barcode scan action: assert "Add to Indent" still offered (3.16)
    - Exact-measurement (no rounding) cut billing: assert unaffected by the disclosure addition (3.17)
    - Within-bounds deposit settlements: assert still accepted (3.18)
    - Delivery-challan sync routing behavior (not the comment): generate routing scenarios across verticals using delivery challans and assert identical routing (3.20)
    - Online invoice-profile save/load: assert unchanged (3.21)
    - Admin/owner reminder trigger: assert still works (3.22)
    - Desktop/mobile CSV export: assert same content, same success (3.23)
    - Other workspace KPI count cards (purchase orders, parties, pending POs, sales orders, velocity, dead stock): assert unchanged rendering (3.24)
    - Every other vertical already on `BaseRepository`/Drift/Sync (delivery_challan, billing, inventory): assert unaffected by hardware's future migration onto the same pattern (3.25)
    - `HardwareOperationsScreen`'s existing `Future.wait`-based refresh and desktop button-refresh: assert unchanged (3.8, 3.9)
    - Single, isolated filter changes in `HardwareCreditControlScreen`: assert still refresh after the debounce delay elapses (3.10)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms the baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14, 3.15, 3.16, 3.17, 3.18, 3.19, 3.20, 3.21, 3.22, 3.23, 3.24, 3.25_

- [x] 3. Fix all 25 hardware audit defects (hardware-scoped, minimal-change except Root Cause A/B)

  - [x] 3.1 Fix Root Cause A - local-first repository + sync handler wiring
    - Add Drift tables for hardware entities (projects, site indents, material deposits, purchase orders, parties, sales orders)
    - Refactor `HardwareOpsRepository` (`lib/features/hardware/data/hardware_ops_repository.dart`) to read from local Drift tables and write locally + call `HardwareSyncHandler.enqueue()` for every mutation, following the `BaseRepository` pattern used by delivery_challan/billing/inventory
    - Replace raw `Map<String, dynamic>` returns with typed model classes where practical
    - One refactor fixes offline reads, offline write durability, and architectural consistency
    - Write a Flutter unit test that FAILS on unfixed code (offline read/write) BEFORE making this change, per task 1
    - _Bug_Condition: isBugCondition(input) where input.surface in {'hardwareOps.read','hardwareOps.mutate','hardwareOps.architecture'} and businessType == hardware_
    - _Expected_Behavior: expectedBehavior(result) - offline reads served locally, offline writes enqueued, repository uses BaseRepository (Property 1 in design)_
    - _Preservation: online reads/writes unchanged; other BaseRepository verticals unaffected (3.1, 3.19, 3.25)_
    - _Requirements: 1.1, 2.1, 1.19, 2.19, 1.25, 2.25_

  - [x] 3.2 Fix Root Cause B - implement GRN / Purchase Bill pipeline
    - Implement `listGrn()`, `createGrn()`, `listPurchaseBills()`, `createPurchaseBill()`, `returnPurchaseBill()` in `HardwareOpsRepository`, routed through the local-first pattern from 3.1
    - Add GRN and Purchase Bill screens, wired into `HardwarePhase12WorkspaceScreen` and `HardwareCommandCenterScreen`, linked to existing purchase orders
    - Write a Flutter unit + widget test that FAILS on unfixed code (missing methods / missing UI) BEFORE this change, per task 1
    - _Bug_Condition: isBugCondition(input) where input.surface == 'hardwareOps.grnOrBill'_
    - _Expected_Behavior: PO -> GRN -> Purchase Bill pipeline functional end-to-end (Property 2 in design)_
    - _Preservation: existing PO create/list unchanged (3.5, 3.15)_
    - _Requirements: 1.5, 2.5, 1.15, 2.15_

  - [x] 3.3 Surface dimension calculator on quick-add/scan sale path
    - Detect dimension-unit items (`sqft`/`sqmtr`/`ft`/`mtr`) added via the quick-add/barcode-scan sale path and surface `DimensionCalculator` inline, or route to the sheet that contains it
    - Write a Flutter widget test that FAILS on unfixed code (calculator not shown outside `ManualItemEntrySheet`) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'billing.quickAddDimensionItem'_
    - _Expected_Behavior: DimensionCalculator reachable from every hardware sale path (Property 3 in design)_
    - _Preservation: non-dimension items and existing manual-entry usage unchanged (3.2)_
    - _Requirements: 1.2, 2.2_

  - [x] 3.4 Persist E-Way Bill Part-A records
    - In `eway_bill_screen.dart` `_generate()`, persist the Part-A record to a local table linked to the associated delivery challan, and queue it for sync
    - Write a Flutter unit test that FAILS on unfixed code (no persistence, only in-memory ref string) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'ewayBill.generate'_
    - _Expected_Behavior: E-Way Bill record durable across screen dismissal and synced (Property 4 in design)_
    - _Preservation: threshold/reference-generation logic unchanged (3.3)_
    - _Requirements: 1.3, 2.3_

  - [x] 3.5 Add endpoint health-check / version negotiation
    - Add a health-check/version-negotiation call for hardware-specific endpoints; render a distinct "endpoint unavailable" UI state when a contract endpoint is missing or unsupported, instead of an indistinguishable empty-data state
    - Write a Flutter unit test that FAILS on unfixed code (missing endpoint indistinguishable from empty data) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'hardwareOps.endpointHealth'_
    - _Expected_Behavior: endpoint-unavailable state distinguishable from empty-data state (Property 5 in design)_
    - _Preservation: deployed-endpoint behavior unchanged (3.4)_
    - _Requirements: 1.4, 2.4_

  - [x] 3.6 Reconcile hardware module manifest with reachable workflows
    - In `business_type_config.dart` extend hardware's `modules` list to include `'purchase'`, `'credit'`, `'delivery_challans'`, `'supplier_management'`, `'projects'`, `'gst'` (or adopt capability-only gating consistently)
    - Write a Flutter unit test that FAILS on unfixed code (manifest missing modules the Command Center surfaces) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'config.moduleManifest'_
    - _Expected_Behavior: manifest and Command Center workflows internally consistent (Property 6 in design)_
    - _Preservation: no other business type's manifest changes (3.6)_
    - _Requirements: 1.6, 2.6_

  - [x] 3.7 Fix hardcoded currency label in Record Payment dialog
    - In `hardware_supplier_management_screen.dart` `_showRecordPaymentDialog`, replace `'Amount (Rs)'` with the shared `₹` currency formatter
    - Write a Flutter widget test that FAILS on unfixed code (label shows `'Rs'`) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'supplier.recordPaymentDialog'_
    - _Expected_Behavior: label renders `'₹'` via shared formatter (Property 7 in design)_
    - _Preservation: all other amount displays unchanged (3.7)_
    - _Requirements: 1.7, 2.7_

  - [x] 3.8 Fix scroll-physics conflict in workspace screen
    - In `hardware_phase12_workspace_screen.dart`, replace `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` with a `CustomScrollView`/slivers (or otherwise enable scroll physics) so `RefreshIndicator` detects the overscroll gesture on mobile/tablet
    - Write a Flutter widget test that FAILS on unfixed code (pull-to-refresh not detected on mobile viewport) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'workspace.pullToRefresh' and viewport in {mobile, tablet}_
    - _Expected_Behavior: RefreshIndicator reliably detects the gesture (Property 8 in design)_
    - _Preservation: desktop button-refresh unchanged (3.8)_
    - _Requirements: 1.8, 2.8_

  - [x] 3.9 Parallelize workspace screen load
    - In `hardware_phase12_workspace_screen.dart` `_load()`, replace sequential `await`s with `Future.wait([...])` for all 7 independent fetches, matching `HardwareOperationsScreen._refreshAll()`
    - Write a Flutter unit test that FAILS on unfixed code (load time ≈ sum of delays) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'workspace.load'_
    - _Expected_Behavior: load time approximates the slowest single call (Property 9 in design)_
    - _Preservation: per-call data and per-call error isolation unchanged (3.9)_
    - _Requirements: 1.9, 2.9_

  - [x] 3.10 Add debounce to credit control filters
    - In `hardware_credit_control_screen.dart`, add a ~300ms debounce `Timer` before calling `_load()` on filter dropdown `onChanged`
    - Write a Flutter unit test that FAILS on unfixed code (5 rapid changes -> 5 calls) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'creditControl.filterChange'_
    - _Expected_Behavior: rapid changes coalesce into one call after ~300ms (Property 10 in design)_
    - _Preservation: a single, isolated filter change still refreshes after the delay (3.10)_
    - _Requirements: 1.10, 2.10_

  - [x] 3.11 Build loose-quantity selling workflow
    - Build a loose-quantity/cut-to-length selling widget integrated with `HardwareBusinessRules.cutToSizeCharge()`, including remnant-inventory tracking, using the local-first repository from 3.1 for remnant persistence
    - Write a Flutter widget test that FAILS on unfixed code (no such widget exists) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'billing.looseQuantitySale'_
    - _Expected_Behavior: loose-quantity sale with remnant tracking supported (Property 11 in design)_
    - _Preservation: non-loose-quantity billing unaffected (3.11)_
    - _Requirements: 1.11, 2.11_

  - [x] 3.12 Enforce contractor credit limit at billing time
    - At invoice-creation time, query the party's outstanding balance and `creditLimit` (via the local-first repository from 3.1) and warn/block when `outstandingBalance + newInvoiceAmount > creditLimit`
    - Write a Flutter unit test that FAILS on unfixed code (over-limit sale allowed silently) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'billing.creditSale' and wouldExceedLimit == true_
    - _Expected_Behavior: over-limit credit sale warned/blocked (Property 12 in design)_
    - _Preservation: in-limit/no-limit sales still allowed (3.12)_
    - _Requirements: 1.12, 2.12_

  - [x] 3.13 Add dimension-aware sales return
    - In `return_inwards_screen.dart`, carry `dimensions` metadata from the original sale into the return context and offer `DimensionCalculator` for partial-area return-quantity entry on dimension-billed items
    - Write a Flutter widget test that FAILS on unfixed code (generic quantity-only return, no dimension metadata) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'returnInwards.dimensionBilledItem'_
    - _Expected_Behavior: dimension metadata carried through; partial-area return entry available (Property 13 in design)_
    - _Preservation: non-dimension-billed returns and other verticals' use of the shared screen unchanged (3.13)_
    - _Requirements: 1.13, 2.13_

  - [x] 3.14 Add low-stock check on indent creation
    - Before submitting an indent to `/hardware/indents`, check the requested product's current local inventory stock level and surface a low-stock warning (optionally suggest a purchase order) when below reorder point
    - Write a Flutter unit test that FAILS on unfixed code (no stock check, no warning) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'indent.create'_
    - _Expected_Behavior: low-stock warning surfaced at indent creation when applicable (Property 14 in design)_
    - _Preservation: sufficient-stock indents unaffected (3.14)_
    - _Requirements: 1.14, 2.14_

  - [x] 3.15 Add contextual barcode-scan actions for Projects/Deposits tabs
    - In `hardware_operations_screen.dart` `_scanProductBarcode()`, add an "Add to Deposit" action pre-filling item type on the Deposits tab, and a "Create Indent for Project" action on the Projects tab
    - Write a Flutter widget test that FAILS on unfixed code (informational dialog only, no action on those tabs) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'operations.barcodeScan' and tab in {projects, deposits}_
    - _Expected_Behavior: contextual action offered on Deposits and Projects tabs (Property 15 in design)_
    - _Preservation: existing "Add to Indent" action on the Indents tab unchanged (3.16)_
    - _Requirements: 1.16, 2.16_

  - [x] 3.16 Add cut-to-size rounding disclosure
    - Display `HardwareBusinessRules.cutToSizeRoundingNote()`'s disclosure on the invoice line item whenever `cutToSizeCharge()` rounds up; add an optional shop-level setting to enable/disable the rounding convention
    - Write a Flutter widget test that FAILS on unfixed code (round-up applied with no visible disclosure) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'billing.cutToSizeRoundUp'_
    - _Expected_Behavior: rounding disclosure displayed on the invoice line item (Property 16 in design)_
    - _Preservation: exact-measurement items unaffected (3.17)_
    - _Requirements: 1.17, 2.17_

  - [x] 3.17 Validate deposit settlement bounds
    - In `hardware_operations_screen.dart` `_showSettleDepositDialog()`, pass the original deposit's quantity and outstanding amount into the dialog and validate `returnedQty <= dep['quantity']` and `refundAmountCents <= dep['outstandingDepositCents']`
    - Write a Flutter unit test that FAILS on unfixed code (over-refund/over-return accepted) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'deposit.settle' and (refund > originalOutstanding or returnedQty > originalQty)_
    - _Expected_Behavior: over-bound settlements rejected (Property 17 in design)_
    - _Preservation: within-bounds settlements still accepted (3.18)_
    - _Requirements: 1.18, 2.18_

  - [x] 3.18 Fix stale sync-comment documentation
    - In `delivery_challan_repository.dart` line 68, update the comment from `// Firestore collection` to accurately describe the REST/DynamoDB routing-key mechanism
    - Write a Flutter unit test (or static assertion) that FAILS on unfixed code (comment contains the stale reference) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'deliveryChallan.syncComment'_
    - _Expected_Behavior: comment accurately describes the REST/DynamoDB mechanism (Property 18 in design)_
    - _Preservation: no runtime routing behavior changes for any vertical (3.20)_
    - _Requirements: 1.20, 2.20_

  - [x] 3.19 Cache invoice profiles locally
    - In `hardware_invoice_profile_screen.dart`, cache invoice profiles locally (SharedPreferences or a Drift table, optionally reusing 3.1's local-first infrastructure) on successful save/load, and serve from cache when offline
    - Write a Flutter unit test that FAILS on unfixed code (offline load fails/falls back to default, no cache) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'invoiceProfile.saveOrLoad' and connectivity == offline_
    - _Expected_Behavior: profiles served from local cache when offline (Property 19 in design)_
    - _Preservation: online save/load unchanged (3.21)_
    - _Requirements: 1.21, 2.21_

  - [x] 3.20 Gate reminder-trigger button behind RBAC
    - Add a `trigger_reminders` action to `HardwarePermissionMatrix.moduleActions['suppliers']` (or an admin/owner role check) and gate the "Reminders" button in `hardware_supplier_management_screen.dart` behind it; verify server-side RBAC as well
    - Write a Flutter widget test that FAILS on unfixed code (button visible/triggerable for a "view"-only role) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'supplier.triggerReminders' and role not in {admin, owner}_
    - _Expected_Behavior: trigger action hidden/disabled for non-admin/owner roles (Property 20 in design)_
    - _Preservation: admin/owner triggering unaffected (3.22)_
    - _Requirements: 1.22, 2.22_

  - [x] 3.21 Make CSV export cross-platform
    - In `hardware_supplier_management_screen.dart` `_exportSuppliersCsv()`, replace direct `dart:io` `File`/`Directory` usage with `share_plus`/`file_saver` so export succeeds on web as well as desktop/mobile
    - Write a Flutter unit test that FAILS on unfixed code (`UnsupportedError` on mocked web platform) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'supplier.csvExport' and platform == web_
    - _Expected_Behavior: export completes successfully on every supported platform (Property 21 in design)_
    - _Preservation: desktop/mobile export content and success unchanged (3.23)_
    - _Requirements: 1.23, 2.23_

  - [x] 3.22 Add rate-comparison drill-down view
    - Add a dedicated rate-comparison screen/section to `HardwarePhase12WorkspaceScreen` showing an item × supplier × price table (sortable/filterable), replacing the bare count card; optionally add a price-trend sparkline
    - Write a Flutter widget test that FAILS on unfixed code (only a count card shown, no table/drill-down) BEFORE this change
    - _Bug_Condition: isBugCondition(input) where input.surface == 'workspace.rateComparisonView'_
    - _Expected_Behavior: dedicated item x supplier x price view available (Property 22 in design)_
    - _Preservation: other workspace KPI count cards unchanged (3.24)_
    - _Requirements: 1.24, 2.24_

  - [x] 3.23 Verify bug condition exploration tests now pass (all 25 issues)
    - **Property 1: Expected Behavior** - Hardware Defect Surfaces (all 25 issues)
    - **IMPORTANT**: Re-run the SAME tests from task 1 - do NOT write new tests
    - The tests from task 1 encode the expected behavior; passing confirms each defect is resolved
    - **EXPECTED OUTCOME**: Tests PASS (confirms bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15, 2.16, 2.17, 2.18, 2.19, 2.20, 2.21, 2.22, 2.23, 2.24, 2.25_

  - [x] 3.24 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Hardware and Hardware-Online Behavior Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions for any other business type or hardware's online-mode behavior)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14, 3.15, 3.16, 3.17, 3.18, 3.19, 3.20, 3.21, 3.22, 3.23, 3.24, 3.25_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run the full Flutter test suite (unit + widget + property-based) with `flutter test`
  - Confirm all task 1 exploration tests now pass and all task 2 preservation tests still pass
  - Confirm no non-hardware vertical behavior changed across the five shared files
  - Confirm hardware's existing online-mode behavior is unaffected
  - Ensure all tests pass, ask the user if questions arise

## Notes

- Root Cause A (task 3.1: Drift tables + `HardwareOpsRepository` refactor + `HardwareSyncHandler` wiring) resolves three issues: HARDWARE-001 (1.1/2.1), HARDWARE-019 (1.19/2.19), HARDWARE-025 (1.25/2.25). This is a foundational, architectural task and is scheduled in its own wave since tasks 3.2, 3.11, 3.12, 3.13, 3.19 build on its local-first infrastructure.
- Root Cause B (task 3.2: GRN/Purchase-Bill repository methods + UI) resolves two issues: HARDWARE-005 (1.5/2.5), HARDWARE-015 (1.15/2.15). It builds on 3.1's local-first pattern.
- HARDWARE-021 (task 3.19, invoice-profile local caching) is independent but reuses 3.1's local-first infrastructure as an implementation convenience; it is scheduled alongside the other Root-Cause-A-dependent tasks in wave 4.
- Shared-file blast radius: `business_type_config.dart`, `manual_item_entry_sheet.dart`, `return_inwards_screen.dart`, `delivery_challan_repository.dart`, `HardwarePermissionMatrix`. Each edit must be verified against clothing, grocery, electronics, mobileShop, wholesale, bookStore, jewellery, vegetablesBroker, decorationCatering, schoolErp, computerShop, service before landing.
- Property-based testing is used for preservation (task 2, large non-hardware input space plus hardware's own connected-mode surface) and for the connectivity-state, deposit-bounds, and debounce properties, per the design Testing Strategy.
- All 25 issue IDs are covered exactly once across tasks 3.1-3.22; the `_Requirements:_` annotations reference the paired clauses (1.x current / 2.x expected / 3.x preservation) from `bugfix.md`.
