// ============================================================================
// TRANSACTION MANAGER
// ============================================================================
// Provides atomic database transactions for complex operations.
// Prevents data inconsistency during multi-step operations.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../error/error_handler.dart';

/// Provides atomic transactions for complex database operations.
///
/// Usage:
/// ```dart
/// final result = await TransactionManager.execute(
///   database: sl<AppDatabase>(),
///   description: 'Create bill with inventory update',
///   operation: (db) async {
///     await db.insertBill(bill);
///     await db.updateStock(productId, -quantity);
///     await db.insertPayment(payment);
///     return billId;
///   },
/// );
///
/// result.when(
///   success: (id) => showSuccess('Bill created: $id'),
///   failure: (error) => showError(error.message),
/// );
/// ```
class TransactionManager {
  TransactionManager._();

  /// Execute a database operation within a transaction.
  /// If any part fails, all changes are rolled back.
  static Future<Result<T>> execute<T>({
    required AppDatabase database,
    required String description,
    required Future<T> Function(AppDatabase db) operation,
  }) async {
    try {
      final result = await database.transaction(() async {
        return operation(database);
      });
      return Result.success(result);
    } catch (e, stack) {
      final error = ErrorHandler.createAppError(
        e,
        stack,
        userMessage: 'Failed to complete: $description',
        category: ErrorCategory.database,
        severity: ErrorSeverity.high,
      );

      // Log for monitoring (fire-and-forget)
      unawaited(
        ErrorHandler.handle(
          e,
          stackTrace: stack,
          userMessage: description,
          showUI: false,
        ),
      );

      return Result.failure(error);
    }
  }

  /// Execute multiple independent transactions in batch.
  /// Each transaction is independent - failure of one doesn't affect others.
  /// Returns results for each transaction.
  static Future<List<Result<T>>> executeBatch<T>({
    required AppDatabase database,
    required List<Future<T> Function(AppDatabase db)> operations,
    required String description,
  }) async {
    final results = <Result<T>>[];

    for (final operation in operations) {
      final result = await execute(
        database: database,
        description: description,
        operation: operation,
      );
      results.add(result);
    }

    return results;
  }

  /// Execute a billing transaction (common pattern).
  /// Creates bill, updates inventory, and optionally creates payment.
  static Future<Result<String>> createBillTransaction({
    required AppDatabase database,
    required BillsCompanion bill,
    required List<InventoryUpdate> inventoryUpdates,
    PaymentsCompanion? payment,
  }) async {
    return execute(
      database: database,
      description: 'Create bill with inventory updates',
      operation: (db) async {
        // 1. Insert bill
        final billId = bill.id.value;
        await db.insertBill(bill);

        // 2. Update inventory for each item
        for (final update in inventoryUpdates) {
          await _updateStock(db, update);
        }

        // 3. Create payment if provided
        if (payment != null) {
          await db.insertPayment(payment);
        }

        return billId;
      },
    );
  }

  /// Internal stock update helper
  static Future<void> _updateStock(
    AppDatabase db,
    InventoryUpdate update,
  ) async {
    // Get current product
    final product = await db.getProductById(update.productId);
    if (product == null) {
      throw Exception('Product not found: ${update.productId}');
    }

    // Calculate new quantity
    final newQuantity = product.stockQuantity + update.quantityChange;
    if (newQuantity < 0) {
      throw Exception(
        'Insufficient stock for ${product.name}. Available: ${product.stockQuantity}',
      );
    }

    // Update using raw update
    await (db.update(
      db.products,
    )..where((p) => p.id.equals(update.productId))).write(
      ProductsCompanion(
        stockQuantity: Value(newQuantity),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

/// Represents an inventory update for a product
class InventoryUpdate {
  final String productId;
  final double quantityChange; // Negative for deductions

  const InventoryUpdate({
    required this.productId,
    required this.quantityChange,
  });
}
