// ============================================================================
// TIME LOCK SERVICE
// ============================================================================
// Enforces cooling periods for critical owner actions.
// Prevents panic fraud and quick insider theft.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:uuid/uuid.dart';

import '../device/trusted_device_service.dart';
import '../../repository/audit_repository.dart';

/// Time Lock Durations for critical actions
class TimeLockDurations {
  static const Duration periodUnlock = Duration(minutes: 60);
  static const Duration bulkDelete = Duration(minutes: 120);
  static const Duration stockAdjustmentLarge = Duration(minutes: 30);
  static const Duration roleChange = Duration(minutes: 60);
  static const Duration dataExport = Duration(minutes: 120);
  static const Duration deviceRemoval = Duration(minutes: 60);
}

/// Pending Action Status
enum PendingActionStatus {
  /// Waiting for cooling period
  pending,

  /// Ready for confirmation
  ready,

  /// Confirmed and executed
  confirmed,

  /// Expired without confirmation
  expired,

  /// Cancelled by user
  cancelled,
}

/// Pending Action - Time-locked action awaiting confirmation.
class PendingAction {
  final String id;
  final String businessId;
  final String requestedBy;
  final String requestDeviceId;
  final String actionType;
  final Map<String, dynamic> actionDetails;
  final DateTime requestedAt;
  final DateTime readyAt;
  final DateTime expiresAt;
  final PendingActionStatus status;
  final String? confirmedBy;
  final String? confirmDeviceId;
  final DateTime? confirmedAt;

  const PendingAction({
    required this.id,
    required this.businessId,
    required this.requestedBy,
    required this.requestDeviceId,
    required this.actionType,
    required this.actionDetails,
    required this.requestedAt,
    required this.readyAt,
    required this.expiresAt,
    this.status = PendingActionStatus.pending,
    this.confirmedBy,
    this.confirmDeviceId,
    this.confirmedAt,
  });

  /// Check if action is pending cooling period
  bool get isPending =>
      status == PendingActionStatus.pending && DateTime.now().isBefore(readyAt);

  /// Check if action is ready for confirmation
  bool get isReady =>
      status == PendingActionStatus.pending &&
      DateTime.now().isAfter(readyAt) &&
      DateTime.now().isBefore(expiresAt);

  /// Check if action has expired
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) ||
      status == PendingActionStatus.expired;

  /// Time remaining until ready
  Duration get timeUntilReady {
    if (isReady || isExpired) return Duration.zero;
    return readyAt.difference(DateTime.now());
  }

  /// Time remaining until expiry
  Duration get timeUntilExpiry {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }

  PendingAction copyWith({
    PendingActionStatus? status,
    String? confirmedBy,
    String? confirmDeviceId,
    DateTime? confirmedAt,
  }) {
    return PendingAction(
      id: id,
      businessId: businessId,
      requestedBy: requestedBy,
      requestDeviceId: requestDeviceId,
      actionType: actionType,
      actionDetails: actionDetails,
      requestedAt: requestedAt,
      readyAt: readyAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmDeviceId: confirmDeviceId ?? this.confirmDeviceId,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'businessId': businessId,
    'requestedBy': requestedBy,
    'requestDeviceId': requestDeviceId,
    'actionType': actionType,
    'actionDetails': actionDetails,
    'requestedAt': requestedAt.toIso8601String(),
    'readyAt': readyAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'status': status.name,
    'confirmedBy': confirmedBy,
    'confirmDeviceId': confirmDeviceId,
    'confirmedAt': confirmedAt?.toIso8601String(),
  };

  factory PendingAction.fromMap(Map<String, dynamic> map) {
    return PendingAction(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      requestedBy: map['requestedBy'] as String,
      requestDeviceId: map['requestDeviceId'] as String,
      actionType: map['actionType'] as String,
      actionDetails: Map<String, dynamic>.from(map['actionDetails'] as Map),
      requestedAt: DateTime.parse(map['requestedAt'] as String),
      readyAt: DateTime.parse(map['readyAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      status: PendingActionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PendingActionStatus.pending,
      ),
      confirmedBy: map['confirmedBy'] as String?,
      confirmDeviceId: map['confirmDeviceId'] as String?,
      confirmedAt: map['confirmedAt'] != null
          ? DateTime.parse(map['confirmedAt'] as String)
          : null,
    );
  }
}

/// Time Lock Service - Enforces cooling periods for critical actions.
class TimeLockService {
  final FirebaseFirestore _firestore;
  final TrustedDeviceService _deviceService;
  final AuditRepository _auditRepository;

  /// Actions requiring time lock
  static const Map<String, Duration> timeLockActions = {
    'PERIOD_UNLOCK': TimeLockDurations.periodUnlock,
    'BULK_DELETE': TimeLockDurations.bulkDelete,
    'STOCK_ADJUSTMENT_LARGE': TimeLockDurations.stockAdjustmentLarge,
    'ROLE_CHANGE': TimeLockDurations.roleChange,
    'DATA_EXPORT': TimeLockDurations.dataExport,
    'DEVICE_REMOVAL': TimeLockDurations.deviceRemoval,
  };

  /// Expiry time for pending actions
  static const Duration expiryDuration = Duration(hours: 24);

  TimeLockService({
    FirebaseFirestore? firestore,
    required TrustedDeviceService deviceService,
    required AuditRepository auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _deviceService = deviceService,
       _auditRepository = auditRepository;

  /// Check if action requires time lock
  bool requiresTimeLock(String actionType) {
    return timeLockActions.containsKey(actionType);
  }

  /// Get cooling period for action
  Duration getCoolingPeriod(String actionType) {
    return timeLockActions[actionType] ?? Duration.zero;
  }

  /// Request a time-locked action
  Future<PendingAction> requestAction({
    required String businessId,
    required String requestedBy,
    required String actionType,
    required Map<String, dynamic> actionDetails,
  }) async {
    // Validate device
    final deviceValidation = await _deviceService.validateCurrentDevice(
      businessId: businessId,
      ownerId: requestedBy,
    );

    if (!deviceValidation.isValid) {
      throw TimeLockException(
        'Cannot request time-locked action: ${deviceValidation.reason}',
      );
    }

    final fingerprint = await _deviceService.getCurrentFingerprint();
    final coolingPeriod = getCoolingPeriod(actionType);
    final now = DateTime.now();

    final action = PendingAction(
      id: const Uuid().v4(),
      businessId: businessId,
      requestedBy: requestedBy,
      requestDeviceId: fingerprint.fingerprintHash,
      actionType: actionType,
      actionDetails: actionDetails,
      requestedAt: now,
      readyAt: now.add(coolingPeriod),
      expiresAt: now.add(expiryDuration),
    );

    // Save to Firestore
    await _firestore
        .collection('pending_actions')
        .doc(action.id)
        .set(action.toMap());

    // Audit log
    await _auditRepository.logAction(
      userId: requestedBy,
      targetTableName: 'pending_actions',
      recordId: action.id,
      action: 'REQUEST_TIME_LOCK',
      newValueJson: jsonEncode({
        'actionType': actionType,
        'coolingMinutes': coolingPeriod.inMinutes,
        'readyAt': action.readyAt.toIso8601String(),
      }),
    );

    debugPrint(
      'TimeLockService: Action $actionType requested. '
      'Ready in ${coolingPeriod.inMinutes} minutes.',
    );

    return action;
  }

  /// Confirm a pending action after cooling period
  Future<bool> confirmAction({
    required String actionId,
    required String confirmedBy,
  }) async {
    // Get pending action
    final doc = await _firestore
        .collection('pending_actions')
        .doc(actionId)
        .get();

    if (!doc.exists) {
      throw TimeLockException('Pending action not found');
    }

    final action = PendingAction.fromMap(doc.data()!);

    // Validate status
    if (action.status != PendingActionStatus.pending) {
      throw TimeLockException('Action is no longer pending');
    }

    // Check expiry
    if (action.isExpired) {
      await _markExpired(actionId);
      throw TimeLockException('Action has expired');
    }

    // Check cooling period
    if (action.isPending) {
      final remaining = action.timeUntilReady;
      throw TimeLockException(
        'Cooling period not complete. Wait ${remaining.inMinutes} more minutes.',
      );
    }

    // Validate device - MUST be same device that requested
    final fingerprint = await _deviceService.getCurrentFingerprint();
    if (fingerprint.fingerprintHash != action.requestDeviceId) {
      throw TimeLockException(
        'Confirmation must be from the same device that requested the action',
      );
    }

    // Validate user
    if (confirmedBy != action.requestedBy) {
      throw TimeLockException(
        'Confirmation must be by the same user who requested',
      );
    }

    // Update action
    await _firestore.collection('pending_actions').doc(actionId).update({
      'status': PendingActionStatus.confirmed.name,
      'confirmedBy': confirmedBy,
      'confirmDeviceId': fingerprint.fingerprintHash,
      'confirmedAt': DateTime.now().toIso8601String(),
    });

    // Audit log
    await _auditRepository.logAction(
      userId: confirmedBy,
      targetTableName: 'pending_actions',
      recordId: actionId,
      action: 'CONFIRM_TIME_LOCK',
      oldValueJson: jsonEncode({'status': action.status.name}),
      newValueJson: jsonEncode({
        'status': PendingActionStatus.confirmed.name,
        'actionType': action.actionType,
      }),
    );

    debugPrint('TimeLockService: Action ${action.actionType} confirmed');
    return true;
  }

  /// Cancel a pending action
  Future<void> cancelAction({
    required String actionId,
    required String cancelledBy,
  }) async {
    final doc = await _firestore
        .collection('pending_actions')
        .doc(actionId)
        .get();

    if (!doc.exists) return;

    final action = PendingAction.fromMap(doc.data()!);

    await _firestore.collection('pending_actions').doc(actionId).update({
      'status': PendingActionStatus.cancelled.name,
    });

    await _auditRepository.logAction(
      userId: cancelledBy,
      targetTableName: 'pending_actions',
      recordId: actionId,
      action: 'CANCEL_TIME_LOCK',
      newValueJson: jsonEncode({'actionType': action.actionType}),
    );
  }

  /// Get pending actions for a business
  Future<List<PendingAction>> getPendingActions(String businessId) async {
    final query = await _firestore
        .collection('pending_actions')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: PendingActionStatus.pending.name)
        .orderBy('requestedAt', descending: true)
        .get();

    return query.docs.map((doc) => PendingAction.fromMap(doc.data())).toList();
  }

  Future<void> _markExpired(String actionId) async {
    await _firestore.collection('pending_actions').doc(actionId).update({
      'status': PendingActionStatus.expired.name,
    });
  }
}

/// Exception for time lock errors
class TimeLockException implements Exception {
  final String message;
  TimeLockException(this.message);

  @override
  String toString() => 'TimeLockException: $message';
}
