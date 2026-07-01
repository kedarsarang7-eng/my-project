// ============================================================================
// ASYNC FEEDBACK — Consistent operation-failure + long-operation channel
// ============================================================================
// Centralizes two stability behaviors so individual screens don't each
// reinvent SnackBar / spinner handling (AGENTS.md DRY):
//
//   • Req 10.4 — operation failures surface through a single, *dismissible*
//                error channel; the app stays usable (no forced restart) and
//                the failed operation can optionally be retried.
//   • Req 10.5 — operations that run longer than ~1 second show a progress
//                indicator that stays visible until the operation completes.
//
// Reuses the existing `ErrorHandler` (for logging) and `AppLoadingIndicator`
// (for the progress visual) rather than duplicating either.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../error/error_handler.dart';
import '../../widgets/loading/loading_states.dart';

/// Shared helpers for surfacing async operation feedback consistently.
///
/// All methods are no-ops when the supplied [BuildContext] is no longer
/// mounted or has no [ScaffoldMessenger]/[Overlay] ancestor, so callers can
/// invoke them safely after `await` without guarding every call site.
class AsyncFeedback {
  AsyncFeedback._();

  /// Threshold after which a still-running operation is treated as "long"
  /// and must surface a progress indicator (Req 10.5).
  static const Duration longOperationThreshold = Duration(seconds: 1);

  /// Surfaces an [message] failure through a consistent, dismissible
  /// [SnackBar] (Req 10.4).
  ///
  /// The message is dismissible (explicit Dismiss action) and never blocks the
  /// app — the user can keep working without a restart. When [onRetry] is
  /// provided, a Retry action is offered instead of Dismiss.
  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: messenger.hideCurrentSnackBar,
                ),
        ),
      );
  }

  /// Runs [operation], showing a non-blocking progress indicator if it runs
  /// longer than [threshold] (~1s, Req 10.5) and routing any failure through
  /// [showError] (Req 10.4).
  ///
  /// Returns the operation result, or `null` if it threw. The progress
  /// indicator is only inserted once the [threshold] elapses, so fast
  /// operations never flash a spinner.
  static Future<T?> runWithProgress<T>(
    BuildContext context,
    Future<T> Function() operation, {
    Duration threshold = longOperationThreshold,
    String? progressMessage,
    String? errorMessage,
  }) async {
    OverlayEntry? entry;
    Timer? timer;

    void removeProgress() {
      timer?.cancel();
      timer = null;
      entry?.remove();
      entry = null;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay != null) {
      // Defer showing the indicator until the operation actually exceeds the
      // latency budget, so quick operations stay spinner-free.
      timer = Timer(threshold, () {
        entry = OverlayEntry(
          builder: (_) => Positioned.fill(
            child: ColoredBox(
              color: const Color(0x66000000),
              child: AppLoadingIndicator(
                message: progressMessage ?? 'Working…',
              ),
            ),
          ),
        );
        overlay.insert(entry!);
      });
    }

    try {
      final result = await operation();
      removeProgress();
      return result;
    } catch (error, stackTrace) {
      removeProgress();
      // Log through the central handler without its own UI; we own the UI here.
      await ErrorHandler.handle(error, stackTrace: stackTrace, showUI: false);
      if (context.mounted) {
        showError(context, errorMessage ?? 'Operation failed. Please retry.');
      }
      return null;
    }
  }
}
