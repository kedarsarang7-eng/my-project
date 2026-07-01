// ============================================================================
// UNIFIED USER ROLE ENUM
// ============================================================================
// Single source of truth for all user roles across the DukanX application.
//
// Used by: SessionManager, RoleManagementService, AuthGate, PermissionGuard,
//          AccessControlService, and all downstream consumers.
// ============================================================================

/// User role in the DukanX system.
///
/// - [owner]: Full access — business owner with all permissions
/// - [manager]: Operational access — limited financial operations
/// - [staff]: General staff access — view and limited billing
/// - [accountant]: Financial access — no user management
/// - [pharmacist]: Pharmacy dispensing staff — least-privilege access scoped to
///   dispensing, prescription capture, batch/expiry view, and compliance
///   register entry. Additive value for the pharmacy vertical; non-pharmacist
///   role behaviour is unchanged.
/// - [waiter]: Restaurant front-of-house — create orders, view tables
/// - [chef]: Restaurant kitchen staff — view KDS, update order status
/// - [captain]: Restaurant floor captain — all waiter permissions + assign
///   tables + view reports
/// - [doctor]: Clinic — full clinical access (diagnosis, private notes,
///   prescriptions, vitals). Can view and treat patients.
/// - [receptionist]: Clinic front-desk — book appointments, register patients,
///   manage queue. CANNOT access diagnosis or private clinical notes.
/// - [nurse]: Clinic clinical support — vitals capture, patient prep,
///   medication administration. Cannot write diagnosis/private notes.
/// - [unknown]: Unauthenticated / unresolved state (NEVER after signup)
enum UserRole {
  owner,
  manager,
  staff,
  accountant,
  pharmacist,
  waiter,
  chef,
  captain,
  doctor,
  receptionist,
  nurse,
  unknown,
}
