/// Recharge Models (Dart)
///
/// SIM/recharge with provider-neutral request/response.
///
/// Requirements: 10.7–10.9; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';

/// Recharge status.
enum RechargeStatus {
  initiated,
  providerPending,
  success,
  failed,
  ambiguous,
  reconciled;

  String toWireValue() {
    switch (this) {
      case RechargeStatus.initiated:
        return 'INITIATED';
      case RechargeStatus.providerPending:
        return 'PROVIDER_PENDING';
      case RechargeStatus.success:
        return 'SUCCESS';
      case RechargeStatus.failed:
        return 'FAILED';
      case RechargeStatus.ambiguous:
        return 'AMBIGUOUS';
      case RechargeStatus.reconciled:
        return 'RECONCILED';
    }
  }

  static RechargeStatus fromWire(String value) {
    switch (value) {
      case 'INITIATED':
        return RechargeStatus.initiated;
      case 'PROVIDER_PENDING':
        return RechargeStatus.providerPending;
      case 'SUCCESS':
        return RechargeStatus.success;
      case 'FAILED':
        return RechargeStatus.failed;
      case 'AMBIGUOUS':
        return RechargeStatus.ambiguous;
      case 'RECONCILED':
        return RechargeStatus.reconciled;
      default:
        throw ArgumentError('Unknown RechargeStatus: $value');
    }
  }
}

/// Recharge type.
enum RechargeType {
  prepaid,
  postpaid,
  dataPack,
  dth,
  broadband;

  String toWireValue() {
    switch (this) {
      case RechargeType.prepaid:
        return 'PREPAID';
      case RechargeType.postpaid:
        return 'POSTPAID';
      case RechargeType.dataPack:
        return 'DATA_PACK';
      case RechargeType.dth:
        return 'DTH';
      case RechargeType.broadband:
        return 'BROADBAND';
    }
  }

  static RechargeType fromWire(String value) {
    switch (value) {
      case 'PREPAID':
        return RechargeType.prepaid;
      case 'POSTPAID':
        return RechargeType.postpaid;
      case 'DATA_PACK':
        return RechargeType.dataPack;
      case 'DTH':
        return RechargeType.dth;
      case 'BROADBAND':
        return RechargeType.broadband;
      default:
        throw ArgumentError('Unknown RechargeType: $value');
    }
  }
}

/// A persisted recharge record.
@immutable
class RechargeRecord {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String mobileNumber;
  final RechargeType rechargeType;
  final String provider;
  final String planId;
  final Money amount;
  final RechargeStatus status;
  final String providerRequestId;
  final String? providerTransactionId;
  final String? failureReason;
  final Money? commissionAmount;
  final String initiatedAt;
  final String? completedAt;
  final String? customerId;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const RechargeRecord({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.mobileNumber,
    required this.rechargeType,
    required this.provider,
    required this.planId,
    required this.amount,
    required this.status,
    required this.providerRequestId,
    this.providerTransactionId,
    this.failureReason,
    this.commissionAmount,
    required this.initiatedAt,
    this.completedAt,
    this.customerId,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RechargeRecord.fromJson(Map<String, dynamic> json) => RechargeRecord(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    mobileNumber: json['mobileNumber'] as String,
    rechargeType: RechargeType.fromWire(json['rechargeType'] as String),
    provider: json['provider'] as String,
    planId: json['planId'] as String,
    amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
    status: RechargeStatus.fromWire(json['status'] as String),
    providerRequestId: json['providerRequestId'] as String,
    providerTransactionId: json['providerTransactionId'] as String?,
    failureReason: json['failureReason'] as String?,
    commissionAmount: json['commissionAmount'] != null
        ? Money.fromJson(json['commissionAmount'] as Map<String, dynamic>)
        : null,
    initiatedAt: json['initiatedAt'] as String,
    completedAt: json['completedAt'] as String?,
    customerId: json['customerId'] as String?,
    operationId: json['operationId'] as String,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'entityId': entityId,
    'version': version,
    'dataModelVersion': dataModelVersion,
    'mobileNumber': mobileNumber,
    'rechargeType': rechargeType.toWireValue(),
    'provider': provider,
    'planId': planId,
    'amount': amount.toJson(),
    'status': status.toWireValue(),
    'providerRequestId': providerRequestId,
    if (providerTransactionId != null)
      'providerTransactionId': providerTransactionId,
    if (failureReason != null) 'failureReason': failureReason,
    if (commissionAmount != null)
      'commissionAmount': commissionAmount!.toJson(),
    'initiatedAt': initiatedAt,
    if (completedAt != null) 'completedAt': completedAt,
    if (customerId != null) 'customerId': customerId,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
