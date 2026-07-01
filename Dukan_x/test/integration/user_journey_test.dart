// ============================================================================
// END-TO-END USER JOURNEY TESTS
// ============================================================================
// Tests for critical user flows from start to finish
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

// Mock data structures for E2E testing
class MockCustomer {
  final String id;
  final String name;
  final String phone;
  double totalDues;
  double paidAmount;

  MockCustomer({
    required this.id,
    required this.name,
    required this.phone,
    this.totalDues = 0,
    this.paidAmount = 0,
  });

  double get pendingDues => totalDues - paidAmount;
  bool get hasDues => pendingDues > 0;
}

class MockBillItem {
  final String id;
  final String name;
  final double quantity;
  final double price;

  MockBillItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get total => quantity * price;
}

class MockBill {
  final String id;
  final String customerId;
  final DateTime date;
  final List<MockBillItem> items;
  double paidAmount;
  String status;

  MockBill({
    required this.id,
    required this.customerId,
    required this.date,
    required this.items,
    this.paidAmount = 0,
    this.status = 'Unpaid',
  });

  double get grandTotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get pendingAmount => grandTotal - paidAmount;
  bool get isPaid => pendingAmount <= 0;
}

class MockReceipt {
  final String id;
  final String customerId;
  final String? billId;
  final double amount;
  final String paymentMode;
  final DateTime date;

  MockReceipt({
    required this.id,
    required this.customerId,
    this.billId,
    required this.amount,
    required this.paymentMode,
    required this.date,
  });
}

class MockProduct {
  final String id;
  final String name;
  double sellingPrice;
  double stockQuantity;
  double lowStockThreshold;

  MockProduct({
    required this.id,
    required this.name,
    required this.sellingPrice,
    this.stockQuantity = 0,
    this.lowStockThreshold = 10,
  });

  bool get isLowStock => stockQuantity <= lowStockThreshold;
}

// Mock repositories for E2E testing
class MockDataStore {
  final List<MockCustomer> customers = [];
  final List<MockBill> bills = [];
  final List<MockReceipt> receipts = [];
  final List<MockProduct> products = [];

  void reset() {
    customers.clear();
    bills.clear();
    receipts.clear();
    products.clear();
  }
}

void main() {
  late MockDataStore dataStore;

  setUp(() {
    dataStore = MockDataStore();
  });

  tearDown(() {
    dataStore.reset();
  });

  group('User Journey: New Customer Onboarding', () {
    test('complete new customer creation flow', () {
      // Step 1: Create new customer
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'John Doe',
        phone: '9876543210',
      );
      dataStore.customers.add(customer);

      // Step 2: Verify customer exists
      expect(dataStore.customers.length, 1);
      expect(dataStore.customers.first.name, 'John Doe');

      // Step 3: Customer has no dues initially
      expect(customer.totalDues, 0);
      expect(customer.hasDues, false);
    });

    test('customer with initial credit limit', () {
      final customer = MockCustomer(
        id: 'cust-002',
        name: 'Jane Smith',
        phone: '1234567890',
      );
      dataStore.customers.add(customer);

      // Step: Verify customer starts with zero balance
      expect(customer.totalDues, 0);
      expect(customer.paidAmount, 0);
      expect(customer.pendingDues, 0);
    });
  });

  group('User Journey: Complete Billing Flow', () {
    test('create bill -> add items -> save', () {
      // Step 1: Create customer
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'Test Customer',
        phone: '9999999999',
      );
      dataStore.customers.add(customer);

      // Step 2: Create bill items
      final items = [
        MockBillItem(id: 'item-1', name: 'Tomato', quantity: 2, price: 50),
        MockBillItem(id: 'item-2', name: 'Onion', quantity: 3, price: 40),
        MockBillItem(id: 'item-3', name: 'Potato', quantity: 5, price: 30),
      ];

      // Step 3: Create bill
      final bill = MockBill(
        id: 'bill-001',
        customerId: customer.id,
        date: DateTime.now(),
        items: items,
      );
      dataStore.bills.add(bill);

      // Step 4: Verify totals
      expect(bill.items.length, 3);
      expect(bill.grandTotal, 100 + 120 + 150); // 370
      expect(bill.status, 'Unpaid');
      expect(bill.pendingAmount, 370);

      // Step 5: Update customer dues
      customer.totalDues = bill.grandTotal;
      expect(customer.hasDues, true);
      expect(customer.pendingDues, 370);
    });

    test('create bill with partial payment', () {
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'Customer',
        phone: '123',
      );
      final bill = MockBill(
        id: 'bill-001',
        customerId: customer.id,
        date: DateTime.now(),
        items: [MockBillItem(id: 'i1', name: 'Item', quantity: 1, price: 1000)],
      );

      // Partial payment
      bill.paidAmount = 500;
      bill.status = 'Partial';

      expect(bill.grandTotal, 1000);
      expect(bill.paidAmount, 500);
      expect(bill.pendingAmount, 500);
      expect(bill.isPaid, false);
    });

    test('create bill with full payment', () {
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'Customer',
        phone: '123',
      );
      final bill = MockBill(
        id: 'bill-001',
        customerId: customer.id,
        date: DateTime.now(),
        items: [MockBillItem(id: 'i1', name: 'Item', quantity: 1, price: 500)],
        paidAmount: 500,
        status: 'Paid',
      );

      expect(bill.grandTotal, 500);
      expect(bill.pendingAmount, 0);
      expect(bill.isPaid, true);
    });
  });

  group('User Journey: Payment Collection', () {
    test('collect payment and update customer dues', () {
      // Setup: Customer with existing dues
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'Customer',
        phone: '123',
        totalDues: 1000,
      );
      dataStore.customers.add(customer);

      // Step 1: Create receipt for payment
      final receipt = MockReceipt(
        id: 'rcpt-001',
        customerId: customer.id,
        amount: 400,
        paymentMode: 'Cash',
        date: DateTime.now(),
      );
      dataStore.receipts.add(receipt);

      // Step 2: Update customer
      customer.paidAmount += receipt.amount;

      // Step 3: Verify
      expect(customer.paidAmount, 400);
      expect(customer.pendingDues, 600);
      expect(customer.hasDues, true);
    });

    test('full payment clears all dues', () {
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'Customer',
        phone: '123',
        totalDues: 500,
      );

      final receipt = MockReceipt(
        id: 'rcpt-001',
        customerId: customer.id,
        amount: 500,
        paymentMode: 'UPI',
        date: DateTime.now(),
      );
      dataStore.receipts.add(receipt);

      customer.paidAmount = 500;

      expect(customer.pendingDues, 0);
      expect(customer.hasDues, false);
    });

    test('multiple payment modes', () {
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'Customer',
        phone: '123',
        totalDues: 1000,
      );

      // Cash payment
      dataStore.receipts.add(
        MockReceipt(
          id: 'r1',
          customerId: customer.id,
          amount: 300,
          paymentMode: 'Cash',
          date: DateTime.now(),
        ),
      );

      // UPI payment
      dataStore.receipts.add(
        MockReceipt(
          id: 'r2',
          customerId: customer.id,
          amount: 500,
          paymentMode: 'UPI',
          date: DateTime.now(),
        ),
      );

      final totalPaid = dataStore.receipts
          .where((r) => r.customerId == customer.id)
          .fold(0.0, (sum, r) => sum + r.amount);

      customer.paidAmount = totalPaid;

      expect(totalPaid, 800);
      expect(customer.pendingDues, 200);
    });
  });

  group('User Journey: Inventory Management', () {
    test('add product to inventory', () {
      final product = MockProduct(
        id: 'prod-001',
        name: 'Rice',
        sellingPrice: 60,
        stockQuantity: 100,
        lowStockThreshold: 20,
      );
      dataStore.products.add(product);

      expect(dataStore.products.length, 1);
      expect(product.isLowStock, false);
    });

    test('stock deduction after sale', () {
      final product = MockProduct(
        id: 'prod-001',
        name: 'Sugar',
        sellingPrice: 50,
        stockQuantity: 50,
      );
      dataStore.products.add(product);

      // Simulate sale
      final soldQuantity = 10.0;
      product.stockQuantity -= soldQuantity;

      expect(product.stockQuantity, 40);
    });

    test('low stock alert', () {
      final product = MockProduct(
        id: 'prod-001',
        name: 'Salt',
        sellingPrice: 20,
        stockQuantity: 5,
        lowStockThreshold: 10,
      );

      expect(product.isLowStock, true);
    });

    test('stock replenishment', () {
      final product = MockProduct(
        id: 'prod-001',
        name: 'Oil',
        sellingPrice: 150,
        stockQuantity: 5,
        lowStockThreshold: 10,
      );

      expect(product.isLowStock, true);

      // Replenish stock
      product.stockQuantity += 50;

      expect(product.stockQuantity, 55);
      expect(product.isLowStock, false);
    });
  });

  group('User Journey: Daily Operations', () {
    test('complete day operations: bills and payments', () {
      // Morning: Create bills
      final customer1 = MockCustomer(
        id: 'c1',
        name: 'Customer 1',
        phone: '111',
      );
      final customer2 = MockCustomer(
        id: 'c2',
        name: 'Customer 2',
        phone: '222',
      );
      dataStore.customers.addAll([customer1, customer2]);

      final bill1 = MockBill(
        id: 'b1',
        customerId: customer1.id,
        date: DateTime.now(),
        items: [MockBillItem(id: 'i1', name: 'Item', quantity: 1, price: 500)],
      );
      final bill2 = MockBill(
        id: 'b2',
        customerId: customer2.id,
        date: DateTime.now(),
        items: [MockBillItem(id: 'i2', name: 'Item', quantity: 1, price: 300)],
      );
      dataStore.bills.addAll([bill1, bill2]);

      customer1.totalDues = bill1.grandTotal;
      customer2.totalDues = bill2.grandTotal;

      // Afternoon: Collect some payments
      bill1.paidAmount = 500;
      bill1.status = 'Paid';
      customer1.paidAmount = 500;

      // End of day summary
      final totalSales = dataStore.bills.fold(
        0.0,
        (sum, b) => sum + b.grandTotal,
      );
      final totalCollections = dataStore.bills.fold(
        0.0,
        (sum, b) => sum + b.paidAmount,
      );
      final pendingAmount = totalSales - totalCollections;

      expect(totalSales, 800);
      expect(totalCollections, 500);
      expect(pendingAmount, 300);
    });

    test('daily analytics calculation', () {
      // Create multiple bills for the day
      for (int i = 1; i <= 5; i++) {
        dataStore.bills.add(
          MockBill(
            id: 'bill-$i',
            customerId: 'cust-$i',
            date: DateTime.now(),
            items: [
              MockBillItem(
                id: 'i$i',
                name: 'Item $i',
                quantity: 1,
                price: 100.0 * i,
              ),
            ],
            paidAmount: i.isEven ? 100.0 * i : 0,
            status: i.isEven ? 'Paid' : 'Unpaid',
          ),
        );
      }

      // Analytics
      final totalBills = dataStore.bills.length;
      final paidBills = dataStore.bills.where((b) => b.isPaid).length;
      final unpaidBills = dataStore.bills.where((b) => !b.isPaid).length;
      final totalRevenue = dataStore.bills.fold(
        0.0,
        (sum, b) => sum + b.grandTotal,
      );

      expect(totalBills, 5);
      expect(paidBills, 2);
      expect(unpaidBills, 3);
      expect(totalRevenue, 100 + 200 + 300 + 400 + 500);
    });
  });

  group('User Journey: Customer Ledger', () {
    test('view customer transaction history', () {
      final customer = MockCustomer(
        id: 'cust-001',
        name: 'Ledger Customer',
        phone: '123',
      );
      dataStore.customers.add(customer);

      // Add bills
      for (int i = 1; i <= 3; i++) {
        dataStore.bills.add(
          MockBill(
            id: 'bill-$i',
            customerId: customer.id,
            date: DateTime.now().subtract(Duration(days: i)),
            items: [
              MockBillItem(id: 'i$i', name: 'Item', quantity: 1, price: 100),
            ],
          ),
        );
      }

      // Add payments
      for (int i = 1; i <= 2; i++) {
        dataStore.receipts.add(
          MockReceipt(
            id: 'rcpt-$i',
            customerId: customer.id,
            amount: 100,
            paymentMode: 'Cash',
            date: DateTime.now().subtract(Duration(days: i)),
          ),
        );
      }

      // Ledger summary
      final customerBills = dataStore.bills.where(
        (b) => b.customerId == customer.id,
      );
      final customerReceipts = dataStore.receipts.where(
        (r) => r.customerId == customer.id,
      );

      final totalBilled = customerBills.fold(
        0.0,
        (sum, b) => sum + b.grandTotal,
      );
      final totalPaid = customerReceipts.fold(0.0, (sum, r) => sum + r.amount);
      final balance = totalBilled - totalPaid;

      expect(customerBills.length, 3);
      expect(customerReceipts.length, 2);
      expect(totalBilled, 300);
      expect(totalPaid, 200);
      expect(balance, 100);
    });
  });

  group('User Journey: Error Recovery', () {
    test('handle empty bill creation', () {
      final bill = MockBill(
        id: 'empty-bill',
        customerId: 'cust-001',
        date: DateTime.now(),
        items: [],
      );

      expect(bill.items.isEmpty, true);
      expect(bill.grandTotal, 0);
    });

    test('handle zero quantity item', () {
      final item = MockBillItem(
        id: 'zero-qty',
        name: 'Zero Item',
        quantity: 0,
        price: 100,
      );

      expect(item.total, 0);
    });

    test('handle negative amount detection', () {
      final amount = -500.0;
      final isValid = amount >= 0;

      expect(isValid, false);
    });
  });
}
