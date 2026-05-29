// ============================================================================
// ID SCANNER BLoC - State Management for ID Card Scanning
// ============================================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'id_scanner_event.dart';
import 'id_scanner_state.dart';
import '../../services/attendance_service.dart';
import '../../domain/attendance_exception.dart';

const _kPendingCheckInKey = 'pending_checkin_request_id';
const _uuid = Uuid();

/// BLoC for managing ID card scanning and shift start
class IDScannerBloc extends Bloc<IDScannerEvent, IDScannerState> {
  final AttendanceService _attendanceService;

  IDScannerBloc({required AttendanceService attendanceService})
      : _attendanceService = attendanceService,
        super(const ScanningIdle()) {
    on<CameraInitialized>(_onCameraInitialized);
    on<CameraError>(_onCameraError);
    on<IDDetected>(_onIDDetected);
    on<StaffValidated>(_onStaffValidated);
    on<ConfirmShiftStart>(_onConfirmShiftStart);
    on<ManualIdEntered>(_onManualIdEntered);
    on<RetryScan>(_onRetryScan);
  }

  void _onCameraInitialized(
    CameraInitialized event,
    Emitter<IDScannerState> emit,
  ) {
    emit(const ScanningActive());
  }

  void _onCameraError(
    CameraError event,
    Emitter<IDScannerState> emit,
  ) {
    emit(ScanError(message: event.message));
  }

  void _onIDDetected(
    IDDetected event,
    Emitter<IDScannerState> emit,
  ) async {
    emit(ValidatingID(extractedId: event.extractedId));

    try {
      // Validate staff ID against backend
      final result = await _attendanceService.validateStaffId(event.extractedId);
      
      if (result['valid'] == true) {
        emit(StaffFound(
          staffId: result['staffId'],
          staffName: result['staffName'],
          photoUrl: result['photoUrl'],
        ));
      } else {
        emit(const ScanError(
          message: 'Invalid staff ID. Please try again.',
          errorCode: AttendanceErrorCode.staffNotFound,
        ));
      }
    } on AttendanceException catch (e) {
      emit(ScanError(
        message: e.message,
        errorCode: e.code,
        isRetryable: e.retryable,
      ));
    } catch (e) {
      emit(ScanError(
        message: 'Failed to validate ID: ${e.toString()}',
        errorCode: AttendanceErrorCode.unknown,
        isRetryable: true,
      ));
    }
  }

  void _onStaffValidated(
    StaffValidated event,
    Emitter<IDScannerState> emit,
  ) {
    emit(StaffFound(
      staffId: event.staffId,
      staffName: event.staffName,
      photoUrl: event.photoUrl,
    ));
  }

  void _onConfirmShiftStart(
    ConfirmShiftStart event,
    Emitter<IDScannerState> emit,
  ) async {
    final currentState = state;
    if (currentState is StaffFound) {
      emit(ProcessingShift(
        staffId: currentState.staffId,
        staffName: currentState.staffName,
      ));

      try {
        // p28(a) Idempotency: generate a UUID for this logical check-in and
        // persist it before sending so that if the app is killed mid-request
        // the same UUID is reused on the next attempt.
        final prefs = await SharedPreferences.getInstance();
        String? clientRequestId = prefs.getString(_kPendingCheckInKey);
        if (clientRequestId == null) {
          clientRequestId = _uuid.v4();
          await prefs.setString(_kPendingCheckInKey, clientRequestId);
        }

        try {
          final result = await _attendanceService.checkIn(
            staffId: currentState.staffId,
            stationId: await _attendanceService.getStationId(),
            clientRequestId: clientRequestId,
          );

          // Clear the pending key only after a confirmed server response so that
          // a crash or network drop before this line causes a safe retry with the
          // same UUID (server returns idempotent replay).
          await prefs.remove(_kPendingCheckInKey);

          final isReplay =
              result['idempotentReplay'] == true || result['alreadyActive'] == true;

          emit(ShiftStarted(
            shiftId: result['shiftId'] as String,
            checkInTime: DateTime.parse(result['checkInTime'] as String),
            staffName: currentState.staffName,
            idempotentReplay: isReplay,
          ));
        } on AttendanceException catch (e) {
          // p28(d): SHIFT_ALREADY_ACTIVE is a soft-success — the shift already
          // exists. Navigate to the dashboard using the existing shiftId.
          if (e.code == AttendanceErrorCode.shiftAlreadyActive &&
              e.extra['shiftId'] != null) {
            await prefs.remove(_kPendingCheckInKey);
            emit(ShiftStarted(
              shiftId: e.extra['shiftId'] as String,
              checkInTime: e.extra['checkInTime'] != null
                  ? DateTime.parse(e.extra['checkInTime'] as String)
                  : DateTime.now(),
              staffName: currentState.staffName,
              idempotentReplay: true,
            ));
            return;
          }
          emit(ScanError(
            message: e.actionHint,
            errorCode: e.code,
            isRetryable: e.retryable,
          ));
        }
      } catch (e) {
        emit(ScanError(
          message: 'Failed to start shift: ${e.toString()}',
          errorCode: AttendanceErrorCode.unknown,
          isRetryable: true,
        ));
      }
    }
  }

  void _onManualIdEntered(
    ManualIdEntered event,
    Emitter<IDScannerState> emit,
  ) async {
    emit(ValidatingID(extractedId: event.staffId));

    try {
      final result = await _attendanceService.validateStaffId(event.staffId);
      
      if (result['valid'] == true) {
        emit(StaffFound(
          staffId: result['staffId'],
          staffName: result['staffName'],
          photoUrl: result['photoUrl'],
        ));
      } else {
        emit(const ScanError(
          message: 'Invalid staff ID. Please try again.',
          errorCode: AttendanceErrorCode.staffNotFound,
        ));
      }
    } on AttendanceException catch (e) {
      emit(ScanError(
        message: e.message,
        errorCode: e.code,
        isRetryable: e.retryable,
      ));
    } catch (e) {
      emit(ScanError(
        message: 'Failed to validate ID: ${e.toString()}',
        errorCode: AttendanceErrorCode.unknown,
        isRetryable: true,
      ));
    }
  }

  void _onRetryScan(
    RetryScan event,
    Emitter<IDScannerState> emit,
  ) {
    emit(const ScanningActive());
  }
}
