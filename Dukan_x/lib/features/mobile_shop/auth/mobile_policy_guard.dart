/// MobileShop Policy Guard — Route/Widget Authorization (Dart)
///
/// Checks TenantContext availability, business type, and permission before
/// allowing access to a mobile-shop screen or widget subtree.
///
/// Applies identically to sidebar dispatch, quick actions, deep links,
/// named routes, and content_host widgets.
///
/// Fixes AF-46: null-session spinners replaced with actionable session-error.
///
/// Requirements: 2.1–2.4, 5.8–5.9, 8.3–8.7
library;

import 'package:flutter/material.dart';

import 'tenant_context_resolver.dart';

// ─── Guard Result ────────────────────────────────────────────────────────────

/// The outcome of a policy guard check.
enum GuardDenialKind {
  /// User is not authenticated; render session-error/signed-out state.
  sessionMissing,

  /// Business type is not mobile_shop; render denial state.
  wrongBusinessType,

  /// Required permission is not granted; render denial state.
  permissionDenied,
}

/// Typed denial produced by [MobilePolicyGuard].
class GuardDenial {
  final GuardDenialKind kind;
  final DomainError error;

  const GuardDenial({required this.kind, required this.error});
}

/// Result of guard evaluation: either access is granted (with context)
/// or denied (with a typed denial).
sealed class GuardResult {
  const GuardResult();
}

/// Access granted; the resolved [TenantContext] is available.
final class GuardGranted extends GuardResult {
  final TenantContext context;
  const GuardGranted(this.context);
}

/// Access denied with a specific denial reason.
final class GuardDenied extends GuardResult {
  final GuardDenial denial;
  const GuardDenied(this.denial);
}

// ─── Guard Logic ─────────────────────────────────────────────────────────────

/// Stateless policy guard for mobile-shop routes and widgets.
///
/// Usage:
/// ```dart
/// final guard = MobilePolicyGuard(resolver: resolver);
/// final result = guard.check(requiredPermission: MobileShopPermissions.serviceView);
/// switch (result) {
///   case GuardGranted(:final context): // render screen with context
///   case GuardDenied(:final denial):   // render denial state
/// }
/// ```
class MobilePolicyGuard {
  final TenantContextResolver _resolver;

  const MobilePolicyGuard({required TenantContextResolver resolver})
    : _resolver = resolver;

  /// Checks that:
  /// 1. TenantContext is available (authenticated)
  /// 2. BusinessType is mobileShop
  /// 3. Required permission (if any) is granted
  ///
  /// Returns [GuardGranted] with context or [GuardDenied] with typed denial.
  GuardResult check({String? requiredPermission}) {
    // Step 1+2: Require mobile shop context
    final result = _resolver.requireMobileShop();

    switch (result) {
      case TenantSuccess(:final value):
        // Step 3: Check permission if specified
        if (requiredPermission != null &&
            !value.hasPermission(requiredPermission)) {
          return GuardDenied(
            GuardDenial(
              kind: GuardDenialKind.permissionDenied,
              error: const DomainError.permissionDenied(),
            ),
          );
        }
        return GuardGranted(value);

      case TenantFailure(:final error):
        final kind = switch (error.kind) {
          DomainErrorKind.wrongBusinessType =>
            GuardDenialKind.wrongBusinessType,
          _ => GuardDenialKind.sessionMissing,
        };
        return GuardDenied(GuardDenial(kind: kind, error: error));
    }
  }

  /// Checks that the context has ANY of the specified permissions.
  GuardResult checkAny({required List<String> permissions}) {
    final result = _resolver.requireMobileShop();

    switch (result) {
      case TenantSuccess(:final value):
        if (!value.hasAnyPermission(permissions)) {
          return GuardDenied(
            GuardDenial(
              kind: GuardDenialKind.permissionDenied,
              error: const DomainError.permissionDenied(),
            ),
          );
        }
        return GuardGranted(value);

      case TenantFailure(:final error):
        final kind = switch (error.kind) {
          DomainErrorKind.wrongBusinessType =>
            GuardDenialKind.wrongBusinessType,
          _ => GuardDenialKind.sessionMissing,
        };
        return GuardDenied(GuardDenial(kind: kind, error: error));
    }
  }

  /// Checks that the context has ALL of the specified permissions.
  GuardResult checkAll({required List<String> permissions}) {
    final result = _resolver.requireMobileShop();

    switch (result) {
      case TenantSuccess(:final value):
        if (!value.hasAllPermissions(permissions)) {
          return GuardDenied(
            GuardDenial(
              kind: GuardDenialKind.permissionDenied,
              error: const DomainError.permissionDenied(),
            ),
          );
        }
        return GuardGranted(value);

      case TenantFailure(:final error):
        final kind = switch (error.kind) {
          DomainErrorKind.wrongBusinessType =>
            GuardDenialKind.wrongBusinessType,
          _ => GuardDenialKind.sessionMissing,
        };
        return GuardDenied(GuardDenial(kind: kind, error: error));
    }
  }

  /// Requires only authentication (any business type).
  /// Use for shared screens that are not mobile-shop-specific.
  GuardResult checkAuthenticated() {
    final result = _resolver.require();

    switch (result) {
      case TenantSuccess(:final value):
        return GuardGranted(value);

      case TenantFailure(:final error):
        return GuardDenied(
          GuardDenial(kind: GuardDenialKind.sessionMissing, error: error),
        );
    }
  }
}

// ─── Guard Widget ────────────────────────────────────────────────────────────

/// A widget that enforces mobile-shop policy before rendering its child.
///
/// - On success: calls [builder] with the resolved [TenantContext].
/// - On denial: calls [deniedBuilder] (or renders a default denial state).
///
/// This ensures NO domain read/write occurs when context is missing
/// (fixes AF-46: no spinner, no domain access).
class MobilePolicyGuardWidget extends StatelessWidget {
  /// The resolver to use for context resolution.
  final TenantContextResolver resolver;

  /// Required permission (optional — null means only business type check).
  final String? requiredPermission;

  /// Builder called when access is granted.
  final Widget Function(BuildContext context, TenantContext tenantContext)
  builder;

  /// Builder called when access is denied.
  /// If null, a default denial widget is rendered.
  final Widget Function(BuildContext context, GuardDenial denial)?
  deniedBuilder;

  const MobilePolicyGuardWidget({
    super.key,
    required this.resolver,
    this.requiredPermission,
    required this.builder,
    this.deniedBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final guard = MobilePolicyGuard(resolver: resolver);
    final result = guard.check(requiredPermission: requiredPermission);

    switch (result) {
      case GuardGranted(context: final tenantCtx):
        return builder(context, tenantCtx);
      case GuardDenied(:final denial):
        if (deniedBuilder != null) {
          return deniedBuilder!(context, denial);
        }
        return _DefaultDenialWidget(denial: denial);
    }
  }
}

/// Default denial state widget — actionable, not a spinner.
class _DefaultDenialWidget extends StatelessWidget {
  final GuardDenial denial;

  const _DefaultDenialWidget({required this.denial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, title, subtitle) = switch (denial.kind) {
      GuardDenialKind.sessionMissing => (
        Icons.lock_outline,
        'Session Expired',
        'Please sign in to continue.',
      ),
      GuardDenialKind.wrongBusinessType => (
        Icons.block_outlined,
        'Not Available',
        'This feature is only available for Mobile Shop businesses.',
      ),
      GuardDenialKind.permissionDenied => (
        Icons.no_encryption_outlined,
        'Access Denied',
        'You do not have permission to access this feature.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
