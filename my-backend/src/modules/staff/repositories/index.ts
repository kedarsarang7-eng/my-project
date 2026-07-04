// ============================================================================
// Staff Module — Repositories (barrel)
// ============================================================================
// Each repository owns an exclusive SK prefix declared in ../manifest.ts and
// scopes every read/write to PK = TENANT#{tenantId}#BIZ#{businessId}.
//
// Payroll/statutory DynamoDB key builders (task 1.4, AD-1) are provisioned in
// ./payroll.keys.ts — PAYRUN#, PAYSLIP#, SALCOMP#, STATRATE#, AUDIT# builders
// that reuse businessPK from dynamodb/keys.ts (tenant + business scoped).
// ============================================================================

export * from './payroll.keys';

// Task 3.2 — Base repository and core entity repositories.
export * from './base.repository';
export * from './employee.repository';
export * from './department.repository';
export * from './designation.repository';

// Task 2.4 — StaffFeatureConfig repository (business-scoped persistence).
export * from './staff-feature-config.repository';

// Task 6.1 — Leave repositories (LeaveType / LeaveRequest / LeaveBalance).
export * from './leave.repository';

// Task 5.1 — AttendanceEvent repository (create-only, append-only immutable).
export * from './attendance-event.repository';

// Task 7.1 — Task repository (CRUD + soft delete, dependency-scoped).
export * from './task.repository';

// Task 5.3 — Shift and Roster repositories (shift definitions + roster building).
export * from './shift.repository';
export * from './roster.repository';
