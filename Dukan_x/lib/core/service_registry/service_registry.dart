// ============================================================================
// SERVICE REGISTRY — THE LAW
// ============================================================================
// THIS IS THE ONLY FILE IN THE ENTIRE CODEBASE ALLOWED TO BRANCH ON AppMode.
//
// All other code (features, repositories, services) calls:
//   ServiceRegistry.db.save(...)
//   ServiceRegistry.auth.login(...)
//   ServiceRegistry.storage.upload(...)
//   etc.
//
// They receive the correct provider transparently. ZERO mode-awareness outside
// this file.
//
// Hot-swap: calling reinitialize() after a migration cutover rewires all six
// service handles to their new providers WITHOUT restarting the Flutter process.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_mode.dart';

// Contracts
import 'contracts/i_auth_service.dart';
import 'contracts/i_database_service.dart';
import 'contracts/i_storage_service.dart';
import 'contracts/i_realtime_service.dart';
import 'contracts/i_job_service.dart';
import 'contracts/i_email_service.dart';

// Online providers
import 'providers/online/cognito_auth_provider.dart';
import 'providers/online/lambda_database_provider.dart';
import 'providers/online/s3_storage_provider.dart';
import 'providers/online/apigw_realtime_provider.dart';
import 'providers/online/sqs_job_provider.dart';
import 'providers/online/ses_email_provider.dart';

// Offline providers
import 'providers/offline/local_vault_auth_provider.dart';
import 'providers/offline/drift_database_provider.dart';
import 'providers/offline/local_fs_storage_provider.dart';
import 'providers/offline/event_bus_realtime_provider.dart';
import 'providers/offline/workmanager_job_provider.dart';
import 'providers/offline/outbox_email_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PUBLIC API — the only thing business code ever sees.
/// ─────────────────────────────────────────────────────────────────────────────

// ignore: non_constant_identifier_names
ServiceBundle get Services => ServiceRegistry.instance._services!;

class ServiceRegistry {
  ServiceRegistry._();
  static final ServiceRegistry instance = ServiceRegistry._();

  ServiceBundle? _services;
  bool get isReady => _services != null;

  AppMode get currentMode => AppModeState.instance.current;

  // ── Initialization ──────────────────────────────────────────────────────────

  /// Call once at app startup (after dotenv is loaded).
  Future<void> initialize() async {
    final mode = AppModeX.fromWire(dotenv.env['MODE']);
    await _buildProviders(mode);
    AppModeState.instance.setInternal(mode);
    debugPrint('[ServiceRegistry] Initialized in ${mode.wire} mode.');
  }

  /// Called by the migration engine after `writeConfigAtomic()`.
  /// Disposes old providers and re-wires with new ones. ~200ms.
  Future<void> reinitialize() async {
    debugPrint('[ServiceRegistry] Reinitializing after mode switch…');
    final old = _services;
    final mode = AppModeX.fromWire(dotenv.env['MODE']);

    // Build new set BEFORE disposing old — fail-safe ordering.
    await _buildProviders(mode);
    AppModeState.instance.setInternal(mode);

    // Dispose old providers gracefully after new ones are live.
    if (old != null) {
      await Future.wait([
        old.auth.dispose().catchError((_) {}),
        old.db.dispose().catchError((_) {}),
        old.storage.dispose().catchError((_) {}),
        old.realtime.dispose().catchError((_) {}),
        old.jobs.dispose().catchError((_) {}),
        old.email.dispose().catchError((_) {}),
      ]);
    }
    debugPrint('[ServiceRegistry] Reinitialized in ${mode.wire} mode.');
  }

  // ── Private builder ─────────────────────────────────────────────────────────

  Future<void> _buildProviders(AppMode mode) async {
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // THE ONLY if(online)/if(offline) BLOCK IN THE ENTIRE CODEBASE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final IAuthService auth;
    final IDatabaseService db;
    final IStorageService storage;
    final IRealtimeService realtime;
    final IJobService jobs;
    final IEmailService email;

    if (mode.isOnline) {
      auth = CognitoAuthProvider();
      db = LambdaDatabaseProvider();
      storage = S3StorageProvider();
      realtime = ApiGwRealtimeProvider();
      jobs = SqsJobProvider();
      email = SesEmailProvider();
    } else {
      auth = LocalVaultAuthProvider();
      db = DriftDatabaseProvider();
      storage = LocalFsStorageProvider();
      realtime = EventBusRealtimeProvider();
      jobs = WorkmanagerJobProvider();
      email = OutboxEmailProvider();
    }
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Connect providers that have async setup.
    await Future.wait([
      realtime.connect().catchError((_) {}),
    ]);

    _services = ServiceBundle(
      auth: auth,
      db: db,
      storage: storage,
      realtime: realtime,
      jobs: jobs,
      email: email,
    );
  }
}

/// Immutable bag of initialized providers. Replaced atomically on reinitialize.
class ServiceBundle {
  final IAuthService auth;
  final IDatabaseService db;
  final IStorageService storage;
  final IRealtimeService realtime;
  final IJobService jobs;
  final IEmailService email;

  const ServiceBundle({
    required this.auth,
    required this.db,
    required this.storage,
    required this.realtime,
    required this.jobs,
    required this.email,
  });
}
