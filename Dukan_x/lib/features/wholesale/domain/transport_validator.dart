import 'validation_result.dart';

/// Validates Transport_Details fields before persistence.
///
/// Required fields (vehicleNumber, transporterName) must be non-empty after
/// trimming. lrNumber is optional and may be empty.
///
/// Requirement 8.6: If a required Transport_Details field is left empty,
/// present a validation error and persist no incomplete record.
class TransportValidator {
  const TransportValidator();

  /// Validates the transport details for persistence.
  ///
  /// Returns [ValidationSuccess] when all required fields are present, or
  /// [ValidationFailure] with a reason describing the first missing field.
  ///
  /// Required: [vehicleNumber], [transporterName]
  /// Optional: [lrNumber]
  ValidationResult validate({
    required String vehicleNumber,
    required String transporterName,
    required String lrNumber,
  }) {
    final trimmedVehicle = vehicleNumber.trim();
    final trimmedTransporter = transporterName.trim();

    if (trimmedVehicle.isEmpty) {
      return const ValidationFailure(
        'Vehicle number is required and must not be empty',
      );
    }

    if (trimmedTransporter.isEmpty) {
      return const ValidationFailure(
        'Transporter name is required and must not be empty',
      );
    }

    return const ValidationSuccess();
  }
}
