// AUDIT_SYSTEM — OUTBOX STRUCTURE & DRAIN-ORDERING CLASSIFIER (Task 15.1)
//
// Pure decision logic for the per-screen verification of offline-to-online
// synchronization safety. This file currently owns the two foundational pieces
// of the Outbox model:
//
//   1. Record structure (Req 9.1) — every persisted Outbox record SHALL carry a
//      unique mutation identifier AND one ordering key that is either a
//      monotonically increasing version number or an ISO-8601 UTC timestamp.
//      Both ordering-key kinds are modeled as a single comparable abstraction
//      ([OutboxOrderingKey]) so callers can choose either without branching.
//
//   2. Oldest-first drain ordering (Req 9.2) — draining the Outbox SHALL emit
//      pending mutations in strictly ascending (oldest-first) order by their
//      ordering key.
//
// The Sync_Engine mechanism (conditional DynamoDB writes, conflict
// reconciliation, retry/backoff) is owned conceptually by the running app and
// the sibling sync feature; this file only models the per-screen verification
// that those rules were applied correctly. The conditional-write/conflict
// reconciliation classifier (Task 15.4, Req 9.3/9.4) and the retry-bound
// classifier (Task 15.6, Req 7.5/9.5/9.6) are SEPARATE additions appended to
// this file later — the types here (notably [OutboxOrderingKey] and
// [OutboxRecord]) are the shared substrate they will build on.
//
// This file is PURE, dependency-light Dart (only `dart:core`), so it imports
// cleanly into `flutter_test` + `dartproptest` VM suites, matching the rest of
// the Audit_System governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 15.1)
// _Requirements: 9.1, 9.2_

/// Which kind of ordering key an Outbox record uses (Req 9.1). An Outbox SHOULD
/// use a single, consistent kind across all of its records; mixing kinds is
/// permitted by the model but discouraged (see [OutboxOrderingKey.compareTo]).
enum OutboxKeyKind {
  /// A monotonically increasing integer version number.
  version,

  /// An ISO-8601 UTC timestamp.
  timestamp,
}

/// The ordering key carried by every Outbox record (Req 9.1).
///
/// A record's position in the drain order is determined entirely by this key.
/// It is one of exactly two variants — [VersionKey] (a monotonically increasing
/// integer) or [TimestampKey] (an ISO-8601 UTC timestamp) — unified here as a
/// single [Comparable] type so drain ordering (Req 9.2) need not branch on the
/// key kind.
///
/// Ordering across the two variants is total and deterministic: all
/// [VersionKey]s sort before all [TimestampKey]s. Within a single kind the
/// natural order applies. In practice an Outbox uses one kind throughout, so
/// the cross-kind rule only guards against accidental mixing.
sealed class OutboxOrderingKey implements Comparable<OutboxOrderingKey> {
  const OutboxOrderingKey();

  /// The kind of this ordering key.
  OutboxKeyKind get kind;

  @override
  int compareTo(OutboxOrderingKey other) {
    // Same-kind comparisons use the variant's natural order. Cross-kind
    // comparisons fall back to a stable ordinal so the order stays total.
    if (this is VersionKey && other is VersionKey) {
      return (this as VersionKey).version.compareTo(other.version);
    }
    if (this is TimestampKey && other is TimestampKey) {
      return (this as TimestampKey).utc.compareTo((other).utc);
    }
    return kind.index.compareTo(other.kind.index);
  }
}

/// A monotonically increasing integer version ordering key (Req 9.1).
///
/// Larger [version] values are "newer" and therefore drain later.
final class VersionKey extends OutboxOrderingKey {
  const VersionKey(this.version);

  /// The monotonically increasing version number.
  final int version;

  @override
  OutboxKeyKind get kind => OutboxKeyKind.version;

  @override
  bool operator ==(Object other) =>
      other is VersionKey && other.version == version;

  @override
  int get hashCode => version.hashCode;

  @override
  String toString() => 'VersionKey($version)';
}

/// An ISO-8601 UTC timestamp ordering key (Req 9.1).
///
/// Later instants are "newer" and therefore drain later. The wrapped
/// [DateTime] is always stored in UTC, and [iso8601] renders the canonical
/// ISO-8601 UTC string (e.g. `2024-01-02T03:04:05.000Z`).
final class TimestampKey extends OutboxOrderingKey {
  /// Wrap an existing [DateTime], normalizing it to UTC.
  TimestampKey(DateTime instant) : utc = instant.toUtc();

  /// Parse an ISO-8601 string into a UTC [TimestampKey].
  ///
  /// Throws a [FormatException] if [iso8601] is not a valid ISO-8601 date-time.
  factory TimestampKey.parse(String iso8601) =>
      TimestampKey(DateTime.parse(iso8601));

  /// The instant of this key, always in UTC.
  final DateTime utc;

  @override
  OutboxKeyKind get kind => OutboxKeyKind.timestamp;

  /// The canonical ISO-8601 UTC representation of this key.
  String get iso8601 => utc.toIso8601String();

  @override
  bool operator ==(Object other) =>
      other is TimestampKey && other.utc.isAtSameMomentAs(utc);

  @override
  int get hashCode => utc.microsecondsSinceEpoch.hashCode;

  @override
  String toString() => 'TimestampKey($iso8601)';
}

/// A single pending mutation persisted in the durable Outbox (Req 9.1).
///
/// Each record carries a [mutationId] that uniquely identifies the mutation and
/// an [orderingKey] that fixes its drain position (Req 9.2). The optional
/// [screenPath] records which Screen produced the mutation (used by later
/// failure-reporting in Task 15.6), and [description] is a human-readable note.
class OutboxRecord {
  OutboxRecord({
    required this.mutationId,
    required this.orderingKey,
    this.screenPath,
    this.description,
  });

  /// The unique identifier of this mutation (Req 9.1).
  final String mutationId;

  /// The ordering key fixing this record's drain position (Req 9.1, 9.2).
  final OutboxOrderingKey orderingKey;

  /// Optional path of the Screen that produced this mutation.
  final String? screenPath;

  /// Optional human-readable note describing the mutation.
  final String? description;

  @override
  String toString() =>
      'OutboxRecord($mutationId, $orderingKey'
      '${screenPath == null ? '' : ', screen=$screenPath'})';
}

/// Why an Outbox record (or set of records) failed structural verification
/// (Req 9.1). [valid] means every checked record is well-formed.
enum OutboxStructureViolation {
  /// The record set is structurally valid.
  valid,

  /// A record has an empty (or whitespace-only) mutation identifier.
  emptyMutationId,

  /// Two or more records share the same mutation identifier.
  duplicateMutationId,
}

/// The outcome of verifying Outbox record structure across a set of records
/// (Req 9.1).
class OutboxStructureResult {
  OutboxStructureResult({required this.violation, this.offendingMutationId});

  /// The structural violation found, or [OutboxStructureViolation.valid].
  final OutboxStructureViolation violation;

  /// The mutation id involved in the violation, when applicable.
  final String? offendingMutationId;

  /// True iff every checked record carries a unique, non-empty mutation id and
  /// a valid ordering key (Req 9.1).
  bool get isValid => violation == OutboxStructureViolation.valid;

  @override
  String toString() =>
      'OutboxStructureResult(${violation.name}'
      '${offendingMutationId == null ? '' : ', id=$offendingMutationId'})';
}

/// Pure classifier for Outbox record structure and drain ordering
/// (Req 9.1, 9.2).
///
/// This classifier is deliberately narrow: it verifies that a set of records is
/// structurally well-formed and computes the oldest-first drain order. The
/// conditional-write/conflict reconciliation classifier (Task 15.4) and the
/// retry-bound classifier (Task 15.6) are separate types appended to this file
/// later; they reuse [OutboxRecord] and [OutboxOrderingKey] from here.
class OutboxClassifier {
  const OutboxClassifier();

  /// Verify that every record in [records] has a non-empty mutation id and that
  /// all mutation ids are unique (Req 9.1).
  ///
  /// The ordering key is intrinsically valid by construction ([VersionKey] /
  /// [TimestampKey]), so structural verification focuses on the mutation id.
  OutboxStructureResult verifyStructure(Iterable<OutboxRecord> records) {
    final seen = <String>{};
    for (final record in records) {
      final id = record.mutationId.trim();
      if (id.isEmpty) {
        return OutboxStructureResult(
          violation: OutboxStructureViolation.emptyMutationId,
          offendingMutationId: record.mutationId,
        );
      }
      if (!seen.add(record.mutationId)) {
        return OutboxStructureResult(
          violation: OutboxStructureViolation.duplicateMutationId,
          offendingMutationId: record.mutationId,
        );
      }
    }
    return OutboxStructureResult(violation: OutboxStructureViolation.valid);
  }

  /// True iff every record in [records] is structurally well-formed (Req 9.1).
  bool isStructurallyValid(Iterable<OutboxRecord> records) =>
      verifyStructure(records).isValid;

  /// Return [records] in oldest-first drain order (Req 9.2).
  ///
  /// Records are ordered by their [OutboxRecord.orderingKey] in strictly
  /// ascending order, so the oldest (lowest version / earliest timestamp)
  /// mutation is transmitted first. The input is not mutated — a new list is
  /// returned. The sort is stable, so records sharing an equal ordering key
  /// retain their relative input order.
  List<OutboxRecord> drainOrder(Iterable<OutboxRecord> records) {
    final ordered = records.toList();
    _stableSortByKey(ordered);
    return ordered;
  }

  /// Stable insertion-equivalent sort by ordering key. Dart's [List.sort] is
  /// not guaranteed stable, so we sort on a (key, originalIndex) pair to keep
  /// the order of equal-keyed records deterministic.
  void _stableSortByKey(List<OutboxRecord> records) {
    final indexed = <_IndexedRecord>[
      for (var i = 0; i < records.length; i++) _IndexedRecord(i, records[i]),
    ];
    indexed.sort((a, b) {
      final byKey = a.record.orderingKey.compareTo(b.record.orderingKey);
      return byKey != 0 ? byKey : a.index.compareTo(b.index);
    });
    for (var i = 0; i < indexed.length; i++) {
      records[i] = indexed[i].record;
    }
  }
}

/// Internal pairing of a record with its original index, used to make the
/// drain-order sort stable.
class _IndexedRecord {
  _IndexedRecord(this.index, this.record);

  final int index;
  final OutboxRecord record;
}

// ---------------------------------------------------------------------------
// CONDITIONAL-WRITE & CONFLICT RECONCILIATION CLASSIFIER (Task 15.4)
//
// Pure decision logic for the per-screen verification that the Sync_Engine
// applies DynamoDB conditional writes and reconciles conflicts correctly:
//
//   • Conditional write (Req 9.3) — a write to the backend is ACCEPTED iff the
//     incoming mutation's guard (version number / timestamp) is STRICTLY
//     GREATER than the stored guard. It is REJECTED as a conflict whenever the
//     stored guard is greater than OR EQUAL TO the incoming guard.
//
//   • Conflict reconciliation (Req 9.4) — when a write is rejected as a
//     conflict, reconciliation retains the record with the higher version /
//     later timestamp (the winner), preserves the losing mutation in a
//     recoverable form, and discards NO committed field value without
//     recording it.
//
// The guard is modeled with the existing [OutboxOrderingKey] hierarchy
// ([VersionKey] / [TimestampKey]) so the same total, deterministic ordering
// used for drain ordering (Req 9.2) governs conflict resolution. This keeps a
// single source of truth for "newer than" across the whole Outbox model.
//
// The retry-bound classifier (Task 15.6, Req 7.5/9.5/9.6) is a SEPARATE
// addition appended after this block; it handles non-conflict failures
// (network errors, timeouts, exhausted retries) and does not overlap with the
// accept/reject + reconciliation logic here.
//
// _Requirements: 9.3, 9.4_

/// A guard-bearing value participating in a conditional write (Req 9.3).
///
/// Models either the value currently stored in DynamoDB or the incoming
/// mutation attempting to overwrite it. The [guard] is the conditional-write
/// guard — a [VersionKey] or [TimestampKey] — and [committedFields] holds the
/// committed field values this value would persist. Reconciliation preserves
/// these fields so a losing mutation stays fully recoverable (Req 9.4).
class GuardedValue {
  GuardedValue({
    required this.mutationId,
    required this.guard,
    Map<String, Object?> committedFields = const {},
  }) : committedFields = Map.unmodifiable(committedFields);

  /// The unique mutation identifier of this value (Req 9.1).
  final String mutationId;

  /// The conditional-write guard (version number or timestamp).
  final OutboxOrderingKey guard;

  /// The committed field values this value carries. Preserved intact through
  /// reconciliation so nothing is silently discarded (Req 9.4).
  final Map<String, Object?> committedFields;

  @override
  String toString() =>
      'GuardedValue($mutationId, $guard, fields=${committedFields.length})';
}

/// The accept/reject outcome of a conditional write (Req 9.3).
enum ConditionalWriteOutcome {
  /// The incoming guard was strictly greater than the stored guard, so the
  /// write is applied.
  accepted,

  /// The stored guard was greater than or equal to the incoming guard, so the
  /// write is rejected as a conflict and must be reconciled (Req 9.4).
  rejected,
}

/// The outcome of reconciling a rejected (conflicting) conditional write
/// (Req 9.4).
///
/// Reconciliation retains the [winner] (the record with the higher version /
/// later timestamp), preserves the [recoverableLoser] in full so it can be
/// recovered, and records every committed field — [discardedCommittedFields]
/// is therefore always empty, and [discardedCommittedField] is always false.
class ReconciliationResult {
  ReconciliationResult({required this.winner, required this.recoverableLoser});

  /// The retained record: the one with the higher version / later timestamp.
  final GuardedValue winner;

  /// The losing mutation, preserved in a recoverable form (its committed
  /// fields are kept intact, never dropped).
  final GuardedValue recoverableLoser;

  /// Committed field values discarded without being recorded. Reconciliation
  /// never discards a committed field, so this is always empty (Req 9.4).
  List<String> get discardedCommittedFields => const [];

  /// True iff any committed field value was discarded without being recorded.
  /// Always false — reconciliation preserves the loser in full (Req 9.4).
  bool get discardedCommittedField => discardedCommittedFields.isNotEmpty;

  @override
  String toString() =>
      'ReconciliationResult(winner=${winner.mutationId}, '
      'recoverableLoser=${recoverableLoser.mutationId}, '
      'discardedCommittedField=$discardedCommittedField)';
}

/// The full result of classifying a conditional write: the accept/reject
/// [outcome] (Req 9.3) and, when rejected as a conflict, the [reconciliation]
/// that resolves it (Req 9.4).
class ConditionalWriteResult {
  ConditionalWriteResult({required this.outcome, this.reconciliation});

  /// Whether the conditional write was accepted or rejected (Req 9.3).
  final ConditionalWriteOutcome outcome;

  /// The reconciliation outcome, present iff the write was rejected as a
  /// conflict (Req 9.4); null when the write was accepted.
  final ReconciliationResult? reconciliation;

  /// True iff the incoming guard was strictly greater than the stored guard.
  bool get isAccepted => outcome == ConditionalWriteOutcome.accepted;

  /// True iff the write was rejected because the stored guard was greater than
  /// or equal to the incoming guard (a conflict requiring reconciliation).
  bool get isConflict => outcome == ConditionalWriteOutcome.rejected;

  @override
  String toString() =>
      'ConditionalWriteResult(${outcome.name}'
      '${reconciliation == null ? '' : ', $reconciliation'})';
}

/// Pure classifier for DynamoDB conditional writes and conflict reconciliation
/// (Req 9.3, 9.4).
///
/// This classifier verifies that the Sync_Engine's write/reconcile behavior is
/// correct; it does not perform the write itself. It reuses
/// [OutboxOrderingKey] so the "newer than" relation is identical to the one
/// governing drain ordering (Req 9.2).
///
/// The retry/backoff behavior for non-conflict failures (Req 9.5, 9.6) is owned
/// by the separate retry-bound classifier (Task 15.6).
class ConditionalWriteClassifier {
  const ConditionalWriteClassifier();

  /// Decide the accept/reject outcome of writing [incoming] over [stored]
  /// (Req 9.3).
  ///
  /// The write is [ConditionalWriteOutcome.accepted] iff [incoming]'s guard is
  /// STRICTLY GREATER than [stored]'s guard. It is
  /// [ConditionalWriteOutcome.rejected] whenever the stored guard is greater
  /// than or equal to the incoming guard. When there is no [stored] value
  /// (first write for the key) the write is always accepted.
  ConditionalWriteOutcome decide({
    GuardedValue? stored,
    required GuardedValue incoming,
  }) {
    if (stored == null) {
      return ConditionalWriteOutcome.accepted;
    }
    final strictlyGreater = incoming.guard.compareTo(stored.guard) > 0;
    return strictlyGreater
        ? ConditionalWriteOutcome.accepted
        : ConditionalWriteOutcome.rejected;
  }

  /// Reconcile a rejected (conflicting) write between [stored] and [incoming]
  /// (Req 9.4).
  ///
  /// Retains the record with the higher version / later timestamp as the
  /// winner; on an exact guard tie the already-committed [stored] value is
  /// retained. The losing mutation is returned as [recoverableLoser] with its
  /// committed fields intact, so no committed field value is discarded.
  ReconciliationResult reconcile({
    required GuardedValue stored,
    required GuardedValue incoming,
  }) {
    final incomingIsNewer = incoming.guard.compareTo(stored.guard) > 0;
    final winner = incomingIsNewer ? incoming : stored;
    final loser = incomingIsNewer ? stored : incoming;
    return ReconciliationResult(winner: winner, recoverableLoser: loser);
  }

  /// Classify writing [incoming] over [stored] end-to-end (Req 9.3, 9.4).
  ///
  /// Returns an accepted result with no reconciliation when the incoming guard
  /// is strictly greater (or there is no stored value); otherwise returns a
  /// rejected result whose [ConditionalWriteResult.reconciliation] retains the
  /// higher-guard record, preserves the loser recoverably, and records no
  /// discarded committed field.
  ConditionalWriteResult classify({
    GuardedValue? stored,
    required GuardedValue incoming,
  }) {
    final outcome = decide(stored: stored, incoming: incoming);
    if (outcome == ConditionalWriteOutcome.accepted) {
      return ConditionalWriteResult(outcome: outcome);
    }
    // Rejected: a stored value must exist (decide accepts when stored is null).
    return ConditionalWriteResult(
      outcome: outcome,
      reconciliation: reconcile(stored: stored!, incoming: incoming),
    );
  }
}

// ---------------------------------------------------------------------------
// RETRY-BOUND CLASSIFIER (Task 15.6)
//
// Pure decision logic for the per-screen verification that non-conflict
// synchronization failures are retried within a bounded budget and that a
// mutation is NEVER silently discarded:
//
//   • Bounded exponential backoff (Req 9.5) — a mutation that fails to
//     synchronize for any reason OTHER than a resolved conflict (network
//     error, timeout, rejected write) remains in the Outbox and is retried up
//     to 5 attempts using exponential backoff starting at 2 seconds. The
//     bounded backoff sequence is exactly [2, 4, 8, 16, 32] seconds — one
//     entry per retry attempt.
//
//   • Exhaustion without silent loss (Req 9.6) — once all 5 attempts have
//     failed, the mutation is RETAINED in the Outbox in a `failed` state with
//     its recorded data intact, and a failure indication is surfaced that
//     NAMES the affected Screen. The mutation is never silently discarded.
//
//   • Offline write retention (Req 7.5) — a write that fails while in
//     Offline_Mode is retained as a pending change with no data discarded;
//     this is the initial `pending` state of the retry status (zero attempts
//     consumed, fully recoverable).
//
// This block reuses [OutboxRecord] (for the mutation identity, screen path and
// payload) from the structure section above. It is intentionally disjoint from
// the conditional-write/conflict classifier (Task 15.4): conflicts are resolved
// by reconciliation (Req 9.3/9.4), whereas this classifier handles the
// non-conflict failure stream (Req 9.5/9.6/7.5).
//
// _Requirements: 7.5, 9.5, 9.6_

/// The maximum number of synchronization attempts a mutation receives before
/// it is retained in a `failed` state (Req 9.5, 9.6).
const int maxOutboxRetryAttempts = 5;

/// The base backoff, in seconds, used before the first retry attempt; each
/// subsequent attempt doubles it (Req 9.5).
const int baseOutboxBackoffSeconds = 2;

/// The terminal classification of a mutation in the retry lifecycle (Req 9.6).
///
/// A mutation is always retained in the Outbox; this only distinguishes whether
/// it may still be retried ([pending]) or has exhausted its budget ([failed]).
/// There is no "discarded" state — silent loss is impossible by construction
/// (Req 9.6, 7.5).
enum OutboxRetryState {
  /// The mutation is retained in the Outbox and may still be retried (its
  /// attempt budget is not yet exhausted). Also the state of an offline write
  /// retained as a pending change (Req 7.5).
  pending,

  /// The mutation exhausted all [maxOutboxRetryAttempts] attempts without
  /// success and is retained in the Outbox with its data intact (Req 9.6).
  failed,
}

/// What the classifier decided for the current failure (Req 9.5, 9.6).
enum OutboxRetryDecision {
  /// Another attempt is scheduled after the computed backoff (Req 9.5).
  retryScheduled,

  /// The attempt budget is exhausted; the mutation is retained in the `failed`
  /// state with a surfaced, screen-naming failure indication (Req 9.6).
  retainedFailed,
}

/// A surfaced failure indication produced when a mutation exhausts its retry
/// budget (Req 9.6, 7.5).
///
/// It always NAMES the affected Screen ([screenPath], falling back to a clearly
/// marked placeholder when the record carried none) and records that the
/// mutation's data is intact and was NOT silently discarded.
class OutboxFailureIndication {
  OutboxFailureIndication({
    required this.mutationId,
    required this.screenPath,
    required this.attemptsMade,
  });

  /// The unique identifier of the mutation that exhausted its retries.
  final String mutationId;

  /// The Screen named in the surfaced failure (Req 9.6). Never empty — when the
  /// source record carried no screen path this is a marked placeholder so the
  /// indication still identifies "which screen" unambiguously.
  final String screenPath;

  /// How many attempts were made before giving up (always
  /// [maxOutboxRetryAttempts]).
  final int attemptsMade;

  /// The mutation's recorded data is retained intact (Req 9.6) — it is never
  /// silently discarded (Req 9.6, 7.5).
  bool get dataIntact => true;

  /// The mutation is never silently discarded; it stays in the Outbox in the
  /// `failed` state (Req 9.6).
  bool get silentlyDiscarded => false;

  /// A human-readable failure message that names the affected Screen.
  String get message =>
      'Synchronization of mutation "$mutationId" on screen "$screenPath" '
      'failed after $attemptsMade attempts. The change is retained in the '
      'Outbox (failed state) with its data intact and was not discarded.';

  @override
  String toString() => 'OutboxFailureIndication($message)';
}

/// The retry lifecycle status of a single Outbox mutation (Req 7.5, 9.5, 9.6).
///
/// Immutable snapshot pairing the [record] with the number of failed attempts
/// consumed ([attemptsMade]), the current [state], and — once exhausted — the
/// surfaced [failureIndication]. Produced and advanced exclusively by
/// [OutboxRetryClassifier] so its invariants always hold.
class OutboxRetryStatus {
  OutboxRetryStatus._({
    required this.record,
    required this.attemptsMade,
    required this.state,
    this.failureIndication,
  });

  /// The mutation this status tracks. Its recorded data is always preserved —
  /// the status never strips or mutates the payload (Req 9.6, 7.5).
  final OutboxRecord record;

  /// The number of synchronization attempts that have failed so far
  /// (0..[maxOutboxRetryAttempts]).
  final int attemptsMade;

  /// Whether the mutation may still be retried or has been retained as failed.
  final OutboxRetryState state;

  /// The surfaced failure indication, present iff [state] is
  /// [OutboxRetryState.failed] (Req 9.6); null while still pending.
  final OutboxFailureIndication? failureIndication;

  /// True while the mutation may still be retried (Req 9.5).
  bool get isPending => state == OutboxRetryState.pending;

  /// True once the mutation has exhausted its retry budget (Req 9.6).
  bool get isFailed => state == OutboxRetryState.failed;

  /// The mutation is ALWAYS retained in the Outbox — in either state — so it is
  /// never silently discarded (Req 9.6, 7.5).
  bool get retainedInOutbox => true;

  /// The mutation's recorded data is always intact: neither retrying nor
  /// failing drops the payload (Req 9.6, 7.5).
  bool get dataIntact => true;

  /// True iff another attempt is permitted (pending and budget remaining).
  bool get canRetry => isPending && attemptsMade < maxOutboxRetryAttempts;

  /// The 1-based number of the next attempt that will be made, or null when the
  /// budget is exhausted.
  int? get nextAttemptNumber => canRetry ? attemptsMade + 1 : null;

  /// The backoff, in seconds, to wait before the next attempt, or null when the
  /// budget is exhausted (Req 9.5).
  int? get nextBackoffSeconds {
    final next = nextAttemptNumber;
    return next == null ? null : _backoffSecondsForAttempt(next);
  }

  /// The backoff [Duration] to wait before the next attempt, or null when the
  /// budget is exhausted (Req 9.5).
  Duration? get nextBackoff {
    final seconds = nextBackoffSeconds;
    return seconds == null ? null : Duration(seconds: seconds);
  }

  @override
  String toString() =>
      'OutboxRetryStatus(${record.mutationId}, attempts=$attemptsMade, '
      '${state.name}${isFailed ? ', failed' : ''})';
}

/// The full result of classifying one non-conflict failure: the [decision]
/// taken and the resulting [status] (Req 9.5, 9.6).
class OutboxRetryClassification {
  OutboxRetryClassification({required this.decision, required this.status});

  /// Whether a retry was scheduled or the mutation was retained as failed.
  final OutboxRetryDecision decision;

  /// The post-failure retry status (always retained, data intact).
  final OutboxRetryStatus status;

  /// True iff a further attempt was scheduled (Req 9.5).
  bool get willRetry => decision == OutboxRetryDecision.retryScheduled;

  /// True iff the mutation exhausted its budget and is retained as failed
  /// (Req 9.6).
  bool get exhausted => decision == OutboxRetryDecision.retainedFailed;

  /// The backoff, in seconds, before the scheduled retry, or null when
  /// exhausted (Req 9.5).
  int? get backoffSeconds =>
      status.isPending ? _backoffSecondsForAttempt(status.attemptsMade) : null;

  @override
  String toString() => 'OutboxRetryClassification(${decision.name}, $status)';
}

/// Backoff, in seconds, before retry [attempt] (1-based). Doubles from
/// [baseOutboxBackoffSeconds]: attempt 1 → 2s, 2 → 4s, … 5 → 32s (Req 9.5).
///
/// Shared by [OutboxRetryStatus] and [OutboxRetryClassification] so the
/// sequence has a single source of truth. Throws [RangeError] outside
/// 1..[maxOutboxRetryAttempts].
int _backoffSecondsForAttempt(int attempt) {
  if (attempt < 1 || attempt > maxOutboxRetryAttempts) {
    throw RangeError.range(attempt, 1, maxOutboxRetryAttempts, 'attempt');
  }
  return baseOutboxBackoffSeconds << (attempt - 1);
}

/// Pure classifier for the bounded retry of non-conflict synchronization
/// failures, with no silent loss (Req 7.5, 9.5, 9.6).
///
/// It does not perform retries or wait; it verifies the per-screen rule that a
/// failed (non-conflict) mutation is retried at most [maxOutboxRetryAttempts]
/// times on the [boundedBackoffSequence], and on exhaustion is retained in a
/// `failed` state with its data intact and a screen-naming failure surfaced.
///
/// Conflict resolution (Req 9.3/9.4) is owned by [ConditionalWriteClassifier];
/// this classifier only handles the non-conflict failure stream.
class OutboxRetryClassifier {
  const OutboxRetryClassifier();

  /// The backoff, in seconds, before retry [attempt] (1-based), doubling from
  /// 2s: 2, 4, 8, 16, 32 (Req 9.5). Throws [RangeError] outside
  /// 1..[maxOutboxRetryAttempts].
  int backoffSecondsForAttempt(int attempt) =>
      _backoffSecondsForAttempt(attempt);

  /// The backoff [Duration] before retry [attempt] (1-based) (Req 9.5).
  Duration backoffForAttempt(int attempt) =>
      Duration(seconds: _backoffSecondsForAttempt(attempt));

  /// The full bounded backoff sequence, in seconds: `[2, 4, 8, 16, 32]`
  /// (Req 9.5). Exactly [maxOutboxRetryAttempts] entries — one per attempt.
  List<int> boundedBackoffSequence() => <int>[
    for (var attempt = 1; attempt <= maxOutboxRetryAttempts; attempt++)
      _backoffSecondsForAttempt(attempt),
  ];

  /// The full bounded backoff sequence as [Duration]s (Req 9.5).
  List<Duration> boundedBackoffDurations() => <Duration>[
    for (final seconds in boundedBackoffSequence()) Duration(seconds: seconds),
  ];

  /// The initial, fully-recoverable pending status for [record] — zero attempts
  /// consumed, retained in the Outbox with its data intact (Req 9.5).
  OutboxRetryStatus pending(OutboxRecord record) => OutboxRetryStatus._(
    record: record,
    attemptsMade: 0,
    state: OutboxRetryState.pending,
  );

  /// Model a write that failed while in Offline_Mode: it is retained as a
  /// pending change with no data discarded (Req 7.5). Identical to [pending];
  /// named for the offline-write use site so intent is explicit.
  OutboxRetryStatus retainOfflineWrite(OutboxRecord record) => pending(record);

  /// Register one non-conflict synchronization failure against [current] and
  /// return the resulting classification (Req 9.5, 9.6).
  ///
  /// While attempts remain the mutation stays pending and a retry is scheduled
  /// on the bounded backoff. Once the [maxOutboxRetryAttempts]th attempt fails
  /// the mutation is retained in the `failed` state with its data intact and a
  /// screen-naming [OutboxFailureIndication] surfaced — never discarded.
  ///
  /// Registering a failure on an already-[OutboxRetryState.failed] status is a
  /// no-op that re-returns the terminal classification (the budget cannot be
  /// exceeded and the mutation cannot be lost).
  OutboxRetryClassification onFailure(OutboxRetryStatus current) {
    if (current.isFailed) {
      return OutboxRetryClassification(
        decision: OutboxRetryDecision.retainedFailed,
        status: current,
      );
    }
    final attempts = current.attemptsMade + 1;
    if (attempts >= maxOutboxRetryAttempts) {
      final status = OutboxRetryStatus._(
        record: current.record,
        attemptsMade: maxOutboxRetryAttempts,
        state: OutboxRetryState.failed,
        failureIndication: OutboxFailureIndication(
          mutationId: current.record.mutationId,
          screenPath: _screenNameOf(current.record),
          attemptsMade: maxOutboxRetryAttempts,
        ),
      );
      return OutboxRetryClassification(
        decision: OutboxRetryDecision.retainedFailed,
        status: status,
      );
    }
    final status = OutboxRetryStatus._(
      record: current.record,
      attemptsMade: attempts,
      state: OutboxRetryState.pending,
    );
    return OutboxRetryClassification(
      decision: OutboxRetryDecision.retryScheduled,
      status: status,
    );
  }

  /// Fold [failureCount] consecutive non-conflict failures over [record],
  /// starting from a fresh pending status, and return the final status
  /// (Req 9.5, 9.6).
  ///
  /// At most [maxOutboxRetryAttempts] failures are counted; any beyond that are
  /// absorbed by the terminal `failed` state (the mutation can neither be
  /// retried again nor lost). [failureCount] must be non-negative.
  OutboxRetryStatus applyFailures(OutboxRecord record, int failureCount) {
    if (failureCount < 0) {
      throw RangeError.value(failureCount, 'failureCount', 'must be >= 0');
    }
    var status = pending(record);
    for (var i = 0; i < failureCount; i++) {
      status = onFailure(status).status;
    }
    return status;
  }

  /// The Screen name to surface in a failure indication (Req 9.6). Uses the
  /// record's [OutboxRecord.screenPath] when present, otherwise a clearly
  /// marked placeholder so the indication still identifies "which screen".
  String _screenNameOf(OutboxRecord record) {
    final path = record.screenPath?.trim();
    return (path == null || path.isEmpty) ? '<unknown screen>' : path;
  }
}
