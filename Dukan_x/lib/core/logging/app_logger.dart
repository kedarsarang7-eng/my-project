import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../security/log_scrubber.dart';

/// Centralized production-ready logging service.
class AppLogger {
  static File? _logFile;
  static bool _isInitStarted = false;
  static bool _isInitialized = false;
  static final List<String> _logQueue = [];
  static bool _isWriting = false;

  /// General info messages.
  static void info(String message, {String? tag}) {
    _log(message, tag: tag, level: 0);
  }

  /// Warning messages for non-critical issues.
  static void warning(String message, {String? tag, Object? error}) {
    _log(message, tag: tag, level: 800, error: error);
  }

  /// Error messages.
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, tag: tag, level: 1000, error: error, stackTrace: stackTrace);
  }

  /// Debug messages (only shown in development mode).
  static void debug(String message, {String? tag}) {
    if (!kReleaseMode) {
      _log(message, tag: tag, level: 500);
    }
  }

  static void _log(
    String message, {
    String? tag,
    int level = 0,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Security_Layer (Req 17.10): scrub secrets, keys, and license keys before
    // anything reaches the dev console or the on-disk log file.
    final safeMessage = LogScrubber.scrub(message);
    final safeError = error == null
        ? null
        : LogScrubber.scrub(error.toString());

    if (!kReleaseMode) {
      developer.log(
        safeMessage,
        name: tag ?? 'AppLogger',
        level: level,
        error: safeError,
        stackTrace: stackTrace,
      );
    }

    _logToFile(safeMessage, level, tag ?? 'AppLogger', safeError, stackTrace);
  }

  static void _logToFile(
    String message,
    int level,
    String tag,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (!kReleaseMode) return;
    try {
      if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    } catch (_) {
      return; // Web platform unsupported for File operations
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level >= 1000 ? 'ERROR' : (level >= 800 ? 'WARN' : 'INFO');
    var formattedMessage = '[$timestamp] [$levelStr] [$tag] $message\n';

    if (error != null) {
      formattedMessage += 'Error: $error\n';
    }
    if (stackTrace != null) {
      formattedMessage += 'StackTrace:\n$stackTrace\n';
    }

    _logQueue.add(formattedMessage);

    if (!_isInitStarted) {
      _isInitStarted = true;
      _initLogFile();
    } else if (_isInitialized && !_isWriting) {
      _flushLogs();
    }
  }

  static Future<void> _initLogFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/app_log.txt');
      _isInitialized = true;
      _flushLogs();
    } catch (_) {
      // Directory fetch failed
    }
  }

  static Future<void> _flushLogs() async {
    if (_logFile == null || _logQueue.isEmpty) return;
    _isWriting = true;
    try {
      final messages = _logQueue.join('');
      _logQueue.clear();

      if (await _logFile!.exists()) {
        final stat = await _logFile!.stat();
        if (stat.size > 5 * 1024 * 1024) {
          // 5MB Rolling Size
          final oldFile = File('${_logFile!.path}_old');
          if (await oldFile.exists()) await oldFile.delete();
          await _logFile!.rename(oldFile.path);
        }
      }

      await _logFile!.writeAsString(messages, mode: FileMode.append);
    } catch (_) {
      // Ignore I/O err
    } finally {
      _isWriting = false;
      if (_logQueue.isNotEmpty) {
        _flushLogs();
      }
    }
  }
}
