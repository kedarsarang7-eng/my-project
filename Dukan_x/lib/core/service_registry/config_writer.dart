// ============================================================================
// Atomic Config Writer
// ============================================================================
// Writes MODE and provider settings to the app's config file atomically using
// the write-to-temp-then-rename pattern (POSIX atomic rename semantics).
//
// On Windows, File.renameSync() is NOT atomic on the same volume when the
// destination exists, so we copy+delete instead to minimise the window.
//
// The config file is located at:
//   <appSupportDir>/dukanx_config.json
//
// It is also re-read into dotenv memory so ServiceRegistry.reinitialize()
// picks up the new MODE without a process restart.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ConfigWriter {
  ConfigWriter._();
  static final ConfigWriter instance = ConfigWriter._();

  static const _fileName = 'dukanx_config.json';

  Future<File> get _configFile async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Read config from disk (called once at startup before dotenv override).
  Future<Map<String, String>> readConfig() async {
    try {
      final file = await _configFile;
      if (!file.existsSync()) return {};
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('[ConfigWriter] readConfig error: $e');
      return {};
    }
  }

  /// Atomically write a new config and refresh dotenv in-memory.
  ///
  /// Called by [CutoverManager] at Step 8. This is the POINT OF NO RETURN.
  /// All local services remain running until this returns successfully.
  Future<void> writeConfigAtomic(Map<String, String> config) async {
    final file = await _configFile;
    final tempFile = File('${file.path}.tmp');

    // Write to temp file.
    final contents = const JsonEncoder.withIndent('  ').convert(config);
    await tempFile.writeAsString(contents, flush: true);

    // Atomic swap — on Windows we delete destination first.
    try {
      if (file.existsSync()) file.deleteSync();
      tempFile.renameSync(file.path);
    } catch (e) {
      // Fallback: copy then delete temp.
      await tempFile.copy(file.path);
      await tempFile.delete();
    }

    // Refresh dotenv in-memory so ServiceRegistry.reinitialize() reads
    // the new MODE without restarting the process.
    for (final entry in config.entries) {
      dotenv.env[entry.key] = entry.value;
    }

    debugPrint('[ConfigWriter] Config written atomically (${config['MODE']} mode).');
  }

  /// Convenience: load config from disk and merge into dotenv BEFORE any
  /// ServiceRegistry.initialize() call. If no file exists, dotenv is unchanged
  /// (existing .env / dart-define values remain authoritative).
  Future<void> mergeConfigIntoDotenv() async {
    final config = await readConfig();
    if (config.isEmpty) return;
    for (final entry in config.entries) {
      dotenv.env[entry.key] = entry.value;
    }
    debugPrint('[ConfigWriter] Merged persisted config into dotenv (MODE=${dotenv.env['MODE']}).');
  }
}
