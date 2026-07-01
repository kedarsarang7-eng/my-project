import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/utils/validators.dart';

void main() {
  group('Validators.isValidPhone (Indian numbering)', () {
    test('accepts a plain 10-digit number starting 6-9', () {
      expect(Validators.isValidPhone('9876543210'), isTrue);
      expect(Validators.isValidPhone('6000000000'), isTrue);
    });

    test('accepts +91 / 91 / 0 prefixes', () {
      expect(Validators.isValidPhone('+91 9876543210'), isTrue);
      expect(Validators.isValidPhone('919876543210'), isTrue);
      expect(Validators.isValidPhone('09876543210'), isTrue);
    });

    test('rejects numbers not starting 6-9', () {
      expect(Validators.isValidPhone('5876543210'), isFalse);
      expect(Validators.isValidPhone('1234567890'), isFalse);
    });

    test('rejects wrong length', () {
      expect(Validators.isValidPhone('98765'), isFalse);
      expect(Validators.isValidPhone('98765432100'), isFalse);
    });
  });

  group('Validators.isValidEmail', () {
    test('accepts well-formed addresses', () {
      expect(Validators.isValidEmail('a@b.com'), isTrue);
      expect(Validators.isValidEmail('name.surname@shop.co.in'), isTrue);
    });

    test('rejects malformed addresses', () {
      expect(Validators.isValidEmail('no-at-sign'), isFalse);
      expect(Validators.isValidEmail('a@b'), isFalse);
      expect(Validators.isValidEmail('a @b.com'), isFalse);
    });
  });
}
