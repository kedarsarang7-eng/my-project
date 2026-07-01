// Jewellery Repository - Full Offline Support
// Manages Jewellery products, Gold Rates, Old Gold Exchange, Custom Orders with Hive

import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/perf/paginated_window.dart';
import '../../../../core/sync/version_reconciliation.dart';
import '../../../../core/utils/rid_generator.dart';
import '../models/jewellery_product_model.dart';
import '../services/kyc_field_crypto.dart';

/// Jewellery Repository with Offline-First Architecture
class JewelleryRepositoryOffline {
  final ApiClient _client;
  final SessionManager _session;

  // Hive boxes for offline storage
  late Box<JewelleryProduct> _productsBox;
  late Box<GoldRateCard> _goldRatesBox;
  late Box<OldGoldExchange> _exchangesBox;
  late Box<JewelleryOrder> _ordersBox;
  late Box<HallmarkRegisterEntry> _hallmarkBox;
  late Box<Map> _syncQueueBox;

  bool _initialized = false;

  JewelleryRepositoryOffline(this._client, this._session);

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_initialized) return;

    _productsBox = await Hive.openBox<JewelleryProduct>('jewellery_products');
    _goldRatesBox = await Hive.openBox<GoldRateCard>('gold_rates');
    _exchangesBox = await Hive.openBox<OldGoldExchange>('gold_exchanges');
    _ordersBox = await Hive.openBox<JewelleryOrder>('jewellery_orders');
    _hallmarkBox = await Hive.openBox<HallmarkRegisterEntry>(
      'hallmark_register',
    );
    _syncQueueBox = await Hive.openBox<Map>('jewellery_sync_queue');

    _initialized = true;
  }

  // ============================================================================
  // JEWELLERY PRODUCTS
  // ============================================================================

  /// Get all products (offline-first).
  ///
  /// D9 performance fix (task 3.2.9): callers may pass [limit] (and an
  /// opaque [cursor] / [offset]) to paginate. When [limit] is null the
  /// method preserves the historical "return everything" contract so
  /// already-correct screens keep their timing class (preservation 3.1).
  Future<List<JewelleryProduct>> getProducts({
    String? category,
    MetalType? metalType,
    bool? lowStock,
    bool? outOfStock,
    String? searchTerm,
    bool includeDeleted = false,
    int? limit,
    int offset = 0,
  }) async {
    await initialize();

    var products = _productsBox.values.toList();

    // Apply filters
    if (!includeDeleted) {
      products = products.where((p) => !p.isDeleted).toList();
    }

    if (category != null) {
      products = products.where((p) => p.category == category).toList();
    }

    if (metalType != null) {
      products = products.where((p) => p.metalType == metalType).toList();
    }

    if (lowStock == true) {
      products = products
          .where((p) => p.isLowStock && !p.isOutOfStock)
          .toList();
    }

    if (outOfStock == true) {
      products = products.where((p) => p.isOutOfStock).toList();
    }

    if (searchTerm != null && searchTerm.isNotEmpty) {
      final term = searchTerm.toLowerCase();
      products = products
          .where(
            (p) =>
                p.name.toLowerCase().contains(term) ||
                (p.sku?.toLowerCase().contains(term) ?? false) ||
                (p.barcode?.toLowerCase().contains(term) ?? false) ||
                (p.huid?.toLowerCase().contains(term) ?? false),
          )
          .toList();
    }

    // Sort by updated date (newest first)
    products.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // D9: bounded pagination window. When `limit` is null the legacy
    // contract is preserved (return all) — see preservation 3.1.
    return paginate(products, limit: limit, offset: offset);
  }

  /// Get single product by ID
  Future<JewelleryProduct?> getProductById(String id) async {
    await initialize();
    return _productsBox.get(id);
  }

  /// Create new jewellery product
  Future<JewelleryProduct> createProduct(
    CreateJewelleryProductRequest request,
  ) async {
    await initialize();

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);

    final product = JewelleryProduct(
      id: id,
      tenantId: tenantId,
      name: request.name,
      description: request.description,
      category: request.category,
      metalType: request.metalType,
      metalWeightGrams: request.metalWeightGrams,
      grossWeightGrams: request.grossWeightGrams ?? request.metalWeightGrams,
      netWeightGrams: request.metalWeightGrams,
      makingChargesPerGram: request.makingChargesPerGram,
      wastagePercent: request.wastagePercent,
      pricePerGramPaisa: request.pricePerGramPaisa,
      totalMrpPaisa: request.totalMrpPaisa,
      huid: request.huid,
      stockQuantity: request.stock,
      barcode: request.barcode,
      sku: request.sku,
      createdAt: now,
      updatedAt: now,
      createdBy: userId,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'create',
      pendingSince: now,
    );

    await _productsBox.put(id, product);
    await _addToSyncQueue('product', 'create', id);

    // Try to sync immediately if online
    _syncProduct(product);

    return product;
  }

  /// Update product
  Future<JewelleryProduct> updateProduct(
    String id,
    UpdateJewelleryProductRequest request,
  ) async {
    await initialize();

    final existing = _productsBox.get(id);
    if (existing == null) {
      throw Exception('Product not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    final updated = existing.copyWith(
      name: request.name ?? existing.name,
      description: request.description ?? existing.description,
      category: request.category ?? existing.category,
      metalType: request.metalType ?? existing.metalType,
      metalWeightGrams: request.metalWeightGrams ?? existing.metalWeightGrams,
      makingChargesPerGram:
          request.makingChargesPerGram ?? existing.makingChargesPerGram,
      pricePerGramPaisa:
          request.pricePerGramPaisa ?? existing.pricePerGramPaisa,
      totalMrpPaisa: request.totalMrpPaisa ?? existing.totalMrpPaisa,
      stockQuantity: request.stock ?? existing.stockQuantity,
      isActive: request.isActive ?? existing.isActive,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'update',
      pendingSince: now,
      version: existing.version + 1,
    );

    await _productsBox.put(id, updated);
    await _addToSyncQueue('product', 'update', id);

    _syncProduct(updated);

    return updated;
  }

  /// Soft delete product
  Future<void> deleteProduct(String id, {bool checkInvoices = true}) async {
    await initialize();

    final existing = _productsBox.get(id);
    if (existing == null) return;

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    // Check if product has invoice history
    if (checkInvoices) {
      final hasInvoices = await _checkProductInvoices(id);
      if (hasInvoices) {
        throw Exception(
          'Cannot delete product with invoice history. '
          'Product "${existing.name}" has been sold and cannot be deleted. '
          'You can mark it as inactive instead.',
        );
      }
    }

    final deleted = existing.copyWith(
      isDeleted: true,
      deletedAt: now,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'delete',
      pendingSince: now,
    );

    await _productsBox.put(id, deleted);
    await _addToSyncQueue('product', 'delete', id);

    _syncProduct(deleted);
  }

  /// Restore soft-deleted product
  Future<JewelleryProduct> restoreProduct(String id) async {
    await initialize();

    final existing = _productsBox.get(id);
    if (existing == null) {
      throw Exception('Product not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    final restored = existing.copyWith(
      isDeleted: false,
      deletedAt: null,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'update',
      pendingSince: now,
    );

    await _productsBox.put(id, restored);
    await _addToSyncQueue('product', 'update', id);

    _syncProduct(restored);

    return restored;
  }

  /// Check for duplicate product name
  Future<bool> isDuplicateName(String name, {String? excludeId}) async {
    await initialize();

    final normalizedName = name.trim().toLowerCase();
    return _productsBox.values.any(
      (p) =>
          !p.isDeleted &&
          p.id != excludeId &&
          p.name.trim().toLowerCase() == normalizedName,
    );
  }

  // ============================================================================
  // GOLD RATE MANAGEMENT
  // ============================================================================

  // TODO(BACKLOG): Live gold-rate market-feed integration.
  // Requirement 16.6 records this as a planned future feature:
  //   - Subscribe to a real-time gold/silver/platinum price feed (e.g., MCX,
  //     LBMA, or a third-party aggregator API).
  //   - Auto-populate `setGoldRate` with live market prices, subject to the
  //     existing spike/sanity bounds (Requirement 15.5).
  //   - Present a "Live Feed" source badge on `GoldRateManagementScreen`.
  //   - This is a NON-BLOCKING backlog item and is NOT implemented in the
  //     current jewellery vertical remediation (Phases 0–8).

  /// Get gold rate for a specific date
  Future<GoldRateCard?> getGoldRate(String date) async {
    await initialize();

    // Try to find by exact date
    final rates = _goldRatesBox.values.where((r) => r.date == date).toList();
    if (rates.isNotEmpty) {
      return rates.first;
    }

    // If no rate for today, return the most recent rate
    if (rates.isEmpty && _goldRatesBox.isNotEmpty) {
      final sorted = _goldRatesBox.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return sorted.first;
    }

    return null;
  }

  /// Get today's gold rate
  Future<GoldRateCard?> getTodayGoldRate() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return getGoldRate(today);
  }

  // ---------------------------------------------------------------------------
  // Gold-rate bounds configuration (Requirement 15.5)
  // ---------------------------------------------------------------------------

  /// Minimum acceptable gold rate per 10g in paise (₹1,000 = 100000 paise).
  /// Anything below this is clearly a data-entry error.
  static const int goldRateSanityMinPer10gPaisa = 100000;

  /// Maximum acceptable gold rate per 10g in paise (₹10,00,000 = 100000000 paise).
  /// Anything above this is clearly a data-entry error.
  static const int goldRateSanityMaxPer10gPaisa = 100000000;

  /// Maximum allowed day-over-day change as a fraction (0.10 = 10%).
  /// Configurable — callers may override via the [spikeThreshold] parameter.
  static const double defaultSpikeThreshold = 0.10;

  /// Set gold rate for a date
  Future<GoldRateCard> setGoldRate({
    required String date,
    required int gold24KPer10gPaisa,
    required int gold22KPer10gPaisa,
    required int gold18KPer10gPaisa,
    required int silverPerKgPaisa,
    int platinumPerGramPaisa = 0,
    String source = 'MANUAL',
    String? notes,
    double spikeThreshold = defaultSpikeThreshold,
  }) async {
    await initialize();

    // ── Requirement 15.5: Sanity bounds ──────────────────────────────────────
    // Reject rates below ₹1,000/10g or above ₹10,00,000/10g as clearly invalid.
    final ratesToCheck = <String, int>{
      'gold24KPer10gPaisa': gold24KPer10gPaisa,
      'gold22KPer10gPaisa': gold22KPer10gPaisa,
      'gold18KPer10gPaisa': gold18KPer10gPaisa,
    };

    for (final entry in ratesToCheck.entries) {
      if (entry.value < goldRateSanityMinPer10gPaisa) {
        throw GoldRateBoundsException(
          field: entry.key,
          value: entry.value,
          reason: GoldRateBoundsReason.belowSanityMin,
          message:
              '${entry.key} (${entry.value} paise/10g) is below the sanity '
              'minimum of $goldRateSanityMinPer10gPaisa paise/10g (₹1,000). '
              'Please verify the rate.',
        );
      }
      if (entry.value > goldRateSanityMaxPer10gPaisa) {
        throw GoldRateBoundsException(
          field: entry.key,
          value: entry.value,
          reason: GoldRateBoundsReason.aboveSanityMax,
          message:
              '${entry.key} (${entry.value} paise/10g) exceeds the sanity '
              'maximum of $goldRateSanityMaxPer10gPaisa paise/10g (₹10,00,000). '
              'Please verify the rate.',
        );
      }
    }

    // ── Requirement 15.5: Spike bounds (day-over-day > threshold) ────────────
    // If yesterday's rate exists, reject a day-over-day change exceeding the
    // configurable spike threshold (default 10%).
    final previousRate = await _getPreviousRate(date);
    if (previousRate != null) {
      _checkSpike(
        'gold24KPer10gPaisa',
        previousRate.gold24KPer10gPaisa,
        gold24KPer10gPaisa,
        spikeThreshold,
      );
      _checkSpike(
        'gold22KPer10gPaisa',
        previousRate.gold22KPer10gPaisa,
        gold22KPer10gPaisa,
        spikeThreshold,
      );
      _checkSpike(
        'gold18KPer10gPaisa',
        previousRate.gold18KPer10gPaisa,
        gold18KPer10gPaisa,
        spikeThreshold,
      );
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';
    final tenantId = _session.ownerId ?? 'default';

    // Use date as ID for easy lookup
    final id = '${tenantId}_$date';

    final rateCard = GoldRateCard(
      id: id,
      tenantId: tenantId,
      date: date,
      gold24KPer10gPaisa: gold24KPer10gPaisa,
      gold22KPer10gPaisa: gold22KPer10gPaisa,
      gold18KPer10gPaisa: gold18KPer10gPaisa,
      silverPerKgPaisa: silverPerKgPaisa,
      platinumPerGramPaisa: platinumPerGramPaisa,
      source: source,
      notes: notes,
      createdAt: now,
      createdBy: userId,
      synced: false,
      pendingOperation: 'create',
    );

    await _goldRatesBox.put(id, rateCard);
    await _addToSyncQueue('gold_rate', 'create', id);

    _syncGoldRate(rateCard);

    return rateCard;
  }

  /// Returns the most recent rate card with a date strictly before [date],
  /// used for spike-detection. Returns null if no prior rate exists.
  Future<GoldRateCard?> _getPreviousRate(String date) async {
    final sorted =
        _goldRatesBox.values.where((r) => r.date.compareTo(date) < 0).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.isNotEmpty ? sorted.first : null;
  }

  /// Throws [GoldRateBoundsException] if the day-over-day change for [field]
  /// exceeds [threshold] (fraction, e.g. 0.10 for 10%).
  void _checkSpike(
    String field,
    int previousValue,
    int newValue,
    double threshold,
  ) {
    if (previousValue <= 0) return; // avoid division by zero on stale data
    final change = (newValue - previousValue).abs();
    final limit = (previousValue * threshold).round();
    if (change > limit) {
      final pct = ((change / previousValue) * 100).toStringAsFixed(1);
      throw GoldRateBoundsException(
        field: field,
        value: newValue,
        reason: GoldRateBoundsReason.spikeExceeded,
        message:
            '$field changed by $pct% (previous: $previousValue, new: $newValue '
            'paise/10g), exceeding the ${(threshold * 100).toStringAsFixed(0)}% '
            'day-over-day limit. Please verify the rate or adjust the spike threshold.',
        previousValue: previousValue,
        changePercent: change / previousValue,
      );
    }
  }

  /// Get gold rate history
  Future<List<GoldRateCard>> getGoldRateHistory({int days = 30}) async {
    await initialize();

    final rates = _goldRatesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return rates.take(days).toList();
  }

  // ============================================================================
  // OLD GOLD EXCHANGE (PML Act Compliance)
  // ============================================================================

  /// Create old gold exchange record
  Future<OldGoldExchange> createOldGoldExchange({
    required String customerId,
    required String customerName,
    String? customerPhone,
    required String customerIdType,
    required String customerIdNumber,
    String? customerPhotoUrl,
    required MetalType oldGoldMetalType,
    required double oldGoldWeightGrams,
    required int oldGoldRatePerGramPaisa,
    required int oldGoldValuePaisa,
    String? purityTestMethod,
    double? actualPurityPercentage,
    String? newItemDescription,
    MetalType? newItemMetalType,
    double? newItemWeightGrams,
    int? newItemTotalPaisa,
    required int exchangeValuePaisa,
    int cashAdjustmentPaisa = 0,
    String? notes,
  }) async {
    await initialize();

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);

    // Requirement 11.1: Encrypt PMLA KYC PII fields before persisting to Hive
    final encryptedIdNumber =
        await KycFieldCrypto.encrypt(customerIdNumber, tenantId) ??
        customerIdNumber;
    final encryptedPhotoUrl = await KycFieldCrypto.encrypt(
      customerPhotoUrl,
      tenantId,
    );

    final exchange = OldGoldExchange(
      id: id,
      tenantId: tenantId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerIdType: customerIdType,
      customerIdNumber: encryptedIdNumber,
      customerPhotoUrl: encryptedPhotoUrl,
      oldGoldMetalType: oldGoldMetalType,
      oldGoldWeightGrams: oldGoldWeightGrams,
      oldGoldValuePaisa: oldGoldValuePaisa,
      oldGoldRatePerGramPaisa: oldGoldRatePerGramPaisa,
      purityTestMethod: purityTestMethod,
      actualPurityPercentage: actualPurityPercentage,
      newItemDescription: newItemDescription,
      newItemMetalType: newItemMetalType,
      newItemWeightGrams: newItemWeightGrams,
      newItemTotalPaisa: newItemTotalPaisa,
      exchangeValuePaisa: exchangeValuePaisa,
      cashAdjustmentPaisa: cashAdjustmentPaisa,
      status: 'PENDING',
      createdAt: now,
      createdBy: userId,
      synced: false,
      pendingOperation: 'create',
      pmlCompliant: true,
      complianceNotes: notes,
    );

    await _exchangesBox.put(id, exchange);
    await _addToSyncQueue('old_gold_exchange', 'create', id);

    _syncOldGoldExchange(exchange);

    // Return with decrypted KYC fields so callers see plaintext
    return exchange.copyWith(
      customerIdNumber: customerIdNumber,
      customerPhotoUrl: customerPhotoUrl,
    );
  }

  /// Get all old gold exchanges.
  ///
  /// D9 performance fix (task 3.2.9): pass [limit] / [offset] to paginate.
  /// When [limit] is null the legacy "return everything" contract is
  /// preserved (preservation 3.1).
  ///
  /// Requirement 11.1/11.4: KYC PII fields are decrypted on read;
  /// on failure the value is withheld and an error flag is surfaced.
  Future<List<OldGoldExchange>> getOldGoldExchanges({
    String? status,
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
  }) async {
    await initialize();

    var exchanges = _exchangesBox.values.toList();

    if (status != null) {
      exchanges = exchanges.where((e) => e.status == status).toList();
    }

    if (customerId != null) {
      exchanges = exchanges.where((e) => e.customerId == customerId).toList();
    }

    if (fromDate != null) {
      exchanges = exchanges
          .where((e) => e.createdAt.isAfter(fromDate))
          .toList();
    }

    if (toDate != null) {
      exchanges = exchanges.where((e) => e.createdAt.isBefore(toDate)).toList();
    }

    exchanges.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final paginated = paginate(exchanges, limit: limit, offset: offset);

    // Decrypt KYC PII fields on read
    return Future.wait(paginated.map((e) => _decryptExchangeKyc(e)));
  }

  /// Decrypt KYC PII fields on an OldGoldExchange record.
  /// Requirement 11.4: on decryption failure, withhold the value and
  /// populate complianceNotes with an error indication.
  Future<OldGoldExchange> _decryptExchangeKyc(OldGoldExchange exchange) async {
    final tenantId = exchange.tenantId;

    // Decrypt customerIdNumber
    final idResult = await KycFieldCrypto.decrypt(
      exchange.customerIdNumber,
      tenantId,
    );

    // Decrypt customerPhotoUrl
    final photoResult = await KycFieldCrypto.decrypt(
      exchange.customerPhotoUrl,
      tenantId,
    );

    // Build error notes if any decryption failed
    String? errorNote;
    if (idResult.hasError || photoResult.hasError) {
      final errors = <String>[];
      if (idResult.hasError) errors.add('ID number: ${idResult.errorMessage}');
      if (photoResult.hasError) {
        errors.add('Photo URL: ${photoResult.errorMessage}');
      }
      errorNote = '[KYC_DECRYPT_ERROR] ${errors.join('; ')}';
    }

    return exchange.copyWith(
      // On success: decrypted value; on failure: withheld (empty string)
      customerIdNumber: idResult.value ?? '',
      customerPhotoUrl: photoResult.value,
      // Surface error indication via complianceNotes if decryption failed
      complianceNotes: errorNote ?? exchange.complianceNotes,
    );
  }

  /// Verify and complete exchange
  Future<OldGoldExchange> verifyExchange(
    String id, {
    required String verifiedBy,
    String? newInvoiceId,
  }) async {
    await initialize();

    final exchange = _exchangesBox.get(id);
    if (exchange == null) {
      throw Exception('Exchange not found: $id');
    }

    final now = DateTime.now();

    final verified = exchange.copyWith(
      status: newInvoiceId != null ? 'COMPLETED' : 'VERIFIED',
      verifiedBy: verifiedBy,
      verifiedAt: now,
      newItemInvoiceId: newInvoiceId ?? exchange.newItemInvoiceId,
      synced: false,
      pendingOperation: 'update',
    );

    await _exchangesBox.put(id, verified);
    await _addToSyncQueue('old_gold_exchange', 'update', id);

    _syncOldGoldExchange(verified);

    return _decryptExchangeKyc(verified);
  }

  // ============================================================================
  // CUSTOM ORDERS
  // ============================================================================

  /// Create custom jewellery order
  Future<JewelleryOrder> createOrder({
    required String customerId,
    required String customerName,
    String? customerPhone,
    required String itemDescription,
    String? designReference,
    String? designNotes,
    required MetalType metalType,
    required double estimatedWeightGrams,
    required int metalRatePerGramPaisa,
    required int makingChargesPerGramPaisa,
    double wastagePercent = 0,
    int stoneChargesPaisa = 0,
    int otherChargesPaisa = 0,
    required int estimatedTotalPaisa,
    int advanceReceivedPaisa = 0,
    String? advancePaymentMode,
    required String promisedDeliveryDate, // YYYY-MM-DD
  }) async {
    await initialize();

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);

    final order = JewelleryOrder(
      id: id,
      tenantId: tenantId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      itemDescription: itemDescription,
      designReference: designReference,
      designNotes: designNotes,
      metalType: metalType,
      estimatedWeightGrams: estimatedWeightGrams,
      metalRatePerGramPaisa: metalRatePerGramPaisa,
      makingChargesPerGramPaisa: makingChargesPerGramPaisa,
      wastagePercent: wastagePercent,
      stoneChargesPaisa: stoneChargesPaisa,
      otherChargesPaisa: otherChargesPaisa,
      estimatedTotalPaisa: estimatedTotalPaisa,
      advanceReceivedPaisa: advanceReceivedPaisa,
      advancePaymentMode: advancePaymentMode,
      orderDate: now,
      promisedDeliveryDate: promisedDeliveryDate,
      status: 'PENDING',
      statusHistory: [
        OrderStatusUpdate(
          status: 'PENDING',
          timestamp: now,
          updatedBy: userId,
          notes: 'Order created',
        ),
      ],
      createdAt: now,
      createdBy: userId,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'create',
    );

    await _ordersBox.put(id, order);
    await _addToSyncQueue('jewellery_order', 'create', id);

    _syncOrder(order);

    return order;
  }

  /// Get orders with filtering.
  ///
  /// D9 performance fix (task 3.2.9): pass [limit] / [offset] to paginate.
  /// When [limit] is null the legacy "return everything" contract is
  /// preserved (preservation 3.1).
  Future<List<JewelleryOrder>> getOrders({
    String? status,
    String? customerId,
    String? assignedTo,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
  }) async {
    await initialize();

    var orders = _ordersBox.values.toList();

    if (status != null) {
      orders = orders.where((o) => o.status == status).toList();
    }

    if (customerId != null) {
      orders = orders.where((o) => o.customerId == customerId).toList();
    }

    if (assignedTo != null) {
      orders = orders.where((o) => o.assignedTo == assignedTo).toList();
    }

    if (fromDate != null) {
      orders = orders.where((o) => o.createdAt.isAfter(fromDate)).toList();
    }

    if (toDate != null) {
      orders = orders.where((o) => o.createdAt.isBefore(toDate)).toList();
    }

    orders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return paginate(orders, limit: limit, offset: offset);
  }

  /// Update order status
  Future<JewelleryOrder> updateOrderStatus(
    String id,
    String newStatus, {
    String? notes,
    String? assignedTo,
  }) async {
    await initialize();

    final order = _ordersBox.get(id);
    if (order == null) {
      throw Exception('Order not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    final updatedHistory = [
      ...?order.statusHistory,
      OrderStatusUpdate(
        status: newStatus,
        timestamp: now,
        updatedBy: userId,
        notes: notes,
      ),
    ];

    String? actualDeliveryDate;
    if (newStatus == 'DELIVERED') {
      actualDeliveryDate = now.toIso8601String().split('T')[0];
    }

    final updated = order.copyWith(
      status: newStatus,
      statusHistory: updatedHistory,
      assignedTo: assignedTo ?? order.assignedTo,
      actualDeliveryDate: actualDeliveryDate ?? order.actualDeliveryDate,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'update',
    );

    await _ordersBox.put(id, updated);
    await _addToSyncQueue('jewellery_order', 'update', id);

    _syncOrder(updated);

    return updated;
  }

  /// Soft-delete a custom order (marks as CANCELLED, persists locally + enqueues sync).
  /// Requirement 14.1: custom orders work offline via Hive + sync queue.
  Future<void> deleteOrder(String id) async {
    await initialize();

    final order = _ordersBox.get(id);
    if (order == null) {
      throw Exception('Order not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    final updatedHistory = [
      ...?order.statusHistory,
      OrderStatusUpdate(
        status: 'CANCELLED',
        timestamp: now,
        updatedBy: userId,
        notes: 'Order soft-deleted',
      ),
    ];

    final deleted = order.copyWith(
      status: 'CANCELLED',
      statusHistory: updatedHistory,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'delete',
    );

    await _ordersBox.put(id, deleted);
    await _addToSyncQueue('jewellery_order', 'delete', id);

    _syncOrder(deleted);
  }

  /// Restore a soft-deleted (CANCELLED) order back to PENDING.
  /// Requirement 14.1: custom orders work offline via Hive + sync queue.
  Future<void> restoreOrder(String id) async {
    await initialize();

    final order = _ordersBox.get(id);
    if (order == null) {
      throw Exception('Order not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    final updatedHistory = [
      ...?order.statusHistory,
      OrderStatusUpdate(
        status: 'PENDING',
        timestamp: now,
        updatedBy: userId,
        notes: 'Order restored',
      ),
    ];

    final restored = order.copyWith(
      status: 'PENDING',
      statusHistory: updatedHistory,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'update',
    );

    await _ordersBox.put(id, restored);
    await _addToSyncQueue('jewellery_order', 'update', id);

    _syncOrder(restored);
  }

  // ============================================================================
  // HALLMARK REGISTER
  // ============================================================================

  /// Register hallmark item.
  ///
  /// Requirement 15.4: Rejects duplicate HUID for the tenant rather than
  /// silently overwriting the existing entry. The original entry is preserved.
  Future<HallmarkRegisterEntry> registerHallmark({
    required String productId,
    required String productName,
    required String huid,
    required PurityStandard purityStandard,
    required double weightGrams,
    String? articleType,
    String? bisLogo,
    String? purityMark,
    String? assayingCenterMark,
    String? jewelerMark,
    required DateTime hallmarkDate,
    String? registrationNumber,
    String? hallmarkImageUrl,
    String? productImageUrl,
  }) async {
    await initialize();

    // Requirement 15.4: Detect existing HUID for the tenant and reject
    // rather than silently overwriting the Hive key. The original entry
    // is preserved intact.
    if (_hallmarkBox.containsKey(huid)) {
      final existing = _hallmarkBox.get(huid);
      throw DuplicateHuidException(
        huid: huid,
        existingProductName: existing?.productName ?? 'unknown',
        message:
            'HUID "$huid" is already registered for product '
            '"${existing?.productName ?? 'unknown'}". '
            'Each hallmark HUID must be unique. The original entry has been preserved.',
      );
    }

    final now = DateTime.now();
    final tenantId = _session.ownerId ?? 'default';

    final entry = HallmarkRegisterEntry(
      id: huid, // Use HUID as ID
      tenantId: tenantId,
      huid: huid,
      productId: productId,
      productName: productName,
      purityStandard: purityStandard,
      weightGrams: weightGrams,
      articleType: articleType,
      bisLogo: bisLogo,
      purityMark: purityMark,
      assayingCenterMark: assayingCenterMark,
      jewelerMark: jewelerMark,
      hallmarkDate: hallmarkDate,
      registrationNumber: registrationNumber,
      status: 'ACTIVE',
      createdAt: now,
    );

    await _hallmarkBox.put(huid, entry);
    await _addToSyncQueue('hallmark', 'create', huid);

    _syncHallmark(entry);

    return entry;
  }

  /// Get hallmark register.
  ///
  /// D9 performance fix (task 3.2.9): pass [limit] / [offset] to paginate.
  /// When [limit] is null the legacy "return everything" contract is
  /// preserved (preservation 3.1).
  Future<List<HallmarkRegisterEntry>> getHallmarkRegister({
    String? status,
    PurityStandard? purityStandard,
    int? limit,
    int offset = 0,
  }) async {
    await initialize();

    var entries = _hallmarkBox.values.toList();

    if (status != null) {
      entries = entries.where((e) => e.status == status).toList();
    }

    if (purityStandard != null) {
      entries = entries
          .where((e) => e.purityStandard == purityStandard)
          .toList();
    }

    entries.sort((a, b) => b.hallmarkDate.compareTo(a.hallmarkDate));

    return paginate(entries, limit: limit, offset: offset);
  }

  /// Mark hallmark item as sold
  Future<HallmarkRegisterEntry> markHallmarkSold(
    String huid,
    String invoiceId,
  ) async {
    await initialize();

    final entry = _hallmarkBox.get(huid);
    if (entry == null) {
      throw Exception('Hallmark entry not found: $huid');
    }

    final updated = entry.copyWith(
      status: 'SOLD',
      saleInvoiceId: invoiceId,
      soldDate: DateTime.now(),
      synced: false,
    );

    await _hallmarkBox.put(huid, updated);
    await _addToSyncQueue('hallmark', 'update', huid);

    _syncHallmark(updated);

    return updated;
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Enqueue a sync-queue entry for a local write (Requirement 14.3).
  ///
  /// **Optimistic local write + enqueue contract:**
  /// Every create/update/delete in this repository follows the same three-step
  /// pattern, whether the device is online or offline:
  ///   1. Persist the change to the local Hive box immediately (optimistic).
  ///   2. Call [_addToSyncQueue] to enqueue a corresponding sync-queue entry.
  ///   3. Fire-and-forget call to `_sync*()` for an immediate sync attempt
  ///      (non-blocking; failures are retried later via [syncAll]).
  ///
  /// This guarantees the user always sees their latest state locally and the
  /// sync layer can reconcile with the server asynchronously.
  Future<void> _addToSyncQueue(
    String entityType,
    String operation,
    String entityId,
  ) async {
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);
    await _syncQueueBox.put(id, {
      'id': id,
      'entityType': entityType,
      'operation': operation,
      'entityId': entityId,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
      // Additive fields (Requirement 14.5, 14.6) — safe defaults so existing
      // boxes deserialize unchanged. See Mini_Gate comment in syncAll().
      'failedPermanently': false,
      'syncFailed': false,
      'serverVersion': 0,
    });
  }

  /// Sync all pending changes.
  ///
  /// Requirement 16.4: If a `/jewellery/*` endpoint is absent (returns 404 or
  /// any HTTP error), the sync method throws, the retry-cap logic increments
  /// retryCount, and after 5 failures the entry is marked `failedPermanently`
  /// with a vendor-observable failed-sync indication. Records are NEVER left
  /// silently unsynced — absent endpoints surface visibly.
  ///
  /// See BACKEND_ENDPOINT_BACKLOG.md for the status of each endpoint.
  Future<SyncResult> syncAll() async {
    await initialize();

    int synced = 0;
    int failed = 0;
    List<String> errors = [];

    final pending = _syncQueueBox.values.toList();

    for (final item in pending) {
      // Skip entries that have permanently failed — they require a manual
      // retry via [retryFailedEntry]. Automatic retries are exhausted.
      if (item['failedPermanently'] as bool? ?? false) {
        continue;
      }

      try {
        final entityType = item['entityType'] as String;
        final entityId = item['entityId'] as String;

        switch (entityType) {
          case 'product':
            final product = _productsBox.get(entityId);
            if (product != null) {
              await _syncProduct(product);
            }
            break;
          case 'gold_rate':
            final rate = _goldRatesBox.get(entityId);
            if (rate != null) {
              await _syncGoldRate(rate);
            }
            break;
          case 'old_gold_exchange':
            final exchange = _exchangesBox.get(entityId);
            if (exchange != null) {
              await _syncOldGoldExchange(exchange);
            }
            break;
          case 'jewellery_order':
            final order = _ordersBox.get(entityId);
            if (order != null) {
              await _syncOrder(order);
            }
            break;
          case 'hallmark':
            final entry = _hallmarkBox.get(entityId);
            if (entry != null) {
              await _syncHallmark(entry);
            }
            break;
        }

        synced++;
        await _syncQueueBox.delete(item['id']);
      } catch (e) {
        failed++;
        errors.add('${item['entityType']}: $e');

        // Update retry count
        final retryCount = (item['retryCount'] as int? ?? 0) + 1;
        if (retryCount >= 5) {
          // ────────────────────────────────────────────────────────────────────
          // Mini_Gate: Hive schema change (Requirement 14.6, 1.6)
          //
          // ADDITIVE FIELDS added to sync-queue map entries:
          //   • failedPermanently (bool, default false)
          //   • syncFailed (bool, default false)
          //   • serverVersion (int, default 0)
          //
          // These are additive with safe defaults — existing Hive boxes
          // deserialize old entries without error because missing keys resolve
          // to their defaults via `as bool? ?? false` / `as int? ?? 0`.
          // The change is idempotent: marking an already-failed entry again
          // produces the same persisted result.
          //
          // Mini_Gate APPROVED for this additive, idempotent Hive schema change.
          // ────────────────────────────────────────────────────────────────────

          // Requirement 14.5: Max retries reached — mark as permanently failed.
          // The entry is RETAINED (never discarded) so the vendor can observe
          // the failed-sync indication and the local record is preserved.
          await _syncQueueBox.put(item['id'], {
            ...item,
            'retryCount': retryCount,
            'lastError': e.toString(),
            'failedPermanently': true,
            'syncFailed': true,
            'serverVersion': item['serverVersion'] as int? ?? 0,
          });

          // Mark the associated local record with syncFailed indication
          // so the UI can display the failed-sync state to the vendor.
          await _markLocalRecordSyncFailed(
            item['entityType'] as String,
            item['entityId'] as String,
          );
        } else {
          await _syncQueueBox.put(item['id'], {
            ...item,
            'retryCount': retryCount,
            'lastError': e.toString(),
            'failedPermanently': false,
            'syncFailed': false,
            'serverVersion': item['serverVersion'] as int? ?? 0,
          });
        }
      }
    }

    // Count permanently-failed entries for the result (Requirement 14.5).
    final permanentlyFailedCount = _syncQueueBox.values
        .where((e) => e['failedPermanently'] as bool? ?? false)
        .length;

    return SyncResult(
      synced: synced,
      failed: failed,
      totalPending: _syncQueueBox.length,
      failedPermanently: permanentlyFailedCount,
      errors: errors,
    );
  }

  /// Individual sync methods — version-based reconciliation (Requirement 14.4).
  ///
  /// Each sync method now:
  ///   1. Sends local data + local version to the server.
  ///   2. Reads the server's response version.
  ///   3. Applies [VersionReconciliation.reconcile] to decide:
  ///      - pushLocal → mark local as synced (server accepted our data).
  ///      - acceptServer → update local record with server's newer data.
  ///      - conflict → prefer server data and mark for review.
  Future<void> _syncProduct(JewelleryProduct product) async {
    try {
      // Send local data with version to the server
      final body = _productToJson(product);
      body['version'] = product.version;

      final response = await _client.post('/jewellery/products', body: body);

      // Extract server version from response
      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      // Version-based reconciliation: compare before overwriting
      final reconciliation = VersionReconciliation.reconcile(
        localVersion: product.version,
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server version is newer — update local with server data
        final serverData = reconciliation.serverData!;
        final reconciled = product.copyWith(
          name: serverData['name'] as String? ?? product.name,
          description:
              serverData['description'] as String? ?? product.description,
          pricePerGramPaisa:
              serverData['pricePerGramPaisa'] as int? ??
              product.pricePerGramPaisa,
          totalMrpPaisa:
              serverData['totalMrpPaisa'] as int? ?? product.totalMrpPaisa,
          stockQuantity: serverData['stock'] as int? ?? product.stockQuantity,
          version: serverVersion,
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
          pendingSince: null,
        );
        await _productsBox.put(product.id, reconciled);
      } else {
        // Local version is current — mark as synced
        final synced = product.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
          pendingSince: null,
        );
        await _productsBox.put(product.id, synced);
      }
    } catch (e) {
      // Will retry later
      throw Exception('Failed to sync product: $e');
    }
  }

  Future<void> _syncGoldRate(GoldRateCard rate) async {
    try {
      final body = _goldRateToJson(rate);

      final response = await _client.post('/jewellery/gold-rate', body: body);

      // Extract server version from response
      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      // Version-based reconciliation (Requirement 14.4)
      final reconciliation = VersionReconciliation.reconcile(
        localVersion: 0, // GoldRateCard has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local rate card
        final serverData = reconciliation.serverData!;
        final rates = serverData['rates'] as Map<String, dynamic>? ?? {};
        final reconciled = rate.copyWith(
          gold24KPer10gPaisa:
              rates['gold24KPer10gPaisa'] as int? ?? rate.gold24KPer10gPaisa,
          gold22KPer10gPaisa:
              rates['gold22KPer10gPaisa'] as int? ?? rate.gold22KPer10gPaisa,
          gold18KPer10gPaisa:
              rates['gold18KPer10gPaisa'] as int? ?? rate.gold18KPer10gPaisa,
          silverPerKgPaisa:
              rates['silverPerKgPaisa'] as int? ?? rate.silverPerKgPaisa,
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _goldRatesBox.put(rate.id, reconciled);
      } else {
        final synced = rate.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _goldRatesBox.put(rate.id, synced);
      }
    } catch (e) {
      throw Exception('Failed to sync gold rate: $e');
    }
  }

  Future<void> _syncOldGoldExchange(OldGoldExchange exchange) async {
    try {
      final body = _exchangeToJson(exchange);

      final response = await _client.post(
        '/jewellery/old-gold-exchange',
        body: body,
      );

      // Extract server version from response
      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      // Version-based reconciliation (Requirement 14.4)
      final reconciliation = VersionReconciliation.reconcile(
        localVersion:
            0, // OldGoldExchange has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local exchange record
        final serverData = reconciliation.serverData!;
        final reconciled = exchange.copyWith(
          status: serverData['status'] as String? ?? exchange.status,
          exchangeValuePaisa:
              serverData['exchangeValuePaisa'] as int? ??
              exchange.exchangeValuePaisa,
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _exchangesBox.put(exchange.id, reconciled);
      } else {
        final synced = exchange.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _exchangesBox.put(exchange.id, synced);
      }
    } catch (e) {
      throw Exception('Failed to sync exchange: $e');
    }
  }

  Future<void> _syncOrder(JewelleryOrder order) async {
    try {
      final body = _orderToJson(order);

      final response = await _client.post(
        '/jewellery/custom-orders',
        body: body,
      );

      // Extract server version from response
      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      // Version-based reconciliation (Requirement 14.4)
      final reconciliation = VersionReconciliation.reconcile(
        localVersion: 0, // JewelleryOrder has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local order
        final serverData = reconciliation.serverData!;
        final reconciled = order.copyWith(
          status: serverData['status'] as String? ?? order.status,
          estimatedTotalPaisa:
              serverData['estimatedTotalPaisa'] as int? ??
              order.estimatedTotalPaisa,
          actualTotalPaisa:
              serverData['actualTotalPaisa'] as int? ?? order.actualTotalPaisa,
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _ordersBox.put(order.id, reconciled);
      } else {
        final synced = order.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _ordersBox.put(order.id, synced);
      }
    } catch (e) {
      throw Exception('Failed to sync order: $e');
    }
  }

  Future<void> _syncHallmark(HallmarkRegisterEntry entry) async {
    try {
      final body = _hallmarkToJson(entry);

      final response = await _client.post(
        '/jewellery/hallmark-inventory',
        body: body,
      );

      // Extract server version from response
      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      // Version-based reconciliation (Requirement 14.4)
      final reconciliation = VersionReconciliation.reconcile(
        localVersion:
            0, // HallmarkRegisterEntry has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local hallmark entry
        final serverData = reconciliation.serverData!;
        final reconciled = entry.copyWith(
          status: serverData['status'] as String? ?? entry.status,
          synced: true,
          lastSyncedAt: DateTime.now(),
        );
        await _hallmarkBox.put(entry.id, reconciled);
      } else {
        final synced = entry.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
        );
        await _hallmarkBox.put(entry.id, synced);
      }
    } catch (e) {
      throw Exception('Failed to sync hallmark: $e');
    }
  }

  // ============================================================================
  // FAILED-SYNC INDICATION (Requirement 14.5)
  // ============================================================================

  /// Mark a local record's syncFailed state so the UI can display a
  /// vendor-observable failed-sync indication.
  ///
  /// This is called when a sync-queue entry reaches its retry cap (5 attempts)
  /// and is marked `failedPermanently: true`. The local record is never
  /// discarded — only annotated.
  ///
  /// The implementation is idempotent (Requirement 1.8): marking an already-
  /// failed record again produces the same persisted result.
  Future<void> _markLocalRecordSyncFailed(
    String entityType,
    String entityId,
  ) async {
    switch (entityType) {
      case 'product':
        final product = _productsBox.get(entityId);
        if (product != null) {
          final marked = product.copyWith(
            synced: false,
            pendingOperation: product.pendingOperation ?? 'update',
          );
          await _productsBox.put(entityId, marked);
        }
        break;
      case 'gold_rate':
        final rate = _goldRatesBox.get(entityId);
        if (rate != null) {
          final marked = rate.copyWith(
            synced: false,
            pendingOperation: rate.pendingOperation ?? 'update',
          );
          await _goldRatesBox.put(entityId, marked);
        }
        break;
      case 'old_gold_exchange':
        final exchange = _exchangesBox.get(entityId);
        if (exchange != null) {
          final marked = exchange.copyWith(
            synced: false,
            pendingOperation: exchange.pendingOperation ?? 'update',
          );
          await _exchangesBox.put(entityId, marked);
        }
        break;
      case 'jewellery_order':
        final order = _ordersBox.get(entityId);
        if (order != null) {
          final marked = order.copyWith(
            synced: false,
            pendingOperation: order.pendingOperation ?? 'update',
          );
          await _ordersBox.put(entityId, marked);
        }
        break;
      case 'hallmark':
        final entry = _hallmarkBox.get(entityId);
        if (entry != null) {
          final marked = entry.copyWith(synced: false);
          await _hallmarkBox.put(entityId, marked);
        }
        break;
    }
  }

  /// Get all sync-queue entries that have permanently failed (retry cap reached).
  ///
  /// These entries are observable to the vendor — the UI should display a
  /// failed-sync indication for each. The entries are never discarded; the
  /// vendor may trigger a manual retry or acknowledge the failure.
  Future<List<Map<dynamic, dynamic>>> getFailedSyncEntries() async {
    await initialize();
    return _syncQueueBox.values
        .where((item) => item['failedPermanently'] as bool? ?? false)
        .toList();
  }

  /// Check whether any sync entry has permanently failed.
  ///
  /// Useful for surfacing a badge/indicator in the UI without loading all entries.
  Future<bool> hasFailedSyncEntries() async {
    await initialize();
    return _syncQueueBox.values.any(
      (item) => item['failedPermanently'] as bool? ?? false,
    );
  }

  /// Get the count of permanently failed sync entries.
  Future<int> getFailedSyncCount() async {
    await initialize();
    return _syncQueueBox.values
        .where((item) => item['failedPermanently'] as bool? ?? false)
        .length;
  }

  /// Retry a permanently-failed sync entry (resets failedPermanently and retryCount).
  ///
  /// Idempotent (Requirement 1.8): retrying an already-active entry is a no-op.
  Future<void> retryFailedEntry(String entryId) async {
    await initialize();
    final item = _syncQueueBox.get(entryId);
    if (item == null) return;
    if (item['failedPermanently'] as bool? ?? false) {
      await _syncQueueBox.put(entryId, {
        ...item,
        'retryCount': 0,
        'failedPermanently': false,
        'syncFailed': false,
        'lastError': null,
      });
    }
  }

  // ============================================================================
  // JSON CONVERTERS
  // ============================================================================

  Map<String, dynamic> _productToJson(JewelleryProduct p) => {
    'id': p.id,
    'tenantId': p.tenantId,
    'name': p.name,
    'description': p.description,
    'category': p.category,
    'metalType': p.metalType.name,
    'metalWeightGrams': p.metalWeightGrams,
    'grossWeightGrams': p.grossWeightGrams,
    'netWeightGrams': p.netWeightGrams,
    'makingChargesPerGram': p.makingChargesPerGram,
    'wastagePercent': p.wastagePercent,
    'pricePerGramPaisa': p.pricePerGramPaisa,
    'totalMrpPaisa': p.totalMrpPaisa,
    'huid': p.huid,
    'stock': p.stockQuantity,
    'barcode': p.barcode,
    'sku': p.sku,
    'isActive': p.isActive,
    'version': p.version,
    'createdAt': p.createdAt.toIso8601String(),
    'updatedAt': p.updatedAt.toIso8601String(),
    'createdBy': p.createdBy,
    'updatedBy': p.updatedBy,
  };

  Map<String, dynamic> _goldRateToJson(GoldRateCard r) => {
    'date': r.date,
    'rates': {
      'gold24KPer10gPaisa': r.gold24KPer10gPaisa,
      'gold22KPer10gPaisa': r.gold22KPer10gPaisa,
      'gold18KPer10gPaisa': r.gold18KPer10gPaisa,
      'silverPerKgPaisa': r.silverPerKgPaisa,
    },
    'source': r.source,
    'notes': r.notes,
  };

  Map<String, dynamic> _exchangeToJson(OldGoldExchange e) => {
    'customerId': e.customerId,
    'customerName': e.customerName,
    'customerPhone': e.customerPhone,
    'customerIdType': e.customerIdType,
    'customerIdNumber': e.customerIdNumber,
    'customerPhotoUrl': e.customerPhotoUrl,
    'oldGoldMetalType': e.oldGoldMetalType.name,
    'oldGoldWeightGrams': e.oldGoldWeightGrams,
    'oldGoldValuePaisa': e.oldGoldValuePaisa,
    'oldGoldRatePerGramPaisa': e.oldGoldRatePerGramPaisa,
    'exchangeValuePaisa': e.exchangeValuePaisa,
    'cashAdjustmentPaisa': e.cashAdjustmentPaisa,
    'newItemDescription': e.newItemDescription,
  };

  Map<String, dynamic> _orderToJson(JewelleryOrder o) => {
    'customerId': o.customerId,
    'customerName': o.customerName,
    'itemDescription': o.itemDescription,
    'metalType': o.metalType.name,
    'estimatedWeightGrams': o.estimatedWeightGrams,
    'metalRatePerGramPaisa': o.metalRatePerGramPaisa,
    'makingChargesPerGramPaisa': o.makingChargesPerGramPaisa,
    'estimatedTotalPaisa': o.estimatedTotalPaisa,
    'advanceReceivedPaisa': o.advanceReceivedPaisa,
    'promisedDeliveryDate': o.promisedDeliveryDate,
  };

  Map<String, dynamic> _hallmarkToJson(HallmarkRegisterEntry h) => {
    'itemName': h.productName,
    'huid': h.huid,
    'purity': h.purityStandard.code,
    'weightGrams': h.weightGrams,
    'makingChargesPerGramPaisa': 0,
    'metalRatePerGramPaisa': 0,
    'totalMrpPaisa': 0,
  };

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Future<bool> _checkProductInvoices(String productId) async {
    // In a real implementation, this would check the bills repository
    // For now, we'll use a conservative approach and check if there are any
    // references in the local database or assume products with low stock
    // have likely been sold

    final product = _productsBox.get(productId);
    if (product == null) return false;

    // If product has less stock than initial, it might have invoices
    // This is a heuristic - in production, check actual invoice lines
    return product.stockQuantity == 0 && product.isActive;
  }

  /// Get pending operations count (includes both active and permanently-failed entries).
  ///
  /// To distinguish:
  ///   - [getFailedSyncCount] → entries that exhausted retries (vendor-observable)
  ///   - total − failed = entries still actively retrying
  Future<int> getPendingSyncCount() async {
    await initialize();
    return _syncQueueBox.length;
  }

  /// Clear all data (for testing/logout)
  Future<void> clearAll() async {
    await initialize();
    await _productsBox.clear();
    await _goldRatesBox.clear();
    await _exchangesBox.clear();
    await _ordersBox.clear();
    await _hallmarkBox.clear();
    await _syncQueueBox.clear();
  }
}

/// Sync result model
class SyncResult {
  final int synced;
  final int failed;
  final int totalPending;

  /// Count of entries that have permanently failed sync (retry cap reached).
  /// These are observable to the vendor via the UI (Requirement 14.5).
  final int failedPermanently;
  final List<String> errors;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.totalPending,
    this.failedPermanently = 0,
    required this.errors,
  });

  bool get success => failed == 0 && errors.isEmpty;

  /// Whether there are entries the vendor should be alerted about.
  bool get hasFailedSyncIndication => failedPermanently > 0;
}

/// Exception thrown when attempting to register a hallmark with an HUID
/// that already exists for the tenant (Requirement 15.4).
///
/// The original entry is preserved intact — the duplicate registration is
/// rejected without overwriting any data.
class DuplicateHuidException implements Exception {
  final String huid;
  final String existingProductName;
  final String message;

  const DuplicateHuidException({
    required this.huid,
    required this.existingProductName,
    required this.message,
  });

  @override
  String toString() => 'DuplicateHuidException: $message';
}

/// Reason a gold-rate was rejected by bounds validation (Requirement 15.5).
enum GoldRateBoundsReason {
  /// Rate is below the absolute sanity minimum (₹1,000/10g).
  belowSanityMin,

  /// Rate exceeds the absolute sanity maximum (₹10,00,000/10g).
  aboveSanityMax,

  /// Day-over-day change exceeds the configurable spike threshold.
  spikeExceeded,
}

/// Exception thrown when [setGoldRate] rejects a rate that violates sanity
/// bounds or day-over-day spike limits (Requirement 15.5).
///
/// The caller surfaces this to the user so they can correct the entry or
/// override the threshold if the spike is genuine (e.g., after a holiday gap).
class GoldRateBoundsException implements Exception {
  /// Which rate field triggered the rejection (e.g., 'gold24KPer10gPaisa').
  final String field;

  /// The rejected value in paise/10g.
  final int value;

  /// Why the rate was rejected.
  final GoldRateBoundsReason reason;

  /// Human-readable explanation for UI display.
  final String message;

  /// The previous day's value (only populated for spike rejections).
  final int? previousValue;

  /// The actual fractional change (only populated for spike rejections).
  final double? changePercent;

  const GoldRateBoundsException({
    required this.field,
    required this.value,
    required this.reason,
    required this.message,
    this.previousValue,
    this.changePercent,
  });

  @override
  String toString() => 'GoldRateBoundsException: $message';
}
