// ============================================================================
// STAFF DETAIL BLoC - State Management for Unified Staff Detail Screen
// ============================================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'staff_detail_event.dart';
import 'staff_detail_state.dart';
import '../../services/staff_attendance_service.dart';

/// BLoC for managing staff detail screen state
/// 
/// Handles:
/// - Loading staff dashboard data
/// - Tab switching with lazy loading
/// - Month/year selection
/// - Export operations
/// - Real-time updates
class StaffDetailBloc extends Bloc<StaffDetailEvent, StaffDetailState> {
  final StaffAttendanceService _attendanceService;

  StaffDetailBloc({required StaffAttendanceService attendanceService})
      : _attendanceService = attendanceService,
        super(const StaffDetailInitial()) {
    on<LoadStaffDetail>(_onLoadStaffDetail);
    on<ChangeMonth>(_onChangeMonth);
    on<ChangeTab>(_onChangeTab);
    on<LoadAttendanceCalendar>(_onLoadAttendanceCalendar);
    on<LoadShiftHistory>(_onLoadShiftHistory);
    on<LoadTransactions>(_onLoadTransactions);
    on<LoadLeaveHistory>(_onLoadLeaveHistory);
    on<ApproveLeave>(_onApproveLeave);
    on<RejectLeave>(_onRejectLeave);
    on<ExportReport>(_onExportReport);
    on<RealTimeUpdateReceived>(_onRealTimeUpdate);
  }

  Future<void> _onLoadStaffDetail(
    LoadStaffDetail event,
    Emitter<StaffDetailState> emit,
  ) async {
    emit(StaffDetailLoading(
      staffId: event.staffId,
      selectedMonth: DateTime.now(),
    ));

    try {
      final dashboard = await _attendanceService.getStaffDashboard(
        staffId: event.staffId,
        month: DateTime.now().month,
        year: DateTime.now().year,
      );

      emit(StaffDetailLoaded(
        staff: dashboard['staff'] as dynamic,
        selectedMonth: DateTime.now(),
        selectedTab: 0,
        attendanceSummary: dashboard['attendanceSummary'] as Map<String, dynamic>?,
        shiftSummary: dashboard['shiftSummary'] as Map<String, dynamic>?,
        salesSummary: dashboard['salesSummary'] as Map<String, dynamic>?,
        performanceScore: dashboard['performanceScore'] as Map<String, dynamic>?,
        weeklyHoursTrend: dashboard['weeklyHoursTrend'] as List<dynamic>?,
        recentAlerts: dashboard['recentAlerts'] as List<dynamic>?,
        leaveBalance: dashboard['leaveBalance'] as Map<String, dynamic>?,
      ));
    } catch (e) {
      emit(StaffDetailError(
        message: e.toString(),
        staffId: event.staffId,
      ));
    }
  }

  Future<void> _onChangeMonth(
    ChangeMonth event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      emit(currentState.copyWith(selectedMonth: event.month));

      try {
        final dashboard = await _attendanceService.getStaffDashboard(
          staffId: event.staffId,
          month: event.month.month,
          year: event.month.year,
        );

        emit(currentState.copyWith(
          attendanceSummary: dashboard['attendanceSummary'] as Map<String, dynamic>?,
          shiftSummary: dashboard['shiftSummary'] as Map<String, dynamic>?,
          salesSummary: dashboard['salesSummary'] as Map<String, dynamic>?,
          performanceScore: dashboard['performanceScore'] as Map<String, dynamic>?,
          weeklyHoursTrend: dashboard['weeklyHoursTrend'] as List<dynamic>?,
          recentAlerts: dashboard['recentAlerts'] as List<dynamic>?,
        ));
      } catch (e) {
        // Keep old data but show error
        emit(currentState.copyWith(
          errorMessage: 'Failed to load data for selected month',
        ));
      }
    }
  }

  Future<void> _onChangeTab(
    ChangeTab event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      emit(currentState.copyWith(selectedTab: event.tabIndex));
    }
  }

  Future<void> _onLoadAttendanceCalendar(
    LoadAttendanceCalendar event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      emit(StaffDetailTabLoading(
        staff: currentState.staff,
        selectedMonth: currentState.selectedMonth,
        selectedTab: currentState.selectedTab,
        loadingTab: 1,
      ));

      try {
        final calendar = await _attendanceService.getAttendanceCalendar(
          staffId: event.staffId,
          month: currentState.selectedMonth.month,
          year: currentState.selectedMonth.year,
        );

        emit(currentState.copyWith(
          attendanceCalendar: calendar['days'] as List<dynamic>?,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Failed to load attendance calendar',
        ));
      }
    }
  }

  Future<void> _onLoadShiftHistory(
    LoadShiftHistory event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      emit(StaffDetailTabLoading(
        staff: currentState.staff,
        selectedMonth: currentState.selectedMonth,
        selectedTab: currentState.selectedTab,
        loadingTab: 2,
      ));

      try {
        final shifts = await _attendanceService.getShiftHistory(
          staffId: event.staffId,
          month: currentState.selectedMonth.month,
          year: currentState.selectedMonth.year,
        );

        emit(currentState.copyWith(
          shiftHistory: shifts['shifts'] as List<dynamic>?,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Failed to load shift history',
        ));
      }
    }
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      emit(StaffDetailTabLoading(
        staff: currentState.staff,
        selectedMonth: currentState.selectedMonth,
        selectedTab: currentState.selectedTab,
        loadingTab: 3,
      ));

      try {
        final transactions = await _attendanceService.getStaffTransactions(
          staffId: event.staffId,
          month: currentState.selectedMonth.month,
          year: currentState.selectedMonth.year,
        );

        emit(currentState.copyWith(
          transactions: transactions['transactions'] as List<dynamic>?,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Failed to load transactions',
        ));
      }
    }
  }

  Future<void> _onLoadLeaveHistory(
    LoadLeaveHistory event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      emit(StaffDetailTabLoading(
        staff: currentState.staff,
        selectedMonth: currentState.selectedMonth,
        selectedTab: currentState.selectedTab,
        loadingTab: 4,
      ));

      try {
        final leave = await _attendanceService.getLeaveHistory(
          staffId: event.staffId,
        );

        emit(currentState.copyWith(
          leaveHistory: leave['leaves'] as List<dynamic>?,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Failed to load leave history',
        ));
      }
    }
  }

  Future<void> _onApproveLeave(
    ApproveLeave event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      try {
        await _attendanceService.processLeaveRequest(
          leaveId: event.leaveId,
          action: 'APPROVE',
          remarks: event.remarks,
          staffId: currentState.staff.staffId,
        );

        // Reload leave history
        add(LoadLeaveHistory(staffId: currentState.staff.staffId));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Failed to approve leave',
        ));
      }
    }
  }

  Future<void> _onRejectLeave(
    RejectLeave event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      try {
        await _attendanceService.processLeaveRequest(
          leaveId: event.leaveId,
          action: 'REJECT',
          remarks: event.remarks,
          staffId: currentState.staff.staffId,
        );

        // Reload leave history
        add(LoadLeaveHistory(staffId: currentState.staff.staffId));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Failed to reject leave',
        ));
      }
    }
  }

  Future<void> _onExportReport(
    ExportReport event,
    Emitter<StaffDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      emit(ExportInProgress(
        staff: currentState.staff,
        selectedMonth: currentState.selectedMonth,
        format: event.format,
      ));

      try {
        final result = await _attendanceService.exportReport(
          staffId: currentState.staff.staffId,
          month: currentState.selectedMonth.month,
          year: currentState.selectedMonth.year,
          format: event.format,
        );

        emit(ExportSuccess(
          staff: currentState.staff,
          selectedMonth: currentState.selectedMonth,
          downloadUrl: result['downloadUrl'] as String,
          format: event.format,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: 'Export failed: ${e.toString()}',
        ));
      }
    }
  }

  void _onRealTimeUpdate(
    RealTimeUpdateReceived event,
    Emitter<StaffDetailState> emit,
  ) {
    final currentState = state;
    if (currentState is StaffDetailLoaded) {
      // Handle real-time updates based on event type
      switch (event.eventType) {
        case 'STAFF_CHECKED_IN':
          // Refresh attendance data
          add(LoadAttendanceCalendar(staffId: currentState.staff.staffId));
          break;
        case 'TRANSACTION_RECORDED':
          // Refresh transactions if on transactions tab
          if (currentState.selectedTab == 3) {
            add(LoadTransactions(staffId: currentState.staff.staffId));
          }
          break;
        case 'LEAVE_REQUESTED':
          // Refresh leave if on leave tab
          if (currentState.selectedTab == 4) {
            add(LoadLeaveHistory(staffId: currentState.staff.staffId));
          }
          break;
      }
    }
  }
}
