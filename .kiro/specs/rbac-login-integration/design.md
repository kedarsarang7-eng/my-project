# RBAC-Login Integration Bugfix Design

## Overview

The DukanX application has a fully-implemented but disconnected RBAC module. The `RoleManagementService`, `RolePermissions`, `RbacManager`, `AccessControlService`, and `PermissionGuard` widgets all exist with correct permission matrices, but the authentication workflow (`AuthGate` → `SessionManager`) never loads staff role data after login. The `sidebarSectionsProvider` only checks `session.isOwner` for the `permission` field, and `PermissionGuard` widgets require a `userRole` parameter that is never populated from the session's actual staff role. This fix integrates the existing RBAC infrastructure into the login flow so that staff roles are loaded post-authentication, navigation is filtered by granular permissions, and guards evaluate the permission matrix.

## Glossary

- **Bug_Condition (C)**: A staff user authenticates but their assigned role from `business_users` collection is never loaded into the session, causing the RBAC system to be bypassed
- **Property (P)**: After authentication, the session SHALL contain the user's staff role and all downstream permission checks SHALL consult `RolePermissions.hasPermission()` against that role
- **Preservation**: Owner accounts with no staff assignment, customer-only mode, business-type capability gates, offline cached-role recovery, and dev bypass must all continue working unchanged
- **SessionManager**: The `ChangeNotifier` in `lib/core/session/session_manager.dart` that manages `UserSession` state — currently only resolves `UserRole.owner|customer|patient|unknown`
- **AuthGate**: The single entry point widget in `lib/core/auth/auth_gate.dart` — currently routes only `UserRole.owner` to the vendor flow and rejects all other roles
- **RoleManagementService**: The service in `lib/services/role_management_service.dart` that queries `business_users` Firestore collection for `BusinessUser` records containing granular `UserRole` (owner, accountant, manager, cashier, staff, viewer)
- **RolePermissions**: The static permission matrix class mapping `UserRole` → `Set<Permission>` — fully defined but never consulted during navigation or session setup
- **PermissionGuard**: Widget in `lib/widgets/security/permission_guard.dart` that takes a `userRole` parameter and checks `RolePermissions.hasPermission()` — functional but callers must manually pass the correct role
- **sidebarSectionsProvider**: Riverpod provider in `lib/widgets/desktop/sidebar_configuration.dart` that filters menu items — currently only checks `session.isOwner` for the `permission` field

## Bug Details

### Bug Condition

The bug manifests when any user who is not the primary business owner authenticates. The `SessionManager._loadUserSession()` resolves users to one of four high-level `UserRole` values (`owner`, `customer`, `patient`, `unknown`) by checking `users/{uid}`, `owners/{uid}`, and `customers/{uid}` collections — but never queries `business_users` for the staff-level role assignment. The `AuthGate` then only accepts `UserRole.owner` for the vendor flow, and the sidebar provider only checks `session.isOwner`.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type AuthenticationAttempt (userId, credentials, businessId)
  OUTPUT: boolean
  
  LET user = authenticateCredentials(input.credentials)
  LET businessUser = RoleManagementService.getBusinessUser(input.businessId, user.uid)
  
  RETURN businessUser != null
         AND businessUser.role IN [manager, accountant, cashier, staff, viewer]
         AND sessionManager.currentSession does NOT contain businessUser.role
         AND permissionChecks use session.isOwner instead of RolePermissions.hasPermission(businessUser.role, *)
END FUNCTION
```

### Examples

- **Manager Login**: User "Amit" authenticates → `users/{uid}.role = 'owner'` (legacy) → `business_users/{bizId}_{uid}.role = 'manager'` exists → Session gets `UserRole.owner` → sees full dashboard including Settings, User Management, Delete operations → **Expected**: should see manager-level items only (no manageUsers, no deleteBill, no financial year close)
- **Cashier Login**: User "Priya" authenticates → same fallback to `UserRole.owner` → sees all reports, export, supplier management → **Expected**: should only see POS/billing and basic stock view
- **Multi-business User**: User "Raj" is manager at Business-A and cashier at Business-B → no role picker shown → defaults to owner → **Expected**: role picker after auth, then session scoped to selected business+role
- **Role Change Propagation**: Owner changes Amit from manager to cashier in UserManagementScreen → Amit's running session still shows manager-level access until app restart → **Expected**: session updates in real-time via Firestore listener

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Primary business owner accounts (no `business_users` record or role = owner) must continue to receive full `UserRole.owner` access with all permissions, routing through AuthGate → LicenseGuard → ProfessionalOwnerDashboard exactly as today
- Customer-Only mode (`AppMode.customerOnly`) must continue to block vendor login and restrict to customer screens
- Business-type capability gating via `FeatureResolver.canAccess()` must remain as a prerequisite to RBAC checks — if a capability is disabled for a business type, no role can access it
- Vendor onboarding screen must still show when no business type is selected
- Dev bypass flag (`devBypassAuth = true`) must continue to skip all auth/RBAC checks
- Offline session recovery from SharedPreferences cached role must continue to work
- Existing staff CRUD operations in UserManagementScreen must continue writing to the same `business_users` Firestore collection without creating duplicate tables or APIs

**Scope:**
All inputs that do NOT involve staff-role users (i.e., primary owners, customers, patients, unauthenticated users) should be completely unaffected by this fix. This includes:
- Owner authentication and session loading
- Customer authentication and shop switching
- All existing Firestore write operations for staff CRUD
- AppMode toggling (customerOnly ↔ normal)
- Business type selection onboarding

## Hypothesized Root Cause

Based on the code analysis, the root causes are:

1. **SessionManager resolves only 4 high-level roles**: `_loadUserSession()` checks `users/{uid}`, `owners/{uid}`, `customers/{uid}` and maps to `UserRole.owner|customer|patient|unknown`. It never queries `business_users` collection via `RoleManagementService.getBusinessUser()` to get the granular staff role (manager, accountant, cashier, staff, viewer).

2. **UserRole enum mismatch**: `session_manager.dart` defines `enum UserRole { owner, customer, patient, unknown }` while `role_management_service.dart` defines `enum UserRole { owner, accountant, manager, cashier, staff, viewer }`. These are two separate enums in different files — the session never maps to the granular one.

3. **AuthGate only routes `UserRole.owner`**: The switch statement in `AuthGate.build()` only handles `case UserRole.owner:` for the vendor flow. All other roles (including legitimate staff) hit the error screen with "Unauthorized. This application is for Vendor/Owner use only."

4. **Sidebar permission check is stub-level**: In `sidebarSectionsProvider`, the permission filter only checks `if (item.permission == 'owner' && !session.isOwner) return false` — it never consults `RolePermissions.hasPermission()` with the user's actual staff role.

5. **PermissionGuard requires explicit `userRole` parameter**: The widget is functional but requires callers to manually pass `userRole`. Without a centralized provider exposing the current user's staff role, callers cannot easily get the correct value.

6. **No real-time role change listener**: When an owner updates a staff member's role via UserManagementScreen, there is no Firestore `snapshots()` listener on the affected user's `business_users` document to propagate the change to their active session.

## Correctness Properties

Property 1: Bug Condition - Staff Role Loading After Authentication

_For any_ authentication attempt where a user has a valid `business_users` record with a staff role (manager, accountant, cashier, staff, viewer) for the active business, the fixed SessionManager SHALL load that staff role into the session, and all downstream permission checks (sidebar filtering, PermissionGuard, action-level RBAC) SHALL evaluate `RolePermissions.hasPermission(staffRole, permission)` returning the correct boolean.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**

Property 2: Preservation - Owner and Non-Staff Authentication Behavior

_For any_ authentication attempt where the user is the primary business owner (no staff role override in `business_users`, or role = owner), OR is a customer/patient, OR is unauthenticated, the fixed code SHALL produce exactly the same session state, navigation routing, and permission results as the original code, preserving full owner access, customer-only mode, business-type capability gates, offline recovery, and dev bypass.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `lib/core/session/session_manager.dart`

**Changes**:
1. **Unify UserRole enum**: Either extend the existing 4-value enum to include `manager`, `accountant`, `cashier`, `staff`, `viewer` OR import and use the `UserRole` from `role_management_service.dart` as the single source of truth across the app.
2. **Add staff role resolution in `_loadUserSession()`**: After determining the user is an owner-type (vendor), query `RoleManagementService.getBusinessUser(businessId, uid)` to check for a staff role assignment. If one exists, override the session role with the granular staff role.
3. **Add `staffPermissions` field to `UserSession`**: Store the loaded `Set<Permission>` from `RolePermissions.getPermissions(role)` so downstream widgets can access it without re-querying.
4. **Add Firestore listener for role changes**: Subscribe to `business_users/{businessId}_{userId}` snapshots to detect real-time role updates and refresh the session accordingly.
5. **Add role/business picker state**: When multiple `business_users` records exist for a user, store the list and expose a method to select the active one.

**File**: `lib/core/auth/auth_gate.dart`

**Changes**:
1. **Accept staff roles in vendor flow**: Expand the `switch (role)` to route `manager`, `accountant`, `cashier`, `staff`, `viewer` through `_buildVendorFlow()` instead of showing the error screen.
2. **Add role-selection step**: If the user has multiple business/role assignments, show a role picker screen before proceeding to the dashboard.

**File**: `lib/widgets/desktop/sidebar_configuration.dart`

**Changes**:
1. **Replace `session.isOwner` check with `RolePermissions.hasPermission()`**: Map the `item.permission` string field to the `Permission` enum and evaluate against the session's actual staff role.
2. **Expose a `currentUserRoleProvider`**: Create a Riverpod provider that resolves the user's current staff-level `UserRole` from the session, so sidebar and other consumers can watch it.

**File**: `lib/widgets/security/permission_guard.dart`

**Changes**:
1. **Add a convenience constructor or provider integration**: Create a `PermissionGuardConnected` widget (or modify existing) that auto-reads the current user role from the session/provider instead of requiring an explicit `userRole` parameter.

**File**: `lib/services/role_management_service.dart`

**Changes**:
1. **Add `getBusinessUsersForUser(userId)` method**: Query all `business_users` where `userId == uid` to support the multi-business role picker.
2. **Add `watchBusinessUser(businessId, userId)` stream**: Return a Firestore `snapshots()` stream for real-time role change detection.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write unit tests that mock Firestore responses with `business_users` records for staff-role users and observe that `SessionManager._loadUserSession()` ignores the staff role, and that `sidebarSectionsProvider` grants full access regardless of role. Run these tests on the UNFIXED code to observe failures and understand the root cause.

**Test Cases**:
1. **Staff Role Not Loaded Test**: Mock a user with `business_users` record as `manager` → assert `session.currentSession.role` does NOT contain manager permissions (will confirm bug on unfixed code)
2. **AuthGate Rejects Staff Test**: Set session role to anything other than `owner` → assert AuthGate shows error screen instead of vendor flow (will confirm bug on unfixed code)
3. **Sidebar Ignores Granular Role Test**: Set session with a `cashier` role → assert sidebar still shows all items including `manageUsers` (will confirm bug on unfixed code)
4. **PermissionGuard Not Connected Test**: Render a PermissionGuard with `Permission.deleteBill` for a cashier → assert it requires manual `userRole` param and without it defaults incorrectly (will confirm bug on unfixed code)

**Expected Counterexamples**:
- `SessionManager` always resolves to `UserRole.owner` for any authenticated vendor-side user regardless of `business_users` record
- `AuthGate` shows "Unauthorized" for non-owner roles even when they are legitimate staff
- Sidebar permission filter is a no-op for granular roles because it only checks `isOwner`

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  LET session = SessionManager_fixed.loadUserSession(input.user)
  LET businessUser = RoleManagementService.getBusinessUser(input.businessId, input.userId)
  
  ASSERT session.staffRole == businessUser.role
  ASSERT session.permissions == RolePermissions.getPermissions(businessUser.role)
  
  FOR ALL menuItem IN sidebarItems DO
    IF menuItem.permission != null THEN
      ASSERT menuItem.visible == RolePermissions.hasPermission(businessUser.role, menuItem.permission)
    END IF
  END FOR
  
  FOR ALL action IN [createBill, deleteBill, manageUsers, viewReports, ...] DO
    ASSERT canPerform(action) == RolePermissions.hasPermission(businessUser.role, action)
  END FOR
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  LET sessionOriginal = SessionManager_original.loadUserSession(input.user)
  LET sessionFixed = SessionManager_fixed.loadUserSession(input.user)
  
  ASSERT sessionOriginal.role == sessionFixed.role
  ASSERT sessionOriginal.isOwner == sessionFixed.isOwner
  ASSERT sessionOriginal.isAuthenticated == sessionFixed.isAuthenticated
  
  // AuthGate routing must be identical
  ASSERT AuthGate_original.route(sessionOriginal) == AuthGate_fixed.route(sessionFixed)
  
  // Sidebar items must be identical
  ASSERT sidebarItems_original(sessionOriginal) == sidebarItems_fixed(sessionFixed)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many combinations of user states (owner, customer, patient, unauthenticated) and business configurations
- It catches edge cases like owner users who also have a `business_users` record with role = owner (should remain unchanged)
- It provides strong guarantees that non-staff authentication paths are completely unaffected

**Test Plan**: Observe behavior on UNFIXED code first for owner logins, customer logins, and offline recovery, then write property-based tests capturing that exact behavior.

**Test Cases**:
1. **Owner Authentication Preservation**: Verify primary owner login → full access → LicenseGuard → ProfessionalOwnerDashboard routing is identical before and after fix
2. **Customer-Only Mode Preservation**: Verify `AppMode.customerOnly` continues to block vendor login and restrict to customer screens
3. **Business-Type Capability Preservation**: Verify `FeatureResolver.canAccess()` still gates features before RBAC is consulted
4. **Offline Recovery Preservation**: Verify cached role from SharedPreferences still restores session correctly
5. **Dev Bypass Preservation**: Verify `devBypassLogin()` still grants full owner access without any RBAC checks

### Unit Tests

- Test `SessionManager._loadUserSession()` correctly queries `business_users` and populates staff role
- Test `AuthGate` routes staff roles (manager, cashier, etc.) to vendor flow instead of error screen
- Test `sidebarSectionsProvider` filters items using `RolePermissions.hasPermission()` for each staff role
- Test `PermissionGuard` correctly hides/shows UI elements based on connected session role
- Test role/business picker shows when user has multiple `business_users` records
- Test real-time role change listener updates session when owner modifies staff role

### Property-Based Tests

- Generate random `UserRole` values and `Permission` sets → verify `RolePermissions.hasPermission()` is always consulted for staff roles and sidebar filtering matches the permission matrix
- Generate random user configurations (owner with no staff record, owner with staff record as owner, staff with single role, staff with multiple roles) → verify session resolution picks the correct role
- Generate random sidebar configurations with various `permission` fields → verify items are correctly shown/hidden for each role according to the RolePermissions matrix

### Integration Tests

- Test full login flow: authenticate → role loaded → sidebar filtered → screen access correct for each staff role
- Test role change flow: owner updates staff role → affected user's session updates → sidebar re-filters in real-time
- Test multi-business flow: authenticate → picker shown → select business → correct role and permissions loaded
- Test offline → online transition: cached staff role used → reconnect → role verified against Firestore
