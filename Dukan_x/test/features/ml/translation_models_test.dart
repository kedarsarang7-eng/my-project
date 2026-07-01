import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/ml/ml_models/translation_request.dart';

void main() {
  group('TranslationRequest', () {
    test('should create TranslationRequest with correct values', () {
      const request = TranslationRequest(
        text: 'Hello World',
        sourceLanguage: 'en',
        targetLanguage: 'hi',
      );

      expect(request.text, 'Hello World');
      expect(request.sourceLanguage, 'en');
      expect(request.targetLanguage, 'hi');
    });

    test('should implement equality correctly', () {
      const request1 = TranslationRequest(
        text: 'Test',
        sourceLanguage: 'en',
        targetLanguage: 'mr',
      );

      const request2 = TranslationRequest(
        text: 'Test',
        sourceLanguage: 'en',
        targetLanguage: 'mr',
      );

      const request3 = TranslationRequest(
        text: 'Different',
        sourceLanguage: 'en',
        targetLanguage: 'mr',
      );

      expect(request1, equals(request2));
      expect(request1, isNot(equals(request3)));
    });
  });

  group('TranslationResult', () {
    test('should create successful TranslationResult', () {
      const result = TranslationResult(
        originalText: 'Hello',
        translatedText: 'नमस्ते',
        sourceLanguage: 'en',
        targetLanguage: 'hi',
      );

      expect(result.originalText, 'Hello');
      expect(result.translatedText, 'नमस्ते');
      expect(result.success, true);
      expect(result.error, isNull);
    });

    test('should create failed TranslationResult with fallback', () {
      final result = TranslationResult.failed(
        originalText: 'Hello',
        sourceLanguage: 'en',
        targetLanguage: 'hi',
        error: 'Model not available',
      );

      expect(result.originalText, 'Hello');
      expect(result.translatedText, 'Hello'); // Falls back to original
      expect(result.success, false);
      expect(result.error, 'Model not available');
    });

    test('should implement equality correctly', () {
      const result1 = TranslationResult(
        originalText: 'Test',
        translatedText: 'टेस्ट',
        sourceLanguage: 'en',
        targetLanguage: 'hi',
      );

      const result2 = TranslationResult(
        originalText: 'Test',
        translatedText: 'टेस्ट',
        sourceLanguage: 'en',
        targetLanguage: 'hi',
      );

      expect(result1, equals(result2));
    });
  });
}
