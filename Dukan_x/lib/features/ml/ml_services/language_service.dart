// ML Kit Language Detection Service
//
// Identifies the language of text to support translation and formatting.
//
// Features:
// - Detects 100+ languages
// - Confidence scoring
// - Fallback mechanism
// - Proper resource disposal
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

/// Result of language detection
class LanguageDetectionResult {
  /// BCP-47 language code (e.g., "hi", "mr", "en")
  final String languageCode;

  /// Human-readable language name
  final String languageName;

  /// Confidence score (0.0-1.0)
  final double confidence;

  /// Whether detection was successful
  final bool success;

  const LanguageDetectionResult({
    required this.languageCode,
    required this.languageName,
    required this.confidence,
    this.success = true,
  });

  /// Fallback result when detection fails
  factory LanguageDetectionResult.unknown() => const LanguageDetectionResult(
    languageCode: 'und',
    languageName: 'Unknown',
    confidence: 0.0,
    success: false,
  );

  /// Default to English
  factory LanguageDetectionResult.english() => const LanguageDetectionResult(
    languageCode: 'en',
    languageName: 'English',
    confidence: 1.0,
    success: true,
  );
}

/// On-device language detection service
class LanguageDetectionService {
  /// Lazy-initialized language identifier
  LanguageIdentifier? _identifier;

  /// Get or create the identifier
  LanguageIdentifier _getIdentifier() {
    _identifier ??= LanguageIdentifier(confidenceThreshold: 0.5);
    return _identifier!;
  }

  /// Detect the language of the given text
  ///
  /// Returns [LanguageDetectionResult] with detected language and confidence
  Future<LanguageDetectionResult> detectLanguage(String text) async {
    if (kIsWeb) {
      debugPrint(
        'LanguageDetectionService: Web not supported, defaulting to English',
      );
      return LanguageDetectionResult.english();
    }

    if (text.isEmpty || text.length < 10) {
      debugPrint(
        'LanguageDetectionService: Text too short for reliable detection',
      );
      return LanguageDetectionResult.unknown();
    }

    try {
      final identifier = _getIdentifier();
      final languageCode = await identifier.identifyLanguage(text);

      if (languageCode == 'und') {
        debugPrint('LanguageDetectionService: Could not determine language');
        return LanguageDetectionResult.unknown();
      }

      final languageName = _getLanguageName(languageCode);
      debugPrint(
        'LanguageDetectionService: Detected $languageName ($languageCode)',
      );

      return LanguageDetectionResult(
        languageCode: languageCode,
        languageName: languageName,
        confidence:
            0.8, // ML Kit doesn't return confidence for single detection
        success: true,
      );
    } catch (e) {
      debugPrint('LanguageDetectionService Error: $e');
      return LanguageDetectionResult.unknown();
    }
  }

  /// Detect possible languages with confidence scores
  ///
  /// Returns list of possible languages sorted by confidence
  Future<List<LanguageDetectionResult>> detectPossibleLanguages(
    String text,
  ) async {
    if (kIsWeb || text.isEmpty || text.length < 10) {
      return [LanguageDetectionResult.english()];
    }

    try {
      final identifier = _getIdentifier();
      final languages = await identifier.identifyPossibleLanguages(text);

      return languages
          .where((lang) => lang.languageTag != 'und')
          .map(
            (lang) => LanguageDetectionResult(
              languageCode: lang.languageTag,
              languageName: _getLanguageName(lang.languageTag),
              confidence: lang.confidence,
              success: true,
            ),
          )
          .toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
    } catch (e) {
      debugPrint('LanguageDetectionService Error: $e');
      return [LanguageDetectionResult.unknown()];
    }
  }

  /// Get human-readable name for language code
  String _getLanguageName(String code) {
    const languageNames = {
      'en': 'English',
      'hi': 'Hindi',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'te': 'Telugu',
      'ta': 'Tamil',
      'gu': 'Gujarati',
      'ur': 'Urdu',
      'kn': 'Kannada',
      'or': 'Odia',
      'ml': 'Malayalam',
      'pa': 'Punjabi',
      'as': 'Assamese',
      'ne': 'Nepali',
      'sa': 'Sanskrit',
    };
    return languageNames[code] ?? code.toUpperCase();
  }

  /// Check if language is supported for translation
  bool isTranslationSupported(String languageCode) {
    const supportedLanguages = {
      'en',
      'hi',
      'mr',
      'bn',
      'te',
      'ta',
      'gu',
      'ur',
      'kn',
      'or',
      'ml',
    };
    return supportedLanguages.contains(languageCode);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _identifier?.close();
    _identifier = null;
    debugPrint('LanguageDetectionService: Disposed');
  }
}
