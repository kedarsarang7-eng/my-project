// ============================================================================
// WhatsApp Config Provider — AsyncNotifier for automation config state
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../providers/tenant_config_provider.dart';
import '../../data/models/automation_config_model.dart';
import '../../data/repositories/whatsapp_automation_repository.dart';

// ── Feature key ──────────────────────────────────────────────────────────────

const String waFeatureKey = 'whatsapp_automation';

// ── State ────────────────────────────────────────────────────────────────────

class WhatsAppConfigState {
  final AutomationConfig? config;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const WhatsAppConfigState({
    this.config,
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  WhatsAppConfigState copyWith({
    AutomationConfig? config,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return WhatsAppConfigState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WhatsAppConfigNotifier extends StateNotifier<WhatsAppConfigState> {
  final Ref _ref;
  late final WhatsAppAutomationRepository _repo;

  WhatsAppConfigNotifier(this._ref)
    : super(const WhatsAppConfigState(isLoading: true)) {
    _repo = WhatsAppAutomationRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppConfigState(isDisabled: true);
      return;
    }
    loadConfig();
  }

  Future<void> loadConfig() async {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppConfigState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final config = await _repo.getConfig();
      state = WhatsAppConfigState(config: config);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateConfig(Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await _repo.updateConfig(updates);
      state = WhatsAppConfigState(config: updated);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final whatsappConfigProvider =
    StateNotifierProvider<WhatsAppConfigNotifier, WhatsAppConfigState>((ref) {
      return WhatsAppConfigNotifier(ref);
    });
