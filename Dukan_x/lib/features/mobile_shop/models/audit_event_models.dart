/// Audit Event Models (Dart)
///
/// Immutable audit event with actor, action, before/after digest.
///
/// Requirements: 3.3, 4.3, 5.2, 8.11–8.12; GR-2
library;

import 'package:flutter/foundation.dart';

/// Action categories for audit events.
enum AuditAction {
  saleCommitted,
  saleCancelled,
  lifecycleTransition,
  intakeAccepted,
  intakeRejected,
  reservationCreated,
  reservationReleased,
  returnCompleted,
  exchangeCompleted,
  serviceStatusChange,
  warrantyRegistered,
  warrantyClaimed,
  financeApproved,
  rechargeCompleted,
  valuationApproved,
  correction;

  String toWireValue() {
    switch (this) {
      case AuditAction.saleCommitted:
        return 'SALE_COMMITTED';
      case AuditAction.saleCancelled:
        return 'SALE_CANCELLED';
      case AuditAction.lifecycleTransition:
        return 'LIFECYCLE_TRANSITION';
      case AuditAction.intakeAccepted:
        return 'INTAKE_ACCEPTED';
      case AuditAction.intakeRejected:
        return 'INTAKE_REJECTED';
      case AuditAction.reservationCreated:
        return 'RESERVATION_CREATED';
      case AuditAction.reservationReleased:
        return 'RESERVATION_RELEASED';
      case AuditAction.returnCompleted:
        return 'RETURN_COMPLETED';
      case AuditAction.exchangeCompleted:
        return 'EXCHANGE_COMPLETED';
      case AuditAction.serviceStatusChange:
        return 'SERVICE_STATUS_CHANGE';
      case AuditAction.warrantyRegistered:
        return 'WARRANTY_REGISTERED';
      case AuditAction.warrantyClaimed:
        return 'WARRANTY_CLAIMED';
      case AuditAction.financeApproved:
        return 'FINANCE_APPROVED';
      case AuditAction.rechargeCompleted:
        return 'RECHARGE_COMPLETED';
      case AuditAction.valuationApproved:
        return 'VALUATION_APPROVED';
      case AuditAction.correction:
        return 'CORRECTION';
    }
  }

  static AuditAction fromWire(String value) {
    switch (value) {
      case 'SALE_COMMITTED':
        return AuditAction.saleCommitted;
      case 'SALE_CANCELLED':
        return AuditAction.saleCancelled;
      case 'LIFECYCLE_TRANSITION':
        return AuditAction.lifecycleTransition;
      case 'INTAKE_ACCEPTED':
        return AuditAction.intakeAccepted;
      case 'INTAKE_REJECTED':
        return AuditAction.intakeRejected;
      case 'RESERVATION_CREATED':
        return AuditAction.reservationCreated;
      case 'RESERVATION_RELEASED':
        return AuditAction.reservationReleased;
      case 'RETURN_COMPLETED':
        return AuditAction.returnCompleted;
      case 'EXCHANGE_COMPLETED':
        return AuditAction.exchangeCompleted;
      case 'SERVICE_STATUS_CHANGE':
        return AuditAction.serviceStatusChange;
      case 'WARRANTY_REGISTERED':
        return AuditAction.warrantyRegistered;
      case 'WARRANTY_CLAIMED':
        return AuditAction.warrantyClaimed;
      case 'FINANCE_APPROVED':
        return AuditAction.financeApproved;
      case 'RECHARGE_COMPLETED':
        return AuditAction.rechargeCompleted;
      case 'VALUATION_APPROVED':
        return AuditAction.valuationApproved;
      case 'CORRECTION':
        return AuditAction.correction;
      default:
        throw ArgumentError('Unknown AuditAction: $value');
    }
  }
}

/// An immutable audit event — append-only.
@immutable
class AuditEvent {
  final String tenantId;
  final String eventId;
  final int dataModelVersion;
  final String actorId;
  final String? actorName;
  final AuditAction action;
  final String entityType;
  final String entityId;
  final String operationId;
  final String correlationId;
  final String? beforeDigest;
  final String? afterDigest;
  final String? reason;
  final List<String>? evidenceRefs;
  final String? correctsEventId;
  final String occurredAt;
  final String createdAt;

  const AuditEvent({
    required this.tenantId,
    required this.eventId,
    required this.dataModelVersion,
    required this.actorId,
    this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.operationId,
    required this.correlationId,
    this.beforeDigest,
    this.afterDigest,
    this.reason,
    this.evidenceRefs,
    this.correctsEventId,
    required this.occurredAt,
    required this.createdAt,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
    tenantId: json['tenantId'] as String,
    eventId: json['eventId'] as String,
    dataModelVersion: json['dataModelVersion'] as int,
    actorId: json['actorId'] as String,
    actorName: json['actorName'] as String?,
    action: AuditAction.fromWire(json['action'] as String),
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    operationId: json['operationId'] as String,
    correlationId: json['correlationId'] as String,
    beforeDigest: json['beforeDigest'] as String?,
    afterDigest: json['afterDigest'] as String?,
    reason: json['reason'] as String?,
    evidenceRefs: (json['evidenceRefs'] as List<dynamic>?)?.cast<String>(),
    correctsEventId: json['correctsEventId'] as String?,
    occurredAt: json['occurredAt'] as String,
    createdAt: json['createdAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'eventId': eventId,
    'dataModelVersion': dataModelVersion,
    'actorId': actorId,
    if (actorName != null) 'actorName': actorName,
    'action': action.toWireValue(),
    'entityType': entityType,
    'entityId': entityId,
    'operationId': operationId,
    'correlationId': correlationId,
    if (beforeDigest != null) 'beforeDigest': beforeDigest,
    if (afterDigest != null) 'afterDigest': afterDigest,
    if (reason != null) 'reason': reason,
    if (evidenceRefs != null) 'evidenceRefs': evidenceRefs,
    if (correctsEventId != null) 'correctsEventId': correctsEventId,
    'occurredAt': occurredAt,
    'createdAt': createdAt,
  };
}
