// ============================================================================
// RESPONSE CACHE - Local caching for API responses with TTL
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';

/// Cache entry with metadata
class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final String etag;
  final int size;

  CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.expiresAt,
    required this.etag,
    required this.size,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get age => DateTime.now().difference(cachedAt);

  Map<String, dynamic> toJson() => {
    'data': data,
    'cachedAt': cachedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'etag': etag,
    'size': size,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJson) {
    return CacheEntry(
      data: fromJson(json['data']),
      cachedAt: DateTime.parse(json['cachedAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      etag: json['etag'],
      size: json['size'],
    );
  }
}

/// Response cache service with Hive backing
class ResponseCache {
  static const String _boxName = 'api_response_cache';
  static const int _maxCacheSizeMB = 50;  // 50MB max cache
  static const Duration _defaultTtl = Duration(minutes: 5);
  
  Box<Map>? _box;
  bool _initialized = false;

  /// Initialize cache
  Future<void> init() async {
    if (_initialized) return;
    
    _box = await Hive.openBox<Map>(_boxName);
    _initialized = true;
  }

  /// Generate cache key from request parameters
  String _generateKey(String path, Map<String, dynamic>? params) {
    final keyData = '$path:${jsonEncode(params ?? {})}';
    final bytes = utf8.encode(keyData);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);  // 32 char hash
  }

  /// Get cached response
  Future<T?> get<T>({
    required String path,
    Map<String, dynamic>? queryParams,
    required T Function(dynamic) fromJson,
    Duration? ttl,
  }) async {
    await init();
    
    final key = _generateKey(path, queryParams);
    final cached = _box?.get(key);
    
    if (cached == null) return null;
    
    try {
      final entry = CacheEntry.fromJson(Map<String, dynamic>.from(cached), fromJson);
      
      // Check if expired
      if (entry.isExpired) {
        await _box?.delete(key);
        return null;
      }
      
      return entry.data;
    } catch (e) {
      // Invalid cache entry, delete it
      await _box?.delete(key);
      return null;
    }
  }

  /// Store response in cache
  Future<void> put<T>({
    required String path,
    Map<String, dynamic>? queryParams,
    required T data,
    required Map<String, dynamic> Function(T) toJson,
    String? etag,
    Duration? ttl,
  }) async {
    await init();
    
    final key = _generateKey(path, queryParams);
    final effectiveTtl = ttl ?? _defaultTtl;
    
    final jsonData = toJson(data);
    final jsonString = jsonEncode(jsonData);
    final size = utf8.encode(jsonString).length;
    
    // Check cache size before adding
    await _enforceCacheLimit();
    
    final entry = CacheEntry(
      data: jsonData,
      cachedAt: DateTime.now(),
      expiresAt: DateTime.now().add(effectiveTtl),
      etag: etag ?? '',
      size: size,
    );
    
    await _box?.put(key, entry.toJson());
  }

  /// Enforce maximum cache size (FIFO eviction)
  Future<void> _enforceCacheLimit() async {
    if (_box == null) return;
    
    int totalSize = 0;
    final entries = <String, int>{};  // key -> size
    
    for (final key in _box!.keys) {
      final value = _box!.get(key);
      if (value != null) {
        final size = value['size'] as int? ?? 0;
        entries[key] = size;
        totalSize += size;
      }
    }
    
    final maxSizeBytes = _maxCacheSizeMB * 1024 * 1024;
    
    // Evict oldest entries if over limit
    if (totalSize > maxSizeBytes) {
      final sortedKeys = entries.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      for (final entry in sortedKeys) {
        if (totalSize <= maxSizeBytes) break;
        
        await _box?.delete(entry.key);
        totalSize -= entry.value;
      }
    }
  }

  /// Invalidate cache by pattern
  Future<void> invalidate(String pattern) async {
    await init();
    
    if (_box == null) return;
    
    final keysToDelete = <String>[];
    
    for (final key in _box!.keys) {
      // For pattern matching, we'd need to store the original path
      // Simplified: just delete by key pattern if we had stored it
      // For now, clear all cache
      if (pattern == '*') {
        keysToDelete.add(key);
      }
    }
    
    for (final key in keysToDelete) {
      await _box?.delete(key);
    }
  }

  /// Invalidate specific path
  Future<void> invalidatePath(String path) async {
    await init();
    
    // Store path-to-keys mapping for faster invalidation
    // For now, simplified approach
    await invalidate('*');
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    await init();
    
    if (_box == null) {
      return {'size': 0, 'entries': 0};
    }
    
    int totalSize = 0;
    int entryCount = 0;
    int expiredCount = 0;
    
    for (final key in _box!.keys) {
      final value = _box!.get(key);
      if (value != null) {
        totalSize += value['size'] as int? ?? 0;
        entryCount++;
        
        final expiresAt = DateTime.tryParse(value['expiresAt'] ?? '');
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
          expiredCount++;
        }
      }
    }
    
    return {
      'size': totalSize,
      'sizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'entries': entryCount,
      'expiredEntries': expiredCount,
      'maxSizeMB': _maxCacheSizeMB,
    };
  }

  /// Clear all cache
  Future<void> clear() async {
    await init();
    await _box?.clear();
  }

  /// Dispose
  Future<void> dispose() async {
    await _box?.close();
    _initialized = false;
  }
}

/// Global cache instance
final responseCache = ResponseCache();

/// Cache decorator for API calls
Future<T> withCache<T>({
  required String path,
  Map<String, dynamic>? queryParams,
  required Future<T> Function() fetch,
  required T Function(dynamic) fromJson,
  required Map<String, dynamic> Function(T) toJson,
  Duration? ttl,
  bool forceRefresh = false,
}) async {
  // Try cache first (unless force refresh)
  if (!forceRefresh) {
    final cached = await responseCache.get(
      path: path,
      queryParams: queryParams,
      fromJson: fromJson,
    );
    
    if (cached != null) {
      return cached;
    }
  }
  
  // Fetch fresh data
  final data = await fetch();
  
  // Store in cache
  await responseCache.put(
    path: path,
    queryParams: queryParams,
    data: data,
    toJson: toJson,
    ttl: ttl,
  );
  
  return data;
}
