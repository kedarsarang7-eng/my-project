/// Bug Condition Exploration Test — Reminder RBAC Gate (HARDWARE-022)
///
/// **Validates: Requirements 1.22, 2.22**
///
/// Property 20: The "Reminders" trigger button in
/// `HardwareSupplierManagementScreen` must be hidden/disabled for
/// non-admin/owner roles (e.g. staff, accountant with only 'view' on
/// suppliers module).
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'supplier.triggerReminders'`
///   AND `role not in {admin, owner}`
///
/// BEFORE fix: The Reminders button is unconditionally visible and
/// triggerable by ANY user regardless of role — no RBAC check exists.
///
/// AFTER fix: The button is wrapped in a role/permission guard so that
/// only admin/owner roles can see/trigger it.
///
/// Strategy: Source-code probe asserting that:
///   1. `HardwarePermissionMatrix.moduleActions['suppliers']` contains
///      a `'trigger_reminders'` action.
///   2. The supplier management screen imports a session/role mechanism.
///   3. The Reminders button is wrapped in a permission guard or role check.
///   4. Preservation: admin/owner roles can still trigger reminders.
///
/// Run: flutter test test/bug_condition/hardware_reminder_rbac_gate_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  group('Bug Condition HARDWARE-022 — reminder trigger RBAC gate', () {
    final supplierScreenSrc = _readSource(
      'lib/features/hardware/presentation/screens/'
      'hardware_supplier_management_screen.dart',
    );

    final permissionMatrixSrc = _readSource(
      'lib/features/hardware/data/hardware_phase12_contracts.dart',
    );

    // =========================================================================
    // Core assertion 1: HardwarePermissionMatrix includes trigger_reminders
    // =========================================================================
    test('HardwarePermissionMatrix.moduleActions[suppliers] contains '
        'trigger_reminders action', () {
      // The fix adds 'trigger_reminders' to the suppliers action set.
      final hasTriggerReminders = permissionMatrixSrc.contains(
        'trigger_reminders',
      );

      expect(
        hasTriggerReminders,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-022): '
            "HardwarePermissionMatrix.moduleActions['suppliers'] does not "
            "include 'trigger_reminders'. Any user with 'view' on suppliers "
            'can trigger payment reminders. '
            "Fix: add 'trigger_reminders' to the suppliers action set.",
      );
    });

    // =========================================================================
    // Core assertion 2: Supplier screen imports session/role mechanism
    // =========================================================================
    test(
      'supplier management screen imports session or permission mechanism',
      () {
        final importsSession =
            supplierScreenSrc.contains('session_manager') ||
            supplierScreenSrc.contains('permission_guard') ||
            supplierScreenSrc.contains('role_management_service');

        expect(
          importsSession,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-022): '
              'HardwareSupplierManagementScreen does not import any session/'
              'role/permission mechanism. The Reminders button has no RBAC '
              'gate — any user can trigger supplier payment reminders. '
              'Fix: import SessionManager or PermissionGuard and check the '
              "user's role before showing the Reminders button.",
        );
      },
    );

    // =========================================================================
    // Core assertion 3: Reminders button is gated behind role/permission check
    // =========================================================================
    test('Reminders button is wrapped in a role or permission guard', () {
      // Look for evidence that the Reminders button region has a guard.
      // Possible patterns:
      //   - PermissionGuard / PermissionGuardConnected wrapping
      //   - RoleGuard wrapping
      //   - if (session.isOwner || role == UserRole.owner ...) around the button
      //   - Conditional visibility using effectiveRole
      final hasRbacGate =
          // Widget-based guards
          (supplierScreenSrc.contains('PermissionGuard') &&
              supplierScreenSrc.contains('Reminders')) ||
          (supplierScreenSrc.contains('RoleGuard') &&
              supplierScreenSrc.contains('Reminders')) ||
          // Inline role check near trigger_reminders / Reminders
          RegExp(
            r'(isOwner|effectiveRole|UserRole\.owner|UserRole\.manager|_canTriggerReminders)',
          ).hasMatch(supplierScreenSrc);

      expect(
        hasRbacGate,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-022): '
            'The Reminders button in HardwareSupplierManagementScreen is '
            'NOT wrapped in any PermissionGuard, RoleGuard, or inline role '
            'check. It is unconditionally visible and triggerable for ALL '
            'roles including "view"-only staff. '
            'Fix: wrap the Reminders OutlinedButton.icon in a RoleGuard '
            'allowing only owner/manager roles, or use an inline '
            'effectiveRole check to conditionally show/hide it.',
      );
    });

    // =========================================================================
    // Preservation: admin/owner triggering unaffected
    // =========================================================================
    test('preservation: _triggerRemindersDialog method still exists', () {
      expect(
        supplierScreenSrc.contains('_triggerRemindersDialog'),
        isTrue,
        reason:
            'Preservation (3.22): _triggerRemindersDialog() must still '
            'exist — admin/owner users must still be able to trigger '
            'supplier payment reminders.',
      );
    });

    // =========================================================================
    // Preservation: owner/manager are in the allowed roles
    // =========================================================================
    test('preservation: owner role is allowed to trigger reminders', () {
      // If using RoleGuard: allowedRoles should include UserRole.owner
      // If using inline check: must include isOwner or UserRole.owner
      final ownerAllowed =
          supplierScreenSrc.contains('UserRole.owner') ||
          supplierScreenSrc.contains('isOwner') ||
          supplierScreenSrc.contains("'owner'");

      expect(
        ownerAllowed,
        isTrue,
        reason:
            'Preservation (3.22): The owner role must be explicitly allowed '
            'to trigger reminders. The gate must permit owner (and '
            'optionally manager) to access the button.',
      );
    });
  });
}
