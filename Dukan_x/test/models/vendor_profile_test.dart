// ============================================================================
// VENDOR PROFILE MODEL TESTS
// ============================================================================
// Comprehensive tests for VendorProfile model
//
// Author: DukanX Engineering
// Version: 3.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/vendor_profile.dart';

void main() {
  group('VendorProfile Model Tests', () {
    test('should create VendorProfile with required fields', () {
      final profile = VendorProfile(
        id: 'vendor-001',
        vendorName: 'John Doe',
        mobileNumber: '9876543210',
        shopName: 'Test Shop',
        shopAddress: '123 Main Street',
        shopMobile: '9876543211',
      );

      expect(profile.id, 'vendor-001');
      expect(profile.vendorName, 'John Doe');
      expect(profile.shopName, 'Test Shop');
      expect(profile.mobileNumber, '9876543210');
    });

    test('should create VendorProfile with all optional fields', () {
      final profile = VendorProfile(
        id: 'vendor-002',
        vendorName: 'Jane Smith',
        mobileNumber: '9876543210',
        email: 'jane@shop.com',
        shopName: 'Complete Shop',
        shopAddress: '456 Market Road',
        shopMobile: '9876543220',
        gstin: '27AABCU9603R1ZM',
        shopLogoUrl: 'https://example.com/logo.png',
      );

      expect(profile.email, 'jane@shop.com');
      expect(profile.gstin, '27AABCU9603R1ZM');
      expect(profile.shopLogoUrl, 'https://example.com/logo.png');
    });

    test('empty factory should create empty profile', () {
      final profile = VendorProfile.empty('vendor-003');

      expect(profile.id, 'vendor-003');
      expect(profile.vendorName, '');
      expect(profile.shopName, '');
      expect(profile.shopAddress, '');
    });

    test('toMap should serialize all fields correctly', () {
      final profile = VendorProfile(
        id: 'vendor-004',
        vendorName: 'Serialize Owner',
        mobileNumber: '1111111111',
        shopName: 'Serialize Shop',
        shopAddress: 'Serialize Address',
        shopMobile: '2222222222',
        gstin: 'GST111111111',
      );

      final map = profile.toMap();

      expect(map['id'], 'vendor-004');
      expect(map['vendorName'], 'Serialize Owner');
      expect(map['shopName'], 'Serialize Shop');
      expect(map['shopAddress'], 'Serialize Address');
      expect(map['gstin'], 'GST111111111');
    });

    test('fromMap should deserialize correctly', () {
      final map = {
        'id': 'vendor-005',
        'vendorName': 'Deserialized Owner',
        'mobileNumber': '3333333333',
        'email': 'deser@test.com',
        'shopName': 'Deserialized Shop',
        'shopAddress': 'Deser Address',
        'shopMobile': '4444444444',
        'gstin': 'GST222222222',
      };

      final profile = VendorProfile.fromMap(map);

      expect(profile.id, 'vendor-005');
      expect(profile.vendorName, 'Deserialized Owner');
      expect(profile.shopName, 'Deserialized Shop');
      expect(profile.gstin, 'GST222222222');
    });

    test('fromMap should handle missing optional fields', () {
      final map = {
        'id': 'vendor-006',
        'vendorName': 'Minimal Owner',
        'mobileNumber': '5555555555',
        'shopName': 'Minimal Shop',
        'shopAddress': 'Minimal Address',
        'shopMobile': '6666666666',
      };

      final profile = VendorProfile.fromMap(map);

      expect(profile.shopName, 'Minimal Shop');
      expect(profile.email, null);
      expect(profile.gstin, null);
      expect(profile.shopLogoUrl, null);
    });

    test('copyWith should create modified copy', () {
      final original = VendorProfile(
        id: 'vendor-007',
        vendorName: 'Original Owner',
        mobileNumber: '7777777777',
        shopName: 'Original Shop',
        shopAddress: 'Original Address',
        shopMobile: '8888888888',
      );

      final updated = original.copyWith(
        shopName: 'Updated Shop',
        gstin: 'NEWGSTIN123456',
      );

      expect(updated.shopName, 'Updated Shop');
      expect(updated.gstin, 'NEWGSTIN123456');
      // Unchanged fields
      expect(updated.id, 'vendor-007');
      expect(updated.vendorName, 'Original Owner');
      // Version should increment
      expect(updated.version, original.version + 1);
    });

    test('serialization round-trip should preserve data', () {
      final original = VendorProfile(
        id: 'roundtrip-vendor',
        vendorName: 'Roundtrip Owner',
        mobileNumber: '9999999999',
        email: 'rt@test.com',
        shopName: 'Roundtrip Shop',
        shopAddress: 'RT Address',
        shopMobile: '1010101010',
        gstin: 'RT444444444444',
        shopLogoUrl: 'https://example.com/rt-logo.png',
      );

      final map = original.toMap();
      final restored = VendorProfile.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.vendorName, original.vendorName);
      expect(restored.shopName, original.shopName);
      expect(restored.email, original.email);
      expect(restored.gstin, original.gstin);
    });
  });

  group('VendorProfile Validation', () {
    test('isComplete should return true for complete profile', () {
      final profile = VendorProfile(
        id: 'complete-001',
        vendorName: 'Complete Owner',
        mobileNumber: '1234567890',
        shopName: 'Complete Shop',
        shopAddress: 'Complete Address',
        shopMobile: '0987654321',
      );

      expect(profile.isComplete, true);
    });

    test('isComplete should return false for incomplete profile', () {
      final profile = VendorProfile(
        id: 'incomplete-001',
        vendorName: '',
        mobileNumber: '',
        shopName: '',
        shopAddress: '',
        shopMobile: '',
      );

      expect(profile.isComplete, false);
    });

    test('isValidMobile should validate Indian mobile numbers', () {
      expect(VendorProfile.isValidMobile('9876543210'), true);
      expect(VendorProfile.isValidMobile('6543210987'), true);
      expect(VendorProfile.isValidMobile('123'), false);
      expect(VendorProfile.isValidMobile('1234567890'), false); // starts with 1
    });

    test('isValidGstin should validate GSTIN format', () {
      expect(VendorProfile.isValidGstin(''), true); // empty is valid
      expect(VendorProfile.isValidGstin('27AABCU9603R1ZM'), true);
      expect(VendorProfile.isValidGstin('INVALID'), false);
    });

    test('isValidEmail should validate email format', () {
      expect(VendorProfile.isValidEmail(''), true); // empty is valid
      expect(VendorProfile.isValidEmail('test@example.com'), true);
      expect(VendorProfile.isValidEmail('invalid-email'), false);
    });
  });

  group('VendorProfile for Invoices', () {
    test('should have all fields needed for invoice generation', () {
      final profile = VendorProfile(
        id: 'invoice-vendor',
        vendorName: 'Invoice Owner',
        mobileNumber: '5555555555',
        email: 'invoice@shop.com',
        shopName: 'Invoice Ready Shop',
        shopAddress: 'Shop Address for Invoice, City, State - 500001',
        shopMobile: '6666666666',
        gstin: '36AABCU9603R1ZM',
        shopLogoUrl: 'https://example.com/logo.png',
      );

      // All invoice-critical fields should be present
      expect(profile.shopName, isNotEmpty);
      expect(profile.vendorName, isNotEmpty);
      expect(profile.shopAddress, isNotEmpty);
      expect(profile.shopMobile, isNotEmpty);
      expect(profile.gstin, isNotNull);
      expect(profile.isComplete, true);
    });

    test('should handle special characters in shop name', () {
      final profile = VendorProfile(
        id: 'special-001',
        vendorName: 'राम शर्मा',
        mobileNumber: '9999999999',
        shopName: 'किराना स्टोर (Kirana Store)',
        shopAddress: 'पुणे, महाराष्ट्र',
        shopMobile: '8888888888',
      );

      expect(profile.shopName, contains('किराना'));
      expect(profile.vendorName, 'राम शर्मा');
    });
  });

  group('ProfileHistoryEntry Tests', () {
    test('should create ProfileHistoryEntry', () {
      final entry = ProfileHistoryEntry(
        version: 2,
        timestamp: DateTime(2024, 12, 25),
        changes: {'shopName': 'New Shop Name'},
        changedBy: 'admin',
      );

      expect(entry.version, 2);
      expect(entry.changes['shopName'], 'New Shop Name');
      expect(entry.changedBy, 'admin');
    });

    test('toMap should serialize correctly', () {
      final entry = ProfileHistoryEntry(
        version: 3,
        timestamp: DateTime(2024, 12, 26),
        changes: {'gstin': 'NEWGSTIN123'},
      );

      final map = entry.toMap();

      expect(map['version'], 3);
      expect(map['changes']['gstin'], 'NEWGSTIN123');
    });
  });
}
