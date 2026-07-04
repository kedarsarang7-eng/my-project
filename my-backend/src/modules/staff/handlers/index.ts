// ============================================================================
// Staff Module — Handlers (barrel)
// ============================================================================
// Lambda handlers for the staff module:
//   - staff.ts              → staff context echo (tenant scoping proof)
//   - tenant-scope.ts       → shared multi-tenancy isolation helpers reused by
//                             every staff handler (task 2.1)
//   - http.ts              → shared request-parsing utilities
//   - employee.handler.ts  → employee CRUD with PII encryption/masking (task 3.2)
//   - department.handler.ts → department CRUD (task 3.2)
//   - designation.handler.ts → designation CRUD (task 3.2)
//   - payroll.ts            → payroll run, payslip, statutory (DynamoDB transactions)
//   - reports.ts            → reporting / search / dashboards
//
// Each handler runs behind `authorizedHandler`, resolves TenantContext via
// `resolveStaffTenantScope` (BusinessID from the authenticated session only),
// validates ownership with `assertStaffResourceScope`, validates input with a
// Zod schema, and returns the standard response envelope.
// ============================================================================

export * from './tenant-scope';
export * from './staff';
export * from './employee.handler';
export * from './department.handler';
export * from './designation.handler';
export * from './leave';
export * from './task';

// Task 6.1 — Leave management handlers (types, balances, request validation).
export * from './leave';

// Task 13.2 — Report export, global search, and saved filter handlers.
export * from './reports';

// Task 13.1 — Reporting, dashboards & insights (query-backed, rule-based).
export * from './reports';
