// ============================================================================
// WhatsApp Rules Provider — AsyncNotifier for rule list + CRUD
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../providers/tenant_config_provider.dart';
import '../../data/models/automation_rule_model.dart';
import '../../data/repositories/whatsapp_automation_repository.dart';
import 'whatsapp_config_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

class WhatsAppRulesState {
  final List<AutomationRule> rules;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const WhatsAppRulesState({
    this.rules = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  WhatsAppRulesState copyWith({
    List<AutomationRule>? rules,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return WhatsAppRulesState(
      rules: rules ?? this.rules,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WhatsAppRulesNotifier extends StateNotifier<WhatsAppRulesState> {
  final Ref _ref;
  late final WhatsAppAutomationRepository _repo;

  WhatsAppRulesNotifier(this._ref)
    : super(const WhatsAppRulesState(isLoading: true)) {
    _repo = WhatsAppAutomationRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppRulesState(isDisabled: true);
      return;
    }
    loadRules();
  }

  Future<void> loadRules() async {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppRulesState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rules = await _repo.getRules();
      state = WhatsAppRulesState(rules: rules);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createRule(Map<String, dynamic> ruleData) async {
    try {
      final created = await _repo.createRule(ruleData);
      state = state.copyWith(rules: [...state.rules, created]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateRule(String ruleId, Map<String, dynamic> updates) async {
    try {
      final updated = await _repo.updateRule(ruleId, updates);
      state = state.copyWith(
        rules: state.rules.map((r) => r.id == ruleId ? updated : r).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteRule(String ruleId) async {
    try {
      await _repo.deleteRule(ruleId);
      state = state.copyWith(
        rules: state.rules.where((r) => r.id != ruleId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> toggleRule(String ruleId, bool enabled) async {
    try {
      final updated = enabled
          ? await _repo.enableRule(ruleId)
          : await _repo.disableRule(ruleId);
      state = state.copyWith(
        rules: state.rules.map((r) => r.id == ruleId ? updated : r).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final whatsappRulesProvider =
    StateNotifierProvider<WhatsAppRulesNotifier, WhatsAppRulesState>((ref) {
      return WhatsAppRulesNotifier(ref);
    });
