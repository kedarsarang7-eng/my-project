// ============================================================================
// DUKANX CUSTOMER APP — ENTRY POINT
// ============================================================================
// Architecture:
//   UI → Riverpod → Repository → CustomerApiClient (REST) → AWS Backend
//   No Drift DB. No SyncManager. No owner-app concerns.
// ============================================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'config/app_config.dart';
import 'core/navigation/app_router.dart';
import 'core/security/security_service.dart';
import 'core/theme/app_theme.dart';

// ============================================================================
// FCM BACKGROUND HANDLER (top-level, required by firebase_messaging)
// ============================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Minimal work here — heavy lifting is done in the foreground handler
}

// ============================================================================
// ENTRY POINT
// ============================================================================
void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Lock orientation to portrait for mobile
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Load .env and populate static AppConfig
      try {
        await dotenv.load(fileName: '.env');
        AppConfig.fromEnv();
      } catch (_) {}

      // Security check — rooted/jailbroken device detection
      final securityResult = await SecurityService.checkDevice();
      if (!securityResult.passed) {
        runApp(_SecurityBlockedApp(reason: securityResult.reason ?? 'Device not supported'));
        return;
      }

      // Hive — offline cart cache
      await Hive.initFlutter();

      // Firebase (FCM only)
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      } catch (_) {}

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };

      runApp(const ProviderScope(child: DukanXCustomerApp()));
    },
    (error, stack) {
      // Zone-level uncaught error — log but do not crash
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

// ============================================================================
// SECURITY BLOCK SCREEN — shown when device is rooted/jailbroken
// ============================================================================
class _SecurityBlockedApp extends StatelessWidget {
  final String reason;
  const _SecurityBlockedApp({required this.reason});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security_rounded,
                      size: 72, color: Color(0xFFE53935)),
                  const SizedBox(height: 24),
                  const Text(
                    'Device Not Supported',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DukanX cannot run on rooted or jailbroken devices to protect your financial data.',
                    style: TextStyle(color: Color(0xFFB0B0C0), fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: const TextStyle(
                        color: Color(0xFF607080), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ROOT APPLICATION WIDGET
// ============================================================================
class DukanXCustomerApp extends ConsumerWidget {
  const DukanXCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'DukanX — My Account',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('mr'),
        Locale('gu'),
        Locale('ta'),
        Locale('te'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
