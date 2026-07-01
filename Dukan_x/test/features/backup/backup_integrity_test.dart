// Phase 3b — backup integrity gate + Phase 3a — destination platform gating.
//
// These tests exercise the pure, dependency-free cores:
//   * OfflineBackupService.validateArchiveIntegrity rejects corrupted/tampered
//     archives BEFORE any restore work begins, and accepts intact ones.
//   * BackupDestination platform gating only offers desktop-only destinations
//     on desktop targets.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/backup/services/offline_backup_service.dart';
import 'package:dukanx/features/backup/models/backup_destination.dart';

Archive _buildArchive({required bool withChecksum, String payload = 'hello'}) {
  final archive = Archive();
  final hiveBytes = utf8.encode(jsonEncode({'k': payload}));
  archive.addFile(ArchiveFile('hive/customers.json', hiveBytes.length, hiveBytes));
  final prefsBytes = utf8.encode(jsonEncode({'x': 1}));
  archive.addFile(ArchiveFile('prefs.json', prefsBytes.length, prefsBytes));

  final manifest = <String, dynamic>{
    'version': withChecksum ? '3.1' : '3.0',
    'boxNames': ['customers'],
  };
  if (withChecksum) {
    manifest['contentChecksum'] =
        OfflineBackupService.contentChecksumFor(archive);
  }
  final mBytes = utf8.encode(jsonEncode(manifest));
  archive.addFile(ArchiveFile('manifest.json', mBytes.length, mBytes));
  return archive;
}

void main() {
  group('Phase 3b — restore integrity gate', () {
    test('accepts an intact v3.1 archive', () {
      final archive = _buildArchive(withChecksum: true);
      expect(OfflineBackupService.validateArchiveIntegrity(archive), isNull);
    });

    test('rejects an archive whose data was tampered after checksumming', () {
      // Checksum is computed against the original payload, then a tampered
      // archive is rebuilt carrying that stale checksum.
      final original = _buildArchive(withChecksum: true);
      final staleChecksum = (jsonDecode(utf8.decode(
              original.findFile('manifest.json')!.content as List<int>))
          as Map<String, dynamic>)['contentChecksum'] as String;

      final tampered = Archive();
      final evil = utf8.encode(jsonEncode({'k': 'EVIL'}));
      tampered.addFile(ArchiveFile('hive/customers.json', evil.length, evil));
      final prefs = utf8.encode(jsonEncode({'x': 1}));
      tampered.addFile(ArchiveFile('prefs.json', prefs.length, prefs));
      final manifest = utf8.encode(jsonEncode({
        'version': '3.1',
        'boxNames': ['customers'],
        'contentChecksum': staleChecksum,
      }));
      tampered.addFile(
          ArchiveFile('manifest.json', manifest.length, manifest));

      final error = OfflineBackupService.validateArchiveIntegrity(tampered);
      expect(error, isNotNull);
      expect(error, contains('integrity check failed'));
    });

    test('rejects an archive with a missing manifest', () {
      final archive = Archive();
      final bytes = utf8.encode(jsonEncode({'k': 'v'}));
      archive.addFile(ArchiveFile('hive/customers.json', bytes.length, bytes));
      expect(
        OfflineBackupService.validateArchiveIntegrity(archive),
        contains('missing manifest'),
      );
    });

    test('allows a legacy backup without an embedded checksum', () {
      final archive = _buildArchive(withChecksum: false);
      expect(OfflineBackupService.validateArchiveIntegrity(archive), isNull);
    });

    test('checksum is deterministic for identical content', () {
      final a = _buildArchive(withChecksum: false);
      final b = _buildArchive(withChecksum: false);
      expect(
        OfflineBackupService.contentChecksumFor(a),
        OfflineBackupService.contentChecksumFor(b),
      );
    });
  });

  group('Phase 3a — destination platform gating', () {
    test('Drive and Local are always available', () {
      expect(BackupDestination.googleDrive.requiresDesktop, isFalse);
      expect(BackupDestination.localDevice.requiresDesktop, isFalse);
    });

    test('USB/SSD/HDD/Network require desktop', () {
      for (final d in [
        BackupDestination.usbDrive,
        BackupDestination.externalSsd,
        BackupDestination.externalHardDrive,
        BackupDestination.networkStorage,
      ]) {
        expect(d.requiresDesktop, isTrue, reason: '${d.label} must be desktop-only');
      }
    });

    test('mobile target hides desktop-only destinations', () {
      final original = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = original);

      final available = BackupDestination.availableDestinations();
      expect(available, contains(BackupDestination.googleDrive));
      expect(available, contains(BackupDestination.localDevice));
      expect(available, isNot(contains(BackupDestination.usbDrive)));
      expect(available, isNot(contains(BackupDestination.networkStorage)));
    });

    test('desktop target exposes all destinations', () {
      final original = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = original);

      final available = BackupDestination.availableDestinations();
      expect(available.length, BackupDestination.values.length);
      expect(available, contains(BackupDestination.usbDrive));
      expect(available, contains(BackupDestination.networkStorage));
    });
  });
}
