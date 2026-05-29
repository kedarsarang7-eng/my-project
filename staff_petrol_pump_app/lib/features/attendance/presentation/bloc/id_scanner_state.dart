// ============================================================================
// ID SCANNER STATES
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../domain/attendance_exception.dart';

abstract class IDScannerState extends Equatable {
  const IDScannerState();

  @override
  List<Object?> get props => [];
}

/// Initial/idle state
class ScanningIdle extends IDScannerState {
  const ScanningIdle();
}

/// Actively scanning
class ScanningActive extends IDScannerState {
  const ScanningActive();
}

/// Validating extracted ID
class ValidatingID extends IDScannerState {
  final String extractedId;

  const ValidatingID({required this.extractedId});

  @override
  List<Object?> get props => [extractedId];
}

/// Staff found and validated
class StaffFound extends IDScannerState {
  final String staffId;
  final String staffName;
  final String? photoUrl;

  const StaffFound({
    required this.staffId,
    required this.staffName,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [staffId, staffName, photoUrl];
}

/// Processing shift start
class ProcessingShift extends IDScannerState {
  final String staffId;
  final String staffName;

  const ProcessingShift({
    required this.staffId,
    required this.staffName,
  });

  @override
  List<Object?> get props => [staffId, staffName];
}

/// Shift started successfully (or confirmed already active via idempotent replay)
class ShiftStarted extends IDScannerState {
  final String shiftId;
  final DateTime checkInTime;
  final String staffName;
  /// True when the server confirmed this was an idempotent replay of an
  /// already-committed check-in (either via clientRequestId sentinel or the
  /// legacy 409 path). UI shows the same success screen; no special handling
  /// needed other than skipping the "already pending" warning toast.
  final bool idempotentReplay;

  const ShiftStarted({
    required this.shiftId,
    required this.checkInTime,
    required this.staffName,
    this.idempotentReplay = false,
  });

  @override
  List<Object?> get props => [shiftId, checkInTime, staffName, idempotentReplay];
}

/// Error state
class ScanError extends IDScannerState {
  final String message;

  /// Machine-readable error code — drive UI branching on this, not [message].
  final AttendanceErrorCode errorCode;

  /// True when the operation is safe to retry automatically.
  final bool isRetryable;

  /// Short user-facing action hint derived from [errorCode].
  String get actionHint => actionHintFor(errorCode);

  const ScanError({
    required this.message,
    this.errorCode = AttendanceErrorCode.unknown,
    this.isRetryable = false,
  });

  @override
  List<Object?> get props => [message, errorCode, isRetryable];
}
