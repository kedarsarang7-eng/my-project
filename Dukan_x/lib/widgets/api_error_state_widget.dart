import 'package:flutter/material.dart';

/// Classification of API error types for user-friendly messaging.
enum ApiErrorType { auth, network, server, unknown }

/// Classifies a dynamic error into an [ApiErrorType].
///
/// Inspects the string representation of the error for known patterns:
/// - 401/403 → [ApiErrorType.auth]
/// - SocketException/timeout → [ApiErrorType.network]
/// - 500/502 → [ApiErrorType.server]
/// - Everything else → [ApiErrorType.unknown]
ApiErrorType classifyError(dynamic error) {
  final msg = error.toString();
  if (msg.contains('401') || msg.contains('403')) return ApiErrorType.auth;
  if (msg.contains('SocketException') || msg.contains('timeout')) {
    return ApiErrorType.network;
  }
  if (msg.contains('500') || msg.contains('502')) return ApiErrorType.server;
  return ApiErrorType.unknown;
}

/// Returns a user-friendly message for the given [ApiErrorType].
///
/// NEVER exposes raw exception details to users.
String userMessageFor(ApiErrorType type) => switch (type) {
  ApiErrorType.auth => 'Session expired. Please try again or re-login.',
  ApiErrorType.network => 'Network error. Check your connection and retry.',
  ApiErrorType.server => 'Server error. Please try again later.',
  ApiErrorType.unknown => 'Something went wrong. Please try again.',
};

/// A standardized widget for displaying API error states.
///
/// Renders an error icon, a user-friendly message, a retry button,
/// and an optional re-login button. NEVER exposes raw exception details.
///
/// Usage:
/// ```dart
/// ApiErrorStateWidget(
///   userMessage: 'Unable to load payment settings.',
///   onRetry: _loadConfigs,
///   showReLogin: true,
///   onReLogin: () => _triggerReAuth(context),
/// )
/// ```
class ApiErrorStateWidget extends StatelessWidget {
  /// User-friendly message shown to the user.
  /// Falls back to a generic message if null.
  final String? userMessage;

  /// Callback invoked when the user taps the retry button.
  final VoidCallback? onRetry;

  /// Callback invoked when the user taps the re-login button.
  final VoidCallback? onReLogin;

  /// Whether to show the re-login button (typically true for 401/403 errors).
  final bool showReLogin;

  const ApiErrorStateWidget({
    super.key,
    this.userMessage,
    this.onRetry,
    this.onReLogin,
    this.showReLogin = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = userMessage ?? userMessageFor(ApiErrorType.unknown);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            if (showReLogin && onReLogin != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: OutlinedButton.icon(
                  onPressed: onReLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Re-login'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
