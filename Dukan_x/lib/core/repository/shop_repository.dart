import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart'; // Added
import '../error/error_handler.dart';

class ShopRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  ShopRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'owners';

  /// Get shop profile by owner ID
  Future<RepositoryResult<ShopEntity?>> getShopProfile(String ownerId) async {
    return await errorHandler.runSafe<ShopEntity?>(() async {
      return await (database.select(
        database.shops,
      )..where((t) => t.id.equals(ownerId))).getSingleOrNull();
    }, 'getShopProfile');
  }

  /// Watch shop profile
  Stream<ShopEntity?> watchShopProfile(String ownerId) {
    return (database.select(
      database.shops,
    )..where((t) => t.id.equals(ownerId))).watchSingleOrNull();
  }

  /// Create or Update shop profile
  Future<RepositoryResult<ShopEntity>> updateShopProfile({
    required String ownerId,
    String? shopName,
    String? ownerName,
    String? address,
    String? phone,
    String? email,
    String? gstin,
    String? invoiceTerms,
    bool? showTaxOnInvoice,
    bool? isGstRegistered,
    int? invoiceLanguage,
    String? logoPath,
    String? signaturePath,
  }) async {
    return await errorHandler.runSafe<ShopEntity>(() async {
      final now = DateTime.now();

      final companion = ShopsCompanion(
        id: Value(ownerId),
        shopName: shopName != null ? Value(shopName) : const Value.absent(),
        ownerName: ownerName != null ? Value(ownerName) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        email: email != null ? Value(email) : const Value.absent(),
        gstin: gstin != null ? Value(gstin) : const Value.absent(),
        invoiceTerms: invoiceTerms != null
            ? Value(invoiceTerms)
            : const Value.absent(),
        showTaxOnInvoice: showTaxOnInvoice != null
            ? Value(showTaxOnInvoice)
            : const Value.absent(),
        isGstRegistered: isGstRegistered != null
            ? Value(isGstRegistered)
            : const Value.absent(),
        invoiceLanguage: invoiceLanguage != null
            ? Value(invoiceLanguage)
            : const Value.absent(),
        logoPath: logoPath != null ? Value(logoPath) : const Value.absent(),
        signaturePath: signaturePath != null
            ? Value(signaturePath)
            : const Value.absent(),
        isSynced: const Value(false),
        updatedAt: Value(now),
        createdAt: Value(
          now,
        ), // Drift will ignore on update if structured correctly
      );

      await database.into(database.shops).insertOnConflictUpdate(companion);

      final updatedProfile = await (database.select(
        database.shops,
      )..where((t) => t.id.equals(ownerId))).getSingle();

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: ownerId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: ownerId,
          payload: _entityToMap(updatedProfile),
        ),
      );

      return updatedProfile;
    }, 'updateShopProfile');
  }

  /// Complete onboarding for owner
  Future<RepositoryResult<void>> completeOnboarding(String ownerId) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(
        database.shops,
      )..where((t) => t.id.equals(ownerId))).write(
        ShopsCompanion(
          onboardingCompleted: const Value(true),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: ownerId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: ownerId,
          payload: {
            'onboardingCompleted': true,
            'onboardingCompletedAt': now.toIso8601String(),
          },
        ),
      );
    }, 'completeOnboarding');
  }

  /// Check if business type is locked (i.e. has existing data)
  Future<RepositoryResult<bool>> isBusinessLocked(String ownerId) async {
    return await errorHandler.runSafe<bool>(() async {
      // Check Bills
      final bill =
          await (database.select(database.bills)
                ..where((t) => t.userId.equals(ownerId) & t.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (bill != null) return true;

      // Check Expenses
      final expense =
          await (database.select(database.expenses)
                ..where((t) => t.userId.equals(ownerId) & t.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (expense != null) return true;

      // Check Purchase Orders
      final po =
          await (database.select(database.purchaseOrders)
                ..where((t) => t.userId.equals(ownerId) & t.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (po != null) return true;

      // Check Payments (Money In/Out) - Consistency with OnboardingRepository
      final payment =
          await (database.select(database.payments)
                ..where((t) => t.userId.equals(ownerId) & t.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (payment != null) return true;

      return false;
    }, 'isBusinessLocked');
  }

  /// Save business type
  Future<RepositoryResult<void>> saveBusinessType(
    String ownerId,
    String type,
  ) async {
    return await errorHandler.runSafe<void>(() async {
      // SECURITY: Enforce Business Type Lockdown
      final currentShop = await (database.select(
        database.shops,
      )..where((t) => t.id.equals(ownerId))).getSingleOrNull();

      if (currentShop != null &&
          currentShop.businessType != null &&
          currentShop.businessType!.isNotEmpty &&
          currentShop.businessType != 'other' &&
          currentShop.businessType != type) {
        // Check if locked
        final isLockedResult = await isBusinessLocked(ownerId);
        if (isLockedResult.data == true) {
          throw Exception(
            'Business Type is LOCKED. You have existing transactions (Bills, Expenses, or POs). '
            'You cannot change Business Type once you start operations. '
            'Please contact support for a Hard Reset if this is a mistake.',
          );
        }
      }

      final now = DateTime.now();
      await (database.update(
        database.shops,
      )..where((t) => t.id.equals(ownerId))).write(
        ShopsCompanion(
          businessType: Value(type),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: ownerId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: ownerId,
          payload: {
            'businessType': type,
            'billTemplate': type, // Legacy support
            'updatedAt': now.toIso8601String(),
          },
        ),
      );
    }, 'saveBusinessType');
  }

  /// Save app language
  Future<RepositoryResult<void>> saveLanguage(
    String ownerId,
    String language,
    String code,
  ) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(
        database.shops,
      )..where((t) => t.id.equals(ownerId))).write(
        ShopsCompanion(
          appLanguage: Value(language),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: ownerId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: ownerId,
          payload: {
            'appLanguage': language,
            'invoiceLanguage': code,
            'updatedAt': now.toIso8601String(),
          },
        ),
      );
    }, 'saveLanguage');
  }

  Map<String, dynamic> _entityToMap(ShopEntity e) {
    return {
      'shopName': e.shopName,
      'ownerName': e.ownerName,
      'address': e.address,
      'phone': e.phone,
      'email': e.email,
      'gstin': e.gstin,
      'invoiceTerms': e.invoiceTerms,
      'showTaxOnInvoice': e.showTaxOnInvoice,
      'isGstRegistered': e.isGstRegistered,
      'invoiceLanguage': e.invoiceLanguage,
      'logoPath': e.logoPath,
      'signaturePath': e.signaturePath,
      'businessType': e.businessType,
      'appLanguage': e.appLanguage,
      'onboardingCompleted': e.onboardingCompleted,
      'updatedAt': e.updatedAt.toIso8601String(),
    };
  }
}
