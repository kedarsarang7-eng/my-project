/// Reservation Models (Dart)
///
/// Reservation claim with IMEI binding and expiry.
///
/// Requirements: 4.6; GR-2
library;

import 'package:flutter/foundation.dart';
import 'common_models.dart';

/// Reservation status.
enum ReservationStatus {
  active,
  converted,
  expired,
  cancelled;

  String toWireValue() => name.toUpperCase();

  static ReservationStatus fromWire(String value) {
    switch (value) {
      case 'ACTIVE':
        return ReservationStatus.active;
      case 'CONVERTED':
        return ReservationStatus.converted;
      case 'EXPIRED':
        return ReservationStatus.expired;
      case 'CANCELLED':
        return ReservationStatus.cancelled;
      default:
        throw ArgumentError('Unknown ReservationStatus: $value');
    }
  }
}

/// A device reservation claim.
@immutable
class Reservation {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String imei;
  final String unitId;
  final String customerId;
  final String customerName;
  final ReservationStatus status;
  final String reservedAt;
  final String expiresAt;
  final Money? depositAmount;
  final bool? depositCollected;
  final String? convertedInvoiceId;
  final String? notes;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const Reservation({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.imei,
    required this.unitId,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.reservedAt,
    required this.expiresAt,
    this.depositAmount,
    this.depositCollected,
    this.convertedInvoiceId,
    this.notes,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    imei: json['imei'] as String,
    unitId: json['unitId'] as String,
    customerId: json['customerId'] as String,
    customerName: json['customerName'] as String,
    status: ReservationStatus.fromWire(json['status'] as String),
    reservedAt: json['reservedAt'] as String,
    expiresAt: json['expiresAt'] as String,
    depositAmount: json['depositAmount'] != null
        ? Money.fromJson(json['depositAmount'] as Map<String, dynamic>)
        : null,
    depositCollected: json['depositCollected'] as bool?,
    convertedInvoiceId: json['convertedInvoiceId'] as String?,
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
    'reservedAt': reservedAt,
    'expiresAt': expiresAt,
    if (depositAmount != null) 'depositAmount': depositAmount!.toJson(),
    if (depositCollected != null) 'depositCollected': depositCollected,
    if (convertedInvoiceId != null) 'convertedInvoiceId': convertedInvoiceId,
    if (notes != null) 'notes': notes,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
