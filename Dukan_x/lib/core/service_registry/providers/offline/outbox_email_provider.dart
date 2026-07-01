// Offline Email Provider — writes emails to a Drift KvStore outbox.
// Emails are flushed automatically by the migration engine when switching
// to online mode, or manually via Settings > Flush Email Outbox.
// No SMTP server is started locally.

import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../contracts/i_email_service.dart';

class OutboxEmailProvider implements IEmailService {
  static const _uuid = Uuid();
  static const _outboxPrefix = 'email:outbox:';

  AppDatabase get _db => AppDatabase.instance;

  @override
  Future<void> send(
    String to,
    String templateId,
    Map<String, dynamic> variables,
  ) async {
    final id = _uuid.v4();
    final record = jsonEncode({
      'id': id,
      'to': to,
      'templateId': templateId,
      'variables': variables,
      'status': 'pending',
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await _db.upsertKv('$_outboxPrefix$id', record);
  }

  @override
  Future<void> bulk(List<EmailRecipient> recipients, String templateId) async {
    await Future.wait(recipients.map(
      (r) => send(r.email, templateId, r.variables),
    ));
  }

  /// Retrieve all pending outbox items. Used by the migration flush step.
  Future<List<Map<String, dynamic>>> getPendingOutbox() async {
    final all = await _db.kvByPrefix(_outboxPrefix);
    return all
        .map((v) => Map<String, dynamic>.from(jsonDecode(v) as Map))
        .where((m) => m['status'] == 'pending')
        .toList();
  }

  /// Mark an outbox item as sent. Called after the online SES send succeeds.
  Future<void> markSent(String id) async {
    final raw = await _db.getKv('$_outboxPrefix$id');
    if (raw == null) return;
    final record = jsonDecode(raw) as Map<String, dynamic>;
    record['status'] = 'sent';
    record['sentAt'] = DateTime.now().toIso8601String();
    await _db.upsertKv('$_outboxPrefix$id', jsonEncode(record));
  }

  @override
  Future<void> dispose() async {}
}
