// ============================================================================
// PROPERTY TEST: e-Way Requirement Threshold
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 19: e-Way requirement threshold
//
// **Validates: Requirements 12.2**
//
// For any consignment total (paise) and movement type, an e-Way bill SHALL be
// required if and only if the total exceeds the ₹50,000 paise threshold AND
// the movement is inter-state.
//
// ForAll 200 iterations: generate random (consignmentPaise, interState) pairs.
// - EWayRules.isRequired returns true iff consignmentPaise > 5000000 AND interState == true
// - When consignmentPaise <= 5000000: always false regardless of interState
// - When interState == false: always false regardless of amount
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_eway_threshold_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/eway_rules.dart';

void main() {
  const int kNumRuns = 200;
  const rules = EWayRules();

  group(
    'Feature: wholesale-vertical-remediation, Property 19: e-Way requirement threshold',
    () {
      // -----------------------------------------------------------------------
      // Property 19a: isRequired iff consignmentPaise > 5000000 AND interState.
      // Full bidirectional check across random inputs.
      // -----------------------------------------------------------------------
      test(
        'Property 19a (forAll): isRequired iff consignmentPaise > threshold AND interState',
        () {
          final held = forAll(
            (int seed) {
              // Generate a consignment amount across a wide range including
              // near-threshold values. Range: 0..10,000,000 paise.
              final consignmentPaise = seed.abs() % 10000001;
              // Deterministic interState from the seed
              final interState = (seed % 2) == 0;

              final result = rules.isRequired(
                consignmentPaise: consignmentPaise,
                interState: interState,
              );

              final expectedRequired =
                  consignmentPaise > EWayRules.thresholdPaise && interState;

              return result == expectedRequired;
            },
            [Gen.interval(-10000000, 10000000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'isRequired must return true iff consignmentPaise > 5000000 '
                'AND interState == true',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 19b: When consignmentPaise <= threshold, always false
      // regardless of interState.
      // -----------------------------------------------------------------------
      test(
        'Property 19b (forAll): at or below threshold always returns false',
        () {
          final held = forAll(
            (int seed) {
              // Generate amounts at or below threshold: 0..5000000
              final consignmentPaise =
                  seed.abs() % (EWayRules.thresholdPaise + 1);
              // Test both interState values
              final interStateTrue = rules.isRequired(
                consignmentPaise: consignmentPaise,
                interState: true,
              );
              final interStateFalse = rules.isRequired(
                consignmentPaise: consignmentPaise,
                interState: false,
              );

              // Both must be false when amount <= threshold
              return !interStateTrue && !interStateFalse;
            },
            [Gen.interval(0, 10000000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When consignmentPaise <= 5000000, isRequired must always '
                'return false regardless of interState',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 19c: When interState == false, always false regardless of
      // amount.
      // -----------------------------------------------------------------------
      test(
        'Property 19c (forAll): intra-state always returns false regardless of amount',
        () {
          final held = forAll(
            (int seed) {
              // Generate any amount (including above threshold)
              final consignmentPaise = seed.abs() % 100000000; // 0..99,999,999

              final result = rules.isRequired(
                consignmentPaise: consignmentPaise,
                interState: false,
              );

              return result == false;
            },
            [Gen.interval(0, 100000000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When interState is false, isRequired must always return '
                'false regardless of the consignment amount',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 19d: Exactly at threshold (5000000) returns false.
      // Boundary: "exceeds" means strictly greater, not equal.
      // -----------------------------------------------------------------------
      test(
        'Property 19d (forAll): exactly at threshold returns false even with interState',
        () {
          final held = forAll(
            (int seed) {
              // Always test exactly at threshold
              const consignmentPaise = EWayRules.thresholdPaise; // 5000000

              final resultTrue = rules.isRequired(
                consignmentPaise: consignmentPaise,
                interState: true,
              );
              final resultFalse = rules.isRequired(
                consignmentPaise: consignmentPaise,
                interState: false,
              );

              // Exactly at threshold must NOT require e-Way (> not >=)
              return !resultTrue && !resultFalse;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Exactly at threshold (5000000 paise) must NOT require an '
                'e-Way bill — the condition is strictly greater than',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 19e: Just above threshold (5000001) with interState returns true.
      // -----------------------------------------------------------------------
      test(
        'Property 19e (forAll): just above threshold with interState returns true',
        () {
          final held = forAll(
            (int seed) {
              // Amounts strictly above threshold: 5000001..15000000
              final consignmentPaise =
                  EWayRules.thresholdPaise + 1 + (seed.abs() % 10000000);

              final result = rules.isRequired(
                consignmentPaise: consignmentPaise,
                interState: true,
              );

              return result == true;
            },
            [Gen.interval(0, 10000000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Any amount above 5000000 with interState == true must '
                'require an e-Way bill',
          );
        },
      );
    },
  );
}
