/// Pure integer arithmetic for box↔pieces conversion and line-amount
/// calculation in the wholesale vertical.
///
/// All operations use integer multiplication only — no floating-point
/// intermediary. This ensures paise-safe arithmetic throughout the
/// wholesale billing pipeline.
class UnitConverter {
  const UnitConverter();

  /// Converts a box count to pieces using the given conversion [factor].
  ///
  /// Formula: `pieces = boxes * factor`
  ///
  /// Throws [ArgumentError] if [factor] is not a positive integer (> 0).
  ///
  /// Example: `boxesToPieces(boxes: 5, factor: 12)` → `60`
  /// (5 boxes × 12 pieces/box = 60 pieces)
  int boxesToPieces({required int boxes, required int factor}) {
    if (factor <= 0) {
      throw ArgumentError.value(
        factor,
        'factor',
        'Conversion factor must be a positive integer',
      );
    }
    return boxes * factor;
  }

  /// Computes the line amount in paise (integer only).
  ///
  /// Formula: `lineAmountPaise = pieces * perPiecePaise`
  ///
  /// This is pure integer multiplication — no rounding, no float conversion.
  ///
  /// Example: `lineAmountPaise(pieces: 60, perPiecePaise: 500)` → `30000`
  /// (60 pieces × ₹5.00/piece = ₹300.00 = 30000 paise)
  int lineAmountPaise({required int pieces, required int perPiecePaise}) {
    return pieces * perPiecePaise;
  }
}
