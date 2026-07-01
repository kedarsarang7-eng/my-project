// ============================================================================
// Trial Subscription Provider — Riverpod State Management
// ============================================================================
// Manages trial state lifecycle:
// - Auto-refresh on app start
// - Hive offline caching with 5-minute TTL
// - Force refresh when backend says EXPIRED but cache says TRIAL
// - Provides computed properties for UI (banner color, gate display)
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import '../models/trial_subscription_state.dart';
import '../services/trial_subscription_service.dart';

// ── Provider Definitions ───────────────────────────────────────────────────

/// Main trial subscription state provider
final trialSubscriptionProvider =
    StateNotifierProvider<TrialSubscriptionNotifier, TrialSubscriptionState?>(
      (ref) => TrialSubscriptionNotifier(),
    );

/// Loading state
final trialLoadingProvider = StateProvider<bool>((ref) => false);

/// Error state
final trialErrorProvider = StateProvider<String?>((ref) => null);

// ── Notifier Implementation ────────────────────────────────────────────────

class TrialSubscriptionNotifier extends StateNotifier<TrialSubscriptionState?> {
  late Box _cacheBox;
  bool _initialized = false;

  TrialSubscriptionNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    await _initCache();
    await _loadFromCache();
    await refresh();
  }

  Future<void> _initCache() async {
    if (!Hive.isBoxOpen('trial_subscription_cache')) {
      _cacheBox = await Hive.openBox('trial_subscription_cache');
    } else {
      _cacheBox = Hive.box('trial_subscription_cache');
    }
    _initialized = true;
  }

  Future<void> _loadFromCache() async {
    if (!_initialized) return;
    try {
      final cached = _cacheBox.get('trial_state');
      if (cached != null) {
        final cacheTime = DateTime.parse(cached['cachedAt']);
        final isStale = DateTime.now().difference(cacheTime).inMinutes > 5;
        if (!isStale) {
          state = TrialSubscriptionState.fromJson(
            Map<String, dynamic>.from(cached['data']),
          );
        }
      }
    } catch (_) {
      // Ignore cache errors
    }
  }

  Future<void> _saveToCache(TrialSubscriptionState sub) async {
    if (!_initialized) return;
    try {
      await _cacheBox.put('trial_state', {
        'data': sub.toJson(),
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Ignore cache errors
    }
  }

  /// Refresh trial state from API
  Future<void> refresh() async {
    try {
      final freshState = await trialSubscriptionService.getSubscriptionState();

      // Edge case: if backend says EXPIRED but local cache says TRIAL
      // → force update immediately
      if (state != null && state!.isInTrial && freshState.isExpired) {
        // Clear stale cache
        if (_initialized) {
          await _cacheBox.delete('trial_state');
        }
      }

      state = freshState;
      await _saveToCache(freshState);
    } catch (e) {
      // Keep existing state if refresh fails (offline mode)
      rethrow;
    }
  }

  /// Force refresh — clears cache and fetches fresh
  Future<void> forceRefresh() async {
    if (_initialized) {
      await _cacheBox.delete('trial_state');
    }
    state = null;
    await refresh();
  }

  /// Perform upgrade
  Future<TrialSubscriptionState> upgrade({
    required String planId,
    required String paymentReference,
  }) async {
    final result = await trialSubscriptionService.upgradePlan(
      planId: planId,
      paymentReference: paymentReference,
    );
    state = result;
    await _saveToCache(result);
    return result;
  }

  // ── Computed Properties ──────────────────────────────────────────────────

  bool get isInTrial => state?.isInTrial ?? false;
  bool get isExpired => state?.isExpired ?? false;
  bool get isActive => state?.isActive ?? false;
  bool get canAccessApp => state?.canAccessApp ?? true;
  bool get shouldShowExpiredGate => state?.shouldShowExpiredGate ?? false;
  int? get daysRemaining => state?.daysRemaining;
  TrialBannerColor get bannerColor =>
      state?.bannerColor ?? TrialBannerColor.none;
}
