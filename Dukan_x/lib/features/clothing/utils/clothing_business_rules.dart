// Clothing — domain rules (clause 2.16 of `bugfix.md`).
//
// Owns tailoring measurement validation and the standard size chart used
// by ready-made-garment SKUs.

class ClothingBusinessRules {
  ClothingBusinessRules._();

  /// Sanity bounds (in inches) for tailoring measurements. Anything
  /// outside the window is suspicious and the form must reject it.
  static const Map<MeasurementKey, ({double min, double max})> _bounds = {
    MeasurementKey.chest: (min: 20, max: 70),
    MeasurementKey.waist: (min: 18, max: 70),
    MeasurementKey.hip: (min: 20, max: 70),
    MeasurementKey.shoulder: (min: 8, max: 30),
    MeasurementKey.sleeve: (min: 5, max: 36),
    MeasurementKey.length: (min: 10, max: 60),
    MeasurementKey.inseam: (min: 10, max: 50),
  };

  /// True iff [valueInches] sits within the documented bounds for [key].
  static bool isValidMeasurement(MeasurementKey key, double valueInches) {
    final r = _bounds[key];
    if (r == null) return false;
    return valueInches >= r.min && valueInches <= r.max;
  }

  /// Maps an inch chest measurement to the standard size chart label.
  /// Edge values fall into the smaller bucket.
  static ClothingSize sizeForChest(double chestInches) {
    if (chestInches < 32) return ClothingSize.xs;
    if (chestInches < 36) return ClothingSize.s;
    if (chestInches < 40) return ClothingSize.m;
    if (chestInches < 44) return ClothingSize.l;
    if (chestInches < 48) return ClothingSize.xl;
    if (chestInches < 52) return ClothingSize.xxl;
    return ClothingSize.xxxl;
  }
}

enum MeasurementKey { chest, waist, hip, shoulder, sleeve, length, inseam }

enum ClothingSize { xs, s, m, l, xl, xxl, xxxl }
