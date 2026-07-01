import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls splash screen audio playback.
/// Designed to be created at splash initState() and disposed at splash dispose().
/// All methods are safe to call even if audio is disabled or assets fail to load.
class SplashAudioController {
  static const String _prefKey = 'splash_audio_enabled';

  final AudioPlayer _whooshPlayer = AudioPlayer();
  final AudioPlayer _strikePlayer = AudioPlayer();

  bool _audioEnabled = false;
  bool _preloaded = false;

  /// Call this FIRST at splash initState() — runs async, does not block.
  /// Reads the user preference AND preloads both audio assets into memory.
  /// Preloading here means zero latency when trigger() is called later.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _audioEnabled = prefs.getBool(_prefKey) ?? false; // default OFF

      if (!_audioEnabled) return;

      // Set volumes before preloading
      await _whooshPlayer.setVolume(0.45); // whoosh is subtle background
      await _strikePlayer.setVolume(0.75); // strike is the impact moment

      // Preload both into memory — this is what prevents Windows audio latency
      await Future.wait([
        _whooshPlayer.setSourceAsset('audio/splash_whoosh.mp3'),
        _strikePlayer.setSourceAsset('audio/splash_strike.mp3'),
      ]);

      _preloaded = true;
    } catch (e) {
      // Audio failure must NEVER crash or delay the splash screen
      debugPrint('[SplashAudio] Init failed: $e — continuing silently');
      _preloaded = false;
    }
  }

  /// Call this at exactly 400ms (Phase 2: particle birth begins).
  /// Plays the whoosh layer at low volume.
  Future<void> playWhoosh() async {
    if (!_audioEnabled || !_preloaded) return;
    try {
      await _whooshPlayer.resume();
    } catch (e) {
      debugPrint('[SplashAudio] Whoosh playback failed: $e');
    }
  }

  /// Call this at exactly 1900ms (100ms before the logo flash at 2000ms).
  /// Plays the strike layer — it peaks at ~2000ms naturally.
  Future<void> playStrike() async {
    if (!_audioEnabled || !_preloaded) return;
    try {
      await _strikePlayer.resume();
    } catch (e) {
      debugPrint('[SplashAudio] Strike playback failed: $e');
    }
  }

  /// Save user preference. Call from settings screen.
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Read current preference. Call from settings screen to show toggle state.
  static Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Must be called in splash screen's dispose().
  Future<void> dispose() async {
    try {
      await _whooshPlayer.dispose();
      await _strikePlayer.dispose();
    } catch (_) {}
  }
}
