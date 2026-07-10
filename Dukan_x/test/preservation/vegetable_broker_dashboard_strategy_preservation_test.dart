/// Preservation Property Test — Live Dashboard Strategy (`_MandiStrategy`)
/// Unaffected
///
/// **Validates: Requirements 3.4, 3.5**
///
/// Property 3: Preservation — `dashboard_strategies.dart`'s `_MandiStrategy`
/// and Sibling Strategies Unaffected
///
/// This test follows the OBSERVATION-FIRST methodology:
///   FOR ALL X WHERE X is any BusinessType value
///   DO ASSERT DashboardStrategyFactory.getStrategy(X).quickActions == baseline
///      AND   DashboardStrategyFactory.getStrategy(X).widgets == baseline
///   END FOR
///
/// On UNFIXED code every observation is recorded as a golden and the test
/// PASSES — that recording IS the expected outcome (baseline capture). When
/// re-run after the `dashboard_strategy_factory.dart`/`concrete_strategies.dart`
/// deletion (the fix), the live observation is compared to the recorded
/// baseline, confirming the live strategy factory is byte-for-byte unchanged
/// for every business type.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/vegetable_broker_dashboard_strategy_preservation_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
// Import the LIVE DashboardStrategyFactory from dashboard_strategies.dart —
// NOT from the dead dashboard_strategy_factory.dart that will be deleted.
import 'package:dukanx/features/dashboard/logic/dashboard_strategies.dart';

// ---------------------------------------------------------------------------
// Golden helpers — record-on-first-run, compare-on-subsequent-runs.
// ---------------------------------------------------------------------------
const JsonEncoder _enc = JsonEncoder.withIndent('  ');

File _goldenFile(String name) => File(
  'test/preservation/__goldens__/vegetable_broker_dashboard_strategy/$name.json',
);

Map<String, dynamic> _readOrWriteGoldenMap(
  String name,
  Map<String, dynamic> live,
) {
  final f = _goldenFile(name);
  if (!f.existsSync()) {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(_enc.convert(live));
    return live;
  }
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
}

// ---------------------------------------------------------------------------
// Serialization helpers — capture strategy resolution as JSON-friendly data.
// ---------------------------------------------------------------------------

/// Serializes a DashboardQuickAction to a deterministic map.
Map<String, dynamic> _serializeQuickAction(DashboardQuickAction action) => {
  'label': action.label,
  'icon': action.icon.codePoint,
  'route': action.route,
};

/// Serializes a DashboardWidgetType enum value to its name string.
String _serializeWidget(DashboardWidgetType widget) => widget.name;

/// Captures the full resolved strategy for a BusinessType as a JSON map.
Map<String, dynamic> _captureStrategy(BusinessType type) {
  final strategy = DashboardStrategyFactory.getStrategy(type);
  return {
    'addItemLabel': strategy.addItemLabel,
    'addItemIcon': strategy.addItemIcon.codePoint,
    'customerLabel': strategy.customerLabel,
    'customerIcon': strategy.customerIcon.codePoint,
    'supplierLabel': strategy.supplierLabel,
    'quickActions': strategy.quickActions.map(_serializeQuickAction).toList(),
    'widgets': strategy.widgets.map(_serializeWidget).toList(),
  };
}

void main() {
  late final Map<String, dynamic> strategyBaseline;

  setUpAll(() {
    // Record strategy resolution baseline for EVERY business type.
    final live = <String, dynamic>{
      for (final type in BusinessType.values) type.name: _captureStrategy(type),
    };
    strategyBaseline = _readOrWriteGoldenMap('dashboard_strategies', live);
  });

  // =========================================================================
  // PRESERVATION 3.4/3.5 — _MandiStrategy for vegetablesBroker is correct
  //
  // The live DashboardStrategyFactory in dashboard_strategies.dart resolves
  // vegetablesBroker → _MandiStrategy with non-empty quickActions and widgets.
  // This MUST remain unchanged after the dead dashboard_strategy_factory.dart
  // and concrete_strategies.dart are deleted.
  // =========================================================================
  group('Preservation 3.4/3.5 — _MandiStrategy for vegetablesBroker', () {
    test('vegetablesBroker resolves to a strategy with non-empty quickActions '
        'and widgets', () {
      final strategy = DashboardStrategyFactory.getStrategy(
        BusinessType.vegetablesBroker,
      );
      expect(
        strategy.quickActions,
        isNotEmpty,
        reason:
            '_MandiStrategy.quickActions must be non-empty — the live '
            'dashboard strategy for vegetablesBroker provides New Entry, '
            'Farmer Ledger, and Daily Rates quick actions.',
      );
      expect(
        strategy.widgets,
        isNotEmpty,
        reason:
            '_MandiStrategy.widgets must be non-empty — the live dashboard '
            'strategy for vegetablesBroker provides salesSummary and '
            'recentBills widgets.',
      );
    });

    test('vegetablesBroker quickActions are exactly New Entry / Farmer Ledger '
        '/ Daily Rates', () {
      final strategy = DashboardStrategyFactory.getStrategy(
        BusinessType.vegetablesBroker,
      );
      final labels = strategy.quickActions.map((a) => a.label).toList();
      expect(labels, ['New Entry', 'Farmer Ledger', 'Daily Rates']);
    });

    test('vegetablesBroker widgets are exactly salesSummary / recentBills', () {
      final strategy = DashboardStrategyFactory.getStrategy(
        BusinessType.vegetablesBroker,
      );
      final widgetNames = strategy.widgets.map((w) => w.name).toList();
      expect(widgetNames, ['salesSummary', 'recentBills']);
    });

    test('vegetablesBroker strategy resolution matches the recorded '
        'baseline', () {
      final live = _captureStrategy(BusinessType.vegetablesBroker);
      final expected = (strategyBaseline['vegetablesBroker'] as Map)
          .cast<String, dynamic>();
      expect(
        _enc.convert(live),
        _enc.convert(expected),
        reason:
            'vegetablesBroker dashboard strategy resolution changed. '
            'The deletion of dashboard_strategy_factory.dart and '
            'concrete_strategies.dart must NOT alter the live _MandiStrategy.',
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.4/3.5 — Every other business type's strategy is unchanged
  //
  // The deletion of the dead dashboard_strategy_factory.dart and
  // concrete_strategies.dart must not alter ANY business type's resolved
  // strategy through the live DashboardStrategyFactory in
  // dashboard_strategies.dart.
  // =========================================================================
  group('Preservation 3.4/3.5 — all business types strategy resolution '
      'unchanged', () {
    test('every business type strategy resolution matches the recorded '
        'baseline', () {
      for (final type in BusinessType.values) {
        final live = _captureStrategy(type);
        final expected = (strategyBaseline[type.name] as Map)
            .cast<String, dynamic>();
        expect(
          _enc.convert(live),
          _enc.convert(expected),
          reason:
              '${type.name} dashboard strategy resolution changed after the '
              'dead file deletion. The fix must not alter any business type\'s '
              'live dashboard strategy.',
        );
      }
    });

    test('PBT: for all business types the strategy resolution is '
        'preserved', () {
      forAll(
        (int idx) {
          final type = BusinessType.values[idx % BusinessType.values.length];
          final live = _captureStrategy(type);
          final expected = (strategyBaseline[type.name] as Map)
              .cast<String, dynamic>();
          expect(
            _enc.convert(live),
            _enc.convert(expected),
            reason:
                'Preservation violated for ${type.name}: dashboard strategy '
                'resolution changed after dead file deletion.',
          );
          return true;
        },
        [Gen.interval(0, BusinessType.values.length - 1)],
        numRuns: 200,
      );
    });
  });

  // =========================================================================
  // COMBINED PBT — Universal preservation: quickActions + widgets stability
  //
  // Generates arbitrary BusinessType values and asserts BOTH quickActions and
  // widgets are byte-for-byte identical to the recorded baseline. This is the
  // single combined property covering Requirements 3.4 and 3.5.
  // =========================================================================
  group('PBT — universal dashboard strategy preservation (all types)', () {
    test('for all business types: quickActions and widgets are '
        'preserved', () {
      forAll(
        (int idx) {
          final type = BusinessType.values[idx % BusinessType.values.length];
          final strategy = DashboardStrategyFactory.getStrategy(type);

          // 1. quickActions preservation
          final liveActions = strategy.quickActions
              .map(_serializeQuickAction)
              .toList();
          final expectedData = (strategyBaseline[type.name] as Map)
              .cast<String, dynamic>();
          final expectedActions = (expectedData['quickActions'] as List)
              .cast<Map<String, dynamic>>();
          expect(
            _enc.convert(liveActions),
            _enc.convert(expectedActions),
            reason:
                '${type.name} quickActions changed after dead file deletion.',
          );

          // 2. widgets preservation
          final liveWidgets = strategy.widgets.map(_serializeWidget).toList();
          final expectedWidgets = (expectedData['widgets'] as List)
              .cast<String>();
          expect(
            liveWidgets,
            expectedWidgets,
            reason: '${type.name} widgets changed after dead file deletion.',
          );

          return true;
        },
        [Gen.interval(0, BusinessType.values.length - 1)],
        numRuns: 200,
      );
    });
  });
}
