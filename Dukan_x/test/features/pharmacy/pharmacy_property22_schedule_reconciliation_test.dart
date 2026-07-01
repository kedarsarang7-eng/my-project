// ============================================================================
// Feature: pharmacy-vertical-remediation, Property 22: Schedule string and enum
//          resolve identically
// **Validates: Requirements 22.1, 22.2, 22.3**
// ============================================================================
//
// Property 22 (design.md — Correctness Properties):
//   *For any* schedule string that differs from a defined `DrugSchedule` value
//   only by letter case or surrounding whitespace, the canonical resolver maps
//   it to the SAME canonical schedule as the enum value, and scheduled-drug
//   enforcement decisions use that canonical representation.
//
// HOW THIS IS PROVEN AS A PROPERTY:
//   The pharmacy vertical carries THREE representations of a drug schedule:
//     1. a free-form `BillItem.drugSchedule` String,
//     2. the `pharmacy_business_rules.dart` enum {otc, h, h1, x}, and
//     3. the `drug_schedule_service.dart` (inventory) enum
//        {none, scheduleH, scheduleH1, scheduleX}.
//   The property asserts these never disagree once funnelled through
//   `DrugScheduleResolver`. For each generated schedule KIND we render it three
//   ways — as a raw string in randomized casing / surrounding whitespace /
//   `-`/`_`/space separators, as the corresponding business-rules enum, and as
//   the corresponding inventory enum — then assert all three resolve to the one
//   expected `CanonicalDrugSchedule`:
//        fromRaw(string) == fromBusinessRules(enum) == fromInventory(enum).
//   Because the raw-string dimension samples casing and whitespace variants of
//   the same value, this also pins the case-insensitive / whitespace-trimmed
//   matching contract (Requirement 22.2).
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. Idiomatic usage:
//     forAll((arg) => <bool>, [gen], numRuns: N);
//   `forAll` returns true when the property held for every run, and throws a
//   shrinking Exception with a counterexample otherwise.
//
// Run: flutter test test/features/pharmacy/pharmacy_property22_schedule_reconciliation_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/pharmacy/utils/drug_schedule_resolver.dart';
import 'package:dukanx/features/pharmacy/utils/pharmacy_business_rules.dart'
    as rules;
import 'package:dukanx/features/inventory/services/drug_schedule_service.dart'
    as inventory;
import 'package:flutter_test/flutter_test.dart';

/// At least 100 iterations are required (Requirement 5.4 test mandate); 200 is
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// The schedule kinds that have BOTH a string spelling AND a value in each of
/// the two legacy enums — i.e. the values across which reconciliation must
/// hold. `unrecognized` is intentionally excluded (it has no enum form and is
/// covered by Property 23).
enum _Kind { nonScheduled, h, h1, x }

/// The `pharmacy_business_rules.dart` enum value for a kind.
rules.DrugSchedule _rulesEnumFor(_Kind k) {
  switch (k) {
    case _Kind.nonScheduled:
      return rules.DrugSchedule.otc;
    case _Kind.h:
      return rules.DrugSchedule.h;
    case _Kind.h1:
      return rules.DrugSchedule.h1;
    case _Kind.x:
      return rules.DrugSchedule.x;
  }
}

/// The `drug_schedule_service.dart` (inventory) enum value for a kind.
inventory.DrugSchedule _inventoryEnumFor(_Kind k) {
  switch (k) {
    case _Kind.nonScheduled:
      return inventory.DrugSchedule.none;
    case _Kind.h:
      return inventory.DrugSchedule.scheduleH;
    case _Kind.h1:
      return inventory.DrugSchedule.scheduleH1;
    case _Kind.x:
      return inventory.DrugSchedule.scheduleX;
  }
}

/// The single canonical value all three representations of a kind must yield.
CanonicalDrugSchedule _expectedFor(_Kind k) {
  switch (k) {
    case _Kind.nonScheduled:
      return CanonicalDrugSchedule.nonScheduled;
    case _Kind.h:
      return CanonicalDrugSchedule.scheduleH;
    case _Kind.h1:
      return CanonicalDrugSchedule.scheduleH1;
    case _Kind.x:
      return CanonicalDrugSchedule.scheduleX;
  }
}

/// Recognised string "forms" for a kind, each as a list of lower-case segments
/// that are joined with a generated separator. Single-segment forms ignore the
/// separator; multi-segment forms ("schedule" + "h1", "non" + "scheduled")
/// exercise the `-`/`_`/space separator stripping in addition to casing.
List<List<String>> _formsFor(_Kind k) {
  switch (k) {
    case _Kind.nonScheduled:
      return const [
        ['otc'],
        ['none'],
        ['nonscheduled'],
        ['non', 'scheduled'],
      ];
    case _Kind.h:
      return const [
        ['h'],
        ['schedule', 'h'],
      ];
    case _Kind.h1:
      return const [
        ['h1'],
        ['schedule', 'h1'],
      ];
    case _Kind.x:
      return const [
        ['x'],
        ['schedule', 'x'],
      ];
  }
}

/// Separators inserted between multi-segment forms. Every entry is composed of
/// characters the resolver strips (`\s`, `-`, `_`), so each must collapse to
/// the same normalized token.
const List<String> _separators = <String>['', ' ', '  ', '-', '_', ' - ', '\t'];

/// One fully-rendered reconciliation case: a raw string spelled in some
/// casing/whitespace/separator variant, alongside the two enum values it must
/// agree with and the canonical value all three must produce.
class _ScheduleCase {
  _ScheduleCase({
    required this.raw,
    required this.rulesEnum,
    required this.inventoryEnum,
    required this.expected,
  });

  final String raw;
  final rules.DrugSchedule rulesEnum;
  final inventory.DrugSchedule inventoryEnum;
  final CanonicalDrugSchedule expected;
}

/// Builds a raw string for [kind] using the generated knobs, applying casing
/// and surrounding whitespace on top of a separator-joined form.
String _buildRaw(
  _Kind kind,
  int formSel,
  int separatorSel,
  int casingMode,
  int leadWs,
  int trailWs,
) {
  final forms = _formsFor(kind);
  final segments = forms[formSel % forms.length];
  final sep = _separators[separatorSel % _separators.length];
  final core = segments.join(sep);

  final String cased;
  switch (casingMode % 4) {
    case 0:
      cased = core.toLowerCase();
      break;
    case 1:
      cased = core.toUpperCase();
      break;
    case 2:
      cased = core; // already lower-case base
      break;
    default:
      cased = core.isEmpty
          ? core
          : core[0].toUpperCase() + core.substring(1); // Title-ish
      break;
  }

  return (' ' * leadWs) + cased + (' ' * trailWs);
}

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 22: Schedule string and '
      'enum resolve identically', () {
    // --- Generator ---------------------------------------------------------
    // Sample the full reconciliation space: every schedule kind × every
    // string form × every separator × casing × surrounding whitespace.
    final Generator<_ScheduleCase> caseGen =
        Gen.tuple([
          Gen.elementOf<_Kind>(_Kind.values), // 0: schedule kind
          Gen.interval(0, 3), // 1: form selector (mod by form count)
          Gen.interval(0, _separators.length - 1), // 2: separator selector
          Gen.interval(0, 3), // 3: casing mode
          Gen.interval(0, 3), // 4: leading whitespace count
          Gen.interval(0, 3), // 5: trailing whitespace count
        ]).map((parts) {
          final kind = parts[0] as _Kind;
          final raw = _buildRaw(
            kind,
            parts[1] as int,
            parts[2] as int,
            parts[3] as int,
            parts[4] as int,
            parts[5] as int,
          );
          return _ScheduleCase(
            raw: raw,
            rulesEnum: _rulesEnumFor(kind),
            inventoryEnum: _inventoryEnumFor(kind),
            expected: _expectedFor(kind),
          );
        });

    test(
      'Property 22: for any schedule rendered as a raw string (varied '
      'casing/whitespace/separators) AND as each legacy enum, fromRaw == '
      'fromBusinessRules == fromInventory == the expected canonical value',
      () {
        final bool held = forAll(
          (_ScheduleCase c) {
            final byRaw = DrugScheduleResolver.fromRaw(c.raw);
            final byRules = DrugScheduleResolver.fromBusinessRules(c.rulesEnum);
            final byInventory = DrugScheduleResolver.fromInventory(
              c.inventoryEnum,
            );

            // (a) every representation resolves to the expected canonical, and
            // (b) the string and both enums agree with each other.
            return byRaw == c.expected &&
                byRules == c.expected &&
                byInventory == c.expected &&
                byRaw == byRules &&
                byRaw == byInventory;
          },
          [caseGen],
          numRuns: kNumRuns,
        );

        expect(
          held,
          isTrue,
          reason:
              'Schedule reconciliation (Property 22) must hold for every '
              'sampled (kind, casing, whitespace, separator) case: the raw '
              'string and both legacy enums must resolve identically.',
        );
      },
    );

    // -- Deterministic anchors: prove the property is non-vacuous on the
    //    exact case/whitespace/separator variants it is meant to catch. ----
    test(
      'Property 22 anchor: representative string spellings resolve identically '
      'to their enum counterparts',
      () {
        // Schedule H1 — case, surrounding whitespace, and separator variants.
        for (final raw in const <String>[
          'h1',
          'H1',
          ' h1 ',
          'Schedule H1',
          'schedule-h1',
          'SCHEDULE_H1',
          '  Schedule-H1  ',
        ]) {
          expect(
            DrugScheduleResolver.fromRaw(raw),
            CanonicalDrugSchedule.scheduleH1,
            reason: 'Raw "$raw" should resolve to Schedule H1.',
          );
          expect(
            DrugScheduleResolver.fromRaw(raw),
            DrugScheduleResolver.fromBusinessRules(rules.DrugSchedule.h1),
          );
          expect(
            DrugScheduleResolver.fromRaw(raw),
            DrugScheduleResolver.fromInventory(
              inventory.DrugSchedule.scheduleH1,
            ),
          );
        }

        // Schedule H.
        expect(
          DrugScheduleResolver.fromRaw(' Schedule H '),
          DrugScheduleResolver.fromBusinessRules(rules.DrugSchedule.h),
        );
        expect(
          DrugScheduleResolver.fromRaw('SCHEDULEH'),
          DrugScheduleResolver.fromInventory(inventory.DrugSchedule.scheduleH),
        );

        // Schedule X.
        expect(
          DrugScheduleResolver.fromRaw('  x  '),
          DrugScheduleResolver.fromBusinessRules(rules.DrugSchedule.x),
        );
        expect(
          DrugScheduleResolver.fromRaw('Schedule-X'),
          DrugScheduleResolver.fromInventory(inventory.DrugSchedule.scheduleX),
        );

        // Non-scheduled (OTC / none).
        expect(
          DrugScheduleResolver.fromRaw(' OTC '),
          DrugScheduleResolver.fromBusinessRules(rules.DrugSchedule.otc),
        );
        expect(
          DrugScheduleResolver.fromRaw('None'),
          DrugScheduleResolver.fromInventory(inventory.DrugSchedule.none),
        );
      },
    );
  });
}
