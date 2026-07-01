// ============================================================================
// Task 23.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 31: Flag-only decision
// records require valid status and complete sign-off
// **Validates: Requirements 27.1, 27.2, 27.3**
// ============================================================================
// Property 31 (design.md): For any create/update of a product-decision record,
// the change is persisted IF AND ONLY IF
//   - the status is EXACTLY one of "deferred" or "scheduled" (R27.1), AND
//   - the sign-off contains a non-empty approver identity (R27.2), AND
//   - the sign-off contains a decision timestamp (R27.2);
// otherwise the change is rejected, the prior recorded state is retained
// unchanged, and the missing/invalid sign-off is indicated (R27.3).
//
// This >=100-case property test exercises the production
// ProductDecisionValidator / ProductDecisionRegistry against an INDEPENDENT
// oracle, over randomly generated combinations of:
//   - status (valid "deferred"/"scheduled", plus invalid: empty, miscased,
//     whitespace-padded, arbitrary fuzz, and null),
//   - approver identity (non-empty, whitespace-padded-but-valid, empty,
//     whitespace-only, and null),
//   - decision timestamp (present or absent/null).
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide (see the dev_dependency note in `pubspec.yaml`). It
//   composes cleanly with `flutter_test` and runs `kNumRuns` (200) generated
//   cases.
//
// Run: flutter test test/features/pharmacy/product_decision_signoff_property31_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/pharmacy/governance/product_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // -- Independent oracle ---------------------------------------------------
  // Re-derived from the acceptance criteria (R27.1–R27.3), deliberately NOT
  // calling the production validator, so the property compares two independent
  // implementations. A change is accepted iff the status is exactly one of the
  // two wire strings AND the approver identity is non-empty after trimming AND
  // a decision timestamp is present.
  bool oracleAccepts(String? status, String? approver, DateTime? timestamp) {
    final statusOk = status == 'deferred' || status == 'scheduled';
    final approverOk = approver != null && approver.trim().isNotEmpty;
    final timestampOk = timestamp != null;
    return statusOk && approverOk && timestampOk;
  }

  // -- Generators -----------------------------------------------------------

  // Non-whitespace characters used to build approver identities that are
  // guaranteed non-empty after trimming.
  const List<String> nameChars = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'A',
    'B',
    'C',
    '0',
    '1',
    '2',
    '3',
    '.',
    '-',
    '_',
  ];

  // status: a deliberate mix of valid and invalid values, including null.
  //   0 => "deferred"        (valid)
  //   1 => "scheduled"       (valid)
  //   2 => ""                (invalid: empty)
  //   3 => "Deferred"        (invalid: wrong case)
  //   4 => " deferred"       (invalid: surrounding whitespace)
  //   5 => "scheduled "      (invalid: trailing whitespace)
  //   6 => "pending"         (invalid: not a recognised status)
  //   7 => arbitrary fuzz    (oracle decides)
  //   8 => null              (invalid: missing)
  final Generator<String?> statusGen =
      Gen.tuple(<Generator<dynamic>>[
        Gen.interval(0, 8),
        Gen.string(minLength: 0, maxLength: 12),
      ]).map((parts) {
        final int kind = parts[0] as int;
        final String fuzz = parts[1] as String;
        switch (kind) {
          case 0:
            return 'deferred';
          case 1:
            return 'scheduled';
          case 2:
            return '';
          case 3:
            return 'Deferred';
          case 4:
            return ' deferred';
          case 5:
            return 'scheduled ';
          case 6:
            return 'pending';
          case 7:
            return fuzz;
          default:
            return null;
        }
      });

  // approver identity: valid, whitespace-padded-but-valid, empty,
  // whitespace-only, and null.
  //   0 => non-empty identity                (valid)
  //   1 => padded non-empty identity         (valid after trim)
  //   2 => ""                                (invalid: empty)
  //   3 => whitespace-only                   (invalid: blank after trim)
  //   4 => null                              (invalid: missing)
  final Generator<String?> approverGen =
      Gen.tuple(<Generator<dynamic>>[
        Gen.interval(0, 4),
        Gen.array<String>(
          Gen.elementOf<String>(nameChars),
          minLength: 1,
          maxLength: 20,
        ),
        Gen.interval(1, 4), // amount of surrounding whitespace
      ]).map((parts) {
        final int kind = parts[0] as int;
        final String name = (parts[1] as List).cast<String>().join();
        final String pad = ' ' * (parts[2] as int);
        switch (kind) {
          case 0:
            return name;
          case 1:
            return '$pad$name$pad';
          case 2:
            return '';
          case 3:
            return pad; // whitespace only
          default:
            return null;
        }
      });

  // decision timestamp: present (a real UTC instant) or absent (null).
  final Generator<DateTime?> timestampGen =
      Gen.tuple(<Generator<dynamic>>[
        Gen.interval(0, 1), // 0 => null, 1 => present
        Gen.interval(0, 4000000000), // seconds since epoch
      ]).map((parts) {
        if ((parts[0] as int) == 0) return null;
        return DateTime.fromMillisecondsSinceEpoch(
          (parts[1] as int) * 1000,
          isUtc: true,
        );
      });

  // A stable, known-good prior decision used to seed the registry for the
  // prior-state-retention facet.
  final DateTime priorTimestamp = DateTime.utc(2024, 1, 1, 9, 30);
  const String priorApprover = 'seed-approver';

  group(
    'Feature: pharmacy-vertical-remediation, Property 31: Flag-only decision '
    'records require valid status and complete sign-off',
    () {
      // -- Facet (a): accept IFF valid status AND complete sign-off --------
      test('Property 31 (a): a change is persisted iff status is exactly '
          '"deferred"/"scheduled" AND approver identity non-empty AND timestamp '
          'present (R27.1, R27.2)', () {
        final held = forAll(
          (String? status, String? approver, DateTime? timestamp) {
            final registry = ProductDecisionRegistry();
            const capability = ProductCapability.creditLimits;

            final result = registry.record(
              capability: capability,
              status: status,
              approverIdentity: approver,
              decisionTimestamp: timestamp,
            );

            final expectedAccept = oracleAccepts(status, approver, timestamp);
            if (result.isValid != expectedAccept) return false;

            if (expectedAccept) {
              // Accepted: a decision was persisted, error is absent, and the
              // stored decision faithfully reflects the (valid) inputs.
              final stored = registry.decisionFor(capability);
              return result.error == null &&
                  result.decision != null &&
                  stored != null &&
                  identical(stored, result.decision) &&
                  stored.capability == capability &&
                  stored.status.value == status &&
                  stored.signOff.approverIdentity == approver!.trim() &&
                  stored.signOff.decisionTimestamp == timestamp;
            } else {
              // Rejected: nothing persisted, an error is surfaced.
              return result.decision == null &&
                  result.error != null &&
                  registry.decisionFor(capability) == null;
            }
          },
          [statusGen, approverGen, timestampGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // -- Facet (b): a rejected change retains the prior state unchanged --
      test('Property 31 (b): when a change is rejected the prior recorded '
          'decision is retained exactly; when accepted it replaces the prior '
          '(R27.3)', () {
        final held = forAll(
          (String? status, String? approver, DateTime? timestamp) {
            final registry = ProductDecisionRegistry();
            const capability = ProductCapability.loyaltyPoints;

            // Seed a valid prior decision.
            final seed = registry.record(
              capability: capability,
              status: 'deferred',
              approverIdentity: priorApprover,
              decisionTimestamp: priorTimestamp,
            );
            if (!seed.isValid) return false;
            final before = registry.decisionFor(capability);

            final result = registry.record(
              capability: capability,
              status: status,
              approverIdentity: approver,
              decisionTimestamp: timestamp,
            );

            final expectedAccept = oracleAccepts(status, approver, timestamp);
            if (result.isValid != expectedAccept) return false;

            final after = registry.decisionFor(capability);
            if (expectedAccept) {
              // Accepted: the prior is replaced by the new decision.
              return result.error == null &&
                  after != null &&
                  identical(after, result.decision) &&
                  after.status.value == status &&
                  after.signOff.approverIdentity == approver!.trim() &&
                  after.signOff.decisionTimestamp == timestamp;
            } else {
              // Rejected: the prior state is retained byte-for-byte (same
              // instance) and an error is returned.
              return result.error != null &&
                  result.decision == null &&
                  identical(after, before);
            }
          },
          [statusGen, approverGen, timestampGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // -- Facet (c): only the two wire strings are ever a valid status ----
      // Confirms the status half of the iff: an accepted decision's persisted
      // status is always exactly one of the two enum wire values, and an
      // invalid status is the surfaced error code.
      test('Property 31 (c): an accepted decision always carries an exact '
          '"deferred"/"scheduled" status; an invalid status yields '
          'INVALID_STATUS (R27.1)', () {
        final held = forAll(
          (String? status, String? approver, DateTime? timestamp) {
            final registry = ProductDecisionRegistry();
            const capability = ProductCapability.eWayBill;

            final result = registry.record(
              capability: capability,
              status: status,
              approverIdentity: approver,
              decisionTimestamp: timestamp,
            );

            final statusValid = status == 'deferred' || status == 'scheduled';

            if (result.isValid) {
              final value = result.decision!.status.value;
              return statusValid &&
                  (value == 'deferred' || value == 'scheduled') &&
                  value == status;
            }

            // Status is checked first: when the status itself is invalid the
            // error must be INVALID_STATUS regardless of the sign-off.
            if (!statusValid) {
              return result.error!.code == 'INVALID_STATUS';
            }
            // Valid status but rejected => the sign-off was incomplete.
            return result.error!.code == 'INCOMPLETE_SIGNOFF';
          },
          [statusGen, approverGen, timestampGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });
    },
  );
}
