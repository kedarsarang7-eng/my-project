// ============================================================================
// RESTAURANT BILLING INTEGRATION TESTS
// ============================================================================
// Validates billing features wired in Phase 1C (tasks 6.1–6.6):
//   1. Half-portion toggle sets `isHalf` correctly
//   2. Parcel flag sets `isParcel` correctly
//   3. Service charge calculation and display for dine-in bills
//   4. Split bill dialog and amount computation
//   5. Tip field saves to bill
//   6. GST rate (5% non-editable) still applies correctly alongside new fields
//
// Requirements: 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 3.3
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/restaurant/utils/restaurant_business_rules.dart';
import 'package:dukanx/models/bill.dart';
import 'package:dukanx/core/billing/business_type_config.dart';

void main() {
  // ==========================================================================
  // 1. Half-portion toggle — BillItem.isHalf
  // Validates: Requirement 2.7
  // ==========================================================================
  group('Half-portion toggle (isHalf)', () {
    test('BillItem.copyWith(isHalf: true) sets isHalf to true', () {
      final item = BillItem(
        productId: 'dish_001',
        productName: 'Paneer Tikka',
        qty: 1,
        price: 250.0,
      );
      expect(item.isHalf, isNull);

      final halfItem = item.copyWith(isHalf: true);
      expect(halfItem.isHalf, isTrue);
      expect(halfItem.productName, 'Paneer Tikka');
      expect(halfItem.price, 250.0);
    });

    test('BillItem.copyWith(isHalf: false) sets isHalf to false', () {
      final item = BillItem(
        productId: 'dish_002',
        productName: 'Dal Makhani',
        qty: 1,
        price: 180.0,
        isHalf: true,
      );
      expect(item.isHalf, isTrue);

      final fullItem = item.copyWith(isHalf: false);
      expect(fullItem.isHalf, isFalse);
    });

    test('isHalf serializes and deserializes correctly via toMap/fromMap', () {
      final item = BillItem(
        productId: 'dish_003',
        productName: 'Butter Chicken',
        qty: 1,
        price: 320.0,
        isHalf: true,
      );

      final map = item.toMap();
      expect(map['isHalf'], isTrue);

      final restored = BillItem.fromMap(map);
      expect(restored.isHalf, isTrue);
    });

    test('isHalf absent in map results in null', () {
      final map = {
        'productId': 'dish_004',
        'productName': 'Naan',
        'qty': 2.0,
        'price': 40.0,
      };
      final item = BillItem.fromMap(map);
      expect(item.isHalf, isNull);
    });

    test('restaurant config declares isHalf as optional field', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(config.optionalFields.contains(ItemField.isHalf), isTrue);
    });
  });

  // ==========================================================================
  // 2. Parcel flag — BillItem.isParcel
  // Validates: Requirement 2.8
  // ==========================================================================
  group('Parcel flag (isParcel)', () {
    test('BillItem.copyWith(isParcel: true) sets isParcel to true', () {
      final item = BillItem(
        productId: 'dish_010',
        productName: 'Biryani',
        qty: 1,
        price: 280.0,
      );
      expect(item.isParcel, isNull);

      final parcelItem = item.copyWith(isParcel: true);
      expect(parcelItem.isParcel, isTrue);
      expect(parcelItem.productName, 'Biryani');
    });

    test('BillItem.copyWith(isParcel: false) sets isParcel to false', () {
      final item = BillItem(
        productId: 'dish_011',
        productName: 'Fried Rice',
        qty: 1,
        price: 200.0,
        isParcel: true,
      );
      final dineInItem = item.copyWith(isParcel: false);
      expect(dineInItem.isParcel, isFalse);
    });

    test(
      'isParcel serializes and deserializes correctly via toMap/fromMap',
      () {
        final item = BillItem(
          productId: 'dish_012',
          productName: 'Manchurian',
          qty: 2,
          price: 180.0,
          isParcel: true,
        );

        final map = item.toMap();
        expect(map['isParcel'], isTrue);

        final restored = BillItem.fromMap(map);
        expect(restored.isParcel, isTrue);
      },
    );

    test('isParcel absent in map results in null', () {
      final map = {
        'productId': 'dish_013',
        'productName': 'Soup',
        'qty': 1.0,
        'price': 120.0,
      };
      final item = BillItem.fromMap(map);
      expect(item.isParcel, isNull);
    });

    test('restaurant config declares isParcel as optional field', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(config.optionalFields.contains(ItemField.isParcel), isTrue);
    });
  });

  // ==========================================================================
  // 3. Service charge calculation and display for dine-in bills
  // Validates: Requirement 2.9
  // ==========================================================================
  group('Service charge calculation (dine-in)', () {
    test('serviceCharge(1000) == 50.0 (5% default)', () {
      expect(RestaurantBusinessRules.serviceCharge(1000), equals(50.0));
    });

    test('serviceCharge(500) == 25.0', () {
      expect(RestaurantBusinessRules.serviceCharge(500), equals(25.0));
    });

    test('serviceCharge(0) == 0 (zero subtotal)', () {
      expect(RestaurantBusinessRules.serviceCharge(0), equals(0.0));
    });

    test('serviceCharge(-100) == 0 (negative subtotal)', () {
      expect(RestaurantBusinessRules.serviceCharge(-100), equals(0.0));
    });

    test('serviceCharge with custom rate 10%', () {
      expect(
        RestaurantBusinessRules.serviceCharge(1000, rate: 0.10),
        equals(100.0),
      );
    });

    test('serviceCharge rounds half-up for odd paise', () {
      // 199.99 * 0.05 = 9.9995 → 10.00
      expect(RestaurantBusinessRules.serviceCharge(199.99), equals(10.0));
    });

    test('Bill.serviceCharge field stores and serializes', () {
      final bill = Bill(
        id: 'bill_sc_001',
        invoiceNumber: 'INV-001',
        customerId: 'cust_001',
        customerName: 'Test Customer',
        customerPhone: '9999999999',
        customerAddress: '',
        customerGst: '',
        date: DateTime(2024, 6, 15),
        items: [],
        subtotal: 1000.0,
        totalTax: 50.0,
        grandTotal: 1100.0,
        paidAmount: 1100.0,
        cashPaid: 1100.0,
        onlinePaid: 0,
        status: 'Paid',
        paymentType: 'Cash',
        discountApplied: 0,
        marketTicket: 0,
        ownerId: 'owner_001',
        shopName: 'Test Restaurant',
        shopAddress: '123 Main St',
        shopGst: '',
        shopContact: '9876543210',
        source: 'app',
        marketCess: 0,
        commissionAmount: 0,
        isInterState: false,
        businessType: 'restaurant',
        serviceCharge: 50.0,
      );

      final map = bill.toMap();
      expect(map['serviceCharge'], equals(50.0));

      final restored = Bill.fromMap('bill_sc_001', map);
      expect(restored.serviceCharge, equals(50.0));
    });
  });

  // ==========================================================================
  // 4. Split bill dialog and amount computation
  // Validates: Requirement 2.10
  // ==========================================================================
  group('Split bill computation', () {
    test('splitBill(1000, 2) returns [500.0, 500.0]', () {
      final parts = RestaurantBusinessRules.splitBill(1000, 2);
      expect(parts, equals([500.0, 500.0]));
      expect(parts.fold<double>(0, (a, b) => a + b), closeTo(1000.0, 1e-9));
    });

    test('splitBill(100, 3) distributes remainder to first guest', () {
      final parts = RestaurantBusinessRules.splitBill(100, 3);
      expect(parts.length, 3);
      // 10000 cents / 3 = 3333 each, remainder 1 cent → first gets 33.34
      expect(parts[0], equals(33.34));
      expect(parts[1], equals(33.33));
      expect(parts[2], equals(33.33));
      expect(parts.fold<double>(0, (a, b) => a + b), closeTo(100.0, 1e-9));
    });

    test('splitBill(250.50, 4) sums back to original', () {
      final parts = RestaurantBusinessRules.splitBill(250.50, 4);
      expect(parts.length, 4);
      final sum = parts.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(250.50, 0.01));
    });

    test('splitBill with zero split count returns empty', () {
      expect(RestaurantBusinessRules.splitBill(500, 0), isEmpty);
    });

    test('splitBill with negative split count returns empty', () {
      expect(RestaurantBusinessRules.splitBill(500, -2), isEmpty);
    });

    test('splitBill with 1 guest returns the full amount', () {
      final parts = RestaurantBusinessRules.splitBill(750, 1);
      expect(parts, equals([750.0]));
    });

    test('splitBill with negative total returns empty', () {
      expect(RestaurantBusinessRules.splitBill(-100, 2), isEmpty);
    });
  });

  // ==========================================================================
  // 5. Tip field saves to bill
  // Validates: Requirement 2.12
  // ==========================================================================
  group('Tip field (Bill.tipAmount)', () {
    test('Bill with tipAmount serializes to map when > 0', () {
      final bill = Bill(
        id: 'bill_tip_001',
        invoiceNumber: 'INV-TIP-001',
        customerId: 'cust_002',
        customerName: 'Tip Customer',
        customerPhone: '8888888888',
        customerAddress: '',
        customerGst: '',
        date: DateTime(2024, 7, 1),
        items: [],
        subtotal: 500.0,
        totalTax: 25.0,
        grandTotal: 575.0,
        paidAmount: 575.0,
        cashPaid: 575.0,
        onlinePaid: 0,
        status: 'Paid',
        paymentType: 'Cash',
        discountApplied: 0,
        marketTicket: 0,
        ownerId: 'owner_002',
        shopName: 'Tip Restaurant',
        shopAddress: '456 Elm St',
        shopGst: '',
        shopContact: '9876543210',
        source: 'app',
        marketCess: 0,
        commissionAmount: 0,
        isInterState: false,
        businessType: 'restaurant',
        tipAmount: 50.0,
      );

      final map = bill.toMap();
      expect(map['tipAmount'], equals(50.0));
    });

    test('Bill with tipAmount == 0 does NOT include tipAmount in map', () {
      final bill = Bill(
        id: 'bill_tip_002',
        invoiceNumber: 'INV-TIP-002',
        customerId: 'cust_003',
        customerName: 'No Tip Customer',
        customerPhone: '7777777777',
        customerAddress: '',
        customerGst: '',
        date: DateTime(2024, 7, 2),
        items: [],
        subtotal: 300.0,
        totalTax: 15.0,
        grandTotal: 315.0,
        paidAmount: 315.0,
        cashPaid: 315.0,
        onlinePaid: 0,
        status: 'Paid',
        paymentType: 'Cash',
        discountApplied: 0,
        marketTicket: 0,
        ownerId: 'owner_003',
        shopName: 'No Tip Restaurant',
        shopAddress: '789 Oak Ave',
        shopGst: '',
        shopContact: '9876543210',
        source: 'app',
        marketCess: 0,
        commissionAmount: 0,
        isInterState: false,
        businessType: 'restaurant',
        tipAmount: 0.0,
      );

      final map = bill.toMap();
      expect(map.containsKey('tipAmount'), isFalse);
    });

    test('Bill.fromMap restores tipAmount correctly', () {
      final map = {
        'id': 'bill_tip_003',
        'invoiceNumber': 'INV-TIP-003',
        'customerId': 'cust_004',
        'customerName': 'Restore Tip',
        'customerPhone': '6666666666',
        'customerAddress': '',
        'customerGst': '',
        'date': DateTime(2024, 7, 3).toIso8601String(),
        'items': <Map<String, dynamic>>[],
        'subtotal': 800.0,
        'totalTax': 40.0,
        'grandTotal': 890.0,
        'paidAmount': 890.0,
        'cashPaid': 890.0,
        'onlinePaid': 0.0,
        'status': 'Paid',
        'paymentType': 'Cash',
        'discountApplied': 0.0,
        'marketTicket': 0.0,
        'ownerId': 'owner_004',
        'shopName': 'Restore Restaurant',
        'shopAddress': '101 Pine Rd',
        'shopGst': '',
        'shopContact': '9876543210',
        'source': 'app',
        'marketCess': 0.0,
        'commissionAmount': 0.0,
        'isInterState': false,
        'businessType': 'restaurant',
        'tipAmount': 75.0,
        'serviceCharge': 40.0,
      };

      final bill = Bill.fromMap('bill_tip_003', map);
      expect(bill.tipAmount, equals(75.0));
    });

    test('Bill.fromMap with missing tipAmount defaults to 0.0', () {
      final map = {
        'id': 'bill_tip_004',
        'invoiceNumber': 'INV-TIP-004',
        'customerId': 'cust_005',
        'customerName': 'Missing Tip',
        'customerPhone': '5555555555',
        'customerAddress': '',
        'customerGst': '',
        'date': DateTime(2024, 7, 4).toIso8601String(),
        'items': <Map<String, dynamic>>[],
        'subtotal': 400.0,
        'totalTax': 20.0,
        'grandTotal': 420.0,
        'paidAmount': 420.0,
        'cashPaid': 420.0,
        'onlinePaid': 0.0,
        'status': 'Paid',
        'paymentType': 'Cash',
        'discountApplied': 0.0,
        'marketTicket': 0.0,
        'ownerId': 'owner_005',
        'shopName': 'Missing Tip Restaurant',
        'shopAddress': '202 Birch Ln',
        'shopGst': '',
        'shopContact': '9876543210',
        'source': 'app',
        'marketCess': 0.0,
        'commissionAmount': 0.0,
        'isInterState': false,
        'businessType': 'restaurant',
      };

      final bill = Bill.fromMap('bill_tip_004', map);
      expect(bill.tipAmount, equals(0.0));
    });

    test('Bill.copyWith(tipAmount: 100) works correctly', () {
      final bill = Bill(
        id: 'bill_tip_005',
        invoiceNumber: 'INV-TIP-005',
        customerId: 'cust_006',
        customerName: 'Copy Tip',
        customerPhone: '4444444444',
        customerAddress: '',
        customerGst: '',
        date: DateTime(2024, 7, 5),
        items: [],
        subtotal: 600.0,
        totalTax: 30.0,
        grandTotal: 630.0,
        paidAmount: 630.0,
        cashPaid: 630.0,
        onlinePaid: 0,
        status: 'Paid',
        paymentType: 'Cash',
        discountApplied: 0,
        marketTicket: 0,
        ownerId: 'owner_006',
        shopName: 'Copy Tip Restaurant',
        shopAddress: '303 Maple Dr',
        shopGst: '',
        shopContact: '9876543210',
        source: 'app',
        marketCess: 0,
        commissionAmount: 0,
        isInterState: false,
        businessType: 'restaurant',
      );

      final updated = bill.copyWith(tipAmount: 100.0);
      expect(updated.tipAmount, equals(100.0));
      expect(
        updated.grandTotal,
        equals(630.0),
      ); // Tip doesn't change grandTotal
    });
  });

  // ==========================================================================
  // 6. GST rate (5% non-editable) still applies correctly alongside new fields
  // Validates: Requirement 3.3
  // ==========================================================================
  group('GST rate preservation (5% non-editable)', () {
    test('restaurant defaultGstRate is 5.0', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(config.defaultGstRate, equals(5.0));
    });

    test('restaurant gstEditable is false', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      expect(config.gstEditable, isFalse);
    });

    test('GST rate coexists with isHalf/isParcel optional fields', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.restaurant);
      // GST remains fixed
      expect(config.defaultGstRate, 5.0);
      expect(config.gstEditable, false);
      // isHalf and isParcel are also available
      expect(config.optionalFields.contains(ItemField.isHalf), isTrue);
      expect(config.optionalFields.contains(ItemField.isParcel), isTrue);
    });

    test('BillItem with isHalf/isParcel still respects GST rate', () {
      // Simulate: a half-portion, parcel item with 5% GST applied
      final item = BillItem(
        productId: 'dish_gst_001',
        productName: 'Half Paneer Tikka (Parcel)',
        qty: 1,
        price: 125.0, // Half portion price
        gstRate: 5.0,
        isHalf: true,
        isParcel: true,
      );

      // GST at 5% of (1 * 125 = 125) = 6.25, split CGST + SGST
      final taxableBase = item.qty * item.price;
      final expectedTax = taxableBase * item.gstRate / 100;
      expect(expectedTax, closeTo(6.25, 1e-9));
      expect(item.isHalf, isTrue);
      expect(item.isParcel, isTrue);
      expect(item.gstRate, equals(5.0));
    });

    test(
      'Bill with serviceCharge and tipAmount still uses 5% GST on items',
      () {
        final item = BillItem(
          productId: 'dish_gst_002',
          productName: 'Biryani',
          qty: 2,
          price: 280.0,
          gstRate: 5.0,
          cgst: 14.0,
          sgst: 14.0,
        );

        final bill = Bill(
          id: 'bill_gst_001',
          invoiceNumber: 'INV-GST-001',
          customerId: 'cust_gst_001',
          customerName: 'GST Customer',
          customerPhone: '3333333333',
          customerAddress: '',
          customerGst: '',
          date: DateTime(2024, 8, 1),
          items: [item],
          subtotal: 560.0,
          totalTax: 28.0,
          grandTotal: 616.0, // 560 + 28 + 28 service charge
          paidAmount: 666.0, // + 50 tip
          cashPaid: 666.0,
          onlinePaid: 0,
          status: 'Paid',
          paymentType: 'Cash',
          discountApplied: 0,
          marketTicket: 0,
          ownerId: 'owner_gst',
          shopName: 'GST Restaurant',
          shopAddress: '404 Cedar Ct',
          shopGst: '07AABCU9603R1ZM',
          shopContact: '9876543210',
          source: 'app',
          marketCess: 0,
          commissionAmount: 0,
          isInterState: false,
          businessType: 'restaurant',
          serviceCharge: 28.0,
          tipAmount: 50.0,
        );

        // Verify GST on the item is still 5%
        expect(bill.items.first.gstRate, equals(5.0));
        expect(bill.serviceCharge, equals(28.0));
        expect(bill.tipAmount, equals(50.0));
        expect(bill.businessType, equals('restaurant'));
      },
    );
  });
}
