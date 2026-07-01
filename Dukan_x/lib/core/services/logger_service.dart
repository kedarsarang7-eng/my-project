// ============================================================================
// LOGGER SERVICE - Production-Safe Logging (CLEANUP FIX)
// ============================================================================
// Replaces direct debugPrint calls with conditional logging
// Only logs in debug mode - safe for production

import 'package:flutter/foundation.dart';

import '../security/log_scrubber.dart';

/// Log levels for categorizing log messages
enum LogLevel { verbose, debug, info, warning, error, fatal }

/// Production-safe logging service
/// All logs are stripped in release builds automatically
class LoggerService {
  LoggerService._();

  /// Factory constructor for service locator registration
  factory LoggerService() => LoggerService._();

  static bool _enabled = kDebugMode;
  static LogLevel _minimumLevel = LogLevel.debug;

  /// Enable or disable logging
  static void setEnabled(bool enabled) {
    _enabled = enabled && kDebugMode;
  }

  /// Set minimum log level
  static void setMinimumLevel(LogLevel level) {
    _minimumLevel = level;
  }

  /// Check if logging is enabled for a specific level
  static bool _shouldLog(LogLevel level) {
    if (!_enabled) return false;
    return level.index >= _minimumLevel.index;
  }

  /// Log a verbose message
  static void v(String tag, String message) {
    _log(LogLevel.verbose, tag, message);
  }

  /// Log a debug message
  static void d(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Log an info message
  static void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Log a warning message
  static void w(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  /// Log an error message
  static void e(
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, tag, message, error, stackTrace);
  }

  /// Log a fatal message
  static void f(
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.fatal, tag, message, error, stackTrace);
  }

  // ======================================================================
  // Instance methods — for usage via service locator (sl<LoggerService>())
  // ======================================================================

  /// Instance info logger (accepts message + optional data map)
  void info(String message, [Map<String, dynamic>? data]) {
    i('App', data != null ? '$message $data' : message);
  }

  /// Instance error logger (accepts message + optional data map + optional stackTrace)
  void error(
    String message, [
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  ]) {
    e('App', data != null ? '$message $data' : message, null, stackTrace);
  }

  /// Instance debug logger
  void debug(String message, [Map<String, dynamic>? data]) {
    d('App', data != null ? '$message $data' : message);
  }

  /// Instance warning logger
  void warning(String message, [Map<String, dynamic>? data]) {
    w('App', data != null ? '$message $data' : message);
  }

  /// Internal log method
  static void _log(
    LogLevel level,
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (!_shouldLog(level)) return;

    // Security_Layer (Req 17.10): scrub secrets, keys, and license keys from
    // the message and any error detail before anything is written.
    final safeMessage = LogScrubber.scrub(message);

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final logMessage = '[$timestamp] $levelStr [$tag] $safeMessage';

    // Use debugPrint for long messages
    if (logMessage.length > 800) {
      debugPrint(logMessage);
    } else {
      // ignore: avoid_print
      print(logMessage);
    }

    if (error != null) {
      debugPrint('ERROR: ${LogScrubber.scrub(error.toString())}');
    }
    if (stackTrace != null) {
      debugPrint('STACK: $stackTrace');
    }
  }

  /// Legacy compatibility - log debug message (old debugPrint replacement)
  static void logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Quick log method for simple messages
  static void log(String tag, String message) {
    d(tag, message);
  }
}

/// Extension methods for easier logging
extension LoggerExtension on Object {
  /// Log from any object
  void logDebug(String message) {
    LoggerService.d(runtimeType.toString(), message);
  }

  void logInfo(String message) {
    LoggerService.i(runtimeType.toString(), message);
  }

  void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    LoggerService.e(runtimeType.toString(), message, error, stackTrace);
  }
}

/// Mixin for classes that need logging
mixin LoggerMixin {
  String get logTag => runtimeType.toString();

  void logV(String message) => LoggerService.v(logTag, message);
  void logD(String message) => LoggerService.d(logTag, message);
  void logI(String message) => LoggerService.i(logTag, message);
  void logW(String message) => LoggerService.w(logTag, message);
  void logE(String message, [dynamic error, StackTrace? stackTrace]) =>
      LoggerService.e(logTag, message, error, stackTrace);
}
