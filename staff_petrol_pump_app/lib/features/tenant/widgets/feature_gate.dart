// ============================================================================
// Feature Gate — Manifest-Driven Feature Gating (Plan Feature System v2)
// (flutter_app variant)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tenant_config_provider.dart';

/// Feature Gate Widget — shows child only if feature is enabled in manifest
class FeatureGate extends ConsumerWidget {
  final String featureKey;
  final Widget child;
  final Widget? fallback;

  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(featureEnabledProvider(featureKey));

    if (isEnabled) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Multi-feature gate — shows child only if ALL features are enabled
class AllFeaturesGate extends ConsumerWidget {
  final List<String> featureKeys;
  final Widget child;
  final Widget? fallback;

  const AllFeaturesGate({
    super.key,
    required this.featureKeys,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEnabled = featureKeys.every(
      (key) => ref.watch(featureEnabledProvider(key)),
    );

    if (allEnabled) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
