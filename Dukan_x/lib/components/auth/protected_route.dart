import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dukanx/core/routing/route_paths.dart';
import '../../auth/auth_store.dart';
import 'access_denied.dart';

// ============================================================
// DEV BYPASS FLAG — set to false before FINAL PRODUCTION release
// ============================================================
const bool devBypassAuth = false; // Set to false to enforce RBAC checks

class ProtectedRoute extends ConsumerWidget {
  final Widget child;
  final String? requiredPermission;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.requiredPermission,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DEV MODE: skip all auth checks
    if (devBypassAuth) return child;

    final authState = ref.watch(authStoreProvider);

    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(RoutePaths.login);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (requiredPermission != null &&
        !authState.permissions.contains(requiredPermission)) {
      return const AccessDeniedScreen();
    }

    return child;
  }
}
