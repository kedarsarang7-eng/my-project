// ============================================================================
// STATEMENTS REPOSITORY - COMPREHENSIVE STATEMENT GENERATION
// ============================================================================
// Generates various business statements with real data from Drift database
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../error/error_handler.dart';
export '../error/error_handler.dart' show RepositoryResult;

class StatementsRepository {
  final AppDatabase database;
  final ErrorHandler errorHandler;

  StatementsRepository({required this.database, required this.errorHandler});

  // ============================================================================
  // PHASE 1.1: INVOICE-WISE CUSTOMER STATEMENT
  // ============================================================================

  /// Get detailed invoice statement for a customer within date range
  Future<RepositoryResult<CustomerInvoiceStatement>>
  getCustomerInvoiceStatement({
    required String userId,
    required String customerId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return errorHandler.runSafe<CustomerInvoiceStatement>(() async {
      // Get customer details
      final customerQuery = database.select(database.customers)
        ..where(
          (c) =>
              c.id.equals(customerId) &
              c.userId.equals(userId) &
              c.deletedAt.isNull(),
        );
      final customer = await customerQuery.getSingleOrNull();

      if (customer == null) {
        throw Exception('Customer not found');
      }

      // Get all bills for this customer in date range
      final billsQuery = database.select(database.bills)
        ..where(
          (b) =>
              b.userId.equals(userId) &
              b.customerId.equals(customerId) &
              b.billDate.isBiggerOrEqualValue(startDate) &
              b.billDate.isSmallerThanValue(
                endDate.add(const Duration(days: 1)),
              ) &
              b.deletedAt.isNull(),
        )
        ..orderBy([(b) => OrderingTerm.asc(b.billDate)]);

      final bills = await billsQuery.get();

      // Calculate opening balance (all transactions before start date)
      final openingBalanceQuery = database.selectOnly(database.bills)
        ..addColumns([
          database.bills.grandTotal.sum(),
          database.bills.paidAmount.sum(),
        ])
        ..where(
          database.bills.userId.equals(userId) &
              database.bills.customerId.equals(customerId) &
              database.bills.billDate.isSmallerThanValue(startDate) &
              database.bills.deletedAt.isNull(),
        );

      final openingResult = await openingBalanceQuery.getSingleOrNull();
      final openingTotal =
          openingResult?.read(database.bills.grandTotal.sum()) ?? 0.0;
      final openingPaid =
          openingResult?.read(database.bills.paidAmount.sum()) ?? 0.0;
      final openingBalance = openingTotal - openingPaid;

      // Build invoice entries
      final List<InvoiceStatementEntry> entries = [];
      double runningBalance = openingBalance;
      double totalSales = 0;
      double totalPaid = 0;
      double totalDue = 0;

      for (final bill in bills) {
        final amount = bill.grandTotal;
        final paid = bill.paidAmount;
        final due = amount - paid;

        runningBalance += due;
        totalSales += amount;
        totalPaid += paid;
        totalDue += due;

        entries.add(
          InvoiceStatementEntry(
            invoiceId: bill.id,
            invoiceNumber: bill.invoiceNumber,
            date: bill.billDate,
            amount: amount,
            paidAmount: paid,
            balance: due,
            runningBalance: runningBalance,
            status: bill.status,
            items: await _getBillItems(bill.id),
          ),
        );
      }

      // Calculate aging
      final aging = await _calculateInvoiceAging(userId, customerId, endDate);

      return CustomerInvoiceStatement(
        customerId: customerId,
        customerName: customer.name,
        customerPhone: customer.phone,
        customerAddress: customer.address,
        gstin: customer.gstin,
        startDate: startDate,
        endDate: endDate,
        openingBalance: openingBalance,
        closingBalance: runningBalance,
        totalSales: totalSales,
        totalPaid: totalPaid,
        totalDue: totalDue,
        entries: entries,
        aging: aging,
      );
    }, 'getCustomerInvoiceStatement');
  }

  /// Get all bills for a customer (simplified for statement list)
  Future<RepositoryResult<List<Map<String, dynamic>>>>
  getCustomerBillsForStatement({
    required String userId,
    required String customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return errorHandler.runSafe<List<Map<String, dynamic>>>(() async {
      var query = database.select(database.bills)
        ..where(
          (b) =>
              b.userId.equals(userId) &
              b.customerId.equals(customerId) &
              b.deletedAt.isNull(),
        );

      if (startDate != null) {
        query = query..where((b) => b.billDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (b) => b.billDate.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }

      query = query..orderBy([(b) => OrderingTerm.desc(b.billDate)]);

      final bills = await query.get();

      return bills
          .map(
            (b) => {
              'id': b.id,
              'invoice_number': b.invoiceNumber,
              'date': b.billDate,
              'total': b.grandTotal,
              'paid': b.paidAmount,
              'balance': b.grandTotal - b.paidAmount,
              'status': b.status,
            },
          )
          .toList();
    }, 'getCustomerBillsForStatement');
  }

  /// Watch all bills for a customer in real-time (Drift stream query)
  Stream<List<Map<String, dynamic>>> watchCustomerBillsForStatement({
    required String userId,
    required String customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var query = database.select(database.bills)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.customerId.equals(customerId) &
            b.deletedAt.isNull(),
      );

    if (startDate != null) {
      query = query..where((b) => b.billDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query = query
        ..where(
          (b) => b.billDate.isSmallerThanValue(
            endDate.add(const Duration(days: 1)),
          ),
        );
    }

    query = query..orderBy([(b) => OrderingTerm.desc(b.billDate)]);

    return query.watch().map(
      (bills) => bills
          .map(
            (b) => {
              'id': b.id,
              'invoice_number': b.invoiceNumber,
              'date': b.billDate,
              'total': b.grandTotal,
              'paid': b.paidAmount,
              'balance': b.grandTotal - b.paidAmount,
              'status': b.status,
            },
          )
          .toList(),
    );
  }

  // ============================================================================
  // PHASE 1.2: STOCK VALUATION STATEMENT
  // ============================================================================

  /// Get comprehensive stock valuation statement
  Future<RepositoryResult<StockValuationStatement>> getStockValuationStatement({
    required String userId,
    String? category,
    bool includeZeroStock = false,
  }) {
    return errorHandler.runSafe<StockValuationStatement>(() async {
      var query = database.select(database.products)
        ..where((p) => p.userId.equals(userId) & p.deletedAt.isNull());

      if (!includeZeroStock) {
        query = query..where((p) => p.stockQuantity.isBiggerThanValue(0));
      }
      if (category != null && category.isNotEmpty) {
        query = query..where((p) => p.category.equals(category));
      }

      query = query..orderBy([(p) => OrderingTerm.asc(p.name)]);

      final products = await query.get();

      final List<StockValuationItem> items = [];
      double totalValue = 0;
      double totalCost = 0;
      int totalItems = 0;
      int lowStockCount = 0;

      for (final product in products) {
        final stockValue = product.stockQuantity * product.sellingPrice;
        final costValue = product.stockQuantity * product.costPrice;
        final isLowStock = product.stockQuantity <= product.lowStockThreshold;

        if (isLowStock) lowStockCount++;

        items.add(
          StockValuationItem(
            productId: product.id,
            name: product.name,
            category: product.category ?? 'Uncategorized',
            sku: product.sku,
            barcode: product.barcode,
            stockQuantity: product.stockQuantity,
            unit: product.unit ?? 'pcs',
            purchasePrice: product.costPrice,
            sellingPrice: product.sellingPrice,
            stockValue: stockValue,
            costValue: costValue,
            profitPotential: stockValue - costValue,
            lowStockThreshold: product.lowStockThreshold,
            isLowStock: isLowStock,
          ),
        );

        totalValue += stockValue;
        totalCost += costValue;
        totalItems += product.stockQuantity.toInt();
      }

      // Get category-wise summary
      final Map<String, double> categoryValues = {};
      for (final item in items) {
        categoryValues[item.category] =
            (categoryValues[item.category] ?? 0) + item.stockValue;
      }

      return StockValuationStatement(
        generatedAt: DateTime.now(),
        totalItems: items.length,
        totalStockQuantity: totalItems,
        totalStockValue: totalValue,
        totalCostValue: totalCost,
        potentialProfit: totalValue - totalCost,
        lowStockCount: lowStockCount,
        items: items,
        categorySummary: categoryValues,
      );
    }, 'getStockValuationStatement');
  }

  // ============================================================================
  // PHASE 1.3: SERVICE/REPAIR JOB STATEMENT
  // ============================================================================

  /// Get service job statement for service-oriented businesses
  Future<RepositoryResult<ServiceJobStatement>> getServiceJobStatement({
    required String userId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) {
    return errorHandler.runSafe<ServiceJobStatement>(() async {
      var query = database.select(database.serviceJobs)
        ..where((j) => j.userId.equals(userId) & j.deletedAt.isNull());

      if (customerId != null) {
        query = query..where((j) => j.customerId.equals(customerId));
      }
      if (startDate != null) {
        query = query
          ..where((j) => j.createdAt.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (j) => j.createdAt.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }
      if (status != null) {
        query = query..where((j) => j.status.equals(status));
      }

      query = query..orderBy([(j) => OrderingTerm.desc(j.createdAt)]);

      final jobs = await query.get();

      final List<ServiceJobEntry> entries = [];
      double totalEstimated = 0;
      double totalActual = 0;
      int pendingCount = 0;
      int completedCount = 0;

      for (final job in jobs) {
        // Get job parts/labor costs
        final partsQuery = database.select(database.serviceJobParts)
          ..where((p) => p.serviceJobId.equals(job.id));
        final parts = await partsQuery.get();
        final partsTotal = parts.fold(0.0, (sum, p) => sum + p.totalCost);

        entries.add(
          ServiceJobEntry(
            jobId: job.id,
            jobNumber: job.jobNumber,
            customerName: job.customerName,
            deviceInfo: '${job.brand} ${job.model}',
            serialNumber: job.imeiOrSerial,
            problemDescription: job.problemDescription,
            status: job.status,
            createdAt: job.createdAt,
            completedAt: job.completedAt,
            estimatedCost: job.estimatedTotal,
            actualCost: job.grandTotal > 0 ? job.grandTotal : partsTotal,
            partsUsed: parts
                .map((p) => '${p.partName} (${p.quantity.toInt()})')
                .toList(),
          ),
        );

        totalEstimated += job.estimatedTotal;
        totalActual += job.grandTotal > 0 ? job.grandTotal : partsTotal;

        if (job.status == 'PENDING' || job.status == 'IN_PROGRESS') {
          pendingCount++;
        } else if (job.status == 'COMPLETED') {
          completedCount++;
        }
      }

      return ServiceJobStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalJobs: jobs.length,
        pendingJobs: pendingCount,
        completedJobs: completedCount,
        totalEstimatedValue: totalEstimated,
        totalActualValue: totalActual,
        entries: entries,
      );
    }, 'getServiceJobStatement');
  }

  // ============================================================================
  // PHASE 1.4: FEE STATEMENT (School ERP / Clinic)
  // ============================================================================

  /// Get comprehensive fee statement for educational/medical institutions
  Future<RepositoryResult<FeeStatement>> getFeeStatement({
    required String userId,
    String? studentId,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
    String? feeType,
  }) {
    return errorHandler.runSafe<FeeStatement>(() async {
      // Query receipts as they contain fee collection data
      var query = database.select(database.receipts)
        ..where((r) => r.userId.equals(userId));

      if (startDate != null) {
        query = query..where((r) => r.date.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (r) =>
                r.date.isSmallerThanValue(endDate.add(const Duration(days: 1))),
          );
      }

      query = query..orderBy([(r) => OrderingTerm.desc(r.date)]);

      final receipts = await query.get();

      final List<FeeEntry> entries = [];
      double totalCollected = 0;
      double totalPending = 0;

      for (final receipt in receipts) {
        entries.add(
          FeeEntry(
            receiptId: receipt.id,
            receiptNumber: receipt.id
                .substring(0, 8)
                .toUpperCase(), // Generate from ID
            payerName: receipt.customerName ?? 'Unknown',
            amount: receipt.amount,
            description: receipt.notes ?? 'Fee Payment',
            paymentMode: receipt.paymentMode ?? 'CASH',
            date: receipt.date,
            reference: receipt.billId,
          ),
        );

        totalCollected += receipt.amount;
      }

      // Get pending fees from customer/student balances
      final pendingQuery = database.selectOnly(database.customers)
        ..addColumns([database.customers.totalDues.sum()])
        ..where(
          database.customers.userId.equals(userId) &
              database.customers.totalDues.isBiggerThanValue(0) &
              database.customers.deletedAt.isNull(),
        );

      final pendingResult = await pendingQuery.getSingleOrNull();
      totalPending =
          pendingResult?.read(database.customers.totalDues.sum()) ?? 0;

      return FeeStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalCollected: totalCollected,
        totalPending: totalPending,
        totalEntries: entries.length,
        entries: entries,
      );
    }, 'getFeeStatement');
  }

  // ============================================================================
  // PHASE 1.5: FUEL SALES STATEMENT (Petrol Pump)
  // ============================================================================

  /// Get fuel sales statement for petrol pump businesses
  Future<RepositoryResult<FuelSalesStatement>> getFuelSalesStatement({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? fuelType,
    String? nozzleId,
  }) {
    return errorHandler.runSafe<FuelSalesStatement>(() async {
      // Get fuel bills from the bills table with fuel-specific data
      var query = database.select(database.bills)
        ..where(
          (b) =>
              b.userId.equals(userId) &
              b.fuelType.isNotNull() &
              b.deletedAt.isNull(),
        );

      if (startDate != null) {
        query = query..where((b) => b.billDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (b) => b.billDate.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }
      if (fuelType != null) {
        query = query..where((b) => b.fuelType.equals(fuelType));
      }

      query = query..orderBy([(b) => OrderingTerm.asc(b.billDate)]);

      final bills = await query.get();

      final List<FuelSalesEntry> entries = [];
      final Map<String, FuelTypeSummary> fuelTypeSummary = {};
      double totalVolume = 0;
      double totalAmount = 0;
      int totalTransactions = 0;

      for (final bill in bills) {
        // Extract fuel details from bill items or fuel-specific fields
        final fuelType = bill.fuelType ?? 'Unknown';
        final volume =
            ((bill.pumpReadingEnd ?? 0) - (bill.pumpReadingStart ?? 0))
                .toDouble();
        final amount = bill.grandTotal;
        final rate = volume > 0 ? (amount / volume).toDouble() : 0.0;

        entries.add(
          FuelSalesEntry(
            billId: bill.id,
            invoiceNumber: bill.invoiceNumber,
            date: bill.billDate,
            fuelType: fuelType,
            nozzleId: bill.shiftId,
            vehicleNumber: bill.vehicleNumber,
            volume: volume,
            rate: rate,
            amount: amount,
            paymentMode: bill.paymentMode ?? 'Cash',
          ),
        );

        // Update fuel type summary
        if (!fuelTypeSummary.containsKey(fuelType)) {
          fuelTypeSummary[fuelType] = FuelTypeSummary(
            fuelType: fuelType,
            totalVolume: 0,
            totalAmount: 0,
            transactionCount: 0,
          );
        }
        final summary = fuelTypeSummary[fuelType]!;
        fuelTypeSummary[fuelType] = FuelTypeSummary(
          fuelType: fuelType,
          totalVolume: summary.totalVolume + volume,
          totalAmount: summary.totalAmount + amount,
          transactionCount: summary.transactionCount + 1,
        );

        totalVolume += volume;
        totalAmount += amount;
        totalTransactions++;
      }

      return FuelSalesStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalTransactions: totalTransactions,
        totalVolume: totalVolume,
        totalAmount: totalAmount,
        averageRate: totalVolume > 0 ? totalAmount / totalVolume : 0,
        entries: entries,
        fuelTypeSummary: fuelTypeSummary.values.toList(),
      );
    }, 'getFuelSalesStatement');
  }

  // ============================================================================
  // PHASE 2.1: BATCH/EXPIRY STATEMENT (Grocery/Pharmacy)
  // ============================================================================

  /// Get batch and expiry tracking statement for pharmacy/grocery
  Future<RepositoryResult<BatchExpiryStatement>> getBatchExpiryStatement({
    required String userId,
    String? productId,
    DateTime? expiryBefore,
    bool expiredOnly = false,
    bool expiringSoon = false,
  }) {
    return errorHandler.runSafe<BatchExpiryStatement>(() async {
      // Query product batches table
      var query = database.select(database.productBatches)
        ..where((b) => b.userId.equals(userId));

      if (productId != null) {
        query = query..where((b) => b.productId.equals(productId));
      }
      if (expiryBefore != null) {
        query = query
          ..where((b) => b.expiryDate.isSmallerThanValue(expiryBefore));
      }
      if (expiredOnly) {
        query = query
          ..where((b) => b.expiryDate.isSmallerThanValue(DateTime.now()));
      }

      query = query..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]);

      final batches = await query.get();

      final List<BatchExpiryEntry> entries = [];
      int expiredCount = 0;
      int expiring7DaysCount = 0;
      int expiring30DaysCount = 0;
      final Map<String, List<BatchExpiryEntry>> productWiseBatches = {};

      final now = DateTime.now();

      for (final batch in batches) {
        // Get product details
        final productQuery = database.select(database.products)
          ..where((p) => p.id.equals(batch.productId));
        final product = await productQuery.getSingleOrNull();

        // Handle null expiry date
        final daysUntilExpiry = batch.expiryDate != null
            ? batch.expiryDate!.difference(now).inDays
            : 9999; // Far future if no expiry date
        String status;
        if (daysUntilExpiry < 0) {
          status = 'EXPIRED';
          expiredCount++;
        } else if (daysUntilExpiry <= 7) {
          status = 'EXPIRING_7_DAYS';
          expiring7DaysCount++;
        } else if (daysUntilExpiry <= 30) {
          status = 'EXPIRING_30_DAYS';
          expiring30DaysCount++;
        } else {
          status = 'VALID';
        }

        final entry = BatchExpiryEntry(
          batchId: batch.id,
          productId: batch.productId,
          productName: product?.name ?? 'Unknown',
          batchNumber: batch.batchNumber,
          manufacturingDate: batch.manufacturingDate,
          expiryDate: batch.expiryDate ?? now.add(const Duration(days: 365)),
          quantity: batch.stockQuantity,
          purchasePrice: batch.purchaseRate,
          sellingPrice: product?.sellingPrice ?? batch.sellingRate,
          stockValue:
              batch.stockQuantity *
              (product?.sellingPrice ?? batch.sellingRate),
          daysUntilExpiry: daysUntilExpiry,
          status: status,
        );

        entries.add(entry);

        // Group by product
        final productName = product?.name ?? 'Unknown';
        productWiseBatches[productName] = [
          ...(productWiseBatches[productName] ?? []),
          entry,
        ];
      }

      return BatchExpiryStatement(
        generatedAt: DateTime.now(),
        totalBatches: batches.length,
        expiredCount: expiredCount,
        expiring7DaysCount: expiring7DaysCount,
        expiring30DaysCount: expiring30DaysCount,
        validCount:
            batches.length -
            expiredCount -
            expiring7DaysCount -
            expiring30DaysCount,
        entries: entries,
        productWiseBatches: productWiseBatches,
      );
    }, 'getBatchExpiryStatement');
  }

  // ============================================================================
  // PHASE 2.2: IMEI-WISE STATEMENT (Electronics/Mobile/Computer Shop)
  // ============================================================================

  /// Get IMEI/Serial number tracking statement
  Future<RepositoryResult<ImeiTrackingStatement>> getImeiTrackingStatement({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? productId,
  }) {
    return errorHandler.runSafe<ImeiTrackingStatement>(() async {
      // Query IMEI serials table
      var query = database.select(database.iMEISerials)
        ..where((i) => i.userId.equals(userId));

      if (productId != null) {
        query = query..where((i) => i.productId.equals(productId));
      }
      if (status != null) {
        query = query..where((i) => i.status.equals(status));
      }

      query = query..orderBy([(i) => OrderingTerm.desc(i.createdAt)]);

      final imeiRecords = await query.get();

      final List<ImeiTrackingEntry> entries = [];
      final Map<String, int> statusCounts = {
        'IN_STOCK': 0,
        'SOLD': 0,
        'RETURNED': 0,
        'DAMAGED': 0,
      };

      for (final record in imeiRecords) {
        // Get product details
        final productQuery = database.select(database.products)
          ..where((p) => p.id.equals(record.productId));
        final product = await productQuery.getSingleOrNull();

        // Get bill details if sold
        String? billNumber;
        DateTime? soldDate;
        String? customerName;
        double? soldPrice;

        if (record.billId != null) {
          final billQuery = database.select(database.bills)
            ..where((b) => b.id.equals(record.billId!));
          final bill = await billQuery.getSingleOrNull();
          if (bill != null) {
            billNumber = bill.invoiceNumber;
            soldDate = bill.billDate;
            customerName = bill.customerName;
            // Find the item price
            final itemQuery = database.select(database.billItems)
              ..where(
                (i) =>
                    i.billId.equals(bill.id) &
                    i.productId.equals(record.productId),
              );
            final item = await itemQuery.getSingleOrNull();
            soldPrice = item?.unitPrice;
          }
        }

        // Filter by date range
        if (startDate != null &&
            soldDate != null &&
            soldDate.isBefore(startDate))
          continue;
        if (endDate != null && soldDate != null && soldDate.isAfter(endDate))
          continue;

        statusCounts[record.status] = (statusCounts[record.status] ?? 0) + 1;

        entries.add(
          ImeiTrackingEntry(
            imeiSerialId: record.id,
            productId: record.productId,
            productName: product?.name ?? 'Unknown',
            imeiNumber: record.type == 'IMEI' ? record.imeiOrSerial : null,
            serialNumber: record.type == 'SERIAL' ? record.imeiOrSerial : null,
            status: record.status,
            purchaseDate: record.purchaseDate,
            soldDate: soldDate,
            warrantyMonths: record.warrantyMonths,
            warrantyExpiry: record.warrantyEndDate,
            billId: record.billId,
            billNumber: billNumber,
            customerName: customerName,
            purchasePrice: record.purchasePrice,
            soldPrice: soldPrice,
          ),
        );
      }

      return ImeiTrackingStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalRecords: entries.length,
        inStockCount: statusCounts['IN_STOCK'] ?? 0,
        soldCount: statusCounts['SOLD'] ?? 0,
        returnedCount: statusCounts['RETURNED'] ?? 0,
        damagedCount: statusCounts['DAMAGED'] ?? 0,
        entries: entries,
      );
    }, 'getImeiTrackingStatement');
  }

  // ============================================================================
  // PHASE 2.3: COMMISSION STATEMENT (Vegetable Broker / Mandi)
  // ============================================================================

  /// Get commission statement for vegetable brokers
  Future<RepositoryResult<CommissionStatement>> getCommissionStatement({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? brokerId,
    String? farmerId,
  }) {
    return errorHandler.runSafe<CommissionStatement>(() async {
      // Query bills with broker information
      var query = database.select(database.bills)
        ..where(
          (b) =>
              b.userId.equals(userId) &
              b.brokerId.isNotNull() &
              b.commissionAmount.isBiggerThanValue(0) &
              b.deletedAt.isNull(),
        );

      if (startDate != null) {
        query = query..where((b) => b.billDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (b) => b.billDate.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }
      if (brokerId != null) {
        query = query..where((b) => b.brokerId.equals(brokerId));
      }

      query = query..orderBy([(b) => OrderingTerm.desc(b.billDate)]);

      final bills = await query.get();

      final List<CommissionEntry> entries = [];
      double totalCommission = 0;
      double totalTransactionValue = 0;
      final Map<String, double> brokerCommissions = {};
      final Map<String, double> farmerCommissions = {};

      for (final bill in bills) {
        // Get broker details
        String brokerName = 'Unknown Broker';
        if (bill.brokerId != null) {
          final brokerQuery = database.select(database.customers)
            ..where((c) => c.id.equals(bill.brokerId!));
          final broker = await brokerQuery.getSingleOrNull();
          if (broker != null) {
            brokerName = broker.name;
          }
        }

        // Get farmer details from customer (farmer) if available
        final customerQuery = database.select(database.customers)
          ..where((c) => c.id.equals(bill.customerId ?? ''));
        final customer = await customerQuery.getSingleOrNull();

        final commission = (bill.commissionAmount ?? 0.0).toDouble();
        final transactionValue = bill.grandTotal.toDouble();
        final commissionRate = transactionValue > 0
            ? (commission / transactionValue) * 100
            : 0.0;

        totalCommission += commission;
        totalTransactionValue += transactionValue;

        // Track by broker
        brokerCommissions[brokerName] =
            (brokerCommissions[brokerName] ?? 0) + commission;

        // Track by farmer
        final farmerName = customer?.name ?? bill.customerName ?? 'Unknown';
        farmerCommissions[farmerName] =
            (farmerCommissions[farmerName] ?? 0) + commission;

        entries.add(
          CommissionEntry(
            billId: bill.id,
            invoiceNumber: bill.invoiceNumber,
            date: bill.billDate,
            brokerId: bill.brokerId ?? '',
            brokerName: brokerName,
            farmerId: bill.customerId ?? '',
            farmerName: farmerName,
            transactionValue: transactionValue,
            commissionRate: commissionRate,
            commissionAmount: commission,
            paymentMode: bill.paymentMode ?? 'Cash',
          ),
        );
      }

      return CommissionStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalTransactions: entries.length,
        totalCommission: totalCommission,
        totalTransactionValue: totalTransactionValue,
        averageCommissionRate: totalTransactionValue > 0
            ? (totalCommission / totalTransactionValue) * 100
            : 0,
        entries: entries,
        brokerSummary: brokerCommissions,
        farmerSummary: farmerCommissions,
      );
    }, 'getCommissionStatement');
  }

  // ============================================================================
  // PHASE 2.4: EVENT BOOKING STATEMENT (Decoration & Catering)
  // ============================================================================

  /// Get event booking statement for decoration/catering businesses
  Future<RepositoryResult<EventBookingStatement>> getEventBookingStatement({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? venueId,
  }) {
    return errorHandler.runSafe<EventBookingStatement>(() async {
      // Query bookings table
      var query = database.select(database.bookings)
        ..where((b) => b.userId.equals(userId));

      if (startDate != null) {
        query = query
          ..where((b) => b.deliveryDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (b) => b.deliveryDate.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }
      if (status != null) {
        query = query..where((b) => b.status.equals(status));
      }

      query = query..orderBy([(b) => OrderingTerm.asc(b.deliveryDate)]);

      final bookings = await query.get();

      final List<EventBookingEntry> entries = [];
      double totalBookingValue = 0;
      double totalAdvanceReceived = 0;
      double totalPending = 0;
      final Map<String, int> statusCounts = {};
      final Map<String, double> monthWiseRevenue = {};

      for (final booking in bookings) {
        // Get customer details
        CustomerEntity? customer;
        if (booking.customerId != null) {
          final customerQuery = database.select(database.customers)
            ..where((c) => c.id.equals(booking.customerId!));
          customer = await customerQuery.getSingleOrNull();
        }

        final bookingValue = booking.totalAmount;
        final advance = booking.advanceAmount;
        final pending = bookingValue - advance;

        totalBookingValue += bookingValue;
        totalAdvanceReceived += advance;
        totalPending += pending;

        statusCounts[booking.status] = (statusCounts[booking.status] ?? 0) + 1;

        // Month-wise aggregation
        final eventDate = booking.deliveryDate ?? booking.date;
        final monthKey = DateFormat('MMM yyyy').format(eventDate);
        monthWiseRevenue[monthKey] =
            (monthWiseRevenue[monthKey] ?? 0) + bookingValue;

        entries.add(
          EventBookingEntry(
            bookingId: booking.id,
            bookingNumber: booking.bookingNumber ?? '',
            eventDate: eventDate,
            eventType: 'General Event',
            customerName: customer?.name ?? booking.customerName ?? 'Unknown',
            customerPhone: customer?.phone,
            venueName: booking.deliveryAddress ?? 'N/A',
            guestCount: 0,
            totalAmount: bookingValue,
            advanceAmount: advance,
            pendingAmount: pending,
            status: booking.status,
            decorationTheme: null,
            cateringPackage: null,
            notes: booking.notes,
          ),
        );
      }

      return EventBookingStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalBookings: entries.length,
        confirmedCount: statusCounts['CONFIRMED'] ?? 0,
        pendingCount: statusCounts['PENDING'] ?? 0,
        completedCount: statusCounts['COMPLETED'] ?? 0,
        cancelledCount: statusCounts['CANCELLED'] ?? 0,
        totalBookingValue: totalBookingValue,
        totalAdvanceReceived: totalAdvanceReceived,
        totalPending: totalPending,
        entries: entries,
        statusSummary: statusCounts,
        monthWiseRevenue: monthWiseRevenue,
      );
    }, 'getEventBookingStatement');
  }

  // ============================================================================
  // PHASE 2.5: PATIENT VISIT STATEMENT (Clinic/Pharmacy)
  // ============================================================================

  /// Get patient visit statement for clinics
  Future<RepositoryResult<PatientVisitStatement>> getPatientVisitStatement({
    required String userId,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
    String? doctorId,
  }) {
    return errorHandler.runSafe<PatientVisitStatement>(() async {
      // Query visits/appointments table
      var query = database.select(database.visits)
        ..where((v) => v.userId.equals(userId) & v.deletedAt.isNull());

      if (patientId != null) {
        query = query..where((v) => v.patientId.equals(patientId));
      }
      if (startDate != null) {
        query = query
          ..where((v) => v.visitDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (v) => v.visitDate.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }

      query = query..orderBy([(v) => OrderingTerm.desc(v.visitDate)]);

      final visits = await query.get();

      final List<PatientVisitEntry> entries = [];
      double totalConsultationFees = 0;
      double totalMedicineAmount = 0;
      int totalVisits = visits.length;
      final Map<String, int> doctorVisitCounts = {};
      final Map<String, List<PatientVisitEntry>> patientWiseVisits = {};

      for (final visit in visits) {
        // Get patient details
        final patientQuery = database.select(database.patients)
          ..where((p) => p.id.equals(visit.patientId));
        final patient = await patientQuery.getSingleOrNull();

        // Get doctor details
        final doctorQuery = database.select(database.doctorProfiles)
          ..where((d) => d.id.equals(visit.doctorId ?? ''));
        final doctor = await doctorQuery.getSingleOrNull();

        // Get prescription/bill for this visit
        final prescriptionQuery = database.select(database.prescriptions)
          ..where((p) => p.visitId.equals(visit.id));
        final prescription = await prescriptionQuery.getSingleOrNull();

        // Get bill details
        double consultationFee = 0;
        double medicineAmount = 0;
        if (prescription != null) {
          final billQuery = database.select(database.bills)
            ..where((b) => b.prescriptionId.equals(prescription.id));
          final bill = await billQuery.getSingleOrNull();
          if (bill != null) {
            try {
              final List<dynamic> items =
                  jsonDecode(bill.itemsJson) as List<dynamic>;
              for (final item in items) {
                if (item is Map<String, dynamic>) {
                  final name = item['productName'] as String?;
                  final type = item['type'] as String?;
                  final amount =
                      (item['totalAmount'] as num?)?.toDouble() ?? 0.0;
                  if (name == 'Consultation Fee' || type == 'SERVICE') {
                    consultationFee += amount;
                  } else {
                    medicineAmount += amount;
                  }
                }
              }
            } catch (_) {
              consultationFee = doctor?.consultationFee ?? 0.0;
              medicineAmount = (bill.grandTotal - consultationFee).clamp(
                0.0,
                double.infinity,
              );
            }
          }
        }

        totalConsultationFees += consultationFee;
        totalMedicineAmount += medicineAmount;

        final doctorName = doctor?.clinicName ?? 'Unknown Doctor';
        doctorVisitCounts[doctorName] =
            (doctorVisitCounts[doctorName] ?? 0) + 1;

        final patientName = patient?.name ?? 'Unknown Patient';

        final entry = PatientVisitEntry(
          visitId: visit.id,
          patientId: visit.patientId,
          patientName: patientName,
          patientAge: patient?.age,
          patientGender: patient?.gender,
          patientPhone: patient?.phone,
          doctorId: visit.doctorId ?? '',
          doctorName: doctorName,
          visitDate: visit.visitDate,
          visitType: 'General',
          chiefComplaint: visit.chiefComplaint,
          diagnosis: visit.diagnosis,
          consultationFee: consultationFee,
          medicineAmount: medicineAmount,
          totalAmount: consultationFee + medicineAmount,
          followUpDate: null,
          notes: visit.notes,
        );

        entries.add(entry);

        // Group by patient
        patientWiseVisits[patientName] = [
          ...(patientWiseVisits[patientName] ?? []),
          entry,
        ];
      }

      return PatientVisitStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalVisits: totalVisits,
        totalConsultationFees: totalConsultationFees,
        totalMedicineAmount: totalMedicineAmount,
        totalRevenue: totalConsultationFees + totalMedicineAmount,
        entries: entries,
        doctorVisitCounts: doctorVisitCounts,
        patientWiseVisits: patientWiseVisits,
      );
    }, 'getPatientVisitStatement');
  }

  // ============================================================================
  // PHASE 3.1: LOYALTY POINTS STATEMENT (Book Store)
  // ============================================================================

  /// Get loyalty points statement for book stores and loyalty programs
  Future<RepositoryResult<LoyaltyPointsStatement>> getLoyaltyPointsStatement({
    required String userId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return errorHandler.runSafe<LoyaltyPointsStatement>(() async {
      // Query bills since loyaltyTransactions table does not exist
      var billQuery = database.select(database.bills)
        ..where((b) => b.userId.equals(userId));

      if (customerId != null) {
        billQuery = billQuery..where((b) => b.customerId.equals(customerId));
      }
      if (startDate != null) {
        billQuery = billQuery
          ..where((b) => b.billDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        billQuery = billQuery
          ..where(
            (b) => b.billDate.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }

      billQuery = billQuery..orderBy([(b) => OrderingTerm.desc(b.billDate)]);

      final bills = await billQuery.get();

      final List<LoyaltyTransactionEntry> entries = [];
      int totalPointsEarned = 0;
      int totalPointsRedeemed = 0;
      final Map<String, int> customerPoints = {};

      for (final bill in bills) {
        if (bill.customerId == null) continue;

        final pointsEarned = (bill.grandTotal / 100).floor();
        if (pointsEarned == 0) continue;

        // Get customer details
        final customerQuery = database.select(database.customers)
          ..where((c) => c.id.equals(bill.customerId!));
        final customer = await customerQuery.getSingleOrNull();
        final cName = customer?.name ?? bill.customerName ?? 'Unknown';

        totalPointsEarned += pointsEarned;
        customerPoints[cName] = (customerPoints[cName] ?? 0) + pointsEarned;

        entries.add(
          LoyaltyTransactionEntry(
            transactionId: 'loyalty_${bill.id}',
            customerId: bill.customerId!,
            customerName: cName,
            customerPhone: customer?.phone,
            billId: bill.id,
            points: pointsEarned,
            balanceAfter: customer?.loyaltyPoints ?? pointsEarned,
            transactionType: 'EARN',
            description: 'Points earned for bill ${bill.invoiceNumber}',
            transactionDate: bill.billDate,
          ),
        );
      }

      // Get current balances for all customers
      final customerQuery = database.select(database.customers)
        ..where(
          (c) => c.userId.equals(userId) & c.loyaltyPoints.isBiggerThanValue(0),
        );
      final customers = await customerQuery.get();

      int totalActivePoints = 0;
      int activeMembers = 0;
      for (final c in customers) {
        totalActivePoints += c.loyaltyPoints;
        if (c.loyaltyPoints > 0) activeMembers++;
      }

      return LoyaltyPointsStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalTransactions: entries.length,
        totalPointsEarned: totalPointsEarned,
        totalPointsRedeemed: totalPointsRedeemed,
        totalActivePoints: totalActivePoints,
        activeMembers: activeMembers,
        entries: entries,
        customerPointsSummary: customerPoints,
      );
    }, 'getLoyaltyPointsStatement');
  }

  // ============================================================================
  // PHASE 3.2: TRANSPORT DETAILS STATEMENT (Hardware)
  // ============================================================================

  /// Get transport/delivery details statement for hardware businesses
  Future<RepositoryResult<TransportDetailsStatement>>
  getTransportDetailsStatement({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? vehicleNumber,
    String? driverName,
  }) {
    return errorHandler.runSafe<TransportDetailsStatement>(() async {
      // Query dispatch records with transport details
      var query = database.select(database.dispatches)
        ..where((d) => d.userId.equals(userId));

      if (startDate != null) {
        query = query..where((d) => d.date.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (d) =>
                d.date.isSmallerThanValue(endDate.add(const Duration(days: 1))),
          );
      }
      if (vehicleNumber != null) {
        query = query..where((d) => d.vehicleNumber.equals(vehicleNumber));
      }

      query = query..orderBy([(d) => OrderingTerm.desc(d.date)]);

      final dispatches = await query.get();

      final List<TransportEntry> entries = [];
      int totalDeliveries = 0;
      int completedDeliveries = 0;
      int pendingDeliveries = 0;
      double totalDistance = 0;
      double totalFreight = 0;
      final Map<String, List<TransportEntry>> vehicleWiseDeliveries = {};

      for (final dispatch in dispatches) {
        // Get bill details
        final billQuery = database.select(database.bills)
          ..where((b) => b.id.equals(dispatch.billId ?? ''));
        final bill = await billQuery.getSingleOrNull();

        // Get customer details
        final customerQuery = database.select(database.customers)
          ..where((c) => c.id.equals(dispatch.customerId ?? ''));
        final customer = await customerQuery.getSingleOrNull();

        totalDeliveries++;
        if (dispatch.status == 'DELIVERED') {
          completedDeliveries++;
        } else if (dispatch.status == 'PENDING' ||
            dispatch.status == 'IN_TRANSIT') {
          pendingDeliveries++;
        }

        totalDistance += 0.0;
        totalFreight += 0.0;

        final entry = TransportEntry(
          deliveryId: dispatch.id,
          billId: dispatch.billId ?? '',
          invoiceNumber: bill?.invoiceNumber,
          customerId: dispatch.customerId ?? '',
          customerName: customer?.name ?? bill?.customerName ?? 'Unknown',
          customerAddress: dispatch.deliveryAddress ?? customer?.address,
          vehicleNumber: dispatch.vehicleNumber ?? 'N/A',
          driverName: dispatch.driverName ?? 'N/A',
          driverPhone: dispatch.driverPhone,
          deliveryDate: dispatch.date,
          status: dispatch.status,
          distanceKm: 0.0,
          freightAmount: 0.0,
          notes: dispatch.notes,
        );

        entries.add(entry);

        // Group by vehicle
        final vehicle = dispatch.vehicleNumber ?? 'N/A';
        vehicleWiseDeliveries[vehicle] = [
          ...(vehicleWiseDeliveries[vehicle] ?? []),
          entry,
        ];
      }

      return TransportDetailsStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalDeliveries: totalDeliveries,
        completedDeliveries: completedDeliveries,
        pendingDeliveries: pendingDeliveries,
        totalDistance: totalDistance,
        totalFreight: totalFreight,
        entries: entries,
        vehicleWiseDeliveries: vehicleWiseDeliveries,
      );
    }, 'getTransportDetailsStatement');
  }

  // ============================================================================
  // PHASE 3.3: SALT-WISE SALES STATEMENT (Pharmacy)
  // ============================================================================

  /// Get salt composition sales statement for pharmacies
  Future<RepositoryResult<SaltWiseSalesStatement>> getSaltWiseSalesStatement({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? saltName,
  }) {
    return errorHandler.runSafe<SaltWiseSalesStatement>(() async {
      // Get bills with pharmacy items
      var billQuery = database.select(database.bills)
        ..where((b) => b.userId.equals(userId) & b.deletedAt.isNull());

      if (startDate != null) {
        billQuery = billQuery
          ..where((b) => b.billDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        billQuery = billQuery
          ..where(
            (b) => b.billDate.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }

      billQuery = billQuery..orderBy([(b) => OrderingTerm.desc(b.billDate)]);
      final bills = await billQuery.get();

      final Map<String, SaltSalesSummary> saltSummary = {};
      final List<SaltWiseSaleEntry> entries = [];
      double totalSales = 0;
      int totalUnits = 0;

      for (final bill in bills) {
        // Get bill items with product details
        final itemsQuery = database.select(database.billItems)
          ..where((i) => i.billId.equals(bill.id));
        final items = await itemsQuery.get();

        for (final item in items) {
          // Get product details
          final productQuery = database.select(database.products)
            ..where((p) => p.id.equals(item.productId ?? ''));
          final product = await productQuery.getSingleOrNull();

          final salt = product?.drugSchedule ?? 'General';

          // Filter by salt name if specified
          if (saltName != null &&
              !salt.toLowerCase().contains(saltName.toLowerCase())) {
            continue;
          }

          totalSales += item.totalAmount;
          totalUnits += item.quantity.toInt();

          // Update salt summary
          if (!saltSummary.containsKey(salt)) {
            saltSummary[salt] = SaltSalesSummary(
              saltName: salt,
              totalQuantity: 0,
              totalAmount: 0,
              productCount: 0,
            );
          }
          final summary = saltSummary[salt]!;
          saltSummary[salt] = SaltSalesSummary(
            saltName: salt,
            totalQuantity: summary.totalQuantity + item.quantity,
            totalAmount: summary.totalAmount + item.totalAmount,
            productCount: summary.productCount + 1,
          );

          entries.add(
            SaltWiseSaleEntry(
              billId: bill.id,
              invoiceNumber: bill.invoiceNumber,
              date: bill.billDate,
              productId: item.productId ?? '',
              productName: item.productName,
              saltComposition: salt,
              quantity: item.quantity,
              unit: item.unit,
              price: item.unitPrice,
              totalAmount: item.totalAmount,
              customerName: bill.customerName ?? 'Unknown',
            ),
          );
        }
      }

      return SaltWiseSalesStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalSales: totalSales,
        totalUnits: totalUnits,
        uniqueSaltCount: saltSummary.length,
        entries: entries,
        saltSummary: saltSummary.values.toList(),
      );
    }, 'getSaltWiseSalesStatement');
  }

  // ============================================================================
  // PHASE 3.4: KITCHEN EFFICIENCY STATEMENT (Restaurant)
  // ============================================================================

  /// Get kitchen efficiency statement for restaurants
  Future<RepositoryResult<KitchenEfficiencyStatement>>
  getKitchenEfficiencyStatement({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return errorHandler.runSafe<KitchenEfficiencyStatement>(() async {
      // Get food orders for kitchen efficiency analysis
      var query = database.select(database.foodOrders)
        ..where((o) => o.vendorId.equals(userId));

      if (startDate != null) {
        query = query
          ..where((o) => o.orderTime.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        query = query
          ..where(
            (o) => o.orderTime.isSmallerThanValue(
              endDate.add(const Duration(days: 1)),
            ),
          );
      }

      query = query..orderBy([(o) => OrderingTerm.desc(o.orderTime)]);
      final orders = await query.get();

      final List<KitchenOrderEntry> entries = [];
      int totalOrders = 0;
      int completedOnTime = 0;
      int delayedOrders = 0;
      int cancelledOrders = 0;
      int totalPrepTime = 0;
      int totalActualTime = 0;
      final Map<String, int> categoryCounts = {};

      for (final order in orders) {
        // Get food item details
        final itemsQuery = database.select(database.foodOrderItems)
          ..where((i) => i.orderId.equals(order.id));
        final items = await itemsQuery.get();

        for (final item in items) {
          // Track category from menu item
          final menuItemQuery = database.select(database.foodMenuItems)
            ..where((m) => m.id.equals(item.menuItemId));
          final menuItem = await menuItemQuery.getSingleOrNull();

          String category = 'General';
          if (menuItem?.categoryId != null) {
            final catQuery = database.select(database.foodCategories)
              ..where((c) => c.id.equals(menuItem!.categoryId!));
            final cat = await catQuery.getSingleOrNull();
            category = cat?.name ?? 'General';
          }
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

          // Calculate prep times (default 15 min if not specified)
          final int prepTime = menuItem?.preparationTimeMinutes ?? 15;
          final int actualTime =
              (order.readyAt != null && order.acceptedAt != null)
              ? order.readyAt!.difference(order.acceptedAt!).inMinutes
              : ((order.completedAt != null)
                    ? order.completedAt!.difference(order.orderTime).inMinutes
                    : 0);

          totalPrepTime += prepTime;
          totalActualTime += actualTime;

          final bool onTime = actualTime <= prepTime;
          final bool delayed = actualTime > prepTime;

          totalOrders++;
          if (order.orderStatus == 'COMPLETED' && onTime) completedOnTime++;
          if (order.orderStatus == 'COMPLETED' && delayed) delayedOrders++;
          if (order.orderStatus == 'CANCELLED') cancelledOrders++;

          entries.add(
            KitchenOrderEntry(
              kitchenOrderId: order.id,
              billId: order.tableId ?? '',
              itemName: item.itemName,
              category: category,
              quantity: item.quantity.toDouble(),
              status: order.orderStatus,
              priority: 'NORMAL',
              startedAt: order.acceptedAt ?? order.orderTime,
              completedAt: order.completedAt,
              estimatedPrepTime: Duration(minutes: prepTime),
              actualPrepTime: Duration(minutes: actualTime),
              isOnTime: onTime,
              delayMinutes: delayed ? actualTime - prepTime : 0,
              notes: order.specialInstructions,
            ),
          );
        }
      }

      // Calculate efficiency metrics
      final avgPrepTime = totalOrders > 0
          ? (totalPrepTime / totalOrders).toDouble()
          : 0.0;
      final avgActualTime = totalOrders > 0
          ? (totalActualTime / totalOrders).toDouble()
          : 0.0;
      final efficiencyRate = totalOrders > 0
          ? (completedOnTime / totalOrders) * 100
          : 0.0;

      return KitchenEfficiencyStatement(
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        totalOrders: totalOrders,
        completedOnTime: completedOnTime,
        delayedOrders: delayedOrders,
        cancelledOrders: cancelledOrders,
        averagePrepTimeMinutes: avgPrepTime,
        averageActualTimeMinutes: avgActualTime,
        efficiencyRate: efficiencyRate,
        entries: entries,
        categoryBreakdown: categoryCounts,
      );
    }, 'getKitchenEfficiencyStatement');
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Future<List<BillItemDetail>> _getBillItems(String billId) async {
    final query = database.select(database.billItems)
      ..where((i) => i.billId.equals(billId));
    final items = await query.get();

    return items
        .map(
          (i) => BillItemDetail(
            productName: i.productName,
            quantity: i.quantity,
            unit: i.unit,
            price: i.unitPrice,
            total: i.totalAmount,
          ),
        )
        .toList();
  }

  Future<InvoiceAging> _calculateInvoiceAging(
    String userId,
    String customerId,
    DateTime asOfDate,
  ) async {
    final buckets = {
      'current': 0.0,
      'days_1_30': 0.0,
      'days_31_60': 0.0,
      'days_61_90': 0.0,
      'days_90_plus': 0.0,
    };

    final query = database.select(database.bills)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.customerId.equals(customerId) &
            b.status.isNotIn(['PAID', 'CANCELLED']) &
            b.deletedAt.isNull(),
      );

    final bills = await query.get();

    for (final bill in bills) {
      final due = bill.grandTotal - bill.paidAmount;
      if (due <= 0) continue;

      final ageDays = asOfDate.difference(bill.billDate).inDays;

      if (ageDays <= 0) {
        buckets['current'] = buckets['current']! + due;
      } else if (ageDays <= 30) {
        buckets['days_1_30'] = buckets['days_1_30']! + due;
      } else if (ageDays <= 60) {
        buckets['days_31_60'] = buckets['days_31_60']! + due;
      } else if (ageDays <= 90) {
        buckets['days_61_90'] = buckets['days_61_90']! + due;
      } else {
        buckets['days_90_plus'] = buckets['days_90_plus']! + due;
      }
    }

    return InvoiceAging(
      current: buckets['current']!,
      days1To30: buckets['days_1_30']!,
      days31To60: buckets['days_31_60']!,
      days61To90: buckets['days_61_90']!,
      days90Plus: buckets['days_90_plus']!,
      totalOutstanding: buckets.values.reduce((a, b) => a + b),
    );
  }
}

// ============================================================================
// MODEL CLASSES
// ============================================================================

class CustomerInvoiceStatement {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? gstin;
  final DateTime startDate;
  final DateTime endDate;
  final double openingBalance;
  final double closingBalance;
  final double totalSales;
  final double totalPaid;
  final double totalDue;
  final List<InvoiceStatementEntry> entries;
  final InvoiceAging aging;

  CustomerInvoiceStatement({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.gstin,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.totalSales,
    required this.totalPaid,
    required this.totalDue,
    required this.entries,
    required this.aging,
  });
}

class InvoiceStatementEntry {
  final String invoiceId;
  final String invoiceNumber;
  final DateTime date;
  final double amount;
  final double paidAmount;
  final double balance;
  final double runningBalance;
  final String status;
  final List<BillItemDetail> items;

  InvoiceStatementEntry({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.amount,
    required this.paidAmount,
    required this.balance,
    required this.runningBalance,
    required this.status,
    required this.items,
  });
}

class BillItemDetail {
  final String productName;
  final double quantity;
  final String? unit;
  final double price;
  final double total;

  BillItemDetail({
    required this.productName,
    required this.quantity,
    this.unit,
    required this.price,
    required this.total,
  });
}

class InvoiceAging {
  final double current;
  final double days1To30;
  final double days31To60;
  final double days61To90;
  final double days90Plus;
  final double totalOutstanding;

  InvoiceAging({
    required this.current,
    required this.days1To30,
    required this.days31To60,
    required this.days61To90,
    required this.days90Plus,
    required this.totalOutstanding,
  });
}

class StockValuationStatement {
  final DateTime generatedAt;
  final int totalItems;
  final int totalStockQuantity;
  final double totalStockValue;
  final double totalCostValue;
  final double potentialProfit;
  final int lowStockCount;
  final List<StockValuationItem> items;
  final Map<String, double> categorySummary;

  StockValuationStatement({
    required this.generatedAt,
    required this.totalItems,
    required this.totalStockQuantity,
    required this.totalStockValue,
    required this.totalCostValue,
    required this.potentialProfit,
    required this.lowStockCount,
    required this.items,
    required this.categorySummary,
  });
}

class StockValuationItem {
  final String productId;
  final String name;
  final String category;
  final String? sku;
  final String? barcode;
  final double stockQuantity;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double stockValue;
  final double costValue;
  final double profitPotential;
  final double lowStockThreshold;
  final bool isLowStock;

  StockValuationItem({
    required this.productId,
    required this.name,
    required this.category,
    this.sku,
    this.barcode,
    required this.stockQuantity,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockValue,
    required this.costValue,
    required this.profitPotential,
    required this.lowStockThreshold,
    required this.isLowStock,
  });
}

class ServiceJobStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalJobs;
  final int pendingJobs;
  final int completedJobs;
  final double totalEstimatedValue;
  final double totalActualValue;
  final List<ServiceJobEntry> entries;

  ServiceJobStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalJobs,
    required this.pendingJobs,
    required this.completedJobs,
    required this.totalEstimatedValue,
    required this.totalActualValue,
    required this.entries,
  });
}

class ServiceJobEntry {
  final String jobId;
  final String jobNumber;
  final String customerName;
  final String deviceInfo;
  final String? serialNumber;
  final String problemDescription;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? estimatedCost;
  final double actualCost;
  final List<String> partsUsed;

  ServiceJobEntry({
    required this.jobId,
    required this.jobNumber,
    required this.customerName,
    required this.deviceInfo,
    this.serialNumber,
    required this.problemDescription,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.estimatedCost,
    required this.actualCost,
    required this.partsUsed,
  });
}

class FeeStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalCollected;
  final double totalPending;
  final int totalEntries;
  final List<FeeEntry> entries;

  FeeStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalCollected,
    required this.totalPending,
    required this.totalEntries,
    required this.entries,
  });
}

class FeeEntry {
  final String receiptId;
  final String receiptNumber;
  final String payerName;
  final double amount;
  final String description;
  final String paymentMode;
  final DateTime date;
  final String? reference;

  FeeEntry({
    required this.receiptId,
    required this.receiptNumber,
    required this.payerName,
    required this.amount,
    required this.description,
    required this.paymentMode,
    required this.date,
    this.reference,
  });
}

class FuelSalesStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalTransactions;
  final double totalVolume;
  final double totalAmount;
  final double averageRate;
  final List<FuelSalesEntry> entries;
  final List<FuelTypeSummary> fuelTypeSummary;

  FuelSalesStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalTransactions,
    required this.totalVolume,
    required this.totalAmount,
    required this.averageRate,
    required this.entries,
    required this.fuelTypeSummary,
  });
}

class FuelSalesEntry {
  final String billId;
  final String invoiceNumber;
  final DateTime date;
  final String fuelType;
  final String? nozzleId;
  final String? vehicleNumber;
  final double volume;
  final double rate;
  final double amount;
  final String paymentMode;

  FuelSalesEntry({
    required this.billId,
    required this.invoiceNumber,
    required this.date,
    required this.fuelType,
    this.nozzleId,
    this.vehicleNumber,
    required this.volume,
    required this.rate,
    required this.amount,
    required this.paymentMode,
  });
}

class FuelTypeSummary {
  final String fuelType;
  final double totalVolume;
  final double totalAmount;
  final int transactionCount;

  FuelTypeSummary({
    required this.fuelType,
    required this.totalVolume,
    required this.totalAmount,
    required this.transactionCount,
  });
}

// ============================================================================
// PHASE 2 MODEL CLASSES
// ============================================================================

class BatchExpiryStatement {
  final DateTime generatedAt;
  final int totalBatches;
  final int expiredCount;
  final int expiring7DaysCount;
  final int expiring30DaysCount;
  final int validCount;
  final List<BatchExpiryEntry> entries;
  final Map<String, List<BatchExpiryEntry>> productWiseBatches;

  BatchExpiryStatement({
    required this.generatedAt,
    required this.totalBatches,
    required this.expiredCount,
    required this.expiring7DaysCount,
    required this.expiring30DaysCount,
    required this.validCount,
    required this.entries,
    required this.productWiseBatches,
  });
}

class BatchExpiryEntry {
  final String batchId;
  final String productId;
  final String productName;
  final String batchNumber;
  final DateTime? manufacturingDate;
  final DateTime expiryDate;
  final double quantity;
  final double purchasePrice;
  final double sellingPrice;
  final double stockValue;
  final int daysUntilExpiry;
  final String status;

  BatchExpiryEntry({
    required this.batchId,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    this.manufacturingDate,
    required this.expiryDate,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockValue,
    required this.daysUntilExpiry,
    required this.status,
  });
}

class ImeiTrackingStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalRecords;
  final int inStockCount;
  final int soldCount;
  final int returnedCount;
  final int damagedCount;
  final List<ImeiTrackingEntry> entries;

  ImeiTrackingStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalRecords,
    required this.inStockCount,
    required this.soldCount,
    required this.returnedCount,
    required this.damagedCount,
    required this.entries,
  });
}

class ImeiTrackingEntry {
  final String imeiSerialId;
  final String productId;
  final String productName;
  final String? imeiNumber;
  final String? serialNumber;
  final String status;
  final DateTime? purchaseDate;
  final DateTime? soldDate;
  final int? warrantyMonths;
  final DateTime? warrantyExpiry;
  final String? billId;
  final String? billNumber;
  final String? customerName;
  final double? purchasePrice;
  final double? soldPrice;

  ImeiTrackingEntry({
    required this.imeiSerialId,
    required this.productId,
    required this.productName,
    this.imeiNumber,
    this.serialNumber,
    required this.status,
    this.purchaseDate,
    this.soldDate,
    this.warrantyMonths,
    this.warrantyExpiry,
    this.billId,
    this.billNumber,
    this.customerName,
    this.purchasePrice,
    this.soldPrice,
  });
}

class CommissionStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalTransactions;
  final double totalCommission;
  final double totalTransactionValue;
  final double averageCommissionRate;
  final List<CommissionEntry> entries;
  final Map<String, double> brokerSummary;
  final Map<String, double> farmerSummary;

  CommissionStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalTransactions,
    required this.totalCommission,
    required this.totalTransactionValue,
    required this.averageCommissionRate,
    required this.entries,
    required this.brokerSummary,
    required this.farmerSummary,
  });
}

class CommissionEntry {
  final String billId;
  final String invoiceNumber;
  final DateTime date;
  final String brokerId;
  final String brokerName;
  final String farmerId;
  final String farmerName;
  final double transactionValue;
  final double commissionRate;
  final double commissionAmount;
  final String paymentMode;

  CommissionEntry({
    required this.billId,
    required this.invoiceNumber,
    required this.date,
    required this.brokerId,
    required this.brokerName,
    required this.farmerId,
    required this.farmerName,
    required this.transactionValue,
    required this.commissionRate,
    required this.commissionAmount,
    required this.paymentMode,
  });
}

class EventBookingStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalBookings;
  final int confirmedCount;
  final int pendingCount;
  final int completedCount;
  final int cancelledCount;
  final double totalBookingValue;
  final double totalAdvanceReceived;
  final double totalPending;
  final List<EventBookingEntry> entries;
  final Map<String, int> statusSummary;
  final Map<String, double> monthWiseRevenue;

  EventBookingStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalBookings,
    required this.confirmedCount,
    required this.pendingCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.totalBookingValue,
    required this.totalAdvanceReceived,
    required this.totalPending,
    required this.entries,
    required this.statusSummary,
    required this.monthWiseRevenue,
  });
}

class EventBookingEntry {
  final String bookingId;
  final String bookingNumber;
  final DateTime eventDate;
  final String eventType;
  final String customerName;
  final String? customerPhone;
  final String? venueName;
  final int guestCount;
  final double totalAmount;
  final double advanceAmount;
  final double pendingAmount;
  final String status;
  final String? decorationTheme;
  final String? cateringPackage;
  final String? notes;

  EventBookingEntry({
    required this.bookingId,
    required this.bookingNumber,
    required this.eventDate,
    required this.eventType,
    required this.customerName,
    this.customerPhone,
    this.venueName,
    required this.guestCount,
    required this.totalAmount,
    required this.advanceAmount,
    required this.pendingAmount,
    required this.status,
    this.decorationTheme,
    this.cateringPackage,
    this.notes,
  });
}

class PatientVisitStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalVisits;
  final double totalConsultationFees;
  final double totalMedicineAmount;
  final double totalRevenue;
  final List<PatientVisitEntry> entries;
  final Map<String, int> doctorVisitCounts;
  final Map<String, List<PatientVisitEntry>> patientWiseVisits;

  PatientVisitStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalVisits,
    required this.totalConsultationFees,
    required this.totalMedicineAmount,
    required this.totalRevenue,
    required this.entries,
    required this.doctorVisitCounts,
    required this.patientWiseVisits,
  });
}

class PatientVisitEntry {
  final String visitId;
  final String patientId;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final String? patientPhone;
  final String doctorId;
  final String doctorName;
  final DateTime visitDate;
  final String visitType;
  final String? chiefComplaint;
  final String? diagnosis;
  final double consultationFee;
  final double medicineAmount;
  final double totalAmount;
  final DateTime? followUpDate;
  final String? notes;

  PatientVisitEntry({
    required this.visitId,
    required this.patientId,
    required this.patientName,
    this.patientAge,
    this.patientGender,
    this.patientPhone,
    required this.doctorId,
    required this.doctorName,
    required this.visitDate,
    required this.visitType,
    this.chiefComplaint,
    this.diagnosis,
    required this.consultationFee,
    required this.medicineAmount,
    required this.totalAmount,
    this.followUpDate,
    this.notes,
  });
}

// ============================================================================
// PHASE 3 MODEL CLASSES
// ============================================================================

class LoyaltyPointsStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalTransactions;
  final int totalPointsEarned;
  final int totalPointsRedeemed;
  final int totalActivePoints;
  final int activeMembers;
  final List<LoyaltyTransactionEntry> entries;
  final Map<String, int> customerPointsSummary;

  LoyaltyPointsStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalTransactions,
    required this.totalPointsEarned,
    required this.totalPointsRedeemed,
    required this.totalActivePoints,
    required this.activeMembers,
    required this.entries,
    required this.customerPointsSummary,
  });
}

class LoyaltyTransactionEntry {
  final String transactionId;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? billId;
  final int points;
  final int balanceAfter;
  final String transactionType;
  final String? description;
  final DateTime transactionDate;

  LoyaltyTransactionEntry({
    required this.transactionId,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.billId,
    required this.points,
    required this.balanceAfter,
    required this.transactionType,
    this.description,
    required this.transactionDate,
  });
}

class TransportDetailsStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalDeliveries;
  final int completedDeliveries;
  final int pendingDeliveries;
  final double totalDistance;
  final double totalFreight;
  final List<TransportEntry> entries;
  final Map<String, List<TransportEntry>> vehicleWiseDeliveries;

  TransportDetailsStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalDeliveries,
    required this.completedDeliveries,
    required this.pendingDeliveries,
    required this.totalDistance,
    required this.totalFreight,
    required this.entries,
    required this.vehicleWiseDeliveries,
  });
}

class TransportEntry {
  final String deliveryId;
  final String billId;
  final String? invoiceNumber;
  final String customerId;
  final String customerName;
  final String? customerAddress;
  final String vehicleNumber;
  final String driverName;
  final String? driverPhone;
  final DateTime deliveryDate;
  final String status;
  final double distanceKm;
  final double freightAmount;
  final String? notes;

  TransportEntry({
    required this.deliveryId,
    required this.billId,
    this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    this.customerAddress,
    required this.vehicleNumber,
    required this.driverName,
    this.driverPhone,
    required this.deliveryDate,
    required this.status,
    required this.distanceKm,
    required this.freightAmount,
    this.notes,
  });
}

class SaltWiseSalesStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalSales;
  final int totalUnits;
  final int uniqueSaltCount;
  final List<SaltWiseSaleEntry> entries;
  final List<SaltSalesSummary> saltSummary;

  SaltWiseSalesStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalSales,
    required this.totalUnits,
    required this.uniqueSaltCount,
    required this.entries,
    required this.saltSummary,
  });
}

class SaltWiseSaleEntry {
  final String billId;
  final String invoiceNumber;
  final DateTime date;
  final String productId;
  final String productName;
  final String saltComposition;
  final double quantity;
  final String? unit;
  final double price;
  final double totalAmount;
  final String customerName;

  SaltWiseSaleEntry({
    required this.billId,
    required this.invoiceNumber,
    required this.date,
    required this.productId,
    required this.productName,
    required this.saltComposition,
    required this.quantity,
    this.unit,
    required this.price,
    required this.totalAmount,
    required this.customerName,
  });
}

class SaltSalesSummary {
  final String saltName;
  final double totalQuantity;
  final double totalAmount;
  final int productCount;

  SaltSalesSummary({
    required this.saltName,
    required this.totalQuantity,
    required this.totalAmount,
    required this.productCount,
  });
}

class KitchenEfficiencyStatement {
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalOrders;
  final int completedOnTime;
  final int delayedOrders;
  final int cancelledOrders;
  final double averagePrepTimeMinutes;
  final double averageActualTimeMinutes;
  final double efficiencyRate;
  final List<KitchenOrderEntry> entries;
  final Map<String, int> categoryBreakdown;

  KitchenEfficiencyStatement({
    required this.generatedAt,
    this.startDate,
    this.endDate,
    required this.totalOrders,
    required this.completedOnTime,
    required this.delayedOrders,
    required this.cancelledOrders,
    required this.averagePrepTimeMinutes,
    required this.averageActualTimeMinutes,
    required this.efficiencyRate,
    required this.entries,
    required this.categoryBreakdown,
  });
}

class KitchenOrderEntry {
  final String kitchenOrderId;
  final String billId;
  final String itemName;
  final String category;
  final double quantity;
  final String status;
  final String priority;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Duration estimatedPrepTime;
  final Duration actualPrepTime;
  final bool isOnTime;
  final int delayMinutes;
  final String? notes;

  KitchenOrderEntry({
    required this.kitchenOrderId,
    required this.billId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.status,
    required this.priority,
    this.startedAt,
    this.completedAt,
    required this.estimatedPrepTime,
    required this.actualPrepTime,
    required this.isOnTime,
    required this.delayMinutes,
    this.notes,
  });
}
