// Clothing Repository - Full Offline Support
// Manages Clothing Variants, Tailoring Records, and Inventory Items with Hive
//
// Following the jewellery_repository_offline.dart pattern: a local store plus
// a clothing_sync_queue (entityType, operation, entityId, retryCount, lastError,
// failed flag; records carry synced, pendingOperation, pendingSince, version),
// tenant-scoped, RID ids, optimistic local write.
//
// Requirements validated: 12.2, 1.4, 1.5, 1.12

import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/sync/version_reconciliation.dart';
import '../../../../core/utils/rid_generator.dart';
import '../variant_repository.dart';
import '../models/tailoring_record.dart';

/// A lightweight inventory item for the clothing vertical.
///
/// Tracks per-product stock and pricing at the aggregate level, complementing
/// the fine-grained per-variant [VariantItem] records.
class ClothingInventoryItem {
  final String id;
  final String tenantId;
  final String productId;
  final String productName;
  final int totalStock; // aggregate stock count
  final int priceCents; // integer Paise, >= 0
  final int reorderLevel; // per-product low-stock threshold
  final DateTime createdAt;
  final DateTime updatedAt;

  // Sync metadata
  final bool synced;
  final String? pendingOperation;
  final DateTime? pendingSince;
  final int version;

  const ClothingInventoryItem({
    required this.id,
    required this.tenantId,
    required this.productId,
    required this.productName,
    this.totalStock = 0,
    this.priceCents = 0,
    this.reorderLevel = 5,
    required this.createdAt,
    required this.updatedAt,
    this.synced = true,
    this.pendingOperation,
    this.pendingSince,
    this.version = 1,
  });

  ClothingInventoryItem copyWith({
    String? id,
    String? tenantId,
    String? productId,
    String? productName,
    int? totalStock,
    int? priceCents,
    int? reorderLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
    String? pendingOperation,
    DateTime? pendingSince,
    int? version,
  }) {
    return ClothingInventoryItem(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      totalStock: totalStock ?? this.totalStock,
      priceCents: priceCents ?? this.priceCents,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      pendingOperation: pendingOperation ?? this.pendingOperation,
      pendingSince: pendingSince ?? this.pendingSince,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenantId': tenantId,
    'productId': productId,
    'productName': productName,
    'totalStock': totalStock,
    'priceCents': priceCents,
    'reorderLevel': reorderLevel,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'synced': synced,
    'pendingOperation': pendingOperation,
    'pendingSince': pendingSince?.toIso8601String(),
    'version': version,
  };

  factory ClothingInventoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException(
        'ClothingInventoryItem.fromJson: "id" must be a non-empty String',
      );
    }
    final tenantId = json['tenantId'];
    if (tenantId is! String || tenantId.isEmpty) {
      throw FormatException(
        'ClothingInventoryItem.fromJson: "tenantId" must be a non-empty String',
      );
    }

    return ClothingInventoryItem(
      id: id,
      tenantId: tenantId,
      productId: (json['productId'] is String)
          ? json['productId'] as String
          : '',
      productName: (json['productName'] is String)
          ? json['productName'] as String
          : '',
      totalStock: (json['totalStock'] is int) ? json['totalStock'] as int : 0,
      priceCents: (json['priceCents'] is int) ? json['priceCents'] as int : 0,
      reorderLevel: (json['reorderLevel'] is int)
          ? json['reorderLevel'] as int
          : 5,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      synced: json['synced'] as bool? ?? true,
      pendingOperation: json['pendingOperation'] as String?,
      pendingSince: json['pendingSince'] != null
          ? DateTime.tryParse(json['pendingSince'].toString())
          : null,
      version: (json['version'] is int) ? json['version'] as int : 1,
    );
  }
}

/// Extension on [VariantItem] to carry offline sync metadata.
///
/// Since [VariantItem] is a value class in [variant_repository.dart], the
/// offline layer wraps it with sync fields stored alongside the variant data
/// in the Hive box.
class OfflineVariantRecord {
  final VariantItem variant;
  final String tenantId;
  final bool synced;
  final String? pendingOperation;
  final DateTime? pendingSince;
  final int version;

  const OfflineVariantRecord({
    required this.variant,
    required this.tenantId,
    this.synced = true,
    this.pendingOperation,
    this.pendingSince,
    this.version = 1,
  });

  OfflineVariantRecord copyWith({
    VariantItem? variant,
    String? tenantId,
    bool? synced,
    String? pendingOperation,
    DateTime? pendingSince,
    int? version,
  }) {
    return OfflineVariantRecord(
      variant: variant ?? this.variant,
      tenantId: tenantId ?? this.tenantId,
      synced: synced ?? this.synced,
      pendingOperation: pendingOperation ?? this.pendingOperation,
      pendingSince: pendingSince ?? this.pendingSince,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
    ...variant.toJson(),
    'tenantId': tenantId,
    'synced': synced,
    'pendingOperation': pendingOperation,
    'pendingSince': pendingSince?.toIso8601String(),
    'version': version,
  };

  factory OfflineVariantRecord.fromJson(Map<String, dynamic> json) {
    return OfflineVariantRecord(
      variant: VariantItem.fromJson(json),
      tenantId: (json['tenantId'] is String) ? json['tenantId'] as String : '',
      synced: json['synced'] as bool? ?? true,
      pendingOperation: json['pendingOperation'] as String?,
      pendingSince: json['pendingSince'] != null
          ? DateTime.tryParse(json['pendingSince'].toString())
          : null,
      version: (json['version'] is int) ? json['version'] as int : 1,
    );
  }
}

/// Sync operation result summary.
class ClothingSyncResult {
  final int synced;
  final int failed;
  final int totalPending;
  final int failedPermanently;
  final List<String> errors;

  const ClothingSyncResult({
    this.synced = 0,
    this.failed = 0,
    this.totalPending = 0,
    this.failedPermanently = 0,
    this.errors = const [],
  });
}

/// Clothing Repository with Offline-First Architecture
///
/// Follows the established [JewelleryRepositoryOffline] pattern:
/// - Local Hive boxes for each entity type (variants, tailoring, inventory)
/// - A `clothing_sync_queue` Hive box for pending operations
/// - Tenant-scoped: every operation resolves tenantId from SessionManager
/// - Optimistic local write: persist locally then enqueue for sync
/// - RID ids for new entities
///
/// Sync queue entry fields:
///   - entityType: 'variant' | 'tailoring_record' | 'inventory_item'
///   - operation: 'create' | 'update' | 'delete'
///   - entityId: the RID of the affected entity
///   - retryCount: int (starts at 0, max 5)
///   - lastError: String? (last failure message)
///   - failedPermanently: bool (true after 5 retries)
///
/// Record sync metadata:
///   - synced: bool
///   - pendingOperation: String?
///   - pendingSince: DateTime?
///   - version: int
class ClothingRepositoryOffline {
  final ApiClient _client;
  final SessionManager _session;

  // Hive boxes for offline storage
  late Box<Map> _variantsBox;
  late Box<Map> _tailoringBox;
  late Box<Map> _inventoryBox;
  late Box<Map> _syncQueueBox;

  bool _initialized = false;

  ClothingRepositoryOffline(this._client, this._session);

  /// Initialize Hive boxes.
  ///
  /// Mini_Gate: These are ADDITIVE Hive boxes with safe defaults. They do not
  /// modify any existing box/table and are applied only after sign-off.
  /// Mini_Gate APPROVED for these additive Hive boxes.
  Future<void> initialize() async {
    if (_initialized) return;

    _variantsBox = await Hive.openBox<Map>('clothing_variants');
    _tailoringBox = await Hive.openBox<Map>('clothing_tailoring_records');
    _inventoryBox = await Hive.openBox<Map>('clothing_inventory_items');
    _syncQueueBox = await Hive.openBox<Map>('clothing_sync_queue');

    _initialized = true;
  }

  /// Resolves the tenant ID from the session. Returns null if unresolved.
  String? _resolveTenantId() {
    return _session.ownerId;
  }

  /// Asserts tenant is resolved; throws if not (Requirement 1.12).
  String _requireTenantId() {
    final tenantId = _resolveTenantId();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError(
        'ClothingRepositoryOffline: tenant ID is unresolved. '
        'Operation aborted — no read or write performed.',
      );
    }
    return tenantId;
  }

  // ==========================================================================
  // VARIANTS
  // ==========================================================================

  /// Get all variants for a product (offline-first, tenant-scoped).
  Future<List<OfflineVariantRecord>> getVariants(String productId) async {
    await initialize();
    final tenantId = _requireTenantId();

    return _variantsBox.values
        .map((m) => OfflineVariantRecord.fromJson(Map<String, dynamic>.from(m)))
        .where(
          (r) => r.tenantId == tenantId && r.variant.productId == productId,
        )
        .toList();
  }

  /// Get a single variant by ID (offline-first, tenant-scoped).
  Future<OfflineVariantRecord?> getVariantById(String id) async {
    await initialize();
    final tenantId = _requireTenantId();

    final raw = _variantsBox.get(id);
    if (raw == null) return null;

    final record = OfflineVariantRecord.fromJson(
      Map<String, dynamic>.from(raw),
    );
    if (record.tenantId != tenantId) return null;
    return record;
  }

  /// Create a new variant (optimistic local write + sync queue entry).
  Future<OfflineVariantRecord> createVariant({
    required String productId,
    required String color,
    required String size,
    String sku = '',
    String barcode = '',
    int priceCents = 0,
    int stock = 0,
  }) async {
    await initialize();
    final tenantId = _requireTenantId();
    final now = DateTime.now();
    final id = RidGenerator.next(tenantId);

    final variant = VariantItem(
      id: id,
      productId: productId,
      color: color,
      size: size,
      sku: sku,
      barcode: barcode,
      priceCents: priceCents,
      stock: stock,
    );

    final record = OfflineVariantRecord(
      variant: variant,
      tenantId: tenantId,
      synced: false,
      pendingOperation: 'create',
      pendingSince: now,
      version: 1,
    );

    await _variantsBox.put(id, record.toJson());
    await _addToSyncQueue('variant', 'create', id);

    // Fire-and-forget sync attempt
    _syncVariant(record);

    return record;
  }

  /// Update an existing variant (optimistic local write + sync queue entry).
  Future<OfflineVariantRecord> updateVariant(
    String id, {
    String? color,
    String? size,
    String? sku,
    String? barcode,
    int? priceCents,
    int? stock,
  }) async {
    await initialize();
    final tenantId = _requireTenantId();
    final now = DateTime.now();

    final existing = await getVariantById(id);
    if (existing == null) {
      throw Exception('Variant not found: $id');
    }

    final updatedVariant = VariantItem(
      id: id,
      productId: existing.variant.productId,
      color: color ?? existing.variant.color,
      size: size ?? existing.variant.size,
      sku: sku ?? existing.variant.sku,
      barcode: barcode ?? existing.variant.barcode,
      priceCents: priceCents ?? existing.variant.priceCents,
      stock: stock ?? existing.variant.stock,
    );

    final record = OfflineVariantRecord(
      variant: updatedVariant,
      tenantId: tenantId,
      synced: false,
      pendingOperation: 'update',
      pendingSince: now,
      version: existing.version + 1,
    );

    await _variantsBox.put(id, record.toJson());
    await _addToSyncQueue('variant', 'update', id);

    _syncVariant(record);

    return record;
  }

  /// Bulk update variants for a product (optimistic local write).
  ///
  /// Each variant in the list is persisted locally and enqueues exactly one
  /// sync-queue entry per variant.
  Future<void> bulkUpdateVariants(
    String productId,
    List<VariantItem> variants,
  ) async {
    await initialize();
    final tenantId = _requireTenantId();
    final now = DateTime.now();

    for (final variant in variants) {
      final existingRaw = _variantsBox.get(variant.id);
      final existingVersion = existingRaw != null
          ? (existingRaw['version'] as int? ?? 1)
          : 0;

      final record = OfflineVariantRecord(
        variant: variant,
        tenantId: tenantId,
        synced: false,
        pendingOperation: existingRaw != null ? 'update' : 'create',
        pendingSince: now,
        version: existingVersion + 1,
      );

      await _variantsBox.put(variant.id, record.toJson());
      await _addToSyncQueue(
        'variant',
        existingRaw != null ? 'update' : 'create',
        variant.id,
      );
    }
  }

  /// Soft-delete a variant (marks pendingOperation as 'delete').
  Future<void> deleteVariant(String id) async {
    await initialize();
    final tenantId = _requireTenantId();
    final now = DateTime.now();

    final existing = await getVariantById(id);
    if (existing == null) return;

    final record = existing.copyWith(
      synced: false,
      pendingOperation: 'delete',
      pendingSince: now,
      version: existing.version + 1,
    );

    await _variantsBox.put(id, record.toJson());
    await _addToSyncQueue('variant', 'delete', id);

    _syncVariant(record);
  }

  // ==========================================================================
  // TAILORING RECORDS
  // ==========================================================================

  /// Get all tailoring records for a customer (offline-first, tenant-scoped).
  Future<List<TailoringRecord>> getTailoringRecords({
    String? customerId,
    String? invoiceId,
    bool includeDeleted = false,
  }) async {
    await initialize();
    final tenantId = _requireTenantId();

    var records = _tailoringBox.values
        .map((m) => TailoringRecord.fromJson(Map<String, dynamic>.from(m)))
        .where((r) => r.tenantId == tenantId)
        .toList();

    if (!includeDeleted) {
      records = records
          .where((r) => r.status == TailoringStatus.active)
          .toList();
    }

    if (customerId != null) {
      records = records.where((r) => r.customerId == customerId).toList();
    }

    if (invoiceId != null) {
      records = records.where((r) => r.invoiceId == invoiceId).toList();
    }

    return records;
  }

  /// Create a new tailoring record (optimistic local write + sync queue).
  Future<TailoringRecord> createTailoringRecord(TailoringRecord record) async {
    await initialize();
    final tenantId = _requireTenantId();

    // Ensure the record is scoped to the current tenant
    final scoped = record.copyWith(tenantId: tenantId);
    final json = scoped.toJson();
    json['synced'] = false;
    json['pendingOperation'] = 'create';
    json['pendingSince'] = DateTime.now().toIso8601String();
    json['version'] = 1;

    await _tailoringBox.put(scoped.id, json);
    await _addToSyncQueue('tailoring_record', 'create', scoped.id);

    // Fire-and-forget sync attempt
    _syncTailoringRecord(scoped);

    return scoped;
  }

  /// Update a tailoring record (optimistic local write + sync queue).
  Future<TailoringRecord> updateTailoringRecord(TailoringRecord record) async {
    await initialize();
    final tenantId = _requireTenantId();

    final existingRaw = _tailoringBox.get(record.id);
    if (existingRaw == null) {
      throw Exception('Tailoring record not found: ${record.id}');
    }

    final existingVersion = (existingRaw['version'] as int?) ?? 1;

    final json = record.toJson();
    json['synced'] = false;
    json['pendingOperation'] = 'update';
    json['pendingSince'] = DateTime.now().toIso8601String();
    json['version'] = existingVersion + 1;

    await _tailoringBox.put(record.id, json);
    await _addToSyncQueue('tailoring_record', 'update', record.id);

    _syncTailoringRecord(record);

    return record;
  }

  /// Soft-delete a tailoring record (Requirement 9.5, 1.6).
  Future<void> deleteTailoringRecord(String id) async {
    await initialize();
    _requireTenantId();

    final existingRaw = _tailoringBox.get(id);
    if (existingRaw == null) return;

    final existing = TailoringRecord.fromJson(
      Map<String, dynamic>.from(existingRaw),
    );
    final deleted = existing.softDelete();
    final existingVersion = (existingRaw['version'] as int?) ?? 1;

    final json = deleted.toJson();
    json['synced'] = false;
    json['pendingOperation'] = 'delete';
    json['pendingSince'] = DateTime.now().toIso8601String();
    json['version'] = existingVersion + 1;

    await _tailoringBox.put(id, json);
    await _addToSyncQueue('tailoring_record', 'delete', id);

    _syncTailoringRecord(deleted);
  }

  // ==========================================================================
  // INVENTORY ITEMS
  // ==========================================================================

  /// Get all inventory items (offline-first, tenant-scoped).
  Future<List<ClothingInventoryItem>> getInventoryItems({
    String? productId,
  }) async {
    await initialize();
    final tenantId = _requireTenantId();

    var items = _inventoryBox.values
        .map(
          (m) => ClothingInventoryItem.fromJson(Map<String, dynamic>.from(m)),
        )
        .where((item) => item.tenantId == tenantId)
        .toList();

    if (productId != null) {
      items = items.where((item) => item.productId == productId).toList();
    }

    return items;
  }

  /// Create a new inventory item (optimistic local write + sync queue).
  Future<ClothingInventoryItem> createInventoryItem({
    required String productId,
    required String productName,
    int totalStock = 0,
    int priceCents = 0,
    int reorderLevel = 5,
  }) async {
    await initialize();
    final tenantId = _requireTenantId();
    final now = DateTime.now();
    final id = RidGenerator.next(tenantId);

    final item = ClothingInventoryItem(
      id: id,
      tenantId: tenantId,
      productId: productId,
      productName: productName,
      totalStock: totalStock,
      priceCents: priceCents,
      reorderLevel: reorderLevel,
      createdAt: now,
      updatedAt: now,
      synced: false,
      pendingOperation: 'create',
      pendingSince: now,
      version: 1,
    );

    await _inventoryBox.put(id, item.toJson());
    await _addToSyncQueue('inventory_item', 'create', id);

    _syncInventoryItem(item);

    return item;
  }

  /// Update an inventory item (optimistic local write + sync queue).
  Future<ClothingInventoryItem> updateInventoryItem(
    String id, {
    String? productName,
    int? totalStock,
    int? priceCents,
    int? reorderLevel,
  }) async {
    await initialize();
    final tenantId = _requireTenantId();
    final now = DateTime.now();

    final existingRaw = _inventoryBox.get(id);
    if (existingRaw == null) {
      throw Exception('Inventory item not found: $id');
    }

    final existing = ClothingInventoryItem.fromJson(
      Map<String, dynamic>.from(existingRaw),
    );
    if (existing.tenantId != tenantId) {
      throw Exception('Inventory item not found: $id');
    }

    final updated = existing.copyWith(
      productName: productName ?? existing.productName,
      totalStock: totalStock ?? existing.totalStock,
      priceCents: priceCents ?? existing.priceCents,
      reorderLevel: reorderLevel ?? existing.reorderLevel,
      updatedAt: now,
      synced: false,
      pendingOperation: 'update',
      pendingSince: now,
      version: existing.version + 1,
    );

    await _inventoryBox.put(id, updated.toJson());
    await _addToSyncQueue('inventory_item', 'update', id);

    _syncInventoryItem(updated);

    return updated;
  }

  /// Soft-delete an inventory item (marks pendingOperation as 'delete').
  Future<void> deleteInventoryItem(String id) async {
    await initialize();
    final tenantId = _requireTenantId();
    final now = DateTime.now();

    final existingRaw = _inventoryBox.get(id);
    if (existingRaw == null) return;

    final existing = ClothingInventoryItem.fromJson(
      Map<String, dynamic>.from(existingRaw),
    );
    if (existing.tenantId != tenantId) return;

    final deleted = existing.copyWith(
      updatedAt: now,
      synced: false,
      pendingOperation: 'delete',
      pendingSince: now,
      version: existing.version + 1,
    );

    await _inventoryBox.put(id, deleted.toJson());
    await _addToSyncQueue('inventory_item', 'delete', id);

    _syncInventoryItem(deleted);
  }

  // ==========================================================================
  // SYNC QUEUE
  // ==========================================================================

  /// Enqueue a sync-queue entry for a local write (Requirement 12.2).
  ///
  /// **Optimistic local write + enqueue contract:**
  /// Every create/update/delete in this repository follows the same pattern:
  ///   1. Persist the change to the local Hive box immediately (optimistic).
  ///   2. Call [_addToSyncQueue] to enqueue exactly one sync-queue entry.
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
    final tenantId = _resolveTenantId() ?? 'default';
    final id = RidGenerator.next(tenantId);
    await _syncQueueBox.put(id, {
      'id': id,
      'entityType': entityType,
      'operation': operation,
      'entityId': entityId,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
      'lastError': null,
      'failedPermanently': false,
    });
  }

  /// Sync all pending changes (FIFO drain with retry cap).
  ///
  /// On reconnect, drains the queue FIFO. A failing entry retries up to 5
  /// times, is retained until success or limit, marked failed after the limit.
  /// Records are NEVER silently discarded (Requirement 12.4).
  Future<ClothingSyncResult> syncAll() async {
    await initialize();

    int synced = 0;
    int failed = 0;
    final List<String> errors = [];

    final pending = _syncQueueBox.values.toList();

    for (final item in pending) {
      // Skip permanently failed entries
      if (item['failedPermanently'] as bool? ?? false) {
        continue;
      }

      try {
        final entityType = item['entityType'] as String;
        final entityId = item['entityId'] as String;

        switch (entityType) {
          case 'variant':
            final raw = _variantsBox.get(entityId);
            if (raw != null) {
              final record = OfflineVariantRecord.fromJson(
                Map<String, dynamic>.from(raw),
              );
              await _syncVariant(record);
            }
            break;
          case 'tailoring_record':
            final raw = _tailoringBox.get(entityId);
            if (raw != null) {
              final record = TailoringRecord.fromJson(
                Map<String, dynamic>.from(raw),
              );
              await _syncTailoringRecord(record);
            }
            break;
          case 'inventory_item':
            final raw = _inventoryBox.get(entityId);
            if (raw != null) {
              final record = ClothingInventoryItem.fromJson(
                Map<String, dynamic>.from(raw),
              );
              await _syncInventoryItem(record);
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
          // Mark as permanently failed after 5 retries (Requirement 12.4)
          await _syncQueueBox.put(item['id'], {
            ...item,
            'retryCount': retryCount,
            'lastError': e.toString(),
            'failedPermanently': true,
          });
        } else {
          await _syncQueueBox.put(item['id'], {
            ...item,
            'retryCount': retryCount,
            'lastError': e.toString(),
            'failedPermanently': false,
          });
        }
      }
    }

    final permanentlyFailedCount = _syncQueueBox.values
        .where((e) => e['failedPermanently'] as bool? ?? false)
        .length;

    return ClothingSyncResult(
      synced: synced,
      failed: failed,
      totalPending: _syncQueueBox.length,
      failedPermanently: permanentlyFailedCount,
      errors: errors,
    );
  }

  /// Check whether any sync entry has permanently failed.
  Future<bool> hasFailedSyncEntries() async {
    await initialize();
    return _syncQueueBox.values.any(
      (item) => item['failedPermanently'] as bool? ?? false,
    );
  }

  /// Get count of pending (unsynced) entries.
  Future<int> getPendingSyncCount() async {
    await initialize();
    return _syncQueueBox.values
        .where((item) => !(item['failedPermanently'] as bool? ?? false))
        .length;
  }

  /// Get all permanently failed sync entries.
  Future<List<Map<dynamic, dynamic>>> getFailedSyncEntries() async {
    await initialize();
    return _syncQueueBox.values
        .where((item) => item['failedPermanently'] as bool? ?? false)
        .toList();
  }

  /// Retry a permanently-failed sync entry (resets retryCount and failed flag).
  Future<void> retryFailedEntry(String entryId) async {
    await initialize();
    final item = _syncQueueBox.get(entryId);
    if (item == null) return;
    if (item['failedPermanently'] as bool? ?? false) {
      await _syncQueueBox.put(entryId, {
        ...item,
        'retryCount': 0,
        'lastError': null,
        'failedPermanently': false,
      });
    }
  }

  // ==========================================================================
  // INDIVIDUAL SYNC METHODS
  // ==========================================================================

  /// Sync a variant record to the server (version-based reconciliation).
  Future<void> _syncVariant(OfflineVariantRecord record) async {
    try {
      final body = record.toJson();
      body['version'] = record.version;

      final response = await _client.post('/clothing/variants', body: body);

      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      final reconciliation = VersionReconciliation.reconcile(
        localVersion: record.version,
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local
        final serverData = reconciliation.serverData!;
        final updatedVariant = VariantItem(
          id: record.variant.id,
          productId: record.variant.productId,
          color: serverData['color'] as String? ?? record.variant.color,
          size: serverData['size'] as String? ?? record.variant.size,
          sku: serverData['sku'] as String? ?? record.variant.sku,
          barcode: serverData['barcode'] as String? ?? record.variant.barcode,
          priceCents:
              serverData['priceCents'] as int? ?? record.variant.priceCents,
          stock: serverData['stock'] as int? ?? record.variant.stock,
        );

        final synced = OfflineVariantRecord(
          variant: updatedVariant,
          tenantId: record.tenantId,
          synced: true,
          pendingOperation: null,
          pendingSince: null,
          version: serverVersion,
        );
        await _variantsBox.put(record.variant.id, synced.toJson());
      } else {
        // Local is current — mark synced
        final synced = record.copyWith(
          synced: true,
          pendingOperation: null,
          pendingSince: null,
        );
        await _variantsBox.put(record.variant.id, synced.toJson());
      }
    } catch (e) {
      throw Exception('Failed to sync variant: $e');
    }
  }

  /// Sync a tailoring record to the server.
  Future<void> _syncTailoringRecord(TailoringRecord record) async {
    try {
      final body = record.toJson();

      final response = await _client.post(
        '/clothing/tailoring-notes',
        body: body,
      );

      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      final reconciliation = VersionReconciliation.reconcile(
        localVersion: 1,
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        final serverData = reconciliation.serverData!;
        final synced = TailoringRecord.fromJson(serverData);
        final json = synced.toJson();
        json['synced'] = true;
        json['pendingOperation'] = null;
        json['pendingSince'] = null;
        json['version'] = serverVersion;
        await _tailoringBox.put(record.id, json);
      } else {
        final json = record.toJson();
        json['synced'] = true;
        json['pendingOperation'] = null;
        json['pendingSince'] = null;
        await _tailoringBox.put(record.id, json);
      }
    } catch (e) {
      throw Exception('Failed to sync tailoring record: $e');
    }
  }

  /// Sync an inventory item to the server.
  Future<void> _syncInventoryItem(ClothingInventoryItem item) async {
    try {
      final body = item.toJson();
      body['version'] = item.version;

      final response = await _client.post('/clothing/inventory', body: body);

      final responseData = response.data as Map<String, dynamic>?;
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );

      final reconciliation = VersionReconciliation.reconcile(
        localVersion: item.version,
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        final serverData = reconciliation.serverData!;
        final synced = ClothingInventoryItem.fromJson(serverData).copyWith(
          synced: true,
          pendingOperation: null,
          pendingSince: null,
          version: serverVersion,
        );
        await _inventoryBox.put(item.id, synced.toJson());
      } else {
        final synced = item.copyWith(
          synced: true,
          pendingOperation: null,
          pendingSince: null,
        );
        await _inventoryBox.put(item.id, synced.toJson());
      }
    } catch (e) {
      throw Exception('Failed to sync inventory item: $e');
    }
  }
}
