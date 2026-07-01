// ============================================================================
// FRAUD ALERT REPOSITORY
// ============================================================================
// Persistence layer for fraud alerts with local and cloud sync.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../security/services/fraud_detection_service.dart';
import 'audit_repository.dart';

/// Fraud Alert Repository - Persistence for fraud detection alerts.
///
/// Features:
/// - Save alerts to local database and Firestore
/// - Query pending/acknowledged alerts
/// - Alert acknowledgement with audit trail
class FraudAlertRepository {
  final AppDatabase _database;
  final FirebaseFirestore _firestore;
  final AuditRepository _auditRepository;

  FraudAlertRepository({
    required AppDatabase database,
    FirebaseFirestore? firestore,
    required AuditRepository auditRepository,
  }) : _database = database,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auditRepository = auditRepository;

  /// Save a fraud alert
  Future<void> saveAlert(FraudAlert alert) async {
    // Save to local database
    await _database
        .into(_database.fraudAlerts)
        .insert(
          FraudAlertsCompanion.insert(
            id: alert.id,
            businessId: alert.businessId,
            alertType: alert.type.name,
            severity: alert.severity.name,
            userId: alert.userId,
            description: alert.description,
            referenceId: drift.Value(alert.referenceId),
            metadataJson: drift.Value(alert.metadata?.toString()),
            createdAt: alert.createdAt,
          ),
          mode: drift.InsertMode.insertOrReplace,
        );

    // Sync to Firestore
    try {
      await _firestore.collection('fraud_alerts').doc(alert.id).set({
        'businessId': alert.businessId,
        'alertType': alert.type.name,
        'severity': alert.severity.name,
        'userId': alert.userId,
        'description': alert.description,
        'referenceId': alert.referenceId,
        'metadata': alert.metadata,
        'isAcknowledged': alert.isAcknowledged,
        'createdAt': Timestamp.fromDate(alert.createdAt),
      });
    } catch (e) {
      debugPrint('FraudAlertRepository: Failed to sync alert: $e');
    }
  }

  /// Get pending (unacknowledged) alerts for a business
  Future<List<FraudAlert>> getPendingAlerts(String businessId) async {
    final rows =
        await (_database.select(_database.fraudAlerts)
              ..where((t) => t.businessId.equals(businessId))
              ..where((t) => t.isAcknowledged.equals(false))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();

    return rows.map(_entityToAlert).toList();
  }

  /// Get all alerts for a business
  Future<List<FraudAlert>> getAllAlerts(
    String businessId, {
    int limit = 100,
  }) async {
    final rows =
        await (_database.select(_database.fraudAlerts)
              ..where((t) => t.businessId.equals(businessId))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
              ..limit(limit))
            .get();

    return rows.map(_entityToAlert).toList();
  }

  /// Get alerts by type
  Future<List<FraudAlert>> getAlertsByType(
    String businessId,
    FraudAlertType type,
  ) async {
    final rows =
        await (_database.select(_database.fraudAlerts)
              ..where((t) => t.businessId.equals(businessId))
              ..where((t) => t.alertType.equals(type.name))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();

    return rows.map(_entityToAlert).toList();
  }

  /// Acknowledge an alert
  Future<void> acknowledgeAlert({
    required String alertId,
    required String acknowledgedBy,
    String? notes,
  }) async {
    final now = DateTime.now();

    // Update local database
    await (_database.update(
      _database.fraudAlerts,
    )..where((t) => t.id.equals(alertId))).write(
      FraudAlertsCompanion(
        isAcknowledged: const drift.Value(true),
        acknowledgedBy: drift.Value(acknowledgedBy),
        acknowledgedAt: drift.Value(now),
      ),
    );

    // Sync to Firestore
    try {
      await _firestore.collection('fraud_alerts').doc(alertId).update({
        'isAcknowledged': true,
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedAt': Timestamp.fromDate(now),
        'notes': notes,
      });
    } catch (e) {
      debugPrint('FraudAlertRepository: Failed to sync acknowledgement: $e');
    }

    // Audit log
    await _auditRepository.logAction(
      userId: acknowledgedBy,
      targetTableName: 'fraud_alerts',
      recordId: alertId,
      action: 'ACKNOWLEDGE',
      newValueJson: '{"acknowledgedBy": "$acknowledgedBy", "notes": "$notes"}',
    );
  }

  /// Get alert count by severity
  Future<Map<FraudSeverity, int>> getAlertCounts(String businessId) async {
    final rows =
        await (_database.select(_database.fraudAlerts)
              ..where((t) => t.businessId.equals(businessId))
              ..where((t) => t.isAcknowledged.equals(false)))
            .get();

    final counts = <FraudSeverity, int>{};
    for (final severity in FraudSeverity.values) {
      counts[severity] = 0;
    }

    for (final row in rows) {
      final severity = FraudSeverity.values.firstWhere(
        (s) => s.name == row.severity,
        orElse: () => FraudSeverity.low,
      );
      counts[severity] = (counts[severity] ?? 0) + 1;
    }

    return counts;
  }

  /// Watch pending alerts stream
  Stream<List<FraudAlert>> watchPendingAlerts(String businessId) {
    return (_database.select(_database.fraudAlerts)
          ..where((t) => t.businessId.equals(businessId))
          ..where((t) => t.isAcknowledged.equals(false))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_entityToAlert).toList());
  }

  /// Delete old acknowledged alerts (cleanup)
  Future<int> cleanupOldAlerts({
    required String businessId,
    required int daysToKeep,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));

    final deleted =
        await (_database.delete(_database.fraudAlerts)
              ..where((t) => t.businessId.equals(businessId))
              ..where((t) => t.isAcknowledged.equals(true))
              ..where((t) => t.acknowledgedAt.isSmallerThanValue(cutoff)))
            .go();

    debugPrint('FraudAlertRepository: Cleaned up $deleted old alerts');
    return deleted;
  }

  FraudAlert _entityToAlert(FraudAlertEntity entity) {
    return FraudAlert(
      id: entity.id,
      businessId: entity.businessId,
      type: FraudAlertType.values.firstWhere(
        (t) => t.name == entity.alertType,
        orElse: () => FraudAlertType.highDiscount,
      ),
      severity: FraudSeverity.values.firstWhere(
        (s) => s.name == entity.severity,
        orElse: () => FraudSeverity.low,
      ),
      userId: entity.userId,
      description: entity.description,
      referenceId: entity.referenceId,
      isAcknowledged: entity.isAcknowledged,
      acknowledgedBy: entity.acknowledgedBy,
      createdAt: entity.createdAt,
      acknowledgedAt: entity.acknowledgedAt,
    );
  }
}
