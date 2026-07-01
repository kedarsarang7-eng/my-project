// Online Email Provider — sends templated emails via Lambda /notifications/email
// which triggers AWS SES BulkTemplatedEmail.

import 'dart:async';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../contracts/i_email_service.dart';

class SesEmailProvider implements IEmailService {
  ApiClient get _api => sl<ApiClient>();

  @override
  Future<void> send(
    String to,
    String templateId,
    Map<String, dynamic> variables,
  ) async {
    final res = await _api.post('/notifications/email', body: {
      'to': to,
      'templateId': templateId,
      'variables': variables,
    });
    if (!res.isSuccess) {
      throw Exception('[SES] send to $to failed: ${res.error}');
    }
  }

  @override
  Future<void> bulk(List<EmailRecipient> recipients, String templateId) async {
    final res = await _api.post('/notifications/email/bulk', body: {
      'templateId': templateId,
      'recipients': recipients
          .map((r) => {'email': r.email, 'variables': r.variables})
          .toList(),
    });
    if (!res.isSuccess) {
      throw Exception('[SES] bulk send failed: ${res.error}');
    }
  }

  @override
  Future<void> dispose() async {}
}
