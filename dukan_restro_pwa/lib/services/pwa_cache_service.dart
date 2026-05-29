// ============================================================================
// PWA CACHE SERVICE (Hive) — Caches menu for offline viewing
// ============================================================================
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'pwa_api_service.dart';

class PwaCacheService {
  static const _boxName = 'pwa_menu_cache';
  static Box? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> cacheMenu(String vendorId, List<PwaCategory> menu) async {
    if (_box == null) await init();

    final dataList = menu
        .map(
          (c) => {
            'id': c.id,
            'name': c.name,
            'imageEmoji': c.imageEmoji,
            'items': c.items
                .map(
                  (i) => {
                    'id': i.id,
                    'name': i.name,
                    'price': i.price,
                    'isVeg': i.isVeg,
                    'description': i.description,
                    'variations': i.variations,
                  },
                )
                .toList(),
          },
        )
        .toList();

    await _box!.put(vendorId, jsonEncode(dataList));
  }

  static Future<List<PwaCategory>?> getCachedMenu(String vendorId) async {
    if (_box == null) await init();

    final jsonStr = _box!.get(vendorId) as String?;
    if (jsonStr == null) return null;

    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => PwaCategory.fromJson(e)).toList();
    } catch (_) {
      return null;
    }
  }
}
