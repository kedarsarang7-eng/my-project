// =============================================================================
// AppL10n — Production-grade localization utility
// =============================================================================
// Single entry point for all translated strings in DukanX.
//
// Usage in widgets:
//   final l10n = AppL10n.of(context);
//   Text(l10n.billing)
//   Text(l10n.invoiceFor('Ramesh'))
//
// Usage with BuildContext extension:
//   Text(context.l10n.billing)
//
// Usage for formatters (locale-aware):
//   AppL10n.formatCurrency(123456.50, context)   → '₹1,23,456.50' (Indian system)
//   AppL10n.formatDate(DateTime.now(), context)
//
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../generated/app_localizations.dart';
import 'remote_translation_service.dart';

export '../../generated/app_localizations.dart';

// =============================================================================
// BUILD CONTEXT EXTENSION — context.l10n shorthand
// =============================================================================

extension AppL10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// True when the active locale is RTL (currently only Urdu).
  bool get isRtl {
    final langCode = Localizations.localeOf(this).languageCode;
    return langCode == 'ur';
  }

  /// Active locale's language code.
  String get currentLangCode => Localizations.localeOf(this).languageCode;

  /// True when locale is Hindi, Marathi, Gujarati (Devanagari script family).
  bool get isDevanagari {
    const devanagariLocales = {'hi', 'mr', 'gu', 'ne', 'bho'};
    return devanagariLocales.contains(currentLangCode);
  }

  /// Look up [key] from the OTA translation delta first; falls back to [fallback].
  ///
  /// Usage:
  ///   Text(context.tOverride('billing', fallback: context.l10n.billing))
  ///
  /// For simple string keys where no interpolation is needed. For ARB keys
  /// with placeholders, continue using context.l10n.keyName(args) directly —
  /// OTA overrides for interpolated strings require manual interpolation.
  String tOverride(String key, {required String fallback}) {
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      final delta = container.read(translationDeltaProvider);
      return delta.lookup(currentLangCode, key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}

// =============================================================================
// AppL10n — Static Utility Class
// =============================================================================

class AppL10n {
  AppL10n._();

  /// Get AppLocalizations from context.
  static AppLocalizations of(BuildContext context) =>
      AppLocalizations.of(context)!;

  // ---------------------------------------------------------------------------
  // CURRENCY FORMATTING — Indian numbering system (lakhs/crores)
  // ---------------------------------------------------------------------------

  /// Format amount in Indian style: ₹1,23,456.50
  /// Always uses INR/Rupee symbol regardless of locale.
  static String formatCurrency(
    num amount, {
    bool showSymbol = true,
    int decimalDigits = 2,
    bool compact = false,
  }) {
    if (compact) {
      return _compactCurrency(amount.toDouble(), showSymbol);
    }
    final formatted = _indianNumberFormat(
      amount.toDouble(),
      decimalDigits: decimalDigits,
    );
    return showSymbol ? '₹$formatted' : formatted;
  }

  /// Format paise (int) to rupee display: 123456 paise → ₹1,234.56
  static String formatPaise(int paise, {bool compact = false}) {
    return formatCurrency(paise / 100, compact: compact);
  }

  /// Compact currency: ₹1.23L, ₹12.3Cr etc.
  static String _compactCurrency(double amount, bool showSymbol) {
    final symbol = showSymbol ? '₹' : '';
    if (amount >= 1e7) {
      return '$symbol${(amount / 1e7).toStringAsFixed(2)}Cr';
    } else if (amount >= 1e5) {
      return '$symbol${(amount / 1e5).toStringAsFixed(2)}L';
    } else if (amount >= 1e3) {
      return '$symbol${(amount / 1e3).toStringAsFixed(1)}K';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Indian number format: 123456.50 → "1,23,456.50"
  static String _indianNumberFormat(double amount, {int decimalDigits = 2}) {
    final str = amount.toStringAsFixed(decimalDigits);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    if (intPart.length <= 3) {
      return decPart.isEmpty ? intPart : '$intPart.$decPart';
    }

    // Indian grouping: last 3, then groups of 2
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final buffer = StringBuffer(last3);

    for (int i = rest.length; i > 0; i -= 2) {
      final start = i - 2 < 0 ? 0 : i - 2;
      buffer.write(',${rest.substring(start, i)}');
    }

    final result = buffer.toString().split('').reversed.join();
    return decPart.isEmpty ? result : '$result.$decPart';
  }

  // ---------------------------------------------------------------------------
  // DATE / TIME FORMATTING — locale-aware
  // ---------------------------------------------------------------------------

  /// Format date localized. E.g. "26 May 2025" / "२६ मई २०२५" (Hindi)
  static String formatDate(DateTime date, BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMMd(locale).format(date);
  }

  /// Short date: "26/05/25"
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  /// Medium date: "26 May 2025"
  static String formatDateMedium(DateTime date, BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date);
  }

  /// Time: "3:45 PM"
  static String formatTime(DateTime time, BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.jm(locale).format(time);
  }

  /// Date + Time: "26 May 2025, 3:45 PM"
  static String formatDateTime(DateTime dt, BuildContext context) {
    return '${formatDateMedium(dt, context)}, ${formatTime(dt, context)}';
  }

  /// Relative time: "2 hours ago", "just now", "yesterday"
  static String formatRelativeTime(DateTime dt, BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final l10n = AppL10n.of(context);

    if (diff.inMinutes < 1) return l10n.relativeJustNow;
    if (diff.inHours < 1) return l10n.relativeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.relativeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.relativeYesterday;
    if (diff.inDays < 7) return l10n.relativeDaysAgo(diff.inDays);
    return formatDateMedium(dt, context);
  }

  // ---------------------------------------------------------------------------
  // NUMBER FORMATTING
  // ---------------------------------------------------------------------------

  /// Format quantity: 1234 → "1,234" (Indian system for counts)
  static String formatNumber(num value) {
    if (value is int) {
      return _indianNumberFormat(value.toDouble(), decimalDigits: 0);
    }
    return _indianNumberFormat(value.toDouble(), decimalDigits: 2);
  }

  /// Format percentage: 18.5 → "18.5%"
  static String formatPercent(double value, {int digits = 1}) {
    return '${value.toStringAsFixed(digits)}%';
  }

  /// Format quantity with unit: "5.5 kg", "100 pcs"
  static String formatQuantityWithUnit(double qty, String unit) {
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
    return '$qtyStr $unit';
  }

  // ---------------------------------------------------------------------------
  // AMOUNT IN WORDS — for invoice PDFs
  // ---------------------------------------------------------------------------

  /// Convert numeric amount to words for invoice
  /// Returns English words only (used on PDF which may not have Devanagari font)
  static String amountInWords(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();
    final rupeesWords = _numberToWords(rupees);
    if (paise == 0) {
      return '$rupeesWords Rupees Only';
    }
    final paiseWords = _numberToWords(paise);
    return '$rupeesWords Rupees and $paiseWords Paise Only';
  }

  static const _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
    'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];

  static String _numberToWords(int n) {
    if (n == 0) return 'Zero';
    if (n < 0) return 'Minus ${_numberToWords(-n)}';
    if (n < 20) return _ones[n];
    if (n < 100) {
      return '${_tens[n ~/ 10]}${n % 10 != 0 ? ' ${_ones[n % 10]}' : ''}';
    }
    if (n < 1000) {
      return '${_ones[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${_numberToWords(n % 100)}' : ''}';
    }
    if (n < 100000) {
      return '${_numberToWords(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${_numberToWords(n % 1000)}' : ''}';
    }
    if (n < 10000000) {
      return '${_numberToWords(n ~/ 100000)} Lakh${n % 100000 != 0 ? ' ${_numberToWords(n % 100000)}' : ''}';
    }
    return '${_numberToWords(n ~/ 10000000)} Crore${n % 10000000 != 0 ? ' ${_numberToWords(n % 10000000)}' : ''}';
  }

  // ---------------------------------------------------------------------------
  // GST / TAX HELPERS
  // ---------------------------------------------------------------------------

  /// Format GST line: "GST @18% : ₹1,234.00"
  static String formatGstLine(
    String label,
    double rate,
    double amount,
  ) {
    return '$label @${formatPercent(rate)} : ${formatCurrency(amount)}';
  }

  /// Split amount into CGST + SGST (intra-state) or IGST (inter-state)
  static ({double cgst, double sgst, double igst}) splitGst({
    required double taxableAmount,
    required double gstRate,
    required bool isInterState,
  }) {
    final totalTax = taxableAmount * gstRate / 100;
    if (isInterState) {
      return (cgst: 0, sgst: 0, igst: totalTax);
    }
    final half = totalTax / 2;
    return (cgst: half, sgst: half, igst: 0);
  }

  // ---------------------------------------------------------------------------
  // FONT HELPERS — Script-aware font selection
  // ---------------------------------------------------------------------------

  /// Returns the optimal font family for the active locale.
  ///
  /// - Devanagari (hi/mr): 'NotoSansDevanagari'
  /// - Gujarati (gu): 'NotoSansGujarati'
  /// - Tamil (ta): 'NotoSansTamil'
  /// - Telugu (te): 'NotoSansTelugu'
  /// - Kannada (kn): 'NotoSansKannada'
  /// - Malayalam (ml): 'NotoSansMalayalam'
  /// - Bengali (bn): 'NotoSansBengali'
  /// - Punjabi (pa): 'NotoSansGurmukhi'
  /// - Urdu (ur): 'NotoNastaliqUrdu'
  /// - Default (en): 'Inter'
  static String fontFamilyForLocale(String languageCode) {
    return _scriptFonts[languageCode] ?? 'Inter';
  }

  static const _scriptFonts = <String, String>{
    'hi': 'NotoSansDevanagari',
    'mr': 'NotoSansDevanagari',
    'gu': 'NotoSansGujarati',
    'ta': 'NotoSansTamil',
    'te': 'NotoSansTelugu',
    'kn': 'NotoSansKannada',
    'ml': 'NotoSansMalayalam',
    'bn': 'NotoSansBengali',
    'pa': 'NotoSansGurmukhi',
    'ur': 'NotoNastaliqUrdu',
    'en': 'Inter',
  };

  /// Get TextStyle override with correct font for locale
  static TextStyle localizedTextStyle(
    String languageCode, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamilyForLocale(languageCode),
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? _lineHeightForLocale(languageCode),
    );
  }

  /// Optimal line height for each script (Devanagari needs more vertical space)
  static double _lineHeightForLocale(String languageCode) {
    switch (languageCode) {
      case 'hi':
      case 'mr':
      case 'gu':
        return 1.6; // Devanagari needs more vertical space for matras
      case 'ta':
      case 'te':
      case 'kn':
      case 'ml':
        return 1.5; // South Indian scripts
      case 'ur':
        return 1.8; // Nastaliq needs most vertical space
      default:
        return 1.4; // Latin / Gurmukhi
    }
  }

  // ---------------------------------------------------------------------------
  // LOCALE SCALE FACTOR — layout expansion
  // ---------------------------------------------------------------------------

  /// Some languages expand text width by 30-40% vs English.
  /// Use this to provide adaptive layouts.
  static double textScaleFactorForLocale(String languageCode) {
    switch (languageCode) {
      case 'ta':
      case 'te':
      case 'kn':
      case 'ml':
        return 1.15; // South Indian script labels are wider
      case 'ur':
        return 1.2; // Urdu RTL
      default:
        return 1.0;
    }
  }

  // ---------------------------------------------------------------------------
  // RTL HELPERS
  // ---------------------------------------------------------------------------

  static const _rtlLocales = {'ur', 'ar', 'fa', 'he'};

  static bool isRtlLocale(String languageCode) =>
      _rtlLocales.contains(languageCode);

  static TextDirection textDirectionForLocale(String languageCode) =>
      isRtlLocale(languageCode) ? TextDirection.rtl : TextDirection.ltr;
}

extension AppLocalizationsExtension on AppLocalizations {
  // Relative Time Getters/Methods
  String get relativeJustNow => 'just now';
  String relativeMinutesAgo(int minutes) => '$minutes minutes ago';
  String relativeHoursAgo(int hours) => '$hours hours ago';
  String get relativeYesterday => 'yesterday';
  String relativeDaysAgo(int days) => '$days days ago';

  // Business Types
  String get businessTypeGrocery => 'Grocery Store';
  String get businessTypePharmacy => 'Pharmacy';
  String get businessTypeRestaurant => 'Restaurant';
  String get businessTypeClothing => 'Clothing / Fashion';
  String get businessTypeElectronics => 'Electronics';
  String get businessTypeMobileShop => 'Mobile Shop';
  String get businessTypeComputerShop => 'Computer Shop';
  String get businessTypeHardware => 'Hardware Store';
  String get businessTypeService => 'Services';
  String get businessTypeWholesale => 'Wholesale';
  String get businessTypePetrolPump => 'Petrol Pump';
  String get businessTypeVegetableBroker => 'Mandi / Vegetable Broker';
  String get businessTypeClinic => 'Clinic / Doctor';
  String get businessTypeBookStore => 'Book Store';
  String get businessTypeJewellery => 'Jewellery Shop';
  String get businessTypeAutoParts => 'Auto Parts';
  String get businessTypeDecorationCatering => 'Decoration & Catering';
  String get businessTypeSchoolErp => 'School ERP';
  String get businessTypeOther => 'Other';

  // Validators
  String validationRequired(Object field) => '$field is required';
  String validationMinLength(Object field, Object min) => '$field must be at least $min characters';
  String validationMaxLength(Object field, Object max) => '$field cannot exceed $max characters';
  String get validationInvalidEmail => 'Invalid email address';
  String get validationInvalidPhone => 'Invalid phone number';
  String get validationInvalidGstin => 'Invalid GSTIN';
  String get validationInvalidPan => 'Invalid PAN';
  String validationPositiveNumber(Object field) => '$field must be a positive number';
  String get validationAmountZero => 'Amount must be greater than zero';
  String validationFutureDate(Object field) => '$field cannot be in the future';
  String validationPastDate(Object field) => '$field cannot be in the past';
  String get validationPasswordWeak => 'Password is too weak';
  String validationMismatch(Object field1, Object field2) => '$field1 does not match $field2';
}
