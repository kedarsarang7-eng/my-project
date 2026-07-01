import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import '../core/database/app_database.dart';
import '../core/sync/sync_queue_state_machine.dart';

/// Service to handle system cleanup and optimization
///
/// Responsibilities:
/// 1. Archive & Delete old Audit Logs (> 180 days)
/// 2. Clean Synced Queue items (> 30 days)
/// 3. Clear temporary files (> 7 days)
/// 4. Optimize Database
class CleanupService {
  final AppDatabase _db;

  CleanupService(this._db);

  /// Run comprehensive daily cleanup
  /// Returns map with stats of cleaned items
  Future<Map<String, int>> runDailyCleanup() async {
    final stats = <String, int>{
      'auditLogsArchived': 0,
      'syncQueueCleaned': 0,
      'tempFilesDeleted': 0,
    };

    try {
      debugPrint('CleanupService: Starting daily cleanup...');

      // 1. Archive & Delete Old Audit Logs
      stats['auditLogsArchived'] = await _archiveOldAuditLogs();

      // 2. Clean Old Synced Queue Items
      stats['syncQueueCleaned'] = await _cleanSyncedQueueItems();

      // 3. Clear Temp Files
      stats['tempFilesDeleted'] = await _clearTempFiles();

      // 4. Optimize Database
      try {
        await _db.customStatement('VACUUM;');
        debugPrint('CleanupService: Database optimized (VACUUM)');
      } catch (e) {
        debugPrint('CleanupService: VACUUM failed (harmless): $e');
      }
    } catch (e) {
      debugPrint('CleanupService: Error during daily cleanup: $e');
      // Rethrow? No, cleanup failure shouldn't crash app
    }

    return stats;
  }

  /// Archive logs older than 180 days to JSON file and delete from DB
  Future<int> _archiveOldAuditLogs() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 180));
    int count = 0;

    await _db.transaction(() async {
      // Fetch logs to archive
      final logs = await (_db.select(
        _db.auditLogs,
      )..where((t) => t.timestamp.isSmallerThanValue(cutoffDate))).get();

      if (logs.isEmpty) return;

      count = logs.length;

      // Create Archive
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final archiveDir = Directory('${appDir.path}/archives/audit');
        if (!await archiveDir.exists()) {
          await archiveDir.create(recursive: true);
        }

        final filename =
            'audit_archive_${DateTime.now().millisecondsSinceEpoch}.json.gz';
        final file = File('${archiveDir.path}/$filename');

        final logsJson = logs
            .map(
              (l) => {
                'id': l.id,
                'timestamp': l.timestamp.toIso8601String(),
                'action': l.action,
                'details':
                    '${l.targetTableName}:${l.recordId}', // Constructed details
                'userId': l.userId,
                'previousHash': l.previousHash,
                'hash': l.currentHash, // Use currentHash
              },
            )
            .toList();

        final jsonString = jsonEncode(logsJson);
        final gzipBytes = GZipEncoder().encode(utf8.encode(jsonString));
        if (gzipBytes != null) {
          await file.writeAsBytes(gzipBytes);
        }

        debugPrint('CleanupService: Archived $count logs to $filename');

        // Delete from DB (Safe: already archived)
        await (_db.delete(
          _db.auditLogs,
        )..where((t) => t.timestamp.isSmallerThanValue(cutoffDate))).go();
      } catch (e) {
        debugPrint('CleanupService: Failed to archive logs: $e');
        // Abort transaction if archiving fails
        throw Exception('Archive failed, rolling back delete');
      }
    });

    return count;
  }

  /// Delete SyncQueue items strictly if:
  /// - Status is SYNCED
  /// - Updated > 30 days ago
  /// - NOT in Pending/Failed state (safety)
  Future<int> _cleanSyncedQueueItems() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    final count =
        await (_db.delete(_db.syncQueue)..where(
              (t) =>
                  t.status.equals(
                    SyncStatus.synced.value,
                  ) & // Use value (String)
                  t.lastAttemptAt.isSmallerThanValue(cutoffDate),
            ))
            .go();

    if (count > 0) {
      debugPrint('CleanupService: Cleaned $count old synced items');
    }
    return count;
  }

  /// Clear files in temp directory older than 7 days
  Future<int> _clearTempFiles() async {
    int count = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(days: 7));

      if (await tempDir.exists()) {
        await for (var entity in tempDir.list(recursive: false)) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoff)) {
              try {
                await entity.delete();
                count++;
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CleanupService: Error clearing temp files: $e');
    }
    return count;
  }
}
