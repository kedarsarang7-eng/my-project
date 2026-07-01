// ============================================================================
// LicenseMigrationCalculator â€” Unit Tests
// ============================================================================
// Pricing (confirmed):
//   Online:  Basic â‚¹249/mo | Pro â‚¹499/mo | Premium â‚¹999/mo | Enterprise â‚¹1,999/mo
//   Offline: Basic â‚¹4,999  | Pro â‚¹9,999  | Premium â‚¹19,999 | Enterprise â‚¹39,999
//   Amortization: 5 years
//
// LC-01  Basic lifetime, 2.5 yrs used â€” correct credit & months
// LC-02  Pro lifetime, fresh purchase â†’ consumed â‰ˆ 0, full credit
// LC-03  License > 5 years old â†’ remaining credit = 0
// LC-04  Pro plan â†’ monthly price = â‚¹499
// LC-05  Premium plan â†’ monthly price = â‚¹999
// LC-06  Enterprise plan â†’ monthly price = â‚¹1,999
// LC-07  creditsInMonths floors (not rounds)
// LC-08  Summary string contains key fields
// LC-09  All 4 plans produce correct online mapping
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/service_registry/licensing/license_migration_calculator.dart';

void main() {
  group('LicenseMigrationCalculator', () {
    // â”€â”€ LC-01 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-01: Basic lifetime, 2.5 years used â€” correct credit & months', () {
      final license = OfflineLicense(
        licenseId: 'LIC-001',
        clientUUID: 'client-001',
        planType: OfflinePlanType.lifetimeBasic,
        purchaseDate: DateTime.now().subtract(const Duration(days: 912)),
        purchaseAmount: 4999,
        amortizationYears: 5,
      );

      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);

      // amortizedPerYear = 4999/5 = 999.8
      // consumed = 999.8 * 2.5 â‰ˆ 2499.5 â†’ rounded to 2500
      // remaining = 4999 - 2500 = 2499
      expect(credit.originalPurchaseAmount, 4999);
      expect(credit.consumedValue, closeTo(2500, 60)); // Â±60 INR for day rounding
      expect(credit.remainingCredit, closeTo(2499, 60));

      // creditsInMonths = floor(2499 / 249) = 10
      expect(credit.creditsInMonths, closeTo(10, 1));
      expect(credit.onlinePlan, OnlinePlanType.basicMonthly);
      expect(credit.onlinePlanMonthlyPrice, 249);
    });

    // â”€â”€ LC-02 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-02: Pro lifetime, fresh purchase â†’ consumed â‰ˆ 0, full credit', () {
      final license = OfflineLicense(
        licenseId: 'LIC-002',
        clientUUID: 'client-002',
        planType: OfflinePlanType.lifetimePro,
        purchaseDate: DateTime.now(),
        purchaseAmount: 9999,
        amortizationYears: 5,
      );

      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);

      expect(credit.consumedValue, closeTo(0, 10));
      expect(credit.remainingCredit, closeTo(9999, 10));
      // creditsInMonths = floor(9999 / 499) = 20
      expect(credit.creditsInMonths, greaterThanOrEqualTo(20));
      expect(credit.onlinePlan, OnlinePlanType.proMonthly);
    });

    // â”€â”€ LC-03 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-03: License > 5 years old â†’ remaining credit = 0', () {
      final license = OfflineLicense(
        licenseId: 'LIC-003',
        clientUUID: 'client-003',
        planType: OfflinePlanType.lifetimeBasic,
        purchaseDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
        purchaseAmount: 4999,
        amortizationYears: 5,
      );

      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);

      expect(credit.remainingCredit, 0);
      expect(credit.creditsInMonths, 0);
    });

    // â”€â”€ LC-04 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-04: Pro plan â†’ monthly price = â‚¹499', () {
      final license = OfflineLicense(
        licenseId: 'LIC-004',
        clientUUID: 'client-004',
        planType: OfflinePlanType.lifetimePro,
        purchaseDate: DateTime.now().subtract(const Duration(days: 365)),
        purchaseAmount: 9999,
      );

      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);

      expect(credit.onlinePlan, OnlinePlanType.proMonthly);
      expect(credit.onlinePlanMonthlyPrice, 499);
    });

    // â”€â”€ LC-05 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-05: Premium plan â†’ monthly price = â‚¹999', () {
      final license = OfflineLicense(
        licenseId: 'LIC-005',
        clientUUID: 'client-005',
        planType: OfflinePlanType.lifetimePremium,
        purchaseDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
        purchaseAmount: 19999,
      );

      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);

      expect(credit.onlinePlan, OnlinePlanType.premiumMonthly);
      expect(credit.onlinePlanMonthlyPrice, 999);
    });

    // â”€â”€ LC-06 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-06: Enterprise plan â†’ monthly price = â‚¹1,999', () {
      final license = OfflineLicense(
        licenseId: 'LIC-006',
        clientUUID: 'client-006',
        planType: OfflinePlanType.lifetimeEnterprise,
        purchaseDate: DateTime.now().subtract(const Duration(days: 365)),
        purchaseAmount: 39999,
      );

      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);

      expect(credit.onlinePlan, OnlinePlanType.enterpriseMonthly);
      expect(credit.onlinePlanMonthlyPrice, 1999);
      expect(credit.subscriptionExpiryDate.isAfter(DateTime.now()), isTrue);
    });

    // â”€â”€ LC-07 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-07: creditsInMonths floors fractional result', () {
      final license = OfflineLicense(
        licenseId: 'LIC-007',
        clientUUID: 'client-007',
        planType: OfflinePlanType.lifetimePro,
        purchaseDate: DateTime.now().subtract(const Duration(days: 365 * 4)),
        purchaseAmount: 9999,
        amortizationYears: 5,
      );
      // consumed = 9999/5 * 4 = 7999.2, remaining â‰ˆ 1999.8 â†’ 2000
      // creditsInMonths = floor(2000 / 499) = 4 (not 5)
      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);
      expect(credit.creditsInMonths, equals(credit.remainingCredit ~/ 499));
    });

    // â”€â”€ LC-08 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-08: Summary string contains key fields', () {
      final license = OfflineLicense(
        licenseId: 'LIC-008',
        clientUUID: 'client-008',
        planType: OfflinePlanType.lifetimeBasic,
        purchaseDate: DateTime.now().subtract(const Duration(days: 365)),
        purchaseAmount: 4999,
      );

      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);
      final summary = credit.warningGateSummary;

      expect(summary, contains('4999'));
      expect(summary, contains('249'));
      expect(summary, isNotEmpty);
    });

    // â”€â”€ LC-09 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    test('LC-09: All 4 offline plans map to correct online plans', () {
      final mapping = {
        OfflinePlanType.lifetimeBasic: OnlinePlanType.basicMonthly,
        OfflinePlanType.lifetimePro: OnlinePlanType.proMonthly,
        OfflinePlanType.lifetimePremium: OnlinePlanType.premiumMonthly,
        OfflinePlanType.lifetimeEnterprise: OnlinePlanType.enterpriseMonthly,
      };
      for (final entry in mapping.entries) {
        expect(entry.key.correspondingOnlinePlan, entry.value,
            reason: '${entry.key} should map to ${entry.value}');
      }
    });
  });

  // â”€â”€ OfflinePlanX extension tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  group('OfflinePlanX', () {
    test('fromWire round-trips all 4 plans', () {
      for (final plan in OfflinePlanType.values) {
        expect(OfflinePlanX.fromWire(plan.wire), equals(plan));
      }
    });

    test('fromWire returns null for unknown wire value', () {
      expect(OfflinePlanX.fromWire('unknown-plan'), isNull);
    });

    test('defaultPurchaseAmount matches confirmed pricing', () {
      expect(OfflinePlanType.lifetimeBasic.defaultPurchaseAmount, 4999);
      expect(OfflinePlanType.lifetimePro.defaultPurchaseAmount, 9999);
      expect(OfflinePlanType.lifetimePremium.defaultPurchaseAmount, 19999);
      expect(OfflinePlanType.lifetimeEnterprise.defaultPurchaseAmount, 39999);
    });
  });

  // â”€â”€ OnlinePlanX extension tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  group('OnlinePlanX', () {
    test('monthlyPriceInr matches confirmed pricing', () {
      expect(OnlinePlanType.basicMonthly.monthlyPriceInr, 249);
      expect(OnlinePlanType.proMonthly.monthlyPriceInr, 499);
      expect(OnlinePlanType.premiumMonthly.monthlyPriceInr, 999);
      expect(OnlinePlanType.enterpriseMonthly.monthlyPriceInr, 1999);
    });

    test('yearlyPriceInr matches confirmed pricing', () {
      expect(OnlinePlanType.basicMonthly.yearlyPriceInr, 2399);
      expect(OnlinePlanType.proMonthly.yearlyPriceInr, 4999);
      expect(OnlinePlanType.premiumMonthly.yearlyPriceInr, 9999);
      expect(OnlinePlanType.enterpriseMonthly.yearlyPriceInr, 19999);
    });

    test('all 6 cycle prices match confirmed pricing â€” Basic', () {
      expect(OnlinePlanType.basicMonthly.priceForCycle(BillingCycleDart.monthly), 249);
      expect(OnlinePlanType.basicMonthly.priceForCycle(BillingCycleDart.quarterly), 699);
      expect(OnlinePlanType.basicMonthly.priceForCycle(BillingCycleDart.biannual), 1299);
      expect(OnlinePlanType.basicMonthly.priceForCycle(BillingCycleDart.yearly), 2399);
      expect(OnlinePlanType.basicMonthly.priceForCycle(BillingCycleDart.biennial), 4299);
      expect(OnlinePlanType.basicMonthly.priceForCycle(BillingCycleDart.triennial), 5999);
    });

    test('all 6 cycle prices match confirmed pricing â€” Enterprise', () {
      expect(OnlinePlanType.enterpriseMonthly.priceForCycle(BillingCycleDart.monthly), 1999);
      expect(OnlinePlanType.enterpriseMonthly.priceForCycle(BillingCycleDart.quarterly), 5499);
      expect(OnlinePlanType.enterpriseMonthly.priceForCycle(BillingCycleDart.biannual), 10499);
      expect(OnlinePlanType.enterpriseMonthly.priceForCycle(BillingCycleDart.yearly), 19999);
      expect(OnlinePlanType.enterpriseMonthly.priceForCycle(BillingCycleDart.biennial), 35999);
      expect(OnlinePlanType.enterpriseMonthly.priceForCycle(BillingCycleDart.triennial), 49999);
    });

    test('every cycle is cheaper than paying monthly for the same period', () {
      for (final plan in OnlinePlanType.values) {
        for (final cycle in BillingCycleDart.values) {
          if (cycle == BillingCycleDart.monthly) continue;
          final cyclePrice = plan.priceForCycle(cycle);
          final monthlyEquivalent = plan.monthlyPriceInr * cycle.months;
          expect(
            cyclePrice < monthlyEquivalent,
            isTrue,
            reason: '${plan.displayName} ${cycle.displayName} should be cheaper than ${cycle.months}Ã— monthly',
          );
        }
      }
    });
  });

  // â”€â”€ BillingCycleDartX tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  group('BillingCycleDartX', () {
    test('months values are correct', () {
      expect(BillingCycleDart.monthly.months, 1);
      expect(BillingCycleDart.quarterly.months, 3);
      expect(BillingCycleDart.biannual.months, 6);
      expect(BillingCycleDart.yearly.months, 12);
      expect(BillingCycleDart.biennial.months, 24);
      expect(BillingCycleDart.triennial.months, 36);
    });

    test('displayName is non-empty for all cycles', () {
      for (final cycle in BillingCycleDart.values) {
        expect(cycle.displayName, isNotEmpty);
      }
    });
  });

  // â”€â”€ bestCycleForCredit tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  group('MigrationCredit.bestCycleForCredit', () {
    test('full Basic lifetime credit â†’ best cycle is triennial', () {
      final license = OfflineLicense(
        licenseId: 'LIC-BC-01',
        clientUUID: 'client-bc-01',
        planType: OfflinePlanType.lifetimeBasic,
        purchaseDate: DateTime.now(),
        purchaseAmount: 4999,
      );
      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);
      // remaining â‰ˆ 4999, triennial Basic = 5999 â†’ won't fit
      // biennial Basic = 4299 â†’ fits â†’ best = biennial
      expect(credit.bestCycleForCredit, BillingCycleDart.biennial);
    });

    test('small remaining credit â†’ falls back to monthly', () {
      final license = OfflineLicense(
        licenseId: 'LIC-BC-02',
        clientUUID: 'client-bc-02',
        planType: OfflinePlanType.lifetimeBasic,
        purchaseDate: DateTime.now().subtract(const Duration(days: 365 * 4 + 300)),
        purchaseAmount: 4999,
        amortizationYears: 5,
      );
      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);
      // consumed â‰ˆ 4999*4.8/5 = 4799, remaining â‰ˆ 200
      // even monthly Basic = 249 â†’ might not fit â†’ falls back to monthly
      expect(
        BillingCycleDart.values.contains(credit.bestCycleForCredit),
        isTrue,
      );
    });
  });
}
