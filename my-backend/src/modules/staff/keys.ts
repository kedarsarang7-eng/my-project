// ============================================================================
// STAFF MODULE — DynamoDB Key Builders (Task 1.2)
// ============================================================================
// Access-pattern-first key design for the Universal Staff Management module.
//
// SECURITY / ISOLATION INVARIANT
// ------------------------------
// EVERY staff entity is stored under the business-scoped partition:
//     PK = TENANT#{tenantId}#BIZ#{businessId}
// built ONLY via the shared `businessPK()` builder from `dynamodb/keys.ts`,
// which validates each segment and REJECTS the '#' character to prevent key
// injection. BusinessID is therefore always the leading scope component of the
// partition (Req 1.5, 11.1). No staff record can be addressed outside the
// caller's business partition.
//
// We deliberately REUSE the platform primitives (`businessPK`, `gsi1PK`,
// `gsi1SK`, `EntityKeys`) rather than re-declaring PK logic here — this keeps a
// single source of truth for tenant scoping while letting the staff module own
// its SK prefixes (declared in `manifest.ts`).
//
// SCOPE OF THIS FILE (Task 1.2): the non-payroll staff entities — Employee,
// Department, Designation, AttendanceEvent, Shift, Roster, LeaveType,
// LeaveRequest, LeaveBalance, Task, CommissionRule, PerformanceScore, AuditLog,
// NotificationLog, StaffFeatureConfig.
// The money-critical payroll/statutory key builders (PAYRUN#, PAYSLIP#,
// SALCOMP#, STATRATE#, SalaryChangeAudit) are provisioned in Task 1.4.
//
// ── SK PREFIX OVERLAP BOUNDARY (resolves README OQ-1) ───────────────────────
// Two staff prefixes textually overlap prefixes already present in
// `dynamodb/keys.ts`:
//   • AUDIT#  — generic append-only audit (`AUDIT_SK_PREFIX`, `auditSK`)
//   • SHIFT#  — petrol-pump *fuel* shift (`SHIFT_SK_PREFIX`, `buildShiftKeys`)
// Resolution (accepted for this design):
//   1. PK-level separation. Generic audit uses the *tenant* partition
//      (`TENANT#{t}`); staff audit uses the *business* partition
//      (`TENANT#{t}#BIZ#{b}`), so they never share a partition. Item IDs are
//      ULID/UUID, so no item can overwrite another.
//   2. entity_type disambiguation. Petrol shift and staff shift can co-exist in
//      the same business partition, so a base-table `begins_with(SK, 'SHIFT#')`
//      or `begins_with(SK, 'AUDIT#')` query MUST additionally filter by the
//      item's `entity_type` attribute (see STAFF_ENTITY_TYPE below).
//   3. GSI1 namespacing. To avoid the petrol-pump GSI1 entity-type collision
//      (petrol shift lists under GSI1PK `…#SHIFT`), every staff entity lists on
//      GSI1 under a `STAFF_`-namespaced entity type (e.g. `STAFF_SHIFT`,
//      `STAFF_AUDIT`). Staff date-ordered listings therefore never mix with any
//      other module's records.
// This keeps the manifest's declared prefixes intact while guaranteeing correct,
// non-colliding reads.
// ============================================================================

import {
    businessPK,
    gsi1PK,
    gsi1SK,
    type EntityKeys,
} from '../../dynamodb/keys';

// ── SK Prefix Constants (owned by the staff manifest) ───────────────────────

export const EMP_SK_PREFIX = 'EMP#';
export const DEPT_SK_PREFIX = 'DEPT#';
export const DESIG_SK_PREFIX = 'DESIG#';
export const ATT_SK_PREFIX = 'ATT#';
export const STAFF_SHIFT_SK_PREFIX = 'SHIFT#'; // overlaps petrol shift — see boundary note
export const ROSTER_SK_PREFIX = 'ROSTER#';
export const LVTYPE_SK_PREFIX = 'LVTYPE#';
export const LVREQ_SK_PREFIX = 'LVREQ#';
export const LVBAL_SK_PREFIX = 'LVBAL#';
export const TASK_SK_PREFIX = 'TASK#';
export const COMMRULE_SK_PREFIX = 'COMMRULE#';
export const PERFSCORE_SK_PREFIX = 'PERFSCORE#';
export const STAFF_AUDIT_SK_PREFIX = 'AUDIT#'; // overlaps generic audit — see boundary note
export const NOTIFLOG_SK_PREFIX = 'NOTIFLOG#';
export const STAFFCFG_SK_PREFIX = 'STAFFCFG#';

// ── GSI1 entity-type namespace ──────────────────────────────────────────────
// Used both as the `entity_type` item attribute (base-table disambiguation) and
// as the GSI1 entity-type segment (GSI1PK = TENANT#{t}#BIZ#{b}#{entityType}).
// The `STAFF_` prefix guarantees staff records never collide with other modules
// on GSI1 (e.g. avoids the petrol-pump `SHIFT` entity type).

export const STAFF_ENTITY_TYPE = {
    EMPLOYEE: 'STAFF_EMP',
    DEPARTMENT: 'STAFF_DEPT',
    DESIGNATION: 'STAFF_DESIG',
    ATTENDANCE: 'STAFF_ATT',
    SHIFT: 'STAFF_SHIFT',
    ROSTER: 'STAFF_ROSTER',
    LEAVE_TYPE: 'STAFF_LVTYPE',
    LEAVE_REQUEST: 'STAFF_LVREQ',
    LEAVE_BALANCE: 'STAFF_LVBAL',
    TASK: 'STAFF_TASK',
    COMMISSION_RULE: 'STAFF_COMMRULE',
    PERFORMANCE_SCORE: 'STAFF_PERFSCORE',
    AUDIT: 'STAFF_AUDIT',
    NOTIFICATION_LOG: 'STAFF_NOTIFLOG',
    FEATURE_CONFIG: 'STAFF_CFG',
} as const;

export type StaffEntityType =
    (typeof STAFF_ENTITY_TYPE)[keyof typeof STAFF_ENTITY_TYPE];

// ── SK Builders ─────────────────────────────────────────────────────────────

export function employeeSK(employeeId: string): string {
    return `${EMP_SK_PREFIX}${employeeId}`;
}

export function departmentSK(departmentId: string): string {
    return `${DEPT_SK_PREFIX}${departmentId}`;
}

export function designationSK(designationId: string): string {
    return `${DESIG_SK_PREFIX}${designationId}`;
}

/** Append-only, immutable. Timestamp-first SK gives natural chronological order. */
export function attendanceEventSK(isoTimestamp: string, eventId: string): string {
    return `${ATT_SK_PREFIX}${isoTimestamp}#${eventId}`;
}

export function shiftSK(shiftId: string): string {
    return `${STAFF_SHIFT_SK_PREFIX}${shiftId}`;
}

export function rosterSK(rosterId: string): string {
    return `${ROSTER_SK_PREFIX}${rosterId}`;
}

export function leaveTypeSK(leaveTypeId: string): string {
    return `${LVTYPE_SK_PREFIX}${leaveTypeId}`;
}

export function leaveRequestSK(leaveRequestId: string): string {
    return `${LVREQ_SK_PREFIX}${leaveRequestId}`;
}

/** Composite key: one balance per (employee, leaveType) — O(1) direct lookup. */
export function leaveBalanceSK(employeeId: string, leaveTypeId: string): string {
    return `${LVBAL_SK_PREFIX}${employeeId}#${leaveTypeId}`;
}

export function taskSK(taskId: string): string {
    return `${TASK_SK_PREFIX}${taskId}`;
}

export function commissionRuleSK(ruleId: string): string {
    return `${COMMRULE_SK_PREFIX}${ruleId}`;
}

/** Composite key: one score per (employee, period) — enables per-employee listing. */
export function performanceScoreSK(employeeId: string, period: string): string {
    return `${PERFSCORE_SK_PREFIX}${employeeId}#${period}`;
}

/** Append-only, immutable. Timestamp-first for chronological audit trails. */
export function staffAuditSK(isoTimestamp: string, eventId: string): string {
    return `${STAFF_AUDIT_SK_PREFIX}${isoTimestamp}#${eventId}`;
}

/** Append-only. Timestamp-first for chronological notification history. */
export function notificationLogSK(isoTimestamp: string, id: string): string {
    return `${NOTIFLOG_SK_PREFIX}${isoTimestamp}#${id}`;
}

/** Config item keyed by BusinessType × SubscriptionTier. */
export function staffFeatureConfigSK(businessType: string, tier: string): string {
    return `${STAFFCFG_SK_PREFIX}${businessType}#${tier}`;
}

// ── Entity Key Builders ───────────────────────────────────────────────────
// Each returns { PK, SK, GSI1PK?, GSI1SK? } using the shared businessPK builder.
// The `entityType` field returned alongside is the value callers MUST persist in
// the item's `entity_type` attribute (base-table disambiguation).

export interface StaffEntityKeys extends EntityKeys {
    /** Value to store in the item's `entity_type` attribute. */
    entityType: StaffEntityType;
}

/**
 * Employee — SK: EMP#{id}
 *
 * Access patterns:
 *  - Get one employee:            GetItem(PK, EMP#{id})
 *  - List employees in business:  Query(PK, begins_with(SK, 'EMP#'))
 *  - List by hire date / recent:  Query GSI1(GSI1PK=…#STAFF_EMP, GSI1SK=date#id)
 * Writes: create, update, deactivate (soft delete via isDeleted).
 */
export function buildEmployeeKeys(
    tenantId: string,
    businessId: string,
    employeeId: string,
    isoDate: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: employeeSK(employeeId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.EMPLOYEE),
        GSI1SK: gsi1SK(isoDate, employeeId),
        entityType: STAFF_ENTITY_TYPE.EMPLOYEE,
    };
}

/**
 * Department — SK: DEPT#{id}
 *
 * Access patterns:
 *  - Get one department:            GetItem(PK, DEPT#{id})
 *  - List departments in business:  Query(PK, begins_with(SK, 'DEPT#'))
 * Writes: create, update, deactivate.
 */
export function buildDepartmentKeys(
    tenantId: string,
    businessId: string,
    departmentId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: departmentSK(departmentId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.DEPARTMENT),
        GSI1SK: departmentId,
        entityType: STAFF_ENTITY_TYPE.DEPARTMENT,
    };
}

/**
 * Designation — SK: DESIG#{id}
 *
 * Access patterns:
 *  - Get one designation:            GetItem(PK, DESIG#{id})
 *  - List designations in business:  Query(PK, begins_with(SK, 'DESIG#'))
 * Writes: create, update, deactivate.
 */
export function buildDesignationKeys(
    tenantId: string,
    businessId: string,
    designationId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: designationSK(designationId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.DESIGNATION),
        GSI1SK: designationId,
        entityType: STAFF_ENTITY_TYPE.DESIGNATION,
    };
}

/**
 * AttendanceEvent — SK: ATT#{isoTimestamp}#{eventId}  (append-only, immutable)
 *
 * Access patterns:
 *  - List events in a time window:  Query(PK, begins_with(SK, 'ATT#{datePrefix}'))
 *    (timestamp-first SK sorts chronologically; range queries are cheap)
 *  - List by employee across dates: Query GSI1(GSI1PK=…#STAFF_ATT,
 *                                              GSI1SK={employeeId}#{ts}#{eventId})
 * Writes: create only (no update/delete — corrections are new events, AD-4).
 */
export function buildAttendanceEventKeys(
    tenantId: string,
    businessId: string,
    employeeId: string,
    isoTimestamp: string,
    eventId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: attendanceEventSK(isoTimestamp, eventId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.ATTENDANCE),
        GSI1SK: `${employeeId}#${isoTimestamp}#${eventId}`,
        entityType: STAFF_ENTITY_TYPE.ATTENDANCE,
    };
}

/**
 * Shift definition — SK: SHIFT#{id}   (overlaps petrol-pump fuel shift)
 *
 * DISAMBIGUATION: a base-table `begins_with(SK, 'SHIFT#')` scan can match the
 * petrol-pump fuel-shift items too; staff repositories MUST filter by
 * `entity_type = STAFF_SHIFT`. GSI1 uses the `STAFF_SHIFT` entity type, which is
 * distinct from petrol pump's `SHIFT`, so date-ordered staff listings are clean.
 *
 * Access patterns:
 *  - Get one shift:              GetItem(PK, SHIFT#{id})
 *  - List staff shifts:          Query(PK, begins_with(SK,'SHIFT#')) + entity_type filter
 *                                or Query GSI1(GSI1PK=…#STAFF_SHIFT)
 * Writes: create, update, deactivate.
 */
export function buildShiftKeys(
    tenantId: string,
    businessId: string,
    shiftId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: shiftSK(shiftId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.SHIFT),
        GSI1SK: shiftId,
        entityType: STAFF_ENTITY_TYPE.SHIFT,
    };
}

/**
 * Roster — SK: ROSTER#{id}
 *
 * Access patterns:
 *  - Get one roster:                 GetItem(PK, ROSTER#{id})
 *  - List rosters by date/range:     Query GSI1(GSI1PK=…#STAFF_ROSTER,
 *                                               GSI1SK={date}#{id})
 * Writes: create, update.
 */
export function buildRosterKeys(
    tenantId: string,
    businessId: string,
    rosterId: string,
    date: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: rosterSK(rosterId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.ROSTER),
        GSI1SK: gsi1SK(date, rosterId),
        entityType: STAFF_ENTITY_TYPE.ROSTER,
    };
}

/**
 * LeaveType — SK: LVTYPE#{id}
 *
 * Access patterns:
 *  - Get one leave type:            GetItem(PK, LVTYPE#{id})
 *  - List leave types in business:  Query(PK, begins_with(SK, 'LVTYPE#'))
 * Writes: create, update, deactivate.
 */
export function buildLeaveTypeKeys(
    tenantId: string,
    businessId: string,
    leaveTypeId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: leaveTypeSK(leaveTypeId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.LEAVE_TYPE),
        GSI1SK: leaveTypeId,
        entityType: STAFF_ENTITY_TYPE.LEAVE_TYPE,
    };
}

/**
 * LeaveRequest — SK: LVREQ#{id}
 *
 * Access patterns:
 *  - Get one request:               GetItem(PK, LVREQ#{id})
 *  - Leave calendar (by from-date): Query GSI1(GSI1PK=…#STAFF_LVREQ,
 *                                              GSI1SK={fromDate}#{id})
 *  - By employee:                   filter/segment on {employeeId} in GSI1SK
 * Writes: create (incl. offline optimistic), approve/reject (status update).
 */
export function buildLeaveRequestKeys(
    tenantId: string,
    businessId: string,
    leaveRequestId: string,
    fromDate: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: leaveRequestSK(leaveRequestId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.LEAVE_REQUEST),
        GSI1SK: gsi1SK(fromDate, leaveRequestId),
        entityType: STAFF_ENTITY_TYPE.LEAVE_REQUEST,
    };
}

/**
 * LeaveBalance — SK: LVBAL#{employeeId}#{leaveTypeId}
 *
 * Access patterns:
 *  - Get balance for employee+type:  GetItem(PK, LVBAL#{emp}#{type})  (O(1))
 *  - List all balances of employee:  Query(PK, begins_with(SK,'LVBAL#{emp}#'))
 * Writes: upsert on approval/accrual.
 */
export function buildLeaveBalanceKeys(
    tenantId: string,
    businessId: string,
    employeeId: string,
    leaveTypeId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: leaveBalanceSK(employeeId, leaveTypeId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.LEAVE_BALANCE),
        GSI1SK: `${employeeId}#${leaveTypeId}`,
        entityType: STAFF_ENTITY_TYPE.LEAVE_BALANCE,
    };
}

/**
 * Task — SK: TASK#{id}
 *
 * Access patterns:
 *  - Get one task:                  GetItem(PK, TASK#{id})
 *  - List tasks / recent:           Query GSI1(GSI1PK=…#STAFF_TASK,
 *                                              GSI1SK={createdAt}#{id})
 *  - Analytics by assignee/status:  application-side grouping over the business
 *                                    partition query (Req 5.6)
 * Writes: create, update (status/checklist/comments), soft delete.
 */
export function buildTaskKeys(
    tenantId: string,
    businessId: string,
    taskId: string,
    createdAt: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: taskSK(taskId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.TASK),
        GSI1SK: gsi1SK(createdAt, taskId),
        entityType: STAFF_ENTITY_TYPE.TASK,
    };
}

/**
 * CommissionRule — SK: COMMRULE#{id}
 *
 * Access patterns:
 *  - Get one rule:                  GetItem(PK, COMMRULE#{id})
 *  - List rules in business:        Query(PK, begins_with(SK, 'COMMRULE#'))
 * Writes: create, update, deactivate.
 */
export function buildCommissionRuleKeys(
    tenantId: string,
    businessId: string,
    ruleId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: commissionRuleSK(ruleId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.COMMISSION_RULE),
        GSI1SK: ruleId,
        entityType: STAFF_ENTITY_TYPE.COMMISSION_RULE,
    };
}

/**
 * PerformanceScore — SK: PERFSCORE#{employeeId}#{period}
 *
 * Access patterns:
 *  - Get score for employee+period: GetItem(PK, PERFSCORE#{emp}#{period})
 *  - List an employee's scores:     Query(PK, begins_with(SK,'PERFSCORE#{emp}#'))
 *  - Rank in a period:              Query GSI1(GSI1PK=…#STAFF_PERFSCORE,
 *                                              GSI1SK={period}#{emp})
 * Writes: upsert per (employee, period).
 */
export function buildPerformanceScoreKeys(
    tenantId: string,
    businessId: string,
    employeeId: string,
    period: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: performanceScoreSK(employeeId, period),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.PERFORMANCE_SCORE),
        GSI1SK: `${period}#${employeeId}`,
        entityType: STAFF_ENTITY_TYPE.PERFORMANCE_SCORE,
    };
}

/**
 * AuditLog (staff) — SK: AUDIT#{isoTimestamp}#{eventId}  (append-only)
 *
 * NOTE: shares the `AUDIT#` prefix with generic audit, but lives in the
 * business partition (generic audit lives in the tenant partition) and carries
 * entity_type = STAFF_AUDIT. Filter by entity_type on base-table scans.
 *
 * Access patterns:
 *  - List audit in a time window:   Query(PK, begins_with(SK, 'AUDIT#{datePrefix}'))
 *                                    + entity_type = STAFF_AUDIT filter
 *  - By actor/target:               Query GSI1(GSI1PK=…#STAFF_AUDIT,
 *                                              GSI1SK={ts}#{eventId})
 * Writes: create only (immutable trail).
 */
export function buildStaffAuditKeys(
    tenantId: string,
    businessId: string,
    isoTimestamp: string,
    eventId: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: staffAuditSK(isoTimestamp, eventId),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.AUDIT),
        GSI1SK: gsi1SK(isoTimestamp, eventId),
        entityType: STAFF_ENTITY_TYPE.AUDIT,
    };
}

/**
 * NotificationLog — SK: NOTIFLOG#{isoTimestamp}#{id}  (append-only)
 *
 * Access patterns:
 *  - List notifications in window:  Query(PK, begins_with(SK, 'NOTIFLOG#{datePrefix}'))
 *  - Recent-first history:          Query GSI1(GSI1PK=…#STAFF_NOTIFLOG,
 *                                              GSI1SK={ts}#{id}) ScanIndexForward=false
 * Writes: create only.
 */
export function buildNotificationLogKeys(
    tenantId: string,
    businessId: string,
    isoTimestamp: string,
    id: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: notificationLogSK(isoTimestamp, id),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.NOTIFICATION_LOG),
        GSI1SK: gsi1SK(isoTimestamp, id),
        entityType: STAFF_ENTITY_TYPE.NOTIFICATION_LOG,
    };
}

/**
 * StaffFeatureConfig — SK: STAFFCFG#{businessType}#{tier}
 *
 * Access patterns:
 *  - Resolve config for a business:  GetItem(PK, STAFFCFG#{businessType}#{tier})
 *  - List all configs in business:   Query(PK, begins_with(SK, 'STAFFCFG#'))
 * Writes: upsert per (businessType, tier).
 */
export function buildStaffFeatureConfigKeys(
    tenantId: string,
    businessId: string,
    businessType: string,
    tier: string,
): StaffEntityKeys {
    return {
        PK: businessPK(tenantId, businessId),
        SK: staffFeatureConfigSK(businessType, tier),
        GSI1PK: gsi1PK(tenantId, businessId, STAFF_ENTITY_TYPE.FEATURE_CONFIG),
        GSI1SK: `${businessType}#${tier}`,
        entityType: STAFF_ENTITY_TYPE.FEATURE_CONFIG,
    };
}
