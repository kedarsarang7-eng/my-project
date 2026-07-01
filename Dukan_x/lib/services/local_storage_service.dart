import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/payment.dart';

import 'web_persistence_service.dart';

/// Local storage service using Hive for permanent data persistence.
/// On web platform, uses IndexedDB via WebPersistenceService.
/// Syncs with Firestore and ensures no data loss on app updates.
class LocalStorageService {
  static const String customersBox = 'customers';
  static const String billsBox = 'bills';
  static const String paymentsBox = 'payments';
  static const String customerRequestsBox = 'customer_requests';

  static const String syncStatusBox = 'sync_status';

  late Box<Map> _customersBox;
  late Box<Map> _billsBox;
  late Box<Map> _paymentsBox;
  late Box<Map> _syncStatusBox;
  late Box<Map> _customerRequestsBox;

  bool _initialized = false;
  bool _isWeb = false;
  WebPersistenceService? _webService;

  bool get isReady => _initialized;

  /// Initialize Hive (mobile) or IndexedDB (web)
  Future<void> init() async {
    // On web, use IndexedDB via WebPersistenceService
    if (kIsWeb) {
      _isWeb = true;
      _webService = WebPersistenceService();
      await _webService!.init();
      _initialized = _webService!.isReady;
      developer.log(
        'LocalStorageService: Web mode - IndexedDB ${_initialized ? "ready" : "failed"}',
        name: 'LocalStorageService',
      );
      return;
    }

    try {
      // Only call initFlutter once
      if (!Hive.isAdapterRegistered(0)) {
        await Hive.initFlutter();
      }

      // Use an encrypted Hive box. The encryption key is stored securely
      // using flutter_secure_storage. We generate a 32-byte random key if one
      // is not already stored.
      const secureStorage = FlutterSecureStorage();
      final keyString = await secureStorage.read(key: 'hive_encryption_key');
      late final Uint8List encryptionKey;
      if (keyString == null) {
        final generated = List<int>.generate(
          32,
          (_) => Random.secure().nextInt(256),
        );
        await secureStorage.write(
          key: 'hive_encryption_key',
          value: base64UrlEncode(generated),
        );
        encryptionKey = Uint8List.fromList(generated);
      } else {
        encryptionKey = base64Url.decode(keyString);
      }

      // Open encrypted boxes
      _customersBox = await Hive.openBox<Map>(
        customersBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      _billsBox = await Hive.openBox<Map>(
        billsBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      _paymentsBox = await Hive.openBox<Map>(
        paymentsBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      _syncStatusBox = await Hive.openBox<Map>(
        syncStatusBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      _customerRequestsBox = await Hive.openBox<Map>(
        customerRequestsBox,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      _initialized = true;
      developer.log(
        'LocalStorageService initialized successfully',
        name: 'LocalStorageService',
      );
    } catch (e) {
      developer.log(
        'Error initializing LocalStorageService: $e',
        name: 'LocalStorageService',
      );
      _initialized = false;
    }
  }

  // =============== CUSTOMER OPERATIONS ===============

  /// Save customer to local storage
  Future<void> saveCustomer(Customer customer) async {
    if (!_initialized) return;
    try {
      final map = customer.toMap();
      if (_isWeb && _webService != null) {
        await _webService!.saveCustomer(map);
      } else {
        await _customersBox.put(customer.phone, map);
      }
    } catch (e) {
      developer.log('Error saving customer: $e', name: 'LocalStorageService');
    }
  }

  /// Get customer from local storage
  Customer? getCustomer(String phone) {
    if (!_initialized) return null;
    try {
      final map = _customersBox.get(phone);
      if (map == null) return null;
      return Customer.fromMap(phone, Map<String, dynamic>.from(map));
    } catch (e) {
      developer.log('Error getting customer: $e', name: 'LocalStorageService');
      return null;
    }
  }

  /// Get all customers from local storage
  List<Customer> getAllCustomers() {
    if (!_initialized) return [];
    try {
      final customers = <Customer>[];
      for (var i = 0; i < _customersBox.length; i++) {
        final key = _customersBox.keyAt(i);
        final map = Map<String, dynamic>.from(_customersBox.getAt(i) as Map);
        customers.add(Customer.fromMap(key.toString(), map));
      }
      return customers;
    } catch (e) {
      developer.log(
        'Error getting all customers: $e',
        name: 'LocalStorageService',
      );
      return [];
    }
  }

  /// Delete customer from local storage
  Future<void> deleteCustomer(String phone) async {
    if (!_initialized) return;
    try {
      await _customersBox.delete(phone);
    } catch (e) {
      developer.log('Error deleting customer: $e', name: 'LocalStorageService');
    }
  }

  /// Update customer in local storage
  Future<void> updateCustomer(Customer customer) async {
    if (!_initialized) return;
    try {
      final map = customer.toMap();
      await _customersBox.put(customer.phone, map);
    } catch (e) {
      developer.log('Error updating customer: $e', name: 'LocalStorageService');
    }
  }

  /// Get customer by phone (useful for login)
  Customer? getCustomerByPhone(String phone) {
    if (!_initialized) return null;
    try {
      final map = _customersBox.get(phone);
      if (map == null) return null;
      return Customer.fromMap(phone, Map<String, dynamic>.from(map));
    } catch (e) {
      developer.log(
        'Error getting customer by phone: $e',
        name: 'LocalStorageService',
      );
      return null;
    }
  }

  // =============== BILL OPERATIONS ===============

  /// Save bill to local storage (synced from Firestore)
  Future<void> saveBill(Bill bill) async {
    if (!_initialized) return;
    try {
      final sanitized = bill.sanitized();
      if (_isWeb && _webService != null) {
        await _webService!.saveBill(sanitized.toMap());
      } else {
        await _billsBox.put(sanitized.id, sanitized.toMap());
      }
    } catch (e) {
      developer.log('Error saving bill: $e', name: 'LocalStorageService');
    }
  }

  /// Get bill from local storage
  Bill? getBill(String billId) {
    if (!_initialized) return null;
    try {
      final map = _billsBox.get(billId);
      if (map == null) return null;
      return Bill.fromMap(billId, Map<String, dynamic>.from(map));
    } catch (e) {
      developer.log('Error getting bill: $e', name: 'LocalStorageService');
      return null;
    }
  }

  /// Get all bills for a customer from local storage
  List<Bill> getBillsForCustomer(String customerId) {
    if (!_initialized) return [];
    try {
      final bills = <Bill>[];
      for (var i = 0; i < _billsBox.length; i++) {
        final key = _billsBox.keyAt(i);
        final map = Map<String, dynamic>.from(_billsBox.getAt(i) as Map);
        if (map['customerId'] == customerId) {
          bills.add(Bill.fromMap(key.toString(), map));
        }
      }
      // Sort by date descending
      bills.sort((a, b) => b.date.compareTo(a.date));
      return bills;
    } catch (e) {
      developer.log(
        'Error getting bills for customer: $e',
        name: 'LocalStorageService',
      );
      return [];
    }
  }

  /// Get all bills from local storage
  List<Bill> getAllBills() {
    if (!_initialized) return [];
    try {
      final bills = <Bill>[];
      for (var i = 0; i < _billsBox.length; i++) {
        final key = _billsBox.keyAt(i);
        final map = Map<String, dynamic>.from(_billsBox.getAt(i) as Map);
        bills.add(Bill.fromMap(key.toString(), map));
      }
      // Sort by date descending
      bills.sort((a, b) => b.date.compareTo(a.date));
      return bills;
    } catch (e) {
      developer.log('Error getting all bills: $e', name: 'LocalStorageService');
      return [];
    }
  }

  List<Bill> queryBills({String? customerId}) {
    final bills = getAllBills();
    if (customerId == null || customerId.isEmpty) return bills;
    return bills.where((bill) => bill.customerId == customerId).toList();
  }

  Future<void> replaceBills(List<Bill> bills) async {
    if (!_initialized) return;
    try {
      await _billsBox.clear();
      for (final bill in bills) {
        final sanitized = bill.sanitized();
        await _billsBox.put(sanitized.id, sanitized.toMap());
      }
    } catch (e) {
      developer.log('Error replacing bills: $e', name: 'LocalStorageService');
    }
  }

  /// Delete bill from local storage (owner action)
  Future<void> deleteBill(String billId) async {
    if (!_initialized) return;
    try {
      await _billsBox.delete(billId);
    } catch (e) {
      developer.log('Error deleting bill: $e', name: 'LocalStorageService');
    }
  }

  /// Update bill in local storage
  Future<void> updateBill(Bill bill) async {
    if (!_initialized) return;
    try {
      final sanitized = bill.sanitized();
      await _billsBox.put(sanitized.id, sanitized.toMap());
    } catch (e) {
      developer.log('Error updating bill: $e', name: 'LocalStorageService');
    }
  }

  // =============== PAYMENT OPERATIONS ===============

  /// Save payment to local storage (synced from Firestore)
  Future<void> savePayment(Payment payment) async {
    if (!_initialized) return;
    try {
      final map = payment.toMap();
      await _paymentsBox.put(payment.id, map);
    } catch (e) {
      developer.log('Error saving payment: $e', name: 'LocalStorageService');
    }
  }

  /// Get payment from local storage
  Payment? getPayment(String paymentId) {
    if (!_initialized) return null;
    try {
      final map = _paymentsBox.get(paymentId);
      if (map == null) return null;
      return Payment.fromMap(paymentId, Map<String, dynamic>.from(map));
    } catch (e) {
      developer.log('Error getting payment: $e', name: 'LocalStorageService');
      return null;
    }
  }

  /// Get all payments for a bill from local storage
  List<Payment> getPaymentsForBill(String billId) {
    if (!_initialized) return [];
    try {
      final payments = <Payment>[];
      for (var i = 0; i < _paymentsBox.length; i++) {
        final key = _paymentsBox.keyAt(i);
        final map = Map<String, dynamic>.from(_paymentsBox.getAt(i) as Map);
        if (map['billId'] == billId) {
          payments.add(Payment.fromMap(key.toString(), map));
        }
      }
      // Sort by date descending
      payments.sort((a, b) => b.date.compareTo(a.date));
      return payments;
    } catch (e) {
      developer.log(
        'Error getting payments for bill: $e',
        name: 'LocalStorageService',
      );
      return [];
    }
  }

  /// Get all payments for a customer from local storage
  List<Payment> getPaymentsForCustomer(String customerId) {
    if (!_initialized) return [];
    try {
      final payments = <Payment>[];
      for (var i = 0; i < _paymentsBox.length; i++) {
        final key = _paymentsBox.keyAt(i);
        final map = Map<String, dynamic>.from(_paymentsBox.getAt(i) as Map);
        if (map['customerId'] == customerId) {
          payments.add(Payment.fromMap(key.toString(), map));
        }
      }
      // Sort by date descending
      payments.sort((a, b) => b.date.compareTo(a.date));
      return payments;
    } catch (e) {
      developer.log(
        'Error getting payments for customer: $e',
        name: 'LocalStorageService',
      );
      return [];
    }
  }

  /// Get all payments from local storage
  List<Payment> getAllPayments() {
    if (!_initialized) return [];
    try {
      final payments = <Payment>[];
      for (var i = 0; i < _paymentsBox.length; i++) {
        final key = _paymentsBox.keyAt(i);
        final map = Map<String, dynamic>.from(_paymentsBox.getAt(i) as Map);
        payments.add(Payment.fromMap(key.toString(), map));
      }
      // Sort by date descending
      payments.sort((a, b) => b.date.compareTo(a.date));
      return payments;
    } catch (e) {
      developer.log(
        'Error getting all payments: $e',
        name: 'LocalStorageService',
      );
      return [];
    }
  }

  /// Delete payment from local storage (owner action)
  Future<void> deletePayment(String paymentId) async {
    if (!_initialized) return;
    try {
      await _paymentsBox.delete(paymentId);
    } catch (e) {
      developer.log('Error deleting payment: $e', name: 'LocalStorageService');
    }
  }

  // =============== SYNC STATUS TRACKING ===============

  /// Save sync status for tracking what's synced and what's pending
  Future<void> setSyncStatus(
    String dataType,
    String itemId,
    bool synced,
  ) async {
    if (!_initialized) return;
    try {
      final key = '${dataType}_$itemId';
      await _syncStatusBox.put(key, {
        'dataType': dataType,
        'itemId': itemId,
        'synced': synced,
        'lastSync': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      developer.log(
        'Error setting sync status: $e',
        name: 'LocalStorageService',
      );
    }
  }

  /// Get sync status for an item
  bool getSyncStatus(String dataType, String itemId) {
    if (!_initialized) return false;
    try {
      final key = '${dataType}_$itemId';
      final map = _syncStatusBox.get(key);
      return (map?['synced'] as bool?) ?? false;
    } catch (e) {
      developer.log(
        'Error getting sync status: $e',
        name: 'LocalStorageService',
      );
      return false;
    }
  }

  /// Get all unsynced items
  List<Map<String, dynamic>> getUnsyncedItems() {
    if (!_initialized) return [];
    try {
      final unsynced = <Map<String, dynamic>>[];
      for (var i = 0; i < _syncStatusBox.length; i++) {
        final map = Map<String, dynamic>.from(_syncStatusBox.getAt(i) as Map);
        if (map['synced'] != true) {
          unsynced.add(map);
        }
      }
      return unsynced;
    } catch (e) {
      developer.log(
        'Error getting unsynced items: $e',
        name: 'LocalStorageService',
      );
      return [];
    }
  }

  /// Mark all as synced after successful cloud sync
  Future<void> markAllAsSynced() async {
    if (!_initialized) return;
    try {
      for (var i = 0; i < _syncStatusBox.length; i++) {
        final map = Map<String, dynamic>.from(_syncStatusBox.getAt(i) as Map);
        map['synced'] = true;
        await _syncStatusBox.putAt(i, map);
      }
    } catch (e) {
      developer.log(
        'Error marking all as synced: $e',
        name: 'LocalStorageService',
      );
    }
  }

  /// Clear sync status tracking
  Future<void> clearSyncStatus() async {
    if (!_initialized) return;
    try {
      await _syncStatusBox.clear();
    } catch (e) {
      developer.log(
        'Error clearing sync status: $e',
        name: 'LocalStorageService',
      );
    }
  }

  // =============== DATA EXPORT / REPORTING ===============

  /// Calculate total dues for a customer
  double calculateTotalDues(String customerId) {
    if (!_initialized) return 0;
    try {
      double total = 0;
      for (var i = 0; i < _billsBox.length; i++) {
        final map = Map<String, dynamic>.from(_billsBox.getAt(i) as Map);
        if (map['customerId'] == customerId && map['status'] != 'PAID') {
          final bill = Bill.fromMap('', map);
          final paid = (bill.paidAmount as num?)?.toDouble() ?? 0;
          final subtotal = (bill.subtotal as num?)?.toDouble() ?? 0;
          total += (subtotal - paid).clamp(0, double.infinity);
        }
      }
      return total;
    } catch (e) {
      developer.log(
        'Error calculating total dues: $e',
        name: 'LocalStorageService',
      );
      return 0;
    }
  }

  /// Calculate total bill amount for a customer
  double calculateTotalBillAmount(String customerId) {
    if (!_initialized) return 0;
    try {
      double total = 0;
      for (var i = 0; i < _billsBox.length; i++) {
        final map = Map<String, dynamic>.from(_billsBox.getAt(i) as Map);
        if (map['customerId'] == customerId) {
          final subtotal = (map['subtotal'] as num?)?.toDouble() ?? 0;
          total += subtotal;
        }
      }
      return total;
    } catch (e) {
      developer.log(
        'Error calculating total bill amount: $e',
        name: 'LocalStorageService',
      );
      return 0;
    }
  }

  /// Calculate total payment amount for a customer
  double calculateTotalPaymentAmount(String customerId) {
    if (!_initialized) return 0;
    try {
      double total = 0;
      for (var i = 0; i < _paymentsBox.length; i++) {
        final map = Map<String, dynamic>.from(_paymentsBox.getAt(i) as Map);
        if (map['customerId'] == customerId) {
          final amount = (map['amount'] as num?)?.toDouble() ?? 0;
          total += amount;
        }
      }
      return total;
    } catch (e) {
      developer.log(
        'Error calculating total payment amount: $e',
        name: 'LocalStorageService',
      );
      return 0;
    }
  }

  /// Alias for compatibility with sync_service
  double getTotalDues(String customerId) => calculateTotalDues(customerId);

  /// Alias for compatibility with sync_service
  double getTotalBillAmount(String customerId) =>
      calculateTotalBillAmount(customerId);

  /// Alias for compatibility with sync_service
  double getTotalPaymentAmount(String customerId) =>
      calculateTotalPaymentAmount(customerId);

  /// Export all data (for backup)
  Future<Map<String, dynamic>> exportAllData() async {
    if (!_initialized) return {};
    try {
      return {
        'customers': getAllCustomers().map((c) => c.toMap()).toList(),
        'bills': getAllBills().map((b) => b.toMap()).toList(),
        'payments': getAllPayments().map((p) => p.toMap()).toList(),
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('Error exporting data: $e', name: 'LocalStorageService');
      return {};
    }
  }

  /// Clear all data (dangerous operation)
  Future<void> clearAllData() async {
    if (!_initialized) return;
    try {
      await _customersBox.clear();
      await _billsBox.clear();
      await _paymentsBox.clear();
      await _syncStatusBox.clear();
    } catch (e) {
      developer.log('Error clearing all data: $e', name: 'LocalStorageService');
    }
  }

  /// Get database size info
  Map<String, int> getDatabaseSize() {
    if (!_initialized) {
      return {'customers': 0, 'bills': 0, 'payments': 0, 'syncStatus': 0};
    }
    try {
      return {
        'customers': _customersBox.length,
        'bills': _billsBox.length,
        'payments': _paymentsBox.length,
        'syncStatus': _syncStatusBox.length,
      };
    } catch (e) {
      developer.log(
        'Error getting database size: $e',
        name: 'LocalStorageService',
      );
      return {'customers': 0, 'bills': 0, 'payments': 0, 'syncStatus': 0};
    }
  }

  // =============== CUSTOMER REQUEST OPERATIONS ===============

  /// Save customer request draft
  Future<void> saveRequestDraft(
    String customerId,
    Map<String, dynamic> requestData,
  ) async {
    if (!_initialized) return;
    try {
      await _customerRequestsBox.put('${customerId}_draft', requestData);
    } catch (e) {
      developer.log(
        'Error saving request draft: $e',
        name: 'LocalStorageService',
      );
    }
  }

  /// Get customer request draft
  Map<String, dynamic>? getRequestDraft(String customerId) {
    if (!_initialized) return null;
    try {
      final map = _customerRequestsBox.get('${customerId}_draft');
      if (map == null) return null;
      return Map<String, dynamic>.from(map);
    } catch (e) {
      developer.log(
        'Error getting request draft: $e',
        name: 'LocalStorageService',
      );
      return null;
    }
  }

  /// Delete customer request draft
  Future<void> deleteRequestDraft(String customerId) async {
    if (!_initialized) return;
    try {
      await _customerRequestsBox.delete('${customerId}_draft');
    } catch (e) {
      developer.log(
        'Error deleting request draft: $e',
        name: 'LocalStorageService',
      );
    }
  }
}
