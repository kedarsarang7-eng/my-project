// ============================================================================
// CartCacheService — Offline Hive cache for in-store cart
// ============================================================================
// Persists cart items + session ID locally so the customer can recover their
// cart if the app is killed mid-session (poor connectivity, etc.).
//
// Box layout (Hive, non-encrypted):
//   'in_store_session_id'  → String   (active session ID)
//   'in_store_cart_items'  → String   (JSON-encoded List<CartItem>)
//   'in_store_store_id'    → String   (store identifier)
//   'in_store_saved_at'    → int      (Unix ms — staleness guard)
//
// TTL: 6 hours — older entries are discarded on read.
// ============================================================================

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/in_store_models.dart';

class CartCacheService {
  static const _boxName = 'in_store_cart';
  static const _keySessionId = 'in_store_session_id';
  static const _keyCartItems = 'in_store_cart_items';
  static const _keyStoreId = 'in_store_store_id';
  static const _keySavedAt = 'in_store_saved_at';
  static const _ttlMs = 6 * 60 * 60 * 1000; // 6 hours

  static Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Persist the full cart state.
  Future<void> saveCart({
    required String sessionId,
    required String storeId,
    required List<CartItem> items,
  }) async {
    final box = await _box();
    final itemsJson =
        jsonEncode(items.map((e) => e.toJson()).toList());
    await box.putAll({
      _keySessionId: sessionId,
      _keyStoreId: storeId,
      _keyCartItems: itemsJson,
      _keySavedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the cached session ID if within TTL, otherwise null.
  Future<String?> getCachedSessionId() async {
    final box = await _box();
    if (_isStale(box)) return null;
    return box.get(_keySessionId) as String?;
  }

  /// Returns cached cart items if the session matches and within TTL.
  Future<List<CartItem>> getCachedItems(String sessionId) async {
    final box = await _box();
    if (_isStale(box)) return [];

    final cachedSession = box.get(_keySessionId) as String?;
    if (cachedSession != sessionId) return [];

    final raw = box.get(_keyCartItems) as String?;
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns the storeId for the cached session.
  Future<String?> getCachedStoreId() async {
    final box = await _box();
    if (_isStale(box)) return null;
    return box.get(_keyStoreId) as String?;
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  /// Clear all cached cart data (call on session end / payment success).
  Future<void> clearCart() async {
    final box = await _box();
    await box.deleteAll(
      [_keySessionId, _keyStoreId, _keyCartItems, _keySavedAt],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isStale(Box box) {
    final savedAt = box.get(_keySavedAt) as int?;
    if (savedAt == null) return true;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    return age > _ttlMs;
  }
}
