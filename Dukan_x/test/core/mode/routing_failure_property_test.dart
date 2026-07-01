// ============================================================================
// Task 1.6 — PROPERTY TEST
// Feature: offline-license-activation, Property 3
//   "Routing failure names the failed target and preserves mode"
// **Validates: Requirements 1.8**
// ============================================================================
//
// Property 3 (from design.md):
//
//   For any active backend target whose routed call neither connects nor
//   responds within 10 seconds, `route` yields a RoutingFailure whose
//   `backendTarget` equals that active target, and the active Operating_Mode
//   is unchanged.
//
// This suite exercises BOTH failure shapes the routing contract recognises
// (Requirement 1.8, see DefaultModeManager.route):
//
//   (a) NO RESPONSE   — the call never returns within the routing timeout
//                       -> RouteFailure(reason: timeout)
//   (b) NO CONNECTION — the call throws a SocketException
//                       -> RouteFailure(reason: connection_failed)
//
// For every generated Operating_Mode the test:
//   1. persists that mode into an in-memory Local_Config and resolves it,
//   2. records the active target authority + active mode,
//   3. routes a never-returning call (a) and a SocketException call (b),
//   4. asserts each yields a RouteFailure whose `backendTarget` equals the
//      active target authority (`127.0.0.1:8765` offline, or the AWS host
//      authority in cloud mode), and that the active mode is byte-for-byte
//      unchanged before and after each routed call.
//
// PBT library: dartproptest ^0.2.1.
//   The design's first suggestion was `glados`, but `glados` is unresolvable
//   in this workspace (it pins the standalone `test` package, conflicting with
//   the Flutter-SDK `test_api`/`matcher` and `mockito 5.4.6`). `dartproptest`
//   is the QuickCheck/Hypothesis-style PBT library already adopted across this
//   project's property suites (see pubspec.yaml dev_dependencies + the
//   subscription-plan-tiers tests). `route` is async, so the async entry point
//   `forAllAsync` is used.
//
// Run: flutter test test/core/mode/routing_failure_property_test.dart
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/mode/local_config.dart';
import 'package:dukanx/core/mode/mode_manager.dart';

void main() {
  // At least 100 generated cases per the spec. Each run performs one
  // never-returning routed call bounded by [kRoutingTimeout], so the count is
  // kept just above the 100 floor to keep the suite brisk while remaining a
  // real, non-degenerate property check.
  const int kNumRuns = 150;

  // A short routing window stands in for the production 10s window: the
  // routing-failure behaviour is identical, only faster to observe.
  const Duration kRoutingTimeout = Duration(milliseconds: 20);

  // Backed by an in-memory secure store so Local_Config persistence works in a
  // headless test (no platform channels). Shared singleton; cleared per run.
  final Map<String, String> store = <String, String>{};

  setUpAll(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      store,
    );
  });

  setUp(() {
    store.clear();
  });

  /// Builds a [DefaultModeManager] whose active mode was resolved purely from a
  /// persisted, in-memory [LocalConfig] set to [mode]. The mode is written by a
  /// separate manager so the manager-under-test derives its mode from storage
  /// (a real round trip), faithful to "an in-memory LocalConfig set to that
  /// mode".
  Future<DefaultModeManager> buildManagerForMode(OperatingMode mode) async {
    final config = LocalConfig();
    // Persist the selected mode via a throwaway manager (writes to the store).
    await DefaultModeManager(localConfig: config).selectMode(mode);
    // Manager under test: short routing window, resolves from persisted config.
    final manager = DefaultModeManager(
      localConfig: config,
      routingTimeout: kRoutingTimeout,
    );
    final resolved = await manager.resolveActiveMode();
    // Guard: the in-memory config must round-trip to the generated mode.
    expect(resolved, mode);
    return manager;
  }

  // A generator drawing either of the two Operating_Mode values.
  final modeGen = Gen.elementOf<OperatingMode>(OperatingMode.values);

  group('Feature: offline-license-activation, Property 3: Routing failure names '
      'the failed target and preserves mode', () {
    test(
      'Feature: offline-license-activation, Property 3 — for any active mode, '
      'a no-response call yields a timeout RouteFailure naming the active '
      'target and leaves the mode unchanged',
      () async {
        final held = await forAllAsync(
          (OperatingMode mode) async {
            final manager = await buildManagerForMode(mode);

            final expectedTarget = manager.activeBackendBaseUri().authority;
            final modeBefore = manager.activeMode;

            // (a) NO RESPONSE: the call never completes within the window.
            final result = await manager.route<int>(
              (_) => Completer<int>().future,
            );

            if (result is! RouteFailure<int>) return false;
            final failure = result.failure;

            return failure.backendTarget == expectedTarget &&
                failure.reason == RoutingFailure.reasonTimeout &&
                // The active mode is untouched by a routing failure (Req 1.8).
                manager.activeMode == modeBefore;
          },
          [modeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test(
      'Feature: offline-license-activation, Property 3 — for any active mode, '
      'a SocketException call yields a connection_failed RouteFailure naming '
      'the active target and leaves the mode unchanged',
      () async {
        final held = await forAllAsync(
          (OperatingMode mode) async {
            final manager = await buildManagerForMode(mode);

            final expectedTarget = manager.activeBackendBaseUri().authority;
            final modeBefore = manager.activeMode;

            // (b) NO CONNECTION: the call fails to connect to the target.
            final result = await manager.route<int>(
              (_) async => throw const SocketException('connection refused'),
            );

            if (result is! RouteFailure<int>) return false;
            final failure = result.failure;

            return failure.backendTarget == expectedTarget &&
                failure.reason == RoutingFailure.reasonConnectionFailed &&
                manager.activeMode == modeBefore;
          },
          [modeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Deterministic anchors (example tests) — one per mode, per failure shape.
    // These pin the concrete target authorities the property generalises over.
    // ----------------------------------------------------------------------

    test(
      'Feature: offline-license-activation, Property 3 — anchor: offline '
      'timeout names 127.0.0.1:8765 and preserves Offline_Lifetime_Mode',
      () async {
        final manager = await buildManagerForMode(
          OperatingMode.offlineLifetime,
        );

        final result = await manager.route<int>((_) => Completer<int>().future);

        expect(result, isA<RouteFailure<int>>());
        final failure = (result as RouteFailure<int>).failure;
        expect(failure.backendTarget, '127.0.0.1:8765');
        expect(failure.reason, RoutingFailure.reasonTimeout);
        expect(manager.activeMode, OperatingMode.offlineLifetime);
      },
    );

    test(
      'Feature: offline-license-activation, Property 3 — anchor: offline '
      'SocketException names 127.0.0.1:8765 and preserves the mode',
      () async {
        final manager = await buildManagerForMode(
          OperatingMode.offlineLifetime,
        );

        final result = await manager.route<int>(
          (_) async => throw const SocketException('refused'),
        );

        expect(result, isA<RouteFailure<int>>());
        final failure = (result as RouteFailure<int>).failure;
        expect(failure.backendTarget, '127.0.0.1:8765');
        expect(failure.reason, RoutingFailure.reasonConnectionFailed);
        expect(manager.activeMode, OperatingMode.offlineLifetime);
      },
    );

    test('Feature: offline-license-activation, Property 3 — anchor: cloud '
        'timeout names the AWS host authority and preserves '
        'Cloud_Subscription_Mode', () async {
      final manager = await buildManagerForMode(
        OperatingMode.cloudSubscription,
      );
      final expectedTarget = manager.activeBackendBaseUri().authority;

      final result = await manager.route<int>((_) => Completer<int>().future);

      expect(result, isA<RouteFailure<int>>());
      final failure = (result as RouteFailure<int>).failure;
      expect(failure.backendTarget, expectedTarget);
      // The cloud target is never the offline loopback backend.
      expect(failure.backendTarget, isNot('127.0.0.1:8765'));
      expect(failure.reason, RoutingFailure.reasonTimeout);
      expect(manager.activeMode, OperatingMode.cloudSubscription);
    });
  });
}
