// Feature: comprehensive-test-certification, Property 17
// ============================================================================
// Property 17: Production-readiness decision is go exactly when all evidence
// is clean.
//
// For any set of readiness inputs, the Production_Readiness_Gate records a go
// decision if and only if Mock_Data is absent, debug flags are absent, the
// environment configuration matches production, operation is crash-free, every
// Quality_Gate is green, zero unresolved release-blocking (Critical or High)
// Defects remain, and no required checklist item is unevaluatable; in every
// other case it records a no-go decision and lists each failing item, non-green
// gate, blocking Defect, or unevaluatable item as a reason.
//
// Test directions:
//   1. FORWARD: All conditions clean → go with no reasons
//   2. REJECTION: mockDataAbsent = false → no-go with ≥1 reason
//   3. REJECTION: debugFlagsAbsent = false → no-go with ≥1 reason
//   4. REJECTION: envMatchesProduction = false → no-go with ≥1 reason
//   5. REJECTION: crashFree = false → no-go with ≥1 reason
//   6. REJECTION: any gate not green → no-go with ≥1 reason
//   7. REJECTION: unresolved Critical/High defects → no-go with ≥1 reason
//   8. REJECTION: unevaluatable items non-empty → no-go with ≥1 reason
//   9. BICONDITIONAL: go IFF all conditions met (combined check)
//
// **Validates: Requirements 7.4, 12.5, 14.2, 14.3, 14.4, 14.5, 15.3, 15.4**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_17_readiness_decision_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/readiness_decider.dart';
import '../core/gate_reducer.dart';
import '../core/defect.dart';
import 'generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// Names of the four standard quality gates.
const List<String> _gateNames = [
  'regression',
  'performance',
  'security',
  'dataIntegrity',
];

/// Generates a GateStatus value.
final Generator<GateStatus> _gateStatusGen = Gen.elementOf<GateStatus>(
  GateStatus.values,
);

/// Generates a Severity value.
final Generator<Severity> _severityGen = Gen.elementOf<Severity>(
  Severity.values,
);

/// Generates a ResolutionStatus value.
final Generator<ResolutionStatus> _resolutionStatusGen =
    Gen.elementOf<ResolutionStatus>(ResolutionStatus.values);

/// Generates a GapCategory value.
final Generator<GapCategory> _gapCategoryGen = Gen.elementOf<GapCategory>(
  GapCategory.values,
);

/// Generates a small number of gate names (1-6 random gates).
final Generator<int> _gateCountGen = Gen.interval(1, 6);

/// Generates a defect count (0-5).
final Generator<int> _defectCountGen = Gen.interval(0, 5);

/// Generates a unevaluatable item count (0-4).
final Generator<int> _unevalCountGen = Gen.interval(0, 4);

/// Boolean generator.
final Generator<bool> _boolGen = Gen.elementOf<bool>([true, false]);

/// Generates a selector index (0-7) for choosing which condition to break.
final Generator<int> _conditionSelectorGen = Gen.interval(0, 7);

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Creates clean ReadinessInputs that should produce a go decision.
ReadinessInputs _cleanInputs() {
  return ReadinessInputs(
    mockDataAbsent: true,
    debugFlagsAbsent: true,
    envMatchesProduction: true,
    crashFree: true,
    gateStatuses: {for (final name in _gateNames) name: GateStatus.green},
    unresolvedDefects: const [],
    unevaluatableItems: const {},
  );
}

/// Creates a defect with the given severity and an open status.
Defect _makeDefect(String id, Severity severity) {
  return Defect(
    id: id,
    severity: severity,
    reproSteps: const ['Step 1'],
    status: ResolutionStatus.open,
    category: GapCategory.feature,
  );
}

/// Checks whether the decision correctly reflects the inputs.
/// go is true IFF all conditions hold.
bool _allConditionsMet(ReadinessInputs inputs) {
  if (!inputs.mockDataAbsent) return false;
  if (!inputs.debugFlagsAbsent) return false;
  if (!inputs.envMatchesProduction) return false;
  if (!inputs.crashFree) return false;

  for (final status in inputs.gateStatuses.values) {
    if (status != GateStatus.green) return false;
  }

  // Only Critical/High are release-blocking
  final hasBlockingDefects = inputs.unresolvedDefects.any(
    (d) => d.severity == Severity.critical || d.severity == Severity.high,
  );
  if (hasBlockingDefects) return false;

  if (inputs.unevaluatableItems.isNotEmpty) return false;

  return true;
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  const decider = ProductionReadinessDecider();

  group('Property 17: Production-readiness decision is go exactly when all '
      'evidence is clean', () {
    // ========================================================================
    // Direction 1: FORWARD — all conditions clean → go with no reasons
    // ========================================================================
    test('FORWARD: All conditions clean → go with empty reasons', () {
      final held = forAll(
        (int gateCount) {
          // Build a clean inputs set with a random number of gates (all green)
          final gateStatuses = <String, GateStatus>{};
          for (int i = 0; i < gateCount; i++) {
            gateStatuses['gate_$i'] = GateStatus.green;
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: gateStatuses,
            unresolvedDefects: const [],
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);

          // Must be go with no reasons
          return decision.go == true && decision.reasons.isEmpty;
        },
        [_gateCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 2: REJECTION — mockDataAbsent = false → no-go
    // ========================================================================
    test('REJECTION: Mock data present → no-go with ≥1 reason', () {
      final held = forAll(
        (int gateCount) {
          final gateStatuses = <String, GateStatus>{};
          for (int i = 0; i < gateCount; i++) {
            gateStatuses['gate_$i'] = GateStatus.green;
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: false, // VIOLATION
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: gateStatuses,
            unresolvedDefects: const [],
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_gateCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 3: REJECTION — debugFlagsAbsent = false → no-go
    // ========================================================================
    test('REJECTION: Debug flags present → no-go with ≥1 reason', () {
      final held = forAll(
        (int gateCount) {
          final gateStatuses = <String, GateStatus>{};
          for (int i = 0; i < gateCount; i++) {
            gateStatuses['gate_$i'] = GateStatus.green;
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: false, // VIOLATION
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: gateStatuses,
            unresolvedDefects: const [],
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_gateCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 4: REJECTION — envMatchesProduction = false → no-go
    // ========================================================================
    test('REJECTION: Environment mismatch → no-go with ≥1 reason', () {
      final held = forAll(
        (int gateCount) {
          final gateStatuses = <String, GateStatus>{};
          for (int i = 0; i < gateCount; i++) {
            gateStatuses['gate_$i'] = GateStatus.green;
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: false, // VIOLATION
            crashFree: true,
            gateStatuses: gateStatuses,
            unresolvedDefects: const [],
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_gateCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 5: REJECTION — crashFree = false → no-go
    // ========================================================================
    test('REJECTION: Crash detected → no-go with ≥1 reason', () {
      final held = forAll(
        (int gateCount) {
          final gateStatuses = <String, GateStatus>{};
          for (int i = 0; i < gateCount; i++) {
            gateStatuses['gate_$i'] = GateStatus.green;
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: false, // VIOLATION
            gateStatuses: gateStatuses,
            unresolvedDefects: const [],
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_gateCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 6: REJECTION — any gate not green → no-go
    // ========================================================================
    test('REJECTION: Any gate notGreen → no-go with ≥1 reason', () {
      final held = forAll(
        (int gateCount, int failingIdx) {
          final effectiveGateCount = gateCount < 1 ? 1 : gateCount;
          final failIdx = failingIdx % effectiveGateCount;

          final gateStatuses = <String, GateStatus>{};
          for (int i = 0; i < effectiveGateCount; i++) {
            gateStatuses['gate_$i'] = i == failIdx
                ? GateStatus.notGreen
                : GateStatus.green;
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: gateStatuses, // One gate is notGreen
            unresolvedDefects: const [],
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_gateCountGen, Gen.interval(0, 100)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 7: REJECTION — unresolved Critical/High defects → no-go
    // ========================================================================
    test('REJECTION: Unresolved Critical defect → no-go with ≥1 reason', () {
      final held = forAll(
        (int defectCount) {
          final effectiveCount = defectCount < 1 ? 1 : defectCount;
          final defects = <Defect>[];
          for (int i = 0; i < effectiveCount; i++) {
            defects.add(_makeDefect('DEF-$i', Severity.critical));
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: {
              for (final name in _gateNames) name: GateStatus.green,
            },
            unresolvedDefects: defects,
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_defectCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('REJECTION: Unresolved High defect → no-go with ≥1 reason', () {
      final held = forAll(
        (int defectCount) {
          final effectiveCount = defectCount < 1 ? 1 : defectCount;
          final defects = <Defect>[];
          for (int i = 0; i < effectiveCount; i++) {
            defects.add(_makeDefect('DEF-HIGH-$i', Severity.high));
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: {
              for (final name in _gateNames) name: GateStatus.green,
            },
            unresolvedDefects: defects,
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_defectCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('FORWARD: Unresolved Medium/Low defects only → still go', () {
      final held = forAll(
        (int defectCount, Severity severity) {
          // Only use Medium or Low — not release-blocking
          final effectiveSeverity =
              (severity == Severity.critical || severity == Severity.high)
              ? Severity.medium
              : severity;

          final defects = <Defect>[];
          for (int i = 0; i < defectCount; i++) {
            defects.add(_makeDefect('DEF-LOW-$i', effectiveSeverity));
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: {
              for (final name in _gateNames) name: GateStatus.green,
            },
            unresolvedDefects: defects,
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);
          return decision.go == true && decision.reasons.isEmpty;
        },
        [_defectCountGen, _severityGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 8: REJECTION — unevaluatable items non-empty → no-go
    // ========================================================================
    test('REJECTION: Unevaluatable items present → no-go with ≥1 reason', () {
      final held = forAll(
        (int itemCount) {
          final effectiveCount = itemCount < 1 ? 1 : itemCount;
          final items = <String>{};
          for (int i = 0; i < effectiveCount; i++) {
            items.add('checklist_item_$i');
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: true,
            debugFlagsAbsent: true,
            envMatchesProduction: true,
            crashFree: true,
            gateStatuses: {
              for (final name in _gateNames) name: GateStatus.green,
            },
            unresolvedDefects: const [],
            unevaluatableItems: items, // NON-EMPTY
          );

          final decision = decider.decide(inputs);
          return decision.go == false && decision.reasons.isNotEmpty;
        },
        [_unevalCountGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 9: BICONDITIONAL — go IFF all conditions are met
    // ========================================================================
    test('BICONDITIONAL: go IFF mockDataAbsent AND debugFlagsAbsent AND '
        'envMatchesProduction AND crashFree AND every gate green AND '
        'zero Critical/High defects AND no unevaluatable items', () {
      final held = forAll(
        (
          bool mockAbsent,
          bool debugAbsent,
          bool envMatch,
          bool crashFreeVal,
          int gateCount,
          int failingGateIdx,
          bool hasFailingGate,
          Severity defectSeverity,
          int unevalCount,
        ) {
          // Build gate statuses (1-6 gates)
          final effectiveGateCount = gateCount < 1 ? 1 : gateCount;
          final gateStatuses = <String, GateStatus>{};
          final failIdx = failingGateIdx % effectiveGateCount;
          for (int i = 0; i < effectiveGateCount; i++) {
            if (hasFailingGate && i == failIdx) {
              gateStatuses['gate_$i'] = GateStatus.notGreen;
            } else {
              gateStatuses['gate_$i'] = GateStatus.green;
            }
          }

          // Build defects list — only include a blocking defect based on severity
          final defects = <Defect>[];
          defects.add(_makeDefect('DEF-BI-0', defectSeverity));

          // Build unevaluatable items
          final unevalItems = <String>{};
          for (int i = 0; i < unevalCount; i++) {
            unevalItems.add('item_$i');
          }

          final inputs = ReadinessInputs(
            mockDataAbsent: mockAbsent,
            debugFlagsAbsent: debugAbsent,
            envMatchesProduction: envMatch,
            crashFree: crashFreeVal,
            gateStatuses: gateStatuses,
            unresolvedDefects: defects,
            unevaluatableItems: unevalItems,
          );

          final decision = decider.decide(inputs);
          final expectedGo = _allConditionsMet(inputs);

          // Biconditional: go IFF all conditions met
          if (decision.go != expectedGo) return false;

          // When no-go, must have at least one reason
          if (!decision.go && decision.reasons.isEmpty) return false;

          // When go, must have zero reasons
          if (decision.go && decision.reasons.isNotEmpty) return false;

          return true;
        },
        [
          _boolGen,
          _boolGen,
          _boolGen,
          _boolGen,
          _gateCountGen,
          Gen.interval(0, 100),
          _boolGen,
          _severityGen,
          _unevalCountGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 10: Reason count — each failing condition adds ≥1 reason
    // ========================================================================
    test('REASONS: Multiple violations produce multiple reasons', () {
      final held = forAll(
        (int conditionSelector) {
          // Break multiple conditions simultaneously
          final breakMock = conditionSelector % 2 == 0;
          final breakDebug = conditionSelector % 3 == 0;
          final breakEnv = conditionSelector % 5 == 0;
          final breakCrash = conditionSelector % 7 == 0;

          // Ensure at least one condition is broken
          final anyBroken = breakMock || breakDebug || breakEnv || breakCrash;

          final inputs = ReadinessInputs(
            mockDataAbsent: !breakMock,
            debugFlagsAbsent: !breakDebug,
            envMatchesProduction: !breakEnv,
            crashFree: !breakCrash,
            gateStatuses: {
              for (final name in _gateNames) name: GateStatus.green,
            },
            unresolvedDefects: const [],
            unevaluatableItems: const {},
          );

          final decision = decider.decide(inputs);

          if (anyBroken) {
            // Count how many boolean conditions are broken
            int expectedMinReasons = 0;
            if (breakMock) expectedMinReasons++;
            if (breakDebug) expectedMinReasons++;
            if (breakEnv) expectedMinReasons++;
            if (breakCrash) expectedMinReasons++;

            return decision.go == false &&
                decision.reasons.length >= expectedMinReasons;
          } else {
            return decision.go == true && decision.reasons.isEmpty;
          }
        },
        [Gen.interval(0, 210)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
