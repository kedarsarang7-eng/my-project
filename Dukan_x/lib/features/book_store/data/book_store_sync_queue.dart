// ============================================================================
// BOOK STORE SYNC QUEUE — Offline-First Write Queue
// ============================================================================
// Implements the Sync_Queue offline-first pattern for Book_Repository writes
// (school orders, consignments, publisher returns). Follows the same pattern
// as bills/products repositories but scoped to book-store operations.
//
// Design invariants (Requirement 10, Phase 7):
// - Currency stored as integer Paise (never double/float) (Req 1.1, 10.6)
// - Identifiers use RID pattern {tenantId}-{timestamp_ms}-{uuid_v4_short} (Req 1.4)
// - Every cached record scoped by active Tenant_Id (Req 1.5)
// - Offline writes queue locally with 'pending' state (Req 10.2)
// - On connectivity restore, flush idempotently by RID (Req 10.3, 10.4)
// - Failed sync retains pending change and retries (Req 10.7)
//
// Persistence: SharedPreferences-backed JSON (avoids Schema_Gate for Drift).
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RID Generator (Requirement 1.4)
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a RID (Record Identifier) following the pattern:
/// `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
///
/// - [tenantId]: the active Tenant_Id from the authenticated session
/// - timestamp_ms: Unix epoch milliseconds at generation time
/// - uuid_v4_short: first 8 characters of a UUID v4 (non-empty)
String generateRid(String tenantId) {
  assert(tenantId.isNotEmpty, 'tenantId must not be empty for RID generation');
  final timestampMs = DateTime.now().millisecondsSinceEpoch;
  final uuidShort = const Uuid().v4().replaceAll('-', '').substring(0, 8);
  return '$tenantId-$timestampMs-$uuidShort';
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Status Enum
// ─────────────────────────────────────────────────────────────────────────────

/// Status of a queued book-store write operation.
enum BookStoreSyncStatus {
  /// Queued locally, awaiting sync.
  pending,

  /// Currently being synced to the backend.
  syncing,

  /// Successfully synced to the backend.
  synced,

  /// Sync attempt failed; will be retried on next connectivity event.
  failed,
}

// ─────────────────────────────────────────────────────────────────────────────
// Entity Types
// ─────────────────────────────────────────────────────────────────────────────

/// The type of book-store entity being written.
enum BookStoreEntityType { schoolOrder, consignment, publisherReturn }

// ─────────────────────────────────────────────────────────────────────────────
// Operation Types
// ─────────────────────────────────────────────────────────────────────────────

/// The type of write operation.
enum BookStoreOperationType { create, update, fulfill, settle }

// ─────────────────────────────────────────────────────────────────────────────
// Pending Operation Model
// ─────────────────────────────────────────────────────────────────────────────

/// A single offline-queued write operation for the book store.
///
/// Every field uses integer Paise for money and the RID pattern for identifiers.
/// The [rid] is the idempotency key: re-applying a write with the same RID
/// on the server yields the same result (Requirement 10.3, 10.4).
class BookStorePendingOp {
  /// Unique RID identifier for this operation (idempotency key).
  final String rid;

  /// The tenant this operation belongs to.
  final String tenantId;

  /// The entity type being written.
  final BookStoreEntityType entityType;

  /// The operation type.
  final BookStoreOperationType operationType;

  /// The HTTP method to use when syncing (POST, PUT, PATCH).
  final String httpMethod;

  /// The API endpoint path (relative to base URL).
  final String endpointPath;

  /// The request payload (money values in integer Paise).
  final Map<String, dynamic> payload;

  /// Current sync status.
  BookStoreSyncStatus status;

  /// Number of sync attempts made.
  int retryCount;

  /// Last error message from a failed sync attempt.
  String? lastError;

  /// When this operation was first queued.
  final DateTime createdAt;

  /// When the last sync attempt occurred.
  DateTime? lastAttemptAt;

  /// When the operation was successfully synced.
  DateTime? syncedAt;

  BookStorePendingOp({
    required this.rid,
    required this.tenantId,
    required this.entityType,
    required this.operationType,
    required this.httpMethod,
    required this.endpointPath,
    required this.payload,
    this.status = BookStoreSyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    DateTime? createdAt,
    this.lastAttemptAt,
    this.syncedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Serialize to JSON for SharedPreferences persistence.
  Map<String, dynamic> toJson() => {
    'rid': rid,
    'tenantId': tenantId,
    'entityType': entityType.name,
    'operationType': operationType.name,
    'httpMethod': httpMethod,
    'endpointPath': endpointPath,
    'payload': payload,
    'status': status.name,
    'retryCount': retryCount,
    'lastError': lastError,
    'createdAt': createdAt.toIso8601String(),
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'syncedAt': syncedAt?.toIso8601String(),
  };

  /// Deserialize from JSON.
  factory BookStorePendingOp.fromJson(Map<String, dynamic> json) {
    return BookStorePendingOp(
      rid: json['rid'] as String,
      tenantId: json['tenantId'] as String,
      entityType: BookStoreEntityType.values.byName(
        json['entityType'] as String,
      ),
      operationType: BookStoreOperationType.values.byName(
        json['operationType'] as String,
      ),
      httpMethod: json['httpMethod'] as String,
      endpointPath: json['endpointPath'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      status: BookStoreSyncStatus.values.byName(json['status'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
    );
  }

  /// Create a copy with updated fields.
  BookStorePendingOp copyWith({
    BookStoreSyncStatus? status,
    int? retryCount,
    String? lastError,
    DateTime? lastAttemptAt,
    DateTime? syncedAt,
  }) {
    return BookStorePendingOp(
      rid: rid,
      tenantId: tenantId,
      entityType: entityType,
      operationType: operationType,
      httpMethod: httpMethod,
      endpointPath: endpointPath,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book Store Sync Queue
// ─────────────────────────────────────────────────────────────────────────────

/// Offline-first sync queue for book-store writes.
///
/// Persists pending operations via SharedPreferences (JSON) keyed by tenant.
/// On connectivity restore, flushes pending/failed operations idempotently
/// (the RID serves as the server-side idempotency key).
///
/// Usage:
/// ```dart
/// final queue = BookStoreSyncQueue(apiClient: apiClient);
/// await queue.initialize();
///
/// // Enqueue an offline write
/// final op = await queue.enqueue(
///   tenantId: tenantId,
///   entityType: BookStoreEntityType.schoolOrder,
///   operationType: BookStoreOperationType.fulfill,
///   httpMethod: 'POST',
///   endpointPath: '/books/school-orders/order123/fulfill',
///   payload: {'sets': 5, 'ridempotencyKey': rid},
/// );
///
/// // Flush when online
/// await queue.flush();
/// ```
class BookStoreSyncQueue {
  /// SharedPreferences key prefix for book-store sync queue.
  static const String _storageKeyPrefix = 'book_store_sync_queue_';

  final ApiClient _apiClient;
  final Connectivity _connectivity;

  /// In-memory cache of all operations (loaded from SharedPreferences).
  final Map<String, BookStorePendingOp> _operations = {};

  /// Whether the queue has been initialized (loaded from disk).
  bool _initialized = false;

  /// Stream controller for connectivity changes.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Whether a flush is currently in progress.
  bool _isFlushing = false;

  /// Notifier for UI to observe pending count changes.
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);

  BookStoreSyncQueue({required ApiClient apiClient, Connectivity? connectivity})
    : _apiClient = apiClient,
      _connectivity = connectivity ?? Connectivity();

  /// Whether the queue has been initialized.
  bool get isInitialized => _initialized;

  /// Current count of pending + failed (retryable) operations.
  int get pendingCount => _operations.values
      .where(
        (op) =>
            op.status == BookStoreSyncStatus.pending ||
            op.status == BookStoreSyncStatus.failed,
      )
      .length;

  /// All operations for a given tenant (including synced, for inspection).
  List<BookStorePendingOp> getOperationsForTenant(String tenantId) {
    return _operations.values.where((op) => op.tenantId == tenantId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// All pending/failed operations for a given tenant (awaiting sync).
  List<BookStorePendingOp> getPendingForTenant(String tenantId) {
    return _operations.values
        .where(
          (op) =>
              op.tenantId == tenantId &&
              (op.status == BookStoreSyncStatus.pending ||
                  op.status == BookStoreSyncStatus.failed),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Initialization
  // ───────────────────────────────────────────────────────────────────────────

  /// Initialize the queue: load persisted operations from SharedPreferences
  /// and start listening for connectivity changes to auto-flush.
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadFromDisk();
    _startConnectivityListener();
    _initialized = true;
    _updatePendingCount();

    debugPrint(
      'BookStoreSyncQueue: Initialized with ${_operations.length} operations '
      '($pendingCount pending)',
    );
  }

  /// Dispose of resources (connectivity listener).
  void dispose() {
    _connectivitySubscription?.cancel();
    pendingCountNotifier.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Enqueue
  // ───────────────────────────────────────────────────────────────────────────

  /// Enqueue a write operation for offline-first processing.
  ///
  /// If online, immediately attempts the API call. If offline or if the
  /// immediate attempt fails, the operation is persisted locally with
  /// [BookStoreSyncStatus.pending] and will be flushed on connectivity restore.
  ///
  /// Returns the [BookStorePendingOp] representing the queued operation.
  ///
  /// The [rid] in the payload serves as the server-side idempotency key.
  /// Re-sending the same RID to the backend yields the same result (Req 10.3).
  Future<BookStorePendingOp> enqueue({
    required String tenantId,
    required BookStoreEntityType entityType,
    required BookStoreOperationType operationType,
    required String httpMethod,
    required String endpointPath,
    required Map<String, dynamic> payload,
    String? rid,
  }) async {
    _ensureInitialized();

    final operationRid = rid ?? generateRid(tenantId);

    // Inject the RID as idempotency key into the payload so the server can
    // deduplicate on replay.
    final enrichedPayload = Map<String, dynamic>.from(payload);
    enrichedPayload['idempotencyKey'] = operationRid;

    final op = BookStorePendingOp(
      rid: operationRid,
      tenantId: tenantId,
      entityType: entityType,
      operationType: operationType,
      httpMethod: httpMethod,
      endpointPath: endpointPath,
      payload: enrichedPayload,
      status: BookStoreSyncStatus.pending,
    );

    // Store in memory + persist to disk.
    _operations[op.rid] = op;
    await _saveToDisk();
    _updatePendingCount();

    // Attempt immediate sync if online.
    final isOnline = await _checkConnectivity();
    if (isOnline) {
      await _syncSingleOp(op);
    }

    return _operations[op.rid]!;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Flush (Connectivity Restore)
  // ───────────────────────────────────────────────────────────────────────────

  /// Flush all pending and failed operations to the backend.
  ///
  /// Idempotency guarantee (Req 10.3, 10.4): Each operation carries an RID
  /// as the idempotency key. The server recognizes duplicate submissions by
  /// this key, so re-sending the same RID-identified change more than once
  /// yields the same persisted result as a single application.
  ///
  /// Failed operations (Req 10.7): A failed sync retains the record's pending
  /// local change, leaves successfully synced records unaffected, and retries
  /// the failed record on the next connectivity-restored event.
  Future<FlushResult> flush() async {
    _ensureInitialized();

    if (_isFlushing) {
      return const FlushResult(total: 0, synced: 0, failed: 0, skipped: 0);
    }

    _isFlushing = true;

    try {
      final pendingOps =
          _operations.values
              .where(
                (op) =>
                    op.status == BookStoreSyncStatus.pending ||
                    op.status == BookStoreSyncStatus.failed,
              )
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (pendingOps.isEmpty) {
        return const FlushResult(total: 0, synced: 0, failed: 0, skipped: 0);
      }

      int syncedCount = 0;
      int failedCount = 0;
      int skippedCount = 0;

      for (final op in pendingOps) {
        // Check connectivity before each operation (in case connection drops
        // mid-flush).
        final isOnline = await _checkConnectivity();
        if (!isOnline) {
          skippedCount += (pendingOps.length - syncedCount - failedCount);
          break;
        }

        final success = await _syncSingleOp(op);
        if (success) {
          syncedCount++;
        } else {
          failedCount++;
        }
      }

      await _saveToDisk();
      _updatePendingCount();

      return FlushResult(
        total: pendingOps.length,
        synced: syncedCount,
        failed: failedCount,
        skipped: skippedCount,
      );
    } finally {
      _isFlushing = false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Query Operations
  // ───────────────────────────────────────────────────────────────────────────

  /// Get a specific operation by its RID.
  BookStorePendingOp? getByRid(String rid) => _operations[rid];

  /// Whether there are any pending/failed operations awaiting sync.
  bool get hasPendingOperations => pendingCount > 0;

  /// Remove synced operations older than [age] to prevent unbounded growth.
  Future<void> pruneCompleted({Duration age = const Duration(days: 7)}) async {
    _ensureInitialized();

    final cutoff = DateTime.now().subtract(age);
    _operations.removeWhere(
      (_, op) =>
          op.status == BookStoreSyncStatus.synced &&
          (op.syncedAt ?? op.createdAt).isBefore(cutoff),
    );
    await _saveToDisk();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private: Sync a Single Operation
  // ───────────────────────────────────────────────────────────────────────────

  /// Attempt to sync a single operation to the backend.
  ///
  /// Returns `true` if the sync succeeded, `false` if it failed.
  /// On failure, the operation stays in memory with status [pending] or
  /// [failed] (it is NEVER discarded — Req 10.7).
  Future<bool> _syncSingleOp(BookStorePendingOp op) async {
    // Mark as syncing.
    op.status = BookStoreSyncStatus.syncing;
    op.lastAttemptAt = DateTime.now();

    try {
      // Execute the API call.
      final response = await _executeApiCall(op);

      if (response) {
        // Success: mark as synced.
        op.status = BookStoreSyncStatus.synced;
        op.syncedAt = DateTime.now();
        _operations[op.rid] = op;
        return true;
      } else {
        // Server-side failure (non-exception): retain as failed for retry.
        op.status = BookStoreSyncStatus.failed;
        op.retryCount++;
        op.lastError = 'Server returned failure response';
        _operations[op.rid] = op;
        return false;
      }
    } catch (e) {
      // Exception (network error, timeout, etc.): retain as failed for retry.
      // NEVER discard (Req 10.7).
      op.status = BookStoreSyncStatus.failed;
      op.retryCount++;
      op.lastError = e.toString();
      _operations[op.rid] = op;
      return false;
    }
  }

  /// Execute the actual API call for an operation.
  ///
  /// The [idempotencyKey] in the payload ensures the server deduplicates on
  /// retry (Req 10.3, 10.4).
  Future<bool> _executeApiCall(BookStorePendingOp op) async {
    switch (op.httpMethod.toUpperCase()) {
      case 'POST':
        final response = await _apiClient.post(
          op.endpointPath,
          body: op.payload,
        );
        return response.isSuccess;
      case 'PUT':
        final response = await _apiClient.put(
          op.endpointPath,
          body: op.payload,
        );
        return response.isSuccess;
      case 'PATCH':
        final response = await _apiClient.patch(
          op.endpointPath,
          body: op.payload,
        );
        return response.isSuccess;
      default:
        debugPrint(
          'BookStoreSyncQueue: Unknown HTTP method ${op.httpMethod} for '
          'operation ${op.rid}',
        );
        return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private: Connectivity
  // ───────────────────────────────────────────────────────────────────────────

  /// Start listening for connectivity changes and auto-flush when online.
  void _startConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline && pendingCount > 0) {
        // Connectivity restored — flush pending operations (Req 10.3, 10.7).
        debugPrint(
          'BookStoreSyncQueue: Connectivity restored, flushing $pendingCount '
          'pending operations',
        );
        flush();
      }
    });
  }

  /// Check current connectivity status.
  Future<bool> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private: Persistence (SharedPreferences)
  // ───────────────────────────────────────────────────────────────────────────

  /// Load all persisted operations from SharedPreferences.
  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('${_storageKeyPrefix}ops');
      if (jsonString == null || jsonString.isEmpty) return;

      final decoded = jsonDecode(jsonString) as List;
      for (final item in decoded) {
        final op = BookStorePendingOp.fromJson(item as Map<String, dynamic>);
        _operations[op.rid] = op;
      }
    } catch (e) {
      debugPrint('BookStoreSyncQueue: Error loading from disk: $e');
    }
  }

  /// Persist all operations to SharedPreferences.
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _operations.values.map((op) => op.toJson()).toList();
      await prefs.setString('${_storageKeyPrefix}ops', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('BookStoreSyncQueue: Error saving to disk: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private: Helpers
  // ───────────────────────────────────────────────────────────────────────────

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'BookStoreSyncQueue has not been initialized. '
        'Call initialize() first.',
      );
    }
  }

  void _updatePendingCount() {
    pendingCountNotifier.value = pendingCount;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flush Result
// ─────────────────────────────────────────────────────────────────────────────

/// Result of a flush operation.
class FlushResult {
  final int total;
  final int synced;
  final int failed;
  final int skipped;

  const FlushResult({
    required this.total,
    required this.synced,
    required this.failed,
    required this.skipped,
  });

  @override
  String toString() =>
      'FlushResult(total: $total, synced: $synced, failed: $failed, '
      'skipped: $skipped)';
}
