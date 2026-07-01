import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// Singleton Service for Microphone Management & Speech-to-Text
/// Ensures only one feature uses the mic at a time.
class SpeechService {
  // Singleton Pattern
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String? _activeFeature; // 'AI_ASSISTANT' or 'VOICE_BILL'

  // Streams for UI updates
  final StreamController<String> _textStreamController =
      StreamController<String>.broadcast();
  Stream<String> get textStream => _textStreamController.stream;

  final StreamController<String> _statusStreamController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream =>
      _statusStreamController.stream; // 'listening', 'notListening', 'done'

  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized && _speech.isAvailable;

  /// Initialize SpeechToText (Run once on App Start)
  Future<bool> init() async {
    if (_isInitialized) return true;

    // Check Permissions first
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          _statusStreamController.add("permission_denied");
          return false;
        }
        return false;
      }
    }

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint("🎤 Speech Status: $status");
          if (status == 'listening') {
            _statusStreamController.add('listening');
          } else if (status == 'notListening') {
            // If we were listening and it stopped automatically w/o our explicit stop:
            if (_isListening) {
              _isListening = false;
              _activeFeature = null;
              _statusStreamController.add('notListening');
            }
          } else if (status == 'done') {
            // Session complete
          }
        },
        onError: (errorNotification) {
          debugPrint("❌ Speech Error: ${errorNotification.errorMsg}");
          _statusStreamController.add("error: ${errorNotification.errorMsg}");
          stopListening();
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint("❌ Init Error: $e");
      return false;
    }
  }

  /// Start Listening safely
  /// [featureName]: Identifier for who is requesting (e.g., 'AI_ASSISTANT')
  /// [onResult]: Callback for partial/final text
  Future<bool> startListening({
    required String featureName,
    required Function(String text, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (_isListening) {
      if (_activeFeature != featureName) {
        debugPrint(
          "⚠️ Mic Conflict: $_activeFeature is already using mic. Stopping it.",
        );
        await stopListening(); // Force stop other
      } else {
        // Already listening for this feature
        return true;
      }
    }

    if (!_isInitialized) {
      bool success = await init();
      if (!success) return false;
    }

    // Set Audio Focus (Active Feature)
    _activeFeature = featureName;
    _isListening = true;
    _statusStreamController.add('listening');

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          _textStreamController.add(result.recognizedWords);

          if (result.finalResult) {
            // Auto-stop logic usually handled by `listen` but we ensure state cleanup
            // stopListening(); // Don't force stop here, let 'listenMode: confirmation' handle it?
            // Actually prompt says "When user stops speaking, finalize text".
            // If finalResult is true, we should probably consider it done.
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: localeId,
        cancelOnError: true,
        listenMode:
            stt.ListenMode.confirmation, // Good for short commands/assistant
        onSoundLevelChange: (level) {
          _soundLevelController.add(level);
        },
      );
      return true;
    } catch (e) {
      debugPrint("❌ Listen Error: $e");
      _isListening = false;
      _activeFeature = null;
      return false;
    }
  }

  /// Stop Listening and release focus
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      _activeFeature = null;
      _statusStreamController.add('notListening');
    }
  }

  /// Cancel listening (discard results)
  Future<void> cancelListening() async {
    await _speech.cancel();
    _isListening = false;
    _activeFeature = null;
    _statusStreamController.add('notListening');
  }
}
