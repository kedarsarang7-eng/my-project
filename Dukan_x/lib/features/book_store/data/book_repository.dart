import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import 'book_store_sync_queue.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final apiClient = sl<ApiClient>();
  return BookRepository(
    apiClient: apiClient,
    database: sl<AppDatabase>(),
    productsRepository: sl<ProductsRepository>(),
    tenantIdResolver: () => ref.read(authStateProvider).userId,
    syncQueue: BookStoreSyncQueue(apiClient: apiClient),
  );
});

class SchoolOrder {
  final String id;
  final String schoolName;
  final String grade;
  final int totalSets;
  final int fulfilledSets;
  final String status;

  SchoolOrder({
    required this.id,
    required this.schoolName,
    required this.grade,
    required this.totalSets,
    required this.fulfilledSets,
    required this.status,
  });

  factory SchoolOrder.fromJson(Map<String, dynamic> json) {
    return SchoolOrder(
      id: json['id'],
      schoolName: json['schoolName'],
      grade: json['grade'],
      totalSets: json['totalSets'],
      fulfilledSets: json['fulfilledSets'],
      status: json['status'],
    );
  }
}

class Consignment {
  final String id;
  final String publisherId;
  final String publisherName;
  final int totalBooksReceived;
  final int totalBooksSold;
  final double settlementAmount;
  final String status;

  Consignment({
    required this.id,
    required this.publisherId,
    required this.publisherName,
    required this.totalBooksReceived,
    required this.totalBooksSold,
    required this.settlementAmount,
    required this.status,
  });

  factory Consignment.fromJson(Map<String, dynamic> json) {
    return Consignment(
      id: json['id'],
      publisherId: json['publisherId'],
      publisherName: json['publisherName'],
      totalBooksReceived: json['totalBooksReceived'],
      totalBooksSold: json['totalBooksSold'],
      settlementAmount: (json['settlementAmount'] ?? 0).toDouble(),
      status: json['status'],
    );
  }
}

/// Result model for `GET /book-store/isbn/{isbn}` — ISBN scan auto-fill lookup.
class BookIsbnResult {
  final String id;
  final String isbn;
  final String name;
  final String? author;
  final String? publisher;
  final String? brand;
  final String? category;
  final String? subcategory;
  final int salePriceCents;
  final int? mrpCents;
  final int? purchasePriceCents;
  final int currentStock;
  final int lowStockThreshold;
  final String? hsnCode;
  final String? autoFillItemName;
  final String? autoFillItemLabel;
  final String? autoFillUnit;

  BookIsbnResult({
    required this.id,
    required this.isbn,
    required this.name,
    this.author,
    this.publisher,
    this.brand,
    this.category,
    this.subcategory,
    required this.salePriceCents,
    this.mrpCents,
    this.purchasePriceCents,
    required this.currentStock,
    required this.lowStockThreshold,
    this.hsnCode,
    this.autoFillItemName,
    this.autoFillItemLabel,
    this.autoFillUnit,
  });

  factory BookIsbnResult.fromJson(Map<String, dynamic> json) {
    final autoFill = json['autoFill'] as Map<String, dynamic>?;
    return BookIsbnResult(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      name: json['name'] as String,
      author: json['author'] as String?,
      publisher: json['publisher'] as String?,
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      salePriceCents: (json['salePriceCents'] as num?)?.toInt() ?? 0,
      mrpCents: (json['mrpCents'] as num?)?.toInt(),
      purchasePriceCents: (json['purchasePriceCents'] as num?)?.toInt(),
      currentStock: (json['currentStock'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 0,
      hsnCode: json['hsnCode'] as String?,
      autoFillItemName: autoFill?['itemName'] as String?,
      autoFillItemLabel: autoFill?['itemLabel'] as String?,
      autoFillUnit: autoFill?['unit'] as String?,
    );
  }
}

/// Result model for items in `GET /book-store/low-stock` response.
class LowStockBook {
  final String id;
  final String name;
  final String? isbn;
  final String? author;
  final String? publisher;
  final int currentStock;
  final int lowStockThreshold;

  LowStockBook({
    required this.id,
    required this.name,
    this.isbn,
    this.author,
    this.publisher,
    required this.currentStock,
    required this.lowStockThreshold,
  });

  factory LowStockBook.fromJson(Map<String, dynamic> json) {
    return LowStockBook(
      id: json['id'] as String,
      name: json['name'] as String,
      isbn: json['isbn'] as String?,
      author: json['author'] as String?,
      publisher: json['publisher'] as String?,
      currentStock: (json['currentStock'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A single line item within a publisher return.
class ReturnItem {
  final String? isbn;
  final String? name;
  final int qty;

  /// Price per unit in integer Paise.
  final int pricePaise;

  ReturnItem({
    this.isbn,
    this.name,
    required this.qty,
    required this.pricePaise,
  });

  Map<String, dynamic> toJson() => {
    if (isbn != null && isbn!.isNotEmpty) 'isbn': isbn,
    if (name != null && name!.isNotEmpty) 'name': name,
    'qty': qty,
    'price': pricePaise,
  };

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      isbn: json['isbn'] as String?,
      name: json['name'] as String?,
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      pricePaise: (json['price'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model for a publisher return record loaded from the backend.
class BookReturn {
  final String id;
  final String vendorId;
  final String? vendorName;
  final String returnDate;
  final String status;
  final List<ReturnItem> items;

  /// Total return amount in integer Paise.
  final int totalAmountPaise;
  final String? notes;
  final String createdAt;

  BookReturn({
    required this.id,
    required this.vendorId,
    this.vendorName,
    required this.returnDate,
    required this.status,
    required this.items,
    required this.totalAmountPaise,
    this.notes,
    required this.createdAt,
  });

  factory BookReturn.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return BookReturn(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      vendorName: json['vendorName'] as String?,
      returnDate: json['returnDate'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      items: rawItems
          .map((e) => ReturnItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAmountPaise: (json['totalAmount'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class BookRepository {
  final ApiClient apiClient;
  final AppDatabase database;
  final ProductsRepository productsRepository;
  final String? Function() tenantIdResolver;
  final BookStoreSyncQueue syncQueue;

  BookRepository({
    required this.apiClient,
    required this.database,
    required this.productsRepository,
    required this.tenantIdResolver,
    required this.syncQueue,
  });

  /// Initialize the offline sync queue. Must be called once after construction.
  /// This loads persisted pending operations and starts the connectivity
  /// listener for auto-flush on reconnect (Requirement 10.3, 10.7).
  Future<void> initializeSyncQueue() async {
    if (!syncQueue.isInitialized) {
      await syncQueue.initialize();
    }
  }

  /// Whether there are pending offline writes awaiting sync.
  bool get hasPendingWrites => syncQueue.hasPendingOperations;

  /// Number of pending offline writes.
  int get pendingWriteCount => syncQueue.pendingCount;

  /// Manually trigger a flush of pending writes (Requirement 10.3).
  /// Typically called when connectivity is restored.
  Future<FlushResult> flushPendingWrites() => syncQueue.flush();

  /// Resolves the active Tenant_Id from the authenticated session.
  /// Returns a [Left(ServerFailure)] if the tenant cannot be resolved (null or empty).
  Either<Failure, String> _resolveTenantId() {
    final tenantId = tenantIdResolver();
    if (tenantId == null || tenantId.isEmpty) {
      return Left(
        ServerFailure(
          'Unresolved tenant: Tenant_Id is missing or unresolved. '
          'No read or write was performed.',
        ),
      );
    }
    return Right(tenantId);
  }

  /// Creates a book product and persists isbn, author, and publisher to the
  /// Product record scoped to the active Tenant_Id.
  ///
  /// Uses [productsRepository.createProduct] for the base row, then patches the
  /// book-specific columns (isbn, author, publisher) via a direct Drift update
  /// on the same row. This keeps us within the freely-editable scope without
  /// modifying the shared [ProductsRepository.createProduct] signature.
  ///
  /// Note: `edition` is NOT persisted here because the Products Drift table does
  /// not have an `edition` column. Adding it requires a Schema_Gate (new Drift
  /// column + build_runner regeneration + migration).
  Future<Either<Failure, Product>> createBook({
    required String title,
    required String isbn,
    String? author,
    String? publisher,
    String? category,
    required double sellingPrice,
    double costPrice = 0,
    double stockQuantity = 1,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    final tenantId = (tenantResult as Right<Failure, String>).value;

    try {
      // Step 1: Create the base product via the shared repository.
      final result = await productsRepository.createProduct(
        userId: tenantId,
        name: title,
        barcode: isbn,
        category: category ?? 'Fiction',
        sellingPrice: sellingPrice,
        costPrice: costPrice,
        stockQuantity: stockQuantity,
      );

      if (!result.isSuccess || result.data == null) {
        return Left(
          ServerFailure(result.errorMessage ?? 'Failed to create product'),
        );
      }

      final product = result.data!;

      // Step 2: Patch the book-specific columns (isbn, author, publisher)
      // directly on the Drift row. These columns already exist in the Products
      // table but are not populated by the generic createProduct method.
      await (database.update(
        database.products,
      )..where((t) => t.id.equals(product.id))).write(
        ProductsCompanion(
          isbn: Value(isbn.isNotEmpty ? isbn : null),
          author: Value(author != null && author.isNotEmpty ? author : null),
          publisher: Value(
            publisher != null && publisher.isNotEmpty ? publisher : null,
          ),
        ),
      );

      return Right(product);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Updates book-specific metadata (isbn, author, publisher) on an existing
  /// Product record scoped to the active Tenant_Id.
  ///
  /// Note: `edition` is NOT persisted (Schema_Gate required for new column).
  Future<Either<Failure, void>> updateBookMetadata({
    required String productId,
    String? isbn,
    String? author,
    String? publisher,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    final tenantId = (tenantResult as Right<Failure, String>).value;

    try {
      // Verify the product belongs to this tenant before updating
      final existing =
          await (database.select(database.products)
                ..where((t) => t.id.equals(productId))
                ..where((t) => t.userId.equals(tenantId)))
              .getSingleOrNull();

      if (existing == null) {
        return Left(
          ServerFailure(
            'Product not found or does not belong to the active tenant.',
          ),
        );
      }

      await (database.update(
        database.products,
      )..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          isbn: Value(isbn),
          author: Value(author),
          publisher: Value(publisher),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Fetches school orders from the backend, scoped to the active tenant.
  ///
  /// Supports pagination via [page] (1-based) and [limit] (items per page).
  /// The query params are passed to the backend so when server-side pagination
  /// is deployed, it works automatically (F32, Requirement 12.3).
  ///
  /// While offline, returns an empty list with no error (surfaces the pending
  /// state through the sync queue's pending operations rather than showing
  /// "Failed to load" — Requirement 10.2).
  Future<Either<Failure, List<SchoolOrder>>> getSchoolOrders({
    int page = 1,
    int limit = 20,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    try {
      final response = await apiClient.get(
        '/books/school-orders?page=$page&limit=$limit',
      );
      final items = (response.data!['orders'] as List)
          .map((item) => SchoolOrder.fromJson(item))
          .toList();
      return Right(items);
    } catch (e) {
      // On network failure, return empty list rather than "Failed to load"
      // (offline-first pattern — Req 10.2). Pending writes are tracked
      // separately via the sync queue.
      return const Right([]);
    }
  }

  Future<Either<Failure, bool>> fulfillSchoolOrder(
    String orderId,
    int setsToFulfill,
  ) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    final tenantId = (tenantResult as Right<Failure, String>).value;

    try {
      // Ensure sync queue is initialized.
      await initializeSyncQueue();

      // Generate a RID for this operation (idempotency key).
      final rid = generateRid(tenantId);

      // Enqueue the write via the Sync_Queue (Req 10.1, 10.2).
      // If online, the queue attempts immediate sync.
      // If offline, the operation stays pending and surfaces as 'pending'
      // state — never "Failed to load" (Req 10.2).
      final op = await syncQueue.enqueue(
        tenantId: tenantId,
        entityType: BookStoreEntityType.schoolOrder,
        operationType: BookStoreOperationType.fulfill,
        httpMethod: 'POST',
        endpointPath: '/books/school-orders/$orderId/fulfill',
        payload: {'sets': setsToFulfill, 'orderId': orderId},
        rid: rid,
      );

      // If immediately synced, return success.
      // If pending (offline), also return success — the write is queued
      // locally and will be flushed on connectivity restore.
      if (op.status == BookStoreSyncStatus.synced ||
          op.status == BookStoreSyncStatus.pending) {
        return const Right(true);
      }

      // If failed on first attempt, still return success to the UI
      // (the write is retained locally for retry — Req 10.7).
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Fetches consignments from the backend, scoped to the active tenant.
  ///
  /// Supports pagination via [page] (1-based) and [limit] (items per page).
  /// The query params are passed to the backend so when server-side pagination
  /// is deployed, it works automatically (F32, Requirement 12.3).
  ///
  /// While offline, returns an empty list with no error (surfaces the pending
  /// state through the sync queue's pending operations rather than showing
  /// "Failed to load" — Requirement 10.2).
  Future<Either<Failure, List<Consignment>>> getConsignments({
    int page = 1,
    int limit = 20,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    try {
      final response = await apiClient.get(
        '/books/consignments?page=$page&limit=$limit',
      );
      final items = (response.data!['consignments'] as List)
          .map((item) => Consignment.fromJson(item))
          .toList();
      return Right(items);
    } catch (e) {
      // On network failure, return empty list rather than "Failed to load"
      // (offline-first pattern — Req 10.2). Pending writes are tracked
      // separately via the sync queue.
      return const Right([]);
    }
  }

  Future<Either<Failure, bool>> processSettlement(
    String consignmentId,
    double amount,
  ) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    final tenantId = (tenantResult as Right<Failure, String>).value;

    try {
      // Ensure sync queue is initialized.
      await initializeSyncQueue();

      // Convert amount to integer Paise for local storage (Req 1.1, 10.6).
      final amountPaise = (amount * 100).round();

      // Generate a RID for this operation (idempotency key).
      final rid = generateRid(tenantId);

      // Enqueue the write via the Sync_Queue (Req 10.1, 10.2).
      final op = await syncQueue.enqueue(
        tenantId: tenantId,
        entityType: BookStoreEntityType.consignment,
        operationType: BookStoreOperationType.settle,
        httpMethod: 'POST',
        endpointPath: '/books/consignments/$consignmentId/settle',
        payload: {
          'amount': amount, // Server expects the original amount format
          'amountPaise': amountPaise, // Also stored locally in Paise
          'consignmentId': consignmentId,
        },
        rid: rid,
      );

      // The write is either synced immediately or queued for later (pending).
      // Both cases surface as success to the caller (Req 10.2).
      if (op.status == BookStoreSyncStatus.synced ||
          op.status == BookStoreSyncStatus.pending) {
        return const Right(true);
      }

      // Failed on first attempt — retained for retry (Req 10.7).
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LOYALTY POINTS — Task 13.2, Requirement 9.4–9.8
  // ════════════════════════════════════════════════════════════════════════════

  /// Retrieves the real loyalty points balance for a customer by phone number
  /// from the local Drift Customers table (which has `IntColumn loyaltyPoints`
  /// with default 0). Returns the integer points balance.
  ///
  /// This replaces the old `customer.totalPaid.toInt()` proxy (F17).
  Future<Either<Failure, int>> getCustomerLoyaltyPoints(String phone) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    try {
      final row = await (database.select(
        database.customers,
      )..where((t) => t.phone.equals(phone))).getSingleOrNull();
      if (row == null) {
        return Left(ServerFailure('Customer not found for phone: $phone'));
      }
      return Right(row.loyaltyPoints);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Accrues loyalty points for a customer after a successful sale.
  ///
  /// Accrual rule: 1 loyalty point per ₹100 spent (rounded down).
  /// Example: ₹350 sale → 3 points accrued.
  ///
  /// [customerId] — the customer's id in the Drift Customers table.
  /// [saleAmountPaise] — the bill grand total in integer Paise.
  ///
  /// Returns the new total loyalty points balance after accrual.
  Future<Either<Failure, int>> accruePoints({
    required String customerId,
    required int saleAmountPaise,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    if (saleAmountPaise <= 0) {
      return Left(ServerFailure('Sale amount must be positive for accrual.'));
    }

    try {
      // Accrual rule: 1 point per ₹100 (i.e. per 10000 Paise), rounded down.
      final pointsToAccrue = saleAmountPaise ~/ 10000;
      if (pointsToAccrue <= 0) {
        // Sale too small for any accrual — return current balance unchanged.
        final row = await (database.select(
          database.customers,
        )..where((t) => t.id.equals(customerId))).getSingleOrNull();
        return Right(row?.loyaltyPoints ?? 0);
      }

      // Fetch current balance
      final row = await (database.select(
        database.customers,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull();
      if (row == null) {
        return Left(ServerFailure('Customer not found for accrual.'));
      }

      final newBalance = row.loyaltyPoints + pointsToAccrue;

      await (database.update(
        database.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          loyaltyPoints: Value(newBalance),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return Right(newBalance);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Redeems loyalty points against a bill.
  ///
  /// Validation: [pointsToRedeem] must not exceed the customer's available
  /// balance. If it does, the redemption is REJECTED — nothing is applied,
  /// and a validation error is returned (Requirement 9.7).
  ///
  /// On success, the customer's loyaltyPoints balance is decreased by
  /// [pointsToRedeem]. The caller applies the discount to the bill total
  /// in integer Paise (1 point = ₹1 = 100 Paise discount).
  ///
  /// Returns the new balance after redemption.
  Future<Either<Failure, int>> redeemPoints({
    required String customerId,
    required int pointsToRedeem,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    if (pointsToRedeem <= 0) {
      return Left(ServerFailure('Points to redeem must be positive.'));
    }

    try {
      final row = await (database.select(
        database.customers,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull();
      if (row == null) {
        return Left(ServerFailure('Customer not found for redemption.'));
      }

      final available = row.loyaltyPoints;
      if (pointsToRedeem > available) {
        return Left(
          ServerFailure(
            'Redemption rejected: requested $pointsToRedeem points but only '
            '$available available. Nothing applied.',
          ),
        );
      }

      final newBalance = available - pointsToRedeem;

      await (database.update(
        database.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          loyaltyPoints: Value(newBalance),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return Right(newBalance);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Looks up a book by ISBN via the deployed `GET /book-store/isbn/{isbn}` endpoint.
  /// Returns the ISBN auto-fill result including book details and pricing (F18).
  Future<Either<Failure, BookIsbnResult>> lookupByIsbn(String isbn) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    try {
      final response = await apiClient.get('/book-store/isbn/$isbn');
      if (!response.isSuccess) {
        return Left(
          ServerFailure(
            response.error ?? 'ISBN lookup failed (${response.statusCode})',
          ),
        );
      }
      final data = response.data;
      if (data == null) {
        return Left(ServerFailure('ISBN lookup returned no data'));
      }
      return Right(BookIsbnResult.fromJson(data));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Retrieves up to 50 low-stock books via the deployed `GET /book-store/low-stock` endpoint.
  /// Used by the dashboard alerts widget for real low-stock counts (F19).
  Future<Either<Failure, List<LowStockBook>>> getLowStockBooks() async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    try {
      final response = await apiClient.get('/book-store/low-stock');
      if (!response.isSuccess) {
        return Left(
          ServerFailure(
            response.error ?? 'Low-stock query failed (${response.statusCode})',
          ),
        );
      }
      final data = response.data;
      if (data == null) {
        return Left(ServerFailure('Low-stock query returned no data'));
      }
      // Backend returns an array which ApiClient wraps as {'data': [...]}
      final rawList = data['data'] as List? ?? [];
      final items = rawList
          .map((item) => LowStockBook.fromJson(item as Map<String, dynamic>))
          .toList();
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Lists publisher returns via `GET /book-store/returns` scoped to the active Tenant_Id.
  /// Optionally filters by [status] (e.g. 'draft', 'sent', 'accepted').
  ///
  /// While offline, returns an empty list (not "Failed to load") — Req 10.2.
  /// Pending return writes are tracked via the sync queue and can be queried
  /// separately for UI display.
  /// Returns [Either<Failure, List<BookReturn>>] (F16, Requirement 9.3).
  Future<Either<Failure, List<BookReturn>>> listReturns({
    String? status,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}'
          : '';
      final response = await apiClient.get('/book-store/returns$queryString');
      if (!response.isSuccess) {
        // On failure, return empty list rather than error (offline-first).
        return const Right([]);
      }
      final data = response.data;
      if (data == null) {
        return const Right([]);
      }
      // Backend paginated response: { "data": [...], "meta": {...} }
      final rawList = data['data'] as List? ?? [];
      final items = rawList
          .map((item) => BookReturn.fromJson(item as Map<String, dynamic>))
          .toList();
      return Right(items);
    } catch (e) {
      // On network failure, return empty list rather than "Failed to load"
      // (Req 10.2). Pending writes are tracked via the sync queue.
      return const Right([]);
    }
  }

  /// Creates a publisher return via the Sync_Queue offline-first pattern.
  ///
  /// While offline, the return is queued locally with a pending state and
  /// surfaces as "pending" (not "Failed to load") — Requirement 10.2, 10.5.
  /// The publisher-return offline behavior is explicitly defined: queueing with
  /// RID-based idempotency, last-write-wins conflict handling on the server
  /// (same RID = same result), and reconciliation on connectivity restore
  /// consistent with school orders and consignments.
  ///
  /// The backend generates the `returnId` server-side. Item prices are sent as
  /// integer Paise (the `price` field in the schema accepts int).
  Future<Either<Failure, Map<String, dynamic>>> createReturn({
    required String vendorId,
    String? vendorName,
    required List<ReturnItem> items,
    String? notes,
    String? returnDate,
  }) async {
    final tenantResult = _resolveTenantId();
    if (tenantResult.isLeft()) {
      return Left((tenantResult as Left<Failure, String>).value);
    }
    final tenantId = (tenantResult as Right<Failure, String>).value;

    try {
      // Ensure sync queue is initialized.
      await initializeSyncQueue();

      // Generate a RID for this return (idempotency key — Req 1.4, 10.6).
      final rid = generateRid(tenantId);

      final body = <String, dynamic>{
        'vendorId': vendorId,
        if (vendorName != null && vendorName.isNotEmpty)
          'vendorName': vendorName,
        'items': items.map((item) => item.toJson()).toList(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (returnDate != null && returnDate.isNotEmpty)
          'returnDate': returnDate,
      };

      // Enqueue via Sync_Queue (Req 10.1, 10.2, 10.5).
      // Publisher returns follow the same offline path as school orders and
      // consignments: queue locally with pending state, flush idempotently
      // on connectivity restore via RID-based dedup.
      final op = await syncQueue.enqueue(
        tenantId: tenantId,
        entityType: BookStoreEntityType.publisherReturn,
        operationType: BookStoreOperationType.create,
        httpMethod: 'POST',
        endpointPath: '/book-store/returns',
        payload: body,
        rid: rid,
      );

      // Return the local operation data so the UI can show the pending state.
      final resultData = <String, dynamic>{
        'id': rid,
        'status': op.status == BookStoreSyncStatus.synced
            ? 'synced'
            : 'pending',
        'vendorId': vendorId,
        'vendorName': vendorName,
        'items': items.map((item) => item.toJson()).toList(),
        'createdAt': op.createdAt.toIso8601String(),
      };

      return Right(resultData);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
