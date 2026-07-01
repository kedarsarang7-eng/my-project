// ============================================================================
// LOCAL_STORE_AUTH_PROBE — production SQLCipher authentication probe (Req 17.12)
// ============================================================================
// Feature: offline-license-activation (Task 18.2 — Security_Layer)
//
// This is the real I/O adapter that backs [StoreTamperDetector]. It opens the
// on-disk Local_Store under the machine-derived SQLCipher key (the same key the
// app uses in `connection_native.dart`) and tries a trivial read. SQLCipher
// authenticates the database lazily on the first read: if the file was copied
// from a DIFFERENT machine/tenant (wrong derived key) or its bytes were
// modified, the per-page HMAC check fails and the read throws — which this
// probe captures as `authenticatedUnderMachineKey: false`. A clean read means
// the store authenticated under THIS machine's binding.
//
// REUSE, DON'T REBUILD:
//   * The key comes from the centralised `LocalStoreEncryption` seam (task
//     18.1 / 7.2) — exactly the value `connection_native.dart` applies. No new
//     key logic here.
//   * The store path mirrors `connection_native.dart`
//     (applicationDocuments/dukanx_enterprise.sqlite).
//   * Opening uses drift's `NativeDatabase` (already a project dependency), so
//     no new package is introduced and the SQLCipher native library loaded by
//     `sqlcipher_flutter_libs` is reused.
//
// SECURITY (Req 17.10): never logs or returns the key/secret. The probe yields
// only booleans.
//
// The probe NEVER throws: an authentication failure is data, not an error.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/local_store_crypto.dart';
import '../../services/logger_service.dart';
import 'store_tamper_detector.dart';

/// File name of the offline Local_Store (matches `connection_native.dart`).
const String _localStoreFileName = 'dukanx_enterprise.sqlite';

const String _logTag = 'StoreAuthProbe';

/// Minimal [QueryExecutorUser] used to drive a one-off open of the store for
/// the authentication probe. It declares no schema work — opening + the first
/// read is all that is needed to force SQLCipher to authenticate.
class _ProbeExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    // No migrations during the probe.
  }
}

/// Builds the default production [StoreAuthProbeRunner] for [StoreTamperDetector].
///
/// Resolves the Local_Store path, snapshots the active SQLCipher key from the
/// [LocalStoreEncryption] seam, and returns a runner that opens the store under
/// that key and attempts a trivial read to confirm authentication.
///
/// When no key is configured (legacy unencrypted install / pre-activation) the
/// runner reports `encryptionConfigured: false`, so the pure decision returns
/// `notApplicable` and forensic mode is never armed.
StoreAuthProbeRunner defaultLocalStoreAuthProbe({
  LocalStoreEncryption? encryption,
}) {
  final enc = encryption ?? LocalStoreEncryption.instance;

  return () async {
    final keyHex = enc.activeKeyHex;
    final encryptionConfigured = keyHex != null && keyHex.isNotEmpty;

    File file;
    try {
      final dir = await getApplicationDocumentsDirectory();
      file = File(p.join(dir.path, _localStoreFileName));
    } catch (e) {
      // Cannot resolve the data directory → nothing to authenticate against.
      LoggerService.w(
        _logTag,
        'Could not resolve Local_Store path for tamper probe; treating as '
        'not-applicable.',
      );
      return const StoreAuthProbe(
        storeExists: false,
        encryptionConfigured: false,
        authenticatedUnderMachineKey: false,
      );
    }

    final storeExists = file.existsSync();

    // Nothing to authenticate when the store is missing or encryption is off.
    if (!storeExists || !encryptionConfigured) {
      return StoreAuthProbe(
        storeExists: storeExists,
        encryptionConfigured: encryptionConfigured,
        authenticatedUnderMachineKey: false,
      );
    }

    final authenticated = await _authenticatesUnderKey(file, keyHex);
    return StoreAuthProbe(
      storeExists: true,
      encryptionConfigured: true,
      authenticatedUnderMachineKey: authenticated,
    );
  };
}

/// Opens [file] applying the SQLCipher raw key and attempts a trivial read.
/// Returns true iff the read succeeds (the store authenticated under the key).
/// Never throws — a failure to authenticate is captured as `false`.
Future<bool> _authenticatesUnderKey(File file, String keyHex) async {
  NativeDatabase? db;
  try {
    db = NativeDatabase(
      file,
      setup: (raw) {
        // SQLCipher raw-key syntax, identical to connection_native.dart. On a
        // standard sqlite3 build this PRAGMA is an inert no-op, so an
        // unencrypted store still reads cleanly (intact).
        raw.execute('PRAGMA key = "x\'$keyHex\'";');
      },
    );

    // Opening + the first read forces SQLCipher to authenticate the pages.
    await db.ensureOpen(_ProbeExecutorUser());
    await db.runSelect('SELECT count(*) FROM sqlite_master;', const []);
    return true;
  } catch (_) {
    // Wrong derived key (swapped store) or modified bytes (tamper): the
    // authenticated read fails. Do NOT log the exception detail to avoid
    // leaking key-related material (Req 17.10).
    LoggerService.w(
      _logTag,
      'Local_Store did not authenticate under the machine-derived key.',
    );
    return false;
  } finally {
    try {
      await db?.close();
    } catch (_) {
      // Best-effort close; ignore.
    }
  }
}
