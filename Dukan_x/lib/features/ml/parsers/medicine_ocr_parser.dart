// ============================================================================
// MEDICINE OCR PARSER
// ============================================================================
// Specialized OCR parser for medicine packaging/strips.
// Extracts batch number, expiry date, MRP from recognized text.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/foundation.dart';

/// Result of medicine-specific OCR parsing
class MedicineOcrResult {
  /// Raw text from OCR
  final String rawText;

  /// Extracted batch number (e.g., "B.No: ABC123")
  final String? batchNumber;

  /// Extracted expiry date
  final DateTime? expiryDate;

  /// Extracted MRP (Maximum Retail Price)
  final double? mrp;

  /// Extracted medicine name (if identifiable)
  final String? medicineName;

  /// Extracted strength (e.g., "500mg", "10ml")
  final String? strength;

  /// Extraction confidence (0.0 - 1.0)
  final double confidence;

  /// Whether the result contains pharmacy-relevant data
  bool get hasPharmacyData =>
      batchNumber != null || expiryDate != null || mrp != null;

  const MedicineOcrResult({
    required this.rawText,
    this.batchNumber,
    this.expiryDate,
    this.mrp,
    this.medicineName,
    this.strength,
    this.confidence = 0.0,
  });

  /// Create empty result
  factory MedicineOcrResult.empty() => const MedicineOcrResult(rawText: '');

  @override
  String toString() {
    return 'MedicineOcrResult(batch: $batchNumber, expiry: $expiryDate, '
        'mrp: $mrp, strength: $strength, confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
  }
}

/// Medicine-specific OCR parser for pharmacy compliance
///
/// Extracts:
/// - Batch number (B.No, BATCH, LOT patterns)
/// - Expiry date (EXP, EXPIRY, BEST BEFORE patterns)
/// - MRP (MRP ₹, M.R.P patterns)
/// - Strength (mg, ml, g patterns)
class MedicineOcrParser {
  // ============================================================
  // EXPIRY DATE PATTERNS (India-specific)
  // ============================================================
  // Supports:
  // - EXP 03/26, EXP: 03/26
  // - EXPIRY: 12/2025, EXPIRY 12-2025
  // - BEST BEFORE 05/2026
  // - EX: 03/26, EXP. 03/26
  // - MM/YY, MM/YYYY, MMM-YYYY
  // ============================================================

  static final List<RegExp> _expiryPatterns = [
    // EXP 03/26, EXP: 03/26, EXP. 03-26
    RegExp(r'EXP[:\.\s]*(\d{1,2})[/\-](\d{2,4})', caseSensitive: false),
    // EXPIRY: 12/2025, EXPIRY 12-2025
    RegExp(r'EXPIRY[:\s]*(\d{1,2})[/\-](\d{2,4})', caseSensitive: false),
    // BEST BEFORE 05/2026
    RegExp(r'BEST\s*BEFORE[:\s]*(\d{1,2})[/\-](\d{2,4})', caseSensitive: false),
    // EX: 03/26
    RegExp(r'EX[:\.\s]+(\d{1,2})[/\-](\d{2,4})', caseSensitive: false),
    // USE BY 03/26
    RegExp(r'USE\s*BY[:\s]*(\d{1,2})[/\-](\d{2,4})', caseSensitive: false),
    // VALID TILL 03/26
    RegExp(r'VALID\s*TILL[:\s]*(\d{1,2})[/\-](\d{2,4})', caseSensitive: false),
    // Standalone date patterns near EXP-related words (MMM-YYYY)
    RegExp(
      r'(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[/\-\s]?(\d{2,4})',
      caseSensitive: false,
    ),
  ];

  // ============================================================
  // BATCH NUMBER PATTERNS
  // ============================================================
  // Supports:
  // - B.No: ABC123, B.No ABC123
  // - BATCH: ABC123, BATCH NO ABC123
  // - LOT: ABC123, LOT NO. ABC123
  // ============================================================

  static final List<RegExp> _batchPatterns = [
    // B.No: ABC123, B.No. ABC123, BNo: ABC123
    RegExp(r'B\.?No\.?[:\s]*([A-Z0-9]+)', caseSensitive: false),
    // BATCH: ABC123, BATCH NO ABC123
    RegExp(r'BATCH\s*(?:NO\.?)?[:\s]*([A-Z0-9]+)', caseSensitive: false),
    // LOT: ABC123, LOT NO. ABC123
    RegExp(r'LOT\s*(?:NO\.?)?[:\s]*([A-Z0-9]+)', caseSensitive: false),
  ];

  // ============================================================
  // MRP PATTERNS (India-specific)
  // ============================================================
  // Supports:
  // - MRP ₹123.45, MRP Rs 123.45
  // - M.R.P: 123.45, MRP: Rs. 123/-
  // ============================================================

  static final List<RegExp> _mrpPatterns = [
    // MRP ₹123.45, MRP Rs 123.45
    RegExp(r'MRP[:\s]*[₹Rs\.]*\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false),
    // M.R.P: 123.45
    RegExp(
      r'M\.R\.P\.?[:\s]*[₹Rs\.]*\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    // MAX RETAIL PRICE 123.45
    RegExp(
      r'MAX(?:IMUM)?\s*RETAIL\s*PRICE[:\s]*[₹Rs\.]*\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
  ];

  // ============================================================
  // STRENGTH PATTERNS
  // ============================================================
  // Supports: 500mg, 10ml, 5g, 250 mg, 100 ml
  // ============================================================

  static final RegExp _strengthPattern = RegExp(
    r'(\d+(?:\.\d+)?)\s*(mg|ml|g|gm|mcg|iu)\b',
    caseSensitive: false,
  );

  /// Parse medicine-specific fields from raw OCR text
  ///
  /// Returns [MedicineOcrResult] with extracted data
  static MedicineOcrResult parse(String rawText) {
    if (rawText.isEmpty) return MedicineOcrResult.empty();

    debugPrint(
      '[MedicineOcrParser] Parsing text: ${rawText.substring(0, rawText.length.clamp(0, 100))}...',
    );

    final batchNumber = _extractBatchNumber(rawText);
    final expiryDate = _extractExpiryDate(rawText);
    final mrp = _extractMrp(rawText);
    final strength = _extractStrength(rawText);

    // Calculate confidence based on extracted fields
    int foundFields = 0;
    if (batchNumber != null) foundFields++;
    if (expiryDate != null) foundFields++;
    if (mrp != null) foundFields++;
    if (strength != null) foundFields++;

    final confidence = foundFields / 4.0;

    final result = MedicineOcrResult(
      rawText: rawText,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      mrp: mrp,
      strength: strength,
      confidence: confidence,
    );

    debugPrint('[MedicineOcrParser] Result: $result');
    return result;
  }

  /// Extract batch number from text
  static String? _extractBatchNumber(String text) {
    for (final pattern in _batchPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final batch = match.group(1)?.trim();
        if (batch != null && batch.length >= 2) {
          return batch.toUpperCase();
        }
      }
    }
    return null;
  }

  /// Extract expiry date from text
  ///
  /// Handles various date formats and normalizes to DateTime
  static DateTime? _extractExpiryDate(String text) {
    for (final pattern in _expiryPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 2) {
        try {
          final part1 = match.group(1)!;
          final part2 = match.group(2)!;

          // Handle month name patterns (JAN, FEB, etc.)
          if (_isMonthName(part1)) {
            final month = _parseMonthName(part1);
            final year = _normalizeYear(int.parse(part2));
            return DateTime(year, month, 1);
          }

          // Handle numeric patterns (MM/YY or MM/YYYY)
          final month = int.parse(part1);
          final year = _normalizeYear(int.parse(part2));

          if (month >= 1 && month <= 12) {
            // Use last day of month for expiry
            return DateTime(year, month + 1, 0);
          }
        } catch (e) {
          debugPrint('[MedicineOcrParser] Date parse error: $e');
          continue;
        }
      }
    }
    return null;
  }

  /// Extract MRP from text
  static double? _extractMrp(String text) {
    for (final pattern in _mrpPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        try {
          return double.parse(match.group(1)!);
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  /// Extract strength (mg, ml, g) from text
  static String? _extractStrength(String text) {
    final match = _strengthPattern.firstMatch(text);
    if (match != null && match.groupCount >= 2) {
      final value = match.group(1);
      final unit = match.group(2);
      if (value != null && unit != null) {
        return '$value${unit.toLowerCase()}';
      }
    }
    return null;
  }

  /// Check if string is a month name
  static bool _isMonthName(String text) {
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months.contains(text.toUpperCase());
  }

  /// Parse month name to number (1-12)
  static int _parseMonthName(String name) {
    final months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12,
    };
    return months[name.toUpperCase()] ?? 1;
  }

  /// Normalize 2-digit year to 4-digit year
  ///
  /// Assumes 00-50 = 2000-2050, 51-99 = 1951-1999
  static int _normalizeYear(int year) {
    if (year < 100) {
      return year <= 50 ? 2000 + year : 1900 + year;
    }
    return year;
  }
}
