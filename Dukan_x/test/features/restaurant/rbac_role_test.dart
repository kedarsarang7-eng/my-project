// ============================================================================
// RBAC Role Permission-Set Regression Lock Tests
// Feature: restaurant-audit-fixes (Task 12) + restaurant-vertical-remediation
// **Validates: Requirements 2.12, 3.9, 2.14, 3.5**
// ============================================================================
//
// Tests that the restaurant-specific roles (waiter, chef, captain) parse
// correctly via IsolationUserRoleExtension.fromString, have appropriate
// permission sets in RolePermissions, and do not escalate via
// resolveFallbackStaffRole. Also verifies preservation of existing role parsing.
//
// REGRESSION LOCK (Property 11):
// - For waiter/chef/captain: granted permission set matches the documented
//   least-privilege set exactly.
// - For manager/staff/accountant/owner: granted permission set is byte-for-byte
//   identical to before waiter/chef/captain were introduced (additive only).
//
// Run: flutter test test/features/restaurant/rbac_role_test.dart
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
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

  // ==========================================================================
  // Task 19.1 — Bug Condition Exploration: useWaiterLinking capability declared
  // but never checked against a role
  // **Validates: Requirements 2.12**
  //
  // EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
  //
  // Bug Condition: useWaiterLinking capability is declared in the
  // BusinessCapability enum and granted to restaurant in the capability
  // registry, but NO code path binds it to any user role (waiter, captain,
  // owner, manager). The PermissionWrapper and FeatureResolver only check if
  // the business TYPE has the capability — they never consult UserRole.
  //
  // This test asserts the POSITIVE expectation: that a RoleCapabilityBinding
  // (or equivalent mapping) exists connecting useWaiterLinking to specific
  // roles, and that UI code consults this binding. On UNFIXED code this FAILS
  // because no such binding exists.
  //
  // COUNTEREXAMPLE (documented after first run):
  // useWaiterLinking is declared at business_capability.dart:99 and granted to
  // restaurant at business_capability.dart:325, but:
  //   - No RoleCapabilityBinding class exists anywhere in the codebase
  //   - No code consults UserRole.waiter/captain/owner/manager when evaluating
  //     useWaiterLinking-gated UI
  //   - PermissionWrapper only checks FeatureResolver.canAccess(businessType, cap)
  //     — never checks role
  //   - sidebar_configuration.dart never uses useWaiterLinking as a gate
  // ==========================================================================

  group(
    'Bug Condition Exploration 19.1 — useWaiterLinking capability declared but never bound to a role (Req 2.12)',
    () {
      late String businessCapabilitySource;
      late String featureResolverSource;
      late String sidebarConfigSource;

      setUpAll(() {
        final capFile = File('lib/core/isolation/business_capability.dart');
        expect(
          capFile.existsSync(),
          isTrue,
          reason: 'business_capability.dart must exist',
        );
        businessCapabilitySource = capFile.readAsStringSync();

        final resolverFile = File('lib/core/isolation/feature_resolver.dart');
        expect(
          resolverFile.existsSync(),
          isTrue,
          reason: 'feature_resolver.dart must exist',
        );
        featureResolverSource = resolverFile.readAsStringSync();

        final configFile = File(
          'lib/widgets/desktop/sidebar_configuration.dart',
        );
        expect(
          configFile.existsSync(),
          isTrue,
          reason: 'sidebar_configuration.dart must exist',
        );
        sidebarConfigSource = configFile.readAsStringSync();
      });

      // =====================================================================
      // Sub-Test 1: useWaiterLinking IS declared in the capability enum.
      // This PASSES on both unfixed and fixed code.
      // =====================================================================
      test('useWaiterLinking is declared in BusinessCapability enum', () {
        expect(
          businessCapabilitySource.contains('useWaiterLinking'),
          isTrue,
          reason:
              'useWaiterLinking must be declared in the BusinessCapability enum',
        );
      });

      // =====================================================================
      // Sub-Test 2: useWaiterLinking IS granted to restaurant in the registry.
      // This PASSES on both unfixed and fixed code.
      // =====================================================================
      test(
        'useWaiterLinking is granted to restaurant in capability registry',
        () {
          // The restaurant entry in businessCapabilityRegistry should contain
          // useWaiterLinking
          final restaurantBlockStart = businessCapabilitySource.indexOf(
            "'restaurant'",
          );
          expect(
            restaurantBlockStart,
            isNot(-1),
            reason: 'restaurant entry must exist in capability registry',
          );

          // Find the closing brace of the restaurant capability set
          final setStart = businessCapabilitySource.indexOf(
            '{',
            restaurantBlockStart,
          );
          expect(
            setStart,
            isNot(-1),
            reason: 'restaurant capability set must have opening brace',
          );

          int depth = 0;
          int setEnd = -1;
          for (int i = setStart; i < businessCapabilitySource.length; i++) {
            if (businessCapabilitySource[i] == '{') depth++;
            if (businessCapabilitySource[i] == '}') {
              depth--;
              if (depth == 0) {
                setEnd = i + 1;
                break;
              }
            }
          }
          expect(
            setEnd,
            isNot(-1),
            reason: 'restaurant capability set must have closing brace',
          );

          final restaurantCapabilities = businessCapabilitySource.substring(
            setStart,
            setEnd,
          );
          expect(
            restaurantCapabilities.contains(
              'BusinessCapability.useWaiterLinking',
            ),
            isTrue,
            reason:
                'useWaiterLinking must be granted to restaurant in the '
                'capability registry',
          );
        },
      );

      // =====================================================================
      // Sub-Test 3: A RoleCapabilityBinding (or equivalent) exists that maps
      // useWaiterLinking to roles.
      // On UNFIXED code this FAILS — no such binding exists anywhere.
      // =====================================================================
      test(
        'a RoleCapabilityBinding or role-to-capability map exists for useWaiterLinking',
        () {
          // Search the lib directory for any file containing a role-to-capability
          // mapping that references useWaiterLinking
          final libDir = Directory('lib');
          expect(
            libDir.existsSync(),
            isTrue,
            reason: 'lib directory must exist',
          );

          bool foundRoleCapabilityBinding = false;
          for (final entity in libDir.listSync(recursive: true)) {
            if (entity is File && entity.path.endsWith('.dart')) {
              final content = entity.readAsStringSync();
              // Look for any of these patterns that would indicate a role-capability binding:
              // - A class/map named RoleCapabilityBinding
              // - A map from UserRole to Set<BusinessCapability> that includes useWaiterLinking
              // - Any code that checks role against useWaiterLinking
              if (content.contains('RoleCapabilityBinding') ||
                  (content.contains('useWaiterLinking') &&
                      (content.contains('UserRole.waiter') ||
                          content.contains('UserRole.captain')) &&
                      // Must be in a binding/mapping context, not just co-located
                      (content.contains('Map<') ||
                          content.contains('roleCapabilities') ||
                          content.contains('capabilityRoles') ||
                          content.contains('binding')))) {
                foundRoleCapabilityBinding = true;
                break;
              }
            }
          }

          expect(
            foundRoleCapabilityBinding,
            isTrue,
            reason:
                'COUNTEREXAMPLE (2.12): useWaiterLinking capability is declared '
                'in BusinessCapability enum and granted to restaurant in the '
                'capability registry, but NO RoleCapabilityBinding or '
                'equivalent role-to-capability map exists anywhere in the '
                'codebase.\n\n'
                'Expected: A class or map (e.g., RoleCapabilityBinding) that '
                'declares useWaiterLinking → {UserRole.waiter, UserRole.captain, '
                'UserRole.owner, UserRole.manager}, consulted wherever '
                'useWaiterLinking-gated UI renders.\n\n'
                'Actual: The only capability-check code is '
                'FeatureResolver.canAccess(businessType, capability) and '
                'PermissionWrapper — both check business TYPE only, never '
                'user ROLE. The capability is declared but has no binding '
                'to any role.',
          );
        },
      );

      // =====================================================================
      // Sub-Test 4: FeatureResolver or PermissionWrapper consults UserRole
      // when evaluating useWaiterLinking.
      // On UNFIXED code this FAILS — neither checks role.
      // =====================================================================
      test(
        'capability check infrastructure consults UserRole for useWaiterLinking',
        () {
          // Check if FeatureResolver references UserRole at all
          final resolverChecksRole =
              featureResolverSource.contains('UserRole') ||
              featureResolverSource.contains('role') &&
                  featureResolverSource.contains('useWaiterLinking');

          // Also check PermissionWrapper
          final permWrapperFile = File(
            'lib/widgets/desktop/permission_wrapper.dart',
          );
          final permWrapperSource = permWrapperFile.existsSync()
              ? permWrapperFile.readAsStringSync()
              : '';
          final wrapperChecksRole =
              permWrapperSource.contains('UserRole') ||
              permWrapperSource.contains('role_management') ||
              permWrapperSource.contains('RoleCapabilityBinding');

          expect(
            resolverChecksRole || wrapperChecksRole,
            isTrue,
            reason:
                'COUNTEREXAMPLE (2.12): Neither FeatureResolver nor '
                'PermissionWrapper consults UserRole when evaluating '
                'capabilities.\n\n'
                'FeatureResolver.canAccess(businessType, capability) checks:\n'
                '  1. Is capability in _universalCapabilities?\n'
                '  2. Is capability in businessCapabilityRegistry[typeKey]?\n'
                'It NEVER checks the current user\'s role.\n\n'
                'PermissionWrapper.build() calls:\n'
                '  FeatureResolver.canAccess(businessTypeState.type.name, '
                'capability)\n'
                'It also NEVER checks the current user\'s role.\n\n'
                'Result: useWaiterLinking is granted to "restaurant" business '
                'type universally — ALL users of a restaurant business see '
                'useWaiterLinking-gated UI regardless of whether they are a '
                'waiter, chef, staff, or accountant. The capability exists '
                'but provides zero role-based access control.',
          );
        },
      );

      // =====================================================================
      // Sub-Test 5: sidebar_configuration.dart uses useWaiterLinking as a
      // capability gate on at least one restaurant sidebar item.
      // On UNFIXED code this FAILS — useWaiterLinking is never used as a gate.
      // =====================================================================
      test(
        'useWaiterLinking is used as a capability gate in restaurant sidebar items',
        () {
          // Direct structural check: the sidebar configuration file must
          // reference useWaiterLinking as a capability on at least one
          // restaurant sidebar item.
          expect(
            sidebarConfigSource.contains('BusinessCapability.useWaiterLinking'),
            isTrue,
            reason:
                'sidebar_configuration.dart must reference '
                'BusinessCapability.useWaiterLinking as a capability gate on '
                'at least one restaurant sidebar item.',
          );

          // Specifically, the restaurant_command_center item must have it
          expect(
            sidebarConfigSource.contains(
              "capability: BusinessCapability.useWaiterLinking",
            ),
            isTrue,
            reason:
                'restaurant_command_center sidebar item must have '
                'capability: BusinessCapability.useWaiterLinking.',
          );
        },
      );
    },
  );

  // ==========================================================================
  // Property 11 — Regression Lock: Pre-existing role permission sets unchanged
  // **Validates: Requirements 2.12, 3.9**
  //
  // These tests exhaustively enumerate the permission sets for manager, staff,
  // accountant, and owner to ensure introducing waiter/chef/captain did NOT
  // alter any pre-existing role's granted permissions.
  // ==========================================================================

  group(
    'Regression-lock: owner permission set unchanged after waiter/chef/captain introduction (Req 3.9)',
    () {
      // Owner: full access — all permissions
      final expectedOwnerPermissions = <Permission>{
        Permission.createBill, Permission.editBill, Permission.deleteBill,
        Permission.reverseBill, Permission.printBill,
        Permission.createCustomer, Permission.editCustomer,
        Permission.deleteCustomer, Permission.viewCustomerBalance,
        Permission.createSupplier, Permission.editSupplier,
        Permission.deleteSupplier,
        Permission.createPurchase, Permission.editPurchase,
        Permission.viewStock, Permission.editStock, Permission.adjustStock,
        Permission.viewReports, Permission.viewCashBook, Permission.viewLedger,
        Permission.makePayment, Permission.receivePayment,
        Permission.journalEntry,
        Permission.lockPeriod, Permission.unlockPeriod,
        Permission.closeFinancialYear,
        Permission.manageUsers, Permission.manageSettings,
        Permission.viewAuditLog,
        Permission.viewGstReports, Permission.fileGstReturns,
        // Fraud Prevention (Owner-only)
        Permission.viewProfit, Permission.viewMargins,
        Permission.applyHighDiscount, Permission.processRefund,
        Permission.acceptCashMismatch, Permission.closeCashDay,
        Permission.viewSecurityDashboard, Permission.manageFraudAlerts,
      };

      test('owner permission set is exactly the documented full set', () {
        expect(
          RolePermissions.getPermissions(UserRole.owner),
          equals(expectedOwnerPermissions),
        );
      });

      test('owner permission count is stable', () {
        expect(
          RolePermissions.getPermissions(UserRole.owner).length,
          equals(expectedOwnerPermissions.length),
        );
      });
    },
  );

  group(
    'Regression-lock: manager permission set unchanged after waiter/chef/captain introduction (Req 3.9)',
    () {
      // Manager: operational access — limited financial operations
      final expectedManagerPermissions = <Permission>{
        Permission.createBill,
        Permission.editBill,
        Permission.printBill,
        Permission.createCustomer,
        Permission.editCustomer,
        Permission.viewCustomerBalance,
        Permission.createSupplier,
        Permission.editSupplier,
        Permission.createPurchase,
        Permission.viewStock,
        Permission.adjustStock,
        Permission.viewReports,
        Permission.viewCashBook,
        Permission.makePayment,
        Permission.receivePayment,
      };

      test('manager permission set is exactly the documented set', () {
        expect(
          RolePermissions.getPermissions(UserRole.manager),
          equals(expectedManagerPermissions),
        );
      });

      test('manager permission count is stable', () {
        expect(
          RolePermissions.getPermissions(UserRole.manager).length,
          equals(expectedManagerPermissions.length),
        );
      });

      test('manager does NOT have deleteBill', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.manager,
            Permission.deleteBill,
          ),
          isFalse,
        );
      });

      test('manager does NOT have reverseBill', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.manager,
            Permission.reverseBill,
          ),
          isFalse,
        );
      });

      test('manager does NOT have journalEntry', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.manager,
            Permission.journalEntry,
          ),
          isFalse,
        );
      });

      test('manager does NOT have lockPeriod', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.manager,
            Permission.lockPeriod,
          ),
          isFalse,
        );
      });

      test('manager does NOT have manageUsers', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.manager,
            Permission.manageUsers,
          ),
          isFalse,
        );
      });
    },
  );

  group(
    'Regression-lock: staff permission set unchanged after waiter/chef/captain introduction (Req 3.9)',
    () {
      // Staff: general staff access — billing and basic operations
      final expectedStaffPermissions = <Permission>{
        Permission.createBill,
        Permission.printBill,
        Permission.createCustomer,
        Permission.viewCustomerBalance,
        Permission.viewStock,
        Permission.receivePayment,
        Permission.closeCashDay,
      };

      test('staff permission set is exactly the documented set', () {
        expect(
          RolePermissions.getPermissions(UserRole.staff),
          equals(expectedStaffPermissions),
        );
      });

      test('staff permission count is stable', () {
        expect(
          RolePermissions.getPermissions(UserRole.staff).length,
          equals(expectedStaffPermissions.length),
        );
      });

      test('staff does NOT have editBill', () {
        expect(
          RolePermissions.hasPermission(UserRole.staff, Permission.editBill),
          isFalse,
        );
      });

      test('staff does NOT have viewReports', () {
        expect(
          RolePermissions.hasPermission(UserRole.staff, Permission.viewReports),
          isFalse,
        );
      });

      test('staff does NOT have manageUsers', () {
        expect(
          RolePermissions.hasPermission(UserRole.staff, Permission.manageUsers),
          isFalse,
        );
      });
    },
  );

  group(
    'Regression-lock: accountant permission set unchanged after waiter/chef/captain introduction (Req 3.9)',
    () {
      // Accountant: financial access — no user management, no delete operations
      final expectedAccountantPermissions = <Permission>{
        Permission.createBill,
        Permission.editBill,
        Permission.reverseBill,
        Permission.printBill,
        Permission.createCustomer,
        Permission.editCustomer,
        Permission.viewCustomerBalance,
        Permission.createSupplier,
        Permission.editSupplier,
        Permission.createPurchase,
        Permission.editPurchase,
        Permission.viewStock,
        Permission.adjustStock,
        Permission.viewReports,
        Permission.viewCashBook,
        Permission.viewLedger,
        Permission.makePayment,
        Permission.receivePayment,
        Permission.journalEntry,
        Permission.lockPeriod,
        Permission.viewAuditLog,
        Permission.viewGstReports,
        Permission.fileGstReturns,
      };

      test('accountant permission set is exactly the documented set', () {
        expect(
          RolePermissions.getPermissions(UserRole.accountant),
          equals(expectedAccountantPermissions),
        );
      });

      test('accountant permission count is stable', () {
        expect(
          RolePermissions.getPermissions(UserRole.accountant).length,
          equals(expectedAccountantPermissions.length),
        );
      });

      test('accountant does NOT have deleteBill', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.deleteBill,
          ),
          isFalse,
        );
      });

      test('accountant does NOT have deleteCustomer', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.deleteCustomer,
          ),
          isFalse,
        );
      });

      test('accountant does NOT have deleteSupplier', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.deleteSupplier,
          ),
          isFalse,
        );
      });

      test('accountant does NOT have unlockPeriod', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.unlockPeriod,
          ),
          isFalse,
        );
      });

      test('accountant does NOT have closeFinancialYear', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.closeFinancialYear,
          ),
          isFalse,
        );
      });

      test('accountant does NOT have manageUsers', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.manageUsers,
          ),
          isFalse,
        );
      });

      test('accountant does NOT have manageSettings', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.manageSettings,
          ),
          isFalse,
        );
      });
    },
  );

  // ==========================================================================
  // Task 19.2 — Preservation Test: generic roles' access to restaurant
  // features (including useWaiterLinking-gated UI) is unaffected by the
  // upcoming RoleCapabilityBinding (Task 19.3).
  // **Validates: Requirements 3.9**
  //
  // PRESERVATION TEST — expected to PASS on unfixed code.
  //
  // Current state: FeatureResolver.canAccess('restaurant', useWaiterLinking)
  // returns true unconditionally for ANY user of a restaurant business (it
  // checks business TYPE only, never user ROLE). This means manager, staff,
  // accountant, and owner ALL currently have access to useWaiterLinking-gated
  // UI.
  //
  // After Task 19.3 adds a RoleCapabilityBinding mapping useWaiterLinking to
  // {waiter, captain, owner, manager}, these 4 generic roles must STILL retain
  // access to all restaurant features they currently access.
  //
  // This test locks:
  //   (a) FeatureResolver grants useWaiterLinking to restaurant business type
  //   (b) Permission sets for manager/staff/accountant/owner are stable
  //   (c) All 4 generic roles retain access to the restaurant capability set
  // ==========================================================================

  group(
    'Preservation 19.2 — generic roles access to restaurant features unaffected by RoleCapabilityBinding (Req 3.9)',
    () {
      // =====================================================================
      // (a) FeatureResolver.canAccess('restaurant', useWaiterLinking) is true
      // (confirms all restaurant users currently have access unconditionally)
      // =====================================================================
      test(
        'FeatureResolver.canAccess grants useWaiterLinking to restaurant business type unconditionally',
        () {
          expect(
            FeatureResolver.canAccess(
              'restaurant',
              BusinessCapability.useWaiterLinking,
            ),
            isTrue,
            reason:
                'useWaiterLinking must be granted to restaurant business type '
                'in the capability registry — this is the baseline access that '
                'all restaurant users (regardless of role) currently enjoy',
          );
        },
      );

      // =====================================================================
      // Also verify the other restaurant capabilities remain granted
      // (these are the features generic roles currently access)
      // =====================================================================
      test('FeatureResolver grants useKOT to restaurant business type', () {
        expect(
          FeatureResolver.canAccess('restaurant', BusinessCapability.useKOT),
          isTrue,
        );
      });

      test(
        'FeatureResolver grants useTableManagement to restaurant business type',
        () {
          expect(
            FeatureResolver.canAccess(
              'restaurant',
              BusinessCapability.useTableManagement,
            ),
            isTrue,
          );
        },
      );

      test(
        'FeatureResolver grants useKitchenDisplay to restaurant business type',
        () {
          expect(
            FeatureResolver.canAccess(
              'restaurant',
              BusinessCapability.useKitchenDisplay,
            ),
            isTrue,
          );
        },
      );

      // =====================================================================
      // (b) Permission sets for the 4 generic roles are stable
      // (confirms that no role's permissions were accidentally modified)
      // =====================================================================
      test('manager permission set count is unchanged', () {
        final perms = RolePermissions.getPermissions(UserRole.manager);
        expect(
          perms.length,
          equals(15),
          reason:
              'manager permission set must remain at 15 permissions — '
              'adding RoleCapabilityBinding must not alter this',
        );
      });

      test('staff permission set count is unchanged', () {
        final perms = RolePermissions.getPermissions(UserRole.staff);
        expect(
          perms.length,
          equals(7),
          reason:
              'staff permission set must remain at 7 permissions — '
              'adding RoleCapabilityBinding must not alter this',
        );
      });

      test('accountant permission set count is unchanged', () {
        final perms = RolePermissions.getPermissions(UserRole.accountant);
        expect(
          perms.length,
          equals(23),
          reason:
              'accountant permission set must remain at 23 permissions — '
              'adding RoleCapabilityBinding must not alter this',
        );
      });

      test('owner permission set count is unchanged', () {
        final perms = RolePermissions.getPermissions(UserRole.owner);
        expect(
          perms.length,
          equals(39),
          reason:
              'owner permission set must remain at 39 permissions — '
              'adding RoleCapabilityBinding must not alter this',
        );
      });

      // =====================================================================
      // (c) All 4 generic roles retain core restaurant permissions
      // (viewStock is the permission mapped to "view tables"/"view KDS")
      // =====================================================================
      test('manager retains viewStock (restaurant screen access)', () {
        expect(
          RolePermissions.hasPermission(UserRole.manager, Permission.viewStock),
          isTrue,
          reason:
              'manager must retain viewStock — this maps to table/KDS access',
        );
      });

      test('manager retains createBill (bill creation access)', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.manager,
            Permission.createBill,
          ),
          isTrue,
          reason:
              'manager must retain createBill — this maps to waiter-linking UI',
        );
      });

      test('staff retains viewStock (restaurant screen access)', () {
        expect(
          RolePermissions.hasPermission(UserRole.staff, Permission.viewStock),
          isTrue,
          reason: 'staff must retain viewStock — this maps to table/KDS access',
        );
      });

      test('staff retains createBill (bill creation access)', () {
        expect(
          RolePermissions.hasPermission(UserRole.staff, Permission.createBill),
          isTrue,
          reason:
              'staff must retain createBill — this maps to waiter-linking UI',
        );
      });

      test('accountant retains viewStock (restaurant screen access)', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.viewStock,
          ),
          isTrue,
          reason:
              'accountant must retain viewStock — this maps to table/KDS access',
        );
      });

      test('accountant retains createBill (bill creation access)', () {
        expect(
          RolePermissions.hasPermission(
            UserRole.accountant,
            Permission.createBill,
          ),
          isTrue,
          reason:
              'accountant must retain createBill — this maps to waiter-linking UI',
        );
      });

      test('owner retains viewStock (restaurant screen access)', () {
        expect(
          RolePermissions.hasPermission(UserRole.owner, Permission.viewStock),
          isTrue,
          reason: 'owner must retain viewStock — this maps to table/KDS access',
        );
      });

      test('owner retains createBill (bill creation access)', () {
        expect(
          RolePermissions.hasPermission(UserRole.owner, Permission.createBill),
          isTrue,
          reason:
              'owner must retain createBill — this maps to waiter-linking UI',
        );
      });

      // =====================================================================
      // (d) FeatureResolver does NOT currently check UserRole for restaurant
      // capabilities — confirming that all roles see useWaiterLinking-gated UI.
      // After 19.3, manager/staff/accountant/owner must still be included in
      // the RoleCapabilityBinding for useWaiterLinking.
      // =====================================================================
      test(
        'FeatureResolver.canAccess is role-agnostic (business-type check only)',
        () {
          // The same call returns true regardless of which user role is logged in
          // because FeatureResolver checks business type, not role.
          // This confirms all 4 generic roles currently get access.
          final result = FeatureResolver.canAccess(
            'restaurant',
            BusinessCapability.useWaiterLinking,
          );
          expect(
            result,
            isTrue,
            reason:
                'FeatureResolver.canAccess must return true for restaurant + '
                'useWaiterLinking regardless of user role — this is the current '
                'behavior that Task 19.3 must preserve for generic roles',
          );

          // Verify the method signature doesn't take a role parameter
          // (if it did, it would mean role-based checks exist — contradicting
          // the preservation baseline)
          // This is implicitly confirmed by the fact that canAccess only takes
          // (String businessType, BusinessCapability capability) — no role arg.
        },
      );
    },
  );

  // ==========================================================================
  // Cross-role isolation check: new roles did NOT leak permissions into
  // existing roles and existing roles did NOT leak into new roles
  // ==========================================================================

  group(
    'Cross-role isolation: waiter/chef/captain are strictly additive (Req 2.12, 3.9)',
    () {
      test('waiter permissions are a strict subset of captain permissions', () {
        final waiterPerms = RolePermissions.getPermissions(UserRole.waiter);
        final captainPerms = RolePermissions.getPermissions(UserRole.captain);
        expect(captainPerms.containsAll(waiterPerms), isTrue);
      });

      test(
        'chef permissions do NOT include captain-only permissions (createBill)',
        () {
          expect(
            RolePermissions.hasPermission(UserRole.chef, Permission.createBill),
            isFalse,
          );
        },
      );

      test('waiter permissions are a strict subset of owner permissions', () {
        final waiterPerms = RolePermissions.getPermissions(UserRole.waiter);
        final ownerPerms = RolePermissions.getPermissions(UserRole.owner);
        expect(ownerPerms.containsAll(waiterPerms), isTrue);
      });

      test('captain permissions are a strict subset of owner permissions', () {
        final captainPerms = RolePermissions.getPermissions(UserRole.captain);
        final ownerPerms = RolePermissions.getPermissions(UserRole.owner);
        expect(ownerPerms.containsAll(captainPerms), isTrue);
      });

      test('chef permissions are a strict subset of owner permissions', () {
        final chefPerms = RolePermissions.getPermissions(UserRole.chef);
        final ownerPerms = RolePermissions.getPermissions(UserRole.owner);
        expect(ownerPerms.containsAll(chefPerms), isTrue);
      });

      test('new restaurant roles do not share sensitive admin permissions', () {
        for (final role in [UserRole.waiter, UserRole.chef, UserRole.captain]) {
          expect(
            RolePermissions.hasPermission(role, Permission.manageUsers),
            isFalse,
            reason: '$role should not have manageUsers',
          );
          expect(
            RolePermissions.hasPermission(role, Permission.manageSettings),
            isFalse,
            reason: '$role should not have manageSettings',
          );
          expect(
            RolePermissions.hasPermission(role, Permission.closeFinancialYear),
            isFalse,
            reason: '$role should not have closeFinancialYear',
          );
          expect(
            RolePermissions.hasPermission(role, Permission.viewAuditLog),
            isFalse,
            reason: '$role should not have viewAuditLog',
          );
        }
      });
    },
  );
}
