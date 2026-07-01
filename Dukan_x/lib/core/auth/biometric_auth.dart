// ============================================================================
// BIOMETRIC AUTHENTICATION - Fingerprint/Face ID Support (P3 FIX)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication states
enum BiometricAuthState {
  unavailable,  // Device doesn't support biometrics
  disabled,     // User hasn't enabled biometrics
  enabled,      // Biometric auth is active
  lockedOut,    // Too many failed attempts
}

/// Biometric auth configuration
class BiometricConfig {
  final bool requireStrongBiometrics;
  final bool allowDeviceCredentials;
  final int maxAttempts;
  final Duration lockoutDuration;
  final String localizedReason;
  final String cancelButton;
  final String settingsButton;

  const BiometricConfig({
    this.requireStrongBiometrics = true,
    this.allowDeviceCredentials = true,
    this.maxAttempts = 3,
    this.lockoutDuration = const Duration(minutes: 1),
    this.localizedReason = 'Authenticate to access your account',
    this.cancelButton = 'Cancel',
    this.settingsButton = 'Settings',
  });
}

/// Biometric authentication service
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final BiometricConfig _config;
  
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  BiometricAuthService({BiometricConfig? config})
      : _config = config ?? const BiometricConfig();

  /// Check if biometrics is available on this device
  Future<bool> get isAvailable async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> get availableTypes async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Get human-readable name for biometric type
  String getBiometricName(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.face:
        return 'Face Recognition';
      case BiometricType.iris:
        return 'Iris Scan';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Biometric';
    }
  }

  /// Check if currently locked out
  bool get isLockedOut {
    if (_lockoutEndTime == null) return false;
    return DateTime.now().isBefore(_lockoutEndTime!);
  }

  /// Authenticate using biometrics
  Future<BiometricAuthResult> authenticate() async {
    // Check lockout
    if (isLockedOut) {
      return BiometricAuthResult.lockedOut(
        remainingTime: _lockoutEndTime!.difference(DateTime.now()),
      );
    }

    // Check if biometrics is available
    final available = await isAvailable;
    if (!available) {
      return BiometricAuthResult.unavailable();
    }

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: _config.localizedReason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
        biometricOnly: !_config.allowDeviceCredentials,
      );

      if (didAuthenticate) {
        _failedAttempts = 0;
        return BiometricAuthResult.success();
      } else {
        _failedAttempts++;
        
        // Lock out after max attempts
        if (_failedAttempts >= _config.maxAttempts) {
          _lockoutEndTime = DateTime.now().add(_config.lockoutDuration);
          return BiometricAuthResult.lockedOut(
            remainingTime: _config.lockoutDuration,
          );
        }
        
        return BiometricAuthResult.failed(
          attemptsRemaining: _config.maxAttempts - _failedAttempts,
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'LockedOut') {
        _lockoutEndTime = DateTime.now().add(_config.lockoutDuration);
        return BiometricAuthResult.lockedOut(
          remainingTime: _config.lockoutDuration,
        );
      }
      return BiometricAuthResult.error(e.message ?? 'Unknown error');
    }
  }

  /// Stop authentication
  Future<bool> stopAuthentication() async {
    return await _localAuth.stopAuthentication();
  }
}

/// Biometric authentication result
class BiometricAuthResult {
  final bool success;
  final bool unavailable;
  final bool lockedOut;
  final String? error;
  final int? attemptsRemaining;
  final Duration? remainingLockoutTime;

  BiometricAuthResult._({
    required this.success,
    this.unavailable = false,
    this.lockedOut = false,
    this.error,
    this.attemptsRemaining,
    this.remainingLockoutTime,
  });

  factory BiometricAuthResult.success() => BiometricAuthResult._(success: true);
  
  factory BiometricAuthResult.unavailable() => 
      BiometricAuthResult._(success: false, unavailable: true);
  
  factory BiometricAuthResult.failed({int? attemptsRemaining}) =>
      BiometricAuthResult._(
        success: false,
        attemptsRemaining: attemptsRemaining,
      );
  
  factory BiometricAuthResult.lockedOut({required Duration remainingTime}) =>
      BiometricAuthResult._(
        success: false,
        lockedOut: true,
        remainingLockoutTime: remainingTime,
      );
  
  factory BiometricAuthResult.error(String message) =>
      BiometricAuthResult._(success: false, error: message);
}

/// Biometric auth preferences manager
class BiometricAuthPreferences {
  static const String _keyBiometricEnabled = 'biometric_auth_enabled';
  static const String _keyLastAuthTime = 'biometric_last_auth_time';

  final SharedPreferences _prefs;

  BiometricAuthPreferences(this._prefs);

  bool get isBiometricEnabled => _prefs.getBool(_keyBiometricEnabled) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_keyBiometricEnabled, enabled);
  }

  DateTime? get lastAuthTime {
    final timestamp = _prefs.getInt(_keyLastAuthTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> recordAuthTime() async {
    await _prefs.setInt(_keyLastAuthTime, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    await _prefs.remove(_keyBiometricEnabled);
    await _prefs.remove(_keyLastAuthTime);
  }
}

/// Provider for biometric auth service
final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

/// Provider for biometric preferences
final biometricPreferencesProvider = FutureProvider<BiometricAuthPreferences>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return BiometricAuthPreferences(prefs);
});

/// Biometric login dialog
class BiometricLoginDialog extends StatelessWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;
  final VoidCallback? onFallback;

  const BiometricLoginDialog({
    super.key,
    this.onSuccess,
    this.onCancel,
    this.onFallback,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.fingerprint, size: 28),
          SizedBox(width: 12),
          Text('Biometric Login'),
        ],
      ),
      content: const Text(
        'Use your fingerprint or face recognition to quickly and securely log in to your account.',
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        if (onFallback != null)
          TextButton(
            onPressed: onFallback,
            child: const Text('Use Password'),
          ),
        FilledButton(
          onPressed: () async {
            final service = BiometricAuthService();
            final result = await service.authenticate();
            
            if (result.success) {
              onSuccess?.call();
            } else {
              // Show error
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.lockedOut
                          ? 'Too many attempts. Please try again later.'
                          : result.error ?? 'Authentication failed',
                    ),
                  ),
                );
              }
            }
          },
          child: const Text('Authenticate'),
        ),
      ],
    );
  }
}

/// Settings tile for biometric authentication
class BiometricAuthSettingsTile extends ConsumerWidget {
  const BiometricAuthSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(biometricAuthServiceProvider);
    final prefsAsync = ref.watch(biometricPreferencesProvider);

    return prefsAsync.when(
      data: (prefs) {
        return FutureBuilder<bool>(
          future: service.isAvailable,
          builder: (context, snapshot) {
            final isAvailable = snapshot.data ?? false;
            final isEnabled = prefs.isBiometricEnabled;

            if (!isAvailable) {
              return const ListTile(
                leading: Icon(Icons.fingerprint_outlined),
                title: Text('Biometric Authentication'),
                subtitle: Text('Not available on this device'),
                enabled: false,
              );
            }

            return SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Biometric Authentication'),
              subtitle: const Text('Use fingerprint or face to unlock'),
              value: isEnabled,
              onChanged: (value) async {
                if (value) {
                  // Enable - verify biometrics work first
                  final result = await service.authenticate();
                  if (result.success) {
                    await prefs.setBiometricEnabled(true);
                    await prefs.recordAuthTime();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Biometric authentication enabled')),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not verify biometrics')),
                      );
                    }
                  }
                } else {
                  // Disable
                  await prefs.setBiometricEnabled(false);
                }
              },
            );
          },
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.fingerprint_outlined),
        title: Text('Biometric Authentication'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const ListTile(
        leading: Icon(Icons.fingerprint_outlined),
        title: Text('Biometric Authentication'),
        subtitle: Text('Error loading settings'),
      ),
    );
  }
}

/// Widget that shows biometric auth option on lock screen
class BiometricUnlockButton extends StatelessWidget {
  final VoidCallback onSuccess;
  final bool isLockedOut;
  final Duration? remainingLockoutTime;

  const BiometricUnlockButton({
    super.key,
    required this.onSuccess,
    this.isLockedOut = false,
    this.remainingLockoutTime,
  });

  @override
  Widget build(BuildContext context) {
    if (isLockedOut && remainingLockoutTime != null) {
      final minutes = remainingLockoutTime!.inMinutes;
      final seconds = remainingLockoutTime!.inSeconds % 60;
      
      return Column(
        children: [
          const Icon(Icons.lock_clock, size: 48, color: Colors.orange),
          const SizedBox(height: 8),
          Text(
            'Locked out',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Try again in $minutes:${seconds.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        final service = BiometricAuthService();
        final result = await service.authenticate();
        
        if (result.success) {
          onSuccess();
        }
      },
      icon: const Icon(Icons.fingerprint),
      label: const Text('Unlock with Biometrics'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
