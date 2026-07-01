// Amount to Words Unit Tests
// Tests for multi-language number-to-words conversion
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/pdf/amount_to_words.dart';
import 'package:dukanx/services/invoice_pdf_service.dart' show InvoiceLanguage;

void main() {
  group('AmountToWords - English', () {
    test('converts zero correctly', () {
      expect(
        AmountToWords.convert(0, InvoiceLanguage.english),
        'Rupees Zero Only',
      );
    });

    test('converts single digit numbers', () {
      expect(
        AmountToWords.convert(5, InvoiceLanguage.english),
        'Rupees Five Only',
      );
    });

    test('converts teen numbers', () {
      expect(
        AmountToWords.convert(15, InvoiceLanguage.english),
        'Rupees Fifteen Only',
      );
    });

    test('converts two digit numbers', () {
      expect(
        AmountToWords.convert(42, InvoiceLanguage.english),
        'Rupees Forty Two Only',
      );
    });

    test('converts hundreds', () {
      expect(
        AmountToWords.convert(100, InvoiceLanguage.english),
        'Rupees One Hundred Only',
      );
      expect(
        AmountToWords.convert(523, InvoiceLanguage.english),
        'Rupees Five Hundred Twenty Three Only',
      );
    });

    test('converts thousands', () {
      expect(
        AmountToWords.convert(1000, InvoiceLanguage.english),
        'Rupees One Thousand Only',
      );
      expect(
        AmountToWords.convert(1234, InvoiceLanguage.english),
        'Rupees One Thousand Two Hundred Thirty Four Only',
      );
    });

    test('converts lakhs (Indian numbering)', () {
      expect(
        AmountToWords.convert(100000, InvoiceLanguage.english),
        'Rupees One Lakh Only',
      );
      expect(
        AmountToWords.convert(123456, InvoiceLanguage.english),
        'Rupees One Lakh Twenty Three Thousand Four Hundred Fifty Six Only',
      );
    });

    test('converts crores (Indian numbering)', () {
      expect(
        AmountToWords.convert(10000000, InvoiceLanguage.english),
        'Rupees One Crore Only',
      );
      expect(
        AmountToWords.convert(12345678, InvoiceLanguage.english),
        'Rupees One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight Only',
      );
    });

    test('handles paise correctly', () {
      expect(
        AmountToWords.convert(1234.56, InvoiceLanguage.english),
        'Rupees One Thousand Two Hundred Thirty Four and Fifty Six Paise Only',
      );
    });

    test('handles whole numbers with zero paise', () {
      expect(
        AmountToWords.convert(500.00, InvoiceLanguage.english),
        'Rupees Five Hundred Only',
      );
    });
  });

  group('AmountToWords - Hindi', () {
    test('converts zero correctly', () {
      expect(
        AmountToWords.convert(0, InvoiceLanguage.hindi),
        'रुपये शून्य मात्र',
      );
    });

    test('converts basic numbers', () {
      expect(
        AmountToWords.convert(5, InvoiceLanguage.hindi),
        'रुपये पांच मात्र',
      );
      expect(
        AmountToWords.convert(15, InvoiceLanguage.hindi),
        'रुपये पंद्रह मात्र',
      );
    });

    test('converts special Hindi numbers (21-99)', () {
      expect(
        AmountToWords.convert(21, InvoiceLanguage.hindi),
        'रुपये इक्कीस मात्र',
      );
      expect(
        AmountToWords.convert(55, InvoiceLanguage.hindi),
        'रुपये पचपन मात्र',
      );
      expect(
        AmountToWords.convert(99, InvoiceLanguage.hindi),
        'रुपये निन्यानवे मात्र',
      );
    });

    test('converts hundreds in Hindi', () {
      expect(
        AmountToWords.convert(100, InvoiceLanguage.hindi),
        'रुपये एक सौ मात्र',
      );
    });

    test('converts thousands in Hindi', () {
      expect(
        AmountToWords.convert(1000, InvoiceLanguage.hindi),
        'रुपये एक हज़ार मात्र',
      );
    });

    test('converts lakhs in Hindi', () {
      expect(
        AmountToWords.convert(100000, InvoiceLanguage.hindi),
        'रुपये एक लाख मात्र',
      );
    });

    test('converts crores in Hindi', () {
      expect(
        AmountToWords.convert(10000000, InvoiceLanguage.hindi),
        'रुपये एक करोड़ मात्र',
      );
    });

    test('handles paise in Hindi', () {
      expect(
        AmountToWords.convert(1234.50, InvoiceLanguage.hindi),
        contains('पैसे'),
      );
    });
  });

  group('AmountToWords - Marathi', () {
    test('converts zero correctly', () {
      expect(
        AmountToWords.convert(0, InvoiceLanguage.marathi),
        'रुपये शून्य मात्र',
      );
    });

    test('converts basic numbers', () {
      expect(
        AmountToWords.convert(5, InvoiceLanguage.marathi),
        'रुपये पाच मात्र',
      );
    });

    test('converts special Marathi numbers', () {
      expect(
        AmountToWords.convert(21, InvoiceLanguage.marathi),
        'रुपये एकवीस मात्र',
      );
    });

    test('converts hundreds in Marathi', () {
      expect(
        AmountToWords.convert(100, InvoiceLanguage.marathi),
        'रुपये एकशे मात्र',
      );
    });

    test('converts thousands in Marathi', () {
      expect(
        AmountToWords.convert(1000, InvoiceLanguage.marathi),
        'रुपये एक हजार मात्र',
      );
    });

    test('converts lakhs in Marathi', () {
      expect(
        AmountToWords.convert(100000, InvoiceLanguage.marathi),
        'रुपये एक लाख मात्र',
      );
    });

    test('converts crores in Marathi (Koti)', () {
      expect(
        AmountToWords.convert(10000000, InvoiceLanguage.marathi),
        'रुपये एक कोटी मात्र',
      );
    });
  });

  group('AmountToWords - Edge Cases', () {
    test('handles very large numbers', () {
      // 10 crore
      final result = AmountToWords.convert(100000000, InvoiceLanguage.english);
      expect(result, contains('Crore'));
    });

    test('handles decimal precision', () {
      final result = AmountToWords.convert(123.456, InvoiceLanguage.english);
      // Should round paise to 46
      expect(result, contains('Forty Six Paise'));
    });

    test('handles small paise values', () {
      final result = AmountToWords.convert(0.50, InvoiceLanguage.english);
      expect(result, equals('Rupees Zero and Fifty Paise Only'));
    });
  });
}
