// ============================================================================
// PROPERTY TEST: e-Way Capture Validation
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 20: e-Way capture validation
//
// **Validates: Requirements 12.4, 12.6**
//
// For any e-Way capture payload with a required field (transporter name,
// approximate distance, vehicle number, party GSTIN) empty or malformed, the
// system SHALL surface a validation error and SHALL NOT submit the e-Way
// request; and where GSP credentials are unavailable it SHALL never produce
// an e-Way number.
//
// ForAll 200 iterations: generate random EWayCapture with various valid/invalid fields.
// - When all fields valid (non-empty transporter, distance > 0, non-empty vehicle,
//   15-char alphanum GSTIN): ValidationSuccess
// - When transporter empty: ValidationFailure
// - When distance <= 0: ValidationFailure
// - When vehicle empty: ValidationFailure
// - When GSTIN not 15 chars or not alphanumeric: ValidationFailure
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_eway_validation_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/eway_rules.dart';
import 'package:dukanx/features/wholesale/domain/validation_result.dart';

void main() {
  const int kNumRuns = 200;
  const rules = EWayRules();

  /// Generates a valid 15-char alphanumeric GSTIN from a seed.
  String _generateValidGstin(int seed) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer();
    for (int i = 0; i < 15; i++) {
      buffer.write(chars[(seed.abs() + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  /// Generates a valid EWayCapture from a seed (all fields valid).
  EWayCapture _validCapture(int seed) {
    return EWayCapture(
      transporterName: 'Transporter_${seed.abs() % 1000}',
      approxDistanceKm: (seed.abs() % 2000) + 1, // 1..2000
      vehicleNumber:
          'MH${(seed.abs() % 100).toString().padLeft(2, '0')}AB${(seed.abs() % 10000).toString().padLeft(4, '0')}',
      partyGstin: _generateValidGstin(seed),
    );
  }

  group(
    'Feature: wholesale-vertical-remediation, Property 20: e-Way capture validation',
    () {
      // -----------------------------------------------------------------------
      // Property 20a: All valid fields → ValidationSuccess.
      // -----------------------------------------------------------------------
      test('Property 20a (forAll): all valid fields yield ValidationSuccess', () {
        final held = forAll(
          (int seed) {
            final capture = _validCapture(seed);
            final result = rules.validateCapture(capture);
            return result is ValidationSuccess;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'When all fields are valid (non-empty transporter, distance > 0, '
              'non-empty vehicle, 15-char alphanum GSTIN), validation must succeed',
        );
      });

      // -----------------------------------------------------------------------
      // Property 20b: Empty transporter name → ValidationFailure.
      // -----------------------------------------------------------------------
      test(
        'Property 20b (forAll): empty transporter name yields ValidationFailure',
        () {
          final held = forAll(
            (int seed) {
              // Use whitespace-only or empty transporterName
              final emptyVariants = ['', ' ', '  ', '\t', '\n'];
              final transporterName =
                  emptyVariants[seed.abs() % emptyVariants.length];

              final capture = EWayCapture(
                transporterName: transporterName,
                approxDistanceKm: (seed.abs() % 2000) + 1,
                vehicleNumber: 'MH01AB1234',
                partyGstin: _generateValidGstin(seed),
              );

              final result = rules.validateCapture(capture);
              return result is ValidationFailure;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When transporter name is empty or whitespace-only, '
                'validation must fail',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 20c: Distance <= 0 → ValidationFailure.
      // -----------------------------------------------------------------------
      test('Property 20c (forAll): distance <= 0 yields ValidationFailure', () {
        final held = forAll(
          (int seed) {
            // Generate zero or negative distances
            final distance = -(seed.abs() % 1000); // -999..0

            final capture = EWayCapture(
              transporterName: 'ValidTransporter',
              approxDistanceKm: distance,
              vehicleNumber: 'MH01AB1234',
              partyGstin: _generateValidGstin(seed),
            );

            final result = rules.validateCapture(capture);
            return result is ValidationFailure;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'When approximate distance is <= 0, validation must fail',
        );
      });

      // -----------------------------------------------------------------------
      // Property 20d: Empty vehicle number → ValidationFailure.
      // -----------------------------------------------------------------------
      test(
        'Property 20d (forAll): empty vehicle number yields ValidationFailure',
        () {
          final held = forAll(
            (int seed) {
              final emptyVariants = ['', ' ', '  ', '\t', '\n'];
              final vehicleNumber =
                  emptyVariants[seed.abs() % emptyVariants.length];

              final capture = EWayCapture(
                transporterName: 'ValidTransporter',
                approxDistanceKm: (seed.abs() % 2000) + 1,
                vehicleNumber: vehicleNumber,
                partyGstin: _generateValidGstin(seed),
              );

              final result = rules.validateCapture(capture);
              return result is ValidationFailure;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When vehicle number is empty or whitespace-only, '
                'validation must fail',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 20e: GSTIN not 15 characters → ValidationFailure.
      // -----------------------------------------------------------------------
      test(
        'Property 20e (forAll): GSTIN not 15 chars yields ValidationFailure',
        () {
          final held = forAll(
            (int seed) {
              // Generate GSTIN with length != 15 (either shorter or longer)
              const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
              // Length 1..14 or 16..30 (never exactly 15)
              int length = (seed.abs() % 14) + 1; // 1..14
              if (seed % 2 == 0) {
                length = (seed.abs() % 15) + 16; // 16..30
              }

              final buffer = StringBuffer();
              for (int i = 0; i < length; i++) {
                buffer.write(chars[(seed.abs() + i * 7) % chars.length]);
              }
              final badGstin = buffer.toString();

              final capture = EWayCapture(
                transporterName: 'ValidTransporter',
                approxDistanceKm: (seed.abs() % 2000) + 1,
                vehicleNumber: 'MH01AB1234',
                partyGstin: badGstin,
              );

              final result = rules.validateCapture(capture);
              return result is ValidationFailure;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When GSTIN is not exactly 15 characters, validation must fail',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 20f: GSTIN with non-alphanumeric chars → ValidationFailure.
      // -----------------------------------------------------------------------
      test(
        'Property 20f (forAll): GSTIN with non-alphanumeric chars yields ValidationFailure',
        () {
          final held = forAll(
            (int seed) {
              // Generate a 15-char string with at least one non-alphanumeric char
              final validGstin = _generateValidGstin(seed);
              // Inject a special character at a random position
              final pos = seed.abs() % 15;
              const specials = '!@#\$%^&*()-_=+[]{}|;:,.<>?/~`';
              final specialChar = specials[seed.abs() % specials.length];
              final badGstin =
                  validGstin.substring(0, pos) +
                  specialChar +
                  validGstin.substring(pos + 1);

              final capture = EWayCapture(
                transporterName: 'ValidTransporter',
                approxDistanceKm: (seed.abs() % 2000) + 1,
                vehicleNumber: 'MH01AB1234',
                partyGstin: badGstin,
              );

              final result = rules.validateCapture(capture);
              return result is ValidationFailure;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When GSTIN contains non-alphanumeric characters, '
                'validation must fail',
          );
        },
      );
    },
  );
}
