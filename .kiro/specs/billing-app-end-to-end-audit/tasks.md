# Implementation Plan

## Overview

This is a meta-bugfix. The "bug" is the existence of an unknown set of latent
defects across 11 well-defined classes (D1..D11) defined in `bugfix.md` §1
and formalized in `design.md`. The plan therefore has two coordinated
tracks that share one bug-condition methodology:

- **Track A — Audit & Inventory** produces the coverage matrix and the
  categorized defect inventory (acceptance criteria 2.17, 2.18, 2.21).
- **Track B — Per-defect-class fixes** resolves every inventory entry with
  a minimal, targeted change that satisfies the per-defect Fix property
  and the per-defect Preservation property (acceptance criteria
  2.1..2.16, 2.19, 2.20, 3.1..3.7).

Task 1 (Property 1 — Bug Condition) is the audit walk over UNFIXED code
that surfaces counterexamples. Task 2 (Property 2 — Preservation) captures
already-correct behavior on UNFIXED code as the regression baseline. Task 3
delivers the inventory and resolves it. Task 4 is the final checkpoint.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "tasks": ["1"],
      "description": "Property 1 audit walk on UNFIXED code — surfaces counterexamples (expected to FAIL)"
    },
    {
      "wave": 2,
      "tasks": ["2"],
      "description": "Property 2 preservation baseline on UNFIXED code — captures already-correct behavior (expected to PASS)"
    },
    {
      "wave": 3,
      "tasks": ["3.1"],
      "description": "Track A — build coverage matrix and categorized defect inventory from Task 1 counterexamples"
    },
    {
      "wave": 4,
      "tasks": ["3.2.1", "3.2.2", "3.2.3", "3.2.4", "3.2.5", "3.2.6", "3.2.7", "3.2.8", "3.2.9"],
      "description": "Track B — per-defect-class fixes for D1..D9 (parallelizable; D10 and D11 deferred to wave 5 due to dependencies)"
    },
    {
      "wave": 5,
      "tasks": ["3.2.10", "3.2.11"],
      "description": "Track B — D10 cross-module sagas (depends on D4/D5/D6) and D11 domain-correctness (depends on D3)"
    },
    {
      "wave": 6,
      "tasks": ["3.3", "3.4"],
      "description": "Re-run Property 1 (must now PASS) and Property 2 (must still PASS)"
    },
    {
      "wave": 7,
      "tasks": ["4"],
      "description": "Checkpoint — full test suite green, inventory closed, coverage matrix complete"
    }
  ]
}
```

```
                ┌──────────────────────────────────────────┐
                │ 1. Property 1: Bug Condition             │
                │    Exploration audit walk (UNFIXED code) │
                │    EXPECTED: FAILS — surfaces defects    │
                └──────────────────┬───────────────────────┘
                                   │ counterexamples seed inventory
                                   ▼
                ┌──────────────────────────────────────────┐
                │ 2. Property 2: Preservation              │
                │    Capture baseline behavior (UNFIXED)   │
                │    EXPECTED: PASSES on UNFIXED code      │
                └──────────────────┬───────────────────────┘
                                   │ baseline locked
                                   ▼
        ┌──────────────────────────────────────────────────────────┐
        │ 3. Fix the meta-bug (audit-and-resolve sweep)            │
        │                                                          │
        │  3.1 Track A — Build coverage matrix + defect inventory  │
        │      (depends on Task 1 counterexamples)                 │
        │             │                                            │
        │             ▼                                            │
        │  3.2 Track B — Per-defect-class fixes                    │
        │      ┌─────────────────────────────────────────────┐     │
        │      │ 3.2.1 D1  Navigation                        │     │
        │      │ 3.2.2 D2  Placeholder / incomplete UI       │     │
        │      │ 3.2.3 D3  Validation & business rules       │     │
        │      │ 3.2.4 D4  Data flow & persistence           │     │
        │      │ 3.2.5 D5  Offline / online / sync           │     │
        │      │ 3.2.6 D6  State consistency                 │     │
        │      │ 3.2.7 D7  Error handling                    │     │
        │      │ 3.2.8 D8  RBAC                              │     │
        │      │ 3.2.9 D9  Performance                       │     │
        │      │ 3.2.10 D10 Cross-module integration         │     │
        │      │ 3.2.11 D11 Domain correctness per vertical  │     │
        │      └─────────────────────────────────────────────┘     │
        │             │ (D10 depends on D4, D5, D6;                │
        │             │  D11 depends on D3; others independent)    │
        │             ▼                                            │
        │  3.3 Verify Property 1 — bug-condition test now PASSES   │
        │             │                                            │
        │             ▼                                            │
        │  3.4 Verify Property 2 — preservation tests still PASS   │
        └──────────────────┬───────────────────────────────────────┘
                           ▼
                ┌──────────────────────────────────────────┐
                │ 4. Checkpoint — all tests green          │
                └──────────────────────────────────────────┘
```

Sub-task ordering inside 3.2 is flexible per defect class with two
constraints: D10 (cross-module) lands after D4/D5/D6 because its sagas
depend on consistent data flow, sync, and state propagation; D11 (domain
correctness) lands after D3 because per-vertical artifacts depend on the
centralized business-rule helpers introduced under D3.

## Tasks

- [x] 1. Write bug condition exploration test (audit walk over UNFIXED code)
  - **Property 1: Bug Condition** — End-to-End Audit Surfaces Defects D1..D11
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure is the defect inventory
  - **DO NOT attempt to fix the test or the code when it fails** — record each failure as an inventory row
  - **NOTE**: This audit encodes the expected behavior from `bugfix.md` §2 (clauses 2.1..2.16); when every reproduction sub-test eventually passes, the meta-bug is resolved
  - **GOAL**: Surface counterexamples that demonstrate `isBugCondition(X)` holds for at least one workflow X, then catalog every X found
  - **Scoped PBT Approach**: Because the defect set is heterogeneous, scope each scenario to a deterministic per-module walk (every route, every primary CRUD, every business-rule edge case, every offline/reconnect/multi-device matrix cell), then layer property-based generators on top per defect class
  - Implement as a structured per-module audit in `test/audit/` (across `Dukan_x`, `school_admin_app`, `school_teacher_app`, `school_student_app`):
    - **D1 navigation walk**: tap every drawer / route / deep link in every `Dukan_x/lib/modules/<m>/routes/*_routes.dart` and `school_*/lib/core/router/app_router.dart`; assert each registered route resolves to a fully-implemented destination (negation of clause 1.1, 1.2)
    - **D2 placeholder sweep**: open every screen, tab, dialog, dropdown; assert no `TODO` / `Coming soon` / lorem strings, no non-functional controls, and that empty/error/loading states render distinguishably (negation of 1.3, 1.4)
    - **D3 validation & business-rule sweep**: submit invalid input and boundary cases (GST slabs, multi-unit conversion, jewellery purity, petrol totalizer rollover, fee pro-rata, KOT split) on every form/calculator (negation of 1.5, 1.6)
    - **D4–D6 data/sync/state sweep**: per module, create-edit-delete then reopen dependent screens; toggle offline/online; open the same account on two devices and edit concurrently (negation of 1.7..1.11)
    - **D7 error sweep**: force backend timeouts, file I/O failures, scanner/camera/PDF/print failures; assert no unhandled exception, no frozen UI (negation of 1.12)
    - **D8 RBAC sweep**: per role, attempt every action via every entry point (drawer, deep link, action button, search) and assert grants match the documented matrix (negation of 1.13)
    - **D9 performance sweep**: seed ≥5k products, ≥10k invoices, ≥2k students; measure first-frame and scroll FPS against documented budgets (negation of 1.14)
    - **D10 cross-module sweep**: run end-to-end sagas (billing→inventory→ledger→GST report; school fee→payment→receipt→ledger; purchase→stock→vendor ledger; jewellery old-gold-exchange→bill→stock; restaurant KOT→bill→kitchen; pharmacy→patient→bill; auto/computer service→job-card→bill→warranty); assert no partial state at boundaries (negation of 1.15)
    - **D11 domain-correctness sweep**: run each business-type signature workflow end-to-end and verify the produced artifact matches the documented expected output (negation of 1.16)
    - **Offline/reconnect/multi-device matrix** (clause 2.21): per offline-capable module, run offline create/edit/delete, reconnect sync, multi-device concurrent edit, flaky network, forced kill mid-write, large-batch sync
  - Assertions must match the Expected Behavior Properties (Property 1 in `design.md` — Defect Inventory is Resolved)
  - Run audit on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct — proves the meta-bug exists)
  - Document every counterexample found with the full inventory schema from clause 2.18 — these rows feed Task 3.1
  - Mark task complete when the audit is implemented, run, and every failure is documented as an inventory candidate
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16_

- [x] 2. Write preservation property tests (BEFORE implementing fixes)
  - **Property 2: Preservation** — Already-Correct Workflows Are Untouched
  - **IMPORTANT**: Follow observation-first methodology — record what F actually does on non-buggy inputs, then assert F' produces the same observation
  - Observe behavior on UNFIXED code for inputs where `isBugCondition(X)` returns false:
    - Already-correct navigation, lists, and forms across every module (capture route graph snapshot, golden screen renders for canonical happy-path screens)
    - Already-correct GST and domain calculations on the inputs they currently handle correctly (snapshot exact numeric outputs)
    - Already-correct offline queue and sync flows (capture queue ordering, idempotency keys, reconcile output)
    - Already-correct RBAC enforcement (snapshot the permitted-actions set per role)
    - Already-correct cross-module hand-offs (snapshot dependent-record state after each saga step)
    - Persisted-data round-trip: open Hive / SQLite / Drift / Isar boxes and DynamoDB records written by F; capture deserialized shape (clause 3.3)
    - Public route names, deep links, persisted storage keys (clause 3.4)
    - Per-business-type theming, iconography, terminology (clause 3.5)
  - Write property-based tests under `test/preservation/` capturing observed behavior patterns from the Preservation Requirements:
    - PBT generators sample `X` and filter `NOT isBugCondition(X)` so only non-buggy inputs reach assertions
    - Assert `F'(X) == F(X)` over outputs, persisted shape, navigation graph, RBAC grants, queue semantics, timing class
    - Run all existing test suites in the four apps unchanged as a fixed regression baseline (clause 3.2)
  - Property-based testing generates many test cases for stronger guarantees over the heterogeneous module surface
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when preservation tests are written, run, and passing on unfixed code
  - _Requirements: 2.20, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 3. Fix the meta-bug — audit-and-resolve sweep across all four apps and all 18 modules

  - [x] 3.1 Track A — Produce per-module coverage matrix and categorized defect inventory
    - Create `.kiro/specs/billing-app-end-to-end-audit/audit/coverage-matrix.md` with one row per `(app, module, screen, workflow)`, marked Audited / Not-Applicable across `Dukan_x` (`auto_parts`, `billing`, `book_store`, `clinic`, `clothing`, `computer_shop`, `decoration_catering`, `grocery`, `hardware`, `jewellery`, `mobile_shop`, `petrol_pump`, `pharmacy`, `restaurant`, `school_erp`/`academic_coaching`, `vegetables_broker`, `wholesale`, plus shared `customers`, `inventory`, `purchase`, `payment`, `delivery_challan`, `service`, `dashboard`, `onboarding`, `settings`) and the three school apps
    - Create `.kiro/specs/billing-app-end-to-end-audit/audit/defect-inventory.md` populated from Task 1 counterexamples using the schema in clause 2.18: `defect-id, app, module, screen/workflow, defect-class (D1..D11), severity (blocker/critical/major/minor), repro steps, observed, expected, proposed-fix-scope`
    - Tag each entry with the corresponding `isBugCondition` predicate it triggers (`exhibitsD1_navigation` … `exhibitsD11_domainCorrectness`) so Task 3.2 sub-tasks can pick them up by class
    - For every offline-capable module, ensure inventory entries exist for offline create/edit/delete, reconnect sync, multi-device concurrent edit, flaky network, forced kill mid-write, large-batch sync (clause 2.21)
    - Inventory is the source of truth for all sub-tasks under 3.2; later sub-tasks reference inventory entries by `defect-id`
    - _Bug_Condition: isBugCondition(X) over the full (app, module, screen, workflow, scenario) space_
    - _Expected_Behavior: per-clause expected behavior 2.1..2.16, plus inventory + matrix per 2.17, 2.18, 2.21_
    - _Preservation: full perimeter from §3 — audit walk does not mutate code_
    - _Requirements: 2.17, 2.18, 2.21_

  - [x] 3.2 Track B — Resolve every inventory entry, grouped by defect class
    - Each sub-task below picks up every inventory entry tagged with its defect class and applies the fix pattern from `design.md` § "Per-defect-class fix patterns". Every fix ships with its reproduction test (clause 2.19) and leaves preservation tests green (clause 2.20).

    - [x] 3.2.1 D1 — Navigation defects
      - Apply the fix pattern in `Dukan_x/lib/modules/<m>/routes/<m>_routes.dart`, `school_*/lib/core/router/app_router.dart`, and the destination screen files
      - Ensure every registered route resolves to a built screen; gate per-business-type entries behind `app_state_providers` selectors
      - Add `WillPopScope` / `PopScope` confirmations on wizards with unsaved input; ensure modals dismiss on route change
      - Add the navigation graph-walk integration test that opens every route and asserts a fully-implemented destination renders
      - _Bug_Condition: exhibitsD1_navigation(X) — clause 1.1, 1.2_
      - _Expected_Behavior: clause 2.1, 2.2_
      - _Preservation: 3.1, 3.4, 3.5_
      - _Requirements: 2.1, 2.2, 2.19, 2.20_

    - [x] 3.2.2 D2 — Placeholder / incomplete UI defects
      - Replace TODO / lorem / dummy strings with real data sources in the affected `*_screen.dart` and `*_widget.dart`
      - Remove non-functional controls or wire them to real handlers
      - Introduce or reuse a shared `EmptyState` / `ErrorState` / `LoadingState` triplet in `Dukan_x/lib/features/shared/widgets/` and adopt across list/grid screens
      - _Bug_Condition: exhibitsD2_placeholderUI(X) — clause 1.3, 1.4_
      - _Expected_Behavior: clause 2.3, 2.4_
      - _Preservation: 3.1, 3.5_
      - _Requirements: 2.3, 2.4, 2.19, 2.20_

    - [x] 3.2.3 D3 — Validation and business-rule defects
      - Register every validator on its `Form` key in `lib/features/<m>/utils/<m>_validators.dart` and `lib/core/localization/l10n_validators.dart`
      - Centralize business-rule constants (GST slabs, rounding mode, multi-unit factors, jewellery purity, fuel totalizer rollover) in a per-module `*_business_rules.dart`
      - Switch monetary math to fixed-precision (paise / `Decimal`) wherever floating-point is currently used
      - Cover each rule with a worked-example unit test referenced from the inventory entry
      - _Bug_Condition: exhibitsD3_validationOrBusinessRule(X) — clause 1.5, 1.6_
      - _Expected_Behavior: clause 2.5, 2.6_
      - _Preservation: 3.1, 3.2_
      - _Requirements: 2.5, 2.6, 2.19, 2.20_

    - [x] 3.2.4 D4 — Data-flow and persistence defects
      - Make multi-step writes atomic via a service that wraps local + remote + provider invalidation, with rollback on partial failure
      - Scope cache keys with tenant / business-type / account in repositories under `lib/features/<m>/data/repositories/` and providers under `lib/providers/`
      - Add invalidation on every mutation path so dependent screens see fresh data on re-open
      - _Bug_Condition: exhibitsD4_dataFlow(X) — clause 1.7, 1.8_
      - _Expected_Behavior: clause 2.7, 2.8_
      - _Preservation: 3.1, 3.3, 3.4_
      - _Requirements: 2.7, 2.8, 2.19, 2.20_

    - [x] 3.2.5 D5 — Offline / online / sync defects
      - Add durable idempotency keys per operation in the sync queue
      - Document and implement per-entity conflict-resolution policy (LWW / per-field merge / user-prompted)
      - Preserve queue order on reconnect; expose a conflict-recovery UI for unresolved cases
      - Cover every offline-capable module with the matrix from clause 2.21 (offline CRUD, reconnect, multi-device, flaky network, forced kill, large-batch)
      - _Bug_Condition: exhibitsD5_offlineOrSync(X) — clause 1.9, 1.10_
      - _Expected_Behavior: clause 2.9, 2.10_
      - _Preservation: 3.7 (queue order + idempotency keys honored for in-flight upgrades)_
      - _Requirements: 2.9, 2.10, 2.19, 2.20, 2.21_

    - [x] 3.2.6 D6 — State-consistency defects
      - Derive cross-module state via shared notifiers / `ref.watch` graphs so writes propagate without manual refresh
      - Replace direct repository reads in dependent providers with watch-based dependencies on the source provider
      - _Bug_Condition: exhibitsD6_stateConsistency(X) — clause 1.11_
      - _Expected_Behavior: clause 2.11_
      - _Preservation: 3.1_
      - _Requirements: 2.11, 2.19, 2.20_

    - [x] 3.2.7 D7 — Error-handling defects
      - Wrap I/O in `try/catch` with localized messages, structured logs, and a retry / fallback action across services (`*_service.dart`), repositories, and screens with I/O paths
      - Never expose raw stack traces; never freeze the UI
      - Cover PDF / print / scanner / camera paths with timeout + retry + localized message
      - _Bug_Condition: exhibitsD7_errorHandling(X) — clause 1.12_
      - _Expected_Behavior: clause 2.12_
      - _Preservation: 3.1_
      - _Requirements: 2.12, 2.19, 2.20_

    - [x] 3.2.8 D8 — RBAC defects
      - Centralize the role-permission matrix in a single `permissions/` module (introduce if absent)
      - Consult it at drawer, deep-link, action-button, and search-result entry points
      - Diff against existing grants to honor preservation 3.6 — fixes only tighten incorrect grants and loosen incorrect denials documented in the inventory
      - _Bug_Condition: exhibitsD8_rbac(X) — clause 1.13_
      - _Expected_Behavior: clause 2.13_
      - _Preservation: 3.6_
      - _Requirements: 2.13, 2.19, 2.20_

    - [x] 3.2.9 D9 — Performance defects
      - Paginate list / report / dashboard / search queries (`limit + cursor`) across DynamoDB scans and unbounded local queries
      - Add indexes on hot query paths
      - Offload heavy work (PDF render, CSV export, large aggregations) to `compute` / isolates
      - Collapse N+1 reads in dashboard widgets into batch queries
      - Verify against documented budgets: first frame within 1s on mid-tier devices, sustained 60fps during scroll
      - _Bug_Condition: exhibitsD9_performance(X) — clause 1.14_
      - _Expected_Behavior: clause 2.14_
      - _Preservation: 3.1 (timing class preserved on already-correct screens)_
      - _Requirements: 2.14, 2.19, 2.20_

    - [x] 3.2.10 D10 — Cross-module integration defects (depends on 3.2.4, 3.2.5, 3.2.6)
      - Implement each cross-module workflow as a saga with compensating actions in a shared service that owns the multi-module transaction (e.g., billing→inventory→ledger)
      - Surface partial-failure recovery
      - Add an integration test per boundary: billing→inventory→ledger→GST report; school fee→payment→receipt→ledger; purchase→stock→vendor ledger; jewellery old-gold-exchange→bill→stock; restaurant KOT→bill→kitchen; pharmacy→patient→bill; auto/computer service→job-card→bill→warranty
      - _Bug_Condition: exhibitsD10_crossModule(X) — clause 1.15_
      - _Expected_Behavior: clause 2.15_
      - _Preservation: 3.1, 3.4_
      - _Requirements: 2.15, 2.19, 2.20_

    - [x] 3.2.11 D11 — Domain-correctness defects per business type (depends on 3.2.3)
      - Encode the documented domain rule per vertical with worked-example tests in `lib/features/<m>/services/` and `lib/features/<m>/utils/` (jewellery purity / making-charges, petrol-pump nozzle/totalizer/shift, restaurant KOT/menu, school admission/attendance/exam/result/timetable/transport/hostel/library/fee, pharmacy batch/expiry/schedule, hardware dimension/area/volume, clothing tailoring measurements, vegetable-broker commission/mandi, wholesale price-tier, decoration-catering quote-to-invoice, book-store ISBN/return, clinic patient/appointment/prescription, auto-parts job-card lifecycle, computer-shop job-card)
      - Render artifacts (PDF, certificate, ID-card, report-card, KOT, prescription) with full data wiring verified by golden tests
      - _Bug_Condition: exhibitsD11_domainCorrectness(X) — clause 1.16_
      - _Expected_Behavior: clause 2.16_
      - _Preservation: 3.1, 3.5_
      - _Requirements: 2.16, 2.19, 2.20_

  - [~] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** — End-to-End Audit Surfaces No Defects
    - **IMPORTANT**: Re-run the SAME audit walk from Task 1 — do NOT write a new test
    - The audit from Task 1 encodes the expected behavior (clauses 2.1..2.16); when every reproduction sub-test passes, every inventory entry is resolved
    - Run the bug-condition exploration audit from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms every inventory entry is fixed and `isBugCondition(X)` no longer holds for any cataloged X)
    - _Requirements: Expected Behavior Properties from design (2.1..2.16, 2.17, 2.18, 2.19, 2.21)_

  - [~] 3.4 Verify preservation tests still pass
    - **Property 2: Preservation** — Already-Correct Workflows Untouched
    - **IMPORTANT**: Re-run the SAME tests from Task 2 — do NOT write new tests
    - Run the preservation property tests from step 2 plus the unchanged existing test suites across `Dukan_x`, `school_admin_app`, `school_teacher_app`, `school_student_app`
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions across outputs, persisted shape, navigation graph, RBAC grants, queue semantics, timing class, theming)
    - Confirm all tests still pass after fixes (no regressions)
    - _Requirements: 2.20, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [~] 4. Checkpoint — Ensure all tests pass
  - Run the full test suite across all four apps plus the new audit and preservation suites
  - Confirm the coverage matrix is fully populated (every row Audited / Not-Applicable) and every inventory entry is closed with its reproduction test green
  - Ensure all tests pass; ask the user if questions arise.

## Notes

- The defect inventory produced in Task 3.1 is the source of truth for every fix sub-task under 3.2. Each inventory row carries a `defect-id` and is tagged with its `isBugCondition` predicate (`exhibitsD1_navigation` … `exhibitsD11_domainCorrectness`); fix sub-tasks pick up entries by class.
- Every fix MUST ship with a reproduction test that fails on F and passes on F' (clause 2.19) and MUST leave the preservation suite from Task 2 green (clause 2.20).
- The four-app perimeter is: `Dukan_x`, `school_admin_app`, `school_teacher_app`, `school_student_app`. The 18-module perimeter inside `Dukan_x` is enumerated in `design.md` § Glossary.
- Property-based testing is the primary tool for both Property 1 (per-class generators that sample buggy inputs) and Property 2 (generators that filter `NOT isBugCondition(X)` and assert `F(X) == F'(X)`).
- Schema migrations introduced by D4 fixes ship forward-only with zero data loss for upgrading users (clause 3.3); route renames ship with deprecation shims rather than removals (clause 3.4).

## Architectural prerequisite for D1 (discovered during Task 3.2.1)

The 84 remaining D1 navigation defects target route tables under
`Dukan_x/lib/modules/<m>/routes/*_routes.dart`. These tables are
assembled by `ModuleRouteBuilder` and intended for a `GoRouter` instance,
but the shipped `MaterialApp` in `lib/app/app.dart` still uses the
legacy `routes:` map produced by `buildAppRoutes()` in `lib/app/routes.dart`.
The module tables therefore have no runtime effect today — they are dead
code waiting on a router migration.

Recommended sequence for the rest of D1:

1. Migrate `MaterialApp` to `MaterialApp.router` driven by a `GoRouter`
   instance built via `ModuleRouteBuilder.instance.buildRoutes(...)`.
   Update every `Navigator.pushNamed` / `Navigator.of(context)` call site
   to the equivalent `context.go(...)` / `context.push(...)`.
2. Wire each module-route entry to its real screen under
   `lib/features/<m>/presentation/screens/`. The pattern shown in
   `lib/modules/auto_parts/routes/auto_parts_routes.dart` (jobcards entry)
   is the template.
3. Add navigation graph-walk integration tests that open every registered
   route and assert a fully-implemented destination renders.

Until step 1 lands, further per-route placeholder swaps in step 2 only
clear inventory rows on the static walker, with no user-visible effect.
