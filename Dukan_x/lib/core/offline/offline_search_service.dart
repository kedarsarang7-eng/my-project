// ignore_for_file: dead_null_aware_expression
// ignore_for_file: constant_identifier_names
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../services/search_service.dart';

/// Offline Search Service
///
/// Provides local search functionality using Drift/SQLite database.
/// Used as a fallback when the online search service is unavailable.
///
/// This service:
/// - Queries the local Drift database
/// - Supports full-text search on indexed fields
/// - Provides pagination
/// - Maintains cache freshness
///
/// @author DukanX Engineering
class OfflineSearchService {
  static final OfflineSearchService _instance =
      OfflineSearchService._internal();
  factory OfflineSearchService() => _instance;
  OfflineSearchService._internal();

  AppDatabase get _db => AppDatabase.instance;

  // Cache configuration
  static const int MAX_CACHE_AGE_DAYS = 30;
  static const int DEFAULT_PAGE_SIZE = 20;

  /// Search customers in local database
  ///
  /// Searches: name, phone, email, address, gstin
  Future<SearchResult<Map<String, dynamic>>> searchCustomers(
    String query, {
    int page = 1,
    int pageSize = DEFAULT_PAGE_SIZE,
    String? businessId,
  }) async {
    final offset = (page - 1) * pageSize;

    // Build the search query
    final searchPattern = '%${query.toLowerCase()}%';

    final queryBuilder = _db.select(_db.customers)
      ..where(
        (c) =>
            c.name.lower().like(searchPattern) |
            c.phone.lower().like(searchPattern) |
            c.email.lower().like(searchPattern) |
            c.address.lower().like(searchPattern) |
            c.gstin.lower().like(searchPattern),
      )
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
      ..limit(pageSize, offset: offset);

    if (businessId != null) {
      queryBuilder.where((c) => c.id.like('%$businessId%'));
    }

    final results = await queryBuilder.get();

    // Get total count for pagination
    final countQuery = _db.customers.selectOnly()
      ..addColumns([_db.customers.id.count()]);
    final totalCount =
        await countQuery
            .map((row) => row.read(_db.customers.id.count()))
            .getSingle() ??
        0;

    return SearchResult(
      results: results.map((c) => _customerToMap(c)).toList(),
      total: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Search products in local database
  ///
  /// Searches: name, sku, barcode, category, brand
  Future<SearchResult<Map<String, dynamic>>> searchProducts(
    String query, {
    int page = 1,
    int pageSize = DEFAULT_PAGE_SIZE,
    String? category,
    bool? isLowStock,
  }) async {
    final offset = (page - 1) * pageSize;
    final searchPattern = '%${query.toLowerCase()}%';

    final queryBuilder = _db.select(_db.products)
      ..where(
        (p) =>
            p.name.lower().like(searchPattern) |
            p.sku.lower().like(searchPattern) |
            p.barcode.lower().like(searchPattern) |
            p.category.lower().like(searchPattern),
      )
      ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])
      ..limit(pageSize, offset: offset);

    if (category != null) {
      queryBuilder.where((p) => p.category.equals(category));
    }

    if (isLowStock == true) {
      queryBuilder.where(
        (p) => p.stockQuantity.isSmallerThan(const Constant(10)),
      );
    }

    final results = await queryBuilder.get();

    final count = _db.products.selectOnly()
      ..addColumns([_db.products.id.count()]);
    final totalCount =
        await count
            .map((row) => row.read(_db.products.id.count()))
            .getSingle() ??
        0;

    return SearchResult(
      results: results.map((p) => _productToMap(p)).toList(),
      total: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Search bills in local database
  ///
  /// Searches: invoice number, customer name, customer phone
  Future<SearchResult<Map<String, dynamic>>> searchBills(
    String query, {
    int page = 1,
    int pageSize = DEFAULT_PAGE_SIZE,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    final offset = (page - 1) * pageSize;
    final searchPattern = '%${query.toLowerCase()}%';

    final queryBuilder = _db.select(_db.bills)
      ..where(
        (b) =>
            b.invoiceNumber.lower().like(searchPattern) |
            b.customerName.lower().like(searchPattern),
      )
      ..orderBy([(b) => OrderingTerm.desc(b.billDate)])
      ..limit(pageSize, offset: offset);

    if (dateFrom != null) {
      queryBuilder.where((b) => b.billDate.isBiggerOrEqualValue(dateFrom));
    }

    if (dateTo != null) {
      queryBuilder.where((b) => b.billDate.isSmallerOrEqualValue(dateTo));
    }

    if (status != null) {
      queryBuilder.where((b) => b.status.equals(status));
    }

    final results = await queryBuilder.get();

    final count = _db.bills.selectOnly()..addColumns([_db.bills.id.count()]);
    final totalCount =
        await count.map((row) => row.read(_db.bills.id.count())).getSingle() ??
        0;

    return SearchResult(
      results: results.map((b) => _billToMap(b)).toList(),
      total: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Search patients (for clinic/pharmacy)
  ///
  /// Searches: name, phone, emergency contact
  Future<SearchResult<Map<String, dynamic>>> searchPatients(
    String query, {
    int page = 1,
    int pageSize = DEFAULT_PAGE_SIZE,
  }) async {
    // Patients are stored as customers with additional metadata
    final offset = (page - 1) * pageSize;
    final searchPattern = '%${query.toLowerCase()}%';

    final queryBuilder = _db.select(_db.customers)
      ..where(
        (c) =>
            c.name.lower().like(searchPattern) |
            c.phone.lower().like(searchPattern),
      )
      ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])
      ..limit(pageSize, offset: offset);

    final results = await queryBuilder.get();

    final count = _db.customers.selectOnly()
      ..addColumns([_db.customers.id.count()]);
    final totalCount =
        await count
            .map((row) => row.read(_db.customers.id.count()))
            .getSingle() ??
        0;

    return SearchResult(
      results: results.map((c) => _customerToMap(c)).toList(),
      total: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Search suppliers/vendors
  ///
  /// Searches: name, phone, email, gstin
  Future<SearchResult<Map<String, dynamic>>> searchSuppliers(
    String query, {
    int page = 1,
    int pageSize = DEFAULT_PAGE_SIZE,
  }) async {
    final offset = (page - 1) * pageSize;
    final searchPattern = '%${query.toLowerCase()}%';

    final queryBuilder = _db.select(_db.vendors)
      ..where(
        (v) =>
            v.name.lower().like(searchPattern) |
            v.phone.lower().like(searchPattern) |
            v.email.lower().like(searchPattern) |
            v.gstin.lower().like(searchPattern),
      )
      ..orderBy([(v) => OrderingTerm.desc(v.createdAt)])
      ..limit(pageSize, offset: offset);

    final results = await queryBuilder.get();

    final count = _db.vendors.selectOnly()
      ..addColumns([_db.vendors.id.count()]);
    final totalCount =
        await count
            .map((row) => row.read(_db.vendors.id.count()))
            .getSingle() ??
        0;

    return SearchResult(
      results: results.map((v) => _vendorToMap(v)).toList(),
      total: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Generic search by entity type
  ///
  /// Routes to the appropriate search method based on entity type.
  /// Core entities use typed Drift queries; vertical-specific entities
  /// use the generic [_searchTable] raw-SQL helper.
  Future<SearchResult<Map<String, dynamic>>> search(
    SearchEntityType entityType,
    String query, {
    int page = 1,
    int pageSize = DEFAULT_PAGE_SIZE,
    Map<String, dynamic>? filters,
  }) async {
    switch (entityType) {
      // ── Core (typed Drift queries) ──────────────────────────────────
      case SearchEntityType.customers:
        return searchCustomers(query, page: page, pageSize: pageSize);
      case SearchEntityType.products:
        return searchProducts(
          query,
          page: page,
          pageSize: pageSize,
          category: filters?['category'],
          isLowStock: filters?['isLowStock'],
        );
      case SearchEntityType.bills:
        return searchBills(
          query,
          page: page,
          pageSize: pageSize,
          dateFrom: filters?['dateFrom'],
          dateTo: filters?['dateTo'],
          status: filters?['status'],
        );
      case SearchEntityType.patients:
        return searchPatients(query, page: page, pageSize: pageSize);
      case SearchEntityType.suppliers:
        return searchSuppliers(query, page: page, pageSize: pageSize);

      // ── Vertical-specific (generic raw-SQL helper) ─────────────────
      case SearchEntityType.expenses:
        return _searchTable(
          'expenses',
          ['category', 'description', 'vendor_name'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'expense_date',
        );
      case SearchEntityType.purchaseBills:
        return _searchTable(
          'purchase_orders',
          ['invoice_number', 'vendor_name'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'purchase_date',
        );
      case SearchEntityType.productBatches:
        return _searchTable(
          'product_batches',
          ['batch_number', 'product_id'],
          query,
          page: page,
          pageSize: pageSize,
        );
      case SearchEntityType.visits:
        return _searchTable(
          'visits',
          ['chief_complaint', 'diagnosis', 'patient_id'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'visit_date',
        );
      case SearchEntityType.prescriptions:
        return _searchTable(
          'prescriptions',
          ['patient_id', 'visit_id', 'advice'],
          query,
          page: page,
          pageSize: pageSize,
        );
      case SearchEntityType.kots:
        return _searchTable(
          'restaurant_kots',
          ['table_number', 'special_instructions', 'status'],
          query,
          page: page,
          pageSize: pageSize,
        );
      case SearchEntityType.menuItems:
        return _searchTable(
          'food_menu_items',
          ['name', 'description'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'name',
        );
      case SearchEntityType.ledgerEntries:
        return _searchTable(
          'ledger_accounts',
          ['name', 'account_type', 'code'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'name',
        );
      case SearchEntityType.bankTransactions:
        return _searchTable(
          'bank_transactions',
          ['description', 'category', 'reference_id'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'transaction_date',
        );
      case SearchEntityType.deliveryChallans:
        return _searchTable(
          'delivery_challans',
          ['challan_number', 'customer_name', 'vehicle_number'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'challan_date',
        );
      case SearchEntityType.bookReturns:
        return _searchTable(
          'return_inwards',
          ['bill_number', 'credit_note_number', 'reason'],
          query,
          page: page,
          pageSize: pageSize,
        );
      case SearchEntityType.preOrders:
        return _searchTable(
          'bookings',
          ['booking_number', 'customer_name', 'notes'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'date',
        );
      case SearchEntityType.serviceJobs:
        return _searchTable(
          'service_jobs',
          [
            'job_number',
            'customer_name',
            'customer_phone',
            'brand',
            'model',
            'problem_description',
          ],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'received_at',
        );
      case SearchEntityType.eInvoices:
        return _searchTable(
          'e_invoices',
          ['irn', 'ack_number', 'bill_id', 'status'],
          query,
          page: page,
          pageSize: pageSize,
        );
      case SearchEntityType.fuelTransactions:
        return _searchTable(
          'bills',
          ['invoice_number', 'customer_name', 'vehicle_number', 'fuel_type'],
          query,
          page: page,
          pageSize: pageSize,
          orderBy: 'bill_date',
        );
    }
  }

  /// Get recent items from local cache
  ///
  /// Useful for showing recently accessed items without a search query.
  /// Core entities use typed Drift queries; others use [_recentFromTable].
  Future<List<Map<String, dynamic>>> getRecentItems(
    SearchEntityType entityType, {
    int limit = 10,
  }) async {
    switch (entityType) {
      case SearchEntityType.customers:
        final results =
            await (_db.select(_db.customers)
                  ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])
                  ..limit(limit))
                .get();
        return results.map((c) => _customerToMap(c)).toList();

      case SearchEntityType.products:
        final results =
            await (_db.select(_db.products)
                  ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])
                  ..limit(limit))
                .get();
        return results.map((p) => _productToMap(p)).toList();

      case SearchEntityType.bills:
        final results =
            await (_db.select(_db.bills)
                  ..orderBy([(b) => OrderingTerm.desc(b.billDate)])
                  ..limit(limit))
                .get();
        return results.map((b) => _billToMap(b)).toList();

      case SearchEntityType.suppliers:
        final results =
            await (_db.select(_db.vendors)
                  ..orderBy([(v) => OrderingTerm.desc(v.createdAt)])
                  ..limit(limit))
                .get();
        return results.map((v) => _vendorToMap(v)).toList();

      case SearchEntityType.expenses:
        return _recentFromTable('expenses', limit, orderBy: 'expense_date');
      case SearchEntityType.purchaseBills:
        return _recentFromTable(
          'purchase_orders',
          limit,
          orderBy: 'purchase_date',
        );
      case SearchEntityType.serviceJobs:
        return _recentFromTable('service_jobs', limit, orderBy: 'received_at');
      case SearchEntityType.deliveryChallans:
        return _recentFromTable(
          'delivery_challans',
          limit,
          orderBy: 'challan_date',
        );
      case SearchEntityType.menuItems:
        return _recentFromTable('food_menu_items', limit, orderBy: 'name');
      case SearchEntityType.preOrders:
        return _recentFromTable('bookings', limit, orderBy: 'date');
      default:
        return _recentFromTable(_entityToTable(entityType), limit);
    }
  }

  /// Clear old cache entries
  ///
  /// Removes items older than MAX_CACHE_AGE_DAYS
  Future<void> clearOldCache() async {
    final cutoffDate = DateTime.now().subtract(
      const Duration(days: MAX_CACHE_AGE_DAYS),
    );

    // Clear old bills
    await (_db.delete(
      _db.bills,
    )..where((b) => b.updatedAt.isSmallerThanValue(cutoffDate))).go();

    // Clear old customers (but keep if they have transactions)
    // This is a simplified version - production should check for references
    await (_db.delete(_db.customers)..where(
          (c) =>
              c.updatedAt.isSmallerThanValue(cutoffDate) &
              c.totalBilled.equals(0.0),
        ))
        .go();

    // Clear old products (be careful not to delete products in stock)
    await (_db.delete(_db.products)..where(
          (p) =>
              p.updatedAt.isSmallerThanValue(cutoffDate) &
              p.stockQuantity.equals(0.0),
        ))
        .go();
  }

  // ==========================================================================
  // DATA TRANSFORMATION HELPERS
  // ==========================================================================

  Map<String, dynamic> _customerToMap(CustomerEntity c) {
    return {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
      'email': c.email,
      'address': c.address,
      'gstin': c.gstin,
      'stateCode': c.stateCode,
      'totalDues': c.totalDues,
      'totalBilled': c.totalBilled,
      'totalPaid': c.totalPaid,
      'creditLimit': c.creditLimit,
      'isActive': c.isActive,
      'isBlocked': c.isBlocked,
      'loyaltyPoints': c.loyaltyPoints,
      'linkStatus': c.linkStatus,
      'createdAt': c.createdAt.toIso8601String(),
      'updatedAt': c.updatedAt.toIso8601String(),
      'lastTransactionDate': c.lastTransactionDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> _productToMap(ProductEntity p) {
    return {
      'id': p.id,
      'name': p.name,
      'sku': p.sku,
      'barcode': p.barcode,
      'altBarcodes': p.altBarcodes,
      'category': p.category,
      'brand': p.brand,
      'sellingPrice': p.sellingPrice,
      'costPrice': p.costPrice,
      'hsnCode': p.hsnCode,
      'stockQuantity': p.stockQuantity,
      'lowStockThreshold': p.lowStockThreshold,
      'unit': p.unit,
      'size': p.size,
      'color': p.color,
      'groupId': p.groupId,
      'drugSchedule': p.drugSchedule,
      'isbn': p.isbn,
      'author': p.author,
      'publisher': p.publisher,
      'isActive': p.isActive,
      'isLowStock': (p.stockQuantity ?? 0) <= (p.lowStockThreshold ?? 10),
      'createdAt': p.createdAt.toIso8601String(),
      'updatedAt': p.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _billToMap(BillEntity b) {
    return {
      'id': b.id,
      'invoiceNumber': b.invoiceNumber,
      'customerId': b.customerId,
      'customerName': b.customerName,
      'subtotal': b.subtotal,
      'taxAmount': b.taxAmount,
      'discountAmount': b.discountAmount,
      'grandTotal': b.grandTotal,
      'paidAmount': b.paidAmount,
      'status': b.status,
      'paymentMode': b.paymentMode,
      'billDate': b.billDate.toIso8601String(),
      'dueDate': b.dueDate?.toIso8601String(),
      'tableNumber': b.tableNumber,
      'vehicleNumber': b.vehicleNumber,
      'prescriptionId': b.prescriptionId,
      'shiftId': b.shiftId,
      'kotId': b.kotId,
      'createdAt': b.createdAt.toIso8601String(),
      'updatedAt': b.updatedAt.toIso8601String(),
      'deletedAt': b.deletedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _vendorToMap(VendorEntity v) {
    return {
      'id': v.id,
      'name': v.name,
      'phone': v.phone,
      'email': v.email,
      'address': v.address,
      'gstin': v.gstin,
      'upiId': v.upiId,
      'upiName': v.upiName,
      'totalPurchased': v.totalPurchased,
      'totalPaid': v.totalPaid,
      'totalOutstanding': v.totalOutstanding,
      'isActive': v.isActive,
      'createdAt': v.createdAt.toIso8601String(),
      'updatedAt': v.updatedAt.toIso8601String(),
    };
  }

  // ==========================================================================
  // GENERIC RAW-SQL SEARCH HELPER
  // ==========================================================================

  /// Searches any table by LIKE-matching [searchColumns] against [query].
  ///
  /// Returns the full row as `Map<String, dynamic>` (Drift's `QueryRow.data`).
  /// This avoids needing a dedicated method + toMap converter per entity.
  Future<SearchResult<Map<String, dynamic>>> _searchTable(
    String tableName,
    List<String> searchColumns,
    String query, {
    int page = 1,
    int pageSize = DEFAULT_PAGE_SIZE,
    String orderBy = 'created_at',
  }) async {
    final offset = (page - 1) * pageSize;
    final pattern = '%${query.toLowerCase()}%';

    final whereClauses = searchColumns
        .map((c) => 'LOWER("$c") LIKE ?')
        .join(' OR ');
    final vars = searchColumns.map((_) => Variable<String>(pattern)).toList();

    final rows = await _db
        .customSelect(
          'SELECT * FROM "$tableName" '
          'WHERE ($whereClauses) '
          'ORDER BY "$orderBy" DESC '
          'LIMIT ? OFFSET ?',
          variables: [...vars, Variable<int>(pageSize), Variable<int>(offset)],
        )
        .get();

    final countRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM "$tableName" '
          'WHERE ($whereClauses)',
          variables: vars,
        )
        .getSingle();

    return SearchResult(
      results: rows.map((r) => r.data).toList(),
      total: countRow.read<int>('cnt'),
      page: page,
      pageSize: pageSize,
    );
  }

  /// Returns the N most recent rows from [tableName].
  Future<List<Map<String, dynamic>>> _recentFromTable(
    String tableName,
    int limit, {
    String orderBy = 'created_at',
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM "$tableName" '
          'ORDER BY "$orderBy" DESC LIMIT ?',
          variables: [Variable<int>(limit)],
        )
        .get();
    return rows.map((r) => r.data).toList();
  }

  /// Maps a [SearchEntityType] to its SQLite table name.
  String _entityToTable(SearchEntityType type) {
    switch (type) {
      case SearchEntityType.customers:
        return 'customers';
      case SearchEntityType.products:
        return 'products';
      case SearchEntityType.bills:
        return 'bills';
      case SearchEntityType.suppliers:
        return 'vendors';
      case SearchEntityType.patients:
        return 'patients';
      case SearchEntityType.expenses:
        return 'expenses';
      case SearchEntityType.purchaseBills:
        return 'purchase_orders';
      case SearchEntityType.productBatches:
        return 'product_batches';
      case SearchEntityType.visits:
        return 'visits';
      case SearchEntityType.prescriptions:
        return 'prescriptions';
      case SearchEntityType.kots:
        return 'restaurant_kots';
      case SearchEntityType.menuItems:
        return 'food_menu_items';
      case SearchEntityType.ledgerEntries:
        return 'ledger_accounts';
      case SearchEntityType.bankTransactions:
        return 'bank_transactions';
      case SearchEntityType.deliveryChallans:
        return 'delivery_challans';
      case SearchEntityType.bookReturns:
        return 'return_inwards';
      case SearchEntityType.preOrders:
        return 'bookings';
      case SearchEntityType.serviceJobs:
        return 'service_jobs';
      case SearchEntityType.eInvoices:
        return 'e_invoices';
      case SearchEntityType.fuelTransactions:
        return 'bills';
    }
  }
}

/// Search result model (re-export for offline use)
class SearchResult<T> {
  final List<T> results;
  final int total;
  final int page;
  final int pageSize;

  SearchResult({
    required this.results,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => (page * pageSize) < total;
}
