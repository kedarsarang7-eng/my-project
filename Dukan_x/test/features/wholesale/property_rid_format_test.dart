// ============================================================================
// PROPERTY TEST: RID Format for New IDs
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 9: RID format for new ids
//
// **Validates: Requirements 1.4, 8.3, 10.3, 11.3, 12.7**
//
// ForAll 200 iterations: generate random non-empty tenantId strings, call
// DefaultRidGenerator().generate(tenantId) and verify:
//   - Result matches pattern {tenantId}-{digits}-{8hexchars}
//   - Empty tenantId throws ArgumentError
//   - Generated IDs are unique across iterations
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_rid_format_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/rid_generator.dart';

void main() {
  const int kNumRuns = 200;

  group(
    'Feature: wholesale-vertical-remediation, Property 9: RID format for new ids',
    () {
      late DefaultRidGenerator generator;

      setUp(() {
        generator = DefaultRidGenerator();
      });

      // -----------------------------------------------------------------------
      // Property 9a: Generated RID matches {tenantId}-{digits}-{8hexchars}.
      // -----------------------------------------------------------------------
      test('Property 9a (forAll): generate(tenantId) matches '
          '{tenantId}-{digits}-{8hexchars} pattern', () {
        // Use a set of varied tenant IDs generated from the iteration index.
        final held = forAll(
          (int seed) {
            // Generate a non-empty tenantId from the seed.
            final tenantId = 'tenant_${seed.abs()}';
            final rid = generator.generate(tenantId);

            // The RID must start with the tenantId prefix.
            if (!rid.startsWith('$tenantId-')) return false;

            // After the tenantId prefix, expect: {digits}-{8hexchars}
            final suffix = rid.substring('$tenantId-'.length);
            // Pattern: one or more digits, hyphen, exactly 8 hex chars.
            final suffixPattern = RegExp(r'^\d+-[0-9a-f]{8}$');
            return suffixPattern.hasMatch(suffix);
          },
          [Gen.interval(0, 99999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'RID must match {tenantId}-{timestamp_ms}-{uuid_v4_short}',
        );
      });

      // -----------------------------------------------------------------------
      // Property 9b: Empty tenantId throws ArgumentError.
      // -----------------------------------------------------------------------
      test('Property 9b: empty tenantId throws ArgumentError', () {
        expect(() => generator.generate(''), throwsA(isA<ArgumentError>()));
      });

      // -----------------------------------------------------------------------
      // Property 9c: Generated IDs are unique across iterations.
      // -----------------------------------------------------------------------
      test('Property 9c: uniqueness across $kNumRuns generated IDs', () {
        final ids = <String>{};
        final tenantId = 'uniqueness_test_tenant';

        for (var i = 0; i < kNumRuns; i++) {
          final rid = generator.generate(tenantId);
          expect(
            ids.add(rid),
            isTrue,
            reason: 'Duplicate RID generated at iteration $i: $rid',
          );
        }

        expect(ids.length, equals(kNumRuns));
      });

      // -----------------------------------------------------------------------
      // Property 9d: Timestamp component is a valid positive integer.
      // -----------------------------------------------------------------------
      test(
        'Property 9d (forAll): timestamp component is a valid positive integer',
        () {
          final held = forAll(
            (int seed) {
              final tenantId = 'ts_test_${seed.abs()}';
              final rid = generator.generate(tenantId);

              // Extract the timestamp portion (between first and last hyphen
              // in the suffix after tenantId).
              final suffix = rid.substring('$tenantId-'.length);
              final lastHyphen = suffix.lastIndexOf('-');
              if (lastHyphen < 0) return false;

              final timestampStr = suffix.substring(0, lastHyphen);
              final timestamp = int.tryParse(timestampStr);
              if (timestamp == null) return false;

              // Timestamp should be positive (milliseconds since epoch).
              return timestamp > 0;
            },
            [Gen.interval(0, 99999)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'Timestamp component must be a valid positive integer',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 9e: UUID suffix is exactly 8 lowercase hex characters.
      // -----------------------------------------------------------------------
      test(
        'Property 9e (forAll): UUID suffix is exactly 8 lowercase hex chars',
        () {
          final hexPattern = RegExp(r'^[0-9a-f]{8}$');

          final held = forAll(
            (int seed) {
              final tenantId = 'hex_test_${seed.abs()}';
              final rid = generator.generate(tenantId);

              // Extract the last 8 chars after the final hyphen.
              final lastHyphen = rid.lastIndexOf('-');
              if (lastHyphen < 0) return false;

              final uuidShort = rid.substring(lastHyphen + 1);
              return hexPattern.hasMatch(uuidShort);
            },
            [Gen.interval(0, 99999)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'UUID suffix must be exactly 8 lowercase hex characters',
          );
        },
      );
    },
  );
}
