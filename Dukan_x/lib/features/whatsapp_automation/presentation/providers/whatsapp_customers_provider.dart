// ============================================================================
// WhatsApp Customers Provider — AsyncNotifier for customer list + consent
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../providers/tenant_config_provider.dart';
import '../../data/models/whatsapp_customer_model.dart';
import '../../data/repositories/whatsapp_automation_repository.dart';
import 'whatsapp_config_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

class WhatsAppCustomersState {
  final List<WhatsAppCustomer> customers;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const WhatsAppCustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  WhatsAppCustomersState copyWith({
    List<WhatsAppCustomer>? customers,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return WhatsAppCustomersState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WhatsAppCustomersNotifier extends StateNotifier<WhatsAppCustomersState> {
  final Ref _ref;
  late final WhatsAppAutomationRepository _repo;

  WhatsAppCustomersNotifier(this._ref)
    : super(const WhatsAppCustomersState(isLoading: true)) {
    _repo = WhatsAppAutomationRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppCustomersState(isDisabled: true);
      return;
    }
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    final enabled = _ref.read(featureEnabledProvider(waFeatureKey));
    if (!enabled) {
      state = const WhatsAppCustomersState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final customers = await _repo.getCustomers();
      state = WhatsAppCustomersState(customers: customers);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createCustomer({
    required String whatsappNumber,
    ConsentState consentState = ConsentState.pending,
    String locale = 'en',
  }) async {
    try {
      final created = await _repo.createCustomer({
        'whatsappNumber': whatsappNumber,
        'consentState': consentState.value,
        'locale': locale,
      });
      state = state.copyWith(customers: [...state.customers, created]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> setConsent(
    String customerId,
    ConsentState consent, {
    String? auditNote,
  }) async {
    try {
      final updated = await _repo.setConsent(
        customerId,
        consent,
        auditNote: auditNote,
      );
      state = state.copyWith(
        customers: state.customers
            .map((c) => c.id == customerId ? updated : c)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateCustomer(
    String customerId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final updated = await _repo.updateCustomer(customerId, updates);
      state = state.copyWith(
        customers: state.customers
            .map((c) => c.id == customerId ? updated : c)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final whatsappCustomersProvider =
    StateNotifierProvider<WhatsAppCustomersNotifier, WhatsAppCustomersState>((
      ref,
    ) {
      return WhatsAppCustomersNotifier(ref);
    });
