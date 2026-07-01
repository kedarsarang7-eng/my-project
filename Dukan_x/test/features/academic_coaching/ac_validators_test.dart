// =============================================================================
// ACADEMIC COACHING — VALIDATORS UNIT TESTS
// =============================================================================
// Tests every validator in AcValidators and the AcFormValidator helper.
// Pure Dart — no Flutter framework needed.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/academic_coaching/utils/ac_validators.dart';

void main() {
  // ===========================================================================
  // validateStudentId
  // ===========================================================================
  group('AcValidators.validateStudentId', () {
    test('null → required error', () {
      expect(AcValidators.validateStudentId(null), 'Student ID is required');
    });

    test('empty → required error', () {
      expect(AcValidators.validateStudentId(''), 'Student ID is required');
    });

    test('too short (2 chars) → length error', () {
      expect(AcValidators.validateStudentId('AB'), 'Must be 3-20 characters');
    });

    test('too long (21 chars) → length error', () {
      expect(AcValidators.validateStudentId('A' * 21), 'Must be 3-20 characters');
    });

    test('invalid chars (special) → format error', () {
      expect(
        AcValidators.validateStudentId('STU@001'),
        'Only letters, numbers, and hyphens allowed',
      );
    });

    test('invalid chars (space) → format error', () {
      expect(
        AcValidators.validateStudentId('STU 001'),
        'Only letters, numbers, and hyphens allowed',
      );
    });

    test('valid alphanumeric → null', () {
      expect(AcValidators.validateStudentId('STU001'), isNull);
    });

    test('valid with hyphen → null', () {
      expect(AcValidators.validateStudentId('STU-001'), isNull);
    });

    test('exactly 3 chars → null', () {
      expect(AcValidators.validateStudentId('ABC'), isNull);
    });

    test('exactly 20 chars → null', () {
      expect(AcValidators.validateStudentId('A' * 20), isNull);
    });
  });

  // ===========================================================================
  // validateName
  // ===========================================================================
  group('AcValidators.validateName', () {
    test('null → required error', () {
      expect(AcValidators.validateName(null), 'Name is required');
    });

    test('empty → required error with custom field', () {
      expect(
        AcValidators.validateName('', field: 'Student Name'),
        'Student Name is required',
      );
    });

    test('1 char → length error', () {
      expect(AcValidators.validateName('A'), 'Name must be 2-50 characters');
    });

    test('51 chars → length error', () {
      expect(
        AcValidators.validateName('A' * 51),
        'Name must be 2-50 characters',
      );
    });

    test('digits in name → format error', () {
      expect(
        AcValidators.validateName('John1 Doe'),
        'Name can only contain letters and spaces',
      );
    });

    test('special chars in name → format error', () {
      expect(
        AcValidators.validateName('John@Doe'),
        'Name can only contain letters and spaces',
      );
    });

    test('valid simple name → null', () {
      expect(AcValidators.validateName('John Doe'), isNull);
    });

    test('valid single word → null', () {
      expect(AcValidators.validateName('Ramesh'), isNull);
    });

    test('custom field name appears in error', () {
      final result = AcValidators.validateName('A' * 51, field: 'Faculty Name');
      expect(result, contains('Faculty Name'));
    });

    test('exactly 2 chars → null', () {
      expect(AcValidators.validateName('Al'), isNull);
    });

    test('exactly 50 chars → null', () {
      expect(AcValidators.validateName('A' * 50), isNull);
    });
  });

  // ===========================================================================
  // validatePhone
  // ===========================================================================
  group('AcValidators.validatePhone', () {
    test('null with required=true → required error', () {
      expect(
        AcValidators.validatePhone(null, required: true),
        'Phone number is required',
      );
    });

    test('null with required=false → null', () {
      expect(AcValidators.validatePhone(null, required: false), isNull);
    });

    test('empty with required=true → required error', () {
      expect(
        AcValidators.validatePhone('', required: true),
        'Phone number is required',
      );
    });

    test('empty with required=false → null', () {
      expect(AcValidators.validatePhone('', required: false), isNull);
    });

    test('9 digits → length error', () {
      expect(AcValidators.validatePhone('987654321'), 'Phone number must be 10 digits');
    });

    test('11 digits → length error', () {
      expect(AcValidators.validatePhone('98765432101'), 'Phone number must be 10 digits');
    });

    test('starts with 5 → invalid Indian number', () {
      expect(AcValidators.validatePhone('5123456789'), 'Invalid Indian mobile number');
    });

    test('starts with 1 → invalid Indian number', () {
      expect(AcValidators.validatePhone('1234567890'), 'Invalid Indian mobile number');
    });

    test('valid Indian number starting with 9 → null', () {
      expect(AcValidators.validatePhone('9876543210'), isNull);
    });

    test('valid Indian number starting with 6 → null', () {
      expect(AcValidators.validatePhone('6543210987'), isNull);
    });

    test('valid Indian number starting with 7 → null', () {
      expect(AcValidators.validatePhone('7890123456'), isNull);
    });

    test('valid Indian number starting with 8 → null', () {
      expect(AcValidators.validatePhone('8765432109'), isNull);
    });

    test('formatted with dashes → strips and validates', () {
      expect(AcValidators.validatePhone('98765-43210'), isNull);
    });

    test('formatted with spaces → strips and validates', () {
      expect(AcValidators.validatePhone('9876 543210'), isNull);
    });

    test('default required=true', () {
      expect(AcValidators.validatePhone(null), 'Phone number is required');
    });
  });

  // ===========================================================================
  // validateEmail
  // ===========================================================================
  group('AcValidators.validateEmail', () {
    test('null with required=false → null', () {
      expect(AcValidators.validateEmail(null), isNull);
    });

    test('empty with required=false → null', () {
      expect(AcValidators.validateEmail(''), isNull);
    });

    test('null with required=true → required error', () {
      expect(AcValidators.validateEmail(null, required: true), 'Email is required');
    });

    test('invalid format (no @) → format error', () {
      expect(AcValidators.validateEmail('invalidemail'), 'Invalid email format');
    });

    test('invalid format (no domain) → format error', () {
      expect(AcValidators.validateEmail('test@'), 'Invalid email format');
    });

    test('invalid format (no TLD) → format error', () {
      expect(AcValidators.validateEmail('test@domain'), 'Invalid email format');
    });

    test('valid email → null', () {
      expect(AcValidators.validateEmail('student@school.com'), isNull);
    });

    test('valid email with subdomain → null', () {
      expect(AcValidators.validateEmail('user.name@sub.domain.org'), isNull);
    });
  });

  // ===========================================================================
  // validateDateOfBirth
  // ===========================================================================
  group('AcValidators.validateDateOfBirth', () {
    test('null → required error', () {
      expect(AcValidators.validateDateOfBirth(null), 'Date of birth is required');
    });

    test('empty → required error', () {
      expect(AcValidators.validateDateOfBirth(''), 'Date of birth is required');
    });

    test('invalid format → format error', () {
      expect(
        AcValidators.validateDateOfBirth('15-06-2000'),
        'Invalid date format (YYYY-MM-DD)',
      );
    });

    test('future date → age error fires before future check', () {
      // Validator computes age = now.year - future.year (negative) → < minAge(5)
      // so 'Must be at least 5 years old' is returned before the isAfter check.
      final future = DateTime(DateTime.now().year + 10, 1, 1);
      final value = '${future.year}-01-01';
      expect(
        AcValidators.validateDateOfBirth(value),
        'Must be at least 5 years old',
      );
    });

    test('too young (age 3, minAge=5) → age error', () {
      final tooYoung = DateTime(DateTime.now().year - 3);
      final value = '${tooYoung.year}-01-01';
      expect(
        AcValidators.validateDateOfBirth(value, minAge: 5),
        'Must be at least 5 years old',
      );
    });

    test('too old (age 110, maxAge=100) → age error', () {
      final tooOld = DateTime(DateTime.now().year - 110);
      final value = '${tooOld.year}-01-01';
      expect(
        AcValidators.validateDateOfBirth(value, maxAge: 100),
        'Age cannot exceed 100 years',
      );
    });

    test('valid adult student → null', () {
      final validDob = DateTime(DateTime.now().year - 20);
      final value = '${validDob.year}-06-15';
      expect(AcValidators.validateDateOfBirth(value), isNull);
    });

    test('valid child student (age 8, minAge=5) → null', () {
      final validDob = DateTime(DateTime.now().year - 8);
      final value = '${validDob.year}-01-01';
      expect(AcValidators.validateDateOfBirth(value, minAge: 5), isNull);
    });
  });

  // ===========================================================================
  // validateFeeAmount
  // ===========================================================================
  group('AcValidators.validateFeeAmount', () {
    test('null → required error', () {
      expect(AcValidators.validateFeeAmount(null), 'Amount is required');
    });

    test('empty → required error', () {
      expect(AcValidators.validateFeeAmount(''), 'Amount is required');
    });

    test('non-numeric → invalid error', () {
      expect(AcValidators.validateFeeAmount('abc'), 'Invalid amount');
    });

    test('below min → min error', () {
      expect(
        AcValidators.validateFeeAmount('-1', min: 0),
        'Amount must be at least ₹0',
      );
    });

    test('above max → max error', () {
      expect(
        AcValidators.validateFeeAmount('2000000', max: 1000000),
        'Amount cannot exceed ₹1000000',
      );
    });

    test('valid amount → null', () {
      expect(AcValidators.validateFeeAmount('5000'), isNull);
    });

    test('valid amount with commas → null (stripped)', () {
      expect(AcValidators.validateFeeAmount('1,500'), isNull);
    });

    test('zero is valid when min=0', () {
      expect(AcValidators.validateFeeAmount('0', min: 0), isNull);
    });

    test('decimal amount → null', () {
      expect(AcValidators.validateFeeAmount('1500.50'), isNull);
    });

    test('custom min/max respected', () {
      expect(
        AcValidators.validateFeeAmount('500', min: 1000, max: 50000),
        'Amount must be at least ₹1000',
      );
      expect(
        AcValidators.validateFeeAmount('1500', min: 1000, max: 50000),
        isNull,
      );
    });
  });

  // ===========================================================================
  // validateCapacity
  // ===========================================================================
  group('AcValidators.validateCapacity', () {
    test('null → required error', () {
      expect(AcValidators.validateCapacity(null), 'Capacity is required');
    });

    test('empty → required error', () {
      expect(AcValidators.validateCapacity(''), 'Capacity is required');
    });

    test('non-integer → invalid error', () {
      expect(AcValidators.validateCapacity('abc'), 'Invalid number');
    });

    test('decimal → invalid error', () {
      expect(AcValidators.validateCapacity('5.5'), 'Invalid number');
    });

    test('below min (0) → min error', () {
      expect(
        AcValidators.validateCapacity('0', min: 1),
        'Minimum capacity is 1',
      );
    });

    test('above max (501) → max error', () {
      expect(
        AcValidators.validateCapacity('501', max: 500),
        'Maximum capacity is 500',
      );
    });

    test('valid capacity → null', () {
      expect(AcValidators.validateCapacity('30'), isNull);
    });

    test('exactly min → null', () {
      expect(AcValidators.validateCapacity('1', min: 1), isNull);
    });

    test('exactly max → null', () {
      expect(AcValidators.validateCapacity('500', max: 500), isNull);
    });
  });

  // ===========================================================================
  // validateDateRange
  // ===========================================================================
  group('AcValidators.validateDateRange', () {
    test('null start → required error', () {
      expect(
        AcValidators.validateDateRange(null, '2024-12-31'),
        'Start date is required',
      );
    });

    test('empty start → required error', () {
      expect(
        AcValidators.validateDateRange('', '2024-12-31'),
        'Start date is required',
      );
    });

    test('null end → required error', () {
      expect(
        AcValidators.validateDateRange('2024-01-01', null),
        'End date is required',
      );
    });

    test('empty end → required error', () {
      expect(
        AcValidators.validateDateRange('2024-01-01', ''),
        'End date is required',
      );
    });

    test('end before start → order error', () {
      expect(
        AcValidators.validateDateRange('2024-06-01', '2024-01-01'),
        'End date must be after start date',
      );
    });

    test('same start and end → null (same day range valid)', () {
      expect(
        AcValidators.validateDateRange('2024-06-01', '2024-06-01'),
        isNull,
      );
    });

    test('duration > 5 years → duration error', () {
      expect(
        AcValidators.validateDateRange('2020-01-01', '2026-01-02'),
        'Batch duration cannot exceed 5 years',
      );
    });

    test('valid range → null', () {
      expect(
        AcValidators.validateDateRange('2024-01-15', '2024-12-15'),
        isNull,
      );
    });

    test('invalid date format → format error', () {
      expect(
        AcValidators.validateDateRange('15-01-2024', '2024-12-31'),
        'Invalid date format',
      );
    });
  });

  // ===========================================================================
  // validateExamDuration
  // ===========================================================================
  group('AcValidators.validateExamDuration', () {
    test('null → required error', () {
      expect(AcValidators.validateExamDuration(null), 'Duration is required');
    });

    test('empty → required error', () {
      expect(AcValidators.validateExamDuration(''), 'Duration is required');
    });

    test('invalid format (plain number) → format error', () {
      expect(
        AcValidators.validateExamDuration('90'),
        'Format: "3 hours" or "90 minutes"',
      );
    });

    test('invalid format (word only) → format error', () {
      expect(
        AcValidators.validateExamDuration('hours'),
        'Format: "3 hours" or "90 minutes"',
      );
    });

    test('too short (10 minutes) → min error', () {
      expect(
        AcValidators.validateExamDuration('10 minutes'),
        'Minimum duration is 15 minutes',
      );
    });

    test('too long (9 hours = 540 min) → max error', () {
      expect(
        AcValidators.validateExamDuration('9 hours'),
        'Maximum duration is 8 hours',
      );
    });

    test('valid: 3 hours → null', () {
      expect(AcValidators.validateExamDuration('3 hours'), isNull);
    });

    test('valid: 90 minutes → null', () {
      expect(AcValidators.validateExamDuration('90 minutes'), isNull);
    });

    test('valid: 1 hour → null', () {
      expect(AcValidators.validateExamDuration('1 hour'), isNull);
    });

    test('valid: 15 minutes (boundary) → null', () {
      expect(AcValidators.validateExamDuration('15 minutes'), isNull);
    });

    test('valid: 8 hours (boundary) → null', () {
      expect(AcValidators.validateExamDuration('8 hours'), isNull);
    });

    test('abbreviated: 60 mins → null', () {
      expect(AcValidators.validateExamDuration('60 mins'), isNull);
    });

    test('abbreviated: 2 hrs → treated as 2 minutes (< 15 min) → min error', () {
      // 'hr' does not startsWith('hour') so treated as minutes in validator
      expect(
        AcValidators.validateExamDuration('2 hrs'),
        'Minimum duration is 15 minutes',
      );
    });

    test('case insensitive: 3 Hours → null', () {
      expect(AcValidators.validateExamDuration('3 Hours'), isNull);
    });
  });

  // ===========================================================================
  // validateMarks
  // ===========================================================================
  group('AcValidators.validateMarks', () {
    test('null → required error', () {
      expect(AcValidators.validateMarks(null), 'Marks are required');
    });

    test('empty → required error', () {
      expect(AcValidators.validateMarks(''), 'Marks are required');
    });

    test('non-numeric → invalid error', () {
      expect(AcValidators.validateMarks('abc'), 'Invalid number');
    });

    test('negative → negative error', () {
      expect(AcValidators.validateMarks('-1'), 'Marks cannot be negative');
    });

    test('exceeds maxMarks → max error', () {
      expect(
        AcValidators.validateMarks('101', maxMarks: 100),
        'Marks cannot exceed 100.0',
      );
    });

    test('valid marks → null', () {
      expect(AcValidators.validateMarks('75'), isNull);
    });

    test('zero marks → null', () {
      expect(AcValidators.validateMarks('0'), isNull);
    });

    test('exactly maxMarks → null', () {
      expect(AcValidators.validateMarks('100', maxMarks: 100), isNull);
    });

    test('decimal marks → null', () {
      expect(AcValidators.validateMarks('85.5'), isNull);
    });

    test('custom maxMarks respected', () {
      expect(
        AcValidators.validateMarks('150', maxMarks: 200),
        isNull,
      );
      expect(
        AcValidators.validateMarks('250', maxMarks: 200),
        'Marks cannot exceed 200.0',
      );
    });
  });

  // ===========================================================================
  // validatePincode
  // ===========================================================================
  group('AcValidators.validatePincode', () {
    test('null → null (optional field)', () {
      expect(AcValidators.validatePincode(null), isNull);
    });

    test('empty → null (optional field)', () {
      expect(AcValidators.validatePincode(''), isNull);
    });

    test('5 digits → length error', () {
      expect(AcValidators.validatePincode('12345'), 'PIN code must be 6 digits');
    });

    test('7 digits → length error', () {
      expect(AcValidators.validatePincode('1234567'), 'PIN code must be 6 digits');
    });

    test('valid 6-digit pincode → null', () {
      expect(AcValidators.validatePincode('400001'), isNull);
    });

    test('pincode with spaces → null (strips non-digits)', () {
      expect(AcValidators.validatePincode('400 001'), isNull);
    });
  });

  // ===========================================================================
  // required (generic)
  // ===========================================================================
  group('AcValidators.required', () {
    test('null → required error', () {
      expect(AcValidators.required(null), 'This field is required');
    });

    test('empty → required error', () {
      expect(AcValidators.required(''), 'This field is required');
    });

    test('whitespace only → required error', () {
      expect(AcValidators.required('   '), 'This field is required');
    });

    test('valid value → null', () {
      expect(AcValidators.required('some value'), isNull);
    });

    test('custom field name in error', () {
      expect(
        AcValidators.required(null, field: 'Batch Code'),
        'Batch Code is required',
      );
    });
  });

  // ===========================================================================
  // validateUniqueId
  // ===========================================================================
  group('AcValidators.validateUniqueId', () {
    test('null → required error', () {
      expect(AcValidators.validateUniqueId(null), 'ID is required');
    });

    test('empty → required error with custom field', () {
      expect(
        AcValidators.validateUniqueId('', field: 'Batch ID'),
        'Batch ID is required',
      );
    });

    test('special chars (@#) → format error', () {
      expect(
        AcValidators.validateUniqueId('batch@01'),
        contains('letters, numbers, underscores, and hyphens'),
      );
    });

    test('space → format error', () {
      expect(
        AcValidators.validateUniqueId('batch 01'),
        contains('letters, numbers, underscores, and hyphens'),
      );
    });

    test('1 char → length error', () {
      expect(
        AcValidators.validateUniqueId('A'),
        contains('2-30 characters'),
      );
    });

    test('31 chars → length error', () {
      expect(
        AcValidators.validateUniqueId('A' * 31),
        contains('2-30 characters'),
      );
    });

    test('valid alphanumeric → null', () {
      expect(AcValidators.validateUniqueId('BATCH001'), isNull);
    });

    test('valid with underscore → null', () {
      expect(AcValidators.validateUniqueId('batch_001'), isNull);
    });

    test('valid with hyphen → null', () {
      expect(AcValidators.validateUniqueId('batch-2024'), isNull);
    });
  });

  // ===========================================================================
  // AcFormValidator (composite validator helper)
  // ===========================================================================
  group('AcFormValidator', () {
    test('no errors → result.isValid is true', () {
      final validator = AcFormValidator();
      validator.validate('name', 'John Doe', AcValidators.validateName);
      expect(validator.result.isValid, isTrue);
      expect(validator.result.errors, isEmpty);
    });

    test('one error → result.isValid is false', () {
      final validator = AcFormValidator();
      validator.validate('name', '', AcValidators.validateName);
      expect(validator.result.isValid, isFalse);
      expect(validator.result.errors, hasLength(1));
    });

    test('multiple errors → all captured', () {
      final validator = AcFormValidator();
      validator.validate('name', '', AcValidators.validateName);
      validator.validate('phone', '123', AcValidators.validatePhone);
      validator.validate('email', 'notanemail', AcValidators.validateEmail);
      expect(validator.result.isValid, isFalse);
      expect(validator.result.errors, hasLength(3));
    });

    test('getError returns correct message', () {
      final validator = AcFormValidator();
      validator.validate('name', '', AcValidators.validateName);
      expect(validator.getError('name'), 'Name is required');
    });

    test('getError returns null for unknown field', () {
      final validator = AcFormValidator();
      expect(validator.getError('nonExistentField'), isNull);
    });

    test('hasError returns true for failing field', () {
      final validator = AcFormValidator();
      validator.validate('phone', '123', AcValidators.validatePhone);
      expect(validator.hasError('phone'), isTrue);
    });

    test('hasError returns false for passing field', () {
      final validator = AcFormValidator();
      validator.validate('phone', '9876543210', AcValidators.validatePhone);
      expect(validator.hasError('phone'), isFalse);
    });

    test('clear() removes all errors', () {
      final validator = AcFormValidator();
      validator.validate('name', '', AcValidators.validateName);
      validator.validate('phone', '123', AcValidators.validatePhone);
      expect(validator.result.isValid, isFalse);
      validator.clear();
      expect(validator.result.isValid, isTrue);
      expect(validator.result.errors, isEmpty);
    });

    test('result.errors is unmodifiable', () {
      final validator = AcFormValidator();
      validator.validate('name', '', AcValidators.validateName);
      final errors = validator.result.errors;
      expect(() => errors['extra'] = 'hack', throwsUnsupportedError);
    });

    test('ValidationResult.success() factory → isValid=true, empty errors', () {
      final r = ValidationResult.success();
      expect(r.isValid, isTrue);
      expect(r.errors, isEmpty);
    });

    test('ValidationResult.failure() factory → isValid=false, errors populated', () {
      final r = ValidationResult.failure({'field': 'some error'});
      expect(r.isValid, isFalse);
      expect(r.errors['field'], 'some error');
    });

    test('passing field does not add to errors map', () {
      final validator = AcFormValidator();
      validator.validate('name', 'Valid Name', AcValidators.validateName);
      validator.validate('phone', '', AcValidators.validatePhone);
      expect(validator.result.errors.containsKey('name'), isFalse);
      expect(validator.result.errors.containsKey('phone'), isTrue);
    });

    test('reuse after clear collects fresh errors', () {
      final validator = AcFormValidator();
      validator.validate('name', '', AcValidators.validateName);
      expect(validator.result.isValid, isFalse);
      validator.clear();
      validator.validate('name', 'Priya Sharma', AcValidators.validateName);
      expect(validator.result.isValid, isTrue);
    });
  });
}
