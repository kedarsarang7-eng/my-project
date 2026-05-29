// ============================================================================
// ACTIVE SHIFT BLoC - State Management for Active Shift Dashboard
// ============================================================================

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'active_shift_event.dart';
import 'active_shift_state.dart';
import '../../services/attendance_service.dart';
import '../../domain/attendance_exception.dart';
import '../../../../core/websocket/websocket_manager.dart';

/// BLoC for managing active shift state
class ActiveShiftBloc extends Bloc<ActiveShiftEvent, ActiveShiftState> {
  final AttendanceService _attendanceService;
  StreamSubscription<WebSocketMessage>? _wsSub;

  ActiveShiftBloc({required AttendanceService attendanceService})
      : _attendanceService = attendanceService,
        super(const ActiveShiftInitial()) {
    on<LoadActiveShift>(_onLoadActiveShift);
    on<RefreshShiftStats>(_onRefreshShiftStats);
    on<RecordTransaction>(_onRecordTransaction);
    on<EndShift>(_onEndShift);
    on<RealTimeUpdateReceived>(_onRealTimeUpdateReceived);

    // p28(b): Subscribe to the shared WebSocket stream so that server-push
    // events (STAFF_CHECKED_IN, STAFF_CHECKED_OUT, LEAVE_PROCESSED, etc.)
    // are fed into the bloc without any screen-level plumbing.
    _wsSub = WebSocketManager().messages.listen((msg) {
      add(RealTimeUpdateReceived(
        eventType: msg.type,
        payload: msg.payload,
      ));
    });
  }

  @override
  Future<void> close() {
    _wsSub?.cancel();
    return super.close();
  }

  Future<void> _onLoadActiveShift(
    LoadActiveShift event,
    Emitter<ActiveShiftState> emit,
  ) async {
    emit(ActiveShiftLoading(shiftId: event.shiftId));

    try {
      final shiftData = await _attendanceService.getShiftDetails(event.shiftId);
      final stats = await _attendanceService.getShiftStats(event.shiftId);
      final transactions = await _attendanceService.getRecentTransactions(
        shiftId: event.shiftId,
        limit: 10,
      );

      emit(ActiveShiftLoaded(
        shiftId: event.shiftId,
        checkInTime: DateTime.parse(shiftData['checkInTime']),
        stats: stats,
        recentTransactions: transactions['transactions'] as List<dynamic>?,
        stationId: shiftData['stationId'] as String?,
        staffId: shiftData['staffId'] as String?,
      ));
    } catch (e) {
      emit(ActiveShiftError(
        message: 'Failed to load shift: ${e.toString()}',
        shiftId: event.shiftId,
      ));
    }
  }

  Future<void> _onRefreshShiftStats(
    RefreshShiftStats event,
    Emitter<ActiveShiftState> emit,
  ) async {
    final currentState = state;
    if (currentState is ActiveShiftLoaded) {
      try {
        final stats = await _attendanceService.getShiftStats(currentState.shiftId);
        final transactions = await _attendanceService.getRecentTransactions(
          shiftId: currentState.shiftId,
          limit: 10,
        );

        emit(currentState.copyWith(
          stats: stats,
          recentTransactions: transactions['transactions'] as List<dynamic>?,
        ));
      } catch (e) {
        // Keep current state but could emit error
      }
    }
  }

  Future<void> _onRecordTransaction(
    RecordTransaction event,
    Emitter<ActiveShiftState> emit,
  ) async {
    final currentState = state;
    if (currentState is ActiveShiftLoaded) {
      try {
        await _attendanceService.recordTransaction(
          shiftId: currentState.shiftId,
          fuelType: event.fuelType,
          litres: event.litres,
          amount: event.amount,
          paymentMethod: event.paymentMethod,
        );

        // Refresh stats after transaction
        add(const RefreshShiftStats());
      } on AttendanceException catch (e) {
        emit(ActiveShiftError(
          message: e.actionHint,
          shiftId: currentState.shiftId,
        ));
        emit(currentState);
      } catch (e) {
        emit(ActiveShiftError(
          message: 'Failed to record transaction: ${e.toString()}',
          shiftId: currentState.shiftId,
        ));
        emit(currentState);
      }
    }
  }

  Future<void> _onEndShift(
    EndShift event,
    Emitter<ActiveShiftState> emit,
  ) async {
    final currentState = state;
    if (currentState is ActiveShiftLoaded) {
      emit(ShiftEnding(shiftId: event.shiftId));

      try {
        final result = await _attendanceService.checkOut(
          shiftId: event.shiftId,
        );

        emit(ShiftEnded(
          shiftId: event.shiftId,
          checkOutTime: DateTime.now(),
          totalHours: result['totalHours']?.toDouble() ?? 0.0,
          totalSales: currentState.stats?['totalSales']?.toDouble() ?? 0.0,
          transactionCount: currentState.stats?['transactionCount']?.toInt() ?? 0,
        ));
      } on AttendanceException catch (e) {
        emit(ActiveShiftError(
          message: e.actionHint,
          shiftId: event.shiftId,
        ));
        emit(currentState);
      } catch (e) {
        emit(ActiveShiftError(
          message: 'Failed to end shift: ${e.toString()}',
          shiftId: event.shiftId,
        ));
        emit(currentState);
      }
    }
  }

  void _onRealTimeUpdateReceived(
    RealTimeUpdateReceived event,
    Emitter<ActiveShiftState> emit,
  ) {
    final currentState = state;
    if (currentState is! ActiveShiftLoaded) return;

    switch (event.eventType) {
      // p28(b) — transaction recorded: refresh live stats
      case 'TRANSACTION_RECORDED':
        if (event.payload['shiftId'] == currentState.shiftId) {
          add(const RefreshShiftStats());
        }

      // p28(b) — another staff member checked in at the same station:
      // refresh so the manager dashboard reflects the updated roster
      case 'STAFF_CHECKED_IN':
        if (event.payload['stationId'] == currentState.stationId) {
          add(const RefreshShiftStats());
        }

      // p28(b) — this staff's own shift was closed remotely (e.g. manager
      // forced checkout), or another staff checked out at the same station
      case 'STAFF_CHECKED_OUT':
        if (event.payload['shiftId'] == currentState.shiftId) {
          // Own shift ended remotely — emit ShiftEnded
          emit(ShiftEnded(
            shiftId: currentState.shiftId,
            checkOutTime: event.payload['checkOutTime'] != null
                ? DateTime.tryParse(event.payload['checkOutTime'] as String) ??
                    DateTime.now()
                : DateTime.now(),
            totalHours:
                (event.payload['totalHours'] as num?)?.toDouble() ?? 0.0,
            totalSales:
                (event.payload['totalSalesAmount'] as num?)?.toDouble() ?? 0.0,
            transactionCount:
                (event.payload['transactionCount'] as num?)?.toInt() ?? 0,
          ));
        } else if (event.payload['stationId'] == currentState.stationId) {
          add(const RefreshShiftStats());
        }

      // p28(b) — leave request approved/rejected for the active staff member
      case 'LEAVE_PROCESSED':
        if (event.payload['staffId'] == currentState.staffId) {
          // Reload dashboard to reflect updated leave balance / attendance row
          add(LoadActiveShift(shiftId: currentState.shiftId));
        }

      // p28(b) — new leave request submitted (manager view refresh)
      case 'LEAVE_REQUESTED':
        if (event.payload['stationId'] == currentState.stationId) {
          add(const RefreshShiftStats());
        }

      default:
        break;
    }
  }
}
