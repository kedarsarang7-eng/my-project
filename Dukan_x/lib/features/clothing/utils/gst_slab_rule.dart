// Clothing — GST value-slab rule (Requirement 10).
//
// Indian apparel GST: 5% when 0 < taxableValue < ₹1000 (100,000 Paise),
// 12% when taxableValue >= ₹1000. All money is integer Paise with half-up
// rounding to whole Paise.

/// The threshold in Paise at which the GST rate switches from 5% to 12%.
/// ₹1000 = 100,000 Paise.
const int gstSlabThresholdPaise = 100000;

/// Result of a successful GST computation.
class GstResult {
  /// The GST amount in Paise (half-up rounded).
  final int amountPaise;

  /// The GST rate percent applied (5 or 12, or the override).
  final int ratePercent;

  const GstResult({required this.amountPaise, required this.ratePercent});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GstResult &&
          other.amountPaise == amountPaise &&
          other.ratePercent == ratePercent;

  @override
  int get hashCode => Object.hash(amountPaise, ratePercent);

  @override
  String toString() =>
      'GstResult(amountPaise: $amountPaise, ratePercent: $ratePercent)';
}

/// Error type returned when GST computation is rejected.
class GstError {
  final String message;
  const GstError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GstError && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'GstError($message)';
}

/// Combined result: either a successful [GstResult] or a [GstError].
/// When [error] is non-null the computation was rejected; when [result]
/// is non-null the computation succeeded.
class GstComputationResult {
  final GstResult? result;
  final GstError? error;

  /// The slab-computed rate retained when an override is rejected (Req 10.4).
  /// Non-null only when an override was rejected and the slab rate is retained.
  final int? retainedSlabRatePercent;

  const GstComputationResult.success(GstResult this.result)
    : error = null,
      retainedSlabRatePercent = null;

  const GstComputationResult.error(
    GstError this.error, {
    this.retainedSlabRatePercent,
  }) : result = null;

  bool get isSuccess => result != null;
  bool get isError => error != null;

  @override
  String toString() => isSuccess
      ? 'GstComputationResult.success($result)'
      : 'GstComputationResult.error($error, retainedSlabRatePercent: $retainedSlabRatePercent)';
}

/// Returns the GST rate percent (5 or 12) for the given taxable value in Paise.
///
/// Returns `null` if the value is <= 0 (invalid — Requirement 10.6).
///
/// - 5% when `0 < taxableValuePaise < 100,000` (Req 10.1)
/// - 12% when `taxableValuePaise >= 100,000` (Req 10.2)
int? gstRatePercentForTaxableValue(int taxableValuePaise) {
  if (taxableValuePaise <= 0) return null;
  if (taxableValuePaise < gstSlabThresholdPaise) return 5;
  return 12;
}

/// Computes the GST amount in Paise with half-up rounding to whole Paise.
///
/// The formula for half-up rounding:
///   `(taxableValuePaise * ratePercent + 50) ~/ 100`
///
/// Behavior:
/// - If [taxableValuePaise] is <= 0, rejects with an error (Req 10.6).
/// - If [overrideRatePercent] is provided and [gstEditable] is true,
///   the override rate is used (Req 10.3).
/// - If [overrideRatePercent] is provided and [gstEditable] is false,
///   the override is rejected, the slab rate is retained, and an error
///   is returned (Req 10.4).
/// - All intermediate and final money is integer Paise (Req 10.5).
GstComputationResult gstAmountPaise(
  int taxableValuePaise, {
  int? overrideRatePercent,
  required bool gstEditable,
}) {
  // Req 10.6: reject non-positive taxable value.
  if (taxableValuePaise <= 0) {
    return const GstComputationResult.error(
      GstError('Taxable value must be greater than 0 Paise'),
    );
  }

  // Determine slab rate.
  final int slabRate = gstRatePercentForTaxableValue(taxableValuePaise)!;

  // Handle override logic.
  final int effectiveRate;
  if (overrideRatePercent != null) {
    if (gstEditable) {
      // Req 10.3: honor the manual override.
      effectiveRate = overrideRatePercent;
    } else {
      // Req 10.4: reject override, retain slab rate, surface error.
      return GstComputationResult.error(
        const GstError('Manual GST edits are disabled'),
        retainedSlabRatePercent: slabRate,
      );
    }
  } else {
    effectiveRate = slabRate;
  }

  // Req 10.5: compute in integer Paise with half-up rounding.
  final int amount = _computeGstAmountPaise(taxableValuePaise, effectiveRate);

  return GstComputationResult.success(
    GstResult(amountPaise: amount, ratePercent: effectiveRate),
  );
}

/// Computes GST amount in Paise with half-up rounding.
///
/// Formula: `(taxableValuePaise * ratePercent + 50) ~/ 100`
///
/// This gives half-up rounding because adding 50 before integer-dividing by 100
/// rounds 0.5 Paise up to the next whole Paise.
int _computeGstAmountPaise(int taxableValuePaise, int ratePercent) {
  return (taxableValuePaise * ratePercent + 50) ~/ 100;
}
