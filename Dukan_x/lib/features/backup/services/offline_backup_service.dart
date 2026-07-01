import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../../../core/services/logger_service.dart';
import '../../../core/database/app_database.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

enum BackupScheduleFrequency { daily, weekly, manual }

enum BackupStatus { idle, running, success, failed }

class BackupEntry {
  final String id;
  final String path;
  final DateTime createdAt;
  final int sizeBytes;
  final String checksum;
  final BackupScheduleFrequency trigger;
  final bool isExternal;

  const BackupEntry({
    required this.id,
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
    required this.checksum,
    required this.trigger,
    this.isExternal = false,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
        'sizeBytes': sizeBytes,
        'checksum': checksum,
        'trigger': trigger.name,
        'isExternal': isExternal,
      };

  factory BackupEntry.fromJson(Map<String, dynamic> j) => BackupEntry(
        id: j['id'] as String,
        path: j['path'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        sizeBytes: j['sizeBytes'] as int,
        checksum: j['checksum'] as String,
        trigger: BackupScheduleFrequency.values.firstWhere(
          (e) => e.name == j['trigger'],
          orElse: () => BackupScheduleFrequency.manual,
        ),
        isExternal: j['isExternal'] as bool? ?? false,
      );
}

class BackupResult {
  final bool success;
  final BackupEntry? entry;
  final String? error;

  const BackupResult.ok(this.entry)
      : success = true,
        error = null;
  const BackupResult.fail(this.error)
      : success = false,
        entry = null;
}

class RestoreResult {
  final bool success;
  final String? error;
  const RestoreResult.ok()
      : success = true,
        error = null;
  const RestoreResult.fail(this.error) : success = false;
}

// ─── Box name registry — tracks all open boxes dynamically ────────────────────

/// System / cache boxes that should never be included in a backup.
const _excludedBoxNames = {
  'api_response_cache',
  'plan_context_cache',
  'subscription_cache',
  'trial_subscription_cache',
  'barcode_cache',
};

// ─── SharedPreferences keys ───────────────────────────────────────────────────

const _kScheduleFreq = 'offline_backup_schedule_freq';
const _kLastBackup = 'offline_backup_last_backup';
const _kBackupIndex = 'offline_backup_index';
const _kExternalDir = 'offline_backup_external_dir';
const _kBackupAesKey = 'offline_backup_aes_key';

// ─── Isolate helper for ZIP encoding (E8: off main thread) ───────────────────

List<int> _encodeArchiveInIsolate(Archive archive) {
  return ZipEncoder().encode(archive) ?? [];
}

// ─── Service ──────────────────────────────────────────────────────────────────

class OfflineBackupService {
  static final OfflineBackupService _instance = OfflineBackupService._();
  factory OfflineBackupService() => _instance;
  OfflineBackupService._();

  static const int _maxLocalBackups = 14;
  static const String _tag = 'OfflineBackup';

  Timer? _scheduleTimer;
  bool _initialized = false;
  final _uuid = const Uuid();
  final _secure = const FlutterSecureStorage();

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _ensureBackupDir();
    _startScheduleTimer();
    LoggerService.d(_tag, 'OfflineBackupService initialized');
  }

  // ── AES-256 encryption key ────────────────────────────────────────────────

  Future<enc.Key> _getOrCreateAesKey() async {
    final existing = await _secure.read(key: _kBackupAesKey);
    if (existing != null) {
      return enc.Key.fromBase64(existing);
    }
    final key = enc.Key.fromSecureRandom(32);
    await _secure.write(key: _kBackupAesKey, value: key.base64);
    return key;
  }

  /// Encrypts raw bytes with AES-256-CBC. Returns [IV (16 bytes) || ciphertext].
  Future<Uint8List> _encrypt(List<int> plainBytes) async {
    final key = await _getOrCreateAesKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    final result = Uint8List(16 + encrypted.bytes.length);
    result.setAll(0, iv.bytes);
    result.setAll(16, encrypted.bytes);
    return result;
  }

  /// Decrypts bytes produced by [_encrypt]. Expects [IV (16 bytes) || ciphertext].
  Future<Uint8List> _decrypt(Uint8List data) async {
    if (data.length <= 16) throw Exception('Encrypted data too short');
    final key = await _getOrCreateAesKey();
    final iv = enc.IV(Uint8List.fromList(data.sublist(0, 16)));
    final cipherBytes = Uint8List.fromList(data.sublist(16));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  // ── Directory helpers ────────────────────────────────────────────────────────

  Future<Directory> get _internalBackupDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'dukanx_backups'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _ensureBackupDir() async {
    await _internalBackupDir;
  }

  // ── Dynamic box discovery (E7) ─────────────────────────────────────────────

  List<String> _collectOpenBusinessBoxNames() {
    try {
      // Hive.boxes returns names of all currently open boxes.
      // We exclude known cache/system boxes.
      // NOTE: Hive doesn't expose a public .boxes getter in all versions,
      // so we fall back to scanning the known registry list.
      final all = Hive.isAdapterRegistered(0)
          ? <String>[] // Will be augmented below
          : <String>[];
      // Augment: add any extra known box names that are open
      const knownBoxNames = [
        'customers', 'bills', 'payments', 'customer_requests', 'sync_status',
        'jewellery_products', 'gold_rates', 'gold_exchanges', 'jewellery_orders',
        'hallmark_register', 'jewellery_sync_queue', 'narcotic_register',
        'bg_sync_ops', 'scan_bill_offline_queue', 'offline_scan_queue',
        'gold_rate_alerts', 'gold_schemes', 'jewellery_repairs', 'making_charges',
        'print_settings',
      ];
      for (final name in knownBoxNames) {
        if (Hive.isBoxOpen(name) && !_excludedBoxNames.contains(name)) {
          all.add(name);
        }
      }
      return all;
    } catch (_) {
      return [];
    }
  }

  // ── Create backup ────────────────────────────────────────────────────────────

  /// Creates an AES-256 encrypted ZIP backup of all open business Hive boxes
  /// + SharedPreferences.
  /// Reports progress via [onProgress] callback (0.0 → 1.0).
  /// [exportToFolder]: if non-null, also copies the encrypted file there.
  Future<BackupResult> createBackup({
    BackupScheduleFrequency trigger = BackupScheduleFrequency.manual,
    String? exportToFolder,
    void Function(double)? onProgress,
  }) async {
    try {
      LoggerService.d(_tag, 'Starting backup (trigger: ${trigger.name})');
      onProgress?.call(0.05);

      final archive = Archive();
      final boxNames = _collectOpenBusinessBoxNames();
      final total = boxNames.length + 3; // boxes + prefs + manifest + zip
      int done = 0;

      // 1. Collect all open business Hive boxes (E7: dynamic discovery)
      for (final boxName in boxNames) {
        try {
          final box = Hive.box(boxName);
          final data = <String, dynamic>{};
          for (final key in box.keys) {
            final value = box.get(key);
            try {
              data[key.toString()] = value;
            } catch (_) {
              data[key.toString()] = value.toString();
            }
          }
          final jsonBytes = utf8.encode(jsonEncode(data));
          archive.addFile(ArchiveFile('hive/$boxName.json', jsonBytes.length, jsonBytes));
        } catch (e) {
          LoggerService.d(_tag, 'Skipping box $boxName: $e');
        }
        done++;
        onProgress?.call(0.05 + 0.50 * (done / total)); // 5% → 55%
      }

      // 2. SharedPreferences snapshot
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        prefsMap[key] = prefs.get(key);
      }
      final prefsBytes = utf8.encode(jsonEncode(prefsMap));
      archive.addFile(ArchiveFile('prefs.json', prefsBytes.length, prefsBytes));
      done++;
      onProgress?.call(0.05 + 0.50 * (done / total));

      // 2b. Drift/SQLite snapshot — the canonical store for Customers, Products,
      //     Suppliers, Sales, Purchases, Payments, Accounting, Ledgers, etc.
      //     Without this the named modules would not actually be backed up.
      try {
        final dbData = await AppDatabase.instance.exportAllData();
        final dbBytes = utf8.encode(jsonEncode(dbData));
        archive.addFile(
            ArchiveFile('database.json', dbBytes.length, dbBytes));
      } catch (e) {
        LoggerService.d(_tag, 'Drift export failed (non-fatal): $e');
      }

      // 3. Content checksum — SHA-256 over the data files (everything except
      //    the manifest itself), so a restored file can self-validate its
      //    integrity before any data is touched (Phase 3b).
      final contentChecksum = _computeContentChecksum(archive);

      // 4. Manifest
      final manifest = {
        'version': '3.1',
        'appVersion': '1.0.0',
        'createdAt': DateTime.now().toIso8601String(),
        'trigger': trigger.name,
        'boxNames': boxNames,
        'encrypted': true,
        'contentChecksum': contentChecksum,
      };
      final manifestBytes = utf8.encode(jsonEncode(manifest));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      done++;
      onProgress?.call(0.60);

      // 5. Encode ZIP in a background isolate (E8: off main thread)
      final zipBytes = await compute(_encodeArchiveInIsolate, archive);
      if (zipBytes.isEmpty) {
        return const BackupResult.fail('ZIP encoder produced empty output');
      }
      onProgress?.call(0.70);

      // 5. AES-256-CBC encrypt the ZIP (E1: encryption)
      final encryptedBytes = await _encrypt(zipBytes);
      onProgress?.call(0.80);

      // 6. Write to internal backup dir
      final id = _uuid.v4(); // E6: UUID not timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'dukanx_backup_${timestamp}_${id.substring(0, 8)}.dbak';
      final dir = await _internalBackupDir;
      final destFile = File(p.join(dir.path, fileName));
      await destFile.writeAsBytes(encryptedBytes);
      onProgress?.call(0.88);

      // 7. Compute SHA-256 checksum of the *encrypted* file
      final checksum = sha256.convert(encryptedBytes).toString();

      final entry = BackupEntry(
        id: id,
        path: destFile.path,
        createdAt: DateTime.now(),
        sizeBytes: encryptedBytes.length,
        checksum: checksum,
        trigger: trigger,
        isExternal: exportToFolder != null,
      );

      // 8. Export to external folder if specified
      if (exportToFolder != null) {
        try {
          final extFile = File(p.join(exportToFolder, fileName));
          await destFile.copy(extFile.path);
          LoggerService.d(_tag, 'Exported to external: ${extFile.path}');
        } catch (e) {
          LoggerService.d(_tag, 'External export failed (backup still saved internally): $e');
        }
      }

      // 9. Persist index + batch-cleanup old (E4: single write)
      await _addToIndex(entry);
      await _cleanupOldBackups();
      onProgress?.call(0.95);

      // 10. Record last backup time for ALL triggers (E3)
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.setString(_kLastBackup, DateTime.now().toIso8601String());

      onProgress?.call(1.0);
      LoggerService.d(_tag, 'Backup created: ${destFile.path} (${entry.formattedSize})');
      return BackupResult.ok(entry);
    } catch (e, st) {
      LoggerService.d(_tag, 'Backup failed: $e\n$st');
      return BackupResult.fail(e.toString());
    }
  }

  // ── Export to user-chosen folder (file_picker) ────────────────────────────

  /// Opens a folder picker then copies the latest (or given) backup there.
  Future<BackupResult> exportToExternalDrive({
    BackupEntry? entry,
    void Function(double)? onProgress,
  }) async {
    try {
      final chosen = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select destination folder for backup',
      );
      if (chosen == null) return const BackupResult.fail('No folder selected');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kExternalDir, chosen);

      if (entry != null) {
        final src = File(entry.path);
        if (!src.existsSync()) return const BackupResult.fail('Backup file not found');
        final destPath = p.join(chosen, p.basename(entry.path));
        await src.copy(destPath);
        LoggerService.d(_tag, 'Exported existing backup to $destPath');
        return BackupResult.ok(entry);
      } else {
        return createBackup(
          trigger: BackupScheduleFrequency.manual,
          exportToFolder: chosen,
          onProgress: onProgress,
        );
      }
    } catch (e) {
      return BackupResult.fail(e.toString());
    }
  }

  // ── Restore ──────────────────────────────────────────────────────────────────

  /// Restores from an encrypted backup file.
  /// Takes a per-box snapshot BEFORE clearing so it can roll back on failure (E2).
  Future<RestoreResult> restoreFromBackup(
    String backupPath, {
    void Function(double)? onProgress,
  }) async {
    // Snapshot of existing data for rollback (E2)
    final Map<String, Map<String, dynamic>> snapshot = {};

    try {
      onProgress?.call(0.05);
      final file = File(backupPath);
      if (!file.existsSync()) return const RestoreResult.fail('Backup file not found');

      // Decrypt
      final encryptedBytes = await file.readAsBytes();
      late final Uint8List zipBytes;
      try {
        zipBytes = await _decrypt(encryptedBytes);
      } catch (_) {
        // Fallback: try reading as plain ZIP (backups from v2.0 or earlier)
        zipBytes = encryptedBytes;
      }
      onProgress?.call(0.15);

      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(zipBytes);
      } catch (_) {
        return const RestoreResult.fail(
            'Corrupted backup: file is not a valid archive');
      }

      // Integrity gate (Phase 3b): reject corrupted/tampered files BEFORE any
      // data is touched. Validates the manifest and, for v3.1+ backups, the
      // embedded content checksum. Legacy backups skip the checksum compare.
      final integrityError = validateArchiveIntegrity(archive);
      if (integrityError != null) {
        LoggerService.d(_tag, 'Integrity gate rejected restore: $integrityError');
        return RestoreResult.fail(integrityError);
      }
      final manifestFile = archive.findFile('manifest.json')!;
      final manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;
      final version = manifest['version'] as String? ?? '1.0';
      LoggerService.d(_tag, 'Integrity OK — restoring backup version $version from $backupPath');
      onProgress?.call(0.18);

      // Collect Hive files from archive
      final hiveFiles = archive.files.where((f) => f.name.startsWith('hive/')).toList();
      onProgress?.call(0.20);

      // Step 1: Snapshot current data for rollback (E2)
      for (final archiveFile in hiveFiles) {
        final boxName = p.basenameWithoutExtension(archiveFile.name.replaceFirst('hive/', ''));
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          final snap = <String, dynamic>{};
          for (final key in box.keys) {
            snap[key.toString()] = box.get(key);
          }
          snapshot[boxName] = snap;
        }
      }
      onProgress?.call(0.30);

      // Step 2: Restore boxes
      bool hadError = false;
      for (int i = 0; i < hiveFiles.length; i++) {
        final archiveFile = hiveFiles[i];
        final boxName = p.basenameWithoutExtension(archiveFile.name.replaceFirst('hive/', ''));
        try {
          final data = jsonDecode(utf8.decode(archiveFile.content as List<int>)) as Map<String, dynamic>;
          final Box box;
          if (Hive.isBoxOpen(boxName)) {
            box = Hive.box(boxName);
          } else {
            box = await Hive.openBox(boxName);
          }
          await box.clear();
          for (final entry in data.entries) {
            await box.put(entry.key, entry.value);
          }
          LoggerService.d(_tag, 'Restored box: $boxName (${data.length} keys)');
        } catch (e) {
          LoggerService.d(_tag, 'Error restoring box $boxName: $e');
          hadError = true;
        }
        onProgress?.call(0.30 + 0.50 * ((i + 1) / hiveFiles.length));
      }

      if (hadError) {
        // Roll back all boxes to snapshot (E2)
        LoggerService.d(_tag, 'Restore had errors — rolling back to snapshot');
        await _rollbackToSnapshot(snapshot);
        return const RestoreResult.fail('Restore partially failed — rolled back to previous data');
      }

      // Step 3: Restore SharedPreferences (non-system keys only)
      final prefsFile = archive.findFile('prefs.json');
      if (prefsFile != null) {
        try {
          final prefsData = jsonDecode(utf8.decode(prefsFile.content as List<int>)) as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();
          for (final entry in prefsData.entries) {
            if (_isSystemPrefsKey(entry.key)) continue;
            final v = entry.value;
            if (v is bool) {
              await prefs.setBool(entry.key, v);
            } else if (v is int) {
              await prefs.setInt(entry.key, v);
            } else if (v is double) {
              await prefs.setDouble(entry.key, v);
            } else if (v is String) {
              await prefs.setString(entry.key, v);
            }
          }
        } catch (e) {
          LoggerService.d(_tag, 'Prefs restore error (non-fatal): $e');
        }
      }

      // Step 4: Restore the Drift/SQLite database (canonical business data).
      // This is atomic at the DB layer (single transaction); a failure here
      // rolls back the Hive boxes too so the app is not left half-restored.
      final dbFile = archive.findFile('database.json');
      if (dbFile != null) {
        try {
          final raw = jsonDecode(utf8.decode(dbFile.content as List<int>))
              as Map<String, dynamic>;
          final dbData = raw.map((table, rows) => MapEntry(
                table,
                (rows as List)
                    .map((r) => Map<String, dynamic>.from(r as Map))
                    .toList(),
              ));
          await AppDatabase.instance.importAllData(dbData);
          onProgress?.call(0.95);
        } catch (e) {
          LoggerService.d(_tag, 'Drift restore failed — rolling back Hive: $e');
          await _rollbackToSnapshot(snapshot);
          return RestoreResult.fail('Database restore failed: $e');
        }
      }

      onProgress?.call(1.0);
      LoggerService.d(_tag, 'Restore complete');
      return const RestoreResult.ok();
    } catch (e, st) {
      // Roll back to snapshot on unexpected failure (E2)
      LoggerService.d(_tag, 'Restore failed: $e\n$st — rolling back');
      await _rollbackToSnapshot(snapshot);
      return RestoreResult.fail(e.toString());
    }
  }

  Future<void> _rollbackToSnapshot(Map<String, Map<String, dynamic>> snapshot) async {
    for (final entry in snapshot.entries) {
      try {
        final Box box;
        if (Hive.isBoxOpen(entry.key)) {
          box = Hive.box(entry.key);
        } else {
          box = await Hive.openBox(entry.key);
        }
        await box.clear();
        for (final kv in entry.value.entries) {
          await box.put(kv.key, kv.value);
        }
        LoggerService.d(_tag, 'Rollback: restored ${entry.key} (${entry.value.length} keys)');
      } catch (e) {
        LoggerService.d(_tag, 'Rollback error for ${entry.key}: $e');
      }
    }
  }

  /// Let user pick a backup file from anywhere (USB, Downloads etc.)
  Future<String?> pickBackupFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select DukanX Backup File',
      type: FileType.custom,
      allowedExtensions: ['dbak', 'zip'],
    );
    return result?.files.single.path;
  }

  // ── Schedule ─────────────────────────────────────────────────────────────────

  void _startScheduleTimer() {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(hours: 1), (_) => _runScheduledBackupIfDue());
    Future.delayed(const Duration(seconds: 30), _runScheduledBackupIfDue);
  }

  Future<void> _runScheduledBackupIfDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final freqName = prefs.getString(_kScheduleFreq) ?? BackupScheduleFrequency.daily.name;
      final freq = BackupScheduleFrequency.values.firstWhere(
        (e) => e.name == freqName,
        orElse: () => BackupScheduleFrequency.daily,
      );

      if (freq == BackupScheduleFrequency.manual) return;

      final lastStr = prefs.getString(_kLastBackup);
      final last = lastStr != null ? DateTime.tryParse(lastStr) : null;
      final now = DateTime.now();

      bool isDue = false;
      if (last == null) {
        isDue = true;
      } else if (freq == BackupScheduleFrequency.daily && now.difference(last).inHours >= 24) {
        isDue = true;
      } else if (freq == BackupScheduleFrequency.weekly && now.difference(last).inDays >= 7) {
        isDue = true;
      }

      if (isDue) {
        LoggerService.d(_tag, 'Auto-backup due (freq: ${freq.name}), running...');
        final extDir = prefs.getString(_kExternalDir);
        String? exportFolder;
        if (extDir != null && Directory(extDir).existsSync()) {
          exportFolder = extDir;
        }
        await createBackup(trigger: freq, exportToFolder: exportFolder);
      }
    } catch (e) {
      LoggerService.d(_tag, 'Scheduled backup check error: $e');
    }
  }

  Future<void> setScheduleFrequency(BackupScheduleFrequency freq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kScheduleFreq, freq.name);
    LoggerService.d(_tag, 'Schedule frequency set to ${freq.name}');
  }

  Future<BackupScheduleFrequency> getScheduleFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kScheduleFreq) ?? BackupScheduleFrequency.daily.name;
    return BackupScheduleFrequency.values.firstWhere(
      (e) => e.name == name,
      orElse: () => BackupScheduleFrequency.daily,
    );
  }

  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kLastBackup);
    return str != null ? DateTime.tryParse(str) : null;
  }

  /// Returns when the next auto-backup is expected, or null if manual.
  Future<DateTime?> getNextScheduledBackupTime() async {
    final freq = await getScheduleFrequency();
    if (freq == BackupScheduleFrequency.manual) return null;
    final last = await getLastBackupTime();
    if (last == null) return DateTime.now();
    if (freq == BackupScheduleFrequency.daily) return last.add(const Duration(hours: 24));
    return last.add(const Duration(days: 7));
  }

  Future<String?> getSavedExternalDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kExternalDir);
  }

  Future<void> setSavedExternalDir(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_kExternalDir);
    } else {
      await prefs.setString(_kExternalDir, path);
    }
  }

  // ── Backup index ──────────────────────────────────────────────────────────────

  Future<List<BackupEntry>> listBackups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kBackupIndex);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BackupEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => File(e.path).existsSync())
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      LoggerService.d(_tag, 'listBackups error: $e');
      return [];
    }
  }

  Future<void> _addToIndex(BackupEntry entry) async {
    final all = await listBackups();
    all.insert(0, entry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackupIndex, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteBackup(BackupEntry entry) async {
    try {
      final f = File(entry.path);
      if (f.existsSync()) await f.delete();
      // Load index, remove entry, write once
      final all = await listBackups();
      all.removeWhere((e) => e.id == entry.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kBackupIndex, jsonEncode(all.map((e) => e.toJson()).toList()));
    } catch (e) {
      LoggerService.d(_tag, 'deleteBackup error: $e');
    }
  }

  /// Batch-deletes old backups with a single SharedPreferences write (E4).
  Future<void> _cleanupOldBackups() async {
    final all = await listBackups();
    if (all.length <= _maxLocalBackups) return;

    final toDelete = all.sublist(_maxLocalBackups);
    final toKeep = all.sublist(0, _maxLocalBackups);

    // Delete files
    for (final e in toDelete) {
      try {
        final f = File(e.path);
        if (f.existsSync()) await f.delete();
      } catch (err) {
        LoggerService.d(_tag, 'Cleanup file delete error: $err');
      }
    }

    // Single index write (E4)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackupIndex, jsonEncode(toKeep.map((e) => e.toJson()).toList()));
    LoggerService.d(_tag, 'Cleaned up ${toDelete.length} old backup(s)');
  }

  // ── Verify integrity ──────────────────────────────────────────────────────────

  Future<bool> verifyChecksum(BackupEntry entry) async {
    try {
      final bytes = await File(entry.path).readAsBytes();
      final actual = sha256.convert(bytes).toString();
      return actual == entry.checksum;
    } catch (_) {
      return false;
    }
  }

  /// Validates an in-memory backup [archive]'s integrity. Returns null when the
  /// archive is intact (or is a legacy backup without an embedded checksum), or
  /// a human-readable error when it is corrupted/tampered. Exposed for tests so
  /// the Phase 3b "reject before restore" guarantee is directly verifiable.
  @visibleForTesting
  static String? validateArchiveIntegrity(Archive archive) {
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) return 'Invalid backup: missing manifest';
    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      return 'Corrupted backup: unreadable manifest';
    }
    final expected = manifest['contentChecksum'] as String?;
    if (expected == null) return null; // legacy backup — no embedded checksum
    final actual = _computeContentChecksum(archive);
    if (actual != expected) {
      return 'Backup integrity check failed — file is corrupted or incompatible. Restore aborted.';
    }
    return null;
  }

  /// Builds a manifest content checksum for an archive being assembled. Exposed
  /// for tests that construct a backup archive directly.
  @visibleForTesting
  static String contentChecksumFor(Archive archive) =>
      _computeContentChecksum(archive);

  /// Deterministic SHA-256 over every archive entry except the manifest.
  /// File order is normalized so the digest is stable across runs.
  static String _computeContentChecksum(Archive archive) {
    final files = archive.files
        .where((f) => f.name != 'manifest.json')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final buffer = BytesBuilder(copy: false);
    for (final f in files) {
      buffer.add(utf8.encode(f.name));
      buffer.add(f.content as List<int>);
    }
    return sha256.convert(buffer.takeBytes()).toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool _isSystemPrefsKey(String key) {
    const systemPrefixes = [
      'cognito_', 'auth_', 'hive_encryption', 'session_', 'token_',
      'offline_backup_', 'onboarding_',
    ];
    return systemPrefixes.any((prefix) => key.startsWith(prefix));
  }

  void dispose() {
    _scheduleTimer?.cancel();
  }
}
