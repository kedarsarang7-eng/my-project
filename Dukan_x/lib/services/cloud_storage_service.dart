import 'package:dukanx/core/compat/firestore_compat.dart';
import 'dart:developer' as developer;
import '../models/bill.dart';
import '../models/customer.dart';

/// Cloud Storage Service - Handles Firestore sync
/// Supports multi-device login with data persistence and cloud backup
class CloudStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cloud sync options
  static const String syncModeLocal = 'local_only';
  static const String syncModeCloud = 'cloud_only';
  static const String syncModeHybrid = 'hybrid'; // Local + Cloud

  /// Save owner data to cloud (Firestore)
  Future<bool> saveOwnerToCloud({
    required String ownerId,
    required Map<String, dynamic> ownerData,
  }) async {
    try {
      await _firestore.collection('owners').doc(ownerId).set({
        ...ownerData,
        'lastUpdated': FieldValue.serverTimestamp(),
        'syncStatus': 'synced',
      }, SetOptions(merge: true));
      developer.log(
        'Owner data saved to cloud: $ownerId',
        name: 'CloudStorageService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error saving owner to cloud: $e',
        name: 'CloudStorageService',
      );
      return false;
    }
  }

  /// Save customer to cloud (Firestore)
  Future<bool> saveCustomerToCloud({
    required String ownerId,
    required Customer customer,
  }) async {
    try {
      await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .doc(customer.id)
          .set({
            'id': customer.id,
            'name': customer.name,
            'phone': customer.phone,
            'address': customer.address,
            'totalDues': customer.totalDues,
            'cashDues': customer.cashDues,
            'onlineDues': customer.onlineDues,
            'lastUpdated': FieldValue.serverTimestamp(),
            'syncStatus': 'synced',
          }, SetOptions(merge: true));
      developer.log(
        'Customer saved to cloud: ${customer.id}',
        name: 'CloudStorageService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error saving customer to cloud: $e',
        name: 'CloudStorageService',
      );
      return false;
    }
  }

  /// Save bill to cloud (Firestore)
  Future<bool> saveBillToCloud({
    required String ownerId,
    required Bill bill,
  }) async {
    try {
      await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('bills')
          .doc(bill.id)
          .set({
            'id': bill.id,
            'customerId': bill.customerId,
            'subtotal': bill.subtotal,
            'paidAmount': bill.paidAmount,
            'dueAmount': bill.subtotal - bill.paidAmount,
            'items': bill.items.map((e) => e.toMap()).toList(),
            'status': bill.status,
            'date': bill.date.toIso8601String(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'syncStatus': 'synced',
          }, SetOptions(merge: true));
      developer.log(
        'Bill saved to cloud: ${bill.id}',
        name: 'CloudStorageService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error saving bill to cloud: $e',
        name: 'CloudStorageService',
      );
      return false;
    }
  }

  /// Fetch owner data from cloud
  Future<Map<String, dynamic>?> getOwnerFromCloud({
    required String ownerId,
  }) async {
    try {
      final doc = await _firestore.collection('owners').doc(ownerId).get();
      if (doc.exists) {
        developer.log(
          'Owner data fetched from cloud: $ownerId',
          name: 'CloudStorageService',
        );
        return doc.data();
      }
      return null;
    } catch (e) {
      developer.log(
        'Error fetching owner from cloud: $e',
        name: 'CloudStorageService',
      );
      return null;
    }
  }

  /// Fetch all customers for owner from cloud
  Future<List<Customer>> getCustomersFromCloud({
    required String ownerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .get();

      final customers = snapshot.docs.map((doc) {
        final data = doc.data();
        return Customer(
          id: data['id'] ?? doc.id,
          name: data['name'] ?? 'Unknown',
          phone: data['phone'] ?? '',
          address: data['address'] ?? '',
          totalDues: (data['totalDues'] ?? 0).toDouble(),
          cashDues: (data['cashDues'] ?? 0).toDouble(),
          onlineDues: (data['onlineDues'] ?? 0).toDouble(),
        );
      }).toList();

      developer.log(
        'Fetched ${customers.length} customers from cloud',
        name: 'CloudStorageService',
      );
      return customers;
    } catch (e) {
      developer.log(
        'Error fetching customers from cloud: $e',
        name: 'CloudStorageService',
      );
      return [];
    }
  }

  /// Fetch all bills for owner from cloud
  Future<List<Bill>> getBillsFromCloud({required String ownerId}) async {
    try {
      final snapshot = await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('bills')
          .get();

      final bills = snapshot.docs.map((doc) {
        final data = doc.data();
        return Bill(
          id: data['id'] ?? doc.id,
          customerId: data['customerId'] ?? '',
          date: data['date'] != null
              ? DateTime.parse(data['date'])
              : DateTime.now(),
          items:
              (data['items'] as List<dynamic>?)
                  ?.map((e) => BillItem.fromMap(Map<String, dynamic>.from(e)))
                  .toList() ??
              [],
          subtotal: (data['subtotal'] ?? 0).toDouble(),
          paidAmount: (data['paidAmount'] ?? 0).toDouble(),
          status: data['status'] ?? 'Unpaid',
        );
      }).toList();

      developer.log(
        'Fetched ${bills.length} bills from cloud',
        name: 'CloudStorageService',
      );
      return bills;
    } catch (e) {
      developer.log(
        'Error fetching bills from cloud: $e',
        name: 'CloudStorageService',
      );
      return [];
    }
  }

  /// Enable multi-device sync by saving session device info
  Future<bool> registerDevice({
    required String ownerId,
    required String deviceId,
    required String deviceName,
  }) async {
    try {
      await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('devices')
          .doc(deviceId)
          .set({
            'deviceId': deviceId,
            'deviceName': deviceName,
            'lastLogin': FieldValue.serverTimestamp(),
            'isActive': true,
          }, SetOptions(merge: true));
      developer.log(
        'Device registered for owner: $ownerId',
        name: 'CloudStorageService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error registering device: $e',
        name: 'CloudStorageService',
      );
      return false;
    }
  }

  /// Get active devices for owner (for multi-device login management)
  Future<List<Map<String, dynamic>>> getActiveDevices({
    required String ownerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('devices')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      developer.log(
        'Error fetching active devices: $e',
        name: 'CloudStorageService',
      );
      return [];
    }
  }

  /// Delete data from cloud when switching devices
  Future<bool> signOutFromCloud({
    required String ownerId,
    required String deviceId,
  }) async {
    try {
      await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('devices')
          .doc(deviceId)
          .update({'isActive': false});
      developer.log(
        'Device signed out from cloud: $ownerId',
        name: 'CloudStorageService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error signing out from cloud: $e',
        name: 'CloudStorageService',
      );
      return false;
    }
  }

  /// Get sync status of all data
  Future<Map<String, String>> getSyncStatus({required String ownerId}) async {
    try {
      final ownerDoc = await _firestore.collection('owners').doc(ownerId).get();
      final ownerSyncStatus = ownerDoc.data()?['syncStatus'] ?? 'unknown';

      final customersSnapshot = await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .get();
      int syncedCustomers = 0;
      for (var doc in customersSnapshot.docs) {
        if (doc.data()['syncStatus'] == 'synced') syncedCustomers++;
      }

      final billsSnapshot = await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('bills')
          .get();
      int syncedBills = 0;
      for (var doc in billsSnapshot.docs) {
        if (doc.data()['syncStatus'] == 'synced') syncedBills++;
      }

      return {
        'owner': ownerSyncStatus,
        'customers': '$syncedCustomers/${customersSnapshot.docs.length}',
        'bills': '$syncedBills/${billsSnapshot.docs.length}',
      };
    } catch (e) {
      developer.log(
        'Error getting sync status: $e',
        name: 'CloudStorageService',
      );
      return {'error': 'Failed to get sync status'};
    }
  }

  /// Enable cloud sync for current user
  Future<bool> enableCloudSync({required String ownerId}) async {
    try {
      await _firestore.collection('owners').doc(ownerId).update({
        'cloudSyncEnabled': true,
        'lastCloudSync': FieldValue.serverTimestamp(),
      });
      developer.log(
        'Cloud sync enabled for owner: $ownerId',
        name: 'CloudStorageService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error enabling cloud sync: $e',
        name: 'CloudStorageService',
      );
      return false;
    }
  }

  /// Disable cloud sync for current user
  Future<bool> disableCloudSync({required String ownerId}) async {
    try {
      await _firestore.collection('owners').doc(ownerId).update({
        'cloudSyncEnabled': false,
      });
      developer.log(
        'Cloud sync disabled for owner: $ownerId',
        name: 'CloudStorageService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error disabling cloud sync: $e',
        name: 'CloudStorageService',
      );
      return false;
    }
  }

  /// Check if cloud sync is enabled
  Future<bool> isCloudSyncEnabled({required String ownerId}) async {
    try {
      final doc = await _firestore.collection('owners').doc(ownerId).get();
      return doc.data()?['cloudSyncEnabled'] ?? false;
    } catch (e) {
      return false;
    }
  }
}
