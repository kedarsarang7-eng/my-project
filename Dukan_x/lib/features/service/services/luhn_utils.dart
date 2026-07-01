/// Luhn validation utilities
/// Pure helper for validating 15-digit IMEI numbers using the Luhn algorithm.
library;

/// Returns `true` if [imei] is exactly 15 numeric digits and passes the
/// Luhn checksum algorithm.
///
/// The Luhn algorithm:
/// 1. Starting from the rightmost digit, double every second digit.
/// 2. If doubling results in a value > 9, subtract 9.
/// 3. Sum all digits.
/// 4. Valid if sum % 10 == 0.
///
/// A value that is not exactly 15 numeric digits is NOT a valid IMEI — callers
/// should treat it as a generic serial and skip the Luhn check entirely.
bool isValidLuhn15(String imei) {
  // Must be exactly 15 characters and all numeric
  if (imei.length != 15) return false;
  if (int.tryParse(imei) == null) return false;

  var sum = 0;
  for (var i = 0; i < imei.length; i++) {
    var digit = int.parse(imei[imei.length - 1 - i]);

    // Double every second digit (starting from the rightmost, index 0 is not
    // doubled, index 1 is doubled, etc.)
    if (i.isOdd) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }

    sum += digit;
  }

  return sum % 10 == 0;
}
