import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../services/audit_service.dart';

/// Repository for handling Payment logic
class PaymentRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  final AuditService? auditService;

  PaymentRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
    this.auditService,
  });

  static const String collectionName = 'payments';

  /// Create a payment and queue it for sync
  Future<RepositoryResult<String>> createPayment({
    required String userId,
    required String billId,
    required String? customerId,
    required double amount,
    required String paymentMode, // CASH, UPI, etc.
    String? referenceNumber,
    String? notes,
    DateTime? date,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      final now = DateTime.now();
      final paymentDate = date ?? now;
      final paymentId = const Uuid().v4();

      await database.transaction(() async {
        // 1. Insert Payment Record
        await database
            .into(database.payments)
            .insert(
              PaymentsCompanion.insert(
                id: paymentId,
                userId: userId,
                billId: billId,
                customerId: Value(customerId),
                amount: amount,
                paymentMode: paymentMode,
                referenceNumber: Value(referenceNumber),
                notes: Value(notes),
                paymentDate: paymentDate,
                createdAt: now,
                isSynced: const Value(false),
                version: const Value(1),
              ),
            );

        // 2. Queue Sync Operation
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.create,
            targetCollection: collectionName,
            documentId: paymentId,
            payload: {
              'id': paymentId,
              'userId': userId,
              'billId': billId,
              'customerId': customerId,
              'amount': amount,
              'paymentMode': paymentMode,
              'referenceNumber': referenceNumber,
              'notes': notes,
              'paymentDate': paymentDate.toIso8601String(),
              'createdAt': now.toIso8601String(),
            },
          ),
        );
      });

      // 3. Audit Log (non-blocking)
      if (auditService != null) {
        auditService!.logPaymentCreation(
          userId: userId,
          billId: billId,
          amount: amount,
          paymentMode: paymentMode,
          paymentId: paymentId,
        );
      }

      return paymentId;
    }, 'createPayment');
  }

  /// Get payments for a specific bill
  Future<RepositoryResult<List<PaymentEntity>>> getPaymentsForBill(
    String billId,
  ) async {
    return await errorHandler.runSafe<List<PaymentEntity>>(() async {
      return await database.getPaymentsForBill(billId);
    }, 'getPaymentsForBill');
  }

  /// Get all payments for user with optional filters
  Future<RepositoryResult<List<PaymentEntity>>> getAllPayments({
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await errorHandler.runSafe<List<PaymentEntity>>(() async {
      return await database.getAllPayments(
        userId,
        fromDate: fromDate,
        toDate: toDate,
      );
    }, 'getAllPayments');
  }

  /// Watch all payments for real-time updates
  Stream<List<PaymentEntity>> watchAllPayments({required String userId}) {
    return (database.select(database.payments)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
        .watch();
  }
}
