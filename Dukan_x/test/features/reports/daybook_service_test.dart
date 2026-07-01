import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/services/daybook_service.dart';

void main() {
  late AppDatabase db;
  late DayBookService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = DayBookService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('computeDaySummary aggregates all transactions correctly', () async {
    final businessId = 'test_biz';
    final date = DateTime(2025, 1, 1);

    // 1. Setup Data

    // Sales: 1 Cash (1000), 1 Credit (500), 1 Split (Cash 200, Credit 300)
    await db
        .into(db.bills)
        .insert(
          BillsCompanion(
            id: Value('b1'),
            userId: Value(businessId),
            invoiceNumber: Value('INV-1'),
            itemsJson: Value('[]'),
            billDate: Value(date),
            grandTotal: Value(1000),
            paymentMode: Value('Cash'),
            cashPaid: Value(1000),
            createdAt: Value(date),
            updatedAt: Value(date),
            // Computed fields: paidAmount presumed 1000
          ),
        );
    await db
        .into(db.bills)
        .insert(
          BillsCompanion(
            id: Value('b2'),
            invoiceNumber: Value('INV-2'),
            itemsJson: Value('[]'),
            userId: Value(businessId),
            billDate: Value(date),
            grandTotal: Value(500),
            paymentMode: Value('Credit'),
            cashPaid: Value(0),
            createdAt: Value(date),
            updatedAt: Value(date),
          ),
        );
    await db
        .into(db.bills)
        .insert(
          BillsCompanion(
            id: Value('b3'),
            invoiceNumber: Value('INV-3'),
            itemsJson: Value('[]'),
            userId: Value(businessId),
            billDate: Value(date),
            grandTotal: Value(500),
            paymentMode: Value('Split'),
            cashPaid: Value(200),
            createdAt: Value(date),
            updatedAt: Value(date),
          ),
        );

    // Purchases: 1 Cash (2000), 1 Credit (1000)
    await db
        .into(db.purchaseOrders)
        .insert(
          PurchaseOrdersCompanion(
            id: Value('po1'),
            userId: Value(businessId),
            purchaseDate: Value(date),
            totalAmount: Value(2000),
            paidAmount: Value(2000),
            paymentMode: Value('Cash'),
            createdAt: Value(date),
            updatedAt: Value(date),
          ),
        );
    await db
        .into(db.purchaseOrders)
        .insert(
          PurchaseOrdersCompanion(
            id: Value('po2'),
            userId: Value(businessId),
            purchaseDate: Value(date),
            totalAmount: Value(1000),
            paidAmount: Value(0),
            paymentMode: Value('Credit'),
            createdAt: Value(date),
            updatedAt: Value(date),
          ),
        );

    // Expenses: 1 Cash (100)
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion(
            id: Value('e1'),
            userId: Value(businessId),
            expenseDate: Value(date),
            amount: Value(100),
            description: Value('Tea'),
            category: Value('Food'),
            paymentMode: Value('Cash'),
            createdAt: Value(date),
            updatedAt: Value(date),
          ),
        );

    // Payments Received: 1 Cash (300)
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion(
            id: Value('p1'),
            userId: Value(businessId),
            billId: Value('b2'),
            paymentDate: Value(date),
            amount: Value(300),
            paymentMode: Value('Cash'),
            createdAt: Value(date),
            updatedAt: Value(date),
          ),
        );

    // 2. Execute
    final summary = await service.computeDaySummary(businessId, date);

    // 3. Verify
    // Total Sales = 1000 + 500 + 500 = 2000
    expect(summary.totalSales, 2000);
    // Cash Sales = 1000 (b1) + 200 (b3) = 1200
    expect(summary.totalCashSales, 1200);
    // Credit Sales = 500 (b2) + 300 (b3) = 800
    expect(summary.totalCreditSales, 800);

    // Total Purchases = 2000 + 1000 = 3000
    expect(summary.totalPurchases, 3000);
    // Cash Purchases = 2000
    expect(summary.totalCashPurchases, 2000);

    // Expenses = 100
    expect(summary.totalCashExpenses, 100);

    // Payments Received = 300
    expect(summary.totalPaymentsReceived, 300);

    // Closing Cash Logic:
    // Opening (0) + Cash Sales (1200) + Payments (300) - Cash Purchases (2000) - Expenses (100)
    // 0 + 1200 + 300 - 2000 - 100 = 1500 - 2100 = -600
    expect(summary.computedClosingBalance, -600);

    // Verify Sync Queue
    final syncItem = await (db.select(
      db.syncQueue,
    )..where((t) => t.targetCollection.equals('day_book'))).getSingleOrNull();
    expect(syncItem, isNotNull);
    expect(syncItem!.documentId, summary.id);
  });
}
