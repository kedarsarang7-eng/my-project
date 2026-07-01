// ============================================================================
// IEmailService — Transactional Email Contract
// ============================================================================
// Online  -> AWS SES via Lambda /notifications/email endpoint.
// Offline -> Drift `email_outbox` table; flushed automatically on next online
//            transition (or manual user action).
// ============================================================================

import 'dart:async';

class EmailRecipient {
  final String email;
  final Map<String, dynamic> variables;
  const EmailRecipient(this.email, [this.variables = const {}]);
}

abstract class IEmailService {
  /// Send a single templated email.
  Future<void> send(
    String to,
    String templateId,
    Map<String, dynamic> variables,
  );

  /// Bulk send. Online: SES BulkTemplatedEmail. Offline: writes one outbox
  /// row per recipient.
  Future<void> bulk(List<EmailRecipient> recipients, String templateId);

  Future<void> dispose() async {}
}
