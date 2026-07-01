// ============================================================================
// WEB DATABASE CONNECTION
// ============================================================================
// For web platform, we use Drift's WebDatabase with IndexedDB and sql.js
//
// Author: DukanX Engineering
// Version: 1.1.0
// ============================================================================

import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import 'package:flutter/foundation.dart';

/// Opens a web-compatible database connection
QueryExecutor openConnection() {
  debugPrint('AppDatabase: Opening web database (IndexedDB-based)');

  // WebDatabase.withStorage will automatically attempt to use window.initSqlJs
  // which is provided by the script tag in index.html.
  return WebDatabase.withStorage(
    // ignore: experimental_member_use
    DriftWebStorage.indexedDb('dukanx_enterprise'),
    logStatements: kDebugMode,
  );
}
