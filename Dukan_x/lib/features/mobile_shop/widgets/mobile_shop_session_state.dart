/// MobileShop Session State — Actionable Session Guards (Dart)
///
/// Provides [MobileShopSessionGuardWidget] that renders actionable
/// signed-out/session-error states instead of perpetual spinners.
///
/// Fixes AF-46: no domain access when session is missing.
///
/// Requirements: 5.9, 11.12
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../auth/tenant_context_resolver.dart';

// ─── Session Guard Widget ────────────────────────────────────────────────────

/// A widget that requires a valid [TenantContext] before rendering its child.
///
/// - If session is available → renders [builder] with the resolved context.
/// - If session is missing/expired → renders [SessionExpiredView] (NOT a spinner).
///
/// This ensures no domain read or write occurs when session is missing.
/// Fixes AF-46: ExchangeListScreen (and similar) no longer show perpetual
/// spinners when userId is null.
class MobileShopSessionGuardWidget extends StatelessWidget {
  /// The resolver used for tenant context resolution.
  final TenantContextResolver resolver;

  /// Builder called when session is available and context is resolved.
  final Widget Function(BuildContext context, TenantContext tenantContext)
  builder;

  /// Optional custom widget for session-error state.
  /// If null, the default [SessionExpiredView] is rendered.
  final Widget Function(BuildContext context, DomainError error)? errorBuilder;

  const MobileShopSessionGuardWidget({
    super.key,
    required this.resolver,
    required this.builder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final result = resolver.require();

    return result.when(
      success: (tenantContext) => builder(context, tenantContext),
      failure: (error) {
        if (errorBuilder != null) {
          return errorBuilder!(context, error);
        }
        return SessionExpiredView(error: error);
      },
    );
  }
}

// ─── Session Expired View ────────────────────────────────────────────────────

/// An actionable session-error state widget.
///
/// Displays:
/// - Lock icon
/// - "Session Expired" title
/// - "Please sign in to continue" message
/// - "Sign In" button that routes to login
///
/// Fully accessible with semantic labels and roles.
class SessionExpiredView extends StatelessWidget {
  /// The domain error that caused the session failure.
  final DomainError error;

  const SessionExpiredView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Session expired. Please sign in to continue.',
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.error,
                semanticLabel: 'Session locked',
              ),
              const SizedBox(height: 16),
              Text(
                'Session Expired',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.message.isNotEmpty
                    ? error.message
                    : 'Please sign in to continue.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _navigateToLogin(context),
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to the login screen using GoRouter.
  void _navigateToLogin(BuildContext context) {
    GoRouter.of(context).go(RoutePaths.authGate);
  }
}
