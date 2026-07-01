import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service for cryptographic operations (Hash Chaining)
class HashService {
  /// Compute SHA-256 hash of a string
  String computeHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Canonical JSON Authorization
  /// Sorts keys recursively to ensure deterministic output for hashing
  String canonicalJson(Map<String, dynamic> data) {
    final sortedData = _sortKeys(data);
    return jsonEncode(sortedData);
  }

  /// Sort keys of a map/list recursively
  dynamic _sortKeys(dynamic value) {
    if (value is Map) {
      final sortedMap = <String, dynamic>{};
      final sortedKeys = value.keys.toList()..sort();
      for (final key in sortedKeys) {
        sortedMap[key.toString()] = _sortKeys(value[key]);
      }
      return sortedMap;
    } else if (value is List) {
      return value.map((e) => _sortKeys(e)).toList();
    } else {
      return value;
    }
  }

  /// Compute hash for a chained record
  /// H = SHA256(PreviousHash + CanonicalData)
  String computeChainHash(String previousHash, Map<String, dynamic> data) {
    final canonicalData = canonicalJson(data);
    final combined = '$previousHash$canonicalData';
    return computeHash(combined);
  }

  /// Verify a hash match
  bool verifyHash(
    String previousHash,
    Map<String, dynamic> data,
    String currentHash,
  ) {
    final computed = computeChainHash(previousHash, data);
    return computed == currentHash;
  }
}
