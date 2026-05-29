// ============================================================================
// ACTIVE SHIFT STATES
// ============================================================================

import 'package:equatable/equatable.dart';

abstract class ActiveShiftState extends Equatable {
  const ActiveShiftState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ActiveShiftInitial extends ActiveShiftState {
  const ActiveShiftInitial();
}

/// Loading shift data
class ActiveShiftLoading extends ActiveShiftState {
  final String shiftId;

  const ActiveShiftLoading({required this.shiftId});

  @override
  List<Object?> get props => [shiftId];
}

/// Shift loaded with data
class ActiveShiftLoaded extends ActiveShiftState {
  final String shiftId;
  final DateTime checkInTime;
  final Map<String, dynamic>? stats;
  final List<dynamic>? recentTransactions;
  /// Station this shift belongs to — used to filter station-scoped WS events.
  final String? stationId;
  /// Staff member ID — used to filter staff-scoped WS events (e.g. LEAVE_PROCESSED).
  final String? staffId;

  const ActiveShiftLoaded({
    required this.shiftId,
    required this.checkInTime,
    this.stats,
    this.recentTransactions,
    this.stationId,
    this.staffId,
  });

  ActiveShiftLoaded copyWith({
    String? shiftId,
    DateTime? checkInTime,
    Map<String, dynamic>? stats,
    List<dynamic>? recentTransactions,
    String? stationId,
    String? staffId,
  }) {
    return ActiveShiftLoaded(
      shiftId: shiftId ?? this.shiftId,
      checkInTime: checkInTime ?? this.checkInTime,
      stats: stats ?? this.stats,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      stationId: stationId ?? this.stationId,
      staffId: staffId ?? this.staffId,
    );
  }

  @override
  List<Object?> get props => [shiftId, checkInTime, stats, recentTransactions, stationId, staffId];
}

/// Shift ending in progress
class ShiftEnding extends ActiveShiftState {
  final String shiftId;

  const ShiftEnding({required this.shiftId});

  @override
  List<Object?> get props => [shiftId];
}

/// Shift ended successfully
class ShiftEnded extends ActiveShiftState {
  final String shiftId;
  final DateTime checkOutTime;
  final double totalHours;
  final double totalSales;
  final int transactionCount;

  const ShiftEnded({
    required this.shiftId,
    required this.checkOutTime,
    required this.totalHours,
    required this.totalSales,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [
    shiftId, 
    checkOutTime, 
    totalHours, 
    totalSales, 
    transactionCount,
  ];
}

/// Error state
class ActiveShiftError extends ActiveShiftState {
  final String message;
  final String? shiftId;

  const ActiveShiftError({
    required this.message,
    this.shiftId,
  });

  @override
  List<Object?> get props => [message, shiftId];
}
