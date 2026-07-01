import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/service_locator.dart';
import '../core/licensing/license_feature_access.dart';
import '../core/licensing/license_snapshot.dart';
import '../core/licensing/plan_context_cache.dart';
import '../services/license_service.dart';
import '../core/api/api_client.dart';

/// Provider that fetches license info with offline cache fallback
final licenseSnapshotProvider = FutureProvider<LicenseSnapshot>((ref) async {
  final ls = sl<LicenseService>();
  final api = sl<ApiClient>();

  try {
    // Try to fetch fresh data from API
    final response = await api.get('/manifest');

    if (response.isSuccess && response.data != null) {
      final manifest = response.data!['manifest'] as Map<String, dynamic>;

      // Create snapshot from API response
      final snapshot = LicenseSnapshot(
        planTier: manifest['planTier'] ?? 'basic',
        featureFlags: Map<String, dynamic>.from(manifest['allowedFeatures'] ?? {}),
        planStatus: manifest['planStatus'] ?? 'active',
        trialEndDate: manifest['trialEndDate'] != null
            ? DateTime.parse(manifest['trialEndDate'])
            : null,
        limits: Map<String, dynamic>.from(manifest['limits'] ?? {}),
      );

      // Save to cache for offline use
      final cacheContext = CachedPlanContext.fromApiResponse(
        {
          'planTier': snapshot.planTier,
          'planStatus': snapshot.planStatus,
          'trialEndDate': snapshot.trialEndDate?.toIso8601String(),
          'featureFlags': snapshot.featureFlags,
          'limits': snapshot.limits,
        },
        manifest['businessType'] ?? 'grocery',
      );
      await planContextCache.save(cacheContext);

      return snapshot;
    }
  } catch (e) {
    // API call failed - will fall back to cache
  }

  // Fallback to legacy license service
  try {
    final info = await ls.getLicenseInfo();
    final flags = await ls.getDecodedFeatureFlags();
    final tier = (info?['planType'] as String?)?.trim();

    final snapshot = LicenseSnapshot(
      planTier: (tier != null && tier.isNotEmpty) ? tier : 'basic',
      featureFlags: flags,
      planStatus: info?['planStatus'] as String?,
      trialEndDate: info?['trialEndDate'] != null
          ? DateTime.parse(info!['trialEndDate'])
          : null,
      limits: Map<String, dynamic>.from(info?['limits'] ?? {}),
    );

    return snapshot;
  } catch (e) {
    // Both API and legacy failed - use cache
    final cached = planContextCache.load();
    if (cached != null) {
      return LicenseSnapshot(
        planTier: cached.planTier,
        featureFlags: cached.featureFlags,
        planStatus: cached.planStatus,
        trialEndDate: cached.trialEndDate,
        limits: cached.limits,
      );
    }

    // Complete fallback - unrestricted
    return LicenseSnapshot.unrestricted();
  }
});

final licenseFeatureAccessProvider = Provider<LicenseFeatureAccess>((ref) {
  final asyncSnap = ref.watch(licenseSnapshotProvider);
  return asyncSnap.when(
    data: LicenseFeatureAccess.fromSnapshot,
    loading: () {
      // Try cache first while loading
      final cached = planContextCache.load();
      if (cached != null) {
        final snapshot = LicenseSnapshot(
          planTier: cached.planTier,
          featureFlags: cached.featureFlags,
          planStatus: cached.planStatus,
          trialEndDate: cached.trialEndDate,
          limits: cached.limits,
        );
        return LicenseFeatureAccess.fromSnapshot(snapshot);
      }
      return LicenseFeatureAccess.unrestricted();
    },
    error: (_, _) {
      // Use cache on error for offline support
      final cached = planContextCache.load();
      if (cached != null) {
        final snapshot = LicenseSnapshot(
          planTier: cached.planTier,
          featureFlags: cached.featureFlags,
          planStatus: cached.planStatus,
          trialEndDate: cached.trialEndDate,
          limits: cached.limits,
        );
        return LicenseFeatureAccess.fromSnapshot(snapshot);
      }
      return LicenseFeatureAccess.unrestricted();
    },
  );
});
