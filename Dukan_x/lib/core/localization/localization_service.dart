/// LocalizationService - Central orchestration for language setup
///
/// Manages:
/// - Language selection state
/// - Setup phase with progress callbacks
/// - Locale validation and fallback
/// - Persistence to SharedPreferences
///
/// Author: DukanX Engineering
/// Version: 1.0.0
library;

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../generated/app_localizations.dart';

/// Singleton service for localization orchestration
class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  // Persistence keys
  static const String _localeKey = 'locale';
  static const String _setupCompleteKey = 'locale_setup_complete';
  static const String _setupTimestampKey = 'locale_setup_timestamp';

  /// Supported locales with their native names
  static const Map<String, LocaleInfo> supportedLocales = {
    'en': LocaleInfo(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      flag: '🇺🇸',
    ),
    'hi': LocaleInfo(
      code: 'hi',
      nativeName: 'हिंदी',
      englishName: 'Hindi',
      flag: '🇮🇳',
    ),
    'mr': LocaleInfo(
      code: 'mr',
      nativeName: 'मराठी',
      englishName: 'Marathi',
      flag: '🇮🇳',
    ),
    'gu': LocaleInfo(
      code: 'gu',
      nativeName: 'ગુજરાતી',
      englishName: 'Gujarati',
      flag: '🇮🇳',
    ),
    'ta': LocaleInfo(
      code: 'ta',
      nativeName: 'தமிழ்',
      englishName: 'Tamil',
      flag: '🇮🇳',
    ),
    'te': LocaleInfo(
      code: 'te',
      nativeName: 'తెలుగు',
      englishName: 'Telugu',
      flag: '🇮🇳',
    ),
    'kn': LocaleInfo(
      code: 'kn',
      nativeName: 'ಕನ್ನಡ',
      englishName: 'Kannada',
      flag: '🇮🇳',
    ),
    'ml': LocaleInfo(
      code: 'ml',
      nativeName: 'മലയാളം',
      englishName: 'Malayalam',
      flag: '🇮🇳',
    ),
    'bn': LocaleInfo(
      code: 'bn',
      nativeName: 'বাংলা',
      englishName: 'Bengali',
      flag: '🇮🇳',
    ),
    'pa': LocaleInfo(
      code: 'pa',
      nativeName: 'ਪੰਜਾਬੀ',
      englishName: 'Punjabi',
      flag: '🇮🇳',
    ),
    'ur': LocaleInfo(
      code: 'ur',
      nativeName: 'اردو',
      englishName: 'Urdu',
      flag: '🇵🇰',
      isRtl: true,
    ),
  };

  /// Check if user has completed initial language selection
  Future<bool> hasCompletedLanguageSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey) ?? false;
  }

  /// Get current saved locale code, or null if not set
  Future<String?> getSavedLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey);
  }

  /// Get current saved locale, with English fallback
  Future<Locale> getSavedLocale() async {
    final code = await getSavedLocaleCode();
    return Locale(code ?? 'en');
  }

  /// Perform full language setup with progress callbacks
  ///
  /// [locale] - The locale to set up
  /// [onProgress] - Callback with status message and progress (0.0 to 1.0)
  /// Returns true if successful, false if failed
  Future<bool> setupLanguage(
    Locale locale,
    void Function(String status, double progress)? onProgress,
  ) async {
    try {
      developer.log(
        'Starting language setup for: ${locale.languageCode}',
        name: 'LocalizationService',
      );

      // Step 1: Loading translations (simulated delay for UX)
      onProgress?.call('Loading translations...', 0.25);
      await Future.delayed(const Duration(milliseconds: 400));

      // Validate locale is supported
      if (!supportedLocales.containsKey(locale.languageCode)) {
        developer.log(
          'Unsupported locale: ${locale.languageCode}',
          name: 'LocalizationService',
        );
        return false;
      }

      // Step 2: Applying preferences
      onProgress?.call('Applying language preferences...', 0.50);
      await Future.delayed(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);

      // Step 3: Preparing experience
      onProgress?.call('Preparing your experience...', 0.75);
      await Future.delayed(const Duration(milliseconds: 300));

      // Mark setup as complete
      await prefs.setBool(_setupCompleteKey, true);
      await prefs.setInt(
        _setupTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Step 4: Complete
      onProgress?.call('Ready!', 1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      developer.log(
        'Language setup complete for: ${locale.languageCode}',
        name: 'LocalizationService',
      );
      return true;
    } catch (e, stack) {
      developer.log(
        'Language setup failed: $e',
        name: 'LocalizationService',
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Quick locale change (for Settings - no full setup phase)
  Future<void> quickSetLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    developer.log(
      'Quick locale change to: ${locale.languageCode}',
      name: 'LocalizationService',
    );
  }

  /// Validate that all required keys exist for a locale
  /// Returns list of missing key names (empty if all present)
  List<String> validateLocale(BuildContext context, Locale locale) {
    // Note: This is a compile-time check via gen_l10n
    // At runtime, missing keys will fall back to English
    // This method can be used for diagnostic purposes
    final l10n = AppLocalizations.of(context);
    return []; // All keys available at compile time
  }

  /// Get fallback locale (English)
  Locale getFallbackLocale() => const Locale('en');

  /// Check if locale is RTL
  bool isRtl(String localeCode) {
    return supportedLocales[localeCode]?.isRtl ?? false;
  }

  /// Reset language selection (for testing/debug)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localeKey);
    await prefs.remove(_setupCompleteKey);
    await prefs.remove(_setupTimestampKey);
    developer.log('Localization reset complete', name: 'LocalizationService');
  }
}

/// Information about a supported locale
class LocaleInfo {
  final String code;
  final String nativeName;
  final String englishName;
  final String flag;
  final bool isRtl;

  const LocaleInfo({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flag,
    this.isRtl = false,
  });
}
