# Bugfix Requirements Document

## Introduction

The DukanX application has a fully-implemented RBAC module (RbacManager, RolePermissions, RBACResolver, AccessControlService, PermissionGuard widgets) but this module is NOT properly integrated with the authentication/login workflow. After a user authenticates with their credentials, there is no mechanism to select or switch their assigned staff role (owner, manager, cashier, accountant, salesperson, etc.), and the granular permission system is not consulted to filter navigation, screen access, feature visibility, or action-level controls. The result is that all authenticated owner-role users see the same full-access interface regardless of their actual staff assignment, and staff sub-roles have no login path at all.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a staff user (assigned role: manager, cashier, accountant, salesperson, stockKeeper, delivery) authenticates with valid credentials THEN the system does not present a role selection step and defaults to the owner-level session, denying granular role-based access

1.2 WHEN a user with multiple role assignments across businesses authenticates THEN the system does not allow selecting which role/business context to operate under and picks a single session without role disambiguation

1.3 WHEN a user is authenticated and the AuthGate routes them to the dashboard THEN the system does NOT load permissions from the existing RolePermissions/RbacManager/RBACResolver based on the user's assigned staff role, resulting in either full owner access or complete denial

1.4 WHEN the sidebar/navigation menu is rendered for an authenticated user THEN the system only checks `session.isOwner` for the permission field on SidebarMenuItem, ignoring the granular permission matrix defined in RolePermissions and RBACResolver

1.5 WHEN a user navigates to a screen protected by VendorRoleGuard THEN the guard only checks `session.isOwner` and does NOT evaluate the `requiredPermission` parameter against the user's role-based permission set

1.6 WHEN a user attempts CRUD actions (create, read, update, delete) on entities (bills, customers, inventory, reports) THEN the system does NOT enforce action-level RBAC rules from the existing RbacManager/AccessControlService, allowing unauthorized operations

1.7 WHEN an owner changes a staff member's role via User Management Screen THEN the affected user's active session does NOT reflect the role change immediately — they must log out and back in (or the change never takes effect within the running app)

### Expected Behavior (Correct)

2.1 WHEN a staff user authenticates with valid credentials THEN the system SHALL load their assigned role(s) from the existing `business_users` collection and present a role-selection step if multiple roles exist, or auto-select the single assigned role, populating the session with the corresponding permission set from RolePermissions

2.2 WHEN a user with multiple role assignments authenticates THEN the system SHALL present a role/business picker allowing them to choose which role context to operate under, and SHALL populate the session permissions accordingly

2.3 WHEN a user is authenticated and the AuthGate routes them to the dashboard THEN the system SHALL query the user's assigned role via RoleManagementService.getBusinessUser(), load all permissions from the existing RolePermissions class, and store them in the SessionManager and AuthStoreState so that all downstream guards and providers can evaluate access

2.4 WHEN the sidebar/navigation menu is rendered THEN the system SHALL filter menu items by consulting RBACResolver.canAccess() or RolePermissions.hasPermission() against the user's current session role, hiding items the user lacks permission to access

2.5 WHEN a user navigates to a screen protected by VendorRoleGuard THEN the guard SHALL evaluate the `requiredPermission` parameter against the user's role-based permission set (via RolePermissions or AccessControlService) and deny access with an appropriate message if the permission is not granted

2.6 WHEN a user attempts CRUD actions on entities THEN the system SHALL enforce action-level permissions by consulting the existing RbacManager.hasPermission() or RBACResolver.canAccess() before allowing the operation, and SHALL show an access-denied response if the permission is not granted

2.7 WHEN an owner changes a staff member's role via User Management Screen THEN the system SHALL propagate the role change to the affected user's active session in real-time (via Firestore listener or WebSocket event) so that navigation, menus, and permissions update immediately without requiring logout or app restart

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a user authenticates as the business owner (primary owner account) with no staff role assignment THEN the system SHALL CONTINUE TO grant full owner access with all permissions, routing through AuthGate → LicenseGuard → ProfessionalOwnerDashboard exactly as it does today

3.2 WHEN the app is in Customer-Only mode (locked via QR/deep link) THEN the system SHALL CONTINUE TO restrict access to customer-only screens and deny vendor login, preserving the existing AppMode.customerOnly behavior

3.3 WHEN a user has not selected a business type after first login THEN the system SHALL CONTINUE TO show the VendorOnboardingScreen for business type selection before proceeding to the dashboard

3.4 WHEN the dev bypass flag (`devBypassAuth = true`) is enabled in ProtectedRoute THEN the system SHALL CONTINUE TO skip all auth/RBAC checks for development purposes

3.5 WHEN the existing business-type capability system (FeatureResolver) determines a capability is not available for a business type THEN the system SHALL CONTINUE TO deny access regardless of user role, maintaining the business-type → capability gate as a prerequisite to the RBAC check

3.6 WHEN a user is offline and cached role data exists in SharedPreferences THEN the system SHALL CONTINUE TO use the cached role for session recovery, maintaining offline access with the last-known role

3.7 WHEN the existing staff CRUD operations (add staff, edit staff, deactivate staff) are performed via UserManagementScreen THEN the system SHALL CONTINUE TO write staff data to the existing Firestore collections and models without creating duplicate tables or APIs
