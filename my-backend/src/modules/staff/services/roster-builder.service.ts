// ============================================================================
// Staff Module — Roster Builder Service (Task 5.3)
// ============================================================================
// Pure, testable shift-rule enforcement logic for roster building (Property 11).
//
// PROPERTY 11 (design.md):
//   "For any roster build over a set of employees and shifts, every produced
//    assignment satisfies the configured shift rules, and any assignment that
//    would violate a rule is rejected rather than persisted."
//
// The enforcement function `validateRosterAssignment` is PURE: it takes a
// proposed assignment (employee + shift) and context, and returns accept/reject.
// The orchestrating `buildRoster` function uses it to filter valid assignments.
//
// SHIFT RULES enforced (Req 3.3, 3.7):
//   1. Shift must be active — inactive shifts cannot accept assignments.
//   2. Employee must be active — inactive employees cannot be assigned.
//   3. No duplicate assignment — same employee cannot be assigned to the same
//      shift on the same roster.
//   4. No overlapping shifts — if an employee is already assigned to a shift
//      whose time range overlaps the proposed shift (same day), reject.
//   5. Geo-fence — if the shift has a geoFence and the employee has a known
//      location, it must be within the fence radius.
//   6. Approval requirement — if the shift requires manager approval, the
//      assignment is rejected unless an `approved` flag is present in context.
//
// Requirements: 3.3 (shift definitions with rules), 3.7 (enforce on roster build).
// ============================================================================

import type {
    Shift,
    RosterAssignment,
    GeoFence,
} from '../schemas/shift.schema';

// ── Rejection codes ─────────────────────────────────────────────────────────

export type ShiftRuleRejectionCode =
    | 'SHIFT_INACTIVE'
    | 'EMPLOYEE_INACTIVE'
    | 'DUPLICATE_ASSIGNMENT'
    | 'OVERLAPPING_SHIFT'
    | 'OUTSIDE_GEO_FENCE'
    | 'APPROVAL_REQUIRED';

// ── Validation result ─────────────────────────────────────────────────────────

export interface ShiftRuleValidationResult {
    accepted: boolean;
    code?: ShiftRuleRejectionCode;
    reason?: string;
}

// ── Context for validation ───────────────────────────────────────────────────

export interface EmployeeContext {
    employeeId: string;
    status: 'active' | 'inactive';
    /** Optional known location of the employee for geo-fence checks. */
    location?: { lat: number; lng: number };
}

export interface AssignmentContext {
    /** The shift being assigned. */
    shift: Shift;
    /** The employee being assigned. */
    employee: EmployeeContext;
    /** Existing assignments already accepted in this roster build. */
    existingAssignments: Array<{ employeeId: string; shiftId: string; shift: Shift }>;
    /** Whether the assignment has been pre-approved by a manager. */
    approved?: boolean;
}

// ── Pure time-overlap helper ─────────────────────────────────────────────────

/**
 * Parse HH:MM to minutes since midnight.
 */
export function timeToMinutes(time: string): number {
    const [h, m] = time.split(':').map(Number);
    return h * 60 + m;
}

/**
 * Check whether two time ranges (same day) overlap. Supports overnight shifts
 * where `end < start` (e.g. 22:00–06:00 treated as spanning midnight).
 */
export function shiftsOverlap(
    startA: string,
    endA: string,
    startB: string,
    endB: string,
): boolean {
    const aStart = timeToMinutes(startA);
    const aEnd = timeToMinutes(endA);
    const bStart = timeToMinutes(startB);
    const bEnd = timeToMinutes(endB);

    // Normalize: represent each shift as a set of minute-ranges within [0, 1440*2)
    // to handle overnight wrapping.
    const rangesA = aEnd > aStart
        ? [[aStart, aEnd]] as [number, number][]
        : [[aStart, 1440], [0, aEnd]] as [number, number][];
    const rangesB = bEnd > bStart
        ? [[bStart, bEnd]] as [number, number][]
        : [[bStart, 1440], [0, bEnd]] as [number, number][];

    for (const [a0, a1] of rangesA) {
        for (const [b0, b1] of rangesB) {
            // Two intervals [a0,a1) and [b0,b1) overlap iff a0 < b1 && b0 < a1
            if (a0 < b1 && b0 < a1) return true;
        }
    }
    return false;
}

// ── Geo-fence helper ─────────────────────────────────────────────────────────

/**
 * Haversine distance in metres between two (lat, lng) points.
 */
export function haversineDistanceMeters(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
): number {
    const R = 6_371_000; // Earth radius in metres
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Check whether a point is within a geo-fence.
 */
export function isWithinGeoFence(
    location: { lat: number; lng: number },
    fence: GeoFence,
): boolean {
    const distance = haversineDistanceMeters(location.lat, location.lng, fence.lat, fence.lng);
    return distance <= fence.radiusMeters;
}

// ── Pure shift-rule enforcement (Property 11) ────────────────────────────────

/**
 * Validate a proposed roster assignment against the shift's configured rules.
 *
 * This function is PURE — no side effects, no I/O. It returns an accept/reject
 * decision for a single proposed assignment given the current context.
 *
 * Enforcement order:
 *   1. Shift must be active
 *   2. Employee must be active
 *   3. No duplicate assignment (same employee+shift already in roster)
 *   4. No overlapping shifts for the same employee
 *   5. Geo-fence check (if shift defines a fence and employee has a location)
 *   6. Approval check (if shift requires manager approval)
 */
export function validateRosterAssignment(ctx: AssignmentContext): ShiftRuleValidationResult {
    const { shift, employee, existingAssignments, approved } = ctx;

    // 1. Shift must be active.
    if (shift.status !== 'active') {
        return {
            accepted: false,
            code: 'SHIFT_INACTIVE',
            reason: `Shift '${shift.name}' is inactive and cannot accept assignments`,
        };
    }

    // 2. Employee must be active.
    if (employee.status !== 'active') {
        return {
            accepted: false,
            code: 'EMPLOYEE_INACTIVE',
            reason: `Employee '${employee.employeeId}' is inactive`,
        };
    }

    // 3. No duplicate assignment.
    const hasDuplicate = existingAssignments.some(
        (a) => a.employeeId === employee.employeeId && a.shiftId === shift.id,
    );
    if (hasDuplicate) {
        return {
            accepted: false,
            code: 'DUPLICATE_ASSIGNMENT',
            reason: `Employee '${employee.employeeId}' is already assigned to shift '${shift.id}'`,
        };
    }

    // 4. No overlapping shifts.
    const employeeShifts = existingAssignments.filter(
        (a) => a.employeeId === employee.employeeId,
    );
    for (const existing of employeeShifts) {
        if (shiftsOverlap(shift.start, shift.end, existing.shift.start, existing.shift.end)) {
            return {
                accepted: false,
                code: 'OVERLAPPING_SHIFT',
                reason: `Shift '${shift.name}' overlaps with already-assigned shift '${existing.shift.name}'`,
            };
        }
    }

    // 5. Geo-fence enforcement.
    if (shift.geoFence && employee.location) {
        if (!isWithinGeoFence(employee.location, shift.geoFence)) {
            return {
                accepted: false,
                code: 'OUTSIDE_GEO_FENCE',
                reason: `Employee '${employee.employeeId}' is outside the geo-fence for shift '${shift.name}'`,
            };
        }
    }

    // 6. Approval requirement.
    if (shift.approvalRule?.mode === 'manager_required' && !approved) {
        return {
            accepted: false,
            code: 'APPROVAL_REQUIRED',
            reason: `Shift '${shift.name}' requires manager approval`,
        };
    }

    return { accepted: true };
}

// ── Roster builder (orchestration) ───────────────────────────────────────────

export interface RosterBuildInput {
    /** The set of proposed assignments. */
    proposedAssignments: Array<{
        employeeId: string;
        shiftId: string;
        /** Whether this assignment has been pre-approved (for approval_required shifts). */
        approved?: boolean;
    }>;
    /** All shift definitions keyed by ID (looked up by the handler beforehand). */
    shiftsById: Map<string, Shift>;
    /** Employee context keyed by ID (looked up by the handler beforehand). */
    employeesById: Map<string, EmployeeContext>;
}

export interface RosterBuildResult {
    /** Assignments that passed all shift rules. */
    accepted: RosterAssignment[];
    /** Assignments that were rejected, with reasons. */
    rejected: Array<{
        employeeId: string;
        shiftId: string;
        code: ShiftRuleRejectionCode;
        reason: string;
    }>;
}

/**
 * Build a roster by evaluating each proposed assignment against the configured
 * shift rules. Accepted assignments are accumulated and become the context for
 * subsequent validations (so overlapping-shift checks account for previously
 * accepted assignments in this same build).
 *
 * This function is PURE — no I/O, fully testable (Property 11).
 */
export function buildRoster(input: RosterBuildInput): RosterBuildResult {
    const { proposedAssignments, shiftsById, employeesById } = input;

    const accepted: RosterAssignment[] = [];
    const rejected: RosterBuildResult['rejected'] = [];

    // Track accepted assignments with their shift details for overlap checks.
    const acceptedWithShifts: Array<{ employeeId: string; shiftId: string; shift: Shift }> = [];

    for (const proposal of proposedAssignments) {
        const shift = shiftsById.get(proposal.shiftId);
        if (!shift) {
            rejected.push({
                employeeId: proposal.employeeId,
                shiftId: proposal.shiftId,
                code: 'SHIFT_INACTIVE',
                reason: `Shift '${proposal.shiftId}' not found`,
            });
            continue;
        }

        const employee = employeesById.get(proposal.employeeId);
        if (!employee) {
            rejected.push({
                employeeId: proposal.employeeId,
                shiftId: proposal.shiftId,
                code: 'EMPLOYEE_INACTIVE',
                reason: `Employee '${proposal.employeeId}' not found`,
            });
            continue;
        }

        const result = validateRosterAssignment({
            shift,
            employee,
            existingAssignments: acceptedWithShifts,
            approved: proposal.approved,
        });

        if (result.accepted) {
            accepted.push({ employeeId: proposal.employeeId, shiftId: proposal.shiftId });
            acceptedWithShifts.push({ employeeId: proposal.employeeId, shiftId: proposal.shiftId, shift });
        } else {
            rejected.push({
                employeeId: proposal.employeeId,
                shiftId: proposal.shiftId,
                code: result.code!,
                reason: result.reason!,
            });
        }
    }

    return { accepted, rejected };
}
