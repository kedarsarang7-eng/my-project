/// Staff provider adapter for petrol pump screens.
///
/// Wraps [StaffManagementNotifier] into the [staffListProvider] interface
/// expected by petrol pump presentation screens.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/di/service_locator.dart';
import '../../staff/data/models/staff_member.dart';
import '../../staff/data/models/staff_performance.dart';
import '../../staff/data/models/staff_profile_model.dart';
import '../../staff/presentation/providers/staff_management_provider.dart';
import '../../staff/services/staff_attendance_service.dart';

/// State used by petrol pump staff screens.
class StaffState {
  final List<StaffMember> staff;
  final bool isLoading;
  final String? error;

  const StaffState({this.staff = const [], this.isLoading = true, this.error});

  StaffState copyWith({
    List<StaffMember>? staff,
    bool? isLoading,
    String? error,
  }) {
    return StaffState(
      staff: staff ?? this.staff,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Adapter notifier that delegates to [StaffManagementNotifier].
class StaffListNotifier extends StateNotifier<StaffState> {
  final StaffManagementNotifier _delegate;

  StaffListNotifier(this._delegate) : super(const StaffState());

  Future<void> loadStaffList() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _delegate.loadStaff(refresh: true);
      final mgmtState = _delegate.state;
      state = StaffState(
        staff: mgmtState.staff.map((e) => StaffMember.fromListItem(e)).toList(),
        isLoading: false,
        error: mgmtState.error,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async => loadStaffList();

  Future<void> deactivateStaff(String staffId) async {
    await _delegate.deactivateStaff(staffId);
    await loadStaffList();
  }

  Future<void> activateStaff(String staffId) async {
    await _delegate.reactivateStaff(staffId);
    await loadStaffList();
  }

  Future<bool> inviteStaff({
    required String name,
    required String phone,
    required String role,
    String? email,
  }) async {
    final request = CreateStaffRequest(
      fullName: name,
      phoneNumber: phone,
      email: email,
      role: StaffRole.fromJson(role),
      shiftTiming: const ShiftTiming(
        start: '09:00',
        end: '17:00',
        days: ['MON', 'TUE', 'WED', 'THU', 'FRI'],
      ),
    );
    final result = await _delegate.createStaff(request);
    if (result != null) {
      await loadStaffList();
      return true;
    }
    return false;
  }
}

/// Provider that petrol pump screens consume.
final staffListProvider = StateNotifierProvider<StaffListNotifier, StaffState>((
  ref,
) {
  final delegate = ref.watch(staffManagementProvider.notifier);
  return StaffListNotifier(delegate);
});

// ============================================================================
// Staff Details Provider — for petrol pump StaffDetailScreen
// ============================================================================

/// State for a single staff member's detail view.
class StaffDetailsState {
  final StaffMember? staff;
  final List<Map<String, dynamic>> transactions;
  final StaffPerformance? performance;
  final bool isLoading;
  final String? error;

  const StaffDetailsState({
    this.staff,
    this.transactions = const [],
    this.performance,
    this.isLoading = false,
    this.error,
  });

  StaffDetailsState copyWith({
    StaffMember? staff,
    List<Map<String, dynamic>>? transactions,
    StaffPerformance? performance,
    bool? isLoading,
    String? error,
  }) {
    return StaffDetailsState(
      staff: staff ?? this.staff,
      transactions: transactions ?? this.transactions,
      performance: performance ?? this.performance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StaffDetailsNotifier extends StateNotifier<StaffDetailsState> {
  final StaffListNotifier _listNotifier;
  final StaffAttendanceService _attendanceService;

  StaffDetailsNotifier(this._listNotifier, this._attendanceService)
    : super(const StaffDetailsState());

  Future<void> loadStaffDetails(String staffId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _listNotifier.loadStaffList();
      final found = _listNotifier.state.staff
          .where((s) => s.id == staffId)
          .firstOrNull;
      state = state.copyWith(
        staff: found,
        isLoading: false,
        error: found == null ? 'Staff member not found' : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadStaffTransactions(String staffId) async {
    final now = DateTime.now();
    try {
      final result = await _attendanceService.getStaffTransactions(
        staffId: staffId,
        month: now.month,
        year: now.year,
      );
      final list = (result['transactions'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      state = state.copyWith(transactions: list);
    } catch (_) {
      state = state.copyWith(transactions: const []);
    }
  }
}

final staffDetailsProvider =
    StateNotifierProvider<StaffDetailsNotifier, StaffDetailsState>((ref) {
      final listNotifier = ref.watch(staffListProvider.notifier);
      final attendanceService = sl<StaffAttendanceService>();
      return StaffDetailsNotifier(listNotifier, attendanceService);
    });
