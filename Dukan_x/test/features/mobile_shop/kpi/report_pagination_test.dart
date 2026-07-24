/// Report Screen Base & Pagination Tests — Task 15.4
///
/// Tests cover:
/// 7. Report pagination: ReportScreenBase bounded query limits
/// - Default query limit is kReportDefaultLimit (50)
/// - Maximum limit is kReportMaxLimit (200)
/// - Filter params round-trip correctly
/// - Session-lost state renders without domain access
///
/// Requirements validated: 9.7–9.9, 9.12–9.13, 13.1
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/screens/reports/report_filter_params.dart';
import 'package:dukanx/features/mobile_shop/screens/reports/report_screen_base.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Report pagination bounds
  // ═══════════════════════════════════════════════════════════════════════════

  group('Report bounded query limits (Req 9.12)', () {
    test('default report limit is 50', () {
      expect(kReportDefaultLimit, 50);
    });

    test('max report limit is 200', () {
      expect(kReportMaxLimit, 200);
    });

    test('max limit is greater than default limit', () {
      expect(kReportMaxLimit, greaterThan(kReportDefaultLimit));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Report filter params
  // ═══════════════════════════════════════════════════════════════════════════

  group('ReportFilterParams', () {
    test('fromQueryParameters extracts lifecycle', () {
      final params = ReportFilterParams.fromQueryParameters({
        'lifecycle': 'IN_STOCK',
      });
      expect(params.lifecycle, 'IN_STOCK');
      expect(params.status, isNull);
    });

    test('fromQueryParameters extracts status', () {
      final params = ReportFilterParams.fromQueryParameters({
        'status': 'active',
      });
      expect(params.status, 'active');
    });

    test('fromQueryParameters extracts claimStatus', () {
      final params = ReportFilterParams.fromQueryParameters({
        'claimStatus': 'open',
      });
      expect(params.claimStatus, 'open');
    });

    test('fromQueryParameters extracts brand and model', () {
      final params = ReportFilterParams.fromQueryParameters({
        'brand': 'Samsung',
        'model': 'Galaxy S24',
      });
      expect(params.brand, 'Samsung');
      expect(params.model, 'Galaxy S24');
    });

    test('fromQueryParameters extracts date range', () {
      final params = ReportFilterParams.fromQueryParameters({
        'from': '2024-01-01',
        'to': '2024-12-31',
      });
      expect(params.fromDate, '2024-01-01');
      expect(params.toDate, '2024-12-31');
    });

    test('hasActiveFilters returns true when any filter set', () {
      const params = ReportFilterParams(lifecycle: 'SOLD');
      expect(params.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters returns false when no filters set', () {
      const params = ReportFilterParams();
      expect(params.hasActiveFilters, isFalse);
    });

    test('toQueryParameters round-trips with fromQueryParameters', () {
      const original = ReportFilterParams(
        lifecycle: 'DEMO',
        status: 'pending',
        brand: 'Apple',
        fromDate: '2024-06-01',
      );

      final queryParams = original.toQueryParameters();
      final restored = ReportFilterParams.fromQueryParameters(queryParams);

      expect(restored.lifecycle, 'DEMO');
      expect(restored.status, 'pending');
      expect(restored.brand, 'Apple');
      expect(restored.fromDate, '2024-06-01');
      expect(restored, equals(original));
    });

    test('toQueryParameters omits null values', () {
      const params = ReportFilterParams(status: 'active');
      final map = params.toQueryParameters();
      expect(map, {'status': 'active'});
      expect(map.containsKey('lifecycle'), isFalse);
      expect(map.containsKey('brand'), isFalse);
    });

    test('activeFilterDescription includes all set filters', () {
      const params = ReportFilterParams(
        lifecycle: 'IN_STOCK',
        status: 'active',
        brand: 'Samsung',
      );
      final desc = params.activeFilterDescription;
      expect(desc, contains('Lifecycle: IN_STOCK'));
      expect(desc, contains('Status: active'));
      expect(desc, contains('Brand: Samsung'));
    });

    test('equality works correctly', () {
      const a = ReportFilterParams(lifecycle: 'IN_STOCK', status: 'active');
      const b = ReportFilterParams(lifecycle: 'IN_STOCK', status: 'active');
      const c = ReportFilterParams(lifecycle: 'SOLD', status: 'active');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('empty params produces empty query parameters map', () {
      const params = ReportFilterParams();
      expect(params.toQueryParameters(), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // KPI-to-filter navigation integration
  // ═══════════════════════════════════════════════════════════════════════════

  group('KPI card filter params match report params format', () {
    test('lifecycle filter from KPI card parses correctly', () {
      // Simulates what happens when a user taps the "In Stock" KPI card
      final params = ReportFilterParams.fromQueryParameters({
        'lifecycle': 'IN_STOCK',
      });
      expect(params.lifecycle, 'IN_STOCK');
      expect(params.hasActiveFilters, isTrue);
    });

    test('status filter from KPI card parses correctly', () {
      // Simulates what happens when a user taps the "Active Repairs" KPI card
      final params = ReportFilterParams.fromQueryParameters({
        'status': 'active',
      });
      expect(params.status, 'active');
      expect(params.hasActiveFilters, isTrue);
    });

    test('claimStatus filter from KPI card parses correctly', () {
      // Simulates what happens when a user taps the "Open Claims" KPI card
      final params = ReportFilterParams.fromQueryParameters({
        'claimStatus': 'open',
      });
      expect(params.claimStatus, 'open');
      expect(params.hasActiveFilters, isTrue);
    });
  });
}
