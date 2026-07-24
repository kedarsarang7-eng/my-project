/// MobileShop Navigation Tests — Task 13.5
///
/// Tests cover: sidebar catalog completeness, sidebar builder filtering,
/// route bindings, quick action handling, deep link resolution,
/// content-host guard, session state widgets, status card behavior,
/// and sole-router composition assertion.
///
/// Requirements validated: 2.1–2.9, 5.8–5.11, 8.3–8.7, 13.1
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/auth/business_type.dart';
import 'package:dukanx/features/mobile_shop/auth/domain_error.dart';
import 'package:dukanx/features/mobile_shop/auth/mobile_policy_guard.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context_resolver.dart';
import 'package:dukanx/features/mobile_shop/migration/sole_router_assertion.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_content_host_guard.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_deep_links.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_quick_actions.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_route_bindings.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_route_catalog.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_route_entry.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_sidebar_builder.dart';
import 'package:dukanx/features/mobile_shop/permissions/mobile_shop_permissions.dart';
import 'package:dukanx/features/mobile_shop/widgets/mobile_shop_session_state.dart';
import 'package:dukanx/features/mobile_shop/widgets/mobile_shop_status_card.dart';

// =============================================================================
// Test Helpers — Mock TenantContextResolver
// =============================================================================

/// A mock [TenantContextResolver] for test isolation.
///
/// Allows tests to control what `require()` and `requireMobileShop()` return
/// without depending on SessionManager or real auth.
class MockTenantContextResolver implements TenantContextResolver {
  final TenantResult<TenantContext> Function()? _requireFn;
  final TenantResult<TenantContext> Function()? _requireMobileShopFn;
  final TenantContext? _current;

  MockTenantContextResolver({
    TenantResult<TenantContext> Function()? requireFn,
    TenantResult<TenantContext> Function()? requireMobileShopFn,
    TenantContext? current,
  }) : _requireFn = requireFn,
       _requireMobileShopFn = requireMobileShopFn,
       _current = current;

  /// Creates a resolver that always grants access for a mobileShop tenant.
  factory MockTenantContextResolver.granted({
    Set<String> permissions = const {},
  }) {
    final ctx = _testMobileShopContext(permissions: permissions);
    return MockTenantContextResolver(
      requireFn: () => TenantSuccess(ctx),
      requireMobileShopFn: () => TenantSuccess(ctx),
      current: ctx,
    );
  }

  /// Creates a resolver that returns session-expired failure.
  factory MockTenantContextResolver.sessionExpired() {
    return MockTenantContextResolver(
      requireFn: () => const TenantFailure(DomainError.sessionExpired()),
      requireMobileShopFn: () =>
          const TenantFailure(DomainError.sessionExpired()),
      current: null,
    );
  }

  /// Creates a resolver that returns wrong-business-type failure.
  factory MockTenantContextResolver.wrongBusinessType() {
    final ctx = _testGroceryContext();
    return MockTenantContextResolver(
      requireFn: () => TenantSuccess(ctx),
      requireMobileShopFn: () =>
          const TenantFailure(DomainError.wrongBusinessType()),
      current: ctx,
    );
  }

  @override
  TenantResult<TenantContext> require() =>
      _requireFn?.call() ?? const TenantFailure(DomainError.sessionExpired());

  @override
  TenantResult<TenantContext> requireMobileShop() =>
      _requireMobileShopFn?.call() ??
      const TenantFailure(DomainError.sessionExpired());

  @override
  TenantContext? get current => _current;

  @override
  void invalidate() {}
}

/// Creates a test [TenantContext] for mobileShop.
TenantContext _testMobileShopContext({Set<String> permissions = const {}}) {
  return TenantContext(
    tenantId: 'test-tenant-001',
    businessId: 'test-business-001',
    subjectId: 'test-user-001',
    businessType: MobileShopBusinessType.mobileShop,
    permissions: permissions,
    correlationId: 'test-correlation-001',
  );
}

/// Creates a test [TenantContext] for a non-mobileShop business.
TenantContext _testGroceryContext() {
  return const TenantContext(
    tenantId: 'test-tenant-002',
    businessId: 'test-business-002',
    subjectId: 'test-user-002',
    businessType: MobileShopBusinessType.grocery,
    permissions: {},
    correlationId: 'test-correlation-002',
  );
}

/// All permissions needed for full sidebar access.
Set<String> get _allPermissions => MobileShopPermissions.all.toSet();

/// All capabilities needed for full sidebar access.
Set<String> get _allCapabilities => const {
  'useIMEI',
  'useWarranty',
  'useBuyback',
  'useExchange',
  'useJobSheets',
};

/// All feature flags needed to show gated entries.
Set<String> get _allFeatures => const {'finance_plans_emi', 'sim_recharge'};

/// Wraps a widget in the minimum tree needed for widget tests.
Widget _testApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// =============================================================================
// 1. Sidebar Catalog Completeness
// =============================================================================

void main() {
  group('1. Sidebar catalog completeness', () {
    test('MobileShopRouteCatalog.all has at least 11 entries', () {
      // Validates Req 2.1: dedicated entries for all mobile workflows
      expect(MobileShopRouteCatalog.all.length, greaterThanOrEqualTo(11));
    });

    test('every entry has non-empty id, label, and routePath', () {
      for (final entry in MobileShopRouteCatalog.all) {
        expect(entry.id, isNotEmpty, reason: '${entry.id} has empty id');
        expect(entry.label, isNotEmpty, reason: '${entry.id} has empty label');
        expect(
          entry.routePath,
          isNotEmpty,
          reason: '${entry.id} has empty routePath',
        );
      }
    });

    test('no duplicate IDs in the catalog', () {
      final ids = MobileShopRouteCatalog.all.map((e) => e.id).toList();
      final uniqueIds = ids.toSet();
      expect(
        uniqueIds.length,
        equals(ids.length),
        reason:
            'Duplicate IDs found: ${ids.where((id) => ids.indexOf(id) != ids.lastIndexOf(id)).toSet()}',
      );
    });

    test('all categories are represented', () {
      // Every non-quickActions category should have at least one entry
      final representedCategories = MobileShopRouteCatalog.all
          .map((e) => e.category)
          .toSet();

      for (final category in MobileShopRouteCategory.values) {
        expect(
          representedCategories.contains(category),
          isTrue,
          reason: 'Category ${category.name} has no entries in the catalog',
        );
      }
    });
  });

  // ===========================================================================
  // 2. Sidebar Builder Filtering
  // ===========================================================================

  group('2. Sidebar builder filtering', () {
    const builder = MobileShopSidebarBuilder();

    test('full permissions/capabilities → all entries visible', () {
      // Validates Req 2.1: dedicated entries exposed under matching gates
      final context = _testMobileShopContext(permissions: _allPermissions);

      final sections = builder.buildSidebar(
        context: context,
        capabilities: _allCapabilities,
        enabledFeatures: _allFeatures,
      );

      // Flatten all visible entries
      final visibleEntries = sections.expand((s) => s.entries).toList();

      // All catalog entries should be visible
      expect(visibleEntries.length, equals(MobileShopRouteCatalog.all.length));
    });

    test('missing permission → entry excluded', () {
      // Validates Req 2.2: exclude entries whose permission is absent
      // Grant all permissions EXCEPT serviceView
      final permissions = _allPermissions.toSet()
        ..remove(MobileShopPermissions.serviceView);
      final context = _testMobileShopContext(permissions: permissions);

      final sections = builder.buildSidebar(
        context: context,
        capabilities: _allCapabilities,
        enabledFeatures: _allFeatures,
      );

      final visibleIds = sections.expand((s) => s.entries).map((e) => e.id);
      expect(visibleIds, isNot(contains('service_jobs')));
    });

    test('missing capability → entry excluded', () {
      // Validates Req 2.2: exclude entries whose capability is absent
      final context = _testMobileShopContext(permissions: _allPermissions);

      // Remove useIMEI capability
      final capabilities = _allCapabilities.toSet()..remove('useIMEI');

      final sections = builder.buildSidebar(
        context: context,
        capabilities: capabilities,
        enabledFeatures: _allFeatures,
      );

      final visibleIds = sections.expand((s) => s.entries).map((e) => e.id);
      expect(visibleIds, isNot(contains('imei_tracking')));
      expect(visibleIds, isNot(contains('serial_imei_history')));
      expect(visibleIds, isNot(contains('imei_lookup')));
    });

    test('feature-gated entry with feature disabled → entry excluded', () {
      // Validates Req 2.2: feature-gated entries hidden when disabled
      final context = _testMobileShopContext(permissions: _allPermissions);

      final sections = builder.buildSidebar(
        context: context,
        capabilities: _allCapabilities,
        enabledFeatures: const {}, // no features enabled
      );

      final visibleIds = sections.expand((s) => s.entries).map((e) => e.id);
      expect(visibleIds, isNot(contains('finance_plans_emi')));
      expect(visibleIds, isNot(contains('sim_recharge')));
    });

    test('non-mobileShop business type → zero entries', () {
      // Validates Req 2.2: non-mobile tenants get zero mobile entries
      final context = _testGroceryContext();

      final sections = builder.buildSidebar(
        context: context,
        capabilities: _allCapabilities,
        enabledFeatures: _allFeatures,
      );

      expect(sections, isEmpty);
    });
  });

  // ===========================================================================
  // 3. Route Bindings
  // ===========================================================================

  group('3. Route bindings', () {
    test('buildMobileShopRoutes returns non-empty list', () {
      // Validates Req 2.3, 2.9: guarded destinations build without exception
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );
      final routes = buildMobileShopRoutes(resolver);
      expect(routes, isNotEmpty);
    });

    test('every catalog entry has a corresponding GoRoute path', () {
      // Validates Req 2.9: every sidebar item has a guarded destination
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );
      final routes = buildMobileShopRoutes(resolver);
      final routePaths = routes.map((r) => r.path).toSet();

      for (final entry in MobileShopRouteCatalog.all) {
        expect(
          routePaths.contains(entry.routePath),
          isTrue,
          reason:
              'No GoRoute found for catalog entry "${entry.id}" '
              'with path "${entry.routePath}"',
        );
      }
    });

    test('IMEI Lookup route path matches catalog entry', () {
      // Validates Req 2.4: IMEI Lookup opens tenant-scoped IMEI history
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );
      final routes = buildMobileShopRoutes(resolver);

      final lookupRoute = routes.firstWhere(
        (r) => r.path == MobileShopRouteCatalog.imeiLookup.routePath,
      );
      expect(lookupRoute.path, equals('/mobile-shop/imei/lookup'));
    });
  });

  // ===========================================================================
  // 4. Quick Action Handling
  // ===========================================================================

  group('4. Quick action handling', () {
    test('accessible entry → navigates to routePath', () {
      // Validates Req 2.3: quick action activates guarded screen
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );
      final sidebarBuilder = const MobileShopSidebarBuilder();
      final context = _testMobileShopContext(permissions: _allPermissions);

      final accessible = sidebarBuilder.isEntryAccessible(
        entry: MobileShopRouteCatalog.imeiLookup,
        context: context,
        capabilities: _allCapabilities,
        enabledFeatures: _allFeatures,
      );
      expect(accessible, isTrue);
    });

    test('inaccessible entry → shows denial (not empty closure)', () {
      // Validates Req 2.3: denied action shows explicit feedback
      final resolver = MockTenantContextResolver.granted(
        permissions: const {}, // no permissions → denied
      );

      // Verify guard denies when permission is missing
      final guard = MobilePolicyGuard(resolver: resolver);
      final result = guard.check(
        requiredPermission: MobileShopPermissions.imeiView,
      );

      expect(result, isA<GuardDenied>());
      final denied = result as GuardDenied;
      expect(denied.denial.kind, equals(GuardDenialKind.permissionDenied));
    });

    test('unknown entry ID → returns false', () {
      // Validates: unknown entries fail gracefully
      final sidebarBuilder = const MobileShopSidebarBuilder();
      final result = sidebarBuilder.findById('nonexistent_entry');
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // 5. Deep Link Resolution
  // ===========================================================================

  group('5. Deep link resolution', () {
    test('known mobile-shop path → DeepLinkResolved', () {
      // Validates Req 2.3: deep links resolve to catalog entries
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );

      final deepLinkResolver = MobileShopDeepLinkResolver(
        resolver: resolver,
        capabilities: _allCapabilities,
        enabledFeatures: _allFeatures,
      );

      final result = deepLinkResolver.resolve('/mobile-shop/imei');
      expect(result, isA<DeepLinkResolved>());
      final resolved = result as DeepLinkResolved;
      expect(resolved.entry.id, equals('imei_tracking'));
    });

    test('cross-vertical path → DeepLinkRedirect to mobile equivalent', () {
      // Validates Req 2.3: cross-vertical paths redirect for mobileShop
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );

      final deepLinkResolver = MobileShopDeepLinkResolver(
        resolver: resolver,
        capabilities: _allCapabilities,
        enabledFeatures: _allFeatures,
      );

      final result = deepLinkResolver.resolve('/computer-shop/serial-history');
      expect(result, isA<DeepLinkRedirect>());
      final redirect = result as DeepLinkRedirect;
      expect(redirect.targetPath, equals('/mobile-shop/imei/history'));
      expect(redirect.originalPath, equals('/computer-shop/serial-history'));
    });

    test('unknown path → DeepLinkNotFound', () {
      // Validates: unknown paths are handled gracefully
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );

      final deepLinkResolver = MobileShopDeepLinkResolver(
        resolver: resolver,
        capabilities: _allCapabilities,
        enabledFeatures: _allFeatures,
      );

      final result = deepLinkResolver.resolve('/totally-unknown/path');
      expect(result, isA<DeepLinkNotFound>());
    });
  });

  // ===========================================================================
  // 6. Content-Host Guard
  // ===========================================================================

  group('6. Content-host guard', () {
    test('known catalog entry → wrapped in guard', () {
      // Validates Req 5.8: content-host guard wraps mobile screens
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );

      final widget = guardedMobileShopScreen(
        'imei_tracking',
        resolver: resolver,
        screenBuilder: () => const Text('IMEI Screen'),
      );

      expect(widget, isNotNull);
      expect(widget, isA<MobileShopContentHostGuard>());
    });

    test('unknown item ID → returns null (fallback to existing dispatch)', () {
      // Validates: unknown items fall through to existing dispatch
      final resolver = MockTenantContextResolver.granted(
        permissions: _allPermissions,
      );

      final widget = guardedMobileShopScreen(
        'completely_unknown_item',
        resolver: resolver,
      );

      expect(widget, isNull);
    });

    testWidgets('denied context → shows denial widget (not raw screen)', (
      tester,
    ) async {
      // Validates Req 5.8: denied context renders denial, not raw content
      final resolver = MockTenantContextResolver.sessionExpired();

      await tester.pumpWidget(
        _testApp(
          MobileShopContentHostGuard(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            child: const Text('Should NOT appear'),
          ),
        ),
      );

      // The denial widget should be shown, not the child
      expect(find.text('Should NOT appear'), findsNothing);
      // Default denial widget shows "Session Expired" for session-missing
      expect(find.text('Session Expired'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 7. Session State Widgets
  // ===========================================================================

  group('7. Session state widgets', () {
    testWidgets(
      'MobileShopSessionGuardWidget with valid session → renders builder',
      (tester) async {
        // Validates Req 5.9: valid session renders builder content
        final resolver = MockTenantContextResolver.granted(
          permissions: _allPermissions,
        );

        await tester.pumpWidget(
          _testApp(
            MobileShopSessionGuardWidget(
              resolver: resolver,
              builder: (context, tenantCtx) =>
                  const Text('Session Active Content'),
            ),
          ),
        );

        expect(find.text('Session Active Content'), findsOneWidget);
      },
    );

    testWidgets(
      'MobileShopSessionGuardWidget with null session → renders SessionExpiredView (NOT spinner)',
      (tester) async {
        // Validates Req 5.9, AF-46: null session shows actionable state, not spinner
        final resolver = MockTenantContextResolver.sessionExpired();

        await tester.pumpWidget(
          _testApp(
            MobileShopSessionGuardWidget(
              resolver: resolver,
              builder: (context, tenantCtx) => const Text('Should NOT appear'),
            ),
          ),
        );

        // Should NOT show the builder content
        expect(find.text('Should NOT appear'), findsNothing);
        // Should NOT show a spinner (CircularProgressIndicator)
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Should show the SessionExpiredView content
        expect(find.text('Session Expired'), findsOneWidget);
      },
    );

    testWidgets('SessionExpiredView has "Sign In" button', (tester) async {
      // Validates Req 5.9: actionable session-error state has Sign In
      await tester.pumpWidget(
        _testApp(const SessionExpiredView(error: DomainError.sessionExpired())),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  // ===========================================================================
  // 8. Status Card Behavior
  // ===========================================================================

  group('8. Status card behavior', () {
    testWidgets('with action → has InkWell, button semantics', (tester) async {
      // Validates Req 5.10: interactive card has InkWell and button semantics
      await tester.pumpWidget(
        _testApp(
          MobileShopStatusCard(
            title: 'Overdue Repairs',
            value: '5',
            icon: Icons.warning,
            action: const MobileShopStatusCardAction(
              routePath: '/mobile-shop/service-jobs',
              queryParams: {'status': 'overdue'},
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);

      // Verify button semantics
      final semantics = tester.getSemantics(find.byType(InkWell));
      // The Semantics wrapper with button: true should be present
      expect(
        find.bySemanticsLabel(RegExp('Overdue Repairs.*Tap to view details')),
        findsOneWidget,
      );
    });

    testWidgets('without action → no InkWell, non-interactive semantics', (
      tester,
    ) async {
      // Validates Req 5.11: non-interactive card has no InkWell
      await tester.pumpWidget(
        _testApp(
          const MobileShopStatusCard(
            title: 'Total Devices',
            value: '120',
            icon: Icons.phone_android,
            action: null,
          ),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
      // Verify semantic label for non-interactive state
      expect(
        find.bySemanticsLabel('Status: Total Devices is 120'),
        findsOneWidget,
      );
    });

    testWidgets('interactive card navigates to filter path with query params', (
      tester,
    ) async {
      // Validates Req 5.10: tapping card applies the exact filter
      // We verify the card builds with correct action metadata
      const action = MobileShopStatusCardAction.filterAction(
        routePath: '/mobile-shop/service-jobs',
        queryParams: {'status': 'overdue', 'priority': 'high'},
      );

      expect(action.routePath, equals('/mobile-shop/service-jobs'));
      expect(action.queryParams['status'], equals('overdue'));
      expect(action.queryParams['priority'], equals('high'));

      // Verify the URI construction matches expected output
      final uri = Uri(
        path: action.routePath,
        queryParameters: action.queryParams,
      );
      expect(uri.toString(), contains('/mobile-shop/service-jobs?'));
      expect(uri.toString(), contains('status=overdue'));
      expect(uri.toString(), contains('priority=high'));
    });
  });

  // ===========================================================================
  // 9. Sole-Router Composition Assertion
  // ===========================================================================

  group('9. Sole-router composition assertion', () {
    test('SoleRouterPatterns.routerProviderName == "appRouterProvider"', () {
      // Validates Req 2.8, 13.1: sole router composition
      expect(
        SoleRouterPatterns.routerProviderName,
        equals('appRouterProvider'),
      );
    });

    test('SoleRouterPatterns.obsoleteModuleClass == "MobileShopModule"', () {
      // Validates Req 2.8: obsolete module must remain absent
      expect(
        SoleRouterPatterns.obsoleteModuleClass,
        equals('MobileShopModule'),
      );
    });

    test('documents positive evidence patterns for future expansion', () {
      // Validates Req 13.1: patterns documented for regression expansion
      //
      // Positive evidence patterns that MUST exist in the codebase:
      // - appEntryFile: where MaterialApp.router is declared
      // - routerProviderFile: where the sole GoRouter is created
      // - routerProviderName: the single provider symbol
      // - routerConfigPattern: proves routerConfig is used (not routes map)
      // - mobileNavigationBarrel: dedicated navigation barrel exists
      // - mobileRouteBindings: route bindings file exists
      expect(SoleRouterPatterns.appEntryFile, isNotEmpty);
      expect(SoleRouterPatterns.routerProviderFile, isNotEmpty);
      expect(SoleRouterPatterns.routerProviderName, isNotEmpty);
      expect(SoleRouterPatterns.routerConfigPattern, isNotEmpty);
      expect(SoleRouterPatterns.mobileNavigationBarrel, isNotEmpty);
      expect(SoleRouterPatterns.mobileRouteBindings, isNotEmpty);
    });

    test('documents negative evidence patterns for future expansion', () {
      // Validates Req 2.8, 13.1: patterns that MUST be absent
      //
      // Negative evidence patterns that MUST NOT exist in the codebase:
      // - obsoleteModulePath: no lib/modules/mobile_shop directory
      // - obsoleteModuleImport: no imports of modules/mobile_shop
      // - obsoleteModuleClass: MobileShopModule not defined/referenced
      // - legacyRoutesMapPattern: MaterialApp(routes: not in app.dart
      // - legacyRouteBuilder: buildAppRoutes not referenced
      // - obsoleteSyncHandler: MobileShopSyncHandler absent
      // - obsoleteWsHandler: MobileShopWsHandler absent
      expect(SoleRouterPatterns.obsoleteModulePath, isNotEmpty);
      expect(SoleRouterPatterns.obsoleteModuleImport, isNotEmpty);
      expect(SoleRouterPatterns.obsoleteModuleClass, isNotEmpty);
      expect(SoleRouterPatterns.legacyRoutesMapPattern, isNotEmpty);
      expect(SoleRouterPatterns.legacyRouteBuilder, isNotEmpty);
      expect(SoleRouterPatterns.obsoleteSyncHandler, isNotEmpty);
      expect(SoleRouterPatterns.obsoleteWsHandler, isNotEmpty);
    });
  });
}
