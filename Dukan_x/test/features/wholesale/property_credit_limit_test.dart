// ============================================================================
// PROPERTY TEST: Credit-Limit Enforcement
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 14: Credit-limit enforcement
//
// **Validates: Requirements 9.4, 9.5, 9.8**
//
// For any party credit limit `L`, current outstanding `O`, and prospective bill
// `B` (all in paise), the limit is exceeded exactly when `O + B > L` (and L > 0);
// a limitPaise of 0 means "no limit" — never exceeded.
// In hardBlock mode when exceeded: warningMessage mentions "cannot be saved".
// In softWarning mode when exceeded: warningMessage mentions "Proceed or cancel".
//
// ForAll 200 iterations: generate random (limitPaise, outstandingPaise, billPaise, mode) tuples.
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_credit_limit_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/credit_limit_evaluator.dart';

void main() {
  const int kNumRuns = 200;
  const evaluator = CreditLimitEvaluator();

  group(
    'Feature: wholesale-vertical-remediation, Property 14: Credit-limit enforcement',
    () {
      // -----------------------------------------------------------------------
      // Property 14a: When limitPaise == 0, exceeded is always false (no limit).
      // -----------------------------------------------------------------------
      test(
        'Property 14a (forAll): exceeded is always false when limitPaise == 0',
        () {
          final held = forAll(
            (int seed) {
              final outstandingPaise = seed.abs() % 10000000; // 0..9,999,999
              final billPaise = (seed.abs() + 17) % 5000000; // 0..4,999,999
              final mode = seed % 2 == 0
                  ? CreditMode.hardBlock
                  : CreditMode.softWarning;

              final decision = evaluator.evaluate(
                mode: mode,
                limitPaise: 0,
                outstandingPaise: outstandingPaise,
                billPaise: billPaise,
              );
              return decision.exceeded == false;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'exceeded must be false when limitPaise == 0 (no limit)',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 14b: When outstanding + bill > limit AND limit > 0, exceeded is true.
      // -----------------------------------------------------------------------
      test(
        'Property 14b (forAll): exceeded is true when outstanding + bill > limit > 0',
        () {
          final held = forAll(
            (int seed) {
              // Generate a positive limit and values that exceed it
              final limitPaise = (seed.abs() % 1000000) + 1; // 1..1,000,000
              // Ensure outstanding + bill > limit
              final outstandingPaise = limitPaise; // at limit already
              final billPaise = (seed.abs() % 500000) + 1; // at least 1 more
              final mode = seed % 2 == 0
                  ? CreditMode.hardBlock
                  : CreditMode.softWarning;

              final decision = evaluator.evaluate(
                mode: mode,
                limitPaise: limitPaise,
                outstandingPaise: outstandingPaise,
                billPaise: billPaise,
              );
              return decision.exceeded == true;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'exceeded must be true when outstanding + bill > limit > 0',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 14c: When outstanding + bill <= limit AND limit > 0, exceeded is false.
      // -----------------------------------------------------------------------
      test(
        'Property 14c (forAll): exceeded is false when outstanding + bill <= limit > 0',
        () {
          final held = forAll(
            (int seed) {
              // Generate a positive limit and values that stay within it
              final limitPaise = (seed.abs() % 1000000) + 100; // 100..1,000,099
              // outstanding + bill <= limit
              final total = seed.abs() % (limitPaise + 1); // 0..limitPaise
              final outstandingPaise = total ~/ 2;
              final billPaise = total - outstandingPaise;
              final mode = seed % 2 == 0
                  ? CreditMode.hardBlock
                  : CreditMode.softWarning;

              final decision = evaluator.evaluate(
                mode: mode,
                limitPaise: limitPaise,
                outstandingPaise: outstandingPaise,
                billPaise: billPaise,
              );
              return decision.exceeded == false;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'exceeded must be false when outstanding + bill <= limit > 0',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 14d: In hardBlock mode when exceeded, warningMessage mentions
      // "cannot be saved".
      // -----------------------------------------------------------------------
      test(
        'Property 14d (forAll): hardBlock exceeded message mentions "cannot be saved"',
        () {
          final held = forAll(
            (int seed) {
              final limitPaise = (seed.abs() % 500000) + 1;
              final outstandingPaise = limitPaise;
              final billPaise = (seed.abs() % 500000) + 1;

              final decision = evaluator.evaluate(
                mode: CreditMode.hardBlock,
                limitPaise: limitPaise,
                outstandingPaise: outstandingPaise,
                billPaise: billPaise,
              );
              if (!decision.exceeded) return false;
              if (decision.warningMessage == null) return false;
              return decision.warningMessage!.toLowerCase().contains(
                'cannot be saved',
              );
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'hardBlock exceeded message must mention "cannot be saved"',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 14e: In softWarning mode when exceeded, warningMessage mentions
      // "Proceed or cancel".
      // -----------------------------------------------------------------------
      test(
        'Property 14e (forAll): softWarning exceeded message mentions "Proceed or cancel"',
        () {
          final held = forAll(
            (int seed) {
              final limitPaise = (seed.abs() % 500000) + 1;
              final outstandingPaise = limitPaise;
              final billPaise = (seed.abs() % 500000) + 1;

              final decision = evaluator.evaluate(
                mode: CreditMode.softWarning,
                limitPaise: limitPaise,
                outstandingPaise: outstandingPaise,
                billPaise: billPaise,
              );
              if (!decision.exceeded) return false;
              if (decision.warningMessage == null) return false;
              return decision.warningMessage!.contains('Proceed or cancel');
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'softWarning exceeded message must mention "Proceed or cancel"',
          );
        },
      );
    },
  );
}
