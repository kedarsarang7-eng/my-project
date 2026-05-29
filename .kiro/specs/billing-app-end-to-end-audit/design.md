# Billing App End-to-End Audit Bugfix Design

## Overview

This is a **meta-bugfix design**. The "bug" is not a single defect: it is the
assertion that the billing/accounting platform — spanning four Flutter apps
(`Dukan_x`, `school_admin_app`, `school_teacher_app`, `school_student_app`)
and ~18 business-type modules plus shared features — contains an unknown set
of latent defects belonging to 11 well-defined defect classes (D1..D11)
defined in `bugfix.md`.

The fix strategy therefore has two phases that share one design:

1. **Audit phase (discovery).** Systematically walk every module × screen ×
   workflow × scenario, exercise it under realistic conditions (online,
   offline, reconnect, multi-device, large data, invalid input, restricted
   role, edge case), and produce a categorized **defect inventory** that is
   the concrete enumeration of the meta-bug.
2. **Fix phase (resolution).** For each inventory entry, apply a minimal,
   targeted fix that satisfies the per-defect Fix property and the
   per-defect Preservation property, with a reproduction test that fails on
   F and passes on F'.

The design below formalizes the bug condition, the preservation perimeter,
the hypothesized root causes per defect class, the implementation approach
per defect class, and the testing strategy that ties everything back to the
acceptance criteria in `bugfix.md`.

## Glossary

- **Bug_Condition (C)**: A workflow `X = (module, screen, workflow, scenario)`
  exhibits at least one defect class from `{D1..D11}` when exercised
  end-to-end.
- **Property (P)**: For every X where C holds, F'(X) exhibits no defect from
  `{D1..D11}` and matches the documented expected behavior in §2 of
  `bugfix.md`.
- **Preservation**: For every X where C does NOT hold, F'(X) is observably
  identical to F(X) — same outputs, persisted shape, navigation, UI, and
  timing class (per §3 of `bugfix.md`).
- **F / F'**: Codebase before / after the audit-and-fix sweep.
- **D1..D11**: The eleven defect classes defined in `bugfix.md` §1
  (navigation, placeholder UI, validation/business rules, data flow,
  offline/sync, state consistency, error handling, RBAC, performance,
  cross-module integration, domain correctness).
- **Defect inventory**: The structured list of every cataloged defect
  instance. Source of truth for tasks generated in Phase 3.
- **Audit coverage matrix**: Per-module × per-screen × per-workflow grid
  marked Audited / Not-Applicable, proving §2.17.
- **Module**: A business-type vertical under `Dukan_x/lib/features/<m>` and/or
  `Dukan_x/lib/modules/<m>/routes`. Includes `auto_parts`, `billing`,
  `book_store`, `clinic`, `clothing`, `computer_shop`, `decoration_catering`,
  `grocery`, `hardware`, `jewellery`, `mobile_shop`, `petrol_pump`,
  `pharmacy`, `restaurant`, `school_erp`/`academic_coaching`,
  `vegetables_broker`, `wholesale`, plus shared features (`customers`,
  `inventory`, `purchase`, `payment`, `delivery_challan`, `service`,
  `dashboard`, `onboarding`, `settings`).
- **App**: One of the four Flutter apps in the workspace.
- **Scenario**: One of `{online, offline, reconnect-sync, multi-device,
  concurrent-edit, large-data, invalid-input, permission-restricted,
  edge-case}`.

## Bug Details

### Bug Condition

The bug manifests when any user-reachable workflow X, exercised under any
documented scenario, exhibits one or more of the defect classes D1..D11.
Because the defect set is heterogeneous, the bug condition is a disjunction
over defect-class predicates rather than a single boolean check on input.

**Formal Specification:**

```
FUNCTION isBugCondition(X)
  INPUT: X = (app, module, screen, workflow, scenario)
         scenario IN {online, offline, reconnect-sync, multi-device,
                      concurrent-edit, large-data, invalid-input,
                      permission-restricted, edge-case}
  OUTPUT: boolean

  RETURN exhibitsD1_navigation(X)
      OR exhibitsD2_placeholderUI(X)
      OR exhibitsD3_validationOrBusinessRule(X)
      OR exhibitsD4_dataFlow(X)
      OR exhibitsD5_offlineOrSync(X)
      OR exhibitsD6_stateConsistency(X)
      OR exhibitsD7_errorHandling(X)
      OR exhibitsD8_rbac(X)
      OR exhibitsD9_performance(X)
      OR exhibitsD10_crossModule(X)
      OR exhibitsD11_domainCorrectness(X)
END FUNCTION
```

Each `exhibitsDk_*(X)` predicate is the negation of the corresponding
expected-behavior clause 2.k in `bugfix.md` §2.

### Examples

Concrete representative manifestations the audit should expect to find
(non-exhaustive — the inventory enumerates the real set):

- **D1**: Tapping a drawer item under `modules/jewellery/routes` opens an
  empty scaffold or throws `RouteNotFoundException` because the route is
  registered in code but the destination screen is not implemented. Expected:
  the entry navigates to a fully-implemented screen, or is hidden for
  business types where it does not apply.
- **D2**: A "Coming soon" tab in `gold_scheme_screen.dart` or a button in
  `payment_analytics_screen.dart` wired to no handler. Expected: only
  production-ready, wired controls render.
- **D3**: GST calculator on a clothing invoice produces an incorrect
  CGST/SGST split when the line item crosses a rate slab. Expected:
  numerically-correct split per the documented business rule.
- **D4**: Creating a customer in `customer_management_screen.dart` writes
  to Hive but the provider state is not refreshed, so the same customer
  appears missing on the next screen open. Expected: atomic write + cache
  invalidation across local, remote, and provider state.
- **D5**: An invoice created offline in the restaurant module is dropped
  on reconnect because the queue lacks an idempotency key. Expected:
  durable queue, deterministic reconcile, no loss/duplication.
- **D11**: The petrol-pump shift-close totalizer mis-rounds when the
  nozzle reading wraps a digit boundary. Expected: domain-correct
  totalizer per the documented formula.
- **Edge case (D9)**: The inventory dashboard freezes for 4s when product
  count exceeds ~5k because the query is unpaginated. Expected: paginated,
  indexed, isolate-offloaded under documented budgets.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors** (full perimeter is `bugfix.md` §3):

- Workflows already correct in F continue to produce identical observable
  behavior in F': same outputs, persisted data shape, navigation graph, UI,
  and timing class (3.1).
- All currently-passing tests across the four apps continue to pass without
  modification, except where a test itself encoded buggy behavior and is
  explicitly updated as part of the corresponding inventory entry (3.2).
- Existing persisted data (Hive / SQLite / Drift / Isar boxes; DynamoDB
  records) opens correctly in F'; any schema change ships with a forward
  migration and zero data loss on upgrade (3.3).
- Public route names, deep links, persisted keys, and external API surfaces
  remain honored; renames ship with deprecation shims, not removals (3.4).
- Per-business-type theming, iconography, and terminology are preserved
  unless the inventory explicitly classifies a visual as a D2 placeholder
  (3.5).
- RBAC grants already permitted in F remain permitted in F'; fixes only
  tighten incorrect grants and loosen incorrect denials documented in the
  inventory (3.6).
- Offline workflows that already worked correctly retain their queue
  semantics, ordering, and idempotency keys so devices upgraded mid-pending
  do not lose queued operations (3.7).

**Scope:**
All inputs X where `NOT isBugCondition(X)` must be completely unaffected by
this audit-and-fix sweep. This includes (but is not limited to):

- Already-correct navigation, lists, and forms across every module.
- Already-correct GST and domain calculations on the inputs they currently
  handle correctly.
- Already-correct offline queue and sync flows.
- Already-correct RBAC enforcement.
- Already-correct cross-module hand-offs.

The actual expected correct behavior for buggy inputs is defined under
**Correctness Properties** below.

## Hypothesized Root Cause

Because the bug is a meta-bug, root causes are hypothesized per defect
class. The audit confirms or refutes these per concrete inventory entry; if
refuted, that entry triggers a targeted re-hypothesis before its fix lands.

1. **D1 Navigation defects** — Likely causes:
   - Routes registered in `modules/<m>/routes/*_routes.dart` whose
     destination screen was never built (placeholder scaffold) or was
     deleted/renamed without updating the route table.
   - Drawer / bottom-nav entries hard-coded across business types instead
     of gated by `app_state_providers` business-type selector.
   - Back-navigation that pops past a wizard root without confirmation,
     and modals that do not dismiss themselves on route change.

2. **D2 Placeholder / incomplete UI** — Likely causes:
   - "TODO"/"Coming soon" strings left in module screens shipped behind
     feature flags that are now on by default.
   - Tabs and dropdowns wired to empty lists instead of real data sources.
   - Empty/error/loading states not implemented because list widgets
     assume a happy-path data shape.

3. **D3 Validation and business rules** — Likely causes:
   - Form widgets that accept input without invoking a validator, or
     validators that are defined but not registered with the `Form` key.
   - Business-rule constants (GST slabs, rounding mode, multi-unit
     factors, jewellery purity, fuel totalizer rollover) duplicated across
     modules and drifting out of sync.
   - Floating-point arithmetic used where fixed-precision (paise / `Decimal`)
     is required.

4. **D4 Data flow and persistence** — Likely causes:
   - Writes that hit local store but bypass the provider invalidation,
     or hit the provider but never persist.
   - Cache keys that omit tenant/business-type/account scoping, causing
     cross-account leakage or stale reads.
   - Non-atomic multi-step writes (e.g., create invoice + decrement stock
     + ledger entry) without rollback on partial failure.

5. **D5 Offline / online / sync** — Likely causes:
   - Operation queue without durable idempotency keys, so retries
     duplicate.
   - Conflict resolution policy not documented, so concurrent edits
     silently last-writer-wins on whole records when per-field merge was
     intended.
   - Reconnect path that flushes the queue without preserving order, or
     drops failed entries instead of surfacing them in a recovery UI.

6. **D6 State consistency** — Likely causes:
   - Riverpod providers that own derived state but do not depend on the
     source provider that mutates.
   - Cross-module dependencies expressed via direct repository reads
     instead of a shared notifier, so one screen's write never reaches
     another's rebuild.

7. **D7 Error handling** — Likely causes:
   - `try/catch` blocks that swallow exceptions silently, or `Future`s
     awaited without `catchError` so errors bubble to the framework as
     red screens.
   - PDF / print / scanner / camera paths missing timeout + retry +
     localized message.

8. **D8 RBAC** — Likely causes:
   - Permission checks duplicated at each entry point (drawer, deep link,
     action button) and drifted out of sync.
   - Role definitions not centralized, so a new screen forgets to consult
     the role gate.

9. **D9 Performance** — Likely causes:
   - Unpaginated DynamoDB scans / unbounded local queries on list
     screens.
   - Heavy work (PDF render, CSV export, large aggregations) on the UI
     isolate.
   - N+1 reads in dashboard widgets that fan out per-row.

10. **D10 Cross-module integration** — Likely causes:
    - Module boundaries crossed by direct repository calls instead of a
      shared transactional service, so a partial failure leaves orphaned
      records.
    - Event hand-offs (billing → inventory → ledger) implemented as
      best-effort fire-and-forget without a saga or compensating action.

11. **D11 Domain correctness per business type** — Likely causes:
    - Business rules encoded once in a generic helper that does not
      handle per-vertical edge cases (jewellery purity rounding,
      petrol-pump rollover, restaurant KOT split, school fee pro-rata,
      pharmacy batch/expiry).
    - Artifacts (PDFs, certificates, ID-cards, report-cards, KOTs)
      generated from templates whose data wiring missed a field.

## Correctness Properties

Property 1: Bug Condition — Defect Inventory is Resolved

_For any_ workflow `X = (app, module, screen, workflow, scenario)` where
the bug condition holds (`isBugCondition(X)` returns true, i.e., X exhibits
at least one defect class from `{D1..D11}`), the fixed system F' SHALL
produce behavior that exhibits **none** of the defect classes from
`{D1..D11}` and SHALL satisfy the corresponding documented expected
behavior clause(s) (2.1 through 2.16) in `bugfix.md` §2. Additionally, the
audit SHALL produce the per-module coverage matrix and categorized defect
inventory described in 2.17–2.18, every fix SHALL ship with a reproduction
test per 2.19, and offline/sync coverage SHALL include all scenarios per
2.21.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15, 2.16, 2.17, 2.18, 2.19, 2.21**

Property 2: Preservation — Already-Correct Workflows Are Untouched

_For any_ workflow X where the bug condition does NOT hold
(`isBugCondition(X)` returns false), the fixed system F' SHALL produce
exactly the same observable behavior as F(X), preserving outputs,
persisted data shape, navigation graph, UI presentation, timing class,
existing route names and deep links, persisted storage keys, RBAC grants
that were already correct, per-business-type theming, and offline-queue
semantics including ordering and idempotency keys.

**Validates: Requirements 2.20, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Fix Implementation

### Changes Required

The fix is delivered in two coordinated tracks. Track A produces the
inventory; Track B resolves it. Both share the same per-defect-class
implementation patterns below.

**Track A — Audit & Inventory (delivers 2.17, 2.18, 2.21)**

Files (new):
- `.kiro/specs/billing-app-end-to-end-audit/audit/coverage-matrix.md`
- `.kiro/specs/billing-app-end-to-end-audit/audit/defect-inventory.md`

Per-module audit walk (one row per `(app, module, screen, workflow)`):
1. Enumerate routes from `Dukan_x/lib/modules/<m>/routes/*_routes.dart`
   and screen files under `Dukan_x/lib/features/<m>/presentation/screens/`,
   plus equivalents in the three school apps.
2. For each screen, exercise: open, primary CRUD, list/grid empty/error/
   loading, validation paths, business-rule calculations, navigation
   in/out, back-gesture, RBAC for each role, offline create/edit/delete,
   reconnect-sync, multi-device, large-data, cross-module hand-offs.
3. Mark each row Audited / Not-Applicable in the coverage matrix.
4. For each defect found, append an inventory row with the schema in
   2.18: `defect-id, app, module, screen/workflow, defect-class (D1..D11),
   severity, repro steps, observed, expected, proposed-fix-scope`.

**Track B — Per-defect-class fix patterns**

Each inventory entry is fixed using the smallest change that satisfies its
Fix property without breaching its Preservation perimeter. The patterns
below are the default approach per defect class; deviations are documented
on the inventory entry.

1. **D1 Navigation fixes**
   - File: `Dukan_x/lib/modules/<m>/routes/<m>_routes.dart`,
     `school_*/lib/core/router/app_router.dart`, plus the destination
     screen files.
   - Pattern: ensure every registered route resolves to a built screen;
     gate per-business-type entries behind `app_state_providers`
     selectors; add a `WillPopScope` / `PopScope` confirmation on
     wizards with unsaved input; ensure modals dismiss on route change.

2. **D2 Placeholder UI fixes**
   - Files: affected `*_screen.dart` and `*_widget.dart`.
   - Pattern: replace TODO/lorem/dummy with real data sources; remove
     non-functional controls or wire them; introduce a reusable
     `EmptyState`, `ErrorState`, `LoadingState` triplet (extend
     `features/shared/widgets/` if absent) and adopt across list/grid
     screens.

3. **D3 Validation & business-rule fixes**
   - Files: `lib/features/<m>/utils/<m>_validators.dart`,
     `lib/core/localization/l10n_validators.dart`, calculator services.
   - Pattern: register all validators on `Form`; centralize business-rule
     constants in a per-module `*_business_rules.dart`; switch monetary
     math to fixed-precision; cover each rule with a worked-example
     unit test referenced from the inventory entry.

4. **D4 Data-flow fixes**
   - Files: repositories under `lib/features/<m>/data/repositories/`,
     providers under `lib/providers/` and feature-local providers.
   - Pattern: make multi-step writes atomic via a service that wraps
     local + remote + provider invalidation, with rollback on partial
     failure; scope cache keys with tenant/business-type/account.

5. **D5 Offline/sync fixes**
   - Files: sync queue, repositories, `app_state_providers.dart`.
   - Pattern: durable idempotency keys per operation; documented
     conflict-resolution policy per entity (LWW / per-field merge /
     user-prompted); preserve queue order on reconnect; expose a
     conflict-recovery UI.

6. **D6 State-consistency fixes**
   - Files: providers and notifiers across features.
   - Pattern: derive cross-module state via shared notifiers / `ref.watch`
     graphs so writes propagate without manual refresh.

7. **D7 Error-handling fixes**
   - Files: services (`*_service.dart`), repositories, screens with
     I/O paths.
   - Pattern: wrap I/O in `try/catch` with localized messages, structured
     logs, and a retry/fallback action; never expose raw stack traces;
     never freeze the UI.

8. **D8 RBAC fixes**
   - Files: a single `permissions/*` module (introduce if absent) plus
     entry-point gates.
   - Pattern: centralize the role-permission matrix; consult it at
     drawer, deep-link, action-button, and search-result entry points;
     diff against existing grants to honor preservation 3.6.

9. **D9 Performance fixes**
   - Files: list/dashboard/report screens and their data sources.
   - Pattern: paginate (`limit + cursor`); index queries; offload heavy
     work (`compute` / isolates); collapse N+1 reads into batch queries;
     verify against documented budgets (1s first frame, 60fps scroll).

10. **D10 Cross-module integration fixes**
    - Files: shared service that owns the multi-module transaction
      (e.g., billing→inventory→ledger).
    - Pattern: implement as a saga with compensating actions; surface
      partial-failure recovery; add an integration test per boundary.

11. **D11 Domain-correctness fixes**
    - Files: per-vertical service / calculator / template (jewellery,
      petrol-pump, restaurant, school, pharmacy, etc.).
    - Pattern: encode the documented domain rule with worked-example
      tests; render artifacts (PDF, certificate, ID-card, report-card,
      KOT) with full data wiring verified by golden tests.

## Testing Strategy

### Validation Approach

Two-phase, identical to the workflow's bug-condition methodology:

1. **Exploratory phase** — exercise UNFIXED code (F) under each scenario
   to surface counterexamples and confirm or refute the per-class root
   cause hypotheses. Refutations trigger a re-hypothesis on the affected
   inventory entry before its fix lands.
2. **Verification phase** — for each inventory entry, write a failing
   reproduction test on F, apply the fix, and verify the test passes on
   F' while every preservation test for the same and adjacent modules
   still passes.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the meta-bug BEFORE
implementing fixes. Confirm or refute the per-class root cause analysis.
If refuted, re-hypothesize on the affected inventory entry.

**Test Plan**: Run a structured per-module audit walk over UNFIXED code,
exercising each scenario and recording each failure as an inventory entry.
Failures observed during exploration directly seed the reproduction tests
required by 2.19.

**Test Cases** (representative; the full set is the inventory):
1. **D1 — Navigation walk**: Tap every drawer / route / deep link in every
   module under every business type; record every dead-end, route-not-
   found, or wrong destination (will fail on unfixed code).
2. **D2 — Placeholder sweep**: Open every screen, tab, dialog, dropdown;
   record every TODO/lorem/non-functional control (will fail on unfixed
   code).
3. **D3 — Validation/business-rule sweep**: Submit invalid input and
   business-rule edge cases (boundary GST slabs, multi-unit conversion,
   jewellery purity, petrol totalizer rollover, fee pro-rata, KOT split)
   on every form / calculator (will fail on unfixed code).
4. **D4–D6 — Data/sync/state sweep**: For each module, create-edit-delete,
   then reopen the dependent screens; toggle offline/online; open the
   same account on two devices and edit concurrently (will fail on
   unfixed code).
5. **D7 — Error sweep**: Force backend timeouts, file I/O failures,
   scanner/camera/PDF/print failures; record any unhandled exception or
   frozen UI (will fail on unfixed code).
6. **D8 — RBAC sweep**: For each role, attempt every action via every
   entry point; record inconsistencies (will fail on unfixed code).
7. **D9 — Performance sweep**: Seed realistic data volumes (≥5k products,
   ≥10k invoices, ≥2k students); measure first-frame and scroll FPS on
   list/report/dashboard screens (will fail on unfixed code where
   pagination/indexing/isolates are missing).
8. **D10 — Cross-module sweep**: Run end-to-end flows across module
   boundaries (billing→inventory→ledger→GST report; school fee→payment→
   receipt→ledger; purchase→stock→vendor ledger; jewellery old-gold-
   exchange→bill→stock; restaurant KOT→bill→kitchen; pharmacy→patient→
   bill; auto/computer service→job-card→bill→warranty); record any
   partial state at a boundary (will fail on unfixed code).
9. **D11 — Domain-correctness sweep**: Run each business-type signature
   workflow end-to-end and verify the produced artifact (invoice,
   receipt, certificate, ID-card, prescription, report-card, KOT print)
   matches the documented expected output (will fail on unfixed code).
10. **Edge case — Offline/reconnect/multi-device matrix**: Per
    offline-capable module, run offline create/edit/delete, reconnect
    sync, multi-device concurrent edit, flaky network, forced kill
    mid-write, and large-batch sync (per 2.21; may fail on unfixed code).

**Expected Counterexamples**:
- A heterogeneous set of failures distributed across D1..D11; each
  failure becomes one inventory entry.
- Possible causes per class are listed under **Hypothesized Root Cause**
  above; refutations are recorded on the inventory entry.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the
fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL X WHERE isBugCondition(X) DO
  result := F_prime(X)
  ASSERT NOT exhibitsAnyDefectClass(result, {D1..D11})
        AND result satisfies expected behavior clause 2.k for the
        defect class(es) k that originally held on X
END FOR
```

In practice, "FOR ALL X" is realized as the union of:
- The reproduction test attached to every inventory entry (2.19), each
  failing on F and passing on F'.
- The per-class property-based tests defined under **Property-Based
  Tests** below, which sample over the input domain to catch instances
  the explicit inventory missed.

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT
hold, the fixed function produces the same result as the original
function.

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F_prime(X)
END FOR
```

**Testing Approach**: Property-based testing is the primary tool for
preservation here, complemented by the existing test suite serving as a
fixed regression baseline (2.20, 3.2). PBT is preferred because:
- It generates many inputs automatically across each module's domain.
- It catches edge cases manual unit tests miss (boundary GST slabs,
  rounding, totalizer rollover, multi-unit conversion).
- It provides strong guarantees of unchanged behavior for non-buggy
  inputs.

**Test Plan**: For each module, capture the current F behavior on
representative non-bug inputs (golden snapshots of UI, persisted shape,
calculation results, route graph), then assert F' produces identical
output for the same inputs. PBT generators sample non-bug inputs by
filtering `NOT isBugCondition(X)`.

**Test Cases**:
1. **Existing test suites**: Run all existing tests across `Dukan_x`,
   `school_admin_app`, `school_teacher_app`, `school_student_app`
   unchanged; observe pass on F and require pass on F' (per 3.2).
2. **Persisted-data round-trip**: Open Hive / SQLite / Drift / Isar
   boxes and DynamoDB records written by F; verify F' reads them
   correctly and any schema migration is forward-only (per 3.3).
3. **Route / deep-link / persisted-key honoring**: Exercise every
   public route name, deep link, and persisted storage key; verify F'
   honors them with deprecation shims for any rename (per 3.4).
4. **RBAC preservation**: For each role, exercise every action that was
   permitted in F; verify F' permits exactly that set (per 3.6).
5. **Offline-queue preservation**: Devices upgraded mid-pending-sync
   retain queued operations with the same ordering and idempotency
   keys (per 3.7).

### Unit Tests

- Per-module validator coverage (D3): one test per business rule with
  a worked example.
- Per-module business-rule calculator coverage (D3, D11): GST splits,
  rounding, multi-unit conversion, jewellery purity, fuel totalizer,
  KOT split, fee pro-rata, payroll, etc.
- Per-module empty/error/loading state rendering (D2).
- Per-module error-path coverage for I/O, PDF, print, scanner, camera
  (D7).

### Property-Based Tests

- **Bug-condition property** (Fix): for inputs sampled to satisfy
  `isBugCondition(X)` on F (e.g., random invalid form inputs, random
  large data sets, random offline/online sequences), assert F' produces
  the documented expected behavior 2.1..2.16.
- **Preservation property**: for inputs sampled to satisfy
  `NOT isBugCondition(X)` on F, assert `F(X) == F'(X)` over outputs,
  persisted shape, and navigation graph.
- **Domain-rule properties** (D11): per-vertical generators for
  jewellery purity / making-charges, petrol-pump nozzle/totalizer,
  restaurant KOT/menu, school fee/exam/result, pharmacy batch/expiry,
  hardware dimension/area/volume, etc.
- **Sync property** (D5): random sequences of offline create/edit/
  delete + reconnect + multi-device concurrent edits converge to a
  deterministic state per the documented conflict-resolution policy.

### Integration Tests

- **Cross-module sagas** (D10): billing→inventory→ledger→GST report;
  school fee→payment→receipt→ledger; purchase→stock→vendor ledger;
  jewellery old-gold-exchange→bill→stock; restaurant KOT→bill→kitchen;
  pharmacy→patient→bill; auto/computer service→job-card→bill→warranty.
  Each test runs end-to-end and verifies all dependent records exist
  and agree, or are rolled back atomically on injected failure.
- **Offline/online lifecycle** (D5, 2.21): per offline-capable module,
  offline create/edit/delete → reconnect → assert convergence; flaky
  network; forced kill mid-write; large-batch sync.
- **Visual / artifact goldens** (D11): invoice PDFs, receipts,
  certificates, ID-cards, prescriptions, report-cards, KOT prints
  rendered against frozen golden files per business type.
- **Navigation graph** (D1): a graph-walk test that opens every route
  registered in every `*_routes.dart` and asserts a fully-implemented
  destination renders.
