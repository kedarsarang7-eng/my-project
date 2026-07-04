// ============================================================================
// Staff Module — Attendance Service (Tasks 5.1 + 5.2)
// ============================================================================
// Append-only attendance capture with geo-fence/GPS validation and idempotent
// merge. Supports the five real capture methods (Manual, QR, Barcode, GPS,
// WiFi — Req 3.1) and exposes Face/Biometric ONLY as a flagged-off interface
// (Req 3.2, AD-7) that never fabricates data.
//
// GEO-FENCE / GPS VALIDATION (task 5.2, Req 3.6):
//   When a location-restricted method (GPS) submits geo coordinates, the service
//   validates them against the configured geo-fence for the business. If the
//   coordinates fall outside the fence, the event is persisted with
//   `rejected=true` and a `rejectionReason` describing the failure.
//
// ATTENDANCE MERGE (task 5.2, AD-4, Req 3.5):
//   `mergeAttendanceEvents(events[])` inserts each event by its (eventId,
//   timestamp) key. Duplicates are silently skipped (ConflictError = already
//   exists). No generic merge-conflict UI. Merge is idempotent and order-
//   independent because the conditional write (`attribute_not_exists(SK)`)
//   ensures only the first insert wins and subsequent inserts of the same key
//   are harmlessly rejected.
//
// SECURITY / ISOLATION
//   • businessId + tenantId come from the authenticated scope (never client
//     input); the repository scopes every write to the business partition.
//   • Face/Biometric capture is FAIL-CLOSED behind an OFF Feature_Flag using the
//     SAME feature-flag mechanism as pii-crypto.service.ts.
//
// Requirements: 3.1, 3.2, 3.4, 3.5, 3.6.
// ============================================================================

import * as crypto from 'crypto';
import * as featureFlagService from '../../../services/feature-flag.service';
import { logger } from '../../../utils/logger';
import { AppError, ConflictError } from '../../../utils/errors';
import { AttendanceEventRepository } from '../repositories/attendance-event.repository';
import {
    AttendanceEvent,
    CaptureAttendanceInput,
    captureAttendanceInputSchema,
    DeferredAttendanceMethod,
    DEFERRED_ATTENDANCE_METHODS,
} from '../schemas/attendance.schema';

// ── Feature flag: Face/Biometric attendance (Req 3.2, AD-7) ───────────────────
// Face Recognition / Biometric attendance is DEFERRED to Phase 11. It exists
// only as the flagged-off interface below. Resolution is FAIL-CLOSED: unless a
// flag with this key exists, is active, and is explicitly `true`, the capability
// stays OFF and no event is ever fabricated. This service never enables the flag.

/** Feature flag key controlling Face/Biometric attendance capture. Stays OFF. */
export const FACE_BIOMETRIC_ATTENDANCE_FLAG = 'staff_face_biometric_attendance';

/**
 * Resolve whether Face/Biometric attendance capture is enabled. FAIL-CLOSED:
 * returns `false` unless the flag exists, is active, and has an explicit `true`
 * default value. On any lookup error, returns `false` (capability stays OFF).
 */
export async function isFaceBiometricAttendanceEnabled(): Promise<boolean> {
    try {
        const flag = await featureFlagService.getFeatureFlag(FACE_BIOMETRIC_ATTENDANCE_FLAG);
        if (!flag || !flag.is_active) {
            return false;
        }
        return flag.default_value === true;
    } catch (err) {
        logger.warn('Face/Biometric attendance flag lookup failed; defaulting OFF', {
            error: (err as Error).message,
        });
        return false;
    }
}

/**
 * Flagged-off interface for the deferred Face/Biometric capture capability
 * (Req 3.2, 15.3, 15.5). It is intentionally NOT wired to any real SDK. Every
 * method rejects while the flag is OFF and NEVER returns fabricated attendance
 * data. Phase 11 will supply a concrete implementation behind the same flag.
 */
export interface FaceBiometricAttendanceCapture {
    readonly method: DeferredAttendanceMethod;
    /**
     * Capture a face/biometric attendance event. Throws a 501 AppError while the
     * feature flag is OFF — it must never fabricate an event.
     */
    capture(input: unknown): Promise<never>;
}

/**
 * Build the flagged-off Face/Biometric capture stub. Callers can reference the
 * interface, but invoking `capture()` throws while the flag is OFF so no
 * fabricated data can ever be produced (Req 3.2, 15.5).
 */
export function createDeferredFaceBiometricCapture(
    method: DeferredAttendanceMethod,
): FaceBiometricAttendanceCapture {
    if (!DEFERRED_ATTENDANCE_METHODS.includes(method)) {
        throw new AppError(
            'ATTENDANCE_METHOD_INVALID',
            `'${method}' is not a deferred attendance method`,
        );
    }
    return {
        method,
        async capture(): Promise<never> {
            const enabled = await isFaceBiometricAttendanceEnabled();
            // Even if a flag were ever enabled, there is no real implementation
            // yet — we still refuse rather than fabricate data (Req 15.5).
            logger.info('Deferred attendance method invoked while unavailable', {
                method,
                flagEnabled: enabled,
            });
            throw new AppError(
                `${method} attendance is not available (deferred to Phase 11)`,
                501,
                'ATTENDANCE_METHOD_DEFERRED',
            );
        },
    };
}

// ── Attendance capture (Req 3.1, 3.4) ─────────────────────────────────────────

// ── Geo-fence configuration and validation (Req 3.6) ──────────────────────────

/**
 * A geo-fence boundary for a business location. A simple circle defined by a
 * centre point and a radius in metres. More complex polygonal fences can be
 * expressed as an array of these in a future iteration; for now the design calls
 * for a configurable boundary per business.
 */
export interface GeoFenceBoundary {
    /** Centre latitude of the geo-fence. */
    lat: number;
    /** Centre longitude of the geo-fence. */
    lng: number;
    /** Radius of the geo-fence in metres. */
    radiusMetres: number;
}

/**
 * Compute the Haversine distance between two points in metres. Used to determine
 * if a captured GPS coordinate falls within a geo-fence radius.
 */
export function haversineDistanceMetres(
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
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

/**
 * Validate an attendance event's geo coordinates against a geo-fence boundary.
 * Returns `{ withinFence: true }` when the point is inside the fence, or
 * `{ withinFence: false, rejectionReason }` when outside.
 */
export function validateGeoFence(
    geo: { lat: number; lng: number },
    fence: GeoFenceBoundary,
): { withinFence: boolean; rejectionReason?: string } {
    const distance = haversineDistanceMetres(geo.lat, geo.lng, fence.lat, fence.lng);
    if (distance <= fence.radiusMetres) {
        return { withinFence: true };
    }
    return {
        withinFence: false,
        rejectionReason: `GPS location (${geo.lat}, ${geo.lng}) is ${Math.round(distance)}m from fence centre — outside the ${fence.radiusMetres}m boundary`,
    };
}

/** Attendance methods that are location-restricted and require geo-fence checks. */
export const LOCATION_RESTRICTED_METHODS = ['gps'] as const;
export type LocationRestrictedMethod = (typeof LOCATION_RESTRICTED_METHODS)[number];

/**
 * Check whether a capture method is location-restricted and therefore requires
 * a geo-fence validation pass before the event can be accepted.
 */
export function isLocationRestrictedMethod(method: string): method is LocationRestrictedMethod {
    return (LOCATION_RESTRICTED_METHODS as readonly string[]).includes(method);
}

// ── Attendance merge (AD-4, Req 3.5) ──────────────────────────────────────────

/**
 * Result of a single event merge attempt.
 * - 'inserted': the event was newly persisted.
 * - 'skipped': the event already existed (duplicate by eventId+timestamp) —
 *   silently ignored, no merge-conflict UI.
 */
export type MergeResult = { eventId: string; status: 'inserted' | 'skipped' };

export class AttendanceService {
    constructor(private readonly repo: AttendanceEventRepository = new AttendanceEventRepository()) {}

    /**
     * Capture an attendance action as a new append-only immutable event.
     *
     * GEO-FENCE VALIDATION (task 5.2, Req 3.6): when the capture method is
     * location-restricted (GPS) and a `geoFence` boundary is provided, the
     * service validates `geo` coordinates against the fence. If outside, the
     * event is persisted with `rejected=true` and the `rejectionReason` recorded.
     *
     * @param tenantId   authenticated tenant scope (never from client input)
     * @param businessId authenticated business scope (never from client input)
     * @param input      validated capture request
     * @param geoFence   optional geo-fence boundary for the business (from shift
     *                   or business config). When provided and the method is
     *                   location-restricted, geo validation is enforced.
     */
    async capture(
        tenantId: string,
        businessId: string,
        input: CaptureAttendanceInput,
        geoFence?: GeoFenceBoundary,
    ): Promise<AttendanceEvent> {
        const parsed = captureAttendanceInputSchema.parse(input);

        // Build the initial event payload.
        const event: AttendanceEvent = {
            eventId: parsed.eventId ?? crypto.randomUUID(),
            employeeId: parsed.employeeId,
            businessId,
            type: parsed.type,
            method: parsed.method,
            // Server-authoritative timestamp when the client did not supply one.
            timestamp: parsed.timestamp ?? new Date().toISOString(),
            ...(parsed.geo !== undefined ? { geo: parsed.geo } : {}),
        };

        // Geo-fence / GPS validation (Req 3.6):
        // If the method is location-restricted and a fence is configured, validate.
        if (isLocationRestrictedMethod(event.method) && geoFence) {
            if (!parsed.geo) {
                // Location-restricted method with no geo data — reject.
                event.rejected = true;
                event.rejectionReason = 'GPS coordinates are required for location-restricted attendance but were not provided';
            } else {
                const validation = validateGeoFence(parsed.geo, geoFence);
                event.geo = {
                    ...parsed.geo,
                    withinFence: validation.withinFence,
                };
                if (!validation.withinFence) {
                    event.rejected = true;
                    event.rejectionReason = validation.rejectionReason;
                }
            }
        }

        return this.repo.create(tenantId, businessId, event);
    }

    /**
     * Merge attendance events from the sync engine by their unique (eventId,
     * timestamp) key (AD-4, Req 3.5).
     *
     * This function inserts each event individually. If an event already exists
     * (ConflictError — the conditional write fires), it is silently skipped.
     * This gives idempotent, order-independent merge semantics without a generic
     * merge-conflict UI.
     *
     * @param tenantId   authenticated tenant scope
     * @param businessId authenticated business scope
     * @param events     array of attendance events to merge
     * @returns per-event result indicating inserted or skipped
     */
    async mergeAttendanceEvents(
        tenantId: string,
        businessId: string,
        events: AttendanceEvent[],
    ): Promise<MergeResult[]> {
        const results: MergeResult[] = [];

        for (const event of events) {
            try {
                await this.repo.create(tenantId, businessId, event);
                results.push({ eventId: event.eventId, status: 'inserted' });
            } catch (err) {
                if (err instanceof ConflictError) {
                    // Event already exists — idempotent skip, no merge-conflict UI.
                    results.push({ eventId: event.eventId, status: 'skipped' });
                } else {
                    // Unexpected error — rethrow.
                    throw err;
                }
            }
        }

        return results;
    }

    /** List a business's events, optionally within a timestamp prefix window. */
    async listByWindow(
        tenantId: string,
        businessId: string,
        opts?: { timestampPrefix?: string; limit?: number; scanIndexForward?: boolean },
    ): Promise<AttendanceEvent[]> {
        return this.repo.listByWindow(tenantId, businessId, opts);
    }

    /** List a single employee's events across dates (chronological). */
    async listByEmployee(
        tenantId: string,
        businessId: string,
        employeeId: string,
        opts?: { limit?: number; scanIndexForward?: boolean },
    ): Promise<AttendanceEvent[]> {
        return this.repo.listByEmployee(tenantId, businessId, employeeId, opts);
    }
}
