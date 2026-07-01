// ============================================================================
// Feature Flag Service — Centralized plan-based feature gating
// ============================================================================
// Reads feature_flags from cached license payload.
// Plan tier (basic/pro/premium) is determined by Super Admin at license
// generation time and validated by AWS DynamoDB.
//
// Usage:
//   final flagService = sl<FeatureFlagService>();
//   if (await flagService.isEnabled('inventory_module')) { ... }
// ============================================================================

import '../../../core/di/service_locator.dart';
import '../../../core/services/logger_service.dart';
import 'license_service.dart';

/// Centralized feature flag service — reads from cached license payload
///
/// All flags are set by Super Admin via DynamoDB.
/// Frontend never determines plan — it only reads.
class FeatureFlagService {
  final LicenseService _licenseService;

  FeatureFlagService({LicenseService? licenseService})
      : _licenseService = licenseService ?? sl<LicenseService>();

  /// Check if feature flag is enabled
  ///
  /// Returns true if flag exists and is truthy (true, 1, "true", non-empty string)
  Future<bool> isEnabled(String flag) async {
    final flags = await getAllFlags();
    final value = flags[flag];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value > 0;
    if (value is String) return value.isNotEmpty && value.toLowerCase() != 'false';
    return false;
  }

  /// Get integer value for flag (e.g., max_users, max_branches)
  Future<int?> getIntValue(String flag) async {
    final flags = await getAllFlags();
    final value = flags[flag];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Get string value for flag
  Future<String?> getStringValue(String flag) async {
    final flags = await getAllFlags();
    final value = flags[flag];
    return value?.toString();
  }

  /// Get all feature flags from cached license
  Future<Map<String, dynamic>> getAllFlags() async {
    try {
      final info = await _licenseService.getLicenseInfo();
      if (info == null) return {};

      final modulesJson = info['enabledModules'];
      if (modulesJson is List) {
        // Legacy format: list of module codes ? convert to bool map
        return {for (final m in modulesJson) m.toString(): true};
      }
      if (modulesJson is Map) {
        return Map<String, dynamic>.from(modulesJson);
      }
      return {};
    } catch (e) {
      LoggerService.d('FeatureFlag', 'FeatureFlagService: Error reading flags: $e');
      return {};
    }
  }

  /// Get current plan tier from cached license
  ///
  /// Returns: 'basic', 'pro', 'premium', 'enterprise', or null if no license
  Future<String?> getCurrentPlanTier() async {
    try {
      final info = await _licenseService.getLicenseInfo();
      if (info == null) return null;
      // F013: Subscription API returns field as 'plan' (not 'planType').
      // Check 'plan' first, fall back to 'planType' for legacy license payloads.
      return (info['plan'] as String?) ?? (info['planType'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// Check if current plan is at least the required tier
  ///
  /// Tier hierarchy: basic < pro < premium < enterprise
  Future<bool> hasPlanTier(String requiredTier) async {
    final current = await getCurrentPlanTier();
    if (current == null) return false;

    const tierRank = {'basic': 0, 'pro': 1, 'premium': 2, 'enterprise': 3};
    final currentRank = tierRank[current.toLowerCase()] ?? 0;
    final requiredRank = tierRank[requiredTier.toLowerCase()] ?? 0;
    return currentRank >= requiredRank;
  }
}
