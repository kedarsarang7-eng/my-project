// ============================================================================
// WhatsApp Templates Provider — AsyncNotifier for template list + CRUD
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../providers/tenant_config_provider.dart';
import '../../data/models/message_template_model.dart';
import '../../data/repositories/whatsapp_automation_repository.dart';
import 'whatsapp_config_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

class WhatsAppTemplatesState {
  final List<MessageTemplate> templates;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const WhatsAppTemplatesState({
    this.templates = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  WhatsAppTemplatesState copyWith({
    List<MessageTemplate>? templates,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return WhatsAppTemplatesState(
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WhatsAppTemplatesNotifier extends StateNotifier<WhatsAppTemplatesState> {
  final Ref _ref;
  late final WhatsAppAutomationRepository _repo;

  WhatsAppTemplatesNotifier(this._ref)
    : super(const WhatsAppTemplatesState(isLoading: true)) {
    _repo = WhatsAppAutomationRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppTemplatesState(isDisabled: true);
      return;
    }
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppTemplatesState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final templates = await _repo.getTemplates();
      state = WhatsAppTemplatesState(templates: templates);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createTemplate({
    required String name,
    required String body,
    required List<String> placeholders,
    String locale = 'en',
  }) async {
    try {
      final created = await _repo.createTemplate({
        'name': name,
        'body': body,
        'placeholders': placeholders,
        'locale': locale,
      });
      state = state.copyWith(templates: [...state.templates, created]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateTemplate(
    String templateId, {
    String? name,
    String? body,
    List<String>? placeholders,
    String? locale,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (body != null) updates['body'] = body;
      if (placeholders != null) updates['placeholders'] = placeholders;
      if (locale != null) updates['locale'] = locale;

      final updated = await _repo.updateTemplate(templateId, updates);
      state = state.copyWith(
        templates: state.templates
            .map((t) => t.id == templateId ? updated : t)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _repo.deleteTemplate(templateId);
      state = state.copyWith(
        templates: state.templates.where((t) => t.id != templateId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final whatsappTemplatesProvider =
    StateNotifierProvider<WhatsAppTemplatesNotifier, WhatsAppTemplatesState>((
      ref,
    ) {
      return WhatsAppTemplatesNotifier(ref);
    });
