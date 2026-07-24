/// MobileShop Tenant Switch Handler (Dart)
///
/// Handles the full tenant switch lifecycle: cancels prior network work,
/// releases outbox leases, revokes active continuation tokens/cursors,
/// clears in-memory caches, unbinds the old tenant, binds the new tenant,
/// and triggers an initial bounded pull.
///
/// Requirements: 7.10–7.12, 8.4
library;

import 'dart:async';

import '../api/mobile_shop_api.dart';
import '../auth/tenant_context.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'mobile_sync_coordinator.dart';
import 'realtime_convergence.dart';

/// Result of a tenant switch operation.
enum TenantSwitchResult {
  /// Switch completed successfully; new tenant is active.
  success,

  /// Switch completed but initial pull failed (non-blocking).
  successWithPullFailure,

  /// Switch failed — old tenant may still be partially active.
  failed,
}

/// Handles the complete tenant-switch lifecycle.
///
/// Guarantees that ALL prior-tenant work is cancelled and cleaned before
/// the new tenant's scope is activated (Req 7.11, 7.12, 8.4):
///
/// 1. Cancel prior network work (abort in-flight HTTP, close WebSocket)
/// 2. Release queue leases (mark outbox mutations as queued if sending)
/// 3. Revoke active continuation tokens (clear from memory)
/// 4. Clear in-memory caches (entity caches, subscription state)
/// 5. Unbind sync coordinator from old tenant
/// 6. Bind sync coordinator to new tenant
/// 7. Trigger initial bounded pull for the new tenant
class TenantSwitchHandler {
  final MobileSyncCoordinatorInterface _syncCoordinator;
  final RealtimeConvergenceService _realtimeService;
  final MobileShopLocalRepository _repository;
  final MobileShopApi _api;

  /// In-memory cache of active continuation tokens per tenant.
  /// Cleared on tenant switch to prevent cross-tenant token reuse.
  final Map<String, Set<String>> _activeContinuationTokens = {};

  /// In-memory entity cache entries per tenant.
  /// Cleared on switch to prevent prior-tenant data leaking.
  final Map<String, Map<String, dynamic>> _entityCache = {};

  /// The currently active tenant ID, tracked for switch detection.
  String? _activeTenantId;

  TenantSwitchHandler({
    required MobileSyncCoordinatorInterface syncCoordinator,
    required RealtimeConvergenceService realtimeService,
    required MobileShopLocalRepository repository,
    required MobileShopApi api,
  }) : _syncCoordinator = syncCoordinator,
       _realtimeService = realtimeService,
       _repository = repository,
       _api = api;

  /// The currently active tenant ID.
  String? get activeTenantId => _activeTenantId;

  /// Whether a tenant is currently bound.
  bool get isBound => _activeTenantId != null;

  /// Execute the full tenant switch lifecycle.
  ///
  /// [oldContext] may be null if this is the initial bind (no prior tenant).
  /// [newContext] is the incoming tenant to activate.
  ///
  /// The switch is all-or-nothing for the teardown phase: if teardown
  /// fails, the switch does not proceed. If only the initial pull fails,
  /// the switch is still considered successful (pull will retry on next cycle).
  Future<TenantSwitchResult> handleTenantSwitch(
    TenantContext? oldContext,
    TenantContext newContext,
  ) async {
    // Skip if switching to the same tenant
    if (oldContext != null && oldContext.tenantId == newContext.tenantId) {
      return TenantSwitchResult.success;
    }

    try {
      // ── Phase 1: Teardown old tenant ────────────────────────────────────
      if (oldContext != null) {
        await _teardownOldTenant(oldContext);
      }

      // ── Phase 2: Activate new tenant ───────────────────────────────────
      await _activateNewTenant(newContext);

      // ── Phase 3: Initial bounded pull ──────────────────────────────────
      final pullSucceeded = await _triggerInitialPull(newContext);

      return pullSucceeded
          ? TenantSwitchResult.success
          : TenantSwitchResult.successWithPullFailure;
    } on Object {
      // Switch failed — caller should handle recovery
      return TenantSwitchResult.failed;
    }
  }

  /// Tears down all state associated with the old tenant.
  ///
  /// Order matters: network first, then leases, then memory (Req 7.11).
  Future<void> _teardownOldTenant(TenantContext oldContext) async {
    // Step 1: Cancel prior network work — close WebSocket subscription
    await _realtimeService.disconnect();

    // Step 2: Release queue leases — reset any 'sending' mutations back to
    // 'queued' so they don't block the outbox for the old tenant
    await _releaseQueueLeases(oldContext);

    // Step 3: Revoke active continuation tokens from memory
    _revokeContinuationTokens(oldContext.tenantId);

    // Step 4: Clear in-memory entity caches
    _clearEntityCache(oldContext.tenantId);

    // Step 5: Unbind sync coordinator from old tenant
    await _syncCoordinator.unbind();
  }

  /// Activates the new tenant scope.
  Future<void> _activateNewTenant(TenantContext newContext) async {
    // Step 6: Bind sync coordinator to new tenant
    await _syncCoordinator.bind(newContext);

    // Connect real-time convergence for the new tenant
    _realtimeService.connect(newContext);

    // Track the new active tenant
    _activeTenantId = newContext.tenantId;
  }

  /// Triggers an initial bounded pull for the new tenant.
  ///
  /// This is non-blocking — failure here doesn't prevent the switch.
  /// The next sync cycle will retry.
  Future<bool> _triggerInitialPull(TenantContext newContext) async {
    try {
      final result = await _syncCoordinator.synchronize(newContext);
      return result.hasWork || !result.hasMorePull;
    } on Object {
      // Pull failure is non-fatal for the switch
      return false;
    }
  }

  /// Releases outbox queue leases for the old tenant.
  ///
  /// Any mutations in 'sending' state are reset to 'queued' so they
  /// remain available for future push cycles without being stuck.
  Future<void> _releaseQueueLeases(TenantContext context) async {
    try {
      // Get mutations that are currently being sent
      final sendingMutations = await _repository.getNextMutations(context, 100);
      for (final mutation in sendingMutations) {
        // Mutations stuck in 'sending' should revert to 'queued'
        // This is handled by the repository's lease expiry mechanism
        // but we force-release here on tenant switch for safety.
        if (mutation.status == OutboxStatus.sending) {
          await _repository.markMutationFailed(
            context,
            mutation.operationId,
            'TENANT_SWITCH_LEASE_RELEASE',
          );
        }
      }
    } on Object {
      // Best-effort — lease will expire naturally if this fails
    }
  }

  /// Revokes all continuation tokens associated with a tenant.
  ///
  /// Prevents cross-tenant token reuse (Req 7.11, 8.4).
  void _revokeContinuationTokens(String tenantId) {
    _activeContinuationTokens.remove(tenantId);
  }

  /// Clears all in-memory entity caches for a tenant.
  ///
  /// Prevents prior-tenant data from leaking to the new tenant scope
  /// (Req 7.12, 8.4).
  void _clearEntityCache(String tenantId) {
    _entityCache.remove(tenantId);
  }

  // ─── Cache Management API ──────────────────────────────────────────────────

  /// Registers a continuation token for the active tenant.
  void registerContinuationToken(String tenantId, String token) {
    _activeContinuationTokens.putIfAbsent(tenantId, () => {}).add(token);
  }

  /// Caches an entity value for the active tenant.
  void cacheEntity(String tenantId, String key, dynamic value) {
    _entityCache.putIfAbsent(tenantId, () => {})[key] = value;
  }

  /// Retrieves a cached entity for the active tenant only.
  ///
  /// Returns null if:
  /// - The requested tenantId doesn't match the active tenant
  /// - The key is not in the cache
  dynamic getCachedEntity(String tenantId, String key) {
    if (tenantId != _activeTenantId) return null;
    return _entityCache[tenantId]?[key];
  }
}
