// Feature: comprehensive-test-certification, Property 6
// ============================================================================
// Property 6: Subscription and license gating is accessible exactly when entitled.
//
// For any active subscription (including license-activation state) and any
// gated feature, the feature is accessible if and only if the active
// subscription's entitlement set contains that feature AND the subscription is
// active AND the license is activated; otherwise access is blocked with a
// denial indication.
//
// Test both directions:
//   1. When all conditions met → accessible
//   2. When any condition fails → blocked with non-null denial reason
//
// **Validates: Requirements 5.4**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_6_entitlement_gating_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import '../core/entitlement_checker.dart';
import 'generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// Pool of feature names to generate from (realistic gated features).
const List<String> _featurePool = [
  'billing',
  'inventory',
  'analytics',
  'reports',
  'multi_branch',
  'advanced_gst',
  'export_pdf',
  'bulk_import',
  'custom_fields',
  'crm',
  'staff_management',
  'api_access',
  'priority_support',
  'white_label',
  'data_backup',
];

/// Generates a random feature name from the feature pool.
final Generator<String> _featureGen = Gen.elementOf<String>(_featurePool);

/// Generates a random set of entitlements (subset of the feature pool).
final Generator<Set<String>> _entitlementSetGen = Gen.set<String>(
  Gen.elementOf<String>(_featurePool),
  minSize: 0,
  maxSize: _featurePool.length,
);

/// Generates a random subscription ID.
final Generator<String> _subscriptionIdGen = Gen.interval(
  1,
  9999,
).map((n) => 'SUB-${n.toString().padLeft(4, '0')}');

// ============================================================================
// TESTS
// ============================================================================

void main() {
  const checker = EntitlementChecker();

  group('Property 6: Entitlement gating — accessible exactly when entitled', () {
    // ========================================================================
    // Direction 1: When all conditions met → accessible
    // ========================================================================
    test('FORWARD: feature accessible when subscription is active, license '
        'activated, and feature in entitlements', () {
      final held = forAll(
        (String subId, Set<String> entitlements, int featureIdx) {
          // Ensure entitlements is non-empty so we can pick a feature from it
          if (entitlements.isEmpty) return true; // vacuously true, skip

          // Pick a feature that IS in the entitlement set
          final feature = entitlements.elementAt(
            featureIdx % entitlements.length,
          );

          final subscription = Subscription(
            id: subId,
            entitlements: entitlements,
            isActive: true,
            licenseActivated: true,
          );

          final decision = checker.check(subscription, feature);

          // Must be accessible
          return decision.result == AccessResult.accessible &&
              decision.denialReason == null;
        },
        [_subscriptionIdGen, _entitlementSetGen, Gen.interval(0, 999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 2: When subscription is inactive → blocked
    // ========================================================================
    test('REJECTION: feature blocked when subscription is NOT active', () {
      final held = forAll(
        (String subId, Set<String> entitlements, String feature) {
          final subscription = Subscription(
            id: subId,
            entitlements: entitlements,
            isActive: false, // inactive
            licenseActivated: true,
          );

          final decision = checker.check(subscription, feature);

          // Must be blocked with a non-null denial reason
          return decision.result == AccessResult.blocked &&
              decision.denialReason != null &&
              decision.denialReason!.isNotEmpty;
        },
        [_subscriptionIdGen, _entitlementSetGen, _featureGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 3: When license is NOT activated → blocked
    // ========================================================================
    test('REJECTION: feature blocked when license is NOT activated', () {
      final held = forAll(
        (String subId, Set<String> entitlements, String feature) {
          final subscription = Subscription(
            id: subId,
            entitlements: entitlements,
            isActive: true,
            licenseActivated: false, // not activated
          );

          final decision = checker.check(subscription, feature);

          // Must be blocked with a non-null denial reason
          return decision.result == AccessResult.blocked &&
              decision.denialReason != null &&
              decision.denialReason!.isNotEmpty;
        },
        [_subscriptionIdGen, _entitlementSetGen, _featureGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 4: When feature NOT in entitlements → blocked
    // ========================================================================
    test(
      'REJECTION: feature blocked when feature is NOT in entitlement set',
      () {
        final held = forAll(
          (String subId, Set<String> entitlements, String feature) {
            // Ensure the feature is NOT in the entitlement set
            final cleanedEntitlements = Set<String>.from(entitlements)
              ..remove(feature);

            final subscription = Subscription(
              id: subId,
              entitlements: cleanedEntitlements,
              isActive: true,
              licenseActivated: true,
            );

            final decision = checker.check(subscription, feature);

            // Must be blocked with a non-null denial reason
            return decision.result == AccessResult.blocked &&
                decision.denialReason != null &&
                decision.denialReason!.isNotEmpty;
          },
          [_subscriptionIdGen, _entitlementSetGen, _featureGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ========================================================================
    // Direction 5: Comprehensive bi-directional — accessible IFF all three
    // conditions are true (isActive AND licenseActivated AND feature in set)
    // ========================================================================
    test('BI-DIRECTIONAL: accessible iff isActive AND licenseActivated AND '
        'feature in entitlements; blocked otherwise with denial', () {
      final held = forAll(
        (
          String subId,
          Set<String> entitlements,
          String feature,
          bool isActive,
          bool licenseActivated,
        ) {
          final subscription = Subscription(
            id: subId,
            entitlements: entitlements,
            isActive: isActive,
            licenseActivated: licenseActivated,
          );

          final decision = checker.check(subscription, feature);

          final shouldBeAccessible =
              isActive && licenseActivated && entitlements.contains(feature);

          if (shouldBeAccessible) {
            // Must be accessible with null denial reason
            return decision.result == AccessResult.accessible &&
                decision.denialReason == null;
          } else {
            // Must be blocked with non-null denial reason
            return decision.result == AccessResult.blocked &&
                decision.denialReason != null &&
                decision.denialReason!.isNotEmpty;
          }
        },
        [
          _subscriptionIdGen,
          _entitlementSetGen,
          _featureGen,
          Gen.boolean(),
          Gen.boolean(),
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
