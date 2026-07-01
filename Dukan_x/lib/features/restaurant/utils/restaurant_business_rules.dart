// Restaurant — domain rules (clause 2.16 of `bugfix.md`).
//
// Owns KOT split logic, the dine-in service-charge formula, and the
// happy-hour-window check used to gate menu pricing tiers.

import 'package:decimal/decimal.dart';
import '../../../core/accounting/money_math.dart';

class RestaurantBusinessRules {
  RestaurantBusinessRules._();

  /// Split a single bill total across [splitCount] guests, distributing
  /// any rounding remainder to the first guest so the parts always sum
  /// back to the original total.
  static List<double> splitBill(double total, int splitCount) {
    if (splitCount <= 0 || total < 0) return const [];
    final cents = (total * 100).round();
    final base = cents ~/ splitCount;
    final remainder = cents - (base * splitCount);
    final out = List<double>.filled(splitCount, base / 100.0);
    out[0] += remainder / 100.0;
    return out
        .map((v) => MoneyMath.roundTo2(Decimal.parse(v.toString())).toDouble())
        .toList();
  }

  /// Service charge for dine-in orders. Documented rate is 5%, rounded
  /// half-up to paise. Takeaway / delivery orders never attract service
  /// charge — caller decides whether to call this helper.
  static double serviceCharge(double subtotal, {double rate = 0.05}) {
    if (subtotal <= 0) return 0;
    final v =
        Decimal.parse(subtotal.toString()) * Decimal.parse(rate.toString());
    return MoneyMath.roundTo2(v).toDouble();
  }

  /// True iff [now] sits inside the configured happy-hour window. Windows
  /// can wrap midnight, e.g. 22:00 → 02:00.
  static bool isInHappyHour({
    required DateTime now,
    required int startHour24,
    required int endHour24,
  }) {
    if (startHour24 == endHour24) return false;
    final h = now.hour;
    if (startHour24 < endHour24) {
      return h >= startHour24 && h < endHour24;
    }
    // Wrap-around window.
    return h >= startHour24 || h < endHour24;
  }
}
