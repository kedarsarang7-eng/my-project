// ============================================================================
// WebSocket Channel Registry — Per-Module Channel Isolation
// ============================================================================
// All WebSocket channel keys are built here.
// Handlers MUST use these builders — never hardcode channel strings.
//
// Channel Hierarchy:
//   tenant:{tenantId}                    ← tenant-wide broadcasts
//   module:{moduleId}:{tenantId}         ← module-scoped events
//   user:{userId}                        ← direct user messages
//   role:{role}:{tenantId}               ← role-scoped broadcasts
//   device:{deviceId}                    ← device-scoped (offline sync ack)
// ============================================================================

import { getAllWsChannelPrefixes, getModule } from '../registry/module-registry';

// ── Channel Key Builders ─────────────────────────────────────────────────────

/** Tenant-wide channel: receives all events for this tenant */
export const tenantChannel = (tenantId: string): string =>
    `tenant:${tenantId}`;

/**
 * Module-scoped channel: receives events for a specific module + tenant.
 * e.g. 'module:restaurant:tenant123' for KOT updates
 */
export const moduleChannel = (moduleId: string, tenantId: string): string =>
    `module:${moduleId}:${tenantId}`;

/** Direct user channel: private messages to a specific user */
export const userChannel = (userId: string): string =>
    `user:${userId}`;

/** Role-scoped channel: broadcast to all users with a given role in a tenant */
export const roleChannel = (role: string, tenantId: string): string =>
    `role:${role}:${tenantId}`;

/** Device-scoped channel: offline sync acknowledgements */
export const deviceChannel = (deviceId: string): string =>
    `device:${deviceId}`;

// ── Event Payload Schema ──────────────────────────────────────────────────────

export interface WsEventPayload {
    /** Target channel key */
    channel: string;
    /** Event name e.g. 'kot.new', 'stock.low', 'fee.due' */
    event: string;
    /** Module that emitted this event */
    moduleId: string;
    /** Tenant this event belongs to */
    tenantId: string;
    /** Business payload — varies per event */
    data: Record<string, unknown>;
    /** ISO8601 timestamp */
    timestamp: string;
    /** Request correlation ID for distributed tracing */
    correlationId: string;
}

// ── Standard Event Names per Module ──────────────────────────────────────────

export const WsEvents = {
    // Restaurant
    RESTAURANT_KOT_NEW: 'kot.new',
    RESTAURANT_KOT_UPDATED: 'kot.updated',
    RESTAURANT_KOT_COMPLETED: 'kot.completed',
    RESTAURANT_TABLE_OCCUPIED: 'table.occupied',
    RESTAURANT_TABLE_CLEARED: 'table.cleared',
    RESTAURANT_ORDER_PLACED: 'order.placed',

    // Grocery
    GROCERY_STOCK_LOW: 'stock.low',
    GROCERY_BATCH_EXPIRING: 'batch.expiring',
    GROCERY_WEIGHSCALE_READING: 'weighscale.reading',

    // Pharmacy
    PHARMACY_BATCH_EXPIRING: 'batch.expiring',
    PHARMACY_BATCH_EXPIRED: 'batch.expired',
    PHARMACY_SCHEDULE_H_DISPENSED: 'schedule.h.dispensed',

    // Clinic
    CLINIC_TOKEN_CALLED: 'token.called',
    CLINIC_APPOINTMENT_BOOKED: 'appointment.booked',
    CLINIC_PATIENT_WAITING: 'patient.waiting',

    // School ERP
    SCHOOL_FEE_DUE: 'fee.due',
    SCHOOL_ATTENDANCE_MARKED: 'attendance.marked',
    SCHOOL_EXAM_RESULT: 'result.published',
    SCHOOL_NOTIFICATION_SENT: 'notification.sent',

    // Petrol Pump
    PUMP_SHIFT_OPENED: 'shift.opened',
    PUMP_SHIFT_CLOSED: 'shift.closed',
    PUMP_NOZZLE_READING: 'nozzle.reading',

    // Jewellery
    JEWELLERY_GOLD_RATE_UPDATED: 'gold.rate.updated',
    JEWELLERY_SCHEME_PAYMENT_DUE: 'scheme.payment.due',
    JEWELLERY_REPAIR_READY: 'repair.ready',

    // Platform
    SUBSCRIPTION_ACTIVATED: 'subscription.activated',
    SUBSCRIPTION_EXPIRED: 'subscription.expired',
    SYNC_COMPLETED: 'sync.completed',
    SYNC_CONFLICT: 'sync.conflict',
} as const;

export type WsEventName = typeof WsEvents[keyof typeof WsEvents];

// ── Channel Validation ────────────────────────────────────────────────────────

/**
 * Validates that a given channel string follows a known pattern.
 * Prevents arbitrary channel subscription attacks.
 */
export function isValidChannel(channel: string): boolean {
    const patterns = [
        /^tenant:[a-zA-Z0-9_-]{1,64}$/,
        /^module:[a-z-]{1,32}:[a-zA-Z0-9_-]{1,64}$/,
        /^user:[a-zA-Z0-9_-]{1,64}$/,
        /^role:[a-z_]{1,32}:[a-zA-Z0-9_-]{1,64}$/,
        /^device:[a-zA-Z0-9_-]{1,128}$/,
    ];
    return patterns.some(p => p.test(channel));
}

/**
 * Extract moduleId from a module channel key.
 * 'module:restaurant:tenant123' → 'restaurant'
 * Returns null if not a module channel.
 */
export function extractModuleFromChannel(channel: string): string | null {
    const match = channel.match(/^module:([a-z-]+):/);
    return match ? match[1] : null;
}

/**
 * Validate that a module channel matches a registered module.
 * Prevents broadcasting to non-existent module channels.
 */
export function isRegisteredModuleChannel(channel: string): boolean {
    const moduleId = extractModuleFromChannel(channel);
    if (!moduleId) return false;
    return getModule(moduleId) !== undefined;
}

/**
 * Get all channels a connection should subscribe to based on their role
 * and active modules. Called on $connect.
 */
export function getSubscriptionChannels(opts: {
    tenantId: string;
    userId: string;
    role: string;
    deviceId?: string;
    activeModules: string[];
}): string[] {
    const channels: string[] = [
        tenantChannel(opts.tenantId),
        userChannel(opts.userId),
        roleChannel(opts.role, opts.tenantId),
    ];

    for (const moduleId of opts.activeModules) {
        const manifest = getModule(moduleId);
        if (manifest && manifest.status !== 'disabled') {
            channels.push(moduleChannel(moduleId, opts.tenantId));
        }
    }

    if (opts.deviceId) {
        channels.push(deviceChannel(opts.deviceId));
    }

    return channels;
}
