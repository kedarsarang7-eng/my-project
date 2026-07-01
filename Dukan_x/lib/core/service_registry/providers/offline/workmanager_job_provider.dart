// Offline Job Provider — persists jobs to Drift `sync_queue` and schedules
// periodic processing via workmanager. This reuses the existing
// BackgroundSyncService infrastructure so no new runtime is needed.

import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../../../../core/database/app_database.dart';
import '../../contracts/i_job_service.dart';

/// Drift-backed job queue for offline mode.
/// Jobs are stored in the KvStore under prefix "job:pending:{id}".
class WorkmanagerJobProvider implements IJobService {
  static const _uuid = Uuid();
  static const _jobPrefix = 'job:pending:';
  static const _schedulePrefix = 'job:schedule:';

  AppDatabase get _db => AppDatabase.instance;

  @override
  Future<String> queue(
    String jobName,
    Map<String, dynamic> payload, {
    JobOptions? options,
  }) async {
    final jobId = options?.idempotencyKey ?? _uuid.v4();

    // Deduplicate by idempotency key.
    final existing = await _db.getKv('$_jobPrefix$jobId');
    if (existing != null) return jobId;

    final record = jsonEncode({
      'jobId': jobId,
      'jobName': jobName,
      'payload': payload,
      'maxAttempts': options?.maxAttempts ?? 5,
      'attempts': 0,
      'status': 'pending',
      'notBefore': options?.notBefore?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _db.upsertKv('$_jobPrefix$jobId', record);

    // Trigger workmanager one-shot task so the job runs even if user
    // navigates away.
    await Workmanager().registerOneOffTask(
      jobId,
      jobName,
      inputData: {'jobId': jobId},
      constraints: Constraints(networkType: NetworkType.notRequired),
    );

    return jobId;
  }

  @override
  Future<void> schedule(
    String jobName,
    String cron,
    Map<String, dynamic> payload,
  ) async {
    final scheduleId = '${jobName}_schedule';
    final record = jsonEncode({
      'jobName': jobName,
      'cron': cron,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _db.upsertKv('$_schedulePrefix$scheduleId', record);

    // workmanager periodic (simplified — minimum 15 min on Android).
    await Workmanager().registerPeriodicTask(
      scheduleId,
      jobName,
      inputData: payload,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }

  @override
  Future<void> retry(String jobId) async {
    final raw = await _db.getKv('$_jobPrefix$jobId');
    if (raw == null) return;
    final record = jsonDecode(raw) as Map<String, dynamic>;
    record['status'] = 'pending';
    await _db.upsertKv('$_jobPrefix$jobId', jsonEncode(record));
  }

  @override
  Future<void> dispose() async {}
}
