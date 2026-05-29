// ============================================================================
// POS APP — THEME + ROUTER
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/verification_screen.dart';
import 'features/floor/floor_grid_screen.dart';
import 'features/order/table_order_screen.dart';
import 'features/order/kot_preview_screen.dart';
import 'features/kitchen/kitchen_display_screen.dart';
import 'features/billing/split_bill_screen.dart';
import 'features/auth/providers/auth_provider.dart';

// ── Colours ──────────────────────────────────────────────────────────────────
const kOrange = Color(0xFFEA580C);
const kOrangeLight = Color(0xFFFED7AA);
const kDark = Color(0xFF0F0F0F);
const kDarkSurface = Color(0xFF1A1A1A);
const kDarkCard = Color(0xFF242424);
const kDarkBorder = Color(0xFF2E2E2E);

class RestaurantPosApp extends ConsumerWidget {
  const RestaurantPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state to trigger rebuilds on auth changes
    final authState = ref.watch(authStateProvider);

    return MaterialApp.router(
      title: 'DukanX Restro POS',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: GoRouter(
        initialLocation: '/login',
        // Redirect logic to protect routes
        redirect: (context, state) {
          final isAuth = authState.value ?? false;
          final isLoggingIn =
              state.uri.path == '/login' ||
              state.uri.path == '/signup' ||
              state.uri.path == '/verify';

          if (!isAuth && !isLoggingIn) return '/login';
          if (isAuth && isLoggingIn) return '/floor';
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
        surface: kDarkSurface,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: kDarkSurface,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      cardTheme: const CardThemeData(
        color: kDarkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: kDarkBorder, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kDarkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kDarkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOrange, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
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
  GoRoute(path: '/floor', builder: (context, state) => const FloorGridScreen()),
  GoRoute(
    path: '/table/:tableId',
    builder: (context, state) {
      final tableId = state.pathParameters['tableId']!;
      final tableNumber = state.uri.queryParameters['number'] ?? tableId;
      return TableOrderScreen(tableId: tableId, tableNumber: tableNumber);
    },
  ),
  GoRoute(path: '/kot', builder: (context, state) => const KotPreviewScreen()),
  GoRoute(
    path: '/kds',
    builder: (context, state) => const KitchenDisplayScreen(),
  ),
  GoRoute(
    path: '/split/:tableId',
    builder: (context, state) {
      final tableId = state.pathParameters['tableId']!;
      return SplitBillScreen(tableId: tableId);
    },
  ),
];
