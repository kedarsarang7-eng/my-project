/// MobileShop Quick Actions — Guarded Navigation Handler (Dart)
///
/// Handles quick-action taps by checking policy before navigation.
/// Replaces the empty `onTap: () {}` closures that made IMEI Lookup
/// and other quick actions non-functional (AF-07).
///
/// All quick actions use the same [MobilePolicyGuard] / [MobileShopSidebarBuilder]
/// policy as sidebar entries, deep links, named routes, and content-host dispatch.
///
/// Requirements: 2.3–2.4, 2.9, 5.8, 8.3–8.7
/// Audit: AF-07
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/mobile_policy_guard.dart';
import '../auth/tenant_context_resolver.dart';
import 'mobile_shop_route_entry.dart';
import 'mobile_shop_sidebar_builder.dart';

/// Handles a mobile-shop quick-action tap.
///
/// Checks whether the [entry] is accessible to the current tenant through the
/// same policy the sidebar uses. If accessible, navigates to the entry's route
/// path. If not accessible, shows an explicit denial (no silent no-op).
///
/// This function replaces the empty `onTap: () {}` closures that previously
/// left IMEI Lookup and other quick actions non-functional (AF-07).
///
/// Parameters:
/// - [buildContext] — Current build context (used for GoRouter navigation).
/// - [entry] — The [MobileShopRouteEntry] representing the quick action.
/// - [resolver] — The authoritative [TenantContextResolver].
/// - [capabilities] — Active capability strings for the tenant.
/// - [enabledFeatures] — Feature flags currently enabled.
void handleMobileShopQuickAction(
  BuildContext buildContext, {
  required MobileShopRouteEntry entry,
  required TenantContextResolver resolver,
  Set<String> capabilities = const {},
  Set<String> enabledFeatures = const {},
}) {
  // Use the same guard check the policy guard widget uses
  final guard = MobilePolicyGuard(resolver: resolver);
  final result = guard.check(requiredPermission: entry.requiredPermission);

  switch (result) {
    case GuardGranted(:final context):
      // Verify capability and feature-gate access using the sidebar builder's
      // isEntryAccessible — same logic as sidebar filtering.
      final sidebarBuilder = const MobileShopSidebarBuilder();
      final accessible = sidebarBuilder.isEntryAccessible(
        entry: entry,
        context: context,
        capabilities: capabilities,
        enabledFeatures: enabledFeatures,
      );

      if (accessible) {
        // Navigate to the entry's production route
        _navigateToEntry(buildContext, entry);
      } else {
        // Capability or feature-gate denial — show explicit feedback
        _showDenialSnackbar(
          buildContext,
          'This action requires a capability that is not enabled.',
        );
      }

    case GuardDenied(:final denial):
      // Permission/session/business-type denial — show explicit feedback
      _showDenialDialog(buildContext, denial);
  }
}

/// Convenience variant that navigates to a route entry by ID from the catalog.
///
/// Looks up the entry in [MobileShopRouteCatalog.all] by [entryId]. Returns
/// `false` if the entry is not found.
bool handleMobileShopQuickActionById(
  BuildContext buildContext, {
  required String entryId,
  required TenantContextResolver resolver,
  Set<String> capabilities = const {},
  Set<String> enabledFeatures = const {},
}) {
  final sidebarBuilder = const MobileShopSidebarBuilder();
  final entry = sidebarBuilder.findById(entryId);
  if (entry == null) return false;

  handleMobileShopQuickAction(
    buildContext,
    entry: entry,
    resolver: resolver,
    capabilities: capabilities,
    enabledFeatures: enabledFeatures,
  );
  return true;
}

// ─── Private Helpers ─────────────────────────────────────────────────────────

/// Navigates to the entry's route path using GoRouter.
void _navigateToEntry(BuildContext context, MobileShopRouteEntry entry) {
  GoRouter.of(context).go(entry.routePath);
}

/// Shows a snackbar with a denial message (for capability/feature-gate denials).
void _showDenialSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Shows a dialog for session/permission/business-type denials.
///
/// This ensures the user sees actionable feedback rather than a silent no-op
/// (fixes AF-07).
void _showDenialDialog(BuildContext context, GuardDenial denial) {
  final (icon, title, subtitle) = switch (denial.kind) {
    GuardDenialKind.sessionMissing => (
      Icons.lock_outline,
      'Session Expired',
      'Please sign in to continue.',
    ),
    GuardDenialKind.wrongBusinessType => (
      Icons.block_outlined,
      'Not Available',
      'This action is only available for Mobile Shop businesses.',
    ),
    GuardDenialKind.permissionDenied => (
      Icons.no_encryption_outlined,
      'Access Denied',
      'You do not have permission for this action.',
    ),
  };

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(icon),
      title: Text(title),
      content: Text(subtitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
