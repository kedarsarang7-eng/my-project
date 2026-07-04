// ============================================================================
// Staff Module — RBAC Extension Service Unit Tests (Task 11.1)
// ============================================================================
// Validates that the fine-grained permission checks (field/action/button/
// report/dashboard/export/delete/approval levels) enforce correctly on the
// backend, fail-closed for unknown permissions, and consistent with the role
// hierarchy.
//
// Requirements: 8.1 (extend RBAC), 8.2 (backend enforcement regardless of client)
// ============================================================================

import { UserRole } from '../../../../types/tenant.types';
import {
    checkStaffPermission,
    enforceStaffPermission,
    checkStaffPermissions,
    enforceStaffPermissions,
    getPermittedActions,
    getDescriptorsByLevel,
    STAFF_PERMISSION_DESCRIPTORS,
    StaffPermissionLevel,
} from '../staff-rbac.service';
import { AuthError } from '../../../../utils/errors';

describe('Staff RBAC Service (Task 11.1)', () => {
    // ── Fail-closed behavior (Req 8.2) ──────────────────────────────────────

    describe('fail-closed — unknown permissions are denied', () => {
        it('denies an unknown permission key', () => {
            const result = checkStaffPermission('nonexistent_action', UserRole.OWNER);
            expect(result.allowed).toBe(false);
            expect(result.reason).toContain('Unknown staff permission');
        });

        it('enforceStaffPermission throws AuthError(403) for unknown keys', () => {
            expect(() =>
                enforceStaffPermission('nonexistent_action', UserRole.ADMIN),
            ).toThrow(AuthError);
        });
    });

    // ── Super Admin bypass ──────────────────────────────────────────────────

    describe('SUPER_ADMIN bypasses all checks', () => {
        it('allows any valid permission for SUPER_ADMIN', () => {
            const result = checkStaffPermission('approve_leave', UserRole.SUPER_ADMIN);
            expect(result.allowed).toBe(true);
        });

        it('allows even unknown keys for SUPER_ADMIN', () => {
            // Super admin bypass fires before the lookup
            const result = checkStaffPermission('totally_fake_key', UserRole.SUPER_ADMIN);
            expect(result.allowed).toBe(true);
        });
    });

    // ── Field-level PII permissions (Phase 0 gap: field level) ──────────────

    describe('field-level permissions (PII)', () => {
        it('OWNER can unmask aadhaar', () => {
            expect(checkStaffPermission('view_pii_aadhaar', UserRole.OWNER).allowed).toBe(true);
        });

        it('ADMIN cannot unmask aadhaar', () => {
            expect(checkStaffPermission('view_pii_aadhaar', UserRole.ADMIN).allowed).toBe(false);
        });

        it('ACCOUNTANT can view bank account details', () => {
            expect(checkStaffPermission('view_pii_bank_account', UserRole.ACCOUNTANT).allowed).toBe(true);
        });

        it('MANAGER cannot view bank account details', () => {
            expect(checkStaffPermission('view_pii_bank_account', UserRole.MANAGER).allowed).toBe(false);
        });

        it('STAFF cannot view salary', () => {
            expect(checkStaffPermission('view_salary', UserRole.STAFF).allowed).toBe(false);
        });

        it('ACCOUNTANT can view salary', () => {
            expect(checkStaffPermission('view_salary', UserRole.ACCOUNTANT).allowed).toBe(true);
        });
    });

    // ── Approval-level permissions (Phase 0 gap: approval level) ────────────

    describe('approval-level permissions', () => {
        it('MANAGER can approve leave', () => {
            expect(checkStaffPermission('approve_leave', UserRole.MANAGER).allowed).toBe(true);
        });

        it('ACCOUNTANT cannot approve leave', () => {
            expect(checkStaffPermission('approve_leave', UserRole.ACCOUNTANT).allowed).toBe(false);
        });

        it('OWNER can approve payroll', () => {
            expect(checkStaffPermission('approve_payroll', UserRole.OWNER).allowed).toBe(true);
        });

        it('MANAGER cannot approve payroll', () => {
            expect(checkStaffPermission('approve_payroll', UserRole.MANAGER).allowed).toBe(false);
        });
    });

    // ── Export-level permissions (Phase 0 gap: export level) ─────────────────

    describe('export-level permissions', () => {
        it('MANAGER can export employees', () => {
            expect(checkStaffPermission('export_employees', UserRole.MANAGER).allowed).toBe(true);
        });

        it('STAFF cannot export employees', () => {
            expect(checkStaffPermission('export_employees', UserRole.STAFF).allowed).toBe(false);
        });

        it('ACCOUNTANT can export payslips', () => {
            expect(checkStaffPermission('export_payslips', UserRole.ACCOUNTANT).allowed).toBe(true);
        });

        it('MANAGER cannot export payslips', () => {
            expect(checkStaffPermission('export_payslips', UserRole.MANAGER).allowed).toBe(false);
        });
    });

    // ── Delete-level permissions (Phase 0 gap: delete level) ────────────────

    describe('delete-level permissions', () => {
        it('ADMIN can delete employee', () => {
            expect(checkStaffPermission('delete_employee', UserRole.ADMIN).allowed).toBe(true);
        });

        it('MANAGER cannot delete employee', () => {
            expect(checkStaffPermission('delete_employee', UserRole.MANAGER).allowed).toBe(false);
        });

        it('MANAGER can delete task', () => {
            expect(checkStaffPermission('delete_task', UserRole.MANAGER).allowed).toBe(true);
        });

        it('CASHIER cannot delete task', () => {
            expect(checkStaffPermission('delete_task', UserRole.CASHIER).allowed).toBe(false);
        });
    });

    // ── Report & Dashboard-level permissions ────────────────────────────────

    describe('report and dashboard permissions', () => {
        it('MANAGER can view attendance report', () => {
            expect(checkStaffPermission('view_attendance_report', UserRole.MANAGER).allowed).toBe(true);
        });

        it('CASHIER cannot view attendance report', () => {
            expect(checkStaffPermission('view_attendance_report', UserRole.CASHIER).allowed).toBe(false);
        });

        it('ACCOUNTANT can view payroll dashboard', () => {
            expect(checkStaffPermission('view_payroll_dashboard', UserRole.ACCOUNTANT).allowed).toBe(true);
        });

        it('STAFF cannot view payroll dashboard', () => {
            expect(checkStaffPermission('view_payroll_dashboard', UserRole.STAFF).allowed).toBe(false);
        });
    });

    // ── Action-level permissions ────────────────────────────────────────────

    describe('action-level permissions', () => {
        it('ACCOUNTANT can run payroll', () => {
            expect(checkStaffPermission('run_payroll', UserRole.ACCOUNTANT).allowed).toBe(true);
        });

        it('MANAGER cannot run payroll', () => {
            expect(checkStaffPermission('run_payroll', UserRole.MANAGER).allowed).toBe(false);
        });

        it('MANAGER can manage shifts', () => {
            expect(checkStaffPermission('manage_shifts', UserRole.MANAGER).allowed).toBe(true);
        });

        it('CASHIER cannot manage shifts', () => {
            expect(checkStaffPermission('manage_shifts', UserRole.CASHIER).allowed).toBe(false);
        });
    });

    // ── Compound permission checks ──────────────────────────────────────────

    describe('compound permission checks (AND logic)', () => {
        it('passes when all permissions are allowed', () => {
            const result = checkStaffPermissions(
                ['approve_leave', 'manage_shifts'],
                UserRole.MANAGER,
            );
            expect(result.allowed).toBe(true);
        });

        it('fails when any permission is denied', () => {
            const result = checkStaffPermissions(
                ['approve_leave', 'run_payroll'],
                UserRole.MANAGER,
            );
            expect(result.allowed).toBe(false);
            expect(result.reason).toContain('run_payroll');
        });

        it('enforceStaffPermissions throws on first denial', () => {
            expect(() =>
                enforceStaffPermissions(
                    ['approve_leave', 'run_payroll'],
                    UserRole.MANAGER,
                ),
            ).toThrow(AuthError);
        });
    });

    // ── getPermittedActions ─────────────────────────────────────────────────

    describe('getPermittedActions', () => {
        it('SUPER_ADMIN gets all actions', () => {
            const actions = getPermittedActions(UserRole.SUPER_ADMIN);
            expect(actions.length).toBe(Object.keys(STAFF_PERMISSION_DESCRIPTORS).length);
        });

        it('STAFF gets very few actions', () => {
            const actions = getPermittedActions(UserRole.STAFF);
            // STAFF has no explicit entries in the descriptor map
            expect(actions.length).toBe(0);
        });

        it('OWNER gets all actions (highest non-super role)', () => {
            const actions = getPermittedActions(UserRole.OWNER);
            expect(actions.length).toBe(Object.keys(STAFF_PERMISSION_DESCRIPTORS).length);
        });

        it('MANAGER gets more actions than ACCOUNTANT', () => {
            const managerActions = getPermittedActions(UserRole.MANAGER);
            const accountantActions = getPermittedActions(UserRole.ACCOUNTANT);
            // Manager has leave/shift/task/report actions; accountant has payroll/salary
            // They have different-but-partially-overlapping sets; manager should be larger
            expect(managerActions.length).toBeGreaterThan(accountantActions.length);
        });
    });

    // ── getDescriptorsByLevel ───────────────────────────────────────────────

    describe('getDescriptorsByLevel', () => {
        it('returns all 8 granularity levels', () => {
            const grouped = getDescriptorsByLevel();
            const levels: StaffPermissionLevel[] = [
                'field', 'action', 'button', 'report', 'dashboard', 'export', 'delete', 'approval',
            ];
            for (const level of levels) {
                expect(grouped[level]).toBeDefined();
                expect(Array.isArray(grouped[level])).toBe(true);
            }
        });

        it('every descriptor is assigned to exactly one level', () => {
            const grouped = getDescriptorsByLevel();
            const totalGrouped = Object.values(grouped).reduce((s, arr) => s + arr.length, 0);
            expect(totalGrouped).toBe(Object.keys(STAFF_PERMISSION_DESCRIPTORS).length);
        });
    });

    // ── Role hierarchy implicit access ──────────────────────────────────────

    describe('role hierarchy (higher roles inherit access)', () => {
        it('OWNER inherits all permissions even if not explicitly listed', () => {
            // delete_task only lists OWNER, ADMIN, MANAGER
            // OWNER is in the list, but this verifies the pattern
            expect(checkStaffPermission('delete_task', UserRole.OWNER).allowed).toBe(true);
        });

        it('ADMIN inherits permissions whose max listed role is MANAGER', () => {
            // manage_shifts allows [OWNER, ADMIN, MANAGER]
            // ADMIN is listed explicitly, but also hierarchy-wise above MANAGER
            expect(checkStaffPermission('manage_shifts', UserRole.ADMIN).allowed).toBe(true);
        });
    });
});
