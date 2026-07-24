/// MobileShop Billing Bridge — DI Registration for Required Dependencies
///
/// Documents and provides the dependency injection bridge that ensures
/// [BillsRepository] receives a non-null IMEI validator and consistency
/// orchestrator for mobileShop tenants.
///
/// The bridge:
/// - Registers [MobileSaleImeiValidator] with the service locator
/// - Registers [MobileSaleConsistencyOrchestratorImpl] with the service locator
/// - Fails closed at startup if required dependencies cannot be constructed
///   for a mobileShop tenant (rather than silently skipping at runtime)
/// - Leaves non-mobileShop business types completely unaffected
///
/// Integration note:
/// The actual `service_locator.dart` registration should call
/// [registerMobileShopBillingDependencies] during app initialization.
/// This is intentionally a separate function so the main DI file does not
/// need to understand mobile-shop internals — it just calls the bridge.
///
/// Requirements: 2.5–2.6, 3.3–3.11, 3.12, 7.2–7.6, 12.3, 12.7–12.10; GR-3
/// Audit: AF-19, AF-20, AF-21, AF-37, AF-49
library;

import 'package:get_it/get_it.dart';

import '../api/mobile_shop_api.dart';
import '../auth/tenant_context_resolver.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../sync/mobile_sync_coordinator.dart';
import 'mobile_sale_consistency_orchestrator.dart';
import 'mobile_sale_imei_validator.dart';

// Re-export the validator, orchestrator, and error for convenience
export 'mobile_sale_consistency_orchestrator.dart';
export 'mobile_sale_imei_validator.dart';

// ─── DI Registration ─────────────────────────────────────────────────────────

/// Registers mobile-shop billing dependencies into the provided [GetIt]
/// service locator instance.
///
/// Call this during app initialization AFTER [TenantContextResolver] is
/// registered. For mobileShop tenants, this ensures [MobileSaleImeiValidator]
/// is available as a non-null dependency.
///
/// For non-mobileShop tenants, the validator is still registered but will
/// throw [MobileShopDependencyError] if invoked — this provides defense-in-depth.
/// Non-mobileShop billing paths should not invoke the validator at all.
///
/// ## Fail-closed behavior
///
/// If [TenantContextResolver] is not registered when this function runs,
/// it throws immediately — preventing the app from starting in a broken
/// state where mobileShop IMEI validation would silently skip (AF-19).
///
/// ## Usage in service_locator.dart
///
/// ```dart
/// import 'package:dukanx/features/mobile_shop/billing/mobile_shop_billing_bridge.dart';
///
/// void setupDependencies() {
///   // ... existing registrations ...
///
///   // After TenantContextResolver is registered:
///   registerMobileShopBillingDependencies(sl);
///
///   // Then BillsRepository can be registered with a non-null validator
///   // for the mobileShop path.
/// }
/// ```
void registerMobileShopBillingDependencies(GetIt sl) {
  // Fail-closed: require TenantContextResolver to be registered
  if (!sl.isRegistered<TenantContextResolver>()) {
    throw MobileShopDependencyError(
      'TenantContextResolver must be registered before mobile-shop billing '
      'dependencies. IMEI validation cannot be wired without tenant context. '
      'This is a startup configuration error (AF-19).',
    );
  }

  // Register MobileSaleImeiValidator as a lazy singleton.
  // It depends on TenantContextResolver which is already registered.
  if (!sl.isRegistered<MobileSaleImeiValidator>()) {
    sl.registerLazySingleton<MobileSaleImeiValidator>(
      () => MobileSaleImeiValidator(resolver: sl<TenantContextResolver>()),
    );
  }

  // Register MobileSaleConsistencyOrchestrator as a lazy singleton.
  // Routes all mobileShop sale/cancel/return operations through the outbox
  // and backend with authoritative confirmation semantics (Req 12.7–12.10).
  if (!sl.isRegistered<MobileSaleConsistencyOrchestrator>()) {
    sl.registerLazySingleton<MobileSaleConsistencyOrchestrator>(
      () => MobileSaleConsistencyOrchestratorImpl(
        repository: sl<MobileShopLocalRepository>(),
        api: sl<MobileShopApi>(),
        syncCoordinator: sl<MobileSyncCoordinatorInterface>(),
      ),
    );
  }
}

// ─── Assertion helper ────────────────────────────────────────────────────────

/// Asserts that the mobile-shop billing validator and orchestrator are
/// available and functional.
///
/// Call this during startup health checks or integration tests to verify the
/// DI wiring is correct. For mobileShop tenants, this should never fail in
/// a correctly configured application.
///
/// Throws [MobileShopDependencyError] if:
/// - [MobileSaleImeiValidator] is not registered
/// - [MobileSaleConsistencyOrchestrator] is not registered
/// - The validator cannot resolve tenant context
void assertMobileShopBillingReady(GetIt sl) {
  if (!sl.isRegistered<MobileSaleImeiValidator>()) {
    throw MobileShopDependencyError(
      'MobileSaleImeiValidator is not registered. '
      'For mobileShop tenants, IMEI validation is mandatory. '
      'Call registerMobileShopBillingDependencies() during initialization.',
    );
  }

  if (!sl.isRegistered<MobileSaleConsistencyOrchestrator>()) {
    throw MobileShopDependencyError(
      'MobileSaleConsistencyOrchestrator is not registered. '
      'For mobileShop tenants, all sale/cancel/return operations must route '
      'through the consistency orchestrator (Req 12.7–12.10). '
      'Call registerMobileShopBillingDependencies() during initialization.',
    );
  }
}
