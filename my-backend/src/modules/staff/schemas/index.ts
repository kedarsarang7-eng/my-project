// ============================================================================
// Staff Module — Schemas (barrel)
// ============================================================================
// Placeholder scaffold. Zod validation schemas are added in later tasks
// (e.g. staff.schema.ts) covering Employee, Department, Designation,
// Attendance, Shift, Roster, Leave*, Task, CommissionRule, PerformanceScore,
// and Staff_Feature_Config. All handler input is validated fail-closed.
//
// Payroll/statutory item shapes + Zod schemas (task 1.4, AD-1) are provisioned
// in ./payroll.schema.ts (DynamoDB single-table, money as integer paise).
// ============================================================================

export * from './payroll.schema';

// Task 2.4 — Staff_Feature_Config schema (BusinessType × SubscriptionTier).
export * from './staff-feature-config.schema';

// Task 5.1 — AttendanceEvent item shape + capture-input schema (append-only).
export * from './attendance.schema';

// Task 6.1 — Leave management schemas (LeaveType, LeaveRequest, LeaveBalance,
// accrual rules, leave-type request rules).
export * from './leave.schema';

// Task 5.3 — Shift and Roster schemas (shift definitions, break/late/overtime/
// geo-fence/approval rules; roster assignments).
export * from './shift.schema';

// Task 13.2 — Report export, search, and saved filter schemas.
export * from './report.schema';

