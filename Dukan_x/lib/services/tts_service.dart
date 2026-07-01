import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// A Reusable, Production-Ready TTS Service for "Mahiru"
/// Tuned for a warm, female Marathi/Indian voice.
class TtsService {
  static final TtsService _instance = TtsService._internal();

  factory TtsService() {
    return _instance;
  }

  late FlutterTts _flutterTts;
  bool _isInitialized = false;

  TtsService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      _flutterTts = FlutterTts();
      _isInitialized = true;

      if (!kIsWeb) {
        // Platform specific setup
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
            IosTextToSpeechAudioMode.voicePrompt,
          );
        }
      }

      await _configureVoiceSettings();

      _flutterTts.setStartHandler(() {
        debugPrint("TTS Started");
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint("TTS Completed");
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
      });
    } catch (e) {
      debugPrint("TTS Init Failed: $e");
    }
  }

  /// Configures strictly solely for the "Mahiru" persona (Warm, Female, Marathi/Indian)
  Future<void> _configureVoiceSettings() async {
    if (!_isInitialized) return;

    // 1. Set Language
    // Prioritize Marathi, fallback to Hindi or Indian English
    await _flutterTts.setLanguage("mr-IN");

    // 2. Set Pitch & Rate (The "Mahiru" Persona)
    // Slightly higher pitch for female feel, slightly slower for clarity/calmness
    await _flutterTts.setPitch(1.3); // 1.0 is normal, >1.0 is higher
    await _flutterTts.setSpeechRate(
      0.4,
    ); // 0.0 to 1.0. 0.5 is usually normal. 0.4 is slightly slower.
    await _flutterTts.setVolume(1.0);

    await _flutterTts.awaitSpeakCompletion(true);

    // 3. Try to find a specific female voice
    // This is device dependent. We iterate and try to match.
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null && voices is List) {
        // Look for 'mr-in-x-female' or hints
        // On many Androids, Google TTS offers "mr-IN-language"
        // We can't guarantee "Wavenet" quality locally, but we try best match.

        // Debug: print voices to see options (dev only)
        // for (var v in voices) debugPrint("Voice: $v");

        // No specific forced selection logic here to avoid crashing if missing.
        // The Engine normally defaults to the Language gender settings if configurable globally.
      }
    } catch (_) {}
  }

  /// The main Speak function.
  /// Interrupts any previous speech.
  Future<void> speak(String text) async {
    if (!_isInitialized) await _initTts();

    // Stop previous if talking
    await _flutterTts.stop();

    if (text.isEmpty) return;

    // Enhancements for natural feel (optional pauses)
    // Replace commas with silences if native engine doesn't handle well?
    // Usually engines handle punctuation.

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    if (_isInitialized) {
      await _flutterTts.stop();
    }
  }
}
