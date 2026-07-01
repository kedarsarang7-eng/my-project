import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/vendor_profile.dart';
import 'package:dukanx/core/billing/business_type_config.dart';

void main() {
  group('Business Integration Verification', () {
    test('VendorProfile should correctly store and retrieve businessType', () {
      final profile = VendorProfile(
        id: 'test_id',
        vendorName: 'Test Vendor',
        mobileNumber: '1234567890',
        shopName: 'Test Shop',
        shopAddress: 'Test Address',
        shopMobile: '1234567890',
        businessType: BusinessType.pharmacy.name,
      );

      expect(profile.businessType, equals('pharmacy'));

      // Simulate To/From Map (DB Roundtrip)
      final map = profile.toMap();
      final restored = VendorProfile.fromMap(map);

      expect(restored.businessType, equals('pharmacy'));
    });

    test('BusinessTypeRegistry config works correctly', () {
      final pharmacyConfig = BusinessTypeRegistry.getConfig(
        BusinessType.pharmacy,
      );
      final electronicsConfig = BusinessTypeRegistry.getConfig(
        BusinessType.electronics,
      );
      final clothingConfig = BusinessTypeRegistry.getConfig(
        BusinessType.clothing,
      );

      // Pharmacy requires batch number
      expect(pharmacyConfig.isRequired(ItemField.batchNo), isTrue);
      expect(electronicsConfig.isRequired(ItemField.batchNo), isFalse);

      // Pharmacy requires expiry date
      expect(pharmacyConfig.isRequired(ItemField.expiryDate), isTrue);
      expect(clothingConfig.isRequired(ItemField.expiryDate), isFalse);
    });
  });
}
