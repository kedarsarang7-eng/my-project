// ============================================================================
// BACKEND SUPERVISOR — Lifecycle unit tests
// ============================================================================
// Feature: offline-license-activation (task 2.3)
//
// Exercises DefaultBackendSupervisor with fully MOCKED process control so the
// lifecycle is fast and deterministic without a real Node process:
//   * fake BackendProcessController / BackendProcessHandle
//   * fake BackendHealthProbe
//   * fake RepositoryConnection
//   * callback LocalLicenseCheck / LicenseDecryptValidate / SessionRestore seams
//
// Covered Requirements:
//   3.3 — Startup_Sequence order: license check -> decrypt/validate -> spawn ->
//         health -> connect -> restore (and the sequence halts on an early
//         failure without spawning or connecting).
//   3.6 — Health-check timeout window logic (bonus): an unhealthy probe within
//         the window resolves to "not healthy".
//   3.7 — Shutdown requests graceful termination and force-kills when the
//         process does not exit within the graceful window.
//   3.8 — An unexpected process exit triggers up to 3 restart attempts, each
//         recorded as a RestartEvent.
//   3.9 — After 3 failed restarts, unrecoverableFailure emits and the
//         repository layer is marked disconnected.
// ============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/mode/backend_supervisor.dart';

// ----------------------------------------------------------------------------
// Test doubles (hand-written fakes — matches existing test conventions)
// ----------------------------------------------------------------------------

/// Fake [BackendProcessHandle] whose exit is driven explicitly by the test.
///
/// By default it ignores [terminate] (modelling a process that does not honour
/// SIGTERM) and only exits on [kill]; set [exitOnTerminate] to model a process
/// that shuts down cleanly on the graceful signal.
class _FakeProcessHandle implements BackendProcessHandle {
  final Completer<int> _exit = Completer<int>();
  final bool exitOnTerminate;

  bool terminateCalled = false;
  bool killCalled = false;

  _FakeProcessHandle({this.exitOnTerminate = false});

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool terminate() {
    terminateCalled = true;
    if (exitOnTerminate && !_exit.isCompleted) _exit.complete(0);
    return true;
  }

  @override
  bool kill() {
    killCalled = true;
    if (!_exit.isCompleted) _exit.complete(-9);
    return true;
  }

  /// Simulates the process dying on its own (e.g. an unexpected crash).
  void simulateExit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

/// Fake [BackendProcessController]. Records spawn calls, can hand out a
/// pre-built handle via [handleFactory], and can be told to throw on spawn to
/// model a backend that fails to (re)start.
class _FakeProcessController implements BackendProcessController {
  int spawnCount = 0;
  bool throwOnSpawn = false;
  final List<_FakeProcessHandle> handles = <_FakeProcessHandle>[];
  _FakeProcessHandle Function()? handleFactory;
  final void Function()? onSpawn;

  _FakeProcessController({this.handleFactory, this.onSpawn});

  @override
  Future<BackendProcessHandle> spawn() async {
    spawnCount++;
    onSpawn?.call();
    if (throwOnSpawn) {
      throw StateError('spawn failed (simulated)');
    }
    final handle = handleFactory?.call() ?? _FakeProcessHandle();
    handles.add(handle);
    return handle;
  }

  _FakeProcessHandle get lastHandle => handles.last;
}

/// Fake [BackendHealthProbe] returning a fixed (mutable) health verdict.
class _FakeHealthProbe implements BackendHealthProbe {
  bool healthy;
  int checkCount = 0;
  final void Function()? onCheck;

  _FakeHealthProbe(this.healthy, {this.onCheck});

  @override
  Future<bool> check() async {
    checkCount++;
    onCheck?.call();
    return healthy;
  }
}

/// Fake [RepositoryConnection] recording connect/disconnect calls.
class _FakeRepositoryConnection implements RepositoryConnection {
  int connectCount = 0;
  int disconnectCount = 0;
  final void Function()? onConnect;

  _FakeRepositoryConnection({this.onConnect});

  @override
  void connect() {
    connectCount++;
    onConnect?.call();
  }

  @override
  void disconnect() {
    disconnectCount++;
  }
}

void main() {
  // Each test builds its own supervisor through this helper so collaborators
  // can be tailored per scenario; dispose is always registered.
  DefaultBackendSupervisor buildSupervisor({
    required _FakeProcessController controller,
    required _FakeHealthProbe probe,
    required _FakeRepositoryConnection repository,
    required LocalLicenseCheck localLicenseCheck,
    required LicenseDecryptValidate licenseDecryptValidate,
    required SessionRestore sessionRestore,
  }) {
    final supervisor = DefaultBackendSupervisor(
      processController: controller,
      healthProbe: probe,
      repository: repository,
      localLicenseCheck: localLicenseCheck,
      licenseDecryptValidate: licenseDecryptValidate,
      sessionRestore: sessionRestore,
    );
    addTearDown(supervisor.dispose);
    return supervisor;
  }

  group('runStartupSequence — call order (Req 3.3)', () {
    test('executes license -> decrypt/validate -> spawn -> health -> connect '
        '-> restore in order, connecting the repository and restoring the '
        'session on a healthy backend', () async {
      final order = <String>[];

      final controller = _FakeProcessController(
        // Pending handle: never exits during this test (no crash path).
        handleFactory: () => _FakeProcessHandle(),
        onSpawn: () => order.add('spawn'),
      );
      final probe = _FakeHealthProbe(true, onCheck: () => order.add('health'));
      final repository = _FakeRepositoryConnection(
        onConnect: () => order.add('connect'),
      );

      final supervisor = buildSupervisor(
        controller: controller,
        probe: probe,
        repository: repository,
        localLicenseCheck: () async {
          order.add('license_check');
          return true;
        },
        licenseDecryptValidate: () async {
          order.add('decrypt_validate');
          return true;
        },
        sessionRestore: () async {
          order.add('restore');
        },
      );

      await supervisor.runStartupSequence();

      expect(order, <String>[
        'license_check',
        'decrypt_validate',
        'spawn',
        'health',
        'connect',
        'restore',
      ]);
      // Req 3.5: repository connected on a healthy backend.
      expect(repository.connectCount, 1);
      expect(repository.disconnectCount, 0);
      // Backend was spawned exactly once during a clean startup.
      expect(controller.spawnCount, 1);
      // connect happens before restore.
      expect(order.indexOf('connect') < order.indexOf('restore'), isTrue);
    });

    test('halts before spawning when the local license check fails '
        '(stops the sequence, Req 3.3/3.6)', () async {
      final controller = _FakeProcessController();
      final probe = _FakeHealthProbe(true);
      final repository = _FakeRepositoryConnection();
      var restoreRan = false;

      final supervisor = buildSupervisor(
        controller: controller,
        probe: probe,
        repository: repository,
        localLicenseCheck: () async => false, // license check fails
        licenseDecryptValidate: () async => true,
        sessionRestore: () async {
          restoreRan = true;
        },
      );

      final errors = <BackendStartupError>[];
      supervisor.startupErrors.listen(errors.add);

      await supervisor.runStartupSequence();
      // Allow the broadcast error event to be delivered.
      await Future<void>.delayed(Duration.zero);

      expect(controller.spawnCount, 0, reason: 'must not spawn backend');
      expect(repository.connectCount, 0);
      expect(restoreRan, isFalse);
      expect(errors.single.phase, 'local_license_check');
    });

    test(
      'halts before spawning when license decrypt/validate fails (Req 3.3)',
      () async {
        final controller = _FakeProcessController();
        final probe = _FakeHealthProbe(true);
        final repository = _FakeRepositoryConnection();

        final supervisor = buildSupervisor(
          controller: controller,
          probe: probe,
          repository: repository,
          localLicenseCheck: () async => true,
          licenseDecryptValidate: () async => false, // decrypt/validate fails
          sessionRestore: () async {},
        );

        final errors = <BackendStartupError>[];
        supervisor.startupErrors.listen(errors.add);

        await supervisor.runStartupSequence();
        await Future<void>.delayed(Duration.zero);

        expect(controller.spawnCount, 0);
        expect(repository.connectCount, 0);
        expect(errors.single.phase, 'license_decrypt_validate');
      },
    );
  });

  group('healthCheck — window logic (Req 3.6)', () {
    test('returns true immediately when the probe reports healthy', () async {
      final controller = _FakeProcessController();
      final probe = _FakeHealthProbe(true);
      final repository = _FakeRepositoryConnection();

      final supervisor = buildSupervisor(
        controller: controller,
        probe: probe,
        repository: repository,
        localLicenseCheck: () async => true,
        licenseDecryptValidate: () async => true,
        sessionRestore: () async {},
      );

      final healthy = await supervisor.healthCheck(
        window: const Duration(milliseconds: 200),
      );

      expect(healthy, isTrue);
      expect(probe.checkCount, 1);
    });

    test(
      'returns false after the window elapses when the probe stays unhealthy',
      () async {
        final controller = _FakeProcessController();
        final probe = _FakeHealthProbe(false);
        final repository = _FakeRepositoryConnection();

        final supervisor = buildSupervisor(
          controller: controller,
          probe: probe,
          repository: repository,
          localLicenseCheck: () async => true,
          licenseDecryptValidate: () async => true,
          sessionRestore: () async {},
        );

        final healthy = await supervisor.healthCheck(
          window: const Duration(milliseconds: 120),
        );

        expect(healthy, isFalse);
        expect(probe.checkCount, greaterThanOrEqualTo(1));
      },
    );
  });

  group('shutdown — graceful then force (Req 3.7)', () {
    test('requests graceful termination and does NOT force-kill when the '
        'process exits within the graceful window', () async {
      final controller = _FakeProcessController(
        handleFactory: () => _FakeProcessHandle(exitOnTerminate: true),
      );
      final probe = _FakeHealthProbe(true);
      final repository = _FakeRepositoryConnection();

      final supervisor = buildSupervisor(
        controller: controller,
        probe: probe,
        repository: repository,
        localLicenseCheck: () async => true,
        licenseDecryptValidate: () async => true,
        sessionRestore: () async {},
      );

      // Startup sets the supervised process handle.
      await supervisor.runStartupSequence();
      final handle = controller.lastHandle;

      await supervisor.shutdown(graceful: const Duration(seconds: 1));

      expect(handle.terminateCalled, isTrue, reason: 'graceful SIGTERM');
      expect(handle.killCalled, isFalse, reason: 'no force-kill needed');
    });

    test('force-terminates when the process does not exit within the graceful '
        'window', () async {
      // exitOnTerminate=false: process ignores SIGTERM, must be force-killed.
      final controller = _FakeProcessController(
        handleFactory: () => _FakeProcessHandle(exitOnTerminate: false),
      );
      final probe = _FakeHealthProbe(true);
      final repository = _FakeRepositoryConnection();

      final supervisor = buildSupervisor(
        controller: controller,
        probe: probe,
        repository: repository,
        localLicenseCheck: () async => true,
        licenseDecryptValidate: () async => true,
        sessionRestore: () async {},
      );

      await supervisor.runStartupSequence();
      final handle = controller.lastHandle;

      // Short graceful window so the timeout fires quickly.
      await supervisor.shutdown(graceful: const Duration(milliseconds: 50));

      expect(handle.terminateCalled, isTrue, reason: 'graceful attempted');
      expect(handle.killCalled, isTrue, reason: 'force-kill after timeout');
    });

    test('is a no-op when there is no running process', () async {
      final controller = _FakeProcessController();
      final probe = _FakeHealthProbe(true);
      final repository = _FakeRepositoryConnection();

      final supervisor = buildSupervisor(
        controller: controller,
        probe: probe,
        repository: repository,
        localLicenseCheck: () async => true,
        licenseDecryptValidate: () async => true,
        sessionRestore: () async {},
      );

      // No startup performed, so no process exists.
      await supervisor.shutdown(graceful: const Duration(milliseconds: 50));

      expect(controller.spawnCount, 0);
    });
  });

  group(
    'unexpected exit — restart + unrecoverable failure (Req 3.8 / 3.9)',
    () {
      test(
        'records exactly 3 RestartEvents and then emits unrecoverableFailure + '
        'disconnects the repository when restarts keep failing',
        () async {
          // Startup uses a controllable handle; restarts then fail by throwing.
          final controller = _FakeProcessController(
            handleFactory: () => _FakeProcessHandle(),
          );
          final probe = _FakeHealthProbe(true);
          final repository = _FakeRepositoryConnection();

          final supervisor = buildSupervisor(
            controller: controller,
            probe: probe,
            repository: repository,
            localLicenseCheck: () async => true,
            licenseDecryptValidate: () async => true,
            sessionRestore: () async {},
          );

          final restartEvents = <RestartEvent>[];
          supervisor.restarts.listen(restartEvents.add);
          final unrecoverable = supervisor.unrecoverableFailure.first;

          // Bring the backend up cleanly.
          await supervisor.runStartupSequence();
          expect(repository.connectCount, 1);
          final startupHandle = controller.lastHandle;

          // Every subsequent (re)spawn fails to start the backend.
          controller.throwOnSpawn = true;

          // Simulate the running backend dying unexpectedly.
          startupHandle.simulateExit(1);

          // Wait for the restart loop to exhaust its attempts.
          await unrecoverable.timeout(const Duration(seconds: 5));

          // Req 3.8: three consecutive restart attempts, each recorded.
          expect(restartEvents.length, 3);
          expect(restartEvents.map((e) => e.attempt).toList(), <int>[1, 2, 3]);
          // Req 3.9: repository marked disconnected after exhaustion.
          expect(repository.disconnectCount, 1);
          // 1 startup spawn + 3 failed restart spawns.
          expect(controller.spawnCount, 4);
        },
      );

      test(
        'a successful restart stops the loop without an unrecoverable failure '
        '(Req 3.8)',
        () async {
          final controller = _FakeProcessController(
            handleFactory: () => _FakeProcessHandle(),
          );
          // Probe healthy throughout, so a respawn recovers immediately.
          final probe = _FakeHealthProbe(true);
          final repository = _FakeRepositoryConnection();

          final supervisor = buildSupervisor(
            controller: controller,
            probe: probe,
            repository: repository,
            localLicenseCheck: () async => true,
            licenseDecryptValidate: () async => true,
            sessionRestore: () async {},
          );

          final restartEvents = <RestartEvent>[];
          supervisor.restarts.listen(restartEvents.add);
          var unrecoverableEmitted = false;
          supervisor.unrecoverableFailure.listen((_) {
            unrecoverableEmitted = true;
          });

          await supervisor.runStartupSequence();
          final startupHandle = controller.lastHandle;

          // Crash once; the respawn (controller still healthy) recovers.
          startupHandle.simulateExit(1);

          // Give the async restart loop time to run.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(
            restartEvents.length,
            1,
            reason: 'one restart, then recovered',
          );
          expect(restartEvents.single.attempt, 1);
          expect(unrecoverableEmitted, isFalse);
          expect(repository.disconnectCount, 0);
        },
      );
    },
  );
}
