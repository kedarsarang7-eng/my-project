// ============================================================================
// BILL MODEL TESTS
// ============================================================================
// Comprehensive tests for Bill and BillItem models
//
// Author: DukanX Engineering
// Version: 3.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/bill.dart';

void main() {
  group('BillItem Model Tests', () {
    test('should create BillItem with required fields', () {
      final item = BillItem(
        productId: 'veg-001',
        productName: 'Tomato',
        qty: 2.5,
        price: 40.0,
      );

      expect(item.productId, 'veg-001');
      expect(item.productName, 'Tomato');
      expect(item.qty, 2.5);
      expect(item.price, 40.0);
      // Total is calculated: qty * price - discount + taxes
      expect(item.total, 100.0);
    });

    test('should create BillItem with tax fields', () {
      final item = BillItem(
        productId: 'veg-002',
        productName: 'Potato',
        qty: 5.0,
        price: 30.0,
        gstRate: 5.0,
        cgst: 3.75,
        sgst: 3.75,
      );

      expect(item.gstRate, 5.0);
      expect(item.cgst, 3.75);
      expect(item.sgst, 3.75);
      // Total = (5 * 30) - 0 + 3.75 + 3.75 + 0 = 157.5
      expect(item.total, 157.5);
    });

    test('toMap should serialize correctly', () {
      final item = BillItem(
        productId: 'veg-003',
        productName: 'Onion',
        qty: 3.0,
        price: 25.0,
        unit: 'kg',
        hsn: '12345',
      );

      final map = item.toMap();

      expect(map['productId'], 'veg-003');
      expect(map['productName'], 'Onion');
      expect(map['qty'], 3.0);
      expect(map['price'], 25.0);
      expect(map['unit'], 'kg');
      expect(map['hsn'], '12345');
      // Backward compatibility fields
      expect(map['vegName'], 'Onion');
      expect(map['qtyKg'], 3.0);
      expect(map['pricePerKg'], 25.0);
    });

    test('fromMap should deserialize correctly', () {
      final map = {
        'vegId': 'veg-004',
        'itemName': 'Carrot',
        'qty': 4,
        'price': 35,
        'unit': 'kg',
        'gstRate': 5,
        'cgst': 3.5,
        'sgst': 3.5,
      };

      final item = BillItem.fromMap(map);

      expect(item.productId, 'veg-004');
      expect(item.productName, 'Carrot');
      expect(item.qty, 4.0);
      expect(item.price, 35.0);
      expect(item.gstRate, 5.0);
    });

    test('fromMap should handle legacy field names', () {
      final map = {
        'vegId': 'veg-005',
        'vegName': 'Cabbage',
        'qtyKg': 2,
        'pricePerKg': 20,
      };

      final item = BillItem.fromMap(map);

      expect(item.itemName, 'Cabbage');
      expect(item.qty, 2.0);
      expect(item.price, 20.0);
    });

    test('backward compatibility getters', () {
      final item = BillItem(
        productId: 'veg-006',
        productName: 'Brinjal',
        qty: 1.5,
        price: 45.0,
      );

      // Backward compatibility getters
      expect(item.vegName, 'Brinjal');
      expect(item.qtyKg, 1.5);
      expect(item.pricePerKg, 45.0);
    });

    test('copyWith should create modified copy', () {
      final original = BillItem(
        productId: 'veg-007',
        productName: 'Spinach',
        qty: 1.0,
        price: 30.0,
      );

      final updated = original.copyWith(qty: 2.0, discount: 5.0);

      expect(updated.qty, 2.0);
      expect(updated.discount, 5.0);
      // Unchanged
      expect(updated.productName, 'Spinach');
      expect(updated.productId, 'veg-007');
    });
  });

  group('Bill Model Tests', () {
    test('should create Bill with required fields', () {
      final now = DateTime.now();
      final bill = Bill(
        id: 'bill-001',
        customerId: 'cust-001',
        date: now,
        items: [],
      );

      expect(bill.id, 'bill-001');
      expect(bill.customerId, 'cust-001');
      expect(bill.date, now);
      expect(bill.status, 'Unpaid'); // default
      expect(bill.paymentType, 'Cash'); // default
    });

    test('should create Bill with all fields', () {
      final now = DateTime.now();
      final items = [
        BillItem(productId: 'v1', productName: 'Tomato', qty: 2, price: 40),
        BillItem(productId: 'v2', productName: 'Potato', qty: 3, price: 30),
      ];

      final bill = Bill(
        id: 'bill-002',
        invoiceNumber: 'INV-2024-002',
        customerId: 'cust-001',
        customerName: 'John Doe',
        customerPhone: '9876543210',
        customerAddress: '123 Main St',
        date: now,
        items: items,
        subtotal: 170.0,
        totalTax: 30.6,
        grandTotal: 200.6,
        paidAmount: 100.0,
        cashPaid: 100.0,
        status: 'Partial',
        ownerId: 'owner-001',
        shopName: 'Test Shop',
      );

      expect(bill.invoiceNumber, 'INV-2024-002');
      expect(bill.items.length, 2);
      expect(bill.subtotal, 170.0);
      expect(bill.grandTotal, 200.6);
      expect(bill.paidAmount, 100.0);
      expect(bill.status, 'Partial');
      expect(bill.shopName, 'Test Shop');
    });

    test('pendingAmount should calculate correctly', () {
      final bill = Bill(
        id: 'bill-003',
        customerId: 'cust-002',
        date: DateTime.now(),
        items: [],
        grandTotal: 1000.0,
        paidAmount: 400.0,
      );

      expect(bill.pendingAmount, 600.0);
    });

    test('isPaid should return true when fully paid', () {
      final paidBill = Bill(
        id: 'bill-004',
        customerId: 'cust-003',
        date: DateTime.now(),
        items: [],
        grandTotal: 1000.0,
        paidAmount: 1000.0,
      );

      expect(paidBill.isPaid, true);
    });

    test('isPaid should return false when partially paid', () {
      final partialBill = Bill(
        id: 'bill-005',
        customerId: 'cust-004',
        date: DateTime.now(),
        items: [],
        grandTotal: 1000.0,
        paidAmount: 500.0,
      );

      expect(partialBill.isPaid, false);
    });

    test('toMap should serialize all fields', () {
      final now = DateTime.now();
      final items = [
        BillItem(productId: 'v1', productName: 'Item1', qty: 1, price: 100),
      ];

      final bill = Bill(
        id: 'bill-006',
        invoiceNumber: 'INV-006',
        customerId: 'cust-005',
        customerName: 'Test Customer',
        date: now,
        items: items,
        subtotal: 100.0,
        grandTotal: 100.0,
        status: 'Unpaid',
        ownerId: 'owner-002',
      );

      final map = bill.toMap();

      expect(map['invoiceNumber'], 'INV-006');
      expect(map['customerId'], 'cust-005');
      expect(map['customerName'], 'Test Customer');
      expect(map['subtotal'], 100.0);
      expect(map['grandTotal'], 100.0);
      expect(map['items'], isA<List>());
    });

    test('fromMap should deserialize correctly', () {
      final map = {
        'invoiceNumber': 'INV-007',
        'customerId': 'cust-006',
        'customerName': 'Deser Customer',
        'date': DateTime.now().toIso8601String(),
        'items': [
          {'vegId': 'v1', 'itemName': 'Item1', 'qty': 2, 'price': 50},
        ],
        'subtotal': 100,
        'grandTotal': 100,
        'paidAmount': 0,
        'status': 'Unpaid',
        'ownerId': 'owner-003',
      };

      final bill = Bill.fromMap('bill-007', map);

      expect(bill.id, 'bill-007');
      expect(bill.invoiceNumber, 'INV-007');
      expect(bill.customerName, 'Deser Customer');
      expect(bill.items.length, 1);
    });

    test('copyWith should create modified copy', () {
      final bill = Bill(
        id: 'bill-008',
        invoiceNumber: 'INV-008',
        customerId: 'cust-007',
        date: DateTime.now(),
        items: [],
        grandTotal: 500.0,
        paidAmount: 0,
        status: 'Unpaid',
      );

      final updated = bill.copyWith(paidAmount: 500.0, status: 'Paid');

      expect(updated.paidAmount, 500.0);
      expect(updated.status, 'Paid');
      // Unchanged
      expect(updated.id, 'bill-008');
      expect(updated.grandTotal, 500.0);
    });

    test('Bill.empty should create empty bill', () {
      final emptyBill = Bill.empty();

      expect(emptyBill.id, '');
      expect(emptyBill.customerId, '');
      expect(emptyBill.items, isEmpty);
    });
  });

  group('Bill Status Derivation', () {
    test('should derive Paid status', () {
      final bill = Bill(
        id: 'status-001',
        customerId: 'c1',
        date: DateTime.now(),
        items: [],
        grandTotal: 100.0,
        paidAmount: 100.0,
      ).sanitized();

      expect(bill.status, 'Paid');
    });

    test('should derive Unpaid status', () {
      final bill = Bill(
        id: 'status-002',
        customerId: 'c2',
        date: DateTime.now(),
        items: [],
        grandTotal: 100.0,
        paidAmount: 0.0,
      ).sanitized();

      expect(bill.status, 'Unpaid');
    });

    test('should derive Partial status', () {
      final bill = Bill(
        id: 'status-003',
        customerId: 'c3',
        date: DateTime.now(),
        items: [],
        grandTotal: 100.0,
        paidAmount: 50.0,
      ).sanitized();

      expect(bill.status, 'Partial');
    });
  });

  group('Bill Edge Cases', () {
    test('should handle empty items list', () {
      final bill = Bill(
        id: 'edge-001',
        customerId: 'c1',
        date: DateTime.now(),
        items: [],
      );

      expect(bill.items, isEmpty);
    });

    test('should handle many items', () {
      final items = List.generate(
        50,
        (i) => BillItem(
          productId: 'v$i',
          productName: 'Item $i',
          qty: 1,
          price: 10,
        ),
      );

      final bill = Bill(
        id: 'edge-002',
        customerId: 'c2',
        date: DateTime.now(),
        items: items,
        grandTotal: 500.0,
      );

      expect(bill.items.length, 50);
    });

    test('should handle decimal quantities', () {
      final item = BillItem(
        productId: 'v1',
        productName: 'Rice',
        qty: 2.75,
        price: 60,
      );

      expect(item.qty, 2.75);
      expect(item.total, 165.0);
    });

    test('should handle vendor snapshot fields', () {
      final bill = Bill(
        id: 'vendor-snap-001',
        customerId: 'c1',
        date: DateTime.now(),
        items: [],
        shopName: 'Test Shop',
        shopAddress: '123 Shop Street',
        shopGst: 'GST123456789',
        shopContact: '9876543210',
      );

      expect(bill.shopName, 'Test Shop');
      expect(bill.shopAddress, '123 Shop Street');
      expect(bill.shopGst, 'GST123456789');
      expect(bill.shopContact, '9876543210');
    });
  });
}
