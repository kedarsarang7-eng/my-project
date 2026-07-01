import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final StreamController<void> _completeController =
      StreamController.broadcast();

  Stream<void> get onComplete => _completeController.stream;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.2); // Slightly higher pitch for female tone

    // completion listener
    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      _completeController.add(null);
    });

    _flutterTts.setErrorHandler((msg) {
      _isPlaying = false;
      debugPrint("TTS Error: $msg");
      _completeController.add(null); // Ensure we don't get stuck
    });
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
  }

  Future<void> speak(String text) async {
    try {
      await stop(); // Ensure any previous audio is stopped
      _isPlaying = true;

      // Attempt to pick a female voice if available (this is best effort)
      // On some devices "en-us-x-sfg#female_1-local" or similar might exist
      // For now we rely on system default or configured language

      await _flutterTts.speak(text);
    } catch (e) {
      _isPlaying = false;
      debugPrint("TTS Speak Error: $e");
      _completeController.add(null);
    }
  }

  /// Helper to set voice if needed
  Future<void> setVoice(Map<String, String> voice) async {
    await _flutterTts.setVoice(voice);
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  void dispose() {
    _flutterTts.stop();
    _completeController.close();
  }
}
