/// Mobile Catalogue Models Tests — Task 15.3
///
/// Verifies handset catalogue attributes, accessory catalogue attributes,
/// and handset/accessory relationships serialize correctly and maintain
/// compatibility semantics.
///
/// Requirements validated: 4.8, 9.11
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/models/catalogue_models.dart';

void main() {
  group('MobileHandsetCatalogueAttributes', () {
    test('round-trips through JSON serialization', () {
      const attrs = MobileHandsetCatalogueAttributes(
        ramMb: 8192,
        storageMb: 131072,
        screenSizeTenths: 67,
        operatingSystem: MobileOperatingSystem.android,
        osVersion: 'Android 14',
        chipset: 'Snapdragon 8 Gen 3',
        batteryMah: 5000,
        networkType: '5G',
        simSlots: 2,
        cameraDescription: '108MP + 12MP + 5MP',
        weightGrams: 195,
        displayType: 'AMOLED',
      );

      final json = attrs.toJson();
      final restored = MobileHandsetCatalogueAttributes.fromJson(json);

      expect(restored.ramMb, 8192);
      expect(restored.storageMb, 131072);
      expect(restored.screenSizeTenths, 67);
      expect(restored.operatingSystem, MobileOperatingSystem.android);
      expect(restored.osVersion, 'Android 14');
      expect(restored.chipset, 'Snapdragon 8 Gen 3');
      expect(restored.batteryMah, 5000);
      expect(restored.networkType, '5G');
      expect(restored.simSlots, 2);
      expect(restored.cameraDescription, '108MP + 12MP + 5MP');
      expect(restored.weightGrams, 195);
      expect(restored.displayType, 'AMOLED');
      expect(restored, equals(attrs));
    });

    test('omits null fields from JSON', () {
      const attrs = MobileHandsetCatalogueAttributes(
        ramMb: 4096,
        batteryMah: 4000,
      );

      final json = attrs.toJson();
      expect(json.containsKey('ramMb'), isTrue);
      expect(json.containsKey('batteryMah'), isTrue);
      expect(json.containsKey('storageMb'), isFalse);
      expect(json.containsKey('screenSizeTenths'), isFalse);
      expect(json.containsKey('operatingSystem'), isFalse);
      expect(json.containsKey('chipset'), isFalse);
    });

    test('all null attributes produces empty JSON map', () {
      const attrs = MobileHandsetCatalogueAttributes();
      final json = attrs.toJson();
      expect(json, isEmpty);
    });

    test('equality works correctly', () {
      const a = MobileHandsetCatalogueAttributes(
        ramMb: 8192,
        operatingSystem: MobileOperatingSystem.ios,
      );
      const b = MobileHandsetCatalogueAttributes(
        ramMb: 8192,
        operatingSystem: MobileOperatingSystem.ios,
      );
      const c = MobileHandsetCatalogueAttributes(
        ramMb: 4096,
        operatingSystem: MobileOperatingSystem.ios,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('MobileOperatingSystem', () {
    test('round-trips all values through wire format', () {
      for (final os in MobileOperatingSystem.values) {
        final wire = os.toWireValue();
        final restored = MobileOperatingSystem.fromWire(wire);
        expect(restored, os);
      }
    });

    test('fromWire throws on unknown value', () {
      expect(
        () => MobileOperatingSystem.fromWire('UNKNOWN_OS'),
        throwsArgumentError,
      );
    });
  });

  group('MobileAccessoryCatalogueAttributes', () {
    test('round-trips through JSON serialization', () {
      const attrs = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.protectiveCase,
        compatibleBrands: ['Samsung', 'OnePlus'],
        compatibleModels: ['Galaxy S24', 'OnePlus 12'],
        material: 'silicone',
        color: 'Black',
        sku: 'ACC-CASE-001',
        isBundleEligible: true,
      );

      final json = attrs.toJson();
      final restored = MobileAccessoryCatalogueAttributes.fromJson(json);

      expect(restored.accessoryType, AccessoryType.protectiveCase);
      expect(restored.compatibleBrands, ['Samsung', 'OnePlus']);
      expect(restored.compatibleModels, ['Galaxy S24', 'OnePlus 12']);
      expect(restored.material, 'silicone');
      expect(restored.color, 'Black');
      expect(restored.sku, 'ACC-CASE-001');
      expect(restored.isBundleEligible, isTrue);
      expect(restored, equals(attrs));
    });

    test('omits empty lists and null optional fields', () {
      const attrs = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.charger,
      );

      final json = attrs.toJson();
      expect(json['accessoryType'], 'CHARGER');
      expect(json['isBundleEligible'], false);
      expect(json.containsKey('compatibleBrands'), isFalse);
      expect(json.containsKey('compatibleModels'), isFalse);
      expect(json.containsKey('material'), isFalse);
    });

    test('isCompatibleWith returns true for universal accessory', () {
      const universal = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.charger,
        compatibleBrands: [],
        compatibleModels: [],
      );

      expect(
        universal.isCompatibleWith(brand: 'Apple', model: 'iPhone 15'),
        isTrue,
      );
    });

    test('isCompatibleWith filters by brand', () {
      const caseAttr = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.protectiveCase,
        compatibleBrands: ['Samsung'],
        compatibleModels: [],
      );

      expect(
        caseAttr.isCompatibleWith(brand: 'Samsung', model: 'Galaxy S24'),
        isTrue,
      );
      expect(
        caseAttr.isCompatibleWith(brand: 'Apple', model: 'iPhone 15'),
        isFalse,
      );
    });

    test('isCompatibleWith filters by model', () {
      const caseAttr = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.screenProtector,
        compatibleBrands: [],
        compatibleModels: ['Galaxy S24', 'Galaxy S24 Ultra'],
      );

      expect(
        caseAttr.isCompatibleWith(brand: 'Samsung', model: 'Galaxy S24'),
        isTrue,
      );
      expect(
        caseAttr.isCompatibleWith(brand: 'Samsung', model: 'Galaxy A15'),
        isFalse,
      );
    });

    test('isCompatibleWith requires both brand and model match', () {
      const caseAttr = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.protectiveCase,
        compatibleBrands: ['Samsung'],
        compatibleModels: ['Galaxy S24'],
      );

      expect(
        caseAttr.isCompatibleWith(brand: 'Samsung', model: 'Galaxy S24'),
        isTrue,
      );
      expect(
        caseAttr.isCompatibleWith(brand: 'Samsung', model: 'Galaxy A15'),
        isFalse,
      );
      expect(
        caseAttr.isCompatibleWith(brand: 'Apple', model: 'Galaxy S24'),
        isFalse,
      );
    });
  });

  group('AccessoryType', () {
    test('round-trips all values through wire format', () {
      for (final type in AccessoryType.values) {
        final wire = type.toWireValue();
        final restored = AccessoryType.fromWire(wire);
        expect(restored, type);
      }
    });

    test('fromWire throws on unknown value', () {
      expect(
        () => AccessoryType.fromWire('UNKNOWN_ACCESSORY'),
        throwsArgumentError,
      );
    });
  });

  group('HandsetAccessoryRelationship', () {
    test('round-trips through JSON serialization', () {
      const rel = HandsetAccessoryRelationship(
        handsetLineId: 'line-001',
        accessoryLineId: 'line-002',
        isBundle: true,
        bundleId: 'bundle-summer-2024',
      );

      final json = rel.toJson();
      final restored = HandsetAccessoryRelationship.fromJson(json);

      expect(restored.handsetLineId, 'line-001');
      expect(restored.accessoryLineId, 'line-002');
      expect(restored.isBundle, isTrue);
      expect(restored.bundleId, 'bundle-summer-2024');
      expect(restored, equals(rel));
    });

    test('omits null bundleId from JSON', () {
      const rel = HandsetAccessoryRelationship(
        handsetLineId: 'line-001',
        accessoryLineId: 'line-003',
      );

      final json = rel.toJson();
      expect(json.containsKey('bundleId'), isFalse);
      expect(json['isBundle'], false);
    });

    test('equality is based on line IDs', () {
      const a = HandsetAccessoryRelationship(
        handsetLineId: 'h1',
        accessoryLineId: 'a1',
        isBundle: true,
      );
      const b = HandsetAccessoryRelationship(
        handsetLineId: 'h1',
        accessoryLineId: 'a1',
        isBundle: false,
      );
      // Same line IDs = equal (equality is structural on IDs)
      expect(a, equals(b));
    });
  });
}
