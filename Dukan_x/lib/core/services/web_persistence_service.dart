// Platform-agnostic web persistence interface
// On web: uses localStorage (simple fallback)
// On mobile: stub that returns empty (Hive handles it)

import 'package:flutter/foundation.dart' show kIsWeb;

/// Simple web persistence service using JSON in localStorage
/// This is a fallback for web platform when Hive is not available
class WebPersistenceService {
  static final WebPersistenceService _instance =
      WebPersistenceService._internal();
  factory WebPersistenceService() => _instance;
  WebPersistenceService._internal();

  bool _initialized = false;

  // In-memory cache that syncs with Firestore on web
  // Web platform primarily uses Firestore, this is just for session cache
  final Map<String, Map<String, Map<String, dynamic>>> _cache = {};

  bool get isReady => _initialized;

  Future<void> init() async {
    if (!kIsWeb) {
      // On mobile, Hive handles persistence
      _initialized = false;
      return;
    }

    // Initialize cache stores
    _cache['customers'] = {};
    _cache['bills'] = {};
    _cache['payments'] = {};
    _cache['vegetables'] = {};
    _cache['settings'] = {};

    _initialized = true;
  }

  Future<void> put(
    String storeName,
    String key,
    Map<String, dynamic> data,
  ) async {
    if (!_initialized) return;
    _cache[storeName]?[key] = Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> get(String storeName, String key) async {
    if (!_initialized) return null;
    return _cache[storeName]?[key];
  }

  Future<List<Map<String, dynamic>>> getAll(String storeName) async {
    if (!_initialized) return [];
    return _cache[storeName]?.values.toList() ?? [];
  }

  Future<void> delete(String storeName, String key) async {
    if (!_initialized) return;
    _cache[storeName]?.remove(key);
  }

  Future<void> clear(String storeName) async {
    if (!_initialized) return;
    _cache[storeName]?.clear();
  }

  Future<int> count(String storeName) async {
    if (!_initialized) return 0;
    return _cache[storeName]?.length ?? 0;
  }

  // ==================== SPECIALIZED METHODS ====================

  Future<void> saveCustomer(Map<String, dynamic> customer) async {
    final id =
        customer['id']?.toString() ?? customer['phone']?.toString() ?? '';
    if (id.isEmpty) return;
    await put('customers', id, customer);
  }

  Future<void> saveBill(Map<String, dynamic> bill) async {
    final id = bill['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await put('bills', id, bill);
  }

  Future<void> savePayment(Map<String, dynamic> payment) async {
    final id = payment['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await put('payments', id, payment);
  }

  Future<List<Map<String, dynamic>>> getBillsForCustomer(
    String customerId,
  ) async {
    final allBills = await getAll('bills');
    return allBills.where((b) => b['customerId'] == customerId).toList();
  }

  Future<void> setSetting(String key, dynamic value) async {
    await put('settings', key, {'key': key, 'value': value});
  }

  Future<T?> getSetting<T>(String key) async {
    final result = await get('settings', key);
    if (result == null) return null;
    try {
      return result['value'] as T?;
    } catch (e) {
      return null;
    }
  }
}
