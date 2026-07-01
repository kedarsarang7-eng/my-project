// Unit tests for hardware client-side GSTIN/HSN validation (bugfix.md 2.22).
//
// These validators run before `createParty` / item creation submit, so
// malformed GSTIN/HSN values are rejected client-side instead of being sent
// to the server.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/hardware/data/hardware_ops_repository.dart';

void main() {
  group('HardwareOpsRepository.isValidGstin', () {
    test('accepts a well-formed 15-character GSTIN', () {
      expect(HardwareOpsRepository.isValidGstin('27ABCDE1234F1Z5'), isTrue);
    });

    test('is case-insensitive (lowercase normalized)', () {
      expect(HardwareOpsRepository.isValidGstin('27abcde1234f1z5'), isTrue);
    });

    test('rejects a GSTIN that is too short', () {
      expect(HardwareOpsRepository.isValidGstin('27ABCDE1234F1Z'), isFalse);
    });

    test('rejects a GSTIN with the wrong character layout', () {
      // 5 digits where 5 letters (PAN) are expected.
      expect(HardwareOpsRepository.isValidGstin('2712345E1234F1Z5'), isFalse);
    });

    test('rejects a GSTIN missing the mandatory Z separator', () {
      expect(HardwareOpsRepository.isValidGstin('27ABCDE1234F1A5'), isFalse);
    });
  });

  group('HardwareOpsRepository.isValidHsn', () {
    test('accepts 4-digit HSN', () {
      expect(HardwareOpsRepository.isValidHsn('7308'), isTrue);
    });

    test('accepts 6-digit HSN', () {
      expect(HardwareOpsRepository.isValidHsn('730890'), isTrue);
    });

    test('accepts 8-digit HSN', () {
      expect(HardwareOpsRepository.isValidHsn('73089010'), isTrue);
    });

    test('rejects a 5-digit code', () {
      expect(HardwareOpsRepository.isValidHsn('73089'), isFalse);
    });

    test('rejects a 3-digit code', () {
      expect(HardwareOpsRepository.isValidHsn('730'), isFalse);
    });

    test('rejects non-numeric HSN', () {
      expect(HardwareOpsRepository.isValidHsn('73AB'), isFalse);
    });
  });
}
