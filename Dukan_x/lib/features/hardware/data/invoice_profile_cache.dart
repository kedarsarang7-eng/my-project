// =============================================================================
// INVOICE PROFILE LOCAL CACHE (HARDWARE-021 / Task 3.19)
// =============================================================================
// Caches invoice profiles to SharedPreferences so they can be served offline.
//
// Strategy:
//   - On successful API load → save JSON-encoded profiles to SharedPreferences
//   - On successful API save → update the local cache with the new profiles
//   - When offline (API fails) → return cached data if available
//
// Uses a simple JSON string in SharedPreferences (profiles are small, typically
// 1–5 entries with a handful of boolean fields each).
// =============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache for hardware invoice profiles using SharedPreferences.
///
/// Stores the full profiles payload (including defaultProfileId) as a
/// JSON-encoded string. This is lightweight and sufficient for the small
/// profile dataset (typically 1–5 profiles).
class InvoiceProfileCache {
  /// SharedPreferences key for the cached invoice profiles data.
  static const String _cacheKey = 'hardware_invoice_profiles_cache';

  /// Save invoice profile data to local cache.
  ///
  /// Called after a successful API load or save to keep the cache fresh.
  Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data);
    await prefs.setString(_cacheKey, jsonStr);
  }

  /// Load invoice profile data from local cache.
  ///
  /// Returns `null` if no cached data exists (first-time use or cleared cache).
  /// Returns the cached `Map<String, dynamic>` with 'defaultProfileId' and
  /// 'profiles' keys if data is available.
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      // Corrupted cache data — treat as missing
      return null;
    }
  }

  /// Clear the cached invoice profiles.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
