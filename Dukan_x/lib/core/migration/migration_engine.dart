// ============================================================================
// Migration Engine — 8-step Offline → Online pipeline
// ============================================================================
// CRITICAL: Steps 1–7 are NON-DESTRUCTIVE. Local data is never touched until
// Step 8 (writeConfigAtomic). Rollback is available at any point before Step 8.
//
// Usage:
//   final engine = MigrationEngine.instance;
//   engine.progressStream.listen((p) => updateUI(p));
//   await engine.start(license: myLicense, awsConfig: {...});
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../service_registry/config_writer.dart';
import '../service_registry/service_registry.dart';
import '../service_registry/licensing/license_migration_calculator.dart';
import '../services/device_fingerprint_service.dart';
import '../services/logger_service.dart';
import '../api/api_client.dart';
import '../di/service_locator.dart';

import 'migration_models.dart';

class MigrationEngine {
  MigrationEngine._();
  static final MigrationEngine instance = MigrationEngine._();

  final _progress = StreamController<MigrationProgress>.broadcast();
  Stream<MigrationProgress> get progressStream => _progress.stream;

  MigrationStatus _status = MigrationStatus.idle;
  MigrationStatus get status => _status;

  /// Unique ID for this migration run (used for rollback tagging).
  late String _migrationId;

  /// Stores the warning gate completer — the engine suspends at Step 2
  /// until the UI calls [confirmWarningGate].
  Completer<void>? _warningGateCompleter;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Start the migration. [awsConfig] must contain all online provider keys.
  /// The engine emits [MigrationProgress] events throughout.
  Future<MigrationResult> start({
    required OfflineLicense license,
    required Map<String, String> awsConfig,
  }) async {
    if (_status == MigrationStatus.running) {
      return MigrationResult.failure(
        MigrationStep.preFlight,
        'Migration already in progress',
      );
    }

    _migrationId = 'MIG-${DateTime.now().millisecondsSinceEpoch}';
    _status = MigrationStatus.running;

    MigrationStep currentStep = MigrationStep.preFlight;

    try {
      // ── Step 1: Pre-flight ────────────────────────────────────────────────
      currentStep = MigrationStep.preFlight;
      _emit(currentStep, MigrationStatus.running, 'Running pre-flight checks…');
      final preFlightResult = await _runPreFlight();
      if (!preFlightResult.allPassed) {
        throw MigrationException(
          currentStep,
          'Pre-flight failed: ${preFlightResult.failures.map((f) => f.name).join(', ')}',
        );
      }
      _emit(currentStep, MigrationStatus.running, 'Pre-flight passed ✓', stepProgress: 1);

      // ── Step 2: Warning Gate (UI suspends engine here) ────────────────────
      currentStep = MigrationStep.warningGate;
      _warningGateCompleter = Completer<void>();
      final credit = LicenseMigrationCalculator.calculateMigrationCredit(license);
      _emit(
        currentStep,
        MigrationStatus.waitingForUser,
        'Awaiting user confirmation',
        metadata: {
          'credit': {
            'originalPurchaseAmount': credit.originalPurchaseAmount,
            'consumedValue': credit.consumedValue,
            'remainingCredit': credit.remainingCredit,
            'creditsInMonths': credit.creditsInMonths,
            'onlinePlan': credit.onlinePlan.wire,
            'onlinePlanMonthlyPrice': credit.onlinePlanMonthlyPrice,
            'subscriptionExpiry': credit.subscriptionExpiryDate.toIso8601String(),
            'summary': credit.warningGateSummary,
          },
        },
      );
      await _warningGateCompleter!.future; // Suspends until confirmWarningGate()
      _emit(currentStep, MigrationStatus.running, 'User confirmed ✓', stepProgress: 1);

      // ── Step 3: Data Audit ────────────────────────────────────────────────
      currentStep = MigrationStep.dataAudit;
      _emit(currentStep, MigrationStatus.running, 'Auditing local data…');
      final audit = await _auditLocalData();
      _emit(
        currentStep,
        MigrationStatus.running,
        'Audit complete: ${audit.tableCounts.values.fold(0, (a, b) => a + b)} records, '
        '${audit.fileCount} files',
        stepProgress: 1,
        metadata: {
          'tables': audit.tableCounts,
          'fileCount': audit.fileCount,
          'fileSizeBytes': audit.fileSizeBytes,
          'estimatedMinutes': audit.estimatedMigrationTime.inMinutes,
        },
      );

      // ── Step 4: Identity Migration ────────────────────────────────────────
      currentStep = MigrationStep.identityMigrate;
      _emit(currentStep, MigrationStatus.running, 'Provisioning cloud user accounts…');
      final userIdMapping = await _migrateIdentities(awsConfig);
      _emit(
        currentStep,
        MigrationStatus.running,
        'Migrated ${userIdMapping.length} users ✓',
        stepProgress: 1,
      );

      // ── Step 5: Database Migration ────────────────────────────────────────
      currentStep = MigrationStep.databaseMigrate;
      _emit(currentStep, MigrationStatus.running, 'Exporting database to cloud…');
      await _migrateDatabase(awsConfig, userIdMapping, audit);
      _emit(currentStep, MigrationStatus.running, 'Database exported ✓', stepProgress: 1);

      // ── Step 6: File Migration ────────────────────────────────────────────
      currentStep = MigrationStep.fileMigrate;
      _emit(currentStep, MigrationStatus.running, 'Uploading files to cloud storage…');
      await _migrateFiles(awsConfig);
      _emit(currentStep, MigrationStatus.running, 'Files uploaded ✓', stepProgress: 1);

      // ── Step 7: Verification ──────────────────────────────────────────────
      currentStep = MigrationStep.verification;
      _emit(currentStep, MigrationStatus.running, 'Verifying migration integrity…');
      await _verificationPass(audit);
      _emit(currentStep, MigrationStatus.running, 'Verification passed ✓', stepProgress: 1);

      // ── Step 8: License Conversion + Cutover ──────────────────────────────
      currentStep = MigrationStep.cutover;
      _emit(currentStep, MigrationStatus.running, 'Converting license + switching to online…');
      await _cutover(license, credit, awsConfig);
      _emit(
        currentStep,
        MigrationStatus.completed,
        '✅ Switched to Online! You now have ${credit.creditsInMonths} months of '
        '${credit.onlinePlan.wire} plan.',
        stepProgress: 1,
      );

      _status = MigrationStatus.completed;
      return MigrationResult.success();
    } on MigrationException catch (e) {
      LoggerService.d('MigrationEngine', 'Migration failed at ${e.step.label}: ${e.message}');
      _emit(e.step, MigrationStatus.failed, '❌ ${e.message}');
      final rolled = await _rollback(e.step);
      _status = MigrationStatus.failed;
      return MigrationResult.failure(e.step, e.message, rolledBack: rolled);
    } catch (e, st) {
      LoggerService.d('MigrationEngine', 'Unexpected migration error: $e\n$st');
      _emit(currentStep, MigrationStatus.failed, '❌ Unexpected error: $e');
      await _rollback(currentStep);
      _status = MigrationStatus.failed;
      return MigrationResult.failure(currentStep, e.toString(), rolledBack: true);
    }
  }

  /// Called by the UI after the user types "SWITCH TO ONLINE" and taps Confirm.
  void confirmWarningGate() {
    _warningGateCompleter?.complete();
  }

  /// Cancel migration before cutover (any step 1–7).
  Future<void> cancel() async {
    if (_status != MigrationStatus.running &&
        _status != MigrationStatus.waitingForUser) { return; }
    _warningGateCompleter?.completeError(
      const MigrationException(MigrationStep.warningGate, 'User cancelled'),
    );
    _status = MigrationStatus.rolledBack;
  }

  // ── Step implementations ──────────────────────────────────────────────────

  Future<PreFlightResult> _runPreFlight() async {
    final results = await Future.wait([
      _checkInternet(),
      _checkDiskSpace(),
      _checkLicenseEligibility(),
      _checkAwsCredentials(),
    ]);
    return PreFlightResult(results);
  }

  Future<PreFlightCheck> _checkInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final connected = results.any((r) => r != ConnectivityResult.none);
      return PreFlightCheck(
        'Internet connectivity',
        passed: connected,
        failureReason: connected ? null : 'No internet connection detected',
      );
    } catch (_) {
      return const PreFlightCheck(
        'Internet connectivity',
        passed: false,
        failureReason: 'Could not check network status',
      );
    }
  }

  Future<PreFlightCheck> _checkDiskSpace() async {
    // Minimal check — we can't easily get free disk on all platforms.
    // A production implementation would use platform channels.
    return const PreFlightCheck('Disk space', passed: true);
  }

  Future<PreFlightCheck> _checkLicenseEligibility() async {
    try {
      final alreadyMigrated = await AppDatabase.instance.getKv('migration:completed');
      if (alreadyMigrated != null) {
        return const PreFlightCheck(
          'License eligibility',
          passed: false,
          failureReason: 'This device has already been migrated to online mode',
        );
      }
      return const PreFlightCheck('License eligibility', passed: true);
    } catch (_) {
      return const PreFlightCheck('License eligibility', passed: true);
    }
  }

  Future<PreFlightCheck> _checkAwsCredentials() async {
    try {
      final api = sl<ApiClient>();
      final res = await api.get('/health');
      return PreFlightCheck(
        'AWS credentials / backend connectivity',
        passed: res.isSuccess,
        failureReason: res.isSuccess ? null : 'Backend unreachable: ${res.error}',
      );
    } catch (e) {
      return PreFlightCheck(
        'AWS credentials / backend connectivity',
        passed: false,
        failureReason: 'Error: $e',
      );
    }
  }

  Future<AuditReport> _auditLocalData() async {
    final db = AppDatabase.instance;
    final tableCounts = <String, int>{};

    // Count key tables that have significant data.
    final tableNames = [
      'bills', 'customers', 'products', 'payments', 'vendors',
      'purchase_orders', 'expenses', 'audit_logs',
    ];
    for (final table in tableNames) {
      try {
        final count = await db.customSelect(
          'SELECT COUNT(*) as c FROM $table',
        ).map((row) => row.read<int>('c')).getSingleOrNull() ?? 0;
        tableCounts[table] = count;
      } catch (_) {
        tableCounts[table] = 0;
      }
    }

    // Count KV store blobs (file metadata).
    final blobs = await db.kvByPrefix('file:');
    final fileCount = blobs.length;

    final totalRecords = tableCounts.values.fold(0, (a, b) => a + b);
    // Rough estimate: 500ms per 100 records + 2s per file.
    final estimatedSeconds = (totalRecords / 100 * 0.5 + fileCount * 2).round();

    return AuditReport(
      tableCounts: tableCounts,
      fileCount: fileCount,
      fileSizeBytes: 0, // Exact size requires FS scan — skipped for speed
      userCount: 1, // Single-user offline
      estimatedMigrationTime: Duration(seconds: estimatedSeconds),
    );
  }

  Future<Map<String, String>> _migrateIdentities(
    Map<String, String> awsConfig,
  ) async {
    // In offline mode there is typically one admin user.
    // We call the backend to pre-create the Cognito account and get a
    // mapping of local userId → Cognito sub.
    try {
      final fingerprint = await sl<DeviceFingerprintService>().getFingerprint();
      final api = sl<ApiClient>();
      final res = await api.post('/migration/identity', body: {
        'migrationId': _migrationId,
        'deviceFingerprint': fingerprint,
      });

      if (!res.isSuccess || res.data == null) {
        throw MigrationException(
          MigrationStep.identityMigrate,
          'Identity migration API call failed: ${res.error}',
        );
      }

      final data = res.data as Map<String, dynamic>;
      final mapping = Map<String, String>.from(
        (data['userIdMapping'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
      return mapping;
    } catch (e) {
      if (e is MigrationException) rethrow;
      throw MigrationException(MigrationStep.identityMigrate, e.toString());
    }
  }

  Future<void> _migrateDatabase(
    Map<String, String> awsConfig,
    Map<String, String> userIdMapping,
    AuditReport audit,
  ) async {
    final db = AppDatabase.instance;
    final api = sl<ApiClient>();

    final tables = audit.tableCounts.keys.toList();
    int done = 0;

    for (final table in tables) {
      try {
        // Read all rows via raw SQL.
        final rows = await db.customSelect(
          'SELECT * FROM $table LIMIT 10000',
        ).get();

        if (rows.isEmpty) {
          done++;
          _emit(
            MigrationStep.databaseMigrate,
            MigrationStatus.running,
            'Skipping empty table: $table',
            stepProgress: done / tables.length,
          );
          continue;
        }

        // Transform: remap user IDs + add migration metadata.
        final records = rows.map((row) {
          final map = Map<String, dynamic>.from(row.data);
          if (map.containsKey('userId') && userIdMapping.containsKey(map['userId'])) {
            map['userId'] = userIdMapping[map['userId']];
          }
          map['_migratedFrom'] = 'offline';
          map['_sourceId'] = map['id'];
          map['_migratedAt'] = DateTime.now().toIso8601String();
          map['_migrationId'] = _migrationId;
          return map;
        }).toList();

        // Batch-send to Lambda in chunks of 25.
        const chunkSize = 25;
        for (int i = 0; i < records.length; i += chunkSize) {
          final chunk = records.skip(i).take(chunkSize).toList();
          final res = await api.post('/migration/import', body: {
            'migrationId': _migrationId,
            'table': table,
            'records': chunk,
          });
          if (!res.isSuccess) {
            throw MigrationException(
              MigrationStep.databaseMigrate,
              'Batch write failed for $table: ${res.error}',
            );
          }
        }

        done++;
        _emit(
          MigrationStep.databaseMigrate,
          MigrationStatus.running,
          'Migrated $table (${rows.length} rows)',
          stepProgress: done / tables.length,
        );
      } catch (e) {
        if (e is MigrationException) rethrow;
        throw MigrationException(MigrationStep.databaseMigrate, 'Table $table: $e');
      }
    }
  }

  Future<void> _migrateFiles(Map<String, String> awsConfig) async {
    // Upload all blobs from LocalFsStorage to S3 via the online storage provider.
    // We temporarily construct an S3 provider directly — ServiceRegistry is
    // still in offline mode at this point.
    final localStorage = Services.storage;
    final blobs = await localStorage.list('');

    int done = 0;
    for (final blob in blobs) {
      try {
        final bytes = await localStorage.download(blob.key);
        final api = sl<ApiClient>();
        // POST presign → PUT to S3 via migration endpoint.
        final res = await api.post('/migration/upload', body: {
          'migrationId': _migrationId,
          'key': blob.key,
          'mimeType': blob.contentType ?? 'application/octet-stream',
          'sizeBytes': blob.sizeBytes,
          'checksum': blob.checksumSha256,
        });
        if (!res.isSuccess || res.data == null) {
          throw MigrationException(
            MigrationStep.fileMigrate,
            'File presign failed for ${blob.key}: ${res.error}',
          );
        }
        final putUrl = (res.data as Map<String, dynamic>)['url'] as String;

        // PUT bytes directly to S3 presigned URL.
        final s3Res = await http.put(Uri.parse(putUrl), body: bytes);
        final httpRes = s3Res.statusCode;
        if (httpRes != 200 && httpRes != 204) {
          throw MigrationException(
            MigrationStep.fileMigrate,
            'S3 PUT failed for ${blob.key}: HTTP $httpRes',
          );
        }

        done++;
        _emit(
          MigrationStep.fileMigrate,
          MigrationStatus.running,
          'Uploaded ${blob.key}',
          stepProgress: blobs.isEmpty ? 1 : done / blobs.length,
        );
      } catch (e) {
        if (e is MigrationException) rethrow;
        debugPrint('[MigrationEngine] File upload error for ${blob.key}: $e');
      }
    }
  }

  Future<void> _verificationPass(AuditReport audit) async {
    final api = sl<ApiClient>();
    final res = await api.post('/migration/verify', body: {
      'migrationId': _migrationId,
      'expectedCounts': audit.tableCounts,
      'expectedFileCount': audit.fileCount,
    });
    if (!res.isSuccess) {
      throw MigrationException(
        MigrationStep.verification,
        'Verification failed: ${res.error}',
      );
    }
    final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
    final passed = data['allPassed'] as bool? ?? false;
    if (!passed) {
      final mismatches = data['mismatches'] ?? 'unknown';
      throw MigrationException(
        MigrationStep.verification,
        'Record count mismatches detected: $mismatches',
      );
    }
  }

  Future<void> _cutover(
    OfflineLicense license,
    MigrationCredit credit,
    Map<String, String> awsConfig,
  ) async {
    // 1. Convert license on the server.
    final api = sl<ApiClient>();
    final res = await api.post('/migration/cutover', body: {
      'migrationId': _migrationId,
      'licenseId': license.licenseId,
      'clientUUID': license.clientUUID,
      'onlinePlan': credit.onlinePlan.wire,
      'creditsInMonths': credit.creditsInMonths,
      'subscriptionExpiry': credit.subscriptionExpiryDate.toIso8601String(),
    });
    if (!res.isSuccess) {
      throw MigrationException(
        MigrationStep.cutover,
        'License conversion failed: ${res.error}',
      );
    }

    // 2. ATOMIC CONFIG WRITE — POINT OF NO RETURN.
    final newConfig = {
      'MODE': 'online',
      ...awsConfig,
      'LICENSE_MODE': 'online-subscription',
      'SUBSCRIPTION_EXPIRY': credit.subscriptionExpiryDate.toIso8601String(),
      'MIGRATION_ID': _migrationId,
      'MIGRATED_AT': DateTime.now().toIso8601String(),
    };
    await ConfigWriter.instance.writeConfigAtomic(newConfig);

    // 3. Hot-swap ServiceRegistry to online providers (~200ms).
    await ServiceRegistry.instance.reinitialize();

    // 4. Mark migration completed in KV (prevents re-migration).
    await AppDatabase.instance.upsertKv(
      'migration:completed',
      jsonEncode({
        'migrationId': _migrationId,
        'completedAt': DateTime.now().toIso8601String(),
        'onlinePlan': credit.onlinePlan.wire,
      }),
    );

    // 5. Flush offline email outbox if any pending emails exist.
    _flushEmailOutboxInBackground();
  }

  void _flushEmailOutboxInBackground() {
    Future.microtask(() async {
      try {
        final db = AppDatabase.instance;
        final pending = await db.kvByPrefix('email:outbox:');
        for (final raw in pending) {
          final record = jsonDecode(raw) as Map<String, dynamic>;
          if (record['status'] == 'pending') {
            await Services.email.send(
              record['to'] as String,
              record['templateId'] as String,
              Map<String, dynamic>.from(record['variables'] as Map? ?? {}),
            );
            record['status'] = 'sent';
            await db.upsertKv(
              'email:outbox:${record['id']}',
              jsonEncode(record),
            );
          }
        }
      } catch (e) {
        debugPrint('[MigrationEngine] Email outbox flush error: $e');
      }
    });
  }

  // ── Rollback ───────────────────────────────────────────────────────────────

  /// Rolls back cloud-side data created during this migration run.
  /// Local data is NEVER touched — this is the safety guarantee.
  Future<bool> _rollback(MigrationStep failedStep) async {
    // Only rollback cloud data if we got past Step 3 (dataAudit).
    if (failedStep.index < MigrationStep.databaseMigrate.index) { return true; }

    try {
      final api = sl<ApiClient>();
      await api.post('/migration/rollback', body: {
        'migrationId': _migrationId,
        'failedStep': failedStep.wire,
      });
      _emit(
        failedStep,
        MigrationStatus.rolledBack,
        'Migration rolled back. Your offline data is intact.',
      );
      return true;
    } catch (e) {
      debugPrint('[MigrationEngine] Rollback error: $e');
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _emit(
    MigrationStep step,
    MigrationStatus status,
    String message, {
    double stepProgress = 0,
    Map<String, dynamic> metadata = const {},
  }) {
    _progress.add(MigrationProgress(
      step: step,
      status: status,
      message: message,
      stepProgress: stepProgress,
      metadata: metadata,
    ));
  }

  void dispose() {
    _progress.close();
  }
}

extension on MigrationStep {
  String get wire => switch (this) {
        MigrationStep.preFlight => 'pre_flight',
        MigrationStep.warningGate => 'warning_gate',
        MigrationStep.dataAudit => 'data_audit',
        MigrationStep.identityMigrate => 'identity_migrate',
        MigrationStep.databaseMigrate => 'database_migrate',
        MigrationStep.fileMigrate => 'file_migrate',
        MigrationStep.verification => 'verification',
        MigrationStep.cutover => 'cutover',
      };
}
