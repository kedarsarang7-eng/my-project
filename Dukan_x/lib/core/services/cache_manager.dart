// ============================================================================
// ENTERPRISE CACHE MANAGER
// ============================================================================
// Memory and disk caching with TTL for enterprise performance.
// Auto-invalidates on sync events.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'dart:collection';

/// Cache entry with expiration
class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  final String? tag;

  CacheEntry(this.value, this.expiresAt, {this.tag});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Enterprise Cache Manager
///
/// Features:
/// - L1: In-memory cache (hot data)
/// - TTL-based expiration
/// - Tag-based invalidation (for sync events)
/// - LRU eviction when memory limit reached
///
/// Usage:
/// ```dart
/// CacheManager.set('products_list', products, ttl: Duration(minutes: 5));
/// final cached = CacheManager.get<List<Product>>('products_list');
/// CacheManager.invalidateByTag('products'); // On sync
/// ```
class CacheManager {
  CacheManager._();

  // Memory cache with LRU ordering
  static final LinkedHashMap<String, CacheEntry<dynamic>> _memoryCache =
      LinkedHashMap<String, CacheEntry<dynamic>>();

  // Maximum cache entries (to prevent memory bloat)
  static const int _maxCacheEntries = 100;

  // Default TTL
  static const Duration _defaultTtl = Duration(minutes: 5);

  // ============================================================================
  // CORE OPERATIONS
  // ============================================================================

  /// Get cached value, returns null if expired or not found
  static T? get<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }

    // Move to end (LRU)
    _memoryCache.remove(key);
    _memoryCache[key] = entry;

    return entry.value as T?;
  }

  /// Get cached value or compute and cache if missing
  static Future<T> getOrCompute<T>(
    String key,
    Future<T> Function() compute, {
    Duration ttl = _defaultTtl,
    String? tag,
  }) async {
    final cached = get<T>(key);
    if (cached != null) return cached;

    final value = await compute();
    set(key, value, ttl: ttl, tag: tag);
    return value;
  }

  /// Get cached value synchronously or compute and cache if missing
  static T getOrComputeSync<T>(
    String key,
    T Function() compute, {
    Duration ttl = _defaultTtl,
    String? tag,
  }) {
    final cached = get<T>(key);
    if (cached != null) return cached;

    final value = compute();
    set(key, value, ttl: ttl, tag: tag);
    return value;
  }

  /// Set value with optional TTL and tag
  static void set<T>(
    String key,
    T value, {
    Duration ttl = _defaultTtl,
    String? tag,
  }) {
    // Evict oldest if at capacity
    while (_memoryCache.length >= _maxCacheEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }

    _memoryCache[key] = CacheEntry(value, DateTime.now().add(ttl), tag: tag);
  }

  /// Remove specific key
  static void remove(String key) {
    _memoryCache.remove(key);
  }

  /// Check if key exists and is not expired
  static bool contains(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _memoryCache.remove(key);
      return false;
    }
    return true;
  }

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  /// Invalidate all entries with specified tag
  static void invalidateByTag(String tag) {
    _memoryCache.removeWhere((_, entry) => entry.tag == tag);
  }

  /// Invalidate entries matching prefix
  static void invalidateByPrefix(String prefix) {
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all expired entries
  static void clearExpired() {
    _memoryCache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Clear entire cache
  static void clear() {
    _memoryCache.clear();
  }

  // ============================================================================
  // SYNC INTEGRATION
  // ============================================================================

  /// Invalidate cache when sync events occur
  /// Call this from SyncManager when data changes
  static void onSyncEvent(String collection, String operation) {
    // Map collection names to cache tags
    final tag = _collectionToTag(collection);
    if (tag != null) {
      invalidateByTag(tag);
      invalidateByPrefix('${collection}_');
    }
  }

  static String? _collectionToTag(String collection) {
    return switch (collection) {
      'products' => 'products',
      'customers' => 'customers',
      'bills' => 'bills',
      'invoices' => 'invoices',
      'expenses' => 'expenses',
      'payments' => 'payments',
      _ => collection,
    };
  }

  // ============================================================================
  // DIAGNOSTICS
  // ============================================================================

  /// Get cache statistics
  static CacheStats getStats() {
    int expiredCount = 0;
    int validCount = 0;

    for (final entry in _memoryCache.values) {
      if (entry.isExpired) {
        expiredCount++;
      } else {
        validCount++;
      }
    }

    return CacheStats(
      totalEntries: _memoryCache.length,
      validEntries: validCount,
      expiredEntries: expiredCount,
      maxEntries: _maxCacheEntries,
    );
  }
}

/// Cache statistics
class CacheStats {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;
  final int maxEntries;

  const CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
    required this.maxEntries,
  });

  double get utilizationPercent => (totalEntries / maxEntries) * 100;

  @override
  String toString() =>
      'CacheStats(valid: $validEntries, expired: $expiredEntries, '
      'total: $totalEntries/$maxEntries)';
}

/// Typed cache wrapper for specific data types
class TypedCache<T> {
  final String prefix;
  final Duration defaultTtl;

  TypedCache(this.prefix, {this.defaultTtl = const Duration(minutes: 5)});

  T? get(String key) => CacheManager.get<T>('${prefix}_$key');

  void set(String key, T value, {Duration? ttl}) {
    CacheManager.set(
      '${prefix}_$key',
      value,
      ttl: ttl ?? defaultTtl,
      tag: prefix,
    );
  }

  Future<T> getOrCompute(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) {
    return CacheManager.getOrCompute<T>(
      '${prefix}_$key',
      compute,
      ttl: ttl ?? defaultTtl,
      tag: prefix,
    );
  }

  void remove(String key) => CacheManager.remove('${prefix}_$key');

  void clear() => CacheManager.invalidateByTag(prefix);
}
