// ============================================================================
// Task 1.3 — SubscriptionTier enum shape
// Spec: subscription-plan-tiers (Requirement 1.1)
// ============================================================================
// Asserts the Tiering_System defines exactly four tiers in strict ascending
// order: basic < pro < premium < enterprise. Order is checked three ways —
// via the `<` / `<=` operators the enum exposes, and via the underlying
// `index` — so any reordering of the enum members fails loudly.
//
// Run: flutter test test/core/subscription/subscription_tier_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/subscription/subscription_tier.dart';

void main() {
  group('UT-TIER-SHAPE: SubscriptionTier enum (Req 1.1)', () {
    test('defines exactly four tiers', () {
      expect(SubscriptionTier.values.length, equals(4));
    });

    test('the four tiers are basic, pro, premium, enterprise', () {
      expect(
        SubscriptionTier.values,
        orderedEquals(const [
          SubscriptionTier.basic,
          SubscriptionTier.pro,
          SubscriptionTier.premium,
          SubscriptionTier.enterprise,
        ]),
      );
    });

    test('index encodes ascending order basic(0) < pro(1) < premium(2) < '
        'enterprise(3)', () {
      expect(SubscriptionTier.basic.index, equals(0));
      expect(SubscriptionTier.pro.index, equals(1));
      expect(SubscriptionTier.premium.index, equals(2));
      expect(SubscriptionTier.enterprise.index, equals(3));
    });

    test(
      'the `<` operator orders the tiers basic < pro < premium < enterprise',
      () {
        expect(SubscriptionTier.basic < SubscriptionTier.pro, isTrue);
        expect(SubscriptionTier.pro < SubscriptionTier.premium, isTrue);
        expect(SubscriptionTier.premium < SubscriptionTier.enterprise, isTrue);

        // Strictness: a tier is never less than itself or a lower tier.
        expect(SubscriptionTier.pro < SubscriptionTier.pro, isFalse);
        expect(SubscriptionTier.premium < SubscriptionTier.basic, isFalse);
        expect(SubscriptionTier.enterprise < SubscriptionTier.premium, isFalse);
      },
    );

    test('the `<=` operator is consistent with the strict order', () {
      expect(SubscriptionTier.basic <= SubscriptionTier.basic, isTrue);
      expect(SubscriptionTier.basic <= SubscriptionTier.enterprise, isTrue);
      expect(SubscriptionTier.enterprise <= SubscriptionTier.basic, isFalse);
    });

    test('the tiers form a strictly ascending chain across all values', () {
      final tiers = SubscriptionTier.values;
      for (var i = 0; i < tiers.length - 1; i++) {
        final lower = tiers[i];
        final higher = tiers[i + 1];
        expect(
          lower < higher,
          isTrue,
          reason:
              '${lower.name} should be strictly lower than '
              '${higher.name}',
        );
        expect(lower <= higher, isTrue);
        expect(lower.index < higher.index, isTrue);
      }
    });
  });
}
