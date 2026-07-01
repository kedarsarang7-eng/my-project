// ============================================================================
// PHASE 5 — Task 6.4: OCR route REACHES THE PIPELINE (integration runs)
// (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 6.4 — Integration test: the new scan-bill GoRouter route reaches the
//            existing AWS Textract "Smart Inventory Import" pipeline.
// Validates: Requirements 8.4
//
// HOW THIS DIFFERS FROM Task 6.2 `phase5_scan_bill_route_test.dart`:
//   * Task 6.2 asserts STATIC FACTS at pure seams: the route is REGISTERED
//     (name/path/count), the `buildScanBillScreen` seam returns the existing
//     pipeline entry, the capability binding is `useScanOCR`, and the pure
//     `redirectDecision` allows/denies the right types. It never DRIVES a
//     navigation.
//   * THIS suite performs 1–2 representative INTEGRATION RUNS that actually
//     DRIVE a GoRouter URL navigation (`router.go('/app/scan-bill')`) through
//     the EXACT production capability guard (`AppRouter.capabilityRedirect`)
//     and observes the routed result — proving the route is genuinely
//     REACHABLE (its front door is hit) for an OCR-capable session, and
//     genuinely GUARDED (the pipeline is never reached) for a session that
//     lacks the capability.
//
// WHY AN INTEGRATION (example) TEST, NOT A PROPERTY TEST (design.md):
//   The scan-bill pipeline is an EXTERNAL pipeline (AWS Textract OCR over the
//   network). The design's Testing Strategy explicitly validates "OCR scan-bill
//   route reaches the existing Textract pipeline (Phase 5) — 1–2 representative
//   examples (external pipeline, not PBT)". So this is example-based, and the
//   external AWS call is NEVER triggered.
//
// REACHABILITY SEAM + EXTERNAL-PIPELINE LIMITATION (documented):
//   The pipeline's FRONT DOOR is `ScanBillImagePickerScreen` (the entry screen
//   of `features/purchase/scan_bill.dart`). Mounting that screen for real pulls
//   heavy infrastructure that is out of scope to stand up in a routing unit
//   test and would require the external pipeline / device plugins:
//     - `sl<LoggerService>()` (GetIt service locator) in its State,
//     - `image_picker` / `image_cropper` platform plugins,
//     - the `scanBillSessionProvider` (Dio-backed `ScanBillApiClient` →
//       `/purchase/scan-bill/extract` → AWS Textract).
//   Per the task guidance, we therefore assert reachability at the PRODUCTION
//   route seam: a real `router.go(...)` is allowed by the production guard to
//   REACH the scan-bill route builder, and that builder constructs the EXISTING
//   pipeline entry via the production `AppRouter.buildScanBillScreen` seam
//   (the IDENTICAL seam the live `appRouterProvider` route builder calls) —
//   yielding a `ScanBillImagePickerScreen` scoped to the active vertical. We do
//   NOT mount the heavy screen and we NEVER trigger a Textract/network call.
//
// DETERMINISM (mirrors `phase3_direct_url_block_widget_test.dart`):
//   The live router's `initialLocation` is `/splash` and its per-item routes
//   build heavy real screens (SplashScreen/AdaptiveShell/GetIt-backed screens),
//   and its guard reads `businessTypeProvider` (which pulls the license
//   snapshot + SharedPreferences). So, exactly as the established Phase 3
//   widget harness does, we build a MINIMAL GoRouter that reuses the PRODUCTION
//   pieces that matter for the claim:
//     (1) the EXACT production guard `AppRouter.capabilityRedirect`, bound to
//         the business type under test (mirroring the live
//         `ref.read(businessTypeProvider).type.name`); and
//     (2) the scan-bill route registered at the REAL `RoutePaths.scanBill`
//         path + `RoutePaths.scanBillName` name, whose builder invokes the
//         PRODUCTION pipeline-reuse seam `AppRouter.buildScanBillScreen` and
//         records the constructed entry screen (rendering a light marker so the
//         heavy screen is not mounted).
//   The shell home and deny destinations are light stubs. The security/
//   reachability-critical path — URL → production guard → scan-bill route /
//   deny — is entirely production code.
//
// TEST-ONLY: no production behavior is changed by this task.
//
// Run: flutter test test/core/routing/phase5_scan_bill_pipeline_integration_test.dart
// ============================================================================

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/features/purchase/presentation/screens/scan_bill_image_picker_screen.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Marker rendered AT the scan-bill route's destination once it is REACHED.
/// Its presence proves the production guard allowed navigation to the pipeline
/// front door; its absence (on the deny run) proves the pipeline was guarded.
const String kPipelineFrontDoorMarker = 'SCAN_BILL_PIPELINE_FRONT_DOOR';

/// Marker for the (light stub) deny destination.
const String kDenyMarker = 'ACCESS_DENIED_STUB';

/// Builds a minimal GoRouter that reuses the PRODUCTION capability guard
/// ([AppRouter.capabilityRedirect]) bound to [businessType] and registers the
/// scan-bill route at the REAL production path/name. The scan-bill route's
/// builder invokes the PRODUCTION pipeline-reuse seam
/// ([AppRouter.buildScanBillScreen]) — scoped to [businessType] exactly as the
/// live route sources it from the active business type — and records the
/// constructed entry screen into [onScreenBuilt] (rendering a light marker so
/// the heavy pipeline screen is never mounted / no Textract call is made).
GoRouter _buildHarnessRouter({
  required String businessType,
  required void Function(Widget screen) onScreenBuilt,
}) {
  return GoRouter(
    initialLocation: RoutePaths.shell, // ungated → always allowed
    // The EXACT production top-level guard, fed a REAL GoRouterState produced
    // by URL navigation, bound to the business type under test (mirroring the
    // live `ref.read(businessTypeProvider).type.name`).
    redirect: (BuildContext context, GoRouterState state) =>
        AppRouter.capabilityRedirect(state, businessType),
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.shell,
        name: RoutePaths.shellName,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('HOME_SHELL'))),
      ),
      // The scan-bill route at its REAL production path + name, so the guard
      // resolves `scan_bill` from a real navigation just as it does live.
      GoRoute(
        path: RoutePaths.scanBill,
        name: RoutePaths.scanBillName,
        builder: (BuildContext context, GoRouterState state) {
          // PRODUCTION pipeline-reuse seam: identical to the seam the live
          // `appRouterProvider` scan-bill route builder calls. Constructing the
          // widget runs no createState()/IO, so this is deterministic and makes
          // no Textract/network call.
          onScreenBuilt(AppRouter.buildScanBillScreen(businessType));
          return const Scaffold(
            body: Center(child: Text(kPipelineFrontDoorMarker)),
          );
        },
      ),
      // Light deny stub (the production deny screen itself is exercised by the
      // Phase 3 suites; here we only need to confirm the pipeline is NOT
      // reached and navigation lands on the deny route).
      GoRoute(
        path: RoutePaths.denied,
        name: RoutePaths.deniedName,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text(kDenyMarker))),
      ),
    ],
  );
}

void main() {
  // The active business type name the live router passes as verticalType /
  // evaluates in the guard (`ref.read(businessTypeProvider).type.name`).
  const String grocery = 'grocery'; // BusinessType.grocery.name

  group('Feature: gorouter-navigation-migration — Phase 5 OCR scan-bill route '
      'REACHES THE PIPELINE (Req 8.4, integration runs)', () {
    // ----------------------------------------------------------------------
    // RUN 1 (representative, positive): an OCR-capable session DRIVES a real
    // URL navigation to `/app/scan-bill` and REACHES the existing pipeline
    // front door (ScanBillImagePickerScreen), scoped to the active vertical.
    // ----------------------------------------------------------------------
    testWidgets(
      'GROCERY navigation to "/app/scan-bill" REACHES the existing pipeline '
      'entry (ScanBillImagePickerScreen), scoped to the active vertical',
      (tester) async {
        // Precondition: grocery genuinely grants useScanOCR, so the guard
        // ALLOWS it — the widget-level reachability below is the live
        // consequence of the production guard, not an assumption.
        expect(
          FeatureResolver.canAccess(grocery, BusinessCapability.useScanOCR),
          isTrue,
          reason: 'grocery must grant useScanOCR for the reachability premise.',
        );
        expect(AppRouter.redirectDecision('scan_bill', grocery), isNull);

        Widget? builtScreen;
        final router = _buildHarnessRouter(
          businessType: grocery,
          onScreenBuilt: (s) => builtScreen = s,
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Sanity: start on the ungated home.
        expect(find.text('HOME_SHELL'), findsOneWidget);
        expect(builtScreen, isNull);

        // DRIVE a real URL navigation (deep link), exactly like opening
        // `/app/scan-bill`.
        router.go(RoutePaths.scanBill);
        await tester.pumpAndSettle();

        // REACHED: the production guard allowed grocery, so navigation landed
        // on the scan-bill route (NOT the deny route, not a crash).
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.scanBill,
          reason:
              'grocery (granted useScanOCR) must reach the scan-bill route '
              'via the production guard.',
        );
        expect(find.text(kPipelineFrontDoorMarker), findsOneWidget);
        expect(find.text(kDenyMarker), findsNothing);

        // REUSE: the route built the EXISTING pipeline entry screen (no new
        // OCR), scoped to the active vertical. This is the pipeline's front
        // door from `features/purchase/scan_bill.dart`.
        expect(
          builtScreen,
          isA<ScanBillImagePickerScreen>(),
          reason:
              'The reached route must construct the EXISTING pipeline entry '
              'screen — proving reuse of the Textract Smart Inventory Import '
              'pipeline, not a new OCR.',
        );
        expect(
          (builtScreen as ScanBillImagePickerScreen).verticalType,
          grocery,
          reason: 'The pipeline session must be scoped to the active vertical.',
        );
      },
    );

    // ----------------------------------------------------------------------
    // RUN 2 (representative, negative control): a session WITHOUT useScanOCR
    // DRIVES the same URL navigation and is GUARDED — it never reaches the
    // pipeline front door (the entry screen is never constructed). This
    // proves the gate protects the pipeline route on REAL navigation, so the
    // "reaches the pipeline" claim is targeted, not blanket.
    // ----------------------------------------------------------------------
    testWidgets(
      'WHOLESALE navigation to "/app/scan-bill" is GUARDED — the pipeline '
      'front door is NEVER reached (route is redirected to deny)',
      (tester) async {
        final String wholesale = BusinessType.wholesale.name;

        // Precondition: wholesale genuinely lacks useScanOCR, so the guard
        // DENIES it.
        expect(
          FeatureResolver.canAccess(wholesale, BusinessCapability.useScanOCR),
          isFalse,
          reason: 'wholesale must NOT grant useScanOCR for the deny premise.',
        );
        expect(
          AppRouter.redirectDecision('scan_bill', wholesale),
          RoutePaths.denied,
        );

        Widget? builtScreen;
        final router = _buildHarnessRouter(
          businessType: wholesale,
          onScreenBuilt: (s) => builtScreen = s,
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('HOME_SHELL'), findsOneWidget);

        router.go(RoutePaths.scanBill);
        await tester.pumpAndSettle();

        // GUARDED: navigation was redirected to the deny route; the scan-bill
        // route builder NEVER ran, so the pipeline entry was never reached.
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          RoutePaths.denied,
          reason:
              'A type lacking useScanOCR must be redirected away from the '
              'scan-bill route (the pipeline is gated).',
        );
        expect(find.text(kDenyMarker), findsOneWidget);
        expect(
          find.text(kPipelineFrontDoorMarker),
          findsNothing,
          reason: 'SECURITY: the pipeline front door must not render.',
        );
        expect(
          builtScreen,
          isNull,
          reason:
              'The pipeline entry screen must NEVER be constructed for a '
              'guarded type (the route builder must not run).',
        );
      },
    );
  });
}
