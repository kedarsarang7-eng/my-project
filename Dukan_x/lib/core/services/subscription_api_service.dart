// ============================================================================
// Subscription API Service
// ============================================================================
// Client for DukanX subscription management API endpoints.
// Handles plan upgrades, downgrades, usage queries, and payment retry.
//
// Security: All requests include Cognito JWT via Dio interceptor
// ============================================================================

import 'package:dio/dio.dart';
import '../../../config/api_config.dart';

// ── Models ─────────────────────────────────────────────────────────────────

enum PlanTier {
  basic,
  pro,
  premium,
  enterprise,
}

enum BillingCycle {
  monthly,
  yearly,
}

enum SubscriptionStatus {
  active,
  trial,
  trialExpired,
  pastDue,
  gracePeriod,
  cancelled,
  expired,
  suspended,
  pendingDowngrade,
}

class Subscription {
  final PlanTier plan;
  final BillingCycle billingCycle;
  final SubscriptionStatus status;
  final DateTime planStartDate;
  final DateTime? planEndDate;
  final DateTime? trialEndDate;
  final DateTime? gracePeriodEndDate;
  final DateTime? nextBillingDate;
  final PlanLimits limits;
  final UsageStats usage;
  final bool isInTrial;
  final int? daysUntilTrialExpiry;
  // F011: allowedFeatures is the list of feature keys the backend grants for this plan+businessType
  final List<String>? allowedFeatures;

  Subscription({
    required this.plan,
    required this.billingCycle,
    required this.status,
    required this.planStartDate,
    this.planEndDate,
    this.trialEndDate,
    this.gracePeriodEndDate,
    this.nextBillingDate,
    required this.limits,
    required this.usage,
    required this.isInTrial,
    this.daysUntilTrialExpiry,
    this.allowedFeatures,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      plan: _parsePlanTier(json['plan']),
      billingCycle: _parseBillingCycle(json['billingCycle']),
      status: _parseStatus(json['status']),
      planStartDate: json['planStartDate'] != null
          ? DateTime.parse(json['planStartDate'])
          : DateTime.now(),
      planEndDate: json['planEndDate'] != null ? DateTime.parse(json['planEndDate']) : null,
      trialEndDate: json['trialEndDate'] != null ? DateTime.parse(json['trialEndDate']) : null,
      gracePeriodEndDate: json['gracePeriodEndDate'] != null ? DateTime.parse(json['gracePeriodEndDate']) : null,
      nextBillingDate: json['nextBillingDate'] != null ? DateTime.parse(json['nextBillingDate']) : null,
      limits: PlanLimits.fromJson(json['limits'] ?? {}),
      usage: UsageStats.fromJson(json['usage'] ?? {}),
      isInTrial: json['isInTrial'] ?? false,
      daysUntilTrialExpiry: json['daysUntilTrialExpiry'],
      // F011: Parse allowedFeatures list from subscription API response
      allowedFeatures: (json['allowedFeatures'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  bool get isLocked => status == SubscriptionStatus.expired ||
      status == SubscriptionStatus.trialExpired ||
      status == SubscriptionStatus.suspended;
  bool get isPartiallyLocked => status == SubscriptionStatus.gracePeriod;
  bool get canWrite => !isLocked && !isPartiallyLocked;
  bool get isPaymentOverdue => status == SubscriptionStatus.pastDue || status == SubscriptionStatus.gracePeriod;
}

class PlanLimits {
  final int? maxUsers;
  final int? maxProducts;
  final int maxBranches;
  final int maxDevices;
  final int maxBusinessTypes;
  final int? maxInvoicesPerMonth;

  PlanLimits({
    this.maxUsers,
    this.maxProducts,
    required this.maxBranches,
    required this.maxDevices,
    required this.maxBusinessTypes,
    this.maxInvoicesPerMonth,
  });

  factory PlanLimits.fromJson(Map<String, dynamic> json) {
    return PlanLimits(
      maxUsers: _parseLimit(json['maxUsers']),
      maxProducts: _parseLimit(json['maxProducts']),
      maxBranches: json['maxBranches'] ?? 1,
      maxDevices: json['maxDevices'] ?? 1,
      maxBusinessTypes: json['maxBusinessTypes'] ?? 1,
      maxInvoicesPerMonth: _parseLimit(json['maxInvoicesPerMonth']),
    );
  }

  /// Parse limit value that may be int, String, 'unlimited', -1, or null.
  /// Returns null for unlimited (null, 'unlimited', -1).
  static int? _parseLimit(dynamic value) {
    if (value == null || value == 'unlimited' || value == -1) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class UsageStats {
  final int currentUsers;
  final int currentProducts;
  final int currentMonthInvoices;
  final int currentBranches;
  final int currentDevices;
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;

  UsageStats({
    required this.currentUsers,
    required this.currentProducts,
    required this.currentMonthInvoices,
    required this.currentBranches,
    required this.currentDevices,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      currentUsers: json['currentUsers'] ?? 0,
      currentProducts: json['currentProducts'] ?? 0,
      currentMonthInvoices: json['currentMonthInvoices'] ?? 0,
      currentBranches: json['currentBranches'] ?? 0,
      currentDevices: json['currentDevices'] ?? 0,
      billingPeriodStart: json['billingPeriodStart'] != null
          ? DateTime.parse(json['billingPeriodStart'])
          : DateTime.now(),
      billingPeriodEnd: json['billingPeriodEnd'] != null
          ? DateTime.parse(json['billingPeriodEnd'])
          : DateTime.now().add(const Duration(days: 30)),
    );
  }

  // NOTE: Percentages should be calculated in UsageResult which has both usage and limits.
}

class PlanInfo {
  final PlanTier id;
  final String name;
  final String description;
  final bool current;
  final PriceInfo monthly;
  final PriceInfo yearly;
  final PlanLimits limits;
  final List<String> features;
  final bool canUpgrade;
  final bool canDowngrade;

  PlanInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.current,
    required this.monthly,
    required this.yearly,
    required this.limits,
    required this.features,
    required this.canUpgrade,
    required this.canDowngrade,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) {
    return PlanInfo(
      id: _parsePlanTier(json['id']),
      name: json['name'],
      description: json['description'],
      current: json['current'],
      monthly: PriceInfo.fromJson(json['monthly']),
      yearly: PriceInfo.fromJson(json['yearly']),
      limits: PlanLimits.fromJson(json['limits']),
      features: List<String>.from(json['features']),
      canUpgrade: json['canUpgrade'],
      canDowngrade: json['canDowngrade'],
    );
  }
}

class PriceInfo {
  final int priceInPaise;
  final String displayPrice;
  final int? savings;
  final String? savingsDisplay;

  PriceInfo({
    required this.priceInPaise,
    required this.displayPrice,
    this.savings,
    this.savingsDisplay,
  });

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    return PriceInfo(
      priceInPaise: json['priceInPaise'],
      displayPrice: json['displayPrice'],
      savings: json['savings'],
      savingsDisplay: json['savingsDisplay'],
    );
  }

  double get priceInRupees => priceInPaise / 100;
}

class UpgradeResult {
  final bool success;
  final String message;
  final PlanTier newPlan;
  final BillingCycle billingCycle;
  final int proratedCharge;
  final String proratedChargeDisplay;
  final DateTime nextBillingDate;
  final String? invoiceUrl;

  UpgradeResult({
    required this.success,
    required this.message,
    required this.newPlan,
    required this.billingCycle,
    required this.proratedCharge,
    required this.proratedChargeDisplay,
    required this.nextBillingDate,
    this.invoiceUrl,
  });

  factory UpgradeResult.fromJson(Map<String, dynamic> json) {
    return UpgradeResult(
      success: json['success'],
      message: json['message'],
      newPlan: _parsePlanTier(json['newPlan']),
      billingCycle: _parseBillingCycle(json['billingCycle']),
      proratedCharge: json['proratedCharge'],
      proratedChargeDisplay: json['proratedChargeDisplay'],
      nextBillingDate: json['nextBillingDate'] != null
          ? DateTime.parse(json['nextBillingDate'])
          : DateTime.now().add(const Duration(days: 30)),
      invoiceUrl: json['invoiceUrl'],
    );
  }
}

class DowngradeResult {
  final bool success;
  final String message;
  final PlanTier targetPlan;
  final BillingCycle billingCycle;
  final DateTime scheduledDate;

  DowngradeResult({
    required this.success,
    required this.message,
    required this.targetPlan,
    required this.billingCycle,
    required this.scheduledDate,
  });

  factory DowngradeResult.fromJson(Map<String, dynamic> json) {
    return DowngradeResult(
      success: json['success'],
      message: json['message'],
      targetPlan: _parsePlanTier(json['targetPlan']),
      billingCycle: _parseBillingCycle(json['billingCycle']),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : DateTime.now(),
    );
  }
}

class RetryPaymentResult {
  final bool success;
  final String? paymentLink;
  final DateTime? nextAttemptDate;
  final String message;

  RetryPaymentResult({
    required this.success,
    this.paymentLink,
    this.nextAttemptDate,
    required this.message,
  });

  factory RetryPaymentResult.fromJson(Map<String, dynamic> json) {
    return RetryPaymentResult(
      success: json['success'],
      paymentLink: json['paymentLink'],
      nextAttemptDate: json['nextAttemptDate'] != null ? DateTime.parse(json['nextAttemptDate']) : null,
      message: json['message'],
    );
  }
}

class UsageResult {
  final UsageStats usage;
  final PlanLimits limits;
  final Map<String, double> percentages;
  final Map<String, bool> isOverLimit;
  final Map<String, String> billingPeriod;

  UsageResult({
    required this.usage,
    required this.limits,
    required this.percentages,
    required this.isOverLimit,
    required this.billingPeriod,
  });

  factory UsageResult.fromJson(Map<String, dynamic> json) {
    return UsageResult(
      usage: UsageStats.fromJson(json['usage']),
      limits: PlanLimits.fromJson(json['limits']),
      percentages: Map<String, double>.from(json['percentages']),
      isOverLimit: Map<String, bool>.from(json['isOverLimit']),
      billingPeriod: Map<String, String>.from(json['billingPeriod']),
    );
  }
}

// ── Parsing Helpers ─────────────────────────────────────────────────────────

PlanTier _parsePlanTier(String value) {
  switch (value.toLowerCase()) {
    case 'basic':
      return PlanTier.basic;
    case 'pro':
      return PlanTier.pro;
    case 'premium':
      return PlanTier.premium;
    case 'enterprise':
      return PlanTier.enterprise;
    default:
      return PlanTier.basic;
  }
}

BillingCycle _parseBillingCycle(String value) {
  switch (value.toLowerCase()) {
    case 'monthly':
      return BillingCycle.monthly;
    case 'yearly':
      return BillingCycle.yearly;
    default:
      return BillingCycle.monthly;
  }
}

SubscriptionStatus _parseStatus(String value) {
  switch (value.toLowerCase()) {
    case 'active':
      return SubscriptionStatus.active;
    case 'trial':
      return SubscriptionStatus.trial;
    case 'trial_expired':
      return SubscriptionStatus.trialExpired;
    case 'past_due':
      return SubscriptionStatus.pastDue;
    case 'grace_period':
      return SubscriptionStatus.gracePeriod;
    case 'cancelled':
      return SubscriptionStatus.cancelled;
    case 'expired':
      return SubscriptionStatus.expired;
    case 'suspended':
      return SubscriptionStatus.suspended;
    case 'pending_downgrade':
      return SubscriptionStatus.pendingDowngrade;
    case 'pending_payment': // F016: new status added on backend
      return SubscriptionStatus.active; // treat as active while payment processes
    default:
      return SubscriptionStatus.active;
  }
}

// ── API Service ─────────────────────────────────────────────────────────────

class SubscriptionApiService {
  final Dio _dio;
  final String _baseUrl;

  SubscriptionApiService({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  // ── GET /subscription/current ─────────────────────────────────────────────
  Future<Subscription> getCurrentSubscription() async {
    try {
      final response = await _dio.get('$_baseUrl/subscription/current');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return Subscription.fromJson(response.data['data']);
      }

      throw SubscriptionApiException(
        message: response.data['message'] ?? 'Failed to load subscription',
        code: response.data['errorCode'],
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── GET /subscription/plans ───────────────────────────────────────────────
  Future<List<PlanInfo>> getAvailablePlans() async {
    try {
      final response = await _dio.get('$_baseUrl/subscription/plans');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final plans = (response.data['data']['plans'] as List)
            .map((json) => PlanInfo.fromJson(json))
            .toList();
        return plans;
      }

      throw SubscriptionApiException(
        message: response.data['message'] ?? 'Failed to load plans',
        code: response.data['errorCode'],
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── POST /subscription/upgrade ────────────────────────────────────────────
  Future<UpgradeResult> upgradePlan({
    required PlanTier targetPlan,
    required BillingCycle billingCycle,
    bool immediateCharge = true,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/subscription/upgrade',
        data: {
          'targetPlan': targetPlan.name,
          'billingCycle': billingCycle.name,
          'immediateCharge': immediateCharge,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return UpgradeResult.fromJson(response.data['data']);
      }

      throw SubscriptionApiException(
        message: response.data['message'] ?? 'Upgrade failed',
        code: response.data['errorCode'],
        upgradeRequired: response.data['upgradeRequired'],
        currentPlan: response.data['currentPlan'],
        requiredPlan: response.data['requiredPlan'],
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── POST /subscription/downgrade ────────────────────────────────────────
  Future<DowngradeResult> downgradePlan({
    required PlanTier targetPlan,
    required BillingCycle billingCycle,
    DateTime? effectiveDate,
  }) async {
    try {
      final data = {
        'targetPlan': targetPlan.name,
        'billingCycle': billingCycle.name,
        if (effectiveDate != null)
          'effectiveDate': effectiveDate.toIso8601String(),
      };

      final response = await _dio.post(
        '$_baseUrl/subscription/downgrade',
        data: data,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return DowngradeResult.fromJson(response.data['data']);
      }

      throw SubscriptionApiException(
        message: response.data['message'] ?? 'Downgrade failed',
        code: response.data['errorCode'],
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── POST /subscription/retry ──────────────────────────────────────────────
  Future<RetryPaymentResult> retryPayment() async {
    try {
      final response = await _dio.post('$_baseUrl/subscription/retry');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return RetryPaymentResult.fromJson(response.data['data']);
      }

      throw SubscriptionApiException(
        message: response.data['message'] ?? 'Payment retry failed',
        code: response.data['errorCode'],
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── GET /subscription/usage ───────────────────────────────────────────────
  Future<UsageResult> getUsageStats() async {
    try {
      final response = await _dio.get('$_baseUrl/subscription/usage');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return UsageResult.fromJson(response.data['data']);
      }

      throw SubscriptionApiException(
        message: response.data['message'] ?? 'Failed to load usage',
        code: response.data['errorCode'],
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── Error Handling ────────────────────────────────────────────────────────
  SubscriptionApiException _handleDioError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      return SubscriptionApiException(
        message: data?['message'] ?? error.message ?? 'Network error',
        code: data?['errorCode'],
        statusCode: error.response!.statusCode,
        upgradeRequired: data?['upgradeRequired'],
        currentPlan: data?['currentPlan'],
        requiredPlan: data?['requiredPlan'],
      );
    }

    return SubscriptionApiException(
      message: error.message ?? 'Network error',
      code: 'NETWORK_ERROR',
    );
  }
}

// ── Exceptions ─────────────────────────────────────────────────────────────

class SubscriptionApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final bool? upgradeRequired;
  final String? currentPlan;
  final String? requiredPlan;

  SubscriptionApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.upgradeRequired,
    this.currentPlan,
    this.requiredPlan,
  });

  @override
  String toString() => 'SubscriptionApiException: $message (code: $code)';
}

// ── Singleton Instance ───────────────────────────────────────────────────────

final subscriptionApiService = SubscriptionApiService();
