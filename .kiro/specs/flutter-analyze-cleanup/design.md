# Flutter Analyze Cleanup Bugfix Design

## Overview

`flutter analyze` against the `Dukan_x` project (package `dukanx`) currently reports a large volume of static-analysis diagnostics. The approved requirements (`bugfix.md`) reference an earlier count of ~3,883 issues, but a fresh run now reports approximately **6,023** issues. This drift is itself a finding: the codebase has continued to evolve, the baseline in the requirements is stale, and any remediation plan that assumes the old number will mis-prioritize work. **The first design step is therefore to establish a fresh, categorized baseline before any fix is attempted.**

The "bug" being fixed is the presence of these analyzer violations: source files whose static analysis is not clean under the project's `analysis_options.yaml`. The fix must drive the in-scope issue count to zero, or to an explicitly justified and documented baseline, **without altering any observable application behavior** (navigation, UI, state semantics, domain logic, persistence, networking contracts, localization).

The strategy is deliberately conservative and incremental:

1. Capture a fresh `flutter analyze` baseline and bucket every diagnostic by severity (error / warning / info) and by lint rule / diagnostic code.
2. Prioritize **errors first** (they may indicate broken or non-compiling code), then **warnings** (latent defects: swallowed exceptions, leaked resources), then **info / lints** (style and best-practice).
3. Fix in **small batches by category**, re-running `flutter analyze` after each batch and verifying behavior preservation through the existing test suite (notably `test/preservation/preservation_property_test.dart` and `test/core/api/api_client_idempotency_test.dart`) plus a build/compile check.
4. Scope every change **exclusively to `Dukan_x`**, never touching sibling projects (`school_admin_app`, `school_student_app`, `school_teacher_app`, `dukan_customer_app`, `dukan_restro_pwa`) or generated files (`**/*.g.dart`, `**/*.freezed.dart`, `**/*.mocks.dart`, `build/**`, `.dart_tool/**`).

This design covers strategy only. No code changes are proposed in this phase.

## Glossary

- **Bug_Condition (C)**: The condition that marks a source file as "buggy" — `flutter analyze` reports one or more in-scope diagnostics against that file. Formally, `isBugCondition(F)` is true when the analyzer emits at least one diagnostic (error, warning, or info) for file `F` that is not excluded by `analysis_options.yaml` and not suppressed by a documented, justified configuration entry.
- **Property (P)**: The desired behavior after the fix — `flutter analyze` reports **zero** in-scope diagnostics for `F`, while the runtime behavior of `F` (its public API, control flow, and observable effects) is byte-for-byte unchanged.
- **Preservation**: The requirement that all behavior NOT related to clearing a diagnostic stays identical. Anchored by the existing test suite, the preservation property suite, and golden fingerprints under `test/preservation/__goldens__/`.
- **In-scope diagnostic**: A diagnostic produced by `flutter analyze` for a file under `Dukan_x/` that is not matched by the `analyzer.exclude` globs and not already mapped to `ignore` in `analyzer.errors`.
- **F (original)**: The `Dukan_x` source tree before the cleanup.
- **F' (fixed)**: The `Dukan_x` source tree after each batch of cleanup edits.
- **Baseline**: The fresh, categorized snapshot of `flutter analyze` output captured before any fix, used to measure progress and prioritize work.
- **Batch**: A small, single-category, reviewable unit of fixes (e.g., "unused imports in `lib/features/jewellery`") after which `flutter analyze`, build, and tests are re-run.
- **`analysis_options.yaml`**: The analyzer configuration at `Dukan_x/analysis_options.yaml`. It extends `package:flutter_lints/flutter.yaml`, enables safety lints (`empty_catches`, `close_sinks`, `cancel_subscriptions`, `avoid_unnecessary_containers`, `sized_box_for_whitespace`, `use_key_in_widget_constructors`), disables noisy style lints (`prefer_const_*`, `prefer_final_*`, `avoid_print`, `avoid_dynamic_calls`, `only_throw_errors`, `unnecessary_this`, `unnecessary_new`), and maps `use_build_context_synchronously`, `deprecated_member_use`, `deprecated_member_use_from_same_package`, and `unawaited_futures` to `ignore`.

## Bug Details

### Bug Condition

The bug manifests when `flutter analyze`, run against the `Dukan_x` project, reports any in-scope diagnostic against a source file `F`. The analyzer is either (a) detecting genuinely broken code (error severity), (b) detecting unsafe constructs that risk silent failures or resource leaks (warning severity), or (c) detecting style / best-practice violations under the configured lint set (info severity). Any one of these makes `F` "buggy" for the purposes of this fix.

**Formal Specification:**
```
FUNCTION isBugCondition(F)
  INPUT: F of type DartSourceFile (path under Dukan_x/)
  OUTPUT: boolean

  IF F matches any glob in analysisOptions.analyzer.exclude THEN
    RETURN false        // generated / build / tool output is out of scope
  END IF

  diagnostics := flutterAnalyze(F)               // run under Dukan_x/analysis_options.yaml
  inScope := FILTER diagnostics WHERE
                 d.code NOT IN analysisOptions.analyzer.errors[ignore]
             AND  d.code NOT IN documentedJustifiedSuppressions

  RETURN COUNT(inScope) > 0
END FUNCTION
```

A file is "fixed" when `isBugCondition(F)` becomes false AND the preservation property (see Correctness Properties) continues to hold for `F`.

### Examples

- **Error severity (D-class: broken code)** — A file references an undefined identifier, passes a wrong argument type, omits a required parameter, or has an invalid override. Expected: the analyzer reports the error and the file may fail to compile. After fix: zero errors, with the narrowest possible change that preserves runtime behavior.
- **Warning severity (`empty_catches`)** — `try { ... } catch (e) {}` swallows an exception silently. Expected: the analyzer flags `empty_catches`; a real failure could be hidden. After fix: an explicit comment or a logged handler is added that preserves the original control flow (no rethrow added, no flow change).
- **Warning severity (`close_sinks` / `cancel_subscriptions`)** — A `StreamController` is never closed, or a `StreamSubscription` is never cancelled, in a `State` / service that owns it. Expected: the analyzer flags a potential resource leak. After fix: a correctly-scoped `dispose()` / `cancel()` is added that does not change emission semantics or timing.
- **Info severity (`avoid_unnecessary_containers`)** — `Container(child: X)` wraps a child with no decoration, padding, color, or constraints. Expected: the analyzer flags an unnecessary container. After fix: replaced with the child directly (or `SizedBox`) only where the `Container` added no visual effect.
- **Info severity (`sized_box_for_whitespace`)** — `Container(width: 8)` used purely for spacing. Expected: the analyzer suggests `SizedBox`. After fix: `SizedBox(width: 8)` — visually identical.
- **Info severity (`use_key_in_widget_constructors`)** — A public widget constructor lacks a `Key? key` parameter. Expected: the analyzer flags it. After fix: `super.key` (or `Key? key`) added without changing the default behavior (key defaults to null exactly as today).
- **Info severity (unused imports / dead code)** — An `import` is never referenced, or a private element is never used. Expected: the analyzer flags it. After fix: removed only when the project provably compiles and behaves identically without it (accounting for reflective / string-based / conditional usage).
- **Edge case (clean file)** — A file with zero in-scope diagnostics. `isBugCondition(F)` is false; the file MUST be left untouched and MUST remain clean after the cleanup.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors** (from `bugfix.md` clauses 3.1–3.12):
- Navigation graph, route transitions, and route arguments — no added, removed, or reordered routes (3.1).
- UI rendering (layout, spacing, colors, typography, conditional rendering, animations) and input handling (taps, gestures, keyboard, focus) (3.2).
- State management flows (Provider / Riverpod / ChangeNotifier / Bloc / streams): same sequence of state transitions, same listeners notified in the same order (3.3).
- Business / domain logic outputs for the same inputs, byte-for-byte where applicable (PDFs, exported documents): billing, GST/tax, discounts, jewellery rates, and all vertical domain rules (3.4).
- I/O contracts: same endpoints, payloads, headers, retry/idempotency semantics, response handling for Firebase, Cloud Functions, Firestore, Storage, Crashlytics, FCM, App Check, local notifications, REST via `api_client.dart`, and file system access (3.5).
- Localization results: same translated strings, validation results, and locale fallbacks (`localization_service.dart`, `l10n_validators.dart`) (3.6).
- Files with no pre-existing diagnostics are left unchanged (3.7).
- Existing test suite pass/fail outcomes unchanged; no test removed or weakened (3.8).
- App launch, provider initialization order, persisted-state restoration, and initial route unchanged (3.9).
- DI / service-locator / provider registration: same services, same lifetimes, same resolved instances (3.10).
- Sibling projects unchanged — this cleanup is scoped exclusively to `Dukan_x` (3.11).
- Excluded / generated files not hand-edited; `build_runner` regeneration permitted only if byte-identical (3.12).

**Scope:**
All inputs that do NOT involve clearing an in-scope diagnostic should be completely unaffected by this fix. This includes:
- Source files that already analyze clean (`NOT isBugCondition(F)`).
- The public API of every touched file: exported symbol names, signatures, generic parameters, default values, and visibility (changed only when required to fix an error-severity diagnostic, and then as narrowly as possible — clause 2.5).
- Sibling Flutter projects in the workspace.
- Generated files and the `build/` and `.dart_tool/` trees.

**Note:** The expected *correct* behavior for buggy inputs (zero in-scope diagnostics with preserved runtime behavior) is defined in the Correctness Properties section (Property 1). This section focuses on what must NOT change.

## Hypothesized Root Cause

The ~6,023 diagnostics are not a single defect but an accumulated population. Based on the bug description, the configured lint set, and the count drift since the requirements were written, the most likely contributing causes are:

1. **Stale baseline / count drift (process cause)**: The requirements cite ~3,883 issues; a fresh run reports ~6,023. New feature code (the `academic_coaching`, `clinic`, `computer_shop`, `auto_parts`, `jewellery`, `clothing`, and other verticals visible in the open editors) has been added without an enforced clean-analyze gate, so diagnostics accrue faster than they are cleared. **Implication: the categorized baseline must be regenerated before prioritization.**

2. **Error-severity diagnostics from broken or drifted code**: Undefined identifiers, type mismatches, missing required arguments, or invalid overrides — possibly from refactors, dependency upgrades (the pubspec pins many recent major versions: `firebase_*` v4–v6, `go_router` ^17, `riverpod` ^3, `freezed` ^3), or partially-migrated APIs. These are the highest risk and may indicate code that does not compile.

3. **Warning-severity safety lints firing across many files**: `empty_catches`, `close_sinks`, and `cancel_subscriptions` are explicitly enabled as warnings. A codebase with many services, repositories, and stream-based providers tends to accumulate swallowed exceptions and uncancelled subscriptions/unclosed sinks. Dead code and unused elements also fall here.

4. **Info-severity lint volume (the bulk of the count)**: Unused imports, `avoid_unnecessary_containers`, `sized_box_for_whitespace`, and `use_key_in_widget_constructors` typically dominate large Flutter UIs. With dozens of screens per vertical, these likely account for the majority of the ~6,023 issues.

5. **Deprecated-API churn partially masked by configuration**: `deprecated_member_use`, `deprecated_member_use_from_same_package`, and `use_build_context_synchronously` are mapped to `ignore`. They will not appear in the in-scope count, but related real errors (e.g., a deprecated symbol fully removed in an upgraded dependency) will surface as **errors** and must be handled in the errors batch.

The baseline categorization (Design Step 0 in Testing Strategy) will confirm or refute the relative weights of causes 2–4. If the distribution differs materially from this hypothesis (e.g., errors are far more numerous than expected), the batching order and risk assessment will be revised before fixes begin.

## Correctness Properties

Property 1: Bug Condition - In-Scope Diagnostics Are Eliminated With Behavior Preserved

_For any_ source file `F` in `Dukan_x` where the bug condition holds (`isBugCondition(F)` returns true, i.e. `flutter analyze` reports at least one in-scope diagnostic), the fixed tree F' SHALL cause `flutter analyze` to report **zero** in-scope diagnostics for `F` (or only documented, justified suppressions), while the file's public API, control flow, and observable runtime effects remain identical to F.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**

Property 2: Preservation - Already-Clean Files And Non-Analyze Behavior Are Untouched

_For any_ input where the bug condition does NOT hold (`isBugCondition(F)` returns false — a file that already analyzes clean, or any observable behavior not tied to clearing a diagnostic), the fixed tree F' SHALL produce the same result as the original tree F, preserving navigation, UI rendering, state-transition sequences, domain-logic outputs, I/O contracts, localization, persistence, DI registration, the existing test outcomes, and all sibling projects and generated files.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12**

## Fix Implementation

> No code is changed in this phase. This section outlines the *strategy* for the implementation phase. All work is scoped to `Dukan_x/` (primarily `lib/` and, where diagnostics exist, `test/`); sibling projects and excluded/generated files are never edited.

### Changes Required

Assuming the root-cause analysis is broadly correct, remediation proceeds category-by-category, in priority order, each in small batches.

**Step 0 — Establish a fresh categorized baseline (prerequisite, no edits):**
1. Run `flutter analyze` for `Dukan_x` only and capture full output to a baseline artifact.
2. Parse the output and bucket every diagnostic by **severity** (error / warning / info) and by **diagnostic code / lint rule**, with per-file and per-rule counts.
3. Produce a prioritized worklist: errors → warnings (`empty_catches`, `close_sinks`, `cancel_subscriptions`, dead code/unused elements) → info (unused imports, `avoid_unnecessary_containers`, `sized_box_for_whitespace`, `use_key_in_widget_constructors`, remaining lints).
4. Record the total (expected ~6,023) and the per-category distribution as the measurement baseline for progress tracking. Re-confirm or revise the hypothesized root cause against this distribution.

**Category 1 — Error-severity diagnostics (highest priority, highest risk):**
- File: any file the baseline lists with `error` severity.
- Strategy: fix the minimum required to satisfy the analyzer while preserving runtime behavior (clause 2.2). Undefined identifiers → restore/import the correct symbol; type mismatches → narrowest correct typing; missing required args → supply the value the code already intended.
- Deprecated-API removals that surface as errors (because a symbol no longer exists in an upgraded dependency) are migrated to the documented replacement API with equivalent semantics. Pure deprecation *warnings* remain `ignore`d per config and are out of the in-scope count.
- This is the only category permitted to make narrow public-API adjustments, and only when an error cannot otherwise be cleared (clause 2.5).

**Category 2 — `empty_catches` (warning):**
- Resolve by adding an explicit handling comment (e.g., `// ignore: empty_catches` only where intentional and documented) or a logged handler that preserves the original control flow. Do NOT add a rethrow or otherwise change which exceptions propagate (clause 2.3).

**Category 3 — `close_sinks` / `cancel_subscriptions` (warning):**
- Resolve by adding correctly-scoped `close()` / `cancel()` calls in the owning `dispose()` (or equivalent lifecycle hook), so the sink/subscription is released without changing emission order, timing, or who-receives-what (clause 2.3). Validate against the stream/provider preservation fingerprints (D5/D6 in the preservation suite).

**Category 4 — Dead code / unused elements (warning):**
- Remove only when the element is provably unreferenced across the entire project, including reflective and string-based lookups and conditional compilation (clause 2.3). When in doubt, prefer leaving the element and suppressing with a documented justification over risking a behavior change.

**Category 5 — Unused imports (info):**
- Remove imports only when the project compiles and behaves identically without them (clause 2.4). Watch for imports that are only used for their side effects or for re-export.

**Category 6 — `avoid_unnecessary_containers` (info):**
- Replace `Container(child: X)` with `X` (or `SizedBox`) only where the `Container` carried no decoration, color, padding, margin, constraints, alignment, or transform — i.e., it produced no visual effect (clause 2.4).

**Category 7 — `sized_box_for_whitespace` (info):**
- Replace whitespace-only `Container(width/height: ...)` with the visually-identical `SizedBox` (clause 2.4).

**Category 8 — `use_key_in_widget_constructors` (info):**
- Add `Key? key` / `super.key` to public widget constructors without changing the default (key stays null by default), so existing call sites and rebuild behavior are unaffected (clause 2.4).

**Category 9 — Configuration / documented baseline (last resort):**
- For any residual diagnostic that cannot be safely fixed without risking behavior, add a documented, justified suppression (file-level `// ignore_for_file:` with rationale, or a justified `analysis_options.yaml` entry). Each suppression must carry a rationale (clause 2.1). The goal remains zero in-scope issues; suppressions are the explicitly-justified exception, not the default.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code (the fresh categorized baseline IS the counterexample set — every reported in-scope diagnostic is a concrete instance of `isBugCondition` being true), then verify each batch of fixes clears those diagnostics while preserving behavior. Because the "bug" is a population of static-analysis findings rather than a single runtime fault, `flutter analyze` itself is the primary oracle for Property 1, and the existing test suite plus golden fingerprints are the oracle for Property 2.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix, and confirm or refute the root-cause hypothesis. If the category distribution refutes the hypothesis (e.g., far more errors than expected, or a dominant rule not anticipated), re-hypothesize and revise the batch order before fixing.

**Test Plan**: Run `flutter analyze` scoped to `Dukan_x` on the UNFIXED tree and parse the output into severity and rule buckets. Each diagnostic is a counterexample. Observe the per-rule and per-file distribution to drive prioritization.

**Test Cases**:
1. **Baseline count test**: Run `flutter analyze` and record the total in-scope count (will report ~6,023 on unfixed code — confirms the bug and the count drift from the requirements' ~3,883).
2. **Severity bucket test**: Bucket diagnostics by error / warning / info (errors enumerate broken code; will be non-empty on unfixed code if compilation issues exist).
3. **Rule distribution test**: Bucket by diagnostic code / lint rule to confirm which rules dominate (expect unused imports, `avoid_unnecessary_containers`, `sized_box_for_whitespace`, `use_key_in_widget_constructors` to lead).
4. **Per-vertical hot-spot test**: Aggregate counts per feature directory to find the highest-density files (will reveal which verticals — e.g., `academic_coaching`, `computer_shop`, `jewellery` — carry the most issues).

**Expected Counterexamples**:
- `flutter analyze` reports ~6,023 in-scope diagnostics across the tree.
- Possible causes: accumulated lint debt (info-heavy), unhandled safety warnings (`empty_catches`, `close_sinks`, `cancel_subscriptions`), and some error-severity breakage from refactors / dependency upgrades.

### Fix Checking

**Goal**: Verify that for all files where the bug condition holds, the fixed tree produces zero in-scope diagnostics with behavior preserved.

**Pseudocode:**
```
FOR ALL F WHERE isBugCondition(F) DO
  applyMinimalFix(F)                       // per-category strategy, in batches
  diagnostics := flutterAnalyze(F)
  inScope := FILTER diagnostics WHERE in-scope AND NOT documentedSuppression
  ASSERT COUNT(inScope) == 0               // Property 1: diagnostics cleared
  ASSERT publicApi(F') == publicApi(F)     // unless an error fix required a narrow change
END FOR

// Whole-project gate after each batch:
ASSERT flutterAnalyze(Dukan_x).inScopeCount  decreases monotonically toward 0
ASSERT flutterBuild(desktopTarget) succeeds
ASSERT flutterTest() outcomes unchanged
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold (already-clean files, and all behavior not tied to clearing a diagnostic), the fixed tree produces the same result as the original tree.

**Pseudocode:**
```
FOR ALL F WHERE NOT isBugCondition(F) DO
  ASSERT contentDigest(F') == contentDigest(F)   // clean files untouched (clause 3.7)
END FOR

FOR ALL observable behavior B (navigation, UI, state, domain, I/O, l10n, persistence, DI) DO
  ASSERT B(F') == B(F)                            // via existing tests + golden fingerprints
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many candidate workflows across the input domain (the existing `preservation_property_test.dart` enumerates `(app, module, screen, workflow)` slices and the negated bug-condition predicates `notBugConditionD1..D11`).
- It catches edge cases that manual unit tests miss, by comparing deterministic fingerprints against committed goldens under `test/preservation/__goldens__/`.
- It provides strong guarantees that route graphs, persisted keys (Hive box names, SharedPreferences keys), domain/business-rule files, RBAC modules, paginated queries, sync-queue idempotency, provider `ref.watch` wiring, and the existing test corpus are byte-stable from F to F'.

**Test Plan**: The preservation goldens are already captured on F. After each fix batch (F'), re-run the preservation suite; any golden mismatch is a preservation regression to investigate before proceeding. Capture build and `flutter test` outcomes on F first as the reference, then compare after each batch.

**Test Cases**:
1. **Clean-file stability**: Observe that files with no diagnostics analyze clean on unfixed code, then verify their content digest is unchanged after each batch (clause 3.7).
2. **Route-graph preservation**: The `d1_route_graph` golden captures non-buggy routes; verify it is byte-stable after fixes (clauses 3.1, 3.9).
3. **Persistence-key preservation**: The `persisted_hive_box_names` and `persisted_shared_prefs_keys` goldens verify persisted storage shape is unchanged (clauses 3.3, 3.9).
4. **Domain / business-rule preservation**: The `d3_decimal_money_helpers` and `d11_existing_business_rules` goldens verify monetary and vertical domain logic files are unchanged (clause 3.4).
5. **I/O contract preservation**: `test/core/api/api_client_idempotency_test.dart` verifies the `ApiClient.post/put/patch/delete` idempotency-key surface still compiles (clause 3.5); the `d7_io_try_catch` golden guards error-handling wiring.
6. **Test-corpus preservation**: The `existing_test_corpus_paths` golden verifies no existing test is removed or weakened (clause 3.8).

### Unit Tests

- Run the existing `Dukan_x` unit test suite (`flutter test`) and confirm identical pass/fail outcomes after each batch (clauses 2.6, 3.8). No test is modified, removed, or weakened to accommodate a fix.
- For error-severity fixes that touch logic (the only category that may adjust a narrow API), confirm the relevant feature/model/service tests under `test/features/`, `test/models/`, `test/services/`, and `test/core/` still pass unchanged.
- Confirm localization tests (`test/localization_test.dart`) pass unchanged (clause 3.6).

### Property-Based Tests

- Re-run `test/preservation/preservation_property_test.dart` (dartproptest-backed enumeration + golden fingerprints) after each batch to assert Property 2 across the generated non-buggy input space.
- Re-run other PBT suites present in the tree (e.g., `test/security/fingerprint_hash_property_test.dart`, `test/tool/responsive_audit_totality_property_test.dart`, `test/d9/paginated_window_test.dart`) to confirm no property regresses.
- Treat any new failing counterexample from these suites as a preservation regression and resolve it before continuing.

### Integration Tests

- Run the existing integration tests (`test/integration/auth_flow_test.dart`, `bill_flow_test.dart`, `customer_flow_test.dart`, `party_ledger_integration_test.dart`, `qr_linking_test.dart`, `sync_verification_test.dart`, `user_journey_test.dart`) to confirm end-to-end flows (auth, billing, customer, sync) behave identically (clauses 3.1, 3.4, 3.5).
- Run golden/widget tests (`test/golden/widget_golden_test.dart`, `test/widget/`, `test/widgets/`) to confirm UI rendering is pixel-stable after UI-lint fixes (`avoid_unnecessary_containers`, `sized_box_for_whitespace`, `use_key_in_widget_constructors`) (clause 3.2).
- After the final batch, run `flutter build` for the configured desktop target to confirm a clean compile, and run `flutter analyze` once more to confirm the in-scope count is zero (or only documented, justified suppressions) (clauses 2.1, 2.6).

### Incremental Batching & Scope Guardrails

- **Batch size**: Small and single-category (often single-directory). After every batch: re-run `flutter analyze` (count must trend monotonically toward zero), build, and the preservation + existing test suites.
- **Scope lock**: Every command and edit is restricted to `Dukan_x/`. No file under `school_admin_app`, `school_student_app`, `school_teacher_app`, `dukan_customer_app`, or `dukan_restro_pwa` is read-for-edit or modified. Generated files (`**/*.g.dart`, `**/*.freezed.dart`, `**/*.mocks.dart`) and the `build/` and `.dart_tool/` trees are never hand-edited.
- **Rollback**: If any batch causes a build failure, a test outcome change, or a preservation golden mismatch that cannot be explained as an intended diagnostic clearance, revert that batch and re-scope.
- **Risk areas**: Error-severity fixes are the riskiest because they are the only ones permitted to adjust a public API (narrowly, per clause 2.5). They are batched first, reviewed most carefully, and validated against the full unit/integration suite before moving to lower-severity, lower-risk categories. Deprecated-API removals surfacing as errors require migrating to a documented replacement with equivalent semantics, validated by the relevant feature tests.
