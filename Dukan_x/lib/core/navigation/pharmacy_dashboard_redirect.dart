import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../../core/session/session_manager.dart';
import '../../core/di/service_locator.dart';

/// Pharmacy Dashboard Redirect - Business Type Aware Routing
///
/// This widget implements the post-login routing logic for pharmacy business type.
/// It checks:
/// 1. User's business_type from JWT/session
/// 2. License features for pharmacy_dashboard
/// 3. Redirects to /pharmacy/dashboard if both conditions are met
/// 4. Falls back to default dashboard or 403 for unauthorized access
class PharmacyDashboardRedirect extends ConsumerStatefulWidget {
  const PharmacyDashboardRedirect({super.key});

  @override
  ConsumerState<PharmacyDashboardRedirect> createState() =>
      _PharmacyDashboardRedirectState();
}

class _PharmacyDashboardRedirectState
    extends ConsumerState<PharmacyDashboardRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePharmacyRedirect();
    });
  }

  Future<void> _handlePharmacyRedirect() async {
    if (!mounted) return;

    try {
      // Get current session and business type
      final sessionManager = sl<SessionManager>();
      final currentSession = sessionManager.currentSession;

      // Check if user is authenticated
      if (!currentSession.isAuthenticated) {
        context.pushReplacement(RoutePaths.login);
        return;
      }

      // Check business type - pharmacy takes priority
      final businessType = currentSession.businessType;
      final isPharmacyBusiness = businessType == BusinessType.pharmacy;

      // Check license for pharmacy_dashboard feature
      final hasPharmacyLicense = await _checkPharmacyLicense(
        currentSession.odId,
      );

      if (isPharmacyBusiness && hasPharmacyLicense) {
        // Redirect to pharmacy dashboard
        context.pushReplacement('/pharmacy/dashboard');
        return;
      }

      // If business type is not pharmacy but license has pharmacy feature, still redirect
      if (!isPharmacyBusiness && hasPharmacyLicense) {
        context.pushReplacement('/pharmacy/dashboard');
        return;
      }

      // Fall through to default dashboard
      context.pushReplacement('/owner_dashboard');
    } catch (e) {
      // On error, fall back to default dashboard
      context.pushReplacement('/owner_dashboard');
    }
  }

  Future<bool> _checkPharmacyLicense(String userId) async {
    try {
      // Check license features for pharmacy_dashboard
      final sessionManager = sl<SessionManager>();
      final session = sessionManager.currentSession;
      return session.isAuthenticated &&
          session.businessType == BusinessType.pharmacy;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Redirecting to your dashboard...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route guard for pharmacy dashboard access
/// Protects /pharmacy/dashboard route from unauthorized access
class PharmacyRouteGuard extends ConsumerWidget {
  final Widget child;

  const PharmacyRouteGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = sl<SessionManager>().currentSession;
    if (!session.isAuthenticated) {
      return _buildUnauthorized(
        context,
        'Please login to access pharmacy dashboard',
      );
    }
    if (session.businessType == BusinessType.pharmacy) {
      return child;
    }
    return _buildUnauthorized(
      context,
      'Pharmacy dashboard is only available for pharmacy businesses',
    );
  }

  Widget _buildUnauthorized(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_pharmacy, size: 64, color: Colors.grey),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  context.pushReplacement('/owner_dashboard');
                },
                child: const Text('Go to Default Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
