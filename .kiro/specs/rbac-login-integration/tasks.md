# Implementation Plan

## Overview

Fix the disconnected RBAC-Login integration in DukanX where the fully-implemented RBAC module (RbacManager, RolePermissions, RBACResolver, AccessControlService, PermissionGuard) is never consulted during authentication or navigation. Staff users (manager, cashier, accountant, etc.) authenticate but their assigned roles from `business_users` collection are never loaded into the session, causing the RBAC system to be entirely bypassed. Uses the bug condition methodology: explore the bug first, write preservation tests for owner/customer flows, implement the integration fix, then validate.

## Tasks

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Staff Role Not Loaded After Authentication
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the RBAC module is disconnected from the login workflow
  - **Scoped PBT Approach**: Scope the property to concrete failing cases: staff users (manager, cashier, accountant, staff, viewer) authenticating with valid business_users records
  - Test that SessionManager._loadUserSession() does NOT populate the session with the staff role from business_users collection (from Bug Condition in design: isBugCondition returns true when businessUser.role IN [manager, accountant, cashier, staff, viewer] AND sessionManager.currentSession does NOT contain businessUser.role)
  - Test that AuthGate rejects staff roles with "Unauthorized" error screen instead of routing to vendor flow
  - Test that sidebarSectionsProvider grants full owner access to staff-role users because it only checks session.isOwner
  - Test that PermissionGuard is not connected to session role and defaults incorrectly without explicit userRole parameter
  - Mock Firestore: create business_users record with role=manager for test user, authenticate, assert session.role resolves to owner (not manager) — confirming bug
  - Mock Firestore: create business_users record with role=cashier, authenticate, assert sidebar shows all items including manageUsers, deleteBill, financialYearClose — confirming unauthorized access
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists: staff roles are never loaded, AuthGate rejects them, sidebar ignores granular permissions)
  - Document counterexamples: SessionManager always resolves to UserRole.owner for vendor-side users; AuthGate shows "Unauthorized" for non-owner roles; sidebar permission filter is no-op for granular roles
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.3, 1.4, 1.5_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Owner and Non-Staff Authentication Behavior Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: Primary owner login → session.role = UserRole.owner, session.isOwner = true, full dashboard access on unfixed code
  - Observe: Customer-only mode (AppMode.customerOnly) → vendor login blocked, customer screens only on unfixed code
  - Observe: User with no business type selected → VendorOnboardingScreen shown on unfixed code
  - Observe: devBypassAuth = true → all auth/RBAC checks skipped, full owner access on unfixed code
  - Observe: Offline with cached role in SharedPreferences → session recovered with last-known role on unfixed code
  - Observe: FeatureResolver.canAccess() returns false for business type → feature denied regardless of role on unfixed code
  - Observe: Staff CRUD via UserManagementScreen → writes to business_users Firestore collection on unfixed code
  - Write property-based test: for all primary owner authentication attempts (no staff role override or business_users.role = owner), session resolves to UserRole.owner with full permissions
  - Write property-based test: for all AppMode.customerOnly states, vendor login is blocked and only customer screens are accessible
  - Write property-based test: for all users without selected business type, VendorOnboardingScreen is shown before dashboard
  - Write property-based test: for all dev bypass enabled states, auth/RBAC checks are completely skipped
  - Write property-based test: for all offline recovery scenarios with cached role, session restores correctly from SharedPreferences
  - Write property-based test: for all business-type capability checks, FeatureResolver gates remain as prerequisite to RBAC
  - Write property-based test: for all staff CRUD operations via UserManagementScreen, writes go to existing business_users collection without duplicates
  - Verify all tests pass on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 3. Fix for RBAC-Login Integration

  - [x] 3.1 Unify UserRole enum across the application
    - Merge the 4-value enum in session_manager.dart (owner, customer, patient, unknown) with the 6-value enum in role_management_service.dart (owner, accountant, manager, cashier, staff, viewer) into a single canonical UserRole enum
    - Create unified enum at a shared location (e.g., lib/core/models/user_role.dart) with all values: owner, manager, accountant, cashier, staff, viewer, customer, patient, unknown
    - Update all imports across session_manager.dart, role_management_service.dart, auth_gate.dart, and related files
    - _Bug_Condition: isBugCondition(input) where session uses 4-value enum that cannot represent staff roles_
    - _Expected_Behavior: Single UserRole enum used across all auth and RBAC modules_
    - _Preservation: Owner, customer, patient, unknown values remain valid and behave identically_
    - _Requirements: 2.1, 2.3, 3.1_

  - [x] 3.2 Add staff role resolution to SessionManager._loadUserSession()
    - After determining user is vendor/owner type, query RoleManagementService.getBusinessUser(businessId, uid) for staff role assignment in business_users collection
    - If business_users record exists with role != owner, set session.staffRole to the granular staff role
    - If business_users record has role = owner OR no record exists, maintain existing owner behavior unchanged
    - Add staffPermissions field to UserSession storing Set<Permission> from RolePermissions.getPermissions(role)
    - Store loaded permissions in SessionManager and AuthStoreState for downstream access
    - _Bug_Condition: isBugCondition(input) where _loadUserSession() never queries business_users for staff role_
    - _Expected_Behavior: session.staffRole == businessUser.role AND session.permissions == RolePermissions.getPermissions(businessUser.role)_
    - _Preservation: Owner accounts with no business_users record or role=owner continue to get full UserRole.owner access_
    - _Requirements: 2.1, 2.3, 3.1, 3.6_

  - [x] 3.3 Add role/business picker for multi-role users
    - Add getBusinessUsersForUser(userId) method to RoleManagementService querying all business_users where userId == uid
    - When multiple business_users records exist, store list in session state and expose selection method
    - Create RolePickerScreen widget shown after authentication when multiple roles/businesses available
    - Auto-select single role if only one business_users record exists
    - Integrate picker into AuthGate flow between authentication and dashboard routing
    - _Bug_Condition: isBugCondition(input) where user with multiple role assignments gets no disambiguation_
    - _Expected_Behavior: Role/business picker presented when multiple assignments exist; session scoped to selected business+role_
    - _Preservation: Users with single role (including owners) bypass picker automatically_
    - _Requirements: 2.2, 3.1_

  - [x] 3.4 Update AuthGate to accept staff roles in vendor flow
    - Expand switch(role) in AuthGate.build() to route manager, accountant, cashier, staff, viewer through _buildVendorFlow()
    - Maintain existing routing for owner (full access), customer (customer flow), patient (patient flow), unknown (error)
    - Insert role-selection step before vendor flow when user has multiple assignments
    - _Bug_Condition: isBugCondition(input) where AuthGate only handles case UserRole.owner for vendor flow_
    - _Expected_Behavior: All staff roles route to vendor flow with appropriate permission scoping_
    - _Preservation: Owner routing → LicenseGuard → ProfessionalOwnerDashboard unchanged; customer/patient flows unchanged_
    - _Requirements: 2.1, 2.3, 3.1, 3.2_

  - [x] 3.5 Replace sidebar permission check with RolePermissions.hasPermission()
    - In sidebarSectionsProvider, replace stub `if (item.permission == 'owner' && !session.isOwner) return false` with proper permission evaluation
    - Map item.permission string field to the Permission enum
    - Evaluate RolePermissions.hasPermission(session.staffRole, permission) for each menu item
    - Create currentUserRoleProvider (Riverpod) exposing user's current staff-level UserRole from session
    - Ensure owner accounts still see all items (RolePermissions grants all permissions to owner role)
    - _Bug_Condition: isBugCondition(input) where sidebar only checks session.isOwner ignoring granular permission matrix_
    - _Expected_Behavior: menuItem.visible == RolePermissions.hasPermission(businessUser.role, menuItem.permission)_
    - _Preservation: Owner sees all menu items; FeatureResolver capability gate still applied before RBAC_
    - _Requirements: 2.4, 3.1, 3.5_

  - [x] 3.6 Connect PermissionGuard to session role provider
    - Create PermissionGuardConnected widget that auto-reads current user role from currentUserRoleProvider
    - Maintain backward compatibility with existing PermissionGuard usage that passes userRole explicitly
    - Ensure guard evaluates RolePermissions.hasPermission(role, requiredPermission) and shows access-denied when not granted
    - _Bug_Condition: isBugCondition(input) where PermissionGuard requires manual userRole param callers cannot easily provide_
    - _Expected_Behavior: PermissionGuard auto-reads role from session provider; denies with appropriate message_
    - _Preservation: Existing explicit-userRole usages continue to work_
    - _Requirements: 2.5, 2.6_

  - [x] 3.7 Add action-level RBAC enforcement for CRUD operations
    - Before allowing create, read, update, delete on entities (bills, customers, inventory, reports), consult RbacManager.hasPermission()
    - Show access-denied response when permission not granted for the attempted action
    - Integrate with existing service layer to intercept operations before Firestore writes
    - _Bug_Condition: isBugCondition(input) where CRUD actions bypass RbacManager/AccessControlService entirely_
    - _Expected_Behavior: canPerform(action) == RolePermissions.hasPermission(businessUser.role, action)_
    - _Preservation: Owner retains all CRUD permissions; existing Firestore write patterns unchanged_
    - _Requirements: 2.6, 3.1, 3.7_

  - [x] 3.8 Add real-time role change listener
    - Add watchBusinessUser(businessId, userId) stream to RoleManagementService returning Firestore snapshots()
    - Subscribe in SessionManager after role is loaded
    - On role change detected, refresh session permissions and notify listeners (ChangeNotifier)
    - Ensure navigation, menus, and PermissionGuard rebuild with updated permissions
    - _Bug_Condition: isBugCondition(input) where role change by owner does not propagate to affected user's active session_
    - _Expected_Behavior: Role change propagates in real-time; session updates without logout/restart_
    - _Preservation: Offline cached role still used when offline; listener reconnects when back online_
    - _Requirements: 2.7, 3.6_

  - [x] 3.9 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Staff Role Loaded and Permissions Enforced
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes expected behavior: staff roles loaded into session, AuthGate routes staff to vendor flow, sidebar filters by granular permissions, PermissionGuard connected to session
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed — staff roles are loaded, permissions enforced)
    - _Requirements: 2.1, 2.3, 2.4, 2.5_

  - [x] 3.10 Verify preservation tests still pass
    - **Property 2: Preservation** - Owner and Non-Staff Behavior Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions — owner auth, customer-only mode, business-type gates, offline recovery, dev bypass all unchanged)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint - Ensure all tests pass
  - Run full test suite: `flutter test`
  - Verify all property-based tests (bug condition + preservation) pass
  - Verify no regressions in existing test suites
  - Confirm staff role authentication flow works end-to-end for all roles (manager, accountant, cashier, staff, viewer)
  - Confirm owner authentication flow is unchanged
  - Confirm sidebar filtering is correct per role-permission matrix
  - Confirm real-time role change propagation works
  - Run `flutter analyze` to ensure no new issues
  - Ensure all tests pass, ask the user if questions arise.

## Task Dependency Graph

```json
{
  "waves": [
    { "tasks": ["1"] },
    { "tasks": ["2"] },
    { "tasks": ["3"] },
    { "tasks": ["4"] }
  ]
}
```

## Notes

- Tasks 1 and 2 MUST be completed before any implementation (task 3)
- Task 3 sub-tasks (3.1–3.8) should be implemented in order due to dependencies: unified enum first, then session loading, then downstream consumers
- Task 3.9 and 3.10 verify the fix against the same tests written in tasks 1 and 2
- Task 4 is the final checkpoint ensuring the full suite passes
- The unified UserRole enum (3.1) is prerequisite for all other implementation tasks
- SessionManager staff role resolution (3.2) must precede AuthGate (3.4), sidebar (3.5), and PermissionGuard (3.6) changes
- The role/business picker (3.3) can be developed in parallel with sidebar/guard changes after 3.2 is complete
- Real-time listener (3.8) is independent of UI-level changes and can be developed last
- Property-based testing is recommended for preservation (task 2) because it generates many combinations of owner/customer/patient states and business configurations
