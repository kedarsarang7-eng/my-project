/// OperationProgressBanner — Screen Reader Announcing Progress Banner (Dart)
///
/// A banner widget that announces operation progress to assistive technology.
/// Uses [Semantics] liveRegion to notify screen readers when state changes.
///
/// Prevents the "spinner forever" anti-pattern: if [timeoutDuration] is set
/// and elapsed, transitions to a stale/failed visual automatically.
///
/// Key features:
/// - Announces state transitions to screen readers
/// - Exposes busy state to prevent duplicate activation (Req 11.8)
/// - Auto-dismisses on terminal states
/// - Supports timeout detection for hung operations
///
/// Requirements: 11.7–11.8, 12.4–12.10; GR-3
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'operation_state.dart';
import 'operation_state_card.dart';

// ─── OperationProgressBanner ─────────────────────────────────────────────────

/// A banner that displays and announces operation progress.
///
/// Usage:
/// ```dart
/// OperationProgressBanner(
///   state: operationState,
///   onRecoveryAction: (action) => handleRecovery(action),
///   timeoutDuration: const Duration(seconds: 30),
///   onTimeout: () => setState(() => _state = OperationStale(...)),
/// )
/// ```
class OperationProgressBanner extends StatefulWidget {
  /// The current operation state.
  final OperationState state;

  /// Callback for recovery action invocation.
  final OnRecoveryAction? onRecoveryAction;

  /// Optional timeout for loading/pending states.
  /// If exceeded, [onTimeout] fires to prevent infinite spinners.
  final Duration? timeoutDuration;

  /// Called when [timeoutDuration] is exceeded in a non-terminal state.
  final VoidCallback? onTimeout;

  /// Whether to auto-dismiss the banner after terminal state is reached.
  final bool autoDismiss;

  /// Duration before auto-dismiss (only for [OperationComplete]).
  final Duration autoDismissDelay;

  /// Whether the banner should be visible (allows animation).
  final bool visible;

  const OperationProgressBanner({
    super.key,
    required this.state,
    this.onRecoveryAction,
    this.timeoutDuration,
    this.onTimeout,
    this.autoDismiss = true,
    this.autoDismissDelay = const Duration(seconds: 5),
    this.visible = true,
  });

  @override
  State<OperationProgressBanner> createState() =>
      _OperationProgressBannerState();
}

class _OperationProgressBannerState extends State<OperationProgressBanner> {
  Timer? _timeoutTimer;
  Timer? _dismissTimer;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _scheduleTimeout();
    _scheduleAutoDismiss();
  }

  @override
  void didUpdateWidget(covariant OperationProgressBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _isDismissed = false;
      _cancelTimers();
      _scheduleTimeout();
      _scheduleAutoDismiss();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _scheduleTimeout() {
    if (widget.timeoutDuration != null && !widget.state.isTerminal) {
      _timeoutTimer = Timer(widget.timeoutDuration!, () {
        if (mounted && !widget.state.isTerminal) {
          widget.onTimeout?.call();
        }
      });
    }
  }

  void _scheduleAutoDismiss() {
    if (widget.autoDismiss && widget.state is OperationComplete) {
      _dismissTimer = Timer(widget.autoDismissDelay, () {
        if (mounted) {
          setState(() => _isDismissed = true);
        }
      });
    }
  }

  void _cancelTimers() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || _isDismissed) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.visible ? 1.0 : 0.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OperationStateCard(
            state: widget.state,
            onRecoveryAction: widget.onRecoveryAction,
            compact: false,
          ),
        ),
      ),
    );
  }
}

// ─── Busy State Guard ────────────────────────────────────────────────────────

/// A widget that prevents duplicate activation while an operation is in progress.
///
/// Wraps an action trigger (button, card, etc.) and disables it when
/// [isBusy] is true. Announces busy state to screen readers (Req 11.8).
///
/// Usage:
/// ```dart
/// OperationBusyGuard(
///   isBusy: _isSubmitting,
///   child: FilledButton(
///     onPressed: _submit,
///     child: Text('Submit'),
///   ),
/// )
/// ```
class OperationBusyGuard extends StatelessWidget {
  /// Whether an operation is currently in progress.
  final bool isBusy;

  /// The action widget to guard.
  final Widget child;

  /// Optional loading indicator to show while busy.
  final Widget? busyIndicator;

  /// Accessibility label when busy.
  final String busyLabel;

  const OperationBusyGuard({
    super.key,
    required this.isBusy,
    required this.child,
    this.busyIndicator,
    this.busyLabel = 'Operation in progress. Please wait.',
  });

  @override
  Widget build(BuildContext context) {
    if (!isBusy) return child;

    return Semantics(
      label: busyLabel,
      liveRegion: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Disabled child
          Opacity(opacity: 0.38, child: IgnorePointer(child: child)),
          // Busy indicator overlay
          if (busyIndicator != null)
            busyIndicator!
          else
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
