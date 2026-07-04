// ============================================================================
// Feature: universal-staff-management, Property 1: Every stored record and query is business-scoped
// ----------------------------------------------------------------------------
// Validates: Requirements 1.5, 2.1, 2.2, 4.6, 11.1
//
// Property 1 (design.md):
//   "For any entity type, tenant id, and business id, the key builder produces a
//    partition key that includes the business id as a leading scope component,
//    and every read/write issued for that entity is constrained to that
//    partition — so no operation can address a record outside the caller's
//    business scope."
//
// How this test proves the property for the DynamoDB single-table design:
//   1. In a single-table design a "read/write" is addressed by its partition
//      key (PK). If EVERY staff key builder produces the SAME business-scoped
//      PK — `TENANT#{tenantId}#BIZ#{businessId}` — then every GetItem/PutItem and
//      every Query(PK, begins_with(SK, ...)) is physically confined to the
//      caller's business partition. No key can address another business.
//   2. `businessId` is a LEADING scope component: the PK begins with
//      `TENANT#{tenantId}#BIZ#{businessId}` and the business-scoped secondary
//      index (GSI1PK) is namespaced under the same business partition prefix.
//   3. The shared `businessPK` builder REJECTS the '#' key-injection character
//      in the tenant/business segments, so a caller cannot escape or forge a
//      different partition by smuggling '#' into the identifiers.
//
// The builders under test are the staff key builders in ../keys.ts and the
// payroll/statutory key builders in ../repositories/payroll.keys.ts. ALL staff
// data (including payroll) lives in the DynamoDB single table.
// ============================================================================

import fc from 'fast-check';

import { businessPK } from '../../../dynamodb/keys';
import {
    buildEmployeeKeys,
    buildDepartmentKeys,
    buildDesignationKeys,
    buildAttendanceEventKeys,
    buildShiftKeys,
    buildRosterKeys,
    buildLeaveTypeKeys,
    buildLeaveRequestKeys,
    buildLeaveBalanceKeys,
    buildTaskKeys,
    buildCommissionRuleKeys,
    buildPerformanceScoreKeys,
    buildStaffAuditKeys,
    buildNotificationLogKeys,
    buildStaffFeatureConfigKeys,
} from '../keys';
import {
    buildPayrollRunKeys,
    buildPayslipKeys,
    buildSalaryComponentKeys,
    buildStatutoryRateKeys,
    buildSalaryChangeAuditKeys,
} from '../repositories/payroll.keys';

// Minimum fast-check iterations mandated by the spec for property tests.
const RUNS = 200;

interface EntityKeysLike {
    PK: string;
    SK: string;
    GSI1PK?: string;
    GSI1SK?: string;
}

interface Segments {
    seg: string; // generic safe id segment (employeeId, deptId, ...)
    seg2: string; // secondary safe id segment (leaveTypeId, componentId, ...)
    date: string; // safe iso date / timestamp segment
    kind: 'PF' | 'ESI' | 'PT' | 'TDS';
    version: number;
}

/**
 * Registry of every staff + payroll key builder, each reduced to a uniform
 * `(tenantId, businessId, segments) => EntityKeys` shape so the property can be
 * asserted identically across the entire entity surface.
 */
const BUILDERS: Array<{
    name: string;
    build: (t: string, b: string, s: Segments) => EntityKeysLike;
}> = [
    // ── Non-payroll staff entities (../keys.ts) ──────────────────────────────
    { name: 'Employee', build: (t, b, s) => buildEmployeeKeys(t, b, s.seg, s.date) },
    { name: 'Department', build: (t, b, s) => buildDepartmentKeys(t, b, s.seg) },
    { name: 'Designation', build: (t, b, s) => buildDesignationKeys(t, b, s.seg) },
    {
        name: 'AttendanceEvent',
        build: (t, b, s) => buildAttendanceEventKeys(t, b, s.seg, s.date, s.seg2),
    },
    { name: 'Shift', build: (t, b, s) => buildShiftKeys(t, b, s.seg) },
    { name: 'Roster', build: (t, b, s) => buildRosterKeys(t, b, s.seg, s.date) },
    { name: 'LeaveType', build: (t, b, s) => buildLeaveTypeKeys(t, b, s.seg) },
    {
        name: 'LeaveRequest',
        build: (t, b, s) => buildLeaveRequestKeys(t, b, s.seg, s.date),
    },
    {
        name: 'LeaveBalance',
        build: (t, b, s) => buildLeaveBalanceKeys(t, b, s.seg, s.seg2),
    },
    { name: 'Task', build: (t, b, s) => buildTaskKeys(t, b, s.seg, s.date) },
    {
        name: 'CommissionRule',
        build: (t, b, s) => buildCommissionRuleKeys(t, b, s.seg),
    },
    {
        name: 'PerformanceScore',
        build: (t, b, s) => buildPerformanceScoreKeys(t, b, s.seg, s.seg2),
    },
    {
        name: 'StaffAudit',
        build: (t, b, s) => buildStaffAuditKeys(t, b, s.date, s.seg),
    },
    {
        name: 'NotificationLog',
        build: (t, b, s) => buildNotificationLogKeys(t, b, s.date, s.seg),
    },
    {
        name: 'StaffFeatureConfig',
        build: (t, b, s) => buildStaffFeatureConfigKeys(t, b, s.seg, s.seg2),
    },
    // ── Money-critical payroll/statutory entities (../repositories/payroll.keys.ts) ──
    { name: 'PayrollRun', build: (t, b, s) => buildPayrollRunKeys(t, b, s.seg) },
    {
        name: 'Payslip',
        build: (t, b, s) => buildPayslipKeys(t, b, s.seg, s.seg2),
    },
    {
        name: 'SalaryComponent',
        build: (t, b, s) => buildSalaryComponentKeys(t, b, s.seg, s.seg2),
    },
    {
        name: 'StatutoryRate',
        build: (t, b, s) =>
            buildStatutoryRateKeys(t, b, s.kind, s.seg, s.version, s.date),
    },
    {
        name: 'SalaryChangeAudit',
        build: (t, b, s) => buildSalaryChangeAuditKeys(t, b, s.date, s.seg),
    },
];

// ── Generators ──────────────────────────────────────────────────────────────
// A "safe" segment is any non-empty, non-whitespace-only string that does NOT
// contain the reserved '#' delimiter — i.e. a value that a well-formed builder
// must accept. Constrained intelligently to the valid key-segment input space.
const safeSegment = fc
    .string({ minLength: 1, maxLength: 24 })
    .filter((v) => v.trim() !== '' && !v.includes('#'));

const segmentsArb: fc.Arbitrary<Segments> = fc.record({
    seg: safeSegment,
    seg2: safeSegment,
    date: safeSegment,
    kind: fc.constantFrom<'PF' | 'ESI' | 'PT' | 'TDS'>('PF', 'ESI', 'PT', 'TDS'),
    version: fc.integer({ min: 0, max: 999 }),
});

// An injection payload is a string that smuggles the reserved '#' delimiter,
// attempting to escape or forge a different partition.
const injectionSegment = fc
    .tuple(
        fc.string({ maxLength: 8 }),
        fc.string({ maxLength: 8 }),
    )
    .map(([a, b]) => `${a}#${b}`);

describe('Property 1: Every stored record and query is business-scoped', () => {
    it('every builder PK equals businessPK(tenantId, businessId) with businessId as the leading scope', () => {
        fc.assert(
            fc.property(safeSegment, safeSegment, segmentsArb, (tenantId, businessId, segs) => {
                const expectedPK = `TENANT#${tenantId}#BIZ#${businessId}`;
                // Sanity: our expectation matches the shared, security-validated builder.
                expect(businessPK(tenantId, businessId)).toBe(expectedPK);

                for (const { name, build } of BUILDERS) {
                    const keys = build(tenantId, businessId, segs);

                    // (1) Every builder confines the item to the business partition.
                    expect(keys.PK).toBe(expectedPK);

                    // (2) businessId is a LEADING scope component of the PK.
                    expect(keys.PK.startsWith(`TENANT#${tenantId}#BIZ#${businessId}`)).toBe(
                        true,
                    );

                    // (3) The business-scoped secondary index stays within the
                    //     same business partition namespace (no cross-business reads).
                    if (keys.GSI1PK !== undefined) {
                        expect(
                            keys.GSI1PK.startsWith(`TENANT#${tenantId}#BIZ#${businessId}`),
                        ).toBe(true);
                    }

                    // Guard against a silently-empty SK (would be an addressing bug).
                    expect(typeof keys.SK).toBe('string');
                    expect(keys.SK.length).toBeGreaterThan(0);

                    // Label the entity in failure output for fast triage.
                    void name;
                }
            }),
            { numRuns: RUNS },
        );
    });

    it("rejects '#' key-injection in the tenantId or businessId scope for every builder", () => {
        fc.assert(
            fc.property(
                injectionSegment,
                safeSegment,
                segmentsArb,
                fc.boolean(),
                (poison, safe, segs, poisonTenant) => {
                    const tenantId = poisonTenant ? poison : safe;
                    const businessId = poisonTenant ? safe : poison;

                    for (const { name, build } of BUILDERS) {
                        // A poisoned scope segment MUST be refused — never used to
                        // build a partition key that could escape the caller's scope.
                        expect(() => build(tenantId, businessId, segs)).toThrow(
                            /SECURITY/,
                        );
                        void name;
                    }
                },
            ),
            { numRuns: RUNS },
        );
    });
});
