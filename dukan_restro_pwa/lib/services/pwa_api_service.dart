// ============================================================================
// PWA API SERVICE — Real HTTP client for Customer PWA
// Single backend: Dukan_x/my-backend (API Gateway). Set at build time:
//   --dart-define=DUKANX_API_URL=https://api.dukanx.com
//
// Auth (P0-02 fix, 2026-05):
// On QR scan we call GET /api/v1/restaurant/scan?v=&t= which issues a
// 60-min table-scoped JWT. That token is cached in memory and sent as
// Authorization: Bearer on POST /orders. The previous client-side
// RESTO_V1_ORDER_KEY shared secret is gone — it was extractable from
// the JS bundle and allowed forging orders.
// ============================================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pwa_cache_service.dart';

class PwaApiService {
  /// API Gateway origin only (no path suffix).
  static const String _apiOrigin = String.fromEnvironment(
    'DUKANX_API_URL',
    defaultValue: 'https://api.dukanx.com',
  );

  static String get _base => '$_apiOrigin/api/v1/restaurant';

  static const _timeout = Duration(seconds: 10);

  // ── Table-scan token cache (in-memory, per-tab) ─────────────────────────────
  // Key = "$vendorId:$tableId". Value = (token, expiresAtEpochSec).
  static final Map<String, _ScanToken> _tokens = {};

  static String _key(String v, String t) => '$v:$t';

  /// Fetches (or returns cached) table-scoped JWT.
  /// Call once after QR scan; reuse across the session.
  static Future<String?> ensureTableToken({
    required String vendorId,
    required String tableId,
    bool forceRefresh = false,
  }) async {
    if (vendorId.isEmpty || tableId.isEmpty) return null;
    final cached = _tokens[_key(vendorId, tableId)];
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Refresh 2 minutes before expiry to avoid edge races.
    if (!forceRefresh && cached != null && cached.expiresAtSec - nowSec > 120) {
      return cached.token;
    }
    if (!await _isOnline()) return cached?.token; // best-effort offline
    try {
      final uri = Uri.parse(
        '$_base/scan?v=${Uri.encodeQueryComponent(vendorId)}&t=${Uri.encodeQueryComponent(tableId)}',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final token = m['token'] as String?;
        final ttl = (m['expiresIn'] as num?)?.toInt() ?? 3600;
        if (token != null && token.isNotEmpty) {
          _tokens[_key(vendorId, tableId)] = _ScanToken(
            token: token,
            expiresAtSec: nowSec + ttl,
          );
          return token;
        }
      }
    } catch (_) {}
    return cached?.token;
  }

  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  static Map<String, String> _jsonHeaders({String? bearer}) => {
    'Content-Type': 'application/json',
    if (bearer != null && bearer.isNotEmpty) 'Authorization': 'Bearer $bearer',
  };

  // ── Vendor info ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchVendorInfo(String vendorId) async {
    if (!await _isOnline()) return {'error': 'Offline'};
    try {
      final uri = Uri.parse('$_base/vendor/$vendorId/info');
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return {'error': 'Failed to load vendor'};
  }

  // ── Menu ─────────────────────────────────────────────────────────────────────
  static Future<List<PwaCategory>> fetchMenu(String vendorId) async {
    if (await _isOnline()) {
      try {
        final uri = Uri.parse('$_base/menu?vendorId=$vendorId');
        final res = await http.get(uri).timeout(_timeout);
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List;
          final menu = list.map((e) => PwaCategory.fromJson(e as Map<String, dynamic>)).toList();
          await PwaCacheService.cacheMenu(vendorId, menu);
          return menu;
        }
      } catch (_) {}
    }
    return await PwaCacheService.getCachedMenu(vendorId) ?? [];
  }

  // ── Order placement ──────────────────────────────────────────────
  /// P0-02: Sends Authorization: Bearer <table-JWT>. Server resolves prices
  /// authoritatively — client only sends {menuItemId, qty, note}.
  /// Returns the orderId on success.
  static Future<String?> placeOrder({
    required String vendorId,
    required String tableId,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? phone,
  }) async {
    if (!await _isOnline()) return null;

    Future<http.Response?> attempt(String? bearer) async {
      try {
        final uri = Uri.parse('$_base/orders');
        return await http
            .post(
              uri,
              headers: _jsonHeaders(bearer: bearer),
              body: jsonEncode({
                'vendorId': vendorId,
                'tableId': tableId,
                'items': items,
                'customerName': customerName,
                'phone': phone,
              }),
            )
            .timeout(_timeout);
      } catch (_) {
        return null;
      }
    }

    var token = await ensureTableToken(vendorId: vendorId, tableId: tableId);
    var res = await attempt(token);

    // Auto-refresh once on 401 (token expired between scan and order).
    if (res != null && res.statusCode == 401) {
      token = await ensureTableToken(
        vendorId: vendorId,
        tableId: tableId,
        forceRefresh: true,
      );
      res = await attempt(token);
    }

    if (res != null && (res.statusCode == 201 || res.statusCode == 200)) {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      return m['orderId'] as String?;
    }
    return null;
  }

  // ── Order tracking ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchOrderStatus(
    String vendorId,
    String orderId,
  ) async {
    if (!await _isOnline()) return null;
    try {
      final uri = Uri.parse(
        '$_base/orders/$orderId?vendorId=$vendorId',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Live bill ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchBill({
    required String vendorId,
    required String tableId,
  }) async {
    if (!await _isOnline()) return null;
    try {
      final uri = Uri.parse(
        '$_base/bill?vendorId=$vendorId&tableId=$tableId',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

class _ScanToken {
  final String token;
  final int expiresAtSec;
  const _ScanToken({required this.token, required this.expiresAtSec});
}

class PwaMenuItem {
  final String id, name, description;
  final double price;
  final bool isVeg;
  final List<String> variations;

  const PwaMenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.isVeg,
    this.description = '',
    this.variations = const [],
  });

  factory PwaMenuItem.fromJson(Map<String, dynamic> j) => PwaMenuItem(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    price: (j['price'] ?? 0).toDouble(),
    isVeg: j['isVeg'] ?? true,
    description: j['description'] ?? '',
    variations: List<String>.from(j['variations'] ?? []),
  );
}

class PwaCategory {
  final String id, name, imageEmoji;
  final List<PwaMenuItem> items;

  const PwaCategory({
    required this.id,
    required this.name,
    required this.items,
    this.imageEmoji = '🍽️',
  });

  factory PwaCategory.fromJson(Map<String, dynamic> j) => PwaCategory(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    imageEmoji: j['imageEmoji'] ?? '🍽️',
    items: (j['items'] as List? ?? [])
        .map((e) => PwaMenuItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
