// ============================================================================
// BACKGROUND SYNC RID SERVICE - Sync tracking with batch RIDs
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/request_context/request_context.dart';
import '../../../core/request_context/request_context_provider.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/api/api_client.dart';

/// Background sync service with RID tracking for offline-first sync
class BackgroundSyncRidService {
  final ApiClient _apiClient;
  final RequestContextNotifier _contextNotifier;
  Timer? _syncTimer;
  bool _isSyncing = false;
  
  BackgroundSyncRidService(this._apiClient, this._contextNotifier);
  
  /// Start periodic background sync
  void startPeriodicSync({
    Duration interval = const Duration(minutes: 5),
    required String tenantId,
    required String userId,
  }) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) async {
      await syncPendingOperations(
        tenantId: tenantId,
        userId: userId,
      );
    });
  }
  
  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  /// Sync pending operations with RID tracking
  Future<SyncResult> syncPendingOperations({
    required String tenantId,
    required String userId,
  }) async {
    if (_isSyncing) {
      return SyncResult.skipped('Sync already in progress');
    }
    
    _isSyncing = true;
    
    // Generate master RID for this sync batch
    final syncContext = RequestContext.generate(
      tenantId: tenantId,
      userId: userId,
    );
    
    _contextNotifier.setContext(syncContext);
    
    LoggerService.d('BackgroundSync', '[Sync:${syncContext.shortReference}] Starting sync batch');
    
    final results = <OperationResult>[];
    final pendingOps = await _getPendingOperations();
    
    if (pendingOps.isEmpty) {
      _isSyncing = false;
      return SyncResult.success(
        operationCount: 0,
        syncRid: syncContext.requestId,
      );
    }
    
    for (var i = 0; i < pendingOps.length; i++) {
      final operation = pendingOps[i];
      
      // Create derived RID for each operation: {syncRid}-op{index}
      final derivedRid = '${syncContext.requestId}-op$i';
      final opContext = RequestContext.inherit(
        requestId: derivedRid,
        tenantId: tenantId,
        userId: userId,
        sessionRid: syncContext.requestId, // Parent becomes session
      );
      
      _contextNotifier.setContext(opContext);
      
      try {
        await _syncOperation(operation, opContext);
        results.add(OperationResult.success(
          operationId: operation.id,
          rid: derivedRid,
        ));
        
        // Mark as synced
        await _markOperationSynced(operation.id, derivedRid);
        
      } catch (e) {
        LoggerService.d('BackgroundSync', '[Sync:${opContext.shortReference}] Failed: $e');
        results.add(OperationResult.failure(
          operationId: operation.id,
          rid: derivedRid,
          error: e.toString(),
        ));
        
        // Log error with context
        _logSyncError(operation, opContext, e);
      }
    }
    
    _isSyncing = false;
    _contextNotifier.clear();
    
    // Calculate results
    final successCount = results.where((r) => r.success).length;
    final failureCount = results.where((r) => !r.success).length;
    
    LoggerService.d('BackgroundSync', '[Sync:${syncContext.shortReference}] Complete: $successCount success, $failureCount failed');
    
    return SyncResult(
      success: failureCount == 0,
      operationCount: pendingOps.length,
      successCount: successCount,
      failureCount: failureCount,
      syncRid: syncContext.requestId,
      operationResults: results,
    );
  }
  
  /// Sync single operation with RID context
  Future<void> _syncOperation(
    SyncOperation operation,
    RequestContext context,
  ) async {
    LoggerService.d('BackgroundSync', '[Sync:${context.shortReference}] Syncing ${operation.type}: ${operation.id}');
    
    switch (operation.type) {
      case 'CREATE_BILL':
        await _syncBillCreate(operation, context);
        break;
      case 'UPDATE_STOCK':
        await _syncStockUpdate(operation, context);
        break;
      case 'CREATE_CUSTOMER':
        await _syncCustomerCreate(operation, context);
        break;
      case 'UPDATE_PRODUCT':
        await _syncProductUpdate(operation, context);
        break;
      default:
        throw UnsupportedError('Unknown operation type: ${operation.type}');
    }
  }
  
  Future<void> _syncBillCreate(SyncOperation op, RequestContext ctx) async {
    final response = await _apiClient.post(
      '/bills',
      body: op.data,
    );
    
    if (!response.isSuccess) {
      throw Exception('Bill create failed: ${response.error}');
    }
  }
  
  Future<void> _syncStockUpdate(SyncOperation op, RequestContext ctx) async {
    final response = await _apiClient.patch(
      '/stock/${op.data['productId']}',
      body: op.data,
    );
    
    if (!response.isSuccess) {
      throw Exception('Stock update failed: ${response.error}');
    }
  }
  
  Future<void> _syncCustomerCreate(SyncOperation op, RequestContext ctx) async {
    final response = await _apiClient.post(
      '/customers',
      body: op.data,
    );
    
    if (!response.isSuccess) {
      throw Exception('Customer create failed: ${response.error}');
    }
  }
  
  Future<void> _syncProductUpdate(SyncOperation op, RequestContext ctx) async {
    final response = await _apiClient.put(
      '/products/${op.data['productId']}',
      body: op.data,
    );
    
    if (!response.isSuccess) {
      throw Exception('Product update failed: ${response.error}');
    }
  }
  
  void _logSyncError(SyncOperation operation, RequestContext context, dynamic error) {
    final logData = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'ERROR',
      'type': 'SYNC_FAILED',
      'operationId': operation.id,
      'operationType': operation.type,
      ...context.toLogMap(),
      'error': error.toString(),
    };
    
    LoggerService.d('BackgroundSync', '[Sync Error] ${jsonEncode(logData)}');
  }
  
  static const String _boxName = 'bg_sync_ops';

  Future<Box<String>> get _box async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<String>(_boxName);
    return Hive.openBox<String>(_boxName);
  }

  Future<List<SyncOperation>> _getPendingOperations() async {
    final box = await _box;
    final ops = <SyncOperation>[];
    for (final key in box.keys) {
      final json = box.get(key as String);
      if (json == null) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
        if (map['synced'] == true) continue;
        ops.add(SyncOperation(
          id: map['id'] as String,
          type: map['type'] as String,
          data: Map<String, dynamic>.from(map['data'] as Map),
          createdAt: DateTime.parse(map['createdAt'] as String),
          retryCount: map['retryCount'] as int? ?? 0,
        ));
      } catch (_) {}
    }
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  Future<void> _markOperationSynced(String operationId, String rid) async {
    final box = await _box;
    final json = box.get(operationId);
    if (json != null) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
        map['synced'] = true;
        map['rid'] = rid;
        map['syncedAt'] = DateTime.now().toIso8601String();
        await box.put(operationId, jsonEncode(map));
      } catch (_) {}
    }
    LoggerService.d('BackgroundSync', '[Sync] Marked $operationId as synced (RID: $rid)');
  }
  
  /// Dispose
  void dispose() {
    stopPeriodicSync();
  }
}

/// Sync operation model
class SyncOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  
  SyncOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });
}

/// Sync result
class SyncResult {
  final bool success;
  final int operationCount;
  final int successCount;
  final int failureCount;
  final String syncRid;
  final List<OperationResult> operationResults;
  final String? message;
  
  SyncResult({
    required this.success,
    required this.operationCount,
    required this.successCount,
    required this.failureCount,
    required this.syncRid,
    required this.operationResults,
    this.message,
  });
  
  SyncResult.success({
    required int operationCount,
    required String syncRid,
  }) : this(
    success: true,
    operationCount: operationCount,
    successCount: operationCount,
    failureCount: 0,
    syncRid: syncRid,
    operationResults: [],
  );
  
  SyncResult.skipped(String reason)
    : this(
      success: true,
      operationCount: 0,
      successCount: 0,
      failureCount: 0,
      syncRid: '',
      operationResults: [],
      message: reason,
    );
  
  double get successRate => operationCount > 0 
    ? (successCount / operationCount) * 100 
    : 0;
}

/// Operation result
class OperationResult {
  final String operationId;
  final String rid;
  final bool success;
  final String? error;
  
  OperationResult({
    required this.operationId,
    required this.rid,
    required this.success,
    this.error,
  });
  
  OperationResult.success({
    required this.operationId,
    required this.rid,
  }) : success = true, error = null;
  
  OperationResult.failure({
    required this.operationId,
    required this.rid,
    required String this.error,
  }) : success = false;
}
