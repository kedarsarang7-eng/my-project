/// IMEI Serial Repository
/// Handles CRUD operations for IMEI/Serial tracking
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/service/services/warranty_date_utils.dart';
import '../../models/imei_serial.dart';

/// Repository for IMEI/Serial CRUD operations
class IMEISerialRepository {
  final AppDatabase _db;

  IMEISerialRepository(this._db);

  /// Create a new IMEI/Serial record
  Future<String> createIMEISerial(IMEISerial imei) async {
    final id = imei.id.isEmpty ? const Uuid().v4() : imei.id;
    final now = DateTime.now();

    await _db
        .into(_db.iMEISerials)
        .insert(
          IMEISerialsCompanion.insert(
            id: id,
            userId: imei.userId,
            productId: imei.productId,
            imeiOrSerial: imei.imeiOrSerial,
            type: Value(imei.type.value),
            status: Value(imei.status.value),
            purchaseOrderId: Value(imei.purchaseOrderId),
            purchasePrice: Value(imei.purchasePrice),
            purchaseDate: Value(imei.purchaseDate),
            supplierName: Value(imei.supplierName),
            billId: Value(imei.billId),
            customerId: Value(imei.customerId),
            soldPrice: Value(imei.soldPrice),
            soldDate: Value(imei.soldDate),
            warrantyMonths: Value(imei.warrantyMonths),
            warrantyStartDate: Value(imei.warrantyStartDate),
            warrantyEndDate: Value(imei.warrantyEndDate),
            isUnderWarranty: Value(imei.isUnderWarranty),
            productName: Value(imei.productName),
            brand: Value(imei.brand),
            model: Value(imei.model),
            color: Value(imei.color),
            storage: Value(imei.storage),
            ram: Value(imei.ram),
            notes: Value(imei.notes),
            isSynced: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );

    return id;
  }

  /// Check if IMEI/Serial already exists
  Future<bool> exists(String userId, String imeiOrSerial) async {
    final count =
        await (_db.selectOnly(_db.iMEISerials)
              ..addColumns([_db.iMEISerials.id.count()])
              ..where(
                _db.iMEISerials.userId.equals(userId) &
                    _db.iMEISerials.imeiOrSerial.equals(imeiOrSerial) &
                    _db.iMEISerials.deletedAt.isNull(),
              ))
            .map((row) => row.read(_db.iMEISerials.id.count()) ?? 0)
            .getSingle();

    return count > 0;
  }

  /// Check if IMEI/Serial is available for sale.
  /// Returns true only for units with status [IMEISerialStatus.inStock].
  /// Demo units return false (excluded from sellable stock).
  Future<bool> isAvailableForSale(String userId, String imeiOrSerial) async {
    final entity =
        await (_db.select(_db.iMEISerials)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.imeiOrSerial.equals(imeiOrSerial) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (entity == null) return false;
    return entity.status == IMEISerialStatus.inStock.value;
  }

  /// Get IMEI/Serial by ID (tenant-scoped)
  Future<IMEISerial?> getById(String id, {required String userId}) async {
    final entity =
        await (_db.select(_db.iMEISerials)
              ..where((t) => t.id.equals(id) & t.userId.equals(userId)))
            .getSingleOrNull();

    if (entity == null) return null;
    return _entityToModel(entity);
  }

  /// Get IMEI/Serial by number
  Future<IMEISerial?> getByNumber(String userId, String imeiOrSerial) async {
    final entity =
        await (_db.select(_db.iMEISerials)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.imeiOrSerial.equals(imeiOrSerial) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (entity == null) return null;
    return _entityToModel(entity);
  }

  /// Get all IMEI/Serials for a user (IMEI tracking / serial history).
  /// Returns ALL statuses including demo — demo units remain visible here
  /// even though they are excluded from sellable stock methods.
  Future<List<IMEISerial>> getAll(String userId) async {
    final entities =
        await (_db.select(_db.iMEISerials)
              ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get in-stock IMEI/Serials (sellable stock only).
  /// Demo units are excluded — only items with status [IMEISerialStatus.inStock]
  /// are returned. Demo units remain visible via [getAll] for IMEI tracking.
  Future<List<IMEISerial>> getInStock(String userId) async {
    final entities =
        await (_db.select(_db.iMEISerials)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.deletedAt.isNull() &
                    t.status.equals(IMEISerialStatus.inStock.value),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get IMEI/Serials for a product
  Future<List<IMEISerial>> getByProduct(String userId, String productId) async {
    final entities =
        await (_db.select(_db.iMEISerials)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.productId.equals(productId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get IMEI/Serials for a customer (purchase history)
  Future<List<IMEISerial>> getByCustomer(
    String userId,
    String customerId,
  ) async {
    final entities =
        await (_db.select(_db.iMEISerials)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.customerId.equals(customerId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.soldDate)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get devices under warranty
  Future<List<IMEISerial>> getUnderWarranty(String userId) async {
    final now = DateTime.now();
    final entities =
        await (_db.select(_db.iMEISerials)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.deletedAt.isNull() &
                    t.warrantyEndDate.isBiggerThanValue(now),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.warrantyEndDate)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Mark as sold (tenant-scoped)
  Future<void> markAsSold({
    required String id,
    required String userId,
    required String billId,
    required String customerId,
    required double soldPrice,
    int warrantyMonths = 0,
  }) async {
    final now = DateTime.now();
    final warrantyEnd = warrantyMonths > 0
        ? warrantyEndDate(now, warrantyMonths)
        : null;

    await (_db.update(
      _db.iMEISerials,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      IMEISerialsCompanion(
        status: Value(IMEISerialStatus.sold.value),
        billId: Value(billId),
        customerId: Value(customerId),
        soldPrice: Value(soldPrice),
        soldDate: Value(now),
        warrantyMonths: Value(warrantyMonths),
        warrantyStartDate: Value(now),
        warrantyEndDate: Value(warrantyEnd),
        isUnderWarranty: Value(warrantyMonths > 0),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );
  }

  /// Mark as returned (tenant-scoped)
  Future<void> markAsReturned(String id, {required String userId}) async {
    await (_db.update(
      _db.iMEISerials,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      IMEISerialsCompanion(
        status: Value(IMEISerialStatus.returned.value),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Mark as in service (tenant-scoped)
  Future<void> markAsInService(String id, {required String userId}) async {
    await (_db.update(
      _db.iMEISerials,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      IMEISerialsCompanion(
        status: Value(IMEISerialStatus.inService.value),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Return to stock (tenant-scoped)
  Future<void> returnToStock(String id, {required String userId}) async {
    await (_db.update(
      _db.iMEISerials,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      IMEISerialsCompanion(
        status: Value(IMEISerialStatus.inStock.value),
        billId: const Value(null),
        customerId: const Value(null),
        soldPrice: const Value(0),
        soldDate: const Value(null),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Mark as demo unit (tenant-scoped).
  /// Demo units are excluded from sellable stock counts (getInStock,
  /// getInStockCount, isAvailableForSale) but remain visible in IMEI
  /// tracking (getAll). Transitioning back to inStock via [returnToStock]
  /// re-includes the unit in sellable counts.
  Future<void> markAsDemo(String id, {required String userId}) async {
    await (_db.update(
      _db.iMEISerials,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      IMEISerialsCompanion(
        status: Value(IMEISerialStatus.demo.value),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Validate warranty
  Future<bool> isUnderWarranty(String imeiOrSerial, String userId) async {
    final entity = await getByNumber(userId, imeiOrSerial);
    if (entity == null) return false;
    return entity.isWarrantyActive;
  }

  /// Get stock count for product (IMEI-tracked, sellable only).
  /// Demo units are excluded — only items with status [IMEISerialStatus.inStock]
  /// are counted. When a unit transitions from demo to inStock, it is
  /// automatically re-included in this count.
  Future<int> getInStockCount(String userId, String productId) async {
    final count =
        await (_db.selectOnly(_db.iMEISerials)
              ..addColumns([_db.iMEISerials.id.count()])
              ..where(
                _db.iMEISerials.userId.equals(userId) &
                    _db.iMEISerials.productId.equals(productId) &
                    _db.iMEISerials.status.equals(
                      IMEISerialStatus.inStock.value,
                    ) &
                    _db.iMEISerials.deletedAt.isNull(),
              ))
            .map((row) => row.read(_db.iMEISerials.id.count()) ?? 0)
            .getSingle();

    return count;
  }

  /// Soft delete (tenant-scoped)
  Future<void> softDelete(String id, {required String userId}) async {
    await (_db.update(
      _db.iMEISerials,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      IMEISerialsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Convert entity to model
  IMEISerial _entityToModel(IMEISerialEntity entity) {
    return IMEISerial(
      id: entity.id,
      userId: entity.userId,
      productId: entity.productId,
      imeiOrSerial: entity.imeiOrSerial,
      type: IMEISerialTypeExtension.fromString(entity.type),
      status: IMEISerialStatusExtension.fromString(entity.status),
      purchaseOrderId: entity.purchaseOrderId,
      purchasePrice: entity.purchasePrice,
      purchaseDate: entity.purchaseDate,
      supplierName: entity.supplierName,
      billId: entity.billId,
      customerId: entity.customerId,
      soldPrice: entity.soldPrice,
      soldDate: entity.soldDate,
      warrantyMonths: entity.warrantyMonths,
      warrantyStartDate: entity.warrantyStartDate,
      warrantyEndDate: entity.warrantyEndDate,
      isUnderWarranty: entity.isUnderWarranty,
      productName: entity.productName,
      brand: entity.brand,
      model: entity.model,
      color: entity.color,
      storage: entity.storage,
      ram: entity.ram,
      notes: entity.notes,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
