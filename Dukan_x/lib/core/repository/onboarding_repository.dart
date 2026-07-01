// ============================================================================
// ONBOARDING REPOSITORY - FIRESTORE-FIRST
// ============================================================================
// Manages onboarding state with Firestore as the source of truth
//
// CRITICAL RULES:
// 1. Firestore is ALWAYS checked first for onboarding status
// 2. Local cache is ONLY for offline fallback
// 3. SharedPreferences is NEVER the primary source
// 4. On completion, BOTH Firestore and local are updated
//
// Author: DukanX Engineering
// ============================================================================

import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

/// OnboardingRepository - Firestore-first onboarding persistence
///
/// CRITICAL: Firestore is the SOURCE OF TRUTH for onboarding status.
/// This ensures onboarding state persists across:
/// - App restarts
/// - App reinstalls
/// - Device changes
/// - Logout/Login cycles
class OnboardingRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  OnboardingRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  static const String _collection = 'owners';

  /// Check if user has completed onboarding
  ///
  /// PRIORITY ORDER:
  /// 1. Check Firestore first (source of truth)
  /// 2. Fall back to local DB if offline
  /// 3. Never rely solely on SharedPreferences
  Future<bool> hasCompletedOnboarding(String userId) async {
    if (userId.isEmpty) return false;

    // === STEP 1: Try Firestore first (source of truth) ===
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists) {
        final data = doc.data();
        final completed =
            data?['onboardingCompleted'] == true ||
            data?['hasCompletedOnboarding'] == true; // Support both field names

        // Cache locally for offline access
        await _cacheOnboardingStatus(userId, completed);

        debugPrint(
          '[OnboardingRepository] Firestore check: onboardingCompleted=$completed',
        );
        return completed;
      }

      // Document doesn't exist = new user = needs onboarding
      debugPrint('[OnboardingRepository] User document not found in Firestore');
      return false;
    } catch (e) {
      debugPrint(
        '[OnboardingRepository] Firestore unavailable, falling back to local: $e',
      );
    }

    // === STEP 2: Fallback to local DB ===
    return await _getLocalOnboardingStatus(userId);
  }

  /// Mark onboarding as completed
  ///
  /// Persists to BOTH Firestore and local DB for reliability
  Future<RepositoryResult<void>> completeOnboarding({
    required String userId,
    required String businessType,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      final data = {
        'onboardingCompleted': true,
        'hasCompletedOnboarding': true, // Backward compatibility
        'businessType': businessType,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // === STEP 1: Update Firestore (source of truth) ===
      try {
        await FirebaseFirestore.instance
            .collection(_collection)
            .doc(userId)
            .set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));

        debugPrint('[OnboardingRepository] Onboarding persisted to Firestore');
      } catch (e) {
        debugPrint(
          '[OnboardingRepository] Firestore write failed, queueing for sync: $e',
        );

        // Queue for sync if Firestore fails
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.update,
            targetCollection: _collection,
            documentId: userId,
            payload: {
              'onboardingCompleted': true,
              'hasCompletedOnboarding': true,
              'businessType': businessType,
              'onboardingCompletedAt': now.toIso8601String(),
            },
          ),
        );
      }

      // === STEP 2: Update local DB ===
      await _cacheOnboardingStatus(userId, true);

      // === STEP 3: Update Shops table for business type ===
      await (database.update(
        database.shops,
      )..where((t) => t.id.equals(userId))).write(
        ShopsCompanion(
          onboardingCompleted: const Value(true),
          businessType: Value(businessType),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      debugPrint('[OnboardingRepository] Onboarding completed for $userId');
    }, 'completeOnboarding');
  }

  /// Save business type selection
  Future<RepositoryResult<void>> saveBusinessType({
    required String userId,
    required String businessType,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // Update Firestore
      try {
        await FirebaseFirestore.instance
            .collection(_collection)
            .doc(userId)
            .set({
              'businessType': businessType,
              'billTemplate': businessType, // Legacy support
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        // Queue for sync if offline
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.update,
            targetCollection: _collection,
            documentId: userId,
            payload: {
              'businessType': businessType,
              'updatedAt': now.toIso8601String(),
            },
          ),
        );
      }

      // Update local DB
      await (database.update(
        database.shops,
      )..where((t) => t.id.equals(userId))).write(
        ShopsCompanion(
          businessType: Value(businessType),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    }, 'saveBusinessType');
  }

  /// Get user's business type
  Future<String?> getBusinessType(String userId) async {
    if (userId.isEmpty) return null;

    // Try Firestore first
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists) {
        return doc.data()?['businessType'] as String?;
      }
    } catch (e) {
      debugPrint('[OnboardingRepository] Firestore read failed: $e');
    }

    // Fallback to local
    final shop = await (database.select(
      database.shops,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();

    return shop?.businessType;
  }

  // === PRIVATE METHODS ===

  /// Cache onboarding status locally
  Future<void> _cacheOnboardingStatus(String userId, bool completed) async {
    try {
      final now = DateTime.now();

      // Check if shop exists
      final existing = await (database.select(
        database.shops,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();

      if (existing != null) {
        await (database.update(
          database.shops,
        )..where((t) => t.id.equals(userId))).write(
          ShopsCompanion(
            onboardingCompleted: Value(completed),
            updatedAt: Value(now),
          ),
        );
      } else {
        // Create minimal shop record for caching
        await database
            .into(database.shops)
            .insert(
              ShopsCompanion(
                id: Value(userId),
                onboardingCompleted: Value(completed),
                createdAt: Value(now),
                updatedAt: Value(now),
                isSynced: const Value(false),
              ),
            );
      }
    } catch (e) {
      debugPrint('[OnboardingRepository] Local cache failed: $e');
    }
  }

  /// Get onboarding status from local DB
  Future<bool> _getLocalOnboardingStatus(String userId) async {
    try {
      final shop = await (database.select(
        database.shops,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();

      return shop?.onboardingCompleted ?? false;
    } catch (e) {
      debugPrint('[OnboardingRepository] Local read failed: $e');
      return false;
    }
  }

  // === LOCKDOWN ENFORCEMENT ===

  /// Check if business type is PERMANENTLY LOCKED
  ///
  /// Returns true if ANY transaction exists:
  /// - Bills
  /// - Purchase Orders
  /// - Expenses
  ///
  /// Once a business has data, the type CANNOT be changed
  /// to prevent data corruption and audit violation.
  Future<bool> isBusinessTypeLocked(String userId) async {
    if (userId.isEmpty) return false;

    // Check Bills (Sales)
    final billCount =
        await (database.select(database.bills)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull()))
            .get()
            .then((rows) => rows.length);

    if (billCount > 0) return true;

    // Check Purchase Orders
    final poCount =
        await (database.select(database.purchaseOrders)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull()))
            .get()
            .then((rows) => rows.length);

    if (poCount > 0) return true;

    // Check Expenses
    final expenseCount =
        await (database.select(database.expenses)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull()))
            .get()
            .then((rows) => rows.length);

    if (expenseCount > 0) return true;

    // Check Payments (Money In/Out)
    final paymentCount =
        await (database.select(database.payments)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull()))
            .get()
            .then((rows) => rows.length);

    if (paymentCount > 0) return true;

    return false;
  }
}
