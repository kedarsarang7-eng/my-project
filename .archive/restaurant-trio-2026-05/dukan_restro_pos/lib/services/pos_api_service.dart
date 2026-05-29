// ============================================================================
// POS API SERVICE — Real HTTP client with SQLite Offline Fallback
// ============================================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/pos_table.dart';
import '../models/pos_menu_item.dart';
import 'local_db_service.dart';

class PosApiService {
  /// Same API Gateway as Dukan_x my-backend. Override:
  /// `--dart-define=DUKANX_API_URL=https://api.dukanx.com`
  static const String _apiOrigin = String.fromEnvironment(
    'DUKANX_API_URL',
    defaultValue: 'https://api.dukanx.com',
  );

  static String get _base => '$_apiOrigin/resto';
  static const _timeout = Duration(seconds: 10);

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('staff_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    final prefs = await SharedPreferences.getInstance();
    final businessId =
        prefs.getString('pos_vendor_id') ?? prefs.getString('vendor_id');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (businessId != null && businessId.isNotEmpty) 'X-Business-Id': businessId,
    };
  }

  static Future<bool> _isOnline() async {
    final res = await Connectivity().checkConnectivity();
    return res != ConnectivityResult.none;
  }

  // ── Auth ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> staffLogin(
    String vendorId,
    String staffName,
  ) async {
    try {
      if (!await _isOnline()) throw Exception('Offline');
      final res = await http
          .post(
            Uri.parse('$_apiOrigin/api/v1/restaurant/auth/staff-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'vendorId': vendorId, 'staffName': staffName}),
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('staff_token', data['token']);
        await prefs.setString('vendor_id', data['vendorId']);
        await prefs.setString('staff_name', data['staffName']);
        return data;
      }
    } catch (_) {}
    return null; // Login requires network
  }

  // ── Tables ──────────────────────────────────────────────────────────────────
  static Future<List<PosTable>> fetchTables(String vendorId) async {
    if (await _isOnline()) {
      try {
        final uri = Uri.parse('$_base/tables');
        final res = await http
            .get(uri, headers: await _headers())
            .timeout(_timeout);
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List;
          final tables = list
              .map(
                (e) => PosTable(
                  id: e['id']?.toString() ?? '',
                  number: (e['name'] ?? e['tableNumber'] ?? '').toString(),
                  status: _mapTableStatus((e['status'] ?? '').toString()),
                  floor: (e['floorName'] ?? e['floor'] ?? '').toString(),
                  capacity:
                      ((e['seatingCapacity'] ?? e['capacity'] ?? 4) as num)
                          .toInt(),
                  currentOrderId:
                      (e['currentBillId'] ?? e['currentOrderId'])?.toString(),
                ),
              )
              .toList();
          await LocalDbService.cacheTables(tables); // Cache for offline
          return tables;
        }
      } catch (_) {}
    }
    // Fallback to SQLite cache
    return await LocalDbService.getCachedTables();
  }

  static Future<bool> updateTableStatus(
    String tableId,
    PosTableStatus status,
  ) async {
    if (!await _isOnline()) return false;
    try {
      final uri = Uri.parse('$_base/tables/$tableId');
      final res = await http
          .put(
            uri,
            headers: await _headers(),
            body: jsonEncode({'status': _toBackendTableStatus(status)}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Menu ─────────────────────────────────────────────────────────────────────
  static Future<List<PosCategory>> fetchMenu(String vendorId) async {
    if (await _isOnline()) {
      try {
        final uri = Uri.parse('$_base/menu');
        final res = await http
            .get(uri, headers: await _headers())
            .timeout(_timeout);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final categories = (data['categories'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final items =
              (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
          final itemsByCategory = <String, List<PosMenuItem>>{};

          for (final item in items) {
            final categoryId = (item['categoryId'] ?? '').toString();
            final row = PosMenuItem(
              id: (item['id'] ?? '').toString(),
              name: (item['name'] ?? '').toString(),
              price:
                  ((item['salePriceCents'] ?? item['priceCents'] ?? 0) as num)
                          .toDouble() /
                      100,
              category: categoryId,
              isVeg: (item['isVeg'] ?? true) as bool,
              isAvailable: !(item['isOutOfStock'] == true),
              description: (item['description'] ?? '').toString(),
              imageUrl: item['imageUrl']?.toString(),
              variations: _extractVariationNames(item['variations']),
              addons: const [],
            );
            itemsByCategory.putIfAbsent(categoryId, () => []).add(row);
          }

          final cats = categories.map((cat) {
            final id = (cat['id'] ?? '').toString();
            return PosCategory(
              id: id,
              name: (cat['name'] ?? '').toString(),
              items: itemsByCategory[id] ?? const [],
            );
          }).toList();
          if (cats.isEmpty && itemsByCategory.isNotEmpty) {
            final allItems = itemsByCategory.values.expand((x) => x).toList();
            cats.add(PosCategory(id: 'default', name: 'Menu', items: allItems));
          }
          await LocalDbService.cacheMenu(cats); // Cache for offline
          return cats;
        }
      } catch (_) {}
    }
    // Fallback to SQLite cache
    return await LocalDbService.getCachedMenu();
  }

  // ── KOTs ────────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchActiveKots(
    String vendorId,
  ) async {
    if (!await _isOnline()) return [];
    try {
      final uri = Uri.parse('$_base/kds/aging-alerts?slaMinutes=20');
      final res = await http
          .get(uri, headers: await _headers())
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final alerts =
            (data['alerts'] as List? ?? []).cast<Map<String, dynamic>>();
        final grouped = <String, List<Map<String, dynamic>>>{};

        for (final item in alerts) {
          final kotId = (item['kotId'] ?? '').toString();
          if (kotId.isEmpty) continue;
          grouped.putIfAbsent(kotId, () => []).add(item);
        }

        return grouped.entries.map((entry) {
          final first = entry.value.first;
          return {
            'id': entry.key,
            'kotNumber': entry.key.substring(0, 6).toUpperCase(),
            'tableNumber': '?',
            'status': (first['itemStatus'] ?? 'pending').toString(),
            'createdAt': DateTime.now().toIso8601String(),
            'items': entry.value
                .map(
                  (x) => {
                    'id': x['itemId'],
                    'itemName': x['menuItemName'] ?? 'Item',
                    'qty': 1,
                    'status': x['itemStatus'] ?? 'pending',
                  },
                )
                .toList(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> postKot(Map<String, dynamic> kotData) async {
    if (await _isOnline()) {
      try {
        final uri = Uri.parse('$_base/kot');
        final payload = {
          'orderType': 'dine_in',
          'tableId': kotData['tableId'],
          'waiterId': null,
          'items': (kotData['items'] as List? ?? [])
              .map(
                (i) => {
                  'menuItemId': i['menuItemId'],
                  'quantity': i['qty'] ?? 1,
                  'notes': i['specialInstructions'],
                },
              )
              .toList(),
        };
        final res = await http
            .post(uri, headers: await _headers(), body: jsonEncode(payload))
            .timeout(_timeout);

        if (res.statusCode == 201 || res.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }

    // OFFLINE: Queue it in SQLite
    final kotId = DateTime.now().millisecondsSinceEpoch.toString();
    await LocalDbService.saveOfflineKot(kotId, kotData);
    return false; // Returns true if sent, false if queued offline
  }

  static Future<bool> updateKotItemStatus(
    String kotId,
    String itemId,
    String status,
  ) async {
    if (!await _isOnline()) return false;
    try {
      final uri = Uri.parse('$_base/kot/$kotId/items/$itemId/status');
      final res = await http
          .put(
            uri,
            headers: await _headers(),
            body: jsonEncode({'itemStatus': status}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static PosTableStatus _mapTableStatus(String value) {
    switch (value.toLowerCase()) {
      case 'occupied':
        return PosTableStatus.occupied;
      case 'reserved':
        return PosTableStatus.reserved;
      case 'cleaning':
      case 'dirty':
        return PosTableStatus.dirty;
      case 'bill_requested':
        return PosTableStatus.bill_requested;
      case 'available':
      default:
        return PosTableStatus.free;
    }
  }

  static String _toBackendTableStatus(PosTableStatus status) {
    switch (status) {
      case PosTableStatus.occupied:
        return 'occupied';
      case PosTableStatus.reserved:
        return 'reserved';
      case PosTableStatus.dirty:
        return 'cleaning';
      case PosTableStatus.bill_requested:
        return 'occupied';
      case PosTableStatus.free:
        return 'available';
    }
  }

  static List<String> _extractVariationNames(dynamic input) {
    if (input is List) {
      return input
          .map((v) {
            if (v is String) return v;
            if (v is Map<String, dynamic>) {
              return (v['name'] ?? '').toString();
            }
            return '';
          })
          .where((v) => v.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
