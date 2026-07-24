/// MobileShop Content-Host Guard — Permission-Checked Dispatch (Dart)
///
/// Wraps the existing content-host `getScreenForItem` dispatch to enforce
/// the same [MobilePolicyGuard] permission check before rendering any
/// mobile-shop screen through the in-shell content-host path.
///
/// Fixes AF-34: content_host no longer bypasses route permission checks.
/// The guard produces the same denial state as named routes (no silent
/// render without guard).
///
/// Requirements: 2.3–2.4, 2.9, 5.8, 8.3–8.7
/// Audit: AF-34
library;

import 'package:flutter/material.dart';

import '../auth/mobile_policy_guard.dart';
import '../auth/tenant_context_resolver.dart';
import 'mobile_shop_route_catalog.dart';
import 'mobile_shop_route_entry.dart';

/// A widget that wraps content-host screen dispatch with mobile-shop
/// policy guard checks.
///
/// Before rendering the target [child] screen, this widget verifies that
/// the current tenant has the required permission through [MobilePolicyGuard].
/// If access is denied, it renders the same denial state used by named routes
/// (no silent render without guard — fixes AF-34).
///
/// Usage in content_host dispatch:
/// ```dart
/// case 'imei_tracking':
///   return MobileShopContentHostGuard(
///     resolver: resolver,
///     requiredPermission: MobileShopPermissions.imeiView,
///     child: const ImeiTrackingStatementScreen(),
///   );
/// ```
class MobileShopContentHostGuard extends StatelessWidget {
  /// The resolver used for tenant context resolution.
  final TenantContextResolver resolver;

  /// The permission required to render this screen.
  /// Null means only business-type check is needed.
  final String? requiredPermission;

  /// The screen to render when access is granted.
  final Widget child;

  /// Optional custom denial builder.
  final Widget Function(BuildContext context, GuardDenial denial)?
  deniedBuilder;

  const MobileShopContentHostGuard({
    super.key,
    required this.resolver,
    this.requiredPermission,
    required this.child,
    this.deniedBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Use the same guard as sidebar, quick actions, deep links, and routes
    return MobilePolicyGuardWidget(
      resolver: resolver,
      requiredPermission: requiredPermission,
      builder: (ctx, tenantCtx) => child,
      deniedBuilder: deniedBuilder,
    );
  }
}

/// Resolves a content-host item ID to a guarded mobile-shop screen.
///
/// Returns a [MobileShopContentHostGuard]-wrapped screen if the [itemId]
/// matches a mobile-shop catalog entry, or `null` if it's not a mobile-shop
/// item (allowing fallback to the existing content-host resolution).
///
/// This function is the integration point between the existing
/// `SidebarNavigationHandler.getScreenForItem` and the new mobile-shop
/// policy guard. It ensures content-host dispatch for mobile-shop screens
/// enforces the same permission policy as named routes.
///
/// [screenBuilder] provides the actual screen widget to render when access
/// is granted. If null, a default "loading" placeholder is shown (callers
/// should provide the real screen from existing dispatch logic).
///
/// Usage:
/// ```dart
/// // In sidebar_navigation_handler.dart or content_host.dart:
/// final mobileScreen = guardedMobileShopScreen(
///   itemId,
///   resolver: resolver,
///   screenBuilder: () => const SecondHandIntakeScreen(),
/// );
/// if (mobileScreen != null) return mobileScreen;
/// // ... fall through to existing dispatch
/// ```
Widget? guardedMobileShopScreen(
  String itemId, {
  required TenantContextResolver resolver,
  Widget Function()? screenBuilder,
}) {
  // Find the catalog entry by ID
  final entry = _findEntryById(itemId);
  if (entry == null) return null;

  // Return a guarded widget that checks policy before rendering
  return MobileShopContentHostGuard(
    resolver: resolver,
    requiredPermission: entry.requiredPermission,
    child: screenBuilder != null
        ? screenBuilder()
        : const Center(child: Text('Loading mobile shop screen...')),
  );
}

// ─── Private Helpers ─────────────────────────────────────────────────────────

/// Finds a catalog entry by its ID.
MobileShopRouteEntry? _findEntryById(String itemId) {
  for (final entry in MobileShopRouteCatalog.all) {
    if (entry.id == itemId) return entry;
  }
  return null;
}
