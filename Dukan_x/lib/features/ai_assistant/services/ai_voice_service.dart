// ... (previous imports)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart'; // NEW
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart'; // NEW
import 'voice_state.dart';
import '../../../../core/services/speech_service.dart';
import 'tts_service.dart';
import 'on_device_ai_service.dart'; // NEW: On-Device AI

class AiVoiceService extends ChangeNotifier {
  // Singleton
  static final AiVoiceService _instance = AiVoiceService._internal();
  factory AiVoiceService() => _instance;
  AiVoiceService._internal() {
    _tts.onComplete.listen((_) {
      if (_state == VoiceState.speaking) {
        _setState(VoiceState.idle);
      }
    });

    _speechService.statusStream.listen((status) {
      if (status == 'notListening' && _state == VoiceState.listening) {
        if (_state == VoiceState.listening) {
          _setState(VoiceState.idle);
        }
      }
    });
  }

  // Dependencies
  final SpeechService _speechService = SpeechService();
  final TtsService _tts = TtsService();

  // ... (streams and state vars)

  final StreamController<Map<String, dynamic>> _responseController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get responseStream => _responseController.stream;

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  String _lastUserText = "";
  String _lastAiText = "";
  String _lastIntent = "";
  Map<String, dynamic>? _lastData;
  String _errorMessage = "";
  String? _currentLanguage;

  String get lastUserText => _lastUserText;
  String get lastAiText => _lastAiText;
  String get lastIntent => _lastIntent;
  Map<String, dynamic>? get lastData => _lastData;
  String get errorMessage => _errorMessage;

  void _setState(VoiceState newState, [String? error]) {
    _state = newState;
    if (error != null) _errorMessage = error;
    notifyListeners();
  }

  Future<bool> init() async {
    return await _speechService.init();
  }

  Future<void> startListening({String languageCode = 'en-IN'}) async {
    _currentLanguage = languageCode;

    if (_state == VoiceState.speaking) {
      await stopSpeaking();
    }

    _setState(VoiceState.listening);
    _lastUserText = "";
    notifyListeners();

    debugPrint("🎤 Starting Listening (Language: $languageCode)...");

    bool available = await _speechService.startListening(
      featureName: 'AI_ASSISTANT',
      localeId: languageCode,
      onResult: (text, isFinal) {
        debugPrint("🎤 Partial Result: $text (Final: $isFinal)");
        _lastUserText = text;
        notifyListeners();

        if (isFinal) {
          stopListening();
          if (text.trim().isNotEmpty) {
            sendTextQuery(text);
          } else {
            _setState(VoiceState.idle);
          }
        }
      },
    );

    if (!available) {
      _setState(
        VoiceState.error,
        "Microphone unavailable or permission denied.",
      );
    }
  }

  Future<void> stopListening() async {
    await _speechService.stopListening();
    if (_state == VoiceState.listening) {
      _setState(VoiceState.idle);
    }
  }

  // Health Monitoring
  final List<String> _healthIssues = [];
  bool get hasHealthIssues => _healthIssues.isNotEmpty;

  /// Report an internal app error to the AI Brain
  void reportError(String source, String error) {
    // Avoid duplicate log spam
    final issue = "$source: $error";
    if (!_healthIssues.contains(issue)) {
      _healthIssues.add(issue);
      notifyListeners();

      // If critical, speak?
      if (_healthIssues.length >= 3 && _state == VoiceState.idle) {
        // Proactive help
        speakText("I noticed some technical issues. Check the warnings.");
      }
    }
  }

  void clearErrors() {
    _healthIssues.clear();
    notifyListeners();
  }

  /// 4. Process Text Query (On-Device AI - No Backend Required!)
  Future<void> sendTextQuery(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Check Internet (Groq API still needs it, but no backend server)
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _setState(VoiceState.error, "No Internet Connection");
      speakText("Please check your internet connection.");
      return;
    }

    _setState(VoiceState.processing);
    _lastUserText = text;
    notifyListeners();

    debugPrint("🤖 Processing On-Device: $text");

    try {
      // 2. Use On-Device AI Service (calls Groq API directly + local DB)
      final aiService = OnDeviceAIService(groqApiKey: _getGroqApiKey());

      // Get user ID from session
      final userId = _getUserId();

      final response = await aiService.processQuery(
        userId: userId,
        userInput: text,
      );

      debugPrint(
        "🤖 AI Response: ${response.text} (Intent: ${response.intent})",
      );

      _lastAiText = response.text;
      _lastIntent = response.intent;
      _lastData = response.data;

      _provideResponse(_lastUserText, _lastAiText, _lastIntent, _lastData);
    } catch (e) {
      debugPrint("❌ On-Device AI Error: $e");
      _setState(VoiceState.error, "AI Processing Failed");
      speakText("Sorry, I encountered an error processing your request.");
    }
  }

  /// Get Groq API Key (Securely from .env)
  String _getGroqApiKey() {
    return dotenv.env['GROQ_API_KEY'] ?? '';
  }

  /// Get current user ID from session
  /// Get current user ID from session
  String _getUserId() {
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null || userId.isEmpty) return 'default_user';
      return userId;
    } catch (e) {
      return 'default_user';
    }
  }

  void _provideResponse(
    String userText,
    String aiText,
    String intent,
    Map<String, dynamic>? params,
  ) {
    // UI Update
    notifyListeners();
    _responseController.add({
      'user_text': userText,
      'mahiru_text': aiText,
      'intent': intent,
      'data': params,
    });

    if (aiText.isNotEmpty) {
      // Speak Response
      speakText(aiText);
    } else {
      _setState(VoiceState.idle);
    }
  }

  /// Speak specific text (Local TTS)
  Future<void> speakText(String text) async {
    // If listening, stop listening
    if (_state == VoiceState.listening) {
      await _speechService.stopListening();
    }

    try {
      if (_currentLanguage != null) {
        await _tts.setLanguage(_currentLanguage!);
      }
      _setState(VoiceState.speaking);
      await _tts.speak(text);
    } catch (e) {
      _setState(VoiceState.error, "TTS Exception: $e");
    }
  }

  /// Manual Stop All
  Future<void> stopAll() async {
    await _speechService.stopListening();
    await _tts.stop();
    _setState(VoiceState.idle);
  }

  /// Stop Speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (_state == VoiceState.speaking) {
      _setState(VoiceState.idle);
    }
  }

  @override
  void dispose() {
    _responseController.close();
    _tts.dispose();
    super.dispose();
  }
}
