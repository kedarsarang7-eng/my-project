// ============================================================================
// STOCK RESERVATION SERVICE
// ============================================================================
// Prevents race conditions during concurrent billing by reserving stock
// before final bill creation.
//
// Pattern:
//   1. Reserve stock when bill is being created (creates reservation record)
//   2. Deduct from reservation during bill finalization
//   3. Release reservation if bill is cancelled/abandoned
//   4. Auto-expire reservations after timeout (e.g., 5 minutes)
//
// This ensures that two cashiers cannot sell the same last item.
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/logger_service.dart';

/// Represents a stock reservation for items in a pending bill
class StockReservation {
  final String id;
  final String userId;
  final String billDraftId; // Temporary bill ID before finalization
  final String productId;
  final String? batchId;
  final double quantity;
  final DateTime reservedAt;
  final DateTime expiresAt;
  final String status; // 'active', 'consumed', 'released', 'expired'

  StockReservation({
    required this.id,
    required this.userId,
    required this.billDraftId,
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.reservedAt,
    required this.expiresAt,
    this.status = 'active',
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => status == 'active' && !isExpired;
}

/// Result of attempting to reserve stock
class ReservationResult {
  final bool success;
  final String? reservationId;
  final String? errorCode;
  final String? errorMessage;
  final double? availableStock;
  final double? requestedQuantity;

  ReservationResult({
    required this.success,
    this.reservationId,
    this.errorCode,
    this.errorMessage,
    this.availableStock,
    this.requestedQuantity,
  });

  factory ReservationResult.success(String reservationId) =>
      ReservationResult(success: true, reservationId: reservationId);

  factory ReservationResult.insufficientStock(
    double available,
    double requested,
  ) => ReservationResult(
        success: false,
        errorCode: 'INSUFFICIENT_STOCK',
        errorMessage: 'Insufficient stock. Available: $available, Requested: $requested',
        availableStock: available,
        requestedQuantity: requested,
      );

  factory ReservationResult.alreadyReserved(String productId) =>
      ReservationResult(
        success: false,
        errorCode: 'ALREADY_RESERVED',
        errorMessage: 'Stock for product $productId is already reserved by another transaction',
      );
}

/// Service to manage stock reservations and prevent race conditions
class StockReservationService {
  final AppDatabase _db;
  static const Duration _defaultReservationTimeout = Duration(minutes: 5);
  static const Duration _cleanupInterval = Duration(minutes: 1);
  
  Timer? _cleanupTimer;

  StockReservationService(this._db) {
    _startCleanupTimer();
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }

  /// Start background timer to clean up expired reservations
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      cleanupExpiredReservations();
    });
  }

  /// Reserve stock for a bill draft
  /// 
  /// This should be called BEFORE creating the final bill to ensure
  /// stock is available and locked for this transaction.
  Future<ReservationResult> reserveStock({
    required String userId,
    required String billDraftId,
    required String productId,
    required double quantity,
    String? batchId,
    Duration? timeout,
  }) async {
    if (quantity <= 0) {
      return ReservationResult(
        success: false,
        errorCode: 'INVALID_QUANTITY',
        errorMessage: 'Quantity must be positive',
      );
    }

    final reservationId = const Uuid().v4();
    final now = DateTime.now();
    final expiresAt = now.add(timeout ?? _defaultReservationTimeout);

    return await _db.transaction(() async {
      // Step 1: Get current available stock (excluding reservations)
      final product = await (_db.select(_db.products)
            ..where((t) => t.id.equals(productId) & t.userId.equals(userId)))
          .getSingleOrNull();

      if (product == null) {
        return ReservationResult(
          success: false,
          errorCode: 'PRODUCT_NOT_FOUND',
          errorMessage: 'Product not found: $productId',
        );
      }

      // Check if service item (no stock tracking)
      final category = product.category?.toLowerCase() ?? '';
      final isService = category.startsWith('service') ||
          category == 'consultation' ||
          category == 'lab test' ||
          category == 'opd';

      if (isService) {
        // Service items don't need stock reservation
        return ReservationResult.success('SERVICE_ITEM');
      }

      // Step 2: Calculate total reserved quantity for this product
      final totalReserved = await _getTotalReservedQuantity(userId, productId);
      final availableStock = product.stockQuantity - totalReserved;

      // Step 3: Check if enough stock is available
      if (availableStock < quantity) {
        return ReservationResult.insufficientStock(availableStock, quantity);
      }

      // Step 4: Create reservation record
      final reservation = StockReservationsCompanion.insert(
        id: reservationId,
        userId: userId,
        billDraftId: billDraftId,
        productId: productId,
        batchId: Value(batchId),
        quantity: quantity,
        reservedAt: now,
        expiresAt: expiresAt,
        updatedAt: now,
        status: const Value('active'),
        isSynced: const Value(false),
      );

      await _db.into(_db.stockReservations).insert(reservation);

      LoggerService.d('StockReservation', 
        'StockReservation: Reserved $quantity of ${product.name} '
        '(Available: $availableStock, Reserved: $totalReserved, After: ${availableStock - quantity})',
      );

      return ReservationResult.success(reservationId);
    });
  }

  /// Reserve stock for multiple items at once
  /// 
  /// This is atomic - either all items are reserved or none are.
  Future<List<ReservationResult>> reserveStockBatch({
    required String userId,
    required String billDraftId,
    required List<ReservationRequest> items,
    Duration? timeout,
  }) async {
    final results = <ReservationResult>[];
    final reservedIds = <String>[];

    // Try to reserve each item
    for (final item in items) {
      final result = await reserveStock(
        userId: userId,
        billDraftId: billDraftId,
        productId: item.productId,
        quantity: item.quantity,
        batchId: item.batchId,
        timeout: timeout,
      );

      results.add(result);

      if (result.success && result.reservationId != null && 
          result.reservationId != 'SERVICE_ITEM') {
        reservedIds.add(result.reservationId!);
      }

      // If any reservation fails, rollback previous reservations
      if (!result.success) {
        // Rollback already reserved items
        for (final id in reservedIds) {
          await releaseReservation(id);
        }
        
        // Mark remaining items as failed due to rollback
        final failedIndex = results.length - 1;
        for (var i = failedIndex + 1; i < items.length; i++) {
          results.add(ReservationResult(
            success: false,
            errorCode: 'ROLLBACK',
            errorMessage: 'Reservation cancelled due to failure of item ${failedIndex + 1}',
          ));
        }
        
        return results;
      }
    }

    return results;
  }

  /// Consume a reservation when bill is finalized
  /// 
  /// This deducts the reserved quantity from actual stock and marks
  /// the reservation as consumed.
  Future<bool> consumeReservation(
    String reservationId, {
    required String referenceBillId,
  }) async {
    return await _db.transaction(() async {
      final reservation = await (_db.select(_db.stockReservations)
            ..where((t) => t.id.equals(reservationId)))
          .getSingleOrNull();

      if (reservation == null) {
        LoggerService.d('StockReservation', 'StockReservation: Cannot consume - reservation not found: $reservationId');
        return false;
      }

      if (reservation.status != 'active') {
        LoggerService.d('StockReservation', 'StockReservation: Cannot consume - reservation status is ${reservation.status}');
        return false;
      }

      if (DateTime.now().isAfter(reservation.expiresAt)) {
        await (_db.update(_db.stockReservations)
              ..where((t) => t.id.equals(reservationId)))
            .write(StockReservationsCompanion(
              status: const Value('expired'),
              updatedAt: Value(DateTime.now()),
            ));
        return false;
      }

      // Mark reservation as consumed
      await (_db.update(_db.stockReservations)
            ..where((t) => t.id.equals(reservationId)))
          .write(
            StockReservationsCompanion(
              status: const Value('consumed'),
              referenceBillId: Value(referenceBillId),
              updatedAt: Value(DateTime.now()),
              isSynced: const Value(false),
            ),
          );

      LoggerService.d('StockReservation', 
        'StockReservation: Consumed reservation $reservationId for bill $referenceBillId',
      );

      return true;
    });
  }

  /// Release a reservation without consuming it
  /// 
  /// Call this when a bill is abandoned, cancelled, or stock needs to be freed.
  Future<bool> releaseReservation(String reservationId) async {
    return await _db.transaction(() async {
      final reservation = await (_db.select(_db.stockReservations)
            ..where((t) => t.id.equals(reservationId)))
          .getSingleOrNull();

      if (reservation == null) {
        return false;
      }

      if (reservation.status != 'active') {
        return false; // Already consumed or released
      }

      await (_db.update(_db.stockReservations)
            ..where((t) => t.id.equals(reservationId)))
          .write(
            StockReservationsCompanion(
              status: const Value('released'),
              updatedAt: Value(DateTime.now()),
              isSynced: const Value(false),
            ),
          );

      LoggerService.d('StockReservation', 'StockReservation: Released reservation $reservationId');

      return true;
    });
  }

  /// Release all reservations for a bill draft
  Future<int> releaseReservationsForBill(String billDraftId) async {
    final reservations = await (_db.select(_db.stockReservations)
          ..where((t) => t.billDraftId.equals(billDraftId) & t.status.equals('active')))
        .get();

    for (final reservation in reservations) {
      await releaseReservation(reservation.id);
    }

    return reservations.length;
  }

  /// Get total reserved quantity for a product (across all active reservations)
  Future<double> _getTotalReservedQuantity(String userId, String productId) async {
    final now = DateTime.now();
    
    final query = await _db.customSelect(
      '''
      SELECT COALESCE(SUM(quantity), 0) as total_reserved
      FROM stock_reservations
      WHERE user_id = ? AND product_id = ? AND status = 'active' AND expires_at > ?
      ''',
      variables: [
        Variable.withString(userId),
        Variable.withString(productId),
        Variable.withString(now.toIso8601String()),
      ],
    ).getSingleOrNull();

    return query?.data['total_reserved'] as double? ?? 0.0;
  }

  /// Get available stock after reservations
  Future<double> getAvailableStock(String userId, String productId) async {
    final product = await (_db.select(_db.products)
          ..where((t) => t.id.equals(productId) & t.userId.equals(userId)))
        .getSingleOrNull();

    if (product == null) return 0.0;

    final totalReserved = await _getTotalReservedQuantity(userId, productId);
    return product.stockQuantity - totalReserved;
  }

  /// Clean up expired reservations
  Future<int> cleanupExpiredReservations() async {
    final now = DateTime.now();
    
    final expired = await (_db.select(_db.stockReservations)
          ..where((t) => t.status.equals('active') & t.expiresAt.isSmallerThanValue(now)))
        .get();

    for (final reservation in expired) {
      await (_db.update(_db.stockReservations)
            ..where((t) => t.id.equals(reservation.id)))
          .write(
            StockReservationsCompanion(
              status: const Value('expired'),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );
    }

    if (expired.isNotEmpty) {
      LoggerService.d('StockReservation', 'StockReservation: Cleaned up ${expired.length} expired reservations');
    }

    return expired.length;
  }

  /// Get active reservations for a bill draft
  Future<List<StockReservation>> getReservationsForBill(String billDraftId) async {
    final rows = await (_db.select(_db.stockReservations)
          ..where((t) => t.billDraftId.equals(billDraftId) & t.status.equals('active')))
        .get();

    return rows.map((r) => StockReservation(
      id: r.id,
      userId: r.userId,
      billDraftId: r.billDraftId,
      productId: r.productId,
      batchId: r.batchId,
      quantity: r.quantity,
      reservedAt: r.reservedAt,
      expiresAt: r.expiresAt,
      status: r.status,
    )).toList();
  }

  /// Extend reservation timeout
  Future<bool> extendReservation(
    String reservationId, {
    required Duration extension,
  }) async {
    final reservation = await (_db.select(_db.stockReservations)
          ..where((t) => t.id.equals(reservationId) & t.status.equals('active')))
        .getSingleOrNull();

    if (reservation == null || DateTime.now().isAfter(reservation.expiresAt)) {
      return false;
    }

    final newExpiry = reservation.expiresAt.add(extension);
    
    await (_db.update(_db.stockReservations)
          ..where((t) => t.id.equals(reservationId)))
        .write(
          StockReservationsCompanion(
            expiresAt: Value(newExpiry),
            updatedAt: Value(DateTime.now()),
          ),
        );

    return true;
  }
}

/// Request object for batch reservation
class ReservationRequest {
  final String productId;
  final double quantity;
  final String? batchId;

  ReservationRequest({
    required this.productId,
    required this.quantity,
    this.batchId,
  });
}
