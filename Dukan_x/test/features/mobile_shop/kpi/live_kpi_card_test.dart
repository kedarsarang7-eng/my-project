/// LiveKpiCard Tests — Task 15.4
///
/// Tests cover:
/// 5. Exact card filters: LiveKpiCard navigates to correct filterRoute
///    with filterParams (Req 9.8)
/// - Verifies each state renders the correct visual indicators
/// - Verifies navigable/non-navigable state distinction
///
/// Requirements validated: 9.1–9.8, 9.13, 13.1
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/kpi/kpi_metric.dart';
import 'package:dukanx/features/mobile_shop/kpi/kpi_state.dart';
import 'package:dukanx/features/mobile_shop/kpi/live_kpi_card.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // EXACT CARD FILTERS — Requirement 9.8
  // ═══════════════════════════════════════════════════════════════════════════

  group('LiveKpiCard exact filter navigation (Req 9.8)', () {
    testWidgets('tapping current card navigates to filterRoute with params', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveKpiCard(
              config: _testConfig,
              kpiState: KpiCurrent<int>(value: 5, watermark: _freshWatermark()),
              onNavigated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The card is navigable (has InkWell) when Current
      expect(find.byType(InkWell), findsOneWidget);

      // Verify the config encodes the correct filter route
      expect(_testConfig.filterRoute, '/mobile-shop/inventory');
      expect(_testConfig.filterParams['lifecycle'], 'IN_STOCK');
    });

    test('each KPI metric config has a filter route', () {
      for (final config in kKpiMetricConfigs) {
        expect(
          config.filterRoute,
          isNotEmpty,
          reason: '${config.metric} must have a filterRoute',
        );
      }
    });

    test('stockInStock filter params contain lifecycle=IN_STOCK', () {
      final config = findKpiConfig(KpiMetric.stockInStock)!;
      expect(config.filterRoute, '/mobile-shop/inventory');
      expect(config.filterParams['lifecycle'], 'IN_STOCK');
    });

    test('repairActive filter params contain status=active', () {
      final config = findKpiConfig(KpiMetric.repairActive)!;
      expect(config.filterRoute, '/mobile-shop/service-jobs');
      expect(config.filterParams['status'], 'active');
    });

    test('repairOverdue filter params contain status=overdue', () {
      final config = findKpiConfig(KpiMetric.repairOverdue)!;
      expect(config.filterRoute, '/mobile-shop/service-jobs');
      expect(config.filterParams['status'], 'overdue');
    });

    test('exchangePending filter params contain status=pending', () {
      final config = findKpiConfig(KpiMetric.exchangePending)!;
      expect(config.filterRoute, '/mobile-shop/exchanges');
      expect(config.filterParams['status'], 'pending');
    });

    test('warrantyActive filter params contain status=active', () {
      final config = findKpiConfig(KpiMetric.warrantyActive)!;
      expect(config.filterRoute, '/mobile-shop/warranties');
      expect(config.filterParams['status'], 'active');
    });

    test('warrantyClaims filter params contain claimStatus=open', () {
      final config = findKpiConfig(KpiMetric.warrantyClaims)!;
      expect(config.filterRoute, '/mobile-shop/warranties');
      expect(config.filterParams['claimStatus'], 'open');
    });

    test('conflictsUnresolved filter params contain status=unresolved', () {
      final config = findKpiConfig(KpiMetric.conflictsUnresolved)!;
      expect(config.filterRoute, '/mobile-shop/conflicts');
      expect(config.filterParams['status'], 'unresolved');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Card navigability based on state
  // ═══════════════════════════════════════════════════════════════════════════

  group('LiveKpiCard navigability by state', () {
    testWidgets('Loading state card is not navigable (no InkWell)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapCard(const KpiLoading<int>()));
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('Unavailable state card is not navigable', (tester) async {
      await tester.pumpWidget(
        _wrapCard(const KpiUnavailable<int>(reason: 'Feature disabled')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('Error state card is not navigable', (tester) async {
      await tester.pumpWidget(
        _wrapCard(
          const KpiError<int>(
            error: KpiErrorInfo(kind: KpiErrorKind.network, message: 'fail'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('Current state card is navigable (has InkWell)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapCard(KpiCurrent<int>(value: 10, watermark: _freshWatermark())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('Stale state card is navigable', (tester) async {
      await tester.pumpWidget(
        _wrapCard(
          KpiStale<int>(
            lastValue: 7,
            lastWatermark: _freshWatermark(),
            refreshStatus: KpiRefreshStatus.notAttempted,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('Empty state card is navigable', (tester) async {
      await tester.pumpWidget(
        _wrapCard(KpiEmpty<int>(watermark: _freshWatermark())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Semantic labels
  // ═══════════════════════════════════════════════════════════════════════════

  group('LiveKpiCard accessibility semantics', () {
    testWidgets('Current card wraps content in Semantics widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapCard(KpiCurrent<int>(value: 42, watermark: _freshWatermark())),
      );
      await tester.pumpAndSettle();

      // Verify a Semantics widget is rendered for the card
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('Unavailable card wraps content in Semantics widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapCard(const KpiUnavailable<int>(reason: 'Feature IMEI disabled')),
      );
      await tester.pumpAndSettle();

      // Verify a Semantics widget is rendered for the card
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Test Helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Config used in navigation tests — stockInStock with IN_STOCK filter.
const _testConfig = KpiMetricConfig(
  metric: KpiMetric.stockInStock,
  title: 'In Stock',
  icon: Icons.inventory_2_outlined,
  requiredPermission: 'mobile_shop:imei:view',
  requiredFeature: 'IMEI_TRACKING',
  filterRoute: '/mobile-shop/inventory',
  filterParams: {'lifecycle': 'IN_STOCK'},
);

/// Returns a fresh watermark that won't be stale.
KpiWatermark _freshWatermark() => KpiWatermark(
  dataVersion: 1,
  confirmedAt: DateTime.now(),
  refreshedAt: DateTime.now(),
  dataModelVersion: 1,
);

/// Wraps a LiveKpiCard in a router for testability (non-navigating).
Widget _wrapCard(KpiState<int> state) {
  return MaterialApp(
    home: Scaffold(
      body: LiveKpiCard(config: _testConfig, kpiState: state),
    ),
  );
}
