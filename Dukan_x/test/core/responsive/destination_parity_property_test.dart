// ============================================================================
// Task 7.3 — PROPERTY TEST
// Feature: cross-platform-responsive-ui, Property 5: Destination parity across
// Form_Factors
// **Validates: Requirements 3.3, 9.4**
// ============================================================================
// Property 5 (design.md): For any business context (any set of SidebarSections
//   produced by sidebarSectionsProvider), the set of reachable destination ids
//   derived for the Mobile drawer equals the set derived for the Tablet drawer,
//   which equals the set derived for the Desktop sidebar. Every destination
//   reachable on one Form_Factor is reachable on the other two.
//
// KEY INSIGHT: all three navigation surfaces (mobile drawer, tablet drawer,
//   desktop sidebar) derive their reachable destination id set from the SAME
//   pure function `reachableDestinationIds(sections)` applied to the SAME
//   `sidebarSectionsProvider` output. Parity therefore holds by construction:
//   the function is referentially transparent, so three evaluations on the
//   same input are necessarily equal. This property test pins that contract
//   and additionally proves it is non-vacuous by asserting the derived set
//   equals an independently computed flat set of every item id (verifying the
//   function actually collects every reachable destination).
//
// Unit under test: `reachableDestinationIds(List<SidebarSection>)` from
//   `package:dukanx/core/responsive/navigation_destinations.dart`.
//   `SidebarSection` / `SidebarMenuItem` come from
//   `package:dukanx/widgets/desktop/sidebar_configuration.dart`.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide. It composes cleanly with `flutter_test` and runs
//   `kNumRuns` (200) generated cases. See the dev_dependency note in
//   `pubspec.yaml` for why `glados` is not used.
//
// Run: flutter test test/core/responsive/destination_parity_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/responsive/navigation_destinations.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required; 200 is the dartproptest default and
  // matches the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // Independent reference: collects every item id across every section into a
  // flat set with a plain loop, deliberately NOT calling the unit under test.
  // Comparing against this proves the property is non-vacuous (the derived set
  // really does contain every reachable destination, with set de-duplication).
  Set<String> referenceIds(List<SidebarSection> sections) {
    final ids = <String>{};
    for (final section in sections) {
      for (final item in section.items) {
        ids.add(item.id);
      }
    }
    return ids;
  }

  // --- Generators ----------------------------------------------------------
  //
  // Destination ids are drawn from a deliberately SMALL pool (`dest_0`..
  // `dest_12`) so that the same id frequently recurs across different items
  // and sections. This exercises set semantics (de-duplication) — the heart of
  // why parity holds for a set rather than a list.
  final Generator<String> idGen = Gen.interval(0, 12).map((n) => 'dest_$n');

  // A section is generated as a list of item ids (0..6 items), allowing empty
  // sections. The full sidebar is a list of such sections (0..5 sections),
  // allowing the empty-sidebar boundary case too.
  final Generator<List<String>> sectionItemIdsGen = Gen.array(
    idGen,
    minLength: 0,
    maxLength: 6,
  );

  // Builds a realistic `List<SidebarSection>` from the generated id structure.
  // Icons/colors/labels are fixed dummy values per the task convention — only
  // the ids and the section/item counts vary, which is all Property 5 cares
  // about. The section `index` is its position so instances stay valid.
  final Generator<List<SidebarSection>> sectionsGen =
      Gen.array(sectionItemIdsGen, minLength: 0, maxLength: 5).map((
        sectionItemIds,
      ) {
        final sections = <SidebarSection>[];
        for (var i = 0; i < sectionItemIds.length; i++) {
          final items = <SidebarMenuItem>[
            for (final id in sectionItemIds[i])
              SidebarMenuItem(id: id, icon: Icons.home, label: 'Item $id'),
          ];
          sections.add(
            SidebarSection(
              index: i,
              icon: Icons.folder_outlined,
              title: 'Section $i',
              accentColor: const Color(0xFF2196F3),
              items: items,
            ),
          );
        }
        return sections;
      });

  group('Feature: cross-platform-responsive-ui, Property 5: Destination parity '
      'across Form_Factors', () {
    // -- Property: parity across the three surfaces + non-vacuity ----------
    test('Property 5: reachable id set for mobile == tablet == desktop, and '
        'equals the independently computed flat set of all item ids', () {
      final held = forAll(
        (List<SidebarSection> sections) {
          // All three surfaces derive their reachable set from the same pure
          // function applied to the same sections — exactly how the Mobile
          // drawer, Tablet drawer, and Desktop sidebar consume
          // `sidebarSectionsProvider` in the design.
          final Set<String> mobile = reachableDestinationIds(sections);
          final Set<String> tablet = reachableDestinationIds(sections);
          final Set<String> desktop = reachableDestinationIds(sections);

          // Parity: every destination reachable on one Form_Factor is
          // reachable on the other two (Req 3.3, 9.4).
          final bool parity =
              setEquals(mobile, tablet) && setEquals(tablet, desktop);

          // Non-vacuity: the derived set is exactly the flat set of every
          // item id (collects every destination; de-duplicates repeats).
          final bool collectsEveryId = setEquals(
            mobile,
            referenceIds(sections),
          );

          return parity && collectsEveryId;
        },
        [sectionsGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Deterministic example: duplicate ids across sections dedupe and the
    //    three surfaces still agree (guards against a vacuous generator). ----
    test('Property 5: duplicate ids across sections collapse to one reachable '
        'set shared by all three surfaces', () {
      final sections = <SidebarSection>[
        SidebarSection(
          index: 0,
          icon: Icons.folder_outlined,
          title: 'Section 0',
          items: const [
            SidebarMenuItem(id: 'a', icon: Icons.home, label: 'A'),
            SidebarMenuItem(id: 'b', icon: Icons.home, label: 'B'),
          ],
        ),
        SidebarSection(
          index: 1,
          icon: Icons.folder_outlined,
          title: 'Section 1',
          items: const [
            // 'a' is intentionally duplicated across sections.
            SidebarMenuItem(id: 'a', icon: Icons.home, label: 'A dup'),
            SidebarMenuItem(id: 'c', icon: Icons.home, label: 'C'),
          ],
        ),
      ];

      final mobile = reachableDestinationIds(sections);
      final tablet = reachableDestinationIds(sections);
      final desktop = reachableDestinationIds(sections);

      expect(mobile, {'a', 'b', 'c'});
      expect(setEquals(mobile, tablet), isTrue);
      expect(setEquals(tablet, desktop), isTrue);
    });

    // -- Boundary example: an empty sidebar yields an empty, equal set. ------
    test('Property 5: empty sections yield an empty reachable set on all '
        'three surfaces', () {
      const List<SidebarSection> sections = <SidebarSection>[];

      final mobile = reachableDestinationIds(sections);
      final tablet = reachableDestinationIds(sections);
      final desktop = reachableDestinationIds(sections);

      expect(mobile, isEmpty);
      expect(setEquals(mobile, tablet), isTrue);
      expect(setEquals(tablet, desktop), isTrue);
    });
  });
}
