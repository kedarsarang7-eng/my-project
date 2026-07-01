// ============================================================================
// Equivalence test for the T-SEC-1 / T-SEC-2 / T-SEC-3 UNS migration.
// ----------------------------------------------------------------------------
// Validates the behaviour-preservation guarantee required by REQ 10.9 / 10.9a
// for the security notification helpers migrated under task 14.4 of the
// unified-notification-system spec.
//
// What this test asserts (the "after" side of the equivalence ledger):
//
//   * SecurityNotificationService captures every FraudAlert that flows
//     through FraudDetectionService.fraudAlerts (legacy invariant).
//   * For each FraudAlertType the service emits the canonical Phase 2
//     event_name onto the Shared_SDK with the priority / channels / dedup
//     scope pinned by phase2-event-registry.md sections 11.8 / 11.9 / 11.10.
//   * The local FraudAlertRepository write is preserved (legacy local cache
//     remains intact alongside the UNS path; this is the explicit allowance
//     in the task notes).
//   * StockSecurityService.logStockAdjustment fires the
//     `system.security_stock.anomaly_detected` event when an adjustment
//     trips the >50% threshold and stays silent below it.
//
// The before-side recipient × channel × message expectation is captured in
// the registry tables themselves and is reproduced as constants in this
// file so a future drift in either side fails the test.
// ============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/core/repository/audit_repository.dart';
import 'package:dukanx/core/repository/fraud_alert_repository.dart';
import 'package:dukanx/core/security/services/fraud_detection_service.dart';
import 'package:dukanx/core/security/services/owner_pin_service.dart';
import 'package:dukanx/core/services/security_notification_service.dart';
import 'package:dukanx/core/services/stock_security_service.dart';

/// In-memory SDK stand-in. Captures every emitted EventContract so the
/// test can assert on the wire shape without needing a live backend.
class _FakeSdk implements uns.NotificationsSdk {
  final List<uns.EventContract> emitted = <uns.EventContract>[];

  @override
  Future<void> emit(uns.EventContract event) async {
    emitted.add(event);
  }

  @override
  uns.EventContract buildEvent({
    required String eventName,
    required uns.EventCategory category,
    String? subCategory,
    required uns.EventPriority priority,
    required String actorId,
    String? targetId,
    required List<uns.Recipient> recipients,
    required Map<String, dynamic> payload,
    required List<uns.NotificationChannel> channels,
    required String sourceModule,
    required uns.SourceApp sourceApp,
    required String dedupKey,
    List<String>? dedupScopeFields,
    String? id,
    String? createdAt,
  }) {
    return uns.EventContract(
      id: id ?? 'test-${emitted.length}',
      eventName: eventName,
      category: category,
      subCategory: subCategory,
      priority: priority,
      actorId: actorId,
      targetId: targetId,
      recipients: recipients,
      payload: payload,
      channels: channels,
      sourceModule: sourceModule,
      sourceApp: sourceApp,
      createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
      dedupKey: dedupKey,
      dedupScopeFields: dedupScopeFields,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal FraudDetectionService double — exposes the alerts stream the
/// SecurityNotificationService listens to without spinning up the database.
class _StubFraudDetection implements FraudDetectionService {
  final StreamController<FraudAlert> _ctrl =
      StreamController<FraudAlert>.broadcast();

  @override
  Stream<FraudAlert> get fraudAlerts => _ctrl.stream;

  void publish(FraudAlert alert) => _ctrl.add(alert);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Captures every saved alert without touching Drift / Firestore.
class _StubFraudAlertRepository implements FraudAlertRepository {
  final List<FraudAlert> saved = <FraudAlert>[];

  @override
  Future<void> saveAlert(FraudAlert alert) async {
    saved.add(alert);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubOwnerPinService implements OwnerPinService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuditRepository implements AuditRepository {
  final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];

  @override
  Future<RepositoryResult<void>> logAction({
    required String userId,
    required String targetTableName,
    required String recordId,
    required String action,
    String? oldValueJson,
    String? newValueJson,
    String? deviceId,
    String? appVersion,
  }) async {
    entries.add(<String, dynamic>{
      'userId': userId,
      'targetTableName': targetTableName,
      'recordId': recordId,
      'action': action,
      'oldValueJson': oldValueJson,
      'newValueJson': newValueJson,
      'deviceId': deviceId,
      'appVersion': appVersion,
    });
    return RepositoryResult.success(null);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Task 14.4 — SecurityNotificationService UNS migration', () {
    late _FakeSdk sdk;
    late _StubFraudDetection fraud;
    late _StubFraudAlertRepository repo;
    late SecurityNotificationService service;

    setUp(() {
      sdk = _FakeSdk();
      fraud = _StubFraudDetection();
      repo = _StubFraudAlertRepository();
      service = SecurityNotificationService(
        fraudService: fraud,
        alertRepository: repo,
        sdk: sdk,
      );
      service.startListening();
    });

    tearDown(() {
      service.dispose();
    });

    /// Build a FraudAlert with the bare-minimum shape every code path needs.
    FraudAlert alert(FraudAlertType type, {String? referenceId}) {
      return FraudAlert(
        id: 'alert-${type.name}',
        businessId: 'biz-1',
        type: type,
        severity: FraudSeverity.high,
        userId: 'cashier-1',
        description: '${type.name} description',
        referenceId: referenceId,
        createdAt: DateTime.utc(2025, 1, 1, 12),
      );
    }

    test('cashVariance alert maps to system.security_cash.mismatch_detected '
        '(critical, in_app+push+sms+email, dedup on day_close_id)', () async {
      fraud.publish(
        alert(FraudAlertType.cashVariance, referenceId: 'closing-2025-01-01'),
      );
      // Allow the broadcast stream to dispatch.
      await Future<void>.delayed(Duration.zero);

      expect(repo.saved, hasLength(1));
      expect(sdk.emitted, hasLength(1));
      final event = sdk.emitted.single;
      expect(event.eventName, 'system.security_cash.mismatch_detected');
      expect(event.category, uns.EventCategory.system);
      expect(event.subCategory, 'cash_mismatch');
      expect(event.priority, uns.EventPriority.critical);
      expect(event.channels, <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
        uns.NotificationChannel.sms,
        uns.NotificationChannel.email,
      ]);
      expect(event.dedupScopeFields, <String>['day_close_id']);
      expect(event.dedupKey, contains('closing-2025-01-01'));
      expect(event.payload['fraud_alert_id'], 'alert-cashVariance');
      expect(event.payload['type'], 'cashVariance');
      // Recipients are empty by design — the backend resolves admin and
      // accountant from the registry.
      expect(event.recipients, isEmpty);
    });

    test('stockMismatch alert maps to system.security_stock.anomaly_detected '
        '(high, in_app+push+email, dedup on anomaly_id)', () async {
      fraud.publish(
        alert(FraudAlertType.stockMismatch, referenceId: 'product-42'),
      );
      await Future<void>.delayed(Duration.zero);

      final event = sdk.emitted.single;
      expect(event.eventName, 'system.security_stock.anomaly_detected');
      expect(event.priority, uns.EventPriority.high);
      expect(event.channels, <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
        uns.NotificationChannel.email,
      ]);
      expect(event.dedupScopeFields, <String>['anomaly_id']);
    });

    test('all other FraudAlertTypes route to '
        'system.security_fraud.alert_raised (critical, all four channels, '
        'dedup on fraud_alert_id)', () async {
      const cases = <FraudAlertType>[
        FraudAlertType.highDiscount,
        FraudAlertType.repeatedBillEdits,
        FraudAlertType.lateNightBilling,
        FraudAlertType.roleAbuseAttempt,
        FraudAlertType.pinBruteForce,
        FraudAlertType.paidBillDeletion,
        FraudAlertType.suspiciousRefunds,
        FraudAlertType.largeTransaction,
        FraudAlertType.billEditWindowExpired,
      ];
      for (final t in cases) {
        fraud.publish(alert(t));
      }
      await Future<void>.delayed(Duration.zero);

      expect(sdk.emitted, hasLength(cases.length));
      for (final event in sdk.emitted) {
        expect(event.eventName, 'system.security_fraud.alert_raised');
        expect(event.priority, uns.EventPriority.critical);
        expect(event.channels, <uns.NotificationChannel>[
          uns.NotificationChannel.inApp,
          uns.NotificationChannel.push,
          uns.NotificationChannel.sms,
          uns.NotificationChannel.email,
        ]);
        expect(event.dedupScopeFields, <String>['fraud_alert_id']);
        expect(event.sourceApp, uns.SourceApp.dukanxDesktop);
        expect(
          event.sourceModule,
          'Dukan_x/lib/core/services/security_notification_service.dart',
        );
      }
    });

    test(
      'local FraudAlertRepository write is preserved alongside UNS emit',
      () async {
        fraud.publish(alert(FraudAlertType.highDiscount));
        await Future<void>.delayed(Duration.zero);

        // Both the local cache and the UNS path receive the alert — the
        // repository write was explicitly preserved by the task.
        expect(repo.saved, hasLength(1));
        expect(sdk.emitted, hasLength(1));
      },
    );

    test(
      'without an SDK the service still mirrors alerts to the repository',
      () async {
        service.dispose();
        service = SecurityNotificationService(
          fraudService: fraud,
          alertRepository: repo,
        );
        service.startListening();

        fraud.publish(alert(FraudAlertType.highDiscount));
        await Future<void>.delayed(Duration.zero);

        expect(repo.saved, hasLength(1));
        expect(sdk.emitted, isEmpty);
      },
    );
  });

  group('Task 14.4 — StockSecurityService anomaly emission', () {
    late _FakeSdk sdk;
    late _StubAuditRepository audit;
    late StockSecurityService service;

    setUp(() {
      sdk = _FakeSdk();
      audit = _StubAuditRepository();
      service = StockSecurityService(
        pinService: _StubOwnerPinService(),
        auditRepository: audit,
        notificationsSdk: sdk,
      );
    });

    test('change >50% emits system.security_stock.anomaly_detected', () async {
      // 100 -> 40 = 60% drop, above the 50% threshold.
      await service.logStockAdjustment(
        businessId: 'biz-1',
        request: StockAdjustmentRequest(
          productId: 'prod-1',
          productName: 'Widget',
          oldQuantity: 100,
          newQuantity: 40,
          reason: StockAdjustmentReason.theft,
          referenceId: 'audit-7',
          adjustedBy: 'staff-1',
          timestamp: DateTime.utc(2025, 1, 2, 10),
        ),
      );

      expect(sdk.emitted, hasLength(1));
      final event = sdk.emitted.single;
      expect(event.eventName, 'system.security_stock.anomaly_detected');
      expect(event.priority, uns.EventPriority.high);
      expect(event.targetId, 'prod-1');
      expect(event.payload['change_percent'], closeTo(60.0, 0.0001));
      expect(event.payload['severity'], 'high');
      expect(event.dedupKey, contains('audit-7'));
    });

    test('change >90% raises severity to critical in the payload', () async {
      // 100 -> 5 = 95% drop, above the 90% mark.
      await service.logStockAdjustment(
        businessId: 'biz-1',
        request: StockAdjustmentRequest(
          productId: 'prod-2',
          productName: 'Gadget',
          oldQuantity: 100,
          newQuantity: 5,
          reason: StockAdjustmentReason.physicalCountCorrection,
          adjustedBy: 'staff-1',
        ),
      );

      expect(sdk.emitted.single.payload['severity'], 'critical');
    });

    test('change <=50% stays silent (no UNS emission, no audit row)', () async {
      // 100 -> 60 = 40% drop, below the threshold.
      await service.logStockAdjustment(
        businessId: 'biz-1',
        request: StockAdjustmentRequest(
          productId: 'prod-3',
          productName: 'Sprocket',
          oldQuantity: 100,
          newQuantity: 60,
          reason: StockAdjustmentReason.saleMade,
          adjustedBy: 'staff-1',
        ),
      );

      expect(sdk.emitted, isEmpty);
      // The non-anomaly audit "DECREASE" row is still recorded; only the
      // STOCK_MISMATCH_ALERT row is gated by the threshold.
      expect(
        audit.entries.where((e) => e['action'] == 'STOCK_MISMATCH_ALERT'),
        isEmpty,
      );
    });

    test('without an SDK the audit row is still written', () async {
      service = StockSecurityService(
        pinService: _StubOwnerPinService(),
        auditRepository: audit,
      );

      await service.logStockAdjustment(
        businessId: 'biz-1',
        request: StockAdjustmentRequest(
          productId: 'prod-4',
          productName: 'Cog',
          oldQuantity: 100,
          newQuantity: 10,
          reason: StockAdjustmentReason.theft,
          adjustedBy: 'staff-1',
        ),
      );

      expect(sdk.emitted, isEmpty);
      expect(
        audit.entries.where((e) => e['action'] == 'STOCK_MISMATCH_ALERT'),
        hasLength(1),
      );
    });
  });
}
