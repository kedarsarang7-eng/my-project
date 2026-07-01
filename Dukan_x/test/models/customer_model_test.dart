// ============================================================================
// CUSTOMER MODEL TESTS
// ============================================================================
// Comprehensive tests for Customer model
//
// Author: DukanX Engineering
// Version: 3.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/customer.dart';

void main() {
  group('Customer Model Tests', () {
    test('should create Customer with required fields', () {
      final customer = Customer(
        id: 'cust-001',
        name: 'John Doe',
        phone: '9876543210',
        address: '123 Main Street',
      );

      expect(customer.id, 'cust-001');
      expect(customer.name, 'John Doe');
      expect(customer.phone, '9876543210');
      expect(customer.address, '123 Main Street');
      expect(customer.totalDues, 0.0); // default
    });

    test('should create Customer with all optional fields', () {
      final customer = Customer(
        id: 'cust-002',
        name: 'Jane Smith',
        phone: '9876543211',
        address: '456 Second Ave, Mumbai',
        totalDues: 500.0,
        cashDues: 300.0,
        onlineDues: 200.0,
        isBlacklisted: false,
        discountPercent: 5.0,
        linkedOwnerId: 'owner-001',
      );

      expect(customer.totalDues, 500.0);
      expect(customer.cashDues, 300.0);
      expect(customer.onlineDues, 200.0);
      expect(customer.discountPercent, 5.0);
      expect(customer.linkedOwnerId, 'owner-001');
    });

    test('toMap should serialize all fields correctly', () {
      final customer = Customer(
        id: 'cust-003',
        name: 'Test Customer',
        phone: '9999999999',
        address: 'Test Address',
        totalDues: 1000.0,
        isBlacklisted: true,
      );

      final map = customer.toMap();

      expect(map['name'], 'Test Customer');
      expect(map['phone'], '9999999999');
      expect(map['address'], 'Test Address');
      expect(map['totalDues'], 1000.0);
      expect(map['isBlacklisted'], true);
    });

    test('fromMap should deserialize correctly', () {
      final map = {
        'name': 'Deserialized Customer',
        'phone': '8888888888',
        'address': 'Deserialized Address',
        'totalDues': 2000,
        'cashDues': 1500,
        'onlineDues': 500,
        'isBlacklisted': false,
        'discountPercent': 10,
      };

      final customer = Customer.fromMap('cust-004', map);

      expect(customer.id, 'cust-004');
      expect(customer.name, 'Deserialized Customer');
      expect(customer.phone, '8888888888');
      expect(customer.totalDues, 2000.0);
      expect(customer.cashDues, 1500.0);
      expect(customer.discountPercent, 10.0);
    });

    test('fromMap should handle missing optional fields', () {
      final map = {'name': 'Minimal Customer', 'phone': '7777777777'};

      final customer = Customer.fromMap('cust-005', map);

      expect(customer.name, 'Minimal Customer');
      expect(customer.phone, '7777777777');
      expect(customer.address, '');
      expect(customer.totalDues, 0.0);
      expect(customer.isBlacklisted, false);
    });

    test('serialization round-trip should preserve data', () {
      final original = Customer(
        id: 'roundtrip-cust',
        name: 'Roundtrip Customer',
        phone: '6666666666',
        address: 'Roundtrip Address',
        totalDues: 3500.50,
        cashDues: 2000.0,
        onlineDues: 1500.50,
        discountPercent: 15.0,
        linkedOwnerId: 'owner-rt',
      );

      final map = original.toMap();
      final restored = Customer.fromMap(original.id, map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.phone, original.phone);
      expect(restored.address, original.address);
      expect(restored.totalDues, original.totalDues);
      expect(restored.cashDues, original.cashDues);
      expect(restored.linkedOwnerId, original.linkedOwnerId);
    });
  });

  group('Customer Edge Cases', () {
    test('should handle empty string fields', () {
      final customer = Customer(id: '', name: '', phone: '', address: '');

      expect(customer.id, '');
      expect(customer.name, '');
    });

    test('should handle zero dues', () {
      final customer = Customer(
        id: 'zero-dues',
        name: 'Zero Dues Customer',
        phone: '1111111111',
        address: 'Address',
        totalDues: 0.0,
      );

      expect(customer.totalDues, 0.0);
    });

    test('should handle large dues amounts', () {
      final customer = Customer(
        id: 'large-dues',
        name: 'Large Dues Customer',
        phone: '3333333333',
        address: 'Address',
        totalDues: 999999999.99,
      );

      expect(customer.totalDues, 999999999.99);
    });

    test('should handle special characters in name', () {
      final customer = Customer(
        id: 'special-chars',
        name: 'अमित कुमार (Amit Kumar)',
        phone: '4444444444',
        address: 'पुणे, महाराष्ट्र',
      );

      expect(customer.name, 'अमित कुमार (Amit Kumar)');
      expect(customer.address, 'पुणे, महाराष्ट्र');
    });

    test('should handle blacklisted customer', () {
      final customer = Customer(
        id: 'blacklist-001',
        name: 'Blacklisted Customer',
        phone: '5555555555',
        address: 'Address',
        isBlacklisted: true,
        blacklistDate: DateTime(2024, 1, 15),
      );

      expect(customer.isBlacklisted, true);
      expect(customer.blacklistDate, isNotNull);
    });
  });

  group('VegetablePurchase Model Tests', () {
    test('should create VegetablePurchase with all fields', () {
      final purchase = VegetablePurchase(
        vegId: 'veg-001',
        vegName: 'Tomato',
        quantityKg: 2.5,
        pricePerKg: 40.0,
        total: 100.0,
        purchaseDate: DateTime.now(),
      );

      expect(purchase.vegId, 'veg-001');
      expect(purchase.vegName, 'Tomato');
      expect(purchase.quantityKg, 2.5);
      expect(purchase.pricePerKg, 40.0);
      expect(purchase.total, 100.0);
    });

    test('toMap and fromMap round-trip', () {
      final original = VegetablePurchase(
        vegId: 'veg-002',
        vegName: 'Potato',
        quantityKg: 5.0,
        pricePerKg: 30.0,
        total: 150.0,
        purchaseDate: DateTime(2024, 12, 25),
        isRecurring: true,
      );

      final map = original.toMap();
      final restored = VegetablePurchase.fromMap(map);

      expect(restored.vegId, original.vegId);
      expect(restored.vegName, original.vegName);
      expect(restored.quantityKg, original.quantityKg);
      expect(restored.isRecurring, true);
    });
  });

  group('Customer with Linked Shops', () {
    test('should handle single linked shop (legacy)', () {
      final customer = Customer(
        id: 'linked-001',
        name: 'Linked Customer',
        phone: '6666666666',
        address: 'Address',
        linkedOwnerId: 'owner-001',
      );

      expect(customer.linkedOwnerId, 'owner-001');
    });

    test('should handle multiple linked shops', () {
      final customer = Customer(
        id: 'multi-linked',
        name: 'Multi-Linked Customer',
        phone: '7777777777',
        address: 'Address',
        linkedShopIds: ['shop-001', 'shop-002', 'shop-003'],
      );

      expect(customer.linkedShopIds.length, 3);
      expect(customer.linkedShopIds, contains('shop-002'));
    });
  });
}
