/// Offline Mode Scaffolding — analyzes screen files and generates the offline
/// mode implementation code: local SQLite caching for reads, OfflineQueue
/// wiring for writes, and offline indicator/action restrictions.
///
/// Requirements: 8.1, 8.2, 8.5
/// - 8.1: Local SQLite caching for read operations so screens render from cache
/// - 8.2: Wire write screens to the OfflineQueue for mutation storage while offline
/// - 8.5: Apply offline indicator and action restrictions
///
/// Uses existing infrastructure:
/// - `core/sync/offline_queue.dart` (OfflineQueue, OfflineMutation)
/// - `core/offline/offline_ui_indicators.dart` (OfflineIndicatorWidget,
///   OfflineActionGuard, OfflineDataUnavailable, OfflineAwareMixin)
///
/// Author: DukanX Engineering
/// Version: 1.0.0
library;

/// Result of analyzing a screen for offline support status.
class OfflineAnalysisResult {
  /// Whether the screen already has offline support.
  final bool hasOfflineSupport;

  /// Whether the screen performs read operations.
  final bool hasReadOperations;

  /// Whether the screen performs write operations.
  final bool hasWriteOperations;

  /// Whether the screen already uses OfflineIndicatorWidget or OfflineAwareMixin.
  final bool hasOfflineIndicator;

  /// Whether the screen already references OfflineQueue.
  final bool hasQueueWiring;

  /// Whether the screen already uses SQLite/cache for reads.
  final bool hasReadCache;

  /// Detected restricted actions used in this screen.
  final List<String> restrictedActions;

  /// Details about what was detected.
  final String details;

  const OfflineAnalysisResult({
    required this.hasOfflineSupport,
    required this.hasReadOperations,
    required this.hasWriteOperations,
    required this.hasOfflineIndicator,
    required this.hasQueueWiring,
    required this.hasReadCache,
    this.restrictedActions = const [],
    this.details = '',
  });
}

/// Generates offline mode scaffolding for DukanX screens.
///
/// This code generator analyzes screen files and produces:
/// 1. SQLite read-cache code so screens render from local cache when offline
/// 2. OfflineQueue wiring code for mutation storage on write screens
/// 3. Offline indicator wrapper and action restriction code
class OfflineImplementer {
  /// Actions that require real-time server confirmation (Requirement 8.5).
  static const List<String> restrictedActions = [
    'payment_processing',
    'account_deletion',
    'subscription_changes',
  ];

  /// Patterns indicating read operations in a screen.
  static const List<String> _readPatterns = [
    'ListView',
    'DataTable',
    'GridView',
    'FutureBuilder',
    'StreamBuilder',
    '.get(',
    '.query(',
    '.list',
    'fetchAll',
    'getAll',
    'loadData',
    'loadItems',
    'repository.get',
    'repository.list',
    'repository.fetch',
  ];

  /// Patterns indicating write operations in a screen.
  static const List<String> _writePatterns = [
    'TextFormField',
    'Form(',
    'FormBuilder',
    '.post(',
    '.put(',
    '.delete(',
    '.create(',
    '.update(',
    '.save(',
    'submit',
    'onSave',
    'onSubmit',
    'repository.create',
    'repository.update',
    'repository.delete',
    'repository.save',
  ];

  /// Patterns that indicate restricted actions (payment, deletion, subscription).
  static const Map<String, List<String>> _restrictedActionPatterns = {
    'payment_processing': [
      'processPayment',
      'makePayment',
      'payNow',
      'razorpay',
      'payment',
      'PaymentGateway',
      'initiatePayment',
    ],
    'account_deletion': [
      'deleteAccount',
      'removeAccount',
      'deactivateAccount',
      'accountDeletion',
    ],
    'subscription_changes': [
      'upgradePlan',
      'downgradePlan',
      'cancelSubscription',
      'changeSubscription',
      'subscribeToPlan',
      'updateSubscription',
    ],
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if a screen already has offline support implemented.
  ///
  /// A screen has offline support if it uses any of:
  /// - OfflineIndicatorWidget / OfflineModeIndicator wrapper
  /// - OfflineAwareMixin
  /// - OfflineQueue / ScanBillOfflineQueue references
  /// - SQLite cache read patterns (sqflite, drift, hive cache)
  bool hasOfflineSupport(String content) {
    return _hasOfflineIndicator(content) &&
        (_hasQueueWiring(content) || !_hasWriteOperations(content)) &&
        (_hasReadCache(content) || !_hasReadOperations(content));
  }

  /// Performs a full offline analysis of a screen.
  ///
  /// Returns detailed results about what offline support the screen has
  /// and what it still needs.
  OfflineAnalysisResult analyzeScreen(String screenPath, String content) {
    final hasReads = _hasReadOperations(content);
    final hasWrites = _hasWriteOperations(content);
    final hasIndicator = _hasOfflineIndicator(content);
    final hasQueue = _hasQueueWiring(content);
    final hasCache = _hasReadCache(content);
    final restricted = _detectRestrictedActions(content);

    final isComplete =
        hasIndicator && (!hasWrites || hasQueue) && (!hasReads || hasCache);

    final details = StringBuffer();
    if (!hasIndicator) details.writeln('• Missing offline indicator wrapper');
    if (hasReads && !hasCache) details.writeln('• Missing read cache');
    if (hasWrites && !hasQueue) details.writeln('• Missing queue wiring');
    if (restricted.isNotEmpty) {
      details.writeln('• Restricted actions found: ${restricted.join(", ")}');
    }

    return OfflineAnalysisResult(
      hasOfflineSupport: isComplete,
      hasReadOperations: hasReads,
      hasWriteOperations: hasWrites,
      hasOfflineIndicator: hasIndicator,
      hasQueueWiring: hasQueue,
      hasReadCache: hasCache,
      restrictedActions: restricted,
      details: details.toString().trimRight(),
    );
  }

  /// Generates local SQLite caching code for read operations so screens
  /// render from cache when offline.
  ///
  /// - [screenPath]: File path of the screen.
  /// - [content]: Dart source content of the screen.
  /// - [entityType]: The data entity type (e.g., 'invoice', 'student').
  ///
  /// Returns generated Dart code to add SQLite caching.
  /// Requirements: 8.1
  String generateReadCache(
    String screenPath,
    String content,
    String entityType,
  ) {
    final pascalEntity = _toPascalCase(entityType);
    final camelEntity = _toCamelCase(entityType);
    final tableName = '${entityType}_cache';
    final vertical = _deriveVertical(screenPath);

    return '''
// ════════════════════════════════════════════════════════════════════════════
// OFFLINE READ CACHE — $pascalEntity
// ════════════════════════════════════════════════════════════════════════════
// Auto-generated by OfflineImplementer for: $screenPath
// Vertical: $vertical
// Requirement: 8.1 — Local SQLite caching for read operations
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Local SQLite cache for $pascalEntity data.
///
/// Stores fetched data locally so the screen can render from cache
/// when the device is offline.
class ${pascalEntity}OfflineCache {
  static const String _tableName = '$tableName';
  static Database? _db;

  /// Initialize the cache database.
  static Future<void> initialize() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, '${tableName}.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(\'\'\'
          CREATE TABLE IF NOT EXISTS \$_tableName (
            id TEXT PRIMARY KEY,
            tenant_id TEXT NOT NULL,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        \'\'\');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_${tableName}_tenant '
          'ON \$_tableName (tenant_id)',
        );
      },
    );
  }

  /// Store or update a list of ${camelEntity}s in the local cache.
  static Future<void> cacheAll(
    String tenantId,
    List<Map<String, dynamic>> items,
  ) async {
    await initialize();
    final batch = _db!.batch();
    final now = DateTime.now().toIso8601String();
    for (final item in items) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        _tableName,
        {
          'id': id,
          'tenant_id': tenantId,
          'data': jsonEncode(item),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Cache a single $camelEntity item.
  static Future<void> cacheOne(
    String tenantId,
    Map<String, dynamic> item,
  ) async {
    await initialize();
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await _db!.insert(
      _tableName,
      {
        'id': id,
        'tenant_id': tenantId,
        'data': jsonEncode(item),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all cached ${camelEntity}s for a tenant.
  ///
  /// Returns an empty list if no cached data exists.
  static Future<List<Map<String, dynamic>>> getAll(String tenantId) async {
    await initialize();
    final rows = await _db!.query(
      _tableName,
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Retrieve a single cached $camelEntity by ID.
  static Future<Map<String, dynamic>?> getById(String id) async {
    await initialize();
    final rows = await _db!.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  /// Check if any cached data exists for a tenant.
  static Future<bool> hasCachedData(String tenantId) async {
    await initialize();
    final count = Sqflite.firstIntValue(
      await _db!.rawQuery(
        'SELECT COUNT(*) FROM \$_tableName WHERE tenant_id = ?',
        [tenantId],
      ),
    );
    return (count ?? 0) > 0;
  }

  /// Remove a cached item by ID.
  static Future<void> remove(String id) async {
    await initialize();
    await _db!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all cached data for a tenant.
  static Future<void> clearForTenant(String tenantId) async {
    await initialize();
    await _db!.delete(
      _tableName,
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
    );
  }
}
''';
  }

  /// Generates code to wire write operations to the OfflineQueue for
  /// mutation storage while offline.
  ///
  /// - [screenPath]: File path of the screen.
  /// - [content]: Dart source content of the screen.
  /// - [entityType]: The data entity type (e.g., 'invoice', 'product').
  ///
  /// Returns generated Dart code for OfflineQueue integration.
  /// Requirements: 8.2
  String generateWriteQueueWiring(
    String screenPath,
    String content,
    String entityType,
  ) {
    final pascalEntity = _toPascalCase(entityType);
    final camelEntity = _toCamelCase(entityType);
    final vertical = _deriveVertical(screenPath);

    return '''
// ════════════════════════════════════════════════════════════════════════════
// OFFLINE WRITE QUEUE WIRING — $pascalEntity
// ════════════════════════════════════════════════════════════════════════════
// Auto-generated by OfflineImplementer for: $screenPath
// Vertical: $vertical
// Requirement: 8.2 — Wire write screens to OfflineQueue for mutation storage
// ════════════════════════════════════════════════════════════════════════════

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dukanx/core/sync/offline_queue.dart';

/// Handles offline-aware write operations for $pascalEntity.
///
/// When online, calls the repository method directly.
/// When offline, enqueues the mutation to the OfflineQueue for later sync.
class ${pascalEntity}OfflineWriter {
  final OfflineQueue _offlineQueue;
  final String _tenantId;

  ${pascalEntity}OfflineWriter({
    required OfflineQueue offlineQueue,
    required String tenantId,
  })  : _offlineQueue = offlineQueue,
        _tenantId = tenantId;

  /// Creates a $camelEntity — queues to OfflineQueue if offline.
  ///
  /// Returns true if the operation was queued (offline) or succeeded (online).
  Future<bool> create${pascalEntity}(Map<String, dynamic> data) async {
    final isOffline = await _checkOffline();
    if (isOffline) {
      return _enqueue(MutationOperationType.create, data);
    }
    // Online path: caller should invoke repository.create$pascalEntity(data)
    return false; // Indicates online path — caller handles directly
  }

  /// Updates a $camelEntity — queues to OfflineQueue if offline.
  Future<bool> update${pascalEntity}(String id, Map<String, dynamic> data) async {
    final isOffline = await _checkOffline();
    if (isOffline) {
      return _enqueue(
        MutationOperationType.update,
        {'id': id, ...data},
      );
    }
    return false;
  }

  /// Deletes a $camelEntity — queues to OfflineQueue if offline.
  Future<bool> delete${pascalEntity}(String id) async {
    final isOffline = await _checkOffline();
    if (isOffline) {
      return _enqueue(
        MutationOperationType.delete,
        {'id': id},
      );
    }
    return false;
  }

  /// Enqueue mutation to the OfflineQueue.
  Future<bool> _enqueue(
    MutationOperationType operationType,
    Map<String, dynamic> payload,
  ) async {
    if (await _offlineQueue.isAtCapacity) {
      // Requirement 8.8: Reject when at max capacity (5000)
      throw OfflineQueueFullException(
        'Offline queue is full (5000 mutations). '
        'Connect to the internet to sync pending changes.',
      );
    }

    final mutation = OfflineMutation(
      tenantId: _tenantId,
      operationType: operationType,
      entityType: '$entityType',
      payload: payload,
    );

    final result = await _offlineQueue.enqueue(mutation);
    return result.success;
  }

  /// Check if the device is currently offline.
  Future<bool> _checkOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.none);
  }
}

/// Exception thrown when the offline queue is at maximum capacity.
class OfflineQueueFullException implements Exception {
  final String message;
  const OfflineQueueFullException(this.message);

  @override
  String toString() => 'OfflineQueueFullException: \$message';
}
''';
  }

  /// Generates the offline indicator wrapper code for a screen.
  ///
  /// Wraps the screen with:
  /// - OfflineIndicatorWidget (visible offline banner)
  /// - OfflineActionGuard for any restricted actions detected
  /// - OfflineDataUnavailable fallback when no cache exists
  ///
  /// - [screenPath]: File path of the screen.
  ///
  /// Returns generated Dart code for the offline indicator wrapper.
  /// Requirements: 8.5
  String generateOfflineIndicatorWrapper(String screenPath) {
    final vertical = _deriveVertical(screenPath);
    final screenName = _deriveScreenName(screenPath);

    return '''
// ════════════════════════════════════════════════════════════════════════════
// OFFLINE INDICATOR WRAPPER — $screenName
// ════════════════════════════════════════════════════════════════════════════
// Auto-generated by OfflineImplementer for: $screenPath
// Vertical: $vertical
// Requirement: 8.5 — Offline indicator and action restrictions
// ════════════════════════════════════════════════════════════════════════════

import 'package:dukanx/core/offline/offline_ui_indicators.dart';

// ──────────────────────────────────────────────────────────────────────────
// STEP 1: Add OfflineAwareMixin to your State class
// ──────────────────────────────────────────────────────────────────────────
//
// class _${screenName}State extends State<$screenName> with OfflineAwareMixin {
//   ...
// }
//
// ──────────────────────────────────────────────────────────────────────────
// STEP 2: Wrap the screen body with OfflineIndicatorWidget
// ──────────────────────────────────────────────────────────────────────────
//
// @override
// Widget build(BuildContext context) {
//   return OfflineIndicatorWidget(
//     child: _buildContent(context),
//   );
// }
//
// ──────────────────────────────────────────────────────────────────────────
// STEP 3: Handle "no cached data" state (Requirement 8.7)
// ──────────────────────────────────────────────────────────────────────────
//
// Widget _buildContent(BuildContext context) {
//   if (isOffline && !_hasCachedData) {
//     return OfflineDataUnavailable(
//       screenName: '$screenName',
//       allowWriteOnly: true,  // Set to true for screens with write capability
//       onWriteAction: _navigateToCreate,
//       writeActionLabel: 'Create New',
//     );
//   }
//   return _buildMainContent(context);
// }
//
// ──────────────────────────────────────────────────────────────────────────
// STEP 4: Guard restricted actions (Requirement 8.5)
// ──────────────────────────────────────────────────────────────────────────
//
// For payment processing buttons:
//   OfflineActionGuard(
//     actionType: 'payment_processing',
//     child: ElevatedButton(
//       onPressed: _processPayment,
//       child: Text('Pay Now'),
//     ),
//   )
//
// For account deletion:
//   OfflineActionGuard(
//     actionType: 'account_deletion',
//     child: ElevatedButton(
//       onPressed: _deleteAccount,
//       child: Text('Delete Account'),
//     ),
//   )
//
// For subscription changes:
//   OfflineActionGuard(
//     actionType: 'subscription_changes',
//     child: ElevatedButton(
//       onPressed: _changePlan,
//       child: Text('Upgrade Plan'),
//     ),
//   )
//
// ──────────────────────────────────────────────────────────────────────────
// STEP 5: Use guardAction() for programmatic checks
// ──────────────────────────────────────────────────────────────────────────
//
// void _onPaymentTap() {
//   if (!guardAction('payment_processing')) return;
//   // Proceed with payment...
// }
//

/// Generates a fully integrated offline-aware screen widget wrapping the
/// existing $screenName content.
///
/// Drop this into your screen file to add offline support in one step.
Widget build${screenName}WithOfflineSupport({
  required Widget Function(BuildContext context) contentBuilder,
  required bool hasCachedData,
  required bool isOffline,
  VoidCallback? onWriteAction,
  String? writeActionLabel,
}) {
  return OfflineIndicatorWidget(
    child: Builder(
      builder: (context) {
        if (isOffline && !hasCachedData) {
          return OfflineDataUnavailable(
            screenName: '$screenName',
            allowWriteOnly: onWriteAction != null,
            onWriteAction: onWriteAction,
            writeActionLabel: writeActionLabel,
          );
        }
        return contentBuilder(context);
      },
    ),
  );
}
''';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if the screen already has an offline indicator.
  bool _hasOfflineIndicator(String content) {
    final patterns = [
      'OfflineIndicatorWidget',
      'OfflineModeIndicator',
      'OfflineAwareMixin',
      'offline_ui_indicators',
      'offline_mode_indicator',
    ];
    return patterns.any((p) => content.contains(p));
  }

  /// Checks if the screen already has OfflineQueue wiring.
  bool _hasQueueWiring(String content) {
    final patterns = [
      'OfflineQueue',
      'offlineQueue',
      'offline_queue',
      'enqueue(',
      'ScanBillOfflineQueue',
      'AttendanceOfflineQueue',
      'OfflineWriter',
    ];
    return patterns.any((p) => content.contains(p));
  }

  /// Checks if the screen already uses a read cache.
  bool _hasReadCache(String content) {
    final patterns = [
      'OfflineCache',
      'sqflite',
      'openDatabase',
      'getDatabasesPath',
      'Hive.openBox',
      'CacheManager',
      'localCache',
      'getCached',
      'getFromCache',
      'loadFromCache',
      'hasCachedData',
    ];
    return patterns.any((p) => content.contains(p));
  }

  /// Detects if a screen has read operations.
  bool _hasReadOperations(String content) {
    final lower = content.toLowerCase();
    return _readPatterns.any((p) => lower.contains(p.toLowerCase()));
  }

  /// Detects if a screen has write operations.
  bool _hasWriteOperations(String content) {
    final lower = content.toLowerCase();
    return _writePatterns.any((p) => lower.contains(p.toLowerCase()));
  }

  /// Detects restricted actions present in the screen content.
  List<String> _detectRestrictedActions(String content) {
    final detected = <String>[];
    final lower = content.toLowerCase();

    for (final entry in _restrictedActionPatterns.entries) {
      final actionType = entry.key;
      final patterns = entry.value;
      if (patterns.any((p) => lower.contains(p.toLowerCase()))) {
        detected.add(actionType);
      }
    }

    return detected;
  }

  /// Derives the vertical from a file path.
  String _deriveVertical(String path) {
    final normalized = path.replaceAll('\\', '/');
    final featureMatch = RegExp(
      r'lib/features/([^/]+)/',
    ).firstMatch(normalized);
    if (featureMatch != null) {
      return featureMatch.group(1)!;
    }
    return 'core/general';
  }

  /// Derives a human-readable screen name from a file path.
  String _deriveScreenName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final fileName = normalized.split('/').last.replaceAll('.dart', '');

    // Convert snake_case to PascalCase
    return _toPascalCase(fileName);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Converts a snake_case or kebab-case string to PascalCase.
String _toPascalCase(String input) {
  return input
      .split(RegExp(r'[_\-/]'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
      .join();
}

/// Converts a snake_case or kebab-case string to camelCase.
String _toCamelCase(String input) {
  final pascal = _toPascalCase(input);
  if (pascal.isEmpty) return pascal;
  return pascal[0].toLowerCase() + pascal.substring(1);
}
