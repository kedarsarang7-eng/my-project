/// IMEI Unit Models (Dart)
///
/// Represents a tenant-scoped device unit with lifecycle state,
/// version, condition, ownership, valuation, warranty, and tenant binding.
///
/// Requirements: 3.3–3.8, 4.1, 4.5–4.9; GR-2
library;

import 'package:flutter/foundation.dart';
import 'catalogue_models.dart';
import 'common_models.dart';

/// Canonical lifecycle states for an IMEI unit.
enum DeviceLifecycleState {
  inStock,
  secondHand,
  reserved,
  salePending,
  sold,
  returned,
  demo,
  inService,
  exchanged,
  damaged,
  retired;

  String toWireValue() {
    switch (this) {
      case DeviceLifecycleState.inStock:
        return 'IN_STOCK';
      case DeviceLifecycleState.secondHand:
        return 'SECOND_HAND';
      case DeviceLifecycleState.reserved:
        return 'RESERVED';
      case DeviceLifecycleState.salePending:
        return 'SALE_PENDING';
      case DeviceLifecycleState.sold:
        return 'SOLD';
      case DeviceLifecycleState.returned:
        return 'RETURNED';
      case DeviceLifecycleState.demo:
        return 'DEMO';
      case DeviceLifecycleState.inService:
        return 'IN_SERVICE';
      case DeviceLifecycleState.exchanged:
        return 'EXCHANGED';
      case DeviceLifecycleState.damaged:
        return 'DAMAGED';
      case DeviceLifecycleState.retired:
        return 'RETIRED';
    }
  }

  static DeviceLifecycleState fromWire(String value) {
    switch (value) {
      case 'IN_STOCK':
        return DeviceLifecycleState.inStock;
      case 'SECOND_HAND':
        return DeviceLifecycleState.secondHand;
      case 'RESERVED':
        return DeviceLifecycleState.reserved;
      case 'SALE_PENDING':
        return DeviceLifecycleState.salePending;
      case 'SOLD':
        return DeviceLifecycleState.sold;
      case 'RETURNED':
        return DeviceLifecycleState.returned;
      case 'DEMO':
        return DeviceLifecycleState.demo;
      case 'IN_SERVICE':
        return DeviceLifecycleState.inService;
      case 'EXCHANGED':
        return DeviceLifecycleState.exchanged;
      case 'DAMAGED':
        return DeviceLifecycleState.damaged;
      case 'RETIRED':
        return DeviceLifecycleState.retired;
      default:
        throw ArgumentError('Unknown DeviceLifecycleState: $value');
    }
  }
}

/// Physical condition of the device.
enum DeviceCondition {
  newDevice,
  likeNew,
  good,
  fair,
  poor,
  damaged;

  String toWireValue() {
    switch (this) {
      case DeviceCondition.newDevice:
        return 'NEW';
      case DeviceCondition.likeNew:
        return 'LIKE_NEW';
      case DeviceCondition.good:
        return 'GOOD';
      case DeviceCondition.fair:
        return 'FAIR';
      case DeviceCondition.poor:
        return 'POOR';
      case DeviceCondition.damaged:
        return 'DAMAGED';
    }
  }

  static DeviceCondition fromWire(String value) {
    switch (value) {
      case 'NEW':
        return DeviceCondition.newDevice;
      case 'LIKE_NEW':
        return DeviceCondition.likeNew;
      case 'GOOD':
        return DeviceCondition.good;
      case 'FAIR':
        return DeviceCondition.fair;
      case 'POOR':
        return DeviceCondition.poor;
      case 'DAMAGED':
        return DeviceCondition.damaged;
      default:
        throw ArgumentError('Unknown DeviceCondition: $value');
    }
  }
}

/// How the device was acquired.
enum OwnershipSource {
  purchasedNew,
  secondHandIntake,
  exchangeIn,
  returnSource,
  demoAllocation,
  transfer;

  String toWireValue() {
    switch (this) {
      case OwnershipSource.purchasedNew:
        return 'PURCHASED_NEW';
      case OwnershipSource.secondHandIntake:
        return 'SECOND_HAND_INTAKE';
      case OwnershipSource.exchangeIn:
        return 'EXCHANGE_IN';
      case OwnershipSource.returnSource:
        return 'RETURN';
      case OwnershipSource.demoAllocation:
        return 'DEMO_ALLOCATION';
      case OwnershipSource.transfer:
        return 'TRANSFER';
    }
  }

  static OwnershipSource fromWire(String value) {
    switch (value) {
      case 'PURCHASED_NEW':
        return OwnershipSource.purchasedNew;
      case 'SECOND_HAND_INTAKE':
        return OwnershipSource.secondHandIntake;
      case 'EXCHANGE_IN':
        return OwnershipSource.exchangeIn;
      case 'RETURN':
        return OwnershipSource.returnSource;
      case 'DEMO_ALLOCATION':
        return OwnershipSource.demoAllocation;
      case 'TRANSFER':
        return OwnershipSource.transfer;
      default:
        throw ArgumentError('Unknown OwnershipSource: $value');
    }
  }
}

/// An IMEI Unit — one physical handset in tenant inventory.
@immutable
class ImeiUnit {
  final String tenantId;
  final String entityId;
  final int version;
  final int dataModelVersion;
  final String imei;
  final DeviceLifecycleState lifecycleState;
  final DeviceCondition condition;
  final OwnershipSource ownershipSource;
  final String brand;
  final String model;
  final String? color;
  final String? storage;
  final Money acquisitionCost;
  final Money salePrice;
  final Money? marketValuation;
  final String? warrantyStartDate;
  final String? warrantyEndDate;
  final String? warrantyProvider;
  final String? customerId;
  final String? saleInvoiceId;
  final String? soldAt;
  final String? supplierId;
  final String? exchangeId;
  final String? intakeId;
  final List<EvidenceReference>? evidenceRefs;
  final MobileHandsetCatalogueAttributes? handsetAttributes;
  final String createdAt;
  final String updatedAt;

  const ImeiUnit({
    required this.tenantId,
    required this.entityId,
    required this.version,
    required this.dataModelVersion,
    required this.imei,
    required this.lifecycleState,
    required this.condition,
    required this.ownershipSource,
    required this.brand,
    required this.model,
    this.color,
    this.storage,
    required this.acquisitionCost,
    required this.salePrice,
    this.marketValuation,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.warrantyProvider,
    this.customerId,
    this.saleInvoiceId,
    this.soldAt,
    this.supplierId,
    this.exchangeId,
    this.intakeId,
    this.evidenceRefs,
    this.handsetAttributes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ImeiUnit.fromJson(Map<String, dynamic> json) => ImeiUnit(
    tenantId: json['tenantId'] as String,
    entityId: json['entityId'] as String,
    version: json['version'] as int,
    dataModelVersion: json['dataModelVersion'] as int,
    imei: json['imei'] as String,
    lifecycleState: DeviceLifecycleState.fromWire(
      json['lifecycleState'] as String,
    ),
    condition: DeviceCondition.fromWire(json['condition'] as String),
    ownershipSource: OwnershipSource.fromWire(
      json['ownershipSource'] as String,
    ),
    brand: json['brand'] as String,
    model: json['model'] as String,
    color: json['color'] as String?,
    storage: json['storage'] as String?,
    acquisitionCost: Money.fromJson(
      json['acquisitionCost'] as Map<String, dynamic>,
    ),
    salePrice: Money.fromJson(json['salePrice'] as Map<String, dynamic>),
    marketValuation: json['marketValuation'] != null
        ? Money.fromJson(json['marketValuation'] as Map<String, dynamic>)
        : null,
    warrantyStartDate: json['warrantyStartDate'] as String?,
    warrantyEndDate: json['warrantyEndDate'] as String?,
    warrantyProvider: json['warrantyProvider'] as String?,
    customerId: json['customerId'] as String?,
    saleInvoiceId: json['saleInvoiceId'] as String?,
    soldAt: json['soldAt'] as String?,
    supplierId: json['supplierId'] as String?,
    exchangeId: json['exchangeId'] as String?,
    intakeId: json['intakeId'] as String?,
    evidenceRefs: (json['evidenceRefs'] as List<dynamic>?)
        ?.map((e) => EvidenceReference.fromJson(e as Map<String, dynamic>))
        .toList(),
    handsetAttributes: json['handsetAttributes'] != null
        ? MobileHandsetCatalogueAttributes.fromJson(
            json['handsetAttributes'] as Map<String, dynamic>,
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
    'imei': imei,
    'lifecycleState': lifecycleState.toWireValue(),
    'condition': condition.toWireValue(),
    'ownershipSource': ownershipSource.toWireValue(),
    'brand': brand,
    'model': model,
    if (color != null) 'color': color,
    if (storage != null) 'storage': storage,
    'acquisitionCost': acquisitionCost.toJson(),
    'salePrice': salePrice.toJson(),
    if (marketValuation != null) 'marketValuation': marketValuation!.toJson(),
    if (warrantyStartDate != null) 'warrantyStartDate': warrantyStartDate,
    if (warrantyEndDate != null) 'warrantyEndDate': warrantyEndDate,
    if (warrantyProvider != null) 'warrantyProvider': warrantyProvider,
    if (customerId != null) 'customerId': customerId,
    if (saleInvoiceId != null) 'saleInvoiceId': saleInvoiceId,
    if (soldAt != null) 'soldAt': soldAt,
    if (supplierId != null) 'supplierId': supplierId,
    if (exchangeId != null) 'exchangeId': exchangeId,
    if (intakeId != null) 'intakeId': intakeId,
    if (evidenceRefs != null)
      'evidenceRefs': evidenceRefs!.map((e) => e.toJson()).toList(),
    if (handsetAttributes != null)
      'handsetAttributes': handsetAttributes!.toJson(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
