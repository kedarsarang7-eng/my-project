/// Warranty Models (Dart)
///
/// Warranty registration, claims, period, and provider.
///
/// Requirements: 5.5–5.7; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';

/// Warranty status.
enum WarrantyStatus {
  active,
  expired,
  claimed,
  void_;

  String toWireValue() {
    switch (this) {
      case WarrantyStatus.active:
        return 'ACTIVE';
      case WarrantyStatus.expired:
        return 'EXPIRED';
      case WarrantyStatus.claimed:
        return 'CLAIMED';
      case WarrantyStatus.void_:
        return 'VOID';
    }
  }

  static WarrantyStatus fromWire(String value) {
    switch (value) {
      case 'ACTIVE':
        return WarrantyStatus.active;
      case 'EXPIRED':
        return WarrantyStatus.expired;
      case 'CLAIMED':
        return WarrantyStatus.claimed;
      case 'VOID':
        return WarrantyStatus.void_;
      default:
        throw ArgumentError('Unknown WarrantyStatus: $value');
    }
  }
}

/// Warranty claim status.
enum WarrantyClaimStatus {
  submitted,
  underReview,
  approved,
  rejected,
  resolved,
  closed;

  String toWireValue() {
    switch (this) {
      case WarrantyClaimStatus.submitted:
        return 'SUBMITTED';
      case WarrantyClaimStatus.underReview:
        return 'UNDER_REVIEW';
      case WarrantyClaimStatus.approved:
        return 'APPROVED';
      case WarrantyClaimStatus.rejected:
        return 'REJECTED';
      case WarrantyClaimStatus.resolved:
        return 'RESOLVED';
      case WarrantyClaimStatus.closed:
        return 'CLOSED';
    }
  }

  static WarrantyClaimStatus fromWire(String value) {
    switch (value) {
      case 'SUBMITTED':
        return WarrantyClaimStatus.submitted;
      case 'UNDER_REVIEW':
        return WarrantyClaimStatus.underReview;
      case 'APPROVED':
        return WarrantyClaimStatus.approved;
      case 'REJECTED':
        return WarrantyClaimStatus.rejected;
      case 'RESOLVED':
        return WarrantyClaimStatus.resolved;
      case 'CLOSED':
        return WarrantyClaimStatus.closed;
      default:
        throw ArgumentError('Unknown WarrantyClaimStatus: $value');
    }
  }
}

/// Warranty type.
enum WarrantyType {
  manufacturer,
  extended,
  thirdParty,
  store;

  String toWireValue() {
    switch (this) {
      case WarrantyType.manufacturer:
        return 'MANUFACTURER';
      case WarrantyType.extended:
        return 'EXTENDED';
      case WarrantyType.thirdParty:
        return 'THIRD_PARTY';
      case WarrantyType.store:
        return 'STORE';
    }
  }

  static WarrantyType fromWire(String value) {
    switch (value) {
      case 'MANUFACTURER':
        return WarrantyType.manufacturer;
      case 'EXTENDED':
        return WarrantyType.extended;
      case 'THIRD_PARTY':
        return WarrantyType.thirdParty;
      case 'STORE':
        return WarrantyType.store;
      default:
        throw ArgumentError('Unknown WarrantyType: $value');
    }
  }
}

/// A warranty registration.
@immutable
class Warranty {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String imei;
  final String unitId;
  final String saleInvoiceId;
  final String customerId;
  final WarrantyType warrantyType;
  final WarrantyStatus status;
  final String provider;
  final int durationMonths;
  final String startDate;
  final String endDate;
  final String? providerReference;
  final Money? cost;
  final String? notes;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const Warranty({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.imei,
    required this.unitId,
    required this.saleInvoiceId,
    required this.customerId,
    required this.warrantyType,
    required this.status,
    required this.provider,
    required this.durationMonths,
    required this.startDate,
    required this.endDate,
    this.providerReference,
    this.cost,
    this.notes,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Warranty.fromJson(Map<String, dynamic> json) => Warranty(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    imei: json['imei'] as String,
    unitId: json['unitId'] as String,
    saleInvoiceId: json['saleInvoiceId'] as String,
    customerId: json['customerId'] as String,
    warrantyType: WarrantyType.fromWire(json['warrantyType'] as String),
    status: WarrantyStatus.fromWire(json['status'] as String),
    provider: json['provider'] as String,
    durationMonths: json['durationMonths'] as int,
    startDate: json['startDate'] as String,
    endDate: json['endDate'] as String,
    providerReference: json['providerReference'] as String?,
    cost: json['cost'] != null
        ? Money.fromJson(json['cost'] as Map<String, dynamic>)
        : null,
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
    'saleInvoiceId': saleInvoiceId,
    'customerId': customerId,
    'warrantyType': warrantyType.toWireValue(),
    'status': status.toWireValue(),
    'provider': provider,
    'durationMonths': durationMonths,
    'startDate': startDate,
    'endDate': endDate,
    if (providerReference != null) 'providerReference': providerReference,
    if (cost != null) 'cost': cost!.toJson(),
    if (notes != null) 'notes': notes,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// A warranty claim.
@immutable
class WarrantyClaim {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String warrantyId;
  final String imei;
  final String unitId;
  final String customerId;
  final WarrantyClaimStatus status;
  final String faultDescription;
  final String claimDate;
  final String? resolution;
  final String? resolvedAt;
  final Money? resolutionCost;
  final List<EvidenceReference>? evidenceRefs;
  final String? serviceJobId;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const WarrantyClaim({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.warrantyId,
    required this.imei,
    required this.unitId,
    required this.customerId,
    required this.status,
    required this.faultDescription,
    required this.claimDate,
    this.resolution,
    this.resolvedAt,
    this.resolutionCost,
    this.evidenceRefs,
    this.serviceJobId,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WarrantyClaim.fromJson(Map<String, dynamic> json) => WarrantyClaim(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    warrantyId: json['warrantyId'] as String,
    imei: json['imei'] as String,
    unitId: json['unitId'] as String,
    customerId: json['customerId'] as String,
    status: WarrantyClaimStatus.fromWire(json['status'] as String),
    faultDescription: json['faultDescription'] as String,
    claimDate: json['claimDate'] as String,
    resolution: json['resolution'] as String?,
    resolvedAt: json['resolvedAt'] as String?,
    resolutionCost: json['resolutionCost'] != null
        ? Money.fromJson(json['resolutionCost'] as Map<String, dynamic>)
        : null,
    evidenceRefs: (json['evidenceRefs'] as List<dynamic>?)
        ?.map((e) => EvidenceReference.fromJson(e as Map<String, dynamic>))
        .toList(),
    serviceJobId: json['serviceJobId'] as String?,
    operationId: json['operationId'] as String,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'entityId': entityId,
    'version': version,
    'dataModelVersion': dataModelVersion,
    'warrantyId': warrantyId,
    'imei': imei,
    'unitId': unitId,
    'customerId': customerId,
    'status': status.toWireValue(),
    'faultDescription': faultDescription,
    'claimDate': claimDate,
    if (resolution != null) 'resolution': resolution,
    if (resolvedAt != null) 'resolvedAt': resolvedAt,
    if (resolutionCost != null) 'resolutionCost': resolutionCost!.toJson(),
    if (evidenceRefs != null)
      'evidenceRefs': evidenceRefs!.map((e) => e.toJson()).toList(),
    if (serviceJobId != null) 'serviceJobId': serviceJobId,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
