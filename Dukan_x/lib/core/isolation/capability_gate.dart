import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/business_type.dart';
import '../../providers/app_state_providers.dart';
import 'business_capability.dart';
import 'feature_resolver.dart';

/// A guard widget that gates access to a child screen via [FeatureResolver.canAccess].
///
/// Evaluated BEFORE the child renders. If the active business type does not hold
/// the required [capability], the child is NOT rendered and an access-denied
/// message is shown instead.
///
/// The denial message:
/// - Names the required capability when the session's business type is in the
///   [allowedTypes] but lacks the capability (e.g. "Requires useWarranty capability").
/// - Names the allowed business types (plural, inclusive of mobileShop where
///   applicable) when the session's business type is not in [allowedTypes]
///   (e.g. "Available for: Computer Shop, Mobile Phone Shop").
/// - NEVER names only "Computer Shop" for a screen that mobileShop may now use.
///
/// Usage (inside a route builder, nested inside VendorRoleGuard + BusinessGuard):
/// ```dart
/// CapabilityGate(
///   capability: BusinessCapability.useWarranty,
///   allowedTypes: [BusinessType.computerShop, BusinessType.mobileShop],
///   child: const WarrantyScreen(),
/// )
/// ```
class CapabilityGate extends ConsumerWidget {
  /// The capability required to access the child screen.
  final BusinessCapability capability;

  /// The screen to render when the capability is held.
  final Widget child;

  /// The full list of business types allowed to access this screen (used in
  /// the denial message for business types not in the allow-list).
  final List<BusinessType> allowedTypes;

  const CapabilityGate({
    super.key,
    required this.capability,
    required this.child,
    required this.allowedTypes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessTypeState = ref.watch(businessTypeProvider);
    final currentType = businessTypeState.type;
    final currentTypeName = currentType.name;

    // Check capability via FeatureResolver (strict-deny, default false).
    final hasCapability = FeatureResolver.canAccess(
      currentTypeName,
      capability,
    );

    if (hasCapability) {
      return child;
    }

    // --- Access denied: build an informative denial widget ---

    // Determine whether the current type is in the allow-list but lacks the
    // capability, or is entirely outside the allow-list.
    final isInAllowList = allowedTypes.contains(currentType);

    final String denialText;
    if (isInAllowList) {
      // The business type is allowed on the route level but lacks the specific
      // capability — name the capability.
      denialText = 'Requires ${capability.name} capability.';
    } else {
      // The business type is not in the allow-list — name all allowed types.
      final typeLabels = allowedTypes.map(_businessTypeLabel).toList();
      denialText = 'Available for: ${typeLabels.join(', ')}.';
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Feature Access Restricted',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              denialText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps a [BusinessType] enum to a user-friendly label.
  static String _businessTypeLabel(BusinessType type) {
    switch (type) {
      case BusinessType.computerShop:
        return 'Computer Shop';
      case BusinessType.mobileShop:
        return 'Mobile Phone Shop';
      case BusinessType.electronics:
        return 'Electronics';
      default:
        // CamelCase → spaced title case (fallback for other types).
        final name = type.name;
        final buffer = StringBuffer();
        for (int i = 0; i < name.length; i++) {
          final char = name[i];
          if (i > 0 &&
              char == char.toUpperCase() &&
              char != char.toLowerCase()) {
            buffer.write(' ');
          }
          buffer.write(i == 0 ? char.toUpperCase() : char);
        }
        return buffer.toString();
    }
  }
}
