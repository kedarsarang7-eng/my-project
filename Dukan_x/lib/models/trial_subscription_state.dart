// ============================================================================
// Trial Subscription State — Dedicated model for trial system
// ============================================================================
// Maps the /tenant/subscription API response to strongly-typed Dart.
// Used by SubscriptionNotifier to drive trial banner + expiry gate.
// ============================================================================

class TrialSubscriptionState {
  final String tenantId;
  final String subscriptionStatus;
  final String? planId;
  final String businessType;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;
  final int? daysRemaining;
  final bool isInTrial;
  final bool isExpired;
  final bool isActive;
  final bool isSuspended;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final DateTime? upgradedAt;
  final String? rid;

  const TrialSubscriptionState({
    required this.tenantId,
    required this.subscriptionStatus,
    this.planId,
    this.businessType = 'other',
    this.trialStartDate,
    this.trialEndDate,
    this.daysRemaining,
    this.isInTrial = false,
    this.isExpired = false,
    this.isActive = false,
    this.isSuspended = false,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.upgradedAt,
    this.rid,
  });

  factory TrialSubscriptionState.fromJson(Map<String, dynamic> json) {
    return TrialSubscriptionState(
      tenantId: json['tenantId'] ?? '',
      subscriptionStatus: json['subscriptionStatus'] ?? 'TRIAL',
      planId: json['planId'],
      businessType: json['businessType'] ?? 'other',
      trialStartDate: _parseDate(json['trialStartDate']),
      trialEndDate: _parseDate(json['trialEndDate']),
      daysRemaining: json['daysRemaining'],
      isInTrial: json['isInTrial'] ?? false,
      isExpired: json['isExpired'] ?? false,
      isActive: json['isActive'] ?? false,
      isSuspended: json['isSuspended'] ?? false,
      subscriptionStartDate: _parseDate(json['subscriptionStartDate']),
      subscriptionEndDate: _parseDate(json['subscriptionEndDate']),
      upgradedAt: _parseDate(json['upgradedAt']),
      rid: json['rid'],
    );
  }

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'subscriptionStatus': subscriptionStatus,
    'planId': planId,
    'businessType': businessType,
    'trialStartDate': trialStartDate?.toIso8601String(),
    'trialEndDate': trialEndDate?.toIso8601String(),
    'daysRemaining': daysRemaining,
    'isInTrial': isInTrial,
    'isExpired': isExpired,
    'isActive': isActive,
    'isSuspended': isSuspended,
    'subscriptionStartDate': subscriptionStartDate?.toIso8601String(),
    'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
    'upgradedAt': upgradedAt?.toIso8601String(),
    'rid': rid,
  };

  /// Banner color: green > 7d, yellow 3–7d, red < 3d
  TrialBannerColor get bannerColor {
    if (!isInTrial || daysRemaining == null) return TrialBannerColor.none;
    if (daysRemaining! > 7) return TrialBannerColor.green;
    if (daysRemaining! >= 3) return TrialBannerColor.yellow;
    return TrialBannerColor.red;
  }

  /// Whether the app should show the full-screen expired gate
  bool get shouldShowExpiredGate => isExpired || isSuspended;

  /// Whether to allow any app features
  bool get canAccessApp => isInTrial || isActive;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

enum TrialBannerColor { none, green, yellow, red }
