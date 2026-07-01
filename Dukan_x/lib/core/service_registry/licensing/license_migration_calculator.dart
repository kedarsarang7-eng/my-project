// ============================================================================
// License Migration Calculator
// ============================================================================
// Computes how much of an offline lifetime license remains and converts it
// to months of online subscription credit.
//
// Formula (as specified in the architecture doc):
//   amortizedValuePerYear  = purchaseAmount / amortizationYears
//   yearsConsumed          = daysSincePurchase / 365
//   consumedValue          = amortizedValuePerYear * yearsConsumed
//   remainingCredit        = max(0, purchaseAmount - consumedValue)
//   creditsInMonths        = floor(remainingCredit / onlinePlanMonthlyPrice)
// ============================================================================

import 'dart:math';

// ── Plan definitions ────────────────────────────────────────────────────────

/// Four offline lifetime plans matching the online SaaS tier names.
enum OfflinePlanType {
  lifetimeBasic,      // ₹4,999  one-time — 1 user, 1 branch
  lifetimePro,        // ₹9,999  one-time — 3 users, 1 branch
  lifetimePremium,    // ₹19,999 one-time — 10 users, 3 branches
  lifetimeEnterprise, // ₹39,999 one-time — unlimited
}

/// Four online SaaS plan tiers. Pricing per cycle is in [OnlinePlanX].
enum OnlinePlanType {
  basicMonthly,      // base tier
  proMonthly,        // growing business
  premiumMonthly,    // multi-user / multi-branch
  enterpriseMonthly, // chain stores / wholesale
}

/// All supported billing durations.
enum BillingCycleDart {
  monthly,    // 1 month
  quarterly,  // 3 months
  biannual,   // 6 months
  yearly,     // 12 months
  biennial,   // 24 months
  triennial,  // 36 months
}

extension OfflinePlanX on OfflinePlanType {
  String get wire => switch (this) {
        OfflinePlanType.lifetimeBasic => 'offline-lifetime-basic',
        OfflinePlanType.lifetimePro => 'offline-lifetime-pro',
        OfflinePlanType.lifetimePremium => 'offline-lifetime-premium',
        OfflinePlanType.lifetimeEnterprise => 'offline-lifetime-enterprise',
      };

  /// Canonical one-time purchase price in INR.
  int get defaultPurchaseAmount => switch (this) {
        OfflinePlanType.lifetimeBasic => 4999,
        OfflinePlanType.lifetimePro => 9999,
        OfflinePlanType.lifetimePremium => 19999,
        OfflinePlanType.lifetimeEnterprise => 39999,
      };

  /// Display label for the UI.
  String get displayName => switch (this) {
        OfflinePlanType.lifetimeBasic => 'Basic Lifetime',
        OfflinePlanType.lifetimePro => 'Pro Lifetime',
        OfflinePlanType.lifetimePremium => 'Premium Lifetime',
        OfflinePlanType.lifetimeEnterprise => 'Enterprise Lifetime',
      };

  OnlinePlanType get correspondingOnlinePlan => switch (this) {
        OfflinePlanType.lifetimeBasic => OnlinePlanType.basicMonthly,
        OfflinePlanType.lifetimePro => OnlinePlanType.proMonthly,
        OfflinePlanType.lifetimePremium => OnlinePlanType.premiumMonthly,
        OfflinePlanType.lifetimeEnterprise => OnlinePlanType.enterpriseMonthly,
      };

  static OfflinePlanType? fromWire(String wire) {
    for (final v in OfflinePlanType.values) {
      if (v.wire == wire) return v;
    }
    return null;
  }
}

extension OnlinePlanX on OnlinePlanType {
  String get wire => switch (this) {
        OnlinePlanType.basicMonthly => 'online-basic-monthly',
        OnlinePlanType.proMonthly => 'online-pro-monthly',
        OnlinePlanType.premiumMonthly => 'online-premium-monthly',
        OnlinePlanType.enterpriseMonthly => 'online-enterprise-monthly',
      };

  /// Display label for the UI.
  String get displayName => switch (this) {
        OnlinePlanType.basicMonthly => 'Basic',
        OnlinePlanType.proMonthly => 'Pro',
        OnlinePlanType.premiumMonthly => 'Premium',
        OnlinePlanType.enterpriseMonthly => 'Enterprise',
      };

  /// Monthly base price in INR (1-month cycle).
  int get monthlyPriceInr => priceForCycle(BillingCycleDart.monthly);

  /// Price in INR for a given billing cycle.
  int priceForCycle(BillingCycleDart cycle) {
    const prices = {
      // ignore: equal_keys_in_map
      OnlinePlanType.basicMonthly: {
        BillingCycleDart.monthly: 249,
        BillingCycleDart.quarterly: 699,
        BillingCycleDart.biannual: 1299,
        BillingCycleDart.yearly: 2399,
        BillingCycleDart.biennial: 4299,
        BillingCycleDart.triennial: 5999,
      },
      OnlinePlanType.proMonthly: {
        BillingCycleDart.monthly: 499,
        BillingCycleDart.quarterly: 1399,
        BillingCycleDart.biannual: 2699,
        BillingCycleDart.yearly: 4999,
        BillingCycleDart.biennial: 8999,
        BillingCycleDart.triennial: 12999,
      },
      OnlinePlanType.premiumMonthly: {
        BillingCycleDart.monthly: 999,
        BillingCycleDart.quarterly: 2799,
        BillingCycleDart.biannual: 5299,
        BillingCycleDart.yearly: 9999,
        BillingCycleDart.biennial: 17999,
        BillingCycleDart.triennial: 24999,
      },
      OnlinePlanType.enterpriseMonthly: {
        BillingCycleDart.monthly: 1999,
        BillingCycleDart.quarterly: 5499,
        BillingCycleDart.biannual: 10499,
        BillingCycleDart.yearly: 19999,
        BillingCycleDart.biennial: 35999,
        BillingCycleDart.triennial: 49999,
      },
    };
    return prices[this]![cycle]!;
  }

  /// Yearly total price in INR (12-month cycle).
  int get yearlyPriceInr => priceForCycle(BillingCycleDart.yearly);
}

extension BillingCycleDartX on BillingCycleDart {
  /// How many months this cycle covers.
  int get months => switch (this) {
        BillingCycleDart.monthly => 1,
        BillingCycleDart.quarterly => 3,
        BillingCycleDart.biannual => 6,
        BillingCycleDart.yearly => 12,
        BillingCycleDart.biennial => 24,
        BillingCycleDart.triennial => 36,
      };

  String get displayName => switch (this) {
        BillingCycleDart.monthly => '1 Month',
        BillingCycleDart.quarterly => '3 Months',
        BillingCycleDart.biannual => '6 Months',
        BillingCycleDart.yearly => '1 Year',
        BillingCycleDart.biennial => '2 Years',
        BillingCycleDart.triennial => '3 Years',
      };
}

// ── Input ──────────────────────────────────────────────────────────────────

class OfflineLicense {
  final String licenseId;
  final String clientUUID;
  final OfflinePlanType planType;
  final DateTime purchaseDate;
  final int purchaseAmount;

  /// How many years the license is amortized over (default: 5).
  /// Offline lifetime is priced lower than 5 years of SaaS, so 5-year
  /// amortization gives customers fair credit without over-rewarding.
  final int amortizationYears;

  const OfflineLicense({
    required this.licenseId,
    required this.clientUUID,
    required this.planType,
    required this.purchaseDate,
    required this.purchaseAmount,
    this.amortizationYears = 5,
  });
}

// ── Output ─────────────────────────────────────────────────────────────────

class MigrationCredit {
  final int originalPurchaseAmount;
  final int consumedValue;
  final int remainingCredit;
  final OnlinePlanType onlinePlan;
  final int onlinePlanMonthlyPrice;
  final int creditsInMonths;
  final DateTime subscriptionExpiryDate;

  const MigrationCredit({
    required this.originalPurchaseAmount,
    required this.consumedValue,
    required this.remainingCredit,
    required this.onlinePlan,
    required this.onlinePlanMonthlyPrice,
    required this.creditsInMonths,
    required this.subscriptionExpiryDate,
  });

  /// Best billing cycle the remaining credit can fully cover.
  /// Picks the longest cycle whose total price ≤ remainingCredit.
  BillingCycleDart get bestCycleForCredit {
    final cycles = BillingCycleDart.values.reversed;
    for (final cycle in cycles) {
      if (onlinePlan.priceForCycle(cycle) <= remainingCredit) {
        return cycle;
      }
    }
    return BillingCycleDart.monthly;
  }

  /// Human-readable summary shown to the user in the Warning Gate.
  String get warningGateSummary {
    final plan = onlinePlan.wire;
    final price = '₹$onlinePlanMonthlyPrice/month';
    final months = creditsInMonths;
    final expiry =
        '${subscriptionExpiryDate.day}/${subscriptionExpiryDate.month}/${subscriptionExpiryDate.year}';
    return '''Offline License:      ₹$originalPurchaseAmount (Lifetime ${_planLabel()})
Consumed (value):     ₹$consumedValue
Remaining Credit:     ₹$remainingCredit
Online Plan:          $plan ($price)
Free Months:          ~$months months
Expiry:               $expiry''';
  }

  String _planLabel() => switch (onlinePlan) {
        OnlinePlanType.basicMonthly => 'Basic',
        OnlinePlanType.proMonthly => 'Pro',
        OnlinePlanType.premiumMonthly => 'Premium',
        OnlinePlanType.enterpriseMonthly => 'Enterprise',
      };
}

// ── Calculator ─────────────────────────────────────────────────────────────

class LicenseMigrationCalculator {
  LicenseMigrationCalculator._();

  /// Compute remaining credit and subscription months.
  static MigrationCredit calculateMigrationCredit(OfflineLicense license) {
    final now = DateTime.now();

    final amortizationYears =
        license.amortizationYears > 0 ? license.amortizationYears : 5;

    final amortizedValuePerYear = license.purchaseAmount / amortizationYears;

    final daysSincePurchase =
        now.difference(license.purchaseDate).inDays.toDouble();
    final yearsConsumed = daysSincePurchase / 365.0;

    final consumedValue = (amortizedValuePerYear * yearsConsumed).round();
    final remainingCredit =
        max(0, license.purchaseAmount - consumedValue);

    final onlinePlan = license.planType.correspondingOnlinePlan;
    final monthlyPrice = onlinePlan.monthlyPriceInr;

    final creditsInMonths = monthlyPrice > 0
        ? (remainingCredit / monthlyPrice).floor()
        : 0;

    final expiryDate = _addMonths(now, creditsInMonths);

    return MigrationCredit(
      originalPurchaseAmount: license.purchaseAmount,
      consumedValue: consumedValue,
      remainingCredit: remainingCredit,
      onlinePlan: onlinePlan,
      onlinePlanMonthlyPrice: monthlyPrice,
      creditsInMonths: creditsInMonths,
      subscriptionExpiryDate: expiryDate,
    );
  }

  static DateTime _addMonths(DateTime date, int months) {
    int newMonth = date.month + months;
    int newYear = date.year + (newMonth - 1) ~/ 12;
    newMonth = (newMonth - 1) % 12 + 1;
    final lastDay = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = min(date.day, lastDay);
    return DateTime(newYear, newMonth, newDay);
  }
}
