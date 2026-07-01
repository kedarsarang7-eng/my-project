// Unit Tests for Business Type Configuration Engine
// Tests for BusinessTypeConfig, BusinessTypeRegistry, and helpers
//
// Created: 2024-12-26

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/billing/business_type_config.dart';

void main() {
  group('BusinessType Enum', () {
    test('should have 19 business types', () {
      expect(BusinessType.values.length, 19);
    });

    test('should have correct display names', () {
      expect(BusinessType.grocery.displayName, 'Grocery Store');
      expect(BusinessType.restaurant.displayName, 'Restaurant / Hotel');
      expect(BusinessType.pharmacy.displayName, 'Medical / Pharmacy');
      expect(BusinessType.clothing.displayName, 'Clothing / Fashion');
      expect(BusinessType.hardware.displayName, 'Hardware Store');
      expect(BusinessType.electronics.displayName, 'Mobile / Electronics');
      expect(BusinessType.service.displayName, 'Service Business');
      expect(BusinessType.petrolPump.displayName, 'Petrol Pump');
    });

    test('should have correct emojis', () {
      expect(BusinessType.grocery.emoji, '🛒');
      expect(BusinessType.restaurant.emoji, '🍽️');
      expect(BusinessType.pharmacy.emoji, '💊');
      expect(BusinessType.clothing.emoji, '👕');
      expect(BusinessType.hardware.emoji, '🧰');
      expect(BusinessType.electronics.emoji, '📱');
      expect(BusinessType.service.emoji, '🧾');
      expect(BusinessType.petrolPump.emoji, '⛽');
    });
  });

  group('BusinessTypeRegistry', () {
    test('should return config for all business types', () {
      for (final type in BusinessType.values) {
        final config = BusinessTypeRegistry.getConfig(type);
        expect(config.type, type);
        expect(config.requiredFields.isNotEmpty, true);
        expect(config.unitOptions.isNotEmpty, true);
      }
    });

    test('grocery should have correct defaults', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.grocery);
      expect(config.defaultGstRate, 0.0);
      expect(config.gstEditable, true);
      expect(config.itemLabel, 'Item');
      expect(config.priceLabel, 'Rate');
    });

    test('restaurant should have 5% fixed GST', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(config.defaultGstRate, 5.0);
      expect(config.gstEditable, false);
      expect(config.itemLabel, 'Dish');
    });

    test('pharmacy should require batch and expiry', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.pharmacy);
      expect(config.isRequired(ItemField.batchNo), true);
      expect(config.isRequired(ItemField.expiryDate), true);
      expect(config.defaultGstRate, 12.0);
    });

    test('electronics should have 18% fixed GST', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.electronics);
      expect(config.defaultGstRate, 18.0);
      expect(config.gstEditable, false);
      expect(config.hasField(ItemField.serialNo), true);
      expect(config.hasField(ItemField.warrantyMonths), true);
    });

    test('clothing should have size as required', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.clothing);
      expect(config.isRequired(ItemField.size), true);
      expect(config.hasField(ItemField.color), true);
    });

    test('service should have labor as required', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.service);
      expect(config.isRequired(ItemField.laborCharge), true);
      expect(config.hasField(ItemField.partsCharge), true);
      expect(config.hasField(ItemField.notes), true);
    });
  });

  group('migrateBusinessType', () {
    test('should migrate legacy grocery to grocery', () {
      expect(migrateBusinessType('grocery'), BusinessType.grocery);
      expect(migrateBusinessType('BusinessType.grocery'), BusinessType.grocery);
    });

    test('should migrate pharmacy correctly', () {
      expect(migrateBusinessType('pharmacy'), BusinessType.pharmacy);
    });

    test('should handle unknown types gracefully', () {
      expect(migrateBusinessType('unknown'), BusinessType.grocery);
      expect(migrateBusinessType(''), BusinessType.grocery);
    });

    test('should migrate wholesale to grocery', () {
      expect(migrateBusinessType('wholesale'), BusinessType.wholesale);
    });
  });

  group('BusinessTypeConfig field visibility', () {
    test('hasField should return true for all fields in allFields', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.pharmacy);
      for (final field in config.allFields) {
        expect(config.hasField(field), true);
      }
    });

    test('isRequired should return false for optional fields', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.pharmacy);
      expect(
        config.isRequired(ItemField.doctorName),
        false,
      ); // optional for pharmacy
    });
  });
}
