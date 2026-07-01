import 'dart:io';
import '../services/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Handles unhandled exceptions, writes crash dumps locally to ensure
/// no silent crashes occur in production environments.
class CrashReporter {
  static final CrashReporter _instance = CrashReporter._internal();
  factory CrashReporter() => _instance;
  CrashReporter._internal();

  bool _isHandlingCrash = false;

  /// Logs a fatal exception, saves a crash dump to the user's documents directory,
  /// and returns the path to the crash dump file.
  Future<String?> recordFatalError(
    dynamic exception,
    StackTrace stackTrace,
  ) async {
    if (_isHandlingCrash) return null;
    _isHandlingCrash = true;

    try {
      LoggerService.d('CrashReporter', '🚨 CRASH REPORTER ACTIVATED 🚨');
      LoggerService.d('CrashReporter', 'Exception: $exception');
      LoggerService.d('CrashReporter', 'Stack: $stackTrace');

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'crash_$timestamp.txt';

      Directory? baseDir;
      if (Platform.isWindows) {
        // Create crash dumps in the user's Documents/DukanX/crashes folder for easy access
        final docDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${docDir.path}\\DukanX\\crashes');
      } else {
        baseDir = await getApplicationSupportDirectory();
      }

      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final file = File('${baseDir.path}${Platform.pathSeparator}$filename');

      final crashReport = StringBuffer();
      crashReport.writeln('=========================================');
      crashReport.writeln('DUKANX FATAL CRASH REPORT');
      crashReport.writeln('=========================================');
      crashReport.writeln('Date/Time: ${DateTime.now().toIso8601String()}');
      crashReport.writeln(
        'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      );
      crashReport.writeln('App Version: 3.0.0 (Production Hardened)');
      crashReport.writeln('\n--- EXCEPTION ---');
      crashReport.writeln(exception.toString());
      crashReport.writeln('\n--- STACK TRACE ---');
      crashReport.writeln(stackTrace.toString());
      crashReport.writeln('=========================================');

      await file.writeAsString(crashReport.toString());
      LoggerService.d('CrashReporter', 'Crash dump saved to: ${file.path}');
      return file.path;
    } catch (e) {
      LoggerService.d('CrashReporter', 'Failed to write crash dump: $e');
      return null;
    } finally {
      _isHandlingCrash = false;
    }
  }
}
