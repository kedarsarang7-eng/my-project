/// Reconciliation logic for the Certification_System.
///
/// Detects orphaned references across invoice/payment/inventory/ledger records
/// and computes net aggregate balance difference (expected 0.00 after sync).
///
/// Pure logic, no I/O. Uses package:decimal for precision.
///
/// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5
library;

import 'package:decimal/decimal.dart';

/// An orphaned foreign-key reference detected during reconciliation.
///
/// An orphan exists when a record's [parentId] does not resolve to any other
/// record's [id] within the same record set (Req 11.1, 11.2).
class OrphanRef {
  /// The type of the record containing the broken reference.
  /// One of: 'invoice', 'payment', 'inventory', 'ledger'.
  final String recordType;

  /// The id of the record that contains the orphaned reference.
  final String recordId;

  /// The foreign key value that doesn't resolve to any parent.
  final String referencedId;

  OrphanRef({
    required this.recordType,
    required this.recordId,
    required this.referencedId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrphanRef &&
          runtimeType == other.runtimeType &&
          recordType == other.recordType &&
          recordId == other.recordId &&
          referencedId == other.referencedId;

  @override
  int get hashCode => Object.hash(recordType, recordId, referencedId);

  @override
  String toString() =>
      'OrphanRef(recordType: $recordType, recordId: $recordId, '
      'referencedId: $referencedId)';
}

/// A single entry in a record set (invoice, payment, inventory, or ledger).
class RecordEntry {
  /// Unique identifier of this record.
  final String id;

  /// The record type: 'invoice', 'payment', 'inventory', or 'ledger'.
  final String type;

  /// The monetary/quantity amount for this record.
  final Decimal amount;

  /// Foreign key to a parent record; null if this is a root record.
  final String? parentId;

  RecordEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.parentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          amount == other.amount &&
          parentId == other.parentId;

  @override
  int get hashCode => Object.hash(id, type, amount, parentId);

  @override
  String toString() =>
      'RecordEntry(id: $id, type: $type, amount: $amount, '
      'parentId: $parentId)';
}

/// A collection of record entries representing a point-in-time snapshot
/// of invoice, payment, inventory, and ledger records.
class RecordSet {
  final List<RecordEntry> entries;

  RecordSet(this.entries);

  /// All unique record ids in this set.
  Set<String> get ids => entries.map((e) => e.id).toSet();

  /// Compute the aggregate balance (sum of all amounts) for this record set.
  Decimal get aggregateBalance {
    if (entries.isEmpty) return Decimal.zero;
    return entries.fold<Decimal>(
      Decimal.zero,
      (sum, entry) => sum + entry.amount,
    );
  }
}

/// Result of a full reconciliation check.
///
/// The check passes if and only if there are zero orphaned references AND
/// the net difference is exactly 0.00 (Req 11.5).
class ReconciliationResult {
  /// All orphaned references found in the record set.
  final List<OrphanRef> orphans;

  /// Net difference between aggregate balances (before vs after sync).
  /// Expected to be 0.00 for a passing check.
  final Decimal netDifference;

  /// True iff orphans is empty AND netDifference == 0.00.
  final bool passed;

  ReconciliationResult({
    required this.orphans,
    required this.netDifference,
    required this.passed,
  });

  @override
  String toString() =>
      'ReconciliationResult(passed: $passed, orphans: ${orphans.length}, '
      'netDifference: $netDifference)';
}

/// Pure reconciliation checker for the Data Integrity Quality Gate.
///
/// Detects orphaned references (Req 11.1, 11.2) and computes net aggregate
/// balance difference (Req 11.3, 11.4). The full check combines both
/// conditions (Req 11.5).
class ReconciliationChecker {
  /// Detect orphaned references: any entry with a non-null [parentId] that
  /// doesn't resolve to another entry's [id] within the same record set.
  ///
  /// Returns a list of [OrphanRef] describing each broken foreign-key
  /// reference. An empty list means all references are valid (Req 11.1).
  ///
  /// If any orphan is found, the Data Integrity Quality Gate fails and
  /// a release-blocking Defect should be recorded (Req 11.2).
  List<OrphanRef> findOrphans(RecordSet records) {
    final validIds = records.ids;
    final orphans = <OrphanRef>[];

    for (final entry in records.entries) {
      if (entry.parentId != null && !validIds.contains(entry.parentId)) {
        orphans.add(
          OrphanRef(
            recordType: entry.type,
            recordId: entry.id,
            referencedId: entry.parentId!,
          ),
        );
      }
    }

    return orphans;
  }

  /// Compute net aggregate balance difference between two record sets
  /// (e.g., before and after sync).
  ///
  /// Returns the difference: after.aggregateBalance - before.aggregateBalance.
  /// Expected to be 0.00 after a valid synchronization (Req 11.3).
  ///
  /// If the difference is not 0.00, the Data Integrity Quality Gate fails
  /// and a release-blocking Defect should be recorded identifying the
  /// inconsistent record sets and the computed difference (Req 11.4).
  Decimal netDifference(RecordSet before, RecordSet after) {
    return after.aggregateBalance - before.aggregateBalance;
  }

  /// Full reconciliation check combining orphan detection and balance
  /// difference verification.
  ///
  /// The check passes if and only if:
  /// - There are zero orphaned references in [records], AND
  /// - The net difference between [records] and [afterSync] is exactly 0.00
  ///   (or [afterSync] is null, in which case only orphan detection applies
  ///   and difference is treated as 0.00).
  ///
  /// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5
  ReconciliationResult check(RecordSet records, RecordSet? afterSync) {
    final orphans = findOrphans(records);

    final difference = afterSync != null
        ? netDifference(records, afterSync)
        : Decimal.zero;

    final passed = orphans.isEmpty && difference == Decimal.zero;

    return ReconciliationResult(
      orphans: orphans,
      netDifference: difference,
      passed: passed,
    );
  }
}
