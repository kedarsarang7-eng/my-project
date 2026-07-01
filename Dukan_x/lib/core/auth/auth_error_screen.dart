// ============================================================================
// AUTH ERROR SCREEN
// ============================================================================
// Displays when authentication fails or role cannot be determined
// Forces logout and provides clear error message
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../di/service_locator.dart';
import '../session/session_manager.dart';

/// Error screen shown when:
/// - Role document is missing or invalid
/// - Authentication fails
/// - Role mismatch detected
///
/// Always provides option to retry or logout
class AuthErrorScreen extends StatelessWidget {
  final String? errorMessage;
  final String? errorCode;
  final VoidCallback? onRetry;

  const AuthErrorScreen({
    super.key,
    this.errorMessage,
    this.errorCode,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red.shade700, Colors.red.shade900],
          ),
        ),
        child: ResponsiveContainer(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Authentication Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error message
                  Text(
                    errorMessage ??
                        'Unable to verify your account. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),

                  if (errorCode != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Error Code: $errorCode',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Retry button
                  if (onRetry != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _handleLogout(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await sl<SessionManager>().signOut();
    } catch (_) {
      // Ignore logout errors
    }

    if (context.mounted) {
      context.go(RoutePaths.splash);
    }
  }
}
