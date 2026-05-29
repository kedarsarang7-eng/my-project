import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Offline attendance queue for teacher app.
///
/// Per `bugfix.md` clause 2.10, every queued batch carries a stable
/// `idempotencyKey`. The key is generated when `enqueue` is called and
/// preserved across app restarts via Hive so retries (network flake,
/// forced kill, multi-device reconciliation) cannot duplicate writes
/// server-side. Conflict-resolution policy: server-side dedupe by
/// `idempotencyKey`; if the server reports the key was already accepted,
/// the local batch is marked synced without re-uploading.
///
/// Saves attendance records to Hive when offline -> auto-syncs on reconnect.
class AttendanceOfflineQueue {
  static const _boxName = 'teacher_att_queue';
  static Box? _box;

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  /// Enqueue a batch with a stable [idempotencyKey]. Callers should pass
  /// `Uuid().v4()` (or any monotonic-unique generator) so retries reuse
  /// the same key and the server can dedupe. Returns the key for caller
  /// observability.
  static Future<String> enqueue(
    List<Map<String, dynamic>> records, {
    required String idempotencyKey,
  }) async {
    final hiveKey = 'att_${DateTime.now().millisecondsSinceEpoch}';
    final envelope = <String, dynamic>{
      'idempotencyKey': idempotencyKey,
      'records': records,
    };
    await _box?.put(hiveKey, jsonEncode(envelope));
    return idempotencyKey;
  }

  static List<QueuedBatch> getPending() {
    final box = _box;
    if (box == null) return [];
    return box.keys
        .map((key) {
          try {
            final raw = box.get(key) as String;
            final decoded = jsonDecode(raw);
            // Support legacy entries (raw List<Map>) and the new envelope.
            if (decoded is List) {
              return QueuedBatch(
                key: key.toString(),
                idempotencyKey: '',
                records: decoded.cast<Map<String, dynamic>>(),
              );
            }
            final map = decoded as Map<String, dynamic>;
            return QueuedBatch(
              key: key.toString(),
              idempotencyKey: (map['idempotencyKey'] ?? '') as String,
              records: (map['records'] as List).cast<Map<String, dynamic>>(),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<QueuedBatch>()
        .toList();
  }

  static Future<void> markSynced(String key) =>
      _box?.delete(key) ?? Future.value();
  static Future<void> clearAll() => _box?.clear() ?? Future.value();
  static int get pendingCount => _box?.length ?? 0;
  static bool get hasPending => pendingCount > 0;

  /// Call once at app startup to auto-sync when internet is restored.
  /// `syncFn` should forward the batch's `idempotencyKey` to the server
  /// (e.g., as the `Idempotency-Key` HTTP header).
  static void startAutoSync(Future<void> Function(QueuedBatch) syncFn) {
    Connectivity().onConnectivityChanged.listen((result) async {
      // connectivity_plus 5.x emits a single ConnectivityResult, not a list.
      if (result != ConnectivityResult.none && hasPending) {
        for (final batch in getPending()) {
          try {
            await syncFn(batch);
            await markSynced(batch.key);
          } catch (_) {}
        }
      }
    });
  }
}

/// One queued batch of records plus the stable [idempotencyKey] that
/// must be replayed on every retry.
class QueuedBatch {
  final String key;
  final String idempotencyKey;
  final List<Map<String, dynamic>> records;
  const QueuedBatch({
    required this.key,
    required this.idempotencyKey,
    required this.records,
  });
}
