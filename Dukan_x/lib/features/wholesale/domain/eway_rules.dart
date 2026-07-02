import 'validation_result.dart';

/// Data class holding the captured e-Way bill form fields.
///
/// All fields are required for a valid e-Way bill submission.
/// Used by [EWayRules.validateCapture] to verify completeness and format.
class EWayCapture {
  /// The name of the transporter (required, non-empty).
  final String transporterName;

  /// Approximate distance in kilometres (required, > 0).
  final int approxDistanceKm;

  /// Vehicle registration number (required, non-empty).
  final String vehicleNumber;

  /// Party's GSTIN — 15-character alphanumeric (required, validated format).
  final String partyGstin;

  const EWayCapture({
    required this.transporterName,
    required this.approxDistanceKm,
    required this.vehicleNumber,
    required this.partyGstin,
  });
}

/// e-Way bill threshold and capture validation rules.
///
/// An e-Way bill is legally required for inter-state goods consignments
/// exceeding ₹50,000 (5,000,000 paise). This class encapsulates:
/// - The threshold check ([isRequired])
/// - Capture form field validation ([validateCapture])
///
/// Per Phase 0 §5 (External_Dependency_Gate: GSP_Credentials-unavailable),
/// this layer ONLY performs capture + validation. No real e-Way number
/// generation occurs until GSP credentials become available.
class EWayRules {
  /// Threshold in integer paise: ₹50,000 = 5,000,000 paise.
  static const int thresholdPaise = 5000000;

  const EWayRules();

  /// Returns `true` if an e-Way bill is required for this consignment.
  ///
  /// An e-Way bill is required iff:
  /// 1. [consignmentPaise] > [thresholdPaise] (₹50,000), AND
  /// 2. [interState] is `true` (movement crosses state boundaries).
  ///
  /// Intra-state movements or amounts at or below the threshold do NOT
  /// require an e-Way bill.
  bool isRequired({required int consignmentPaise, required bool interState}) {
    return consignmentPaise > thresholdPaise && interState;
  }

  /// Validates the captured e-Way form fields.
  ///
  /// Returns [ValidationSuccess] if all fields pass, or [ValidationFailure]
  /// with a descriptive reason for the first failing field.
  ///
  /// Validation rules:
  /// - transporterName: non-empty after trim
  /// - approxDistanceKm: > 0
  /// - vehicleNumber: non-empty after trim
  /// - partyGstin: exactly 15 alphanumeric characters
  ValidationResult validateCapture(EWayCapture capture) {
    if (capture.transporterName.trim().isEmpty) {
      return const ValidationFailure('Transporter name is required');
    }

    if (capture.approxDistanceKm <= 0) {
      return const ValidationFailure(
        'Approximate distance must be greater than 0 km',
      );
    }

    if (capture.vehicleNumber.trim().isEmpty) {
      return const ValidationFailure('Vehicle number is required');
    }

    // GSTIN format: exactly 15 alphanumeric characters.
    final gstin = capture.partyGstin.trim();
    if (gstin.isEmpty) {
      return const ValidationFailure('Party GSTIN is required');
    }
    if (gstin.length != 15 || !_gstinPattern.hasMatch(gstin)) {
      return const ValidationFailure(
        'Party GSTIN must be exactly 15 alphanumeric characters',
      );
    }

    return const ValidationSuccess();
  }

  /// GSTIN: 15 alphanumeric characters (digits + uppercase/lowercase letters).
  static final RegExp _gstinPattern = RegExp(r'^[A-Za-z0-9]{15}$');
}
