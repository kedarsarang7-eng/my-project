// ============================================================================
// USER REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages generic User data (auth settings, onboarding flags)
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart'; // Added
import '../error/error_handler.dart';

class UserRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  UserRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'users';

  /// Get user record by ID
  Future<RepositoryResult<UserEntity?>> getUser(String userId) async {
    return await errorHandler.runSafe<UserEntity?>(() async {
      return await (database.select(
        database.users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
    }, 'getUser');
  }

  /// Mark login onboarding as seen
  Future<RepositoryResult<void>> markLoginOnboardingSeen(String userId) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // Ensure user exists locally first
      final existing = await (database.select(
        database.users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (existing == null) {
        await database
            .into(database.users)
            .insert(
              UsersCompanion.insert(
                id: userId,
                hasSeenLoginOnboarding: const Value(true),
                loginOnboardingSeenAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (database.update(
          database.users,
        )..where((t) => t.id.equals(userId))).write(
          UsersCompanion(
            hasSeenLoginOnboarding: const Value(true),
            loginOnboardingSeenAt: Value(now),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );
      }

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: userId,
          payload: {
            'hasSeenLoginOnboarding': true,
            'loginOnboardingSeenAt': now.toIso8601String(),
          },
        ),
      );
    }, 'markLoginOnboardingSeen');
  }

  /// Create or update user locally (for session sync)
  Future<RepositoryResult<UserEntity>> syncUserLocally({
    required String id,
    String? email,
    String? role,
    bool? hasSeenLoginOnboarding,
  }) async {
    return await errorHandler.runSafe<UserEntity>(() async {
      final now = DateTime.now();
      final companion = UsersCompanion(
        id: Value(id),
        email: email != null ? Value(email) : const Value.absent(),
        role: role != null ? Value(role) : const Value.absent(),
        hasSeenLoginOnboarding: hasSeenLoginOnboarding != null
            ? Value(hasSeenLoginOnboarding)
            : const Value.absent(),
        updatedAt: Value(now),
        createdAt: Value(now), // Ignored on update
      );

      await database.into(database.users).insertOnConflictUpdate(companion);

      return await (database.select(
        database.users,
      )..where((t) => t.id.equals(id))).getSingle();
    }, 'syncUserLocally');
  }
}
