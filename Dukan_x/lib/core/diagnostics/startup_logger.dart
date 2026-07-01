// ============================================================================
// STARTUP LOGGER — File-based logging for release mode diagnostics
// ============================================================================
// Writes every startup step to %APPDATA%\DukanX\logs\startup.log
// so silent crashes on deployment machines can be diagnosed.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Enterprise-grade file-based startup logger.
/// Writes to %APPDATA%\DukanX\logs\startup.log on Windows,
/// or equivalent app support directory on other platforms.
class StartupLogger {
  static StartupLogger? _instance;
  static StartupLogger get instance => _instance ??= StartupLogger._();

  StartupLogger._();

  File? _logFile;
  bool _isInitialized = false;
  final List<String> _buffer = [];
  final Stopwatch _stopwatch = Stopwatch();

  /// Initialize the logger. Must be called very early, before any other init.
  /// Uses sync file I/O to guarantee logs are written even during crashes.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _stopwatch.start();

    try {
      final appData = await _getLogDirectory();
      final logDir = Directory(p.join(appData, 'DukanX', 'logs'));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      _logFile = File(p.join(logDir.path, 'startup.log'));

      // Rotate log if it's too large (> 5MB)
      if (_logFile!.existsSync() && _logFile!.lengthSync() > 5 * 1024 * 1024) {
        final backup = File(p.join(logDir.path, 'startup.log.old'));
        if (backup.existsSync()) backup.deleteSync();
        _logFile!.renameSync(backup.path);
        _logFile = File(p.join(logDir.path, 'startup.log'));
      }

      _isInitialized = true;

      // Write session header
      final header = '\n${'=' * 80}\n'
          'DUKANX STARTUP LOG — ${DateTime.now().toIso8601String()}\n'
          'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
          'Executable: ${Platform.resolvedExecutable}\n'
          'Dart: ${Platform.version}\n'
          'Debug: $kDebugMode | Profile: $kProfileMode | Release: $kReleaseMode\n'
          'Arguments: ${Platform.executableArguments.join(', ')}\n'
          'Script: ${Platform.script}\n'
          '${'=' * 80}\n';

      _logFile!.writeAsStringSync(header, mode: FileMode.append, flush: true);

      // Flush any buffered messages
      if (_buffer.isNotEmpty) {
        for (final msg in _buffer) {
          _logFile!.writeAsStringSync(msg, mode: FileMode.append, flush: true);
        }
        _buffer.clear();
      }
    } catch (e) {
      // Cannot write logs — buffer and continue
      _buffer.add('[INIT-ERROR] Failed to initialize logger: $e\n');
    }
  }

  /// Get the log directory path.
  Future<String> _getLogDirectory() async {
    if (Platform.isWindows) {
      // Use %APPDATA% on Windows
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) return appData;
    }
    // Fallback to path_provider
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  /// Log a startup step with timing info.
  void step(String message) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final line = '[+${elapsed}ms] ✓ $message\n';
    _write(line);
  }

  /// Log an informational message.
  void info(String message) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final line = '[+${elapsed}ms] ℹ $message\n';
    _write(line);
  }

  /// Log a warning.
  void warn(String message) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final line = '[+${elapsed}ms] ⚠ WARNING: $message\n';
    _write(line);
  }

  /// Log an error with optional stack trace.
  void error(String message, [Object? err, StackTrace? stack]) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final buf = StringBuffer('[+${elapsed}ms] ❌ ERROR: $message\n');
    if (err != null) buf.write('  Exception: $err\n');
    if (stack != null) buf.write('  StackTrace:\n$stack\n');
    _write(buf.toString());
  }

  /// Log a fatal error — the app will likely not start.
  void fatal(String message, [Object? err, StackTrace? stack]) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final buf = StringBuffer(
        '[+${elapsed}ms] 💀 FATAL: $message\n');
    if (err != null) buf.write('  Exception: $err\n');
    if (stack != null) buf.write('  StackTrace:\n$stack\n');
    _write(buf.toString());
  }

  /// Write a diagnostic section (e.g., --diagnostics results).
  void section(String title, String content) {
    final line = '\n--- $title ---\n$content\n--- end $title ---\n';
    _write(line);
  }

  void _write(String line) {
    // Always print to console in debug mode
    if (kDebugMode) {
      debugPrint(line.trimRight());
    }

    if (_isInitialized && _logFile != null) {
      try {
        _logFile!.writeAsStringSync(line, mode: FileMode.append, flush: true);
      } catch (e) {
        // If file write fails, at least we have the debug print above
        _buffer.add(line);
      }
    } else {
      _buffer.add(line);
    }
  }

  /// Get the log file path (for diagnostics reporting).
  String? get logFilePath => _logFile?.path;

  /// Read the current log file content.
  String? readLog() {
    try {
      return _logFile?.readAsStringSync();
    } catch (_) {
      return null;
    }
  }
}

/// Global startup logger instance.
StartupLogger get startupLog => StartupLogger.instance;
