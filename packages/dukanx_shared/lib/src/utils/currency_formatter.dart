import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _inrCompact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String format(double amount) => _inr.format(amount);

  static String compact(double amount) => _inrCompact.format(amount);

  static String formatSigned(double amount) {
    final formatted = _inr.format(amount.abs());
    return amount < 0 ? '-$formatted' : formatted;
  }
}
