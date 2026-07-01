// ============================================================================
// APP STATE PROVIDERS - RIVERPOD ONLY
// ============================================================================
// Centralized state management using Riverpod
// Replaces Provider completely for consistent architecture
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed unused cognito import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dukanx/core/api/api_client.dart';
import '../features/onboarding/onboarding_models.dart';
import '../core/billing/business_type_config.dart';
import '../core/licensing/plan_context_cache.dart';
import '../core/licensing/license_snapshot.dart';
import 'license_snapshot_provider.dart';

import '../core/di/service_locator.dart';
import '../core/services/logger_service.dart';
import '../core/session/session_manager.dart';
import '../core/service_registry/service_registry.dart';
import '../features/settings/data/services/profile_image_service.dart';

import '../core/sync/engine/sync_engine.dart'; // Added
import '../core/sync/models/sync_types.dart'; // Added
import '../core/repository/customers_repository.dart';
import '../core/repository/patients_repository.dart';
import '../core/repository/visits_repository.dart';
// import '../core/sync/sync_manager.dart'; // Removed
import '../models/patient.dart';
import '../models/visit.dart';
import '../core/monitoring/monitoring_service.dart';
import '../core/database/app_database.dart';
import '../core/database/daos/pharmacy_dao.dart';
import '../features/clinic/models/clinic_dashboard_models.dart' show ClinicRole;

// ============================================================================
// THEME STATE
// ============================================================================

import 'package:google_fonts/google_fonts.dart';

class AppColorPalette {
  final String name;
  final Color leafGreen;
  final Color sunYellow;
  final Color tomatoRed;
  final Color royalBlue;
  final Color offWhite;
  final Color creamCard;
  final Color mutedGray;
  final Color darkGray;

  Color get textPrimary => mutedGray;
  Color get skyBlue => const Color(0xFF38BDF8); // Light Blue 400
  Color get glassBorder => darkGray.withValues(alpha: 0.1);
  Color get subtleSurface => creamCard.withValues(alpha: 0.5);

  const AppColorPalette({
    required this.name,
    required this.leafGreen,
    required this.sunYellow,
    required this.tomatoRed,
    required this.royalBlue,
    required this.offWhite,
    required this.creamCard,
    required this.mutedGray,
    required this.darkGray,
  });

  static const fresh = AppColorPalette(
    name: 'Fresh Market',
    leafGreen: Color(0xFF0EA5E9), // Ocean Blue
    sunYellow: Color(0xFFFFC107), // Amber 500
    tomatoRed: Color(0xFFEF4444), // Red 500
    royalBlue: Color(0xFF2563EB), // Blue 600
    offWhite: Color(0xFFF8FAFC), // Slate 50
    creamCard: Color(0xFFFFFFFF),
    mutedGray: Color(0xFF1E293B), // Slate 800
    darkGray: Color(0xFF64748B), // Slate 500
  );

  static const ocean = AppColorPalette(
    name: 'Ocean Vibes',
    leafGreen: Color(0xFF0284C7), // Sky 600
    sunYellow: Color(0xFFF59E0B), // Amber 600
    tomatoRed: Color(0xFFDC2626), // Red 600
    royalBlue: Color(0xFF0369A1), // Sky 700
    offWhite: Color(0xFFF0F9FF), // Sky 50
    creamCard: Color(0xFFFFFFFF),
    mutedGray: Color(0xFF0C4A6E), // Sky 900
    darkGray: Color(0xFF7DD3FC), // Sky 300
  );

  static const sunset = AppColorPalette(
    name: 'Sunset Glow',
    leafGreen: Color(0xFF7C3AED), // Violet 600
    sunYellow: Color(0xFFDB2777), // Pink 600
    tomatoRed: Color(0xFFBE123C), // Rose 700
    royalBlue: Color(0xFF9333EA), // Purple 600
    offWhite: Color(0xFFFFF1F2), // Rose 50
    creamCard: Color(0xFFFFFFFF),
    mutedGray: Color(0xFF4C0519), // Rose 900
    darkGray: Color(0xFFFDA4AF), // Rose 300
  );

  static const futuristic = AppColorPalette(
    name: 'DukanX Premium',
    leafGreen: Color(0xFF6366F1), // Indigo 500 (Primary)
    sunYellow: Color(0xFFF59E0B), // Amber 500 (Warning)
    tomatoRed: Color(0xFFF97316), // Orange 500 (Error)
    royalBlue: Color(0xFF0EA5E9), // Sky 500 (Accent)
    offWhite: Color(0xFFF8FAFC), // Slate 50
    creamCard: Color(0xFFFFFFFF),
    mutedGray: Color(0xFF0F172A), // Slate 900
    darkGray: Color(0xFF64748B), // Slate 500
  );

  static const List<AppColorPalette> all = [futuristic, fresh, ocean, sunset];
}

class ThemeState {
  final bool isDark;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final AppColorPalette palette;

  ThemeState({
    required this.isDark,
    required this.lightTheme,
    required this.darkTheme,
    required this.palette,
  });

  ThemeState copyWith({
    bool? isDark,
    AppColorPalette? palette,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
  }) {
    return ThemeState(
      isDark: isDark ?? this.isDark,
      palette: palette ?? this.palette,
      lightTheme: lightTheme ?? this.lightTheme,
      darkTheme: darkTheme ?? this.darkTheme,
    );
  }
}

class ThemeStateNotifier extends Notifier<ThemeState> {
  bool _initialized = false;

  @override
  ThemeState build() {
    // Default initial state
    final defaultPalette = AppColorPalette.futuristic;
    // Fire-and-forget async load (will update state when ready)
    Future.microtask(() => loadSettings());
    return ThemeState(
      isDark: false,
      palette: defaultPalette,
      lightTheme: _buildTheme(false, defaultPalette),
      darkTheme: _buildTheme(true, defaultPalette),
    );
  }

  Future<void> loadSettings() async {
    if (_initialized) return; // SM-AUDIT #6: prevent re-entrancy
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('theme_dark') ?? false;

    state = ThemeState(
      isDark: isDark,
      palette: state.palette,
      lightTheme: _buildTheme(false, state.palette),
      darkTheme: _buildTheme(true, state.palette),
    );
    _initialized = true;
  }

  Future<void> toggleTheme() async {
    final newValue = !state.isDark;
    state = ThemeState(
      isDark: newValue,
      palette: state.palette,
      lightTheme: _buildTheme(false, state.palette),
      darkTheme: _buildTheme(true, state.palette),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_dark', newValue);
  }

  Future<void> setDarkMode(bool value) async {
    state = ThemeState(
      isDark: value,
      palette: state.palette,
      lightTheme: _buildTheme(false, state.palette),
      darkTheme: _buildTheme(true, state.palette),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_dark', value);
  }

  // Ported from legacy ThemeProvider to ensure matching UI
  ThemeData _buildTheme(bool isDark, AppColorPalette palette) {
    // Note: We are simplifying slightly by not passing Locale here for fonts
    // If dynamic language fonts are critical, we need to inject LocaleState
    // For this migration, we'll use the default Google Font (Outfit)

    final baseTextTheme = GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: palette.mutedGray,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: palette.mutedGray,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: palette.mutedGray,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: palette.mutedGray,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: palette.darkGray,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
    );

    if (isDark) {
      return ThemeData.dark(useMaterial3: true).copyWith(
        textTheme: baseTextTheme.apply(
          bodyColor: const Color(0xFFF8FAFC),
          displayColor: const Color(0xFFF8FAFC),
        ),
        primaryColor: palette.leafGreen,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Color(0xFFF8FAFC),
          iconTheme: IconThemeData(color: Color(0xFF94A3B8)),
        ),
        colorScheme: ColorScheme.dark(
          primary: palette.leafGreen,
          secondary: palette.sunYellow,
          error: palette.tomatoRed,
          surface: const Color(0xFF1E293B),
          onSurface: const Color(0xFFF8FAFC),
          onPrimary: Colors.white,
          outline: const Color(0xFF334155),
        ),
        dividerColor: const Color(0x1AFFFFFF),
        dividerTheme: const DividerThemeData(
          color: Color(0x1AFFFFFF),
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF334155),
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF475569)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF475569)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.leafGreen, width: 2),
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF1E293B),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFF334155)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1E293B),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF94A3B8),
          textColor: Color(0xFFF8FAFC),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: const Color(0xFF334155),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF475569)),
          ),
          textStyle: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.leafGreen
                : const Color(0xFF64748B);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.leafGreen.withValues(alpha: 0.4)
                : const Color(0xFF334155);
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.leafGreen
                : Colors.transparent;
          }),
          side: const BorderSide(color: Color(0xFF64748B), width: 1.5),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: palette.leafGreen,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: palette.leafGreen,
          dividerColor: const Color(0xFF334155),
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: palette.leafGreen,
        scaffoldBackgroundColor: palette.offWhite,
        cardColor: palette.creamCard,
        textTheme: baseTextTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: palette.royalBlue,
          brightness: Brightness.light,
          primary: palette.leafGreen,
          secondary: palette.sunYellow,
          error: palette.tomatoRed,
          surface: palette.creamCard,
          onSurface: const Color(0xFF0F172A),
          onPrimary: Colors.white,
          outline: const Color(0xFFE2E8F0),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: palette.offWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFF0F172A),
          iconTheme: const IconThemeData(color: Color(0xFF64748B)),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: palette.creamCard,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        dividerColor: const Color(0xFFE2E8F0),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE2E8F0),
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.leafGreen, width: 2),
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF64748B),
          textColor: Color(0xFF0F172A),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.leafGreen
                : const Color(0xFF94A3B8);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.leafGreen.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0);
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.leafGreen
                : Colors.transparent;
          }),
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: palette.leafGreen,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: palette.leafGreen,
          dividerColor: const Color(0xFFE2E8F0),
        ),
      );
    }
  }
}

final themeStateProvider = NotifierProvider<ThemeStateNotifier, ThemeState>(
  ThemeStateNotifier.new,
);

// ============================================================================
// LOCALE STATE
// ============================================================================

class LocaleState {
  final Locale locale;

  LocaleState({required this.locale});

  LocaleState copyWith({Locale? locale}) {
    return LocaleState(locale: locale ?? this.locale);
  }
}

class LocaleStateNotifier extends Notifier<LocaleState> {
  bool _initialized = false;
  final Locale? _preloadedLocale;

  LocaleStateNotifier() : _preloadedLocale = null;

  /// Used by main.dart to inject the locale pre-loaded before runApp,
  /// eliminating the first-frame English flash.
  LocaleStateNotifier.withInitialLocale(Locale locale)
    : _preloadedLocale = locale;

  @override
  LocaleState build() {
    if (_preloadedLocale != null) {
      _initialized = true;
      return LocaleState(locale: _preloadedLocale);
    }
    _loadFromPrefs();
    return LocaleState(locale: const Locale('en'));
  }

  Future<void> _loadFromPrefs() async {
    if (_initialized) return; // SM-AUDIT #6: prevent re-entrancy
    final prefs = await SharedPreferences.getInstance();

    // Check for new key first
    if (prefs.containsKey('locale')) {
      final langCode = prefs.getString('locale') ?? 'en';
      state = state.copyWith(locale: Locale(langCode));
      return;
    }

    // Fallback/Migrate from legacy key 'app_locale' or 'app_language' (OnboardingService key)
    // OnboardingService uses 'app_language', LocaleProvider used 'app_locale'
    String? legacyName =
        prefs.getString('app_locale') ?? prefs.getString('app_language');

    if (legacyName != null) {
      try {
        final appLang = AppLanguage.values.firstWhere(
          (l) => l.name == legacyName,
          orElse: () => AppLanguage.english,
        );

        final config = LanguageConfig.all.firstWhere(
          (c) => c.language == appLang,
          orElse: () => LanguageConfig.all.first,
        );

        // Save to new key for future
        await prefs.setString('locale', config.code);
        state = state.copyWith(locale: Locale(config.code));
        return;
      } catch (e) {
        LoggerService.d('AppState', 'Error migrating locale: $e');
      }
    }

    // Default
    state = state.copyWith(locale: const Locale('en'));
    _initialized = true;
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
  }
}

final localeStateProvider = NotifierProvider<LocaleStateNotifier, LocaleState>(
  LocaleStateNotifier.new,
);

// ============================================================================
// AUTH STATE
// ============================================================================

enum AuthStatus { unknown, authenticated, unauthenticated, otpRequired }

class AuthState {
  final AuthStatus status;
  final UserSession? session;
  final bool isLoading;
  final String? unconfirmedEmail;
  final ClinicRole? clinicRole;

  AuthState({
    required this.status,
    this.session,
    this.isLoading = false,
    this.unconfirmedEmail,
    this.clinicRole,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserSession? session,
    bool? isLoading,
    String? unconfirmedEmail,
    ClinicRole? clinicRole,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      unconfirmedEmail: unconfirmedEmail ?? this.unconfirmedEmail,
      clinicRole: clinicRole ?? this.clinicRole,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isOwner => session?.isOwner ?? false;
  bool get isCustomer => session?.isCustomer ?? false;
  String? get userId => session?.odId;
  String? get ownerId => session?.ownerId;
}

class AuthStateNotifier extends Notifier<AuthState> {
  late SessionManager _sessionManager;

  @override
  AuthState build() {
    _sessionManager = sl<SessionManager>();

    // Determine initial state
    final initialSession = _sessionManager.currentSession;
    AuthState initialState;
    if (initialSession.isAuthenticated) {
      initialState = AuthState(
        status: AuthStatus.authenticated,
        session: initialSession,
      );
    } else if (_sessionManager.isInitialized) {
      initialState = AuthState(
        status: AuthStatus.unauthenticated,
        session: null,
      );
    } else {
      initialState = AuthState(status: AuthStatus.unknown);
    }

    _listenToSessionChanges();
    return initialState;
  }

  void _listenToSessionChanges() {
    // Listen to session changes
    _sessionManager.addListener(() {
      final session = _sessionManager.currentSession;
      if (session.isAuthenticated) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          unconfirmedEmail: null,
        );
      } else {
        if (state.status != AuthStatus.otpRequired) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            session: null,
            unconfirmedEmail: null,
          );
        }
      }
    });
  }

  void requireOtp(String email) {
    state = state.copyWith(
      status: AuthStatus.otpRequired,
      unconfirmedEmail: email,
      isLoading: false,
    );
  }

  void clearOtpState() {
    if (state.status == AuthStatus.otpRequired) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        unconfirmedEmail: null,
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _sessionManager.signOut();
      state = AuthState(status: AuthStatus.unauthenticated);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshSession() async {
    await _sessionManager.refreshSession();
    final session = _sessionManager.currentSession;
    state = state.copyWith(session: session);
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

// ============================================================================
// CUSTOMERS STATE
// ============================================================================

class CustomersState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;

  CustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
  });

  CustomersState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final customersStreamProvider = StreamProvider.family<List<Customer>, String?>((
  ref,
  userId,
) {
  if (userId == null || userId.isEmpty) {
    return const Stream.empty();
  }
  return sl<CustomersRepository>().watchAll(userId: userId);
});

final patientsStreamProvider = StreamProvider.family<List<Patient>, String?>((
  ref,
  userId,
) async* {
  if (userId == null || userId.isEmpty) {
    yield [];
    return;
  }
  final result = await sl<PatientsRepository>().search('', userId: userId);
  if (result.isSuccess && result.data != null) {
    yield result.data!;
  } else {
    yield [];
  }
});

final todaysVisitsProvider = FutureProvider.autoDispose<List<Visit>>((
  ref,
) async {
  final userId = ref.watch(authStateProvider).userId;
  if (userId == null) return [];

  final repo = sl<VisitsRepository>();
  final result = await repo.getDailyVisits(userId, DateTime.now());

  if (result.isSuccess) {
    return result.data ?? [];
  }
  return [];
});

// ============================================================================
// SYNC STATUS
// ============================================================================

final syncStatusProvider = StreamProvider<SyncStats>((ref) {
  return SyncEngine.instance.statsStream;
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final items = await sl<AppDatabase>().getPendingSyncEntries();
  return items.length;
});

// ============================================================================
// BUSINESS TYPE
// ============================================================================

// ENUM MOVED TO lib/models/business_type.dart

class BusinessTypeState {
  final BusinessType type;
  final String? customName;

  BusinessTypeState({this.type = BusinessType.other, this.customName});

  BusinessTypeState copyWith({BusinessType? type, String? customName}) {
    return BusinessTypeState(
      type: type ?? this.type,
      customName: customName ?? this.customName,
    );
  }

  String get displayName => type.displayName;

  // Feature Flags
  bool get showExpiry =>
      BusinessTypeRegistry.getConfig(type).hasField(ItemField.expiryDate);
  bool get showBatch =>
      BusinessTypeRegistry.getConfig(type).hasField(ItemField.batchNo);
  bool get showTableInfo =>
      BusinessTypeRegistry.getConfig(type).hasModule('kot');
  bool get showDimensions =>
      BusinessTypeRegistry.getConfig(type).hasField(ItemField.dimensions);
  bool get showServiceDetails =>
      BusinessTypeRegistry.getConfig(type).hasModule('jobs');
  bool get showWeight =>
      BusinessTypeRegistry.getConfig(type).hasField(ItemField.weight) ||
      BusinessTypeRegistry.getConfig(type).hasField(ItemField.metalWeight);
  bool get isPetrolPump => type == BusinessType.petrolPump;
  bool get isClinic => type == BusinessType.clinic;
}

class BusinessTypeNotifier extends Notifier<BusinessTypeState> {
  bool _initialized = false;

  @override
  BusinessTypeState build() {
    // Watch the license snapshot to automatically update the business type from the subscription manifest.
    ref.listen<AsyncValue<LicenseSnapshot>>(licenseSnapshotProvider, (
      previous,
      next,
    ) async {
      final snapshot = next.value;
      if (snapshot != null) {
        // Only auto-activate if not overridden by the developer manually in SharedPreferences.
        final prefs = await SharedPreferences.getInstance();
        if (!prefs.containsKey('business_type')) {
          // No manual override, so load the business type from the cached plan context.
          final cachedContext = planContextCache.load();
          if (cachedContext != null && cachedContext.businessType.isNotEmpty) {
            final type = BusinessType.values.firstWhere(
              (t) => t.name == cachedContext.businessType,
              orElse: () => BusinessType.grocery,
            );
            state = BusinessTypeState(
              type: type,
              customName: prefs.getString('business_custom_name'),
            );
          }
        }
      }
    });

    _loadFromPrefs();
    return BusinessTypeState();
  }

  Future<void> _loadFromPrefs() async {
    if (_initialized) return; // SM-AUDIT #6: prevent re-entrancy
    final prefs = await SharedPreferences.getInstance();

    // Attempt to read as String first (New Standard)
    try {
      final typeName = prefs.getString('business_type');
      if (typeName != null) {
        try {
          final type = BusinessType.values.byName(typeName);
          _setState(type, prefs.getString('business_custom_name'));
          return;
        } catch (_) {
          // Fallback if name doesn't match
        }
      }
    } catch (e) {
      // Might be int (Legacy)
    }

    // Fallback: Try reading as Int (Legacy)
    try {
      final typeIndex = prefs.getInt('business_type');
      if (typeIndex != null &&
          typeIndex >= 0 &&
          typeIndex < BusinessType.values.length) {
        _setState(
          BusinessType.values[typeIndex],
          prefs.getString('business_custom_name'),
        );
        return;
      }
    } catch (_) {}

    // Next priority: Load from planContextCache (Hive cache from subscription manifest)
    try {
      final cachedContext = planContextCache.load();
      if (cachedContext != null && cachedContext.businessType.isNotEmpty) {
        final type = BusinessType.values.firstWhere(
          (t) => t.name == cachedContext.businessType,
          orElse: () => BusinessType.grocery,
        );
        _setState(type, prefs.getString('business_custom_name'));
        return;
      }
    } catch (e) {
      LoggerService.d(
        'AppState',
        'BusinessTypeNotifier: Failed to load from planContextCache: $e',
      );
    }

    // CRITICAL FIX: Fallback to license cache if not in SharedPreferences
    // This ensures BusinessGuard works correctly for hardware and other types
    try {
      final db = sl<AppDatabase>();
      final licenseEntries = await db.select(db.licenseCache).get();

      if (licenseEntries.isNotEmpty) {
        final license = licenseEntries.first;
        final businessTypeJson = license.businessType;

        if (businessTypeJson.isNotEmpty) {
          try {
            // Parse JSON array of business types from license
            final List<dynamic> businessTypes = jsonDecode(businessTypeJson);
            if (businessTypes.isNotEmpty) {
              final typeName = businessTypes.first as String;
              final type = _parseBusinessTypeFromLicense(typeName);

              // Save to SharedPreferences for next time
              await prefs.setString('business_type', type.name);

              LoggerService.d(
                'AppState',
                'BusinessTypeNotifier: Loaded from license cache: ${type.name}',
              );
              _setState(type, prefs.getString('business_custom_name'));
              return;
            }
          } catch (e) {
            LoggerService.d(
              'AppState',
              'BusinessTypeNotifier: Failed to parse license business type: $e',
            );
          }
        }
      }
    } catch (e) {
      LoggerService.d(
        'AppState',
        'BusinessTypeNotifier: Failed to load from license cache: $e',
      );
    }

    // Default
    _setState(BusinessType.other, prefs.getString('business_custom_name'));
  }

  /// PHASE 1 FIX B: Single funnel for rehydrated business-type state.
  ///
  /// Consolidates the previous five `state = ...; _initialized = true;` blocks
  /// into one place so the SessionManager bridge runs for EVERY rehydration
  /// path (String, int-index, planContextCache, license cache, default).
  ///
  /// On app boot, `SessionManager._currentSession.businessType` is populated
  /// only from the Firestore `users/{uid}.businessType` field — which is
  /// frequently absent and silently defaults to `grocery`. Meanwhile this
  /// provider correctly rehydrates the persisted SharedPreferences value.
  /// Without bridging here, Inventory + LicenseGuard would read `grocery`
  /// until the next explicit switch. See Phase 0 Section B.4.
  void _setState(BusinessType type, String? customName) {
    state = BusinessTypeState(type: type, customName: customName);
    _initialized = true;
    try {
      sl<SessionManager>().setBusinessType(type);
    } catch (e) {
      // Logged, not swallowed: locator may not be ready in early boot or tests.
      LoggerService.d(
        'AppState',
        'BusinessTypeNotifier._setState: SessionManager bridge failed: $e',
      );
    }
  }

  /// Parse business type string from license to enum
  BusinessType _parseBusinessTypeFromLicense(String businessTypeName) {
    final normalized = businessTypeName.toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );

    switch (normalized) {
      case 'grocery':
      case 'grocerystore':
        return BusinessType.grocery;
      case 'pharmacy':
      case 'medical':
      case 'medicalstore':
        return BusinessType.pharmacy;
      case 'restaurant':
      case 'hotel':
      case 'food':
        return BusinessType.restaurant;
      case 'clothing':
      case 'fashion':
      case 'apparel':
        return BusinessType.clothing;
      case 'electronics':
      case 'electronic':
        return BusinessType.electronics;
      case 'mobileshop':
      case 'mobile':
      case 'mobilephone':
        return BusinessType.mobileShop;
      case 'computershop':
      case 'computer':
        return BusinessType.computerShop;
      case 'hardware':
      case 'hardwarestore':
        return BusinessType.hardware;
      case 'service':
      case 'services':
        return BusinessType.service;
      case 'wholesale':
        return BusinessType.wholesale;
      case 'petrolpump':
      case 'petrol':
      case 'fuelstation':
      case 'gasstation':
        return BusinessType.petrolPump;
      case 'vegetablesbroker':
      case 'vegetablebroker':
      case 'mandi':
      case 'vegetables':
        return BusinessType.vegetablesBroker;
      case 'clinic':
      case 'doctor':
      case 'hospital':
        return BusinessType.clinic;
      case 'bookstore':
      case 'books':
      case 'stationery':
        return BusinessType.bookStore;
      case 'jewellery':
      case 'jewelry':
      case 'jeweller':
      case 'jeweler':
        return BusinessType.jewellery;
      case 'autoparts':
      case 'auto':
      case 'garage':
      case 'automotive':
        return BusinessType.autoParts;
      case 'decorationcatering':
      case 'decoration':
      case 'catering':
      case 'eventmanagement':
        return BusinessType.decorationCatering;
      case 'schoolerp':
      case 'school_erp':
      case 'academiccoaching':
      case 'academic_coaching':
      case 'coaching':
      case 'tuition':
      case 'academy':
      case 'institute':
      case 'school':
        return BusinessType.schoolErp;
      default:
        return BusinessType.other;
    }
  }

  Future<void> setBusinessType(BusinessType type, {String? customName}) async {
    state = BusinessTypeState(type: type, customName: customName);

    // PHASE 1 FIX B: Persist to SharedPreferences (the original behavior).
    // This is what AuthGate's gate-check reads (auth_gate.dart:155) and what
    // BusinessTypeNotifier._loadFromPrefs rehydrates on boot.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_type', type.name);
    if (customName != null) {
      await prefs.setString('business_custom_name', customName);
    }

    // PHASE 1 FIX B (bridge): Keep SessionManager.activeBusinessType in sync.
    // Inventory (product_management_screen, add_edit_product_sheet) and
    // LicenseGuard (via AuthGate) read business type off SessionManager, NOT
    // off this provider. Without this bridge, switching business type updated
    // the Riverpod UI but left those modules reading the old value.
    // See Phase 0 Section B.1 / D.1.
    try {
      sl<SessionManager>().setBusinessType(type);
    } catch (e) {
      // Logged, not swallowed: if the locator isn't ready (e.g. very early
      // boot or test context), we must not crash the selection flow, but we
      // also must not hide that the bridge failed.
      LoggerService.d(
        'AppState',
        'BusinessTypeNotifier.setBusinessType: SessionManager bridge failed: $e',
      );
    }
  }
}

final businessTypeProvider =
    NotifierProvider<BusinessTypeNotifier, BusinessTypeState>(
      BusinessTypeNotifier.new,
    );

// ============================================================================
// APP DATABASE PROVIDER (for direct access if needed)
// ============================================================================

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => AppDatabase.instance,
);

// Modular DAOs
final pharmacyDaoProvider = Provider<PharmacyDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PharmacyDao(db);
});

// ============================================================================
// MONITORING PROVIDER
// ============================================================================

final monitoringProvider = Provider<MonitoringService>((ref) {
  return monitoring;
});

// ============================================================================
// SETTINGS STATE (Dashboard Mode & Profile)
// ============================================================================

class SettingsState {
  final bool isOwnerDashboard;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? businessName;
  // Stable storage keys (never presigned URLs — those expire).
  final String? profileImageKey;
  final String? businessLogoKey;
  // Resolved, currently-valid display URLs derived from the keys above.
  final String? profileImageUrl;
  final String? businessLogoUrl;
  final bool isLoading;

  SettingsState({
    this.isOwnerDashboard = true,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.businessName,
    this.profileImageKey,
    this.businessLogoKey,
    this.profileImageUrl,
    this.businessLogoUrl,
    this.isLoading = false,
  });

  SettingsState copyWith({
    bool? isOwnerDashboard,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? businessName,
    String? profileImageKey,
    String? businessLogoKey,
    String? profileImageUrl,
    String? businessLogoUrl,
    bool? isLoading,
    bool clearProfileImage = false,
    bool clearBusinessLogo = false,
  }) {
    return SettingsState(
      isOwnerDashboard: isOwnerDashboard ?? this.isOwnerDashboard,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      businessName: businessName ?? this.businessName,
      profileImageKey: clearProfileImage
          ? null
          : (profileImageKey ?? this.profileImageKey),
      businessLogoKey: clearBusinessLogo
          ? null
          : (businessLogoKey ?? this.businessLogoKey),
      profileImageUrl: clearProfileImage
          ? null
          : (profileImageUrl ?? this.profileImageUrl),
      businessLogoUrl: clearBusinessLogo
          ? null
          : (businessLogoUrl ?? this.businessLogoUrl),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsStateNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadFromPrefs();
    return SettingsState();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isOwner = prefs.getBool('is_owner_dashboard') ?? true;
    final name = prefs.getString('user_name');
    final email = prefs.getString('user_email');
    final phone = prefs.getString('user_phone');
    final businessName = prefs.getString('business_name');
    final profileKey = prefs.getString('profile_image_key');
    final logoKey = prefs.getString('business_logo_key');

    state = state.copyWith(
      isOwnerDashboard: isOwner,
      userName: name,
      userEmail: email,
      userPhone: phone,
      businessName: businessName,
      profileImageKey: profileKey,
      businessLogoKey: logoKey,
    );

    // Resolve fresh display URLs from the stable keys (presigned URLs expire).
    unawaited(_resolveImageUrls(profileKey, logoKey));

    // Also sync from server if user is logged in (background)
    unawaited(_syncFromFirestore(prefs));
  }

  Future<void> _resolveImageUrls(String? profileKey, String? logoKey) async {
    try {
      final service = ProfileImageService();
      String? profileUrl;
      String? logoUrl;
      if (profileKey != null && profileKey.isNotEmpty) {
        profileUrl = await service.resolveUrl(profileKey);
      }
      if (logoKey != null && logoKey.isNotEmpty) {
        logoUrl = await service.resolveUrl(logoKey);
      }
      state = state.copyWith(
        profileImageUrl: profileUrl,
        businessLogoUrl: logoUrl,
      );
    } catch (_) {
      // Resolution failed (offline/expired) — keep keys; URLs stay null.
    }
  }

  Future<void> setDashboardMode(bool isOwner) async {
    final session = sl<SessionManager>();
    if (!isOwner && session.isOwner) {
      // Owner switching to Customer view - Allowed
    } else if (isOwner && session.isOwner) {
      // Owner switching to Owner view - Allowed
    } else if (isOwner && session.isCustomer) {
      // Customer trying to access Owner view - BLOCKED
      final context = sl<GlobalKey<NavigatorState>>().currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permission Denied: Customers cannot access Owner Dashboard.',
            ),
          ),
        );
      }
      return;
    }

    state = state.copyWith(isOwnerDashboard: isOwner);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_owner_dashboard', isOwner);
  }

  /// Saves the editable profile fields together. Validation must be done by the
  /// caller (UI) before invoking; this method persists trusted values.
  Future<void> saveProfileFields({
    String? name,
    String? email,
    String? phone,
    String? businessName,
  }) async {
    state = state.copyWith(
      userName: name,
      userEmail: email,
      userPhone: phone,
      businessName: businessName,
    );
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('user_name', name);
    if (email != null) await prefs.setString('user_email', email);
    if (phone != null) await prefs.setString('user_phone', phone);
    if (businessName != null) {
      await prefs.setString('business_name', businessName);
    }

    // Persist to API Gateway → DynamoDB.
    try {
      final api = sl<ApiClient>();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (businessName != null) body['businessName'] = businessName;
      await api.put('/api/v1/profile', body: body);
    } catch (_) {
      // Silent fail — local prefs already updated; background sync will retry.
    }
  }

  /// Back-compat single-field name setter.
  Future<void> setUserName(String name) => saveProfileFields(name: name);

  /// Stores the profile-photo storage [key] and its resolved [url].
  Future<void> updateProfileImage(String key, String url) async {
    state = state.copyWith(profileImageKey: key, profileImageUrl: url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_key', key);

    try {
      final api = sl<ApiClient>();
      await api.put('/api/v1/profile', body: {'profileImageKey': key});
    } catch (_) {
      // Silent fail — local prefs already updated.
    }
  }

  /// Stores the business-logo storage [key] and its resolved [url].
  Future<void> updateBusinessLogo(String key, String url) async {
    state = state.copyWith(businessLogoKey: key, businessLogoUrl: url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_logo_key', key);

    try {
      final api = sl<ApiClient>();
      await api.put('/api/v1/profile', body: {'businessLogoKey': key});
    } catch (_) {
      // Silent fail — local prefs already updated.
    }
  }

  /// Removes the profile photo locally, on the server, and in storage.
  Future<void> removeProfileImage() async {
    final key = state.profileImageKey;
    state = state.copyWith(clearProfileImage: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_key');

    try {
      final api = sl<ApiClient>();
      await api.put('/api/v1/profile', body: {'profileImageKey': null});
      if (key != null && key.isNotEmpty) {
        unawaited(Services.storage.delete(key).catchError((_) {}));
      }
    } catch (_) {
      // Silent fail — local state already cleared.
    }
  }

  /// Removes the business logo locally, on the server, and in storage.
  Future<void> removeBusinessLogo() async {
    final key = state.businessLogoKey;
    state = state.copyWith(clearBusinessLogo: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('business_logo_key');

    try {
      final api = sl<ApiClient>();
      await api.put('/api/v1/profile', body: {'businessLogoKey': null});
      if (key != null && key.isNotEmpty) {
        unawaited(Services.storage.delete(key).catchError((_) {}));
      }
    } catch (_) {
      // Silent fail — local state already cleared.
    }
  }

  Future<void> _syncFromFirestore(SharedPreferences prefs) async {
    final uid = sl<SessionManager>().userId;
    if (uid == null) return;

    try {
      final api = sl<ApiClient>();
      final res = await api
          .get('/api/v1/profile')
          .timeout(const Duration(seconds: 5));

      if (res.isSuccess && res.data != null) {
        final data = res.data!;
        final name = data['name'] as String?;
        final email = data['email'] as String?;
        final phone = data['phone'] as String?;
        final businessName = data['businessName'] as String?;
        final profileKey = data['profileImageKey'] as String?;
        final logoKey = data['businessLogoKey'] as String?;

        if (name != null) unawaited(prefs.setString('user_name', name));
        if (email != null) unawaited(prefs.setString('user_email', email));
        if (phone != null) unawaited(prefs.setString('user_phone', phone));
        if (businessName != null) {
          unawaited(prefs.setString('business_name', businessName));
        }
        if (profileKey != null) {
          unawaited(prefs.setString('profile_image_key', profileKey));
        }
        if (logoKey != null) {
          unawaited(prefs.setString('business_logo_key', logoKey));
        }

        state = state.copyWith(
          userName: name,
          userEmail: email,
          userPhone: phone,
          businessName: businessName,
          profileImageKey: profileKey,
          businessLogoKey: logoKey,
        );

        // Resolve fresh display URLs for any server-provided keys.
        unawaited(_resolveImageUrls(profileKey, logoKey));
      }
    } catch (e) {
      // Silent fail on sync
    }
  }
}

final settingsStateProvider =
    NotifierProvider<SettingsStateNotifier, SettingsState>(
      SettingsStateNotifier.new,
    );
// Convenience provider for current user ID (Deprecated Firebase User replacement)
final currentUserProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).userId;
});
