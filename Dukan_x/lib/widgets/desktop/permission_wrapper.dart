import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/isolation/business_capability.dart';
import '../../core/isolation/feature_resolver.dart';
import '../../providers/app_state_providers.dart';

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

    if (hasAccess) {
      return child;
    }

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
