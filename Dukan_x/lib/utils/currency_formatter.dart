import 'package:intl/intl.dart';
import '../core/di/service_locator.dart';
import '../core/services/currency_service.dart';

class CurrencyFormatter {
  /// Resolve the active currency symbol from [CurrencyService].
  /// Falls back to '₹' during early bootstrap before DI is ready.
  static String get _currencySymbol {
    try {
      if (sl.isRegistered<CurrencyService>()) {
        return sl<CurrencyService>().symbol;
      }
    } catch (_) {}
    return '₹';
  }

  static String get _locale {
    try {
      if (sl.isRegistered<CurrencyService>()) {
        return sl<CurrencyService>().current.locale;
      }
    } catch (_) {}
    return 'en_IN';
  }

  static String format(int cents) {
    final rupees = cents / 100;
    try {
      if (sl.isRegistered<CurrencyService>()) {
        return sl<CurrencyService>().format(rupees);
      }
    } catch (_) {}
    final formatter = NumberFormat.currency(
      locale: _locale,
      symbol: _currencySymbol,
      decimalDigits: 2,
    );
    return formatter.format(rupees);
  }
  
  static String formatShort(int cents) {
    final rupees = cents / 100;
    final sym = _currencySymbol;
    
    if (rupees >= 100000) { // 1 lakh+
      return '$sym${(rupees / 100000).toStringAsFixed(1)}L';
    } else if (rupees >= 1000) { // 1k+
      return '$sym${(rupees / 1000).toStringAsFixed(1)}K';
    } else {
      return '$sym${rupees.toStringAsFixed(0)}';
    }
  }
  
  static String formatWithoutSymbol(int cents) {
    final rupees = cents / 100;
    try {
      if (sl.isRegistered<CurrencyService>()) {
        return sl<CurrencyService>().formatPlain(rupees);
      }
    } catch (_) {}
    final formatter = NumberFormat.currency(
      locale: _locale,
      symbol: '',
      decimalDigits: 2,
    );
    return formatter.format(rupees);
  }
}
