// ============================================================================
// AUDIT REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages local audit logs with Drift persistence
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../error/error_handler.dart';
import 'package:flutter/foundation.dart';

import '../security/hash_service.dart';

/// Audit Repository
class AuditRepository {
  final AppDatabase database;
  final ErrorHandler errorHandler;
  final HashService _hashService = HashService();

  AuditRepository({required this.database, required this.errorHandler});

  String get collectionName => 'auditLogs';

  // ============================================
  // LOGGING OPERATIONS (APPEND-ONLY)
  // ============================================

  /// Log an action (Append Only)
  Future<RepositoryResult<void>> logAction({
    required String userId,
    required String targetTableName,
    required String recordId,
    required String action, // CREATE, UPDATE, DELETE
    String? oldValueJson,
    String? newValueJson,
    String? deviceId,
    String? appVersion,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      await database.transaction(() async {
        await _insertLogWithHash(
          userId,
          targetTableName,
          recordId,
          action,
          oldValueJson,
          newValueJson,
          deviceId,
          appVersion,
        );
      });
    }, 'logAction');
  }

  // Helper for safe insertion with consistent timestamp
  Future<void> _insertLogWithHash(
    String userId,
    String targetTableName,
    String recordId,
    String action,
    String? oldValueJson,
    String? newValueJson,
    String? deviceId,
    String? appVersion,
  ) async {
    final now = DateTime.now().toUtc();
    final normalizedTime = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    final lastLog =
        await (database.select(database.auditLogs)
              ..where((t) => t.userId.equals(userId))
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();

    final previousHash =
        lastLog?.currentHash ?? '00000000000000000000000000000000';

    final logData = {
      'userId': userId,
      'targetTableName': targetTableName,
      'recordId': recordId,
      'action': action,
      'oldValueJson': oldValueJson,
      'newValueJson': newValueJson,
      'deviceId': deviceId,
      'appVersion': appVersion,
      'timestamp': normalizedTime.toIso8601String(), // Validatable timestamp
    };

    final currentHash = _hashService.computeChainHash(previousHash, logData);

    await database
        .into(database.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            userId: userId,
            targetTableName: targetTableName,
            recordId: recordId,
            action: action,
            oldValueJson: Value(oldValueJson),
            newValueJson: Value(newValueJson),
            deviceId: Value(deviceId),
            appVersion: Value(appVersion),
            previousHash: Value(previousHash),
            currentHash: Value(currentHash),
            timestamp: normalizedTime,
          ),
        );
  }

  // ============================================
  // READING OPERATIONS
  // ============================================

  /// Get audit logs for a specific record
  Future<RepositoryResult<List<AuditLogEntity>>> getLogsForRecord({
    required String tableName,
    required String recordId,
    int limit = 50,
  }) async {
    return await errorHandler.runSafe<List<AuditLogEntity>>(() async {
      final results =
          await (database.select(database.auditLogs)
                ..where(
                  (t) =>
                      t.targetTableName.equals(tableName) &
                      t.recordId.equals(recordId),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.timestamp), (t) => OrderingTerm.desc(t.id)])
                ..limit(limit))
              .get();
      return results;
    }, 'getLogsForRecord');
  }

  /// Get audit logs for a user (recent activity)
  Future<RepositoryResult<List<AuditLogEntity>>> getLogsForUser({
    required String userId,
    int limit = 100,
  }) async {
    return await errorHandler.runSafe<List<AuditLogEntity>>(() async {
      final results =
          await (database.select(database.auditLogs)
                ..where((t) => t.userId.equals(userId))
                ..orderBy([(t) => OrderingTerm.desc(t.timestamp), (t) => OrderingTerm.desc(t.id)])
                ..limit(limit))
              .get();
      return results;
    }, 'getLogsForUser');
  }

  /// Get logs by date range (for Compliance Reports)
  Future<RepositoryResult<List<AuditLogEntity>>> getLogsByDateRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    return await errorHandler.runSafe<List<AuditLogEntity>>(() async {
      final results =
          await (database.select(database.auditLogs)
                ..where(
                  (t) =>
                      t.userId.equals(userId) &
                      t.timestamp.isBiggerOrEqualValue(from) &
                      t.timestamp.isSmallerOrEqualValue(to),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.timestamp), (t) => OrderingTerm.desc(t.id)]))
              .get();
      return results;
    }, 'getLogsByDateRange');
  }

  /// Verify Audit Hash Chain Integrity
  /// Returns TRUE if valid, FALSE if tampering detected.
  Future<RepositoryResult<bool>> verifyChain(String userId) async {
    return await errorHandler.runSafe<bool>(() async {
      // Fetch all logs for user, ordered by ID ASC (Chronological)
      final logs =
          await (database.select(database.auditLogs)
                ..where((t) => t.userId.equals(userId))
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get();

      if (logs.isEmpty) return true;

      String expectedPrevHash = '00000000000000000000000000000000';

      for (final log in logs) {
        // 1. Check Linkage
        if (log.previousHash != expectedPrevHash) {
          debugPrint(
            'AUDIT TAMPER: Broken Link at ID ${log.id}. Exp: $expectedPrevHash, Found: ${log.previousHash}',
          );
          return false;
        }

        // 2. Re-compute Hash
        final logData = {
          'userId': log.userId,
          'targetTableName': log.targetTableName,
          'recordId': log.recordId,
          'action': log.action,
          'oldValueJson': log.oldValueJson,
          'newValueJson': log.newValueJson,
          'deviceId': log.deviceId,
          'appVersion': log.appVersion,
          'timestamp': log.timestamp.toUtc().toIso8601String(),
        };

        final computedHash = _hashService.computeChainHash(
          expectedPrevHash,
          logData,
        );

        if (computedHash != log.currentHash) {
          debugPrint('AUDIT TAMPER: Hash Mismatch at ID ${log.id}.');
          return false;
        }

        // Advance
        expectedPrevHash = log.currentHash!;
      }

      return true;
    }, 'verifyChain');
  }

  // ============================================================
  // SAFETY PATCH: Tamper-Proof Audit Log Export (Control 4)
  // ============================================================
  // Exports audit logs with row hashes and chain verification
  // for CA/GST audit compliance.
  // ============================================================

  /// Export audit logs with full hash verification
  /// Returns JSON that can be saved as a verifiable audit file
  Future<RepositoryResult<AuditExportReport>> exportLogsWithVerification({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await errorHandler.runSafe<AuditExportReport>(() async {
      // 1. Fetch logs
      final query = database.select(database.auditLogs)
        ..where((t) => t.userId.equals(userId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]);

      if (fromDate != null) {
        query.where((t) => t.timestamp.isBiggerOrEqualValue(fromDate));
      }
      if (toDate != null) {
        query.where((t) => t.timestamp.isSmallerOrEqualValue(toDate));
      }

      final logs = await query.get();

      // 2. Verify chain integrity
      final chainResult = await verifyChain(userId);
      final isChainValid = chainResult.data ?? false;

      // 3. Build export entries
      final entries = <AuditExportEntry>[];
      for (final log in logs) {
        entries.add(
          AuditExportEntry(
            id: log.id,
            userId: log.userId,
            targetTable: log.targetTableName,
            recordId: log.recordId,
            action: log.action,
            oldValue: log.oldValueJson,
            newValue: log.newValueJson,
            deviceId: log.deviceId,
            appVersion: log.appVersion,
            timestamp: log.timestamp,
            previousHash: log.previousHash,
            currentHash: log.currentHash,
          ),
        );
      }

      // 4. Compute summary hash of entire export
      final summaryData = entries.map((e) => e.currentHash ?? '').join('');
      final summaryHash = _hashService.computeHash(summaryData);

      return AuditExportReport(
        userId: userId,
        exportedAt: DateTime.now(),
        fromDate: fromDate,
        toDate: toDate,
        totalEntries: entries.length,
        chainValid: isChainValid,
        summaryHash: summaryHash,
        entries: entries,
      );
    }, 'exportLogsWithVerification');
  }

  /// Export audit logs as CSV format
  Future<RepositoryResult<String>> exportLogsAsCsv({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      final exportResult = await exportLogsWithVerification(
        userId: userId,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (!exportResult.isSuccess || exportResult.data == null) {
        throw Exception('Failed to export logs');
      }

      final report = exportResult.data!;
      final buffer = StringBuffer();

      // Header
      buffer.writeln(
        'ID,Timestamp,Table,RecordID,Action,DeviceID,AppVersion,PreviousHash,CurrentHash',
      );

      // Rows
      for (final entry in report.entries) {
        buffer.writeln(
          '${entry.id},'
          '${entry.timestamp.toIso8601String()},'
          '${entry.targetTable},'
          '${entry.recordId},'
          '${entry.action},'
          '${entry.deviceId ?? ""},'
          '${entry.appVersion ?? ""},'
          '${entry.previousHash ?? ""},'
          '${entry.currentHash ?? ""}',
        );
      }

      // Footer with verification
      buffer.writeln('');
      buffer.writeln('# Verification Summary');
      buffer.writeln('# Exported At: ${report.exportedAt.toIso8601String()}');
      buffer.writeln('# Total Entries: ${report.totalEntries}');
      buffer.writeln('# Chain Valid: ${report.chainValid}');
      buffer.writeln('# Summary Hash: ${report.summaryHash}');

      return buffer.toString();
    }, 'exportLogsAsCsv');
  }
}

// ============================================================
// EXPORT RESULT CLASSES
// ============================================================

/// Complete audit export report with verification
class AuditExportReport {
  final String userId;
  final DateTime exportedAt;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int totalEntries;
  final bool chainValid;
  final String summaryHash;
  final List<AuditExportEntry> entries;

  AuditExportReport({
    required this.userId,
    required this.exportedAt,
    this.fromDate,
    this.toDate,
    required this.totalEntries,
    required this.chainValid,
    required this.summaryHash,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'exportedAt': exportedAt.toIso8601String(),
    if (fromDate != null) 'fromDate': fromDate!.toIso8601String(),
    if (toDate != null) 'toDate': toDate!.toIso8601String(),
    'totalEntries': totalEntries,
    'chainValid': chainValid,
    'summaryHash': summaryHash,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}

/// Individual audit log entry for export
class AuditExportEntry {
  final int id;
  final String userId;
  final String targetTable;
  final String recordId;
  final String action;
  final String? oldValue;
  final String? newValue;
  final String? deviceId;
  final String? appVersion;
  final DateTime timestamp;
  final String? previousHash;
  final String? currentHash;

  AuditExportEntry({
    required this.id,
    required this.userId,
    required this.targetTable,
    required this.recordId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.deviceId,
    this.appVersion,
    required this.timestamp,
    this.previousHash,
    this.currentHash,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'targetTable': targetTable,
    'recordId': recordId,
    'action': action,
    if (oldValue != null) 'oldValue': oldValue,
    if (newValue != null) 'newValue': newValue,
    if (deviceId != null) 'deviceId': deviceId,
    if (appVersion != null) 'appVersion': appVersion,
    'timestamp': timestamp.toIso8601String(),
    'previousHash': previousHash,
    'currentHash': currentHash,
  };
}
