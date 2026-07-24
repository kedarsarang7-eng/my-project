/// Commerce UI Utilities — Masking, Policy Gating, Pending State Display
///
/// Shared utilities for all commerce UI flows:
/// - Sensitive value masking (PAN, account numbers, mobile numbers)
/// - Feature policy gate widget
/// - Pending/ambiguous outcome display
/// - Offline data preservation indicator
///
/// Requirements: 10.1–10.12, 12.1–12.8
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../config/feature_policy_config.dart';
import '../../widgets/mobile_shop_session_state.dart';
import 'mobile_commerce_service.dart';

// ─── Sensitive Value Masking ─────────────────────────────────────────────────

/// Masks sensitive values for display (PAN, account numbers, mobile numbers).
///
/// Rules:
/// - PAN: Shows last 4 characters → "XXXX XXXX 1234"
/// - Account numbers: Shows last 4 digits → "●●●●●●1234"
/// - Mobile numbers: Shows last 4 digits → "●●●●●●7890"
/// - Short values (≤4 chars): Fully masked → "●●●●"
class SensitiveMask {
  const SensitiveMask._();

  /// Masks a PAN or Aadhaar number, showing only last 4 characters.
  static String maskPan(String value) {
    if (value.isEmpty) return '';
    if (value.length <= 4) return '●' * value.length;
    final visible = value.substring(value.length - 4);
    final masked = 'X' * (value.length - 4);
    return '$masked$visible';
  }

  /// Masks an account number, showing only last 4 digits.
  static String maskAccountNumber(String value) {
    if (value.isEmpty) return '';
    if (value.length <= 4) return '●' * value.length;
    final visible = value.substring(value.length - 4);
    final masked = '●' * (value.length - 4);
    return '$masked$visible';
  }

  /// Masks a mobile number, showing only last 4 digits.
  static String maskMobileNumber(String value) {
    if (value.isEmpty) return '';
    if (value.length <= 4) return '●' * value.length;
    final visible = value.substring(value.length - 4);
    final masked = '●' * (value.length - 4);
    return '$masked$visible';
  }

  /// Generic mask: shows last [visibleChars] characters.
  static String mask(String value, {int visibleChars = 4}) {
    if (value.isEmpty) return '';
    if (value.length <= visibleChars) return '●' * value.length;
    final visible = value.substring(value.length - visibleChars);
    final masked = '●' * (value.length - visibleChars);
    return '$masked$visible';
  }
}

// ─── Feature Policy Gate Widget ──────────────────────────────────────────────

/// Widget that gates its child by feature policy.
///
/// If the feature is disabled, shows a disabled state message.
/// If enabled, renders the child.
///
/// Usage:
/// ```dart
/// FeaturePolicyGate(
///   featureId: 'OCR_INTAKE',
///   service: commerceService,
///   child: OcrIntakeScreen(...),
/// )
/// ```
class FeaturePolicyGate extends StatelessWidget {
  /// The feature ID to check against the policy.
  final String featureId;

  /// The commerce service (for policy checking).
  final MobileCommerceService service;

  /// The child to render when the feature is enabled.
  final Widget child;

  /// Optional custom widget for disabled state.
  final Widget? disabledWidget;

  const FeaturePolicyGate({
    super.key,
    required this.featureId,
    required this.service,
    required this.child,
    this.disabledWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (service.isFeatureEnabled(featureId)) {
      return child;
    }

    return disabledWidget ?? _DefaultDisabledView(featureId: featureId);
  }
}

class _DefaultDisabledView extends StatelessWidget {
  final String featureId;

  const _DefaultDisabledView({required this.featureId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Feature not available',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
                semanticLabel: 'Feature disabled',
              ),
              const SizedBox(height: 16),
              Text(
                'Feature Not Available',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is not enabled for your account. '
                'Contact your administrator to enable it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Commerce Outcome Display Widget ─────────────────────────────────────────

/// Displays the outcome of a commerce operation with appropriate visual state.
///
/// Shows distinct states for: success, pending, ambiguous, rejected,
/// offline-preserved, and feature-disabled outcomes. Never shows false success.
class CommerceOutcomeDisplay extends StatelessWidget {
  final CommerceOutcome outcome;

  /// Optional callback when user requests retry.
  final VoidCallback? onRetry;

  /// Optional callback to dismiss the outcome display.
  final VoidCallback? onDismiss;

  const CommerceOutcomeDisplay({
    super.key,
    required this.outcome,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title, subtitle) = _getDisplayData(context);

    return Semantics(
      label: '$title. $subtitle',
      liveRegion: true,
      child: Card(
        color: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32, semanticLabel: title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close),
                      tooltip: 'Dismiss',
                    ),
                ],
              ),
              if (outcome.operationId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Reference: ${outcome.operationId.substring(0, 8)}...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onRetry != null &&
                  outcome.state == CommerceOutcomeState.rejected) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, String, String) _getDisplayData(BuildContext context) {
    final theme = Theme.of(context);
    switch (outcome.state) {
      case CommerceOutcomeState.success:
        return (
          Icons.check_circle_outlined,
          Colors.green,
          'Completed',
          'Operation confirmed successfully.',
        );
      case CommerceOutcomeState.pending:
        return (
          Icons.hourglass_top_outlined,
          theme.colorScheme.primary,
          'Pending Verification',
          'Awaiting provider confirmation. Do not resubmit.',
        );
      case CommerceOutcomeState.ambiguous:
        return (
          Icons.help_outline,
          Colors.orange,
          'Outcome Uncertain',
          'Provider returned ambiguous result. Reconciliation in progress.',
        );
      case CommerceOutcomeState.rejected:
        return (
          Icons.cancel_outlined,
          theme.colorScheme.error,
          'Rejected',
          outcome.errorMessage ?? 'Operation was rejected.',
        );
      case CommerceOutcomeState.offlinePreserved:
        return (
          Icons.cloud_off_outlined,
          theme.colorScheme.tertiary,
          'Saved Offline',
          'Data preserved locally. Will submit when online.',
        );
      case CommerceOutcomeState.featureDisabled:
        return (
          Icons.block_outlined,
          theme.colorScheme.onSurfaceVariant,
          'Feature Disabled',
          outcome.errorMessage ?? 'This feature is not enabled.',
        );
      case CommerceOutcomeState.connectivityRequired:
        return (
          Icons.wifi_off_outlined,
          Colors.orange,
          'Connectivity Required',
          'This operation requires an internet connection.',
        );
    }
  }
}

// ─── Offline Data Preservation Banner ────────────────────────────────────────

/// Banner indicating data has been preserved offline.
///
/// Shown when an online-only operation is attempted without connectivity.
/// The user's entered data is preserved and will be submitted when online.
class OfflinePreservationBanner extends StatelessWidget {
  /// The operation type that was preserved.
  final String operationType;

  /// Optional callback when user manually retries.
  final VoidCallback? onRetryNow;

  const OfflinePreservationBanner({
    super.key,
    required this.operationType,
    this.onRetryNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Data saved offline. Will submit when connection is available.',
      child: MaterialBanner(
        backgroundColor: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
        leading: Icon(
          Icons.cloud_off_outlined,
          color: theme.colorScheme.tertiary,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Data Preserved Offline',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            Text(
              'Your $operationType data has been saved locally and will '
              'be submitted automatically when connectivity is restored.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          if (onRetryNow != null)
            TextButton(onPressed: onRetryNow, child: const Text('Retry Now'))
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ─── Money Formatting ────────────────────────────────────────────────────────

/// Formats minor-unit money for display.
String formatMoney(int amountMinor, String currency) {
  final major = amountMinor ~/ 100;
  final minor = (amountMinor % 100).toString().padLeft(2, '0');
  final symbol = _currencySymbol(currency);
  return '$symbol$major.$minor';
}

String _currencySymbol(String currency) {
  switch (currency.toUpperCase()) {
    case 'INR':
      return '₹';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    default:
      return '$currency ';
  }
}
