// ignore_for_file: unused_element
// License Middleware — Global license check wrapping entire app navigation
// All routes must pass through this middleware before rendering
//
// States: valid → proceed, expired → lock/read-only, trial_expired → upgrade prompt
// Integrates with AntiTamperService for integrity checks

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../services/license_write_block_service.dart';
import '../models/business_type.dart';
import '../core/di/service_locator.dart';
import '../core/services/logger_service.dart';
import '../security/anti_tamper_service.dart';

/// Global license state for the middleware
enum LicenseMiddlewareState {
  checking,
  valid,
  readOnly, // expired but data still visible
  trialExpired, // trial specifically expired — show upgrade prompt
  expired, // fully expired — locked
  suspended,
  blocked,
  noLicense,
  error,
}

/// License Middleware Widget — wraps entire app
class LicenseMiddleware extends StatefulWidget {
  final Widget child;
  final BusinessType businessType;

  /// Called when revalidation timer fires — use to trigger heartbeat
  final VoidCallback? onPeriodicRevalidation;

  const LicenseMiddleware({
    super.key,
    required this.child,
    required this.businessType,
    this.onPeriodicRevalidation,
  });

  @override
  State<LicenseMiddleware> createState() => _LicenseMiddlewareState();
}

class _LicenseMiddlewareState extends State<LicenseMiddleware> {
  LicenseMiddlewareState _state = LicenseMiddlewareState.checking;
  String? _errorMessage;
  int? _daysUntilExpiry;
  Timer? _revalidationTimer;
  final _antiTamper = AntiTamperService();

  // HIGH-003 FIX: Reduced from 4h to 30min for faster ban/revocation detection
  static const _revalidationInterval = Duration(minutes: 30);

  // MED-005 FIX: Static flag to block writes at service level when in readOnly state.
  // Service layer should check LicenseWriteBlockService.instance.isBlocked instead.
  static bool get isWriteBlocked => LicenseWriteBlockService.instance.isBlocked;

  @override
  void initState() {
    super.initState();
    _validate();
    _startRevalidationTimer();
  }

  void _startRevalidationTimer() {
    _revalidationTimer?.cancel();
    _revalidationTimer = Timer.periodic(_revalidationInterval, (_) {
      _validate();
      widget.onPeriodicRevalidation?.call();
    });
  }

  Future<void> _validate() async {
    setState(() => _state = LicenseMiddlewareState.checking);

    try {
      // Run anti-tamper checks first
      final tamperResult = _antiTamper.performChecks();
      if (tamperResult.isSuspicious) {
        LoggerService.d('License', 
          'LicenseMiddleware: Tamper warning — ${tamperResult.warnings}',
        );
      }

      final licenseService = sl<LicenseService>();
      final result = await licenseService.validateLicense(
        requiredBusinessType: widget.businessType,
      );

      if (!mounted) return;

      if (result.isValid) {
        _daysUntilExpiry = result.daysUntilExpiry;

        setState(() => _state = LicenseMiddlewareState.valid);
      } else {
        switch (result.status) {
          case LicenseStatus.expired:
            // Check if this was a trial — show upgrade prompt
            final category = result.license?.licenseType ?? '';
            if (category == 'trial') {
              setState(() {
                _state = LicenseMiddlewareState.trialExpired;
                _errorMessage = 'Your trial license has expired.';
              });
            } else {
              // Paid/lifetime expired — allow read-only
              setState(() {
                _state = LicenseMiddlewareState.readOnly;
                _errorMessage = result.message;
              });
            }
            break;
          case LicenseStatus.suspended:
            setState(() {
              _state = LicenseMiddlewareState.suspended;
              _errorMessage = 'License suspended. Contact support.';
            });
            break;
          case LicenseStatus.blocked:
            setState(() {
              _state = LicenseMiddlewareState.blocked;
              _errorMessage = result.message ?? 'License blocked.';
            });
            break;
          case LicenseStatus.notFound:
            setState(() {
              _state = LicenseMiddlewareState.noLicense;
              _errorMessage = 'No license found.';
            });
            break;
          default:
            setState(() {
              _state = LicenseMiddlewareState.error;
              _errorMessage = result.message ?? 'License validation failed.';
            });
        }
      }
    } catch (e) {
      if (!mounted) return;
      LoggerService.d('License', 'LicenseMiddleware: Validation error: $e');
      setState(() {
        _state = LicenseMiddlewareState.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case LicenseMiddlewareState.checking:
        return _buildCheckingScreen();

      case LicenseMiddlewareState.valid:
        LicenseWriteBlockService.instance.unblock();
        return Stack(
          children: [
            widget.child,
            // Show renewal warning banner if expiring within 3 days
            if (_daysUntilExpiry != null &&
                _daysUntilExpiry! <= 3 &&
                _daysUntilExpiry! >= 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildRenewalBanner(),
              ),
          ],
        );

      case LicenseMiddlewareState.readOnly:
        // MED-005 FIX: Block writes via singleton service
        LicenseWriteBlockService.instance.block(reason: 'License expired — read-only mode');
        return Stack(
          children: [
            AbsorbPointer(
              absorbing:
                  false, // Allow viewing — writes blocked at service level via isWriteBlocked
              child: widget.child,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildExpiredBanner(isReadOnly: true),
            ),
          ],
        );

      case LicenseMiddlewareState.trialExpired:
        return _buildTrialExpiredScreen();

      case LicenseMiddlewareState.expired:
      case LicenseMiddlewareState.suspended:
      case LicenseMiddlewareState.blocked:
      case LicenseMiddlewareState.noLicense:
      case LicenseMiddlewareState.error:
        return _buildLockedScreen();
    }
  }

  Widget _buildCheckingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Validating License...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenewalBanner() {
    return Material(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade700, Colors.deepOrange.shade600],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _daysUntilExpiry == 0
                      ? 'License expires TODAY! Renew now.'
                      : 'License expires in $_daysUntilExpiry day${_daysUntilExpiry == 1 ? '' : 's'}. Renew soon.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredBanner({bool isReadOnly = false}) {
    return Material(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(color: Colors.redAccent),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(
                Icons.lock_clock_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isReadOnly
                      ? 'License expired. Read-only mode — modifications disabled.'
                      : 'License expired. Please renew to continue.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrialExpiredScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_disabled_rounded,
                size: 72,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Trial License Expired',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your trial period has ended.\nPlease activate a Paid License to continue using DukanX.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Activate Paid License'),
                onPressed: () {
                  // Navigate to license activation screen
                  // This will be wired to the actual activation flow
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _validate,
                child: const Text('Retry Validation'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedScreen() {
    IconData icon;
    String title;
    String subtitle;

    switch (_state) {
      case LicenseMiddlewareState.suspended:
        icon = Icons.pause_circle_filled_rounded;
        title = 'License Suspended';
        subtitle =
            _errorMessage ??
            'Your license has been suspended. Contact support.';
        break;
      case LicenseMiddlewareState.blocked:
        icon = Icons.block_rounded;
        title = 'License Blocked';
        subtitle =
            _errorMessage ?? 'Your license has been permanently revoked.';
        break;
      case LicenseMiddlewareState.noLicense:
        icon = Icons.vpn_key_off_rounded;
        title = 'No License Found';
        subtitle = 'Please enter a valid license key to use DukanX.';
        break;
      default:
        icon = Icons.error_outline_rounded;
        title = 'License Error';
        subtitle = _errorMessage ?? 'Unable to validate license.';
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _validate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _revalidationTimer?.cancel();
    super.dispose();
  }
}
