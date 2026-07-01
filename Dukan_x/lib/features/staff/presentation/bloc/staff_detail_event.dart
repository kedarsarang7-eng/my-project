// ============================================================================
// STAFF DETAIL EVENTS
// ============================================================================

import 'package:equatable/equatable.dart';

abstract class StaffDetailEvent extends Equatable {
  const StaffDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Load initial staff detail data
class LoadStaffDetail extends StaffDetailEvent {
  final String staffId;

  const LoadStaffDetail({required this.staffId});

  @override
  List<Object?> get props => [staffId];
}

/// Change selected month/year
class ChangeMonth extends StaffDetailEvent {
  final String staffId;
  final DateTime month;

  const ChangeMonth({required this.staffId, required this.month});

  @override
  List<Object?> get props => [staffId, month];
}

/// Change selected tab
class ChangeTab extends StaffDetailEvent {
  final int tabIndex;

  const ChangeTab({required this.tabIndex});

  @override
  List<Object?> get props => [tabIndex];
}

/// Load attendance calendar for tab
class LoadAttendanceCalendar extends StaffDetailEvent {
  final String staffId;

  const LoadAttendanceCalendar({required this.staffId});

  @override
  List<Object?> get props => [staffId];
}

/// Load shift history for tab
class LoadShiftHistory extends StaffDetailEvent {
  final String staffId;

  const LoadShiftHistory({required this.staffId});

  @override
  List<Object?> get props => [staffId];
}

/// Load transactions for tab
class LoadTransactions extends StaffDetailEvent {
  final String staffId;

  const LoadTransactions({required this.staffId});

  @override
  List<Object?> get props => [staffId];
}

/// Load leave history for tab
class LoadLeaveHistory extends StaffDetailEvent {
  final String staffId;

  const LoadLeaveHistory({required this.staffId});

  @override
  List<Object?> get props => [staffId];
}

/// Approve leave request
class ApproveLeave extends StaffDetailEvent {
  final String leaveId;
  final String? remarks;

  const ApproveLeave({required this.leaveId, this.remarks});

  @override
  List<Object?> get props => [leaveId, remarks];
}

/// Reject leave request
class RejectLeave extends StaffDetailEvent {
  final String leaveId;
  final String? remarks;

  const RejectLeave({required this.leaveId, this.remarks});

  @override
  List<Object?> get props => [leaveId, remarks];
}

/// Export report (PDF/CSV)
class ExportReport extends StaffDetailEvent {
  final String format; // 'PDF' or 'CSV'

  const ExportReport({required this.format});

  @override
  List<Object?> get props => [format];
}

/// Real-time WebSocket update received
class RealTimeUpdateReceived extends StaffDetailEvent {
  final String eventType;
  final Map<String, dynamic> payload;

  const RealTimeUpdateReceived({
    required this.eventType,
    required this.payload,
  });

  @override
  List<Object?> get props => [eventType, payload];
}
