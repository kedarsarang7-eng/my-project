import 'package:flutter/foundation.dart';

/// Cached subscription view used for plan gating (license row + decoded flags).
@immutable
class LicenseSnapshot {
  final String planTier;
  final Map<String, dynamic> featureFlags;
  final String? planStatus;
  final DateTime? trialEndDate;
  final Map<String, dynamic> limits;

  const LicenseSnapshot({
    required this.planTier,
    required this.featureFlags,
    this.planStatus,
    this.trialEndDate,
    this.limits = const {},
  });

  /// Create an unrestricted snapshot (fallback when no data available)
  factory LicenseSnapshot.unrestricted() {
    return const LicenseSnapshot(
      planTier: 'enterprise',
      featureFlags: {},
      planStatus: 'active',
      limits: {},
    );
  }

  bool explicitUnlock(String key) {
    final v = featureFlags[key];
    if (v == true || v == 1 || v == 'true') return true;
    return false;
  }

  /// Check if currently in trial period
  bool get isInTrial => planStatus == 'trial';

  /// Days remaining until trial expires
  int? get daysRemaining {
    if (trialEndDate == null) return null;
    final diff = trialEndDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Check if trial has expired
  bool get isTrialExpired {
    if (trialEndDate == null) return false;
    return DateTime.now().isAfter(trialEndDate!);
  }
}
