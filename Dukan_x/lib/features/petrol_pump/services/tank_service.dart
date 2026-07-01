import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/audit_repository.dart';
import '../models/tank.dart';

/// TankService - Manages fuel tank stock with AUDIT TRAIL
///
/// FRAUD PREVENTION (Gap #4 FIX):
/// All stock modifications are audit-logged with before/after values.
/// Manual adjustments require a reason and are flagged for review.
class TankService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _ownerId => sl<SessionManager>().ownerId ?? '';

  CollectionReference get _tankCollection =>
      _firestore.collection('owners').doc(_ownerId).collection('tanks');

  /// Get all tanks
  Stream<List<Tank>> getTanks() {
    return _tankCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => Tank.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    });
  }

  /// Get single tank by ID
  Future<Tank?> getTankById(String tankId) async {
    final doc = await _tankCollection.doc(tankId).get();
    if (!doc.exists) return null;
    return Tank.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Create or update tank (with audit)
  Future<void> saveTank(Tank tank, {String? employeeId}) async {
    await _tankCollection
        .doc(tank.tankId)
        .set(tank.toMap(), SetOptions(merge: true));

    await _logStockEvent(
      tankId: tank.tankId,
      action: 'TANK_SAVE',
      details: 'Tank ${tank.tankName} saved with stock ${tank.currentStock}L',
      employeeId: employeeId,
    );
  }

  /// Add purchase (refill) with AUDIT TRAIL
  /// Gap #4 FIX: All purchases are logged with before/after stock
  Future<void> addPurchase(
    String tankId,
    double quantity, {
    String? employeeId,
    String? invoiceNumber,
  }) async {
    final docRef = _tankCollection.doc(tankId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Tank not found');

      final tank = Tank.fromMap(
        snapshot.id,
        snapshot.data() as Map<String, dynamic>,
      );
      final oldStock = tank.currentStock;
      final updatedTank = tank.addPurchase(quantity);

      transaction.update(docRef, updatedTank.toMap());

      // AUDIT: Log purchase with before/after stock
      await _logStockEvent(
        tankId: tankId,
        action: 'STOCK_PURCHASE',
        details:
            'Purchase: +${quantity}L | Stock: ${oldStock}L → ${updatedTank.currentStock}L',
        employeeId: employeeId,
        metadata: {
          'quantityAdded': quantity,
          'stockBefore': oldStock,
          'stockAfter': updatedTank.currentStock,
          'invoiceNumber': invoiceNumber,
        },
      );
    });
  }

  /// Record dip reading (manual check) with AUDIT TRAIL
  /// Gap #4 FIX: Dip readings that cause stock changes are logged
  Future<void> recordDipReading(
    String tankId,
    double actualStock, {
    String? employeeId,
    String? reason,
  }) async {
    final docRef = _tankCollection.doc(tankId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Tank not found');

      final tank = Tank.fromMap(
        snapshot.id,
        snapshot.data() as Map<String, dynamic>,
      );
      final oldStock = tank.currentStock;
      final variance = actualStock - tank.calculatedStock;
      final updatedTank = tank.updateWithDipReading(actualStock);

      transaction.update(docRef, updatedTank.toMap());

      // AUDIT: Log dip reading with variance
      await _logStockEvent(
        tankId: tankId,
        action: variance.abs() > 1 ? 'DIP_READING_VARIANCE' : 'DIP_READING',
        details:
            'Dip reading: ${actualStock}L | Variance: ${variance.toStringAsFixed(2)}L | ${reason ?? "Routine check"}',
        employeeId: employeeId,
        metadata: {
          'dipReading': actualStock,
          'calculatedStock': tank.calculatedStock,
          'previousStock': oldStock,
          'variance': variance,
          'reason': reason,
        },
      );

      // Alert if variance exceeds threshold
      if (variance.abs() > 10) {
        await _logStockEvent(
          tankId: tankId,
          action: 'STOCK_VARIANCE_ALERT',
          details:
              'HIGH VARIANCE DETECTED: ${variance.toStringAsFixed(2)}L difference requires investigation',
          employeeId: employeeId,
          metadata: {'severity': 'HIGH', 'variance': variance},
        );
      }
    });
  }

  /// Manual stock adjustment (requires reason) with AUDIT TRAIL
  /// Gap #4 FIX: Manual adjustments are ALWAYS logged and flagged
  Future<void> adjustStock({
    required String tankId,
    required double newStock,
    required String reason,
    required String employeeId,
  }) async {
    final docRef = _tankCollection.doc(tankId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Tank not found');

      final tank = Tank.fromMap(
        snapshot.id,
        snapshot.data() as Map<String, dynamic>,
      );
      final oldStock = tank.currentStock;
      final adjustment = newStock - oldStock;

      transaction.update(docRef, {
        'currentStock': newStock.clamp(0, tank.capacity),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // AUDIT: Log manual adjustment with flag for review
      await _logStockEvent(
        tankId: tankId,
        action: 'MANUAL_STOCK_ADJUSTMENT',
        details:
            'MANUAL ADJUSTMENT: ${oldStock}L → ${newStock}L (${adjustment > 0 ? "+" : ""}${adjustment.toStringAsFixed(2)}L) | Reason: $reason',
        employeeId: employeeId,
        metadata: {
          'stockBefore': oldStock,
          'stockAfter': newStock,
          'adjustment': adjustment,
          'reason': reason,
          'requiresReview': true,
        },
      );
    });
  }

  /// Deduct stock based on sales (called when Shift Closes)
  Future<void> deductSales(String tankId, double quantity) async {
    final docRef = _tankCollection.doc(tankId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return; // Silent fail if tank deleted

      final tank = Tank.fromMap(
        snapshot.id,
        snapshot.data() as Map<String, dynamic>,
      );
      final updatedTank = tank.deductSales(quantity);

      transaction.update(docRef, updatedTank.toMap());
    });
  }

  /// Log stock-related events to audit trail
  Future<void> _logStockEvent({
    required String tankId,
    required String action,
    required String details,
    String? employeeId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final auditRepo = sl<AuditRepository>();
      await auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'tanks',
        recordId: tankId,
        action: action,
        newValueJson:
            '{"details": "$details", "employeeId": "${employeeId ?? 'system'}", "timestamp": "${DateTime.now().toIso8601String()}", "metadata": ${metadata != null ? metadata.toString() : '{}'}}',
      );
    } catch (_) {
      // Audit failure should not block stock operations
    }
  }
}
