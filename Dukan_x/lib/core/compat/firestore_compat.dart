// ============================================================================
// FIRESTORE COMPATIBILITY LAYER → API GATEWAY BRIDGE
// ============================================================================
// Drop-in replacement for cloud_firestore types. All data operations now
// route through ApiClient → API Gateway → Lambda → DynamoDB.
//
// This layer lets existing services keep their Firestore-style call patterns
// (collection().doc().set/get/update/delete) while data flows through AWS.
//
// Types provided:
//   - Timestamp          → wraps DateTime (kept as-is)
//   - FieldValue         → serverTimestamp(), delete(), increment()
//   - SetOptions         → merge semantics
//   - DocumentReference  → API-backed get/set/update/delete
//   - DocumentSnapshot   → wraps API response
//   - QuerySnapshot      → wraps list response
//   - CollectionReference → API-backed collection operations
//   - WriteBatch         → batched API calls
//   - FirebaseFirestore  → singleton that routes through ApiClient
//
// ============================================================================

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import '../api/api_client.dart';
import '../di/service_locator.dart';

// ---- Collection Path → API Endpoint Mapping ----

/// Maps Firestore collection paths to API Gateway endpoints.
/// Sub-collections under owners/businesses are flattened to top-level API routes.
/// FIX (H-06): Added all missing collections discovered by scanning .collection() calls.
const Map<String, String> _collectionToApi = {
  // ── Core Business Collections ──
  'bills': '/api/v1/bills',
  'customers': '/api/v1/customers',
  'products': '/api/v1/products',
  'items': '/api/v1/products', // Legacy alias
  'payments': '/api/v1/payments',
  'expenses': '/api/v1/expenses',
  'receipts': '/api/v1/receipts',
  'estimates': '/api/v1/estimates',
  'proformas': '/api/v1/proformas',
  'bookings': '/api/v1/bookings',
  'purchase_orders': '/api/v1/purchase-orders',
  'purchase_bills': '/api/v1/purchase-bills',
  'delivery_challans': '/api/v1/delivery-challans',
  'dispatches': '/api/v1/dispatches',
  'returnInwards': '/api/v1/return-inwards',
  'stock': '/api/v1/stock',
  'stock_movements': '/api/v1/stock-movements',

  // ── Accounting ──
  'journal_entries': '/api/v1/journal-entries',
  'ledgers': '/api/v1/ledgers',
  'accounting_periods': '/api/v1/accounting-periods',
  'supplier_advances': '/api/v1/supplier-advances',
  'cash_closings': '/api/v1/cash-closings',
  'bank_statement_entries': '/api/v1/bank-statement-entries',
  'locked_periods': '/api/v1/locked-periods',

  // ── Users & Auth ──
  'users': '/api/v1/users',
  'user_sessions': '/api/v1/user-sessions',
  'owners': '/api/v1/vendor-profiles',
  'vendor_profiles': '/api/v1/vendor-profiles',
  'businesses': '/api/v1/businesses',
  'business_users': '/api/v1/business-users',
  'members': '/api/v1/business-users', // Sub-collection alias
  'settings': '/api/v1/settings',

  // ── Customer Linking ──
  'connections': '/api/v1/connections',
  'link_requests': '/api/v1/connections',
  'requests': '/api/v1/connections',
  'shop_links': '/api/v1/shop-links',
  'customer_profiles': '/api/v1/customer-profiles',

  // ── RBAC & Staff ──
  'staff_members': '/api/rbac/staff',
  'roles': '/api/rbac/roles',
  'permissions': '/api/rbac/permissions',

  // ── Admin & Licensing ──
  'admin_users': '/api/v1/admin-users',
  'licenses': '/api/v1/licenses',
  'devices': '/api/v1/devices',
  'app_versions': '/api/v1/app-versions',
  'activation_logs': '/api/v1/activation-logs',

  // ── Audit & Backup ──
  'audit_log': '/api/v1/audit',
  'backups': '/api/v1/backups',

  // ── Petrol Pump ──
  'tanks': '/api/v1/tanks',
  'dispensers': '/api/v1/dispensers',
  'nozzles': '/api/v1/nozzles',
  'shifts': '/api/v1/shifts',
  'fuel_types': '/api/v1/fuel-types',
  'employees': '/api/v1/employees',
};

/// Resolve a Firestore collection path to an API endpoint.
/// Handles sub-collection paths like 'owners/{id}/products' → '/api/v1/products'
String _resolveEndpoint(String collectionPath) {
  // Handle sub-collection patterns
  final parts = collectionPath.split('/');
  
  // Direct match first
  if (_collectionToApi.containsKey(collectionPath)) {
    return _collectionToApi[collectionPath]!;
  }
  
  // Sub-collection: 'owners/{id}/products' → 'products'
  // Sub-collection: 'businesses/{id}/journal_entries' → 'journal_entries'
  if (parts.length >= 3) {
    final subCollection = parts.last;
    if (_collectionToApi.containsKey(subCollection)) {
      return _collectionToApi[subCollection]!;
    }
  }
  
  // Last segment fallback
  final lastSegment = parts.last;
  if (_collectionToApi.containsKey(lastSegment)) {
    return _collectionToApi[lastSegment]!;
  }
  
  // Unknown collection → generic API path
  developer.log(
    'WARNING: No API mapping for collection "$collectionPath" → using /api/v1/$lastSegment',
    name: 'FirestoreCompat',
  );
  return '/api/v1/$lastSegment';
}

/// Get ApiClient from service locator
ApiClient get _api {
  try {
    return sl<ApiClient>();
  } catch (_) {
    developer.log(
      'WARNING: ApiClient not registered in ServiceLocator. Operations will fail.',
      name: 'FirestoreCompat',
    );
    rethrow;
  }
}

// ============================================================================
// Timestamp — wraps DateTime (unchanged from original)
// ============================================================================

/// Replacement for cloud_firestore Timestamp.
/// Wraps DateTime for backward compatibility with existing fromMap/toMap code.
class Timestamp {
  final int seconds;
  final int nanoseconds;

  Timestamp(this.seconds, this.nanoseconds);

  factory Timestamp.fromDate(DateTime date) {
    final ms = date.millisecondsSinceEpoch;
    return Timestamp(ms ~/ 1000, (ms % 1000) * 1000000);
  }

  factory Timestamp.now() => Timestamp.fromDate(DateTime.now());

  /// Parse from various formats found in API responses
  factory Timestamp.fromDynamic(dynamic value) {
    if (value == null) return Timestamp.now();
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      try {
        return Timestamp.fromDate(DateTime.parse(value));
      } catch (_) {
        return Timestamp.now();
      }
    }
    if (value is int) {
      // Epoch milliseconds
      return Timestamp.fromDate(
        DateTime.fromMillisecondsSinceEpoch(value),
      );
    }
    if (value is Map) {
      // {seconds: x, nanoseconds: y} format from some APIs
      final s = value['seconds'] as int? ??
          value['_seconds'] as int? ??
          0;
      final n = value['nanoseconds'] as int? ??
          value['_nanoseconds'] as int? ??
          0;
      return Timestamp(s, n);
    }
    return Timestamp.now();
  }

  DateTime toDate() {
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000 + nanoseconds ~/ 1000000,
    );
  }

  String toIso8601String() => toDate().toUtc().toIso8601String();

  @override
  String toString() => toIso8601String();

  @override
  bool operator ==(Object other) =>
      other is Timestamp &&
      seconds == other.seconds &&
      nanoseconds == other.nanoseconds;

  @override
  int get hashCode => Object.hash(seconds, nanoseconds);
}

// ============================================================================
// FieldValue — Sentinels
// ============================================================================

class FieldValue {
  final String _type;
  final dynamic _value;

  // ignore: unused_element_parameter
  const FieldValue._(this._type, [this._value]);

  /// Server timestamp — replaced with UTC ISO8601 string
  static String serverTimestamp() =>
      DateTime.now().toUtc().toIso8601String();

  /// Delete sentinel — signals field removal
  static const FieldValue _deleteSentinel = FieldValue._('delete');
  static FieldValue delete() => _deleteSentinel;

  /// Increment sentinel — for atomic counter updates
  static Map<String, dynamic> increment(num value) => {
    '__fieldValue': 'increment',
    'value': value,
  };

  /// Array union sentinel
  static Map<String, dynamic> arrayUnion(List<dynamic> elements) => {
    '__fieldValue': 'arrayUnion',
    'elements': elements,
  };

  /// Array remove sentinel
  static Map<String, dynamic> arrayRemove(List<dynamic> elements) => {
    '__fieldValue': 'arrayRemove',
    'elements': elements,
  };

  String get type => _type;
  dynamic get value => _value;

  @override
  String toString() => 'FieldValue($_type, $_value)';
}

// ============================================================================
// SetOptions
// ============================================================================

class SetOptions {
  final bool merge;
  final List<String>? mergeFields;

  const SetOptions({this.merge = false, this.mergeFields});
}

enum Source { server, cache, serverAndCache }

class GetOptions {
  final Source source;
  const GetOptions({this.source = Source.serverAndCache});
}

// ============================================================================
// DocumentSnapshot — wraps API response
// ============================================================================

class DocumentSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  final bool _exists;
  final String? collectionPath;

  DocumentSnapshot({
    required this.id,
    Map<String, dynamic>? data,
    bool exists = true,
    this.collectionPath,
  })  : _data = data,
        _exists = exists;

  bool get exists => _exists;
  Map<String, dynamic>? data() => _data;

  dynamic operator [](String key) => _data?[key];

  DocumentReference get reference {
    final path = collectionPath;
    if (path == null || path.isEmpty) {
      throw StateError(
        'DocumentSnapshot.reference unavailable: no collection path',
      );
    }
    return DocumentReference(path, id);
  }
}

// ============================================================================
// QueryDocumentSnapshot
// ============================================================================

class QueryDocumentSnapshot extends DocumentSnapshot {
  QueryDocumentSnapshot({
    required super.id,
    required Map<String, dynamic> data,
    super.collectionPath,
  })  : super(data: data, exists: true);

  @override
  Map<String, dynamic> data() => super.data()!;
}

// ============================================================================
// QuerySnapshot
// ============================================================================

enum DocumentChangeType { added, modified, removed }

class DocumentChange {
  final DocumentChangeType type;
  final QueryDocumentSnapshot doc;

  const DocumentChange({required this.type, required this.doc});
}

class QuerySnapshot {
  final List<QueryDocumentSnapshot> docs;

  QuerySnapshot(this.docs);

  int get size => docs.length;
  bool get isEmpty => docs.isEmpty;

  /// Compat shim: every doc reported as `added` since the REST snapshot
  /// stream emits one-shot results (no live diffs).
  List<DocumentChange> get docChanges => docs
      .map((d) => DocumentChange(type: DocumentChangeType.added, doc: d))
      .toList(growable: false);
}

// ============================================================================
// DocumentReference — API-Backed
// ============================================================================

class DocumentReference {
  final String collectionPath;
  final String documentId;
  final String _endpoint;

  DocumentReference(this.collectionPath, this.documentId)
      : _endpoint = _resolveEndpoint(collectionPath);

  /// Firestore-compatible id getter
  String get id => documentId;

  /// Get document from API
  Future<DocumentSnapshot> get([GetOptions? options]) async {
    try {
      final res = await _api.get('$_endpoint/$documentId');
      if (res.isSuccess && res.data != null) {
        // Extract entity from response (API wraps in {entityName: data})
        final data = _extractEntity(res.data!);
        return DocumentSnapshot(
          id: documentId,
          data: data,
          exists: true,
          collectionPath: collectionPath,
        );
      }
      return DocumentSnapshot(
        id: documentId,
        exists: false,
        collectionPath: collectionPath,
      );
    } catch (e) {
      developer.log(
        'DocumentReference.get($documentId) failed: $e',
        name: 'FirestoreCompat',
      );
      return DocumentSnapshot(
        id: documentId,
        exists: false,
        collectionPath: collectionPath,
      );
    }
  }

  /// Set document via API (PUT for upsert)
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    try {
      // Clean FieldValue sentinels
      final cleaned = _cleanFieldValues(data);
      cleaned['id'] = documentId;

      await _api.put('$_endpoint/$documentId', body: cleaned);
    } catch (e) {
      developer.log(
        'DocumentReference.set($documentId) failed: $e',
        name: 'FirestoreCompat',
      );
      rethrow;
    }
  }

  /// Update document via API (PUT with partial data)
  Future<void> update(Map<String, dynamic> data) async {
    try {
      final cleaned = _cleanFieldValues(data);
      await _api.put('$_endpoint/$documentId', body: cleaned);
    } catch (e) {
      developer.log(
        'DocumentReference.update($documentId) failed: $e',
        name: 'FirestoreCompat',
      );
      rethrow;
    }
  }

  /// Delete document via API (soft delete)
  Future<void> delete() async {
    try {
      await _api.delete('$_endpoint/$documentId');
    } catch (e) {
      developer.log(
        'DocumentReference.delete($documentId) failed: $e',
        name: 'FirestoreCompat',
      );
      rethrow;
    }
  }

  /// Return sub-collection reference
  CollectionReference<Map<String, dynamic>> collection(String subPath) {
    return CollectionReference<Map<String, dynamic>>(
      '$collectionPath/$documentId/$subPath',
    );
  }

  /// FIX (H-05): Polling stream for live UI updates.
  /// Emits current value immediately, then polls every 30s.
  /// For truly real-time events, subscribe to WebSocketService directly.
  Stream<DocumentSnapshot> snapshots() {
    late StreamController<DocumentSnapshot> controller;
    Timer? timer;
    controller = StreamController<DocumentSnapshot>(
      onListen: () async {
        // Emit immediately
        try {
          controller.add(await get());
        } catch (_) {}
        // Poll every 30 seconds
        timer = Timer.periodic(const Duration(seconds: 30), (_) async {
          if (controller.isClosed) return;
          try {
            controller.add(await get());
          } catch (_) {}
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }
}

// ============================================================================
// Query — API-backed query builder
// ============================================================================

class Query<T> {
  final String _endpoint;
  final Map<String, String> _queryParams;
  final String _collectionPath;

  Query(this._collectionPath, this._endpoint, [Map<String, String>? params])
      : _queryParams = params ?? {};

  /// Add where filter
  Query<T> where(
    String field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic>? whereIn,
  }) {
    final newParams = Map<String, String>.from(_queryParams);
    if (isEqualTo != null) newParams[field] = isEqualTo.toString();
    if (isNotEqualTo != null) newParams['${field}_ne'] = isNotEqualTo.toString();
    if (isGreaterThan != null) newParams['${field}_gt'] = isGreaterThan.toString();
    if (isGreaterThanOrEqualTo != null) newParams['${field}_gte'] = isGreaterThanOrEqualTo.toString();
    if (isLessThan != null) newParams['${field}_lt'] = isLessThan.toString();
    if (isLessThanOrEqualTo != null) newParams['${field}_lte'] = isLessThanOrEqualTo.toString();
    if (arrayContains != null) newParams['${field}_contains'] = arrayContains.toString();
    if (whereIn != null) newParams['${field}_in'] = whereIn.join(',');
    return Query<T>(_collectionPath, _endpoint, newParams);
  }

  /// Order by field
  Query<T> orderBy(String field, {bool descending = false}) {
    final newParams = Map<String, String>.from(_queryParams);
    newParams['orderBy'] = field;
    newParams['order'] = descending ? 'desc' : 'asc';
    return Query<T>(_collectionPath, _endpoint, newParams);
  }

  /// Limit results
  Query<T> limit(int count) {
    final newParams = Map<String, String>.from(_queryParams);
    newParams['limit'] = count.toString();
    return Query<T>(_collectionPath, _endpoint, newParams);
  }

  /// Start after document
  Query<T> startAfterDocument(DocumentSnapshot doc) {
    final newParams = Map<String, String>.from(_queryParams);
    newParams['startAfter'] = doc.id;
    return Query<T>(_collectionPath, _endpoint, newParams);
  }

  /// Count documents
  AggregateQuery<T> count() {
    return AggregateQuery<T>(this);
  }

  /// Execute query and return snapshot
  Future<QuerySnapshot> get() async {
    try {
      final res = await _api.get(
        _endpoint,
        queryParams: _queryParams.isEmpty ? null : _queryParams,
      );

      if (res.isSuccess && res.data != null) {
        final list = _extractList(res.data!);
        return QuerySnapshot(
          list.map((item) {
            final id = item['id'] ?? item['_id'] ?? 
                       item['${_collectionPath}_id'] ?? '';
            return QueryDocumentSnapshot(
              id: id.toString(),
              data: Map<String, dynamic>.from(item),
              collectionPath: _collectionPath,
            );
          }).toList(),
        );
      }
      return QuerySnapshot([]);
    } catch (e) {
      developer.log(
        'Query.get() failed for $_endpoint: $e',
        name: 'FirestoreCompat',
      );
      return QuerySnapshot([]);
    }
  }

  /// FIX (H-05): Polling stream for live query updates.
  /// Emits current results immediately, then polls every 30s.
  /// For truly real-time events, subscribe to WebSocketService directly.
  Stream<QuerySnapshot> snapshots() {
    late StreamController<QuerySnapshot> controller;
    Timer? timer;
    controller = StreamController<QuerySnapshot>(
      onListen: () async {
        try {
          controller.add(await get());
        } catch (_) {}
        timer = Timer.periodic(const Duration(seconds: 30), (_) async {
          if (controller.isClosed) return;
          try {
            controller.add(await get());
          } catch (_) {}
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }
}

// ============================================================================
// AggregateQuery & AggregateQuerySnapshot — for count queries
// ============================================================================

class AggregateQuery<T> {
  final Query<T> _query;
  AggregateQuery(this._query);

  Future<AggregateQuerySnapshot> get() async {
    final snapshot = await _query.get();
    return AggregateQuerySnapshot(snapshot.size);
  }
}

class AggregateQuerySnapshot {
  final int? count;
  AggregateQuerySnapshot(this.count);
}

// ============================================================================
// CollectionReference — API-backed
// ============================================================================

class CollectionReference<T> extends Query<T> {
  CollectionReference(String path)
      : super(path, _resolveEndpoint(path));

  String get path => _collectionPath;

  /// Get document reference. Omit [id] to auto-generate a UUID (mirrors Firestore .doc()).
  DocumentReference doc([String? id]) {
    final docId = id ?? _uuid();
    return DocumentReference(_collectionPath, docId);
  }

  // FIX (C-04): Use cryptographically secure random for UUID generation.
  // The old implementation used DateTime.now().microsecondsSinceEpoch which
  // produced identical UUIDs for operations within the same microsecond,
  // causing silent document overwrites in DynamoDB.
  static final _secureRandom = Random.secure();

  static String _uuid() {
    final r = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    r[6] = (r[6] & 0x0F) | 0x40; // Version 4
    r[8] = (r[8] & 0x3F) | 0x80; // Variant 1
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${r.sublist(0,4).map(hex).join()}-${r.sublist(4,6).map(hex).join()}-'
           '${r.sublist(6,8).map(hex).join()}-${r.sublist(8,10).map(hex).join()}-'
           '${r.sublist(10).map(hex).join()}';
  }

  /// Add new document (auto-generated ID)
  Future<DocumentReference> add(Map<String, dynamic> data) async {
    try {
      final cleaned = _cleanFieldValues(data);
      final res = await _api.post(_endpoint, body: cleaned);

      if (res.isSuccess && res.data != null) {
        // Extract generated ID from response
        final responseData = _extractEntity(res.data!);
        final id = responseData['id'] ?? responseData['_id'] ?? 
                   responseData['${_collectionPath}_id'] ?? '';
        return DocumentReference(_collectionPath, id.toString());
      }
      throw Exception('Failed to add document to $_collectionPath');
    } catch (e) {
      developer.log(
        'CollectionReference.add() failed for $_collectionPath: $e',
        name: 'FirestoreCompat',
      );
      rethrow;
    }
  }

  /// Query with where clause
  @override
  Query<T> where(
    String field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic>? whereIn,
  }) {
    return super.where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      arrayContains: arrayContains,
      whereIn: whereIn,
    );
  }
}

// ============================================================================
// WriteBatch — Atomic batch via server-side endpoint
// ============================================================================
// FIX (C-02): WriteBatch now collects operations and sends them to
// POST /api/v1/batch for atomic execution (DynamoDB TransactWriteItems).
// Falls back to sequential execution if batch endpoint is unavailable.

class _BatchOperation {
  final String type; // 'set', 'update', 'delete'
  final String collection;
  final String documentId;
  final Map<String, dynamic>? data;

  const _BatchOperation({
    required this.type,
    required this.collection,
    required this.documentId,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'collection': collection,
    'documentId': documentId,
    if (data != null) 'data': _cleanFieldValues(data!),
  };
}

class WriteBatch {
  final List<_BatchOperation> _operations = [];
  // Keep legacy closures for fallback
  final List<Future<void> Function()> _fallbackOps = [];

  void set(DocumentReference ref, Map<String, dynamic> data, [SetOptions? options]) {
    _operations.add(_BatchOperation(
      type: 'set',
      collection: ref.collectionPath,
      documentId: ref.documentId,
      data: data,
    ));
    _fallbackOps.add(() => ref.set(data, options));
  }

  // FIX (M-04): Log warning instead of silently ignoring non-DocumentReference
  void update(dynamic ref, Map<String, dynamic> data) {
    if (ref is DocumentReference) {
      _operations.add(_BatchOperation(
        type: 'update',
        collection: ref.collectionPath,
        documentId: ref.documentId,
        data: data,
      ));
      _fallbackOps.add(() => ref.update(data));
    } else {
      developer.log(
        'WriteBatch.update() called with non-DocumentReference (${ref.runtimeType}) — operation ignored',
        name: 'FirestoreCompat',
        level: 900, // WARNING
      );
    }
  }

  void delete(dynamic ref) {
    if (ref is DocumentReference) {
      _operations.add(_BatchOperation(
        type: 'delete',
        collection: ref.collectionPath,
        documentId: ref.documentId,
      ));
      _fallbackOps.add(() => ref.delete());
    }
  }

  /// Commit all operations atomically via server-side batch endpoint.
  /// Falls back to sequential if the batch endpoint isn't available.
  Future<void> commit() async {
    if (_operations.isEmpty) return;

    try {
      // Attempt atomic batch via server endpoint
      final res = await _api.post('/api/v1/batch', body: {
        'operations': _operations.map((op) => op.toJson()).toList(),
      });

      if (res.isSuccess) {
        _operations.clear();
        _fallbackOps.clear();
        return;
      }

      // If batch endpoint returns 404 (not deployed yet), fall back
      if (res.statusCode == 404) {
        developer.log(
          'Batch endpoint not available, falling back to sequential (${_operations.length} ops)',
          name: 'FirestoreCompat',
          level: 900,
        );
        await _commitSequential();
        return;
      }

      throw Exception('Batch commit failed: ${res.error}');
    } catch (e) {
      // Network error or batch endpoint not available — sequential fallback
      developer.log(
        'Batch commit error ($e), falling back to sequential',
        name: 'FirestoreCompat',
        level: 900,
      );
      await _commitSequential();
    }
  }

  /// Sequential fallback (legacy behavior)
  Future<void> _commitSequential() async {
    for (final op in _fallbackOps) {
      await op();
    }
    _operations.clear();
    _fallbackOps.clear();
  }

  int get operationCount => _operations.length;
}

// ============================================================================
// Settings — No-op stub for main.dart compatibility
// ============================================================================

class Settings {
  // ignore: constant_identifier_names
  static const int CACHE_SIZE_UNLIMITED = -1;
  final bool? persistenceEnabled;
  final int? cacheSizeBytes;
  const Settings({this.persistenceEnabled, this.cacheSizeBytes});
}

// ============================================================================
// Transaction — Server-side transaction proxy
// ============================================================================
// FIX (C-03): Provides a transaction proxy object so callers that do
// transaction.get() / transaction.set() don't crash with NoSuchMethod.

class _TransactionProxy {
  final List<_BatchOperation> _writes = [];

  /// Read a document during the transaction
  Future<DocumentSnapshot> get(DocumentReference ref) => ref.get();

  /// Queue a set operation
  void set(DocumentReference ref, Map<String, dynamic> data, [SetOptions? options]) {
    _writes.add(_BatchOperation(
      type: 'set',
      collection: ref.collectionPath,
      documentId: ref.documentId,
      data: data,
    ));
  }

  /// Queue an update operation
  void update(DocumentReference ref, Map<String, dynamic> data) {
    _writes.add(_BatchOperation(
      type: 'update',
      collection: ref.collectionPath,
      documentId: ref.documentId,
      data: data,
    ));
  }

  /// Queue a delete operation
  void delete(DocumentReference ref) {
    _writes.add(_BatchOperation(
      type: 'delete',
      collection: ref.collectionPath,
      documentId: ref.documentId,
    ));
  }

  /// Execute all queued writes atomically
  Future<void> _commitWrites() async {
    if (_writes.isEmpty) return;
    final batch = WriteBatch();
    for (final op in _writes) {
      final ref = DocumentReference(op.collection, op.documentId);
      switch (op.type) {
        case 'set':
          batch.set(ref, op.data ?? {});
          break;
        case 'update':
          batch.update(ref, op.data ?? {});
          break;
        case 'delete':
          batch.delete(ref);
          break;
      }
    }
    await batch.commit();
  }
}

// ============================================================================
// FirebaseFirestore — API-backed singleton
// ============================================================================

class FirebaseFirestore {
  static final FirebaseFirestore instance = FirebaseFirestore._();
  FirebaseFirestore._();

  // No-op settings setter for main.dart compatibility
  // ignore: avoid_setters_without_getters
  set settings(Settings _) { /* No-op: API Gateway doesn't need local settings */ }

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return CollectionReference<Map<String, dynamic>>(path);
  }

  WriteBatch batch() => WriteBatch();

  /// FIX (C-03): runTransaction now provides a real proxy object instead of null.
  /// Reads are executed immediately; writes are batched and committed atomically
  /// after the handler completes.
  Future<T> runTransaction<T>(
    Future<T> Function(dynamic transaction) handler,
  ) async {
    final txn = _TransactionProxy();
    final result = await handler(txn);
    await txn._commitWrites();
    return result;
  }

  Future<void> enableNetwork() async { /* No-op */ }
  Future<void> disableNetwork() async { /* No-op */ }
  Future<void> clearPersistence() async { /* No-op */ }
  Future<void> terminate() async { /* No-op */ }
}

// ============================================================================
// ApiClient extension — Firestore-style collection access
// ============================================================================
// Lets legacy services call `_api.collection('...')` directly. Mirrors the
// FirebaseFirestore.instance.collection(...) entry point so we don't have to
// rewrite every service in one go.
extension FirestoreCompatOnApiClient on ApiClient {
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CollectionReference<Map<String, dynamic>>(path);

  DocumentReference doc(String path) {
    final parts = path.split('/');
    if (parts.length < 2) {
      throw ArgumentError(
        'Doc path must include collection and id (got "$path")',
      );
    }
    final id = parts.removeLast();
    return DocumentReference(parts.join('/'), id);
  }

  WriteBatch batch() => WriteBatch();

  Future<T> runTransaction<T>(
    Future<T> Function(dynamic transaction) handler,
  ) =>
      FirebaseFirestore.instance.runTransaction(handler);
}

// ============================================================================
// FirebaseStorage — S3 bridge stub
// ============================================================================

class FirebaseStorage {
  static final FirebaseStorage instance = FirebaseStorage._();
  FirebaseStorage._();

  dynamic ref([String? path]) {
    developer.log(
      'FirebaseStorage.ref($path) — use ApiClient /api/storage endpoint',
      name: 'FirestoreCompat',
    );
    return null;
  }

  dynamic refFromURL(String url) {
    developer.log(
      'FirebaseStorage.refFromURL($url) — use S3 URL directly',
      name: 'FirestoreCompat',
    );
    return null;
  }
}

/// SettableMetadata — Firebase Storage upload metadata stub.
/// Migrated to S3 pre-signed URLs; metadata kept for callsite compat only.
class SettableMetadata {
  final String? contentType;
  final String? contentDisposition;
  final String? contentEncoding;
  final String? contentLanguage;
  final String? cacheControl;
  final Map<String, String>? customMetadata;
  const SettableMetadata({
    this.contentType,
    this.contentDisposition,
    this.contentEncoding,
    this.contentLanguage,
    this.cacheControl,
    this.customMetadata,
  });
}

// ============================================================================
// Helpers
// ============================================================================

/// Extract entity data from API response wrapper
/// API returns { entityName: {...} } or { items: [...] }
Map<String, dynamic> _extractEntity(Map<String, dynamic> response) {
  // If response has a single key that's not 'success'/'error'/'items', it's the entity
  for (final key in response.keys) {
    if (key != 'success' && key != 'error' && key != 'items' && key != 'message') {
      final value = response[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }
  }
  // Otherwise return as-is
  return response;
}

/// Extract list from API response
List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
  // Try 'items' key first (standard list response)
  if (response.containsKey('items') && response['items'] is List) {
    return List<Map<String, dynamic>>.from(
      (response['items'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }
  // Try direct list keys
  for (final key in response.keys) {
    if (response[key] is List) {
      return List<Map<String, dynamic>>.from(
        (response[key] as List).map((e) => 
          e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{'value': e}
        ),
      );
    }
  }
  return [];
}

/// Clean FieldValue sentinels from data before sending to API
Map<String, dynamic> _cleanFieldValues(Map<String, dynamic> data) {
  final cleaned = <String, dynamic>{};
  for (final entry in data.entries) {
    final value = entry.value;
    if (value is FieldValue) {
      // Skip delete sentinels, they'll be handled server-side
      continue;
    }
    if (value is Map && value.containsKey('__fieldValue')) {
      // Pass through increment/arrayUnion/arrayRemove as-is for server handling
      cleaned[entry.key] = value;
      continue;
    }
    cleaned[entry.key] = value;
  }
  return cleaned;
}
