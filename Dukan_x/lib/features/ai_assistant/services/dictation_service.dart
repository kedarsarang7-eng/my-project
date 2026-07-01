import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../config/api_config.dart';

/// A pure STT service for billing/dictation.
/// Isolates billing voice logic from the conversational AI assistant.
/// Supports Offline fallback to on-device SpeechToText.
class DictationService {
  // CONFIG matches AiVoiceService for backend (only used if online)
  String get _baseUrl => ApiConfig.baseUrl;

  // Recorder for Backend STT (Online)
  final AudioRecorder _recorder = AudioRecorder();

  // Local Speech for Offline STT
  final stt.SpeechToText _localSpeech = stt.SpeechToText();
  bool _useLocalFallback = false;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _currentLanguage; // Stores language choice for the current session

  // Stream for simple text output
  final StreamController<String> _textController = StreamController.broadcast();
  Stream<String> get textStream => _textController.stream;

  final StreamController<String> _statusController =
      StreamController.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // Singleton to prevent multi-instance recording overlaps
  static final DictationService _instance = DictationService._internal();
  factory DictationService() => _instance;
  DictationService._internal();

  Future<bool> init() async {
    // 1. Mic Permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  Future<void> startListening({
    String? language,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _currentLanguage = language;
    _textController.add(""); // Clear previous

    // 1. Check Connectivity
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isOffline = connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
      debugPrint("DictationService: Offline mode, using local STT");
      _useLocalFallback = true;
      await _startLocalListening(language: language, timeout: timeout);
      return;
    }

    _useLocalFallback = false;

    // 2. Online Mode: Try Backend Recorder
    try {
      if (await _recorder.hasPermission()) {
        String path = 'dictation.wav'; // Default for Web
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          path = '${dir.path}/dictation.wav';
        }

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );

        _isRecording = true;
        _statusController.add("Listening...");
        debugPrint("DictationService: Started (Backend Mode)");

        // Auto-stop
        Future.delayed(timeout, () {
          if (_isRecording) stopListening();
        });
      }
    } catch (e) {
      debugPrint("Dictation Record Error: $e");
      // Fallback to local
      _statusController.add("Backend Error, switching to offline mic...");
      _useLocalFallback = true;
      await _startLocalListening(language: language, timeout: timeout);
    }
  }

  Future<void> _startLocalListening({
    String? language,
    Duration? timeout,
  }) async {
    try {
      bool available = await _localSpeech.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (val) => debugPrint('STT Status: $val'),
      );

      if (available) {
        _isRecording = true;
        _statusController.add("Listening (Offline)...");

        await _localSpeech.listen(
          onResult: (result) {
            _textController.add(result.recognizedWords);
            if (result.finalResult) {
              // Can optionally stop here
            }
          },
          listenFor: timeout,
          localeId: language,
          cancelOnError: true,
          partialResults: true,
        );
      } else {
        _statusController.add("Error: Speech Init Failed");
        debugPrint("STT Initialize failed");
      }
    } catch (e) {
      debugPrint("Local Listen Error: $e");
      _statusController.add("Error");
    }
  }

  Future<void> stopListening() async {
    if (!_isRecording) return;

    if (_useLocalFallback) {
      await _localSpeech.stop();
      _isRecording = false;
      _statusController.add("Idle");
      return;
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _statusController.add("Processing...");

      if (path != null) {
        await _transcribe(path);
      }
    } catch (e) {
      debugPrint("Dictation Stop Error: $e");
      _statusController.add("Error");
    }
  }

  Future<void> _transcribe(String filePath) async {
    try {
      // Use the pure STT endpoint
      final uri = Uri.parse("$_baseUrl/stt");
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final resp = await http.get(Uri.parse(filePath));
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            resp.bodyBytes,
            filename: 'dictation.wav',
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      if (_currentLanguage != null) {
        request.fields['language'] = _currentLanguage!;
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr) as Map<String, dynamic>;
        final text = data['text'] as String? ?? "";

        debugPrint("Dictation Output: $text");
        _textController.add(text);
        _statusController.add("Idle");
      } else {
        debugPrint("Backend Error: ${response.statusCode}");
        _statusController.add("Error ${response.statusCode}");

        // Final fallback: If backend fails during processing (e.g. 500 error),
        // we can't easily fallback to STT because the audio is already recorded/past.
        // User has to retry.
      }
    } catch (e) {
      debugPrint("Dictation Transcribe Error: $e");
      _statusController.add("Error: Connection Failed");
    }
  }

  void dispose() {
    _recorder.dispose(); // Releases mic
    _localSpeech.cancel();
    _textController.close();
    _statusController.close();
  }
}
