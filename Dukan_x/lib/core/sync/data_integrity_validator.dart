// ============================================================================
// DATA INTEGRITY VALIDATOR
// ============================================================================
// Validates data before sync to prevent corruption
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// Data validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(List<String> errors) =>
      ValidationResult(isValid: false, errors: errors);
}

/// Data integrity validator for sync operations
class DataIntegrityValidator {
  static final DataIntegrityValidator _instance =
      DataIntegrityValidator._internal();
  factory DataIntegrityValidator() => _instance;
  DataIntegrityValidator._internal();

  /// Validate data before sync
  ValidationResult validateForSync({
    required String collection,
    required Map<String, dynamic> data,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // 1. Check required fields
    _validateRequiredFields(collection, data, errors);

    // 2. Check data types
    _validateDataTypes(collection, data, errors);

    // 3. Check business rules
    _validateBusinessRules(collection, data, errors, warnings);

    // 4. Check data size limits
    _validateSizeLimits(data, errors);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate required fields based on collection type
  void _validateRequiredFields(
    String collection,
    Map<String, dynamic> data,
    List<String> errors,
  ) {
    final requiredFields = _getRequiredFields(collection);

    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        errors.add('Missing required field: $field');
      }
    }
  }

  /// Get required fields for each collection
  List<String> _getRequiredFields(String collection) {
    switch (collection) {
      case 'bills':
        return ['id', 'invoiceNumber', 'customerId', 'billDate', 'grandTotal'];
      case 'customers':
        return ['id', 'name'];
      case 'products':
        return ['id', 'name'];
      case 'payments':
        return ['id', 'amount', 'billId', 'paymentDate'];
      default:
        return ['id'];
    }
  }

  /// Validate data types
  void _validateDataTypes(
    String collection,
    Map<String, dynamic> data,
    List<String> errors,
  ) {
    // Validate common numeric fields
    final numericFields = [
      'grandTotal',
      'amount',
      'quantity',
      'price',
      'paidAmount',
    ];
    for (final field in numericFields) {
      if (data.containsKey(field) && data[field] != null) {
        if (data[field] is! num) {
          errors.add(
            'Field $field must be numeric, got ${data[field].runtimeType}',
          );
        } else if ((data[field] as num).isNaN ||
            (data[field] as num).isInfinite) {
          errors.add('Field $field has invalid numeric value');
        }
      }
    }

    // Validate date fields
    final dateFields = [
      'billDate',
      'paymentDate',
      'dueDate',
      'createdAt',
      'updatedAt',
    ];
    for (final field in dateFields) {
      if (data.containsKey(field) && data[field] != null) {
        if (data[field] is! DateTime && data[field] is! String) {
          errors.add('Field $field must be DateTime or ISO string');
        }
      }
    }
  }

  /// Validate business rules
  void _validateBusinessRules(
    String collection,
    Map<String, dynamic> data,
    List<String> errors,
    List<String> warnings,
  ) {
    if (collection == 'bills') {
      // Bill total must be non-negative
      final grandTotal = data['grandTotal'];
      if (grandTotal is num && grandTotal < 0) {
        errors.add('Bill grandTotal cannot be negative');
      }

      // Paid amount cannot exceed total
      final paidAmount = data['paidAmount'] as num?;
      if (paidAmount != null && grandTotal is num && paidAmount > grandTotal) {
        warnings.add(
          'paidAmount exceeds grandTotal - may indicate overpayment',
        );
      }

      // Due date should not be before bill date
      if (data['dueDate'] != null && data['billDate'] != null) {
        try {
          final dueDate = _parseDate(data['dueDate']);
          final billDate = _parseDate(data['billDate']);
          if (dueDate != null &&
              billDate != null &&
              dueDate.isBefore(billDate)) {
            warnings.add('Due date is before bill date');
          }
        } catch (_) {}
      }
    }

    if (collection == 'payments') {
      // Payment amount must be positive
      final amount = data['amount'];
      if (amount is num && amount <= 0) {
        errors.add('Payment amount must be positive');
      }
    }

    if (collection == 'products') {
      // Price must be non-negative
      final price = data['price'];
      if (price is num && price < 0) {
        errors.add('Product price cannot be negative');
      }
    }
  }

  /// Validate data size limits
  void _validateSizeLimits(Map<String, dynamic> data, List<String> errors) {
    // Firestore document size limit is 1MB
    final jsonSize = utf8.encode(jsonEncode(data)).length;
    if (jsonSize > 900 * 1024) {
      // 900KB warning threshold
      errors.add(
        'Document size (${jsonSize ~/ 1024}KB) approaching Firestore limit',
      );
    }

    // Check individual string field lengths
    for (final entry in data.entries) {
      if (entry.value is String && (entry.value as String).length > 100000) {
        errors.add('Field ${entry.key} exceeds maximum string length');
      }
    }
  }

  /// Parse date from various formats
  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Generate checksum for data integrity verification
  String generateChecksum(Map<String, dynamic> data) {
    final sortedJson = _sortedJsonEncode(data);
    final bytes = utf8.encode(sortedJson);
    return md5.convert(bytes).toString();
  }

  /// Verify data integrity using checksum
  bool verifyChecksum(Map<String, dynamic> data, String expectedChecksum) {
    final actualChecksum = generateChecksum(data);
    return actualChecksum == expectedChecksum;
  }

  /// JSON encode with sorted keys for consistent checksums
  String _sortedJsonEncode(dynamic data) {
    if (data is Map) {
      final sortedMap = Map.fromEntries(
        data.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString())),
      );
      return jsonEncode(sortedMap.map((k, v) => MapEntry(k, _sortValue(v))));
    }
    return jsonEncode(data);
  }

  dynamic _sortValue(dynamic value) {
    if (value is Map) {
      return Map.fromEntries(
        value.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString())),
      ).map((k, v) => MapEntry(k, _sortValue(v)));
    }
    if (value is List) {
      return value.map(_sortValue).toList();
    }
    return value;
  }
}
