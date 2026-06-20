import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/token_storage.dart';
import '../features/auth/register_screen.dart';
import '../features/petrol_pump/providers/license_provider.dart';
import '../features/petrol_pump/screens/petrol_pump_dashboard_screen.dart';
import '../features/petrol_pump/presentation/screens/amount_entry_screen.dart';
import '../features/petrol_pump/presentation/screens/qr_display_screen.dart';
import '../features/petrol_pump/presentation/screens/payment_success_screen.dart';
import '../features/petrol_pump/presentation/screens/payment_failed_screen.dart';
import '../features/petrol_pump/presentation/screens/staff_list_screen.dart';
import '../features/petrol_pump/presentation/screens/add_staff_screen.dart';
import '../features/petrol_pump/presentation/screens/staff_detail_screen.dart';
import '../features/petrol_pump/presentation/screens/revenue_dashboard_screen.dart';
import '../features/petrol_pump/presentation/screens/staff_mobile/staff_mobile_dashboard.dart';
import '../features/petrol_pump/presentation/screens/staff_mobile/staff_shift_summary_screen.dart';
import '../features/petrol_pump/presentation/screens/staff_mobile/staff_quick_pay_screen.dart';
import '../features/petrol_pump/presentation/screens/staff_mobile/staff_transactions_screen.dart';
import '../features/petrol_pump/presentation/screens/staff_mobile/staff_profile_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../pages/403_page.dart';
import '../pages/license_page.dart' as custom;
import '../pages/main_login_page.dart';

/// FuelPOS Router with License-Based Routing
/// Handles routing based on user's business type from license profile
class FuelPOSRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Extract business type from JWT token
  static String? _extractBusinessType(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      return (payload['custom:business_type'] ??
              payload['businessType'] ??
              payload['custom:businessType'])
          ?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Get redirect path based on business type
  static String? _getRedirectPath(String? businessType) {
    if (businessType == null) return null;

    final normalizedType = businessType.toLowerCase().trim();

    return switch (normalizedType) {
      'petrol_pump' ||
      'fuel_station' ||
      'gas_station' =>
        '/dashboard/petrol-pump',
      'retail' || 'shop' || 'store' => '/dashboard/retail',
      'restaurant' || 'food' => '/dashboard/restaurant',
      'pharmacy' || 'medical' || 'drugstore' => '/dashboard/pharmacy',
      _ => '/dashboard',
    };
  }

  /// Build the router
  static GoRouter buildRouter(WidgetRef ref) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash', // Start with splash for auto-login check
      routes: [
        // Splash screen (auto-login check)
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),

        // Auth routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const MainLoginPage(),
        ),
        GoRoute(
          path: '/license',
          builder: (context, state) => const custom.LicensePage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/403',
          builder: (context, state) => const ForbiddenPage(),
        ),

        // Petrol Pump Dashboard
        GoRoute(
          path: '/dashboard/petrol-pump',
          builder: (context, state) => const PetrolPumpDashboardScreen(),
        ),

        // QR Payment Flow (NEW - Critical Feature)
        GoRoute(
          path: '/qr/entry',
          builder: (context, state) => const AmountEntryScreen(),
        ),
        GoRoute(
          path: '/qr/display',
          builder: (context, state) => const QRDisplayScreen(),
        ),

        // Payment Result Screens (NEW)
        GoRoute(
          path: '/payment/success',
          builder: (context, state) => PaymentSuccessScreen(
            paymentData: state.extra as Map<String, dynamic>?,
          ),
        ),
        GoRoute(
          path: '/payment/failed',
          builder: (context, state) => PaymentFailedScreen(
            errorMessage: state.extra as String?,
          ),
        ),

        // Staff Management (NEW)
        GoRoute(
          path: '/staff',
          builder: (context, state) => const StaffListScreen(),
        ),
        GoRoute(
          path: '/staff/add',
          builder: (context, state) => const AddStaffScreen(),
        ),
        GoRoute(
          path: '/staff/:id',
          builder: (context, state) => StaffDetailScreen(
            staffId: state.pathParameters['id']!,
          ),
        ),

        // Revenue Reports (NEW)
        GoRoute(
          path: '/reports',
          builder: (context, state) => const RevenueDashboardScreen(),
        ),
        GoRoute(
          path: '/reports/revenue',
          builder: (context, state) => const RevenueDashboardScreen(),
        ),

        // Sales, Inventory, Customers, Settings (placeholder screens)
        GoRoute(
          path: '/sales',
          builder: (context, state) => const _ComingSoonPlaceholder(
            title: 'Sales',
            icon: Icons.receipt_long_outlined,
          ),
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const _ComingSoonPlaceholder(
            title: 'Inventory',
            icon: Icons.inventory_2_outlined,
          ),
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const _ComingSoonPlaceholder(
            title: 'Customers',
            icon: Icons.people_outline,
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const _ComingSoonPlaceholder(
            title: 'Settings',
            icon: Icons.settings_outlined,
          ),
        ),

        // Staff Mobile App (NEW - for staff on mobile/iOS)
        GoRoute(
          path: '/staff-mobile',
          builder: (context, state) => const StaffMobileDashboard(),
        ),
        GoRoute(
          path: '/staff-mobile/quick-pay',
          builder: (context, state) => const StaffQuickPayScreen(),
        ),
        GoRoute(
          path: '/staff-mobile/shift-summary',
          builder: (context, state) => const StaffShiftSummaryScreen(),
        ),
        GoRoute(
          path: '/staff-mobile/transactions',
          builder: (context, state) => const StaffTransactionsScreen(),
        ),
        GoRoute(
          path: '/staff-mobile/profile',
          builder: (context, state) => const StaffProfileScreen(),
        ),

        // Generic dashboard (fallback)
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const _DashboardPlaceholder(),
        ),

        // Placeholder routes for other business types
        GoRoute(
          path: '/dashboard/retail',
          builder: (context, state) => const _BusinessTypePlaceholder(
            businessType: 'Retail',
          ),
        ),
        GoRoute(
          path: '/dashboard/restaurant',
          builder: (context, state) => const _BusinessTypePlaceholder(
            businessType: 'Restaurant',
          ),
        ),
        GoRoute(
          path: '/dashboard/pharmacy',
          builder: (context, state) => const _BusinessTypePlaceholder(
            businessType: 'Pharmacy',
          ),
        ),
      ],
      redirect: (context, state) async {
        final token = await TokenStorage.getAccessToken();
        final isAuthRoute = [
          '/login',
          '/register',
          '/license',
          '/splash',
        ].contains(state.uri.path);

        // Not authenticated and trying to access protected route
        if (token == null && !isAuthRoute) {
          return '/splash'; // Go to splash first for auto-login check
        }

        // Authenticated but on auth route (except splash) - redirect to appropriate dashboard
        if (token != null && isAuthRoute && state.uri.path != '/splash') {
          final businessType = _extractBusinessType(token);
          return _getRedirectPath(businessType) ?? '/dashboard';
        }

        // Check business type access control
        if (token != null) {
          final businessType = _extractBusinessType(token);
          final currentPath = state.uri.path;

          // If trying to access petrol-pump dashboard but not a petrol pump
          if (currentPath == '/dashboard/petrol-pump' &&
              businessType?.toLowerCase() != 'petrol_pump') {
            return '/403';
          }
        }

        return null;
      },
      refreshListenable: _RouterRefreshNotifier(ref),
    );
  }
}

/// Router refresh notifier that listens to auth state changes
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(WidgetRef ref) {
    ref.listen<LicenseState>(
      licenseProvider,
      (previous, next) {
        // Notify router to re-evaluate redirect when license changes
        if (previous?.profile?.businessType != next.profile?.businessType) {
          notifyListeners();
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Placeholder for generic dashboard
class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuelPOSTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dashboard,
              size: 64,
              color: FuelPOSTheme.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Dashboard',
              style: TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a business type',
              style: TextStyle(
                color: FuelPOSTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for other business types
class _BusinessTypePlaceholder extends StatelessWidget {
  final String businessType;

  const _BusinessTypePlaceholder({required this.businessType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuelPOSTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 64,
              color: FuelPOSTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              '$businessType Dashboard',
              style: const TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: TextStyle(
                color: FuelPOSTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard/petrol-pump'),
              child: const Text('Go to Petrol Pump Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder screen for sections under development
class _ComingSoonPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;

  const _ComingSoonPlaceholder({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuelPOSTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: FuelPOSTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming Soon',
              style: TextStyle(
                color: FuelPOSTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard/petrol-pump'),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

// Import needed for FuelPOSTheme
class FuelPOSTheme {
  static const Color backgroundDark = Color(0xFF0F1419);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8C4);
  static const Color textMuted = Color(0xFF6B7280);
}
