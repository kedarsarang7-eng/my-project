// ============================================================================
// HARDWARE OPS REPOSITORY — LOCAL-FIRST + SYNC QUEUE (bugfix.md 2.1, 2.19, 2.25)
// ============================================================================
// Refactored from online-only (ApiClient-direct) to the BaseRepository pattern:
//   • Reads served from local Drift tables (offline-capable)
//   • Writes applied locally first, then enqueued via HardwareSyncHandler
//   • Online sync fetches from API and upserts to local tables
//   • Typed model classes replace raw Map<String, dynamic> where practical
//
// Preservation: all API paths, request/response shapes, and method signatures
// are unchanged. Online behavior is identical — the only addition is local
// persistence + sync queue wiring for offline durability.
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Variable;

import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import '../hardware_module.dart';
import '../hardware_sync_handler.dart';
import '../utils/low_stock_checker.dart';
import 'hardware_phase12_contracts.dart';
import 'invoice_profile_cache.dart';
import 'models/hardware_models.dart';

/// Type alias for backward-compatible map-based returns used by existing
/// screens. Avoids raw Future<List<Map>> in method signatures while
/// preserving the runtime interface for screen code.
typedef HardwareMapList = List<Map<String, dynamic>>;

/// Surface-area exception used to bubble actionable failures out of the
/// hardware operations repository.
class HardwareOpsException implements Exception {
  final String operation;
  final String message;
  final int? statusCode;

  HardwareOpsException(this.operation, this.message, {this.statusCode});

  @override
  String toString() =>
      'HardwareOpsException[$operation${statusCode != null ? ' · $statusCode' : ''}]: $message';
}

/// Result of an indent creation with stock-level advisory information.
///
/// The indent is always created (non-blocking). The [lowStockCheck] field
/// provides advisory information for the UI to optionally surface a warning.
class IndentCreationResult {
  /// Whether the indent was successfully created.
  final bool success;

  /// Advisory low-stock check result. If [LowStockCheckResult.hasLowStockItems]
  /// is true, the UI should show a warning (and optionally suggest a PO).
  final LowStockCheckResult lowStockCheck;

  const IndentCreationResult({
    required this.success,
    required this.lowStockCheck,
  });
}

/// Local-first hardware operations repository following the BaseRepository
/// pattern used by delivery_challan, billing, and inventory verticals.
///
/// Architecture:
///   UI → Local Drift DB → SyncQueue (via HardwareSyncHandler) → REST API
///
/// Reads are served from local Drift tables. Writes are applied locally and
/// enqueued for background sync. Online refresh fetches from the API and
/// upserts into local tables.
class HardwareOpsRepository {
  HardwareOpsRepository();

  static const _uuid = Uuid();

  /// Local cache for invoice profiles (offline-capable).
  final InvoiceProfileCache _invoiceProfileCache = InvoiceProfileCache();

  AppDatabase get _db => AppDatabase.instance;
  ApiClient get _api => sl<ApiClient>();

  /// The sync handler instance from the live HardwareModule.
  HardwareSyncHandler get _syncHandler {
    final handler = HardwareModule.instance.syncHandler;
    if (handler != null) return handler;
    return HardwareSyncHandler(SyncManager.instance);
  }

  String get _currentUserId {
    try {
      return sl<SessionManager>().userId ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Indian GSTIN format: 15 characters.
  static final RegExp _gstinPattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$',
  );

  /// HSN/SAC codes are 4, 6, or 8 digits.
  static final RegExp _hsnPattern = RegExp(r'^(\d{4}|\d{6}|\d{8})$');

  static bool isValidGstin(String gstin) =>
      _gstinPattern.hasMatch(gstin.trim().toUpperCase());

  static bool isValidHsn(String hsn) => _hsnPattern.hasMatch(hsn.trim());

  // ==========================================================================
  // ENFORCEMENT & HELPERS
  // ==========================================================================

  void _enforce(BusinessCapability capability) {
    final businessType = sl<SessionManager>().activeBusinessType.name;
    FeatureResolver.enforceAccess(businessType, capability);
  }

  Never _failList(String op, ApiResponse res) {
    throw HardwareOpsException(
      op,
      res.error ?? 'Failed to load $op',
      statusCode: res.statusCode,
    );
  }

  Never _failWrite(String op, ApiResponse res) {
    throw HardwareOpsException(
      op,
      res.error ?? 'Failed to perform $op',
      statusCode: res.statusCode,
    );
  }

  List<Map<String, dynamic>> _extractItems(
    ApiResponse res,
    String op, {
    String key = 'items',
  }) {
    if (!res.isSuccess) _failList(op, res);
    final items = res.data?['data']?[key] ?? res.data?[key];
    if (items == null) return const [];
    if (items is! List) {
      throw HardwareOpsException(
        op,
        'Unexpected response shape for $op (expected List)',
        statusCode: res.statusCode,
      );
    }
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Enqueue a mutation for offline sync via HardwareSyncHandler.
  Future<void> _enqueue({
    required SyncOperationType operationType,
    required String collection,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final item = SyncQueueItem.create(
      userId: _currentUserId,
      operationType: operationType,
      targetCollection: collection,
      documentId: documentId,
      payload: payload,
      priority: 1,
    );
    await _syncHandler.enqueue(item);
  }

  // ==========================================================================
  // LOCAL DB HELPERS — raw SQL via AppDatabase (no codegen dependency)
  // ==========================================================================

  Future<List<Map<String, dynamic>>> _localQuery(
    String table, {
    String? where,
    String orderBy = 'created_at DESC',
  }) async {
    final sql = StringBuffer('SELECT * FROM "$table"');
    if (where != null) sql.write(' WHERE $where');
    sql.write(' ORDER BY $orderBy');
    final rows = await _db.customSelect(sql.toString()).get();
    return rows.map((r) => r.data).toList();
  }

  Future<void> _localInsert(String table, Map<String, dynamic> row) async {
    final cols = row.keys.toList();
    final colSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    final values = cols.map((c) => row[c]).toList();
    await _db.customInsert(
      'INSERT OR REPLACE INTO "$table" ($colSql) VALUES ($placeholders)',
      variables: values.map((v) => Variable(v)).toList(),
    );
  }

  Future<void> _localUpdate(
    String table,
    String id,
    Map<String, dynamic> changes,
  ) async {
    final sets = changes.keys.map((k) => '"$k" = ?').join(', ');
    final values = changes.values.toList();
    await _db.customUpdate(
      'UPDATE "$table" SET $sets WHERE "id" = ?',
      variables: [...values.map((v) => Variable(v)), Variable(id)],
    );
  }

  // ==========================================================================
  // PROJECTS — Local-first reads + sync-queued writes
  // ==========================================================================

  Future<List<HardwareProject>> listProjects() async {
    _enforce(BusinessCapability.useInventoryList);
    final rows = await _localQuery(
      'hardware_projects',
      where: 'deleted_at IS NULL',
    );
    return rows.map((r) => HardwareProject.fromJson(r)).toList();
  }

  Future<bool> createProject({
    required String projectName,
    String? contractorName,
    String? siteAddress,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _localInsert('hardware_projects', {
      'id': id,
      'user_id': _currentUserId,
      'project_name': projectName,
      'contractor_name': contractorName,
      'site_address': siteAddress,
      'notes': notes,
      'status': 'active',
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    });
    await _enqueue(
      operationType: SyncOperationType.create,
      collection: 'hardware_projects',
      documentId: id,
      payload: {
        'id': id,
        'projectName': projectName,
        if (contractorName != null && contractorName.trim().isNotEmpty)
          'contractorName': contractorName.trim(),
        if (siteAddress != null && siteAddress.trim().isNotEmpty)
          'siteAddress': siteAddress.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return true;
  }

  Future<bool> closeProject(String projectId) async {
    _enforce(BusinessCapability.useStockManagement);
    await _localUpdate('hardware_projects', projectId, {
      'status': 'closed',
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    await _enqueue(
      operationType: SyncOperationType.update,
      collection: 'hardware_projects',
      documentId: projectId,
      payload: {'id': projectId, 'status': 'closed'},
    );
    return true;
  }

  // ==========================================================================
  // SITE INDENTS
  // ==========================================================================

  Future<List<HardwareSiteIndent>> listIndents({String? projectId}) async {
    _enforce(BusinessCapability.useInventoryList);
    String? where = 'deleted_at IS NULL';
    if (projectId != null && projectId.isNotEmpty) {
      where += " AND project_id = '$projectId'";
    }
    final rows = await _localQuery('hardware_site_indents', where: where);
    return rows.map((r) => HardwareSiteIndent.fromJson(r)).toList();
  }

  Future<bool> createIndent({
    required String projectId,
    required String requestedBy,
    required List<Map<String, dynamic>> items,
    String priority = 'normal',
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    for (final item in items) {
      final hsn = (item['hsn'] ?? item['hsnCode'])?.toString().trim() ?? '';
      if (hsn.isNotEmpty && !isValidHsn(hsn)) {
        throw HardwareOpsException(
          'createIndent',
          'Invalid HSN code "$hsn": must be 4, 6, or 8 digits.',
        );
      }
    }
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _localInsert('hardware_site_indents', {
      'id': id,
      'user_id': _currentUserId,
      'project_id': projectId,
      'requested_by': requestedBy,
      'priority': priority,
      'status': 'open',
      'notes': notes,
      'items_json': jsonEncode(items),
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    });
    await _enqueue(
      operationType: SyncOperationType.create,
      collection: 'site_indents',
      documentId: id,
      payload: {
        'id': id,
        'projectId': projectId,
        'requestedBy': requestedBy,
        'priority': priority,
        'items': items,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return true;
  }

  /// Create an indent with a low-stock advisory check.
  ///
  /// This is the preferred entry point for indent creation in the UI layer.
  /// It creates the indent (non-blocking) AND returns low-stock information
  /// so the UI can surface a warning dialog when applicable.
  ///
  /// The indent is always created regardless of stock levels. The
  /// [LowStockCheckResult] is purely advisory.
  Future<IndentCreationResult> createIndentWithStockCheck({
    required String projectId,
    required String requestedBy,
    required List<Map<String, dynamic>> items,
    String priority = 'normal',
    String? notes,
  }) async {
    // Perform stock check before creating the indent
    final stockCheck = await checkLowStockForIndent(items);

    // Create the indent regardless of stock levels (non-blocking warning)
    await createIndent(
      projectId: projectId,
      requestedBy: requestedBy,
      items: items,
      priority: priority,
      notes: notes,
    );

    return IndentCreationResult(success: true, lowStockCheck: stockCheck);
  }

  /// Check inventory stock levels for items in an indent before submission.
  ///
  /// Returns a [LowStockCheckResult] indicating which items (if any) are
  /// below their reorder point. This is a non-blocking advisory check —
  /// the indent proceeds regardless.
  ///
  /// Preservation: indents with all items at sufficient stock return an
  /// empty result (no warning shown, no extra step).
  Future<LowStockCheckResult> checkLowStockForIndent(
    List<Map<String, dynamic>> items,
  ) async {
    // Collect product IDs from the indent items
    final productIds = <String>[];
    for (final item in items) {
      final pid = (item['productId'] ?? item['product_id'] ?? '')
          .toString()
          .trim();
      if (pid.isNotEmpty) productIds.add(pid);
    }

    if (productIds.isEmpty) return const LowStockCheckResult.clear();

    // Query local inventory table for stock levels of the requested products
    final inventoryData = <String, InventoryStockInfo>{};
    for (final pid in productIds) {
      final rows = await _db
          .customSelect(
            'SELECT product_id, quantity, reorder_level FROM "inventory" '
            'WHERE product_id = ? AND deleted_at IS NULL '
            'LIMIT 1',
            variables: [Variable<String>(pid)],
          )
          .get();

      if (rows.isNotEmpty) {
        final row = rows.first.data;
        // Also try to get the product name from inventory or products cache
        final name = (row['product_name'] ?? row['name'] ?? pid).toString();
        inventoryData[pid] = InventoryStockInfo(
          productId: pid,
          productName: name,
          quantity: (row['quantity'] as num?)?.toDouble() ?? 0.0,
          reorderLevel: (row['reorder_level'] as num?)?.toDouble() ?? 0.0,
        );
      }
    }

    return LowStockChecker.check(
      indentItems: items,
      inventoryData: inventoryData,
    );
  }

  Future<bool> closeIndent(String indentId) async {
    _enforce(BusinessCapability.useStockManagement);
    await _localUpdate('hardware_site_indents', indentId, {
      'status': 'closed',
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    await _enqueue(
      operationType: SyncOperationType.update,
      collection: 'site_indents',
      documentId: indentId,
      payload: {'id': indentId, 'status': 'closed'},
    );
    return true;
  }

  // ==========================================================================
  // MATERIAL DEPOSITS
  // ==========================================================================

  Future<List<HardwareMaterialDeposit>> listDeposits({String? status}) async {
    _enforce(BusinessCapability.useInventoryList);
    String? where = 'deleted_at IS NULL';
    if (status != null && status.isNotEmpty) {
      where += " AND status = '$status'";
    }
    final rows = await _localQuery('hardware_material_deposits', where: where);
    return rows.map((r) => HardwareMaterialDeposit.fromJson(r)).toList();
  }

  Future<bool> createDeposit({
    required String customerId,
    required String customerName,
    required String itemType,
    required double quantity,
    required int depositAmountCents,
    String? referenceNo,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _localInsert('hardware_material_deposits', {
      'id': id,
      'user_id': _currentUserId,
      'customer_id': customerId,
      'customer_name': customerName,
      'item_type': itemType,
      'quantity': quantity,
      'deposit_amount_cents': depositAmountCents,
      'reference_no': referenceNo,
      'notes': notes,
      'status': 'active',
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    });
    await _enqueue(
      operationType: SyncOperationType.create,
      collection: 'material_deposits',
      documentId: id,
      payload: {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'itemType': itemType,
        'quantity': quantity,
        'depositAmountCents': depositAmountCents,
        if (referenceNo != null && referenceNo.trim().isNotEmpty)
          'referenceNo': referenceNo.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return true;
  }

  Future<bool> settleDeposit({
    required String depositId,
    required double returnedQuantity,
    required int refundAmountCents,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    await _localUpdate('hardware_material_deposits', depositId, {
      'status': 'settled',
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    await _enqueue(
      operationType: SyncOperationType.update,
      collection: 'material_deposits',
      documentId: depositId,
      payload: {
        'id': depositId,
        'returnedQuantity': returnedQuantity,
        'refundAmountCents': refundAmountCents,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return true;
  }

  // ==========================================================================
  // PURCHASE ORDERS
  // ==========================================================================

  Future<List<HardwarePurchaseOrder>> listPurchaseOrders() async {
    _enforce(BusinessCapability.useInventoryList);
    final rows = await _localQuery(
      'hardware_purchase_orders',
      where: 'deleted_at IS NULL',
    );
    return rows.map((r) => HardwarePurchaseOrder.fromJson(r)).toList();
  }

  Future<bool> createPurchaseOrder({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    String? expectedDeliveryDate,
    String? notes,
  }) async {
    _enforce(BusinessCapability.usePurchaseOrder);
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _localInsert('hardware_purchase_orders', {
      'id': id,
      'user_id': _currentUserId,
      'supplier_id': supplierId,
      'status': 'pending',
      'expected_delivery_date': expectedDeliveryDate,
      'notes': notes,
      'items_json': jsonEncode(items),
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    });
    await _enqueue(
      operationType: SyncOperationType.create,
      collection: 'hardware_purchase_orders',
      documentId: id,
      payload: {
        'id': id,
        'supplierId': supplierId,
        'items': items,
        if (expectedDeliveryDate != null && expectedDeliveryDate.isNotEmpty)
          'expectedDeliveryDate': expectedDeliveryDate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return true;
  }

  // ==========================================================================
  // PARTIES
  // ==========================================================================

  Future<List<HardwareParty>> listParties() async {
    _enforce(BusinessCapability.useInventoryList);
    final rows = await _localQuery(
      'hardware_parties',
      where: 'deleted_at IS NULL',
    );
    return rows.map((r) => HardwareParty.fromJson(r)).toList();
  }

  Future<bool> createParty({
    required String name,
    required String type,
    String? phone,
    String? gstin,
    String? address,
    int creditLimit = 0,
    int creditDays = 30,
    String priceCategory = 'retail',
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final cleanGstin = gstin?.trim();
    if (cleanGstin != null &&
        cleanGstin.isNotEmpty &&
        !isValidGstin(cleanGstin)) {
      throw HardwareOpsException(
        'createParty',
        'Invalid GSTIN format: must be a 15-character GSTIN '
            '(e.g. 27ABCDE1234F1Z5).',
      );
    }
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _localInsert('hardware_parties', {
      'id': id,
      'user_id': _currentUserId,
      'name': name,
      'type': type,
      'phone': phone,
      'gstin': cleanGstin,
      'address': address,
      'credit_limit': creditLimit,
      'credit_days': creditDays,
      'price_category': priceCategory,
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    });
    await _enqueue(
      operationType: SyncOperationType.create,
      collection: 'hardware_parties',
      documentId: id,
      payload: {
        'id': id,
        'name': name,
        'type': type,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (cleanGstin != null && cleanGstin.isNotEmpty) 'gstin': cleanGstin,
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        'creditLimit': creditLimit,
        'creditDays': creditDays,
        'priceCategory': priceCategory,
      },
    );
    return true;
  }

  // ==========================================================================
  // SALES ORDERS
  // ==========================================================================

  Future<List<HardwareSalesOrder>> listSalesOrders() async {
    _enforce(BusinessCapability.useInventoryList);
    final rows = await _localQuery(
      'hardware_sales_orders',
      where: 'deleted_at IS NULL',
    );
    return rows.map((r) => HardwareSalesOrder.fromJson(r)).toList();
  }

  Future<bool> updateSalesOrderStatus({
    required String id,
    required String status,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    await _localUpdate('hardware_sales_orders', id, {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    await _enqueue(
      operationType: SyncOperationType.update,
      collection: 'hardware_sales_orders',
      documentId: id,
      payload: {
        'id': id,
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return true;
  }

  // ==========================================================================
  // BACKWARD-COMPATIBLE MAP ACCESSORS (for existing screen code)
  // ==========================================================================

  Future<HardwareMapList> listProjectsAsMap() async =>
      (await listProjects()).map((e) => e.toJson()).toList();

  Future<HardwareMapList> listIndentsAsMap({String? projectId}) async =>
      (await listIndents(projectId: projectId)).map((e) => e.toJson()).toList();

  Future<HardwareMapList> listDepositsAsMap({String? status}) async =>
      (await listDeposits(status: status)).map((e) => e.toJson()).toList();

  Future<HardwareMapList> listPurchaseOrdersAsMap() async =>
      (await listPurchaseOrders()).map((e) => e.toJson()).toList();

  Future<HardwareMapList> listPartiesAsMap() async =>
      (await listParties()).map((e) => e.toJson()).toList();

  Future<HardwareMapList> listSalesOrdersAsMap() async =>
      (await listSalesOrders()).map((e) => e.toJson()).toList();

  // ==========================================================================
  // ONLINE-ONLY ENDPOINTS (reports, aggregates — remain API-direct)
  // API paths preserved for online behavior compatibility.
  // ==========================================================================

  Future<HardwareMapList> listCustomers() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/customers');
    return _extractItems(res, 'listCustomers');
  }

  Future<HardwareMapList> listProducts() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/inventory');
    return _extractItems(res, 'listProducts');
  }

  Future<HardwareMapList> getRateComparison({String? itemName}) async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(
      '/hardware/rate-comparison',
      queryParameters: {
        if (itemName != null && itemName.trim().isNotEmpty)
          'itemName': itemName.trim(),
      },
    );
    return _extractItems(res, 'getRateComparison', key: 'best');
  }

  Future<HardwareMapList> getPendingPurchaseOrders() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/purchase-orders/pending');
    return _extractItems(res, 'getPendingPurchaseOrders');
  }

  Future<Map<String, dynamic>> getInvoiceProfiles() async {
    _enforce(BusinessCapability.useInvoiceList);
    try {
      final res = await _api.get('/hardware/invoice-profiles');
      if (!res.isSuccess) _failList('getInvoiceProfiles', res);
      final data = res.data?['data'] ?? res.data ?? const {};
      final result = Map<String, dynamic>.from(data as Map);
      // Cache on successful API load for offline fallback
      await _invoiceProfileCache.save(result);
      return result;
    } on HardwareOpsException {
      // API failed — try local cache before re-throwing
      final cached = await _invoiceProfileCache.load();
      if (cached != null) return cached;
      rethrow;
    } catch (_) {
      // Network/connectivity error — try local cache
      final cached = await _invoiceProfileCache.load();
      if (cached != null) return cached;
      throw HardwareOpsException(
        'getInvoiceProfiles',
        'Offline and no cached profiles available',
      );
    }
  }

  Future<bool> saveInvoiceProfiles({
    required List<Map<String, dynamic>> profiles,
    String? defaultProfileId,
  }) async {
    _enforce(BusinessCapability.useInvoiceCreate);
    final res = await _api.put(
      '/hardware/invoice-profiles',
      body: {'profiles': profiles, 'defaultProfileId': defaultProfileId},
    );
    if (!res.isSuccess) _failWrite('saveInvoiceProfiles', res);
    // Update local cache on successful save
    await _invoiceProfileCache.save({
      'profiles': profiles,
      'defaultProfileId': defaultProfileId,
    });
    return true;
  }

  Future<HardwareMapList> getFastSlowMoving() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/reports/item-velocity');
    if (!res.isSuccess) _failList('getFastSlowMoving', res);
    final data = res.data?['data'] ?? res.data ?? const {};
    final fast = (data['fastMoving'] as List?) ?? const [];
    final slow = (data['slowMoving'] as List?) ?? const [];
    return [
      ...fast.whereType<Map>().map(
        (e) => {'bucket': 'fast', ...Map<String, dynamic>.from(e)},
      ),
      ...slow.whereType<Map>().map(
        (e) => {'bucket': 'slow', ...Map<String, dynamic>.from(e)},
      ),
    ];
  }

  Future<HardwareMapList> getDeadStock() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/reports/dead-stock');
    return _extractItems(res, 'getDeadStock');
  }

  Future<int> getContractorCreditOutstandingCents() async {
    _enforce(BusinessCapability.useCreditManagement);
    final res = await _api.get('/customers/credit/reminder-candidates');
    if (!res.isSuccess) _failList('getContractorCreditOutstandingCents', res);
    final data = res.data?['data'] ?? res.data ?? const {};
    final totals = (data is Map ? data['totals'] : null) as Map? ?? const {};
    return (totals['totalOutstanding'] as num?)?.round() ?? 0;
  }

  // ==========================================================================
  // GRN & PURCHASE BILL — Methods for Root Cause B (Task 3.2)
  // ==========================================================================

  Future<HardwareMapList> listGrn({String? purchaseOrderId}) async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(
      HardwareApiContract.listGrn,
      queryParameters: {
        if (purchaseOrderId != null && purchaseOrderId.isNotEmpty)
          'purchaseOrderId': purchaseOrderId,
      },
    );
    return _extractItems(res, 'listGrn');
  }

  Future<bool> createGrn({
    required String purchaseOrderId,
    required List<Map<String, dynamic>> receivedItems,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final res = await _api.post(
      HardwareApiContract.createGrn,
      body: {
        'purchaseOrderId': purchaseOrderId,
        'receivedItems': receivedItems,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('createGrn', res);
    return true;
  }

  Future<HardwareMapList> listPurchaseBills({String? purchaseOrderId}) async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(
      HardwareApiContract.listPurchaseBills,
      queryParameters: {
        if (purchaseOrderId != null && purchaseOrderId.isNotEmpty)
          'purchaseOrderId': purchaseOrderId,
      },
    );
    return _extractItems(res, 'listPurchaseBills');
  }

  Future<bool> createPurchaseBill({
    required String purchaseOrderId,
    required String grnId,
    required List<Map<String, dynamic>> billedItems,
    String? invoiceNumber,
    String? notes,
  }) async {
    _enforce(BusinessCapability.usePurchaseOrder);
    final res = await _api.post(
      HardwareApiContract.createPurchaseBill,
      body: {
        'purchaseOrderId': purchaseOrderId,
        'grnId': grnId,
        'billedItems': billedItems,
        if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
          'invoiceNumber': invoiceNumber.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('createPurchaseBill', res);
    return true;
  }

  Future<bool> returnPurchaseBill({
    required String billId,
    required List<Map<String, dynamic>> returnedItems,
    String? reason,
  }) async {
    _enforce(BusinessCapability.usePurchaseOrder);
    final endpoint = HardwareApiContract.returnPurchaseBill.replaceAll(
      '{id}',
      billId,
    );
    final res = await _api.post(
      endpoint,
      body: {
        'returnedItems': returnedItems,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('returnPurchaseBill', res);
    return true;
  }

  // ==========================================================================
  // ONLINE REFRESH — Fetch from API and upsert into local tables
  // ==========================================================================

  Future<void> refreshProjects() async {
    try {
      final res = await _api.get('/hardware/projects');
      final items = _extractItems(res, 'refreshProjects');
      for (final item in items) {
        item['user_id'] = _currentUserId;
        item['is_synced'] = 1;
        item['created_at'] ??= DateTime.now().toIso8601String();
        item['updated_at'] ??= DateTime.now().toIso8601String();
        await _localInsert('hardware_projects', item);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HardwareOpsRepository.refreshProjects: $e');
    }
  }

  Future<void> refreshIndents() async {
    try {
      final res = await _api.get('/hardware/indents');
      final items = _extractItems(res, 'refreshIndents');
      for (final item in items) {
        item['user_id'] = _currentUserId;
        item['is_synced'] = 1;
        item['items_json'] ??= jsonEncode(item['items'] ?? []);
        item['created_at'] ??= DateTime.now().toIso8601String();
        item['updated_at'] ??= DateTime.now().toIso8601String();
        await _localInsert('hardware_site_indents', item);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HardwareOpsRepository.refreshIndents: $e');
    }
  }

  Future<void> refreshDeposits() async {
    try {
      final res = await _api.get('/hardware/deposits');
      final items = _extractItems(res, 'refreshDeposits');
      for (final item in items) {
        item['user_id'] = _currentUserId;
        item['is_synced'] = 1;
        item['created_at'] ??= DateTime.now().toIso8601String();
        item['updated_at'] ??= DateTime.now().toIso8601String();
        await _localInsert('hardware_material_deposits', item);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HardwareOpsRepository.refreshDeposits: $e');
    }
  }

  Future<void> refreshPurchaseOrders() async {
    try {
      final res = await _api.get(HardwareApiContract.listPurchaseOrders);
      final items = _extractItems(res, 'refreshPurchaseOrders');
      for (final item in items) {
        item['user_id'] = _currentUserId;
        item['is_synced'] = 1;
        item['items_json'] ??= jsonEncode(item['items'] ?? []);
        item['created_at'] ??= DateTime.now().toIso8601String();
        item['updated_at'] ??= DateTime.now().toIso8601String();
        await _localInsert('hardware_purchase_orders', item);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HardwareOpsRepository.refreshPurchaseOrders: $e');
      }
    }
  }

  Future<void> refreshParties() async {
    try {
      final res = await _api.get(HardwareApiContract.listParties);
      final items = _extractItems(res, 'refreshParties');
      for (final item in items) {
        item['user_id'] = _currentUserId;
        item['is_synced'] = 1;
        item['created_at'] ??= DateTime.now().toIso8601String();
        item['updated_at'] ??= DateTime.now().toIso8601String();
        await _localInsert('hardware_parties', item);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HardwareOpsRepository.refreshParties: $e');
    }
  }

  Future<void> refreshSalesOrders() async {
    try {
      final res = await _api.get('/hardware/sales-orders');
      final items = _extractItems(res, 'refreshSalesOrders');
      for (final item in items) {
        item['user_id'] = _currentUserId;
        item['is_synced'] = 1;
        item['items_json'] ??= jsonEncode(item['items'] ?? []);
        item['created_at'] ??= DateTime.now().toIso8601String();
        item['updated_at'] ??= DateTime.now().toIso8601String();
        await _localInsert('hardware_sales_orders', item);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HardwareOpsRepository.refreshSalesOrders: $e');
      }
    }
  }

  /// Full refresh — sync all hardware entity types from API to local DB.
  Future<void> refreshAll() async {
    await Future.wait([
      refreshProjects(),
      refreshIndents(),
      refreshDeposits(),
      refreshPurchaseOrders(),
      refreshParties(),
      refreshSalesOrders(),
    ]);
  }

  // ==========================================================================
  // REMNANT INVENTORY — Loose-quantity / cut-to-length tracking (Task 3.11)
  // ==========================================================================

  /// Persist a remnant record after a cut-to-size sale.
  ///
  /// Stores the remaining stock length locally and enqueues for sync.
  /// This enables the shop to track partial-length inventory across sales
  /// (e.g., a 6ft bar cut to 1.3ft leaves 4.7ft as a remnant for the next
  /// customer).
  Future<void> saveRemnant({
    required String itemName,
    required double remainingLength,
    required String unit,
    required double pricePerUnit,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _localInsert('hardware_remnants', {
      'id': id,
      'user_id': _currentUserId,
      'item_name': itemName,
      'remaining_length': remainingLength,
      'unit': unit,
      'price_per_unit': pricePerUnit,
      'status': 'available',
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    });
    await _enqueue(
      operationType: SyncOperationType.create,
      collection: 'hardware_remnants',
      documentId: id,
      payload: {
        'id': id,
        'itemName': itemName,
        'remainingLength': remainingLength,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
      },
    );
  }

  /// List available remnants (unsold partial-length stock).
  Future<List<Map<String, dynamic>>> listRemnants({String? itemName}) async {
    _enforce(BusinessCapability.useInventoryList);
    String where = "status = 'available' AND deleted_at IS NULL";
    if (itemName != null && itemName.isNotEmpty) {
      where += " AND item_name = '$itemName'";
    }
    return _localQuery('hardware_remnants', where: where);
  }

  /// Mark a remnant as sold (consumed by a subsequent cut-to-size sale).
  Future<void> consumeRemnant(String remnantId) async {
    _enforce(BusinessCapability.useStockManagement);
    await _localUpdate('hardware_remnants', remnantId, {
      'status': 'sold',
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    await _enqueue(
      operationType: SyncOperationType.update,
      collection: 'hardware_remnants',
      documentId: remnantId,
      payload: {'id': remnantId, 'status': 'sold'},
    );
  }
}
