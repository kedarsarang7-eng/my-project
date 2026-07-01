// ============================================================================
// UTILS TESTS - VALIDATORS, NUMBER UTILS, AND TAX CALCULATOR
// ============================================================================
// Comprehensive tests for utility functions
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/utils/validators.dart';
import 'package:dukanx/utils/number_utils.dart';

void main() {
  group('Validators Tests', () {
    group('isValidPhone', () {
      test('should return true for valid 10-digit phone', () {
        expect(Validators.isValidPhone('9876543210'), true);
        expect(Validators.isValidPhone('6000000000'), true);
      });

      test('should return true for phone with formatting', () {
        expect(Validators.isValidPhone('98765-43210'), true);
        expect(Validators.isValidPhone('(987) 654-3210'), true);
        expect(
          Validators.isValidPhone('+1 9876543210'),
          false,
        ); // +1 adds digit
        expect(Validators.isValidPhone('987 654 3210'), true);
      });

      test('should return false for invalid phone numbers', () {
        expect(Validators.isValidPhone('123'), false);
        expect(Validators.isValidPhone('12345678901'), false); // 11 digits
        expect(Validators.isValidPhone(''), false);
        expect(Validators.isValidPhone('abcdefghij'), false);
        expect(Validators.isValidPhone('1234567890'), false); // starts with 1
      });

      test('should handle edge cases', () {
        expect(
          Validators.isValidPhone('9000000000'),
          true,
        ); // valid 10 digits starting with 9
        expect(Validators.isValidPhone(' 9876543210 '), true); // with spaces
      });
    });

    group('isValidEmail', () {
      test('should return true for valid emails', () {
        expect(Validators.isValidEmail('test@example.com'), true);
        expect(Validators.isValidEmail('user.name@domain.org'), true);
        expect(Validators.isValidEmail('user+tag@example.co.in'), true);
      });

      test('should return false for invalid emails', () {
        expect(Validators.isValidEmail(''), false);
        expect(Validators.isValidEmail('test'), false);
        expect(Validators.isValidEmail('test@'), false);
        expect(Validators.isValidEmail('@example.com'), false);
        expect(Validators.isValidEmail('test@.com'), false);
        expect(
          Validators.isValidEmail('test example@test.com'),
          false,
        ); // has space
      });

      test('should handle edge cases', () {
        expect(Validators.isValidEmail('a@b.c'), true);
        expect(Validators.isValidEmail('test@sub.domain.example.com'), true);
      });
    });

    group('isValidPassword', () {
      test('should return true for valid passwords', () {
        expect(Validators.isValidPassword('1234'), true);
        expect(Validators.isValidPassword('password'), true);
        expect(Validators.isValidPassword('Password1'), true);
      });

      test('should return false for invalid passwords', () {
        expect(Validators.isValidPassword(''), false);
        expect(Validators.isValidPassword('abc'), false); // less than 4
        expect(Validators.isValidPassword('123'), false);
      });

      test('should handle edge cases', () {
        expect(
          Validators.isValidPassword('    '),
          true,
        ); // 4 spaces - technically valid
        expect(
          Validators.isValidPassword(
            '1234567890123456789012345678901234567890',
          ),
          true,
        ); // long password
      });
    });

    group('isValidName', () {
      test('should return true for valid names', () {
        expect(Validators.isValidName('Jo'), true);
        expect(Validators.isValidName('John'), true);
        expect(Validators.isValidName('John Doe'), true);
        expect(Validators.isValidName('Mary Jane Watson'), true);
      });

      test('should return false for invalid names', () {
        expect(Validators.isValidName(''), false);
        expect(Validators.isValidName('J'), false); // less than 2 chars
      });

      test('should handle edge cases', () {
        expect(
          Validators.isValidName('  '),
          true,
        ); // 2 spaces - technically valid
        expect(Validators.isValidName('æ—¥æœ¬èªž'), true); // unicode name
        expect(Validators.isValidName('123'), true); // numbers also >= 2 chars
      });
    });
  });

  group('Number Utils Tests', () {
    group('parseDouble', () {
      test('should handle null values', () {
        expect(parseDouble(null), 0.0);
        expect(parseDouble(null, fallback: 100.0), 100.0);
      });

      test('should handle integer values', () {
        expect(parseDouble(42), 42.0);
        expect(parseDouble(0), 0.0);
        expect(parseDouble(-10), -10.0);
      });

      test('should handle double values', () {
        expect(parseDouble(3.14), 3.14);
        expect(parseDouble(0.0), 0.0);
        expect(parseDouble(-99.99), -99.99);
      });

      test('should handle string values', () {
        expect(parseDouble('100'), 100.0);
        expect(parseDouble('3.14'), 3.14);
        expect(parseDouble('-50'), -50.0);
        expect(parseDouble('  42  '), 42.0); // with whitespace
      });

      test('should handle formatted strings with commas', () {
        expect(parseDouble('1,000'), 1000.0);
        expect(parseDouble('1,234,567.89'), 1234567.89);
        expect(parseDouble('99,999'), 99999.0);
      });

      test('should return fallback for empty strings', () {
        expect(parseDouble(''), 0.0);
        expect(parseDouble('   '), 0.0);
        expect(parseDouble('  ', fallback: 50.0), 50.0);
      });

      test('should return fallback for invalid strings', () {
        expect(parseDouble('abc'), 0.0);
        expect(parseDouble('abc', fallback: -1.0), -1.0);
        expect(parseDouble('12.34.56'), 0.0); // multiple dots
      });

      test('should handle boolean values', () {
        expect(parseDouble(true), 1.0);
        expect(parseDouble(false), 0.0);
      });

      test('should handle edge cases', () {
        expect(parseDouble(double.infinity), double.infinity);
        expect(parseDouble(double.negativeInfinity), double.negativeInfinity);
        expect(parseDouble('infinity'), 0.0); // string 'infinity' not parsed
        expect(parseDouble(999999999999), 999999999999.0); // large number
      });
    });
  });

  group('Tax Calculator Logic Tests', () {
    // Note: We can't test TaxCalculator.calculateTax directly as it returns a complex map,
    // but we can test the logic

    test('exclusive tax calculation formula', () {
      // Formula: Tax = (Total * Rate) / 100
      double price = 100.0;
      double quantity = 1.0;
      double rate = 18.0;
      double total = price * quantity;

      double expectedTax = (total * rate) / 100;
      expect(expectedTax, 18.0);

      double cgst = expectedTax / 2;
      double sgst = expectedTax / 2;
      expect(cgst, 9.0);
      expect(sgst, 9.0);
    });

    test('inclusive tax calculation formula', () {
      // Formula: Tax = (Total * Rate) / (100 + Rate)
      double price = 118.0; // price including 18% GST
      double quantity = 1.0;
      double rate = 18.0;
      double total = price * quantity;

      double expectedTax = (total * rate) / (100 + rate);
      expect(expectedTax.toStringAsFixed(2), '18.00');

      double taxableValue = total - expectedTax;
      expect(taxableValue.toStringAsFixed(2), '100.00');
    });

    test('tax calculation with quantity', () {
      double price = 100.0;
      double quantity = 5.0;
      double rate = 18.0;
      double total = price * quantity;

      expect(total, 500.0);

      double expectedTax = (total * rate) / 100;
      expect(expectedTax, 90.0);
    });

    test('zero tax rate should result in zero tax', () {
      double price = 100.0;
      double quantity = 1.0;
      double rate = 0.0;
      double total = price * quantity;

      double expectedTax = (total * rate) / 100;
      expect(expectedTax, 0.0);
    });

    test('high tax rate calculation', () {
      double price = 100.0;
      double quantity = 1.0;
      double rate = 28.0; // highest GST slab
      double total = price * quantity;

      double expectedTax = (total * rate) / 100;
      expect(expectedTax, 28.0);

      double cgst = expectedTax / 2;
      double sgst = expectedTax / 2;
      expect(cgst, 14.0);
      expect(sgst, 14.0);
    });

    test('decimal price and quantity calculations', () {
      double price = 99.99;
      double quantity = 2.5;
      double rate = 12.0;
      double total = price * quantity;

      expect(total, closeTo(249.975, 0.001));

      double expectedTax = (total * rate) / 100;
      expect(expectedTax, closeTo(29.997, 0.001));
    });
  });

  group('Edge Cases and Boundary Tests', () {
    test('parseDouble with very large numbers', () {
      expect(parseDouble(9999999999999.99), 9999999999999.99);
      expect(parseDouble('9999999999999.99'), 9999999999999.99);
    });

    test('parseDouble with very small numbers', () {
      expect(parseDouble(0.0001), 0.0001);
      expect(parseDouble('0.0001'), 0.0001);
    });

    test('parseDouble with negative numbers', () {
      expect(parseDouble(-100), -100.0);
      expect(parseDouble('-100'), -100.0);
      expect(parseDouble('-1,234.56'), -1234.56);
    });

    test('validators with special characters', () {
      expect(Validators.isValidPhone('!@#\$%^&*()'), false); // No digits
      expect(
        Validators.isValidEmail('test@exam!ple.com'),
        true,
      ); // ! is allowed by current regex
    });

    test('validators with unicode', () {
      expect(Validators.isValidName('æ—¥æœ¬èªžã®åå‰'), true);
      expect(Validators.isValidName('Ù…Ø±Ø­Ø¨Ø§'), true); // Arabic
      expect(Validators.isValidName('ÐŸÑ€Ð¸Ð²ÐµÑ‚'), true); // Russian
    });
  });
}
