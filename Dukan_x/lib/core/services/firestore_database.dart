import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';

import 'package:dukanx/models/bill.dart';

/// A Clean, Schema-Strict Service for Firestore
/// Adapts to the new nested schema: shops/{shopId}/...
class FirestoreDatabase {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? uid;

  FirestoreDatabase({this.uid});

  // --- PATH HELPERS ---
  String shopPath(String shopId) => 'businesses/$shopId';
  String customersPath(String shopId) => 'businesses/$shopId/customers';
  String billsPath(String shopId) => 'businesses/$shopId/sales';
  String inventoryPath(String shopId) =>
      'owners/$shopId/stock'; // ✅ UNIFIED: Matches StockScreen & BuyFlowService

  // --- 1. USER MANAGEMENT ---
  Future<void> createUserProfile(
    User user,
    String role,
    String defaultShopId,
  ) async {
    final docRef = _db.collection('users').doc(user.uid);
    await docRef.set({
      'name': user.displayName ?? '',
      'phone': user.phoneNumber ?? '',
      'email': user.email ?? '',
      'role': role,
      'defaultShopId': defaultShopId,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
  }

  // --- 2. SHOP MANAGEMENT ---
  Future<String> createShop(String name, String address, String gst) async {
    if (uid == null) throw Exception("User not logged in");

    final shopRef = _db.collection('businesses').doc();
    await shopRef.set({
      'name': name,
      'ownerUid': uid,
      'address': address,
      'gstNumber': gst,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });

    await shopRef.collection('members').doc(uid).set({
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return shopRef.id;
  }

  // --- 3. BILLS (Transaction Based) ---
  Future<String> createBill({
    required String shopId,
    required Bill bill,
  }) async {
    if (uid == null) throw Exception("User not logged in");

    final billRef = _db.collection(billsPath(shopId)).doc();
    final billData = {
      'billNumber': bill.invoiceNumber.isEmpty
          ? _generateBillNumber()
          : bill.invoiceNumber,
      'customerId': bill.customerId,
      'createdBy': uid,
      'totalAmount': bill.grandTotal,
      'taxAmount': bill.totalTax,
      'paymentMode': bill.paymentType,
      'billDate': Timestamp.fromDate(bill.date),
      'status': bill.status.toLowerCase(),
      'ocrStatus': 'success',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _db.runTransaction((tx) async {
      tx.set(billRef, billData);
      if (bill.status.toLowerCase() != 'paid' && bill.customerId.isNotEmpty) {
        final custRef = _db
            .collection(customersPath(shopId))
            .doc(bill.customerId);
        final custSnap = await tx.get(custRef);
        if (custSnap.exists) {
          double currentDues = (custSnap.data()?['totalDues'] ?? 0).toDouble();
          double pending = (bill.grandTotal - bill.paidAmount);
          tx.update(custRef, {'totalDues': currentDues + pending});
        }
      }
      for (var item in bill.items) {
        if (item.vegId.isNotEmpty) {
          final stockRef = _db
              .collection(inventoryPath(shopId))
              .doc(item.vegId);
          final stockSnap = await tx.get(stockRef);
          if (stockSnap.exists) {
            double currentStock = (stockSnap.data()?['stock'] ?? 0).toDouble();
            tx.update(stockRef, {'stock': currentStock - item.qty});
          }
        }
      }
    });

    final batch = _db.batch();
    for (var item in bill.items) {
      final itemRef = billRef.collection('items').doc();
      batch.set(itemRef, {
        'name': item.itemName,
        'quantity': item.qty,
        'price': item.price,
        'total': item.total,
        'productId': item.vegId,
      });
    }
    await batch.commit();
    return billRef.id;
  }

  // --- 4. RAW SYNC METHODS (For Queue Processor) ---

  Map<String, dynamic> mapSqlToFirestore(Map<String, dynamic> sqlData) {
    // Naive SnakeCase -> CamelCase Converter could be risky.
    // Explicit mapping is safer roughly.
    final Map<String, dynamic> out = {};
    sqlData.forEach((key, value) {
      if (key == 'id' || key == 'is_synced' || key == 'is_deleted') return;
      // Convert common keys
      String newKey = key;
      if (key == 'bill_number') newKey = 'billNumber';
      if (key == 'shop_id') newKey = 'shopId';
      if (key == 'customer_id') newKey = 'customerId';
      if (key == 'total_amount') newKey = 'totalAmount';
      if (key == 'tax_amount') newKey = 'taxAmount';
      if (key == 'created_by') newKey = 'createdBy';
      if (key == 'bill_date') newKey = 'billDate';
      if (key == 'payment_mode') newKey = 'paymentMode';
      if (key == 'ocr_status') newKey = 'ocrStatus';
      if (key == 'total_dues') newKey = 'totalDues';
      if (key == 'total_spent') newKey = 'totalSpent';
      if (key == 'gst_number') newKey = 'gstNumber';
      if (key == 'owner_uid') newKey = 'ownerUid';

      // Handle Timestamps
      if ((key == 'created_at' || key == 'updated_at' || key == 'bill_date') &&
          value is String) {
        try {
          out[newKey] = Timestamp.fromDate(DateTime.parse(value));
        } catch (e) {
          out[newKey] = value;
        }
      } else {
        out[newKey] = value;
      }
    });
    return out;
  }

  Future<void> syncBillRaw(
    String shopId,
    String billId,
    Map<String, dynamic> sqlData,
  ) async {
    final data = mapSqlToFirestore(sqlData);
    await _db
        .collection(billsPath(shopId))
        .doc(billId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> syncCustomerRaw(
    String shopId,
    String custId,
    Map<String, dynamic> sqlData,
  ) async {
    final data = mapSqlToFirestore(sqlData);
    await _db
        .collection(customersPath(shopId))
        .doc(custId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> syncInventoryRaw(
    String shopId,
    String itemId,
    Map<String, dynamic> sqlData,
  ) async {
    final data = mapSqlToFirestore(sqlData);
    // Ensure we handle renaming: 'stock_qty' (SQL) -> 'quantity' (Firestore)
    if (sqlData.containsKey('stock_qty')) {
      data['quantity'] = sqlData['stock_qty'];
    }
    await _db
        .collection(inventoryPath(shopId))
        .doc(itemId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> syncShopRaw(String shopId, Map<String, dynamic> sqlData) async {
    final data = mapSqlToFirestore(sqlData);
    await _db
        .collection('businesses')
        .doc(shopId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteBill(String shopId, String billId) async {
    await _db.collection(billsPath(shopId)).doc(billId).delete();
  }

  Future<void> syncEntityRaw(
    String collectionPath,
    String docId,
    Map<String, dynamic> data,
  ) async {
    // Basic mapping if needed, or assume data is ready
    // Ensure timestamps? helper _mapSqlToFirestore handles it if we reuse it.
    // Ideally we pass cleaned map.
    await _db
        .collection(collectionPath)
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  String _generateBillNumber() {
    return "INV-${DateTime.now().millisecondsSinceEpoch}";
  }
}
