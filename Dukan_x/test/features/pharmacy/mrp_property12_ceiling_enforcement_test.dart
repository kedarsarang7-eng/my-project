// ============================================================================
// TASK 3.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 12: MRP ceiling enforcement
// **Validates: Requirements 8.1, 8.2, 8.3, 8.4**
// ============================================================================
//
// Property 12 (design.md — Correctness Properties):
//   "For any line item with selling price and MRP expressed in paise, the line
//    item is permitted (at entry and at persistence) if and only if its selling
//    price is less than or equal to its MRP; if any line item's selling price
//    strictly exceeds its MRP, the line item is blocked and the entire bill is
//    rejected without altering any previously stored record, identifying the
//    violating items."
//
// The property is proven against an INDEPENDENT ORACLE that restates the
// acceptance criteria in plain integer logic and never calls the production
// comparison:
//
//   permitted(selling, mrp) :=
//       (mrp == null || mrp <= 0)   // MRP genuinely unknown → non-blocking
//       ? true
//       : selling <= mrp;           // ceiling holds iff selling ≤ mrp
//
// A line VIOLATES iff `mrp != null && mrp > 0 && selling > mrp`.
//
// Two surfaces are exercised, matching "at entry and at persistence":
//   (A) ENTRY  — `MrpEnforcementValidator.isMrpCompliant(sellingPaise, mrpPaise)`
//       must equal the oracle for every (selling, mrp) pair, including the
//       null / ≤0 (unknown-MRP) non-blocking cases.
//   (B) PERSISTENCE — `validateBill(bill, lookup)` must be compliant iff NO
//       line violates; on any violation the whole-bill result is non-compliant
//       (rejection), the reported violators are EXACTLY the violating lines
//       (each carrying the correct selling/MRP paise), and the bill's stored
//       line data is left unaltered (the validator never mutates records).
//
// Selling prices are generated as whole paise and fed to the bill as exact
// rupee values (`paise / 100`), which `Paise.fromRupees` round-trips back to
// the same whole paise (see Property 3) — so `validateBill`'s internal
// rupee→paise conversion reproduces the generated selling paise exactly.
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard). `forAll` returns true
// when the property held for every run and throws a shrinking counterexample
// otherwise.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/mrp_property12_ceiling_enforcement_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/models/bill.dart';
import 'package:dukanx/utils/mrp_enforcement_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// Upper bound on a single MRP/selling value in paise — the product-entry range
/// ceiling (R8.5, 99,999,999 paise = ₹999,999.99). Comfortably inside IEEE
/// double exact-integer territory so the `paise/100` round-trip is exact.
const int kMaxPaise = 99999999;

// ---------------------------------------------------------------------------
// Independent oracle (pure integer logic; never calls production comparison)
// ---------------------------------------------------------------------------

/// The acceptance-criteria definition of "permitted": a null/≤0 MRP is unknown
/// and therefore non-blocking; otherwise the line is permitted iff selling ≤ mrp.
bool _oraclePermitted(int sellingPaise, int? mrpPaise) {
  if (mrpPaise == null || mrpPaise <= 0) return true;
  return sellingPaise <= mrpPaise;
}

// ---------------------------------------------------------------------------
// Case model + generators
// ---------------------------------------------------------------------------

/// One bill line: a selling price (paise) and an MRP that may be unknown
/// (`null`), non-positive (treated as unknown), at/above, or below the price.
class _LineSpec {
  const _LineSpec(this.sellingPaise, this.mrpPaise);
  final int sellingPaise;
  final int? mrpPaise;
}

class _BillCase {
  const _BillCase(this.lines);
  final List<_LineSpec> lines;
}

/// A single line. The MRP value spans negatives, zero, and the full positive
/// range so the unknown-MRP (null/≤0), compliant (mrp ≥ selling), and violating
/// (0 < mrp < selling) regions all co-occur across runs.
final Generator<_LineSpec> _lineGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(1, kMaxPaise), // 0: selling price in paise (≥ 1)
      Gen.interval(0, 1), // 1: MRP present flag (0 ⇒ null/unknown)
      Gen.interval(-1000, kMaxPaise), // 2: MRP value (may be ≤ 0)
    ]).map((parts) {
      final int selling = parts[0] as int;
      final bool present = (parts[1] as int) == 1;
      final int mrpValue = parts[2] as int;
      return _LineSpec(selling, present ? mrpValue : null);
    });

/// A bill of 1..8 lines drawn from [_lineGen]; mixes compliant and violating
/// lines so single- and multi-violation rejection are both exercised.
final Generator<_BillCase> _billCaseGen = Gen.array<_LineSpec>(
  _lineGen,
  minLength: 1,
  maxLength: 8,
).map((lines) => _BillCase(lines.cast<_LineSpec>().toList()));

// ---------------------------------------------------------------------------
// Builders — turn a case into a Bill + MrpLookup the validator consumes
// ---------------------------------------------------------------------------

Bill _buildBill(_BillCase c) {
  final items = <BillItem>[];
  for (var i = 0; i < c.lines.length; i++) {
    items.add(
      BillItem(
        productId: 'p$i',
        productName: 'Item $i',
        qty: 1,
        // Selling paise fed as an exact rupee value; Paise.fromRupees inside
        // validateBill round-trips this back to the same whole paise.
        price: c.lines[i].sellingPaise / 100.0,
      ),
    );
  }
  return Bill(
    id: 'bill-under-test',
    customerId: 'cust',
    date: DateTime(2024, 1, 1),
    items: items,
  );
}

MrpLookup _buildLookup(_BillCase c) {
  final map = <String, int?>{};
  for (var i = 0; i < c.lines.length; i++) {
    map['p$i'] = c.lines[i].mrpPaise;
  }
  return MrpLookup.fromProductMrpPaise(map);
}

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 12: MRP ceiling '
      'enforcement — Req 8.1, 8.2, 8.3, 8.4', () {
    // ----------------------------------------------------------------------
    // (A) ENTRY: isMrpCompliant matches the acceptance-criteria oracle for
    //     every (selling, mrp) pair, including unknown-MRP (null/≤0) cases.
    //     (R8.1, R8.2)
    // ----------------------------------------------------------------------
    test('Property 12a: isMrpCompliant(selling, mrp) is true iff selling ≤ mrp '
        '(null/≤0 MRP non-blocking)', () {
      final bool held = forAll(
        (_LineSpec line) {
          final actual = MrpEnforcementValidator.isMrpCompliant(
            line.sellingPaise,
            line.mrpPaise,
          );
          final expected = _oraclePermitted(line.sellingPaise, line.mrpPaise);
          return actual == expected;
        },
        [_lineGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'A line is permitted at entry iff its selling price is ≤ its '
            'MRP; a null or non-positive MRP is non-blocking.',
      );
    });

    // ----------------------------------------------------------------------
    // (B) PERSISTENCE: validateBill is compliant iff no line violates; on any
    //     violation the whole bill is rejected, the violators reported are
    //     exactly the violating lines (with correct selling/MRP paise), and
    //     the stored line data is left unaltered. (R8.3, R8.4)
    // ----------------------------------------------------------------------
    test(
      'Property 12b: validateBill rejects the whole bill iff any line exceeds '
      'its MRP, identifies exactly the violators, and mutates nothing',
      () {
        final bool held = forAll(
          (_BillCase c) {
            final bill = _buildBill(c);
            final lookup = _buildLookup(c);

            // Snapshot stored line data to prove the validator does not
            // alter any record (R8.4 "without altering any previously
            // stored record").
            final beforePrices = bill.items.map((e) => e.price).toList();
            final beforeIds = bill.items.map((e) => e.productId).toList();

            final result = MrpEnforcementValidator.validateBill(bill, lookup);

            // Expected violators per the oracle, keyed by productId.
            final expectedViolators = <String, _LineSpec>{};
            for (var i = 0; i < c.lines.length; i++) {
              final line = c.lines[i];
              if (!_oraclePermitted(line.sellingPaise, line.mrpPaise)) {
                expectedViolators['p$i'] = line;
              }
            }

            // 1. Compliance iff no line violates (whole-bill rejection).
            if (result.isCompliant != expectedViolators.isEmpty) return false;

            // 2. Reported violator ids are EXACTLY the expected set.
            final reportedIds = result.violations
                .map((v) => v.productId)
                .toSet();
            if (reportedIds.length != result.violations.length) {
              return false; // no duplicate entries
            }
            if (reportedIds.length != expectedViolators.length) return false;
            if (!reportedIds.containsAll(expectedViolators.keys)) return false;

            // 3. Each violation carries the correct selling/MRP paise and a
            //    non-empty identifying message.
            for (final v in result.violations) {
              final line = expectedViolators[v.productId];
              if (line == null) return false;
              if (v.sellingPaise != line.sellingPaise) return false;
              if (v.mrpPaise != line.mrpPaise) return false;
              if (v.message.isEmpty) return false;
            }

            // 4. No stored record was altered by validation.
            final afterPrices = bill.items.map((e) => e.price).toList();
            final afterIds = bill.items.map((e) => e.productId).toList();
            if (afterPrices.length != beforePrices.length) return false;
            for (var i = 0; i < beforePrices.length; i++) {
              if (afterPrices[i] != beforePrices[i]) return false;
              if (afterIds[i] != beforeIds[i]) return false;
            }

            return true;
          },
          [_billCaseGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'A bill is compliant iff every line is at/below its MRP; any '
              'violation rejects the whole bill, names exactly the violating '
              'lines, and leaves stored records unchanged.',
        );
      },
    );

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin the boundary and prove non-vacuity.
    // ----------------------------------------------------------------------
    test('Property 12 anchors: entry-level boundary and unknown-MRP cases', () {
      // Equal → permitted (≤ is inclusive).
      expect(MrpEnforcementValidator.isMrpCompliant(5000, 5000), isTrue);
      // Below → permitted.
      expect(MrpEnforcementValidator.isMrpCompliant(4999, 5000), isTrue);
      // Above by one paise → blocked.
      expect(MrpEnforcementValidator.isMrpCompliant(5001, 5000), isFalse);
      // Unknown MRP (null / zero / negative) → non-blocking.
      expect(MrpEnforcementValidator.isMrpCompliant(5000, null), isTrue);
      expect(MrpEnforcementValidator.isMrpCompliant(5000, 0), isTrue);
      expect(MrpEnforcementValidator.isMrpCompliant(5000, -1), isTrue);
    });

    test('Property 12 anchors: a single violating line rejects the whole bill '
        'and is identified without mutation', () {
      final bill = Bill(
        id: 'b1',
        customerId: 'c1',
        date: DateTime(2024, 1, 1),
        items: [
          BillItem(
            productId: 'ok',
            productName: 'Compliant',
            qty: 1,
            price: 50.00,
          ),
          BillItem(
            productId: 'bad',
            productName: 'Over MRP',
            qty: 1,
            price: 80.00,
          ),
        ],
      );
      final lookup = MrpLookup.fromProductMrpPaise(<String, int?>{
        'ok': 5000, // 50.00 ≤ 50.00 → compliant
        'bad': 7000, // 80.00 > 70.00 → violation
      });

      final result = MrpEnforcementValidator.validateBill(bill, lookup);

      expect(result.isCompliant, isFalse, reason: 'whole bill is rejected');
      expect(result.violations.length, 1);
      expect(result.violations.single.productId, 'bad');
      expect(result.violations.single.sellingPaise, 8000);
      expect(result.violations.single.mrpPaise, 7000);
      // Stored records unchanged by validation.
      expect(bill.items[0].price, 50.00);
      expect(bill.items[1].price, 80.00);
    });

    test('Property 12 anchors: a fully compliant bill is accepted with no '
        'violations', () {
      final bill = Bill(
        id: 'b2',
        customerId: 'c2',
        date: DateTime(2024, 1, 1),
        items: [
          BillItem(productId: 'a', productName: 'A', qty: 1, price: 10.00),
          BillItem(productId: 'b', productName: 'B', qty: 1, price: 25.00),
        ],
      );
      final lookup = MrpLookup.fromProductMrpPaise(<String, int?>{
        'a': 1000, // equal → ok
        'b': 9999, // below → ok
      });

      final result = MrpEnforcementValidator.validateBill(bill, lookup);

      expect(result.isCompliant, isTrue);
      expect(result.violations, isEmpty);
    });
  });
}
