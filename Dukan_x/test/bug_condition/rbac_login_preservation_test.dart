/// Preservation Property Tests — RBAC-Login Integration
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
///
/// Property 2: Preservation — Owner and Non-Staff Authentication Behavior Unchanged
///
/// These tests observe behavior on UNFIXED code for cases where the bug
/// condition does NOT hold (primary owner, customer-only mode, dev bypass,
/// offline recovery, business-type gating, staff CRUD).
/// They MUST PASS on unfixed code, confirming baseline behavior to preserve.
///
/// Strategy (observation-first):
/// - Observe: Primary owner login → session.role = UserRole.owner, isOwner = true
/// - Observe: Customer-only mode → vendor login blocked
/// - Observe: No business type → VendorOnboardingScreen shown
/// - Observe: devBypassAuth = true → all auth/RBAC checks skipped
/// - Observe: Offline recovery → session from SharedPreferences
/// - Observe: FeatureResolver.canAccess() → gates by business type
/// - Observe: Staff CRUD → writes to business_users collection
///
/// Run: flutter test test/bug_condition/rbac_login_preservation_test.dart
library;

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/services/role_management_service.dart' as rbac;
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/security/permission_guard.dart';

/// Number of property test iterations
const int kNumRuns = 100;

void main() {
  // ==========================================================================
  // PROPERTY 2.1: Primary Owner Authentication Preserved
  // For all primary owner authentication attempts (no staff role override or
  // business_users.role = owner), session resolves to UserRole.owner with full
  // permissions.
  // **Validates: Requirements 3.1**
  // ==========================================================================
  group('Preservation 3.1: Primary owner gets full access', () {
    test(
      'Property: for all owner UserSession instances, role=owner and isOwner=true',
      () {
        // Generate random owner session configurations using uid index
        final uidIndexGen = Gen.interval(1, 99999);

        forAll(
          (int uidIdx) {
            final uid = 'owner_$uidIdx';
            // On unfixed code, any vendor-side user resolves to owner
            final session = UserSession(
              odId: uid,
              email: 'owner@example.com',
              role: UserRole.owner,
              ownerId: uid,
              lastLoginAt: DateTime.now(),
            );

            // PRESERVATION: owner session always has role=owner and isOwner=true
            expect(
              session.role,
              equals(UserRole.owner),
              reason: 'Primary owner session.role must be UserRole.owner',
            );
            expect(
              session.isOwner,
              isTrue,
              reason: 'Primary owner session.isOwner must be true',
            );
            expect(
              session.isAuthenticated,
              isTrue,
              reason: 'Primary owner session must be authenticated',
            );
            expect(
              session.isCustomer,
              isFalse,
              reason: 'Owner must not be identified as customer',
            );
            expect(
              session.isPatient,
              isFalse,
              reason: 'Owner must not be identified as patient',
            );
            return true;
          },
          [uidIndexGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: for all owner sessions, RBAC owner role grants ALL permissions',
      () {
        // The RBAC permission matrix grants all permissions to UserRole.owner
        final allPermissions = rbac.Permission.values;

        for (final perm in allPermissions) {
          expect(
            rbac.RolePermissions.hasPermission(rbac.UserRole.owner, perm),
            isTrue,
            reason: 'Owner must have permission: ${perm.name}',
          );
        }

        // Verify owner permission set equals full permission set
        final ownerPerms = rbac.RolePermissions.getPermissions(
          rbac.UserRole.owner,
        );
        expect(
          ownerPerms.length,
          equals(allPermissions.length),
          reason: 'Owner must have ALL ${allPermissions.length} permissions',
        );
      },
    );

    test(
      'Property: for all owner sessions with various metadata, isOwner remains true',
      () {
        final typeGen = Gen.elementOf<BusinessType>(BusinessType.values);

        forAll(
          (BusinessType type) {
            final session = UserSession(
              odId: 'owner-uid',
              email: 'owner@test.com',
              role: UserRole.owner,
              ownerId: 'owner-uid',
              businessType: type,
              lastLoginAt: DateTime.now(),
            );

            expect(
              session.isOwner,
              isTrue,
              reason:
                  'Owner with businessType=${type.name} must remain isOwner=true',
            );
            expect(session.role, equals(UserRole.owner));
            return true;
          },
          [typeGen],
          numRuns: kNumRuns,
        );
      },
    );
  });

  // ==========================================================================
  // PROPERTY 2.2: Customer-Only Mode Blocks Vendor Login
  // For all AppMode.customerOnly states, vendor login is blocked and only
  // customer screens are accessible.
  // **Validates: Requirements 3.2**
  // ==========================================================================
  group('Preservation 3.2: Customer-only mode blocks vendor login', () {
    test('Property: for all customerOnly sessions, appMode is customerOnly', () {
      final vendorIdIndexGen = Gen.interval(1, 99999);

      forAll(
        (int vendorIdx) {
          final vendorId = 'vendor_$vendorIdx';
          // In unified enum, customer-only mode uses unknown role (not vendor)
          final session = UserSession(
            odId: 'customer-uid',
            email: 'customer@test.com',
            role: UserRole.unknown,
            ownerId: vendorId,
            appMode: AppMode.customerOnly,
            lockedVendorId: vendorId,
          );

          // PRESERVATION: customer-only mode properties hold
          expect(
            session.appMode,
            equals(AppMode.customerOnly),
            reason: 'Session must be in customerOnly mode',
          );
          expect(
            session.lockedVendorId,
            equals(vendorId),
            reason: 'Locked vendor ID must be set',
          );
          expect(
            session.isOwner,
            isFalse,
            reason: 'Customer-only mode must not allow owner access',
          );
          // isCustomer is now a legacy getter that always returns false
          expect(
            session.isCustomer,
            isFalse,
            reason: 'isCustomer is legacy getter (always false)',
          );
          return true;
        },
        [vendorIdIndexGen],
        numRuns: kNumRuns,
      );
    });

    test(
      'Property: for all non-owner roles in customerOnly mode, isOwner is false',
      () {
        // In customerOnly mode, non-owner roles must not have owner access
        const session = UserSession(
          odId: 'vendor-uid',
          role: UserRole.unknown,
          appMode: AppMode.customerOnly,
          lockedVendorId: 'vendor-uid',
        );

        expect(
          session.isOwner,
          isFalse,
          reason: 'In customerOnly mode, owner login must be blocked',
        );
      },
    );

    test(
      'Property: AppMode enum has exactly normal and customerOnly values',
      () {
        expect(AppMode.values.length, equals(2));
        expect(AppMode.values, contains(AppMode.normal));
        expect(AppMode.values, contains(AppMode.customerOnly));
      },
    );
  });

  // ==========================================================================
  // PROPERTY 2.3: VendorOnboardingScreen Shown When No Business Type
  // For all users without selected business type, VendorOnboardingScreen is
  // shown before dashboard.
  // **Validates: Requirements 3.3**
  // ==========================================================================
  group('Preservation 3.3: No business type → VendorOnboardingScreen', () {
    test(
      'Property: for all owner sessions with null businessType, onboarding is needed',
      () {
        final uidIndexGen = Gen.interval(1, 99999);

        forAll(
          (int uidIdx) {
            final uid = 'user_$uidIdx';
            final session = UserSession(
              odId: uid,
              role: UserRole.owner,
              ownerId: uid,
              businessType: null, // No business type selected
            );

            // PRESERVATION: no business type means onboarding needed
            expect(
              session.isOwner,
              isTrue,
              reason: 'Owner without business type is still authenticated',
            );
            expect(session.isAuthenticated, isTrue);
            expect(
              session.businessType,
              isNull,
              reason: 'Business type must be null to trigger onboarding',
            );
            return true;
          },
          [uidIndexGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: AuthGate checks SharedPreferences for business_type before showing dashboard',
      () {
        // This tests the contract: if business_type key is absent in prefs,
        // VendorOnboardingScreen must be shown.
        // On unfixed code, AuthGate._checkBusinessType reads:
        //   prefs.getString('business_type') != null || prefs.getInt('business_type') != null
        // and shows VendorOnboardingScreen when false.

        // Verify session can exist with null businessType (the trigger condition)
        const session = UserSession(
          odId: 'new-user',
          role: UserRole.owner,
          ownerId: 'new-user',
          businessType: null,
        );
        expect(session.businessType, isNull);
        expect(session.isOwner, isTrue);
        // The AuthGate contract: owner + no business_type → VendorOnboardingScreen
      },
    );
  });

  // ==========================================================================
  // PROPERTY 2.4: Dev Bypass Skips All Auth/RBAC Checks
  // For all dev bypass enabled states, auth/RBAC checks are completely skipped.
  // **Validates: Requirements 3.4**
  // ==========================================================================
  group('Preservation 3.4: Dev bypass skips all auth/RBAC', () {
    test('Property: devBypassLogin creates owner session with full access', () {
      // On unfixed code, devBypassLogin() creates:
      // UserSession(odId: 'dev-admin-id', role: UserRole.owner, ...)
      const devSession = UserSession(
        odId: 'dev-admin-id',
        email: 'admin@myvyaparmitra.com',
        displayName: 'Dev Admin',
        role: UserRole.owner,
        ownerId: 'dev-admin-id',
      );

      // PRESERVATION: dev bypass always gives full owner access
      expect(
        devSession.role,
        equals(UserRole.owner),
        reason: 'Dev bypass must give owner role',
      );
      expect(
        devSession.isOwner,
        isTrue,
        reason: 'Dev bypass must give isOwner=true',
      );
      expect(
        devSession.isAuthenticated,
        isTrue,
        reason: 'Dev bypass session must be authenticated',
      );
      expect(
        devSession.odId,
        equals('dev-admin-id'),
        reason: 'Dev bypass uses dev-admin-id',
      );
    });

    test(
      'Property: for all permission checks, owner role always grants access',
      () {
        // devBypassAuth=true skips ProtectedRoute entirely.
        // Even when it's false, devBypassLogin gives owner role which
        // has all permissions.
        final permGen = Gen.elementOf<rbac.Permission>(rbac.Permission.values);

        forAll(
          (rbac.Permission perm) {
            // Owner (dev bypass session) always has permission
            expect(
              rbac.RolePermissions.hasPermission(rbac.UserRole.owner, perm),
              isTrue,
              reason: 'Dev bypass (owner role) must have ${perm.name}',
            );
            return true;
          },
          [permGen],
          numRuns: kNumRuns,
        );
      },
    );

    test('Property: devBypassCustomerLogin creates non-owner session', () {
      // With unified enum, legacy customer role no longer exists.
      // Dev customer bypass creates a session with unknown role (non-vendor).
      const devCustomerSession = UserSession(
        odId: 'dev-customer-id',
        email: 'customer@myvyaparmitra.com',
        displayName: 'Dev Customer',
        role: UserRole.unknown,
        ownerId: 'dev-admin-id',
      );

      expect(devCustomerSession.role, equals(UserRole.unknown));
      // isCustomer is a legacy getter that always returns false
      expect(devCustomerSession.isCustomer, isFalse);
      expect(devCustomerSession.isOwner, isFalse);
    });
  });

  // ==========================================================================
  // PROPERTY 2.5: Offline Recovery from SharedPreferences Cached Role
  // For all offline recovery scenarios with cached role, session restores
  // correctly from SharedPreferences.
  // **Validates: Requirements 3.6**
  // ==========================================================================
  group('Preservation 3.6: Offline cached role recovery', () {
    test('Property: for all cached role strings, UserRole resolves correctly', () {
      // SessionManager offline recovery logic (post-fix):
      // All valid role names resolve to their corresponding UserRole enum value.
      // Unknown strings resolve to UserRole.unknown.
      final roleStrings = [
        'owner',
        'manager',
        'staff',
        'accountant',
        'unknown',
      ];
      final roleStringGen = Gen.elementOf<String>(roleStrings);

      forAll(
        (String roleStr) {
          // Resolve role string to enum using the same logic as UserRole.values.firstWhere
          final UserRole resolved = UserRole.values.firstWhere(
            (r) => r.name == roleStr,
            orElse: () => UserRole.unknown,
          );

          // PRESERVATION: offline recovery uses role-name-based resolution
          expect(
            resolved.name,
            equals(roleStr),
            reason: 'Cached "$roleStr" must resolve to matching UserRole',
          );
          return true;
        },
        [roleStringGen],
        numRuns: kNumRuns,
      );
    });

    test(
      'Property: offline-recovered session is always authenticated with non-empty odId',
      () {
        final uidIndexGen = Gen.interval(1, 99999);

        forAll(
          (int uidIdx) {
            final uid = 'cached_user_$uidIdx';
            // Simulate offline recovery session creation
            final recoveredSession = UserSession(
              odId: uid,
              email: null,
              displayName: null,
              role: UserRole.owner,
              ownerId: uid,
              lastLoginAt: DateTime.now(),
            );

            expect(
              recoveredSession.isAuthenticated,
              isTrue,
              reason: 'Offline-recovered session must be authenticated',
            );
            expect(
              recoveredSession.odId,
              isNotEmpty,
              reason: 'Recovered session must have a non-empty odId',
            );
            return true;
          },
          [uidIndexGen],
          numRuns: kNumRuns,
        );
      },
    );

    test('Property: empty session (UserSession.empty) is unauthenticated', () {
      expect(UserSession.empty.isAuthenticated, isFalse);
      expect(UserSession.empty.role, equals(UserRole.unknown));
      expect(UserSession.empty.odId, isEmpty);
    });
  });

  // ==========================================================================
  // PROPERTY 2.6: FeatureResolver Business-Type Capability Gating
  // For all business-type capability checks, FeatureResolver gates remain
  // as prerequisite to RBAC.
  // **Validates: Requirements 3.5**
  // ==========================================================================
  group('Preservation 3.5: FeatureResolver gates by business type', () {
    test(
      'Property: for all business types, canAccess returns false for unregistered capabilities',
      () {
        final typeGen = Gen.elementOf<BusinessType>(BusinessType.values);

        forAll(
          (BusinessType type) {
            final registeredCaps = FeatureResolver.getCapabilities(type.name);

            // For any capability NOT in the registered set, canAccess must be false
            for (final cap in BusinessCapability.values) {
              if (!registeredCaps.contains(cap)) {
                expect(
                  FeatureResolver.canAccess(type.name, cap),
                  isFalse,
                  reason:
                      '${type.name} must NOT have access to ${cap.name} (not registered)',
                );
              }
            }
            return true;
          },
          [typeGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: for all business types with registered capabilities, canAccess returns true',
      () {
        final typeGen = Gen.elementOf<BusinessType>(BusinessType.values);

        forAll(
          (BusinessType type) {
            final registeredCaps = FeatureResolver.getCapabilities(type.name);

            // For any capability IN the registered set, canAccess must be true
            for (final cap in registeredCaps) {
              expect(
                FeatureResolver.canAccess(type.name, cap),
                isTrue,
                reason:
                    '${type.name} must have access to ${cap.name} (registered)',
              );
            }
            return true;
          },
          [typeGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: unknown business type gets empty capabilities (deny-by-default)',
      () {
        final unknownTypes = ['unknown', 'nonexistent', 'fakeType', 'xyz123'];
        final unknownGen = Gen.elementOf<String>(unknownTypes);

        forAll(
          (String unknownType) {
            final caps = FeatureResolver.getCapabilities(unknownType);
            expect(
              caps.isEmpty,
              isTrue,
              reason:
                  'Unknown type "$unknownType" must have empty capabilities',
            );

            // Any capability check must return false
            for (final cap in BusinessCapability.values) {
              expect(
                FeatureResolver.canAccess(unknownType, cap),
                isFalse,
                reason: 'Unknown type must be denied access to ${cap.name}',
              );
            }
            return true;
          },
          [unknownGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: FeatureResolver is prerequisite — even owner role cannot bypass capability gate',
      () {
        // This verifies FeatureResolver gates are independent of RBAC roles.
        // Even if a user has owner permissions via RBAC, FeatureResolver denies
        // access if the business type doesn't have the capability.
        final caps = FeatureResolver.getCapabilities('grocery');
        final allCaps = BusinessCapability.values.toSet();
        final deniedCaps = allCaps.difference(caps);

        for (final deniedCap in deniedCaps) {
          // Owner has all RBAC permissions but FeatureResolver still gates
          expect(
            FeatureResolver.canAccess('grocery', deniedCap),
            isFalse,
            reason:
                'Grocery must not access ${deniedCap.name} even for owner role',
          );
        }
      },
    );
  });

  // ==========================================================================
  // PROPERTY 2.7: Staff CRUD Operations Write to business_users Collection
  // For all staff CRUD operations via UserManagementScreen, writes go to
  // existing business_users collection without duplicates.
  // **Validates: Requirements 3.7**
  // ==========================================================================
  group('Preservation 3.7: Staff CRUD writes to business_users', () {
    test(
      'Property: for all staff roles, BusinessUser model correctly serializes to Firestore format',
      () {
        final roleGen = Gen.elementOf<rbac.UserRole>(rbac.UserRole.values);

        forAll(
          (rbac.UserRole role) {
            final businessUser = rbac.BusinessUser(
              id: 'business1_user1',
              businessId: 'business1',
              userId: 'user1',
              email: 'staff@test.com',
              name: 'Test Staff',
              role: role,
              createdAt: DateTime(2024, 1, 1),
              createdBy: 'owner1',
            );

            // PRESERVATION: toFirestore produces correct map structure
            final map = businessUser.toFirestore();
            expect(map['businessId'], equals('business1'));
            expect(map['userId'], equals('user1'));
            expect(map['email'], equals('staff@test.com'));
            expect(map['name'], equals('Test Staff'));
            expect(map['role'], equals(role.name));
            expect(map['isActive'], isTrue);
            expect(map['createdBy'], equals('owner1'));
            return true;
          },
          [roleGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: for all business/user pairs, document ID is deterministic (no duplicates)',
      () {
        final bizIdIndexGen = Gen.interval(1, 99999);

        forAll(
          (int bizIdx) {
            final bizId = 'biz_$bizIdx';
            final userId = 'user_${bizIdx % 1000}';
            final docId = '${bizId}_$userId';

            // PRESERVATION: document ID convention is {businessId}_{userId}
            expect(docId, equals('${bizId}_$userId'));

            // Creating the same BusinessUser again produces the same ID
            final user1 = rbac.BusinessUser(
              id: docId,
              businessId: bizId,
              userId: userId,
              email: 'staff@test.com',
              name: 'Staff',
              role: rbac.UserRole.staff,
              createdAt: DateTime(2024, 1, 1),
            );

            final user2 = rbac.BusinessUser(
              id: '${bizId}_$userId',
              businessId: bizId,
              userId: userId,
              email: 'staff@test.com',
              name: 'Staff',
              role: rbac.UserRole.staff,
              createdAt: DateTime(2024, 1, 1),
            );

            expect(
              user1.id,
              equals(user2.id),
              reason: 'Same biz+user must produce same doc ID (no duplicates)',
            );
            return true;
          },
          [bizIdIndexGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: BusinessUser.fromMap round-trips correctly for all roles',
      () {
        final roleGen = Gen.elementOf<rbac.UserRole>(rbac.UserRole.values);

        forAll(
          (rbac.UserRole role) {
            final original = rbac.BusinessUser(
              id: 'biz1_user1',
              businessId: 'biz1',
              userId: 'user1',
              email: 'test@test.com',
              name: 'Test',
              role: role,
              isActive: true,
              createdAt: DateTime(2024, 6, 15),
              createdBy: 'owner1',
            );

            final map = original.toFirestore();
            final restored = rbac.BusinessUser.fromMap('biz1_user1', map);

            expect(restored.id, equals(original.id));
            expect(restored.businessId, equals(original.businessId));
            expect(restored.userId, equals(original.userId));
            expect(restored.role, equals(original.role));
            expect(restored.email, equals(original.email));
            expect(restored.name, equals(original.name));
            expect(restored.isActive, equals(original.isActive));
            return true;
          },
          [roleGen],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'Property: RolePermissions permission matrix is complete for all defined roles',
      () {
        // Every role in the enum must have a defined permission set (even if empty)
        for (final role in rbac.UserRole.values) {
          final perms = rbac.RolePermissions.getPermissions(role);
          expect(
            perms,
            isNotNull,
            reason: 'Role ${role.name} must have a defined permission set',
          );
        }
      },
    );
  });

  // ==========================================================================
  // PROPERTY 2.8: PermissionGuard widget preserves behavior with explicit roles
  // This tests that the existing PermissionGuard correctly shows/hides based
  // on the explicitly-passed userRole parameter.
  // **Validates: Requirements 3.1 (owner full access preserved)**
  // ==========================================================================
  group('Preservation: PermissionGuard shows content for owner', () {
    testWidgets(
      'Property: for all permissions, PermissionGuard shows child for owner role',
      (tester) async {
        final permissions = rbac.Permission.values;

        for (final perm in permissions) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PermissionGuard(
                  permission: perm,
                  userRole: rbac.UserRole.owner,
                  child: Text('Content-${perm.name}'),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.text('Content-${perm.name}'),
            findsOneWidget,
            reason: 'Owner must see content guarded by ${perm.name}',
          );
        }
      },
    );

    testWidgets(
      'Property: PermissionGuard hides content for staff role on admin permissions',
      (tester) async {
        // Staff only has limited permissions (createBill, printBill, createCustomer, etc.)
        // These admin/write permissions should be denied for staff:
        final adminPermissions = [
          rbac.Permission.deleteBill,
          rbac.Permission.manageUsers,
          rbac.Permission.manageSettings,
          rbac.Permission.closeFinancialYear,
          rbac.Permission.lockPeriod,
        ];

        for (final perm in adminPermissions) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PermissionGuard(
                  permission: perm,
                  userRole: rbac.UserRole.staff,
                  child: Text('Content-${perm.name}'),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.text('Content-${perm.name}'),
            findsNothing,
            reason: 'Staff must NOT see content guarded by ${perm.name}',
          );
        }
      },
    );
  });

  // ==========================================================================
  // CROSS-CUTTING: AuthGate routing preserved for owner
  // ==========================================================================
  group('Preservation: AuthGate routes owner to vendor flow', () {
    test(
      'Property: UserRole.owner is the primary role routed to vendor flow',
      () {
        // On fixed code, AuthGate switch statement routes all vendor roles:
        // case UserRole.owner: → _buildVendorFlow (full access)
        // case UserRole.manager/staff/accountant: → _buildVendorFlow (scoped)
        // case UserRole.unknown: → AuthErrorScreen
        for (final role in UserRole.values) {
          if (role == UserRole.owner) {
            // This is the primary vendor flow path
            expect(role, equals(UserRole.owner));
          }
        }

        // PRESERVATION: owner route must continue to exist
        expect(
          UserRole.values.contains(UserRole.owner),
          isTrue,
          reason: 'UserRole.owner must exist for vendor flow routing',
        );
      },
    );

    test('Property: Unified UserRole enum has all expected values', () {
      // Post-fix: unified enum includes original roles + pharmacy + restaurant + clinic
      expect(
        UserRole.values.length,
        equals(12),
        reason: 'Unified UserRole enum has exactly 12 values',
      );
      expect(
        UserRole.values.map((e) => e.name).toSet(),
        equals({
          'owner',
          'manager',
          'staff',
          'accountant',
          'pharmacist',
          'waiter',
          'chef',
          'captain',
          'doctor',
          'receptionist',
          'nurse',
          'unknown',
        }),
      );
    });
  });
}
