// ============================================================================
// POST-LOGIN ENTERPRISE INITIALIZATION + WEEKLY INTEGRITY CHECK
// ============================================================================
// • `initEnterpriseServicesForUser` — called after a user logs in to bootstrap
//   per-tenant services (module loader, app bootstrap, anti-tamper) and kick
//   off the weekly integrity job.
// • Weekly integrity job — auto-reconciles stock counts and customer ledger
//   balances against authoritative DB rows; fire-and-forget so it never blocks
//   the UI.
// ============================================================================

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_bootstrap.dart';
import '../core/database/app_database.dart';
import '../core/di/service_locator.dart';
import '../core/services/module_loader_service.dart';
import '../core/session/session_manager.dart';
import '../features/restaurant/data/migrations/restaurant_vendor_id_migration.dart';
import '../security/anti_tamper_service.dart';
import '../services/data_integrity_service.dart';

/// Bootstrap enterprise services after login. Idempotent.
Future<void> initEnterpriseServicesForUser(String userId) async {
  if (AppBootstrap.instance.isInitialized) {
    developer.log('Enterprise services already initialized', name: 'main');
    return;
  }

  try {
    try {
      await sl<ModuleLoaderService>().init();
    } catch (_) {}

    await AppBootstrap.instance.initialize(
      userId: userId,
      enableBackgroundSync: !kIsWeb,
    );
    developer.log('Enterprise services initialized for user', name: 'main');

    // Anti-tamper detection (Phase A security).
    final tamperResult = AntiTamperService().performChecks();
    if (tamperResult.isSuspicious) {
      developer.log(
        'Anti-tamper WARNING: ${tamperResult.warnings}',
        name: 'security',
      );
    }

    // Restaurant vendor ID migration (P0 tenant isolation fix).
    // Migrates legacy 'SYSTEM' vendorId rows to the real tenant ID.
    // Fire-and-forget — non-blocking, idempotent, runs once per install.
    _runRestaurantVendorIdMigration();

    _runWeeklyIntegrityCheck(userId);
  } catch (e, stack) {
    developer.log(
      'Enterprise init failed: $e',
      name: 'main',
      stackTrace: stack,
    );
  }
}

/// Background integrity check that runs at most once every 7 days.
/// Fire-and-forget — never blocks UI.
void _runWeeklyIntegrityCheck(String userId) {
  Future.microtask(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('lastIntegrityCheck') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const weekInMs = 7 * 24 * 60 * 60 * 1000;

      if (now - lastCheck > weekInMs) {
        developer.log('Running weekly integrity check...', name: 'integrity');

        final integrityService = DataIntegrityService(
          database: AppDatabase.instance,
        );

        final stockResult = await integrityService
            .verifyAndAutoFixStockIntegrity(
              userId,
              minorThreshold: 1.0,
              alertThreshold: 5.0,
            );
        developer.log(
          'Stock integrity: ${stockResult.checkedCount} products, '
          '${stockResult.minorFixCount} corrections',
          name: 'integrity',
        );

        final ledgerResult = await integrityService.reconcileCustomerBalance(
          userId,
        );
        developer.log(
          'Ledger integrity: ${ledgerResult.checkedCount} customers, '
          '${ledgerResult.correctionCount} corrected',
          name: 'integrity',
        );

        await prefs.setInt('lastIntegrityCheck', now);
        developer.log('Weekly integrity check complete', name: 'integrity');
      }
    } catch (e) {
      developer.log(
        'Integrity check failed (non-blocking): $e',
        name: 'integrity',
      );
    }
  });
}

/// Runs the one-time restaurant vendorId migration if the active business type
/// is restaurant. Migrates legacy 'SYSTEM' rows to the real tenant ID.
/// Fire-and-forget — never blocks UI.
void _runRestaurantVendorIdMigration() {
  Future.microtask(() async {
    try {
      final session = sl<SessionManager>();
      if (session.activeBusinessType != BusinessType.restaurant) return;

      await RestaurantVendorIdMigration.runIfNeeded(
        AppDatabase.instance,
        session,
      );
    } catch (e) {
      developer.log(
        'Restaurant vendorId migration failed (non-blocking): $e',
        name: 'migration',
      );
    }
  });
}
