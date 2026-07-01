// ============================================================================
// UNIT CONVERSION SERVICE (bugfix.md 2.13)
// ============================================================================
// Mixed-unit conversion for the hardware vertical line-item flow. Gated behind
// the `useMultiUnit` capability (granted to hardware). Supports the two
// conversions the hardware checklist calls out:
//   * length: feet ↔ metres
//   * packaging: box ↔ pieces (configurable pieces-per-box)
//
// Pure value logic — no I/O, no Flutter dependency — so it is trivially
// unit-testable and safe to call from the line-item editor.
// ============================================================================

/// Supported unit families. A conversion is only valid within one family
/// (plus the box↔pcs packaging conversion which needs a pack size).
enum UnitKind { length, packaging, unknown }

class UnitConversionService {
  const UnitConversionService();

  /// 1 foot = 0.3048 metre (exact, international foot).
  static const double _metresPerFoot = 0.3048;

  /// Canonical aliases → normalised unit token.
  static const Map<String, String> _aliases = <String, String>{
    'ft': 'ft',
    'feet': 'ft',
    'foot': 'ft',
    'mtr': 'mtr',
    'm': 'mtr',
    'metre': 'mtr',
    'meter': 'mtr',
    'box': 'box',
    'boxes': 'box',
    'pcs': 'pcs',
    'pc': 'pcs',
    'piece': 'pcs',
    'pieces': 'pcs',
  };

  /// Normalise a free-text unit to a canonical token, or null if unknown.
  String? normalise(String unit) => _aliases[unit.trim().toLowerCase()];

  /// The family a unit belongs to.
  UnitKind kindOf(String unit) {
    switch (normalise(unit)) {
      case 'ft':
      case 'mtr':
        return UnitKind.length;
      case 'box':
      case 'pcs':
        return UnitKind.packaging;
      default:
        return UnitKind.unknown;
    }
  }

  /// True when [from] can be converted to [to] (within a family, or box↔pcs
  /// when [piecesPerBox] is supplied).
  bool canConvert(String from, String to, {int? piecesPerBox}) {
    final f = normalise(from);
    final t = normalise(to);
    if (f == null || t == null) return false;
    if (f == t) return true;
    if ((f == 'ft' && t == 'mtr') || (f == 'mtr' && t == 'ft')) return true;
    if ((f == 'box' && t == 'pcs') || (f == 'pcs' && t == 'box')) {
      return piecesPerBox != null && piecesPerBox > 0;
    }
    return false;
  }

  /// Convert [value] from unit [from] to unit [to].
  ///
  /// Throws [ArgumentError] when the conversion is not supported (e.g. crossing
  /// families, or box↔pcs without a valid [piecesPerBox]).
  double convert(double value, String from, String to, {int? piecesPerBox}) {
    final f = normalise(from);
    final t = normalise(to);
    if (f == null || t == null) {
      throw ArgumentError('Unknown unit: "$from" → "$to"');
    }
    if (f == t) return value;

    // Length family.
    if (f == 'ft' && t == 'mtr') return value * _metresPerFoot;
    if (f == 'mtr' && t == 'ft') return value / _metresPerFoot;

    // Packaging family.
    if (f == 'box' && t == 'pcs') {
      _requirePack(piecesPerBox);
      return value * piecesPerBox!;
    }
    if (f == 'pcs' && t == 'box') {
      _requirePack(piecesPerBox);
      return value / piecesPerBox!;
    }

    throw ArgumentError(
      'Unsupported conversion: "$from" → "$to" (different unit families)',
    );
  }

  void _requirePack(int? piecesPerBox) {
    if (piecesPerBox == null || piecesPerBox <= 0) {
      throw ArgumentError(
        'box↔pcs conversion requires a positive piecesPerBox',
      );
    }
  }
}
