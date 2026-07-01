// ============================================================================
// STOCK SECURITY SERVICE
// ============================================================================
// Security layer for stock operations with PIN and audit integration.
//
// T-SEC-3 producer site (Phase 2 §11.10): when `logStockAdjustment` detects
// a large quantity change it raises a `system.security_stock.anomaly_detected`
// event onto the UNS via the Shared_SDK in addition to the existing audit
// row write. The audit row stays — it is the local cache; UNS is the
// canonical notification path.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import '../repository/audit_repository.dart';
import '../security/services/owner_pin_service.dart';

/// Stock Adjustment Reason - Required for all manual stock changes.
enum StockAdjustmentReason {
  /// Stock arrived from supplier
  purchaseReceived,

  /// Stock sold to customer
  saleMade,

  /// Customer returned item
  customerReturn,

  /// Item returned to supplier
  supplierReturn,

  /// Damaged/expired items
  damageOrExpiry,

  /// Stolen or missing items
  theft,

  /// Physical count correction
  physicalCountCorrection,

  /// Opening balance for new item
  openingBalance,

  /// Transfer between locations
  transfer,

  /// Sample/demo given
  sampleGiven,

  /// Other (requires notes)
  other,
}

extension StockAdjustmentReasonX on StockAdjustmentReason {
  String get displayName {
    switch (this) {
      case StockAdjustmentReason.purchaseReceived:
        return 'Purchase Received';
      case StockAdjustmentReason.saleMade:
        return 'Sale Made';
      case StockAdjustmentReason.customerReturn:
        return 'Customer Return';
      case StockAdjustmentReason.supplierReturn:
        return 'Supplier Return';
      case StockAdjustmentReason.damageOrExpiry:
        return 'Damage/Expiry';
      case StockAdjustmentReason.theft:
        return 'Theft/Missing';
      case StockAdjustmentReason.physicalCountCorrection:
        return 'Physical Count';
      case StockAdjustmentReason.openingBalance:
        return 'Opening Balance';
      case StockAdjustmentReason.transfer:
        return 'Transfer';
      case StockAdjustmentReason.sampleGiven:
        return 'Sample Given';
      case StockAdjustmentReason.other:
        return 'Other';
    }
  }

  /// Whether this reason requires additional notes
  bool get requiresNotes {
    switch (this) {
      case StockAdjustmentReason.other:
      case StockAdjustmentReason.theft:
      case StockAdjustmentReason.physicalCountCorrection:
        return true;
      default:
        return false;
    }
  }

  /// Whether this reason requires PIN verification
  bool get requiresPin {
    switch (this) {
      case StockAdjustmentReason.theft:
      case StockAdjustmentReason.physicalCountCorrection:
      case StockAdjustmentReason.other:
      case StockAdjustmentReason.damageOrExpiry:
        return true;
      default:
        return false;
    }
  }
}

/// Stock Adjustment Request
class StockAdjustmentRequest {
  final String productId;
  final String productName;
  final double oldQuantity;
  final double newQuantity;
  final StockAdjustmentReason reason;
  final String? referenceId; // billId, purchaseId, etc.
  final String? notes;
  final String adjustedBy;
  final DateTime timestamp;

  StockAdjustmentRequest({
    required this.productId,
    required this.productName,
    required this.oldQuantity,
    required this.newQuantity,
    required this.reason,
    this.referenceId,
    this.notes,
    required this.adjustedBy,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get quantityChange => newQuantity - oldQuantity;
  bool get isIncrease => quantityChange > 0;
  bool get isDecrease => quantityChange < 0;

  Map<String, dynamic> toAuditJson() => {
    'productId': productId,
    'productName': productName,
    'oldQuantity': oldQuantity,
    'newQuantity': newQuantity,
    'quantityChange': quantityChange,
    'reason': reason.name,
    'referenceId': referenceId,
    'notes': notes,
    'adjustedBy': adjustedBy,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Stock Security Service - PIN and audit integration for stock operations.
class StockSecurityService {
  final OwnerPinService _pinService;
  final AuditRepository _auditRepository;
  final uns.NotificationsSdk? _sdk;

  /// Path-style identifier recorded in the EventContract.source_module
  /// field. Matches the Phase 2 §11.10 entry for T-SEC-3.
  static const String _sourceModule =
      'Dukan_x/lib/core/services/stock_security_service.dart';

  StockSecurityService({
    required OwnerPinService pinService,
    required AuditRepository auditRepository,
    uns.NotificationsSdk? notificationsSdk,
  }) : _pinService = pinService,
       _auditRepository = auditRepository,
       _sdk = notificationsSdk;

  /// Validate stock adjustment request
  Future<StockAdjustmentValidation> validateAdjustment({
    required String businessId,
    required StockAdjustmentRequest request,
    String? pin,
  }) async {
    // Check if reason requires notes
    if (request.reason.requiresNotes &&
        (request.notes == null || request.notes!.trim().isEmpty)) {
      return StockAdjustmentValidation.denied(
        'Reason "${request.reason.displayName}" requires notes',
      );
    }

    // Check if reason requires PIN
    if (request.reason.requiresPin) {
      if (pin == null || pin.isEmpty) {
        return StockAdjustmentValidation.pinRequired(
          'PIN required for ${request.reason.displayName}',
        );
      }

      // Verify PIN
      try {
        final isValid = await _pinService.verifyPin(
          businessId: businessId,
          pin: pin,
        );
        if (!isValid) {
          return StockAdjustmentValidation.denied('Invalid PIN');
        }
      } catch (e) {
        return StockAdjustmentValidation.denied('$e');
      }
    }

    return StockAdjustmentValidation.allowed();
  }

  /// Log stock adjustment with full context
  Future<void> logStockAdjustment({
    required String businessId,
    required StockAdjustmentRequest request,
    bool pinVerified = false,
  }) async {
    // Audit log
    await _auditRepository.logAction(
      userId: request.adjustedBy,
      targetTableName: 'stock_movements',
      recordId: request.productId,
      action: request.isIncrease ? 'INCREASE' : 'DECREASE',
      oldValueJson: '{"quantity": ${request.oldQuantity}}',
      newValueJson: '${request.toAuditJson()}',
    );

    // Check for suspicious patterns - large quantity changes
    final double changePercent = request.oldQuantity > 0
        ? (request.quantityChange.abs() / request.oldQuantity) * 100
        : 100.0;

    if (changePercent > 50) {
      // Local audit-cache row — kept post-migration for in-process fraud
      // review screens that read directly from the audit log.
      await _auditRepository.logAction(
        userId: request.adjustedBy,
        targetTableName: 'fraud_alerts',
        recordId: request.productId,
        action: 'STOCK_MISMATCH_ALERT',
        newValueJson:
            '''{
          "severity": "${changePercent > 90 ? 'CRITICAL' : 'HIGH'}",
          "description": "Large stock adjustment (${changePercent.toStringAsFixed(0)}%): ${request.productName}",
          "oldQuantity": ${request.oldQuantity},
          "newQuantity": ${request.newQuantity},
          "reason": "${request.reason.name}"
        }''',
      );

      // UNS emission — Phase 2 §11.10 / T-SEC-3.
      // Replaces the legacy in-process flow where the bell widget would
      // surface this only by polling the audit table. Recipient resolution
      // (admin) is owned by the backend per the Notification_Event_Registry.
      await _emitStockAnomalyEvent(
        businessId: businessId,
        request: request,
        changePercent: changePercent,
      );
    }

    debugPrint(
      'StockSecurityService: Logged adjustment for ${request.productId}: '
      '${request.oldQuantity} -> ${request.newQuantity} (${request.reason.displayName})',
    );
  }

  /// Publish `system.security_stock.anomaly_detected` to the UNS.
  ///
  /// Pinned by Phase 2 §11.10:
  ///   - priority = high
  ///   - channels = in_app, push, email
  ///   - dedup = (event_name, anomaly_id) within 3600 s
  ///
  /// Recipients are resolved server-side from the registry consumer_roles
  /// (admin only) — we leave the array empty per the schema contract.
  Future<void> _emitStockAnomalyEvent({
    required String businessId,
    required StockAdjustmentRequest request,
    required double changePercent,
  }) async {
    final sdk = _sdk;
    if (sdk == null) {
      // Pre-init / unit-test path — audit-cache row already written above.
      return;
    }

    // Anomaly id ties the dedup window to the producing adjustment.
    // referenceId comes from the adjustment's source document (bill /
    // purchase) when present; falls back to product+timestamp so two
    // separate adjustments do not collide.
    final anomalyId =
        request.referenceId ??
        '${request.productId}:${request.timestamp.toUtc().toIso8601String()}';

    final severity = changePercent > 90 ? 'critical' : 'high';

    final payload = <String, dynamic>{
      'anomaly_id': anomalyId,
      'business_id': businessId,
      'product_id': request.productId,
      'product_name': request.productName,
      'old_quantity': request.oldQuantity,
      'new_quantity': request.newQuantity,
      'quantity_change': request.quantityChange,
      'change_percent': changePercent,
      'severity': severity,
      'reason': request.reason.name,
      if (request.referenceId != null) 'reference_id': request.referenceId,
      if (request.notes != null) 'notes': request.notes,
      'detected_at': request.timestamp.toUtc().toIso8601String(),
    };

    try {
      final event = sdk.buildEvent(
        eventName: 'system.security_stock.anomaly_detected',
        category: uns.EventCategory.system,
        subCategory: 'stock_anomaly',
        priority: uns.EventPriority.high,
        actorId: request.adjustedBy,
        targetId: request.productId,
        recipients: const <uns.Recipient>[],
        payload: payload,
        channels: const <uns.NotificationChannel>[
          uns.NotificationChannel.inApp,
          uns.NotificationChannel.push,
          uns.NotificationChannel.email,
        ],
        sourceModule: _sourceModule,
        sourceApp: uns.SourceApp.dukanxDesktop,
        dedupKey: 'system.security_stock.anomaly_detected:$anomalyId',
        dedupScopeFields: const <String>['anomaly_id'],
      );
      await sdk.emit(event);
    } catch (e) {
      // Schema / auth errors propagate up from the SDK; we swallow them
      // here so a single bad emission does not corrupt the stock-write
      // path. The audit-cache row above is the local fallback record.
      debugPrint('StockSecurityService: emit anomaly failed: $e');
    }
  }
}

/// Stock adjustment validation result
class StockAdjustmentValidation {
  final bool isAllowed;
  final bool requiresPin;
  final String? error;

  StockAdjustmentValidation._({
    required this.isAllowed,
    this.requiresPin = false,
    this.error,
  });

  factory StockAdjustmentValidation.allowed() {
    return StockAdjustmentValidation._(isAllowed: true);
  }

  factory StockAdjustmentValidation.denied(String error) {
    return StockAdjustmentValidation._(isAllowed: false, error: error);
  }

  factory StockAdjustmentValidation.pinRequired(String message) {
    return StockAdjustmentValidation._(
      isAllowed: false,
      requiresPin: true,
      error: message,
    );
  }
}
