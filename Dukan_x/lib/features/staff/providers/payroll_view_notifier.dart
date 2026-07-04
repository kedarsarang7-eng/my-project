import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/tenant_config_provider.dart';
import '../data/models/payroll_run_model.dart';
import '../data/models/payslip_model.dart';
import '../data/repositories/staff_management_repository.dart';
import 'staff_feature_keys.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// State for the payroll view sub-area.
///
/// Payroll runs are online-only but payslips can be viewed offline from
/// the last synced cache (Req 6.7).
class PayrollViewState {
  final List<PayrollRunModel> runs;
  final List<PayslipModel> payslips;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const PayrollViewState({
    this.runs = const [],
    this.payslips = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  PayrollViewState copyWith({
    List<PayrollRunModel>? runs,
    List<PayslipModel>? payslips,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return PayrollViewState(
      runs: runs ?? this.runs,
      payslips: payslips ?? this.payslips,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PayrollViewNotifier extends StateNotifier<PayrollViewState> {
  final Ref _ref;
  late final StaffManagementRepository _repo;

  PayrollViewNotifier(this._ref)
    : super(const PayrollViewState(isLoading: true)) {
    _repo = StaffManagementRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(StaffFeatureKeys.payroll));
    if (!enabled) {
      state = const PayrollViewState(isDisabled: true);
      return;
    }
    loadRuns();
  }

  /// Load payroll runs for the business.
  Future<void> loadRuns({String? period}) async {
    final enabled = _ref.read(featureEnabledProvider(StaffFeatureKeys.payroll));
    if (!enabled) {
      state = const PayrollViewState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final runs = await _repo.getPayrollRuns(period: period);
      state = state.copyWith(runs: runs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load payslips for a specific employee or period.
  Future<void> loadPayslips({String? employeeId, String? period}) async {
    if (state.isDisabled) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final payslips = await _repo.getPayslips(
        employeeId: employeeId,
        period: period,
      );
      state = state.copyWith(payslips: payslips, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Initiate a payroll run (requires online).
  Future<PayrollRunModel?> initiateRun(Map<String, dynamic> data) async {
    if (state.isDisabled) return null;
    try {
      final run = await _repo.createPayrollRun(data);
      state = state.copyWith(runs: [run, ...state.runs]);
      return run;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final payrollViewProvider =
    StateNotifierProvider<PayrollViewNotifier, PayrollViewState>((ref) {
      return PayrollViewNotifier(ref);
    });
