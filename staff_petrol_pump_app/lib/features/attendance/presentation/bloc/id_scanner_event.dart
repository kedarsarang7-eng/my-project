// ============================================================================
// ID SCANNER EVENTS
// ============================================================================

import 'package:equatable/equatable.dart';

abstract class IDScannerEvent extends Equatable {
  const IDScannerEvent();

  @override
  List<Object?> get props => [];
}

/// Camera initialized successfully
class CameraInitialized extends IDScannerEvent {
  const CameraInitialized();
}

/// Camera error occurred
class CameraError extends IDScannerEvent {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}

/// ID detected from OCR
class IDDetected extends IDScannerEvent {
  final String extractedId;
  final double confidence;

  const IDDetected({
    required this.extractedId,
    required this.confidence,
  });

  @override
  List<Object?> get props => [extractedId, confidence];
}

/// Staff validated successfully
class StaffValidated extends IDScannerEvent {
  final String staffId;
  final String staffName;
  final String? photoUrl;

  const StaffValidated({
    required this.staffId,
    required this.staffName,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [staffId, staffName, photoUrl];
}

/// Confirm and start shift
class ConfirmShiftStart extends IDScannerEvent {
  const ConfirmShiftStart();
}

/// Manual ID entry
class ManualIdEntered extends IDScannerEvent {
  final String staffId;

  const ManualIdEntered({required this.staffId});

  @override
  List<Object?> get props => [staffId];
}

/// Retry scan
class RetryScan extends IDScannerEvent {
  const RetryScan();
}
