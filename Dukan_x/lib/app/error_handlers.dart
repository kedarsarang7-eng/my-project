// ============================================================================
// GLOBAL ERROR HANDLERS
// ============================================================================
// Configures Flutter's framework-level error pipeline:
//   • FlutterError.onError      — caught Flutter exceptions
//   • ErrorWidget.builder       — replaces red-screen-of-death with friendly UI
//   • runZonedGuarded callback  — async / uncaught zone errors
//
// All paths funnel into `CrashReporter` and `MonitoringService` so the same
// telemetry pipeline sees every failure mode.
// ============================================================================

import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../core/error/crash_reporter.dart';
import '../core/monitoring/monitoring_service.dart';
import '../widgets/error_boundary.dart' show MainErrorFallback;

/// Install Flutter framework + UI error handlers. Call exactly once during
/// startup, before `runApp()`.
void installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashReporter().recordFatalError(
      details.exception,
      details.stack ?? StackTrace.empty,
    );
    try {
      monitoring.fatal(
        'FlutterError',
        details.exceptionAsString(),
        error: details.exception,
        stackTrace: details.stack,
      );
    } catch (_) {
      // Monitoring must never throw from an error handler.
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MainErrorFallback(details: details);
  };
}

/// Handle uncaught zone errors from `runZonedGuarded`. This is a top-level
/// function (not a closure) so it can be referenced cleanly from `main()`.
void handleZoneError(Object error, StackTrace stack) {
  developer.log(
    'Uncaught zone error: $error',
    name: 'main',
    stackTrace: stack,
  );
  CrashReporter().recordFatalError(error, stack);
  try {
    monitoring.fatal(
      'ZoneError',
      error.toString(),
      error: error,
      stackTrace: stack,
    );
  } catch (_) {
    // Never throw from an error handler.
  }
}
