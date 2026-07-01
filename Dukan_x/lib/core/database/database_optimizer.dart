// ============================================================================
// DATABASE OPTIMIZER
// ============================================================================
// Safe database optimizations for scale without schema-breaking changes.
//
// Features:
// - SQLite WAL mode for better concurrent access
// - Pagination helpers for large collections
// - Firestore index documentation
//
// IMPORTANT: This module only affects configuration and read patterns.
// It does NOT modify any data structures, accounting logic, or business rules.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// Database Optimizer Service
///
/// Provides safe, non-breaking optimizations for database performance.
/// All changes are configuration-only and do not alter data or schema.
class DatabaseOptimizer {
  /// Enable WAL (Write-Ahead Logging) mode for SQLite
  ///
  /// WAL mode provides better concurrent read/write performance:
  /// - Writers don't block readers
  /// - Readers don't block writers
  /// - Better performance for offline-first apps
  ///
  /// SAFE: This is a SQLite configuration change, not a schema change.
  static Future<bool> enableWalMode(AppDatabase db) async {
    try {
      // Check current journal mode
      final currentMode = await db
          .customSelect('PRAGMA journal_mode')
          .getSingle();
      final journalMode = currentMode.data['journal_mode'] as String?;

      if (journalMode?.toLowerCase() == 'wal') {
        debugPrint('[DatabaseOptimizer] WAL mode already enabled');
        return true;
      }

      // Enable WAL mode
      await db.customStatement('PRAGMA journal_mode=WAL');

      // Verify
      final newMode = await db.customSelect('PRAGMA journal_mode').getSingle();
      final success =
          (newMode.data['journal_mode'] as String?)?.toLowerCase() == 'wal';

      if (success) {
        debugPrint('[DatabaseOptimizer] WAL mode enabled successfully');

        // Set optimal WAL configuration
        await db.customStatement(
          'PRAGMA synchronous=NORMAL',
        ); // Good balance of safety/speed
        await db.customStatement(
          'PRAGMA wal_autocheckpoint=1000',
        ); // Checkpoint every 1000 pages
        await db.customStatement('PRAGMA cache_size=-2000'); // 2MB cache
      } else {
        debugPrint('[DatabaseOptimizer] Failed to enable WAL mode');
      }

      return success;
    } catch (e) {
      debugPrint('[DatabaseOptimizer.enableWalMode] error: $e');
      return false;
    }
  }

  /// Get current database optimization status
  static Future<Map<String, dynamic>> getOptimizationStatus(
    AppDatabase db,
  ) async {
    try {
      final journalMode = await db
          .customSelect('PRAGMA journal_mode')
          .getSingle();
      final cacheSize = await db.customSelect('PRAGMA cache_size').getSingle();
      final synchronous = await db
          .customSelect('PRAGMA synchronous')
          .getSingle();
      final pageCount = await db.customSelect('PRAGMA page_count').getSingle();
      final pageSize = await db.customSelect('PRAGMA page_size').getSingle();

      final pages = pageCount.data['page_count'] as int? ?? 0;
      final size = pageSize.data['page_size'] as int? ?? 0;
      final dbSizeBytes = pages * size;

      return {
        'journalMode': journalMode.data['journal_mode'],
        'cacheSize': cacheSize.data['cache_size'],
        'synchronous': synchronous.data['synchronous'],
        'pageCount': pages,
        'pageSize': size,
        'databaseSizeBytes': dbSizeBytes,
        'databaseSizeMB': (dbSizeBytes / 1024 / 1024).toStringAsFixed(2),
        'isOptimized':
            (journalMode.data['journal_mode'] as String?)?.toLowerCase() ==
            'wal',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('[DatabaseOptimizer.getOptimizationStatus] error: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Run VACUUM to optimize database file size (use sparingly)
  ///
  /// SAFE: Does not alter data, only reorganizes for efficiency.
  /// WARNING: VACUUM requires exclusive database access and may take time.
  static Future<bool> vacuumDatabase(AppDatabase db) async {
    try {
      debugPrint('[DatabaseOptimizer] Running VACUUM...');
      await db.customStatement('VACUUM');
      debugPrint('[DatabaseOptimizer] VACUUM completed');
      return true;
    } catch (e) {
      debugPrint('[DatabaseOptimizer.vacuumDatabase] error: $e');
      return false;
    }
  }

  /// Analyze database for query optimization
  ///
  /// SAFE: Read-only operation that updates internal statistics.
  static Future<bool> analyzeDatabase(AppDatabase db) async {
    try {
      await db.customStatement('ANALYZE');
      debugPrint('[DatabaseOptimizer] ANALYZE completed');
      return true;
    } catch (e) {
      debugPrint('[DatabaseOptimizer.analyzeDatabase] error: $e');
      return false;
    }
  }

  /// Runs SQLite's `PRAGMA integrity_check`. Returns `(ok, details)` where ok is
  /// true only when SQLite reports the database is intact. SAFE: read-only.
  static Future<({bool ok, String details})> integrityCheck(
      AppDatabase db) async {
    try {
      final rows = await db.customSelect('PRAGMA integrity_check').get();
      final messages = rows
          .map((r) => r.data.values.first?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final ok = messages.length == 1 && messages.first.toLowerCase() == 'ok';
      return (ok: ok, details: ok ? 'No corruption found.' : messages.join('\n'));
    } catch (e) {
      debugPrint('[DatabaseOptimizer.integrityCheck] error: $e');
      return (ok: false, details: 'Integrity check failed: $e');
    }
  }
}

// ============================================================================
// PAGINATION HELPERS
// ============================================================================

/// Pagination result wrapper
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final bool hasMore;

  PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
  }) : hasMore = (page + 1) * pageSize < totalItems;

  int get totalPages => (totalItems / pageSize).ceil();
  bool get isFirstPage => page == 0;
  bool get isLastPage => !hasMore;

  Map<String, dynamic> toJson() => {
    'items': items.length,
    'page': page,
    'pageSize': pageSize,
    'totalItems': totalItems,
    'totalPages': totalPages,
    'hasMore': hasMore,
  };
}

/// Pagination request parameters
class PaginationParams {
  final int page;
  final int pageSize;

  const PaginationParams({this.page = 0, this.pageSize = 20});

  int get offset => page * pageSize;
  int get limit => pageSize;

  /// Standard page sizes for different use cases
  static const PaginationParams small = PaginationParams(pageSize: 10);
  static const PaginationParams medium = PaginationParams(pageSize: 20);
  static const PaginationParams large = PaginationParams(pageSize: 50);

  PaginationParams nextPage() =>
      PaginationParams(page: page + 1, pageSize: pageSize);
  PaginationParams previousPage() =>
      PaginationParams(page: page > 0 ? page - 1 : 0, pageSize: pageSize);
}

// ============================================================================
// FIRESTORE INDEX DOCUMENTATION
// ============================================================================

/// Recommended Firestore composite indexes for common queries.
///
/// These indexes should be created in Firebase Console or via firestore.indexes.json.
/// This documentation helps track required indexes for production performance.
///
/// IMPORTANT: Creating indexes does not modify data or affect existing queries.
class FirestoreIndexRecommendations {
  /// Index recommendations for bills collection
  static const billsIndexes = '''
  // Collection: users/{userId}/bills
  
  // Index 1: Bills by date (most common query)
  // Fields: billDate DESC, createdAt DESC
  // Usage: Fetching recent bills for dashboard
  
  // Index 2: Bills by customer
  // Fields: customerId ASC, billDate DESC
  // Usage: Customer bill history
  
  // Index 3: Bills by status
  // Fields: status ASC, billDate DESC
  // Usage: Filtering unpaid/pending bills
  
  // Index 4: Bills by payment status
  // Fields: paymentStatus ASC, dueDate ASC
  // Usage: Overdue payment alerts
  ''';

  /// Index recommendations for customers collection
  static const customersIndexes = '''
  // Collection: users/{userId}/customers
  
  // Index 1: Customers by balance
  // Fields: currentBalance DESC
  // Usage: Top debtors report
  
  // Index 2: Customers by last transaction
  // Fields: lastTransactionDate DESC
  // Usage: Active/inactive customer lists
  ''';

  /// Index recommendations for products collection
  static const productsIndexes = '''
  // Collection: users/{userId}/products
  
  // Index 1: Products by stock level
  // Fields: stockQty ASC, category ASC
  // Usage: Low stock alerts
  
  // Index 2: Products by category
  // Fields: category ASC, name ASC
  // Usage: Category-wise product listing
  ''';

  /// Index recommendations for sync queue
  static const syncQueueIndexes = '''
  // Collection: users/{userId}/sync_queue
  
  // Index 1: Pending sync items
  // Fields: status ASC, createdAt ASC
  // Usage: Processing sync queue in order
  
  // Index 2: Failed sync items
  // Fields: status ASC, retryCount DESC
  // Usage: Identifying dead letters
  ''';

  /// Get all index recommendations as formatted string
  static String getAllRecommendations() {
    return '''
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘          FIRESTORE COMPOSITE INDEX RECOMMENDATIONS           â•‘
â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£

$billsIndexes

$customersIndexes

$productsIndexes

$syncQueueIndexes

â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
''';
  }
}
