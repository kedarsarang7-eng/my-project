// ============================================================================
// DUKANX - MAIN ENTRY POINT
// ============================================================================
// Production-ready bootstrap with proper dependency injection
//
// ARCHITECTURE:
// UI → Riverpod State → Repository → Drift DB → SyncManager → Firestore
//
// Author: DukanX Engineering
// Version: 3.0.0 (Production Hardened)
// ============================================================================

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/config/api_config.dart';
// firebase_app_check removed — API security handled by Cognito JWT + API Gateway
import 'package:workmanager/workmanager.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dukanx/services/google_drive_service.dart';

// Core DI & Session
import 'core/di/service_locator.dart';
import 'core/auth/auth_intent_service.dart';
import 'core/mode/offline_startup_coordinator.dart';

import 'core/monitoring/monitoring_service.dart';
import 'core/sync/background_sync_service.dart';
import 'core/sync/sync_manager.dart';

import 'core/database/app_database.dart';
import 'core/app_bootstrap.dart';
import 'core/diagnostics/startup_logger.dart';
import 'core/diagnostics/diagnostics_runner.dart';
import 'core/lifecycle/app_lifecycle_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/data_integrity_service.dart';

// Error Boundary
import 'widgets/error_boundary.dart';

// ============================================================================
// CANONICAL APP WIDGET — defined in lib/app/app.dart
// Navigation is driven by go_router via MaterialApp.router, configured in
// lib/app/app.dart. The legacy named-route table was removed.
// ============================================================================
import 'app/app.dart';

// ============================================================================
// WORKMANAGER CALLBACK (Must be top-level)
// ============================================================================
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      developer.log('Background task started: $taskName', name: 'WorkManager');

      // No Firebase init needed — all data ops use AWS compat layer
      if (taskName == BackgroundSyncService.syncTaskName) {
        // Get pending count and sync
        final database = AppDatabase.instance;
        final pending = await database.getPendingSyncEntries();

        if (pending.isNotEmpty) {
          // Initialize sync manager and perform sync
          final syncManager = SyncManager.instance;
          await syncManager.initialize(localOperations: database);
          await syncManager.forceSyncAll();
        }

        developer.log(
          'Background sync completed: ${pending.length} items',
          name: 'WorkManager',
        );
      }

      return true;
    } catch (e, stack) {
      developer.log(
        'Background task failed: $e',
        name: 'WorkManager',
        stackTrace: stack,
      );
      return false;
    }
  });
}

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================
void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 0. CRITICAL: Initialize file-based startup logger FIRST
      // This writes to %APPDATA%\DukanX\logs\startup.log so silent
      // crashes on deployment machines are diagnosed.
      await startupLog.initialize();
      startupLog.step('WidgetsFlutterBinding initialized');

      // 0.1 Check for --diagnostics mode
      final isDiagnostics =
          Platform.executableArguments.contains('--diagnostics') ||
          (Platform.environment['DUKANX_DIAGNOSTICS'] == '1');
      if (isDiagnostics) {
        startupLog.info('DIAGNOSTICS MODE REQUESTED');
      }

      // 1. Load environment config
      try {
        await dotenv.load(fileName: ".env");
        startupLog.step('Environment config loaded');
      } catch (e) {
        startupLog.warn(
          'Environment config load failed (expected if .env not in assets): $e',
        );
        try {
          dotenv.loadFromString(envString: 'INITIALIZED=true');
          startupLog.step('Environment config initialized with fallback');
        } catch (_) {}
      }

      // 1.2. Load any user-configured server URL override (Server Settings).
      try {
        await ApiConfig.loadRuntimeOverride();
        startupLog.step('Server settings override loaded');
      } catch (e) {
        startupLog.warn('Server settings override load failed: $e');
      }

      // 1.5. Initialize Google Sign-In (v7.x requirement)
      try {
        await GoogleSignIn.instance.initialize();
        startupLog.step('Google Sign-In initialized');
        // Silently restore a previous Drive session so the user isn't forced
        // to re-link Google Drive every launch (non-fatal if unavailable).
        unawaited(GoogleDriveService().tryRestoreSession());
      } catch (e) {
        startupLog.warn(
          'Google Sign-In initialization failed (non-fatal on Windows): $e',
        );
      }

      // 2. Configure Flutter error handling (Crash Prevention)
      FlutterError.onError = (details) {
        startupLog.error(
          'FlutterError: ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
        FlutterError.presentError(details);
        monitoring.fatal(
          'FlutterError',
          details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      // 2.0.1 PlatformDispatcher error handler (catches native/async crashes
      // that runZonedGuarded cannot intercept)
      PlatformDispatcher.instance.onError = (error, stack) {
        startupLog.fatal('PlatformDispatcher error', error, stack);
        monitoring.fatal(
          'PlatformDispatcher',
          error.toString(),
          error: error,
          stackTrace: stack,
        );
        return true; // Handled
      };
      startupLog.step('Error handlers configured');

      // 2.1 Global UI Error Fallback (Prevents Gray/Red Screen of Death)
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return MainErrorFallback(details: details);
      };

      // 3. CRITICAL: Initialize dependency injection FIRST
      try {
        await initializeDependencies();
        startupLog.step('Dependencies initialized (GetIt)');
      } catch (e, stack) {
        startupLog.fatal('Dependency injection FAILED', e, stack);
        rethrow;
      }

      // 3.5 Offline_Lifetime_Mode startup sequence
      try {
        await _bootOfflineModeIfActive();
        startupLog.step('Offline mode check completed');
      } catch (e, stack) {
        startupLog.warn('Offline startup check failed (non-blocking): $e');
        developer.log(
          'Offline startup failed: $e',
          name: 'main',
          stackTrace: stack,
        );
      }

      // 4. Firebase removed — all services use AWS compat layers
      startupLog.step('Firebase removed — using AWS compat layers');

      // 5. Initialize WorkManager for background sync
      try {
        await _initializeWorkManager();
        startupLog.step('WorkManager initialized');
      } catch (e) {
        startupLog.warn('WorkManager init failed (non-fatal): $e');
      }

      // 6. Initialize AuthIntentService
      try {
        await authIntent.initialize();
        startupLog.step('AuthIntentService initialized');
      } catch (e, stack) {
        startupLog.error('AuthIntentService FAILED', e, stack);
      }

      // 7. Register global app lifecycle observer
      try {
        AppLifecycleObserver.instance.register();
        startupLog.step('AppLifecycleObserver registered');
      } catch (e) {
        startupLog.warn('AppLifecycleObserver failed: $e');
      }

      // 7.5 Run diagnostics if requested
      if (isDiagnostics) {
        final runner = DiagnosticsRunner();
        await runner.runAll();
        startupLog.step(
          'Diagnostics completed: '
          '${runner.passCount} passed, ${runner.failCount} failed',
        );
        startupLog.info('Log file: ${startupLog.logFilePath}');
      }

      // 8. Start application
      // DukanXApp is imported from lib/app/app.dart — single source of truth
      startupLog.step('Launching DukanXApp...');
      runApp(const riverpod.ProviderScope(child: DukanXApp()));
      startupLog.step('runApp() completed — UI should be visible');
    },
    (error, stack) {
      // Zone-level crash handler
      startupLog.fatal('Uncaught zone error', error, stack);
      developer.log(
        'Uncaught zone error: $error',
        name: 'main',
        stackTrace: stack,
      );
      monitoring.fatal(
        'ZoneError',
        error.toString(),
        error: error,
        stackTrace: stack,
      );
    },
  );
}

// ============================================================================
// OFFLINE_LIFETIME_MODE STARTUP (offline-license-activation, task 20.1)
// ============================================================================
/// Runs the Offline_Lifetime_Mode Startup_Sequence when offline mode is active.
///
/// Delegates entirely to the wired [OfflineStartupCoordinator]: it resolves the
/// active Operating_Mode and only drives the Backend_Supervisor (license check
/// → decrypt/validate → spawn → health → connect → restore) when the app is in
/// Offline_Lifetime_Mode. In the default Cloud_Subscription_Mode it returns
/// immediately without constructing or starting anything offline, so cloud
/// startup behavior is unchanged. Any failure here is non-fatal to cloud mode
/// and is logged rather than blocking app start.
Future<void> _bootOfflineModeIfActive() async {
  try {
    final didBootOffline = await sl<OfflineStartupCoordinator>()
        .bootIfOffline();
    developer.log(
      didBootOffline
          ? '✓ Offline_Lifetime_Mode startup sequence executed'
          : '✓ Cloud_Subscription_Mode active (offline startup skipped)',
      name: 'main',
    );
  } catch (e, stack) {
    developer.log(
      'Offline startup check failed (non-blocking): $e',
      name: 'main',
      stackTrace: stack,
    );
  }
}

// ============================================================================
// FIREBASE BOOTSTRAP — REMOVED
// ============================================================================
// Firebase has been completely removed from DukanX.
// All data operations now route through:
//   - firestore_compat.dart → API Gateway → DynamoDB
//   - firebase_auth_compat.dart → Cognito
//   - S3 via ApiClient
// Crash reporting handled by MonitoringService (dart:developer)
// Analytics handled by MonitoringService.trackEvent()

// ============================================================================
// WORKMANAGER INITIALIZATION
// ============================================================================
Future<void> _initializeWorkManager() async {
  if (kIsWeb) return; // WorkManager not supported on web

  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    // Register periodic sync task (every 15 minutes)
    await Workmanager().registerPeriodicTask(
      BackgroundSyncService.syncTaskId,
      BackgroundSyncService.syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );

    developer.log('WorkManager registered for background sync', name: 'main');
  } catch (e) {
    developer.log('WorkManager init failed: $e', name: 'main');
  }
}

// ============================================================================
// POST-LOGIN ENTERPRISE INIT
// ============================================================================
Future<void> initEnterpriseServicesForUser(String userId) async {
  if (AppBootstrap.instance.isInitialized) {
    developer.log('Enterprise services already initialized', name: 'main');
    return;
  }

  try {
    await AppBootstrap.instance.initialize(
      userId: userId,
      enableBackgroundSync: !kIsWeb,
    );
    developer.log('Enterprise services initialized for user', name: 'main');

    // ================================================================
    // AUDIT FIX: Automatic weekly integrity verification
    // Ensures 100/100 audit compliance by detecting data drift
    // ================================================================
    _runWeeklyIntegrityCheck(userId);
  } catch (e, stack) {
    developer.log(
      'Enterprise init failed: $e',
      name: 'main',
      stackTrace: stack,
    );
  }
}

/// Background integrity check that runs weekly
/// Fire-and-forget to not block user experience
void _runWeeklyIntegrityCheck(String userId) {
  Future.microtask(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('lastIntegrityCheck') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const weekInMs = 7 * 24 * 60 * 60 * 1000; // 7 days

      if (now - lastCheck > weekInMs) {
        developer.log('Running weekly integrity check...', name: 'integrity');

        // Create integrity service directly with database
        final integrityService = DataIntegrityService(
          database: AppDatabase.instance,
        );

        // Stock integrity check with auto-fix
        final stockResult = await integrityService
            .verifyAndAutoFixStockIntegrity(
              userId,
              minorThreshold: 1.0,
              alertThreshold: 5.0,
            );
        developer.log(
          'Stock integrity: ${stockResult.checkedCount} products, '
          '${stockResult.minorFixCount} corrections',
          name: 'integrity',
        );

        // Customer ledger integrity check
        final ledgerResult = await integrityService.reconcileCustomerBalance(
          userId,
        );
        developer.log(
          'Ledger integrity: ${ledgerResult.checkedCount} customers, '
          '${ledgerResult.correctionCount} corrected',
          name: 'integrity',
        );

        await prefs.setInt('lastIntegrityCheck', now);
        developer.log('Weekly integrity check complete', name: 'integrity');
      }
    } catch (e) {
      developer.log(
        'Integrity check failed (non-blocking): $e',
        name: 'integrity',
      );
    }
  });
}
