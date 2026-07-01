// ============================================================================
// OFFLINE UI INDICATORS AND RESTRICTIONS
// ============================================================================
// Provides visible offline indicators, action guards for real-time-only
// operations, and "data unavailable" messaging when no cache exists.
//
// Requirements: 8.5, 8.7
// - 8.5: Display visible offline indicator and disable payment processing,
//         account deletion, and subscription changes while offline
// - 8.7: Show "data unavailable until first sync" when no cache, restrict
//         to write-only operations where applicable
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Actions that are disabled when the device is offline.
///
/// These actions require real-time server confirmation and cannot
/// be safely queued for later replay.
const List<String> offlineRestrictedActions = [
  'payment_processing',
  'account_deletion',
  'subscription_changes',
];

// =============================================================================
// OfflineIndicatorWidget
// =============================================================================

/// Displays a visible offline indicator banner when the device is disconnected.
///
/// Wraps child content and shows a persistent banner at the top when offline.
/// Automatically listens to connectivity changes and updates in real-time.
///
/// Usage:
/// ```dart
/// OfflineIndicatorWidget(
///   child: MyScreenContent(),
/// )
/// ```
class OfflineIndicatorWidget extends StatefulWidget {
  /// The child widget to display below the offline banner.
  final Widget child;

  /// Whether to show the banner at the top (true) or bottom (false).
  final bool showAtTop;

  const OfflineIndicatorWidget({
    super.key,
    required this.child,
    this.showAtTop = true,
  });

  @override
  State<OfflineIndicatorWidget> createState() => _OfflineIndicatorWidgetState();
}

class _OfflineIndicatorWidgetState extends State<OfflineIndicatorWidget> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateStatus(result);

    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final isOffline = results.contains(ConnectivityResult.none);
    if (isOffline != _isOffline) {
      setState(() {
        _isOffline = isOffline;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAtTop) {
      return Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _isOffline ? _buildBanner(context) : const SizedBox.shrink(),
          ),
          Expanded(child: widget.child),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: widget.child),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _isOffline ? _buildBanner(context) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: Colors.orange.shade700),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Text(
              'You are offline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• Changes saved locally',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// OfflineActionGuard
// =============================================================================

/// Guards actions that require real-time server confirmation.
///
/// When the device is offline, disables the child widget and shows a tooltip
/// explaining why the action is unavailable. When online, renders normally.
///
/// Usage:
/// ```dart
/// OfflineActionGuard(
///   actionType: 'payment_processing',
///   child: ElevatedButton(
///     onPressed: processPayment,
///     child: Text('Pay Now'),
///   ),
/// )
/// ```
class OfflineActionGuard extends StatefulWidget {
  /// The child widget to conditionally enable/disable.
  final Widget child;

  /// The action type being guarded (must be in [offlineRestrictedActions]).
  final String actionType;

  /// Optional custom message shown when the action is disabled.
  final String? disabledMessage;

  /// Optional callback invoked when user taps a disabled action.
  final VoidCallback? onDisabledTap;

  const OfflineActionGuard({
    super.key,
    required this.child,
    required this.actionType,
    this.disabledMessage,
    this.onDisabledTap,
  });

  @override
  State<OfflineActionGuard> createState() => _OfflineActionGuardState();
}

class _OfflineActionGuardState extends State<OfflineActionGuard> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateStatus(result);

    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final isOffline = results.contains(ConnectivityResult.none);
    if (isOffline != _isOffline) {
      setState(() {
        _isOffline = isOffline;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Whether the guarded action is currently restricted.
  bool get _isRestricted =>
      _isOffline && offlineRestrictedActions.contains(widget.actionType);

  String get _tooltipMessage =>
      widget.disabledMessage ?? _defaultMessageForAction(widget.actionType);

  static String _defaultMessageForAction(String actionType) {
    switch (actionType) {
      case 'payment_processing':
        return 'Payment processing requires an internet connection';
      case 'account_deletion':
        return 'Account deletion requires an internet connection';
      case 'subscription_changes':
        return 'Subscription changes require an internet connection';
      default:
        return 'This action requires an internet connection';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRestricted) {
      return widget.child;
    }

    return Tooltip(
      message: _tooltipMessage,
      child: GestureDetector(
        onTap: () {
          if (widget.onDisabledTap != null) {
            widget.onDisabledTap!();
          } else {
            _showDisabledSnackbar(context);
          }
        },
        child: Opacity(opacity: 0.5, child: IgnorePointer(child: widget.child)),
      ),
    );
  }

  void _showDisabledSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_tooltipMessage)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// =============================================================================
// OfflineDataUnavailable
// =============================================================================

/// Shows "data unavailable until first sync" when accessed offline with no cache.
///
/// Displays an informational message and optionally allows write-only operations
/// when applicable. This widget should be used as the body of screens that have
/// no cached data available.
///
/// Usage:
/// ```dart
/// if (isOffline && !hasCachedData) {
///   return OfflineDataUnavailable(
///     screenName: 'Invoices',
///     allowWriteOnly: true,
///     onWriteAction: () => navigateToCreateInvoice(),
///     writeActionLabel: 'Create Invoice',
///   );
/// }
/// ```
class OfflineDataUnavailable extends StatelessWidget {
  /// Name of the screen for contextual messaging.
  final String screenName;

  /// Whether write-only operations are available despite no cached data.
  final bool allowWriteOnly;

  /// Callback for the write action button (shown when [allowWriteOnly] is true).
  final VoidCallback? onWriteAction;

  /// Label for the write action button.
  final String? writeActionLabel;

  const OfflineDataUnavailable({
    super.key,
    required this.screenName,
    this.allowWriteOnly = false,
    this.onWriteAction,
    this.writeActionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Data unavailable until first sync',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '$screenName data will appear here after your first '
              'successful sync with the server.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (allowWriteOnly && onWriteAction != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'You can still create new entries offline',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: onWriteAction,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(writeActionLabel ?? 'Create New'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!allowWriteOnly) ...[
              const SizedBox(height: 24),
              Text(
                'Connect to the internet to load data.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// OfflineAwareMixin
// =============================================================================

/// Mixin to add offline awareness to any screen's State.
///
/// Provides connectivity monitoring, restricted action checking, and helper
/// methods for screens that need offline-aware behavior.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with OfflineAwareMixin {
///   @override
///   Widget build(BuildContext context) {
///     if (isOffline && !hasCachedData) {
///       return OfflineDataUnavailable(screenName: 'My Screen');
///     }
///     return buildContent();
///   }
/// }
/// ```
mixin OfflineAwareMixin<T extends StatefulWidget> on State<T> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Whether the device is currently offline.
  bool get isOffline => _isOffline;

  /// Whether the device is currently online.
  bool get isOnline => !_isOffline;

  @override
  void initState() {
    super.initState();
    _initOfflineAwareness();
  }

  Future<void> _initOfflineAwareness() async {
    final result = await Connectivity().checkConnectivity();
    _handleConnectivityChange(result);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOffline = _isOffline;
    _isOffline = results.contains(ConnectivityResult.none);

    if (wasOffline != _isOffline && mounted) {
      setState(() {});
      onConnectivityChanged(_isOffline);
    }
  }

  /// Override this to react to connectivity changes.
  ///
  /// Called whenever connectivity state transitions between online and offline.
  void onConnectivityChanged(bool isOffline) {}

  /// Checks if a specific action is restricted while offline.
  ///
  /// Returns true if the device is offline AND the action is in the
  /// [offlineRestrictedActions] list.
  bool isActionRestricted(String actionType) {
    return _isOffline && offlineRestrictedActions.contains(actionType);
  }

  /// Attempts to execute an action, showing a snackbar if restricted offline.
  ///
  /// Returns true if the action was allowed to proceed, false if blocked.
  bool guardAction(String actionType, {String? message}) {
    if (!isActionRestricted(actionType)) {
      return true;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message ?? 'This action requires an internet connection',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    return false;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
