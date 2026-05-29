import 'dart:convert';

/// Offline sync queue scaffold for school_admin_app.
///
/// Per `bugfix.md` clauses 2.9, 2.10, 2.21 the admin app needs a durable
/// queue with a stable `idempotencyKey` per operation so retries (flaky
/// network, forced kill, multi-device race) cannot duplicate
/// server-side state. This scaffold is the minimal envelope; concrete
/// persistence (Hive / Drift / SharedPreferences) is plumbed by the
/// integration layer at app startup.
///
/// Conflict-resolution policy: server-side dedupe by `idempotencyKey`.
/// On 2xx the queue entry is dropped; on 409 (duplicate) the queue
/// entry is also dropped (the server already has the write); on other
/// errors the entry is retained for retry.

/// One queued operation. The `idempotencyKey` is supplied at enqueue
/// time and is preserved across replays so the backend can dedupe.
class SyncOperation {
  final String idempotencyKey;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final DateTime enqueuedAt;

  const SyncOperation({
    required this.idempotencyKey,
    required this.method,
    required this.path,
    required this.body,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
        'idempotencyKey': idempotencyKey,
        'method': method,
        'path': path,
        'body': body,
        'enqueuedAt': enqueuedAt.toIso8601String(),
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        idempotencyKey: json['idempotencyKey'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        body: Map<String, dynamic>.from(json['body'] as Map),
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      );

  String encode() => jsonEncode(toJson());
}

/// Lightweight in-memory queue. Production apps should plug in a
/// durable backend (Hive box / SharedPreferences entry) by replacing
/// `_storage` with a real persistent map keyed by `idempotencyKey`.
abstract class SyncQueue {
  /// Enqueue an operation. The supplied [idempotencyKey] is honored on
  /// every retry so the server can dedupe.
  Future<void> enqueue(SyncOperation op);

  /// All pending operations in insertion order.
  Future<List<SyncOperation>> pending();

  /// Mark an operation as synced and remove it from the queue.
  Future<void> ack(String idempotencyKey);

  /// Number of operations still waiting.
  Future<int> get length;
}

/// In-memory implementation. Useful for tests and as the default
/// fallback when a persistent backend has not been wired yet.
class InMemorySyncQueue implements SyncQueue {
  final Map<String, SyncOperation> _storage = {};

  @override
  Future<void> enqueue(SyncOperation op) async {
    _storage[op.idempotencyKey] = op;
  }

  @override
  Future<List<SyncOperation>> pending() async => _storage.values.toList();

  @override
  Future<void> ack(String idempotencyKey) async {
    _storage.remove(idempotencyKey);
  }

  @override
  Future<int> get length async => _storage.length;
}
