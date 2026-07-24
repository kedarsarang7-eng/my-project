/// IMEI Unit — Domain Model (Dart)
///
/// Pure domain model for a tenant-scoped IMEI unit with lifecycle state,
/// version, condition, ownership, valuation, warranty, and associations.
/// Provides a factory for initial creation and an event-based state transition.
///
/// Requirements: 3.5–3.6, 3.10–3.11, 4.1, 4.5–4.7, 4.9, 5.2–5.4
library;

import 'package:flutter/foundation.dart';
import '../models/common_models.dart';
import 'device_lifecycle.dart';

// ─── Device Condition ────────────────────────────────────────────────────────

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

// ─── Ownership Source ────────────────────────────────────────────────────────

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

// ─── IMEI Unit Domain Model ──────────────────────────────────────────────────

/// Current data model version for IMEI units.
const int currentImeiUnitDataModelVersion = 1;

/// Immutable domain representation of a tenant-scoped IMEI unit.
/// Mutations produce a new instance via [applyTransition].
@immutable
class ImeiUnit implements TransitionableUnit {
  final String tenantId;
  final String entityId;
  @override
  final int version;
  final int dataModelVersion;
  final String imei;
  @override
  final DeviceLifecycleState lifecycleState;
  final DeviceCondition condition;
  final OwnershipSource ownershipSource;
  final String brand;
  final String model;
  final String? color;
  final String? storage;

  // Valuation
  final Money acquisitionCost;
  final Money salePrice;
  final Money? marketValuation;

  // Warranty
  final String? warrantyStartDate;
  final String? warrantyEndDate;
  final String? warrantyProvider;

  // Associations
  final String? customerId;
  final String? saleInvoiceId;
  final String? soldAt;
  final String? supplierId;
  final String? exchangeId;
  final String? intakeId;

  // Evidence
  final List<EvidenceReference>? evidenceRefs;

  // Timestamps
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
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy with updated fields.
  ImeiUnit copyWith({
    String? tenantId,
    String? entityId,
    int? version,
    int? dataModelVersion,
    String? imei,
    DeviceLifecycleState? lifecycleState,
    DeviceCondition? condition,
    OwnershipSource? ownershipSource,
    String? brand,
    String? model,
    String? color,
    String? storage,
    Money? acquisitionCost,
    Money? salePrice,
    Money? marketValuation,
    String? warrantyStartDate,
    String? warrantyEndDate,
    String? warrantyProvider,
    String? customerId,
    String? saleInvoiceId,
    String? soldAt,
    String? supplierId,
    String? exchangeId,
    String? intakeId,
    List<EvidenceReference>? evidenceRefs,
    String? createdAt,
    String? updatedAt,
  }) {
    return ImeiUnit(
      tenantId: tenantId ?? this.tenantId,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      dataModelVersion: dataModelVersion ?? this.dataModelVersion,
      imei: imei ?? this.imei,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      condition: condition ?? this.condition,
      ownershipSource: ownershipSource ?? this.ownershipSource,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      storage: storage ?? this.storage,
      acquisitionCost: acquisitionCost ?? this.acquisitionCost,
      salePrice: salePrice ?? this.salePrice,
      marketValuation: marketValuation ?? this.marketValuation,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      warrantyProvider: warrantyProvider ?? this.warrantyProvider,
      customerId: customerId ?? this.customerId,
      saleInvoiceId: saleInvoiceId ?? this.saleInvoiceId,
      soldAt: soldAt ?? this.soldAt,
      supplierId: supplierId ?? this.supplierId,
      exchangeId: exchangeId ?? this.exchangeId,
      intakeId: intakeId ?? this.intakeId,
      evidenceRefs: evidenceRefs ?? this.evidenceRefs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─── Factory Parameters ──────────────────────────────────────────────────────

/// Parameters for creating a new IMEI unit.
/// Initial state is either IN_STOCK (new devices) or SECOND_HAND (used intake).
@immutable
class CreateImeiUnitParams {
  final String tenantId;
  final String entityId;
  final String imei;
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
  final String? supplierId;
  final String? exchangeId;
  final String? intakeId;
  final List<EvidenceReference>? evidenceRefs;

  /// Whether this is a second-hand intake (initial state: SECOND_HAND).
  final bool isSecondHand;
  final int? dataModelVersion;

  const CreateImeiUnitParams({
    required this.tenantId,
    required this.entityId,
    required this.imei,
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
    this.supplierId,
    this.exchangeId,
    this.intakeId,
    this.evidenceRefs,
    this.isSecondHand = false,
    this.dataModelVersion,
  });
}

// ─── Factory ─────────────────────────────────────────────────────────────────

/// Creates a new IMEI unit with initial state.
/// - New devices start as IN_STOCK
/// - Second-hand intake devices start as SECOND_HAND
ImeiUnit createImeiUnit(CreateImeiUnitParams params) {
  final now = DateTime.now().toUtc().toIso8601String();
  final initialState = params.isSecondHand
      ? DeviceLifecycleState.secondHand
      : DeviceLifecycleState.inStock;

  return ImeiUnit(
    tenantId: params.tenantId,
    entityId: params.entityId,
    version: 1,
    dataModelVersion:
        params.dataModelVersion ?? currentImeiUnitDataModelVersion,
    imei: params.imei,
    lifecycleState: initialState,
    condition: params.condition,
    ownershipSource: params.ownershipSource,
    brand: params.brand,
    model: params.model,
    color: params.color,
    storage: params.storage,
    acquisitionCost: params.acquisitionCost,
    salePrice: params.salePrice,
    marketValuation: params.marketValuation,
    warrantyStartDate: params.warrantyStartDate,
    warrantyEndDate: params.warrantyEndDate,
    warrantyProvider: params.warrantyProvider,
    supplierId: params.supplierId,
    exchangeId: params.exchangeId,
    intakeId: params.intakeId,
    evidenceRefs: params.evidenceRefs,
    createdAt: now,
    updatedAt: now,
  );
}

// ─── Apply Transition ────────────────────────────────────────────────────────

/// Applies a validated lifecycle event to an IMEI unit, producing a new
/// immutable version with updated state and version number.
///
/// This function does NOT validate the transition — that responsibility
/// belongs to [validateTransition] in device_lifecycle.dart. This function
/// assumes the event has already been validated.
ImeiUnit applyTransition(ImeiUnit unit, DeviceLifecycleEvent event) {
  return unit.copyWith(
    lifecycleState: event.newState,
    version: event.newVersion,
    updatedAt: event.occurredAt,
  );
}
