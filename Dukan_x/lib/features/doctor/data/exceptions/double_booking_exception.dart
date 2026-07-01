/// Thrown when a proposed appointment slot overlaps an existing appointment
/// for the same doctor.
///
/// Callers should surface this to the user so they can pick a different time
/// or cancel the conflicting appointment. The exception carries both the
/// proposed and conflicting appointment ids for diagnostics.
class DoubleBookingException implements Exception {
  /// The doctor whose schedule has the conflict.
  final String doctorId;

  /// The proposed appointment id that was rejected.
  final String proposedAppointmentId;

  /// The existing appointment id that conflicts.
  final String conflictingAppointmentId;

  /// Human-readable scheduled time of the conflicting appointment.
  final DateTime conflictingTime;

  const DoubleBookingException({
    required this.doctorId,
    required this.proposedAppointmentId,
    required this.conflictingAppointmentId,
    required this.conflictingTime,
  });

  @override
  String toString() =>
      'DoubleBookingException: appointment "$proposedAppointmentId" overlaps '
      'existing appointment "$conflictingAppointmentId" '
      '(scheduled at ${conflictingTime.toIso8601String()}) '
      'for doctor "$doctorId". Choose a non-overlapping slot.';
}
