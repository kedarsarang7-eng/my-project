// ML Providers
//
// Riverpod providers for ML Kit services.
// All services are lazily instantiated.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ml_services/ocr_service.dart';
import 'ml_services/language_service.dart';
import 'ml_services/translation_service.dart';

/// Provider for ML Kit OCR service
final mlOcrServiceProvider = Provider<MLKitOcrService>((ref) {
  final service = MLKitOcrService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for language detection service
final languageDetectionServiceProvider = Provider<LanguageDetectionService>((
  ref,
) {
  final service = LanguageDetectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for translation service
final translationServiceProvider = Provider<TranslationService>((ref) {
  final service = TranslationService();
  ref.onDispose(() => service.dispose());
  return service;
});
