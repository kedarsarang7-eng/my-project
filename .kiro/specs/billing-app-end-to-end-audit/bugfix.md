# Bugfix Requirements Document

## Introduction

This is a META-bugfix spec covering an end-to-end audit-and-fix sweep of the
billing/accounting platform across all Flutter apps in the workspace
(`Dukan_x`, `school_admin_app`, `school_teacher_app`, `school_student_app`)
and across every supported business-type module
(`auto_parts`, `billing`, `book_store`, `clinic`, `clothing`, `computer_shop`,
`decoration_catering`, `grocery`, `hardware`, `jewellery`, `mobile_shop`,
`petrol_pump`, `pharmacy`, `restaurant`, `school_erp` /
`academic_coaching`, `vegetables_broker`, `wholesale`, plus shared features
such as `customers`, `inventory`, `purchase`, `payment`, `delivery_challan`,
`service`, `dashboard`, `onboarding`, `settings`).

The "bug" being fixed is not a single defect but the assertion that the
codebase contains an unknown set of latent defects of one or more
well-defined defect classes (navigation, data flow, sync, state, validation,
UI/UX placeholder, performance, permissions, error handling, feature
integration, domain workflow correctness).

The output of this spec is twofold:

1. A categorized **defect inventory** produced by a systematic per-module
   audit (this serves as the concrete enumeration of the meta-bug).
2. A set of fixes that resolve every cataloged defect while preserving all
   currently-correct behavior (the standard bugfix Fix + Preservation
   properties applied per-defect).

Impact: Until this audit and fix sweep is complete, business owners,
accountants, shopkeepers, distributors, wholesalers, retailers, and service
providers using the platform may encounter broken workflows, lost data, sync
conflicts, incorrect calculations (GST, inventory, ledgers), placeholder
screens, or unhandled error states under realistic real-world usage,
including offline-first and multi-device scenarios.

### Bug Condition (C) and Property (P) — Meta Form

```pascal
FUNCTION isBugCondition(X)
  INPUT: X = (module, screen, workflow, scenario)
         where scenario covers: online, offline, reconnect-sync,
         multi-device, concurrent-edit, large-data, invalid-input,
         permission-restricted, edge-case
  OUTPUT: boolean

  // X is a buggy workflow if, when exercised end-to-end under the given
  // scenario, it exhibits at least one defect class from D1..D11
  // (see Section 1).
  RETURN exhibitsAnyDefectClass(X, {D1..D11})
END FUNCTION
```

```pascal
// Property: Fix Checking
FOR ALL X WHERE isBugCondition(X) DO
  result <- F'(X)
  ASSERT NOT exhibitsAnyDefectClass(result, {D1..D11})
        AND result satisfies the documented expected behavior in Section 2
END FOR

// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)   // unchanged workflows behave identically
END FOR
```

Where **F** is the codebase before this audit/fix sweep and **F'** is the
codebase after all cataloged defects are resolved.

## Bug Analysis

### Current Behavior (Defect)

The defect classes below are the categories the audit MUST search for in
every module and workflow. Each `WHEN ... THEN ...` clause describes the
*incorrect* behavior currently exhibited by at least some user-reachable
workflow X in F. The audit's job is to enumerate the concrete instances per
clause into the defect inventory.

**D1 — Navigation defects**

1.1 WHEN a user taps a navigation entry (drawer item, route, deep link,
    bottom-nav tab, action button, list-tile chevron) for any module screen
    THEN the system navigates to a missing route, a dead-end screen, the
    wrong screen, an empty scaffold, or throws a route-not-found error.

1.2 WHEN a user uses Back, system back-gesture, or close on a nested
    screen (modal, dialog, wizard step, multi-step flow) THEN the system
    pops to an inconsistent state, loses unsaved input without warning, or
    leaves orphaned overlays/modals on screen.

**D2 — Placeholder / incomplete UI defects**

1.3 WHEN a user opens any screen, tab, dialog, or dropdown across any
    module THEN the system renders placeholder text ("TODO", "Coming
    soon", lorem-style strings), dummy/hardcoded data, non-functional
    buttons, empty tabs, or controls wired to no handler.

1.4 WHEN a user triggers a list/grid screen with zero records, an error,
    or while loading THEN the system fails to render an appropriate
    empty-state, error-state, or loading-state and instead shows a blank
    screen, infinite spinner, or a misleading "no data" when data is
    actually loading or errored.

**D3 — Validation and business-rule defects**

1.5 WHEN a user submits a form (invoice, bill, customer, vendor,
    product, payment, expense, ledger entry, GST detail, school
    student/fee, patient, job-card, etc.) with missing, malformed,
    out-of-range, or business-rule-violating input THEN the system
    accepts the input, persists corrupt data, crashes, or fails silently
    instead of producing a clear, localized validation error.

1.6 WHEN a domain calculation runs (GST/CGST/SGST/IGST split, rounding,
    discount stacking, making-charges, gold-rate conversion, multi-unit
    conversion, stock decrement, FIFO/LIFO costing, ledger balancing,
    fuel-pump totalizer, restaurant KOT split, hardware
    dimension/area/volume, jewellery purity, exam-mark aggregation, fee
    pro-rata, payroll, etc.) THEN the system produces an incorrect
    numeric result, wrong tax breakup, or inconsistent rounding versus
    the documented business rule.

**D4 — Data-flow and persistence defects**

1.7 WHEN a user creates, edits, or deletes a record on any screen THEN
    the system writes inconsistent or partial data to local storage
    (Hive/SQLite/Drift/SharedPreferences/Isar), backend (Node/DynamoDB/
    REST), and in-memory provider state — leaving the three views of
    the same entity disagreeing.

1.8 WHEN a screen re-opens or a list re-loads after a write THEN the
    system shows stale data, missing newly-created records, or records
    that were just deleted, because of missing invalidation, missing
    refresh, or incorrect cache keys.

**D5 — Offline / online / sync defects**

1.9 WHEN the device is offline and the user performs any
    create/edit/delete operation across any module THEN the system
    fails the operation, loses the write, or queues it incorrectly so
    that on reconnect the change is not applied or is applied out of
    order.

1.10 WHEN connectivity is restored after offline use, or the same
     account is used on multiple devices, THEN the system fails to
     reconcile concurrent edits, drops conflicting writes silently,
     duplicates records, or leaves the local and remote stores
     permanently divergent without a recovery path.

**D6 — State-management and consistency defects**

1.11 WHEN one screen mutates an entity that another open screen, tab,
     or widget depends on (cross-module: e.g., inventory write affects
     billing screen totals; payment write affects ledger; student
     promotion affects fee schedule) THEN the system fails to propagate
     the change, leaving dependent screens showing stale or contradictory
     values until a manual refresh or app restart.

**D7 — Error handling and fallback defects**

1.12 WHEN a backend call, file I/O, PDF/print, scanner, camera, or
     local-DB operation fails or times out THEN the system throws an
     unhandled exception, shows a raw stack trace, freezes the UI, or
     silently swallows the error without informing the user or offering
     a retry/fallback path.

**D8 — Permissions and role-based access defects**

1.13 WHEN a user with a restricted role (staff, accountant, teacher,
     student, parent, kitchen-staff, etc.) opens a screen, action, or
     report they should not be able to access THEN the system either
     allows the action, hides it inconsistently across entry points, or
     blocks legitimate access for an authorized role.

**D9 — Performance defects**

1.14 WHEN a list, report, dashboard, or search runs over a realistic
     data volume (thousands of products, invoices, students, patients,
     ledger entries) THEN the system causes UI jank, frame drops over
     16ms budget, multi-second blocking loads, or out-of-memory on
     low-end devices because of unbounded queries, missing pagination,
     synchronous heavy work on the UI isolate, or N+1 reads.

**D10 — Cross-module integration defects**

1.15 WHEN a workflow crosses module boundaries (e.g., billing -> inventory
     -> ledger -> GST report; school fee -> payment -> receipt -> ledger;
     purchase -> stock -> vendor ledger; jewellery old-gold-exchange ->
     bill -> stock; restaurant KOT -> bill -> kitchen; pharmacy -> patient
     -> bill; auto/computer service -> job-card -> bill -> warranty) THEN
     the system fails at a boundary: the originating record is created
     but the dependent record is missing, partial, or inconsistent.

**D11 — Domain-correctness defects (per business type)**

1.16 WHEN a business-type-specific workflow runs end-to-end (auto-parts
     job-card lifecycle, jewellery purity / hallmark / scheme / repair,
     hardware dimension calc, clothing tailoring measurements,
     petrol-pump nozzle/totalizer/shift, pharmacy batch/expiry/schedule,
     restaurant table/KOT/menu, school admission/attendance/exam/result/
     timetable/transport/hostel/library/fee, vegetable-broker commission/
     mandi, wholesale price-tier, decoration-catering quote-to-invoice,
     book-store ISBN/return, clinic patient/appointment/prescription)
     THEN the system fails to produce the domain-correct artifact
     (invoice, receipt, report, certificate, ID-card, prescription,
     report-card, KOT print, etc.) under at least one realistic input.

### Expected Behavior (Correct)

For each defect clause above, the corresponding clause below states the
correct behavior the fixed system F' MUST deliver.

**D1 — Navigation**

2.1 WHEN a user taps any navigation entry across any module THEN the
    system SHALL navigate to a fully-implemented destination screen, OR
    explicitly hide/disable the entry if the feature is not yet available
    for that business type, with no broken routes, dead-ends, or
    route-not-found errors.

2.2 WHEN a user uses Back, system back-gesture, or close on any nested
    screen THEN the system SHALL pop to a consistent prior state, prompt
    before discarding unsaved input, and dismiss any associated
    overlays/modals.

**D2 — Placeholder / incomplete UI**

2.3 WHEN a user opens any screen, tab, dialog, or dropdown THEN the
    system SHALL render only production-ready content backed by real
    data sources and wired handlers, with no TODO/lorem/dummy strings
    and no non-functional controls.

2.4 WHEN a list/grid screen has zero records, an error, or is loading
    THEN the system SHALL render the appropriate distinguishable
    empty/error/loading state with a clear message and, where relevant,
    a primary action (create, retry).

**D3 — Validation and business rules**

2.5 WHEN a user submits any form with invalid or business-rule-violating
    input THEN the system SHALL reject the submission, show a clear
    localized inline error per field, and not persist any partial or
    corrupt data.

2.6 WHEN any domain calculation runs THEN the system SHALL produce the
    numerically-correct result per the documented business rule
    (including GST splits, rounding mode, multi-unit conversion, stock
    movement, ledger balance, and per-business-type formulas), verified
    against worked examples captured in the defect inventory.

**D4 — Data flow and persistence**

2.7 WHEN a user creates, edits, or deletes a record THEN the system
    SHALL write atomically and consistently across local storage,
    backend, and in-memory state, with rollback on partial failure so
    all three views agree.

2.8 WHEN a screen re-opens or a list re-loads after a write THEN the
    system SHALL show fresh data reflecting the latest committed state
    via correct invalidation/refresh of caches and providers.

**D5 — Offline / online / sync**

2.9 WHEN the device is offline THEN the system SHALL accept
    create/edit/delete operations across all offline-capable modules,
    queue them durably, and surface clear pending-sync status to the
    user.

2.10 WHEN connectivity is restored, or the same account is used across
     multiple devices, THEN the system SHALL reconcile queued and
     concurrent changes deterministically (documented conflict-resolution
     policy: last-writer-wins, per-field merge, or user-prompted resolve
     as appropriate), without dropping, duplicating, or permanently
     diverging records, and shall expose a recovery UI for unresolved
     conflicts.

**D6 — State management and consistency**

2.11 WHEN any screen mutates an entity used by other open screens or
     widgets THEN the system SHALL propagate the change through the
     state layer so all dependent UIs reflect the new value without a
     manual refresh or app restart.

**D7 — Error handling and fallback**

2.12 WHEN any backend, I/O, scanner, camera, PDF, print, or local-DB
     operation fails or times out THEN the system SHALL catch the
     failure, present a user-readable localized message, log
     diagnostic detail, and offer a retry or safe fallback path; the UI
     SHALL never freeze or expose a raw stack trace.

**D8 — Permissions and RBAC**

2.13 WHEN a user with any role accesses any screen, action, or report
     THEN the system SHALL enforce role-based access uniformly across
     every entry point (drawer, deep link, action button, search result),
     allowing exactly the documented permitted set for that role and no
     more.

**D9 — Performance**

2.14 WHEN any list, report, dashboard, or search runs over realistic
     data volumes THEN the system SHALL complete within documented
     budgets (interactive screens render first frame within 1s on
     mid-tier devices and sustain 60fps during scroll) using pagination,
     indexed queries, isolate-offloaded heavy work, and bounded memory.

**D10 — Cross-module integration**

2.15 WHEN any cross-module workflow runs end-to-end THEN the system
     SHALL create, update, or roll back all dependent records
     transactionally so no partial or inconsistent state is left at a
     module boundary.

**D11 — Domain correctness per business type**

2.16 WHEN any business-type-specific workflow runs end-to-end THEN the
     system SHALL produce the domain-correct artifact (invoice, receipt,
     report, certificate, ID-card, prescription, report-card, KOT print,
     etc.) for every documented realistic input set.

### Audit & Inventory Acceptance Criteria

These clauses are part of the fix property: the fix is not "complete" until
each is satisfied. They sit under section 2 because they describe the
correct end-state of F'.

2.17 WHEN this spec is executed THEN the system SHALL produce a
     **per-module audit coverage matrix** listing every screen, dialog,
     and primary workflow for every module across all four apps, with
     each row marked Audited / Not-Applicable.

2.18 WHEN the audit identifies any defect THEN the system SHALL record
     it in a **categorized defect inventory** with: defect-id, module,
     screen/workflow, defect class (D1..D11), severity
     (blocker/critical/major/minor), reproduction steps, observed
     behavior, expected behavior, and proposed fix scope. The inventory
     SHALL be the source of truth for tasks generated in Phase 3.

2.19 WHEN any fix is applied THEN the system SHALL be accompanied by a
     reproduction test (unit, widget, or integration as appropriate)
     that fails on F and passes on F', satisfying the per-defect Fix
     property.

2.20 WHEN any fix is applied THEN unrelated workflows for the same
     module and adjacent modules SHALL pass their existing tests
     unchanged, satisfying the per-defect Preservation property.

2.21 WHEN the audit covers offline/online behavior THEN the system
     SHALL include explicit scenario coverage for: offline create, edit,
     delete; reconnect sync; multi-device concurrent edit; flaky network;
     forced kill mid-write; large-batch sync, for every offline-capable
     module.

### Unchanged Behavior (Regression Prevention)

The audit-and-fix sweep MUST NOT change behavior of workflows that are
already correct. The clauses below define the preservation perimeter.

3.1 WHEN a workflow X already behaves correctly under all documented
    scenarios in F (i.e., NOT isBugCondition(X)) THEN the system SHALL
    CONTINUE TO produce identical observable behavior in F' — same
    outputs, same persisted data shape, same navigation, same UI, same
    timing class.

3.2 WHEN existing passing tests across all four apps (`Dukan_x`,
    `school_admin_app`, `school_teacher_app`, `school_student_app`) are
    re-run after fixes THEN the system SHALL CONTINUE TO pass them
    without modification, except where a test itself encoded the buggy
    behavior and is explicitly updated as part of the fix's defect-
    inventory entry.

3.3 WHEN existing data persisted by F (local Hive/SQLite/Drift/Isar
    boxes and remote DynamoDB records) is opened by F' THEN the system
    SHALL CONTINUE TO read it correctly, with migrations supplied for
    any schema change introduced by a fix and no data loss for users
    upgrading.

3.4 WHEN existing public APIs, route names, deep links, and persisted
    keys used by other apps in the workspace or by external integrations
    are exercised THEN the system SHALL CONTINUE TO honor them, with
    deprecation shims rather than removals where a rename is required.

3.5 WHEN a module's currently-shipping business-type-specific UI/UX
    (theming, iconography, terminology) is used by an existing customer
    THEN the system SHALL CONTINUE TO present the same visual language
    after fixes, unless the inventory explicitly classifies that visual
    as a D2 placeholder defect.

3.6 WHEN any user role exercises actions that were already permitted in
    F THEN the system SHALL CONTINUE TO permit those exact actions in
    F' (RBAC fixes only tighten incorrect grants and loosen incorrect
    denials documented in the inventory; they do not redefine the
    permission model wholesale).

3.7 WHEN offline workflows that already worked correctly are exercised
    in F' THEN the system SHALL CONTINUE TO accept, queue, and sync
    them with the same semantics, including ordering and idempotency
    keys, so devices upgraded in the middle of a pending-sync state do
    not lose queued operations.
