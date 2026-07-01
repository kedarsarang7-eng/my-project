// ignore_for_file: unused_element
// ============================================================================
// Tenant Config Provider — Riverpod Provider for Plan Feature System v2
// ============================================================================
// Fetches unified tenant config from GET /tenant/config and provides:
//   - Plan tier, license status, expiry
//   - Effective features list (derived from PlanConfig + manualOverrides)
//   - Limits (maxUsers, storageLimitGB, apiRateLimit, etc.)
//   - Manifest JWT token
//
// Architecture:
//   - Polls /tenant/config every 45 seconds (configurable)
//   - Listens for WebSocket 'manifest_invalidated' events
//   - Caches response in memory + SecureStorage
//   - Falls back to cached data on network failure
//
// Usage:
//   final config = ref.watch(tenantConfigProvider);
//   final features = ref.watch(effectiveFeaturesProvider);
//   final hasApi = ref.watch(featureEnabledProvider('api_access'));
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../core/di/service_locator.dart';
import '../core/services/logger_service.dart';
import '../services/websocket_service.dart';

// ── Type Definitions ───────────────────────────────────────────────────────

/// Unified tenant config response from /tenant/config endpoint
class TenantConfig {
  final String tenantId;
  final String licenseKey;
  final String plan;
  final String businessType;
  final String licenseStatus;
  final DateTime? licenseExpiry;
  final List<String> effectiveFeatures;
  final TenantLimits limits;
  final String manifestToken;
  final Map<String, dynamic> manualOverrides;
  final DateTime fetchedAt;

  const TenantConfig({
    required this.tenantId,
    required this.licenseKey,
    required this.plan,
    required this.businessType,
    required this.licenseStatus,
    this.licenseExpiry,
    required this.effectiveFeatures,
    required this.limits,
    required this.manifestToken,
    required this.manualOverrides,
    required this.fetchedAt,
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return TenantConfig(
      tenantId: data['tenantId'] as String? ?? '',
      licenseKey: data['licenseKey'] as String? ?? '',
      plan: data['plan'] as String? ?? 'basic',
      businessType: data['businessType'] as String? ?? 'general',
      licenseStatus: data['licenseStatus'] as String? ?? 'active',
      licenseExpiry: data['licenseExpiry'] != null
          ? DateTime.tryParse(data['licenseExpiry'] as String)
          : null,
      effectiveFeatures: (data['effectiveFeatures'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      limits: TenantLimits.fromJson(data['limits'] as Map<String, dynamic>? ?? {}),
      manifestToken: data['manifestToken'] as String? ?? '',
      manualOverrides: data['manualOverrides'] as Map<String, dynamic>? ?? const {},
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'tenantId': tenantId,
        'licenseKey': licenseKey,
        'plan': plan,
        'businessType': businessType,
        'licenseStatus': licenseStatus,
        'licenseExpiry': licenseExpiry?.toIso8601String(),
        'effectiveFeatures': effectiveFeatures,
        'limits': limits.toJson(),
        'manifestToken': manifestToken,
        'manualOverrides': manualOverrides,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  /// Check if a specific feature is enabled
  bool hasFeature(String featureKey) => effectiveFeatures.contains(featureKey);

  /// Check if license is valid and not expired
  bool get isLicenseValid =>
      licenseStatus.toLowerCase() == 'active' &&
      (licenseExpiry == null || licenseExpiry!.isAfter(DateTime.now()));
}

/// Tenant limits from the config
class TenantLimits {
  final int maxUsers;
  final int maxProducts;
  final int maxBranches;
  final int maxDevices;
  final int maxBusinessTypes;
  final int? storageLimitGB;
  final int? apiRateLimit;

  const TenantLimits({
    required this.maxUsers,
    required this.maxProducts,
    required this.maxBranches,
    required this.maxDevices,
    required this.maxBusinessTypes,
    this.storageLimitGB,
    this.apiRateLimit,
  });

  factory TenantLimits.fromJson(Map<String, dynamic> json) {
    return TenantLimits(
      maxUsers: json['maxUsers'] as int? ?? 3,
      maxProducts: json['maxProducts'] as int? ?? 500,
      maxBranches: json['maxBranches'] as int? ?? 1,
      maxDevices: json['maxDevices'] as int? ?? 1,
      maxBusinessTypes: json['maxBusinessTypes'] as int? ?? 1,
      storageLimitGB: json['storageLimitGB'] as int?,
      apiRateLimit: json['apiRateLimit'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxUsers': maxUsers,
        'maxProducts': maxProducts,
        'maxBranches': maxBranches,
        'maxDevices': maxDevices,
        'maxBusinessTypes': maxBusinessTypes,
        'storageLimitGB': storageLimitGB,
        'apiRateLimit': apiRateLimit,
      };
}

// ── State Definitions ──────────────────────────────────────────────────────

/// Async state for tenant config
class TenantConfigState {
  final TenantConfig? config;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetch;

  const TenantConfigState({
    this.config,
    this.isLoading = false,
    this.error,
    this.lastFetch,
  });

  const TenantConfigState.loading()
      : config = null,
        isLoading = true,
        error = null,
        lastFetch = null;

  const TenantConfigState.loaded(this.config)
      : isLoading = false,
        error = null,
        lastFetch = null;

  const TenantConfigState.error(this.error, {this.config, this.lastFetch})
      : isLoading = false;

  bool get hasData => config != null;

  TenantConfigState copyWith({
    TenantConfig? config,
    bool? isLoading,
    String? error,
    DateTime? lastFetch,
  }) {
    return TenantConfigState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetch: lastFetch ?? this.lastFetch,
    );
  }
}

// ── Configuration ──────────────────────────────────────────────────────────

const _pollIntervalSeconds = 45;
const _cacheKey = 'tenant_config_v1';
const _minBackoffSeconds = 5;
const _maxBackoffSeconds = 300;

// ── Notifier Implementation ────────────────────────────────────────────────

class TenantConfigNotifier extends Notifier<TenantConfigState> with WidgetsBindingObserver {
  Timer? _pollTimer;
  int _consecutiveErrors = 0;
  bool _isDisposed = false;
  static const _storage = FlutterSecureStorage();

  @override
  TenantConfigState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _isDisposed = true;
      _pollTimer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    _init();
    return const TenantConfigState.loading();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _pollTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      refresh().then((_) => _startPolling());
    }
  }

  Future<void> _init() async {
    // Load cached config first
    await _loadCachedConfig();
    
    // Then fetch fresh
    await refresh();

    // Start polling
    _startPolling();

    // Subscribe to WebSocket events
    _subscribeToWebSocket();
  }

  /// Load cached config from SecureStorage for fast startup and offline fallback.
  Future<void> _loadCachedConfig() async {
    try {
      final raw = await _storage.read(key: _cacheKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cached = TenantConfig.fromJson(json);
      if (!_isDisposed) {
        state = TenantConfigState.loaded(cached);
        LoggerService.d('TenantConfig', 'Loaded tenant config from cache (plan=${cached.plan})');
      }
    } catch (e) {
      LoggerService.d('TenantConfig', 'Failed to load cached tenant config: $e');
    }
  }

  /// Start periodic polling every 45 seconds
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: _pollIntervalSeconds),
      (_) => refresh(),
    );
  }

  /// Subscribe to WebSocket manifest_invalidated events
  void _subscribeToWebSocket() {
    try {
      final wsService = sl<WebSocketService>();
      wsService.subscribe('manifest_invalidated', _onManifestInvalidated);
    } catch (e) {
      LoggerService.d('TenantConfig', 'WebSocket not available for tenant config, using poll only');
    }
  }

  /// Handle manifest_invalidated WebSocket event
  void _onManifestInvalidated(WSEvent event) {
    LoggerService.d('TenantConfig', 'Received manifest_invalidated, refreshing tenant config');
    
    // Cancel existing poll timer and refresh immediately
    _pollTimer?.cancel();
    refresh().then((_) => _startPolling());
  }

  /// Fetch fresh config from /tenant/config endpoint
  Future<void> refresh() async {
    if (_isDisposed) return;

    // Prevent concurrent fetches
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final config = await _fetchConfig();
      _consecutiveErrors = 0;
      
      if (!_isDisposed) {
        state = TenantConfigState.loaded(config);
        _persistToCache(config);
      }
    } catch (e) {
      _consecutiveErrors++;
      final backoff = _calculateBackoff();
      
      LoggerService.d('TenantConfig', 'Failed to fetch tenant config: ${e.toString()} (errors: $_consecutiveErrors, backoff: ${backoff}s)');

      if (!_isDisposed) {
        state = TenantConfigState.error(
          'Failed to refresh config (retry in ${backoff}s)',
          config: state.config, // Keep existing data
          lastFetch: state.lastFetch,
        );
      }
    }
  }

  /// Calculate exponential backoff
  int _calculateBackoff() {
    final backoff = _minBackoffSeconds * (1 << _consecutiveErrors.clamp(0, 5));
    return backoff.clamp(_minBackoffSeconds, _maxBackoffSeconds);
  }

  /// HTTP GET /tenant/config
  Future<TenantConfig> _fetchConfig() async {
    final baseUrl = ApiConfig.baseUrl;
    final url = Uri.parse('$baseUrl/tenant/config');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Auth token will be added by interceptor or middleware
        if (sl.isRegistered<AuthTokenProvider>())
          'Authorization': 'Bearer ${sl<AuthTokenProvider>().token}',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TenantConfig.fromJson(json);
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Authentication required for tenant config');
    } else {
      throw HttpException(
        'Failed to fetch tenant config: ${response.statusCode}',
        uri: url,
      );
    }
  }

  /// Force refresh (public API)
  Future<void> forceRefresh() async {
    _consecutiveErrors = 0;
    await refresh();
  }

  Future<void> _persistToCache(TenantConfig config) async {
    try {
      await _storage.write(key: _cacheKey, value: jsonEncode(config.toJson()));
    } catch (e) {
      LoggerService.d('TenantConfig', 'Failed to persist tenant config to cache: $e');
    }
  }

}

// ── Provider Exports ───────────────────────────────────────────────────────

/// Main tenant config provider (async state)
final tenantConfigProvider =
    NotifierProvider<TenantConfigNotifier, TenantConfigState>(
  TenantConfigNotifier.new,
);

/// Simplified provider that just returns the config (or null)
final tenantConfigValueProvider = Provider<TenantConfig?>((ref) {
  final state = ref.watch(tenantConfigProvider);
  return state.config;
});

/// Provider for effective features list
final effectiveFeaturesProvider = Provider<Set<String>>((ref) {
  final config = ref.watch(tenantConfigValueProvider);
  return config?.effectiveFeatures.toSet() ?? const {};
});

/// Provider to check if a specific feature is enabled
/// Usage: ref.watch(featureEnabledProvider('api_access'))
final featureEnabledProvider = Provider.family<bool, String>((ref, featureKey) {
  final features = ref.watch(effectiveFeaturesProvider);
  return features.contains(featureKey);
});

/// Provider for tenant limits
final tenantLimitsProvider = Provider<TenantLimits>((ref) {
  final config = ref.watch(tenantConfigValueProvider);
  return config?.limits ?? const TenantLimits(
    maxUsers: 3,
    maxProducts: 500,
    maxBranches: 1,
    maxDevices: 1,
    maxBusinessTypes: 1,
  );
});

/// Provider for license validity
final licenseValidProvider = Provider<bool>((ref) {
  final config = ref.watch(tenantConfigValueProvider);
  return config?.isLicenseValid ?? false;
});

/// Provider for plan tier string
final planTierStringProvider = Provider<String>((ref) {
  final config = ref.watch(tenantConfigValueProvider);
  return config?.plan ?? 'basic';
});

// ── Exception Classes ──────────────────────────────────────────────────────

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => 'UnauthorizedException: $message';
}

// ── Placeholder for AuthTokenProvider (to be implemented based on auth system)

abstract class AuthTokenProvider {
  String get token;
}
