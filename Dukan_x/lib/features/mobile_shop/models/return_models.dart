/// Return Models (Dart)
///
/// Device return with eligibility, disposition, and target lifecycle state.
///
/// Requirements: 4.7; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';
import 'imei_unit_models.dart';

/// Return status.
enum ReturnStatus {
  requested,
  eligibilityVerified,
  inspectionPending,
  inspected,
  approved,
  completed,
  rejected,
  cancelled;

  String toWireValue() {
    switch (this) {
      case ReturnStatus.requested:
        return 'REQUESTED';
      case ReturnStatus.eligibilityVerified:
        return 'ELIGIBILITY_VERIFIED';
      case ReturnStatus.inspectionPending:
        return 'INSPECTION_PENDING';
      case ReturnStatus.inspected:
        return 'INSPECTED';
      case ReturnStatus.approved:
        return 'APPROVED';
      case ReturnStatus.completed:
        return 'COMPLETED';
      case ReturnStatus.rejected:
        return 'REJECTED';
      case ReturnStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static ReturnStatus fromWire(String value) {
    switch (value) {
      case 'REQUESTED':
        return ReturnStatus.requested;
      case 'ELIGIBILITY_VERIFIED':
        return ReturnStatus.eligibilityVerified;
      case 'INSPECTION_PENDING':
        return ReturnStatus.inspectionPending;
      case 'INSPECTED':
        return ReturnStatus.inspected;
      case 'APPROVED':
        return ReturnStatus.approved;
      case 'COMPLETED':
        return ReturnStatus.completed;
      case 'REJECTED':
        return ReturnStatus.rejected;
      case 'CANCELLED':
        return ReturnStatus.cancelled;
      default:
        throw ArgumentError('Unknown ReturnStatus: $value');
    }
  }
}

/// Disposition of the returned device.
enum ReturnDisposition {
  restock,
  refurbish,
  damageWriteOff,
  exchangeCredit,
  vendorReturn;

  String toWireValue() {
    switch (this) {
      case ReturnDisposition.restock:
        return 'RESTOCK';
      case ReturnDisposition.refurbish:
        return 'REFURBISH';
      case ReturnDisposition.damageWriteOff:
        return 'DAMAGE_WRITE_OFF';
      case ReturnDisposition.exchangeCredit:
        return 'EXCHANGE_CREDIT';
      case ReturnDisposition.vendorReturn:
        return 'VENDOR_RETURN';
    }
  }

  static ReturnDisposition fromWire(String value) {
    switch (value) {
      case 'RESTOCK':
        return ReturnDisposition.restock;
      case 'REFURBISH':
        return ReturnDisposition.refurbish;
      case 'DAMAGE_WRITE_OFF':
        return ReturnDisposition.damageWriteOff;
      case 'EXCHANGE_CREDIT':
        return ReturnDisposition.exchangeCredit;
      case 'VENDOR_RETURN':
        return ReturnDisposition.vendorReturn;
      default:
        throw ArgumentError('Unknown ReturnDisposition: $value');
    }
  }
}

/// A device return record.
@immutable
class DeviceReturn {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String imei;
  final String unitId;
  final String customerId;
  final String customerName;
  final ReturnStatus status;
  final String originatingInvoiceId;
  final String originalSaleDate;
  final bool withinReturnWindow;
  final String reason;
  final DeviceCondition? returnCondition;
  final bool? imeiMatchVerified;
  final String? inspectionNotes;
  final ReturnDisposition? disposition;
  final DeviceLifecycleState? targetLifecycleState;
  final Money? refundAmount;
  final Money? restockingFee;
  final List<EvidenceReference>? evidenceRefs;
  final String? notes;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const DeviceReturn({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.imei,
    required this.unitId,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.originatingInvoiceId,
    required this.originalSaleDate,
    required this.withinReturnWindow,
    required this.reason,
    this.returnCondition,
    this.imeiMatchVerified,
    this.inspectionNotes,
    this.disposition,
    this.targetLifecycleState,
    this.refundAmount,
    this.restockingFee,
    this.evidenceRefs,
    this.notes,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceReturn.fromJson(Map<String, dynamic> json) => DeviceReturn(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    imei: json['imei'] as String,
    unitId: json['unitId'] as String,
    customerId: json['customerId'] as String,
    customerName: json['customerName'] as String,
    status: ReturnStatus.fromWire(json['status'] as String),
    originatingInvoiceId: json['originatingInvoiceId'] as String,
    originalSaleDate: json['originalSaleDate'] as String,
    withinReturnWindow: json['withinReturnWindow'] as bool,
    reason: json['reason'] as String,
    returnCondition: json['returnCondition'] != null
        ? DeviceCondition.fromWire(json['returnCondition'] as String)
        : null,
    imeiMatchVerified: json['imeiMatchVerified'] as bool?,
    inspectionNotes: json['inspectionNotes'] as String?,
    disposition: json['disposition'] != null
        ? ReturnDisposition.fromWire(json['disposition'] as String)
        : null,
    targetLifecycleState: json['targetLifecycleState'] != null
        ? DeviceLifecycleState.fromWire(json['targetLifecycleState'] as String)
        : null,
    refundAmount: json['refundAmount'] != null
        ? Money.fromJson(json['refundAmount'] as Map<String, dynamic>)
        : null,
    restockingFee: json['restockingFee'] != null
        ? Money.fromJson(json['restockingFee'] as Map<String, dynamic>)
        : null,
    evidenceRefs: (json['evidenceRefs'] as List<dynamic>?)
        ?.map((e) => EvidenceReference.fromJson(e as Map<String, dynamic>))
        .toList(),
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
    'originatingInvoiceId': originatingInvoiceId,
    'originalSaleDate': originalSaleDate,
    'withinReturnWindow': withinReturnWindow,
    'reason': reason,
    if (returnCondition != null)
      'returnCondition': returnCondition!.toWireValue(),
    if (imeiMatchVerified != null) 'imeiMatchVerified': imeiMatchVerified,
    if (inspectionNotes != null) 'inspectionNotes': inspectionNotes,
    if (disposition != null) 'disposition': disposition!.toWireValue(),
    if (targetLifecycleState != null)
      'targetLifecycleState': targetLifecycleState!.toWireValue(),
    if (refundAmount != null) 'refundAmount': refundAmount!.toJson(),
    if (restockingFee != null) 'restockingFee': restockingFee!.toJson(),
    if (evidenceRefs != null)
      'evidenceRefs': evidenceRefs!.map((e) => e.toJson()).toList(),
    if (notes != null) 'notes': notes,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
