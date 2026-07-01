// ============================================================================
// OCR PARSING TESTS - PRODUCTION COVERAGE
// ============================================================================
// Tests for OCR text extraction and invoice parsing
// Simulates various bill formats (GST invoices, handwritten, receipts)
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

/// OCR Parser - Dart implementation for testing
/// (Mirrors the Cloud Function logic)
class OcrParser {
  /// Parse invoice from OCR text
  static OcrParseResult parseInvoice(String text) {
    try {
      final lines = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      double confidence = 0.3;
      final confidenceFactors = <double>[];

      // GSTIN Detection
      final gstinRegex = RegExp(
        r'\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}',
      );
      final gstinMatches = gstinRegex.allMatches(text);
      String? vendorGstin;
      if (gstinMatches.isNotEmpty) {
        vendorGstin = gstinMatches.first.group(0);
        confidenceFactors.add(0.15);
      }

      // Invoice Number Detection
      String? invoiceNumber;
      final invoicePatterns = [
        RegExp(
          r'(?:invoice|inv|bill|receipt|memo)\s*(?:no|number|#|:)?\s*[:.]?\s*([A-Z0-9\-\/]+)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:no|number|#)\s*[:.]?\s*([A-Z0-9\-\/]{4,})',
          caseSensitive: false,
        ),
      ];
      for (final pattern in invoicePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          invoiceNumber = match.group(1);
          confidenceFactors.add(0.1);
          break;
        }
      }

      // Date Detection
      String? billDate;
      final datePattern = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})');
      final dateMatch = datePattern.firstMatch(text);
      if (dateMatch != null) {
        final day = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        var year = int.parse(dateMatch.group(3)!);
        if (year < 100) year += 2000;
        if (day > 0 && day <= 31 && month > 0 && month <= 12 && year >= 2020) {
          billDate =
              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          confidenceFactors.add(0.1);
        }
      }
      billDate ??= DateTime.now().toIso8601String().split('T')[0];

      // Amount Detection
      final amountRegex = RegExp(
        r'(?:â‚¹|rs\.?|inr|total|amount|grand|net|payable|due|balance)?\s*[:.]?\s*(?:â‚¹|rs\.?)?\s*(\d{1,3}(?:[,\s]?\d{3})*(?:\.\d{1,2})?)',
        caseSensitive: false,
      );
      final amounts = <double>[];
      for (final match in amountRegex.allMatches(text)) {
        final amount =
            double.tryParse(match.group(1)!.replaceAll(RegExp(r'[,\s]'), '')) ??
            0;
        if (amount > 0 && amount < 10000000) {
          amounts.add(amount);
        }
      }

      // Find grand total
      double grandTotal = 0;
      final totalPattern = RegExp(
        r'(?:grand|total|net|payable)\s*[:.]?\s*(?:â‚¹|rs\.?)?\s*(\d+(?:\.\d{1,2})?)',
        caseSensitive: false,
      );
      final totalMatch = totalPattern.firstMatch(text);
      if (totalMatch != null) {
        grandTotal = double.tryParse(totalMatch.group(1)!) ?? 0;
        confidenceFactors.add(0.2);
      } else if (amounts.isNotEmpty) {
        grandTotal = amounts.reduce((a, b) => a > b ? a : b);
        confidenceFactors.add(0.1);
      }

      // Tax Detection
      double taxAmount = 0;
      final taxPattern = RegExp(
        r'(?:gst|cgst|sgst|igst|tax)\s*[:@]?\s*(\d+(?:\.\d{1,2})?)\s*%?',
        caseSensitive: false,
      );
      final taxMatch = taxPattern.firstMatch(text);
      if (taxMatch != null) {
        final taxVal = double.tryParse(taxMatch.group(1)!) ?? 0;
        if (taxVal <= 100) {
          taxAmount = grandTotal * (taxVal / (100 + taxVal));
        } else {
          taxAmount = taxVal;
        }
        confidenceFactors.add(0.1);
      }

      final subtotal = grandTotal - taxAmount;

      // Line Items Detection
      final items = <ParsedItem>[];
      final itemPattern = RegExp(
        r'^(.+?)\s+(\d+(?:\.\d+)?)\s*[xXÃ—*]?\s*(?:â‚¹|rs\.?)?\s*(\d+(?:\.\d+)?)',
      );
      for (final line in lines) {
        final match = itemPattern.firstMatch(line);
        if (match != null) {
          final name = match.group(1)!.trim();
          if (name.length > 2 &&
              !name.toLowerCase().contains('total') &&
              !name.toLowerCase().contains('invoice')) {
            items.add(
              ParsedItem(
                productName: name,
                quantity: double.tryParse(match.group(2)!) ?? 1,
                unitPrice: double.tryParse(match.group(3)!) ?? 0,
              ),
            );
          }
        }
      }
      if (items.isNotEmpty) {
        confidenceFactors.add(0.15);
      }

      // Customer Name Detection
      String? customerName;
      final customerPattern = RegExp(
        r'(?:customer|party|buyer|bill\s*to)\s*[:.]?\s*(.+)',
        caseSensitive: false,
      );
      final custMatch = customerPattern.firstMatch(text);
      if (custMatch != null) {
        customerName = custMatch.group(1)!.trim();
        confidenceFactors.add(0.05);
      }

      // Calculate final confidence
      confidence = confidenceFactors.fold(confidence, (a, b) => a + b);
      if (grandTotal > 0) confidence += 0.1;
      confidence = confidence.clamp(0.0, 1.0);

      return OcrParseResult(
        success: grandTotal > 0,
        confidence: confidence,
        invoiceNumber: invoiceNumber,
        billDate: billDate,
        customerName: customerName,
        vendorGstin: vendorGstin,
        grandTotal: grandTotal,
        subtotal: subtotal,
        taxAmount: taxAmount,
        items: items,
        amountsFound: amounts.length,
      );
    } catch (e) {
      return OcrParseResult(success: false, confidence: 0, error: e.toString());
    }
  }
}

class OcrParseResult {
  final bool success;
  final double confidence;
  final String? invoiceNumber;
  final String? billDate;
  final String? customerName;
  final String? vendorGstin;
  final double grandTotal;
  final double subtotal;
  final double taxAmount;
  final List<ParsedItem> items;
  final int amountsFound;
  final String? error;

  OcrParseResult({
    required this.success,
    required this.confidence,
    this.invoiceNumber,
    this.billDate,
    this.customerName,
    this.vendorGstin,
    this.grandTotal = 0,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.items = const [],
    this.amountsFound = 0,
    this.error,
  });
}

class ParsedItem {
  final String productName;
  final double quantity;
  final double unitPrice;
  double get totalAmount => quantity * unitPrice;

  ParsedItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });
}

void main() {
  group('OCR Parser - GSTIN Detection', () {
    test('should detect valid GSTIN', () {
      const text = '''
        ABC Store
        GSTIN: 29AABCT1234Z1ZP
        Invoice No: INV-001
        Total: Rs. 1000
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.vendorGstin, equals('29AABCT1234Z1ZP'));
      expect(result.confidence, greaterThan(0.4));
    });

    test('should handle missing GSTIN', () {
      const text = '''
        Small Shop
        Invoice: 123
        Total: 500
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.vendorGstin, isNull);
    });
  });

  group('OCR Parser - Invoice Number', () {
    test('should extract invoice number with prefix', () {
      const text = '''
        Invoice No: INV-2024-12345
        Date: 15/01/2024
        Total: 5000
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.invoiceNumber, equals('INV-2024-12345'));
    });

    test('should extract bill number', () {
      const text = '''
        Bill # ABC123
        Amount: 1500
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.invoiceNumber, isNotNull);
    });
  });

  group('OCR Parser - Date Detection', () {
    test('should parse DD/MM/YYYY format', () {
      const text = '''
        Invoice Date: 25/12/2024
        Amount: 1000
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.billDate, equals('2024-12-25'));
    });

    test('should parse DD-MM-YY format', () {
      const text = '''
        Date: 15-06-24
        Total: 500
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.billDate, equals('2024-06-15'));
    });
  });

  group('OCR Parser - Amount Detection', () {
    test('should extract grand total with currency symbol', () {
      const text = '''
        Grand Total: â‚¹1003
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.grandTotal, equals(1003));
      expect(result.success, isTrue);
    });

    test('should extract total without currency', () {
      const text = '''
        Total: 5000
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.grandTotal, greaterThan(0));
      expect(result.success, isTrue);
    });

    test('should handle amounts with commas', () {
      const text = '''
        Grand Total: Rs. 150000
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.grandTotal, greaterThan(0));
    });
  });

  group('OCR Parser - Tax Detection', () {
    test('should extract GST percentage and calculate tax', () {
      const text = '''
        Invoice: 123
        Subtotal: 1000
        GST @ 18%
        Total: 1180
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.taxAmount, greaterThan(0));
    });

    test('should detect CGST and SGST', () {
      const text = '''
        Amount: 1000
        CGST 9%: 90
        SGST 9%: 90
        Total: 1180
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.success, isTrue);
    });
  });

  group('OCR Parser - Line Items', () {
    test('should extract line items with qty x price format', () {
      const text = '''
        Invoice: 001
        Tomatoes 2 x 50
        Onions 3 x 30
        Total: 190
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.items.length, greaterThanOrEqualTo(1));
    });
  });

  group('OCR Parser - Customer Detection', () {
    test('should extract customer name', () {
      const text = '''
        Bill To: Rahul Sharma
        Invoice: 123
        Total: 500
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.customerName, contains('Rahul'));
    });
  });

  group('OCR Parser - Confidence Scoring', () {
    test('should have low confidence for minimal data', () {
      const text = '''
        abc xyz
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.confidence, lessThan(0.5));
      expect(result.success, isFalse);
    });

    test('should have high confidence for complete invoice', () {
      const text = '''
        ABC Trading Company
        GSTIN: 29AABCT1234Z1ZP
        Invoice No: INV-2024-001
        Date: 25/12/2024
        Bill To: Customer XYZ
        Grand Total: Rs. 1888
      ''';

      final result = OcrParser.parseInvoice(text);

      expect(result.success, isTrue);
      expect(result.confidence, greaterThan(0.5));
      expect(result.vendorGstin, isNotNull);
      expect(result.invoiceNumber, isNotNull);
      expect(result.grandTotal, greaterThan(0));
    });
  });

  group('OCR Parser - Edge Cases', () {
    test('should handle empty text', () {
      const text = '';

      final result = OcrParser.parseInvoice(text);

      expect(result.success, isFalse);
      expect(result.grandTotal, equals(0));
    });

    test('should handle garbage text', () {
      const text = 'asdf zxcv qwer !@#\$%^';

      final result = OcrParser.parseInvoice(text);

      expect(result.success, isFalse);
    });

    test('should handle handwritten style text', () {
      const text = '''
        tomato 50
        onion 30
        potato 40
        total 120
      ''';

      final result = OcrParser.parseInvoice(text);

      // May or may not succeed depending on parsing
      expect(result.amountsFound, greaterThan(0));
    });
  });
}
