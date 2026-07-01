// ============================================================================
// RESTAURANT BILL REPOSITORY
// ============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/repository/bills_repository.dart'; // Core Bill
import '../../../../core/di/service_locator.dart'; // For default injection
import '../models/restaurant_bill_model.dart';
// Logging instead of print or remove
// debugPrint('Searching bills: $query'); // Core Bill Model
import '../../../../models/business_type.dart';
import '../models/food_order_model.dart'; // Ensure FoodOrder is available

/// Repository for managing restaurant bills
class RestaurantBillRepository {
  final AppDatabase _db;
  final ErrorHandler _errorHandler;
  static const _uuid = Uuid();

  final BillsRepository _billsRepository;

  RestaurantBillRepository({
    AppDatabase? db,
    ErrorHandler? errorHandler,
    BillsRepository? billsRepository,
  }) : _db = db ?? AppDatabase.instance,
       _errorHandler = errorHandler ?? ErrorHandler.instance,
       _billsRepository = billsRepository ?? sl<BillsRepository>();

  // ============================================================================
  // BILL GENERATION
  // ============================================================================

  /// Generate bill for an order
  Future<RepositoryResult<RestaurantBill>> generateBill({
    required String vendorId,
    required String orderId,
    required String customerId,
    required double subtotal,
    String? tableNumber,
    double cgstRate = 2.5,
    double sgstRate = 2.5,
    double serviceChargeRate = 0,
    double discount = 0,
  }) async {
    return await _errorHandler.runSafe<RestaurantBill>(() async {
      final now = DateTime.now();
      final id = _uuid.v4();

      // Calculate taxes
      final cgst = subtotal * (cgstRate / 100);
      final sgst = subtotal * (sgstRate / 100);
      final serviceCharge = subtotal * (serviceChargeRate / 100);
      final grandTotal = subtotal + cgst + sgst + serviceCharge - discount;

      // Generate bill number
      final billNumber = await _generateBillNumber(vendorId);

      // Tax breakdown
      final taxBreakdown = [
        TaxBreakdownItem(name: 'CGST', rate: cgstRate, amount: cgst),
        TaxBreakdownItem(name: 'SGST', rate: sgstRate, amount: sgst),
        if (serviceCharge > 0)
          TaxBreakdownItem(
            name: 'Service Charge',
            rate: serviceChargeRate,
            amount: serviceCharge,
          ),
      ];

      await _db
          .into(_db.restaurantBills)
          .insert(
            RestaurantBillsCompanion.insert(
              id: id,
              vendorId: vendorId,
              orderId: orderId,
              customerId: customerId,
              tableNumber: Value(tableNumber),
              billNumber: billNumber,
              subtotal: subtotal,
              cgst: Value(cgst),
              sgst: Value(sgst),
              serviceCharge: Value(serviceCharge),
              discountAmount: Value(discount),
              grandTotal: grandTotal,
              taxBreakdownJson: Value(
                jsonEncode(taxBreakdown.map((e) => e.toJson()).toList()),
              ),
              paymentStatus: Value(BillPaymentStatus.generated.value),
              generatedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.restaurantBills,
      )..where((t) => t.id.equals(id))).getSingle();

      final restaurantBill = RestaurantBill.fromEntity(entity);

      // ============================================================
      // CORE INTEGRATION: Create Shadow Bill
      // ============================================================
      try {
        // 1. Fetch the Order to get Items
        final orderEntity = await (_db.select(
          _db.foodOrders,
        )..where((t) => t.id.equals(orderId))).getSingle();
        final order = FoodOrder.fromEntity(orderEntity);

        // 2. Map Items to BillItem
        final billItems = order.items.map((item) {
          return BillItem(
            productId: item.menuItemId,
            productName: item.itemName,
            qty: item.quantity.toDouble(),
            price: item.unitPrice,
            totalOverride: item.totalPrice, // Use exact total from order
            tableNo: tableNumber,
            notes: item.specialInstructions,
            // Defaults
            unit: 'plate',
          );
        }).toList();

        // 3. Create Core Bill
        final coreBill = Bill(
          id: id, // LINKAGE: Same ID
          invoiceNumber: billNumber,
          date: now,
          subtotal: subtotal,
          totalTax: cgst + sgst,
          discountApplied: discount,
          grandTotal: grandTotal,
          paidAmount: 0, // Initially unpaid
          customerName: customerId == 'GUEST'
              ? 'Guest'
              : (customerId), // Placeholder
          customerId: customerId,
          businessType: BusinessType.restaurant.name,
          status: 'Unpaid',
          paymentType: 'Unpaid',
          items: billItems,
          ownerId: vendorId,
          updatedAt: now,
          tableNumber: tableNumber,
          serviceCharge: serviceCharge,
          source: 'RESTAURANT',
        );

        // 4. Save to Core Repository
        // This handles Ledger, GST, and Inventory (Recipe)
        await _billsRepository.createBill(coreBill);
      } catch (e) {
        // Log error but don't fail restaurant bill generation
        debugPrint('Failed to create shadow bill: $e');
      }

      return restaurantBill;
    }, 'generateBill');
  }

  /// Generate sequential bill number
  Future<String> _generateBillNumber(String vendorId) async {
    final now = DateTime.now();
    final prefix = 'BILL-${now.year}${now.month.toString().padLeft(2, '0')}';

    // Count existing bills for this month
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final count =
        await (_db.select(_db.restaurantBills)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.generatedAt.isBiggerOrEqualValue(startOfMonth) &
                  t.generatedAt.isSmallerOrEqualValue(endOfMonth),
            ))
            .get()
            .then((list) => list.length);

    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }

  // ============================================================================
  // BILL QUERIES
  // ============================================================================

  /// Get bill by ID
  Future<RepositoryResult<RestaurantBill?>> getBillById(String id) async {
    return await _errorHandler.runSafe<RestaurantBill?>(() async {
      final entity = await (_db.select(
        _db.restaurantBills,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      return entity != null ? RestaurantBill.fromEntity(entity) : null;
    }, 'getBillById');
  }

  /// Get bill by order ID
  Future<RepositoryResult<RestaurantBill?>> getBillByOrder(
    String orderId,
  ) async {
    return await _errorHandler.runSafe<RestaurantBill?>(() async {
      final entity = await (_db.select(
        _db.restaurantBills,
      )..where((t) => t.orderId.equals(orderId))).getSingleOrNull();

      return entity != null ? RestaurantBill.fromEntity(entity) : null;
    }, 'getBillByOrder');
  }

  /// Get all bills for a vendor
  Future<RepositoryResult<List<RestaurantBill>>> getVendorBills(
    String vendorId, {
    DateTime? fromDate,
    DateTime? toDate,
    BillPaymentStatus? status,
  }) async {
    return await _errorHandler.runSafe<List<RestaurantBill>>(() async {
      var query = _db.select(_db.restaurantBills)
        ..where((t) => t.vendorId.equals(vendorId));

      if (fromDate != null) {
        query = query
          ..where((t) => t.generatedAt.isBiggerOrEqualValue(fromDate));
      }
      if (toDate != null) {
        query = query
          ..where((t) => t.generatedAt.isSmallerOrEqualValue(toDate));
      }
      if (status != null) {
        query = query..where((t) => t.paymentStatus.equals(status.value));
      }

      final entities =
          await (query..orderBy([(t) => OrderingTerm.desc(t.generatedAt)]))
              .get();

      return entities.map((e) => RestaurantBill.fromEntity(e)).toList();
    }, 'getVendorBills');
  }

  /// Get pending bills (not paid)
  Future<RepositoryResult<List<RestaurantBill>>> getPendingBills(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<RestaurantBill>>(() async {
      final entities =
          await (_db.select(_db.restaurantBills)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.paymentStatus.isIn([
                        BillPaymentStatus.pending.value,
                        BillPaymentStatus.generated.value,
                      ]),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.generatedAt)]))
              .get();

      return entities.map((e) => RestaurantBill.fromEntity(e)).toList();
    }, 'getPendingBills');
  }

  // ============================================================================
  // PAYMENT OPERATIONS
  // ============================================================================

  /// Mark bill as paid
  Future<RepositoryResult<void>> markBillPaid(
    String billId,
    String paymentMode,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // 1. Update Restaurant Bill
      await (_db.update(
        _db.restaurantBills,
      )..where((t) => t.id.equals(billId))).write(
        RestaurantBillsCompanion(
          paymentStatus: Value(BillPaymentStatus.paid.value),
          paymentMode: Value(paymentMode),
          paidAt: Value(now),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // 2. Sync Payment to Core Bill
      try {
        final bill = await (_db.select(
          _db.restaurantBills,
        )..where((t) => t.id.equals(billId))).getSingle();

        await _billsRepository.recordPayment(
          userId: bill.vendorId,
          billId: billId,
          amount: bill.grandTotal,
          paymentMode: paymentMode,
        );
      } catch (e) {
        debugPrint('Failed to sync payment to Core Bill: $e');
      }
    }, 'markBillPaid');
  }

  /// Cancel a bill
  Future<RepositoryResult<void>> cancelBill(String billId) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.restaurantBills,
      )..where((t) => t.id.equals(billId))).write(
        RestaurantBillsCompanion(
          paymentStatus: Value(BillPaymentStatus.cancelled.value),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
    }, 'cancelBill');
  }

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Get today's total revenue
  Future<double> getTodayRevenue(String vendorId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final bills =
        await (_db.select(_db.restaurantBills)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.generatedAt.isBiggerOrEqualValue(startOfDay) &
                  t.paymentStatus.equals(BillPaymentStatus.paid.value),
            ))
            .get();

    return bills.fold<double>(0, (sum, bill) => sum + bill.grandTotal);
  }

  /// Get today's bill count
  Future<int> getTodayBillCount(String vendorId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final bills =
        await (_db.select(_db.restaurantBills)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.generatedAt.isBiggerOrEqualValue(startOfDay),
            ))
            .get();

    return bills.length;
  }

  /// Get revenue by date range
  Future<double> getRevenueByDateRange(
    String vendorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final bills =
        await (_db.select(_db.restaurantBills)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.generatedAt.isBiggerOrEqualValue(startDate) &
                  t.generatedAt.isSmallerOrEqualValue(endDate) &
                  t.paymentStatus.equals(BillPaymentStatus.paid.value),
            ))
            .get();

    return bills.fold<double>(0, (sum, bill) => sum + bill.grandTotal);
  }

  /// Get revenue for a specific date (returns RepositoryResult)
  Future<RepositoryResult<double>> getDailyRevenue(
    String vendorId,
    DateTime date,
  ) async {
    return await _errorHandler.runSafe<double>(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final bills =
          await (_db.select(_db.restaurantBills)..where(
                (t) =>
                    t.vendorId.equals(vendorId) &
                    t.generatedAt.isBiggerOrEqualValue(startOfDay) &
                    t.generatedAt.isSmallerThanValue(endOfDay) &
                    t.paymentStatus.equals(BillPaymentStatus.paid.value),
              ))
              .get();

      return bills.fold<double>(0, (sum, bill) => sum + bill.grandTotal);
    }, 'getDailyRevenue');
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Get unsynced bills
  Future<List<RestaurantBill>> getUnsyncedBills(String vendorId) async {
    final entities =
        await (_db.select(_db.restaurantBills)..where(
              (t) => t.vendorId.equals(vendorId) & t.isSynced.equals(false),
            ))
            .get();

    return entities.map((e) => RestaurantBill.fromEntity(e)).toList();
  }

  /// Mark bill as synced
  Future<void> markBillSynced(String billId) async {
    await (_db.update(_db.restaurantBills)..where((t) => t.id.equals(billId)))
        .write(const RestaurantBillsCompanion(isSynced: Value(true)));
  }
}
