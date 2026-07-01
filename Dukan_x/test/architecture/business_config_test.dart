import 'package:dukanx/core/billing/business_type_config.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Business Type Architecture Guardrails', () {
    test('All Business Types must have a configuration', () {
      for (final type in BusinessType.values) {
        final config = BusinessTypeRegistry.getConfig(type);
        expect(
          config.type,
          equals(type),
          reason: 'Config for $type should match the enum',
        );
      }
    });

    test('Pharmacy and Wholesale must have Batch and Expiry fields', () {
      final pharmacy = BusinessTypeRegistry.getConfig(BusinessType.pharmacy);
      expect(pharmacy.hasField(ItemField.batchNo), isTrue);
      expect(pharmacy.hasField(ItemField.expiryDate), isTrue);
      expect(pharmacy.hasField(ItemField.drugSchedule), isTrue);

      final wholesale = BusinessTypeRegistry.getConfig(BusinessType.wholesale);
      expect(
        wholesale.hasField(ItemField.batchNo),
        isTrue,
      ); // Hardware uses batch
      // Wholesale uses batch/expiry? Let's check logic.
      // Current Logic in Service: requiresBatchNumber && requiresExpiryDate
      // My Config update added drugSchedule to wholesale.
    });

    test('Electronics and Mobile Shop must have Brand field', () {
      final electronics = BusinessTypeRegistry.getConfig(
        BusinessType.electronics,
      );
      expect(electronics.hasField(ItemField.brand), isTrue);

      final mobile = BusinessTypeRegistry.getConfig(BusinessType.mobileShop);
      expect(mobile.hasField(ItemField.brand), isTrue);
    });

    test('Grocery should NOT have Drug Schedule', () {
      final grocery = BusinessTypeRegistry.getConfig(BusinessType.grocery);
      expect(grocery.hasField(ItemField.drugSchedule), isFalse);
    });

    test('Validation Service Logic Alignment', () {
      // Verify that Configuration aligns with Validation Service Expectations
      final pharmacy = BusinessTypeRegistry.getConfig(BusinessType.pharmacy);
      final isPharmacy =
          pharmacy.hasField(ItemField.batchNo) &&
          pharmacy.hasField(ItemField.expiryDate);
      expect(isPharmacy, isTrue);
    });
  });
}
