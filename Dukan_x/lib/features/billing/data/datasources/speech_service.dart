import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;

  Future<bool> init() async {
    if (!_isInitialized) {
      _isInitialized = await _stt.initialize(
        onError: (e) => debugPrint('Speech Error: $e'),
        onStatus: (s) => debugPrint('Speech Status: $s'),
      );
    }
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String) onResult,
    String localeId = 'en_IN', // Default, can be hi_IN or mr_IN
  }) async {
    if (!_isInitialized) {
      await init();
    }
    if (_stt.isAvailable) {
      await _stt.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );
    }
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  bool get isListening => _stt.isListening;
}
