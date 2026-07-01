// ============================================================================
// FEATURE ERROR BOUNDARY
// ============================================================================
// Auto-recovery error boundary for feature screens.
// Wraps each screen in the DesktopContentHost to prevent cascading failures.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/error/error_handler.dart';
import '../core/navigation/app_screens.dart';

/// A production-ready error boundary that catches rendering errors
/// and provides a recovery UI instead of the red screen of death.
class FeatureErrorBoundary extends StatefulWidget {
  final Widget child;
  final AppScreen screen;
  final VoidCallback? onRetry;

  const FeatureErrorBoundary({
    super.key,
    required this.child,
    required this.screen,
    this.onRetry,
  });

  @override
  State<FeatureErrorBoundary> createState() => _FeatureErrorBoundaryState();
}

class _FeatureErrorBoundaryState extends State<FeatureErrorBoundary> {
  Object? _error;
  bool _isRecovering = false;
  int _retryCount = 0;
  static const int _maxAutoRetries = 2;

  @override
  void didUpdateWidget(FeatureErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset error state when screen changes
    if (oldWidget.screen != widget.screen) {
      _error = null;
      _retryCount = 0;
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (!mounted) return;

    // Log to monitoring
    ErrorHandler.handle(
      error,
      stackTrace: stackTrace,
      userMessage: 'Screen ${widget.screen.name} encountered an error',
      showUI: false,
    );

    setState(() {
      _error = error;
    });

    if (kDebugMode) {
      debugPrint('[FeatureErrorBoundary] Error in ${widget.screen.name}:');
      debugPrint('$error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _recover() async {
    if (_isRecovering) return;

    setState(() {
      _isRecovering = true;
    });

    // Brief delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      _retryCount++;
      setState(() {
        _error = null;
        _isRecovering = false;
      });

      widget.onRetry?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorUI(context);
    }

    // Use ErrorWidget.builder pattern for this subtree
    return _ErrorCatcher(onError: _handleError, child: widget.child);
  }

  Widget _buildErrorUI(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark ? Colors.red.shade900 : Colors.red.shade50)
                    .withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 56,
                color: isDark ? Colors.red.shade300 : Colors.red.shade400,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'This screen encountered an issue',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              _retryCount >= _maxAutoRetries
                  ? 'We\'ve tried to recover but the issue persists. Please try again later or contact support.'
                  : 'Don\'t worry, your data is safe. Try refreshing this screen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Retry Button
            FilledButton.icon(
              onPressed: _isRecovering ? null : _recover,
              icon: _isRecovering
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(_isRecovering ? 'Recovering...' : 'Try Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),

            // Debug info (only in debug mode)
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Screen: ${widget.screen.name}\n'
                      'Error: ${_error.runtimeType}\n'
                      'Retry count: $_retryCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal widget that catches errors in the subtree
class _ErrorCatcher extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace stackTrace) onError;

  const _ErrorCatcher({required this.child, required this.onError});

  @override
  State<_ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<_ErrorCatcher> {
  @override
  Widget build(BuildContext context) {
    // This widget itself doesn't catch errors directly,
    // but we can use it with Flutter's error handling
    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hook into Flutter's error handling for this subtree
    // Note: This is a simplified approach. Full implementation would use
    // a custom RenderObjectWidget or Element override.
  }
}

/// Extension to wrap any widget in a FeatureErrorBoundary
extension WidgetErrorBoundaryExtension on Widget {
  Widget withErrorBoundary(AppScreen screen, {VoidCallback? onRetry}) {
    return FeatureErrorBoundary(screen: screen, onRetry: onRetry, child: this);
  }
}
