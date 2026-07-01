// ============================================================================
// BIOMETRIC GATE — Sensitive Action Re-Authentication
// ============================================================================
// Reusable guard that MUST be called before any sensitive operation.
// Uses BiometricAuthService for fingerprint/face, falls back to PIN.
//
// Usage:
//   final ok = await BiometricGate.require(SensitiveAction.payment);
//   if (!ok) return; // user cancelled or failed
//   // proceed with sensitive operation
//
// Author: DukanX Engineering — Security Remediation
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/services/logger_service.dart';
import 'biometric_auth.dart';

/// Categories of sensitive operations that require re-authentication.
enum SensitiveAction {
  payment,
  refund,
  deleteAccount,
  exportData,
  changePin,
  changeBankDetails,
  viewFullCardNumber,
  revokeStaffAccess,
}

/// Biometric gate — guards sensitive operations with biometric/PIN challenge.
class BiometricGate {
  BiometricGate._();

  /// Require re-authentication before proceeding with [action].
  ///
  /// Returns `true` if the user successfully authenticated.
  /// Returns `false` if the user cancelled or authentication failed.
  ///
  /// If biometrics are not available, falls back to PIN.
  /// If neither is available, returns `false` (fail-closed).
  static Future<bool> require(
    SensitiveAction action, {
    BuildContext? context,
  }) async {
    final bioAuth = sl<BiometricAuthService>();

    // Check if account is locked (brute-force protection)
    if (await bioAuth.isAccountLocked()) {
      LoggerService.d('Biometric', '[BiometricGate] Account locked — denying $action');
      return false;
    }

    // Try biometric first
    final biometrics = await bioAuth.getAvailableBiometrics();
    if (biometrics.isNotEmpty) {
      final authenticated = await bioAuth.authenticateWithBiometric(
        reason: _reasonForAction(action),
      );
      if (authenticated) return true;
      // If biometric failed/cancelled, fall through to PIN if available
    }

    // Biometric not available or failed — try PIN fallback
    if (context != null && context.mounted) {
      return _showPinDialog(context, bioAuth, action);
    }

    // No context for PIN dialog and biometric failed → deny
    LoggerService.d('Biometric', '[BiometricGate] No auth method available for $action');
    return false;
  }

  /// Show PIN entry dialog for fallback authentication.
  static Future<bool> _showPinDialog(
    BuildContext context,
    BiometricAuthService bioAuth,
    SensitiveAction action,
  ) async {
    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Security Verification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _reasonForAction(action),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Enter PIN',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) async {
                      final pin = controller.text.trim();
                      if (pin.isEmpty) return;

                      final ok = await bioAuth.authenticateWithPIN(pin);
                      if (ok) {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } else {
                        setState(() {
                          errorText = 'Incorrect PIN';
                          controller.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pin = controller.text.trim();
                    if (pin.isEmpty) return;

                    final ok = await bioAuth.authenticateWithPIN(pin);
                    if (ok) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } else {
                      setState(() {
                        errorText = 'Incorrect PIN';
                        controller.clear();
                      });
                    }
                  },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result ?? false;
  }

  /// Human-readable reason string for each action.
  static String _reasonForAction(SensitiveAction action) {
    switch (action) {
      case SensitiveAction.payment:
        return 'Verify your identity to authorize this payment';
      case SensitiveAction.refund:
        return 'Verify your identity to process this refund';
      case SensitiveAction.deleteAccount:
        return 'Verify your identity to delete your account';
      case SensitiveAction.exportData:
        return 'Verify your identity to export business data';
      case SensitiveAction.changePin:
        return 'Verify your identity to change your PIN';
      case SensitiveAction.changeBankDetails:
        return 'Verify your identity to update bank details';
      case SensitiveAction.viewFullCardNumber:
        return 'Verify your identity to view full card number';
      case SensitiveAction.revokeStaffAccess:
        return 'Verify your identity to revoke staff access';
    }
  }
}
