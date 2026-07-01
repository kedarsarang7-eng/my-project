// ============================================================================
// STATEMENTS SERVICE - BUSINESS LOGIC LAYER
// ============================================================================
// Orchestrates statement generation with caching and business rules
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import '../repository/statements_repository.dart';
import '../di/service_locator.dart';
import '../session/session_manager.dart';

// Re-export statement models for convenience
export '../repository/statements_repository.dart'
    show
        CustomerInvoiceStatement,
        InvoiceStatementEntry,
        BillItemDetail,
        InvoiceAging,
        StockValuationStatement,
        StockValuationItem,
        ServiceJobStatement,
        ServiceJobEntry,
        FeeStatement,
        FeeEntry,
        FuelSalesStatement,
        FuelSalesEntry,
        FuelTypeSummary,
        // Phase 2 models
        BatchExpiryStatement,
        BatchExpiryEntry,
        ImeiTrackingStatement,
        ImeiTrackingEntry,
        CommissionStatement,
        CommissionEntry,
        EventBookingStatement,
        EventBookingEntry,
        PatientVisitStatement,
        PatientVisitEntry,
        // Phase 3 models
        LoyaltyPointsStatement,
        LoyaltyTransactionEntry,
        TransportDetailsStatement,
        TransportEntry,
        SaltWiseSalesStatement,
        SaltWiseSaleEntry,
        SaltSalesSummary,
        KitchenEfficiencyStatement,
        KitchenOrderEntry;

class StatementsService {
  final StatementsRepository _repository;
  final SessionManager _sessionManager;

  // Cache for recently generated statements (5 minutes TTL)
  final Map<String, _CachedStatement> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);

  StatementsService({
    required StatementsRepository repository,
    required SessionManager sessionManager,
  }) : _repository = repository,
       _sessionManager = sessionManager;

  // Factory constructor for DI
  factory StatementsService.fromLocator() {
    return StatementsService(
      repository: sl<StatementsRepository>(),
      sessionManager: sl<SessionManager>(),
    );
  }

  String _getCacheKey(String type, Map<String, dynamic> params) {
    return '$type:${params.toString()}';
  }

  void _cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere(
      (_, cached) => now.difference(cached.timestamp) > _cacheTTL,
    );
  }

  // ============================================================================
  // PHASE 1.1: INVOICE-WISE CUSTOMER STATEMENT
  // ============================================================================

  /// Generate customer invoice statement with real data
  Future<CustomerInvoiceStatement> generateCustomerInvoiceStatement({
    required String customerId,
    required DateTime startDate,
    required DateTime endDate,
    bool useCache = true,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final cacheKey = _getCacheKey('customer_invoice', {
      'userId': userId,
      'customerId': customerId,
      'start': startDate.toIso8601String(),
      'end': endDate.toIso8601String(),
    });

    // Check cache
    if (useCache && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data as CustomerInvoiceStatement;
      }
    }

    _cleanCache();

    final result = await _repository.getCustomerInvoiceStatement(
      userId: userId,
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(result.error ?? 'Failed to generate statement');
    }

    // Cache the result
    _cache[cacheKey] = _CachedStatement(result.data!, DateTime.now());

    return result.data!;
  }

  /// Stream of customer invoices for real-time updates
  Stream<List<Map<String, dynamic>>> watchCustomerBills({
    required String customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async* {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    yield* _repository.watchCustomerBillsForStatement(
      userId: userId,
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ============================================================================
  // PHASE 1.2: STOCK VALUATION STATEMENT
  // ============================================================================

  /// Generate stock valuation statement
  Future<StockValuationStatement> generateStockValuationStatement({
    String? category,
    bool includeZeroStock = false,
    bool useCache = true,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final cacheKey = _getCacheKey('stock_valuation', {
      'userId': userId,
      'category': category ?? 'all',
      'includeZero': includeZeroStock,
    });

    if (useCache && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data as StockValuationStatement;
      }
    }

    _cleanCache();

    final result = await _repository.getStockValuationStatement(
      userId: userId,
      category: category,
      includeZeroStock: includeZeroStock,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(result.error ?? 'Failed to generate stock valuation');
    }

    _cache[cacheKey] = _CachedStatement(result.data!, DateTime.now());

    return result.data!;
  }

  // ============================================================================
  // PHASE 1.3: SERVICE JOB STATEMENT
  // ============================================================================

  /// Generate service job statement for repairs/services
  Future<ServiceJobStatement> generateServiceJobStatement({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getServiceJobStatement(
      userId: userId,
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      status: status,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate service job statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 1.4: FEE STATEMENT
  // ============================================================================

  /// Generate fee statement for educational/medical institutions
  Future<FeeStatement> generateFeeStatement({
    String? studentId,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
    String? feeType,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getFeeStatement(
      userId: userId,
      studentId: studentId,
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
      feeType: feeType,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(result.error ?? 'Failed to generate fee statement');
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 1.5: FUEL SALES STATEMENT
  // ============================================================================

  /// Generate fuel sales statement for petrol pumps
  Future<FuelSalesStatement> generateFuelSalesStatement({
    DateTime? startDate,
    DateTime? endDate,
    String? fuelType,
    String? nozzleId,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getFuelSalesStatement(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      fuelType: fuelType,
      nozzleId: nozzleId,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate fuel sales statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 2.1: BATCH/EXPIRY STATEMENT (Grocery/Pharmacy)
  // ============================================================================

  /// Generate batch and expiry tracking statement
  Future<BatchExpiryStatement> generateBatchExpiryStatement({
    String? productId,
    DateTime? expiryBefore,
    bool expiredOnly = false,
    bool expiringSoon = false,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getBatchExpiryStatement(
      userId: userId,
      productId: productId,
      expiryBefore: expiryBefore,
      expiredOnly: expiredOnly,
      expiringSoon: expiringSoon,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate batch expiry statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 2.2: IMEI-WISE STATEMENT (Electronics/Mobile)
  // ============================================================================

  /// Generate IMEI/Serial number tracking statement
  Future<ImeiTrackingStatement> generateImeiTrackingStatement({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? productId,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getImeiTrackingStatement(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      status: status,
      productId: productId,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate IMEI tracking statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 2.3: COMMISSION STATEMENT (Vegetable Broker / Mandi)
  // ============================================================================

  /// Generate commission statement for vegetable brokers
  Future<CommissionStatement> generateCommissionStatement({
    DateTime? startDate,
    DateTime? endDate,
    String? brokerId,
    String? farmerId,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getCommissionStatement(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      brokerId: brokerId,
      farmerId: farmerId,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate commission statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 2.4: EVENT BOOKING STATEMENT (Decoration & Catering)
  // ============================================================================

  /// Generate event booking statement
  Future<EventBookingStatement> generateEventBookingStatement({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? venueId,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getEventBookingStatement(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      status: status,
      venueId: venueId,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate event booking statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 2.5: PATIENT VISIT STATEMENT (Clinic/Pharmacy)
  // ============================================================================

  /// Generate patient visit statement for clinics
  Future<PatientVisitStatement> generatePatientVisitStatement({
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
    String? doctorId,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getPatientVisitStatement(
      userId: userId,
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
      doctorId: doctorId,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate patient visit statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 3.1: LOYALTY POINTS STATEMENT (Book Store)
  // ============================================================================

  /// Generate loyalty points statement for book stores
  Future<LoyaltyPointsStatement> generateLoyaltyPointsStatement({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getLoyaltyPointsStatement(
      userId: userId,
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate loyalty points statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 3.2: TRANSPORT DETAILS STATEMENT (Hardware)
  // ============================================================================

  /// Generate transport/delivery details statement
  Future<TransportDetailsStatement> generateTransportDetailsStatement({
    DateTime? startDate,
    DateTime? endDate,
    String? vehicleNumber,
    String? driverName,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getTransportDetailsStatement(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      vehicleNumber: vehicleNumber,
      driverName: driverName,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate transport details statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 3.3: SALT-WISE SALES STATEMENT (Pharmacy)
  // ============================================================================

  /// Generate salt-wise sales statement for pharmacies
  Future<SaltWiseSalesStatement> generateSaltWiseSalesStatement({
    DateTime? startDate,
    DateTime? endDate,
    String? saltName,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getSaltWiseSalesStatement(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      saltName: saltName,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate salt-wise sales statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PHASE 3.4: KITCHEN EFFICIENCY STATEMENT (Restaurant)
  // ============================================================================

  /// Generate kitchen efficiency statement for restaurants
  Future<KitchenEfficiencyStatement> generateKitchenEfficiencyStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _sessionManager.ownerId;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _repository.getKitchenEfficiencyStatement(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!result.isSuccess || result.data == null) {
      throw Exception(
        result.error ?? 'Failed to generate kitchen efficiency statement',
      );
    }

    return result.data!;
  }

  // ============================================================================
  // PDF GENERATION HELPERS
  // ============================================================================

  /// Get statement data formatted for PDF export
  Map<String, dynamic> getCustomerStatementPdfData(
    CustomerInvoiceStatement statement,
  ) {
    return {
      'title': 'Customer Invoice Statement',
      'generatedAt': DateTime.now().toIso8601String(),
      'customer': {
        'name': statement.customerName,
        'phone': statement.customerPhone,
        'address': statement.customerAddress,
        'gstin': statement.gstin,
      },
      'period': {
        'start': statement.startDate.toIso8601String(),
        'end': statement.endDate.toIso8601String(),
      },
      'summary': {
        'openingBalance': statement.openingBalance,
        'closingBalance': statement.closingBalance,
        'totalSales': statement.totalSales,
        'totalPaid': statement.totalPaid,
        'totalDue': statement.totalDue,
      },
      'aging': {
        'current': statement.aging.current,
        'days_1_30': statement.aging.days1To30,
        'days_31_60': statement.aging.days31To60,
        'days_61_90': statement.aging.days61To90,
        'days_90_plus': statement.aging.days90Plus,
        'totalOutstanding': statement.aging.totalOutstanding,
      },
      'entries': statement.entries
          .map(
            (e) => {
              'invoiceNumber': e.invoiceNumber,
              'date': e.date.toIso8601String(),
              'amount': e.amount,
              'paid': e.paidAmount,
              'balance': e.balance,
              'runningBalance': e.runningBalance,
              'status': e.status,
              'items': e.items
                  .map(
                    (i) => {
                      'productName': i.productName,
                      'quantity': i.quantity,
                      'price': i.price,
                      'total': i.total,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> getStockValuationPdfData(
    StockValuationStatement statement,
  ) {
    return {
      'title': 'Stock Valuation Statement',
      'generatedAt': statement.generatedAt.toIso8601String(),
      'summary': {
        'totalItems': statement.totalItems,
        'totalStockQuantity': statement.totalStockQuantity,
        'totalStockValue': statement.totalStockValue,
        'totalCostValue': statement.totalCostValue,
        'potentialProfit': statement.potentialProfit,
        'lowStockCount': statement.lowStockCount,
      },
      'categorySummary': statement.categorySummary,
      'items': statement.items
          .map(
            (i) => {
              'name': i.name,
              'category': i.category,
              'sku': i.sku,
              'barcode': i.barcode,
              'stockQuantity': i.stockQuantity,
              'unit': i.unit,
              'purchasePrice': i.purchasePrice,
              'sellingPrice': i.sellingPrice,
              'stockValue': i.stockValue,
              'costValue': i.costValue,
              'isLowStock': i.isLowStock,
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> getServiceJobPdfData(ServiceJobStatement statement) {
    return {
      'title': 'Service Job Statement',
      'generatedAt': statement.generatedAt.toIso8601String(),
      'period': {
        'start': statement.startDate?.toIso8601String(),
        'end': statement.endDate?.toIso8601String(),
      },
      'summary': {
        'totalJobs': statement.totalJobs,
        'pendingJobs': statement.pendingJobs,
        'completedJobs': statement.completedJobs,
        'totalEstimated': statement.totalEstimatedValue,
        'totalActual': statement.totalActualValue,
      },
      'entries': statement.entries
          .map(
            (e) => {
              'jobNumber': e.jobNumber,
              'customerName': e.customerName,
              'deviceInfo': e.deviceInfo,
              'serialNumber': e.serialNumber,
              'problem': e.problemDescription,
              'status': e.status,
              'createdAt': e.createdAt.toIso8601String(),
              'completedAt': e.completedAt?.toIso8601String(),
              'estimatedCost': e.estimatedCost,
              'actualCost': e.actualCost,
              'partsUsed': e.partsUsed,
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> getFeeStatementPdfData(FeeStatement statement) {
    return {
      'title': 'Fee Statement',
      'generatedAt': statement.generatedAt.toIso8601String(),
      'period': {
        'start': statement.startDate?.toIso8601String(),
        'end': statement.endDate?.toIso8601String(),
      },
      'summary': {
        'totalCollected': statement.totalCollected,
        'totalPending': statement.totalPending,
        'totalEntries': statement.totalEntries,
      },
      'entries': statement.entries
          .map(
            (e) => {
              'receiptNumber': e.receiptNumber,
              'payerName': e.payerName,
              'amount': e.amount,
              'description': e.description,
              'paymentMode': e.paymentMode,
              'date': e.date.toIso8601String(),
              'reference': e.reference,
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> getFuelSalesPdfData(FuelSalesStatement statement) {
    return {
      'title': 'Fuel Sales Statement',
      'generatedAt': statement.generatedAt.toIso8601String(),
      'period': {
        'start': statement.startDate?.toIso8601String(),
        'end': statement.endDate?.toIso8601String(),
      },
      'summary': {
        'totalTransactions': statement.totalTransactions,
        'totalVolume': statement.totalVolume,
        'totalAmount': statement.totalAmount,
        'averageRate': statement.averageRate,
      },
      'fuelTypeSummary': statement.fuelTypeSummary
          .map(
            (f) => {
              'fuelType': f.fuelType,
              'totalVolume': f.totalVolume,
              'totalAmount': f.totalAmount,
              'transactionCount': f.transactionCount,
              'averageRate': f.totalVolume > 0
                  ? f.totalAmount / f.totalVolume
                  : 0,
            },
          )
          .toList(),
      'entries': statement.entries
          .map(
            (e) => {
              'invoiceNumber': e.invoiceNumber,
              'date': e.date.toIso8601String(),
              'fuelType': e.fuelType,
              'nozzleId': e.nozzleId,
              'vehicleNumber': e.vehicleNumber,
              'volume': e.volume,
              'rate': e.rate,
              'amount': e.amount,
              'paymentMode': e.paymentMode,
            },
          )
          .toList(),
    };
  }

  // ============================================================================
  // CLEAR CACHE
  // ============================================================================

  void clearCache() {
    _cache.clear();
  }

  void clearCacheForType(String type) {
    _cache.removeWhere((key, _) => key.startsWith('$type:'));
  }
}

// Cache entry wrapper
class _CachedStatement {
  final dynamic data;
  final DateTime timestamp;

  _CachedStatement(this.data, this.timestamp);
}
