// ============================================================================
// NATIVE DATABASE CONNECTION
// ============================================================================
// Database connection for mobile and desktop platforms
//
// Author: DukanX Engineering
// Version: 1.1.0
// ============================================================================

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

import 'local_store_crypto.dart';

/// Opens a native database connection for mobile/desktop platforms.
///
/// Offline License Activation — task 7.2 (Requirements 8.3, 8.4):
///  - SQLCipher encryption key (PRAGMA key) is applied in the [setup] hook,
///    which runs as the very first statement on the freshly-opened database —
///    the only correct place for a SQLCipher key. It is applied ONLY when a key
///    has been configured via [LocalStoreEncryption]; when none is configured
///    (the default), the database opens exactly as before (no behavioral
///    change for existing, unencrypted installs).
///  - Write-ahead logging (PRAGMA journal_mode = WAL) is enabled in the
///    database's `beforeOpen` callback (see app_database.dart).
///
/// NOTE on isolates: [NativeDatabase.createInBackground] sends the [setup]
/// closure to a background isolate. We therefore read the active key in the
/// current isolate and capture it *by value* in the closure (a plain String is
/// safe to send across isolate boundaries), instead of touching the
/// main-isolate singleton from inside the worker isolate.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dukanx_enterprise.sqlite'));
    debugPrint('AppDatabase: Opening native database at ${file.path}');

    // Snapshot the active SQLCipher key (if any) in this isolate so it can be
    // captured by the cross-isolate setup closure below.
    final cipherKeyHex = LocalStoreEncryption.instance.activeKeyHex;

    return NativeDatabase.createInBackground(
      file,
      setup: (cipherKeyHex == null || cipherKeyHex.isEmpty)
          ? null
          : (db) {
              // SQLCipher raw-key syntax: a 64-char hex string (256-bit key)
              // applied verbatim as  PRAGMA key = "x'<hex>'".  Must be the
              // first statement executed on the connection. On a standard
              // (non-SQLCipher) sqlite3 build this PRAGMA is an inert no-op, so
              // it never breaks existing unencrypted databases.
              db.execute('PRAGMA key = "x\'$cipherKeyHex\'";');
            },
    );
  });
}
