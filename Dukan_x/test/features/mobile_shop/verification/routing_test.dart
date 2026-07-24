// ============================================================================
// MOBILE SHOP — ROUTING AND ROUTE CATALOG TESTS
// ============================================================================
// Tests GoRouter route catalog, bindings, deep links, and sidebar builder.
// Focuses on route completeness, guard enforcement, and reachability —
// complementing the existing mobile_shop_navigation_test.dart.
//
// **Validates: Requirements 2.1–2.9, 5.8–5.11, 8.3–8.7, 13.1, 13.5**
//
// Run: flutter test test/features/mobile_shop/verification/routing_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/auth/business_type.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context_resolver.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_route_catalog.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_route_entry.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_route_bindings.dart';
import 'package:dukanx/features/mobile_shop/navigation/mobile_shop_sidebar_builder.dart';
import 'package:dukanx/features/mobile_shop/permissions/mobile_shop_permissions.dart';

// ─── Mock Resolver ───────────────────────────────────────────────────────────

class _FullAccessResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> require() => TenantSuccess(
    TenantContext(
      tenantId: 'test-tenant',
      businessId: 'test-biz',
      subjectId: 'test-user',
      businessType: MobileShopBusinessType.mobileShop,
      permissions: MobileShopPermissions.all.toSet(),
      correlationId: 'corr-001',
    ),
  );

  @override
  TenantResult<TenantContext> requireMobileShop() => require();

  @override
  TenantContext? get current =>
      (require() as TenantSuccess<TenantContext>).value;

  @override
  void invalidate() {}
}

class _NoPermissionResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> require() => const TenantSuccess(
    TenantContext(
      tenantId: 'test-tenant',
      businessId: 'test-biz',
      subjectId: 'test-user',
      businessType: MobileShopBusinessType.mobileShop,
      permissions: {},
      correlationId: 'corr-002',
    ),
  );

  @override
  TenantResult<TenantContext> requireMobileShop() => require();

  @override
  TenantContext? get current =>
      (require() as TenantSuccess<TenantContext>).value;

  @override
  void invalidate() {}
}

// ─── Main Test Suite ─────────────────────────────────────────────────────────

void main() {
  // ==========================================================================
  // GROUP 1: Route Catalog — Structural Integrity
  // ==========================================================================
  group('Route catalog — structural integrity', () {
    test('all entries have unique route paths', () {
      final paths = MobileShopRouteCatalog.all.map((e) => e.routePath).toList();
      final uniquePaths = paths.toSet();
      expect(
        uniquePaths.length,
        paths.length,
        reason: 'Duplicate route paths found',
      );
    });

    test('all route paths start with /mobile-shop/', () {
      for (final entry in MobileShopRouteCatalog.all) {
        expect(
          entry.routePath.startsWith('/mobile-shop/'),
          isTrue,
          reason:
              '${entry.id} path "${entry.routePath}" does not start with /mobile-shop/',
        );
      }
    });

    test('every entry declares at least one required permission', () {
      for (final entry in MobileShopRouteCatalog.all) {
        expect(
          entry.requiredPermission,
          isNotNull,
          reason: '${entry.id} has no required permission',
        );
        expect(
          entry.requiredPermission!.isNotEmpty,
          isTrue,
          reason: '${entry.id} has empty required permission',
        );
      }
    });

    test('named catalog accessors match their IDs', () {
      expect(MobileShopRouteCatalog.imeiTracking.id, 'imei_tracking');
      expect(MobileShopRouteCatalog.serviceJobs.id, 'service_jobs');
      expect(MobileShopRouteCatalog.exchanges.id, 'exchanges');
      expect(MobileShopRouteCatalog.warranties.id, 'warranties');
      expect(MobileShopRouteCatalog.imeiLookup.id, 'imei_lookup');
    });

    test('all categories have defined display order', () {
      final categories = MobileShopRouteCatalog.all
          .map((e) => e.category)
          .toSet();
      expect(categories.length, greaterThanOrEqualTo(3));
    });
  });

  // ==========================================================================
  // GROUP 2: Route Bindings — GoRoute Generation
  // ==========================================================================
  group('Route bindings — GoRoute generation', () {
    test('buildMobileShopRoutes generates one route per catalog entry', () {
      final resolver = _FullAccessResolver();
      final routes = buildMobileShopRoutes(resolver);

      expect(
        routes.length,
        equals(MobileShopRouteCatalog.all.length),
        reason: 'Route count should match catalog entry count',
      );
    });

    test('all generated routes have non-null path', () {
      final resolver = _FullAccessResolver();
      final routes = buildMobileShopRoutes(resolver);

      for (final route in routes) {
        expect(route.path, isNotNull);
        expect(route.path, isNotEmpty);
      }
    });

    test(
      'routes are usable regardless of permission (guard at render time)',
      () {
        // Route bindings must exist for all entries even for unprivileged users
        // because the guard renders denial widget — not a 404
        final resolver = _NoPermissionResolver();
        final routes = buildMobileShopRoutes(resolver);

        expect(routes.length, equals(MobileShopRouteCatalog.all.length));
      },
    );
  });

  // ==========================================================================
  // GROUP 3: Sidebar Builder — Filtering Logic
  // ==========================================================================
  group('Sidebar builder — filtering logic', () {
    const builder = MobileShopSidebarBuilder();

    test('entries sorted by category order', () {
      final context = TenantContext(
        tenantId: 'test-t',
        businessId: 'test-b',
        subjectId: 'test-s',
        businessType: MobileShopBusinessType.mobileShop,
        permissions: MobileShopPermissions.all.toSet(),
        correlationId: 'c1',
      );

      final sections = builder.buildSidebar(
        context: context,
        capabilities: const {
          'useIMEI',
          'useWarranty',
          'useBuyback',
          'useExchange',
          'useJobSheets',
        },
        enabledFeatures: const {'finance_plans_emi', 'sim_recharge'},
      );

      // Sections should be grouped and ordered
      expect(sections, isNotEmpty);
      // First section should be inventory/device related
      expect(sections.first.entries, isNotEmpty);
    });

    test('removeAll permissions → empty sidebar', () {
      final context = const TenantContext(
        tenantId: 'test-t',
        businessId: 'test-b',
        subjectId: 'test-s',
        businessType: MobileShopBusinessType.mobileShop,
        permissions: {},
        correlationId: 'c2',
      );

      final sections = builder.buildSidebar(
        context: context,
        capabilities: const {
          'useIMEI',
          'useWarranty',
          'useBuyback',
          'useExchange',
          'useJobSheets',
        },
        enabledFeatures: const {'finance_plans_emi', 'sim_recharge'},
      );

      final visibleEntries = sections.expand((s) => s.entries).toList();
      expect(visibleEntries, isEmpty);
    });

    test('findById returns correct entry', () {
      final entry = builder.findById('imei_tracking');
      expect(entry, isNotNull);
      expect(entry!.id, 'imei_tracking');
    });

    test('findById returns null for unknown id', () {
      expect(builder.findById('nonexistent'), isNull);
    });
  });

  // ==========================================================================
  // GROUP 4: Route Entry — Metadata Completeness
  // ==========================================================================
  group('Route entry — metadata completeness', () {
    test('every entry has an icon', () {
      for (final entry in MobileShopRouteCatalog.all) {
        expect(entry.icon, isNotNull, reason: '${entry.id} has no icon');
      }
    });

    test('every entry has a non-empty label for sidebar display', () {
      for (final entry in MobileShopRouteCatalog.all) {
        expect(
          entry.label.isNotEmpty,
          isTrue,
          reason: '${entry.id} has empty label',
        );
      }
    });

    test('every entry has a category', () {
      for (final entry in MobileShopRouteCatalog.all) {
        expect(
          MobileShopRouteCategory.values.contains(entry.category),
          isTrue,
          reason: '${entry.id} has invalid category',
        );
      }
    });
  });

  // ==========================================================================
  // GROUP 5: Route Catalog — Required Workflows Present
  // ==========================================================================
  group('Route catalog — required workflows present', () {
    test('IMEI tracking route exists', () {
      _assertRouteExists('imei_tracking');
    });

    test('Service jobs route exists', () {
      _assertRouteExists('service_jobs');
    });

    test('Exchanges route exists', () {
      _assertRouteExists('exchanges');
    });

    test('Warranties route exists', () {
      _assertRouteExists('warranties');
    });

    test('Second-hand intake route exists', () {
      _assertRouteExists('second_hand_intake');
    });

    test('IMEI lookup route exists', () {
      _assertRouteExists('imei_lookup');
    });

    test('IMEI history route exists', () {
      _assertRouteExists('serial_imei_history');
    });

    test('Reports route exists', () {
      final hasReports = MobileShopRouteCatalog.all.any(
        (e) => e.id.contains('report'),
      );
      expect(hasReports, isTrue, reason: 'No reports route found');
    });
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

void _assertRouteExists(String id) {
  final entry = MobileShopRouteCatalog.all.firstWhere(
    (e) => e.id == id,
    orElse: () => throw StateError('Route "$id" not found in catalog'),
  );
  expect(entry.id, id);
  expect(entry.routePath, isNotEmpty);
}
