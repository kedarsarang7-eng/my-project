import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'dart:developer' as developer;

class AuditLogger {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log critical actions: BILL_CREATE, STOCK_ADJUST, PAYMENT_DELETE, etc.
  static Future<void> logAction({
    required String shopId,
    required String action, // e.g. 'BILL_CREATE'
    required String entityId, // ID of Bill/Product/Payment
    required String details, // Short description
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('shops').doc(shopId).collection('activity_logs').add(
        {
          'action': action,
          'entityId': entityId,
          'details': details,
          'performedBy': user.uid,
          'performerEmail': user.email ?? 'Unknown',
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': metadata ?? {},
          'device': 'Mobile App', // Could capture device info
        },
      );
    } catch (e) {
      // Fail silently for logs, don't block user
      developer.log("Audit Log Failed: $e", name: 'AuditLogger', error: e);
    }
  }

  // --- SHORTCUTS ---

  static Future<void> logBillCreated(
    String shopId,
    String billId,
    double amount,
  ) async {
    await logAction(
      shopId: shopId,
      action: 'BILL_CREATE',
      entityId: billId,
      details: 'Created bill for ₹$amount',
    );
  }

  static Future<void> logStockChange(
    String shopId,
    String productId,
    double oldQty,
    double newQty,
    String reason,
  ) async {
    await logAction(
      shopId: shopId,
      action: 'STOCK_ADJUST',
      entityId: productId,
      details: 'Stock changed from $oldQty to $newQty',
      metadata: {'reason': reason, 'change': newQty - oldQty},
    );
  }

  static Future<void> logPaymentReceived(
    String shopId,
    String paymentId,
    double amount,
    String mode,
  ) async {
    await logAction(
      shopId: shopId,
      action: 'PAYMENT_RECEIVED',
      entityId: paymentId,
      details: 'Received ₹$amount via $mode',
    );
  }
}
