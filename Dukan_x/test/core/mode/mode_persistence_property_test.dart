// ============================================================================
// Task 1.4 — PROPERTY TEST
// Feature: offline-license-activation, Property 1
//   "Mode persistence round trip and safe default"
// **Validates: Requirements 1.2, 1.3, 1.9**
// ============================================================================
// Property 1 (design.md):
//   For ANY value stored in Local_Config as the operating mode, resolving the
//   active mode returns that mode when it is a recognized Operating_Mode, and
//   otherwise returns Cloud_Subscription_Mode AND persists that default; and
//   for ANY mode passed to `selectMode`, a subsequent `resolveActiveMode`
//   returns the same mode.
//
// This is realised as three sub-properties, each over >= 100 generated cases:
//
//   (a) ROUND TRIP — recognized raw value resolves to its mode (Req 1.2).
//       A directly-stored recognized storage string ('cloud_subscription' /
//       'offline_lifetime') resolves back to the matching OperatingMode.
//
//   (b) SAFE DEFAULT — missing / unrecognized value defaults to Cloud and is
//       PERSISTED as the recognized cloud value (Req 1.2, 1.9). Generated over
//       arbitrary non-recognized strings, both stored and absent.
//
//   (c) SELECT ROUND TRIP — selectMode(m) then a *fresh* manager's
//       resolveActiveMode() returns m (Req 1.3). A fresh manager is used so the
//       assertion checks durable persistence, not the in-memory cache.
//
// Hermetic by construction: the test swaps in the in-memory
// `TestFlutterSecureStoragePlatform` (shipped by flutter_secure_storage) so no
// platform channel, disk, or network is touched. A fresh backing map per case
// keeps every generated input isolated.
//
// PBT library: dartproptest ^0.2.1 (the project's standardized PBT library;
// see pubspec.yaml — `glados` is unresolvable against the Flutter-SDK-pinned
// test_api/matcher + mockito constraints).
//
// Run: flutter test test/core/mode/mode_persistence_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/mode/local_config.dart';
import 'package:dukanx/core/mode/mode_manager.dart';

/// At least 100 iterations per the spec (the dartproptest default is 200).
const int kNumRuns = 200;

/// Stable on-disk values owned by Mode_Manager (mirrored here from the
/// production `DefaultModeManager` constants, which are private). These are the
/// only two recognized persisted values.
const String kStorageCloud = 'cloud_subscription';
const String kStorageOffline = 'offline_lifetime';

/// The recognized storage string for an [OperatingMode].
String rawFor(OperatingMode mode) => switch (mode) {
  OperatingMode.cloudSubscription => kStorageCloud,
  OperatingMode.offlineLifetime => kStorageOffline,
};

/// Installs a fresh in-memory secure-storage backend and returns a
/// [LocalConfig] bound to it. Each call fully isolates one generated case.
LocalConfig freshLocalConfig() {
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
    <String, String>{},
  );
  return LocalConfig();
}

void main() {
  // Generates one of the exactly-two recognized modes (Req 1.1).
  final modeGen = Gen.elementOf<OperatingMode>(OperatingMode.values);

  group(
    'Feature: offline-license-activation, Property 1: Mode persistence round '
    'trip and safe default',
    () {
      // ----------------------------------------------------------------------
      // (a) ROUND TRIP — a recognized stored value resolves to its mode.
      // **Validates: Requirements 1.2**
      // ----------------------------------------------------------------------
      test('Feature: offline-license-activation, Property 1 (a) — a recognized '
          'stored operating mode resolves back to that mode', () async {
        final held = await forAllAsync(
          (OperatingMode mode) async {
            final localConfig = freshLocalConfig();
            // Store the recognized raw value directly (Req 1.2 input).
            await localConfig.setOperatingMode(rawFor(mode));

            final manager = DefaultModeManager(localConfig: localConfig);
            final resolved = await manager.resolveActiveMode();

            // Recognized value resolves to the matching mode, and a
            // recognized value is never overwritten by the default.
            final persisted = await localConfig.getOperatingMode();
            return resolved == mode && persisted == rawFor(mode);
          },
          [modeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // ----------------------------------------------------------------------
      // (b) SAFE DEFAULT — missing / unrecognized value defaults to Cloud and
      // persists the recognized cloud value.
      // **Validates: Requirements 1.2, 1.9**
      // ----------------------------------------------------------------------
      test(
        'Feature: offline-license-activation, Property 1 (b) — a missing or '
        'unrecognized operating mode defaults to Cloud and persists it',
        () async {
          final held = await forAllAsync(
            (String raw, bool storeIt) async {
              // Only exercise genuinely unrecognized values; the recognized
              // strings are covered by sub-property (a).
              precond(raw != kStorageCloud && raw != kStorageOffline);

              final localConfig = freshLocalConfig();
              if (storeIt) {
                // An unrecognized value is present in Local_Config.
                await localConfig.setOperatingMode(raw);
              }
              // else: no operating mode is persisted at all (the missing case).

              final manager = DefaultModeManager(localConfig: localConfig);
              final resolved = await manager.resolveActiveMode();
              final persisted = await localConfig.getOperatingMode();

              // Defaults to Cloud_Subscription_Mode (Req 1.9) AND persists the
              // recognized cloud value so the next startup reads a known mode.
              return resolved == OperatingMode.cloudSubscription &&
                  persisted == kStorageCloud;
            },
            [Gen.string(minLength: 0, maxLength: 24), Gen.boolean()],
            numRuns: kNumRuns,
          );
          expect(held, isTrue);
        },
      );

      // ----------------------------------------------------------------------
      // (c) SELECT ROUND TRIP — selectMode(m) durably persists m.
      // **Validates: Requirements 1.3**
      // ----------------------------------------------------------------------
      test(
        'Feature: offline-license-activation, Property 1 (c) — selectMode then '
        'a fresh resolveActiveMode returns the selected mode',
        () async {
          final held = await forAllAsync(
            (OperatingMode mode) async {
              final localConfig = freshLocalConfig();

              // Persist the user-selected mode (Req 1.3).
              final writer = DefaultModeManager(localConfig: localConfig);
              await writer.selectMode(mode);

              // A *fresh* manager guarantees we read durable persistence, not
              // the writer's in-memory cache.
              final reader = DefaultModeManager(localConfig: localConfig);
              final resolved = await reader.resolveActiveMode();

              return resolved == mode &&
                  await localConfig.getOperatingMode() == rawFor(mode);
            },
            [modeGen],
            numRuns: kNumRuns,
          );
          expect(held, isTrue);
        },
      );

      // ----------------------------------------------------------------------
      // Deterministic anchors (example-based unit checks of the same property).
      // ----------------------------------------------------------------------
      test(
        'anchor: recognized "cloud_subscription" resolves to Cloud',
        () async {
          final localConfig = freshLocalConfig();
          await localConfig.setOperatingMode(kStorageCloud);
          final manager = DefaultModeManager(localConfig: localConfig);
          expect(
            await manager.resolveActiveMode(),
            OperatingMode.cloudSubscription,
          );
        },
      );

      test(
        'anchor: recognized "offline_lifetime" resolves to Offline',
        () async {
          final localConfig = freshLocalConfig();
          await localConfig.setOperatingMode(kStorageOffline);
          final manager = DefaultModeManager(localConfig: localConfig);
          expect(
            await manager.resolveActiveMode(),
            OperatingMode.offlineLifetime,
          );
        },
      );

      test(
        'anchor: a missing mode defaults to Cloud and persists it',
        () async {
          final localConfig = freshLocalConfig();
          final manager = DefaultModeManager(localConfig: localConfig);
          expect(
            await manager.resolveActiveMode(),
            OperatingMode.cloudSubscription,
          );
          expect(await localConfig.getOperatingMode(), kStorageCloud);
        },
      );

      test(
        'anchor: an unrecognized mode defaults to Cloud and persists it',
        () async {
          final localConfig = freshLocalConfig();
          await localConfig.setOperatingMode('totally-unknown-mode');
          final manager = DefaultModeManager(localConfig: localConfig);
          expect(
            await manager.resolveActiveMode(),
            OperatingMode.cloudSubscription,
          );
          expect(await localConfig.getOperatingMode(), kStorageCloud);
        },
      );

      test('anchor: selectMode(offline) survives a fresh manager', () async {
        final localConfig = freshLocalConfig();
        await DefaultModeManager(
          localConfig: localConfig,
        ).selectMode(OperatingMode.offlineLifetime);
        final reader = DefaultModeManager(localConfig: localConfig);
        expect(await reader.resolveActiveMode(), OperatingMode.offlineLifetime);
      });
    },
  );
}
