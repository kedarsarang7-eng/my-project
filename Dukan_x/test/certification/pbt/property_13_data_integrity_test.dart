// Feature: comprehensive-test-certification, Property 13
//
// Property 13: Data-integrity verdict requires zero orphans and a zero
// reconciliation difference.
//
// For any record set over invoice, payment, inventory, and ledger records, the
// Data_Integrity Quality_Gate passes if and only if every foreign-key reference
// resolves to an existing parent (zero orphaned references) and the net
// difference between corresponding aggregate reconciliation balances is exactly
// 0.00 currency units; otherwise the gate fails and the Defect identifies the
// orphaned references and/or the inconsistent record sets together with the
// computed difference.
//
// **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_13_data_integrity_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/reconciliation.dart';
import '../pbt/generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// Valid record types used by the reconciliation checker.
const List<String> _recordTypes = ['invoice', 'payment', 'inventory', 'ledger'];

/// Generates a record type string.
final Generator<String> _recordTypeGen = Gen.elementOf<String>(_recordTypes);

/// Generates a list length for record sets (1–10 entries).
final Generator<int> _listLenGen = Gen.interval(1, 10);

/// Generates a small positive integer for unique id suffixes.
final Generator<int> _idSuffixGen = Gen.interval(1, 9999);

// ============================================================================
// TESTS
// ============================================================================

void main() {
  final checker = ReconciliationChecker();

  group('Feature: comprehensive-test-certification, Property 13: '
      'Data-integrity verdict requires zero orphans and a zero '
      'reconciliation difference', () {
    // FORWARD: A record set with all valid references and identical
    // before/after sets → passed=true, orphans empty, netDifference=0.00
    test('Property 13 FORWARD: valid references + identical before/after '
        '→ passed=true, orphans empty, netDifference=0.00', () {
      final held = forAll(
        (int listLen, int idBase, Decimal amount1, Decimal amount2) {
          // Build a record set where all parentIds resolve to existing ids.
          // Root records have no parentId; child records reference a root.
          final entries = <RecordEntry>[];
          final len = (listLen % 10) + 1; // 1–10

          // Create root entries (no parentId)
          for (var i = 0; i < len; i++) {
            entries.add(
              RecordEntry(
                id: 'rec-${idBase + i}',
                type: _recordTypes[i % _recordTypes.length],
                amount: i.isEven ? amount1 : amount2,
              ),
            );
          }

          // Add some child entries that reference valid roots
          if (len >= 2) {
            entries.add(
              RecordEntry(
                id: 'child-${idBase + len}',
                type: _recordTypes[(len + 1) % _recordTypes.length],
                amount: amount1,
                parentId: 'rec-$idBase', // references first root (valid)
              ),
            );
          }

          final recordSet = RecordSet(entries);

          // Use same record set for before and after (identical → diff = 0.00)
          final result = checker.check(recordSet, recordSet);

          // Must pass: zero orphans and zero difference
          return result.passed == true &&
              result.orphans.isEmpty &&
              result.netDifference == Decimal.zero;
        },
        [_listLenGen, _idSuffixGen, moneyGen, moneyGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // REJECTION (orphans): A record with parentId that doesn't exist
    // → passed=false, orphans non-empty
    test('Property 13 REJECTION (orphans): parentId referencing non-existent '
        'record → passed=false, orphans non-empty', () {
      final held = forAll(
        (int idBase, Decimal amount, String recordType) {
          // Create a record set with at least one orphaned reference.
          // The root record exists, but a child references a non-existent parent.
          final entries = <RecordEntry>[
            RecordEntry(id: 'root-$idBase', type: recordType, amount: amount),
            RecordEntry(
              id: 'orphan-$idBase',
              type: recordType,
              amount: amount,
              parentId:
                  'non-existent-${idBase + 9999}', // ORPHAN: doesn't exist
            ),
          ];

          final recordSet = RecordSet(entries);

          // Use same record set for after (so difference is 0.00),
          // but orphans should still cause failure.
          final result = checker.check(recordSet, recordSet);

          // Must fail: orphans present
          return result.passed == false && result.orphans.isNotEmpty;
        },
        [_idSuffixGen, moneyGen, _recordTypeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // REJECTION (difference): Before and after sets with different aggregate
    // balances → passed=false, netDifference ≠ 0
    test('Property 13 REJECTION (difference): different aggregate balances '
        '→ passed=false, netDifference ≠ 0', () {
      final held = forAll(
        (int idBase, Decimal amount1, Decimal amount2, String recordType) {
          // Ensure the amounts are actually different so balances differ.
          // If they happen to be equal, tweak one slightly.
          final adjustedAmount2 = amount1 == amount2
              ? amount2 + Decimal.parse('0.01')
              : amount2;

          // Before set: one root record with amount1
          final beforeEntries = <RecordEntry>[
            RecordEntry(
              id: 'before-$idBase',
              type: recordType,
              amount: amount1,
            ),
          ];

          // After set: one root record with a different amount
          final afterEntries = <RecordEntry>[
            RecordEntry(
              id: 'after-$idBase',
              type: recordType,
              amount: adjustedAmount2,
            ),
          ];

          final beforeSet = RecordSet(beforeEntries);
          final afterSet = RecordSet(afterEntries);

          // Before set has no orphans (no parentId references)
          final result = checker.check(beforeSet, afterSet);

          // Must fail: net difference != 0
          return result.passed == false && result.netDifference != Decimal.zero;
        },
        [_idSuffixGen, moneyGen, moneyGen, _recordTypeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
