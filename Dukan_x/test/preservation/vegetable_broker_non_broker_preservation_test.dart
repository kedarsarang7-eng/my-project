/// Preservation Property Test — Non-VegetablesBroker Business Types Unaffected
///
/// **Validates: Requirements 3.1, 3.3**
///
/// Property 3: Preservation — Non-VegetablesBroker Capability Registry &
/// Plan Mapping Unaffected
///
/// This test follows the OBSERVATION-FIRST methodology:
///   FOR ALL X WHERE X.businessType != BusinessType.vegetablesBroker
///   DO ASSERT F(X) == F'(X) END FOR
///
/// On UNFIXED code (F) every observation is recorded as a golden and the test
/// PASSES — that recording IS the expected outcome (baseline capture). When
/// re-run after the vegetablesBroker fixes (F'), the live observation is
/// compared to the recorded baseline, confirming `F'(X) == F(X)` for every
/// non-vegetablesBroker vertical.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/vegetable_broker_non_broker_preservation_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/subscription/plan_mapping_builder.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

// ---------------------------------------------------------------------------
// The input domain: every business type EXCEPT vegetablesBroker.
// These are the inputs where the vegetablesBroker bugfix conditions do NOT hold.
// ---------------------------------------------------------------------------
final List<BusinessType> _nonBrokerTypes = BusinessType.values
    .where((t) => t != BusinessType.vegetablesBroker)
    .toList(growable: false);

// ---------------------------------------------------------------------------
// Golden helpers — record-on-first-run, compare-on-subsequent-runs.
// ---------------------------------------------------------------------------
const JsonEncoder _enc = JsonEncoder.withIndent('  ');

File _goldenFile(String name) => File(
  'test/preservation/__goldens__/vegetable_broker_non_broker/$name.json',
);

void _expectGolden(String name, Object observation) {
  final f = _goldenFile(name);
  final live = _enc.convert(observation);
  if (!f.existsSync()) {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(live);
    return; // baseline recorded — EXPECTED OUTCOME on unfixed code
  }
  final golden = _enc.convert(jsonDecode(f.readAsStringSync()));
  expect(
    live,
    golden,
    reason:
        'Preservation regression: "$name" changed between F and F\'. A '
        'vegetablesBroker-only fix must not alter any non-broker vertical\'s '
        'capability registry or plan mapping. Restore the original behaviour, '
        'or update the golden only if this change is an intended, documented '
        'part of the fix.',
  );
}

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
// Helpers.
// ---------------------------------------------------------------------------

/// The sorted capability-name set a business type is granted today.
List<String> _capabilityNames(BusinessType type) {
  final names = FeatureResolver.getCapabilities(
    type.name,
  ).map((c) => c.name).toList()..sort();
  return names;
}

/// Serializes a PlanMapping's per-tier capability sets as a sorted JSON-friendly
/// structure: { "basic": [...], "pro": [...], "premium": [...], "enterprise": [...] }
Map<String, List<String>> _serializePlanMapping(String businessType) {
  final builder = PlanMappingBuilder();
  final mapping = builder.buildFor(businessType);
  final result = <String, List<String>>{};
  for (final tier in SubscriptionTier.values) {
    final caps = mapping.capabilitiesAt(tier).map((c) => c.name).toList()
      ..sort();
    result[tier.name] = caps;
  }
  return result;
}

void main() {
  late final Map<String, dynamic> capabilityBaseline;
  late final Map<String, dynamic> planMappingBaseline;

  setUpAll(() {
    // Record capability registry baseline
    final capLive = <String, dynamic>{
      for (final t in _nonBrokerTypes) t.name: _capabilityNames(t),
    };
    capabilityBaseline = _readOrWriteGoldenMap('capabilities', capLive);

    // Record plan mapping baseline
    final planLive = <String, dynamic>{
      for (final t in _nonBrokerTypes) t.name: _serializePlanMapping(t.name),
    };
    planMappingBaseline = _readOrWriteGoldenMap('plan_mappings', planLive);
  });

  // =========================================================================
  // PRESERVATION 3.1 — Non-vegetablesBroker capability sets unchanged
  //
  // The vegetablesBroker fix edits ONLY the vegetablesBroker capability
  // registry entry (removing useCrateManagement). No other type's grant/deny
  // set may change.
  // =========================================================================
  group('Preservation 3.1 — non-broker capability sets', () {
    test('every non-broker capability set matches the recorded baseline', () {
      for (final type in _nonBrokerTypes) {
        expect(
          _capabilityNames(type),
          (capabilityBaseline[type.name] as List).cast<String>(),
          reason:
              '${type.name} capability set changed. The vegetablesBroker fix '
              'must not leak into any other vertical\'s registry entry.',
        );
      }
    });

    test('PBT: for all non-broker types the capability set is preserved', () {
      forAll(
        (int idx) {
          final type = _nonBrokerTypes[idx % _nonBrokerTypes.length];
          final live = _capabilityNames(type);
          final expected = (capabilityBaseline[type.name] as List)
              .cast<String>();
          expect(
            live,
            expected,
            reason:
                'Capability preservation violated for ${type.name}: the '
                'vegetablesBroker fix leaked a change into a non-broker '
                'vertical.',
          );
          return true;
        },
        [Gen.interval(0, _nonBrokerTypes.length - 1)],
        numRuns: 100,
      );
    });
  });

  // =========================================================================
  // PRESERVATION 3.3 — Non-vegetablesBroker plan mappings unchanged
  //
  // The vegetablesBroker fix removes useCrateManagement from the broker/mandi
  // plan mapping block. No other type's plan mapping may change.
  // =========================================================================
  group('Preservation 3.3 — non-broker plan mappings', () {
    test('every non-broker plan mapping matches the recorded baseline', () {
      for (final type in _nonBrokerTypes) {
        final live = _serializePlanMapping(type.name);
        final expected = (planMappingBaseline[type.name] as Map)
            .cast<String, dynamic>();
        for (final tier in SubscriptionTier.values) {
          expect(
            live[tier.name],
            (expected[tier.name] as List).cast<String>(),
            reason:
                '${type.name} plan mapping at ${tier.name} tier changed. '
                'The vegetablesBroker fix must not alter any other vertical\'s '
                'plan mapping.',
          );
        }
      }
    });

    test('PBT: for all non-broker types the plan mapping is preserved', () {
      forAll(
        (int idx) {
          final type = _nonBrokerTypes[idx % _nonBrokerTypes.length];
          final live = _serializePlanMapping(type.name);
          final expected = (planMappingBaseline[type.name] as Map)
              .cast<String, dynamic>();
          for (final tier in SubscriptionTier.values) {
            expect(
              live[tier.name],
              (expected[tier.name] as List).cast<String>(),
              reason:
                  'Plan mapping preservation violated for ${type.name} at '
                  '${tier.name}: the vegetablesBroker fix leaked a change.',
            );
          }
          return true;
        },
        [Gen.interval(0, _nonBrokerTypes.length - 1)],
        numRuns: 100,
      );
    });
  });

  // =========================================================================
  // PBT — Universal preservation property: capabilities + plan mapping
  //
  // Generates arbitrary non-broker BusinessType values and asserts BOTH the
  // capability registry entry AND plan mapping are byte-for-byte identical to
  // the recorded baselines. This is the single combined property that
  // covers Requirements 3.1 and 3.3 together.
  // =========================================================================
  group('PBT — universal non-broker preservation (caps + plan mapping)', () {
    test('for all non-broker types: capabilities and plan mapping are '
        'preserved', () {
      forAll(
        (int idx) {
          final type = _nonBrokerTypes[idx % _nonBrokerTypes.length];

          // 1. Capability registry preservation
          final liveCaps = _capabilityNames(type);
          final expectedCaps = (capabilityBaseline[type.name] as List)
              .cast<String>();
          expect(
            liveCaps,
            expectedCaps,
            reason: '${type.name} capabilities changed after broker fix',
          );

          // 2. Plan mapping preservation
          final liveMapping = _serializePlanMapping(type.name);
          final expectedMapping = (planMappingBaseline[type.name] as Map)
              .cast<String, dynamic>();
          for (final tier in SubscriptionTier.values) {
            expect(
              liveMapping[tier.name],
              (expectedMapping[tier.name] as List).cast<String>(),
              reason:
                  '${type.name} plan mapping at ${tier.name} changed after '
                  'broker fix',
            );
          }

          return true;
        },
        [Gen.interval(0, _nonBrokerTypes.length - 1)],
        numRuns: 100,
      );
    });
  });
}
