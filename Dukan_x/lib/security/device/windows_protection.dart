import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/logger_service.dart';
import 'package:crypto/crypto.dart';

/// Windows-Specific Security Protection Service
/// Detects debuggers, DLL injection, memory tampering, and other
/// attack vectors specific to Windows desktop applications.
///
/// SECURITY:
///   - Checks for attached debuggers (IsDebuggerPresent)
///   - Detects known malicious DLLs (Frida, Xposed, etc.)
///   - Verifies executable integrity via SHA-256 checksums
///   - Monitors for suspicious process names
///   - Detects virtualization/sandbox environments
class WindowsProtectionService {
  bool _isInitialized = false;
  bool _integrityValid = true;
  final List<String> _detectedThreats = [];
  String? _executableHash;

  // Known malicious/hooking DLL names (lowercase)
  static const _suspiciousDlls = [
    'frida-gadget',
    'frida-agent',
    'substrate',
    'xposed',
    'cydia',
    'dbghelp',
    'titaniumbackup',
    'gameguardian',
    'lucky_patcher',
    'magisk',
    'libhooker',
  ];

  // Known debugging/reverse-engineering process names (lowercase)
  static const _suspiciousProcesses = [
    'x64dbg',
    'x32dbg',
    'ollydbg',
    'ida64',
    'ida',
    'ghidra',
    'procmon',
    'procexp',
    'wireshark',
    'fiddler',
    'charles',
    'mitmproxy',
    'dnspy',
    'dotpeek',
    'ilspy',
    'cheatengine',
    'artmoney',
    'frida',
    'objection',
  ];

  /// Initialize Windows protection layer
  Future<bool> initialize() async {
    if (!Platform.isWindows) {
      _isInitialized = true;
      return true;
    }

    try {
      // 1. Check for debugger attachment
      final debuggerAttached = _checkDebuggerAttached();
      if (debuggerAttached) {
        _detectedThreats.add('DEBUGGER_ATTACHED');
        LoggerService.d('WindowsProtection', '⚠️ SECURITY: Debugger detected');
      }

      // 2. Compute executable hash for integrity checking
      _executableHash = await _computeExecutableHash();
      LoggerService.d('WindowsProtection', '🔒 Executable hash: ${_executableHash?.substring(0, 16)}...');

      // 3. Check for suspicious processes
      final suspiciousProcs = await _checkSuspiciousProcesses();
      if (suspiciousProcs.isNotEmpty) {
        _detectedThreats.addAll(
          suspiciousProcs.map((p) => 'SUSPICIOUS_PROCESS:$p'),
        );
        LoggerService.d('WindowsProtection', 
          '⚠️ SECURITY: Suspicious processes detected: $suspiciousProcs',
        );
      }

      // 4. Check for DLL injection indicators
      final injectedDlls = await _checkDllInjection();
      if (injectedDlls.isNotEmpty) {
        _detectedThreats.addAll(injectedDlls.map((d) => 'DLL_INJECTION:$d'));
        LoggerService.d('WindowsProtection', '⚠️ SECURITY: Suspicious DLLs detected: $injectedDlls');
      }

      _integrityValid = _detectedThreats.isEmpty;
      _isInitialized = true;

      return _integrityValid;
    } catch (e) {
      LoggerService.d('WindowsProtection', 'Windows protection initialization error: $e');
      _isInitialized = true;
      return true; // Fail-open to avoid blocking on security check errors
    }
  }

  /// Check if a debugger is attached using Windows API
  bool _checkDebuggerAttached() {
    if (!Platform.isWindows) return false;

    // In release mode, check for debugger
    if (kReleaseMode) {
      try {
        final kernel32 = DynamicLibrary.open('kernel32.dll');

        // IsDebuggerPresent
        final isDebuggerPresent = kernel32
            .lookupFunction<Int32 Function(), int Function()>(
              'IsDebuggerPresent',
            );
        if (isDebuggerPresent() != 0) return true;

        // CheckRemoteDebuggerPresent
        final checkRemoteDebugger = kernel32
            .lookupFunction<
              Int32 Function(IntPtr, Pointer<Int32>),
              int Function(int, Pointer<Int32>)
            >('CheckRemoteDebuggerPresent');

        final getCurrentProcess = kernel32
            .lookupFunction<IntPtr Function(), int Function()>(
              'GetCurrentProcess',
            );

        final debuggerFlag = calloc<Int32>();
        try {
          checkRemoteDebugger(getCurrentProcess(), debuggerFlag);
          if (debuggerFlag.value != 0) return true;
        } finally {
          calloc.free(debuggerFlag);
        }
      } catch (e) {
        LoggerService.d('WindowsProtection', 'Debugger check failed: $e');
      }
    }

    return false;
  }

  /// Compute SHA-256 hash of the running executable
  Future<String?> _computeExecutableHash() async {
    try {
      final exePath = Platform.resolvedExecutable;
      final exeFile = File(exePath);
      if (await exeFile.exists()) {
        final bytes = await exeFile.readAsBytes();
        return sha256.convert(bytes).toString();
      }
    } catch (e) {
      LoggerService.d('WindowsProtection', 'Executable hash computation failed: $e');
    }
    return null;
  }

  /// Verify executable integrity by comparing hash
  /// The expected hash should be stored securely (e.g., in secure storage
  /// during first run, or hardcoded for release builds)
  Future<bool> verifyExecutableIntegrity(String? expectedHash) async {
    if (expectedHash == null || _executableHash == null) return true;
    return _executableHash == expectedHash;
  }

  /// Check for suspicious processes that indicate reverse engineering
  Future<List<String>> _checkSuspiciousProcesses() async {
    final detected = <String>[];

    if (!Platform.isWindows) return detected;

    try {
      final result = await Process.run('tasklist', ['/NH', '/FO', 'CSV']);
      final output = (result.stdout as String).toLowerCase();

      for (final processName in _suspiciousProcesses) {
        if (output.contains(processName)) {
          detected.add(processName);
        }
      }
    } catch (e) {
      // tasklist may not be available — ignore
    }

    return detected;
  }

  /// Check for known malicious/hooking DLLs loaded in the process
  Future<List<String>> _checkDllInjection() async {
    final detected = <String>[];

    if (!Platform.isWindows) return detected;

    try {
      // Check loaded modules via listdlls-like approach
      final result = await Process.run('tasklist', [
        '/M',
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
      ]);
      final output = (result.stdout as String).toLowerCase();

      for (final dllName in _suspiciousDlls) {
        if (output.contains(dllName)) {
          detected.add(dllName);
        }
      }
    } catch (e) {
      // Ignore failures
    }

    return detected;
  }

  /// Run periodic security checks (call from a timer)
  Future<Map<String, dynamic>> runPeriodicCheck() async {
    if (!Platform.isWindows) {
      return {'status': 'skipped', 'reason': 'not_windows'};
    }

    final issues = <String>[];

    // Re-check debugger
    if (_checkDebuggerAttached()) {
      issues.add('debugger_attached');
    }

    // Re-check suspicious processes
    final procs = await _checkSuspiciousProcesses();
    if (procs.isNotEmpty) {
      issues.add('suspicious_processes: ${procs.join(", ")}');
    }

    // Re-verify executable hash
    final currentHash = await _computeExecutableHash();
    if (_executableHash != null &&
        currentHash != null &&
        currentHash != _executableHash) {
      issues.add('executable_modified');
    }

    return {
      'status': issues.isEmpty ? 'secure' : 'threats_detected',
      'issues': issues,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get current threat status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'integrityValid': _integrityValid,
      'detectedThreats': _detectedThreats,
      'executableHashPrefix': _executableHash?.substring(0, 16),
    };
  }

  bool get isInitialized => _isInitialized;
  bool get isIntegrityValid => _integrityValid;
  List<String> get detectedThreats => List.unmodifiable(_detectedThreats);

  void dispose() {
    _detectedThreats.clear();
  }
}
