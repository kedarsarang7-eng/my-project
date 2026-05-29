import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'features/petrol_pump/theme/fuelpos_theme.dart' as theme;
import 'router/fuelpos_router.dart';

/// FuelPOS Main Entry Point
/// 
/// This is the main entry point for the FuelPOS Petrol Pump application.
/// It uses the FuelPOS dark theme and the FuelPOS router with license-based
/// business type routing.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  runApp(const ProviderScope(child: FuelPOSApp()));
}

class FuelPOSApp extends ConsumerWidget {
  const FuelPOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'FuelPOS | Petrol Pump Management',
      debugShowCheckedModeBanner: false,
      theme: theme.FuelPOSTheme.darkTheme,
      darkTheme: theme.FuelPOSTheme.darkTheme,
      themeMode: ThemeMode.dark, // Always use dark theme for FuelPOS
      routerConfig: FuelPOSRouter.buildRouter(ref),
      supportedLocales: const [
        Locale('en', 'IN'), // Indian English for INR formatting
        Locale('en', ''),
      ],
      builder: (context, child) => FuelPOSErrorBoundary(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Error boundary for FuelPOS
class FuelPOSErrorBoundary extends StatelessWidget {
  final Widget child;

  const FuelPOSErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
