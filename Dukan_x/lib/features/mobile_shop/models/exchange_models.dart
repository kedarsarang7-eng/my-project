/// Exchange Models (Dart)
///
/// Device exchange with old/new device, valuation, financial adjustment.
///
/// Requirements: 5.4; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';

/// Exchange status.
enum ExchangeStatus {
  initiated,
  valuationPending,
  valuationApproved,
  approved,
  completed,
  cancelled;

  String toWireValue() {
    switch (this) {
      case ExchangeStatus.initiated:
        return 'INITIATED';
      case ExchangeStatus.valuationPending:
        return 'VALUATION_PENDING';
      case ExchangeStatus.valuationApproved:
        return 'VALUATION_APPROVED';
      case ExchangeStatus.approved:
        return 'APPROVED';
      case ExchangeStatus.completed:
        return 'COMPLETED';
      case ExchangeStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static ExchangeStatus fromWire(String value) {
    switch (value) {
      case 'INITIATED':
        return ExchangeStatus.initiated;
      case 'VALUATION_PENDING':
        return ExchangeStatus.valuationPending;
      case 'VALUATION_APPROVED':
        return ExchangeStatus.valuationApproved;
      case 'APPROVED':
        return ExchangeStatus.approved;
      case 'COMPLETED':
        return ExchangeStatus.completed;
      case 'CANCELLED':
        return ExchangeStatus.cancelled;
      default:
        throw ArgumentError('Unknown ExchangeStatus: $value');
    }
  }
}

/// Adjustment direction for exchange financial settlement.
enum AdjustmentDirection {
  customerPays,
  customerReceives;

  String toWireValue() => this == AdjustmentDirection.customerPays
      ? 'CUSTOMER_PAYS'
      : 'CUSTOMER_RECEIVES';

  static AdjustmentDirection fromWire(String value) {
    switch (value) {
      case 'CUSTOMER_PAYS':
        return AdjustmentDirection.customerPays;
      case 'CUSTOMER_RECEIVES':
        return AdjustmentDirection.customerReceives;
      default:
        throw ArgumentError('Unknown AdjustmentDirection: $value');
    }
  }
}

/// A device exchange record.
@immutable
class Exchange {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String customerId;
  final String customerName;
  final ExchangeStatus status;
  final String oldDeviceImei;
  final String oldDeviceUnitId;
  final String oldDeviceBrand;
  final String oldDeviceModel;
  final String oldDeviceCondition;
  final Money oldDeviceValuation;
  final String newDeviceImei;
  final String newDeviceUnitId;
  final String newDeviceBrand;
  final String newDeviceModel;
  final Money newDeviceSalePrice;
  final Money adjustmentAmount;
  final AdjustmentDirection adjustmentDirection;
  final String? approvedBy;
  final String? approvedAt;
  final String? invoiceId;
  final String operationId;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const Exchange({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.oldDeviceImei,
    required this.oldDeviceUnitId,
    required this.oldDeviceBrand,
    required this.oldDeviceModel,
    required this.oldDeviceCondition,
    required this.oldDeviceValuation,
    required this.newDeviceImei,
    required this.newDeviceUnitId,
    required this.newDeviceBrand,
    required this.newDeviceModel,
    required this.newDeviceSalePrice,
    required this.adjustmentAmount,
    required this.adjustmentDirection,
    this.approvedBy,
    this.approvedAt,
    this.invoiceId,
    required this.operationId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Exchange.fromJson(Map<String, dynamic> json) => Exchange(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    customerId: json['customerId'] as String,
    customerName: json['customerName'] as String,
    status: ExchangeStatus.fromWire(json['status'] as String),
    oldDeviceImei: json['oldDeviceImei'] as String,
    oldDeviceUnitId: json['oldDeviceUnitId'] as String,
    oldDeviceBrand: json['oldDeviceBrand'] as String,
    oldDeviceModel: json['oldDeviceModel'] as String,
    oldDeviceCondition: json['oldDeviceCondition'] as String,
    oldDeviceValuation: Money.fromJson(
      json['oldDeviceValuation'] as Map<String, dynamic>,
    ),
    newDeviceImei: json['newDeviceImei'] as String,
    newDeviceUnitId: json['newDeviceUnitId'] as String,
    newDeviceBrand: json['newDeviceBrand'] as String,
    newDeviceModel: json['newDeviceModel'] as String,
    newDeviceSalePrice: Money.fromJson(
      json['newDeviceSalePrice'] as Map<String, dynamic>,
    ),
    adjustmentAmount: Money.fromJson(
      json['adjustmentAmount'] as Map<String, dynamic>,
    ),
    adjustmentDirection: AdjustmentDirection.fromWire(
      json['adjustmentDirection'] as String,
    ),
    approvedBy: json['approvedBy'] as String?,
    approvedAt: json['approvedAt'] as String?,
    invoiceId: json['invoiceId'] as String?,
    operationId: json['operationId'] as String,
    notes: json['notes'] as String?,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'entityId': entityId,
    'version': version,
    'dataModelVersion': dataModelVersion,
    'customerId': customerId,
    'customerName': customerName,
    'status': status.toWireValue(),
    'oldDeviceImei': oldDeviceImei,
    'oldDeviceUnitId': oldDeviceUnitId,
    'oldDeviceBrand': oldDeviceBrand,
    'oldDeviceModel': oldDeviceModel,
    'oldDeviceCondition': oldDeviceCondition,
    'oldDeviceValuation': oldDeviceValuation.toJson(),
    'newDeviceImei': newDeviceImei,
    'newDeviceUnitId': newDeviceUnitId,
    'newDeviceBrand': newDeviceBrand,
    'newDeviceModel': newDeviceModel,
    'newDeviceSalePrice': newDeviceSalePrice.toJson(),
    'adjustmentAmount': adjustmentAmount.toJson(),
    'adjustmentDirection': adjustmentDirection.toWireValue(),
    if (approvedBy != null) 'approvedBy': approvedBy,
    if (approvedAt != null) 'approvedAt': approvedAt,
    if (invoiceId != null) 'invoiceId': invoiceId,
    'operationId': operationId,
    if (notes != null) 'notes': notes,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
