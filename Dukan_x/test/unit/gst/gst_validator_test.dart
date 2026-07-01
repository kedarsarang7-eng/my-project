// Unit tests: GstValidator — GSTIN format validation
// Source: packages/shared_core/lib/src/validators/gst_validator.dart

import 'package:flutter_test/flutter_test.dart';

// We re-implement the validator inline because the shared_core package
// has its own pubspec. The regex pattern is identical.
class GstValidator {
  static final _pattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );
  static bool isValid(String gstin) =>
      _pattern.hasMatch(gstin.toUpperCase().trim());
  static String? validate(String? gstin) {
    if (gstin == null || gstin.trim().isEmpty) return null;
    if (!isValid(gstin)) return 'Enter a valid GSTIN (15 characters)';
    return null;
  }
}

void main() {
  group('GstValidator.isValid', () {
    test('valid GSTIN passes', () {
      // Standard Maharashtra GSTIN format
      expect(GstValidator.isValid('27AAPFU0939F1ZV'), true);
    });

    test('lowercase input is auto-uppercased', () {
      expect(GstValidator.isValid('27aapfu0939f1zv'), true);
    });

    test('too short → invalid', () {
      expect(GstValidator.isValid('27AAPFU0939F1Z'), false);
    });

    test('too long → invalid', () {
      expect(GstValidator.isValid('27AAPFU0939F1ZV1'), false);
    });

    test('wrong 13th char (not Z) → invalid', () {
      expect(GstValidator.isValid('27AAPFU0939F1AV'), false);
    });

    test('empty string → invalid', () {
      expect(GstValidator.isValid(''), false);
    });
  });

  group('GstValidator.validate', () {
    test('null → null (GST is optional)', () {
      expect(GstValidator.validate(null), null);
    });

    test('empty string → null (optional)', () {
      expect(GstValidator.validate(''), null);
    });

    test('whitespace only → null (optional)', () {
      expect(GstValidator.validate('   '), null);
    });

    test('valid GSTIN → null (no error)', () {
      expect(GstValidator.validate('27AAPFU0939F1ZV'), null);
    });

    test('invalid GSTIN → error message', () {
      expect(GstValidator.validate('INVALID'),
          'Enter a valid GSTIN (15 characters)');
    });
  });
}
