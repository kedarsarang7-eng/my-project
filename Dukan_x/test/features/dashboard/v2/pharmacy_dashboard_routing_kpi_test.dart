// ============================================================================
// Task 9.2 — Integration test: pharmacy dashboard routing + KPI request
// Feature: pharmacy-vertical-remediation
// Validates: Requirement 12.6 (and exercises 12.1, 12.2, 12.3, 12.4, 12.5)
// ============================================================================
//
// WHAT THIS PROVES (Req 12 — Reconcile Dashboard Split):
//
//   1) SINGLE DESTINATION (Req 12.1, 12.5): the `executive_dashboard` sidebar
//      item resolves — through the shared `SidebarNavigationHandler` — to
//      EXACTLY one destination for a pharmacy session: `PharmacyDashboardScreen`
//      (never the generic `DashboardController`, never a placeholder). For a
//      non-pharmacy session the SAME item keeps the generic `DashboardController`
//      so the other 18 verticals are unchanged (Req 5.3).
//
//   2) KPI REQUEST CARRIES tenantId (Req 12.2): the dashboard's KPI provider
//      (`pharmacyKpiProvider`) resolves the active tenantId through the shared
//      `TenantScope` chokepoint and calls `pharmacy_dashboard_service`
//      .fetchKpiData(tenantId: <active>) with it.
//
//   3) ERROR BRANCH (Req 12.3): when the service errors, the provider surfaces
//      the error (so the dashboard can show an error + retry without navigating
//      away) and the service was actually invoked.
//
//   4) TIMEOUT BRANCH (Req 12.3): when the service does not respond, the KPI
//      request is bounded to 10s and surfaces a `TimeoutException`. Proven
//      deterministically with `fake_async` (no 10s real-time wait).
//
//   5) NO-TENANT BRANCH (Req 12.4): when no active tenantId can be resolved,
//      the provider raises the canonical `TenantScopeError` and SKIPS the KPI
//      request entirely (the service is never called).
//
// SEAMS / TEST DOUBLES:
//   * `FakeSessionManager` (`extends Mock implements SessionManager`, the
//     repo-wide pattern) pins `currentBusinessId` (drives `TenantScope`) and
//     `activeBusinessType` (drives the handler's pharmacy gate). Registered in
//     the GetIt service locator so production code resolves it via `sl<>`.
//   * `FakePharmacyDashboardService` (`extends Mock implements
//     PharmacyDashboardService`) records the tenantId passed to `fetchKpiData`
//     and lets each test script success / error / hang. Its `Mock` base skips
//     the real constructor's `sl<ApiClient>()` lookup.
//   * `authStateProvider` / `businessTypeProvider` are overridden with tiny
//     notifier subclasses so the KPI provider's auth + business-type guards
//     pass without SharedPreferences / Firebase / GetIt session wiring.
//
// Run: flutter test test/features/dashboard/v2/pharmacy_dashboard_routing_kpi_test.dart
// ============================================================================

import 'dart:async';

import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/error/tenant_scope_error.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/dashboard/presentation/screens/dashboard_controller.dart';
import 'package:dukanx/features/dashboard/v2/models/pharmacy_dashboard_models.dart';
import 'package:dukanx/features/dashboard/v2/providers/pharmacy_dashboard_providers.dart';
import 'package:dukanx/features/dashboard/v2/screens/pharmacy_dashboard_screen.dart';
import 'package:dukanx/features/dashboard/v2/services/pharmacy_dashboard_service.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A lightweight fake [SessionManager] whose `currentBusinessId` (the active
/// tenantId source for `TenantScope`) and `activeBusinessType` (the pharmacy
/// gate the handler reads) are fixed via the constructor. `Mock` supplies
/// `noSuchMethod` no-ops for every other member; the code under test only
/// reads the two getters we override here.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager({
    this.businessId,
    this.activeType = BusinessType.pharmacy,
  });

  final String? businessId;
  final BusinessType activeType;

  @override
  String? get currentBusinessId => businessId;

  @override
  BusinessType get activeBusinessType => activeType;
}

/// A fake [PharmacyDashboardService] that records the tenantId passed to
/// [fetchKpiData] and delegates the call's behaviour to [onFetchKpi] so each
/// test can script success / error / hang. The `Mock` base means the real
/// constructor (which resolves `sl<ApiClient>()`) is never run.
class FakePharmacyDashboardService extends Mock
    implements PharmacyDashboardService {
  FakePharmacyDashboardService({required this.onFetchKpi});

  final Future<PharmacyKpiData> Function(
    String tenantId,
    PharmacyDashboardFilters filters,
  )
  onFetchKpi;

  int fetchKpiCallCount = 0;
  String? lastTenantId;

  @override
  Future<PharmacyKpiData> fetchKpiData({
    required String tenantId,
    required PharmacyDashboardFilters filters,
  }) {
    fetchKpiCallCount++;
    lastTenantId = tenantId;
    return onFetchKpi(tenantId, filters);
  }
}

/// Authenticated [AuthState] override so `pharmacyKpiProvider`'s auth guard
/// passes without the real SessionManager-backed notifier.
class _AuthenticatedAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated);
}

/// Pharmacy [BusinessTypeState] override so `pharmacyKpiProvider`'s
/// `ref.watch(businessTypeProvider)` resolves without SharedPreferences /
/// license-snapshot wiring.
class _PharmacyBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.pharmacy);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// The overrides that let the KPI provider build in isolation: an
/// authenticated auth state and a pharmacy business type, so the provider's
/// guards pass without the real SessionManager-backed notifiers.
ProviderContainer _kpiContainer() => ProviderContainer(
  overrides: [
    authStateProvider.overrideWith(_AuthenticatedAuthNotifier.new),
    businessTypeProvider.overrideWith(_PharmacyBusinessTypeNotifier.new),
  ],
);

/// Pumps real microtasks until the KPI provider leaves its loading state (or a
/// bounded number of turns elapses), then returns the settled [AsyncValue].
/// The provider must already be subscribed so it stays alive while settling.
Future<AsyncValue<PharmacyKpiData>> _settleKpi(
  ProviderContainer container,
) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(pharmacyKpiProvider);
    if (!state.isLoading) return state;
    await Future<void>.delayed(Duration.zero);
  }
  return container.read(pharmacyKpiProvider);
}

/// Registers the fakes that production code resolves through GetIt.
void _registerFakes({
  required String? businessId,
  required FakePharmacyDashboardService service,
  BusinessType activeType = BusinessType.pharmacy,
}) {
  sl.registerSingleton<SessionManager>(
    FakeSessionManager(businessId: businessId, activeType: activeType),
  );
  sl.registerSingleton<PharmacyDashboardService>(service);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await sl.reset();
  });

  // =========================================================================
  // 1) Routing: single executive_dashboard destination (Req 12.1, 12.5)
  // =========================================================================
  group('Feature: pharmacy-vertical-remediation — executive_dashboard routing '
      '(Req 12.1, 12.5, 12.6)', () {
    testWidgets(
      'pharmacy session resolves executive_dashboard to the single '
      'PharmacyDashboardScreen destination (never generic, never placeholder)',
      (tester) async {
        sl.registerSingleton<SessionManager>(
          FakeSessionManager(activeType: BusinessType.pharmacy),
        );

        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final screen = SidebarNavigationHandler.tryGetScreenForItem(
          'executive_dashboard',
          ctx,
        );

        // Resolves to exactly the pharmacy dashboard — the single destination.
        expect(screen, isA<PharmacyDashboardScreen>());
        // And NOT to the generic dashboard or a null (placeholder) miss.
        expect(screen, isNot(isA<DashboardController>()));
        expect(screen, isNotNull);
      },
    );

    testWidgets(
      'non-pharmacy session keeps the generic DashboardController for '
      'executive_dashboard (other verticals unchanged, Req 5.3)',
      (tester) async {
        sl.registerSingleton<SessionManager>(
          FakeSessionManager(activeType: BusinessType.grocery),
        );

        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final screen = SidebarNavigationHandler.tryGetScreenForItem(
          'executive_dashboard',
          ctx,
        );

        expect(screen, isA<DashboardController>());
        expect(screen, isNot(isA<PharmacyDashboardScreen>()));
      },
    );
  });

  // =========================================================================
  // 2) KPI request: tenant scoping, error, timeout, no-tenant (Req 12.2–12.4)
  // =========================================================================
  group('Feature: pharmacy-vertical-remediation — pharmacyKpiProvider KPI '
      'request (Req 12.2, 12.3, 12.4, 12.6)', () {
    test('KPI request is scoped to the active tenantId and returns data '
        '(Req 12.2)', () async {
      final service = FakePharmacyDashboardService(
        onFetchKpi: (_, __) async => PharmacyKpiData.empty,
      );
      _registerFakes(businessId: 'tenant-alpha', service: service);

      final container = _kpiContainer();
      addTearDown(container.dispose);
      // Keep the provider subscribed so its future settles deterministically.
      final sub = container.listen(
        pharmacyKpiProvider,
        (_, __) {},
        onError: (_, __) {},
      );
      addTearDown(sub.close);

      final data = await container.read(pharmacyKpiProvider.future);

      expect(data, isA<PharmacyKpiData>());
      expect(service.fetchKpiCallCount, 1);
      expect(
        service.lastTenantId,
        'tenant-alpha',
        reason: 'The KPI request must carry the active tenantId (Req 12.2).',
      );
    });

    test('a service error surfaces as the provider error state without '
        'crashing (Req 12.3)', () async {
      final service = FakePharmacyDashboardService(
        onFetchKpi: (_, __) async => throw Exception('service unavailable'),
      );
      _registerFakes(businessId: 'tenant-alpha', service: service);

      final container = _kpiContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        pharmacyKpiProvider,
        (_, __) {},
        onError: (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final state = await _settleKpi(container);

      // The error is held as the provider's error state (retry-able) — the
      // dashboard stays put rather than crashing / navigating away.
      expect(state.hasError, isTrue);
      expect(state.error, isA<Exception>());
      expect(service.fetchKpiCallCount, 1);
    });

    test('the KPI request is bounded to 10s and surfaces a TimeoutException '
        'when the service does not respond (Req 12.3)', () {
      fakeAsync((async) {
        // A future that never completes models an unresponsive service.
        final hang = Completer<PharmacyKpiData>();
        final service = FakePharmacyDashboardService(
          onFetchKpi: (_, __) => hang.future,
        );
        _registerFakes(businessId: 'tenant-alpha', service: service);

        final container = _kpiContainer();
        final sub = container.listen(
          pharmacyKpiProvider,
          (_, __) {},
          onError: (_, __) {},
          fireImmediately: true,
        );

        // Body runs up to the awaited service call; still loading at 9s.
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 9));
        async.flushMicrotasks();
        expect(container.read(pharmacyKpiProvider).isLoading, isTrue);

        // Past the 10s bound the request times out into the error state.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        final state = container.read(pharmacyKpiProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<TimeoutException>());
        expect(service.fetchKpiCallCount, greaterThanOrEqualTo(1));
        expect(service.lastTenantId, 'tenant-alpha');

        sub.close();
        container.dispose();
      });
    });

    test('no resolvable tenantId raises TenantScopeError and SKIPS the KPI '
        'request entirely (Req 12.4)', () async {
      var called = false;
      final service = FakePharmacyDashboardService(
        onFetchKpi: (_, __) async {
          called = true;
          return PharmacyKpiData.empty;
        },
      );
      // Blank/absent business id → no resolvable active tenantId.
      _registerFakes(businessId: null, service: service);

      final container = _kpiContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        pharmacyKpiProvider,
        (_, __) {},
        onError: (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final state = await _settleKpi(container);

      expect(state.hasError, isTrue);
      expect(state.error, isA<TenantScopeError>());
      expect(
        service.fetchKpiCallCount,
        0,
        reason:
            'The KPI request must be skipped when no tenant resolves '
            '(Req 12.4).',
      );
      expect(called, isFalse);
    });
  });
}
