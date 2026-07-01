// License Guard - Route protection based on license validity
// Blocks app access when license is invalid, expired, or mismatched
//
// Usage:
//   LicenseGuard(
//     businessType: BusinessType.petrolPump,
//     child: YourScreen(),
//   )

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/business_type.dart';
import '../services/license_service.dart';
import '../core/di/service_locator.dart';

/// License guard screen states
enum LicenseGuardState {
  checking,
  valid,
  noLicense,
  expired,
  businessTypeMismatch,
  deviceMismatch,
  blocked,
  error,
}

/// Provider for license validation state
final licenseGuardProvider =
    NotifierProvider<LicenseGuardNotifier, AsyncValue<LicenseGuardState>>(
      LicenseGuardNotifier.new,
    );

/// License guard state notifier
class LicenseGuardNotifier
    extends Notifier<AsyncValue<LicenseGuardState>> {
  @override
  AsyncValue<LicenseGuardState> build() => const AsyncValue.loading();

  Future<void> validateLicense(BusinessType businessType) async {
    state = const AsyncValue.loading();

    try {
      final licenseService = sl<LicenseService>();
      final result = await licenseService.validateLicense(
        requiredBusinessType: businessType,
      );

      if (result.isValid) {
        state = const AsyncValue.data(LicenseGuardState.valid);
      } else {
        switch (result.status) {
          case LicenseStatus.notFound:
            state = const AsyncValue.data(LicenseGuardState.noLicense);
            break;
          case LicenseStatus.expired:
            state = const AsyncValue.data(LicenseGuardState.expired);
            break;
          case LicenseStatus.businessTypeMismatch:
            state = const AsyncValue.data(
              LicenseGuardState.businessTypeMismatch,
            );
            break;
          case LicenseStatus.deviceMismatch:
            state = const AsyncValue.data(LicenseGuardState.deviceMismatch);
            break;
          case LicenseStatus.blocked:
          case LicenseStatus.suspended:
            state = const AsyncValue.data(LicenseGuardState.blocked);
            break;
          default:
            state = const AsyncValue.data(LicenseGuardState.error);
        }
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// License Guard Widget - Wraps screens to enforce license validation
class LicenseGuard extends ConsumerStatefulWidget {
  final BusinessType businessType;
  final Widget child;
  final Widget? loadingWidget;
  final Widget Function(LicenseGuardState state, VoidCallback retry)?
  errorBuilder;

  const LicenseGuard({
    super.key,
    required this.businessType,
    required this.child,
    this.loadingWidget,
    this.errorBuilder,
  });

  @override
  ConsumerState<LicenseGuard> createState() => _LicenseGuardState();
}

class _LicenseGuardState extends ConsumerState<LicenseGuard> {
  @override
  void initState() {
    super.initState();
    // Subscription-based model: license key validation is bypassed.
  }

  void _retry() {
    // No-op under subscription model
  }

  @override
  Widget build(BuildContext context) {
    // Under the subscription-based model:
    // Any authenticated user who has a valid subscription has their business type activated automatically.
    // In dev mode, we can manually change the business type.
    // Thus, LicenseGuard is now a pass-through that does not block or require entering a license key.
    return widget.child;
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Validating License...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(
    BuildContext context,
    LicenseGuardState state,
    String? errorMessage,
  ) {
    final (icon, title, message, showActivation, showContact) =
        _getErrorContent(state, errorMessage);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 80, color: Colors.red.shade400),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (showActivation) ...[
                      ElevatedButton.icon(
                        onPressed: () => _showActivationDialog(context),
                        icon: const Icon(Icons.key),
                        label: const Text('Enter License Key'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 48),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(200, 48),
                      ),
                    ),
                    if (showContact) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _contactSupport(context),
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Contact Support'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (IconData, String, String, bool, bool) _getErrorContent(
    LicenseGuardState state,
    String? errorMessage,
  ) {
    switch (state) {
      case LicenseGuardState.noLicense:
        return (
          Icons.key_off,
          'License Required',
          'Please enter your license key to continue using this application.',
          true,
          true,
        );
      case LicenseGuardState.expired:
        return (
          Icons.event_busy,
          'License Expired',
          'Your license has expired. Please renew to continue using this application.',
          false,
          true,
        );
      case LicenseGuardState.businessTypeMismatch:
        return (
          Icons.error_outline,
          'Wrong License Type',
          'The license key you entered is not valid for this business type. '
              'Please use the correct license key.',
          true,
          true,
        );
      case LicenseGuardState.deviceMismatch:
        return (
          Icons.devices_other,
          'Device Not Authorized',
          'This license is registered to a different device. '
              'Please contact support to reset your device binding.',
          false,
          true,
        );
      case LicenseGuardState.blocked:
        return (
          Icons.block,
          'License Blocked',
          'Your license has been blocked. Please contact support immediately.',
          false,
          true,
        );
      case LicenseGuardState.error:
        return (
          Icons.warning_amber,
          'Validation Error',
          errorMessage ??
              'An error occurred while validating your license. Please try again.',
          false,
          true,
        );
      default:
        return (
          Icons.help_outline,
          'Unknown Error',
          'An unexpected error occurred.',
          false,
          true,
        );
    }
  }

  void _showActivationDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter License Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your license key in the format:\nAPP-TYPE-PLATFORM-CODE-YEAR',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'License Key',
                hintText: 'APP-PETROL-DESK-A9F3K-2026',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _activateLicense(context, controller.text);
            },
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  Future<void> _activateLicense(BuildContext context, String licenseKey) async {
    if (licenseKey.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Activating license...'),
          ],
        ),
      ),
    );

    try {
      final licenseService = sl<LicenseService>();
      final result = await licenseService.activateLicense(
        licenseKey: licenseKey,
        businessType: widget.businessType,
      );

      if (context.mounted) Navigator.pop(context); // Close loading

      if (result.isSuccess) {
        // Retry validation
        _retry();
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Activation failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _contactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: support@dukanx.com'),
            SizedBox(height: 8),
            Text('Phone: +91-XXXXXXXXXX'),
            SizedBox(height: 8),
            Text('WhatsApp: +91-XXXXXXXXXX'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Module guard - checks if specific module is enabled
class ModuleGuard extends StatelessWidget {
  final String moduleCode;
  final Widget child;
  final Widget? fallback;

  const ModuleGuard({
    super.key,
    required this.moduleCode,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: sl<LicenseService>().isModuleEnabled(moduleCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final isEnabled = snapshot.data ?? false;

        if (isEnabled) {
          return child;
        }

        return fallback ?? _buildModuleDisabled(context);
      },
    );
  }

  Widget _buildModuleDisabled(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Module Not Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'The "$moduleCode" module is not included in your license.\n'
                'Please upgrade your plan to access this feature.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to upgrade/contact screen
                },
                child: const Text('Upgrade Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
