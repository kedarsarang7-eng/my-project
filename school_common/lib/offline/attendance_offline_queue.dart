import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/school_models.dart';

/// Offline-first attendance queue.
/// Records are saved to Hive when offline and synced when connection is restored.
class AttendanceOfflineQueue {
  static const _boxName = 'attendance_queue';
  static Box? _box;

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  /// Enqueue attendance records when offline
  static Future<void> enqueue(List<AttendanceRecord> records) async {
    final box = _box!;
    final key = 'att_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  /// Get all pending records
  static List<Map<String, dynamic>> getPending() {
    final box = _box!;
    final all = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      try {
        final raw = box.get(key) as String;
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          all.add({...item as Map<String, dynamic>, '_queueKey': key});
        }
      } catch (_) {}
    }
    return all;
  }

  /// Remove synced records by queue key
  static Future<void> markSynced(String queueKey) async {
    await _box?.delete(queueKey);
  }

  /// Clear all pending records
  static Future<void> clearAll() async => await _box?.clear();

  static int get pendingCount => _box?.length ?? 0;
  static bool get hasPending => pendingCount > 0;

  /// Auto-sync when connectivity is restored
  static void startAutoSync(Future<void> Function(List<Map<String, dynamic>>) syncFn) {
    Connectivity().onConnectivityChanged.listen((results) async {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && hasPending) {
        final pending = getPending();
        if (pending.isNotEmpty) {
          try {
            await syncFn(pending);
            await clearAll();
          } catch (_) {}
        }
      }
    });
  }
}
