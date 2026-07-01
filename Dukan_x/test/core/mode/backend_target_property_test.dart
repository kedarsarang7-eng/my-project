// ============================================================================
// Task 1.5 — PROPERTY TEST
// Feature: offline-license-activation, Property 2:
//   Backend target is a total function of mode
// **Validates: Requirements 1.4, 1.5**
// ============================================================================
// Property 2 (design.md): *For any* active Operating_Mode,
//   `activeBackendBaseUri` returns the AWS host IF AND ONLY IF the mode is
//   Cloud_Subscription_Mode, and the loopback address `127.0.0.1:8765` IF AND
//   ONLY IF the mode is Offline_Lifetime_Mode.
//
// The mapping is exercised over BOTH OperatingMode values through both access
// paths that the design defines as equivalent:
//   * the pure static total function `DefaultModeManager.baseUriForMode(mode)`,
//   * the instance method `DefaultModeManager.activeBackendBaseUri()` after the
//     mode has been selected.
//
// The "AWS host" is the existing `ApiConfig.baseUrl` (Req 1.4) and the loopback
// is `ModeManager.loopbackBaseUri` == `http://127.0.0.1:8765` (Req 1.5). The
// test derives the expected AWS host from `ApiConfig.baseUrl` itself so it
// stays correct in every build environment (dev / staging / production).
//
// PBT library: dartproptest ^0.2.1 (the project's property-testing library;
// `glados` is unresolvable here — see pubspec.yaml dev_dependencies note).
//
// Run: flutter test test/core/mode/backend_target_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/config/api_config.dart';
import 'package:dukanx/core/mode/local_config.dart';
import 'package:dukanx/core/mode/mode_manager.dart';

/// In-memory [LocalConfig] that keeps the operating mode in a field instead of
/// `flutter_secure_storage`, so the property test never touches a platform
/// channel. Only the operating-mode accessors are overridden; everything else
/// inherits the real implementation (and is unused here).
class _InMemoryLocalConfig extends LocalConfig {
  String? _mode;

  @override
  Future<String?> getOperatingMode() async => _mode;

  @override
  Future<void> setOperatingMode(String mode) async {
    _mode = mode;
  }
}

void main() {
  // At least 100 iterations per the spec; 200 is the dartproptest default.
  const int kNumRuns = 200;

  // The two backend targets the mapping must distinguish.
  final awsUri = Uri.parse(ApiConfig.baseUrl); // Req 1.4
  final loopbackUri = ModeManager.loopbackBaseUri; // Req 1.5

  // Generates over BOTH OperatingMode values (the entire input space).
  final modeGen = Gen.elementOf<OperatingMode>(OperatingMode.values);

  group('Feature: offline-license-activation, Property 2 '
      '(Backend target is a total function of mode)', () {
    // The iff mapping only carries information if the two targets differ.
    // This invariant underpins every assertion below; assert it once.
    test('Feature: offline-license-activation, Property 2 — invariant: the AWS '
        'host and the loopback target are distinct', () {
      expect(
        awsUri,
        isNot(equals(loopbackUri)),
        reason:
            'AWS host ($awsUri) and loopback ($loopbackUri) must differ '
            'for the mode->target mapping to be injective.',
      );
    });

    test('Feature: offline-license-activation, Property 2 — static '
        'baseUriForMode maps AWS host iff Cloud and loopback iff Offline', () {
      final held = forAll(
        (OperatingMode mode) {
          final isCloud = mode == OperatingMode.cloudSubscription;
          final isOffline = mode == OperatingMode.offlineLifetime;

          final uri = DefaultModeManager.baseUriForMode(mode);

          // Total function: every mode maps to a non-null target that is
          // exactly one of the two known targets.
          if (uri != awsUri && uri != loopbackUri) return false;

          // AWS host  <=>  Cloud_Subscription_Mode (Req 1.4).
          if ((uri == awsUri) != isCloud) return false;

          // Loopback 127.0.0.1:8765  <=>  Offline_Lifetime_Mode (Req 1.5).
          if ((uri == loopbackUri) != isOffline) return false;

          return true;
        },
        [modeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Feature: offline-license-activation, Property 2 — instance '
        'activeBackendBaseUri agrees with the static mapping for the active '
        'mode', () async {
      // Build one manager per mode, with the mode already selected, so the
      // synchronous property closure can read the active target directly.
      final managers = <OperatingMode, DefaultModeManager>{};
      for (final mode in OperatingMode.values) {
        final manager = DefaultModeManager(localConfig: _InMemoryLocalConfig());
        await manager.selectMode(mode);
        managers[mode] = manager;
      }

      final held = forAll(
        (OperatingMode mode) {
          final isCloud = mode == OperatingMode.cloudSubscription;
          final isOffline = mode == OperatingMode.offlineLifetime;

          final uri = managers[mode]!.activeBackendBaseUri();

          // Both access paths must agree (the design treats them as one
          // total function).
          if (uri != DefaultModeManager.baseUriForMode(mode)) return false;

          if (uri != awsUri && uri != loopbackUri) return false;
          if ((uri == awsUri) != isCloud) return false;
          if ((uri == loopbackUri) != isOffline) return false;

          return true;
        },
        [modeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // Deterministic anchors pin the concrete targets the property asserts.
    test('Feature: offline-license-activation, Property 2 — anchor: Offline '
        'maps to http://127.0.0.1:8765', () {
      final uri = DefaultModeManager.baseUriForMode(
        OperatingMode.offlineLifetime,
      );
      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 8765);
      expect(uri, equals(loopbackUri));
    });

    test('Feature: offline-license-activation, Property 2 — anchor: Cloud maps '
        'to ApiConfig.baseUrl', () {
      final uri = DefaultModeManager.baseUriForMode(
        OperatingMode.cloudSubscription,
      );
      expect(uri, equals(Uri.parse(ApiConfig.baseUrl)));
    });
  });
}
