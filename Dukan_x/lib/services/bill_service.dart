import 'dart:async';
import 'dart:developer' as developer;

import 'package:dukanx/core/compat/firestore_compat.dart';

import '../models/bill.dart';
import 'local_storage_service.dart';

/// Keeps local Hive cache and Firestore in sync so bills remain editable offline.
class BillService {
  BillService({FirebaseFirestore? firestore, LocalStorageService? localStorage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _localStorage = localStorage ?? LocalStorageService();

  final FirebaseFirestore _firestore;
  final LocalStorageService _localStorage;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('bills');

  Stream<List<Bill>> watchBills({
    String? ownerId,
    String? customerId,
    String? businessId,
  }) {
    final controller = StreamController<List<Bill>>.broadcast();
    controller.add(
      _filterCachedBills(
        ownerId: ownerId,
        customerId: customerId,
        businessId: businessId,
      ),
    );

    Query<Map<String, dynamic>> query = _collection.orderBy(
      'date',
      descending: true,
    );
    if (ownerId != null && ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }
    if (customerId != null && customerId.isNotEmpty) {
      query = query.where('customerId', isEqualTo: customerId);
    }
    if (businessId != null && businessId.isNotEmpty) {
      query = query.where('businessId', isEqualTo: businessId);
    }

    StreamSubscription? sub;
    sub = query.snapshots().listen(
      (snapshot) async {
        final bills = snapshot.docs
            .map((doc) => Bill.fromMap(doc.id, doc.data()))
            .toList();
        await _localStorage.replaceBills(bills);
        controller.add(
          _filterCachedBills(
            ownerId: ownerId,
            customerId: customerId,
            businessId: businessId,
            source: bills,
          ),
        );
      },
      onError: (error, stack) {
        developer.log(
          'Bill stream error: $error',
          name: 'BillService',
          error: error,
          stackTrace: stack,
        );
        controller.add(
          _filterCachedBills(
            ownerId: ownerId,
            customerId: customerId,
            businessId: businessId,
          ),
        );
      },
    );

    controller.onCancel = () {
      sub?.cancel();
      controller.close();
    };
    return controller.stream;
  }

  Future<List<Bill>> fetchBills({
    String? ownerId,
    String? customerId,
    String? businessId,
    bool refresh = false,
  }) async {
    if (!refresh) {
      final cached = _filterCachedBills(
        ownerId: ownerId,
        customerId: customerId,
        businessId: businessId,
      );
      if (cached.isNotEmpty) return cached;
    }
    try {
      Query<Map<String, dynamic>> query = _collection.orderBy(
        'date',
        descending: true,
      );
      if (ownerId != null && ownerId.isNotEmpty) {
        query = query.where('ownerId', isEqualTo: ownerId);
      }
      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customerId', isEqualTo: customerId);
      }
      if (businessId != null && businessId.isNotEmpty) {
        query = query.where('businessId', isEqualTo: businessId);
      }
      final snapshot = await query.get();
      final bills = snapshot.docs
          .map((doc) => Bill.fromMap(doc.id, doc.data()))
          .toList();
      await _localStorage.replaceBills(bills);
      return bills;
    } catch (e, stack) {
      developer.log(
        'fetchBills fallback to cache: $e',
        name: 'BillService',
        error: e,
        stackTrace: stack,
      );
      final cached = _filterCachedBills(
        ownerId: ownerId,
        customerId: customerId,
        businessId: businessId,
      );
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<Bill> saveBill(Bill bill, {String? ownerId}) async {
    final doc = bill.id.isEmpty ? _collection.doc() : _collection.doc(bill.id);
    final sanitized = bill
        .copyWith(
          id: doc.id,
          ownerId: ownerId ?? bill.ownerId,
          date: bill.date.toLocal(),
        )
        .sanitized();

    await _localStorage.saveBill(sanitized);
    await _localStorage.setSyncStatus('bill', sanitized.id, false);

    try {
      await doc.set(sanitized.toMap());
      await _localStorage.setSyncStatus('bill', sanitized.id, true);
      return sanitized;
    } catch (e, stack) {
      developer.log(
        'Bill save offline, will retry sync: $e',
        name: 'BillService',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Bill saved locally. Sync pending. (${e.toString()})');
    }
  }

  Future<void> updateBill(Bill bill) async {
    if (bill.id.isEmpty) {
      throw ArgumentError('Bill ID is required for update');
    }
    final sanitized = bill.sanitized();
    await _localStorage.updateBill(sanitized);
    await _localStorage.setSyncStatus('bill', sanitized.id, false);
    try {
      await _collection.doc(sanitized.id).set(sanitized.toMap());
      await _localStorage.setSyncStatus('bill', sanitized.id, true);
    } catch (e, stack) {
      developer.log(
        'Bill update failed: $e',
        name: 'BillService',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Unable to sync bill. ${e.toString()}');
    }
  }

  Future<void> deleteBill(String billId) async {
    await _localStorage.deleteBill(billId);
    await _localStorage.setSyncStatus('bill', billId, false);
    try {
      await _collection.doc(billId).delete();
      await _localStorage.setSyncStatus('bill', billId, true);
    } catch (e, stack) {
      developer.log(
        'Bill delete failed: $e',
        name: 'BillService',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Unable to delete bill online. ${e.toString()}');
    }
  }

  Future<void> syncPendingBills() async {
    final unsynced = _localStorage
        .getUnsyncedItems()
        .where((item) => item['dataType'] == 'bill' && item['itemId'] != null)
        .toList();
    if (unsynced.isEmpty) return;

    final cache = _localStorage.getAllBills();
    for (final entry in unsynced) {
      final billId = entry['itemId'] as String;
      final bill = cache.firstWhere(
        (b) => b.id == billId,
        orElse: () => Bill.empty(),
      );
      if (bill.id.isEmpty) continue;
      try {
        await _collection.doc(bill.id).set(bill.toMap());
        await _localStorage.setSyncStatus('bill', bill.id, true);
      } catch (e, stack) {
        developer.log(
          'Retry bill sync failed for ${bill.id}: $e',
          name: 'BillService',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  List<Bill> _filterCachedBills({
    String? ownerId,
    String? customerId,
    String? businessId,
    List<Bill>? source,
  }) {
    final bills = source ?? _localStorage.getAllBills();
    return bills.where((bill) {
      final ownerMatches = ownerId == null || ownerId.isEmpty
          ? true
          : bill.ownerId == ownerId;
      final customerMatches = customerId == null || customerId.isEmpty
          ? true
          : bill.customerId == customerId;
      final businessMatches = businessId == null || businessId.isEmpty
          ? true
          : bill.businessId == businessId;
      return ownerMatches && customerMatches && businessMatches;
    }).toList();
  }
}
