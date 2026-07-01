// ============================================================================
// PHARMACY VERTICAL REMEDIATION — Task 1.4: PROPERTY TESTS
// Feature: pharmacy-vertical-remediation, Property 5: RID format
// Feature: pharmacy-vertical-remediation, Property 6: RID intra-millisecond
//          uniqueness
// Feature: pharmacy-vertical-remediation, Property 7: RID timestamp ordering
//          matches creation sequence
// Feature: pharmacy-vertical-remediation, Property 8: Identifier generation
//          requires a tenant
// **Validates: Requirements 3.1, 3.3, 3.4, 3.5**
// ============================================================================
//
// Implementation under test:
//   lib/core/services/rid_generator.dart — `RidGenerator().generate(tenantId)`
//   produces the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}`:
//     R3.1 exactly three hyphen-separated segments; segment 2 is integer ms
//          since the Unix epoch (UTC); segment 3 is a non-empty short uuid v4.
//     R3.3 IDs for the same tenant within the same millisecond are distinct.
//     R3.4 IDs for the same tenant sort by their timestamp_ms segment
//          consistently with their creation sequence (non-decreasing time).
//     R3.5 a blank/unresolved tenantId throws `TenantScopeError` and produces
//          no identifier.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. Idiomatic usage: `forAll((args...) => <bool>, [gens],
//   numRuns: N)` returns true when the property held for every run and throws a
//   shrinking Exception with a counterexample otherwise. We use numRuns: 200,
//   well above the 100-case minimum.
//
// NOTE on segment counting (Property 5): real tenantIds contain hyphens, which
//   would inflate a naive `split('-')` segment count. The format property is
//   therefore exercised with tenantIds drawn from an alphanumeric-only pool (no
//   hyphens) so the "exactly three hyphen-separated segments" assertion is
//   meaningful. Hyphen-bearing tenantIds are covered by the deterministic
//   anchor test below, which slices the RID by its known structure instead.
//
// Run: flutter test test/features/pharmacy/rid_generator_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/error/tenant_scope_error.dart';
import 'package:dukanx/core/services/rid_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 iterations are required; 200 is the dartproptest default and
/// the convention used across this repo's property suites.
const int kNumRuns = 200;

/// Alphanumeric characters used to build hyphen-free tenantIds for the format
/// property. Excluding the hyphen keeps `split('-')` segment counting exact.
const List<String> _alphaNum = <String>[
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
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '_',
];

/// Blank/unresolvable tenantId values (empty or whitespace-only). Each must be
/// rejected by `generate` with a `TenantScopeError` (R3.5).
const List<String> _blankTenantIds = <String>[
  '',
  ' ',
  '   ',
  '\t',
  '\n',
  ' \t \n ',
  '\r\n',
];

void main() {
  // --- Generators ----------------------------------------------------------

  /// A non-empty, hyphen-free tenantId (1..24 alphanumeric/underscore chars).
  final Generator<String> tenantIdGen = Gen.array<String>(
    Gen.elementOf<String>(_alphaNum),
    minLength: 1,
    maxLength: 24,
  ).map((chars) => chars.join());

  /// How many identifiers to generate in a single burst (drives the
  /// uniqueness and ordering properties). 2..60 covers single and many
  /// intra-millisecond emissions.
  final Generator<int> burstCountGen = Gen.interval(2, 60);

  /// A blank/unresolvable tenantId.
  final Generator<String> blankTenantGen = Gen.elementOf<String>(
    _blankTenantIds,
  );

  group('Feature: pharmacy-vertical-remediation, Property 5: RID format', () {
    test('Property 5: generate(tenantId) yields exactly three segments — '
        'tenantId, integer ms-since-epoch, non-empty short uuid', () {
      final bool held = forAll(
        (String tenantId) {
          // Fresh generator per run so the timestamp segment reflects this
          // call only (no carried-forward clock from earlier tenants).
          final generator = RidGenerator();

          final int beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;
          final String rid = generator.generate(tenantId);
          final int afterMs = DateTime.now().toUtc().millisecondsSinceEpoch;

          final List<String> segments = rid.split('-');
          if (segments.length != 3) return false;

          // Segment 1: the active tenantId, verbatim.
          if (segments[0] != tenantId) return false;

          // Segment 2: integer ms since the Unix epoch (UTC), captured at
          // the moment of creation, so it lies within [before, after].
          final int? ts = int.tryParse(segments[1]);
          if (ts == null) return false;
          if (ts < beforeMs || ts > afterMs) return false;

          // Segment 3: a non-empty short uuid v4 value.
          if (segments[2].isEmpty) return false;

          return true;
        },
        [tenantIdGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'Every generated RID must match the '
            '{tenantId}-{timestamp_ms}-{uuid_v4_short} format (R3.1).',
      );
    });

    test('Property 5 anchor: a hyphen-bearing tenantId is preserved and the '
        'trailing two segments remain a valid ms + short uuid', () {
      const String tenantId = 'tenant-abc-123';
      final generator = RidGenerator();

      final int beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final String rid = generator.generate(tenantId);
      final int afterMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      // The RID is structurally {tenantId}-{ms}-{short}. Because tenantId
      // itself contains hyphens, slice by the known structure: the last
      // two hyphen-separated fields are ms and short; everything before is
      // the tenantId.
      final int lastDash = rid.lastIndexOf('-');
      final int secondLastDash = rid.lastIndexOf('-', lastDash - 1);

      final String tenantPart = rid.substring(0, secondLastDash);
      final String msPart = rid.substring(secondLastDash + 1, lastDash);
      final String shortPart = rid.substring(lastDash + 1);

      expect(tenantPart, tenantId);

      final int? ts = int.tryParse(msPart);
      expect(ts, isNotNull);
      expect(ts! >= beforeMs && ts <= afterMs, isTrue);

      expect(shortPart, isNotEmpty);
    });
  });

  group('Feature: pharmacy-vertical-remediation, Property 6: RID '
      'intra-millisecond uniqueness', () {
    test('Property 6: any number of IDs for one tenant generated in a burst '
        'are pairwise distinct', () {
      final bool held = forAll(
        (String tenantId, int count) {
          // One shared generator: the burst is emitted as fast as possible,
          // so many IDs land in the same millisecond (the case R3.3 guards).
          final generator = RidGenerator();
          final ids = <String>[];
          for (var i = 0; i < count; i++) {
            ids.add(generator.generate(tenantId));
          }
          // Pairwise distinctness <=> set size equals list length.
          return ids.toSet().length == ids.length;
        },
        [tenantIdGen, burstCountGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'No two IDs for the same tenant within the same '
            'millisecond may be equal (R3.3).',
      );
    });
  });

  group('Feature: pharmacy-vertical-remediation, Property 7: RID timestamp '
      'ordering matches creation sequence', () {
    test('Property 7: timestamp_ms segments are non-decreasing in creation '
        'order, so sorting by timestamp_ms matches the creation sequence', () {
      final bool held = forAll(
        (String tenantId, int count) {
          final generator = RidGenerator();
          final timestamps = <int>[];
          for (var i = 0; i < count; i++) {
            final rid = generator.generate(tenantId);
            final segments = rid.split('-');
            // For hyphen-free tenantIds, segment 2 is the timestamp.
            final ts = int.tryParse(segments[1]);
            if (ts == null) return false;
            timestamps.add(ts);
          }

          // Creation order is the list order. Sorting ascending by
          // timestamp_ms is consistent with creation order iff the
          // sequence is already non-decreasing.
          for (var i = 1; i < timestamps.length; i++) {
            if (timestamps[i] < timestamps[i - 1]) return false;
          }
          return true;
        },
        [tenantIdGen, burstCountGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'timestamp_ms segments must be non-decreasing across the '
            'creation sequence for a tenant (R3.4).',
      );
    });
  });

  group('Feature: pharmacy-vertical-remediation, Property 8: Identifier '
      'generation requires a tenant', () {
    test('Property 8: a blank/unresolvable tenantId throws TenantScopeError '
        'and produces no identifier', () {
      final bool held = forAll(
        (String blankTenant) {
          final generator = RidGenerator();
          try {
            generator.generate(blankTenant);
            // An identifier was produced for a blank tenant — violation.
            return false;
          } on TenantScopeError catch (e) {
            // The rejection must be the missing-tenant authorization error.
            return e.kind == TenantScopeErrorKind.missingTenant;
          } catch (_) {
            // Any other error type is not the contract.
            return false;
          }
        },
        [blankTenantGen],
        numRuns: kNumRuns,
      );

      expect(
        held,
        isTrue,
        reason:
            'No identifier may be produced without a resolvable '
            'tenantId; a TenantScopeError must be thrown (R3.5).',
      );
    });
  });
}
