/// Service Job Models (Dart)
///
/// Service jobs with status, transitions, technician, fault, estimate.
///
/// Requirements: 5.1–5.3; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';

/// Service job status following allowed transitions.
enum ServiceJobStatus {
  received,
  diagnosed,
  estimateSent,
  approved,
  inProgress,
  partsOrdered,
  ready,
  delivered,
  cancelled;

  String toWireValue() {
    switch (this) {
      case ServiceJobStatus.received:
        return 'RECEIVED';
      case ServiceJobStatus.diagnosed:
        return 'DIAGNOSED';
      case ServiceJobStatus.estimateSent:
        return 'ESTIMATE_SENT';
      case ServiceJobStatus.approved:
        return 'APPROVED';
      case ServiceJobStatus.inProgress:
        return 'IN_PROGRESS';
      case ServiceJobStatus.partsOrdered:
        return 'PARTS_ORDERED';
      case ServiceJobStatus.ready:
        return 'READY';
      case ServiceJobStatus.delivered:
        return 'DELIVERED';
      case ServiceJobStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static ServiceJobStatus fromWire(String value) {
    switch (value) {
      case 'RECEIVED':
        return ServiceJobStatus.received;
      case 'DIAGNOSED':
        return ServiceJobStatus.diagnosed;
      case 'ESTIMATE_SENT':
        return ServiceJobStatus.estimateSent;
      case 'APPROVED':
        return ServiceJobStatus.approved;
      case 'IN_PROGRESS':
        return ServiceJobStatus.inProgress;
      case 'PARTS_ORDERED':
        return ServiceJobStatus.partsOrdered;
      case 'READY':
        return ServiceJobStatus.ready;
      case 'DELIVERED':
        return ServiceJobStatus.delivered;
      case 'CANCELLED':
        return ServiceJobStatus.cancelled;
      default:
        throw ArgumentError('Unknown ServiceJobStatus: $value');
    }
  }
}

/// Priority level.
enum ServicePriority {
  low,
  normal,
  high,
  urgent;

  String toWireValue() => name.toUpperCase();

  static ServicePriority fromWire(String value) {
    switch (value) {
      case 'LOW':
        return ServicePriority.low;
      case 'NORMAL':
        return ServicePriority.normal;
      case 'HIGH':
        return ServicePriority.high;
      case 'URGENT':
        return ServicePriority.urgent;
      default:
        throw ArgumentError('Unknown ServicePriority: $value');
    }
  }
}

/// A service/repair job for a device.
@immutable
class ServiceJob {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String imei;
  final String unitId;
  final String customerId;
  final String customerName;
  final ServiceJobStatus status;
  final ServicePriority priority;
  final String faultDescription;
  final String? diagnosisNotes;
  final String? technicianId;
  final String? technicianName;
  final Money? estimatedCost;
  final Money? actualCost;
  final bool underWarranty;
  final String? warrantyClaimId;
  final String receivedAt;
  final String? estimatedCompletionAt;
  final String? completedAt;
  final String? deliveredAt;
  final String? dueAt;
  final String? notes;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const ServiceJob({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.imei,
    required this.unitId,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.priority,
    required this.faultDescription,
    this.diagnosisNotes,
    this.technicianId,
    this.technicianName,
    this.estimatedCost,
    this.actualCost,
    required this.underWarranty,
    this.warrantyClaimId,
    required this.receivedAt,
    this.estimatedCompletionAt,
    this.completedAt,
    this.deliveredAt,
    this.dueAt,
    this.notes,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceJob.fromJson(Map<String, dynamic> json) => ServiceJob(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    imei: json['imei'] as String,
    unitId: json['unitId'] as String,
    customerId: json['customerId'] as String,
    customerName: json['customerName'] as String,
    status: ServiceJobStatus.fromWire(json['status'] as String),
    priority: ServicePriority.fromWire(json['priority'] as String),
    faultDescription: json['faultDescription'] as String,
    diagnosisNotes: json['diagnosisNotes'] as String?,
    technicianId: json['technicianId'] as String?,
    technicianName: json['technicianName'] as String?,
    estimatedCost: json['estimatedCost'] != null
        ? Money.fromJson(json['estimatedCost'] as Map<String, dynamic>)
        : null,
    actualCost: json['actualCost'] != null
        ? Money.fromJson(json['actualCost'] as Map<String, dynamic>)
        : null,
    underWarranty: json['underWarranty'] as bool,
    warrantyClaimId: json['warrantyClaimId'] as String?,
    receivedAt: json['receivedAt'] as String,
    estimatedCompletionAt: json['estimatedCompletionAt'] as String?,
    completedAt: json['completedAt'] as String?,
    deliveredAt: json['deliveredAt'] as String?,
    dueAt: json['dueAt'] as String?,
    notes: json['notes'] as String?,
    operationId: json['operationId'] as String,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'entityId': entityId,
    'version': version,
    'dataModelVersion': dataModelVersion,
    'imei': imei,
    'unitId': unitId,
    'customerId': customerId,
    'customerName': customerName,
    'status': status.toWireValue(),
    'priority': priority.toWireValue(),
    'faultDescription': faultDescription,
    if (diagnosisNotes != null) 'diagnosisNotes': diagnosisNotes,
    if (technicianId != null) 'technicianId': technicianId,
    if (technicianName != null) 'technicianName': technicianName,
    if (estimatedCost != null) 'estimatedCost': estimatedCost!.toJson(),
    if (actualCost != null) 'actualCost': actualCost!.toJson(),
    'underWarranty': underWarranty,
    if (warrantyClaimId != null) 'warrantyClaimId': warrantyClaimId,
    'receivedAt': receivedAt,
    if (estimatedCompletionAt != null)
      'estimatedCompletionAt': estimatedCompletionAt,
    if (completedAt != null) 'completedAt': completedAt,
    if (deliveredAt != null) 'deliveredAt': deliveredAt,
    if (dueAt != null) 'dueAt': dueAt,
    if (notes != null) 'notes': notes,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
