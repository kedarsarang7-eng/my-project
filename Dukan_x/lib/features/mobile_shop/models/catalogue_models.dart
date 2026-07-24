/// Mobile Catalogue Models (Dart)
///
/// Defines handset-specific catalogue attributes and accessory relationship
/// models. These enrich the IMEI unit with structured hardware specifications
/// and link accessories to their parent handset for bundle reporting.
///
/// Non-mobile catalogues (grocery, hardware, etc.) are unaffected.
///
/// Requirements: 4.8, 9.11
library;

import 'package:flutter/foundation.dart';

/// Operating system families for mobile devices.
enum MobileOperatingSystem {
  android,
  ios,
  harmonyOs,
  kaiOs,
  other;

  String toWireValue() {
    switch (this) {
      case MobileOperatingSystem.android:
        return 'ANDROID';
      case MobileOperatingSystem.ios:
        return 'IOS';
      case MobileOperatingSystem.harmonyOs:
        return 'HARMONY_OS';
      case MobileOperatingSystem.kaiOs:
        return 'KAI_OS';
      case MobileOperatingSystem.other:
        return 'OTHER';
    }
  }

  static MobileOperatingSystem fromWire(String value) {
    switch (value) {
      case 'ANDROID':
        return MobileOperatingSystem.android;
      case 'IOS':
        return MobileOperatingSystem.ios;
      case 'HARMONY_OS':
        return MobileOperatingSystem.harmonyOs;
      case 'KAI_OS':
        return MobileOperatingSystem.kaiOs;
      case 'OTHER':
        return MobileOperatingSystem.other;
      default:
        throw ArgumentError('Unknown MobileOperatingSystem: $value');
    }
  }
}

/// Accessory type categorization.
enum AccessoryType {
  protectiveCase,
  screenProtector,
  charger,
  cable,
  earphone,
  powerBank,
  memoryCard,
  stylus,
  mount,
  other;

  String toWireValue() {
    switch (this) {
      case AccessoryType.protectiveCase:
        return 'PROTECTIVE_CASE';
      case AccessoryType.screenProtector:
        return 'SCREEN_PROTECTOR';
      case AccessoryType.charger:
        return 'CHARGER';
      case AccessoryType.cable:
        return 'CABLE';
      case AccessoryType.earphone:
        return 'EARPHONE';
      case AccessoryType.powerBank:
        return 'POWER_BANK';
      case AccessoryType.memoryCard:
        return 'MEMORY_CARD';
      case AccessoryType.stylus:
        return 'STYLUS';
      case AccessoryType.mount:
        return 'MOUNT';
      case AccessoryType.other:
        return 'OTHER';
    }
  }

  static AccessoryType fromWire(String value) {
    switch (value) {
      case 'PROTECTIVE_CASE':
        return AccessoryType.protectiveCase;
      case 'SCREEN_PROTECTOR':
        return AccessoryType.screenProtector;
      case 'CHARGER':
        return AccessoryType.charger;
      case 'CABLE':
        return AccessoryType.cable;
      case 'EARPHONE':
        return AccessoryType.earphone;
      case 'POWER_BANK':
        return AccessoryType.powerBank;
      case 'MEMORY_CARD':
        return AccessoryType.memoryCard;
      case 'STYLUS':
        return AccessoryType.stylus;
      case 'MOUNT':
        return AccessoryType.mount;
      case 'OTHER':
        return AccessoryType.other;
      default:
        throw ArgumentError('Unknown AccessoryType: $value');
    }
  }
}

/// Handset-specific catalogue attributes.
///
/// These extend the base IMEI unit with structured hardware specifications
/// for mobile handsets. They are only applicable to `mobile_shop` tenants
/// and do not affect any other business type's catalogue model.
@immutable
class MobileHandsetCatalogueAttributes {
  /// RAM in megabytes (e.g. 8192 for 8 GB).
  final int? ramMb;

  /// Internal storage in megabytes (e.g. 131072 for 128 GB).
  final int? storageMb;

  /// Screen size in inches * 10 for integer precision (e.g. 67 for 6.7").
  final int? screenSizeTenths;

  /// Operating system.
  final MobileOperatingSystem? operatingSystem;

  /// OS version string (e.g. "14", "Android 14").
  final String? osVersion;

  /// Chipset / SoC name (e.g. "Snapdragon 8 Gen 3").
  final String? chipset;

  /// Battery capacity in mAh.
  final int? batteryMah;

  /// Network type (e.g. "5G", "4G LTE").
  final String? networkType;

  /// Number of SIM slots.
  final int? simSlots;

  /// Camera description (e.g. "108MP + 12MP + 5MP").
  final String? cameraDescription;

  /// Weight in grams.
  final int? weightGrams;

  /// Display type (e.g. "AMOLED", "IPS LCD").
  final String? displayType;

  const MobileHandsetCatalogueAttributes({
    this.ramMb,
    this.storageMb,
    this.screenSizeTenths,
    this.operatingSystem,
    this.osVersion,
    this.chipset,
    this.batteryMah,
    this.networkType,
    this.simSlots,
    this.cameraDescription,
    this.weightGrams,
    this.displayType,
  });

  factory MobileHandsetCatalogueAttributes.fromJson(
    Map<String, dynamic> json,
  ) => MobileHandsetCatalogueAttributes(
    ramMb: json['ramMb'] as int?,
    storageMb: json['storageMb'] as int?,
    screenSizeTenths: json['screenSizeTenths'] as int?,
    operatingSystem: json['operatingSystem'] != null
        ? MobileOperatingSystem.fromWire(json['operatingSystem'] as String)
        : null,
    osVersion: json['osVersion'] as String?,
    chipset: json['chipset'] as String?,
    batteryMah: json['batteryMah'] as int?,
    networkType: json['networkType'] as String?,
    simSlots: json['simSlots'] as int?,
    cameraDescription: json['cameraDescription'] as String?,
    weightGrams: json['weightGrams'] as int?,
    displayType: json['displayType'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (ramMb != null) 'ramMb': ramMb,
    if (storageMb != null) 'storageMb': storageMb,
    if (screenSizeTenths != null) 'screenSizeTenths': screenSizeTenths,
    if (operatingSystem != null)
      'operatingSystem': operatingSystem!.toWireValue(),
    if (osVersion != null) 'osVersion': osVersion,
    if (chipset != null) 'chipset': chipset,
    if (batteryMah != null) 'batteryMah': batteryMah,
    if (networkType != null) 'networkType': networkType,
    if (simSlots != null) 'simSlots': simSlots,
    if (cameraDescription != null) 'cameraDescription': cameraDescription,
    if (weightGrams != null) 'weightGrams': weightGrams,
    if (displayType != null) 'displayType': displayType,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobileHandsetCatalogueAttributes &&
          ramMb == other.ramMb &&
          storageMb == other.storageMb &&
          screenSizeTenths == other.screenSizeTenths &&
          operatingSystem == other.operatingSystem &&
          osVersion == other.osVersion &&
          chipset == other.chipset &&
          batteryMah == other.batteryMah &&
          networkType == other.networkType &&
          simSlots == other.simSlots &&
          cameraDescription == other.cameraDescription &&
          weightGrams == other.weightGrams &&
          displayType == other.displayType;

  @override
  int get hashCode => Object.hash(
    ramMb,
    storageMb,
    screenSizeTenths,
    operatingSystem,
    osVersion,
    chipset,
    batteryMah,
    networkType,
    simSlots,
    cameraDescription,
    weightGrams,
    displayType,
  );

  @override
  String toString() =>
      'MobileHandsetCatalogueAttributes(ram: ${ramMb}MB, '
      'storage: ${storageMb}MB, screen: ${screenSizeTenths != null ? (screenSizeTenths! / 10.0) : null}", '
      'os: $operatingSystem, chipset: $chipset, battery: ${batteryMah}mAh)';
}

/// Accessory catalogue attributes with handset compatibility.
///
/// Represents a mobile accessory that may be associated with one or more
/// handset models. Accessories maintain separate stock, tax, and accounting
/// lines from handset devices per Requirement 4.8.
@immutable
class MobileAccessoryCatalogueAttributes {
  /// The accessory type category.
  final AccessoryType accessoryType;

  /// Compatible handset brand(s). Empty means universal.
  final List<String> compatibleBrands;

  /// Compatible handset model identifiers.
  /// These correspond to `ImeiUnit.model` values for relationship linking.
  final List<String> compatibleModels;

  /// Material (e.g. "silicone", "tempered glass").
  final String? material;

  /// Color variant.
  final String? color;

  /// SKU / article number for the accessory.
  final String? sku;

  /// Whether this accessory is typically bundled with a handset.
  final bool isBundleEligible;

  const MobileAccessoryCatalogueAttributes({
    required this.accessoryType,
    this.compatibleBrands = const [],
    this.compatibleModels = const [],
    this.material,
    this.color,
    this.sku,
    this.isBundleEligible = false,
  });

  factory MobileAccessoryCatalogueAttributes.fromJson(
    Map<String, dynamic> json,
  ) => MobileAccessoryCatalogueAttributes(
    accessoryType: AccessoryType.fromWire(json['accessoryType'] as String),
    compatibleBrands:
        (json['compatibleBrands'] as List<dynamic>?)?.cast<String>() ??
        const [],
    compatibleModels:
        (json['compatibleModels'] as List<dynamic>?)?.cast<String>() ??
        const [],
    material: json['material'] as String?,
    color: json['color'] as String?,
    sku: json['sku'] as String?,
    isBundleEligible: json['isBundleEligible'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'accessoryType': accessoryType.toWireValue(),
    if (compatibleBrands.isNotEmpty) 'compatibleBrands': compatibleBrands,
    if (compatibleModels.isNotEmpty) 'compatibleModels': compatibleModels,
    if (material != null) 'material': material,
    if (color != null) 'color': color,
    if (sku != null) 'sku': sku,
    'isBundleEligible': isBundleEligible,
  };

  /// Returns true if this accessory is compatible with the given model.
  bool isCompatibleWith({required String brand, required String model}) {
    final brandMatch =
        compatibleBrands.isEmpty || compatibleBrands.contains(brand);
    final modelMatch =
        compatibleModels.isEmpty || compatibleModels.contains(model);
    return brandMatch && modelMatch;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobileAccessoryCatalogueAttributes &&
          accessoryType == other.accessoryType &&
          listEquals(compatibleBrands, other.compatibleBrands) &&
          listEquals(compatibleModels, other.compatibleModels) &&
          material == other.material &&
          color == other.color &&
          sku == other.sku &&
          isBundleEligible == other.isBundleEligible;

  @override
  int get hashCode => Object.hash(
    accessoryType,
    Object.hashAll(compatibleBrands),
    Object.hashAll(compatibleModels),
    material,
    color,
    sku,
    isBundleEligible,
  );

  @override
  String toString() =>
      'MobileAccessoryCatalogueAttributes(type: $accessoryType, '
      'brands: $compatibleBrands, models: $compatibleModels, '
      'bundle: $isBundleEligible)';
}

/// A handset/accessory relationship for bundle reporting.
///
/// Links an accessory item to a parent handset on an invoice, allowing
/// separate stock, tax, and accounting lines while maintaining the
/// logical relationship for bundle discounts and reporting.
@immutable
class HandsetAccessoryRelationship {
  /// The parent handset invoice line ID.
  final String handsetLineId;

  /// The accessory invoice line ID.
  final String accessoryLineId;

  /// Whether this relationship is part of a configured bundle.
  final bool isBundle;

  /// Bundle identifier if part of a bundle promotion.
  final String? bundleId;

  const HandsetAccessoryRelationship({
    required this.handsetLineId,
    required this.accessoryLineId,
    this.isBundle = false,
    this.bundleId,
  });

  factory HandsetAccessoryRelationship.fromJson(Map<String, dynamic> json) =>
      HandsetAccessoryRelationship(
        handsetLineId: json['handsetLineId'] as String,
        accessoryLineId: json['accessoryLineId'] as String,
        isBundle: json['isBundle'] as bool? ?? false,
        bundleId: json['bundleId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'handsetLineId': handsetLineId,
    'accessoryLineId': accessoryLineId,
    'isBundle': isBundle,
    if (bundleId != null) 'bundleId': bundleId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandsetAccessoryRelationship &&
          handsetLineId == other.handsetLineId &&
          accessoryLineId == other.accessoryLineId;

  @override
  int get hashCode => Object.hash(handsetLineId, accessoryLineId);
}
