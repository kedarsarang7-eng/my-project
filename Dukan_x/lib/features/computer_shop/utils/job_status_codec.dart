import 'computer_shop_business_rules.dart';

/// Codec that maps [ComputerJobStatus] to/from backend wire strings.
///
/// This is the ONLY component that reads or writes the backend status string.
/// All other layers work exclusively with the typed enum.
class JobStatusCodec {
  JobStatusCodec._();

  static const Map<ComputerJobStatus, String> _toWireMap = {
    ComputerJobStatus.intake: 'INTAKE',
    ComputerJobStatus.diagnosis: 'DIAGNOSIS',
    ComputerJobStatus.partsOrdered: 'AWAITING_PARTS',
    ComputerJobStatus.underRepair: 'REPAIRING',
    ComputerJobStatus.qa: 'QC',
    ComputerJobStatus.ready: 'READY',
    ComputerJobStatus.delivered: 'DELIVERED',
    ComputerJobStatus.cancelled: 'CANCELLED',
  };

  static const Map<String, ComputerJobStatus> _fromWireMap = {
    'INTAKE': ComputerJobStatus.intake,
    'DIAGNOSIS': ComputerJobStatus.diagnosis,
    'AWAITING_PARTS': ComputerJobStatus.partsOrdered,
    'REPAIRING': ComputerJobStatus.underRepair,
    'QC': ComputerJobStatus.qa,
    'READY': ComputerJobStatus.ready,
    'DELIVERED': ComputerJobStatus.delivered,
    'CANCELLED': ComputerJobStatus.cancelled,
  };

  static const Map<ComputerJobStatus, String> _labels = {
    ComputerJobStatus.intake: 'Intake',
    ComputerJobStatus.diagnosis: 'Diagnosis',
    ComputerJobStatus.partsOrdered: 'Parts Ordered',
    ComputerJobStatus.underRepair: 'Under Repair',
    ComputerJobStatus.qa: 'Quality Check',
    ComputerJobStatus.ready: 'Ready',
    ComputerJobStatus.delivered: 'Delivered',
    ComputerJobStatus.cancelled: 'Cancelled',
  };

  /// Converts a [ComputerJobStatus] enum value to its backend wire string.
  ///
  /// This is a total function — every enum value has a defined wire string.
  static String toWire(ComputerJobStatus status) => _toWireMap[status]!;

  /// Converts a backend wire string to the corresponding [ComputerJobStatus].
  ///
  /// Returns `null` for unrecognized strings, allowing the caller to reject
  /// or handle gracefully.
  static ComputerJobStatus? fromWire(String raw) => _fromWireMap[raw];

  /// Returns a UI-facing human-readable label for the given status.
  static String label(ComputerJobStatus status) => _labels[status]!;
}
