// ============================================================================
// Plan Context Cache — Offline-First Plan State Management
// ============================================================================
// Caches plan context locally with 24-hour TTL for offline support.
// Features:
//   - Hive-based persistent storage
//   - 24-hour cache expiry
//   - Silent background refresh
//   - Graceful degradation when offline
//
// Used by: license_snapshot_provider.dart
// ============================================================================

import 'package:hive_flutter/hive_flutter.dart';
import '../services/logger_service.dart';

/// Cached plan context with TTL
class CachedPlanContext {
  final String planTier;
  final String businessType;
  final String planStatus;
  final DateTime? trialEndDate;
  final Map<String, dynamic> featureFlags;
  final Map<String, dynamic> limits;
  final DateTime cachedAt;
  final DateTime expiresAt;

  CachedPlanContext({
    required this.planTier,
    required this.businessType,
    required this.planStatus,
    this.trialEndDate,
    required this.featureFlags,
    required this.limits,
    required this.cachedAt,
    required this.expiresAt,
  });

  /// Check if cache is still valid (not expired)
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Days remaining until trial expires (if in trial)
  int? get daysRemaining {
    if (trialEndDate == null || planStatus != 'trial') return null;
    final diff = trialEndDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Convert to JSON for Hive storage
  Map<String, dynamic> toJson() => {
        'planTier': planTier,
        'businessType': businessType,
        'planStatus': planStatus,
        'trialEndDate': trialEndDate?.toIso8601String(),
        'featureFlags': featureFlags,
        'limits': limits,
        'cachedAt': cachedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  /// Create from JSON (Hive storage)
  factory CachedPlanContext.fromJson(Map<String, dynamic> json) {
    return CachedPlanContext(
      planTier: json['planTier'] ?? json['tier'] ?? 'basic',
      businessType: json['businessType'] ?? 'grocery',
      planStatus: json['planStatus'] ?? 'active',
      trialEndDate: json['trialEndDate'] != null
          ? DateTime.parse(json['trialEndDate'])
          : null,
      featureFlags: Map<String, dynamic>.from(json['featureFlags'] ?? json['allowedFeatures'] ?? json['feature_flags'] ?? {}),
      limits: Map<String, dynamic>.from(json['limits'] ?? {}),
      cachedAt: DateTime.parse(json['cachedAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  /// Create from API response
  factory CachedPlanContext.fromApiResponse(
    Map<String, dynamic> response,
    String businessType,
  ) {
    final now = DateTime.now();
    return CachedPlanContext(
      planTier: response['planTier'] ?? response['tier'] ?? response['plan'] ?? 'basic',
      businessType: businessType,
      planStatus: response['planStatus'] ?? 'active',
      trialEndDate: response['trialEndDate'] != null
          ? DateTime.parse(response['trialEndDate'])
          : null,
      featureFlags: Map<String, dynamic>.from(response['featureFlags'] ?? response['allowedFeatures'] ?? response['feature_flags'] ?? {}),
      limits: Map<String, dynamic>.from(response['limits'] ?? {}),
      cachedAt: now,
      expiresAt: now.add(const Duration(hours: 24)), // 24-hour TTL
    );
  }
}

/// Plan Context Cache Manager
class PlanContextCache {
  static const String _boxName = 'plan_context_cache';
  static const String _cacheKey = 'current_plan_context';
  static const String _lastSyncKey = 'last_plan_sync';

  Box<dynamic>? _box;

  /// Initialize Hive box
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_boxName);
      LoggerService.d('PlanContext', '[PlanContextCache] Initialized');
    } catch (e) {
      LoggerService.d('PlanContext', '[PlanContextCache] Failed to initialize: $e');
    }
  }

  /// Save plan context to cache
  Future<void> save(CachedPlanContext context) async {
    if (_box == null) return;
    try {
      await _box!.put(_cacheKey, context.toJson());
      await _box!.put(_lastSyncKey, DateTime.now().toIso8601String());
      LoggerService.d('PlanContext', '[PlanContextCache] Saved plan context: ${context.planTier}');
    } catch (e) {
      LoggerService.d('PlanContext', '[PlanContextCache] Failed to save: $e');
    }
  }

  /// Load plan context from cache
  CachedPlanContext? load() {
    if (_box == null) return null;
    try {
      final json = _box!.get(_cacheKey);
      if (json == null) return null;

      final context = CachedPlanContext.fromJson(Map<String, dynamic>.from(json));

      // Check if cache is expired
      if (!context.isValid) {
        LoggerService.d('PlanContext', '[PlanContextCache] Cache expired');
        return null;
      }

      LoggerService.d('PlanContext', '[PlanContextCache] Loaded valid cache: ${context.planTier}');
      return context;
    } catch (e) {
      LoggerService.d('PlanContext', '[PlanContextCache] Failed to load: $e');
      return null;
    }
  }

  /// Check if we have a valid cached context
  bool get hasValidCache {
    final context = load();
    return context != null && context.isValid;
  }

  /// Get last sync time
  DateTime? get lastSync {
    if (_box == null) return null;
    final str = _box!.get(_lastSyncKey);
    if (str == null) return null;
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  /// Check if cache is stale (older than 24 hours)
  bool get isStale {
    final last = lastSync;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= 24;
  }

  /// Clear cache
  Future<void> clear() async {
    if (_box == null) return;
    await _box!.delete(_cacheKey);
    await _box!.delete(_lastSyncKey);
    LoggerService.d('PlanContext', '[PlanContextCache] Cache cleared');
  }

  /// Get trial status from cache
  TrialStatus? getTrialStatus() {
    final context = load();
    if (context == null) return null;

    return TrialStatus(
      isInTrial: context.planStatus == 'trial',
      daysRemaining: context.daysRemaining ?? 0,
      trialEndDate: context.trialEndDate,
      planStatus: context.planStatus,
    );
  }
}

/// Trial status information
class TrialStatus {
  final bool isInTrial;
  final int daysRemaining;
  final DateTime? trialEndDate;
  final String planStatus;

  TrialStatus({
    required this.isInTrial,
    required this.daysRemaining,
    this.trialEndDate,
    required this.planStatus,
  });

  /// Get display message for trial banner
  String get displayMessage {
    if (!isInTrial) return '';
    if (daysRemaining <= 0) return 'Your trial has expired';
    if (daysRemaining == 1) return '1 day left in your trial';
    return '$daysRemaining days left in your trial';
  }

  /// Get urgency level for UI coloring
  TrialUrgency get urgency {
    if (!isInTrial) return TrialUrgency.none;
    if (daysRemaining <= 1) return TrialUrgency.critical;
    if (daysRemaining <= 3) return TrialUrgency.high;
    if (daysRemaining <= 7) return TrialUrgency.medium;
    return TrialUrgency.low;
  }
}

enum TrialUrgency { none, low, medium, high, critical }

/// Singleton instance
final planContextCache = PlanContextCache();
