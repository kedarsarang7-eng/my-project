/// MobileShop Deep Links — Guarded Deep Link Resolver (Dart)
///
/// Maps incoming deep link paths to catalog entries and applies the same
/// guard check before navigation. Unknown paths redirect to mobile-shop home.
/// Cross-vertical device screen paths (e.g. `/computer-shop/serial-history`)
/// redirect to the mobile-shop equivalent when business type is mobileShop.
///
/// All deep links use the same [MobilePolicyGuard] as sidebar, quick actions,
/// named routes, and content-host dispatch — one unified policy.
///
/// Requirements: 2.3–2.4, 2.9, 5.8, 8.3–8.7
/// Audit: AF-24–AF-26
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/mobile_policy_guard.dart';
import '../auth/tenant_context_resolver.dart';
import 'mobile_shop_route_catalog.dart';
import 'mobile_shop_route_entry.dart';
import 'mobile_shop_sidebar_builder.dart';

/// Result of resolving a deep link path.
sealed class DeepLinkResolution {
  const DeepLinkResolution();
}

/// The deep link resolved to a valid mobile-shop catalog entry.
final class DeepLinkResolved extends DeepLinkResolution {
  /// The catalog entry this deep link maps to.
  final MobileShopRouteEntry entry;
  const DeepLinkResolved(this.entry);
}

/// The deep link path was not found in the mobile-shop catalog.
final class DeepLinkNotFound extends DeepLinkResolution {
  /// The original path that could not be resolved.
  final String originalPath;
  const DeepLinkNotFound(this.originalPath);
}

/// The deep link was a cross-vertical path that should redirect to the
/// mobile-shop equivalent.
final class DeepLinkRedirect extends DeepLinkResolution {
  /// The mobile-shop equivalent path to redirect to.
  final String targetPath;

  /// The original cross-vertical path.
  final String originalPath;
  const DeepLinkRedirect({
    required this.targetPath,
    required this.originalPath,
  });
}

/// The deep link resolved but access was denied by the policy guard.
final class DeepLinkDenied extends DeepLinkResolution {
  final GuardDenial denial;
  const DeepLinkDenied(this.denial);
}

// ─── Cross-Vertical Redirect Map ─────────────────────────────────────────────

/// Maps cross-vertical device screen paths to their mobile-shop equivalents.
///
/// When a mobileShop tenant attempts to access a path originally scoped to
/// computerShop (e.g. `/computer-shop/serial-history`), this map provides the
/// mobile-shop equivalent route. This fixes AF-24–AF-26 where these screens
/// were blocked for mobileShop by BusinessGuard([computerShop]).
const Map<String, String> _crossVerticalRedirects = {
  // Computer shop serial/IMEI history → mobile-shop IMEI history
  '/computer-shop/serial-history': '/mobile-shop/imei/history',
  '/serial-history': '/mobile-shop/imei/history',

  // Computer shop warranty → mobile-shop warranty
  '/computer-shop/warranty': '/mobile-shop/warranty',
  '/warranty': '/mobile-shop/warranty',

  // Generic service-jobs path → mobile-shop service-jobs
  '/service-jobs': '/mobile-shop/service-jobs',
  '/service_jobs': '/mobile-shop/service-jobs',

  // Generic exchanges path → mobile-shop exchanges
  '/exchanges': '/mobile-shop/exchanges',

  // Generic IMEI tracking → mobile-shop IMEI
  '/imei-tracking': '/mobile-shop/imei',
  '/imei_tracking': '/mobile-shop/imei',
};

// ─── Deep Link Resolver ──────────────────────────────────────────────────────

/// Resolves a deep link path to a mobile-shop route entry.
///
/// Resolution order:
/// 1. Direct match in the mobile-shop route catalog → [DeepLinkResolved]
/// 2. Cross-vertical redirect map → [DeepLinkRedirect]
/// 3. No match → [DeepLinkNotFound]
class MobileShopDeepLinkResolver {
  final TenantContextResolver _resolver;
  final Set<String> _capabilities;
  final Set<String> _enabledFeatures;

  const MobileShopDeepLinkResolver({
    required TenantContextResolver resolver,
    Set<String> capabilities = const {},
    Set<String> enabledFeatures = const {},
  }) : _resolver = resolver,
       _capabilities = capabilities,
       _enabledFeatures = enabledFeatures;

  /// Resolves a deep link [path] to a [DeepLinkResolution].
  ///
  /// Checks the mobile-shop route catalog first, then cross-vertical
  /// redirects, and finally returns not-found for unknown paths.
  DeepLinkResolution resolve(String path) {
    // Normalize the path (trim trailing slash, lowercase)
    final normalizedPath = _normalizePath(path);

    // Step 1: Direct match in the catalog
    final catalogEntry = _findCatalogEntry(normalizedPath);
    if (catalogEntry != null) {
      return _checkAccess(catalogEntry);
    }

    // Step 2: Cross-vertical redirect
    final redirect = _crossVerticalRedirects[normalizedPath];
    if (redirect != null) {
      return DeepLinkRedirect(targetPath: redirect, originalPath: path);
    }

    // Step 3: Not found
    return DeepLinkNotFound(path);
  }

  /// Handles a deep link by resolving it and performing the appropriate
  /// navigation action.
  ///
  /// Returns `true` if the deep link was handled (navigated or shown denial),
  /// `false` if the path was not found.
  bool handleDeepLink(BuildContext context, String path) {
    final resolution = resolve(path);

    switch (resolution) {
      case DeepLinkResolved(:final entry):
        GoRouter.of(context).go(entry.routePath);
        return true;

      case DeepLinkRedirect(:final targetPath):
        GoRouter.of(context).go(targetPath);
        return true;

      case DeepLinkDenied(:final denial):
        _showDenialSnackbar(context, denial);
        // Navigate to mobile-shop home on denial
        GoRouter.of(context).go('/mobile-shop/imei');
        return true;

      case DeepLinkNotFound():
        // Navigate to mobile-shop home for unknown paths
        GoRouter.of(context).go('/mobile-shop/imei');
        return false;
    }
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  /// Finds a catalog entry matching the given path.
  MobileShopRouteEntry? _findCatalogEntry(String path) {
    for (final entry in MobileShopRouteCatalog.all) {
      if (entry.routePath == path) {
        return entry;
      }
    }
    return null;
  }

  /// Checks policy access for a resolved catalog entry.
  DeepLinkResolution _checkAccess(MobileShopRouteEntry entry) {
    final guard = MobilePolicyGuard(resolver: _resolver);
    final result = guard.check(requiredPermission: entry.requiredPermission);

    switch (result) {
      case GuardGranted(:final context):
        // Also verify capability and feature gate
        final sidebarBuilder = const MobileShopSidebarBuilder();
        final accessible = sidebarBuilder.isEntryAccessible(
          entry: entry,
          context: context,
          capabilities: _capabilities,
          enabledFeatures: _enabledFeatures,
        );
        if (accessible) {
          return DeepLinkResolved(entry);
        }
        // Capability/feature-gate denial
        return DeepLinkDenied(
          GuardDenial(
            kind: GuardDenialKind.permissionDenied,
            error: const DomainError.permissionDenied(),
          ),
        );

      case GuardDenied(:final denial):
        return DeepLinkDenied(denial);
    }
  }

  /// Normalizes a path for comparison (lowercase, strip trailing slash).
  String _normalizePath(String path) {
    var normalized = path.toLowerCase().trim();
    if (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Shows a snackbar with denial feedback.
  void _showDenialSnackbar(BuildContext context, GuardDenial denial) {
    final message = switch (denial.kind) {
      GuardDenialKind.sessionMissing => 'Please sign in to continue.',
      GuardDenialKind.wrongBusinessType =>
        'This feature is only available for Mobile Shop businesses.',
      GuardDenialKind.permissionDenied =>
        'You do not have permission to access this feature.',
    };

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
