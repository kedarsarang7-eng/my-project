// ============================================================================
// Task 9.6 — Plan_Positioning_Summary generator
// Spec: subscription-plan-tiers (Requirements 18.1, 18.2, 18.3, 18.4)
// ============================================================================
// Verifies the generator produces exactly one non-empty entry per tier, that
// each entry references its Requirement 1 coverage band (Req 18.3) and the
// category anchors consistent with Requirements 9, 10, 11 (Req 18.4), and that
// the value narratives match the Requirement 18.2 positioning of each tier.
//
// Run: flutter test test/core/subscription/positioning_summary_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/subscription/capability_classifier.dart';
import 'package:dukanx/core/subscription/positioning_summary.dart';
import 'package:dukanx/core/subscription/subscription_tier.dart';

void main() {
  const generator = PlanPositioningSummaryGenerator();

  group('UT-POS-SHAPE: one non-empty entry per tier (Req 18.1)', () {
    test('produces exactly one entry for each of the four tiers', () {
      final summary = generator.generate();
      expect(
        summary.tiers.keys.toSet(),
        equals(SubscriptionTier.values.toSet()),
      );
      expect(summary.tiers.length, equals(4));
    });

    test(
      'every tier entry has non-empty narrative fields (Req 18.1, 18.2)',
      () {
        final summary = generator.generate();
        for (final tier in SubscriptionTier.values) {
          final positioning = summary.positioningFor(tier);
          expect(
            positioning,
            isNotNull,
            reason:
                '${tier.name} must have an '
                'entry',
          );
          expect(positioning!.tier, equals(tier));
          expect(
            positioning.targetCustomer.trim(),
            isNotEmpty,
            reason: '${tier.name} target customer must be non-empty',
          );
          expect(
            positioning.valueNarrative.trim(),
            isNotEmpty,
            reason: '${tier.name} value narrative must be non-empty',
          );
          expect(
            positioning.upgradeTrigger.trim(),
            isNotEmpty,
            reason: '${tier.name} upgrade trigger must be non-empty',
          );
        }
      },
    );
  });

  group('UT-POS-COVERAGE: each entry references its Req 1 coverage band '
      '(Req 18.3)', () {
    test('coverageTarget equals the tier band for every tier', () {
      final summary = generator.generate();
      for (final tier in SubscriptionTier.values) {
        final positioning = summary.positioningFor(tier)!;
        expect(
          positioning.coverageTarget,
          equals(tier.band),
          reason:
              '${tier.name} must reference its Requirement 1 coverage '
              'band ${tier.band}',
        );
      }
    });

    test('enterprise coverage target is exactly 100%', () {
      final summary = generator.generate();
      final enterprise = summary.positioningFor(SubscriptionTier.enterprise)!;
      expect(enterprise.coverageTarget.minPercent, equals(100));
      expect(enterprise.coverageTarget.maxPercent, equals(100));
    });
  });

  group('UT-POS-ANCHORS: category anchors consistent with Req 9/10/11 '
      '(Req 18.4)', () {
    late PlanPositioningSummary summary;

    setUp(() => summary = generator.generate());

    test('every tier names at least one category anchor', () {
      for (final tier in SubscriptionTier.values) {
        expect(
          summary.positioningFor(tier)!.categoryAnchors,
          isNotEmpty,
          reason: '${tier.name} must name at least one category anchor',
        );
      }
    });

    test('Basic is anchored by Billing_Core (Req 5)', () {
      expect(
        summary.positioningFor(SubscriptionTier.basic)!.categoryAnchors,
        contains(GatingCategory.billingCore),
      );
    });

    test('Premium is anchored by analytics/export and compliance/seasonal '
        '(Req 9, Req 11)', () {
      final anchors = summary
          .positioningFor(SubscriptionTier.premium)!
          .categoryAnchors;
      expect(anchors, contains(GatingCategory.analyticsExport));
      expect(anchors, contains(GatingCategory.complianceSeasonal));
    });

    test('Enterprise is anchored by the enterprise-only category (Req 10)', () {
      expect(
        summary.positioningFor(SubscriptionTier.enterprise)!.categoryAnchors,
        contains(GatingCategory.enterpriseOnly),
      );
    });
  });

  group('UT-POS-NARRATIVE: Req 18.2 positioning phrasing', () {
    late PlanPositioningSummary summary;

    setUp(() => summary = generator.generate());

    test(
      'Basic reads as the pen-and-paper replacement for a solo operator',
      () {
        final narrative = summary
            .positioningFor(SubscriptionTier.basic)!
            .valueNarrative
            .toLowerCase();
        expect(narrative, contains('pen-and-paper'));
        expect(narrative, contains('solo operator'));
      },
    );

    test('Pro reads as the efficiency tier for a shop with 1 to 5 staff', () {
      final narrative = summary
          .positioningFor(SubscriptionTier.pro)!
          .valueNarrative
          .toLowerCase();
      expect(narrative, contains('efficiency'));
      expect(narrative, contains('1 to 5 staff'));
    });

    test('Premium reads as the reporting and multi-workflow tier', () {
      final narrative = summary
          .positioningFor(SubscriptionTier.premium)!
          .valueNarrative
          .toLowerCase();
      expect(narrative, contains('reporting'));
      expect(narrative, contains('multi-workflow'));
    });

    test(
      'Enterprise reads as multi-location, regulated, and franchise-ready',
      () {
        final narrative = summary
            .positioningFor(SubscriptionTier.enterprise)!
            .valueNarrative
            .toLowerCase();
        expect(narrative, contains('multi-location'));
        expect(narrative, contains('regulated'));
        expect(narrative, contains('franchise-ready'));
      },
    );
  });
}
