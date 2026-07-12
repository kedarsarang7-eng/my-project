// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: sidebar.capabilityGating (Requirement 2.13; Preservation 3.10)
//
// `kitchen_display`, `menu_management`, and `daily_summary` SidebarMenuItems in
// `_getRestaurantSections()` currently declare NO `capability` field, even though
// `useKitchenDisplay` and `useKOT` capabilities exist and are declared for the
// restaurant business type. Meanwhile, `restaurant_tables` correctly declares
// `capability: BusinessCapability.useTableManagement`.
//
// This test asserts the POSITIVE expectation: each of the three items SHOULD
// declare a capability gate. On UNFIXED code this FAILS because they don't.
//
// **Validates: Requirements 2.13**
//
// COUNTEREXAMPLE (documented after first run):
// `kitchen_display` has no `capability:` field — it is ungated.
// `menu_management` has no `capability:` field — it is ungated.
// `daily_summary` has no `capability:` field — it is ungated.
// Any user with sidebar access can reach these screens regardless of their
// business capabilities, violating the consistent gating pattern established by
// `restaurant_tables` (which gates on `useTableManagement`).
//
// PRESERVATION TEST (Requirement 3.10) — expected to PASS on unfixed code.
//
// `restaurant_tables`'s existing `useTableManagement` capability gate must
// continue to gate access exactly as before after gating is added to the other
// three sidebar items. This preservation group verifies the existing gate is
// intact and specifically uses `BusinessCapability.useTableManagement`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition 2.13 — sidebar.capabilityGating '
      '(kitchen_display / menu_management / daily_summary)', () {
    late String sidebarConfigSource;
    late String restaurantSectionsBody;

    setUpAll(() {
      final configFile = File('lib/widgets/desktop/sidebar_configuration.dart');
      expect(
        configFile.existsSync(),
        isTrue,
        reason: 'sidebar_configuration.dart must exist',
      );
      sidebarConfigSource = configFile.readAsStringSync();

      // Locate _getRestaurantSections() function DEFINITION
      final defPattern = '_getRestaurantSections() {';
      final methodIdx = sidebarConfigSource.indexOf(defPattern);
      expect(
        methodIdx,
        isNot(-1),
        reason:
            '_getRestaurantSections() function definition must exist in '
            'sidebar_configuration.dart',
      );

      // Extract the function body by matching braces
      final blockStart = sidebarConfigSource.indexOf('{', methodIdx);
      expect(
        blockStart,
        isNot(-1),
        reason: '_getRestaurantSections() must have a body block',
      );

      int depth = 0;
      int blockEnd = -1;
      for (int i = blockStart; i < sidebarConfigSource.length; i++) {
        if (sidebarConfigSource[i] == '{') depth++;
        if (sidebarConfigSource[i] == '}') {
          depth--;
          if (depth == 0) {
            blockEnd = i + 1;
            break;
          }
        }
      }
      expect(
        blockEnd,
        isNot(-1),
        reason:
            'Could not find matching closing brace for '
            '_getRestaurantSections()',
      );

      restaurantSectionsBody = sidebarConfigSource.substring(
        blockStart,
        blockEnd,
      );
    });

    /// Extracts the SidebarMenuItem block for a given [itemId] from the
    /// restaurant sections body. Returns null if the item id is not found.
    String? _extractMenuItemBlock(String itemId) {
      final idPattern = "id: '$itemId'";
      final idIdx = restaurantSectionsBody.indexOf(idPattern);
      if (idIdx == -1) return null;

      // Walk backwards to find the start of this SidebarMenuItem(
      final prefix = restaurantSectionsBody.substring(0, idIdx);
      final menuItemStart = prefix.lastIndexOf('SidebarMenuItem(');
      if (menuItemStart == -1) return null;

      // Walk forward from the SidebarMenuItem( to find its closing )
      // by matching parentheses depth
      int depth = 0;
      int blockEnd = -1;
      for (int i = menuItemStart; i < restaurantSectionsBody.length; i++) {
        if (restaurantSectionsBody[i] == '(') depth++;
        if (restaurantSectionsBody[i] == ')') {
          depth--;
          if (depth == 0) {
            blockEnd = i + 1;
            break;
          }
        }
      }
      if (blockEnd == -1) return null;

      return restaurantSectionsBody.substring(menuItemStart, blockEnd);
    }

    /// Returns true if the SidebarMenuItem block contains a `capability:`
    /// field with a non-null value.
    bool _hasCapabilityField(String menuItemBlock) {
      // Match `capability: BusinessCapability.someValue`
      final capabilityPattern = RegExp(r'capability:\s*BusinessCapability\.');
      return capabilityPattern.hasMatch(menuItemBlock);
    }

    // =====================================================================
    // PRECONDITION: restaurant_tables already has capability gating.
    // This PASSES on both unfixed and fixed code — confirms the pattern
    // exists and our detection logic works.
    // =====================================================================
    test(
      'PRECONDITION: restaurant_tables declares useTableManagement capability',
      () {
        final block = _extractMenuItemBlock('restaurant_tables');
        expect(
          block,
          isNotNull,
          reason:
              'restaurant_tables SidebarMenuItem must exist in '
              '_getRestaurantSections()',
        );

        final hasCapability = _hasCapabilityField(block!);
        expect(
          hasCapability,
          isTrue,
          reason:
              'restaurant_tables must declare a capability field '
              '(useTableManagement) — this is the baseline pattern that '
              'kitchen_display, menu_management, and daily_summary should '
              'also follow.',
        );

        // Verify it's specifically useTableManagement
        expect(
          block.contains('BusinessCapability.useTableManagement'),
          isTrue,
          reason:
              'restaurant_tables capability must be '
              'BusinessCapability.useTableManagement',
        );
      },
    );

    // =====================================================================
    // BUG CONDITION: kitchen_display has no capability gate.
    // On UNFIXED code this FAILS — confirms the bug.
    // =====================================================================
    test('kitchen_display declares a capability gate', () {
      final block = _extractMenuItemBlock('kitchen_display');
      expect(
        block,
        isNotNull,
        reason:
            'kitchen_display SidebarMenuItem must exist in '
            '_getRestaurantSections()',
      );

      final hasCapability = _hasCapabilityField(block!);
      expect(
        hasCapability,
        isTrue,
        reason:
            'COUNTEREXAMPLE (2.13): kitchen_display SidebarMenuItem in '
            '_getRestaurantSections() declares NO capability field.\n\n'
            'Current item block:\n$block\n\n'
            'Expected: capability: BusinessCapability.useKitchenDisplay\n'
            'Actual: no capability field present — the item is ungated.\n\n'
            'Any user with restaurant sidebar access can reach Kitchen/KOT '
            'View regardless of whether the useKitchenDisplay capability is '
            'granted, violating the consistent gating pattern established by '
            'restaurant_tables (useTableManagement).',
      );
    });

    // =====================================================================
    // BUG CONDITION: menu_management has no capability gate.
    // On UNFIXED code this FAILS — confirms the bug.
    // =====================================================================
    test('menu_management declares a capability gate', () {
      final block = _extractMenuItemBlock('menu_management');
      expect(
        block,
        isNotNull,
        reason:
            'menu_management SidebarMenuItem must exist in '
            '_getRestaurantSections()',
      );

      final hasCapability = _hasCapabilityField(block!);
      expect(
        hasCapability,
        isTrue,
        reason:
            'COUNTEREXAMPLE (2.13): menu_management SidebarMenuItem in '
            '_getRestaurantSections() declares NO capability field.\n\n'
            'Current item block:\n$block\n\n'
            'Expected: capability: BusinessCapability.useKOT (or a dedicated '
            'useMenuManagement capability)\n'
            'Actual: no capability field present — the item is ungated.\n\n'
            'Any user with restaurant sidebar access can reach Menu Management '
            'regardless of their business capabilities.',
      );
    });

    // =====================================================================
    // BUG CONDITION: daily_summary has no capability gate.
    // On UNFIXED code this FAILS — confirms the bug.
    // =====================================================================
    test('daily_summary declares a capability gate', () {
      final block = _extractMenuItemBlock('daily_summary');
      expect(
        block,
        isNotNull,
        reason:
            'daily_summary SidebarMenuItem must exist in '
            '_getRestaurantSections()',
      );

      final hasCapability = _hasCapabilityField(block!);
      expect(
        hasCapability,
        isTrue,
        reason:
            'COUNTEREXAMPLE (2.13): daily_summary SidebarMenuItem in '
            '_getRestaurantSections() declares NO capability field.\n\n'
            'Current item block:\n$block\n\n'
            'Expected: capability: BusinessCapability.useKOT (or a dedicated '
            'useDailySummary capability)\n'
            'Actual: no capability field present — the item is ungated.\n\n'
            'Any user with restaurant sidebar access can reach Daily Summary '
            'regardless of their business capabilities.',
      );
    });
  });

  // =======================================================================
  // PRESERVATION TEST — Requirement 3.10
  //
  // **Validates: Requirements 3.10**
  //
  // `restaurant_tables`'s existing `useTableManagement` capability gate must
  // keep gating exactly as before. This test PASSES on unfixed code and must
  // continue to PASS after Task 20.3 adds capability gates to the other 3
  // sidebar items — confirming no accidental regression to the existing gate.
  // =======================================================================
  group('Preservation 3.10 — restaurant_tables gate unaffected', () {
    late String sidebarConfigSource;
    late String restaurantSectionsBody;

    setUpAll(() {
      final configFile = File('lib/widgets/desktop/sidebar_configuration.dart');
      expect(
        configFile.existsSync(),
        isTrue,
        reason: 'sidebar_configuration.dart must exist',
      );
      sidebarConfigSource = configFile.readAsStringSync();

      // Locate _getRestaurantSections() function DEFINITION
      final defPattern = '_getRestaurantSections() {';
      final methodIdx = sidebarConfigSource.indexOf(defPattern);
      expect(
        methodIdx,
        isNot(-1),
        reason:
            '_getRestaurantSections() function definition must exist in '
            'sidebar_configuration.dart',
      );

      // Extract the function body by matching braces
      final blockStart = sidebarConfigSource.indexOf('{', methodIdx);
      expect(
        blockStart,
        isNot(-1),
        reason: '_getRestaurantSections() must have a body block',
      );

      int depth = 0;
      int blockEnd = -1;
      for (int i = blockStart; i < sidebarConfigSource.length; i++) {
        if (sidebarConfigSource[i] == '{') depth++;
        if (sidebarConfigSource[i] == '}') {
          depth--;
          if (depth == 0) {
            blockEnd = i + 1;
            break;
          }
        }
      }
      expect(
        blockEnd,
        isNot(-1),
        reason:
            'Could not find matching closing brace for '
            '_getRestaurantSections()',
      );

      restaurantSectionsBody = sidebarConfigSource.substring(
        blockStart,
        blockEnd,
      );
    });

    /// Extracts the SidebarMenuItem block for a given [itemId].
    String? _extractMenuItemBlock(String itemId) {
      final idPattern = "id: '$itemId'";
      final idIdx = restaurantSectionsBody.indexOf(idPattern);
      if (idIdx == -1) return null;

      final prefix = restaurantSectionsBody.substring(0, idIdx);
      final menuItemStart = prefix.lastIndexOf('SidebarMenuItem(');
      if (menuItemStart == -1) return null;

      int depth = 0;
      int blockEnd = -1;
      for (int i = menuItemStart; i < restaurantSectionsBody.length; i++) {
        if (restaurantSectionsBody[i] == '(') depth++;
        if (restaurantSectionsBody[i] == ')') {
          depth--;
          if (depth == 0) {
            blockEnd = i + 1;
            break;
          }
        }
      }
      if (blockEnd == -1) return null;

      return restaurantSectionsBody.substring(menuItemStart, blockEnd);
    }

    test('restaurant_tables item exists in _getRestaurantSections()', () {
      final block = _extractMenuItemBlock('restaurant_tables');
      expect(
        block,
        isNotNull,
        reason:
            'restaurant_tables SidebarMenuItem must exist in '
            '_getRestaurantSections() — removal would break table management '
            'navigation.',
      );
    });

    test(
      'restaurant_tables declares capability: BusinessCapability.useTableManagement',
      () {
        final block = _extractMenuItemBlock('restaurant_tables');
        expect(block, isNotNull);

        // Verify a capability field is present
        final capabilityPattern = RegExp(r'capability:\s*BusinessCapability\.');
        expect(
          capabilityPattern.hasMatch(block!),
          isTrue,
          reason:
              'restaurant_tables must declare a capability field — it gates '
              'access to Table Management based on the business capability '
              'registry.',
        );

        // Verify it is specifically useTableManagement (not accidentally
        // changed to a different capability during Task 20.3)
        expect(
          block.contains('BusinessCapability.useTableManagement'),
          isTrue,
          reason:
              'restaurant_tables capability must be '
              'BusinessCapability.useTableManagement — not accidentally '
              'changed to useKitchenDisplay, useKOT, or any other capability.',
        );
      },
    );

    test('restaurant_tables capability is not null or empty', () {
      final block = _extractMenuItemBlock('restaurant_tables');
      expect(block, isNotNull);

      // Ensure it's not set to null (e.g., `capability: null`)
      final nullCapabilityPattern = RegExp(r'capability:\s*null');
      expect(
        nullCapabilityPattern.hasMatch(block!),
        isFalse,
        reason:
            'restaurant_tables capability must not be null — it must '
            'actively gate access using useTableManagement.',
      );
    });

    test(
      'restaurant_tables retains its id, icon, and label alongside the gate',
      () {
        final block = _extractMenuItemBlock('restaurant_tables');
        expect(block, isNotNull);

        // Verify the item's identity fields are intact (a holistic check that
        // Task 20.3 didn't accidentally modify the wrong item)
        expect(
          block!.contains("id: 'restaurant_tables'"),
          isTrue,
          reason: 'restaurant_tables id field must be preserved',
        );
        expect(
          block.contains('Icons.table_restaurant_outlined'),
          isTrue,
          reason:
              'restaurant_tables icon must remain table_restaurant_outlined',
        );
        expect(
          block.contains("label: 'Table Management'"),
          isTrue,
          reason: "restaurant_tables label must remain 'Table Management'",
        );
      },
    );

    test('useTableManagement is not removed from restaurant_tables '
        '(other items may share it)', () {
      // Verify that restaurant_tables specifically has useTableManagement.
      // Other items (e.g., floor_management) may also use it — that's fine.
      // The concern is that Task 20.3 doesn't accidentally REMOVE the
      // capability from restaurant_tables or CHANGE it to something else.
      final block = _extractMenuItemBlock('restaurant_tables');
      expect(block, isNotNull);

      expect(
        block!.contains('BusinessCapability.useTableManagement'),
        isTrue,
        reason:
            'restaurant_tables must retain BusinessCapability.'
            'useTableManagement — it must not be removed or changed '
            'during capability gating of other sidebar items.',
      );
    });
  });
}
