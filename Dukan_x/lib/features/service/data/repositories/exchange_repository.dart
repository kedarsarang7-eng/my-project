/// Exchange Repository
/// CRUD operations for device exchange transactions
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../models/exchange.dart';

/// Repository for Exchange CRUD operations
class ExchangeRepository {
  final AppDatabase _db;

  ExchangeRepository(this._db);

  /// Generate exchange number (EXC-YYMM-0001)
  Future<String> generateExchangeNumber(String userId) async {
    final now = DateTime.now();
    final prefix =
        'EXC-${now.year % 100}${now.month.toString().padLeft(2, '0')}';

    // Count existing exchanges for this month
    final count =
        await ((_db.select(_db.exchanges)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.exchangeNumber.like('$prefix%'))))
            .get();

    final sequence = (count.length + 1).toString().padLeft(4, '0');
    return '$prefix-$sequence';
  }

  /// Create a new exchange
  Future<Exchange> createExchange(Exchange exchange) async {
    final id = exchange.id.isEmpty ? const Uuid().v4() : exchange.id;
    final exchangeNumber =
        exchange.exchangeNumber ??
        await generateExchangeNumber(exchange.userId);
    final now = DateTime.now();

    await _db
        .into(_db.exchanges)
        .insert(
          ExchangesCompanion.insert(
            id: id,
            userId: exchange.userId,
            exchangeNumber: exchangeNumber,
            customerId: Value(exchange.customerId),
            customerName: exchange.customerName,
            customerPhone: exchange.customerPhone,
            oldDeviceType: exchange.oldDeviceName,
            oldBrand: exchange.oldDeviceBrand ?? '',
            oldModel: exchange.oldDeviceModel ?? '',
            oldImeiSerial: Value(exchange.oldImeiSerial),
            oldCondition: exchange.oldDeviceCondition ?? 'GOOD',
            oldConditionNotes: Value(exchange.oldDeviceNotes),
            oldDeviceValue: exchange.exchangeValue,
            newProductId: Value(exchange.newProductId),
            newImeiSerialId: Value(exchange.newImeiSerialId),
            newProductName: exchange.newProductName,
            newImeiSerial: Value(exchange.newImeiSerial),
            newDevicePrice: exchange.newDevicePrice,
            exchangeValue: exchange.exchangeValue,
            priceDifference: exchange.priceDifference,
            additionalDiscount: Value(exchange.additionalDiscount),
            amountToPay: exchange.amountToPay,
            paymentStatus: Value(exchange.paymentStatus.value),
            amountPaid: Value(exchange.amountPaid),
            paymentMode: Value(exchange.paymentMode),
            billId: Value(exchange.billId),
            status: Value(exchange.status.value),
            exchangeDate: exchange.exchangeDate,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return exchange.copyWith(
      id: id,
      exchangeNumber: exchangeNumber,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update an existing exchange (tenant-scoped)
  Future<Exchange> updateExchange(Exchange exchange) async {
    final now = DateTime.now();

    await (_db.update(_db.exchanges)..where(
          (t) => t.id.equals(exchange.id) & t.userId.equals(exchange.userId),
        ))
        .write(
          ExchangesCompanion(
            customerId: Value(exchange.customerId),
            customerName: Value(exchange.customerName),
            customerPhone: Value(exchange.customerPhone),
            oldDeviceType: Value(exchange.oldDeviceName),
            oldBrand: Value(exchange.oldDeviceBrand ?? ''),
            oldModel: Value(exchange.oldDeviceModel ?? ''),
            oldImeiSerial: Value(exchange.oldImeiSerial),
            oldCondition: Value(exchange.oldDeviceCondition ?? 'GOOD'),
            oldConditionNotes: Value(exchange.oldDeviceNotes),
            oldDeviceValue: Value(exchange.exchangeValue),
            newProductId: Value(exchange.newProductId),
            newImeiSerialId: Value(exchange.newImeiSerialId),
            newProductName: Value(exchange.newProductName),
            newImeiSerial: Value(exchange.newImeiSerial),
            newDevicePrice: Value(exchange.newDevicePrice),
            exchangeValue: Value(exchange.exchangeValue),
            priceDifference: Value(exchange.priceDifference),
            additionalDiscount: Value(exchange.additionalDiscount),
            amountToPay: Value(exchange.amountToPay),
            paymentStatus: Value(exchange.paymentStatus.value),
            amountPaid: Value(exchange.amountPaid),
            paymentMode: Value(exchange.paymentMode),
            billId: Value(exchange.billId),
            status: Value(exchange.status.value),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    return exchange.copyWith(updatedAt: now);
  }

  /// Get exchange by ID (tenant-scoped)
  Future<Exchange?> getById(String id, {required String userId}) async {
    final entity =
        await (_db.select(_db.exchanges)
              ..where((t) => t.id.equals(id) & t.userId.equals(userId)))
            .getSingleOrNull();

    if (entity == null) return null;
    return _entityToModel(entity);
  }

  /// Get exchange by number
  Future<Exchange?> getByNumber(String userId, String exchangeNumber) async {
    final entity =
        await (_db.select(_db.exchanges)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.exchangeNumber.equals(exchangeNumber)))
            .getSingleOrNull();

    if (entity == null) return null;
    return _entityToModel(entity);
  }

  /// Get all exchanges for user
  Future<List<Exchange>> getAll(String userId) async {
    final entities =
        await (_db.select(_db.exchanges)
              ..where((t) => t.userId.equals(userId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get exchanges by status
  Future<List<Exchange>> getByStatus(
    String userId,
    ExchangeStatus status,
  ) async {
    final entities =
        await (_db.select(_db.exchanges)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.status.equals(status.value))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get draft/pending exchanges
  Future<List<Exchange>> getDrafts(String userId) async {
    return getByStatus(userId, ExchangeStatus.draft);
  }

  /// Get completed exchanges
  Future<List<Exchange>> getCompleted(String userId) async {
    return getByStatus(userId, ExchangeStatus.completed);
  }

  /// Watch all exchanges
  Stream<List<Exchange>> watchAll(String userId) {
    return (_db.select(_db.exchanges)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((entities) => entities.map(_entityToModel).toList());
  }

  /// Complete an exchange (tenant-scoped)
  Future<void> completeExchange(
    String id,
    String? billId, {
    required String userId,
  }) async {
    final now = DateTime.now();
    await (_db.update(
      _db.exchanges,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ExchangesCompanion(
        status: const Value('COMPLETED'),
        billId: Value(billId),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );
  }

  /// Cancel an exchange (tenant-scoped)
  Future<void> cancelExchange(String id, {required String userId}) async {
    final now = DateTime.now();
    await (_db.update(
      _db.exchanges,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ExchangesCompanion(
        status: const Value('CANCELLED'),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );
  }

  /// Record payment for an exchange (tenant-scoped)
  Future<void> recordPayment(
    String id,
    double amount,
    String paymentMode, {
    required String userId,
  }) async {
    final entity =
        await (_db.select(_db.exchanges)
              ..where((t) => t.id.equals(id) & t.userId.equals(userId)))
            .getSingleOrNull();

    if (entity == null) return;

    final newAmountPaid = entity.amountPaid + amount;
    final isPaid = newAmountPaid >= entity.amountToPay;
    final paymentStatus = isPaid
        ? 'PAID'
        : (newAmountPaid > 0 ? 'PARTIAL' : 'PENDING');

    await (_db.update(
      _db.exchanges,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ExchangesCompanion(
        amountPaid: Value(newAmountPaid),
        paymentMode: Value(paymentMode),
        paymentStatus: Value(paymentStatus),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Convert entity to model
  Exchange _entityToModel(ExchangeEntity e) {
    return Exchange(
      id: e.id,
      userId: e.userId,
      exchangeNumber: e.exchangeNumber,
      customerId: e.customerId,
      customerName: e.customerName,
      customerPhone: e.customerPhone,
      oldDeviceName: e.oldDeviceType,
      oldDeviceBrand: e.oldBrand,
      oldDeviceModel: e.oldModel,
      oldImeiSerial: e.oldImeiSerial,
      oldDeviceCondition: e.oldCondition,
      oldDeviceNotes: e.oldConditionNotes,
      estimatedValue: e.oldDeviceValue,
      finalExchangeValue: e.exchangeValue,
      newProductId: e.newProductId,
      newImeiSerialId: e.newImeiSerialId,
      newProductName: e.newProductName,
      newImeiSerial: e.newImeiSerial,
      newDevicePrice: e.newDevicePrice,
      exchangeValue: e.exchangeValue,
      priceDifference: e.priceDifference,
      additionalDiscount: e.additionalDiscount,
      amountToPay: e.amountToPay,
      paymentStatus: ExchangePaymentStatusExtension.fromString(e.paymentStatus),
      amountPaid: e.amountPaid,
      paymentMode: e.paymentMode,
      billId: e.billId,
      status: ExchangeStatusExtension.fromString(e.status),
      exchangeDate: e.exchangeDate,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      isSynced: e.isSynced,
    );
  }
}
