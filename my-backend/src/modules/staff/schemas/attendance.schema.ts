// ============================================================================
// Staff Module — Attendance Event Item Shape + Zod Schema (Task 5.1)
// ============================================================================
// The DynamoDB single-table item shape for append-only, immutable
// AttendanceEvent records. Matches design.md → Data Models → AttendanceEvent
// exactly.
//
// AD-4 — APPEND-ONLY ATTENDANCE
// -----------------------------
// AttendanceEvents are immutable: a correction is a NEW event, never an in-place
// edit or delete. The item therefore carries NO `updatedAt`/`isDeleted` field —
// there is no lifecycle beyond creation. The create-only repository
// (attendance-event.repository.ts) refuses to overwrite an existing event.
//
// CAPTURE METHODS (Req 3.1): manual | qr | barcode | gps | wifi.
// Face Recognition / Biometric are DEFERRED (Req 3.2, AD-7): they exist only as
// a flagged-off interface (see attendance.service.ts) and are NOT valid values
// of the persisted `method` field — no fabricated face/biometric data is ever
// stored.
//
// SK: ATT#{isoTimestamp}#{eventId}   (timestamp-first → natural chronology)
//
// Requirements: 3.1 (capture methods), 3.2 (face/biometric flagged-off only),
// 3.4 (append-only immutable event).
// ============================================================================

import { z } from 'zod';

// ── Enumerations ─────────────────────────────────────────────────────────────

/** The kind of attendance action an event records. */
export const ATTENDANCE_EVENT_TYPES = ['check_in', 'check_out', 'state_change'] as const;
export type AttendanceEventType = (typeof ATTENDANCE_EVENT_TYPES)[number];

/**
 * Attendance capture methods that ACTUALLY produce stored events (Req 3.1).
 * Face/Biometric are intentionally NOT here — they are deferred (Req 3.2).
 */
export const ATTENDANCE_CAPTURE_METHODS = ['manual', 'qr', 'barcode', 'gps', 'wifi'] as const;
export type AttendanceCaptureMethod = (typeof ATTENDANCE_CAPTURE_METHODS)[number];

/**
 * Deferred capture methods (Req 3.2, AD-7). Listed here as typed constants so
 * callers/UIs can reference them, but they are NEVER accepted by the persisted
 * schema and never produce fabricated events. Enabling them is a Phase 11 task.
 */
export const DEFERRED_ATTENDANCE_METHODS = ['face', 'biometric'] as const;
export type DeferredAttendanceMethod = (typeof DEFERRED_ATTENDANCE_METHODS)[number];

// ── Validators ───────────────────────────────────────────────────────────────

const nonEmpty = z.string().min(1);

/** SK segments must never contain '#' (key-injection guard). */
const skSafe = nonEmpty.refine((v) => !v.includes('#'), {
    message: "value must not contain '#'",
});

/** ISO-8601 timestamp string (server-authoritative on sync). */
const isoTimestamp = z.string().datetime({ offset: true });

/**
 * Optional geo payload captured with a location-based method. Geo-fence
 * VALIDATION (setting/enforcing `withinFence`) is task 5.2 — here we only define
 * the shape so location-based events can carry their coordinates.
 */
export const attendanceGeoSchema = z.object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
    withinFence: z.boolean().optional(),
});
export type AttendanceGeo = z.infer<typeof attendanceGeoSchema>;

// ── AttendanceEvent — SK: ATT#{isoTimestamp}#{eventId} (append-only) ──────────

export interface AttendanceEvent {
    eventId: string;
    employeeId: string;
    businessId: string;
    type: AttendanceEventType;
    method: AttendanceCaptureMethod;
    timestamp: string; // ISO-8601, server-authoritative on sync
    geo?: AttendanceGeo;
    /** Set by geo-fence/GPS validation (task 5.2); absent means accepted. */
    rejected?: boolean;
    rejectionReason?: string;
}

export const attendanceEventSchema = z.object({
    eventId: skSafe,
    employeeId: skSafe,
    businessId: skSafe,
    type: z.enum(ATTENDANCE_EVENT_TYPES),
    method: z.enum(ATTENDANCE_CAPTURE_METHODS),
    timestamp: isoTimestamp,
    geo: attendanceGeoSchema.optional(),
    rejected: z.boolean().optional(),
    rejectionReason: nonEmpty.optional(),
});

/**
 * Handler-facing input for capturing an attendance action. `eventId` and
 * `timestamp` are optional — the service assigns a server-authoritative value
 * when they are omitted. `businessId` is derived from the authenticated scope,
 * never from client input, so it is NOT part of this schema.
 */
export const captureAttendanceInputSchema = z.object({
    employeeId: skSafe,
    type: z.enum(ATTENDANCE_EVENT_TYPES),
    method: z.enum(ATTENDANCE_CAPTURE_METHODS),
    eventId: skSafe.optional(),
    timestamp: isoTimestamp.optional(),
    geo: attendanceGeoSchema.optional(),
});
export type CaptureAttendanceInput = z.infer<typeof captureAttendanceInputSchema>;
