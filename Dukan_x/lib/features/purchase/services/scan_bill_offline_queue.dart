// ============================================================================
// Scan Bill Offline Queue Service
// ============================================================================
// P0: Offline Queue - Stores failed submissions and retries them
// when network is available
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/connection_service.dart';
import '../models/scan_bill_models.dart';
import 'scan_bill_api_client.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// Queue item status
enum QueueItemStatus {
  pending,
  processing,
  completed,
  failed,
  maxRetriesExceeded,
}

/// Queue item for offline storage
class QueueItem {
  final String id;
  final String rid;
  final String verticalType;
  final Map<String, dynamic> purchaseEntry;
  final List<String> imagePaths;
  final DateTime createdAt;
  final int retryCount;
  final QueueItemStatus status;
  final String? lastError;
  final DateTime? lastAttempt;

  QueueItem({
    required this.id,
    required this.rid,
    required this.verticalType,
    required this.purchaseEntry,
    required this.imagePaths,
    required this.createdAt,
    this.retryCount = 0,
    this.status = QueueItemStatus.pending,
    this.lastError,
    this.lastAttempt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'rid': rid,
    'verticalType': verticalType,
    'purchaseEntry': purchaseEntry,
    'imagePaths': imagePaths,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'status': status.index,
    'lastError': lastError,
    'lastAttempt': lastAttempt?.toIso8601String(),
  };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
    id: json['id'],
    rid: json['rid'],
    verticalType: json['verticalType'],
    purchaseEntry: json['purchaseEntry'],
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    retryCount: json['retryCount'] ?? 0,
    status: QueueItemStatus.values[json['status'] ?? 0],
    lastError: json['lastError'],
    lastAttempt: json['lastAttempt'] != null 
        ? DateTime.parse(json['lastAttempt']) 
        : null,
  );

  QueueItem copyWith({
    QueueItemStatus? status,
    int? retryCount,
    String? lastError,
    DateTime? lastAttempt,
  }) => QueueItem(
    id: id,
    rid: rid,
    verticalType: verticalType,
    purchaseEntry: purchaseEntry,
    imagePaths: imagePaths,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
    status: status ?? this.status,
    lastError: lastError ?? this.lastError,
    lastAttempt: lastAttempt ?? this.lastAttempt,
  );
}

/// Callback for queue status updates
typedef QueueStatusCallback = void Function(
  int pendingCount,
  int processingCount,
  int completedCount,
  int failedCount,
);

/// Offline queue service for scan bill submissions
class ScanBillOfflineQueue {
  static const String _boxName = 'scan_bill_queue';
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 30);
  static const Duration _maxAge = Duration(hours: 24);
  
  final LoggerService _logger = sl<LoggerService>();
  final ConnectionService _connection = sl<ConnectionService>();
  final ScanBillApiClient _apiClient = sl<ScanBillApiClient>();
  
  Box<String>? _box;
  bool _isInitialized = false;
  bool _isProcessing = false;
  QueueStatusCallback? _statusCallback;

  /// Initialize Hive box
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _box = await Hive.openBox<String>(_boxName);
      _isInitialized = true;
      _logger.info('ScanBillOfflineQueue initialized', {
        'pendingItems': await getPendingCount(),
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize offline queue', 
          {'error': e.toString()}, stackTrace);
      rethrow;
    }
  }

  /// Set status callback for UI updates
  void setStatusCallback(QueueStatusCallback callback) {
    _statusCallback = callback;
  }

  /// Add purchase entry to queue
  Future<String> enqueue({
    required String rid,
    required String verticalType,
    required PurchaseEntry entry,
    required List<File> imageFiles,
  }) async {
    await initialize();
    
    final id = '${rid}_${_nowMs()}';
    final item = QueueItem(
      id: id,
      rid: rid,
      verticalType: verticalType,
      purchaseEntry: entry.toJson(),
      imagePaths: imageFiles.map((f) => f.path).toList(),
      createdAt: DateTime.now(),
    );
    
    await _box!.put(id, jsonEncode(item.toJson()));
    
    _logger.info('Item added to offline queue', {
      'id': id,
      'rid': rid,
      'verticalType': verticalType,
    });
    
    _notifyStatusUpdate();
    
    // Try to process immediately if online
    if (await _connection.isOnline()) {
      processQueue();
    }
    
    return id;
  }

  /// Get all pending items
  Future<List<QueueItem>> getPendingItems() async {
    await initialize();
    
    final items = <QueueItem>[];
    for (final value in _box!.values) {
      try {
        final item = QueueItem.fromJson(jsonDecode(value));
        if (item.status == QueueItemStatus.pending ||
            item.status == QueueItemStatus.failed) {
          // Check if item is too old
          if (DateTime.now().difference(item.createdAt) > _maxAge) {
            await _box!.delete(item.id);
            continue;
          }
          items.add(item);
        }
      } catch (e) {
        _logger.error('Failed to parse queue item', {'error': e.toString()});
      }
    }
    
    return items..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get count of pending items
  Future<int> getPendingCount() async {
    final items = await getPendingItems();
    return items.where((i) => i.status == QueueItemStatus.pending).length;
  }

  /// Get queue statistics
  Future<Map<String, int>> getStats() async {
    await initialize();
    
    final stats = <QueueItemStatus, int>{
      QueueItemStatus.pending: 0,
      QueueItemStatus.processing: 0,
      QueueItemStatus.completed: 0,
      QueueItemStatus.failed: 0,
      QueueItemStatus.maxRetriesExceeded: 0,
    };
    
    for (final value in _box!.values) {
      try {
        final item = QueueItem.fromJson(jsonDecode(value));
        stats[item.status] = (stats[item.status] ?? 0) + 1;
      } catch (e) {
        // Skip invalid items
      }
    }
    
    return {
      'pending': stats[QueueItemStatus.pending]!,
      'processing': stats[QueueItemStatus.processing]!,
      'completed': stats[QueueItemStatus.completed]!,
      'failed': stats[QueueItemStatus.failed]!,
      'maxRetriesExceeded': stats[QueueItemStatus.maxRetriesExceeded]!,
    };
  }

  /// Process the queue
  Future<void> processQueue() async {
    if (_isProcessing) {
      _logger.debug('Queue already processing, skipping');
      return;
    }
    
    if (!await _connection.isOnline()) {
      _logger.debug('Offline, skipping queue processing');
      return;
    }
    
    _isProcessing = true;
    _logger.info('Starting queue processing');
    
    try {
      final items = await getPendingItems();
      
      for (final item in items) {
        if (!await _connection.isOnline()) {
          _logger.info('Went offline during processing, pausing');
          break;
        }
        
        await _processItem(item);
      }
    } catch (e, stackTrace) {
      _logger.error('Queue processing error', {'error': e.toString()}, stackTrace);
    } finally {
      _isProcessing = false;
      _notifyStatusUpdate();
    }
  }

  /// Process a single item
  Future<void> _processItem(QueueItem item) async {
    try {
      // Mark as processing
      await _updateItem(item.copyWith(
        status: QueueItemStatus.processing,
        lastAttempt: DateTime.now(),
      ));
      
      _logger.info('Processing queue item', {
        'id': item.id,
        'rid': item.rid,
        'retryCount': item.retryCount,
      });
      
      // Check if images still exist
      final imageFiles = <File>[];
      for (final path in item.imagePaths) {
        final file = File(path);
        if (await file.exists()) {
          imageFiles.add(file);
        } else {
          _logger.error('Image file not found', {'path': path});
        }
      }
      
      if (imageFiles.isEmpty) {
        throw Exception('No valid image files found');
      }
      
      // Reconstruct purchase entry
      final entry = PurchaseEntry.fromJson(item.purchaseEntry);
      
      // Submit to API
      await _apiClient.createPurchaseEntry(
        entry: entry,
        imageFiles: imageFiles,
      );
      
      // Mark as completed
      await _updateItem(item.copyWith(
        status: QueueItemStatus.completed,
        lastAttempt: DateTime.now(),
      ));
      
      _logger.info('Queue item processed successfully', {
        'id': item.id,
        'rid': item.rid,
      });
      
      // Clean up images after successful submission
      for (final path in item.imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          _logger.error('Failed to cleanup image', {'path': path, 'error': e.toString()});
        }
      }
      
    } catch (e) {
      _logger.error('Failed to process queue item', {
        'id': item.id,
        'error': e.toString(),
        'retryCount': item.retryCount,
      });
      
      final newRetryCount = item.retryCount + 1;
      final newStatus = newRetryCount >= _maxRetries
          ? QueueItemStatus.maxRetriesExceeded
          : QueueItemStatus.failed;
      
      await _updateItem(item.copyWith(
        status: newStatus,
        retryCount: newRetryCount,
        lastError: e.toString(),
        lastAttempt: DateTime.now(),
      ));
      
      // Wait before next retry
      if (newStatus == QueueItemStatus.failed) {
        await Future.delayed(_retryDelay);
      }
    }
  }

  /// Update item in storage
  Future<void> _updateItem(QueueItem item) async {
    await _box!.put(item.id, jsonEncode(item.toJson()));
    _notifyStatusUpdate();
  }

  /// Remove item from queue
  Future<void> removeItem(String id) async {
    await initialize();
    await _box!.delete(id);
    _notifyStatusUpdate();
  }

  /// Clear all completed items
  Future<int> clearCompleted() async {
    await initialize();
    
    var count = 0;
    final keysToDelete = <String>[];
    
    for (final entry in _box!.toMap().entries) {
      try {
        final item = QueueItem.fromJson(jsonDecode(entry.value));
        if (item.status == QueueItemStatus.completed) {
          keysToDelete.add(entry.key);
        }
      } catch (e) {
        keysToDelete.add(entry.key);
      }
    }
    
    for (final key in keysToDelete) {
      await _box!.delete(key);
      count++;
    }
    
    _logger.info('Cleared completed items', {'count': count});
    _notifyStatusUpdate();
    
    return count;
  }

  /// Retry a failed item
  Future<void> retryItem(String id) async {
    await initialize();
    
    final value = _box!.get(id);
    if (value == null) return;
    
    final item = QueueItem.fromJson(jsonDecode(value));
    
    if (item.status == QueueItemStatus.failed ||
        item.status == QueueItemStatus.maxRetriesExceeded) {
      final resetItem = item.copyWith(
        status: QueueItemStatus.pending,
        retryCount: 0,
        lastError: null,
      );
      
      await _updateItem(resetItem);
      
      // Try to process immediately
      if (await _connection.isOnline()) {
        processQueue();
      }
    }
  }

  /// Retry all failed items
  Future<void> retryAllFailed() async {
    await initialize();
    
    for (final value in _box!.values) {
      try {
        final item = QueueItem.fromJson(jsonDecode(value));
        if (item.status == QueueItemStatus.failed ||
            item.status == QueueItemStatus.maxRetriesExceeded) {
          await retryItem(item.id);
        }
      } catch (e) {
        // Skip invalid items
      }
    }
  }

  /// Notify status update callback
  void _notifyStatusUpdate() {
    if (_statusCallback != null) {
      getStats().then((stats) {
        _statusCallback!(
          stats['pending']!,
          stats['processing']!,
          stats['completed']!,
          stats['failed']!,
        );
      });
    }
  }

  /// Get current timestamp in milliseconds
  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Dispose resources
  Future<void> dispose() async {
    await _box?.close();
    _isInitialized = false;
  }
}
