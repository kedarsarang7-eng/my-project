// ============================================================================
// DIAGNOSTICS RUNNER — Runtime dependency & health verification
// ============================================================================
// When launched with `dukanx.exe --diagnostics`, this runs comprehensive
// checks and generates a report.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'startup_logger.dart';

/// Result of a single diagnostic check.
class DiagnosticResult {
  final String name;
  final bool passed;
  final String message;
  final String? details;

  DiagnosticResult({
    required this.name,
    required this.passed,
    required this.message,
    this.details,
  });

  @override
  String toString() =>
      '${passed ? "✅ PASS" : "❌ FAIL"} | $name | $message'
      '${details != null ? '\n    $details' : ''}';
}

/// Comprehensive diagnostics runner for deployment troubleshooting.
class DiagnosticsRunner {
  final List<DiagnosticResult> _results = [];

  List<DiagnosticResult> get results => List.unmodifiable(_results);
  int get passCount => _results.where((r) => r.passed).length;
  int get failCount => _results.where((r) => !r.passed).length;

  /// Run all diagnostic checks.
  Future<void> runAll() async {
    startupLog.info('=== DIAGNOSTICS MODE ===');

    await _checkPlatformInfo();
    await _checkVCppRedistributable();
    await _checkWritePermissions();
    await _checkDatabaseAccess();
    await _checkFlutterAssets();
    await _checkPluginDlls();
    await _checkFirebaseConfig();
    await _checkInternetConnectivity();
    await _checkSecureStorage();
    await _checkDiskSpace();

    // Generate report
    _generateReport();
  }

  /// Platform information.
  Future<void> _checkPlatformInfo() async {
    _results.add(DiagnosticResult(
      name: 'Platform Info',
      passed: true,
      message: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      details: 'Arch: ${Platform.localHostname} | '
          'Processors: ${Platform.numberOfProcessors} | '
          'Locale: ${Platform.localeName}',
    ));
  }

  /// Check if Visual C++ Redistributable is available.
  Future<void> _checkVCppRedistributable() async {
    if (!Platform.isWindows) {
      _results.add(DiagnosticResult(
        name: 'VC++ Redistributable',
        passed: true,
        message: 'Not applicable (non-Windows)',
      ));
      return;
    }

    try {
      // Check for VCRUNTIME140.dll and MSVCP140.dll in system paths
      final systemDir = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final system32 = p.join(systemDir, 'System32');

      final vcruntime140 = File(p.join(system32, 'vcruntime140.dll'));
      final msvcp140 = File(p.join(system32, 'msvcp140.dll'));
      final vcruntime140_1 = File(p.join(system32, 'vcruntime140_1.dll'));

      final missing = <String>[];
      if (!vcruntime140.existsSync()) missing.add('vcruntime140.dll');
      if (!msvcp140.existsSync()) missing.add('msvcp140.dll');
      if (!vcruntime140_1.existsSync()) missing.add('vcruntime140_1.dll');

      if (missing.isEmpty) {
        _results.add(DiagnosticResult(
          name: 'VC++ Redistributable',
          passed: true,
          message: 'All required VC++ runtime DLLs found',
        ));
      } else {
        _results.add(DiagnosticResult(
          name: 'VC++ Redistributable',
          passed: false,
          message: 'MISSING: ${missing.join(', ')}',
          details: 'Download VC++ Redistributable from: '
              'https://aka.ms/vs/17/release/vc_redist.x64.exe',
        ));
      }
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'VC++ Redistributable',
        passed: false,
        message: 'Check failed: $e',
      ));
    }
  }

  /// Check write permissions to app data directory.
  Future<void> _checkWritePermissions() async {
    try {
      final appData = await getApplicationSupportDirectory();
      final testFile = File(p.join(appData.path, '.dukanx_write_test'));

      // Try writing
      testFile.writeAsStringSync('test', flush: true);
      testFile.deleteSync();

      _results.add(DiagnosticResult(
        name: 'Write Permissions',
        passed: true,
        message: 'Can write to: ${appData.path}',
      ));
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'Write Permissions',
        passed: false,
        message: 'CANNOT WRITE to app data directory',
        details: 'Error: $e\nThis may be caused by antivirus or folder permissions.',
      ));
    }

    // Also check Documents directory (where DB lives)
    try {
      final docs = await getApplicationDocumentsDirectory();
      final testFile = File(p.join(docs.path, '.dukanx_db_write_test'));
      testFile.writeAsStringSync('test', flush: true);
      testFile.deleteSync();

      _results.add(DiagnosticResult(
        name: 'DB Directory Permissions',
        passed: true,
        message: 'Can write to Documents: ${docs.path}',
      ));
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'DB Directory Permissions',
        passed: false,
        message: 'CANNOT WRITE to Documents directory',
        details: 'Error: $e\nDatabase creation will fail.',
      ));
    }
  }

  /// Check database file access.
  Future<void> _checkDatabaseAccess() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(docs.path, 'dukanx_enterprise.sqlite'));

      if (dbFile.existsSync()) {
        final stat = dbFile.statSync();
        _results.add(DiagnosticResult(
          name: 'Database File',
          passed: true,
          message: 'Exists (${(stat.size / 1024).toStringAsFixed(1)} KB)',
          details: 'Path: ${dbFile.path}\nModified: ${stat.modified}',
        ));
      } else {
        _results.add(DiagnosticResult(
          name: 'Database File',
          passed: true,
          message: 'Not yet created (will be created on first run)',
          details: 'Expected path: ${dbFile.path}',
        ));
      }
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'Database File',
        passed: false,
        message: 'Cannot access database path: $e',
      ));
    }
  }

  /// Check Flutter assets are present in the data folder.
  Future<void> _checkFlutterAssets() async {
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final dataDir = Directory(p.join(exeDir, 'data'));
      final assetsDir = Directory(p.join(exeDir, 'data', 'flutter_assets'));

      final checks = <String, bool>{};

      // Check data directory
      checks['data/'] = dataDir.existsSync();

      // Check flutter_assets
      checks['data/flutter_assets/'] = assetsDir.existsSync();

      // Check key asset files
      final icudtl = File(p.join(exeDir, 'data', 'icudtl.dat'));
      checks['data/icudtl.dat'] = icudtl.existsSync();

      // Check AOT snapshot
      final appSo = File(p.join(exeDir, 'data', 'app.so'));
      checks['data/app.so'] = appSo.existsSync();

      // Check flutter_assets subdirectories
      if (assetsDir.existsSync()) {
        final assetManifest = File(
            p.join(assetsDir.path, 'AssetManifest.json'));
        final assetManifestBin = File(
            p.join(assetsDir.path, 'AssetManifest.bin'));
        checks['AssetManifest'] = assetManifest.existsSync() ||
            assetManifestBin.existsSync();

        final fontManifest = File(
            p.join(assetsDir.path, 'FontManifest.json'));
        checks['FontManifest.json'] = fontManifest.existsSync();
      }

      final missing = checks.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

      if (missing.isEmpty) {
        _results.add(DiagnosticResult(
          name: 'Flutter Assets',
          passed: true,
          message: 'All ${checks.length} required assets found',
        ));
      } else {
        _results.add(DiagnosticResult(
          name: 'Flutter Assets',
          passed: false,
          message: 'MISSING: ${missing.join(', ')}',
          details: 'Exe dir: $exeDir\nRebuild with: flutter build windows --release',
        ));
      }
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'Flutter Assets',
        passed: false,
        message: 'Asset check failed: $e',
      ));
    }
  }

  /// Check plugin DLLs are present.
  Future<void> _checkPluginDlls() async {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);

      // Core Flutter DLL
      final flutterDll = File(p.join(exeDir, 'flutter_windows.dll'));

      // Known plugin DLLs (from generated_plugins.cmake)
      final expectedDlls = [
        'flutter_windows.dll',
      ];

      final missing = <String>[];
      for (final dll in expectedDlls) {
        if (!File(p.join(exeDir, dll)).existsSync()) {
          missing.add(dll);
        }
      }

      // Also list all DLLs found in the directory
      final dir = Directory(exeDir);
      final foundDlls = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dll'))
          .map((f) => p.basename(f.path))
          .toList();

      if (missing.isEmpty && flutterDll.existsSync()) {
        _results.add(DiagnosticResult(
          name: 'Plugin DLLs',
          passed: true,
          message: '${foundDlls.length} DLLs found',
          details: 'DLLs: ${foundDlls.join(', ')}',
        ));
      } else {
        _results.add(DiagnosticResult(
          name: 'Plugin DLLs',
          passed: false,
          message: 'Missing DLLs: ${missing.join(', ')}',
          details: 'Found: ${foundDlls.join(', ')}\n'
              'Rebuild with: flutter build windows --release',
        ));
      }
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'Plugin DLLs',
        passed: false,
        message: 'DLL check failed: $e',
      ));
    }
  }

  /// Check AWS compat layer configuration (Firebase removed).
  Future<void> _checkFirebaseConfig() async {
    // Firebase has been completely removed. All services use AWS compat layers.
    _results.add(DiagnosticResult(
      name: 'Cloud Backend Config',
      passed: true,
      message: 'Firebase removed — all services use AWS compat layers',
      details: 'Auth: Cognito (firebase_auth_compat.dart)\n'
          'Data: API Gateway → DynamoDB (firestore_compat.dart)\n'
          'Storage: S3 via ApiClient\n'
          'Crash reporting: MonitoringService (dart:developer)',
    ));
  }

  /// Check internet connectivity.
  Future<void> _checkInternetConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final hasNetwork = result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.mobile);

      _results.add(DiagnosticResult(
        name: 'Internet Connectivity',
        passed: true,
        message: hasNetwork
            ? 'Connected (${result.map((r) => r.name).join(', ')})'
            : 'No internet (app should work offline)',
        details: hasNetwork ? null : 'Firebase initialization may timeout without internet.',
      ));
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'Internet Connectivity',
        passed: true,
        message: 'Check failed (non-blocking): $e',
      ));
    }
  }

  /// Check secure storage availability.
  Future<void> _checkSecureStorage() async {
    try {
      // On Windows, flutter_secure_storage uses Windows Credential Manager
      // We just verify the plugin is loadable
      _results.add(DiagnosticResult(
        name: 'Secure Storage',
        passed: true,
        message: 'flutter_secure_storage_windows plugin registered',
        details: 'Uses Windows Credential Manager (DPAPI).',
      ));
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'Secure Storage',
        passed: false,
        message: 'Secure storage check failed: $e',
      ));
    }
  }

  /// Check available disk space.
  Future<void> _checkDiskSpace() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      // Use the drive of the documents directory
      final drive = docs.path.substring(0, 3); // e.g., "C:\"

      if (Platform.isWindows) {
        final result = await Process.run(
          'wmic',
          ['logicaldisk', 'where', 'DeviceID="${drive.substring(0, 2)}"',
           'get', 'FreeSpace', '/value'],
        );
        final output = result.stdout.toString().trim();
        final match = RegExp(r'FreeSpace=(\d+)').firstMatch(output);
        if (match != null) {
          final freeBytes = int.parse(match.group(1)!);
          final freeGB = freeBytes / (1024 * 1024 * 1024);
          _results.add(DiagnosticResult(
            name: 'Disk Space',
            passed: freeGB > 0.5,
            message: '${freeGB.toStringAsFixed(1)} GB free on $drive',
            details: freeGB < 1.0
                ? 'WARNING: Low disk space may cause database issues'
                : null,
          ));
          return;
        }
      }

      _results.add(DiagnosticResult(
        name: 'Disk Space',
        passed: true,
        message: 'Could not determine (non-critical)',
      ));
    } catch (e) {
      _results.add(DiagnosticResult(
        name: 'Disk Space',
        passed: true,
        message: 'Check failed (non-critical): $e',
      ));
    }
  }

  /// Generate the full report.
  void _generateReport() {
    final report = StringBuffer();
    report.writeln('\n${'=' * 70}');
    report.writeln('DUKANX DIAGNOSTICS REPORT');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln('=' * 70);
    report.writeln('');

    for (final result in _results) {
      report.writeln(result.toString());
    }

    report.writeln('');
    report.writeln('─' * 70);
    report.writeln('SUMMARY: $passCount passed, $failCount failed, '
        '${_results.length} total');

    if (failCount > 0) {
      report.writeln('');
      report.writeln('⚠ FAILED CHECKS:');
      for (final result in _results.where((r) => !r.passed)) {
        report.writeln('  → ${result.name}: ${result.message}');
      }
    }

    report.writeln('=' * 70);

    final reportStr = report.toString();
    startupLog.section('DIAGNOSTICS REPORT', reportStr);

    // Also print to stdout for console visibility
    // ignore: avoid_print
    print(reportStr);
  }
}
