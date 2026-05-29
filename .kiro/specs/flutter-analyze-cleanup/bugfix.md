# Bugfix Requirements Document

## Introduction

`flutter analyze` reports approximately 3,883 issues in the desktop application project (`Dukan_x`, package `dukanx`). The diagnostics span the full severity spectrum produced by the Dart analyzer under the project's `analysis_options.yaml` (which extends `package:flutter_lints/flutter.yaml`):

- **Errors** — diagnostics that prevent successful compilation or indicate definitively broken code (e.g., undefined identifiers, type errors, missing required parameters).
- **Warnings** — diagnostics that flag likely bugs or unsafe constructs (e.g., `empty_catches`, `close_sinks`, `cancel_subscriptions`, dead code, unused elements that the project treats as warnings).
- **Info / Lints** — style and best-practice diagnostics from the enabled lint set (e.g., `avoid_unnecessary_containers`, `sized_box_for_whitespace`, `use_key_in_widget_constructors`, unused imports, prefer-typed declarations).

These analyzer findings degrade maintainability, obscure real defects in the noise, and create latent risk of runtime errors (null dereferences, leaked resources, swallowed exceptions, race conditions). The bug being fixed is the presence of these analyzer violations themselves: source files whose static analysis is not clean.

The fix must drive the analyzer issue count to zero (or to an explicitly justified, configured baseline) **without altering the application's observable behavior**. Specifically, navigation flow, state management semantics, UI appearance and interaction, business/domain logic, persistence, networking contracts, and feature workflows must remain identical from the user's and the API's perspective. Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`), the `build/` tree, and `.dart_tool/` are out of scope (already excluded by the analyzer).

## Bug Analysis

### Current Behavior (Defect)

For the purposes of these clauses, let *F* be any Dart source file in the `Dukan_x` project that is in scope of the analyzer (i.e., not excluded by `analysis_options.yaml`). An "analyzer issue" means any diagnostic emitted by `flutter analyze` against *F*.

1.1 WHEN `flutter analyze` is run against the `Dukan_x` project on the current source tree THEN the system reports approximately 3,883 analyzer issues across the codebase.

1.2 WHEN a source file *F* contains diagnostics of severity **error** (e.g., undefined identifier, type mismatch, missing required argument, invalid override) THEN the system reports those errors and *F* may fail to compile or behave incorrectly at runtime.

1.3 WHEN a source file *F* contains diagnostics of severity **warning** (e.g., `empty_catches`, `close_sinks`, `cancel_subscriptions`, dead code, unreachable branches, unused elements treated as warnings) THEN the system reports those warnings and *F* contains constructs that risk silent failures, leaked resources, or maintenance hazards.

1.4 WHEN a source file *F* contains diagnostics of severity **info / lint** (e.g., unused imports, `avoid_unnecessary_containers`, `sized_box_for_whitespace`, `use_key_in_widget_constructors`, prefer-typed-declarations, naming conventions) THEN the system reports those lints and *F* contains style or best-practice violations under the project's configured lint set.

1.5 WHEN a developer or CI process inspects analyzer output for the `Dukan_x` project THEN the signal-to-noise ratio is poor: real defects are buried among thousands of low-severity findings, making it impractical to detect newly introduced regressions through `flutter analyze` alone.

### Expected Behavior (Correct)

2.1 WHEN `flutter analyze` is run against the `Dukan_x` project on the fixed source tree THEN the system SHALL report **zero** analyzer issues, OR report only issues that are explicitly suppressed via documented, justified entries in `analysis_options.yaml` (with each suppression accompanied by a rationale).

2.2 WHEN a source file *F* previously contained **error**-severity diagnostics THEN the system SHALL no longer report those errors for *F*, with each fix limited to the minimum change required to satisfy the analyzer while preserving the file's runtime behavior.

2.3 WHEN a source file *F* previously contained **warning**-severity diagnostics THEN the system SHALL no longer report those warnings for *F*, with `empty_catches` resolved by adding an explicit comment or logged handler that preserves the original control flow, `close_sinks` and `cancel_subscriptions` resolved by adding correctly-scoped `dispose`/`cancel` calls that do not change emission semantics, and dead-code/unused-element warnings resolved by removal only when the element is provably unreferenced across the project (including reflective and string-based lookups).

2.4 WHEN a source file *F* previously contained **info / lint**-severity diagnostics THEN the system SHALL no longer report those lints for *F*, with each fix being a behavior-preserving rewrite (e.g., replacing `Container()` with `SizedBox()` only where the `Container` had no decoration/padding/margin, removing imports only when the project compiles without them, adding `key` parameters to widget constructors without altering their default value, and so on).

2.5 WHEN any change is made to resolve an analyzer issue THEN the system SHALL preserve the public API of the affected file: exported symbol names, signatures, generic parameters, default values, and visibility SHALL remain unchanged unless the change is required to fix an error-severity diagnostic, in which case it SHALL be the narrowest possible adjustment.

2.6 WHEN the cleanup is complete THEN the system SHALL build successfully (`flutter build` for the configured desktop targets) and pass the existing test suite (`flutter test`) with the same pass/fail outcomes as before the cleanup.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a user navigates between any screens or routes in the application THEN the system SHALL CONTINUE TO follow the same navigation graph, transitions, and route arguments as before the cleanup, with no added, removed, or reordered routes.

3.2 WHEN any UI screen or widget is rendered THEN the system SHALL CONTINUE TO produce the same visual output (layout, spacing, colors, typography, conditional rendering, animations) and respond to user input (taps, gestures, keyboard, focus) identically to the pre-cleanup behavior.

3.3 WHEN any state management flow executes (Provider/Riverpod/ChangeNotifier/Bloc/streams as used in `Dukan_x`) THEN the system SHALL CONTINUE TO emit the same sequence of state transitions for the same inputs, with the same listeners notified in the same order.

3.4 WHEN any business logic executes (billing calculations, inventory updates, pricing, GST/tax computations, discounts, jewellery rate logic, restaurant/clothing/auto-parts/clinic/pharmacy/computer-shop/hardware/grocery/jewellery domain rules, payment flows, delivery challan generation, scan-bill workflows, warranty claims, custom order management) THEN the system SHALL CONTINUE TO produce the same outputs for the same inputs, byte-for-byte where applicable (e.g., generated PDFs, exported documents).

3.5 WHEN any I/O operation is performed (Firebase reads/writes, Cloud Functions calls, Firestore queries, Storage uploads, Crashlytics reporting, FCM messaging, App Check, local notifications, REST API calls via `api_client.dart`, file system access) THEN the system SHALL CONTINUE TO use the same endpoints, request payloads, headers, retry/idempotency semantics, and response handling as before.

3.6 WHEN localization is resolved (`localization_service.dart`, `l10n_validators.dart`) THEN the system SHALL CONTINUE TO return the same translated strings, validation results, and locale fallbacks for the same inputs.

3.7 WHEN any source file *F* contains **no** analyzer issues prior to the cleanup THEN the system SHALL leave *F* unchanged (modulo whitespace-neutral edits required by tooling), and `flutter analyze` SHALL CONTINUE TO report zero issues for *F* after the cleanup.

3.8 WHEN the existing test suite is executed (unit tests, widget tests, including `test/preservation/preservation_property_test.dart` and `test/core/api/api_client_idempotency_test.dart`) THEN the system SHALL CONTINUE TO produce the same pass/fail outcome for each test as before the cleanup, with no test removed or weakened to accommodate a fix.

3.9 WHEN the application is launched on its supported desktop target THEN the system SHALL CONTINUE TO start, initialize providers in the same order, restore persisted state identically, and reach the same initial route as before the cleanup.

3.10 WHEN any dependency injection, service locator, or provider registration runs (`providers/app_state_providers.dart`, module routes such as `modules/grocery/routes/grocery_routes.dart`) THEN the system SHALL CONTINUE TO register the same services with the same lifetimes and resolve to the same instances for the same lookups.

3.11 WHEN any sibling Flutter project in the workspace (`school_admin_app`, `school_student_app`, `school_teacher_app`, `dukan_customer_app`, `dukan_restro_pwa`) is analyzed, built, or run THEN the system SHALL CONTINUE TO behave identically, since this cleanup is scoped exclusively to `Dukan_x` and SHALL NOT modify files in other projects.

3.12 WHEN any file excluded by `analysis_options.yaml` (`**/*.g.dart`, `**/*.freezed.dart`, `**/*.mocks.dart`, `build/**`, `.dart_tool/**`) is consulted by the build or runtime THEN the system SHALL CONTINUE TO use the same generated content, since these files SHALL NOT be hand-edited as part of this cleanup (regeneration via `build_runner` is permitted only if it produces byte-identical output).
