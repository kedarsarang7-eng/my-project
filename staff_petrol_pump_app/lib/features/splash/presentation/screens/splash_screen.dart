import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/websocket/websocket_manager.dart';
import '../../../../features/petrol_pump/providers/license_provider.dart';
import '../../../petrol_pump/theme/fuelpos_theme.dart';

/// Splash Screen with auto-login check
/// 
/// This screen shows on app startup and:
/// 1. Checks if user has valid tokens
/// 2. Validates token expiry
/// 3. Refreshes if needed
/// 4. Navigates to appropriate dashboard or login
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _status = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Step 1: Check authentication
      setState(() => _status = 'Checking authentication...');
      await Future.delayed(const Duration(milliseconds: 500)); // UX delay

      final authRepo = AuthRepository();
      final isAuthenticated = await authRepo.isAuthenticated();

      if (!isAuthenticated) {
        // No valid auth - go to login
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // Step 2: Load license profile
      setState(() => _status = 'Loading station data...');
      await ref.read(licenseProvider.notifier).fetchLicenseProfile();

      // Step 3: Connect WebSocket for real-time updates
      setState(() => _status = 'Connecting to payment server...');
      try {
        await WebSocketManager().connect();
      } catch (e) {
        // Non-critical: Continue even if WebSocket fails
        debugPrint('WebSocket connection failed: $e');
      }

      // Step 4: Navigate based on business type
      if (!mounted) return;

      final license = ref.read(licenseProvider).profile;
      final businessType = license?.businessType ?? '';

      switch (businessType.toLowerCase()) {
        case 'petrol_pump':
        case 'fuel_station':
        case 'gas_station':
          context.go('/dashboard/petrol-pump');
          break;
        case 'retail':
        case 'shop':
        case 'store':
          context.go('/dashboard/retail');
          break;
        case 'restaurant':
        case 'food':
          context.go('/dashboard/restaurant');
          break;
        case 'pharmacy':
        case 'medical':
          context.go('/dashboard/pharmacy');
          break;
        default:
          // Unknown business type - go to generic dashboard
          context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _status = 'Error: $e';
      });

      // Wait a moment then go to login
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuelPOSTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with shimmer effect
            Shimmer.fromColors(
              baseColor: FuelPOSTheme.petrolBlue,
              highlightColor: FuelPOSTheme.dieselOrange,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [FuelPOSTheme.petrolBlue, FuelPOSTheme.dieselOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.local_gas_station,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // App name
            Text(
              'FuelPOS',
              style: TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Petrol Pump Management',
              style: TextStyle(
                color: FuelPOSTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            if (!_hasError) ...[
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: FuelPOSTheme.cardDark,
                  valueColor: AlwaysStoppedAnimation<Color>(FuelPOSTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status text
            Text(
              _status,
              style: TextStyle(
                color: _hasError ? FuelPOSTheme.errorRed : FuelPOSTheme.textMuted,
                fontSize: 12,
              ),
            ),

            // Retry button on error
            if (_hasError) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _status = 'Retrying...';
                  });
                  _initializeApp();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
