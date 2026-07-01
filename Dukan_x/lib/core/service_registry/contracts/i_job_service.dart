// ============================================================================
// IJobService — Background Job Contract
// ============================================================================
// Online  -> AWS SQS (Lambda consumer).
// Offline -> Drift `sync_queue` (existing) processed by `BackgroundSyncService`
//            and `workmanager` periodic tasks.
// ============================================================================

import 'dart:async';

class JobOptions {
  /// Earliest run time (defaults to now).
  final DateTime? notBefore;

  /// Max retry attempts.
  final int maxAttempts;

  /// Idempotency key — duplicate enqueues with the same key are deduplicated.
  final String? idempotencyKey;

  const JobOptions({
    this.notBefore,
    this.maxAttempts = 5,
    this.idempotencyKey,
  });
}

abstract class IJobService {
  /// Enqueue a job. Returns the provider-side job id.
  Future<String> queue(
    String jobName,
    Map<String, dynamic> payload, {
    JobOptions? options,
  });

  /// Schedule a recurring job. `cron` uses standard 5-field crontab syntax.
  Future<void> schedule(
    String jobName,
    String cron,
    Map<String, dynamic> payload,
  );

  /// Force a retry of an existing job (ignores backoff).
  Future<void> retry(String jobId);

  Future<void> dispose() async {}
}
