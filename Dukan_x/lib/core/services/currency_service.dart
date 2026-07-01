// ============================================================================
// CURRENCY SERVICE - MULTI-CURRENCY SUPPORT
// ============================================================================
// Centralizes currency formatting so the app can support any currency.
// Replaces all hardcoded '₹' symbols with a configurable currency.
//
// Usage:
//   final cs = sl<CurrencyService>();
//   cs.format(1234.56)  →  "₹1,234.56" (default)
//   cs.symbol           →  "₹"
// ============================================================================

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported currencies with metadata
class CurrencyInfo {
  final String code; // ISO 4217: INR, USD, EUR, etc.
  final String symbol; // ₹, $, €, etc.
  final String name; // Indian Rupee, US Dollar, etc.
  final int decimalDigits;
  final String locale; // For NumberFormat

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimalDigits = 2,
    this.locale = 'en_IN',
  });
}

class CurrencyService {
  static const _prefKey = 'app_currency_code';

  // ============================================
  // SUPPORTED CURRENCIES
  // ============================================
  static const Map<String, CurrencyInfo> supportedCurrencies = {
    'INR': CurrencyInfo(
      code: 'INR',
      symbol: '₹',
      name: 'Indian Rupee',
      locale: 'en_IN',
    ),
    'USD': CurrencyInfo(
      code: 'USD',
      symbol: '\$',
      name: 'US Dollar',
      locale: 'en_US',
    ),
    'EUR': CurrencyInfo(
      code: 'EUR',
      symbol: '€',
      name: 'Euro',
      locale: 'de_DE',
    ),
    'GBP': CurrencyInfo(
      code: 'GBP',
      symbol: '£',
      name: 'British Pound',
      locale: 'en_GB',
    ),
    'AED': CurrencyInfo(
      code: 'AED',
      symbol: 'د.إ',
      name: 'UAE Dirham',
      locale: 'ar_AE',
    ),
    'SAR': CurrencyInfo(
      code: 'SAR',
      symbol: '﷼',
      name: 'Saudi Riyal',
      locale: 'ar_SA',
    ),
    'JPY': CurrencyInfo(
      code: 'JPY',
      symbol: '¥',
      name: 'Japanese Yen',
      decimalDigits: 0,
      locale: 'ja_JP',
    ),
    'CNY': CurrencyInfo(
      code: 'CNY',
      symbol: '¥',
      name: 'Chinese Yuan',
      locale: 'zh_CN',
    ),
    'AUD': CurrencyInfo(
      code: 'AUD',
      symbol: 'A\$',
      name: 'Australian Dollar',
      locale: 'en_AU',
    ),
    'CAD': CurrencyInfo(
      code: 'CAD',
      symbol: 'C\$',
      name: 'Canadian Dollar',
      locale: 'en_CA',
    ),
    'SGD': CurrencyInfo(
      code: 'SGD',
      symbol: 'S\$',
      name: 'Singapore Dollar',
      locale: 'en_SG',
    ),
    'MYR': CurrencyInfo(
      code: 'MYR',
      symbol: 'RM',
      name: 'Malaysian Ringgit',
      locale: 'ms_MY',
    ),
    'BDT': CurrencyInfo(
      code: 'BDT',
      symbol: '৳',
      name: 'Bangladeshi Taka',
      locale: 'bn_BD',
    ),
    'NPR': CurrencyInfo(
      code: 'NPR',
      symbol: 'रू',
      name: 'Nepalese Rupee',
      locale: 'ne_NP',
    ),
    'LKR': CurrencyInfo(
      code: 'LKR',
      symbol: 'Rs',
      name: 'Sri Lankan Rupee',
      locale: 'si_LK',
    ),
    'NGN': CurrencyInfo(
      code: 'NGN',
      symbol: '₦',
      name: 'Nigerian Naira',
      locale: 'en_NG',
    ),
    'KES': CurrencyInfo(
      code: 'KES',
      symbol: 'KSh',
      name: 'Kenyan Shilling',
      locale: 'en_KE',
    ),
    'ZAR': CurrencyInfo(
      code: 'ZAR',
      symbol: 'R',
      name: 'South African Rand',
      locale: 'en_ZA',
    ),
    'BRL': CurrencyInfo(
      code: 'BRL',
      symbol: 'R\$',
      name: 'Brazilian Real',
      locale: 'pt_BR',
    ),
  };

  // Current active currency (defaults to INR)
  CurrencyInfo _current = supportedCurrencies['INR']!;
  late NumberFormat _formatter;

  CurrencyService() {
    _updateFormatter();
  }

  // ============================================
  // GETTERS
  // ============================================

  /// Current currency symbol (e.g. "₹")
  String get symbol => _current.symbol;

  /// Current currency code (e.g. "INR")
  String get code => _current.code;

  /// Current currency info
  CurrencyInfo get current => _current;

  /// List of all supported currencies
  List<CurrencyInfo> get allCurrencies => supportedCurrencies.values.toList();

  // ============================================
  // FORMATTING
  // ============================================

  /// Format a monetary amount with currency symbol.
  /// Example: format(1234.56) → "₹1,234.56"
  String format(double amount) {
    return _formatter.format(amount);
  }

  /// Format without symbol (just the number with grouping).
  /// Example: formatPlain(1234.56) → "1,234.56"
  String formatPlain(double amount) {
    return NumberFormat.decimalPatternDigits(
      decimalDigits: _current.decimalDigits,
    ).format(amount);
  }

  /// Format compact (e.g. ₹1.2K, ₹3.4L)
  String formatCompact(double amount) {
    return '${_current.symbol}${NumberFormat.compact().format(amount)}';
  }

  // ============================================
  // CONFIGURATION
  // ============================================

  /// Initialize from stored preferences.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey) ?? 'INR';
      setCurrency(savedCode);
    } catch (_) {
      // Default to INR if preferences fail
      setCurrency('INR');
    }
  }

  /// Change the active currency. Persists to SharedPreferences.
  Future<void> setCurrency(String currencyCode) async {
    final info = supportedCurrencies[currencyCode.toUpperCase()];
    if (info == null) return;

    _current = info;
    _updateFormatter();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, currencyCode);
    } catch (_) {
      // Silently fail for offline scenarios
    }
  }

  void _updateFormatter() {
    _formatter = NumberFormat.currency(
      locale: _current.locale,
      symbol: _current.symbol,
      decimalDigits: _current.decimalDigits,
    );
  }
}
