import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Data Tamper Prevention Service
/// Verifies data integrity through hashing and detects modifications
class TamperDetectionService {
  late Map<String, String> _customerHashes = {};
  late Map<String, String> _billHashes = {};
  late String _hashDatabasePath;

  /// Initialize tamper detection service
  Future<void> initialize() async {
    try {
      // Set up hash database location
      final appDir = await getApplicationDocumentsDirectory();
      _hashDatabasePath = '${appDir.path}/security/hashes.json';

      // Load existing hashes
      await _loadHashDatabase();
    } catch (e) {
      debugPrint('[TamperDetectionService.initialize] error: $e');
      rethrow;
    }
  }

  /// Load hash database from storage
  Future<void> _loadHashDatabase() async {
    try {
      final hashFile = File(_hashDatabasePath);

      if (!hashFile.existsSync()) {
        await hashFile.parent.create(recursive: true);
        return;
      }

      final content = await hashFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      _customerHashes = Map<String, String>.from(
        data['customers'] ?? <String, String>{},
      );
      _billHashes = Map<String, String>.from(
        data['bills'] ?? <String, String>{},
      );
    } catch (e) {
      debugPrint('[TamperDetectionService._loadHashDatabase] error: $e');
    }
  }

  /// Save hash database to storage
  Future<void> _saveHashDatabase() async {
    try {
      final data = {
        'customers': _customerHashes,
        'bills': _billHashes,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      final hashFile = File(_hashDatabasePath);
      await hashFile.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[TamperDetectionService._saveHashDatabase] error: $e');
      rethrow;
    }
  }

  /// Generate SHA-256 hash for customer record
  String _generateCustomerHash(Map<String, dynamic> customer) {
    try {
      // Include all sensitive fields
      final payload = {
        'id': customer['id'],
        'name': customer['name'],
        'phone': customer['phone'],
        'address': customer['address'],
        'totalDues': customer['totalDues'],
        'cashDues': customer['cashDues'],
        'onlineDues': customer['onlineDues'],
        'discount': customer['discount'],
        'marketTicket': customer['marketTicket'],
        'isBlacklisted': customer['isBlacklisted'],
        'createdAt': customer['createdAt'],
      };

      final jsonString = jsonEncode(payload);
      return sha256.convert(utf8.encode(jsonString)).toString();
    } catch (e) {
      debugPrint('[TamperDetectionService._generateCustomerHash] error: $e');
      return '';
    }
  }

  /// Generate SHA-256 hash for bill record
  String _generateBillHash(Map<String, dynamic> bill) {
    try {
      // Include all sensitive fields
      final payload = {
        'id': bill['id'],
        'customerId': bill['customerId'],
        'invoiceNumber': bill['invoiceNumber'],
        'subtotal': bill['subtotal'],
        'paidAmount': bill['paidAmount'],
        'paymentMethod': bill['paymentMethod'],
        'status': bill['status'],
        'date': bill['date'],
        'dueDate': bill['dueDate'],
        'notes': bill['notes'],
      };

      final jsonString = jsonEncode(payload);
      return sha256.convert(utf8.encode(jsonString)).toString();
    } catch (e) {
      debugPrint('[TamperDetectionService._generateBillHash] error: $e');
      return '';
    }
  }

  /// Store customer hash for integrity verification
  Future<void> storeCustomerHash(Map<String, dynamic> customer) async {
    try {
      final customerId = customer['id'] as String;
      final hash = _generateCustomerHash(customer);

      _customerHashes[customerId] = hash;

      await _saveHashDatabase();
    } catch (e) {
      debugPrint('[TamperDetectionService.storeCustomerHash] error: $e');
      rethrow;
    }
  }

  /// Store bill hash for integrity verification
  Future<void> storeBillHash(Map<String, dynamic> bill) async {
    try {
      final billId = bill['id'] as String;
      final hash = _generateBillHash(bill);

      _billHashes[billId] = hash;

      await _saveHashDatabase();
    } catch (e) {
      debugPrint('[TamperDetectionService.storeBillHash] error: $e');
      rethrow;
    }
  }

  /// Verify customer integrity (detect if modified)
  Future<bool> verifyCustomerIntegrity(Map<String, dynamic> customer) async {
    try {
      final customerId = customer['id'] as String;
      final storedHash = _customerHashes[customerId];

      if (storedHash == null) {
        return false;
      }

      final currentHash = _generateCustomerHash(customer);

      if (storedHash == currentHash) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('[TamperDetectionService.verifyCustomerIntegrity] error: $e');
      return false;
    }
  }

  /// Verify bill integrity (detect if modified)
  Future<bool> verifyBillIntegrity(Map<String, dynamic> bill) async {
    try {
      final billId = bill['id'] as String;
      final storedHash = _billHashes[billId];

      if (storedHash == null) {
        return false;
      }

      final currentHash = _generateBillHash(bill);

      if (storedHash == currentHash) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('[TamperDetectionService.verifyBillIntegrity] error: $e');
      return false;
    }
  }

  /// Batch verify all customer records
  Future<List<String>> verifyAllCustomers(
    List<Map<String, dynamic>> customers,
  ) async {
    try {
      final tamperedCustomers = <String>[];

      for (final customer in customers) {
        final isValid = await verifyCustomerIntegrity(customer);
        if (!isValid) {
          tamperedCustomers.add(customer['id'] as String);
        }
      }

      if (tamperedCustomers.isNotEmpty) {
      } else {}

      return tamperedCustomers;
    } catch (e) {
      debugPrint('[TamperDetectionService.verifyAllCustomers] error: $e');
      return [];
    }
  }

  /// Batch verify all bills
  Future<List<String>> verifyAllBills(List<Map<String, dynamic>> bills) async {
    try {
      final tamperedBills = <String>[];

      for (final bill in bills) {
        final isValid = await verifyBillIntegrity(bill);
        if (!isValid) {
          tamperedBills.add(bill['id'] as String);
        }
      }

      if (tamperedBills.isNotEmpty) {
      } else {}

      return tamperedBills;
    } catch (e) {
      debugPrint('[TamperDetectionService.verifyAllBills] error: $e');
      return [];
    }
  }

  /// Get tamper detection status
  Map<String, dynamic> getTamperStatus() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'customerHashesStored': _customerHashes.length,
      'billHashesStored': _billHashes.length,
      'totalRecordsProtected': _customerHashes.length + _billHashes.length,
      'status': 'MONITORING âœ“',
    };
  }

  /// Dispose
  void dispose() {
    debugPrint('[TamperDetectionService] dispose called');
  }
}
