import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/business_type.dart';
import '../../../providers/app_state_providers.dart';

/// A guard widget that restricts access to its child based on the active [BusinessType].
///
/// Usage:
/// ```dart
/// BusinessGuard(
///   allowedTypes: [BusinessType.clinic],
///   fallback: Text('Not available for your shop type'),
///   child: DoctorDashboard(),
/// )
/// ```
class BusinessGuard extends ConsumerWidget {
  /// The widget to display if the business type matches.
  final Widget child;

  /// List of business types allowed to access this feature.
  final List<BusinessType> allowedTypes;

  /// Optional widget to show when access is denied.
  /// Defaults to [SizedBox.shrink()].
  final Widget? fallback;

  /// Optional message to show in a centered error container if fallback is null.
  /// If null, [SizedBox.shrink()] is used.
  final String? denialMessage;

  const BusinessGuard({
    super.key,
    required this.child,
    required this.allowedTypes,
    this.fallback,
    this.denialMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessState = ref.watch(businessTypeProvider);
    final currentType = businessState.type;

    if (allowedTypes.contains(currentType)) {
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    if (denialMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                denialMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
