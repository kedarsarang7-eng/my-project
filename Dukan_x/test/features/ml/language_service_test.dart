import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/ml/ml_services/language_service.dart';

void main() {
  group('LanguageDetectionResult', () {
    test('should create result with correct values', () {
      const result = LanguageDetectionResult(
        languageCode: 'hi',
        languageName: 'Hindi',
        confidence: 0.95,
      );

      expect(result.languageCode, 'hi');
      expect(result.languageName, 'Hindi');
      expect(result.confidence, 0.95);
      expect(result.success, true);
    });

    test('should create unknown result', () {
      final unknown = LanguageDetectionResult.unknown();

      expect(unknown.languageCode, 'und');
      expect(unknown.languageName, 'Unknown');
      expect(unknown.confidence, 0.0);
      expect(unknown.success, false);
    });

    test('should create english default result', () {
      final english = LanguageDetectionResult.english();

      expect(english.languageCode, 'en');
      expect(english.languageName, 'English');
      expect(english.confidence, 1.0);
      expect(english.success, true);
    });
  });

  group('LanguageDetectionService', () {
    late LanguageDetectionService service;

    setUp(() {
      service = LanguageDetectionService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('isTranslationSupported returns true for supported languages', () {
      expect(service.isTranslationSupported('en'), true);
      expect(service.isTranslationSupported('hi'), true);
      expect(service.isTranslationSupported('mr'), true);
      expect(service.isTranslationSupported('bn'), true);
      expect(service.isTranslationSupported('te'), true);
      expect(service.isTranslationSupported('ta'), true);
    });

    test('isTranslationSupported returns false for unsupported languages', () {
      expect(service.isTranslationSupported('fr'), false);
      expect(service.isTranslationSupported('de'), false);
      expect(service.isTranslationSupported('es'), false);
      expect(service.isTranslationSupported('xyz'), false);
    });

    // Note: Actual language detection requires device ML models
    // These tests verify the service structure, not the ML inference
  });
}
