import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as developer;
import '../../../models/bill.dart';
import '../../../models/customer.dart';

/// CRITICAL FIX: Specific error types for proper UI handling
enum CloudStorageErrorType {
  network,
  timeout,
  unauthorized,
  notFound,
  serverError,
  validation,
  unknown,
}

/// CRITICAL FIX: Result type for explicit error handling
class CloudStorageResult<T> {
  final T? data;
  final CloudStorageErrorType? errorType;
  final String? errorMessage;
  final int? statusCode;
  final bool success;

  const CloudStorageResult._({
    this.data,
    this.errorType,
    this.errorMessage,
    this.statusCode,
    required this.success,
  });

  factory CloudStorageResult.ok(T data) =>
      CloudStorageResult._(data: data, success: true);

  factory CloudStorageResult.error({
    required CloudStorageErrorType type,
    required String message,
    int? statusCode,
  }) => CloudStorageResult._(
        errorType: type,
        errorMessage: message,
        statusCode: statusCode,
        success: false,
      );

  /// Map ApiResponse status code to error type
  static CloudStorageErrorType _mapStatusCode(int statusCode) {
    if (statusCode == 0) return CloudStorageErrorType.network;
    if (statusCode == 401 || statusCode == 403) return CloudStorageErrorType.unauthorized;
    if (statusCode == 404) return CloudStorageErrorType.notFound;
    if (statusCode >= 400 && statusCode < 500) return CloudStorageErrorType.validation;
    if (statusCode >= 500) return CloudStorageErrorType.serverError;
    return CloudStorageErrorType.unknown;
  }

  factory CloudStorageResult.fromApiFailure(int statusCode, String? error) {
    return CloudStorageResult.error(
      type: _mapStatusCode(statusCode),
      message: error ?? 'Operation failed',
      statusCode: statusCode,
    );
  }
}

/// AUDIT FIX #6: Cloud Storage Service — Uses REST API endpoints directly
/// instead of Firestore compat layer. Routes through ApiClient ? API Gateway
/// ? Lambda ? DynamoDB.
///
/// Supports multi-device login with data persistence and cloud backup.
class CloudStorageService {
  ApiClient get _api => sl<ApiClient>();
  static const _secureStorage = FlutterSecureStorage();

  // Cloud sync options
  static const String syncModeLocal = 'local_only';
  static const String syncModeCloud = 'cloud_only';
  static const String syncModeHybrid = 'hybrid'; // Local + Cloud

  /// CRITICAL FIX: Save owner/vendor profile with proper error propagation
  Future<CloudStorageResult<void>> saveOwnerToCloudResult({
    required String ownerId,
    required Map<String, dynamic> ownerData,
  }) async {
    try {
      final res = await _api.put('/vendor-profiles/$ownerId', body: {
        ...ownerData,
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
        'syncStatus': 'synced',
      });
      if (res.isSuccess) {
        developer.log('Owner data saved to cloud: $ownerId', name: 'CloudStorageService');
        return CloudStorageResult.ok(null);
      }
      developer.log('Failed to save owner: ${res.error}', name: 'CloudStorageService');
      return CloudStorageResult.fromApiFailure(res.statusCode, res.error);
    } catch (e) {
      developer.log('Error saving owner to cloud: $e', name: 'CloudStorageService');
      return CloudStorageResult.error(
        type: CloudStorageErrorType.unknown,
        message: e.toString(),
      );
    }
  }

  /// Legacy bool wrapper - prefer saveOwnerToCloudResult for new code
  Future<bool> saveOwnerToCloud({
    required String ownerId,
    required Map<String, dynamic> ownerData,
  }) async {
    final result = await saveOwnerToCloudResult(ownerId: ownerId, ownerData: ownerData);
    return result.success;
  }

  /// CRITICAL FIX: Save customer with proper error propagation
  Future<CloudStorageResult<void>> saveCustomerToCloudResult({
    required String ownerId,
    required Customer customer,
  }) async {
    try {
      final res = await _api.put('/customers/${customer.id}', body: {
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        // CRITICAL FIX: Send cents to match backend API contract
        'totalDues': (customer.totalDues * 100).toInt(),
        'cashDuesCents': (customer.cashDues * 100).toInt(),
        'onlineDuesCents': (customer.onlineDues * 100).toInt(),
        'syncStatus': 'synced',
      });
      if (res.isSuccess) {
        developer.log('Customer saved to cloud: ${customer.id}', name: 'CloudStorageService');
        return CloudStorageResult.ok(null);
      }
      return CloudStorageResult.fromApiFailure(res.statusCode, res.error);
    } catch (e) {
      developer.log('Error saving customer to cloud: $e', name: 'CloudStorageService');
      return CloudStorageResult.error(
        type: CloudStorageErrorType.unknown,
        message: e.toString(),
      );
    }
  }

  /// Legacy bool wrapper - prefer saveCustomerToCloudResult for new code
  Future<bool> saveCustomerToCloud({
    required String ownerId,
    required Customer customer,
  }) async {
    final result = await saveCustomerToCloudResult(ownerId: ownerId, customer: customer);
    return result.success;
  }

  /// Save bill/invoice to cloud via REST API
  Future<bool> saveBillToCloud({
    required String ownerId,
    required Bill bill,
  }) async {
    try {
      // CRITICAL FIX: Convert rupee amounts to cents (int) for backend API
      final subtotal = (bill.subtotal * 100).toInt();
      final paidCents = (bill.paidAmount * 100).toInt();
      final dueCents = subtotal - paidCents;

      final res = await _api.put('/invoices/${bill.id}', body: {
        'id': bill.id,
        'customerId': bill.customerId,
        // CRITICAL FIX: Send cents to match backend API contract
        'subtotal': subtotal,
        'paidCents': paidCents,
        'dueCents': dueCents,
        'items': bill.items.map((e) => _convertItemToCents(e.toMap())).toList(),
        'status': bill.status,
        'date': bill.date.toIso8601String(),
        'syncStatus': 'synced',
      });
      if (res.isSuccess) {
        developer.log('Bill saved to cloud: ${bill.id}', name: 'CloudStorageService');
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Error saving bill to cloud: $e', name: 'CloudStorageService');
      return false;
    }
  }

  /// Helper to convert item price fields to cents for API
  Map<String, dynamic> _convertItemToCents(Map<String, dynamic> item) {
    final converted = Map<String, dynamic>.from(item);
    // Convert price-related fields to cents if they exist
    if (converted['price'] != null) {
      converted['priceCents'] = ((converted['price'] as num) * 100).toInt();
    }
    if (converted['total'] != null) {
      converted['totalCents'] = ((converted['total'] as num) * 100).toInt();
    }
    if (converted['cgst'] != null) {
      converted['cgstCents'] = ((converted['cgst'] as num) * 100).toInt();
    }
    if (converted['sgst'] != null) {
      converted['sgstCents'] = ((converted['sgst'] as num) * 100).toInt();
    }
    if (converted['igst'] != null) {
      converted['igstCents'] = ((converted['igst'] as num) * 100).toInt();
    }
    if (converted['discount'] != null) {
      converted['discountCents'] = ((converted['discount'] as num) * 100).toInt();
    }
    return converted;
  }

  /// Fetch owner/vendor profile data from cloud
  Future<Map<String, dynamic>?> getOwnerFromCloud({
    required String ownerId,
  }) async {
    try {
      final res = await _api.get('/vendor-profiles/$ownerId');
      if (res.isSuccess && res.data != null) {
        developer.log('Owner data fetched from cloud: $ownerId', name: 'CloudStorageService');
        return res.data;
      }
      return null;
    } catch (e) {
      developer.log('Error fetching owner from cloud: $e', name: 'CloudStorageService');
      return null;
    }
  }

  /// Fetch all customers from cloud via REST API
  Future<List<Customer>> getCustomersFromCloud({
    required String ownerId,
  }) async {
    try {
      final res = await _api.get('/customers');
      if (res.isSuccess && res.data != null) {
        final items = res.data!['items'] as List<dynamic>? ??
            res.data!['customers'] as List<dynamic>? ??
            (res.data!['data'] is List ? res.data!['data'] as List<dynamic> : <dynamic>[]);

        final customers = items.map((item) {
          final data = Map<String, dynamic>.from(item);
          return Customer(
            id: data['id'] ?? '',
            name: data['name'] ?? 'Unknown',
            phone: data['phone'] ?? '',
            address: data['address'] ?? '',
            totalDues: (data['totalDues'] ?? data['creditLimit'] ?? 0).toDouble(),
            cashDues: (data['cashDues'] ?? 0).toDouble(),
            onlineDues: (data['onlineDues'] ?? 0).toDouble(),
          );
        }).toList();

        developer.log('Fetched ${customers.length} customers from cloud', name: 'CloudStorageService');
        return customers;
      }
      return [];
    } catch (e) {
      developer.log('Error fetching customers from cloud: $e', name: 'CloudStorageService');
      return [];
    }
  }

  /// Fetch all bills/invoices from cloud via REST API
  Future<List<Bill>> getBillsFromCloud({required String ownerId}) async {
    try {
      final res = await _api.get('/invoices');
      if (res.isSuccess && res.data != null) {
        // CRITICAL FIX: Standardize on 'data' key for list responses
        final items = res.data!['data'] as List<dynamic>? ??
            res.data!['items'] as List<dynamic>? ??
            res.data!['invoices'] as List<dynamic>? ??
            <dynamic>[];

        final bills = items.map((item) {
          final data = Map<String, dynamic>.from(item);
          
          // CRITICAL FIX: Handle both cents (new) and rupees (legacy) from backend
          final subtotal = _extractAmountInRupees(data, 'subtotal', 'subtotal');
          final paidAmount = _extractAmountInRupees(data, 'paidAmount', 'paidCents');
          
          return Bill(
            id: data['id'] ?? '',
            customerId: data['customerId'] ?? data['customer_id'] ?? '',
            date: data['date'] != null || data['createdAt'] != null || data['created_at'] != null
                ? DateTime.parse(data['date'] ?? data['createdAt'] ?? data['created_at'])
                : DateTime.now(),
            items: (data['items'] as List<dynamic>?)
                    ?.map((e) => BillItem.fromMap(Map<String, dynamic>.from(e)))
                    .toList() ??
                [],
            subtotal: subtotal,
            paidAmount: paidAmount,
            status: data['status'] ?? 'Unpaid',
          );
        }).toList();

        developer.log('Fetched ${bills.length} bills from cloud', name: 'CloudStorageService');
        return bills;
      }
      return [];
    } catch (e) {
      developer.log('Error fetching bills from cloud: $e', name: 'CloudStorageService');
      return [];
    }
  }

  /// Helper to extract amount in rupees from backend response (handles both cents and rupees)
  double _extractAmountInRupees(Map<String, dynamic> data, String rupeeKey, String centsKey) {
    // Prefer cents if available (new standard), fall back to rupees (legacy)
    if (data[centsKey] != null) {
      return (data[centsKey] as num).toDouble() / 100;
    }
    if (data[rupeeKey] != null) {
      return (data[rupeeKey] as num).toDouble();
    }
    // Also check totalCents as fallback for subtotal
    if (centsKey == 'subtotal' && data['totalCents'] != null) {
      return (data['totalCents'] as num).toDouble() / 100;
    }
    return 0.0;
  }

  /// Register device for multi-device sync via notifications endpoint
  Future<bool> registerDevice({
    required String ownerId,
    required String deviceId,
    required String deviceName,
  }) async {
    try {
      final res = await _api.post('/notifications/register', body: {
        'fcmToken': deviceId,
        'deviceName': deviceName,
        'platform': _detectPlatform(),
      });
      if (res.isSuccess) {
        developer.log('Device registered for owner: $ownerId', name: 'CloudStorageService');
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Error registering device: $e', name: 'CloudStorageService');
      return false;
    }
  }

  /// Get active devices (sync status via sync endpoint)
  Future<List<Map<String, dynamic>>> getActiveDevices({
    required String ownerId,
  }) async {
    try {
      final res = await _api.get('/sync/devices');
      if (res.isSuccess && res.data != null) {
        final devices = res.data!['devices'] as List<dynamic>? ?? [];
        return devices.map((d) => Map<String, dynamic>.from(d)).toList();
      }
      return [];
    } catch (e) {
      developer.log('Error fetching active devices: $e', name: 'CloudStorageService');
      return [];
    }
  }

  /// Sign out device from cloud sync
  Future<bool> signOutFromCloud({
    required String ownerId,
    required String deviceId,
  }) async {
    try {
      final res = await _api.post('/sync/devices/$deviceId/deactivate');
      if (res.isSuccess) {
        developer.log('Device signed out from cloud: $ownerId', name: 'CloudStorageService');
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Error signing out from cloud: $e', name: 'CloudStorageService');
      return false;
    }
  }

  /// Get sync status via sync endpoint
  Future<Map<String, String>> getSyncStatus({required String ownerId}) async {
    try {
      final res = await _api.get('/sync/status');
      if (res.isSuccess && res.data != null) {
        return {
          'owner': res.data!['ownerStatus']?.toString() ?? 'unknown',
          'customers': res.data!['customersStatus']?.toString() ?? 'unknown',
          'bills': res.data!['billsStatus']?.toString() ?? 'unknown',
          'lastSyncedAt': res.data!['lastSyncedAt']?.toString() ?? '',
        };
      }
      return {'error': 'Failed to get sync status'};
    } catch (e) {
      developer.log('Error getting sync status: $e', name: 'CloudStorageService');
      return {'error': 'Failed to get sync status'};
    }
  }

  /// Enable cloud sync
  Future<bool> enableCloudSync({required String ownerId}) async {
    try {
      await _secureStorage.write(key: 'cloud_sync_enabled', value: 'true');
      developer.log('Cloud sync enabled for owner: $ownerId', name: 'CloudStorageService');
      return true;
    } catch (e) {
      developer.log('Error enabling cloud sync: $e', name: 'CloudStorageService');
      return false;
    }
  }

  /// Disable cloud sync
  Future<bool> disableCloudSync({required String ownerId}) async {
    try {
      await _secureStorage.write(key: 'cloud_sync_enabled', value: 'false');
      developer.log('Cloud sync disabled for owner: $ownerId', name: 'CloudStorageService');
      return true;
    } catch (e) {
      developer.log('Error disabling cloud sync: $e', name: 'CloudStorageService');
      return false;
    }
  }

  /// Check if cloud sync is enabled
  Future<bool> isCloudSyncEnabled({required String ownerId}) async {
    try {
      final value = await _secureStorage.read(key: 'cloud_sync_enabled');
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  String _detectPlatform() {
    // Platform detection for device registration
    return 'windows'; // Default — override based on Platform checks in caller
  }
}
