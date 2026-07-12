import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/isolation/business_capability.dart';
import '../../core/isolation/feature_resolver.dart';
import '../../core/isolation/role_capability_binding.dart';
import '../../providers/app_state_providers.dart';
import 'sidebar_configuration.dart' show currentUserRoleProvider;

class PermissionWrapper extends ConsumerWidget {
  final BusinessCapability capability;
  final Widget child;
  final Widget? fallback;
  final bool maintainSize;

  const PermissionWrapper({
    super.key,
    required this.capability,
    required this.child,
    this.fallback,
    this.maintainSize = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessTypeState = ref.watch(businessTypeProvider);
    final hasAccess = FeatureResolver.canAccess(
      businessTypeState.type.name,
      capability,
    );

    if (!hasAccess) {
      return _buildFallback();
    }

    // Role-Capability Binding gate (Req 2.12): if this capability has a role
    // binding, check the current user's role is in the allowed set.
    final userRole = ref.watch(currentUserRoleProvider);
    if (!RoleCapabilityBinding.canAccess(capability, userRole)) {
      return _buildFallback();
    }

    return child;
  }

  Widget _buildFallback() {
    if (fallback != null) {
      return fallback!;
    }

    if (maintainSize) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child,
      );
    }

    return const SizedBox.shrink();
  }
}
