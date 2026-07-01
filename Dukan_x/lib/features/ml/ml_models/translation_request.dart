// Translation Request & Result Models
//
// Domain models for on-device translation. request with source and target languages.

import 'package:equatable/equatable.dart';

/// Request for on-device translation
class TranslationRequest extends Equatable {
  /// Text to translate
  final String text;

  /// Source language BCP-47 code (e.g., "hi", "mr", "en")
  final String sourceLanguage;

  /// Target language BCP-47 code
  final String targetLanguage;

  const TranslationRequest({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  List<Object> get props => [text, sourceLanguage, targetLanguage];
}

/// Result of translation
class TranslationResult extends Equatable {
  /// Original text
  final String originalText;

  /// Translated text
  final String translatedText;

  /// Source language
  final String sourceLanguage;

  /// Target language
  final String targetLanguage;

  /// Whether translation was successful
  final bool success;

  /// Error message if translation failed
  final String? error;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.success = true,
    this.error,
  });

  /// Create failed translation result
  factory TranslationResult.failed({
    required String originalText,
    required String sourceLanguage,
    required String targetLanguage,
    required String error,
  }) => TranslationResult(
    originalText: originalText,
    translatedText: originalText, // Fallback to original
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    success: false,
    error: error,
  );

  @override
  List<Object?> get props => [
    originalText,
    translatedText,
    sourceLanguage,
    targetLanguage,
    success,
    error,
  ];
}
