// ============================================================================
// LAN_COORDINATOR — primary/secondary coordination + allowance cap unit tests
// ============================================================================
// Feature: offline-license-activation (Task 16.1)
//
// Exercises DefaultLanCoordinator + LanDeviceRegistry with fully injected seams
// (in-memory secure storage, a fake LanPrimaryTransport, an injected device
// allowance, and an injected auth-token provider) so the tests are fast,
// hermetic, and touch no real network, disk, or session.
//
// Covered Requirements:
//   15.1 — exactly one Primary_Device role is read from LocalConfig.
//   15.2 — a Secondary_Device connects with an authenticated session within 10s.
//   15.4 — an unreachable primary is reported as a failure REGARDLESS of any
//          previously-reported (connected) status.
//   15.5 — connected devices (secondaries + primary) are capped at the license
//          device allowance; connections beyond it are rejected.
//   15.6 — a Secondary_Device cannot write to the primary store while the
//          primary is unreachable / not yet connected.
//
// Run: flutter test test/core/mode/lan_coordinator_test.dart
// ============================================================================

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/mode/lan_coordinator.dart';
import 'package:dukanx/core/mode/local_config.dart';

/// Installs a fresh in-memory secure-storage backend and returns a [LocalConfig]
/// bound to it. Each call fully isolates one test.
LocalConfig freshLocalConfig() {
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
    <String, String>{},
  );
  return LocalConfig();
}

/// Fake [LanPrimaryTransport] returning a fixed (mutable) reachability verdict,
/// recording the token it was asked to present and the probe count.
class _FakeLanTransport implements LanPrimaryTransport {
  bool reachable;
  int probeCount = 0;
  String? lastToken;

  _FakeLanTransport(this.reachable);

  @override
  Future<bool> probe(
    Uri primaryBaseUri, {
    required String authToken,
    required Duration timeout,
  }) async {
    probeCount++;
    lastToken = authToken;
    return reachable;
  }
}

void main() {
  group('LanDeviceRegistry — device-allowance cap (Req 15.5)', () {
    test('wouldExceedAllowance is a pure function of counts and cap', () {
      // allowance 1 → only the primary fits, so even the first secondary
      // exceeds it.
      expect(
        LanDeviceRegistry.wouldExceedAllowance(
          currentSecondaryCount: 0,
          maxDevices: 1,
        ),
        isTrue,
      );
      // allowance 3 → primary + 2 secondaries fit; the 3rd secondary exceeds.
      expect(
        LanDeviceRegistry.wouldExceedAllowance(
          currentSecondaryCount: 1,
          maxDevices: 3,
        ),
        isFalse,
      );
      expect(
        LanDeviceRegistry.wouldExceedAllowance(
          currentSecondaryCount: 2,
          maxDevices: 3,
        ),
        isTrue,
      );
    });

    test('caps total connected devices (primary + secondaries) at the '
        'allowance and rejects beyond it', () {
      final registry = LanDeviceRegistry(maxDevices: 3);

      final a = registry.admit('device-a');
      final b = registry.admit('device-b');
      expect(a.admitted, isTrue);
      expect(b.admitted, isTrue);
      // primary + 2 secondaries == 3 devices, exactly the allowance.
      expect(registry.connectedDeviceCount, 3);

      final c = registry.admit('device-c');
      expect(c.admitted, isFalse);
      expect(c.code, LanAdmission.codeAllowanceExceeded);
      // The rejected device did not consume a slot.
      expect(registry.connectedDeviceCount, 3);
    });

    test('a default (allowance 1) deployment admits no secondaries', () {
      final registry = LanDeviceRegistry(maxDevices: 1);
      final result = registry.admit('device-a');
      expect(result.admitted, isFalse);
      expect(registry.connectedDeviceCount, 1); // just the primary
    });

    test('re-admitting a connected device is idempotent (counts concurrent, '
        'not cumulative)', () {
      final registry = LanDeviceRegistry(maxDevices: 3);
      expect(registry.admit('device-a').admitted, isTrue);
      // Same device again must not consume another slot.
      expect(registry.admit('device-a').admitted, isTrue);
      expect(registry.connectedSecondaryCount, 1);
      // A different device now fills the last slot (primary + 2 secondaries).
      expect(registry.admit('device-b').admitted, isTrue);
      expect(registry.connectedDeviceCount, 3);
    });

    test('releasing a device frees its slot for another', () {
      final registry = LanDeviceRegistry(maxDevices: 2);
      expect(registry.admit('device-a').admitted, isTrue);
      expect(registry.admit('device-b').admitted, isFalse); // allowance full

      registry.release('device-a');
      expect(registry.admit('device-b').admitted, isTrue);
      expect(registry.connectedDeviceCount, 2);
    });

    test('an allowance below 1 is floored to 1 (a deployment always has the '
        'primary)', () {
      final registry = LanDeviceRegistry(maxDevices: 0);
      expect(registry.maxDevices, 1);
      expect(registry.admit('device-a').admitted, isFalse);
    });
  });

  group('DefaultLanCoordinator — primary side (Req 15.5)', () {
    test('admitSecondary enforces the resolved license allowance', () async {
      final coordinator = DefaultLanCoordinator(
        localConfig: freshLocalConfig(),
        transport: _FakeLanTransport(true),
        allowanceResolver: () async => 2, // primary + 1 secondary
        authTokenProvider: () async => 'jwt',
      );
      addTearDown(coordinator.dispose);

      final first = await coordinator.admitSecondary('counter-1');
      expect(first.admitted, isTrue);
      expect(coordinator.connectedDeviceCount, 2);

      final second = await coordinator.admitSecondary('counter-2');
      expect(second.admitted, isFalse);
      expect(second.code, LanAdmission.codeAllowanceExceeded);
      expect(coordinator.connectedDeviceCount, 2);
    });
  });

  group('DefaultLanCoordinator — secondary side (Req 15.1/15.2/15.4/15.6)', () {
    test('connect requires the secondary role (Req 15.1)', () async {
      final config = freshLocalConfig();
      await config.setLanRole(LanRole.primary);
      final coordinator = DefaultLanCoordinator(
        localConfig: config,
        transport: _FakeLanTransport(true),
        allowanceResolver: () async => 3,
        authTokenProvider: () async => 'jwt',
      );
      addTearDown(coordinator.dispose);

      final result = await coordinator.connectToPrimary();
      expect(result.status, LanConnectionStatus.notSecondary);
      // A primary owns its authoritative store and may always write.
      expect(coordinator.canWriteToPrimaryStore, isTrue);
    });

    test('a configured secondary connects to a reachable primary with an '
        'authenticated session (Req 15.2)', () async {
      final config = freshLocalConfig();
      await config.setLanRole(LanRole.secondary);
      await config.setLanPrimaryHost('192.168.1.10');
      final transport = _FakeLanTransport(true);
      final coordinator = DefaultLanCoordinator(
        localConfig: config,
        transport: transport,
        allowanceResolver: () async => 3,
        authTokenProvider: () async => 'session-jwt',
      );
      addTearDown(coordinator.dispose);

      final result = await coordinator.connectToPrimary();
      expect(result.isConnected, isTrue);
      expect(result.primaryHost, '192.168.1.10');
      // The authenticated session token was presented to the primary.
      expect(transport.lastToken, 'session-jwt');
      // While connected, the secondary may write to the primary store (15.6).
      expect(coordinator.canWriteToPrimaryStore, isTrue);
    });

    test('without an authenticated session the secondary does not connect '
        '(Req 15.2)', () async {
      final config = freshLocalConfig();
      await config.setLanRole(LanRole.secondary);
      await config.setLanPrimaryHost('192.168.1.10');
      final coordinator = DefaultLanCoordinator(
        localConfig: config,
        transport: _FakeLanTransport(true),
        allowanceResolver: () async => 3,
        authTokenProvider: () async => null, // no session
      );
      addTearDown(coordinator.dispose);

      final result = await coordinator.connectToPrimary();
      expect(result.status, LanConnectionStatus.unauthenticated);
      expect(coordinator.canWriteToPrimaryStore, isFalse);
    });

    test('a missing primary host yields noPrimaryConfigured', () async {
      final config = freshLocalConfig();
      await config.setLanRole(LanRole.secondary);
      final coordinator = DefaultLanCoordinator(
        localConfig: config,
        transport: _FakeLanTransport(true),
        allowanceResolver: () async => 3,
        authTokenProvider: () async => 'jwt',
      );
      addTearDown(coordinator.dispose);

      final result = await coordinator.connectToPrimary();
      expect(result.status, LanConnectionStatus.noPrimaryConfigured);
      expect(coordinator.canWriteToPrimaryStore, isFalse);
    });

    test('an unreachable primary is reported as a failure REGARDLESS of a '
        'previously connected status, and blocks secondary writes '
        '(Req 15.4/15.6)', () async {
      final config = freshLocalConfig();
      await config.setLanRole(LanRole.secondary);
      await config.setLanPrimaryHost('192.168.1.10');
      final transport = _FakeLanTransport(true);
      final coordinator = DefaultLanCoordinator(
        localConfig: config,
        transport: transport,
        allowanceResolver: () async => 3,
        authTokenProvider: () async => 'jwt',
      );
      addTearDown(coordinator.dispose);

      // First: reachable → connected, writes allowed.
      final connected = await coordinator.connectToPrimary();
      expect(connected.isConnected, isTrue);
      expect(coordinator.canWriteToPrimaryStore, isTrue);

      // Primary goes down; a fresh probe must flip to a failure (15.4).
      transport.reachable = false;
      final dropped = await coordinator.connectToPrimary();
      expect(dropped.status, LanConnectionStatus.unreachable);
      // Writes to the primary store are now blocked (15.6).
      expect(coordinator.canWriteToPrimaryStore, isFalse);
    });

    test(
      'connectionStatus stream emits each fresh connection result',
      () async {
        final config = freshLocalConfig();
        await config.setLanRole(LanRole.secondary);
        await config.setLanPrimaryHost('10.0.0.5');
        final transport = _FakeLanTransport(true);
        final coordinator = DefaultLanCoordinator(
          localConfig: config,
          transport: transport,
          allowanceResolver: () async => 3,
          authTokenProvider: () async => 'jwt',
        );
        addTearDown(coordinator.dispose);

        final seen = <LanConnectionStatus>[];
        final sub = coordinator.connectionStatus.listen(
          (r) => seen.add(r.status),
        );

        await coordinator.connectToPrimary();
        transport.reachable = false;
        await coordinator.connectToPrimary();
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(seen, <LanConnectionStatus>[
          LanConnectionStatus.connected,
          LanConnectionStatus.unreachable,
        ]);
      },
    );
  });
}
