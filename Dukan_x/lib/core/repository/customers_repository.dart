// ============================================================================
// CUSTOMERS REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages customer data with Drift as source of truth
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

// ============================================================================
// CUSTOMER ENUMS
// ============================================================================

/// Customer type for classification and pricing
enum CustomerType {
  cash,
  credit,
  regular,
  wholesale;

  String get value => name;

  static CustomerType fromString(String value) {
    return CustomerType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => CustomerType.regular,
    );
  }
}

/// GST preference for billing
enum GstPreference {
  inclusive,
  exclusive,
  exempt;

  String get value => name;

  static GstPreference fromString(String value) {
    return GstPreference.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => GstPreference.exclusive,
    );
  }
}

/// Customer entity
class Customer {
  final String id;
  final String odId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstin;
  final double totalBilled;
  final double totalPaid;
  final double totalDues;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Customer Master Tab Enhancement Fields
  final CustomerType customerType;
  final double creditLimit;
  final double openingBalance;
  final String? priceLevel;
  final GstPreference gstPreference;
  final bool isBlocked;
  final String? blockReason;
  final DateTime? lastTransactionDate;

  Customer({
    required this.id,
    required this.odId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.totalBilled = 0,
    this.totalPaid = 0,
    this.totalDues = 0,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    // Customer Master Tab Enhancement Fields
    this.customerType = CustomerType.regular,
    this.creditLimit = 0,
    this.openingBalance = 0,
    this.priceLevel,
    this.gstPreference = GstPreference.exclusive,
    this.isBlocked = false,
    this.blockReason,
    this.lastTransactionDate,
  });

  double get balance => totalDues;
  bool get hasOutstanding => totalDues > 0;

  Customer copyWith({
    String? id,
    String? odId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    double? totalBilled,
    double? totalPaid,
    double? totalDues,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    // Customer Master Tab Enhancement Fields
    CustomerType? customerType,
    double? creditLimit,
    double? openingBalance,
    String? priceLevel,
    GstPreference? gstPreference,
    bool? isBlocked,
    String? blockReason,
    DateTime? lastTransactionDate,
  }) {
    return Customer(
      id: id ?? this.id,
      odId: odId ?? this.odId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      totalBilled: totalBilled ?? this.totalBilled,
      totalPaid: totalPaid ?? this.totalPaid,
      totalDues: totalDues ?? this.totalDues,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      customerType: customerType ?? this.customerType,
      creditLimit: creditLimit ?? this.creditLimit,
      openingBalance: openingBalance ?? this.openingBalance,
      priceLevel: priceLevel ?? this.priceLevel,
      gstPreference: gstPreference ?? this.gstPreference,
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': odId,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'gstin': gstin,
    'totalBilled': totalBilled,
    'totalPaid': totalPaid,
    'totalDues': totalDues,
    'isActive': isActive,
    'isSynced': isSynced,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    // Customer Master Tab Enhancement Fields
    'customerType': customerType.value,
    'creditLimit': creditLimit,
    'openingBalance': openingBalance,
    'priceLevel': priceLevel,
    'gstPreference': gstPreference.value,
    'isBlocked': isBlocked,
    'blockReason': blockReason,
    'lastTransactionDate': lastTransactionDate?.toIso8601String(),
  };

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'gstin': gstin,
    'totalBilled': totalBilled,
    'totalPaid': totalPaid,
    'totalDues': totalDues,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    // Customer Master Tab Enhancement Fields
    'customerType': customerType.value,
    'creditLimit': creditLimit,
    'openingBalance': openingBalance,
    'priceLevel': priceLevel,
    'gstPreference': gstPreference.value,
    'isBlocked': isBlocked,
    'blockReason': blockReason,
    'lastTransactionDate': lastTransactionDate?.toIso8601String(),
  };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'] as String,
    odId: map['userId'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    address: map['address'] as String?,
    gstin: map['gstin'] as String?,
    totalBilled: (map['totalBilled'] as num?)?.toDouble() ?? 0,
    totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0,
    totalDues: (map['totalDues'] as num?)?.toDouble() ?? 0,
    isActive: map['isActive'] as bool? ?? true,
    isSynced: map['isSynced'] as bool? ?? false,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    deletedAt: map['deletedAt'] != null
        ? DateTime.parse(map['deletedAt'] as String)
        : null,
    // Customer Master Tab Enhancement Fields
    customerType: CustomerType.fromString(
      map['customerType'] as String? ?? 'regular',
    ),
    creditLimit: (map['creditLimit'] as num?)?.toDouble() ?? 0,
    openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0,
    priceLevel: map['priceLevel'] as String?,
    gstPreference: GstPreference.fromString(
      map['gstPreference'] as String? ?? 'exclusive',
    ),
    isBlocked: map['isBlocked'] as bool? ?? false,
    blockReason: map['blockReason'] as String?,
    lastTransactionDate: map['lastTransactionDate'] != null
        ? DateTime.parse(map['lastTransactionDate'] as String)
        : null,
  );
}

/// Customers Repository
class CustomersRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  CustomersRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'customers';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Create a new customer
  Future<RepositoryResult<Customer>> createCustomer({
    required String userId,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? gstin,
  }) async {
    return await errorHandler.runSafe<Customer>(() async {
      // Check for duplicate phone number (if provided)
      if (phone != null && phone.isNotEmpty) {
        final existing =
            await (database.select(database.customers)..where(
                  (t) =>
                      t.phone.equals(phone) &
                      t.userId.equals(userId) &
                      t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (existing != null) {
          throw Exception('Customer with phone $phone already exists');
        }
      }

      final now = DateTime.now();
      final id = _generateId();

      final customer = Customer(
        id: id,
        odId: userId,
        name: name,
        phone: phone,
        email: email,
        address: address,
        gstin: gstin,
        createdAt: now,
        updatedAt: now,
      );

      await database
          .into(database.customers)
          .insert(
            CustomersCompanion.insert(
              id: id,
              userId: userId,
              name: name,
              phone: Value(phone),
              email: Value(email),
              address: Value(address),
              gstin: Value(gstin),
              isActive: const Value(true),
              isSynced: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: id,
        payload: customer.toFirestoreMap(),
      );
      await syncManager.enqueue(item);

      return customer;
    }, 'createCustomer');
  }

  /// Get customer by ID
  Future<RepositoryResult<Customer?>> getById(String id) async {
    return await errorHandler.runSafe<Customer?>(() async {
      final result =
          await (database.select(database.customers)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();

      if (result == null) return null;
      return _entityToCustomer(result);
    }, 'getById');
  }

  /// Get customer by phone
  Future<RepositoryResult<Customer?>> getByPhone(String phone) async {
    return await errorHandler.runSafe<Customer?>(() async {
      final result =
          await (database.select(database.customers)
                ..where((t) => t.phone.equals(phone) & t.deletedAt.isNull()))
              .getSingleOrNull();

      if (result == null) return null;
      return _entityToCustomer(result);
    }, 'getByPhone');
  }

  /// Get all customers for user
  Future<RepositoryResult<List<Customer>>> getAll({String? userId}) async {
    return await errorHandler.runSafe<List<Customer>>(() async {
      final query = database.select(database.customers)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (userId != null) {
        query.where((t) => t.userId.equals(userId));
      }

      final results = await query.get();
      return results.map(_entityToCustomer).toList();
    }, 'getAll');
  }

  /// Watch all customers
  Stream<List<Customer>> watchAll({String? userId}) {
    final query = database.select(database.customers)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    if (userId != null) {
      query.where((t) => t.userId.equals(userId));
    }

    return query.watch().map((rows) => rows.map(_entityToCustomer).toList());
  }

  /// Update customer
  Future<RepositoryResult<Customer>> updateCustomer(
    Customer customer, {
    required String userId,
  }) async {
    return await errorHandler.runSafe<Customer>(() async {
      final updated = customer.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await (database.update(
        database.customers,
      )..where((t) => t.id.equals(customer.id))).write(
        CustomersCompanion(
          name: Value(updated.name),
          phone: Value(updated.phone),
          email: Value(updated.email),
          address: Value(updated.address),
          gstin: Value(updated.gstin),
          totalBilled: Value(updated.totalBilled),
          totalPaid: Value(updated.totalPaid),
          totalDues: Value(updated.totalDues),
          isActive: Value(updated.isActive),
          isSynced: const Value(false),
          updatedAt: Value(updated.updatedAt),
        ),
      );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.update,
        targetCollection: collectionName,
        documentId: customer.id,
        payload: updated.toFirestoreMap(),
      );
      await syncManager.enqueue(item);

      return updated;
    }, 'updateCustomer');
  }

  /// Delete customer (soft delete)
  Future<RepositoryResult<bool>> deleteCustomer(
    String id, {
    required String userId,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      await (database.update(
        database.customers,
      )..where((t) => t.id.equals(id))).write(
        CustomersCompanion(
          deletedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.delete,
        targetCollection: collectionName,
        documentId: id,
        payload: {},
      );
      await syncManager.enqueue(item);

      return true;
    }, 'deleteCustomer');
  }

  // ============================================
  // BUSINESS LOGIC
  // ============================================

  /// Get customers with outstanding dues
  Future<RepositoryResult<List<Customer>>> getCustomersWithDues({
    String? userId,
  }) async {
    return await errorHandler.runSafe<List<Customer>>(() async {
      final query = database.select(database.customers)
        ..where((t) => t.deletedAt.isNull() & t.totalDues.isBiggerThanValue(0))
        ..orderBy([(t) => OrderingTerm.desc(t.totalDues)]);

      if (userId != null) {
        query.where((t) => t.userId.equals(userId));
      }

      final results = await query.get();
      return results.map(_entityToCustomer).toList();
    }, 'getCustomersWithDues');
  }

  /// Update customer balance after payment
  Future<RepositoryResult<Customer>> recordPayment({
    required String customerId,
    required double amount,
    required String userId,
  }) async {
    return await errorHandler.runSafe<Customer>(() async {
      final current = await (database.select(
        database.customers,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull();

      if (current == null) {
        throw Exception('Customer not found');
      }

      final newTotalPaid = current.totalPaid + amount;
      final newTotalDues = current.totalBilled - newTotalPaid;

      await (database.update(
        database.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          totalPaid: Value(newTotalPaid),
          totalDues: Value(newTotalDues > 0 ? newTotalDues : 0),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.update,
        targetCollection: collectionName,
        documentId: customerId,
        payload: {
          'totalPaid': newTotalPaid,
          'totalDues': newTotalDues > 0 ? newTotalDues : 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      await syncManager.enqueue(item);

      return _entityToCustomer(current).copyWith(
        totalPaid: newTotalPaid,
        totalDues: newTotalDues > 0 ? newTotalDues : 0,
      );
    }, 'recordPayment');
  }

  /// Search customers by name, phone, or invoice number
  ///
  /// CRITICAL DATA ISOLATION: All searches are scoped by userId (businessId)
  /// - userId is REQUIRED for business isolation
  /// - Searches by name, phone, and optionally invoice number
  /// - Optimized with limit for performance
  Future<RepositoryResult<List<Customer>>> search(
    String query, {
    required String userId, // MANDATORY for business isolation
    int limit = 50,
  }) async {
    return await errorHandler.runSafe<List<Customer>>(() async {
      if (query.isEmpty) return [];

      final lowerQuery = query.toLowerCase();

      // CRITICAL: Always filter by userId for business isolation
      // This prevents cross-business data leakage
      final allCustomers =
          await (database.select(database.customers)
                ..where((t) => t.deletedAt.isNull() & t.userId.equals(userId))
                ..orderBy([(t) => OrderingTerm.asc(t.name)])
                ..limit(limit * 2)) // Fetch extra to account for filtering
              .get();

      // Filter by name or phone in Dart for case-insensitive search
      var results = allCustomers.where(
        (c) =>
            c.name.toLowerCase().contains(lowerQuery) ||
            (c.phone?.contains(query) ?? false),
      );

      // If query looks like an invoice number, also search bills
      // and include matching customers
      if (query.toUpperCase().startsWith('INV') ||
          query.toUpperCase().startsWith('BILL') ||
          RegExp(r'^\d{6,}$').hasMatch(query)) {
        try {
          final matchingBills =
              await (database.select(database.bills)..where(
                    (t) =>
                        t.deletedAt.isNull() &
                        t.invoiceNumber.contains(query) &
                        t.userId.equals(userId),
                  ))
                  .get();

          final customerIdsFromBills = matchingBills
              .map((b) => b.customerId)
              .toSet();

          // Add customers not already in results
          final existingIds = results.map((c) => c.id).toSet();
          final additionalCustomers = allCustomers.where(
            (c) =>
                customerIdsFromBills.contains(c.id) &&
                !existingIds.contains(c.id),
          );

          results = [...results, ...additionalCustomers];
        } catch (e) {
          // Bill search failed, continue with name/phone results only
        }
      }

      return results.take(limit).map(_entityToCustomer).toList();
    }, 'search');
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  Customer _entityToCustomer(CustomerEntity e) => Customer(
    id: e.id,
    odId: e.userId,
    name: e.name,
    phone: e.phone,
    email: e.email,
    address: e.address,
    gstin: e.gstin,
    totalBilled: e.totalBilled,
    totalPaid: e.totalPaid,
    totalDues: e.totalDues,
    isActive: e.isActive,
    isSynced: e.isSynced,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    deletedAt: e.deletedAt,
    // Customer Master Tab Enhancement Fields
    customerType: CustomerType.fromString(e.customerType),
    creditLimit: e.creditLimit,
    openingBalance: e.openingBalance,
    priceLevel: e.priceLevel,
    gstPreference: GstPreference.fromString(e.gstPreference),
    isBlocked: e.isBlocked,
    blockReason: e.blockReason,
    lastTransactionDate: e.lastTransactionDate,
  );

  // ============================================
  // ANALYTICS & SCORING
  // ============================================

  /// Calculate Customer Trust Score
  Future<RepositoryResult<TrustScore>> calculateTrustScore(
    String customerId,
  ) async {
    return await errorHandler.runSafe<TrustScore>(() async {
      // 1. Fetch History
      final bills =
          await (database.select(database.bills)..where(
                (t) => t.customerId.equals(customerId) & t.deletedAt.isNull(),
              ))
              .get();

      if (bills.isEmpty) {
        return TrustScore.neutral();
      }

      // 2. Calculate Components
      double score = 0;
      final now = DateTime.now();

      // A. Reliability (Max 40) - Late Payments
      int lateBills = bills.where((b) {
        final isOverdue = b.status == 'OVERDUE';
        final isOldUnpaid =
            (b.status == 'Unpaid' || b.status == 'Partial') &&
            b.billDate.isBefore(now.subtract(const Duration(days: 30)));
        return isOverdue || isOldUnpaid;
      }).length;

      double reliabilityRatio = bills.isNotEmpty
          ? (1 - (lateBills / bills.length))
          : 1.0;
      double reliabilityScore = 40 * reliabilityRatio;

      // B. Financial Health (Max 30) - Credit Usage
      double totalBilled = bills.fold(0, (sum, b) => sum + b.grandTotal);
      double totalPaid = bills.fold(0, (sum, b) => sum + b.paidAmount);
      double totalDues = (totalBilled - totalPaid).clamp(0, double.infinity);

      double creditRatio = totalBilled > 0 ? (totalDues / totalBilled) : 0.0;
      double creditScore = 30 * (1 - creditRatio); // More debt = lower score

      // C. Value (Max 20) - Average Bill Amount
      double avgBill = bills.isNotEmpty ? (totalBilled / bills.length) : 0;
      double valueScore = ((avgBill / 1000) * 20).clamp(
        0,
        20,
      ); // Cap at 20 (Target ₹1000)

      // D. Frequency (Max 10) - Bills per Month
      DateTime firstBillDate = bills
          .map((b) => b.billDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      int daysActive =
          now.difference(firstBillDate).inDays + 1; // +1 to avoid div by zero
      double monthsActive = daysActive / 30;
      double billsPerMonth = monthsActive > 0
          ? (bills.length / monthsActive)
          : 0;
      double frequencyScore = ((billsPerMonth / 4) * 10).clamp(
        0,
        10,
      ); // Cap at 10 (Target 4/month)

      // Total
      score = reliabilityScore + creditScore + valueScore + frequencyScore;

      return TrustScore(
        score: score,
        reliabilityScore: reliabilityScore,
        creditScore: creditScore,
        valueScore: valueScore,
        frequencyScore: frequencyScore,
        totalBills: bills.length,
        lateBills: lateBills,
        totalDues: totalDues,
      );
    }, 'calculateTrustScore');
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (DateTime.now().microsecond % 9000)).toString();
  }
}

class TrustScore {
  final double score;
  final double reliabilityScore;
  final double creditScore;
  final double valueScore;
  final double frequencyScore;

  // Metadata
  final int totalBills;
  final int lateBills;
  final double totalDues;

  TrustScore({
    required this.score,
    required this.reliabilityScore,
    required this.creditScore,
    required this.valueScore,
    required this.frequencyScore,
    required this.totalBills,
    required this.lateBills,
    required this.totalDues,
  });

  factory TrustScore.neutral() => TrustScore(
    score: 50,
    reliabilityScore: 20,
    creditScore: 15,
    valueScore: 10,
    frequencyScore: 5,
    totalBills: 0,
    lateBills: 0,
    totalDues: 0,
  );

  bool get isRisky => score < 50;
  bool get isExcellent => score >= 80;

  String get label {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Average';
    if (score >= 20) return 'Poor';
    return 'High Risk';
  }
}
