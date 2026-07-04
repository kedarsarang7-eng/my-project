import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/tenant_config_provider.dart';
import '../data/models/leave_type_model.dart';
import '../data/models/leave_request_model.dart';
import '../data/models/leave_balance_model.dart';
import '../data/repositories/staff_management_repository.dart';
import 'staff_feature_keys.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// State for the leave management sub-area.
class LeaveState {
  final List<LeaveTypeModel> leaveTypes;
  final List<LeaveRequestModel> requests;
  final List<LeaveBalanceModel> balances;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const LeaveState({
    this.leaveTypes = const [],
    this.requests = const [],
    this.balances = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  LeaveState copyWith({
    List<LeaveTypeModel>? leaveTypes,
    List<LeaveRequestModel>? requests,
    List<LeaveBalanceModel>? balances,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return LeaveState(
      leaveTypes: leaveTypes ?? this.leaveTypes,
      requests: requests ?? this.requests,
      balances: balances ?? this.balances,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }

  /// Pending requests for approval workflow.
  List<LeaveRequestModel> get pendingRequests =>
      requests.where((r) => r.status == 'pending').toList();

  /// Approved requests (for calendar display).
  List<LeaveRequestModel> get approvedRequests =>
      requests.where((r) => r.status == 'approved').toList();
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class LeaveNotifier extends StateNotifier<LeaveState> {
  final Ref _ref;
  late final StaffManagementRepository _repo;

  LeaveNotifier(this._ref) : super(const LeaveState(isLoading: true)) {
    _repo = StaffManagementRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(StaffFeatureKeys.leave));
    if (!enabled) {
      state = const LeaveState(isDisabled: true);
      return;
    }
    loadAll();
  }

  /// Load leave types, requests, and balances.
  Future<void> loadAll({String? employeeId}) async {
    final enabled = _ref.read(featureEnabledProvider(StaffFeatureKeys.leave));
    if (!enabled) {
      state = const LeaveState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getLeaveTypes(),
        _repo.getLeaveRequests(employeeId: employeeId),
        _repo.getLeaveBalances(employeeId: employeeId),
      ]);

      state = LeaveState(
        leaveTypes: results[0] as List<LeaveTypeModel>,
        requests: results[1] as List<LeaveRequestModel>,
        balances: results[2] as List<LeaveBalanceModel>,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Submit a new leave request.
  Future<LeaveRequestModel?> submitRequest(Map<String, dynamic> data) async {
    if (state.isDisabled) return null;
    try {
      final request = await _repo.createLeaveRequest(data);
      state = state.copyWith(requests: [...state.requests, request]);
      return request;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Approve a leave request.
  Future<bool> approveRequest(String id) async {
    if (state.isDisabled) return false;
    try {
      final updated = await _repo.approveLeaveRequest(id);
      state = state.copyWith(
        requests: state.requests.map((r) => r.id == id ? updated : r).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Reject a leave request.
  Future<bool> rejectRequest(String id) async {
    if (state.isDisabled) return false;
    try {
      final updated = await _repo.rejectLeaveRequest(id);
      state = state.copyWith(
        requests: state.requests.map((r) => r.id == id ? updated : r).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final leaveProvider = StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  return LeaveNotifier(ref);
});
