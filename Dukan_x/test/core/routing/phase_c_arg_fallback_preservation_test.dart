// ============================================================================
// PHASE C — Task 6.4: PRESERVATION TEST for argument routes
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 10.2, 10.3**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the CHANGED code):
//
//   This is the inverse of the Task 6.1 EXPLORATION test
//   (`phase_c_arg_fallback_exploration_test.dart`). That test pinned, per
//   argument-bearing legacy route, two facts about the UNCHANGED code:
//     (a) the arg routes were NOT yet registered under the live AppRouter
//         (deferred from Phase B); and
//     (b) the LEGACY builder in `lib/app/routes.dart` already carried the
//         defensive `is`-type-check + safe fallback contract.
//
//   Phase C (Task 6.2) then registered each arg-bearing legacy string as a
//   top-level `GoRoute` whose builder reads `GoRouterState.extra` (instead of
//   `ModalRoute.settings.arguments`) while lifting the guard wrappers, the
//   `is`-type-check, and the safe fallback CHARACTER-FOR-CHARACTER from
//   `buildAppRoutes()` (design.md AD-3). This preservation test proves the
//   defensive fallback contract is PRESERVED on go_router's `extra`: for each
//   representative arg route, driving `context.push('<path>', extra: <value>)`
//   with three `extra` variants — VALID (correct type), NULL, and WRONG-TYPED —
//   resolves to the intended guard-wrapped path (valid) or to the SAME safe
//   legacy fallback (null / wrong-typed), with NO crash and WITHOUT falling
//   through to the route-not-found screen.
//
// THE THREE REPRESENTATIVE ARG ROUTES (spanning the arg shapes):
//
//   | Path                     | Arg shape        | Variant behaviour verified                                   |
//   |--------------------------|------------------|--------------------------------------------------------------|
//   | /customer_portal         | String non-empty | valid -> CustomerRoleGuard (intended path);                  |
//   |                          |                  | null / wrong -> plain guard-free Scaffold:                   |
//   |                          |                  | "Invalid customer portal access. Please login again."        |
//   | /clinic/consultation     | Map<String,String>| Req 10.3: non-clinic business type -> VendorRoleGuard +      |
//   |                          |                  | BusinessGuard DENY (target ConsultationScreen NOT built) for |
//   |                          |                  | ALL three extra variants — isolation preserved indep. of args|
//   | /advanced_bill_creation  | optional Bill    | null -> create mode; valid Bill -> edit mode; wrong -> create|
//   |                          |                  | — all resolve to VendorRoleGuard, no crash.                  |
//
// DETERMINISM (mirrors the established harness rationale in
// `phase_b_guarded_resolution_preservation_test.dart`):
//   The live router's `initialLocation` is `/splash`, whose `SplashScreen` runs
//   a repeating animation + audio/GetIt init that never settles, so we do NOT
//   pump the heavy `/splash` entry. The widget-level harness pumps a MINIMAL
//   `MaterialApp.router` that reuses the EXACT production pieces that matter:
//   the real `LegacyRoutes.routes()` table and the real production not-found
//   builder (lifted from the live router) as the errorBuilder, so a resolved
//   guard / fallback render is provably distinct from the not-found fallback.
//
//   To keep VALID args from constructing heavy target screens, the guarded
//   variants are pumped with the SessionManager still resolving, so the lifted
//   `VendorRoleGuard` / `CustomerRoleGuard` renders its "Verifying access..."
//   gate (proving the guard wrapper resolved, NOT the not-found screen) without
//   building the heavy child. Because that gate animates forever, those pumps
//   are FIXED (`pump` + `pump(50ms)`), never `pumpAndSettle`. The guard-free
//   fallback Scaffolds and the static BusinessGuard deny (SizedBox.shrink) DO
//   settle, so those use `pumpAndSettle`.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test \
//   test/core/routing/phase_c_arg_fallback_preservation_test.dart \
//   --reporter expanded
// ============================================================================

import 'package:dukanx/core/auth/auth_loading_screen.dart';
import 'package:dukanx/core/auth/role_guard.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/clinic/presentation/screens/consultation_screen.dart';
import 'package:dukanx/features/core/auth/business_type_guard.dart';
import 'package:dukanx/models/bill.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

/// Lightweight ungated home for the harness whose button issues the imperative
/// go_router push under test (the exact go_router equivalent of the legacy
/// `Navigator.pushNamed('<path>', arguments: <value>)` call site).
const String kHarnessHomePath = '/harness-home';
const String kHarnessHomeMarker = 'HARNESS_HOME';

/// The guard-free safe fallback rendered by `/customer_portal` for missing /
/// wrong-typed args (the contract Phase C preserves, lifted verbatim).
const String kCustomerPortalFallbackText =
    'Invalid customer portal access. Please login again.';

/// The production not-found screen body text (rendered by the live router's
/// `errorBuilder`). A resolved guard / fallback render must NOT show this.
const String kNotFoundMarker = 'Unknown Screen';

// ---------------------------------------------------------------------------
// Harness helpers (mirror phase_b_guarded_resolution_preservation_test.dart).
// ---------------------------------------------------------------------------

/// Finds the [GoRoute] registered for [path] anywhere in the router
/// configuration and returns its builder, so the harness can render the REAL
/// production not-found screen (not a stand-in).
GoRouterWidgetBuilder? _findBuilderForPath(
  List<RouteBase> routes,
  String path,
) {
  for (final route in routes) {
    if (route is GoRoute) {
      if (route.path == path) return route.builder;
      final nested = _findBuilderForPath(route.routes, path);
      if (nested != null) return nested;
    } else if (route is ShellRouteBase) {
      final nested = _findBuilderForPath(route.routes, path);
      if (nested != null) return nested;
    }
  }
  return null;
}

/// Lifts the REAL production not-found builder from the live router so the
/// harness errorBuilder renders the actual `_RouteNotFoundScreen`. A resolved
/// guard / fallback render is then provably distinct from this fallback.
GoRouterWidgetBuilder _liveNotFoundBuilder() {
  final container = ProviderContainer();
  final router = container.read(appRouterProvider);
  final builder = _findBuilderForPath(
    router.configuration.routes,
    RoutePaths.notFound,
  );
  router.dispose();
  container.dispose();
  if (builder == null) {
    throw StateError(
      'The live router must register the not-found route '
      '(${RoutePaths.notFound}) whose builder renders the production '
      '"Feature Not Found" screen.',
    );
  }
  return builder;
}

/// Builds a minimal harness `GoRouter` that registers the ACTUAL
/// `LegacyRoutes.routes()` plus an ungated home whose button pushes [pushPath]
/// carrying [extra] (the go_router equivalent of the legacy
/// `Navigator.pushNamed(pushPath, arguments: extra)`).
///
/// The top-level redirect consults the SAME production `aliasTargetFor` single
/// source of truth (faithful composition); arg routes are NOT aliases, so it is
/// a no-op for them. It deliberately does NOT add the router-level capability
/// guard — legacy routes are protected by their WIDGET guards (Req 4.6 / AD-2).
GoRouter _harnessPushing(
  String pushPath,
  Object? extra,
  GoRouterWidgetBuilder notFound,
) {
  return GoRouter(
    initialLocation: kHarnessHomePath,
    redirect: (BuildContext context, GoRouterState state) =>
        LegacyRoutes.aliasTargetFor(state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
        path: kHarnessHomePath,
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push(pushPath, extra: extra),
              child: const Text(kHarnessHomeMarker),
            ),
          ),
        ),
      ),
      // The REAL migrated arg-bearing legacy routes (single source of truth).
      ...LegacyRoutes.routes(),
    ],
    errorBuilder: notFound,
  );
}

/// A lightweight fake [SessionManager] whose auth-state getters are fixed via
/// the constructor (mirrors the helper in the Phase B preservation test).
/// [SessionManager] is a [ChangeNotifier], so the guards' `ListenableBuilder`
/// can listen to it; `Mock` provides the inherited listener no-ops via
/// `noSuchMethod`, while the boolean getters the guards read are overridden
/// with real backing values.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager({
    this.isLoading = false,
    this.isInitialized = true,
    this.isAuthenticated = true,
    this.isOwner = true,
    this.isCustomerOnlyMode = false,
  });

  /// Session still resolving -> the guard shows the "Verifying access..." gate
  /// (builds no child screen, schedules no redirect) — deterministic and light.
  factory FakeSessionManager.resolving() =>
      FakeSessionManager(isLoading: true, isInitialized: false);

  /// Authenticated owner -> `VendorRoleGuard` passes through to its child
  /// (e.g. the inner `BusinessGuard`).
  factory FakeSessionManager.authenticatedOwner() => FakeSessionManager();

  @override
  final bool isLoading;
  @override
  final bool isInitialized;
  @override
  final bool isAuthenticated;
  @override
  final bool isOwner;
  @override
  final bool isCustomerOnlyMode;
}

/// A [BusinessTypeNotifier] pinned to a fixed type, used to override
/// [businessTypeProvider] without touching SharedPreferences. Mirrors the
/// helper in the Phase B preservation test.
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  _FixedBusinessTypeNotifier(this._fixed);
  final BusinessType _fixed;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _fixed);
}

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  final GoRouterWidgetBuilder notFound = _liveNotFoundBuilder();

  group('Feature: imperative-navigation-gorouter-migration — Phase C '
      'PRESERVATION: argument routes preserve the defensive fallback contract '
      'on GoRouterState.extra (Req 10.2, 10.3)', () {
    // ====================================================================
    // (0) CONFIG-LEVEL — the three representative arg routes are now
    //     registered GoRoutes / known legacy paths (the Phase C gap closed).
    // ====================================================================
    test('the live AppRouter now registers the representative arg routes, '
        'and isKnownLegacyPath is true for each (Req 10.2 — gap closed)', () {
      const List<String> argPaths = <String>[
        '/customer_portal',
        '/clinic/consultation',
        '/advanced_bill_creation',
      ];

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      final Set<String> paths = <String>{};
      void collect(List<RouteBase> routes) {
        for (final route in routes) {
          if (route is GoRoute) {
            paths.add(route.path);
            collect(route.routes);
          } else if (route is ShellRouteBase) {
            collect(route.routes);
          }
        }
      }

      collect(router.configuration.routes);

      for (final argPath in argPaths) {
        expect(
          paths,
          contains(argPath),
          reason:
              '"$argPath" must now be a registered GoRoute path under the '
              'live AppRouter (Phase C / Task 6.2 registration).',
        );
        expect(
          LegacyRoutes.isKnownLegacyPath(argPath),
          isTrue,
          reason:
              'LegacyRoutes.isKnownLegacyPath("$argPath") must be true now '
              'that its arg-bearing GoRoute is registered.',
        );
      }
    });

    // ====================================================================
    // ROUTE 1 — /customer_portal (String shape): guard-free fallback on
    //   null / wrong-typed; CustomerRoleGuard on valid String.
    // ====================================================================
    group('/customer_portal (String shape)', () {
      testWidgets(
        'VALID String extra resolves to the intended CustomerRoleGuard path '
        '(NOT the fallback, NOT not-found)',
        (tester) async {
          // Resolving session -> CustomerRoleGuard renders its gate, so the
          // heavy CustomerDashboardScreen is never built.
          await GetIt.I.reset();
          GetIt.I.registerSingleton<SessionManager>(
            FakeSessionManager.resolving(),
          );
          addTearDown(() async => GetIt.I.reset());

          final harness = _harnessPushing(
            '/customer_portal',
            'customer-123',
            notFound,
          );
          addTearDown(harness.dispose);

          await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
          await tester.pumpAndSettle();
          expect(find.text(kHarnessHomeMarker), findsOneWidget);

          await tester.tap(find.text(kHarnessHomeMarker));
          // Fixed pumps: the resolving guard shows AuthLoadingScreen whose
          // spinner animates forever and would never settle.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(
            find.byType(CustomerRoleGuard),
            findsOneWidget,
            reason:
                'A valid non-empty String extra must resolve to the intended '
                'CustomerRoleGuard-wrapped path.',
          );
          expect(find.byType(AuthLoadingScreen), findsOneWidget);
          expect(find.text('Verifying access...'), findsOneWidget);
          expect(
            find.text(kCustomerPortalFallbackText),
            findsNothing,
            reason:
                'A valid String extra must NOT render the missing-args '
                'fallback Scaffold.',
          );
          expect(
            find.text(kNotFoundMarker),
            findsNothing,
            reason: 'The route resolved; it must not be the not-found screen.',
          );
        },
      );

      testWidgets(
        'NULL extra falls back to the SAME safe guard-free Scaffold the '
        'legacy table used (no crash, not not-found)',
        (tester) async {
          await GetIt.I.reset();
          GetIt.I.registerSingleton<SessionManager>(
            FakeSessionManager.resolving(),
          );
          addTearDown(() async => GetIt.I.reset());

          final harness = _harnessPushing('/customer_portal', null, notFound);
          addTearDown(harness.dispose);

          await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
          await tester.pumpAndSettle();
          expect(find.text(kHarnessHomeMarker), findsOneWidget);

          await tester.tap(find.text(kHarnessHomeMarker));
          // The fallback is a plain static Scaffold -> it settles.
          await tester.pumpAndSettle();

          expect(
            find.text(kCustomerPortalFallbackText),
            findsOneWidget,
            reason:
                'With null extra, "/customer_portal" must fall back to the '
                'safe "Invalid customer portal access" Scaffold (preserved '
                'verbatim).',
          );
          expect(
            find.byType(CustomerRoleGuard),
            findsNothing,
            reason:
                'The guard-free fallback path must NOT build CustomerRoleGuard.',
          );
          expect(
            find.text(kNotFoundMarker),
            findsNothing,
            reason: 'The route resolved; it must not be the not-found screen.',
          );
        },
      );

      testWidgets(
        'WRONG-TYPED (int) extra falls back to the SAME safe guard-free '
        'Scaffold (never an unconditional cast, no crash, not not-found)',
        (tester) async {
          await GetIt.I.reset();
          GetIt.I.registerSingleton<SessionManager>(
            FakeSessionManager.resolving(),
          );
          addTearDown(() async => GetIt.I.reset());

          final harness = _harnessPushing(
            '/customer_portal',
            12345, // wrong type: int, not String
            notFound,
          );
          addTearDown(harness.dispose);

          await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
          await tester.pumpAndSettle();
          expect(find.text(kHarnessHomeMarker), findsOneWidget);

          await tester.tap(find.text(kHarnessHomeMarker));
          await tester.pumpAndSettle();

          expect(
            find.text(kCustomerPortalFallbackText),
            findsOneWidget,
            reason:
                'With wrong-typed (int) extra, "/customer_portal" must fall '
                'back to the safe Scaffold — the `args is String` check is '
                'preserved (never an unconditional cast).',
          );
          expect(find.byType(CustomerRoleGuard), findsNothing);
          expect(
            find.text(kNotFoundMarker),
            findsNothing,
            reason: 'The route resolved; it must not be the not-found screen.',
          );
        },
      );
    });

    // ====================================================================
    // ROUTE 2 — /clinic/consultation (Map shape): Req 10.3 business-type
    //   isolation preserved INDEPENDENT of args. A non-clinic business type
    //   gets the VendorRoleGuard(child: BusinessGuard) DENY for EVERY extra
    //   variant (valid Map, null, wrong-typed) — the target ConsultationScreen
    //   is never built.
    // ====================================================================
    group('/clinic/consultation (Map shape) — Req 10.3 isolation', () {
      // valid Map, null, wrong-typed (int) — all must deny under non-clinic.
      final Map<String, Object?> variants = <String, Object?>{
        'VALID Map<String,String> extra': <String, String>{
          'patientId': 'p1',
          'patientName': 'John Doe',
        },
        'NULL extra': null,
        'WRONG-TYPED (int) extra': 999,
      };

      variants.forEach((label, extra) {
        testWidgets('$label under a NON-clinic business type resolves to '
            'VendorRoleGuard + BusinessGuard DENY (ConsultationScreen NOT '
            'built), preserving isolation independent of args', (tester) async {
          // Authenticated owner -> VendorRoleGuard passes through to the
          // inner BusinessGuard, which denies for a non-clinic type.
          await GetIt.I.reset();
          GetIt.I.registerSingleton<SessionManager>(
            FakeSessionManager.authenticatedOwner(),
          );
          addTearDown(() async => GetIt.I.reset());

          // Active business type is grocery (NOT clinic) -> deny regardless
          // of the args carried in `extra`.
          final container = ProviderContainer(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _FixedBusinessTypeNotifier(BusinessType.grocery),
              ),
            ],
          );
          addTearDown(container.dispose);

          final harness = _harnessPushing(
            '/clinic/consultation',
            extra,
            notFound,
          );
          addTearDown(harness.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(routerConfig: harness),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(kHarnessHomeMarker), findsOneWidget);

          await tester.tap(find.text(kHarnessHomeMarker));
          // Authenticated owner + static BusinessGuard deny (SizedBox.shrink
          // for this route — no denialMessage) -> the tree settles.
          await tester.pumpAndSettle();

          // The arg route resolved to its lifted nested guard wrappers...
          expect(
            find.byType(VendorRoleGuard),
            findsOneWidget,
            reason:
                '"/clinic/consultation" must resolve to its lifted '
                'VendorRoleGuard wrapper for every extra variant.',
          );
          expect(
            find.byType(BusinessGuard),
            findsOneWidget,
            reason:
                '"/clinic/consultation" must resolve to its inner '
                'BusinessGuard (business-type isolation preserved).',
          );
          // ...and the BusinessGuard DENIED, so the target screen is not
          // built — isolation holds independent of the args (Req 10.3).
          expect(
            find.byType(ConsultationScreen),
            findsNothing,
            reason:
                'A non-clinic business type must DENY the clinic route '
                'regardless of args — ConsultationScreen must NOT be built.',
          );
          // And it is NOT the production not-found screen (route resolved).
          expect(
            find.text(kNotFoundMarker),
            findsNothing,
            reason:
                'The route resolved to its guard chain; it must not be the '
                'not-found screen.',
          );
        });
      });
    });

    // ====================================================================
    // ROUTE 3 — /advanced_bill_creation (optional Bill shape): null -> create
    //   mode; valid Bill -> edit mode; wrong-typed -> create mode. All resolve
    //   to the lifted VendorRoleGuard with no crash.
    // ====================================================================
    group('/advanced_bill_creation (optional Bill shape)', () {
      // valid Bill, null (create mode), wrong-typed String (create mode).
      final Map<String, Object?> variants = <String, Object?>{
        'VALID Bill extra (edit mode)': Bill.empty(),
        'NULL extra (create mode)': null,
        'WRONG-TYPED (String) extra (create mode)': 'not-a-bill',
      };

      variants.forEach((label, extra) {
        testWidgets(
          '$label resolves to the lifted VendorRoleGuard (no crash, not '
          'not-found)',
          (tester) async {
            // Resolving session -> VendorRoleGuard renders its gate, so the
            // heavy AdvancedBillCreationScreen is never built; both the edit
            // and create branches resolve to the same guard wrapper.
            await GetIt.I.reset();
            GetIt.I.registerSingleton<SessionManager>(
              FakeSessionManager.resolving(),
            );
            addTearDown(() async => GetIt.I.reset());

            final harness = _harnessPushing(
              '/advanced_bill_creation',
              extra,
              notFound,
            );
            addTearDown(harness.dispose);

            await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
            await tester.pumpAndSettle();
            expect(find.text(kHarnessHomeMarker), findsOneWidget);

            await tester.tap(find.text(kHarnessHomeMarker));
            // Fixed pumps: the resolving guard's spinner never settles.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));

            expect(
              find.byType(VendorRoleGuard),
              findsOneWidget,
              reason:
                  '"/advanced_bill_creation" must resolve to its lifted '
                  'VendorRoleGuard wrapper for every extra variant.',
            );
            expect(find.byType(AuthLoadingScreen), findsOneWidget);
            expect(find.text('Verifying access...'), findsOneWidget);
            expect(
              find.text(kNotFoundMarker),
              findsNothing,
              reason:
                  'The route resolved to its guard wrapper; it must not be '
                  'the not-found screen.',
            );
          },
        );
      });
    });
  });
}
