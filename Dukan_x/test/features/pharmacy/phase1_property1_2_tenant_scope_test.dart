// ============================================================================
// PHASE 1 — Task 1.6: PROPERTY TESTS
// Feature: pharmacy-vertical-remediation, Property 1: Tenant-scoped reads and
//          writes; Property 2: Tenant-scope violations are rejected without
//          mutation
// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 19.5**
// ============================================================================
//
// Property 1 (design.md — Correctness Properties):
//   *For any* set of pharmacy records carrying mixed tenantIds and any active
//   tenantId resolved from the session, every result produced by changed read
//   code contains only records whose tenantId equals the active tenantId, and
//   every write performed by changed code persists the active tenantId on the
//   record. (Requirements 1.1, 1.2, 1.4, 19.5)
//
// Property 2 (design.md — Correctness Properties):
//   *For any* pharmacy data operation in changed code that has no resolvable
//   active tenantId or requests a tenantId not equal to the active tenantId,
//   the operation is rejected with an authorization error and no targeted
//   record is read or mutated. (Requirements 1.3, 1.5)
//
// HOW THIS IS PROVEN AS A PROPERTY:
//   `TenantScope` (lib/features/pharmacy/utils/tenant_scope.dart) is the single
//   authorization-error chokepoint every changed pharmacy read/write path uses.
//   These properties pin its contract by driving a small in-memory repository
//   test-double that scopes reads (filter by `require()`) and stamps writes
//   (persist `require()` / `requireMatch()`), sampling the full input space:
//     - active tenantId  ∈ a pool of distinct ids (plus blank/null for R1.3)
//     - record tenantIds ∈ the same pool (mixed-tenant store, 0..20 records)
//     - requested tenantId ∈ the pool (equal vs. deliberately foreign)
//   For every sample we assert reads return only active-tenant rows, writes
//   stamp the active tenantId, and a missing/foreign tenant rejects with the
//   correct `TenantScopeError` kind while leaving the store byte-for-byte
//   unchanged.
//
// SEAM: `TenantScope` resolves the active tenantId from
//   `SessionManager.currentBusinessId`. A `FakeSessionManager`
//   (`extends Mock implements SessionManager`, the repo-wide pattern) pins that
//   getter via the constructor — no GetIt, no Firebase, no IO. The in-memory
//   repo is a test-only stand-in for the changed read/write paths; no
//   production code is touched.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. `forAll((case) => <bool>, [gen], numRuns: N)` runs N
//   generated cases, returning true iff the property held for every run and
//   throwing a shrinking counterexample otherwise.
//
// Run: flutter test test/features/pharmacy/phase1_property1_2_tenant_scope_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/pharmacy/utils/tenant_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

/// At least 100 iterations are required by the spec; 200 is the dartproptest
/// default and the convention across this repo's property suites.
const int kNumRuns = 200;

/// A pool of distinct, non-blank tenantIds. Mixed-tenant stores and
/// active/foreign tenant selection are drawn from this pool so the scoping
/// filter is exercised across same-tenant and cross-tenant records.
const List<String> _tenantPool = <String>[
  'tenant-alpha',
  'tenant-bravo',
  'tenant-charlie',
  'tenant-delta',
];

/// Blank/absent business ids that must resolve to "no active tenant" (R1.3):
/// `null`, empty, and whitespace-only are all treated as unresolved.
const List<String?> _blankBusinessIds = <String?>[null, '', '   ', '\t'];

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A lightweight fake [SessionManager] whose `currentBusinessId` is fixed via
/// the constructor. `Mock` supplies `noSuchMethod` no-ops for every other
/// member; `TenantScope` only reads `currentBusinessId`, which we override.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager(this._businessId);

  final String? _businessId;

  @override
  String? get currentBusinessId => _businessId;
}

/// An immutable pharmacy record stand-in carrying only the fields the tenant
/// scoping property cares about.
class _Record {
  const _Record(this.id, this.tenantId);
  final String id;
  final String tenantId;

  /// Stable signature used to compare store snapshots for "no mutation".
  String get sig => '$id|$tenantId';
}

/// An in-memory stand-in for the changed pharmacy read/write paths. It routes
/// every read and write through [TenantScope] exactly as production code is
/// required to:
///   - reads filter by the active tenantId (`require`) — R1.1 / R1.4
///   - writes stamp the active tenantId (`require` / `requireMatch`) — R1.2
///   - an explicit requested tenantId is validated first (`requireMatch`) — R1.5
/// A missing active tenantId rejects via [TenantScopeError] before any read or
/// write touches the store (R1.3).
class _InMemoryPharmacyRepo {
  _InMemoryPharmacyRepo(this._scope, List<_Record> seed)
    : _store = List<_Record>.of(seed);

  final TenantScope _scope;
  final List<_Record> _store;

  /// R1.1 / R1.4: a scoped read returns only active-tenant records.
  List<_Record> readScoped() {
    final active = _scope.require();
    return _store.where((r) => r.tenantId == active).toList();
  }

  /// R1.5: a scoped read for an explicit [requestedTenantId] validates the
  /// request before reading; a foreign tenant rejects without reading.
  List<_Record> readForTenant(String? requestedTenantId) {
    final active = _scope.requireMatch(requestedTenantId);
    return _store.where((r) => r.tenantId == active).toList();
  }

  /// R1.2: a write persists the active tenantId on the record, regardless of
  /// any [requestedTenantId] supplied (which, when non-null, must match —
  /// R1.5). Returns the stored record.
  _Record write(String id, {String? requestedTenantId}) {
    final active = requestedTenantId == null
        ? _scope.require()
        : _scope.requireMatch(requestedTenantId);
    final rec = _Record(id, active);
    _store.add(rec);
    return rec;
  }

  /// Immutable signature of the current store, for no-mutation assertions.
  List<String> snapshotSig() =>
      List<String>.unmodifiable(_store.map((r) => r.sig));
}

bool _sameStore(List<String> before, List<String> after) {
  if (before.length != after.length) return false;
  for (var i = 0; i < before.length; i++) {
    if (before[i] != after[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Property 1 case + generator
// ---------------------------------------------------------------------------

class _ScopedCase {
  const _ScopedCase(this.activeTenant, this.recordTenants);
  final String activeTenant;
  final List<String> recordTenants;
}

/// Active tenantId × a mixed-tenant store of 0..20 records, every tenantId
/// drawn from [_tenantPool] so same-tenant and cross-tenant rows co-occur.
final Generator<_ScopedCase> _scopedCaseGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, _tenantPool.length - 1),
      Gen.array<int>(
        Gen.interval(0, _tenantPool.length - 1),
        minLength: 0,
        maxLength: 20,
      ),
    ]).map((parts) {
      final active = _tenantPool[parts[0] as int];
      final recordTenants = (parts[1] as List)
          .cast<int>()
          .map((i) => _tenantPool[i])
          .toList();
      return _ScopedCase(active, recordTenants);
    });

// ---------------------------------------------------------------------------
// Property 2 (missing-tenant) case + generator
// ---------------------------------------------------------------------------

class _MissingTenantCase {
  const _MissingTenantCase(this.blankBusinessId, this.requestedTenant);
  final String? blankBusinessId;
  final String requestedTenant;
}

/// A blank/null active business id × a (well-formed) requested tenantId. The
/// operation must reject as missing-tenant before reading or writing anything.
final Generator<_MissingTenantCase> _missingTenantCaseGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, _blankBusinessIds.length - 1),
      Gen.interval(0, _tenantPool.length - 1),
    ]).map((parts) {
      return _MissingTenantCase(
        _blankBusinessIds[parts[0] as int],
        _tenantPool[parts[1] as int],
      );
    });

// ---------------------------------------------------------------------------
// Property 2 (mismatch) case + generator
// ---------------------------------------------------------------------------

class _MismatchCase {
  const _MismatchCase(this.activeTenant, this.foreignTenant);
  final String activeTenant;
  final String foreignTenant;
}

/// Active tenantId × a deliberately FOREIGN requested tenantId (guaranteed
/// different by adding a non-zero offset modulo the pool size). The operation
/// must reject as a tenant-scope violation without reading or mutating.
final Generator<_MismatchCase> _mismatchCaseGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, _tenantPool.length - 1),
      Gen.interval(1, _tenantPool.length - 1),
    ]).map((parts) {
      final activeIdx = parts[0] as int;
      final offset = parts[1] as int;
      final foreignIdx = (activeIdx + offset) % _tenantPool.length;
      return _MismatchCase(_tenantPool[activeIdx], _tenantPool[foreignIdx]);
    });

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 1: Tenant-scoped reads '
      'and writes', () {
    test('Property 1: for any active tenantId and mixed-tenant store, scoped '
        'reads return only active-tenant records and writes persist the active '
        'tenantId (R1.1, R1.2, R1.4, 19.5)', () {
      final bool held = forAll(
        (_ScopedCase c) {
          final scope = TenantScope(
            session: FakeSessionManager(c.activeTenant),
          );
          final seed = <_Record>[
            for (var i = 0; i < c.recordTenants.length; i++)
              _Record('rec-$i', c.recordTenants[i]),
          ];
          final repo = _InMemoryPharmacyRepo(scope, seed);

          // R1.1 / R1.4: a scoped read excludes every foreign-tenant row
          // and includes exactly the active-tenant rows.
          final read = repo.readScoped();
          final expectedCount = seed
              .where((r) => r.tenantId == c.activeTenant)
              .length;
          final readOnlyActive = read.every(
            (r) => r.tenantId == c.activeTenant,
          );
          final readComplete = read.length == expectedCount;

          // R1.2 / 19.5: a write stamps the active tenantId on the record,
          // and the new record is visible to a subsequent scoped read.
          final written = repo.write('rec-new');
          final writeStampsActive = written.tenantId == c.activeTenant;
          final visibleAfterWrite = repo.readScoped().any(
            (r) => r.id == 'rec-new' && r.tenantId == c.activeTenant,
          );

          // R1.5 (positive path): an explicit matching request reads the
          // same active-tenant rows.
          final matchRead = repo.readForTenant(c.activeTenant);
          final matchReadOnlyActive = matchRead.every(
            (r) => r.tenantId == c.activeTenant,
          );

          return readOnlyActive &&
              readComplete &&
              writeStampsActive &&
              visibleAfterWrite &&
              matchReadOnlyActive;
        },
        <Generator<dynamic>>[_scopedCaseGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'Property 1 must hold: scoped reads return only active-tenant '
            'records and writes persist the active tenantId.',
      );
    });
  });

  group('Feature: pharmacy-vertical-remediation, Property 2: Tenant-scope '
      'violations are rejected without mutation', () {
    test('Property 2a: for any unresolvable active tenantId, reads and writes '
        'reject with a missing-tenant authorization error and the store is '
        'unchanged (R1.3)', () {
      final bool held = forAll(
        (_MissingTenantCase c) {
          final scope = TenantScope(
            session: FakeSessionManager(c.blankBusinessId),
          );
          final seed = const <_Record>[
            _Record('seed-0', 'tenant-alpha'),
            _Record('seed-1', 'tenant-bravo'),
          ];
          final repo = _InMemoryPharmacyRepo(scope, seed);
          final before = repo.snapshotSig();

          // A scoped read rejects with missing-tenant.
          var readKind = _kindOfThrow(() => repo.readScoped());
          // A write (with an explicit request) rejects with missing-tenant
          // — `require()` runs before any read/match, so a blank active
          // tenant fails first (R1.3 takes precedence over R1.5).
          var writeKind = _kindOfThrow(
            () => repo.write('x', requestedTenantId: c.requestedTenant),
          );
          // A plain write (no explicit request) also rejects.
          var plainWriteKind = _kindOfThrow(() => repo.write('y'));

          final allMissing =
              readKind == TenantScopeErrorKind.missingTenant &&
              writeKind == TenantScopeErrorKind.missingTenant &&
              plainWriteKind == TenantScopeErrorKind.missingTenant;

          // No targeted record was read or mutated.
          final unchanged = _sameStore(before, repo.snapshotSig());

          return allMissing && unchanged;
        },
        <Generator<dynamic>>[_missingTenantCaseGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'Property 2 (missing tenant) must hold: a blank/null active '
            'tenantId rejects every operation and mutates nothing.',
      );
    });

    test('Property 2b: for any requested tenantId not equal to the active '
        'tenantId, the operation rejects with a tenant-scope violation and the '
        'store is unchanged (R1.5)', () {
      final bool held = forAll(
        (_MismatchCase c) {
          final scope = TenantScope(
            session: FakeSessionManager(c.activeTenant),
          );
          final seed = const <_Record>[
            _Record('seed-0', 'tenant-alpha'),
            _Record('seed-1', 'tenant-bravo'),
            _Record('seed-2', 'tenant-charlie'),
          ];
          final repo = _InMemoryPharmacyRepo(scope, seed);
          final before = repo.snapshotSig();

          // A write requesting a foreign tenantId rejects with a mismatch.
          final writeKind = _kindOfThrow(
            () => repo.write('x', requestedTenantId: c.foreignTenant),
          );
          // A read for a foreign tenantId likewise rejects with a mismatch.
          final readKind = _kindOfThrow(
            () => repo.readForTenant(c.foreignTenant),
          );

          final bothMismatch =
              writeKind == TenantScopeErrorKind.tenantMismatch &&
              readKind == TenantScopeErrorKind.tenantMismatch;

          // No targeted record was read or mutated.
          final unchanged = _sameStore(before, repo.snapshotSig());

          return bothMismatch && unchanged;
        },
        <Generator<dynamic>>[_mismatchCaseGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'Property 2 (mismatch) must hold: a foreign requested tenantId '
            'rejects with a tenant-scope violation and mutates nothing.',
      );
    });
  });
}

/// Runs [op], returning the [TenantScopeErrorKind] of the thrown
/// [TenantScopeError], or `null` if no [TenantScopeError] was thrown.
TenantScopeErrorKind? _kindOfThrow(void Function() op) {
  try {
    op();
    return null;
  } on TenantScopeError catch (e) {
    return e.kind;
  }
}

