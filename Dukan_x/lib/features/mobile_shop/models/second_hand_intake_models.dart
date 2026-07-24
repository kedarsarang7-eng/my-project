/// Second-Hand Intake Models (Dart)
///
/// Intake with seller, evidence, inspection, valuation.
///
/// Requirements: 4.2–4.4; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';
import 'imei_unit_models.dart';

/// Intake status.
enum IntakeStatus {
  submitted,
  inspectionPending,
  inspected,
  valuationPending,
  valuationApproved,
  accepted,
  rejected,
  cancelled;

  String toWireValue() {
    switch (this) {
      case IntakeStatus.submitted:
        return 'SUBMITTED';
      case IntakeStatus.inspectionPending:
        return 'INSPECTION_PENDING';
      case IntakeStatus.inspected:
        return 'INSPECTED';
      case IntakeStatus.valuationPending:
        return 'VALUATION_PENDING';
      case IntakeStatus.valuationApproved:
        return 'VALUATION_APPROVED';
      case IntakeStatus.accepted:
        return 'ACCEPTED';
      case IntakeStatus.rejected:
        return 'REJECTED';
      case IntakeStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static IntakeStatus fromWire(String value) {
    switch (value) {
      case 'SUBMITTED':
        return IntakeStatus.submitted;
      case 'INSPECTION_PENDING':
        return IntakeStatus.inspectionPending;
      case 'INSPECTED':
        return IntakeStatus.inspected;
      case 'VALUATION_PENDING':
        return IntakeStatus.valuationPending;
      case 'VALUATION_APPROVED':
        return IntakeStatus.valuationApproved;
      case 'ACCEPTED':
        return IntakeStatus.accepted;
      case 'REJECTED':
        return IntakeStatus.rejected;
      case 'CANCELLED':
        return IntakeStatus.cancelled;
      default:
        throw ArgumentError('Unknown IntakeStatus: $value');
    }
  }
}

/// Inspection result.
enum InspectionResult {
  pass,
  conditionalPass,
  fail;

  String toWireValue() {
    switch (this) {
      case InspectionResult.pass:
        return 'PASS';
      case InspectionResult.conditionalPass:
        return 'CONDITIONAL_PASS';
      case InspectionResult.fail:
        return 'FAIL';
    }
  }

  static InspectionResult fromWire(String value) {
    switch (value) {
      case 'PASS':
        return InspectionResult.pass;
      case 'CONDITIONAL_PASS':
        return InspectionResult.conditionalPass;
      case 'FAIL':
        return InspectionResult.fail;
      default:
        throw ArgumentError('Unknown InspectionResult: $value');
    }
  }
}

/// Ownership evidence status.
enum OwnershipEvidenceStatus {
  pending,
  verified,
  unverified;

  String toWireValue() => name.toUpperCase();

  static OwnershipEvidenceStatus fromWire(String value) {
    switch (value) {
      case 'PENDING':
        return OwnershipEvidenceStatus.pending;
      case 'VERIFIED':
        return OwnershipEvidenceStatus.verified;
      case 'UNVERIFIED':
        return OwnershipEvidenceStatus.unverified;
      default:
        throw ArgumentError('Unknown OwnershipEvidenceStatus: $value');
    }
  }
}

/// A second-hand device intake record.
@immutable
class SecondHandIntake {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String imei;
  final IntakeStatus status;
  final String sellerId;
  final String sellerName;
  final String? sellerContact;
  final String brand;
  final String model;
  final String? color;
  final String? storage;
  final DeviceCondition condition;
  final InspectionResult? inspectionResult;
  final String? inspectionNotes;
  final String? inspectedBy;
  final String? inspectedAt;
  final Money? proposedPrice;
  final Money? approvedValuation;
  final String? valuationApprovedBy;
  final String? valuationApprovedAt;
  final OwnershipEvidenceStatus ownershipEvidenceStatus;
  final List<EvidenceReference>? evidenceRefs;
  final String? exchangeId;
  final String? resultingUnitId;
  final String? notes;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const SecondHandIntake({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.imei,
    required this.status,
    required this.sellerId,
    required this.sellerName,
    this.sellerContact,
    required this.brand,
    required this.model,
    this.color,
    this.storage,
    required this.condition,
    this.inspectionResult,
    this.inspectionNotes,
    this.inspectedBy,
    this.inspectedAt,
    this.proposedPrice,
    this.approvedValuation,
    this.valuationApprovedBy,
    this.valuationApprovedAt,
    required this.ownershipEvidenceStatus,
    this.evidenceRefs,
    this.exchangeId,
    this.resultingUnitId,
    this.notes,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SecondHandIntake.fromJson(Map<String, dynamic> json) =>
      SecondHandIntake(
        tenantId: json['tenantId'] as String,
        entityId: json['entityId'] as String,
        version: json['version'] as int,
        dataModelVersion: json['dataModelVersion'] as int,
        imei: json['imei'] as String,
        status: IntakeStatus.fromWire(json['status'] as String),
        sellerId: json['sellerId'] as String,
        sellerName: json['sellerName'] as String,
        sellerContact: json['sellerContact'] as String?,
        brand: json['brand'] as String,
        model: json['model'] as String,
        color: json['color'] as String?,
        storage: json['storage'] as String?,
        condition: DeviceCondition.fromWire(json['condition'] as String),
        inspectionResult: json['inspectionResult'] != null
            ? InspectionResult.fromWire(json['inspectionResult'] as String)
            : null,
        inspectionNotes: json['inspectionNotes'] as String?,
        inspectedBy: json['inspectedBy'] as String?,
        inspectedAt: json['inspectedAt'] as String?,
        proposedPrice: json['proposedPrice'] != null
            ? Money.fromJson(json['proposedPrice'] as Map<String, dynamic>)
            : null,
        approvedValuation: json['approvedValuation'] != null
            ? Money.fromJson(json['approvedValuation'] as Map<String, dynamic>)
            : null,
        valuationApprovedBy: json['valuationApprovedBy'] as String?,
        valuationApprovedAt: json['valuationApprovedAt'] as String?,
        ownershipEvidenceStatus: OwnershipEvidenceStatus.fromWire(
          json['ownershipEvidenceStatus'] as String,
        ),
        evidenceRefs: (json['evidenceRefs'] as List<dynamic>?)
            ?.map((e) => EvidenceReference.fromJson(e as Map<String, dynamic>))
            .toList(),
        exchangeId: json['exchangeId'] as String?,
        resultingUnitId: json['resultingUnitId'] as String?,
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
    'status': status.toWireValue(),
    'sellerId': sellerId,
    'sellerName': sellerName,
    if (sellerContact != null) 'sellerContact': sellerContact,
    'brand': brand,
    'model': model,
    if (color != null) 'color': color,
    if (storage != null) 'storage': storage,
    'condition': condition.toWireValue(),
    if (inspectionResult != null)
      'inspectionResult': inspectionResult!.toWireValue(),
    if (inspectionNotes != null) 'inspectionNotes': inspectionNotes,
    if (inspectedBy != null) 'inspectedBy': inspectedBy,
    if (inspectedAt != null) 'inspectedAt': inspectedAt,
    if (proposedPrice != null) 'proposedPrice': proposedPrice!.toJson(),
    if (approvedValuation != null)
      'approvedValuation': approvedValuation!.toJson(),
    if (valuationApprovedBy != null) 'valuationApprovedBy': valuationApprovedBy,
    if (valuationApprovedAt != null) 'valuationApprovedAt': valuationApprovedAt,
    'ownershipEvidenceStatus': ownershipEvidenceStatus.toWireValue(),
    if (evidenceRefs != null)
      'evidenceRefs': evidenceRefs!.map((e) => e.toJson()).toList(),
    if (exchangeId != null) 'exchangeId': exchangeId,
    if (resultingUnitId != null) 'resultingUnitId': resultingUnitId,
    if (notes != null) 'notes': notes,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
