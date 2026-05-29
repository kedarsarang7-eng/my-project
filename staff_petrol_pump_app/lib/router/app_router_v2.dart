import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/token_storage.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/billing/billing_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/tenant/tenant_list_screen.dart';
import '../features/users/user_list_screen.dart';
import '../features/petrol_pump/providers/license_provider.dart';
import '../pages/403_page.dart';
import '../pages/license_page.dart' as custom;
import '../pages/main_login_page.dart';

class AppRouterV2 {
  static String _extractRole(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return '';
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    return (payload['roleName'] ?? payload['custom:role'] ?? '')
        .toString()
        .toLowerCase();
  }

  static GoRouter createRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const MainLoginPage()),
      GoRoute(path: '/license', builder: (context, state) => const custom.LicensePage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/403', builder: (context, state) => const ForbiddenPage()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/tenants', builder: (context, state) => const TenantListScreen()),
      GoRoute(path: '/users', builder: (context, state) => const UserListScreen()),
      GoRoute(path: '/billing', builder: (context, state) => const BillingScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      
      // ENHANCED: Business type specific routes with guards
      GoRoute(
        path: '/fuel-pos',
        builder: (context, state) => _BusinessTypeGuard(
          requiredBusinessType: 'petrol_pump',
          child: const _PlaceholderScreen(title: 'Fuel POS'),
        ),
      ),
      GoRoute(
        path: '/shifts',
        builder: (context, state) => _BusinessTypeGuard(
          requiredBusinessType: 'petrol_pump',
                    child: const _PlaceholderScreen(title: 'Shifts'),
        ),
      ),
      GoRoute(
        path: '/pharmacy',
        builder: (context, state) => _BusinessTypeGuard(
          requiredBusinessType: 'pharmacy',
                    child: const _PlaceholderScreen(title: 'Pharmacy'),
        ),
      ),
      GoRoute(
        path: '/drug-stock',
        builder: (context, state) => _BusinessTypeGuard(
          requiredBusinessType: 'pharmacy',
                    child: const _PlaceholderScreen(title: 'Drug Stock'),
        ),
      ),
      GoRoute(
        path: '/restaurant',
        builder: (context, state) => _BusinessTypeGuard(
          requiredBusinessType: 'restaurant',
                    child: const _PlaceholderScreen(title: 'Restaurant'),
        ),
      ),
      GoRoute(
        path: '/clinic',
        builder: (context, state) => _BusinessTypeGuard(
          requiredBusinessType: 'clinic',
                    child: const _PlaceholderScreen(title: 'Clinic'),
        ),
      ),
      GoRoute(
        path: '/grocery',
        builder: (context, state) => _BusinessTypeGuard(
          requiredBusinessType: 'grocery',
                    child: const _PlaceholderScreen(title: 'Grocery'),
        ),
      ),
    ],
    redirect: (context, state) async {
      final token = await TokenStorage.getAccessToken();
      final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/register' || state.uri.path == '/license';
      if (token == null && !isAuthRoute) {
        return '/login';
      }
      if (token != null && isAuthRoute) {
        return '/dashboard';
      }

      if (token != null) {
        try {
          final roleName = _extractRole(token);
          final path = state.uri.path;
          if (path == '/admin' && roleName != 'admin') {
            return '/403';
          }
          if (path == '/tenants' && roleName != 'admin') {
            return '/403';
          }
          if (path == '/users' && roleName != 'admin' && roleName != 'manager') {
            return '/403';
          }
          if (path == '/billing' &&
              roleName != 'admin' &&
              roleName != 'manager' &&
              roleName != 'ca') {
            return '/403';
          }
        } catch (_) {
          return '/login';
        }
      }

      return null;
    },
  );
  }
}

// ENHANCED: Business Type Route Guard
class _BusinessTypeGuard extends ConsumerWidget {
  final String requiredBusinessType;
  final Widget child;

  const _BusinessTypeGuard({
    required this.requiredBusinessType,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseState = ref.watch(licenseStateProvider);
    final license = licenseState.profile;

    if (license == null) {
      return const _LoadingScreen();
    }

    if (!license.hasBusinessType(requiredBusinessType)) {
      return const _AccessDeniedScreen();
    }

    if (!license.isActive || license.isExpired) {
      return const _LicenseExpiredScreen();
    }

    return child;
  }
}

// ENHANCED: Placeholder Screen for Business Type Routes
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Module Under Development',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This business module is currently being implemented.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your license does not include access to this business module.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseExpiredScreen extends StatelessWidget {
  const _LicenseExpiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('License Issue')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'License Issue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your license is inactive or expired. Please contact support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
