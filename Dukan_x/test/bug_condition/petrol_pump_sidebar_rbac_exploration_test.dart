/// Bug Condition Exploration Test — rbac.sidebarGateMissing
///
/// **Validates: Requirements 1.8**
///
/// Property 8: Bug Condition — Sidebar Capability & Role Gating
///
/// This test confirms that:
/// 1. `_getPetrolPumpSections()` builds SidebarMenuItems with NO `capability:`
///    argument — specifically the `shift_management` item has `capability == null`.
/// 2. `UserRole` enum does NOT contain an `attendant` value.
///
/// On UNFIXED code this test FAILS — capability is null on every petrol pump
/// sidebar item, and no `attendant` role exists in UserRole.
/// After the fix this same test PASSES — items declare `capability:` gates
/// and `UserRole.attendant` exists.
///
/// Run: flutter test test/bug_condition/petrol_pump_sidebar_rbac_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // rbac.sidebarGateMissing / 1.8 / 2.8 — Every item under
  // _getPetrolPumpSections() is visible to all roles with no capability or
  // permission gate. The UserRole enum has no `attendant` value, so
  // pump-attendant identity cannot be resolved by RBAC.
  //
  // Expected (post-fix): Each sidebar item declares an appropriate
  // `capability:` gate, and `UserRole` includes an `attendant` value.
  //
  // Bug condition: capability is null on every item; no attendant role exists.
  // ===========================================================================
  group('Bug Condition 1.8 — rbac.sidebarGateMissing', () {
    late String sidebarSrc;
    late String userRoleSrc;

    setUpAll(() {
      sidebarSrc = _readSource(
        'lib/widgets/desktop/sidebar_configuration.dart',
      );
      assert(sidebarSrc.isNotEmpty, 'sidebar_configuration.dart must exist');

      userRoleSrc = _readSource('lib/core/models/user_role.dart');
      assert(userRoleSrc.isNotEmpty, 'user_role.dart must exist');
    });

    test(
      'shift_management sidebar item declares a capability gate (not null)',
      () {
        // On FIXED code: the shift_management SidebarMenuItem should
        // have a `capability: BusinessCapability.useShiftManagement`
        // (or similar) argument.
        //
        // On UNFIXED code: the SidebarMenuItem for shift_management has
        // no `capability:` argument at all — it defaults to null.

        // Find _getPetrolPumpSections function definition (not the call site).
        // The definition signature is:
        //   List<SidebarSection> _getPetrolPumpSections() {
        final defnPattern = '_getPetrolPumpSections() {';
        final methodIdx = sidebarSrc.indexOf(defnPattern);
        expect(
          methodIdx,
          isNot(-1),
          reason:
              '_getPetrolPumpSections() definition must exist in '
              'sidebar_configuration',
        );

        // Extract a generous slice of the function body (covers all items)
        final bodySlice = sidebarSrc.substring(
          methodIdx,
          (methodIdx + 3000).clamp(0, sidebarSrc.length),
        );

        // Locate the shift_management item definition using the string literal
        final shiftMgmtMarker = "shift_management";
        final shiftMgmtIdx = bodySlice.indexOf(shiftMgmtMarker);
        expect(
          shiftMgmtIdx,
          isNot(-1),
          reason: 'shift_management item must exist in _getPetrolPumpSections',
        );

        // Extract the SidebarMenuItem constructor call for shift_management.
        final itemSliceStart = bodySlice.lastIndexOf(
          'SidebarMenuItem(',
          shiftMgmtIdx,
        );
        expect(
          itemSliceStart,
          isNot(-1),
          reason:
              'SidebarMenuItem constructor must precede shift_management id',
        );

        // Find the end of this SidebarMenuItem (next SidebarMenuItem or `]`)
        final nextItemIdx = bodySlice.indexOf('SidebarMenuItem(', shiftMgmtIdx);
        final listEndIdx = bodySlice.indexOf('],', shiftMgmtIdx);
        final itemEndIdx = nextItemIdx != -1 && nextItemIdx < listEndIdx
            ? nextItemIdx
            : listEndIdx;

        final shiftMgmtItem = bodySlice.substring(itemSliceStart, itemEndIdx);

        // Check that the item has a capability argument
        final hasCapability = shiftMgmtItem.contains('capability:');

        expect(
          hasCapability,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.8): The shift_management SidebarMenuItem in '
              '_getPetrolPumpSections() does NOT declare a `capability:` '
              'argument. The item definition is:\n'
              '  ${shiftMgmtItem.trim()}\n\n'
              'Every petrol pump sidebar item is fully visible to all '
              'authenticated users regardless of role. No capability or '
              'permission gating is applied, so even a minimal-privilege '
              'attendant role would see shift-management, tank-management, '
              'and report items. The item must declare '
              '`capability: BusinessCapability.useShiftManagement` (or '
              'equivalent) so that the existing sidebarSectionsProvider '
              'FeatureResolver.canAccess check can enforce role-based '
              'visibility.',
        );
      },
    );

    test('UserRole enum contains an attendant value', () {
      // On FIXED code: UserRole should have an `attendant` enum value
      // so that pump-attendant identity can be resolved by RBAC.
      //
      // On UNFIXED code: UserRole has 12 values (owner, manager, staff,
      // accountant, pharmacist, waiter, chef, captain, doctor,
      // receptionist, nurse, unknown) but no `attendant`.

      // Find the enum definition
      final enumIdx = userRoleSrc.indexOf('enum UserRole');
      expect(
        enumIdx,
        isNot(-1),
        reason: 'UserRole enum must exist in user_role.dart',
      );

      // Extract the enum body (up to closing brace)
      final enumOpenBrace = userRoleSrc.indexOf('{', enumIdx);
      final enumCloseBrace = userRoleSrc.indexOf('}', enumOpenBrace);
      final enumBody = userRoleSrc.substring(enumOpenBrace, enumCloseBrace + 1);

      // Check for `attendant` value
      final hasAttendant = RegExp(r'\battendant\b').hasMatch(enumBody);

      expect(
        hasAttendant,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.8): UserRole enum does NOT contain an '
            '`attendant` value. Current enum values are:\n'
            '  ${enumBody.trim()}\n\n'
            'Without an `attendant` (or `shiftOperator`) role value, '
            'pump-attendant identity cannot be resolved through the RBAC '
            'system. SessionManager, RoleManagementService, and '
            'PermissionGuard have no way to distinguish a pump attendant '
            'from generic staff. The capabilities registered in '
            'business_capability.dart (useShiftManagement, usePumpReadings, '
            'useFuelManagement) can never be enforced per-role for petrol '
            'pump workers because the role itself does not exist.',
      );
    });
  });
}
