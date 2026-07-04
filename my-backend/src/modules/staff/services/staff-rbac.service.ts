// ============================================================================
// Staff Module — RBAC Extension Service (Task 11.1)
// ============================================================================
// Extends the existing RBAC model (permission-matrix.ts) with FINE-GRAINED
// permission descriptors where Phase 0 confirmed genuine gaps:
//   • Field-level access (PII fields, salary fields)
//   • Button/action-level control (approve, reject, export, delete)
//   • Report/dashboard/export/delete/approval-level permissions
//
// AD-3: Extend RBAC, do NOT replace. The existing `checkPermission(feature,
// role, plan)` remains the first gate; this service adds the second (action-
// level) gate that handlers call AFTER the feature check passes. Both are
// **fail-closed** — unknown actions are denied. Enforcement is backend-only
// regardless of any client gating (Req 8.2).
//
// Requirements: 8.1 (extend RBAC to field/action/button/API/report/dashboard/
// export/delete/approval levels), 8.2 (backend enforcement regardless of client).
// ============================================================================

import { UserRole } from '../../../types/tenant.types';
import { AuthError } from '../../../utils/errors';
import { logger } from '../../../utils/logger';

// ── Permission Descriptor Types ─────────────────────────────────────────────

/**
 * Granularity levels added by the staff module (Phase 0 gap closure).
 * Each level represents a distinct authorization surface that the existing
 * screen/feature/API/role model did NOT previously cover.
 */
export type StaffPermissionLevel =
    | 'field'       // Field-level (PII, salary, contact details)
    | 'action'      // Action-level (approve_leave, reject_leave, lock_payroll)
    | 'button'      // Button/UI-action (export_btn, delete_btn, bulk_assign_btn)
    | 'report'      // Report access (attendance_report, payroll_report)
    | 'dashboard'   // Dashboard widget access (payroll_dashboard, hr_dashboard)
    | 'export'      // Data export (export_employees_csv, export_payslips_pdf)
    | 'delete'      // Destructive operations (delete_employee, delete_task)
    | 'approval';   // Approval workflows (approve_leave, approve_payroll)

/**
 * A staff permission descriptor: the combination of a level, a resource name,
 * and a minimum role required (inherits the plan check from the parent feature).
 */
export interface StaffPermissionDescriptor {
    /** The granularity level this permission controls. */
    level: StaffPermissionLevel;
    /** Unique permission key (e.g. 'view_salary', 'approve_leave'). */
    key: string;
    /** Human-readable description for audit/debugging. */
    description: string;
    /** Roles that are allowed this permission (inclusive of higher roles). */
    allowedRoles: UserRole[];
}

// ── Staff Permission Matrix (fine-grained) ──────────────────────────────────

/**
 * The staff fine-grained permission matrix. This extends the coarse-grained
 * `PERMISSION_MATRIX` (feature-level) with action/field/export/delete/approval
 * checks the Phase 0 audit confirmed are missing.
 *
 * The map is keyed by a stable permission key. Fail-closed: if a key is not
 * found, access is DENIED.
 */
export const STAFF_PERMISSION_DESCRIPTORS: Record<string, StaffPermissionDescriptor> = {
    // ── Field-level permissions (Req 8.1 — PII and salary) ──────────────────
    view_pii_aadhaar: {
        level: 'field',
        key: 'view_pii_aadhaar',
        description: 'Unmask Aadhaar field (full value)',
        allowedRoles: [UserRole.OWNER],
    },
    view_pii_pan: {
        level: 'field',
        key: 'view_pii_pan',
        description: 'Unmask PAN field (full value)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    view_pii_passport: {
        level: 'field',
        key: 'view_pii_passport',
        description: 'Unmask Passport field (full value)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    view_pii_driving_licence: {
        level: 'field',
        key: 'view_pii_driving_licence',
        description: 'Unmask Driving Licence field (full value)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    view_pii_bank_account: {
        level: 'field',
        key: 'view_pii_bank_account',
        description: 'Unmask bank account details',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },
    view_pii_upi: {
        level: 'field',
        key: 'view_pii_upi',
        description: 'Unmask UPI details',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },
    view_salary: {
        level: 'field',
        key: 'view_salary',
        description: 'View salary/compensation details',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },
    edit_salary: {
        level: 'field',
        key: 'edit_salary',
        description: 'Edit salary/compensation values',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },

    // ── Action-level permissions ────────────────────────────────────────────
    approve_leave: {
        level: 'approval',
        key: 'approve_leave',
        description: 'Approve or reject leave requests',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    approve_payroll: {
        level: 'approval',
        key: 'approve_payroll',
        description: 'Approve/lock a payroll run for processing',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    run_payroll: {
        level: 'action',
        key: 'run_payroll',
        description: 'Initiate a payroll run (requires online)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },
    manage_shifts: {
        level: 'action',
        key: 'manage_shifts',
        description: 'Create/edit/delete shift definitions and rosters',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    manage_leave_types: {
        level: 'action',
        key: 'manage_leave_types',
        description: 'Create/edit/delete leave type definitions',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    assign_tasks: {
        level: 'action',
        key: 'assign_tasks',
        description: 'Create and assign tasks to staff',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    manage_commission_rules: {
        level: 'action',
        key: 'manage_commission_rules',
        description: 'Create/edit/delete commission rules',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },
    manage_statutory_rates: {
        level: 'action',
        key: 'manage_statutory_rates',
        description: 'Update statutory rate tables (PF/ESI/PT/TDS)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    manage_employees: {
        level: 'action',
        key: 'manage_employees',
        description: 'Create/update/deactivate employee records',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    manage_departments: {
        level: 'action',
        key: 'manage_departments',
        description: 'Create/update/deactivate departments and designations',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },

    // ── Button-level permissions ────────────────────────────────────────────
    bulk_assign_tasks: {
        level: 'button',
        key: 'bulk_assign_tasks',
        description: 'Bulk-assign tasks to multiple employees',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    bulk_attendance_mark: {
        level: 'button',
        key: 'bulk_attendance_mark',
        description: 'Mark attendance in bulk for multiple employees',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },

    // ── Report-level permissions ────────────────────────────────────────────
    view_attendance_report: {
        level: 'report',
        key: 'view_attendance_report',
        description: 'Access attendance reports and analytics',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    view_payroll_report: {
        level: 'report',
        key: 'view_payroll_report',
        description: 'Access payroll reports and summaries',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },
    view_leave_report: {
        level: 'report',
        key: 'view_leave_report',
        description: 'Access leave reports and patterns',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    view_performance_report: {
        level: 'report',
        key: 'view_performance_report',
        description: 'Access performance scores and rankings',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    view_task_report: {
        level: 'report',
        key: 'view_task_report',
        description: 'Access task analytics and productivity reports',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },

    // ── Dashboard-level permissions ─────────────────────────────────────────
    view_hr_dashboard: {
        level: 'dashboard',
        key: 'view_hr_dashboard',
        description: 'Access the HR overview dashboard',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    view_payroll_dashboard: {
        level: 'dashboard',
        key: 'view_payroll_dashboard',
        description: 'Access the payroll dashboard with totals',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },

    // ── Export-level permissions ─────────────────────────────────────────────
    export_employees: {
        level: 'export',
        key: 'export_employees',
        description: 'Export employee data (CSV/Excel/PDF)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    export_attendance: {
        level: 'export',
        key: 'export_attendance',
        description: 'Export attendance records (CSV/Excel/PDF)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    export_payslips: {
        level: 'export',
        key: 'export_payslips',
        description: 'Export payslips (PDF/Excel)',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    },
    export_leave_data: {
        level: 'export',
        key: 'export_leave_data',
        description: 'Export leave balances and history',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    export_performance: {
        level: 'export',
        key: 'export_performance',
        description: 'Export performance scores and reports',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },

    // ── Delete-level permissions ────────────────────────────────────────────
    delete_employee: {
        level: 'delete',
        key: 'delete_employee',
        description: 'Permanently deactivate/delete an employee record',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    delete_department: {
        level: 'delete',
        key: 'delete_department',
        description: 'Delete a department',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    delete_task: {
        level: 'delete',
        key: 'delete_task',
        description: 'Delete a task',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
    delete_leave_type: {
        level: 'delete',
        key: 'delete_leave_type',
        description: 'Delete a leave type definition',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },
    delete_commission_rule: {
        level: 'delete',
        key: 'delete_commission_rule',
        description: 'Delete a commission rule',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN],
    },

    // ── Approval-level permissions ──────────────────────────────────────────
    approve_attendance_correction: {
        level: 'approval',
        key: 'approve_attendance_correction',
        description: 'Approve an attendance correction request',
        allowedRoles: [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    },
};

// ── Role Hierarchy (reuse from permission-matrix concept) ───────────────────

const ROLE_HIERARCHY: Record<string, number> = {
    [UserRole.VIEWER]: 0,
    [UserRole.STAFF]: 1,
    [UserRole.PUMPBOY]: 1,
    [UserRole.CASHIER]: 2,
    [UserRole.ACCOUNTANT]: 3,
    [UserRole.CHARTERED_ACCOUNTANT]: 3,
    [UserRole.MANAGER]: 4,
    [UserRole.ADMIN]: 5,
    [UserRole.OWNER]: 6,
    [UserRole.SUPER_ADMIN]: 99,
};

// ── Core Enforcement Function ───────────────────────────────────────────────

export interface StaffPermissionCheck {
    allowed: boolean;
    reason?: string;
}

/**
 * Check whether a user role is authorized for a specific staff action.
 *
 * FAIL-CLOSED: If the permission key is not found in the descriptor map, access
 * is DENIED. This guarantees that newly added actions are denied by default
 * until explicitly authorized — matching the platform's existing fail-closed
 * philosophy (Req 8.2).
 *
 * SUPER_ADMIN bypasses all checks (consistent with platform behavior).
 * OWNER/ADMIN bypass checks for actions within the staff module (consistent
 * with the platform's "Owner/Admin = full plan access" rule).
 *
 * @param permissionKey - The fine-grained permission key (e.g. 'approve_leave')
 * @param userRole - The caller's UserRole from the authenticated session
 * @returns { allowed, reason? }
 */
export function checkStaffPermission(
    permissionKey: string,
    userRole: UserRole,
): StaffPermissionCheck {
    // Super Admin bypasses everything (consistent with checkPermission)
    if (userRole === UserRole.SUPER_ADMIN) {
        return { allowed: true };
    }

    const descriptor = STAFF_PERMISSION_DESCRIPTORS[permissionKey];
    if (!descriptor) {
        // Fail-closed: unknown permission key → DENY
        return {
            allowed: false,
            reason: `Unknown staff permission: ${permissionKey}`,
        };
    }

    // Check if the caller's role is in the allowed list
    if (descriptor.allowedRoles.includes(userRole)) {
        return { allowed: true };
    }

    // Check via hierarchy — if caller's role level >= highest allowed role level
    // This handles cases where higher roles implicitly have access
    const callerLevel = ROLE_HIERARCHY[userRole] ?? -1;
    const maxAllowedLevel = Math.max(
        ...descriptor.allowedRoles.map((r) => ROLE_HIERARCHY[r] ?? 0),
    );
    if (callerLevel > maxAllowedLevel) {
        return { allowed: true };
    }

    return {
        allowed: false,
        reason: `Role '${userRole}' is not authorized for '${permissionKey}' (${descriptor.description}). Required: ${descriptor.allowedRoles.join(', ')}.`,
    };
}

/**
 * Enforce a staff permission check — throws AuthError(403) on denial.
 *
 * This is the primary enforcement call that handlers use. It wraps
 * `checkStaffPermission` and throws on failure, making the deny path explicit
 * and impossible to accidentally skip (Req 8.2: backend enforces regardless of
 * client gating).
 *
 * @param permissionKey - The fine-grained permission key
 * @param userRole - The caller's UserRole
 * @param context - Optional context for logging (userId, path, etc.)
 * @throws AuthError(403) if the check fails
 */
export function enforceStaffPermission(
    permissionKey: string,
    userRole: UserRole,
    context?: { userId?: string; path?: string; businessId?: string },
): void {
    const result = checkStaffPermission(permissionKey, userRole);
    if (!result.allowed) {
        logger.warn('STAFF_RBAC: Permission denied', {
            permissionKey,
            userRole,
            reason: result.reason,
            ...context,
        });
        throw new AuthError(
            result.reason ?? `Access denied for action '${permissionKey}'`,
            403,
        );
    }
}

/**
 * Check multiple permissions at once (AND logic — all must pass).
 * Useful for compound actions that require multiple permission checks.
 */
export function checkStaffPermissions(
    permissionKeys: string[],
    userRole: UserRole,
): StaffPermissionCheck {
    for (const key of permissionKeys) {
        const result = checkStaffPermission(key, userRole);
        if (!result.allowed) {
            return result;
        }
    }
    return { allowed: true };
}

/**
 * Enforce multiple permissions (AND logic) — throws on first denial.
 */
export function enforceStaffPermissions(
    permissionKeys: string[],
    userRole: UserRole,
    context?: { userId?: string; path?: string; businessId?: string },
): void {
    for (const key of permissionKeys) {
        enforceStaffPermission(key, userRole, context);
    }
}

// ── Query utilities (for frontend feature-flag sync) ────────────────────────

/**
 * Returns all permission keys that a given role is authorized to use.
 * Used by the GET /staff/context endpoint to send the client a list of
 * permitted actions for UI gating (Req 8.2 note: client gating is cosmetic
 * only; backend ALWAYS re-checks).
 */
export function getPermittedActions(userRole: UserRole): string[] {
    if (userRole === UserRole.SUPER_ADMIN) {
        return Object.keys(STAFF_PERMISSION_DESCRIPTORS);
    }

    const callerLevel = ROLE_HIERARCHY[userRole] ?? -1;

    return Object.entries(STAFF_PERMISSION_DESCRIPTORS)
        .filter(([_, descriptor]) => {
            if (descriptor.allowedRoles.includes(userRole)) return true;
            const maxAllowedLevel = Math.max(
                ...descriptor.allowedRoles.map((r) => ROLE_HIERARCHY[r] ?? 0),
            );
            return callerLevel > maxAllowedLevel;
        })
        .map(([key]) => key);
}

/**
 * Returns all permission descriptors grouped by level.
 * Useful for admin UIs that display the permission matrix.
 */
export function getDescriptorsByLevel(): Record<StaffPermissionLevel, StaffPermissionDescriptor[]> {
    const grouped: Record<StaffPermissionLevel, StaffPermissionDescriptor[]> = {
        field: [],
        action: [],
        button: [],
        report: [],
        dashboard: [],
        export: [],
        delete: [],
        approval: [],
    };

    for (const descriptor of Object.values(STAFF_PERMISSION_DESCRIPTORS)) {
        grouped[descriptor.level].push(descriptor);
    }

    return grouped;
}
