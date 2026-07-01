// ============================================================================
// Task 14.1 — UNIT TESTS
// Feature: offline-license-activation
//   BackupLocationGate: first-run writable backup-location gating
//   Validates: Requirements 13.1, 13.6
// ============================================================================
// These tests exercise the gate's decision logic with an injected writability
// probe and an in-memory Local_Config, so no filesystem or platform channel is
// touched. They cover:
//
//   * BLOCK USE until a writable location is selected (Req 13.1).
//   * ACCEPT + PERSIST a writable selection (Req 13.1).
//   * REJECT a non-writable selection with a clear indication, persist nothing,
//     and keep requiring a writable location (Req 13.6).
//   * Empty input is treated as not-writable.
//
// Run: flutter test test/core/backup/backup_location_gate_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/backup/backup_location_gate.dart';
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
  group(
    'Feature: offline-license-activation — BackupLocationGate (Task 14.1)',
    () {
      late _InMemoryLocalConfig config;

      setUp(() {
        config = _InMemoryLocalConfig();
      });

      BackupLocationGate gateWith({required bool writable}) =>
          BackupLocationGate(
            config: config,
            writabilityProbe: (_) async => writable,
          );

      test(
        'blocks use on first run when no location is configured (Req 13.1)',
        () async {
          final gate = gateWith(writable: true);
          expect(await gate.isSetupRequired(), isTrue);
          expect(await gate.configuredLocation(), isNull);
        },
      );

      test('accepts and persists a writable selection (Req 13.1)', () async {
        final gate = gateWith(writable: true);

        final outcome = await gate.selectLocation('/backups/dukanx');

        expect(outcome, isA<BackupLocationAccepted>());
        expect((outcome as BackupLocationAccepted).path, '/backups/dukanx');
        // Setup is no longer required once a writable location is accepted.
        expect(await gate.isSetupRequired(), isFalse);
        expect(await gate.configuredLocation(), '/backups/dukanx');
      });

      test('rejects a non-writable selection, persists nothing, and keeps '
          'requiring a writable location (Req 13.6)', () async {
        final gate = gateWith(writable: false);

        final outcome = await gate.selectLocation('/read-only/path');

        expect(outcome, isA<BackupLocationRejected>());
        final rejected = outcome as BackupLocationRejected;
        expect(rejected.path, '/read-only/path');
        expect(rejected.reason, BackupLocationGate.notWritableReason);
        expect(rejected.reason, isNotEmpty);

        // Nothing persisted; a writable location is still required (Req 13.6).
        expect(await config.getBackupLocation(), isNull);
        expect(await gate.isSetupRequired(), isTrue);
      });

      test(
        'keeps requiring a writable location until one is accepted (Req 13.6)',
        () async {
          // First selection is rejected (not writable).
          final rejectingGate = gateWith(writable: false);
          expect(
            await rejectingGate.selectLocation('/bad'),
            isA<BackupLocationRejected>(),
          );
          expect(await rejectingGate.isSetupRequired(), isTrue);

          // A later, writable selection (same config) completes setup.
          final acceptingGate = gateWith(writable: true);
          expect(
            await acceptingGate.selectLocation('/good'),
            isA<BackupLocationAccepted>(),
          );
          expect(await acceptingGate.isSetupRequired(), isFalse);
          expect(await config.getBackupLocation(), '/good');
        },
      );

      test('treats an empty path as not writable (Req 13.6)', () async {
        // Probe would say writable, but an empty path is rejected before probing.
        final gate = gateWith(writable: true);

        expect(await gate.isWritable('   '), isFalse);
        expect(await gate.selectLocation('  '), isA<BackupLocationRejected>());
        expect(await config.getBackupLocation(), isNull);
      });

      test('isWritable returns true only when the probe succeeds', () async {
        expect(await gateWith(writable: true).isWritable('/somewhere'), isTrue);
        expect(
          await gateWith(writable: false).isWritable('/somewhere'),
          isFalse,
        );
      });
    },
  );
}
