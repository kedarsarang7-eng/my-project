// ============================================================================
// UPDATE SERVICE — Unit tests
// ============================================================================
// Feature: offline-license-activation (task 19.2)
//
// Exercises DefaultUpdateService with hand-written fakes (matching existing
// test conventions) so the policy/flows are fast and deterministic without
// real connectivity or a real installer.
//
// Covered Requirements:
//   18.1 — A user-triggered check surfaces available / no-update / failed.
//   18.2 — A mandatory security patch must be applied (cannot be deferred).
//   18.3 — A non-mandatory update may be deferred.
//   18.4 — A mandatory security patch is not deferrable.
//   18.5 — Applying an update never modifies Local_Store data (the service
//          holds no Local_Store reference; the installer touches binaries only).
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/mode/update_service.dart';
import 'package:dukanx/core/mode/local_config.dart';

// ----------------------------------------------------------------------------
// Test doubles
// ----------------------------------------------------------------------------

/// In-memory [LocalConfig] that keeps the deferred-update version set in a
/// field instead of `flutter_secure_storage`, so deferral persistence can be
/// exercised without a platform channel. Only the deferred-update accessors
/// are overridden; the rest of the real implementation is unused here.
class _InMemoryLocalConfig extends LocalConfig {
  Set<String> _deferred = <String>{};

  @override
  Future<Set<String>> getDeferredUpdateVersions() async => <String>{
    ..._deferred,
  };

  @override
  Future<void> setDeferredUpdateVersions(Set<String> versions) async {
    _deferred = <String>{...versions};
  }
}

/// Fake [UpdateSource] that returns a pre-set update, or throws to model a
/// failed check (no connectivity / malformed manifest).
class _FakeUpdateSource implements UpdateSource {
  UpdateInfo? latest;
  bool throwOnFetch = false;
  int fetchCount = 0;

  @override
  Future<UpdateInfo?> fetchLatest() async {
    fetchCount++;
    if (throwOnFetch) throw StateError('no connectivity (simulated)');
    return latest;
  }
}

/// Fake [UpdateInstaller] that records installs and can be told to fail.
class _FakeUpdateInstaller implements UpdateInstaller {
  bool throwOnInstall = false;
  final List<String> installedVersions = <String>[];

  @override
  Future<void> install(UpdateInfo update) async {
    if (throwOnInstall) throw StateError('install failed (simulated)');
    installedVersions.add(update.version);
  }
}

const _mandatory = UpdateInfo(
  version: '1.4.2',
  isMandatorySecurityPatch: true,
  releaseNotes: 'Critical security fix',
);

const _optional = UpdateInfo(
  version: '1.5.0',
  isMandatorySecurityPatch: false,
  releaseNotes: 'New reports',
);

void main() {
  late _FakeUpdateSource source;
  late _FakeUpdateInstaller installer;
  late DefaultUpdateService service;

  setUp(() {
    source = _FakeUpdateSource();
    installer = _FakeUpdateInstaller();
    service = DefaultUpdateService(source: source, installer: installer);
  });

  group('checkForUpdates (Req 18.1)', () {
    test('surfaces an available update', () async {
      source.latest = _optional;

      final result = await service.checkForUpdates();

      expect(result, isA<UpdateAvailable>());
      expect((result as UpdateAvailable).update.version, '1.5.0');
      expect(source.fetchCount, 1);
    });

    test('reports no update when the installation is current', () async {
      source.latest = null;

      final result = await service.checkForUpdates();

      expect(result, isA<NoUpdateAvailable>());
    });

    test('reports failure when the probe throws (no connectivity)', () async {
      source.throwOnFetch = true;

      final result = await service.checkForUpdates();

      expect(result, isA<UpdateCheckFailed>());
    });
  });

  group('deferral policy (Req 18.2 / 18.3 / 18.4)', () {
    test('a non-mandatory update can be deferred', () async {
      expect(service.canDefer(_optional), isTrue);

      final result = await service.defer(_optional);

      expect(result, isA<UpdateDeferred>());
      expect(service.isDeferred(_optional.version), isTrue);
    });

    test('a mandatory security patch cannot be deferred', () async {
      expect(service.canDefer(_mandatory), isFalse);

      final result = await service.defer(_mandatory);

      expect(result, isA<DeferralRejected>());
      expect(service.isDeferred(_mandatory.version), isFalse);
    });
  });

  group('applyUpdate (Req 18.5)', () {
    test('applies an update via the installer and clears deferral', () async {
      await service.defer(_optional);
      expect(service.isDeferred(_optional.version), isTrue);

      final result = await service.applyUpdate(_optional);

      expect(result, isA<UpdateApplied>());
      expect(installer.installedVersions, contains('1.5.0'));
      // Once applied, the version is no longer considered deferred.
      expect(service.isDeferred(_optional.version), isFalse);
    });

    test('reports failure when the installer throws', () async {
      installer.throwOnInstall = true;

      final result = await service.applyUpdate(_mandatory);

      expect(result, isA<UpdateApplyFailed>());
      expect(installer.installedVersions, isEmpty);
    });
  });

  group('durable deferral via LocalConfig (Req 18.3)', () {
    test('a deferred non-mandatory update survives a restart', () async {
      final config = _InMemoryLocalConfig();
      final first = DefaultUpdateService(
        source: source,
        installer: installer,
        config: config,
      );

      await first.defer(_optional);
      expect(first.isDeferred(_optional.version), isTrue);

      // A fresh service instance (modelling an app restart) hydrates the
      // deferral set from the same persistent config.
      final restarted = DefaultUpdateService(
        source: source,
        installer: installer,
        config: config,
      );
      expect(restarted.isDeferred(_optional.version), isFalse);

      await restarted.loadDeferred();
      expect(restarted.isDeferred(_optional.version), isTrue);
    });

    test(
      'applying a deferred update clears it from persistent storage',
      () async {
        final config = _InMemoryLocalConfig();
        service = DefaultUpdateService(
          source: source,
          installer: installer,
          config: config,
        );

        await service.defer(_optional);
        expect(
          await config.getDeferredUpdateVersions(),
          contains(_optional.version),
        );

        await service.applyUpdate(_optional);
        expect(
          await config.getDeferredUpdateVersions(),
          isNot(contains(_optional.version)),
        );
      },
    );

    test('a mandatory patch is never written to persistent storage', () async {
      final config = _InMemoryLocalConfig();
      service = DefaultUpdateService(
        source: source,
        installer: installer,
        config: config,
      );

      await service.defer(_mandatory);

      expect(await config.getDeferredUpdateVersions(), isEmpty);
    });

    test('loadDeferred is a safe no-op when no config is injected', () async {
      // The default `service` has no config; loading must not throw.
      await service.loadDeferred();
      expect(service.isDeferred(_optional.version), isFalse);
    });
  });
}
