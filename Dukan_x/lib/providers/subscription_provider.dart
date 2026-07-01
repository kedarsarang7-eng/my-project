// ============================================================================
// Subscription Provider — Riverpod State Management
// ============================================================================
// Manages subscription state with:
// - Auto-refresh on app start
// - Background sync
// - Offline caching via Hive
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import '../services/subscription_api_service.dart';
import '../core/licensing/plan_context_cache.dart';
import 'license_snapshot_provider.dart';

// ── Provider Definitions ───────────────────────────────────────────────────

/// Main subscription state provider
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, Subscription?>((ref) {
      return SubscriptionNotifier(ref);
    });

/// Subscription loading state
final subscriptionLoadingProvider = StateProvider<bool>((ref) => false);

/// Subscription error state
final subscriptionErrorProvider = StateProvider<String?>((ref) => null);

/// Usage statistics provider (separate for granular updates)
final usageStatsProvider = FutureProvider<UsageResult?>((ref) async {
  try {
    return await subscriptionApiService.getUsageStats();
  } catch (e) {
    return null;
  }
});

// ── Notifier Implementation ────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<Subscription?> {
  final Ref _ref;
  late Box _cacheBox;
  bool _initialized = false;

  SubscriptionNotifier(this._ref) : super(null) {
    _init();
  }

  Future<void> _init() async {
    await _initCache();
    await _loadFromCache();
    await refresh(); // Fetch fresh data
  }

  Future<void> _initCache() async {
    if (!Hive.isBoxOpen('subscription_cache')) {
      _cacheBox = await Hive.openBox('subscription_cache');
    } else {
      _cacheBox = Hive.box('subscription_cache');
    }
    _initialized = true;
  }

  Future<void> _loadFromCache() async {
    if (!_initialized) return;

    try {
      final cached = _cacheBox.get('subscription');
      if (cached != null) {
        final cacheTime = DateTime.parse(cached['cachedAt']);
        // F012: Reduce TTL to 15 minutes so plan upgrades reflect quickly
        final isStale = DateTime.now().difference(cacheTime).inMinutes > 15;

        if (!isStale) {
          state = Subscription.fromJson(cached['data']);
        }
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  Future<void> _saveToCache(Subscription subscription) async {
    if (!_initialized) return;

    try {
      await _cacheBox.put('subscription', {
        'data': _subscriptionToJson(subscription),
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Refresh subscription data from API
  Future<void> refresh() async {
    try {
      final subscription = await subscriptionApiService
          .getCurrentSubscription();
      state = subscription;
      await _saveToCache(subscription);
    } catch (e) {
      // Keep existing state if refresh fails (offline mode)
      rethrow;
    }
  }

  /// Perform plan upgrade
  Future<UpgradeResult> upgrade({
    required PlanTier targetPlan,
    required BillingCycle billingCycle,
  }) async {
    final result = await subscriptionApiService.upgradePlan(
      targetPlan: targetPlan,
      billingCycle: billingCycle,
    );

    // Clear stale plan cache and invalidate Riverpod provider so UI reflects new plan immediately.
    await planContextCache.clear();
    _ref.invalidate(licenseSnapshotProvider);
    await refresh();
    return result;
  }

  /// Perform plan downgrade
  Future<DowngradeResult> downgrade({
    required PlanTier targetPlan,
    required BillingCycle billingCycle,
  }) async {
    final result = await subscriptionApiService.downgradePlan(
      targetPlan: targetPlan,
      billingCycle: billingCycle,
    );

    // Clear stale plan cache and invalidate Riverpod provider so UI reflects new plan immediately.
    await planContextCache.clear();
    _ref.invalidate(licenseSnapshotProvider);
    await refresh();
    return result;
  }

  /// Check if feature is allowed (client-side check for UI)
  /// F011: Check the actual feature key against allowedFeatures list returned by API.
  /// Previous implementation ignored featureKey and always returned "is subscription active?".
  bool hasFeature(String featureKey) {
    if (state == null) return false;
    // If subscription is fully locked, no features
    if (state!.isLocked) return false;
    // Check allowedFeatures list from subscription API response
    if (state!.allowedFeatures != null) {
      return state!.allowedFeatures!.contains(featureKey);
    }
    // Fallback: trial/active with no feature list = allow all (safe default during migration)
    return state!.status == SubscriptionStatus.active ||
        state!.status == SubscriptionStatus.trial;
  }

  /// Check if user can perform write operations
  bool canWrite() {
    if (state == null) return false;
    return state!.canWrite;
  }

  /// Check if account is locked
  bool isLocked() {
    if (state == null) return false;
    return state!.isLocked;
  }

  /// Get days until trial expiry
  int? get daysUntilTrialExpiry => state?.daysUntilTrialExpiry;

  Map<String, dynamic> _subscriptionToJson(Subscription subscription) {
    return {
      'plan': subscription.plan.name,
      'billingCycle': subscription.billingCycle.name,
      'status': subscription.status.name,
      'planStartDate': subscription.planStartDate.toIso8601String(),
      'planEndDate': subscription.planEndDate?.toIso8601String(),
      'trialEndDate': subscription.trialEndDate?.toIso8601String(),
      'gracePeriodEndDate': subscription.gracePeriodEndDate?.toIso8601String(),
      'nextBillingDate': subscription.nextBillingDate?.toIso8601String(),
    };
  }
}

// ── Extension for easier provider access ───────────────────────────────────
extension SubscriptionProviderExtension on WidgetRef {
  Subscription? get subscription => read(subscriptionProvider);
  bool get canWrite => read(subscriptionProvider)?.canWrite ?? false;
  bool get isLocked => read(subscriptionProvider)?.isLocked ?? false;
}
