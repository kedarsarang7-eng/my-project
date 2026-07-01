// ============================================================================
// TASK 8.3 — RBAC Role Tests
// Feature: restaurant-vertical-remediation
// **Validates: Requirements 2.14, 3.5**
// ============================================================================
//
// Tests that the restaurant-specific roles (waiter, chef, captain) parse
// correctly via IsolationUserRoleExtension.fromString, have appropriate
// permission sets in RolePermissions, and do not escalate via
// resolveFallbackStaffRole. Also verifies preservation of existing role parsing.
//
// Run: flutter test test/features/restaurant/rbac_role_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/isolation/role_based_access_control.dart'
    show IsolationUserRoleExtension;
import 'package:dukanx/core/services/role_management_service.dart';
import 'package:dukanx/core/session/session_manager.dart' show SessionManager;

void main() {
  group('RBAC Role Parsing — new restaurant roles (Requirement 2.14)', () {
    test('parsing "waiter" → UserRole.waiter', () {
      expect(
        IsolationUserRoleExtension.fromString('waiter'),
        equals(UserRole.waiter),
      );
    });

    test('parsing "WAITER" (uppercase) → UserRole.waiter', () {
      expect(
        IsolationUserRoleExtension.fromString('WAITER'),
        equals(UserRole.waiter),
      );
    });

    test('parsing "chef" → UserRole.chef', () {
      expect(
        IsolationUserRoleExtension.fromString('chef'),
        equals(UserRole.chef),
      );
    });

    test('parsing "CHEF" (uppercase) → UserRole.chef', () {
      expect(
        IsolationUserRoleExtension.fromString('CHEF'),
        equals(UserRole.chef),
      );
    });

    test('parsing "COOK" (alias) → UserRole.chef', () {
      expect(
        IsolationUserRoleExtension.fromString('COOK'),
        equals(UserRole.chef),
      );
    });

    test('parsing "captain" → UserRole.captain', () {
      expect(
        IsolationUserRoleExtension.fromString('captain'),
        equals(UserRole.captain),
      );
    });

    test('parsing "CAPTAIN" (uppercase) → UserRole.captain', () {
      expect(
        IsolationUserRoleExtension.fromString('CAPTAIN'),
        equals(UserRole.captain),
      );
    });
  });

  group(
    'RBAC Role Parsing — preservation of existing roles (Requirement 3.5)',
    () {
      test('parsing "OWNER" → UserRole.owner', () {
        expect(
          IsolationUserRoleExtension.fromString('OWNER'),
          equals(UserRole.owner),
        );
      });

      test('parsing "MANAGER" → UserRole.manager', () {
        expect(
          IsolationUserRoleExtension.fromString('MANAGER'),
          equals(UserRole.manager),
        );
      });

      test('parsing "STAFF" → UserRole.staff', () {
        expect(
          IsolationUserRoleExtension.fromString('STAFF'),
          equals(UserRole.staff),
        );
      });

      test('parsing "CASHIER" → UserRole.staff', () {
        expect(
          IsolationUserRoleExtension.fromString('CASHIER'),
          equals(UserRole.staff),
        );
      });

      test('parsing "ACCOUNTANT" → UserRole.accountant', () {
        expect(
          IsolationUserRoleExtension.fromString('ACCOUNTANT'),
          equals(UserRole.accountant),
        );
      });

      test('parsing "PHARMACIST" → UserRole.pharmacist', () {
        expect(
          IsolationUserRoleExtension.fromString('PHARMACIST'),
          equals(UserRole.pharmacist),
        );
      });

      test('parsing unknown string → UserRole.unknown', () {
        expect(
          IsolationUserRoleExtension.fromString('INVALID_ROLE'),
          equals(UserRole.unknown),
        );
      });
    },
  );

  group('Permission sets — waiter (Requirement 2.14)', () {
    // Waiter: create orders (createBill + printBill) and view tables (viewStock)
    final expectedWaiterPermissions = <Permission>{
      Permission.createBill,
      Permission.printBill,
      Permission.viewStock,
    };

    test('waiter permission set matches expected grants', () {
      expect(
        RolePermissions.getPermissions(UserRole.waiter),
        equals(expectedWaiterPermissions),
      );
    });

    test('waiter has createBill permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.waiter, Permission.createBill),
        isTrue,
      );
    });

    test('waiter has viewStock permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.waiter, Permission.viewStock),
        isTrue,
      );
    });

    test('waiter does NOT have manageUsers permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.waiter, Permission.manageUsers),
        isFalse,
      );
    });

    test('waiter does NOT have viewReports permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.waiter, Permission.viewReports),
        isFalse,
      );
    });
  });

  group('Permission sets — chef (Requirement 2.14)', () {
    // Chef: view KDS (viewStock) and update order status (editBill)
    final expectedChefPermissions = <Permission>{
      Permission.viewStock,
      Permission.editBill,
    };

    test('chef permission set matches expected grants', () {
      expect(
        RolePermissions.getPermissions(UserRole.chef),
        equals(expectedChefPermissions),
      );
    });

    test('chef has viewStock permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.chef, Permission.viewStock),
        isTrue,
      );
    });

    test('chef has editBill permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.chef, Permission.editBill),
        isTrue,
      );
    });

    test('chef does NOT have createBill permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.chef, Permission.createBill),
        isFalse,
      );
    });

    test('chef does NOT have manageUsers permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.chef, Permission.manageUsers),
        isFalse,
      );
    });
  });

  group('Permission sets — captain (Requirement 2.14)', () {
    // Captain: all waiter + assign tables + view reports + createCustomer + viewCustomerBalance
    final expectedCaptainPermissions = <Permission>{
      Permission.createBill,
      Permission.printBill,
      Permission.editBill,
      Permission.viewStock,
      Permission.viewReports,
      Permission.createCustomer,
      Permission.viewCustomerBalance,
    };

    test('captain permission set matches expected grants', () {
      expect(
        RolePermissions.getPermissions(UserRole.captain),
        equals(expectedCaptainPermissions),
      );
    });

    test(
      'captain has all waiter permissions (createBill, printBill, viewStock)',
      () {
        expect(
          RolePermissions.hasPermission(
            UserRole.captain,
            Permission.createBill,
          ),
          isTrue,
        );
        expect(
          RolePermissions.hasPermission(UserRole.captain, Permission.printBill),
          isTrue,
        );
        expect(
          RolePermissions.hasPermission(UserRole.captain, Permission.viewStock),
          isTrue,
        );
      },
    );

    test('captain has viewReports permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.captain, Permission.viewReports),
        isTrue,
      );
    });

    test('captain has createCustomer permission', () {
      expect(
        RolePermissions.hasPermission(
          UserRole.captain,
          Permission.createCustomer,
        ),
        isTrue,
      );
    });

    test('captain has viewCustomerBalance permission', () {
      expect(
        RolePermissions.hasPermission(
          UserRole.captain,
          Permission.viewCustomerBalance,
        ),
        isTrue,
      );
    });

    test('captain does NOT have manageUsers permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.captain, Permission.manageUsers),
        isFalse,
      );
    });

    test('captain does NOT have deleteBill permission', () {
      expect(
        RolePermissions.hasPermission(UserRole.captain, Permission.deleteBill),
        isFalse,
      );
    });
  });

  group('resolveFallbackStaffRole — does not escalate new roles', () {
    test('waiter is preserved (not escalated to owner)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.waiter),
        equals(UserRole.waiter),
      );
    });

    test('chef is preserved (not escalated to owner)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.chef),
        equals(UserRole.chef),
      );
    });

    test('captain is preserved (not escalated to owner)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.captain),
        equals(UserRole.captain),
      );
    });

    test('existing staff roles still preserved — manager', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.manager),
        equals(UserRole.manager),
      );
    });

    test('existing staff roles still preserved — staff', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.staff),
        equals(UserRole.staff),
      );
    });

    test('existing staff roles still preserved — accountant', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.accountant),
        equals(UserRole.accountant),
      );
    });

    test('existing staff roles still preserved — pharmacist', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.pharmacist),
        equals(UserRole.pharmacist),
      );
    });

    test('owner falls back to owner (genuine owner)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.owner),
        equals(UserRole.owner),
      );
    });

    test('unknown falls back to owner (no usable cache)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(UserRole.unknown),
        equals(UserRole.owner),
      );
    });

    test('null falls back to owner (no cache)', () {
      expect(
        SessionManager.resolveFallbackStaffRole(null),
        equals(UserRole.owner),
      );
    });
  });
}
