// ============================================================================
// STAFF MODULE MANIFEST — Universal Staff Management
// ============================================================================
// A single, configuration-driven module that adapts to EVERY DukanX business
// type purely through Staff_Feature_Config (BusinessType × SubscriptionTier).
// There are NO per-industry code forks — differences are expressed as config.
//
// Mirrors src/modules/_template/manifest.ts. Registered in the module registry
// in a later task; this task only scaffolds the manifest + directory skeleton.
//
// See ./README.md for the Phase 0 discovery / codebase-audit artifact.
// ============================================================================

import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const staffManifest: ModuleManifest = {
    // ── Identity ────────────────────────────────────────────────────────────
    id: 'staff',
    version: '1.0.0',
    displayName: 'Staff Management',
    status: 'beta',

    // ── Activation ──────────────────────────────────────────────────────────
    // Universal module — activates for ALL business types. Capability-level
    // gating (which sub-features are visible) is refined by Staff_Feature_Config.
    businessTypes: [
        BusinessType.GROCERY,
        BusinessType.PHARMACY,
        BusinessType.RESTAURANT,
        BusinessType.CLOTHING,
        BusinessType.ELECTRONICS,
        BusinessType.MOBILE_SHOP,
        BusinessType.COMPUTER_SHOP,
        BusinessType.HARDWARE,
        BusinessType.SERVICE,
        BusinessType.WHOLESALE,
        BusinessType.PETROL_PUMP,
        BusinessType.VEGETABLES_BROKER,
        BusinessType.CLINIC,
        BusinessType.BOOK_STORE,
        BusinessType.JEWELLERY,
        BusinessType.AUTO_PARTS,
        BusinessType.DECORATION_CATERING,
        BusinessType.SCHOOL_ERP,
        BusinessType.OTHER,
    ],
    requiredPlan: PlanTier.BASIC,   // capability-level gating refines this per feature
    minRole: UserRole.MANAGER,

    // ── Feature Keys ──────────────────────────────────────────────────────────
    // STAFF_* capability keys registered in config/plan-feature-registry.ts
    // (task 2.4). Each maps 1:1 to a StaffModule; Staff_Feature_Config refines
    // which of these are exposed per BusinessType × SubscriptionTier (AD-2).
    featureKeys: [
        FeatureKey.STAFF_CORE,
        FeatureKey.STAFF_ATTENDANCE,
        FeatureKey.STAFF_LEAVE,
        FeatureKey.STAFF_TASKS,
        FeatureKey.STAFF_REPORTS,
        FeatureKey.STAFF_PAYROLL,
        FeatureKey.STAFF_PERFORMANCE,
        FeatureKey.STAFF_COMMISSION,
    ],

    // ── Infrastructure ────────────────────────────────────────────────────────
    lambdaFunctions: [
        'staffMain',      // employee/department/designation CRUD, attendance, leave, task
        'staffPayroll',   // payroll run, payslip, statutory (DynamoDB transactions)
        'staffReports',   // reporting / search / dashboards
    ],
    wsChannelPrefix: 'staff:',
    apiPrefix: '/staff',

    db: {
        // SK prefixes this module owns EXCLUSIVELY. Every staff record uses
        // PK = TENANT#{tenantId}#BIZ#{businessId} (business-scoped partition).
        // Key builders + per-entity access-pattern docs live in ./keys.ts.
        // NOTE: 'AUDIT#' and 'SHIFT#' textually overlap prefixes in
        // dynamodb/keys.ts (generic audit / petrol-pump fuel shift). Resolved in
        // task 1.2 (see ./keys.ts + README OQ-1/OQ-1b): AUDIT# is separated at the
        // PK level (business vs tenant partition); SHIFT# co-exists in the business
        // partition and is disambiguated by the item's `entity_type` (STAFF_SHIFT)
        // plus a STAFF_-namespaced GSI1 entity type. Staff payroll prefixes
        // (PAYRUN#/PAYSLIP#/SALCOMP#/STATRATE#) get their key builders in task 1.4.
        skPrefixes: [
            'EMP#',        // Employee
            'DEPT#',       // Department
            'DESIG#',      // Designation
            'ATT#',        // Attendance_Event (append-only, immutable)
            'SHIFT#',      // Shift definition
            'ROSTER#',     // Roster
            'LVTYPE#',     // LeaveType
            'LVREQ#',      // LeaveRequest
            'LVBAL#',      // LeaveBalance
            'TASK#',       // Task
            'COMMRULE#',   // CommissionRule
            'PERFSCORE#',  // PerformanceScore
            'PAYRUN#',     // PayrollRun (single-writer lock via conditional PutItem)
            'PAYSLIP#',    // Payslip (written atomically with its run)
            'SALCOMP#',    // SalaryComponent
            'STATRATE#',   // StatutoryRate (effective-dated PF/ESI/PT/TDS)
            'AUDIT#',      // Audit_Log (append-only)
            'NOTIFLOG#',   // Notification_Log (append-only)
            'STAFFCFG#',   // Staff_Feature_Config (STAFFCFG#{businessType}#{tier})
        ],
        gsiIndexes: ['GSI1'],
        requiresWriteSharding: false,
    },

    // ── EventBridge ─────────────────────────────────────────────────────────
    eventPatterns: [
        {
            source: 'dukanx.staff',
            detailTypes: [
                'employee.created',
                'attendance.recorded',
                'leave.requested',
                'leave.decided',
                'task.assigned',
                'payroll.processed',
            ],
        },
    ],

    // ── Rate Limiting ─────────────────────────────────────────────────────────
    rateLimits: {
        [PlanTier.BASIC]: 100,
        [PlanTier.PRO]: 400,
        [PlanTier.PREMIUM]: 1200,
        [PlanTier.ENTERPRISE]: 5000,
    },

    // ── Dependencies ──────────────────────────────────────────────────────────
    dependsOn: ['billing'],

    // ── Future: AI / Marketplace ──────────────────────────────────────────────
    aiToolsEnabled: false,
    marketplaceEligible: false,
};
