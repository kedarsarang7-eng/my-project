// ============================================================================
// UOM CONVERSION ENGINE
// ============================================================================
// Handles unit-of-measure conversions for hardware shop billing.
//
// Example: "2 boxes of screws" → box contains 100 pcs → deduct 200 pcs
//          "5 feet of pipe" → pipe stored in metres → convert to 1.524 metres
//
// Design:
// - Each StockItem has a `baseUnit` (the atomic unit: pcs, kg, mtr)
// - Conversion factors define how many baseUnits = 1 of another unit
// - Billing can use any configured unit; stock always deducts in baseUnit
//
// Author: DukanX Engineering
// ============================================================================

/// Predefined conversion families (units that can convert between each other)
enum UomFamily {
  count,   // pcs, dozen, box, gross, set
  weight,  // kg, gm, quintal, ton
  length,  // mtr, ft, inch, cm, mm
  volume,  // ltr, ml, gallon
  area,    // sqft, sqmtr
  none,    // Custom / no family
}

/// A single unit of measure with its base conversion factor
class UomDefinition {
  final String code;       // 'pcs', 'box', 'dozen', 'kg', 'ft', etc.
  final String label;      // 'Pieces', 'Box', 'Dozen', etc.
  final UomFamily family;
  final double toBaseFactor; // How many base units = 1 of this unit

  const UomDefinition({
    required this.code,
    required this.label,
    required this.family,
    required this.toBaseFactor,
  });
}

/// Registry of all known UOMs with their conversion factors
class UomRegistry {
  UomRegistry._();

  // ─── COUNT FAMILY ────────────────────────────────
  // Base unit: pcs (1 pcs = 1)
  static const pcs    = UomDefinition(code: 'pcs',    label: 'Pieces',  family: UomFamily.count,  toBaseFactor: 1);
  static const dozen  = UomDefinition(code: 'dozen',  label: 'Dozen',   family: UomFamily.count,  toBaseFactor: 12);
  static const gross  = UomDefinition(code: 'gross',  label: 'Gross',   family: UomFamily.count,  toBaseFactor: 144);
  static const nos    = UomDefinition(code: 'nos',    label: 'Numbers', family: UomFamily.count,  toBaseFactor: 1);

  // ─── WEIGHT FAMILY ───────────────────────────────
  // Base unit: gm (1 gm = 1)
  static const gm      = UomDefinition(code: 'gm',      label: 'Grams',    family: UomFamily.weight, toBaseFactor: 1);
  static const kg      = UomDefinition(code: 'kg',      label: 'Kg',       family: UomFamily.weight, toBaseFactor: 1000);
  static const quintal = UomDefinition(code: 'quintal', label: 'Quintal',  family: UomFamily.weight, toBaseFactor: 100000);
  static const ton     = UomDefinition(code: 'ton',     label: 'Ton',      family: UomFamily.weight, toBaseFactor: 1000000);

  // ─── LENGTH FAMILY ───────────────────────────────
  // Base unit: mm (1 mm = 1)
  static const mm  = UomDefinition(code: 'mm',  label: 'mm',     family: UomFamily.length, toBaseFactor: 1);
  static const cm  = UomDefinition(code: 'cm',  label: 'cm',     family: UomFamily.length, toBaseFactor: 10);
  static const mtr = UomDefinition(code: 'mtr', label: 'Metre',  family: UomFamily.length, toBaseFactor: 1000);
  static const ft  = UomDefinition(code: 'ft',  label: 'Feet',   family: UomFamily.length, toBaseFactor: 304.8);
  static const inch = UomDefinition(code: 'inch', label: 'Inch', family: UomFamily.length, toBaseFactor: 25.4);

  // ─── VOLUME FAMILY ───────────────────────────────
  // Base unit: ml (1 ml = 1)
  static const ml  = UomDefinition(code: 'ml',  label: 'mL',    family: UomFamily.volume, toBaseFactor: 1);
  static const ltr = UomDefinition(code: 'ltr', label: 'Litre', family: UomFamily.volume, toBaseFactor: 1000);

  // ─── AREA FAMILY ─────────────────────────────────
  // Base unit: sq cm
  static const sqft  = UomDefinition(code: 'sqft',  label: 'Sq.Ft',  family: UomFamily.area, toBaseFactor: 929.03);
  static const sqmtr = UomDefinition(code: 'sqmtr', label: 'Sq.Mtr', family: UomFamily.area, toBaseFactor: 10000);

  /// All registered UOMs
  static const List<UomDefinition> all = [
    pcs, dozen, gross, nos,
    gm, kg, quintal, ton,
    mm, cm, mtr, ft, inch,
    ml, ltr,
    sqft, sqmtr,
  ];

  /// Lookup by code
  static UomDefinition? byCode(String code) {
    final lower = code.toLowerCase().trim();
    try {
      return all.firstWhere((u) => u.code.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  /// Get all UOMs in a family
  static List<UomDefinition> byFamily(UomFamily family) {
    return all.where((u) => u.family == family).toList();
  }
}

/// Per-product custom UOM mapping.
/// Used when a product has a custom "box" size (e.g. box = 50 pcs for nails,
/// but box = 10 pcs for bolts).
class ProductUomConfig {
  final String productId;
  final String baseUnit; // e.g. 'pcs'
  final Map<String, double> customFactors; // e.g. {'box': 50, 'dozen': 12}

  const ProductUomConfig({
    required this.productId,
    required this.baseUnit,
    this.customFactors = const {},
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'baseUnit': baseUnit,
    'customFactors': customFactors,
  };

  factory ProductUomConfig.fromMap(Map<String, dynamic> m) {
    return ProductUomConfig(
      productId: m['productId']?.toString() ?? '',
      baseUnit: m['baseUnit']?.toString() ?? 'pcs',
      customFactors: (m['customFactors'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ) ?? {},
    );
  }
}

/// UOM Conversion Calculator
/// Performs unit conversions using either standard registry or per-product config.
class UomConverter {
  const UomConverter._();

  /// Convert quantity from [fromUnit] to [toUnit].
  ///
  /// Priority: 1) Product-specific customFactors, 2) Standard UomRegistry
  ///
  /// Returns converted quantity, or null if conversion is impossible.
  static double? convert({
    required double qty,
    required String fromUnit,
    required String toUnit,
    ProductUomConfig? productConfig,
  }) {
    if (fromUnit == toUnit) return qty;

    // 1. Try product-specific conversion
    if (productConfig != null) {
      final result = _convertViaProduct(qty, fromUnit, toUnit, productConfig);
      if (result != null) return result;
    }

    // 2. Try standard registry conversion
    return _convertViaRegistry(qty, fromUnit, toUnit);
  }

  /// Convert billing quantity to stock base unit quantity.
  ///
  /// Example: 2 boxes → 200 pcs (if box = 100 pcs for this product)
  static double? toBaseUnit({
    required double qty,
    required String billingUnit,
    required ProductUomConfig productConfig,
  }) {
    return convert(
      qty: qty,
      fromUnit: billingUnit,
      toUnit: productConfig.baseUnit,
      productConfig: productConfig,
    );
  }

  // ─── Internal ────────────────────────────────────

  static double? _convertViaProduct(
    double qty,
    String from,
    String to,
    ProductUomConfig config,
  ) {
    final base = config.baseUnit;

    // from → base → to
    double? fromToBase;
    if (from == base) {
      fromToBase = qty;
    } else if (config.customFactors.containsKey(from)) {
      fromToBase = qty * config.customFactors[from]!;
    } else {
      return null;
    }

    if (to == base) {
      return fromToBase;
    } else if (config.customFactors.containsKey(to)) {
      return fromToBase / config.customFactors[to]!;
    }

    return null;
  }

  static double? _convertViaRegistry(double qty, String from, String to) {
    final fromDef = UomRegistry.byCode(from);
    final toDef = UomRegistry.byCode(to);

    if (fromDef == null || toDef == null) return null;
    if (fromDef.family != toDef.family) return null; // Can't convert kg → mtr
    if (fromDef.family == UomFamily.none) return null;

    // Convert: qty * fromFactor / toFactor
    return qty * fromDef.toBaseFactor / toDef.toBaseFactor;
  }
}
