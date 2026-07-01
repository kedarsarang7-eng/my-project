/// Performance Indexes for IMEI/Serial Tracking
/// 
/// This file documents and creates database indexes for optimal
/// query performance with large IMEI datasets (10,000+ records).
library;

import 'package:drift/drift.dart';

/// SQL statements to create performance indexes for IMEI tables
/// Run these migrations for optimal performance
class IMEIPerformanceIndexes {
  
  /// Index 1: Fast lookup by IMEI number
  /// Critical for duplicate prevention and warranty lookup
  static const createIMEILookupIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_lookup 
    ON i_m_e_i_serials(user_id, imei_or_serial, deleted_at);
  ''';

  /// Index 2: Fast status-based queries
  /// Used for "In Stock" availability checks
  static const createStatusIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_status 
    ON i_m_e_i_serials(user_id, status, deleted_at);
  ''';

  /// Index 3: Fast product-based grouping
  /// Used for "Available IMEIs for Product X" queries
  static const createProductIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_product 
    ON i_m_e_i_serials(user_id, product_id, status, deleted_at);
  ''';

  /// Index 4: Fast customer purchase history
  /// Used for warranty lookup by customer
  static const createCustomerIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_customer 
    ON i_m_e_i_serials(user_id, customer_id, sold_date);
  ''';

  /// Index 5: Fast warranty expiration queries
  /// Used for "Warranty Expiring Soon" alerts
  static const createWarrantyExpiryIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_warranty 
    ON i_m_e_i_serials(user_id, warranty_end_date, status) 
    WHERE warranty_end_date IS NOT NULL;
  ''';

  /// Index 6: Fast purchase date sorting
  /// Used for "Recently Added" and purchase history
  static const createPurchaseDateIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_purchase_date 
    ON i_m_e_i_serials(user_id, purchase_date DESC);
  ''';

  /// Index 7: Fast sync status queries
  /// Used for "Pending Sync" operations
  static const createSyncStatusIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_sync 
    ON i_m_e_i_serials(user_id, is_synced) 
    WHERE is_synced = 0;
  ''';

  /// Index 8: Composite index for search
  /// Supports partial IMEI search and brand/model filtering
  static const createSearchIndex = '''
    CREATE INDEX IF NOT EXISTS idx_imei_search 
    ON i_m_e_i_serials(user_id, imei_or_serial, brand, model, product_name);
  ''';

  /// All index creation statements
  static const List<String> allIndexes = [
    createIMEILookupIndex,
    createStatusIndex,
    createProductIndex,
    createCustomerIndex,
    createWarrantyExpiryIndex,
    createPurchaseDateIndex,
    createSyncStatusIndex,
    createSearchIndex,
  ];

  /// Migration to create all indexes
  static Future<void> createAllIndexes(QueryExecutor db) async {
    for (final indexSql in allIndexes) {
      await db.runCustom(indexSql);
    }
  }

  /// Drop all indexes (for migration rollback)
  static const List<String> dropAllIndexes = [
    'DROP INDEX IF EXISTS idx_imei_lookup;',
    'DROP INDEX IF EXISTS idx_imei_status;',
    'DROP INDEX IF EXISTS idx_imei_product;',
    'DROP INDEX IF EXISTS idx_imei_customer;',
    'DROP INDEX IF EXISTS idx_imei_warranty;',
    'DROP INDEX IF EXISTS idx_imei_purchase_date;',
    'DROP INDEX IF EXISTS idx_imei_sync;',
    'DROP INDEX IF EXISTS idx_imei_search;',
  ];
}

/// Performance queries that benefit from these indexes
class IMEIPerformanceQueries {
  
  /// Query 1: Check IMEI availability (uses idx_imei_lookup)
  static const checkAvailability = '''
    SELECT status FROM i_m_e_i_serials
    WHERE user_id = ? 
      AND imei_or_serial = ?
      AND deleted_at IS NULL
    LIMIT 1;
  ''';

  /// Query 2: Get in-stock count for product (uses idx_imei_product)
  static const getInStockCount = '''
    SELECT COUNT(*) FROM i_m_e_i_serials
    WHERE user_id = ?
      AND product_id = ?
      AND status = 'IN_STOCK'
      AND deleted_at IS NULL;
  ''';

  /// Query 3: Get expiring warranty list (uses idx_imei_warranty)
  static const getExpiringWarranty = '''
    SELECT * FROM i_m_e_i_serials
    WHERE user_id = ?
      AND warranty_end_date BETWEEN ? AND ?
      AND status = 'SOLD'
    ORDER BY warranty_end_date ASC;
  ''';

  /// Query 4: Get customer purchase history (uses idx_imei_customer)
  static const getCustomerHistory = '''
    SELECT * FROM i_m_e_i_serials
    WHERE user_id = ?
      AND customer_id = ?
    ORDER BY sold_date DESC;
  ''';

  /// Query 5: Search IMEI partial match (uses idx_imei_search)
  static const searchPartialIMEI = '''
    SELECT * FROM i_m_e_i_serials
    WHERE user_id = ?
      AND imei_or_serial LIKE ?
      AND deleted_at IS NULL
    ORDER BY created_at DESC
    LIMIT 20;
  ''';

  /// Query 6: Get unsynced records (uses idx_imei_sync)
  static const getUnsynced = '''
    SELECT * FROM i_m_e_i_serials
    WHERE user_id = ?
      AND is_synced = 0
    ORDER BY updated_at ASC;
  ''';
}

/// Performance monitoring utilities
class IMEIPerformanceMonitor {
  
  /// Analyze query performance
  static Future<Map<String, dynamic>> analyzePerformance(
    QueryExecutor db,
    String userId,
  ) async {
    // Check table size
    final countResult = await db.runSelect(
      'SELECT COUNT(*) as count FROM i_m_e_i_serials WHERE user_id = ?',
      [userId],
    );
    final recordCount = countResult.first['count'] as int;

    // Check for missing indexes
    final indexResult = await db.runSelect(
      '''
      SELECT name FROM sqlite_master 
      WHERE type = 'index' 
        AND tbl_name = 'i_m_e_i_serials'
        AND name LIKE 'idx_imei_%'
      ''',
      [],
    );
    final existingIndexes = indexResult.map((r) => r['name'] as String).toList();

    return {
      'recordCount': recordCount,
      'existingIndexes': existingIndexes,
      'missingIndexes': IMEIPerformanceIndexes.allIndexes.length - existingIndexes.length,
      'performanceStatus': recordCount > 1000 && existingIndexes.isEmpty
          ? 'WARNING: Large table without indexes'
          : 'OK',
    };
  }

  /// Get query execution plan
  static Future<String> explainQuery(
    QueryExecutor db,
    String query,
    List<Object?> params,
  ) async {
    final result = await db.runSelect('EXPLAIN QUERY PLAN $query', params);
    return result.map((r) => r.toString()).join('\n');
  }
}
