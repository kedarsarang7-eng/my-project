import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

import '../di/service_locator.dart';
import '../auth/auth_intent_service.dart';
import '../sync/background_sync_service.dart';
import '../lifecycle/app_lifecycle_observer.dart';
import '../services/logger_service.dart';
import '../../services/license_service.dart';
import '../../features/backup/services/offline_backup_service.dart';

/// Defines the outcome of the initialization phase
enum StartupOutcome { success, noLicense, networkFailure, fatalError }

/// The current phase of the initialization process
enum StartupPhase {
  initializingCore,
  checkingLicense,
  initializingNetwork,
  ready,
}

/// Orchestrates the non-blocking startup and initialization sequence.
/// Guarantees that networking failures DO NOT block the UI thread.
class StartupManager extends ChangeNotifier {
  static final StartupManager _instance = StartupManager._internal();
  factory StartupManager() => _instance;
  StartupManager._internal();

  StartupPhase _phase = StartupPhase.initializingCore;
  StartupPhase get currentPhase => _phase;

  double get progress {
    switch (_phase) {
      case StartupPhase.initializingCore:
        return 0.2;
      case StartupPhase.checkingLicense:
        return 0.4;
      case StartupPhase.initializingNetwork:
        return 0.7;
      case StartupPhase.ready:
        return 1.0;
    }
  }

  void _updatePhase(StartupPhase newPhase) {
    _phase = newPhase;
    notifyListeners();
  }

  /// Begins the non-blocking initialization sequence
  Future<StartupOutcome> bootApp() async {
    try {
      _updatePhase(StartupPhase.initializingCore);

      // 1. Initial Local/Fast Boot Steps
      await _bootCore();

      // 2. Local License Validation
      _updatePhase(StartupPhase.checkingLicense);
      final hasLicense = await _checkLocalLicense();
      if (!hasLicense) {
        return StartupOutcome.noLicense;
      }

      // 3. Network/Background dependencies (Wrapped in Timeouts)
      _updatePhase(StartupPhase.initializingNetwork);
      try {
        await _bootNetworkAndBackgroundServices().timeout(
          const Duration(seconds: 10),
        );
      } catch (e) {
      LoggerService.d('Startup', 'StartupManager: Network init failed/timed out: $e');
        // We still return success as we gracefully degrade to offline mode.
      }

      _updatePhase(StartupPhase.ready);
      return StartupOutcome.success;
    } catch (e, stack) {
      LoggerService.d('Startup', 'StartupManager: Fatal Boot Error: $e\n$stack');
      return StartupOutcome.fatalError;
    }
  }

  /// Boot local dependencies that are fast and synchronous/local async.
  Future<void> _bootCore() async {
    // ================================================================
    // Firebase removed — all services use AWS compat layers.
    // Auth: firebase_auth_compat.dart (Cognito)
    // Data: firestore_compat.dart (API Gateway → DynamoDB)
    // Storage: S3 via ApiClient
    // Crash reporting: MonitoringService (dart:developer)
    // Push notifications: EXCLUDED per removal spec
    // ================================================================
    LoggerService.d('Startup', 'StartupManager: Firebase removed — using AWS compat layers');

    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      LoggerService.d('Startup', "StartupManager: .env load failed, using defaults");
    }

    // Google Sign-In removed — auth via Cognito Hosted UI
    // See google_signin_service.dart for Cognito OAuth2 flow

    // Initialize Service Locator (Local DB, etc)
    if (!isDependenciesInitialized) {
      await initializeDependencies();
    }

    // Initialize Auth Intent
    await authIntent.initialize();

    // Register global app lifecycle observer for sync on resume
    AppLifecycleObserver.instance.register();

    // Initialize offline backup service (starts schedule timer)
    try {
      await OfflineBackupService().initialize();
    } catch (e) {
      LoggerService.d('Startup', 'OfflineBackupService init failed (non-fatal): $e');
    }
  }

  /// Verifies only the LOCAL configuration for a valid license.
  /// Skips online heartbeat verification initially to allow ultra-fast booting.
  Future<bool> _checkLocalLicense() async {
    try {
      // Must use ServiceLocator here
      final licenseService = sl<LicenseService>();
      return await licenseService.hasValidCachedLicense();
    } catch (e) {
      LoggerService.d('Startup', 'StartupManager: License check failed: $e');
      return false; // Safest default is to ask for license
    }
  }

  /// Initialize WorkManager and background tasks with strict timeouts.
  Future<void> _bootNetworkAndBackgroundServices() async {
    if (!kIsWeb) {
      try {
        await Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: kDebugMode,
        );

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
      } catch (e) {
        LoggerService.d('Startup', 'StartupManager: WorkManager init failed: $e');
      }
    }
  }
}

// callbackDispatcher is defined in background_sync_service.dart (canonical).
// WorkManager resolves it at the top-level entry point via @pragma('vm:entry-point').
