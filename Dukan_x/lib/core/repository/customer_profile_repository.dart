// ============================================================================
// CUSTOMER PROFILE REPOSITORY
// ============================================================================
// Shop-scoped customer profile management for multi-tenant data isolation.
// Each customer gets a unique profile per shop they link to.
//
// CRITICAL: Bills MUST reference customerProfileId, NOT customerId directly.
// Author: DukanX Engineering
// ============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

class CustomerProfileRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  CustomerProfileRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'customer_profiles';

  /// Generate unique QR hash for a shop-customer profile
  /// Uses SHA256(shopId + customerId + timestamp + random salt)
  String _generateQrHash(String shopId, String customerId) {
    final salt = const Uuid().v4();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    final input = '$shopId:$customerId:$timestamp:$salt';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a new customer profile for a shop
  /// This is called when a customer scans a shop's QR code
  Future<RepositoryResult<CustomerProfileEntity>> createProfile({
    required String shopId,
    required String customerId,
    String? displayName,
    String? phone,
    String? email,
  }) async {
    return await errorHandler.runSafe<CustomerProfileEntity>(() async {
      final now = DateTime.now();
      final profileId = const Uuid().v4();
      final qrHash = _generateQrHash(shopId, customerId);

      final companion = CustomerProfilesCompanion(
        id: Value(profileId),
        shopId: Value(shopId),
        customerId: Value(customerId),
        qrHash: Value(qrHash),
        displayName: Value(displayName),
        phone: Value(phone),
        email: Value(email),
        status: const Value('ACTIVE'),
        createdAt: Value(now),
        updatedAt: Value(now),
        isSynced: const Value(false),
      );

      await database.into(database.customerProfiles).insert(companion);

      final profile = await (database.select(
        database.customerProfiles,
      )..where((t) => t.id.equals(profileId))).getSingle();

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: shopId, // Shop owns this profile
          operationType: SyncOperationType.create,
          targetCollection: collectionName,
          documentId: profileId,
          payload: _entityToMap(profile),
        ),
      );

      return profile;
    }, 'createProfile');
  }

  /// Get profile by ID
  Future<RepositoryResult<CustomerProfileEntity?>> getProfileById(
    String profileId,
  ) async {
    return await errorHandler.runSafe<CustomerProfileEntity?>(() async {
      return await (database.select(
        database.customerProfiles,
      )..where((t) => t.id.equals(profileId))).getSingleOrNull();
    }, 'getProfileById');
  }

  /// Get profile for a specific shop-customer combination
  Future<RepositoryResult<CustomerProfileEntity?>> getProfileForShopCustomer({
    required String shopId,
    required String customerId,
  }) async {
    return await errorHandler.runSafe<CustomerProfileEntity?>(() async {
      return await (database.select(database.customerProfiles)..where(
            (t) => t.shopId.equals(shopId) & t.customerId.equals(customerId),
          ))
          .getSingleOrNull();
    }, 'getProfileForShopCustomer');
  }

  /// Get all profiles for a customer (all linked shops)
  Future<RepositoryResult<List<CustomerProfileEntity>>> getProfilesForCustomer(
    String customerId,
  ) async {
    return await errorHandler.runSafe<List<CustomerProfileEntity>>(() async {
      return await (database.select(database.customerProfiles)
            ..where(
              (t) =>
                  t.customerId.equals(customerId) & t.status.equals('ACTIVE'),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
    }, 'getProfilesForCustomer');
  }

  /// Get all profiles for a shop (all linked customers)
  Future<RepositoryResult<List<CustomerProfileEntity>>> getProfilesForShop(
    String shopId,
  ) async {
    return await errorHandler.runSafe<List<CustomerProfileEntity>>(() async {
      return await (database.select(database.customerProfiles)
            ..where((t) => t.shopId.equals(shopId) & t.status.equals('ACTIVE'))
            ..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .get();
    }, 'getProfilesForShop');
  }

  /// Watch profiles for a shop (reactive)
  Stream<List<CustomerProfileEntity>> watchProfilesForShop(String shopId) {
    return (database.select(database.customerProfiles)
          ..where((t) => t.shopId.equals(shopId) & t.status.equals('ACTIVE'))
          ..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
        .watch();
  }

  /// Validate that a profile exists and is active
  Future<bool> validateProfile({
    required String shopId,
    required String customerProfileId,
  }) async {
    final profile =
        await (database.select(database.customerProfiles)..where(
              (t) =>
                  t.id.equals(customerProfileId) &
                  t.shopId.equals(shopId) &
                  t.status.equals('ACTIVE'),
            ))
            .getSingleOrNull();
    return profile != null;
  }

  /// Get profile by QR hash (for QR linking validation)
  Future<RepositoryResult<CustomerProfileEntity?>> getProfileByQrHash(
    String qrHash,
  ) async {
    return await errorHandler.runSafe<CustomerProfileEntity?>(() async {
      return await (database.select(
        database.customerProfiles,
      )..where((t) => t.qrHash.equals(qrHash))).getSingleOrNull();
    }, 'getProfileByQrHash');
  }

  /// Block a customer profile (shop-side action)
  Future<RepositoryResult<void>> blockProfile({
    required String profileId,
    required String reason,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(
        database.customerProfiles,
      )..where((t) => t.id.equals(profileId))).write(
        CustomerProfilesCompanion(
          status: const Value('BLOCKED'),
          blockReason: Value(reason),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      final profile = await (database.select(
        database.customerProfiles,
      )..where((t) => t.id.equals(profileId))).getSingleOrNull();
      if (profile != null) {
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: profile.shopId,
            operationType: SyncOperationType.update,
            targetCollection: collectionName,
            documentId: profileId,
            payload: {'status': 'BLOCKED', 'blockReason': reason},
          ),
        );
      }
    }, 'blockProfile');
  }

  /// Unblock a customer profile
  Future<RepositoryResult<void>> unblockProfile(String profileId) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(
        database.customerProfiles,
      )..where((t) => t.id.equals(profileId))).write(
        CustomerProfilesCompanion(
          status: const Value('ACTIVE'),
          blockReason: const Value(null),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    }, 'unblockProfile');
  }

  /// Update profile display name
  Future<RepositoryResult<void>> updateDisplayName({
    required String profileId,
    required String displayName,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(
        database.customerProfiles,
      )..where((t) => t.id.equals(profileId))).write(
        CustomerProfilesCompanion(
          displayName: Value(displayName),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    }, 'updateDisplayName');
  }

  Map<String, dynamic> _entityToMap(CustomerProfileEntity e) {
    return {
      'id': e.id,
      'shopId': e.shopId,
      'customerId': e.customerId,
      'qrHash': e.qrHash,
      'displayName': e.displayName,
      'phone': e.phone,
      'email': e.email,
      'status': e.status,
      'blockReason': e.blockReason,
      'createdAt': e.createdAt.toIso8601String(),
      'updatedAt': e.updatedAt.toIso8601String(),
    };
  }
}
