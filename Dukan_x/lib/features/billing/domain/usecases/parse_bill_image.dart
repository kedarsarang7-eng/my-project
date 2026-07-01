import 'dart:convert';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_item.dart';

import 'package:flutter/material.dart';

class ParseBillImage {
  Bill call(dynamic ocrResult) {
    if (ocrResult is RecognizedText) {
      return _parseMlKit(ocrResult);
    } else if (ocrResult is String) {
      return _parseAiText(ocrResult);
    }
    return _emptyBill();
  }

  Bill _parseMlKit(RecognizedText recognizedText) {
    List<TextLine> allLines = [];
    for (var block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    String shopName = '';
    DateTime date = DateTime.now();
    double totalAmount = 0.0;
    List<BillItem> items = [];

    // ... existing logic ...
    final totalKeywords = ['total', 'grand total', 'payable', 'amount', 'net'];

    for (int i = 0; i < allLines.take(5).length; i++) {
      final text = allLines[i].text.trim();
      if (_isValidShopName(text)) {
        shopName = text;
        break;
      }
    }

    for (var line in allLines) {
      final d = _extractDate(line.text);
      if (d != null) {
        date = d;
        break;
      }
    }

    for (int i = allLines.length - 1; i >= 0; i--) {
      final text = allLines[i].text.toLowerCase();
      if (totalKeywords.any((k) => text.contains(k))) {
        final numbers = _extractNumbers(text);
        if (numbers.isNotEmpty) {
          totalAmount = numbers.last;
          break;
        }
      }
    }

    // Basic Item Extraction
    for (var line in allLines) {
      final text = line.text.trim();
      if (text.length < 5) continue;
      final numbers = _extractNumbers(text);
      if (numbers.isEmpty) continue;

      if (text == shopName) continue;
      if (totalKeywords.any((k) => text.toLowerCase().contains(k))) continue;

      items.add(
        BillItem(
          productId: '',
          name: text.replaceAll(RegExp(r'[0-9.,]'), '').trim(),
          quantity: 1,
          rate: numbers.last,
          amount: numbers.last,
          unit: 'pc',
        ),
      );
    }

    return Bill(
      id: '',
      items: items,
      date: date,
      shopName: shopName.isNotEmpty ? shopName : 'Scanned Vendor',
      totalAmount: totalAmount == 0
          ? items.fold(0, (sum, it) => sum + it.amount)
          : totalAmount,
      subtotal: totalAmount,
      tax: 0,
      discount: 0,
      source: BillSource.scan,
    );
  }

  Bill _parseAiText(String text) {
    try {
      // Clean up potential markdown code blocks
      final cleanJson = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final map = json.decode(cleanJson) as Map<String, dynamic>;

      final List<BillItem> items = [];
      if (map['items'] != null) {
        for (var it in (map['items'] as List)) {
          items.add(
            BillItem(
              productId: '',
              name: it['name']?.toString() ?? 'Unknown Item',
              quantity: (it['qty'] ?? 1).toDouble(),
              rate: (it['rate'] ?? 0).toDouble(),
              amount: (it['amount'] ?? 0).toDouble(),
              unit: 'pc',
            ),
          );
        }
      }

      return Bill(
        id: '',
        items: items,
        date:
            DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
        shopName: map['shopName']?.toString() ?? 'Scanned Vendor',
        totalAmount: (map['totalAmount'] ?? 0).toDouble(),
        subtotal: (map['totalAmount'] ?? 0).toDouble(),
        tax: (map['tax'] ?? 0).toDouble(),
        discount: (map['discount'] ?? 0).toDouble(),
        source: BillSource.scan,
      );
    } catch (e) {
      debugPrint("JSON Parse failed fallback to heuristic: $e");
      // Fallback to previous heuristic if JSON fails
      return _parseHeuristic(text);
    }
  }

  Bill _parseHeuristic(String text) {
    // Tesseract Raw Text Heuristics
    String shopName = '';
    double totalAmount = 0.0;
    DateTime date = DateTime.now();
    List<BillItem> items = [];

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract Date
    for (var line in lines) {
      final d = _extractDate(line);
      if (d != null) {
        date = d;
        break;
      }
    }

    // 2. Extract Shop Name (First non-date, non-empty line usually)
    for (int i = 0; i < lines.take(5).length; i++) {
      final line = lines[i];
      if (line.length > 3 &&
          !line.contains(RegExp(r'\d{1,4}[-/.]\d{1,2}')) && // Not a date
          !line.toLowerCase().contains('total')) {
        shopName = line;
        break;
      }
    }
    if (shopName.isEmpty) shopName = 'Scanned Vendor';

    // 3. Extract Total (Look for keywords or largest number at bottom)
    final totalKeywords = ['total', 'payable', 'amount', 'net', 'grand'];
    bool foundTotal = false;

    // Search from bottom up
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].toLowerCase();

      // Heuristic A: Line contains "Total"
      if (totalKeywords.any((k) => line.contains(k))) {
        final nums = _extractNumbers(lines[i]); // Use original case line
        if (nums.isNotEmpty) {
          totalAmount = nums
              .last; // Usually the last number on "Total: 1200" line is the amount
          foundTotal = true;
          break;
        }
      }
    }

    // Heuristic B: If no total keyword, find largest number in last 5 lines
    if (!foundTotal) {
      double maxVal = 0.0;
      int checkLines = lines.length > 5 ? 5 : lines.length;
      for (int i = 0; i < checkLines; i++) {
        final idx = lines.length - 1 - i;
        final nums = _extractNumbers(lines[idx]);
        for (var n in nums) {
          if (n > maxVal) maxVal = n;
        }
      }
      if (maxVal > 0) totalAmount = maxVal;
    }

    // 4. Extract Items (Lines with Text + Number)
    for (var line in lines) {
      if (line.toLowerCase().contains('total') ||
          line.contains(shopName) ||
          line.length < 5) {
        continue;
      }

      final nums = _extractNumbers(line);
      if (nums.isNotEmpty) {
        // Assume format: "Item Name 100.00" or "2 x Item 50"
        // We take the last number as price/amount
        final amount = nums.last;
        // The text is everything except the numbers
        final name = line.replaceAll(RegExp(r'[0-9.,₹$]'), '').trim();

        if (name.length > 2) {
          items.add(
            BillItem(
              productId: '',
              name: name,
              quantity: 1,
              rate: amount,
              amount: amount,
              unit: 'pc',
            ),
          );
        }
      }
    }

    return Bill(
      id: '',
      items: items,
      date: date,
      shopName: shopName,
      totalAmount: totalAmount == 0
          ? items.fold(0, (sum, it) => sum + it.amount)
          : totalAmount,
      subtotal: totalAmount,
      tax: 0,
      discount: 0,
      source: BillSource.scan,
    );
  }

  Bill _emptyBill() => Bill(
    id: '',
    items: [],
    date: DateTime.now(),
    shopName: 'Empty Scan',
    totalAmount: 0,
    subtotal: 0,
    tax: 0,
    discount: 0,
    source: BillSource.scan,
  );

  bool _isValidShopName(String text) {
    if (text.length < 3) return false;
    if (RegExp(r'[0-9]').hasMatch(text)) return false;
    return true;
  }

  DateTime? _extractDate(String text) {
    final regex = RegExp(r'(\d{1,4}[./-]\d{1,2}[./-]\d{1,4})');
    final match = regex.firstMatch(text);
    if (match != null) {
      try {
        String s = match.group(0)!.replaceAll(RegExp(r'[./]'), '-');
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<double> _extractNumbers(String text) {
    final regex = RegExp(r'\d+(?:\.\d+)?');
    return regex
        .allMatches(text)
        .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
        .toList();
  }
}
