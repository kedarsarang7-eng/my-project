// Online Job Provider — enqueues jobs via Lambda /jobs endpoint which
// forwards to SQS for async processing by consumer Lambdas.

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../contracts/i_job_service.dart';

class SqsJobProvider implements IJobService {
  ApiClient get _api => sl<ApiClient>();
  static const _uuid = Uuid();

  @override
  Future<String> queue(
    String jobName,
    Map<String, dynamic> payload, {
    JobOptions? options,
  }) async {
    final jobId = options?.idempotencyKey ?? _uuid.v4();
    final res = await _api.post('/jobs', body: {
      'jobId': jobId,
      'jobName': jobName,
      'payload': payload,
      if (options?.notBefore != null)
        'notBefore': options!.notBefore!.toIso8601String(),
      'maxAttempts': options?.maxAttempts ?? 5,
    });
    if (!res.isSuccess) {
      throw Exception('[SqsJob] queue $jobName failed: ${res.error}');
    }
    final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
    return (data['jobId'] as String?) ?? jobId;
  }

  @override
  Future<void> schedule(
    String jobName,
    String cron,
    Map<String, dynamic> payload,
  ) async {
    final res = await _api.post('/jobs/schedule', body: {
      'jobName': jobName,
      'cron': cron,
      'payload': payload,
    });
    if (!res.isSuccess) {
      throw Exception('[SqsJob] schedule $jobName failed: ${res.error}');
    }
  }

  @override
  Future<void> retry(String jobId) async {
    final res = await _api.post('/jobs/$jobId/retry', body: {});
    if (!res.isSuccess) {
      throw Exception('[SqsJob] retry $jobId failed: ${res.error}');
    }
  }

  @override
  Future<void> dispose() async {}
}
