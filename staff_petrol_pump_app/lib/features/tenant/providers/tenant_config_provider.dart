// ============================================================================
// Tenant Config Provider — Riverpod Provider for Plan Feature System v2
// (flutter_app variant - streamlined)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

// ── Types ───────────────────────────────────────────────────────────────────

class TenantConfig {
  final String tenantId;
  final String plan;
  final List<String> effectiveFeatures;
  final bool isLicenseValid;
  final DateTime fetchedAt;

  const TenantConfig({
    required this.tenantId,
    required this.plan,
    required this.effectiveFeatures,
    required this.isLicenseValid,
    required this.fetchedAt,
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return TenantConfig(
      tenantId: data['tenantId'] as String? ?? '',
      plan: data['plan'] as String? ?? 'basic',
      effectiveFeatures: (data['effectiveFeatures'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isLicenseValid: data['licenseStatus'] == 'active',
      fetchedAt: DateTime.now(),
    );
  }

  bool hasFeature(String key) => effectiveFeatures.contains(key);
}

class TenantConfigState {
  final TenantConfig? config;
  final bool isLoading;
  final String? error;

  const TenantConfigState({this.config, this.isLoading = false, this.error});
  const TenantConfigState.loading() : this(isLoading: true);
  const TenantConfigState.loaded(this.config) : isLoading = false, error = null;
}

// ── Configuration ──────────────────────────────────────────────────────────

const _pollIntervalSeconds = 45;

// ── Notifier ─────────────────────────────────────────────────────────────────

class TenantConfigNotifier extends StateNotifier<TenantConfigState> {
  Timer? _timer;
  bool _isDisposed = false;

  TenantConfigNotifier() : super(const TenantConfigState.loading()) {
    _init();
  }

  Future<void> _init() async {
    await refresh();
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: _pollIntervalSeconds),
      (_) => refresh(),
    );
  }

  Future<void> refresh() async {
    if (_isDisposed || state.isLoading) return;

    state = const TenantConfigState.loading();

    try {
      final config = await _fetch();
      if (!_isDisposed) {
        state = TenantConfigState.loaded(config);
      }
    } catch (e) {
      if (!_isDisposed) {
        state = TenantConfigState(error: e.toString(), config: state.config);
      }
    }
  }

  Future<TenantConfig> _fetch() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/tenant/config');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return TenantConfig.fromJson(jsonDecode(response.body));
    }
    throw HttpException('Config fetch failed: ${response.statusCode}');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final tenantConfigProvider =
    StateNotifierProvider<TenantConfigNotifier, TenantConfigState>((ref) {
  return TenantConfigNotifier();
});

final tenantConfigValueProvider = Provider<TenantConfig?>((ref) {
  return ref.watch(tenantConfigProvider).config;
});

final featureEnabledProvider = Provider.family<bool, String>((ref, key) {
  final config = ref.watch(tenantConfigValueProvider);
  return config?.hasFeature(key) ?? false;
});
