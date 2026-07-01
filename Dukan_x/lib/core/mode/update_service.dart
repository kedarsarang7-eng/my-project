// ============================================================================
// UPDATE SERVICE — Offline_Lifetime_Mode application updates
// ============================================================================
// Feature: offline-license-activation (Task 19.2)
//
// The Update_Service checks for and applies application updates while the app
// runs in Offline_Lifetime_Mode (see the requirements Glossary). It implements
// Requirement 18:
//
//   18.1  A user-triggered update check runs in the BACKGROUND (asynchronously,
//         off the UI path) — modelled here as an async `checkForUpdates()` that
//         delegates the network probe to an injected [UpdateSource] seam.
//   18.2  A mandatory security patch MUST be applied.
//   18.3  A non-mandatory update MAY be deferred by the user.
//   18.4  A mandatory security patch MUST NOT be deferrable.
//   18.5  Applying an update NEVER modifies Local_Store data.
//
// Design constraints honoured here (see design.md, "Update_Service"):
//   * SERVICE LAYER ONLY. Pure Dart with no Flutter / widget-tree dependency;
//     injected through the existing `service_locator` (`sl`) and never
//     referenced by the UI. No UI changes are introduced.
//   * REUSE, DON'T REBUILD. The actual network probe and binary installation
//     are abstracted behind the [UpdateSource] / [UpdateInstaller] seams so the
//     concrete download/replace mechanism (and its tests) can be supplied
//     without coupling this policy layer to a transport.
//   * LOCAL_STORE IS NEVER TOUCHED (Req 18.5). This service holds NO reference
//     to the Local_Store / Drift database. Updates replace application binaries
//     only; the data directory is structurally out of reach here, so an update
//     can never mutate business data.
//
// The deferral POLICY (Req 18.2–18.4) is the pure, input-varying core of this
// component and is exposed as [canDefer] so it is directly testable
// (Property 38).
//
// Author: DukanX Engineering
// ============================================================================

import '../services/logger_service.dart';
import 'local_config.dart';

// ============================================================================
// Value types
// ============================================================================

/// Describes a single available application update returned by the
/// [UpdateSource].
///
/// [isMandatorySecurityPatch] is the field that drives the deferral policy
/// (Req 18.2–18.4): when `true` the update must be applied and cannot be
/// deferred; when `false` the user may defer it.
class UpdateInfo {
  /// The version string of the available update (e.g. `1.4.2`).
  final String version;

  /// Whether this update is a mandatory security patch (Req 18.2 / 18.4).
  ///
  /// `true`  → the update must be applied and cannot be deferred.
  /// `false` → the update is optional and the user may defer it (Req 18.3).
  final bool isMandatorySecurityPatch;

  /// Human-readable release notes, suitable for display/logging.
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.isMandatorySecurityPatch,
    this.releaseNotes = '',
  });

  @override
  String toString() =>
      'UpdateInfo(version: $version, '
      'mandatorySecurityPatch: $isMandatorySecurityPatch)';
}

// ============================================================================
// Result types (sealed — matches the mode layer's RouteResult style)
// ============================================================================

/// Outcome of a user-triggered update check (Req 18.1).
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

/// An update is available; [update] describes it (Req 18.1).
class UpdateAvailable extends UpdateCheckResult {
  final UpdateInfo update;
  const UpdateAvailable(this.update);
}

/// The check completed and the installation is already up to date (Req 18.1).
class NoUpdateAvailable extends UpdateCheckResult {
  const NoUpdateAvailable();
}

/// The check could not complete (e.g. no connectivity); [reason] explains why.
class UpdateCheckFailed extends UpdateCheckResult {
  final String reason;
  const UpdateCheckFailed(this.reason);
}

/// Outcome of a deferral request (Req 18.3 / 18.4).
sealed class DeferralResult {
  const DeferralResult();
}

/// The update was deferred at the user's request (Req 18.3).
class UpdateDeferred extends DeferralResult {
  final String version;
  const UpdateDeferred(this.version);
}

/// Deferral was rejected because the update is a mandatory security patch
/// (Req 18.4); [reason] explains why it cannot be deferred.
class DeferralRejected extends DeferralResult {
  final String reason;
  const DeferralRejected(this.reason);
}

/// Outcome of applying an update (Req 18.5).
sealed class UpdateApplyResult {
  const UpdateApplyResult();
}

/// The update was applied successfully; [version] is the applied version.
class UpdateApplied extends UpdateApplyResult {
  final String version;
  const UpdateApplied(this.version);
}

/// The update could not be applied; [reason] explains why.
class UpdateApplyFailed extends UpdateApplyResult {
  final String reason;
  const UpdateApplyFailed(this.reason);
}

// ============================================================================
// Injectable seams
// ============================================================================

/// Probes for the latest available application update (the background network
/// step of Req 18.1). Injectable/mockable so the policy layer is testable
/// without real connectivity.
abstract class UpdateSource {
  /// Returns the latest [UpdateInfo] when one is available, or `null` when the
  /// installation is already up to date. Throws on a check failure (no
  /// connectivity, malformed manifest, …); the [UpdateService] converts a
  /// thrown error into an [UpdateCheckFailed].
  Future<UpdateInfo?> fetchLatest();
}

/// Applies an update by replacing application binaries (Req 18.5).
///
/// Implementations MUST NOT touch the Local_Store / data directory — they only
/// stage and install the new application files. Injectable/mockable so apply
/// flows can be verified without a real installer.
abstract class UpdateInstaller {
  /// Stages and installs [update]'s application binaries. Throws on failure;
  /// the [UpdateService] converts a thrown error into an [UpdateApplyFailed].
  Future<void> install(UpdateInfo update);
}

/// A documented no-op [UpdateSource] used as the production default until a
/// concrete update channel (release manifest endpoint / file feed) is wired in.
///
/// It reports "no update available" so the Update_Service is fully functional
/// and testable end-to-end without a real update channel: the deferral policy
/// (Req 18.2–18.4) and the Local_Store-preservation guarantee (Req 18.5) hold
/// regardless of the source. Swap this for a concrete [UpdateSource] when the
/// release feed is available — no other wiring changes.
class NoOpUpdateSource implements UpdateSource {
  const NoOpUpdateSource();

  @override
  Future<UpdateInfo?> fetchLatest() async => null;
}

/// A documented no-op [UpdateInstaller] used as the production default until a
/// concrete installer (the desktop binary replacer) is wired in.
///
/// It performs no installation and, critically, holds no Local_Store reference,
/// so it cannot violate the "updates never modify Local_Store data" guarantee
/// (Req 18.5). Replace it with a concrete [UpdateInstaller] when the desktop
/// updater is available.
class NoOpUpdateInstaller implements UpdateInstaller {
  const NoOpUpdateInstaller();

  @override
  Future<void> install(UpdateInfo update) async {
    // Intentionally does nothing: no concrete installer is wired yet, and a
    // no-op install can never reach business data (Req 18.5).
  }
}

// ============================================================================
// Abstract service (matches design.md)
// ============================================================================

/// Checks for and applies application updates in Offline_Lifetime_Mode,
/// enforcing the mandatory-security-patch deferral policy and never modifying
/// Local_Store data (Requirement 18).
abstract class UpdateService {
  /// Runs a user-triggered update check in the background (Req 18.1).
  Future<UpdateCheckResult> checkForUpdates();

  /// The deferral POLICY (Req 18.2–18.4): an update may be deferred if and only
  /// if it is NOT a mandatory security patch. Pure and side-effect free.
  bool canDefer(UpdateInfo update);

  /// Defers [update] when policy permits (Req 18.3), or rejects the request for
  /// a mandatory security patch (Req 18.4).
  Future<DeferralResult> defer(UpdateInfo update);

  /// Applies [update] without modifying Local_Store data (Req 18.5).
  Future<UpdateApplyResult> applyUpdate(UpdateInfo update);

  /// Whether [version] is currently deferred by the user (Req 18.3).
  bool isDeferred(String version);

  /// Loads any previously deferred (non-mandatory) update versions from
  /// persistent storage so a deferral survives an application restart
  /// (Req 18.3). Safe to call once during service initialisation.
  Future<void> loadDeferred();
}

// ============================================================================
// Concrete service
// ============================================================================

/// Default [UpdateService] implementation.
///
/// All collaborators are injected so the check/apply flows are fully testable
/// without real connectivity or a real installer. It holds NO reference to the
/// Local_Store, which structurally guarantees Req 18.5: an update applied
/// through this service cannot reach business data.
///
/// An optional [LocalConfig] is used purely to persist the set of deferred
/// (non-mandatory) update versions so a deferral survives a restart (Req 18.3).
/// `LocalConfig` is configuration storage, NOT the Local_Store business data,
/// so persisting deferrals there does not weaken the Req 18.5 guarantee. When
/// no [LocalConfig] is injected the service degrades gracefully to in-memory
/// deferral, which keeps the pure deferral policy ([canDefer]) trivially
/// testable.
class DefaultUpdateService implements UpdateService {
  static const String _logTag = 'UpdateService';

  final UpdateSource _source;
  final UpdateInstaller _installer;

  /// Optional durable store for deferred versions (Req 18.3). When `null`,
  /// deferral state lives in memory only for the current session.
  final LocalConfig? _config;

  /// Versions the user has chosen to defer (Req 18.3). Held in memory and,
  /// when a [LocalConfig] is injected, mirrored to durable storage so the
  /// deferral survives a restart. A mandatory security patch is never added
  /// here (Req 18.4).
  final Set<String> _deferred = <String>{};

  DefaultUpdateService({
    required UpdateSource source,
    required UpdateInstaller installer,
    LocalConfig? config,
  }) : _source = source,
       _installer = installer,
       _config = config;

  // --------------------------------------------------------------------------
  // Deferral state hydration (Req 18.3 — survive restart)
  // --------------------------------------------------------------------------

  @override
  Future<void> loadDeferred() async {
    final config = _config;
    if (config == null) return;
    try {
      final stored = await config.getDeferredUpdateVersions();
      _deferred
        ..clear()
        ..addAll(stored);
      LoggerService.i(
        _logTag,
        'Loaded ${_deferred.length} deferred update version(s)',
      );
    } on Object catch (e) {
      // A failure to read persisted deferrals must never block update checks;
      // fall back to an empty in-memory set.
      LoggerService.w(_logTag, 'Failed to load deferred updates: $e');
    }
  }

  /// Mirrors the in-memory deferral set to durable storage when configured.
  /// Best-effort: a persistence failure is logged but never surfaced to the
  /// caller, since the in-memory state already reflects the user's choice.
  Future<void> _persistDeferred() async {
    final config = _config;
    if (config == null) return;
    try {
      await config.setDeferredUpdateVersions(_deferred);
    } on Object catch (e) {
      LoggerService.w(_logTag, 'Failed to persist deferred updates: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Update check (Req 18.1)
  // --------------------------------------------------------------------------

  @override
  Future<UpdateCheckResult> checkForUpdates() async {
    LoggerService.i(_logTag, 'Checking for updates in the background');
    try {
      final update = await _source.fetchLatest();
      if (update == null) {
        LoggerService.i(
          _logTag,
          'No update available; installation is current',
        );
        return const NoUpdateAvailable();
      }
      LoggerService.i(
        _logTag,
        'Update available: ${update.version} '
        '(mandatorySecurityPatch: ${update.isMandatorySecurityPatch})',
      );
      return UpdateAvailable(update);
    } on Object catch (e) {
      LoggerService.w(_logTag, 'Update check failed: $e');
      return UpdateCheckFailed('update check failed: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Deferral policy (Req 18.2 / 18.3 / 18.4)
  // --------------------------------------------------------------------------

  @override
  bool canDefer(UpdateInfo update) => !update.isMandatorySecurityPatch;

  @override
  Future<DeferralResult> defer(UpdateInfo update) async {
    // Req 18.4: a mandatory security patch can never be deferred.
    if (!canDefer(update)) {
      LoggerService.w(
        _logTag,
        'Deferral rejected for mandatory security patch ${update.version}',
      );
      return const DeferralRejected(
        'This is a mandatory security patch and must be applied; it cannot be '
        'deferred.',
      );
    }
    // Req 18.3: a non-mandatory update may be deferred.
    _deferred.add(update.version);
    await _persistDeferred();
    LoggerService.i(_logTag, 'Update ${update.version} deferred by user');
    return UpdateDeferred(update.version);
  }

  @override
  bool isDeferred(String version) => _deferred.contains(version);

  // --------------------------------------------------------------------------
  // Apply (Req 18.5 — never modifies Local_Store data)
  // --------------------------------------------------------------------------

  @override
  Future<UpdateApplyResult> applyUpdate(UpdateInfo update) async {
    LoggerService.i(_logTag, 'Applying update ${update.version}');
    try {
      // The installer replaces application binaries only; this service holds no
      // Local_Store reference, so applying an update cannot touch business data.
      await _installer.install(update);
      // A freshly applied version is no longer considered deferred.
      _deferred.remove(update.version);
      await _persistDeferred();
      LoggerService.i(_logTag, 'Update ${update.version} applied');
      return UpdateApplied(update.version);
    } on Object catch (e) {
      LoggerService.e(_logTag, 'Failed to apply update ${update.version}', e);
      return UpdateApplyFailed('failed to apply update: $e');
    }
  }
}
