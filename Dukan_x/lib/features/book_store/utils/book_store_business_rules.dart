// Book store — domain rules (clause 2.16 of `bugfix.md`).
//
// Owns ISBN validation and the per-condition resale price floor that
// returned/used books must clear before going on the shelf again.

class BookStoreBusinessRules {
  BookStoreBusinessRules._();

  /// Validates an ISBN-10 or ISBN-13 string. Hyphens / spaces are ignored.
  /// Returns true iff the checksum is correct.
  static bool isValidIsbn(String raw) {
    final compact = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (compact.length == 10) return _isbn10Valid(compact);
    if (compact.length == 13) return _isbn13Valid(compact);
    return false;
  }

  /// Documented per-condition discount applied to the original retail
  /// price when accepting a returned / used book. The shopkeeper may
  /// override but the suggested floor is what we expose by default.
  ///
  /// new          -> 5% off  (publisher-return / shop-soiled)
  /// likeNew      -> 15% off
  /// good         -> 30% off
  /// acceptable   -> 50% off
  /// damaged      -> 75% off (hard floor; lower offers require manual approval)
  static double suggestedResalePrice(double originalPrice, BookCondition c) {
    if (originalPrice < 0) return 0;
    final pctOff = _resaleDiscount[c]!;
    final after = originalPrice * (1 - pctOff);
    // Round to nearest paise (half-up).
    return (after * 100).roundToDouble() / 100;
  }

  static const Map<BookCondition, double> _resaleDiscount = {
    BookCondition.brandNew: 0.05,
    BookCondition.likeNew: 0.15,
    BookCondition.good: 0.30,
    BookCondition.acceptable: 0.50,
    BookCondition.damaged: 0.75,
  };

  static bool _isbn10Valid(String s) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final c = s[i];
      final d = c == 'X' && i == 9 ? 10 : int.tryParse(c);
      if (d == null) return false;
      sum += d * (10 - i);
    }
    return sum % 11 == 0;
  }

  static bool _isbn13Valid(String s) {
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      final d = int.tryParse(s[i]);
      if (d == null) return false;
      sum += d * (i.isEven ? 1 : 3);
    }
    return sum % 10 == 0;
  }
}

enum BookCondition { brandNew, likeNew, good, acceptable, damaged }
