/// Exchange Service
/// Business logic for device exchange/trade-in transactions
library;

import 'package:dukanx/core/database/app_database.dart';
import '../data/repositories/exchange_repository.dart';
import '../data/repositories/imei_serial_repository.dart';
import '../models/exchange.dart';
import '../models/imei_serial.dart';

/// Service for managing device exchanges
class ExchangeService {
  final ExchangeRepository _exchangeRepository;
  final IMEISerialRepository _imeiSerialRepository;

  ExchangeService(AppDatabase db)
    : _exchangeRepository = ExchangeRepository(db),
      _imeiSerialRepository = IMEISerialRepository(db);

  /// Create a new exchange
  Future<Exchange> createExchange({
    required String userId,
    required String customerName,
    required String customerPhone,
    String? customerId,
    required String oldDeviceName,
    String? oldDeviceBrand,
    String? oldDeviceModel,
    String? oldImeiSerial,
    String? oldDeviceCondition,
    String? oldDeviceNotes,
    required double oldDeviceValue,
    required String newProductName,
    String? newProductId,
    String? newImeiSerial,
    required double newDevicePrice,
    double additionalDiscount = 0,
  }) async {
    // Calculate values
    final calculation = Exchange.calculateExchange(
      newDevicePrice: newDevicePrice,
      oldDeviceValue: oldDeviceValue,
      additionalDiscount: additionalDiscount,
    );

    final now = DateTime.now();

    final exchange = Exchange(
      id: '',
      userId: userId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      oldDeviceName: oldDeviceName,
      oldDeviceBrand: oldDeviceBrand,
      oldDeviceModel: oldDeviceModel,
      oldImeiSerial: oldImeiSerial,
      oldDeviceCondition: oldDeviceCondition ?? 'GOOD',
      oldDeviceNotes: oldDeviceNotes,
      estimatedValue: oldDeviceValue,
      finalExchangeValue: oldDeviceValue,
      newProductId: newProductId,
      newProductName: newProductName,
      newImeiSerial: newImeiSerial,
      newDevicePrice: newDevicePrice,
      exchangeValue: calculation['exchangeValue']!,
      priceDifference: calculation['priceDifference']!,
      additionalDiscount: additionalDiscount,
      amountToPay: calculation['amountToPay']!,
      exchangeDate: now,
      createdAt: now,
      updatedAt: now,
    );

    return await _exchangeRepository.createExchange(exchange);
  }

  /// Update exchange values
  Future<Exchange> updateExchangeValue({
    required String exchangeId,
    required String userId,
    required double newOldDeviceValue,
    double? additionalDiscount,
  }) async {
    final exchange = await _exchangeRepository.getById(
      exchangeId,
      userId: userId,
    );
    if (exchange == null) throw Exception('Exchange not found');

    final discount = additionalDiscount ?? exchange.additionalDiscount;
    final calculation = Exchange.calculateExchange(
      newDevicePrice: exchange.newDevicePrice,
      oldDeviceValue: newOldDeviceValue,
      additionalDiscount: discount,
    );

    return await _exchangeRepository.updateExchange(
      exchange.copyWith(
        exchangeValue: calculation['exchangeValue'],
        priceDifference: calculation['priceDifference'],
        amountToPay: calculation['amountToPay'],
        additionalDiscount: discount,
        finalExchangeValue: newOldDeviceValue,
      ),
    );
  }

  /// Complete an exchange and mark old device as acquired
  Future<void> completeExchange({
    required String exchangeId,
    String? billId,
    required String userId,
  }) async {
    final exchange = await _exchangeRepository.getById(
      exchangeId,
      userId: userId,
    );
    if (exchange == null) throw Exception('Exchange not found');

    // Mark exchange as completed
    await _exchangeRepository.completeExchange(
      exchangeId,
      billId,
      userId: userId,
    );

    // If old device has IMEI, mark it as acquired in inventory
    if (exchange.oldImeiSerial != null && exchange.oldImeiSerial!.isNotEmpty) {
      // Check if this IMEI exists
      final existingIMEI = await _imeiSerialRepository.getByNumber(
        userId,
        exchange.oldImeiSerial!,
      );

      if (existingIMEI == null) {
        // Create new IMEI record for acquired device
        final now = DateTime.now();
        await _imeiSerialRepository.createIMEISerial(
          IMEISerial(
            id: '',
            userId: userId,
            productId: '',
            imeiOrSerial: exchange.oldImeiSerial!,
            type: IMEISerialType.serial,
            status: IMEISerialStatus.inStock, // Now we own it
            purchasePrice: exchange.exchangeValue,
            purchaseDate: now,
            productName: exchange.oldDeviceName,
            brand: exchange.oldDeviceBrand,
            model: exchange.oldDeviceModel,
            notes: 'Acquired via exchange ${exchange.exchangeNumber}',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  }

  /// Cancel an exchange
  Future<void> cancelExchange(
    String exchangeId, {
    required String userId,
  }) async {
    await _exchangeRepository.cancelExchange(exchangeId, userId: userId);
  }

  /// Record payment for exchange
  Future<void> recordPayment({
    required String exchangeId,
    required String userId,
    required double amount,
    required String paymentMode,
  }) async {
    await _exchangeRepository.recordPayment(
      exchangeId,
      amount,
      paymentMode,
      userId: userId,
    );
  }

  /// Get exchange by ID
  Future<Exchange?> getExchangeById(String id, {required String userId}) async {
    return await _exchangeRepository.getById(id, userId: userId);
  }

  /// Get all exchanges for user
  Future<List<Exchange>> getExchanges(String userId) async {
    return await _exchangeRepository.getAll(userId);
  }

  /// Get draft exchanges
  Future<List<Exchange>> getDraftExchanges(String userId) async {
    return await _exchangeRepository.getDrafts(userId);
  }

  /// Get completed exchanges
  Future<List<Exchange>> getCompletedExchanges(String userId) async {
    return await _exchangeRepository.getCompleted(userId);
  }

  /// Watch all exchanges
  Stream<List<Exchange>> watchExchanges(String userId) {
    return _exchangeRepository.watchAll(userId);
  }

  /// Get exchange summary stats
  Future<Map<String, dynamic>> getExchangeStats(String userId) async {
    final all = await _exchangeRepository.getAll(userId);
    final completed = all.where((e) => e.isCompleted).toList();
    final drafts = all.where((e) => e.isDraft).toList();

    double totalExchangeValue = 0;
    double totalNewDeviceValue = 0;
    double totalDifference = 0;

    for (final e in completed) {
      totalExchangeValue += e.exchangeValue;
      totalNewDeviceValue += e.newDevicePrice;
      totalDifference += e.priceDifference;
    }

    return {
      'totalExchanges': all.length,
      'completedExchanges': completed.length,
      'draftExchanges': drafts.length,
      'totalExchangeValue': totalExchangeValue,
      'totalNewDeviceValue': totalNewDeviceValue,
      'totalDifference': totalDifference,
    };
  }
}
