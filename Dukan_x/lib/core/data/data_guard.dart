import 'dart:convert';

/// A utility class for defensive data parsing.
/// Prevents runtime exceptions like "type 'Null' is not a subtype of type 'String'".
class DataGuard {
  // Prevent instantiation
  DataGuard._();

  /// Safely parses a String. Returns [fallback] if null.
  /// Converts numbers/booleans to string if needed.
  static String safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely parses an int. Returns [fallback] if null or invalid.
  static int safeInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return fallback;
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
    }
    return fallback;
  }

  /// Safely parses a double. Returns [fallback] if null or invalid.
  static double safeDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return fallback;
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  /// Safely parses a bool. Returns [fallback] if null.
  /// Handles "true", "1", 1 as true.
  static bool safeBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final v = value.toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return fallback;
  }

  /// Safely parses a List. Returns empty list if null or not a list.
  /// Note: The returned list contains runtime generics of T.
  static List<T> safeList<T>(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      try {
        return value.cast<T>().toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  /// Safely parses a DateTime. Returns null or [fallback] if invalid.
  static DateTime? safeDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback;
    if (value is DateTime) return value;
    if (value is String) {
      if (value.isEmpty) return fallback;
      return DateTime.tryParse(value) ?? fallback;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return fallback;
  }

  /// Safely parses a Map. Returns empty map if null or not a map.
  static Map<K, V> safeMap<K, V>(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      try {
        return value.cast<K, V>();
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  /// Safely parses a JSON string into a `Map<String, dynamic>`
  static Map<String, dynamic> safeJsonMap(String? value) {
    if (value == null || value.isEmpty) return {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }
}
