// ML Kit Translation Service
//
// On-device neural translation using Google ML Kit.
//
// Features:
// - On-demand model download
// - Offline translation
// - Model lifecycle management (download/delete)
// - Fallback to original text if model missing

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../ml_models/translation_request.dart';

/// Status of a language model
enum ModelStatus {
  /// Model needs to be downloaded
  notDownloaded,

  /// Model is currently downloading
  downloading,

  /// Model is downloaded and ready
  ready,

  /// Model download failed
  failed,
}

/// On-device translation service
class TranslationService {
  /// Cache of downloaded translators
  final Map<String, OnDeviceTranslator> _translators = {};

  /// Model manager for checking/downloading models
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  /// Supported translation languages
  static final supportedLanguages = {
    'en': TranslateLanguage.english,
    'hi': TranslateLanguage.hindi,
    'mr': TranslateLanguage.marathi,
    'bn': TranslateLanguage.bengali,
    'te': TranslateLanguage.telugu,
    'ta': TranslateLanguage.tamil,
    'gu': TranslateLanguage.gujarati,
    'ur': TranslateLanguage.urdu,
    'kn': TranslateLanguage.kannada,
  };

  /// Get translator key for caching
  String _getTranslatorKey(String source, String target) => '$source-$target';

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(String languageCode) async {
    if (kIsWeb) return false;

    final language = supportedLanguages[languageCode];
    if (language == null) return false;

    try {
      return await _modelManager.isModelDownloaded(language.bcpCode);
    } catch (e) {
      debugPrint('TranslationService: Error checking model: $e');
      return false;
    }
  }

  /// Download a language model
  ///
  /// Returns true if download successful or already downloaded
  Future<bool> downloadModel(String languageCode) async {
    if (kIsWeb) {
      debugPrint('TranslationService: Web not supported');
      return false;
    }

    final language = supportedLanguages[languageCode];
    if (language == null) {
      debugPrint('TranslationService: Unsupported language: $languageCode');
      return false;
    }

    try {
      // Check if already downloaded
      if (await isModelDownloaded(languageCode)) {
        debugPrint(
          'TranslationService: Model already downloaded: $languageCode',
        );
        return true;
      }

      debugPrint('TranslationService: Downloading model: $languageCode');
      await _modelManager.downloadModel(language.bcpCode);
      debugPrint('TranslationService: Model downloaded: $languageCode');
      return true;
    } catch (e) {
      debugPrint('TranslationService: Download failed for $languageCode: $e');
      return false;
    }
  }

  /// Delete a downloaded language model
  Future<bool> deleteModel(String languageCode) async {
    if (kIsWeb) return false;

    final language = supportedLanguages[languageCode];
    if (language == null) return false;

    try {
      await _modelManager.deleteModel(language.bcpCode);
      debugPrint('TranslationService: Model deleted: $languageCode');
      return true;
    } catch (e) {
      debugPrint('TranslationService: Delete failed for $languageCode: $e');
      return false;
    }
  }

  /// Get or create translator for language pair
  Future<OnDeviceTranslator?> _getTranslator(
    String sourceCode,
    String targetCode,
  ) async {
    final key = _getTranslatorKey(sourceCode, targetCode);

    if (_translators.containsKey(key)) {
      return _translators[key];
    }

    final sourceLanguage = supportedLanguages[sourceCode];
    final targetLanguage = supportedLanguages[targetCode];

    if (sourceLanguage == null || targetLanguage == null) {
      debugPrint(
        'TranslationService: Unsupported language pair: $sourceCode -> $targetCode',
      );
      return null;
    }

    // Check if models are available
    final sourceDownloaded = await isModelDownloaded(sourceCode);
    final targetDownloaded = await isModelDownloaded(targetCode);

    if (!sourceDownloaded || !targetDownloaded) {
      debugPrint('TranslationService: Models not downloaded');
      return null;
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    _translators[key] = translator;
    return translator;
  }

  /// Translate text
  ///
  /// [request] - Translation request with source/target languages
  ///
  /// Returns [TranslationResult] with translated text or fallback
  Future<TranslationResult> translate(TranslationRequest request) async {
    if (kIsWeb) {
      return TranslationResult.failed(
        originalText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        error: 'Translation not supported on web',
      );
    }

    // Skip if same language
    if (request.sourceLanguage == request.targetLanguage) {
      return TranslationResult(
        originalText: request.text,
        translatedText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
      );
    }

    try {
      final translator = await _getTranslator(
        request.sourceLanguage,
        request.targetLanguage,
      );

      if (translator == null) {
        return TranslationResult.failed(
          originalText: request.text,
          sourceLanguage: request.sourceLanguage,
          targetLanguage: request.targetLanguage,
          error: 'Translation model not available',
        );
      }

      final translatedText = await translator.translateText(request.text);

      return TranslationResult(
        originalText: request.text,
        translatedText: translatedText,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
      );
    } catch (e) {
      debugPrint('TranslationService Error: $e');
      return TranslationResult.failed(
        originalText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        error: e.toString(),
      );
    }
  }

  /// Translate multiple texts in batch
  Future<List<TranslationResult>> translateBatch(
    List<String> texts,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final results = <TranslationResult>[];

    for (final text in texts) {
      final result = await translate(
        TranslationRequest(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        ),
      );
      results.add(result);
    }

    return results;
  }

  /// Get list of downloaded models
  Future<List<String>> getDownloadedModels() async {
    final downloaded = <String>[];

    for (final code in supportedLanguages.keys) {
      if (await isModelDownloaded(code)) {
        downloaded.add(code);
      }
    }

    return downloaded;
  }

  /// Dispose all translators
  Future<void> dispose() async {
    for (final translator in _translators.values) {
      await translator.close();
    }
    _translators.clear();
    debugPrint('TranslationService: All translators disposed');
  }
}
