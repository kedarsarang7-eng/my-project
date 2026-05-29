// ============================================================================
// CUSTOMER PWA — THEME + ROUTER
// ============================================================================
// dart:html replaced with Uri.base for cross-platform URL parsing
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/landing/scan_landing_screen.dart';
import 'features/menu/menu_screen.dart';
import 'features/order/order_bag_screen.dart';
import 'features/order/order_tracking_screen.dart';
import 'features/bill/live_bill_screen.dart';
import 'features/payment/payment_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/verification_screen.dart';
import 'features/auth/providers/auth_provider.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const kOrange = Color(0xFFEA580C);
const kCream = Color(0xFFFEF3C7);
const kDark = Color(0xFF0F0F0F);

// Parse QR params from URL: ?v=VENDOR_ID&t=TABLE_ID
Map<String, String> _parseQrParams() {
  try {
    return Uri.base.queryParameters;
  } catch (_) {
    return {};
  }
}

class RestroCustomerApp extends ConsumerWidget {
  const RestroCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state to trigger rebuilds on auth changes
    final authState = ref.watch(authStateProvider);

    return MaterialApp.router(
      title: 'DukanX Restro',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: GoRouter(
        initialLocation: '/',
        redirect: (context, state) {
          // P1-04: Customer PWA is anonymous-by-default.
          // Customers reach /menu via QR scan, no login required.
          // Login routes exist only for the future "View past orders" CTA.
          final isAuth = authState.valueOrNull ?? false;
          final isLoggingIn =
              state.uri.path == '/login' ||
              state.uri.path == '/signup' ||
              state.uri.path == '/verify';

          if (isAuth && isLoggingIn) return '/menu';
          // All other routes (/, /menu, /bag, /payment, /track, /bill) are open.
          return null;
        },
        routes: _routes,
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kDark,
      colorScheme: const ColorScheme.dark(
        primary: kOrange,
        secondary: kOrange,
        surface: Color(0xFF1A1A1A),
      ),
      textTheme: ThemeData.dark().textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: kDark,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      useMaterial3: true,
    );
  }
}

final _routes = [
  GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
  GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
  GoRoute(
    path: '/verify',
    builder: (context, state) {
      final username = state.extra as String? ?? '';
      return VerificationScreen(username: username);
    },
  ),
  GoRoute(
    path: '/',
    builder: (ctx, state) {
      final params = _parseQrParams();
      return ScanLandingScreen(
        vendorId: params['v'] ?? '',
        tableId: params['t'] ?? '',
      );
    },
  ),
  GoRoute(
    path: '/menu',
    builder: (ctx, state) {
      final extra = state.extra as Map<String, String>? ?? {};
      return MenuScreen(
        vendorId: extra['vendorId'] ?? '',
        tableId: extra['tableId'] ?? '',
      );
    },
  ),
  GoRoute(
    path: '/bag',
    builder: (ctx, state) {
      final extra = state.extra as Map<String, String>? ?? {};
      return OrderBagScreen(
        vendorId: extra['vendorId'] ?? '',
        tableId: extra['tableId'] ?? '',
      );
    },
  ),
  GoRoute(
    path: '/payment',
    builder: (ctx, state) {
      final extra = state.extra as Map<String, String>? ?? {};
      return PaymentScreen(
        vendorId: extra['vendorId'] ?? '',
        tableId: extra['tableId'] ?? '',
        customerName: extra['customerName'] ?? '',
        phone: extra['phone'] ?? '',
      );
    },
  ),
  GoRoute(
    path: '/track',
    builder: (ctx, state) {
      final extra = state.extra as Map<String, String>? ?? {};
      return OrderTrackingScreen(
        vendorId: extra['vendorId'] ?? '',
        orderId: extra['orderId'] ?? '',
        tableId: extra['tableId'] ?? '',
      );
    },
  ),
  GoRoute(
    path: '/bill',
    builder: (ctx, state) {
      final extra = state.extra as Map<String, String>? ?? {};
      return LiveBillScreen(
        vendorId: extra['vendorId'] ?? '',
        tableId: extra['tableId'] ?? '',
      );
    },
  ),
];
