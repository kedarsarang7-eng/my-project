// ============================================================================
// STAFF DETAIL STATES
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../data/models/staff_profile_model.dart';

abstract class StaffDetailState extends Equatable {
  const StaffDetailState();

  /// Nullable accessor so callers don't need to cast to get the current staff.
  StaffProfileModel? get staff => null;

  @override
  List<Object?> get props => [];
}

/// Initial state
class StaffDetailInitial extends StaffDetailState {
  const StaffDetailInitial();
}

/// Loading state
class StaffDetailLoading extends StaffDetailState {
  final String? staffId;
  @override
  final StaffProfileModel? staff;
  final DateTime selectedMonth;

  const StaffDetailLoading({
    this.staffId,
    this.staff,
    required this.selectedMonth,
  });

  @override
  List<Object?> get props => [staffId, staff, selectedMonth];
}

/// Loaded state with all data
class StaffDetailLoaded extends StaffDetailState {
  @override
  final StaffProfileModel staff;
  final DateTime selectedMonth;
  final int selectedTab;
  
  // Dashboard data
  final Map<String, dynamic>? attendanceSummary;
  final Map<String, dynamic>? shiftSummary;
  final Map<String, dynamic>? salesSummary;
  final Map<String, dynamic>? performanceScore;
  final List<dynamic>? weeklyHoursTrend;
  final List<dynamic>? recentAlerts;
  final Map<String, dynamic>? leaveBalance;
  
  // Tab-specific data
  final List<dynamic>? attendanceCalendar;
  final List<dynamic>? shiftHistory;
  final List<dynamic>? transactions;
  final List<dynamic>? leaveHistory;
  
  // Error message (if any)
  final String? errorMessage;

  const StaffDetailLoaded({
    required this.staff,
    required this.selectedMonth,
    required this.selectedTab,
    this.attendanceSummary,
    this.shiftSummary,
    this.salesSummary,
    this.performanceScore,
    this.weeklyHoursTrend,
    this.recentAlerts,
    this.leaveBalance,
    this.attendanceCalendar,
    this.shiftHistory,
    this.transactions,
    this.leaveHistory,
    this.errorMessage,
  });

  StaffDetailLoaded copyWith({
    StaffProfileModel? staff,
    DateTime? selectedMonth,
    int? selectedTab,
    Map<String, dynamic>? attendanceSummary,
    Map<String, dynamic>? shiftSummary,
    Map<String, dynamic>? salesSummary,
    Map<String, dynamic>? performanceScore,
    List<dynamic>? weeklyHoursTrend,
    List<dynamic>? recentAlerts,
    Map<String, dynamic>? leaveBalance,
    List<dynamic>? attendanceCalendar,
    List<dynamic>? shiftHistory,
    List<dynamic>? transactions,
    List<dynamic>? leaveHistory,
    String? errorMessage,
  }) {
    return StaffDetailLoaded(
      staff: staff ?? this.staff,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedTab: selectedTab ?? this.selectedTab,
      attendanceSummary: attendanceSummary ?? this.attendanceSummary,
      shiftSummary: shiftSummary ?? this.shiftSummary,
      salesSummary: salesSummary ?? this.salesSummary,
      performanceScore: performanceScore ?? this.performanceScore,
      weeklyHoursTrend: weeklyHoursTrend ?? this.weeklyHoursTrend,
      recentAlerts: recentAlerts ?? this.recentAlerts,
      leaveBalance: leaveBalance ?? this.leaveBalance,
      attendanceCalendar: attendanceCalendar ?? this.attendanceCalendar,
      shiftHistory: shiftHistory ?? this.shiftHistory,
      transactions: transactions ?? this.transactions,
      leaveHistory: leaveHistory ?? this.leaveHistory,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    staff,
    selectedMonth,
    selectedTab,
    attendanceSummary,
    shiftSummary,
    salesSummary,
    performanceScore,
    weeklyHoursTrend,
    recentAlerts,
    leaveBalance,
    attendanceCalendar,
    shiftHistory,
    transactions,
    leaveHistory,
    errorMessage,
  ];
}

/// Tab loading state (shows shimmer while loading tab data)
class StaffDetailTabLoading extends StaffDetailState {
  @override
  final StaffProfileModel staff;
  final DateTime selectedMonth;
  final int selectedTab;
  final int loadingTab;

  const StaffDetailTabLoading({
    required this.staff,
    required this.selectedMonth,
    required this.selectedTab,
    required this.loadingTab,
  });

  @override
  List<Object?> get props => [staff, selectedMonth, selectedTab, loadingTab];
}

/// Error state
class StaffDetailError extends StaffDetailState {
  final String message;
  final String? staffId;

  const StaffDetailError({
    required this.message,
    this.staffId,
  });

  @override
  List<Object?> get props => [message, staffId];
}

/// Export in progress
class ExportInProgress extends StaffDetailState {
  @override
  final StaffProfileModel staff;
  final DateTime selectedMonth;
  final String format;

  const ExportInProgress({
    required this.staff,
    required this.selectedMonth,
    required this.format,
  });

  @override
  List<Object?> get props => [staff, selectedMonth, format];
}

/// Export success
class ExportSuccess extends StaffDetailState {
  @override
  final StaffProfileModel staff;
  final DateTime selectedMonth;
  final String downloadUrl;
  final String format;

  const ExportSuccess({
    required this.staff,
    required this.selectedMonth,
    required this.downloadUrl,
    required this.format,
  });

  @override
  List<Object?> get props => [staff, selectedMonth, downloadUrl, format];
}
