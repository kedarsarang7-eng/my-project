/// Invoice Models (Dart)
///
/// Invoice and invoice-device-line association DTOs.
///
/// Requirements: 3.3–3.4, 4.8; GR-2
library;

import 'package:flutter/foundation.dart';
import 'catalogue_models.dart';
import 'common_models.dart';

/// Invoice status.
enum InvoiceStatus {
  draft,
  pendingSync,
  committed,
  acceptedPending,
  cancelled,
  returned;

  String toWireValue() {
    switch (this) {
      case InvoiceStatus.draft:
        return 'DRAFT';
      case InvoiceStatus.pendingSync:
        return 'PENDING_SYNC';
      case InvoiceStatus.committed:
        return 'COMMITTED';
      case InvoiceStatus.acceptedPending:
        return 'ACCEPTED_PENDING';
      case InvoiceStatus.cancelled:
        return 'CANCELLED';
      case InvoiceStatus.returned:
        return 'RETURNED';
    }
  }

  static InvoiceStatus fromWire(String value) {
    switch (value) {
      case 'DRAFT':
        return InvoiceStatus.draft;
      case 'PENDING_SYNC':
        return InvoiceStatus.pendingSync;
      case 'COMMITTED':
        return InvoiceStatus.committed;
      case 'ACCEPTED_PENDING':
        return InvoiceStatus.acceptedPending;
      case 'CANCELLED':
        return InvoiceStatus.cancelled;
      case 'RETURNED':
        return InvoiceStatus.returned;
      default:
        throw ArgumentError('Unknown InvoiceStatus: $value');
    }
  }
}

/// Line item type.
enum InvoiceLineType {
  device,
  accessory;

  String toWireValue() =>
      this == InvoiceLineType.device ? 'DEVICE' : 'ACCESSORY';

  static InvoiceLineType fromWire(String value) {
    switch (value) {
      case 'DEVICE':
        return InvoiceLineType.device;
      case 'ACCESSORY':
        return InvoiceLineType.accessory;
      default:
        throw ArgumentError('Unknown InvoiceLineType: $value');
    }
  }
}

/// A tenant-scoped invoice.
@immutable
class Invoice {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String invoiceNumber;
  final InvoiceStatus status;
  final String customerId;
  final String customerName;
  final Money totalAmount;
  final Money taxAmount;
  final Money discountAmount;
  final Money netAmount;
  final String? paymentMethod;
  final String? paymentReference;
  final String invoiceDate;
  final String? dueDate;
  final String? notes;
  final String operationId;
  final String createdAt;
  final String updatedAt;

  const Invoice({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.invoiceNumber,
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    required this.taxAmount,
    required this.discountAmount,
    required this.netAmount,
    this.paymentMethod,
    this.paymentReference,
    required this.invoiceDate,
    this.dueDate,
    this.notes,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    invoiceNumber: json['invoiceNumber'] as String,
    status: InvoiceStatus.fromWire(json['status'] as String),
    customerId: json['customerId'] as String,
    customerName: json['customerName'] as String,
    totalAmount: Money.fromJson(json['totalAmount'] as Map<String, dynamic>),
    taxAmount: Money.fromJson(json['taxAmount'] as Map<String, dynamic>),
    discountAmount: Money.fromJson(
      json['discountAmount'] as Map<String, dynamic>,
    ),
    netAmount: Money.fromJson(json['netAmount'] as Map<String, dynamic>),
    paymentMethod: json['paymentMethod'] as String?,
    paymentReference: json['paymentReference'] as String?,
    invoiceDate: json['invoiceDate'] as String,
    dueDate: json['dueDate'] as String?,
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
    'invoiceNumber': invoiceNumber,
    'status': status.toWireValue(),
    'customerId': customerId,
    'customerName': customerName,
    'totalAmount': totalAmount.toJson(),
    'taxAmount': taxAmount.toJson(),
    'discountAmount': discountAmount.toJson(),
    'netAmount': netAmount.toJson(),
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (paymentReference != null) 'paymentReference': paymentReference,
    'invoiceDate': invoiceDate,
    if (dueDate != null) 'dueDate': dueDate,
    if (notes != null) 'notes': notes,
    'operationId': operationId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// A device line linking an invoice to an IMEI unit.
@immutable
class InvoiceDeviceLine {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String invoiceId;
  final InvoiceLineType lineType;
  final String? imei;
  final String? unitId;
  final String description;
  final String? brand;
  final String? model;
  final int quantity;
  final Money unitPrice;
  final Money lineTax;
  final Money lineDiscount;
  final Money lineTotal;
  final String? hsnCode;
  final int? taxRateBasisPoints;
  final int? warrantyMonths;
  final String? parentLineId;
  final MobileAccessoryCatalogueAttributes? accessoryAttributes;
  final String createdAt;
  final String updatedAt;

  const InvoiceDeviceLine({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.invoiceId,
    required this.lineType,
    this.imei,
    this.unitId,
    required this.description,
    this.brand,
    this.model,
    required this.quantity,
    required this.unitPrice,
    required this.lineTax,
    required this.lineDiscount,
    required this.lineTotal,
    this.hsnCode,
    this.taxRateBasisPoints,
    this.warrantyMonths,
    this.parentLineId,
    this.accessoryAttributes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvoiceDeviceLine.fromJson(Map<String, dynamic> json) =>
      InvoiceDeviceLine(
        tenantId: json['tenantId'] as String,
        entityId: json['entityId'] as String,
        version: json['version'] as int,
        dataModelVersion: json['dataModelVersion'] as int,
        invoiceId: json['invoiceId'] as String,
        lineType: InvoiceLineType.fromWire(json['lineType'] as String),
        imei: json['imei'] as String?,
        unitId: json['unitId'] as String?,
        description: json['description'] as String,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        quantity: json['quantity'] as int,
        unitPrice: Money.fromJson(json['unitPrice'] as Map<String, dynamic>),
        lineTax: Money.fromJson(json['lineTax'] as Map<String, dynamic>),
        lineDiscount: Money.fromJson(
          json['lineDiscount'] as Map<String, dynamic>,
        ),
        lineTotal: Money.fromJson(json['lineTotal'] as Map<String, dynamic>),
        hsnCode: json['hsnCode'] as String?,
        taxRateBasisPoints: json['taxRateBasisPoints'] as int?,
        warrantyMonths: json['warrantyMonths'] as int?,
        parentLineId: json['parentLineId'] as String?,
        accessoryAttributes: json['accessoryAttributes'] != null
            ? MobileAccessoryCatalogueAttributes.fromJson(
                json['accessoryAttributes'] as Map<String, dynamic>,
              )
            : null,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'entityId': entityId,
    'version': version,
    'dataModelVersion': dataModelVersion,
    'invoiceId': invoiceId,
    'lineType': lineType.toWireValue(),
    if (imei != null) 'imei': imei,
    if (unitId != null) 'unitId': unitId,
    'description': description,
    if (brand != null) 'brand': brand,
    if (model != null) 'model': model,
    'quantity': quantity,
    'unitPrice': unitPrice.toJson(),
    'lineTax': lineTax.toJson(),
    'lineDiscount': lineDiscount.toJson(),
    'lineTotal': lineTotal.toJson(),
    if (hsnCode != null) 'hsnCode': hsnCode,
    if (taxRateBasisPoints != null) 'taxRateBasisPoints': taxRateBasisPoints,
    if (warrantyMonths != null) 'warrantyMonths': warrantyMonths,
    if (parentLineId != null) 'parentLineId': parentLineId,
    if (accessoryAttributes != null)
      'accessoryAttributes': accessoryAttributes!.toJson(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
