// ============================================================================
// WhatsApp Delivery Log Provider — AsyncNotifier for delivery log (read-only)
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../providers/tenant_config_provider.dart';
import '../../data/models/delivery_log_model.dart';
import '../../data/repositories/whatsapp_automation_repository.dart';
import 'whatsapp_config_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

class WhatsAppDeliveryLogState {
  final List<DeliveryLogEntry> entries;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const WhatsAppDeliveryLogState({
    this.entries = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  WhatsAppDeliveryLogState copyWith({
    List<DeliveryLogEntry>? entries,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return WhatsAppDeliveryLogState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WhatsAppDeliveryLogNotifier
    extends StateNotifier<WhatsAppDeliveryLogState> {
  final Ref _ref;
  late final WhatsAppAutomationRepository _repo;

  WhatsAppDeliveryLogNotifier(this._ref)
    : super(const WhatsAppDeliveryLogState(isLoading: true)) {
    _repo = WhatsAppAutomationRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppDeliveryLogState(isDisabled: true);
      return;
    }
    loadLogs();
  }

  Future<void> loadLogs({int? limit}) async {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppDeliveryLogState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final entries = await _repo.getDeliveryLogs(limit: limit ?? 100);
      state = WhatsAppDeliveryLogState(entries: entries);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadLogs();
}

// ── Provider ─────────────────────────────────────────────────────────────────

final whatsappDeliveryLogProvider =
    StateNotifierProvider<
      WhatsAppDeliveryLogNotifier,
      WhatsAppDeliveryLogState
    >((ref) {
      return WhatsAppDeliveryLogNotifier(ref);
    });
