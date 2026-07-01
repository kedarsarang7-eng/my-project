import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_state_providers.dart';
import '../business_capability.dart';
import '../feature_resolver.dart';

/// A widget that selectively shows its child based on the current Business Type's capabilities.
///
/// If access is denied, it renders the [replacement] widget (default: SizedBox.shrink).
class FeatureGate extends ConsumerWidget {
  final BusinessCapability capability;
  final Widget child;
  final Widget replacement;

  const FeatureGate({
    super.key,
    required this.capability,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessTypeState = ref.watch(businessTypeProvider);

    // FIX: Convert enum to string for the resolver since it expects string
    final businessTypeName = businessTypeState.type.name;

    if (FeatureResolver.canAccess(businessTypeName, capability)) {
      return child;
    }

    return replacement;
  }
}

/// A builder version of FeatureGate that passes the access state to the builder.
/// Useful if you want to render the widget but disabled/greyed out instead of hiding it.
class FeatureGateBuilder extends ConsumerWidget {
  final BusinessCapability capability;
  final Widget Function(BuildContext context, bool isEnabled) builder;

  const FeatureGateBuilder({
    super.key,
    required this.capability,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessTypeState = ref.watch(businessTypeProvider);
    final businessTypeName = businessTypeState.type.name;
    final canAccess = FeatureResolver.canAccess(businessTypeName, capability);

    return builder(context, canAccess);
  }
}
