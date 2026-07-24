/// Finance Models (Dart)
///
/// Finance plan, EMI details, and provider tracking.
///
/// Requirements: 10.4–10.6; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';

/// Finance plan status.
enum FinancePlanStatus {
  applied,
  approved,
  active,
  completed,
  defaulted,
  cancelled;

  String toWireValue() => name.toUpperCase();

  static FinancePlanStatus fromWire(String value) {
    switch (value) {
      case 'APPLIED':
        return FinancePlanStatus.applied;
      case 'APPROVED':
        return FinancePlanStatus.approved;
      case 'ACTIVE':
        return FinancePlanStatus.active;
      case 'COMPLETED':
        return FinancePlanStatus.completed;
      case 'DEFAULTED':
        return FinancePlanStatus.defaulted;
      case 'CANCELLED':
        return FinancePlanStatus.cancelled;
      default:
        throw ArgumentError('Unknown FinancePlanStatus: $value');
    }
  }
}

/// EMI status for individual installments.
enum EmiStatus {
  upcoming,
  due,
  paid,
  overdue,
  waived;

  String toWireValue() => name.toUpperCase();

  static EmiStatus fromWire(String value) {
    switch (value) {
      case 'UPCOMING':
        return EmiStatus.upcoming;
      case 'DUE':
        return EmiStatus.due;
      case 'PAID':
        return EmiStatus.paid;
      case 'OVERDUE':
        return EmiStatus.overdue;
      case 'WAIVED':
        return EmiStatus.waived;
      default:
        throw ArgumentError('Unknown EmiStatus: $value');
    }
  }
}

/// A finance plan for a device purchase.
@immutable
class FinancePlan {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String customerId;
  final String customerName;
  final String invoiceId;
  final String imei;
  final String unitId;
  final FinancePlanStatus status;
  final String provider;
  final String? providerReference;
  final String? providerRequestId;
  final Money principalAmount;
  final Money downPayment;
  final int interestRateBasisPoints;
  final int tenureMonths;
  final Money emiAmount;
  final Money totalPayable;
  final String startDate;
  final String endDate;
  final String? approvedBy;
  final String? approvedAt;
  final String? notes;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const FinancePlan({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.customerId,
    required this.customerName,
    required this.invoiceId,
    required this.imei,
    required this.unitId,
    required this.status,
    required this.provider,
    this.providerReference,
    this.providerRequestId,
    required this.principalAmount,
    required this.downPayment,
    required this.interestRateBasisPoints,
    required this.tenureMonths,
    required this.emiAmount,
    required this.totalPayable,
    required this.startDate,
    required this.endDate,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinancePlan.fromJson(Map<String, dynamic> json) => FinancePlan(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    customerId: json['customerId'] as String,
    customerName: json['customerName'] as String,
    invoiceId: json['invoiceId'] as String,
    imei: json['imei'] as String,
    unitId: json['unitId'] as String,
    status: FinancePlanStatus.fromWire(json['status'] as String),
    provider: json['provider'] as String,
    providerReference: json['providerReference'] as String?,
    providerRequestId: json['providerRequestId'] as String?,
    principalAmount: Money.fromJson(
      json['principalAmount'] as Map<String, dynamic>,
    ),
    downPayment: Money.fromJson(json['downPayment'] as Map<String, dynamic>),
    interestRateBasisPoints: json['interestRateBasisPoints'] as int,
    tenureMonths: json['tenureMonths'] as int,
    emiAmount: Money.fromJson(json['emiAmount'] as Map<String, dynamic>),
    totalPayable: Money.fromJson(json['totalPayable'] as Map<String, dynamic>),
    startDate: json['startDate'] as String,
    endDate: json['endDate'] as String,
    approvedBy: json['approvedBy'] as String?,
    approvedAt: json['approvedAt'] as String?,
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
    'customerId': customerId,
    'customerName': customerName,
    'invoiceId': invoiceId,
    'imei': imei,
    'unitId': unitId,
    'status': status.toWireValue(),
    'provider': provider,
    if (providerReference != null) 'providerReference': providerReference,
    if (providerRequestId != null) 'providerRequestId': providerRequestId,
    'principalAmount': principalAmount.toJson(),
    'downPayment': downPayment.toJson(),
    'interestRateBasisPoints': interestRateBasisPoints,
    'tenureMonths': tenureMonths,
    'emiAmount': emiAmount.toJson(),
    'totalPayable': totalPayable.toJson(),
    'startDate': startDate,
    'endDate': endDate,
    if (approvedBy != null) 'approvedBy': approvedBy,
    if (approvedAt != null) 'approvedAt': approvedAt,
    if (notes != null) 'notes': notes,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// An individual EMI installment.
@immutable
class EmiInstallment {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String financePlanId;
  final int installmentNumber;
  final String dueDate;
  final Money amount;
  final EmiStatus status;
  final String? paidAt;
  final String? paymentReference;
  final String createdAt;
  final String updatedAt;

  const EmiInstallment({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.financePlanId,
    required this.installmentNumber,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidAt,
    this.paymentReference,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmiInstallment.fromJson(Map<String, dynamic> json) => EmiInstallment(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    financePlanId: json['financePlanId'] as String,
    installmentNumber: json['installmentNumber'] as int,
    dueDate: json['dueDate'] as String,
    amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
    status: EmiStatus.fromWire(json['status'] as String),
    paidAt: json['paidAt'] as String?,
    paymentReference: json['paymentReference'] as String?,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'entityId': entityId,
    'version': version,
    'dataModelVersion': dataModelVersion,
    'financePlanId': financePlanId,
    'installmentNumber': installmentNumber,
    'dueDate': dueDate,
    'amount': amount.toJson(),
    'status': status.toWireValue(),
    if (paidAt != null) 'paidAt': paidAt,
    if (paymentReference != null) 'paymentReference': paymentReference,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
