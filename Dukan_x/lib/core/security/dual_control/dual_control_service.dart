// ============================================================================
// DUAL CONTROL SERVICE
// ============================================================================
// Requires two different approvers for ultra-critical actions.
// Same person/device/role cannot approve twice.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:uuid/uuid.dart';

import '../device/trusted_device_service.dart';
import '../../repository/audit_repository.dart';

/// Dual Control Approval
class DualControlApproval {
  final String approverId;
  final String approverRole;
  final String deviceFingerprint;
  final DateTime approvedAt;
  final String? comment;

  const DualControlApproval({
    required this.approverId,
    required this.approverRole,
    required this.deviceFingerprint,
    required this.approvedAt,
    this.comment,
  });

  Map<String, dynamic> toMap() => {
    'approverId': approverId,
    'approverRole': approverRole,
    'deviceFingerprint': deviceFingerprint,
    'approvedAt': approvedAt.toIso8601String(),
    'comment': comment,
  };

  factory DualControlApproval.fromMap(Map<String, dynamic> map) {
    return DualControlApproval(
      approverId: map['approverId'] as String,
      approverRole: map['approverRole'] as String,
      deviceFingerprint: map['deviceFingerprint'] as String,
      approvedAt: DateTime.parse(map['approvedAt'] as String),
      comment: map['comment'] as String?,
    );
  }
}

/// Dual Control Request Status
enum DualControlStatus {
  /// Waiting for first approval
  waitingFirst,

  /// Waiting for second approval
  waitingSecond,

  /// Both approvals received
  approved,

  /// Request rejected
  rejected,

  /// Request expired
  expired,
}

/// Dual Control Request
class DualControlRequest {
  final String id;
  final String businessId;
  final String requestedBy;
  final String actionType;
  final Map<String, dynamic> actionDetails;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final DualControlStatus status;
  final DualControlApproval? firstApproval;
  final DualControlApproval? secondApproval;
  final List<String> requiredRoles;

  const DualControlRequest({
    required this.id,
    required this.businessId,
    required this.requestedBy,
    required this.actionType,
    required this.actionDetails,
    required this.requestedAt,
    required this.expiresAt,
    this.status = DualControlStatus.waitingFirst,
    this.firstApproval,
    this.secondApproval,
    this.requiredRoles = const ['owner', 'manager'],
  });

  bool get isComplete =>
      status == DualControlStatus.approved &&
      firstApproval != null &&
      secondApproval != null;

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) || status == DualControlStatus.expired;

  bool get canAddApproval =>
      status == DualControlStatus.waitingFirst ||
      status == DualControlStatus.waitingSecond;

  DualControlRequest copyWith({
    DualControlStatus? status,
    DualControlApproval? firstApproval,
    DualControlApproval? secondApproval,
  }) {
    return DualControlRequest(
      id: id,
      businessId: businessId,
      requestedBy: requestedBy,
      actionType: actionType,
      actionDetails: actionDetails,
      requestedAt: requestedAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      firstApproval: firstApproval ?? this.firstApproval,
      secondApproval: secondApproval ?? this.secondApproval,
      requiredRoles: requiredRoles,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'businessId': businessId,
    'requestedBy': requestedBy,
    'actionType': actionType,
    'actionDetails': actionDetails,
    'requestedAt': requestedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'status': status.name,
    'firstApproval': firstApproval?.toMap(),
    'secondApproval': secondApproval?.toMap(),
    'requiredRoles': requiredRoles,
  };

  factory DualControlRequest.fromMap(Map<String, dynamic> map) {
    return DualControlRequest(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      requestedBy: map['requestedBy'] as String,
      actionType: map['actionType'] as String,
      actionDetails: Map<String, dynamic>.from(map['actionDetails'] as Map),
      requestedAt: DateTime.parse(map['requestedAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      status: DualControlStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DualControlStatus.waitingFirst,
      ),
      firstApproval: map['firstApproval'] != null
          ? DualControlApproval.fromMap(
              map['firstApproval'] as Map<String, dynamic>,
            )
          : null,
      secondApproval: map['secondApproval'] != null
          ? DualControlApproval.fromMap(
              map['secondApproval'] as Map<String, dynamic>,
            )
          : null,
      requiredRoles: List<String>.from(
        map['requiredRoles'] ?? ['owner', 'manager'],
      ),
    );
  }
}

/// Dual Control Service - Two-person approval for critical actions.
///
/// Rules:
/// - Same person cannot approve twice
/// - Same device cannot approve twice
/// - Same role cannot approve twice (optional)
/// - Approvals must be within 24h
class DualControlService {
  final FirebaseFirestore _firestore;
  final TrustedDeviceService _deviceService;
  final AuditRepository _auditRepository;

  /// Actions requiring dual control
  static const List<String> dualControlActions = [
    'DELETE_BILL_AFTER_GST',
    'UNLOCK_CLOSED_YEAR',
    'CHANGE_OWNER_ACCOUNT',
    'REMOVE_TRUSTED_DEVICE',
    'EXPORT_FULL_DATABASE',
    'BULK_DELETE_CUSTOMERS',
    'MODIFY_AUDIT_SETTINGS',
  ];

  /// Approval expiry
  static const Duration approvalExpiry = Duration(hours: 24);

  DualControlService({
    FirebaseFirestore? firestore,
    required TrustedDeviceService deviceService,
    required AuditRepository auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _deviceService = deviceService,
       _auditRepository = auditRepository;

  /// Check if action requires dual control
  bool requiresDualControl(String actionType) {
    return dualControlActions.contains(actionType);
  }

  /// Create a dual control request
  Future<DualControlRequest> createRequest({
    required String businessId,
    required String requestedBy,
    required String actionType,
    required Map<String, dynamic> actionDetails,
    List<String>? requiredRoles,
  }) async {
    final now = DateTime.now();

    final request = DualControlRequest(
      id: const Uuid().v4(),
      businessId: businessId,
      requestedBy: requestedBy,
      actionType: actionType,
      actionDetails: actionDetails,
      requestedAt: now,
      expiresAt: now.add(approvalExpiry),
      requiredRoles: requiredRoles ?? const ['owner', 'manager'],
    );

    await _firestore
        .collection('dual_control_requests')
        .doc(request.id)
        .set(request.toMap());

    await _auditRepository.logAction(
      userId: requestedBy,
      targetTableName: 'dual_control_requests',
      recordId: request.id,
      action: 'CREATE_DUAL_CONTROL_REQUEST',
      newValueJson: jsonEncode({
        'actionType': actionType,
        'expiresAt': request.expiresAt.toIso8601String(),
      }),
    );

    debugPrint(
      'DualControlService: Created request for $actionType. '
      'Expires: ${request.expiresAt}',
    );

    return request;
  }

  /// Add approval to a request
  Future<DualControlRequest> addApproval({
    required String requestId,
    required String approverId,
    required String approverRole,
    String? comment,
  }) async {
    // Get request
    final doc = await _firestore
        .collection('dual_control_requests')
        .doc(requestId)
        .get();

    if (!doc.exists) {
      throw DualControlException('Request not found');
    }

    final request = DualControlRequest.fromMap(doc.data()!);

    // Check expiry
    if (request.isExpired) {
      await _markExpired(requestId);
      throw DualControlException('Request has expired');
    }

    // Check status
    if (!request.canAddApproval) {
      throw DualControlException('Request is no longer accepting approvals');
    }

    // Get device fingerprint
    final fingerprint = await _deviceService.getCurrentFingerprint();

    // Validate: Same person cannot approve twice
    if (request.firstApproval?.approverId == approverId) {
      throw DualControlException('Same person cannot approve twice');
    }

    // Validate: Same device cannot approve twice
    if (request.firstApproval?.deviceFingerprint ==
        fingerprint.fingerprintHash) {
      throw DualControlException('Same device cannot approve twice');
    }

    // Validate: Same role cannot approve twice (for stricter control)
    if (request.firstApproval?.approverRole == approverRole) {
      throw DualControlException('Same role cannot approve twice');
    }

    // Validate: Must be from trusted device
    final deviceValidation = await _deviceService.validateCurrentDevice(
      businessId: request.businessId,
      ownerId: approverId,
    );

    if (!deviceValidation.isValid && !deviceValidation.isTrusted) {
      throw DualControlException('Approval must be from a trusted device');
    }

    // Create approval
    final approval = DualControlApproval(
      approverId: approverId,
      approverRole: approverRole,
      deviceFingerprint: fingerprint.fingerprintHash,
      approvedAt: DateTime.now(),
      comment: comment,
    );

    // Determine new status
    DualControlRequest updatedRequest;
    if (request.firstApproval == null) {
      updatedRequest = request.copyWith(
        firstApproval: approval,
        status: DualControlStatus.waitingSecond,
      );
    } else {
      updatedRequest = request.copyWith(
        secondApproval: approval,
        status: DualControlStatus.approved,
      );
    }

    // Save
    await _firestore
        .collection('dual_control_requests')
        .doc(requestId)
        .update(updatedRequest.toMap());

    // Audit log
    await _auditRepository.logAction(
      userId: approverId,
      targetTableName: 'dual_control_requests',
      recordId: requestId,
      action: 'DUAL_CONTROL_APPROVAL',
      newValueJson: jsonEncode({
        'approverRole': approverRole,
        'approvalNumber': request.firstApproval == null ? 1 : 2,
        'isComplete': updatedRequest.isComplete,
      }),
    );

    debugPrint(
      'DualControlService: Approval added by $approverId ($approverRole). '
      'Complete: ${updatedRequest.isComplete}',
    );

    return updatedRequest;
  }

  /// Reject a dual control request
  Future<void> rejectRequest({
    required String requestId,
    required String rejectedBy,
    String? reason,
  }) async {
    await _firestore.collection('dual_control_requests').doc(requestId).update({
      'status': DualControlStatus.rejected.name,
    });

    await _auditRepository.logAction(
      userId: rejectedBy,
      targetTableName: 'dual_control_requests',
      recordId: requestId,
      action: 'DUAL_CONTROL_REJECTED',
      newValueJson: jsonEncode({'reason': reason}),
    );
  }

  /// Get pending requests for a business
  Future<List<DualControlRequest>> getPendingRequests(String businessId) async {
    final query = await _firestore
        .collection('dual_control_requests')
        .where('businessId', isEqualTo: businessId)
        .where(
          'status',
          whereIn: [
            DualControlStatus.waitingFirst.name,
            DualControlStatus.waitingSecond.name,
          ],
        )
        .orderBy('requestedAt', descending: true)
        .get();

    return query.docs
        .map((doc) => DualControlRequest.fromMap(doc.data()))
        .where((r) => !r.isExpired)
        .toList();
  }

  Future<void> _markExpired(String requestId) async {
    await _firestore.collection('dual_control_requests').doc(requestId).update({
      'status': DualControlStatus.expired.name,
    });
  }
}

/// Exception for dual control errors
class DualControlException implements Exception {
  final String message;
  DualControlException(this.message);

  @override
  String toString() => 'DualControlException: $message';
}
