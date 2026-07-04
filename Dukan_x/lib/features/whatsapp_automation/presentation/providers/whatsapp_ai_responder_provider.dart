// ============================================================================
// WhatsApp AI Responder Provider — StateNotifier for AI response settings
// ============================================================================
// Feature-gated via BOTH:
//   1. waFeatureKey ('whatsapp_automation') — base WA feature must be enabled
//   2. waAiResponderFeatureKey ('wa_ai_responder') — Enterprise-only AI cap
//
// When WA_AI_RESPONDER is OFF:
//   - State is set to disabled/unavailable
//   - No AI content is generated, returned, or stored (Req 15.2, 15.3)
//   - UI renders explicit "unavailable" indicator (Req 15.5)
//
// Requirements: 1.5, 11.10, 15.2, 15.3, 15.6
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../providers/tenant_config_provider.dart';
import '../../data/models/ai_responder_settings_model.dart';
import '../../data/repositories/whatsapp_automation_repository.dart';
import 'whatsapp_config_provider.dart';

// ── Feature key for AI Responder (Enterprise-only) ───────────────────────────

const String waAiResponderFeatureKey = 'wa_ai_responder';

// ── State ────────────────────────────────────────────────────────────────────

/// Represents the current state of the AI responder capability.
///
/// When [isDisabled] is true, the AI responder feature is not granted to
/// this business (either base WA is OFF or AI tier is not included).
/// No AI content is ever generated/returned in the disabled state.
class WhatsAppAiResponderState {
  /// AI responder settings when available.
  final AiResponderSettings? settings;

  /// Whether data is currently being fetched.
  final bool isLoading;

  /// Whether the AI responder capability is disabled for this business.
  /// When true, no AI content is generated/returned/stored (Req 15.2).
  final bool isDisabled;

  /// Error message from the last failed operation.
  final String? error;

  const WhatsAppAiResponderState({
    this.settings,
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  WhatsAppAiResponderState copyWith({
    AiResponderSettings? settings,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return WhatsAppAiResponderState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WhatsAppAiResponderNotifier
    extends StateNotifier<WhatsAppAiResponderState> {
  final Ref _ref;
  late final WhatsAppAutomationRepository _repo;

  WhatsAppAiResponderNotifier(this._ref)
    : super(const WhatsAppAiResponderState(isLoading: true)) {
    _repo = WhatsAppAutomationRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    // Gate 1: Base WhatsApp feature must be enabled
    final waEnabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!waEnabled) {
      state = const WhatsAppAiResponderState(isDisabled: true);
      return;
    }

    // Gate 2: AI Responder capability must be granted (Enterprise tier)
    final aiEnabled = _ref.read(
      featureEnabledProvider(waAiResponderFeatureKey),
    );
    if (!aiEnabled) {
      state = const WhatsAppAiResponderState(isDisabled: true);
      return;
    }

    loadSettings();
  }

  /// Load AI responder settings from the backend.
  /// Returns disabled state if either feature gate is OFF.
  Future<void> loadSettings() async {
    // Re-check feature gates on every load to handle dynamic tier changes
    final waEnabled = _ref.read(featureEnabledProvider(waFeatureKey));
    final aiEnabled = _ref.read(
      featureEnabledProvider(waAiResponderFeatureKey),
    );

    if (!waEnabled || !aiEnabled) {
      state = const WhatsAppAiResponderState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final settings = await _repo.getAiResponderSettings();
      state = WhatsAppAiResponderState(settings: settings);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update AI responder settings. Only callable when the feature is enabled.
  /// When disabled, this is a no-op (Req 15.2 — capabilities not granted
  /// are neither shown nor executed).
  Future<bool> updateSettings(Map<String, dynamic> updates) async {
    final waEnabled = _ref.read(featureEnabledProvider(waFeatureKey));
    final aiEnabled = _ref.read(
      featureEnabledProvider(waAiResponderFeatureKey),
    );

    if (!waEnabled || !aiEnabled) {
      // Feature not granted — silently refuse (Req 1.5, 15.2)
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await _repo.updateAiResponderSettings(updates);
      state = WhatsAppAiResponderState(settings: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Toggle AI auto-reply on/off. Only when enabled.
  Future<bool> toggleAutoReply(bool enabled) async {
    return updateSettings({'autoReplyEnabled': enabled});
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final whatsappAiResponderProvider =
    StateNotifierProvider<
      WhatsAppAiResponderNotifier,
      WhatsAppAiResponderState
    >((ref) {
      return WhatsAppAiResponderNotifier(ref);
    });

// ── Convenience Providers ────────────────────────────────────────────────────

/// Whether the AI responder is available (feature granted AND not disabled).
final isAiResponderAvailableProvider = Provider<bool>((ref) {
  final state = ref.watch(whatsappAiResponderProvider);
  return !state.isDisabled && state.settings != null;
});
