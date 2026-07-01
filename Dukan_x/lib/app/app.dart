// ============================================================================
// DUKANX ROOT APP WIDGET
// ============================================================================
// The top-level app shell. Owns:
//   • Localization config + supported locales
//   • Theme (driven by Riverpod `themeStateProvider`)
//   • Navigation via the single `GoRouter` (`appRouterProvider`) consumed by
//     `MaterialApp.router` — go_router is the sole navigation path
//   • Global keyboard handler + help overlay
//   • Sync-conflict / license-invalid listeners
//   • Admin-action WebSocket subscription (forced logout / suspend)
// ============================================================================

import 'dart:io' show Platform;

import 'package:dukanx/generated/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../core/di/service_locator.dart';
import '../core/session/session_manager.dart';
import '../core/sync/sync_conflict_listener.dart';
import '../core/localization/remote_translation_service.dart';
import '../providers/app_state_providers.dart';
import '../security/license_invalid_listener.dart';
import 'package:dukanx/services/websocket_service.dart';
import '../widgets/desktop/keyboard_help_overlay.dart';
import '../core/keyboard/global_keyboard_handler.dart';
import '../widgets/error_boundary.dart';
import 'global_keys.dart';
import '../core/theme/futuristic_colors.dart';
import '../core/routing/app_router.dart';
import '../core/routing/route_paths.dart';

/// Maximum text-scale factor applied on mobile/tablet/desktop (non-Windows)
/// platforms. The Windows render path is intentionally left unmodified per the
/// platform-freeze constraint; large system font sizes there pass through as-is.
///
/// On Android/iOS/iPadOS/macOS (and web) we cap growth so increased system font
/// size doesn't shatter fixed-width KPI cards and dense billing layouts. This is
/// a safety net on top of the per-widget responsiveness fixes; individual Text
/// widgets also gain `maxLines`/`overflow` so they degrade gracefully regardless.
const double kMaxTextScaleFactor = 1.3;

/// Pure, platform-parameterized text-scale clamp arithmetic.
///
/// Returns the effective linear text-scale factor for [requested] given whether
/// the host is Windows:
/// - Windows: pass-through (no cap) per the platform-freeze constraint.
/// - non-Windows: clamp into `[1.0, kMaxTextScaleFactor]`, so above-cap requests
///   collapse to exactly the cap and at-or-below-cap requests pass through.
///
/// This function has no Flutter/platform dependencies, so it is fully unit- and
/// property-testable in isolation.
double clampTextScaleFactor(double requested, {required bool isWindows}) {
  if (isWindows) {
    return requested;
  }
  return requested.clamp(1.0, kMaxTextScaleFactor);
}

/// Thin adapter over [clampTextScaleFactor] used by `MaterialApp.builder`.
///
/// Derives the linear scale factor from [data], clamps it via the pure
/// [clampTextScaleFactor], and only rebuilds [MediaQueryData] (via
/// [TextScaler.linear]) when the factor actually changes. On Windows the
/// original [data] is returned unchanged so the desktop layout/behavior is not
/// altered.
///
/// The [isWindowsOverride] parameter exists solely for tests; production callers
/// pass nothing, preserving the live `!kIsWeb && Platform.isWindows` check.
MediaQueryData applyTextScaleClamp(
  MediaQueryData data, {
  bool? isWindowsOverride,
}) {
  // HARD SCOPE CONSTRAINT: Windows platform code/layout/behavior must NOT change.
  final isWindows = isWindowsOverride ?? (!kIsWeb && Platform.isWindows);
  final requested = data.textScaler.scale(1.0);
  final effective = clampTextScaleFactor(requested, isWindows: isWindows);
  if (effective == requested) {
    return data;
  }
  // Rebuild a linear scaler so we don't depend on the TextScaler.clamp API
  // (which differs across Flutter versions). This caps font growth at
  // [kMaxTextScaleFactor] on non-Windows platforms.
  return data.copyWith(textScaler: TextScaler.linear(effective));
}

class DukanXApp extends riverpod.ConsumerStatefulWidget {
  const DukanXApp({super.key});

  @override
  riverpod.ConsumerState<DukanXApp> createState() => _DukanXAppState();
}

class _DukanXAppState extends riverpod.ConsumerState<DukanXApp> {
  @override
  void initState() {
    super.initState();
    WebSocketService.instance.subscribe(
      WSEventName.adminAction,
      _onAdminAction,
    );
  }

  @override
  void dispose() {
    WebSocketService.instance.unsubscribe(
      WSEventName.adminAction,
      _onAdminAction,
    );
    super.dispose();
  }

  void _onAdminAction(WSEvent event) {
    if (!mounted) return;

    final action = event.data['action'];
    if (action == 'logout' || action == 'suspend') {
      sl<SessionManager>().signOut();

      // go_router is the sole navigation path. Drive the out-of-context
      // logout through the single GoRouter (which owns globalNavigatorKey) so
      // the stack is reset to the canonical auth gate (AD-5 / Req 7.8).
      ref.read(appRouterProvider).go(RoutePaths.authGate);

      globalScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            action == 'suspend'
                ? 'Your account has been suspended by the administrator.'
                : 'You have been logged out by the administrator.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    final localeState = ref.watch(localeStateProvider);
    // Kick off OTA translation fetch in background — never blocks rendering.
    ref.watch(remoteTranslationProvider);

    // Sync FuturisticColors static flag so all dynamic getters
    // return the correct light/dark values throughout the widget tree.
    FuturisticColors.sync(themeState.isDark);

    // go_router is the SOLE navigation path (Task 9.3 — legacy removal). The
    // app root always drives navigation through the single `GoRouter` from
    // `appRouterProvider` (AppRouter). The legacy named-route table and the
    // navigation feature flag have been removed.
    return ErrorBoundary(
      child: _buildGoRouterApp(context, themeState, localeState),
    );
  }

  /// Builds the go_router-backed app root.
  ///
  /// Drives navigation through the single [GoRouter] from `appRouterProvider`
  /// (`AppRouter` — splash/login/business-type resolution + the main shell
  /// `ShellRoute`). The GoRouter owns `globalNavigatorKey`, so out-of-context
  /// navigation and the listener stack keep working unchanged.
  Widget _buildGoRouterApp(
    BuildContext context,
    ThemeState themeState,
    LocaleState localeState,
  ) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      // navigatorKey is owned by the GoRouter (globalNavigatorKey), so it is
      // NOT passed here — MaterialApp.router forbids a duplicate key.
      scaffoldMessengerKey: globalScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'DukanX',
      locale: localeState.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('mr'),
        Locale('gu'),
        Locale('ta'),
        Locale('te'),
        Locale('kn'),
        Locale('ml'),
        Locale('bn'),
        Locale('pa'),
        Locale('ur'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeState.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      routerConfig: router,
      builder: _appBuilder,
    );
  }

  /// Shared `MaterialApp.builder` for the app-wide overlay/listener stack and
  /// the accessibility text-scale clamp.
  Widget _appBuilder(BuildContext context, Widget? child) {
    // Cap system text-scale growth app-wide so fixed-width layouts (KPI
    // cards, dense billing rows) don't overflow when users raise font size
    // for accessibility. Windows is exempt (see applyTextScaleClamp).
    final clampedMediaQuery = applyTextScaleClamp(MediaQuery.of(context));
    return MediaQuery(
      data: clampedMediaQuery,
      child: GlobalKeyboardHandler(
        onHelpRequested: () {
          // F1 Help overlay is managed via keyboardStateProvider
        },
        onQuitRequested: () {
          // Handle app quit request
        },
        child: SyncConflictListener(
          navigatorKey: globalNavigatorKey,
          child: LicenseInvalidListener(
            navigatorKey: globalNavigatorKey,
            child: Stack(
              children: [
                // The main app content (Navigator)
                child!,
                // Global Overlays (always on top)
                const KeyboardHelpOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
