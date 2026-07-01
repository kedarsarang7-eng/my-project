// ============================================================================
// Task 14.1 — UNIT TESTS
// Feature: offline-license-activation
//   BackupService: first-run writable backup-location prompt
//   Validates: Requirements 13.1, 13.6
// ============================================================================
// These tests exercise the Backup_Service's first-run gate by composing it
// over an injected writability probe and an in-memory Local_Config, so no
// filesystem or platform channel is touched. They confirm the service
// correctly delegates to the BackupLocationGate it composes:
//
//   * BLOCK USE until a writable location is selected (Req 13.1).
//   * ACCEPT + PERSIST a writable selection (Req 13.1).
//   * REJECT a non-writable selection with a clear indication, persist nothing,
//     and keep requiring a writable location (Req 13.6).
//   * Empty input is treated as not-writable (Req 13.6).
//
// Run: flutter test test/core/backup/backup_service_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/backup/backup_service.dart';
import 'package:dukanx/core/mode/local_config.dart';

/// In-memory [LocalConfig] keeping the backup location in a field instead of
/// `flutter_secure_storage`, so tests never touch a platform channel.
class _InMemoryLocalConfig extends LocalConfig {
  String? _location;

  @override
  Future<String?> getBackupLocation() async => _location;

  @override
  Future<void> setBackupLocation(String path) async {
    _location = path;
  }
}

void main() {
  group('Feature: offline-license-activation — BackupService first-run gate '
      '(Task 14.1)', () {
    late _InMemoryLocalConfig config;

    setUp(() {
      config = _InMemoryLocalConfig();
    });

    BackupService serviceWith({required bool writable}) =>
        BackupService(config: config, writabilityProbe: (_) async => writable);

    test(
      'blocks use on first run when no location is configured (Req 13.1)',
      () async {
        final service = serviceWith(writable: true);
        expect(await service.isFirstRunSetupRequired(), isTrue);
        expect(await service.backupLocation(), isNull);
      },
    );

    test('accepts and persists a writable selection (Req 13.1)', () async {
      final service = serviceWith(writable: true);

      final outcome = await service.selectBackupLocation('/backups/dukanx');

      expect(outcome, isA<BackupLocationAccepted>());
      expect((outcome as BackupLocationAccepted).path, '/backups/dukanx');
      expect(await service.isFirstRunSetupRequired(), isFalse);
      expect(await service.backupLocation(), '/backups/dukanx');
    });

    test('rejects a non-writable selection, persists nothing, and keeps '
        'requiring a writable location (Req 13.6)', () async {
      final service = serviceWith(writable: false);

      final outcome = await service.selectBackupLocation('/read-only/path');

      expect(outcome, isA<BackupLocationRejected>());
      final rejected = outcome as BackupLocationRejected;
      expect(rejected.path, '/read-only/path');
      expect(rejected.reason, isNotEmpty);

      // Nothing persisted; a writable location is still required (Req 13.6).
      expect(await config.getBackupLocation(), isNull);
      expect(await service.isFirstRunSetupRequired(), isTrue);
    });

    test(
      'keeps requiring a writable location until one is accepted (Req 13.6)',
      () async {
        // First selection rejected (not writable): setup still required.
        final rejecting = serviceWith(writable: false);
        expect(
          await rejecting.selectBackupLocation('/bad'),
          isA<BackupLocationRejected>(),
        );
        expect(await rejecting.isFirstRunSetupRequired(), isTrue);

        // A later, writable selection (same config) completes setup.
        final accepting = serviceWith(writable: true);
        expect(
          await accepting.selectBackupLocation('/good'),
          isA<BackupLocationAccepted>(),
        );
        expect(await accepting.isFirstRunSetupRequired(), isFalse);
        expect(await config.getBackupLocation(), '/good');
      },
    );

    test('treats an empty path as not writable (Req 13.6)', () async {
      // Probe would say writable, but an empty path is rejected before probing.
      final service = serviceWith(writable: true);

      expect(await service.isLocationWritable('   '), isFalse);
      expect(
        await service.selectBackupLocation('  '),
        isA<BackupLocationRejected>(),
      );
      expect(await config.getBackupLocation(), isNull);
    });
  });
}
