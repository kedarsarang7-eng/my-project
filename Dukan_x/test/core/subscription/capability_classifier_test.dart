// ============================================================================
// Task 3.2 — CapabilityClassifier floor / ceiling / category
// Spec: subscription-plan-tiers (Requirements 5.1, 9.1, 10.1, 11.1)
// ============================================================================
// Verifies the gating category and the floor/ceiling tier the classifier
// assigns to each gated capability set:
//   billingCore         → category billingCore        floor basic      ceiling basic
//   analyticsExport     → category analyticsExport     floor premium    ceiling enterprise
//   enterpriseOnly      → category enterpriseOnly      floor enterprise ceiling enterprise
//   complianceSeasonal  → category complianceSeasonal  floor premium    ceiling enterprise
//   standard            → category standard            floor basic      ceiling enterprise
//
// Run: flutter test test/core/subscription/capability_classifier_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/capability_classifier.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

void main() {
  const classifier = CapabilityClassifier();

  /// Asserts every member of [caps] resolves to [category] with [floor] and
  /// [ceiling].
  void expectSet(
    Set<BusinessCapability> caps,
    GatingCategory category,
    SubscriptionTier floor,
    SubscriptionTier ceiling,
  ) {
    for (final cap in caps) {
      expect(
        classifier.categoryOf(cap),
        equals(category),
        reason: '${cap.name} should be categorised as ${category.name}',
      );
      expect(
        classifier.floorFor(cap),
        equals(floor),
        reason: '${cap.name} floor should be ${floor.name}',
      );
      expect(
        classifier.ceilingFor(cap),
        equals(ceiling),
        reason: '${cap.name} ceiling should be ${ceiling.name}',
      );
    }
  }

  group('UT-CLS-BILLING: Billing_Core → basic/basic (Req 5.1)', () {
    test('every Billing_Core member is billingCore, floor=basic, '
        'ceiling=basic', () {
      expectSet(
        CapabilityClassifier.billingCoreCapabilities,
        GatingCategory.billingCore,
        SubscriptionTier.basic,
        SubscriptionTier.basic,
      );
    });
  });

  group(
    'UT-CLS-ANALYTICS: analytics/export → premium/enterprise (Req 9.1)',
    () {
      test('every analytics/export member is analyticsExport, floor=premium, '
          'ceiling=enterprise', () {
        expectSet(
          CapabilityClassifier.analyticsExportCapabilities,
          GatingCategory.analyticsExport,
          SubscriptionTier.premium,
          SubscriptionTier.enterprise,
        );
      });
    },
  );

  group('UT-CLS-ENTERPRISE: enterprise-only → enterprise/enterprise '
      '(Req 10.1)', () {
    test('every enterprise-only member is enterpriseOnly, floor=enterprise, '
        'ceiling=enterprise', () {
      expectSet(
        CapabilityClassifier.enterpriseOnlyCapabilities,
        GatingCategory.enterpriseOnly,
        SubscriptionTier.enterprise,
        SubscriptionTier.enterprise,
      );
    });
  });

  group('UT-CLS-COMPLIANCE: compliance/seasonal → premium/enterprise '
      '(Req 11.1)', () {
    test('every compliance/seasonal member is complianceSeasonal, '
        'floor=premium, ceiling=enterprise', () {
      expectSet(
        CapabilityClassifier.complianceSeasonalCapabilities,
        GatingCategory.complianceSeasonal,
        SubscriptionTier.premium,
        SubscriptionTier.enterprise,
      );
    });
  });

  group('UT-CLS-STANDARD: everything else → basic/enterprise', () {
    test('a representative standard capability is standard, floor=basic, '
        'ceiling=enterprise', () {
      // useProductAdd belongs to no gated set, so it is standard.
      expectSet(
        {
          BusinessCapability.useProductAdd,
          BusinessCapability.useBarcodeScanner,
          BusinessCapability.useStockEntry,
        },
        GatingCategory.standard,
        SubscriptionTier.basic,
        SubscriptionTier.enterprise,
      );
    });

    test('every capability not in a gated set classifies as standard', () {
      final gated = <BusinessCapability>{
        ...CapabilityClassifier.billingCoreCapabilities,
        ...CapabilityClassifier.analyticsExportCapabilities,
        ...CapabilityClassifier.enterpriseOnlyCapabilities,
        ...CapabilityClassifier.complianceSeasonalCapabilities,
      };
      for (final cap in BusinessCapability.values) {
        if (gated.contains(cap)) continue;
        expect(
          classifier.categoryOf(cap),
          equals(GatingCategory.standard),
          reason:
              '${cap.name} is not in any gated set, so it must be '
              'standard',
        );
        expect(classifier.floorFor(cap), equals(SubscriptionTier.basic));
        expect(classifier.ceilingFor(cap), equals(SubscriptionTier.enterprise));
      }
    });
  });

  group('UT-CLS-INVARIANTS: floor never exceeds ceiling', () {
    test('floorFor(cap) <= ceilingFor(cap) for every capability', () {
      for (final cap in BusinessCapability.values) {
        expect(
          classifier.floorFor(cap) <= classifier.ceilingFor(cap),
          isTrue,
          reason: '${cap.name}: floor must be <= ceiling',
        );
      }
    });
  });
}
