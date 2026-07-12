// ============================================================================
// PRESERVATION TEST — Offline Drift Streams Unaffected by Tenant-Scope Fix
// Feature: restaurant-audit-fixes (Task 24.2)
// **Property 20: Preservation** — Offline Drift Streams Unaffected by
//   Tenant-Scope Fix for a Correctly-Scoped Tenant
// **Validates: Requirements 3.17**
// ============================================================================
//
// Preservation Goal:
//   For any non-'SYSTEM' tenant id and any sequence of offline table/order/menu
//   writes followed by reads, the Drift stream behavior must be identical to
//   pre-fix behavior. The P0 fix removed the 'SYSTEM' fallback, so all
//   restaurant queries now use the real tenant id — but for tenants that were
//   ALREADY correctly scoped (non-'SYSTEM'), nothing should change.
//
// Approach (structural source-code analysis + PBT):
//   1. Verify FoodOrderRepository queries scope by vendorId parameter.
//   2. Verify RestaurantTableRepository queries scope by vendorId parameter.
//   3. Verify FoodMenuRepository queries scope by vendorId parameter.
//   4. Verify Drift stream watchers accept and pass vendorId through.
//   5. PBT: for randomized non-'SYSTEM' vendorIds, the repository source
//      code's query patterns use `.equals(vendorId)` parameterization.
//
// Run on current code — expect PASS.
//
// Run: flutter test test/features/restaurant/offline_drift_stream_preservation_test.dart
// ============================================================================

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String orderRepo;
  late String tableRepo;
  late String menuRepo;

  setUpAll(() {
    final f1 = File(
      'lib/features/restaurant/data/repositories/food_order_repository.dart',
    );
    expect(
      f1.existsSync(),
      isTrue,
      reason: 'food_order_repository.dart must exist',
    );
    orderRepo = f1.readAsStringSync();

    final f2 = File(
      'lib/features/restaurant/data/repositories/restaurant_table_repository.dart',
    );
    expect(
      f2.existsSync(),
      isTrue,
      reason: 'restaurant_table_repository.dart must exist',
    );
    tableRepo = f2.readAsStringSync();

    final f3 = File(
      'lib/features/restaurant/data/repositories/food_menu_repository.dart',
    );
    expect(
      f3.existsSync(),
      isTrue,
      reason: 'food_menu_repository.dart must exist',
    );
    menuRepo = f3.readAsStringSync();
  });

  // ==========================================================================
  // Group 1: FoodOrderRepository scopes by vendorId
  // ==========================================================================
  group('FoodOrderRepo vendorId scoping', () {
    test('watchVendorOrders accepts vendorId param', () {
      expect(
        orderRepo.contains('watchVendorOrders(String vendorId)'),
        isTrue,
        reason: 'watchVendorOrders must accept vendorId as a parameter',
      );
      expect(
        orderRepo.contains('t.vendorId.equals(vendorId)'),
        isTrue,
        reason: 'must filter using t.vendorId.equals(vendorId)',
      );
    });

    test('watchPendingOrders accepts vendorId param', () {
      expect(
        orderRepo.contains('watchPendingOrders(String vendorId)'),
        isTrue,
        reason: 'watchPendingOrders must accept vendorId as a parameter',
      );
    });

    test('getVendorOrders uses vendorId param', () {
      expect(orderRepo.contains('getVendorOrders'), isTrue);
      expect(
        orderRepo.contains('t.vendorId.equals(vendorId)'),
        isTrue,
        reason: 'getVendorOrders must scope by vendorId parameter',
      );
    });

    test('createOrder writes with vendorId param', () {
      expect(
        orderRepo.contains('vendorId: vendorId'),
        isTrue,
        reason: 'createOrder must write using the passed vendorId',
      );
    });

    test('no SYSTEM literal in order repository', () {
      expect(
        RegExp(r"'SYSTEM'").hasMatch(orderRepo),
        isFalse,
        reason: 'food_order_repository.dart must NOT contain SYSTEM literal',
      );
    });
  });

  // ==========================================================================
  // Group 2: RestaurantTableRepository scopes by vendorId
  // ==========================================================================
  group('TableRepo vendorId scoping', () {
    test('watchTables accepts vendorId param', () {
      expect(
        tableRepo.contains('watchTables(String vendorId)'),
        isTrue,
        reason: 'watchTables must accept vendorId as a parameter',
      );
      expect(
        tableRepo.contains('t.vendorId.equals(vendorId)'),
        isTrue,
        reason: 'must filter using t.vendorId.equals(vendorId)',
      );
    });

    test('getTablesByVendor uses vendorId param', () {
      expect(tableRepo.contains('getTablesByVendor'), isTrue);
      expect(
        tableRepo.contains('t.vendorId.equals(vendorId)'),
        isTrue,
        reason: 'getTablesByVendor must scope by vendorId',
      );
    });

    test('createTable writes with vendorId param', () {
      expect(
        tableRepo.contains('vendorId: vendorId'),
        isTrue,
        reason: 'createTable must write using the passed vendorId',
      );
    });

    test('no SYSTEM literal in table repository', () {
      expect(
        RegExp(r"'SYSTEM'").hasMatch(tableRepo),
        isFalse,
        reason:
            'restaurant_table_repository.dart must NOT contain SYSTEM literal',
      );
    });
  });

  // ==========================================================================
  // Group 3: FoodMenuRepository scopes by vendorId
  // ==========================================================================
  group('MenuRepo vendorId scoping', () {
    test('watchMenuItems accepts vendorId param', () {
      expect(
        menuRepo.contains('watchMenuItems(String vendorId)'),
        isTrue,
        reason: 'watchMenuItems must accept vendorId as a parameter',
      );
      expect(
        menuRepo.contains('t.vendorId.equals(vendorId)'),
        isTrue,
        reason: 'must filter using t.vendorId.equals(vendorId)',
      );
    });

    test('watchCategories accepts vendorId param', () {
      expect(
        menuRepo.contains('watchCategories(String vendorId)'),
        isTrue,
        reason: 'watchCategories must accept vendorId as a parameter',
      );
    });

    test('createMenuItem writes with vendorId param', () {
      expect(
        menuRepo.contains('vendorId: vendorId'),
        isTrue,
        reason: 'createMenuItem must write using the passed vendorId',
      );
    });

    test('no SYSTEM literal in menu repository', () {
      expect(
        RegExp(r"'SYSTEM'").hasMatch(menuRepo),
        isFalse,
        reason: 'food_menu_repository.dart must NOT contain SYSTEM literal',
      );
    });
  });

  // ==========================================================================
  // Group 4: PBT — parameterized vendorId for any non-SYSTEM tenant
  // **Validates: Requirements 3.17**
  // ==========================================================================
  group('PBT: Drift streams parameterized (Req 3.17)', () {
    test('PBT: queries use .equals(vendorId), no hardcoded tenant', () {
      final held = forAll(
        (int seed1, int seed2) {
          final vendorId = _genVendorId(seed1, seed2);
          if (vendorId == 'SYSTEM') return false;

          // All repos use parameterized vendorId queries
          if (!orderRepo.contains('t.vendorId.equals(vendorId)')) return false;
          if (!tableRepo.contains('t.vendorId.equals(vendorId)')) return false;
          if (!menuRepo.contains('t.vendorId.equals(vendorId)')) return false;

          // No repo hardcodes THIS vendorId as a literal
          final hardcoded = "'$vendorId'";
          if (orderRepo.contains(hardcoded)) return false;
          if (tableRepo.contains(hardcoded)) return false;
          if (menuRepo.contains(hardcoded)) return false;

          // No SYSTEM literal in any repository
          if (orderRepo.contains("'SYSTEM'")) return false;
          if (tableRepo.contains("'SYSTEM'")) return false;
          if (menuRepo.contains("'SYSTEM'")) return false;

          return true;
        },
        [Gen.interval(0, 1000000), Gen.interval(0, 1000000)],
        numRuns: 200,
      );

      expect(
        held,
        isTrue,
        reason:
            'Property 20 (Req 3.17): For any non-SYSTEM vendorId, all repos '
            'use parameterized queries with no hardcoded tenant literal.',
      );
    });

    test('PBT: stream signatures accept String vendorId', () {
      final held = forAll(
        (int seed) {
          final vendorId = _genRealisticId(seed);
          if (vendorId.isEmpty || vendorId == 'SYSTEM') return false;

          // Stream methods exist with String vendorId signatures
          final sigs = [
            'watchVendorOrders(String vendorId)',
            'watchPendingOrders(String vendorId)',
            'watchTables(String vendorId)',
            'watchMenuItems(String vendorId)',
            'watchCategories(String vendorId)',
          ];

          for (final sig in sigs) {
            final src = sig.contains('Order')
                ? orderRepo
                : sig.contains('Table')
                ? tableRepo
                : menuRepo;
            if (!src.contains(sig)) return false;
          }

          // Write methods require vendorId
          if (!orderRepo.contains('required String vendorId')) return false;
          if (!tableRepo.contains('required String vendorId')) return false;
          if (!menuRepo.contains('required String vendorId')) return false;

          return true;
        },
        [Gen.interval(0, 1000000)],
        numRuns: 200,
      );

      expect(
        held,
        isTrue,
        reason:
            'Property 20 (Req 3.17): All Drift stream watchers accept '
            'String vendorId as parameter with no default.',
      );
    });

    test('PBT: sync ops filter by vendorId & isSynced', () {
      final held = forAll(
        (int seed) {
          final vendorId = _genVendorId(seed, seed * 3 + 7);
          if (vendorId == 'SYSTEM') return false;

          // Sync methods in FoodOrderRepository
          if (!orderRepo.contains('getUnsyncedOrders(String vendorId)')) {
            return false;
          }
          if (!orderRepo.contains(
            't.vendorId.equals(vendorId) & t.isSynced.equals(false)',
          )) {
            return false;
          }

          // Sync methods in RestaurantTableRepository
          if (!tableRepo.contains('getUnsyncedTables(String vendorId)')) {
            return false;
          }
          if (!tableRepo.contains(
            't.vendorId.equals(vendorId) & t.isSynced.equals(false)',
          )) {
            return false;
          }

          // Sync methods in FoodMenuRepository
          if (!menuRepo.contains('getUnsyncedItems(String vendorId)')) {
            return false;
          }
          if (!menuRepo.contains(
            't.vendorId.equals(vendorId) & t.isSynced.equals(false)',
          )) {
            return false;
          }

          return true;
        },
        [Gen.interval(0, 1000000)],
        numRuns: 200,
      );

      expect(
        held,
        isTrue,
        reason:
            'Property 20 (Req 3.17): Offline sync operations filter by '
            'parameterized vendorId AND isSynced == false.',
      );
    });
  });
}

// ============================================================================
// HELPERS
// ============================================================================

String _genVendorId(int seed1, int seed2) {
  final patterns = [
    'biz_${seed1.abs().toRadixString(16)}',
    'vendor_${seed2.abs()}',
    'restaurant_${(seed1.abs() % 9999) + 1}',
    'usr_${seed1.abs().toRadixString(36)}_${seed2.abs().toRadixString(36)}',
    '${seed1.abs().toRadixString(16).padLeft(8, "0")}-${seed2.abs().toRadixString(16).padLeft(4, "0")}',
    'tenant_${seed1.abs() % 10000}',
    'shop_${seed2.abs() % 5000}_owner',
  ];
  return patterns[(seed1.abs() + seed2.abs()) % patterns.length];
}

String _genRealisticId(int seed) {
  final patterns = [
    'currentBiz_${seed.abs() % 99999}',
    'firebase_uid_${seed.abs().toRadixString(36)}',
    'biz_${seed.abs().toRadixString(16).padLeft(12, "0")}',
    'owner_${seed.abs() % 5000}',
    'resto_${seed.abs() % 100}_branch_${seed.abs() % 20}',
  ];
  return patterns[seed.abs() % patterns.length];
}
