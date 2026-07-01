import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';

/// Formats numbers in Indian numbering system (lakhs, crores)
/// e.g., 1,42,850 instead of 142,850
class IndianNumberFormatter {
  /// Resolve the active currency symbol from [CurrencyService].
  /// Falls back to '₹' during early bootstrap before DI is ready.
  static String get _sym {
    try {
      if (sl.isRegistered<CurrencyService>()) {
        return sl<CurrencyService>().symbol;
      }
    } catch (_) {}
    return '₹';
  }

  static NumberFormat get _currFormat {
    try {
      if (sl.isRegistered<CurrencyService>()) {
        final cs = sl<CurrencyService>();
        return NumberFormat.currency(
          locale: cs.current.locale,
          symbol: cs.symbol,
          decimalDigits: 0,
        );
      }
    } catch (_) {}
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  }

  static NumberFormat get _currFormatDecimal {
    try {
      if (sl.isRegistered<CurrencyService>()) {
        final cs = sl<CurrencyService>();
        return NumberFormat.currency(
          locale: cs.current.locale,
          symbol: cs.symbol,
          decimalDigits: 2,
        );
      }
    } catch (_) {}
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  }

  static final _numberFormat = NumberFormat('#,##,##0', 'en_IN');

  /// Format cents to currency display (₹1,42,850)
  static String formatCentsToInr(int cents) {
    final rupees = cents / 100;
    final sym = _sym;
    if (rupees >= 10000000) {
      return '$sym${(rupees / 10000000).toStringAsFixed(1)}Cr';
    } else if (rupees >= 100000) {
      return '$sym${(rupees / 100000).toStringAsFixed(1)}L';
    } else if (rupees >= 1000) {
      return '$sym${(rupees / 1000).toStringAsFixed(1)}k';
    }
    return _currFormat.format(rupees);
  }

  /// Format cents to full currency (₹1,42,850.00)
  static String formatCentsToInrFull(int cents) {
    return _currFormatDecimal.format(cents / 100);
  }

  /// Format rupees directly (₹1,42,850)
  static String formatRupees(double rupees) {
    final sym = _sym;
    if (rupees >= 10000000) {
      return '$sym${(rupees / 10000000).toStringAsFixed(1)}Cr';
    } else if (rupees >= 100000) {
      return '$sym${(rupees / 100000).toStringAsFixed(1)}L';
    }
    return _currFormat.format(rupees);
  }

  /// Format rupees with full precision (₹1,42,850)
  static String formatRupeesFull(double rupees) {
    return _currFormat.format(rupees);
  }

  /// Format plain number in Indian format (1,42,850)
  static String formatNumber(int number) {
    return _numberFormat.format(number);
  }

  /// Format cents for chart axis (₹10k, ₹1.5L, ₹2Cr)
  static String formatCentsForAxis(double cents) {
    final rupees = cents / 100;
    final sym = _sym;
    if (rupees.abs() >= 10000000) {
      return '$sym${(rupees / 10000000).toStringAsFixed(0)}Cr';
    } else if (rupees.abs() >= 100000) {
      return '$sym${(rupees / 100000).toStringAsFixed(0)}L';
    } else if (rupees.abs() >= 1000) {
      return '$sym${(rupees / 1000).toStringAsFixed(0)}k';
    }
    return '$sym${rupees.toStringAsFixed(0)}';
  }

  /// Format percentage with sign (+12.5%, -1.5%)
  static String formatPercent(double percent) {
    final sign = percent >= 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(1)}%';
  }
}
