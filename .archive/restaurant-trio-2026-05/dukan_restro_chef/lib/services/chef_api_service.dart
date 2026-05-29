import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chef_models.dart';

class ChefApiService {
  static const String _apiOrigin = String.fromEnvironment(
    'DUKANX_API_URL',
    defaultValue: 'https://api.dukanx.com',
  );
  static const _timeout = Duration(seconds: 12);

  static String get _restoBase => '$_apiOrigin/resto';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('staff_token') ?? '';
    final businessId =
        prefs.getString('pos_vendor_id') ?? prefs.getString('vendor_id') ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (businessId.isNotEmpty) 'X-Business-Id': businessId,
    };
  }

  static Future<List<ChefKot>> fetchActiveKots() async {
    try {
      final uri = Uri.parse('$_restoBase/kds/aging-alerts?slaMinutes=15');
      final res = await http.get(uri, headers: await _headers()).timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final alerts = (body['alerts'] as List? ?? []).cast<Map<String, dynamic>>();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final a in alerts) {
        final kotId = (a['kotId'] ?? '').toString();
        if (kotId.isEmpty) continue;
        grouped.putIfAbsent(kotId, () => []).add(a);
      }
      return grouped.entries.map((entry) {
        final items = entry.value
            .map(
              (x) => ChefKotItem(
                id: (x['itemId'] ?? '').toString(),
                name: (x['menuItemName'] ?? 'Item').toString(),
                qty: 1,
                status: (x['itemStatus'] ?? 'pending').toString(),
                ageMinutes: ((x['ageMinutes'] ?? 0) as num).round(),
              ),
            )
            .toList();
        final hasPriority = items.any(
          (i) => i.name.toLowerCase().contains('priority') || i.ageMinutes > 25,
        );
        return ChefKot(
          id: entry.key,
          tableLabel: 'Table ?',
          priority: hasPriority,
          createdAt: DateTime.now().subtract(
            Duration(minutes: items.isEmpty ? 0 : items.first.ageMinutes),
          ),
          items: items,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> updateItemStatus({
    required String kotId,
    required String itemId,
    required String status,
  }) async {
    try {
      final uri = Uri.parse('$_restoBase/kot/$kotId/items/$itemId/status');
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

  static Future<bool> markItemUnavailable(String menuItemId) async {
    try {
      final uri = Uri.parse('$_restoBase/menu/items/$menuItemId');
      final res = await http
          .put(
            uri,
            headers: await _headers(),
            body: jsonEncode({'isOutOfStock': true}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
