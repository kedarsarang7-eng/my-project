// ============================================================================
// Lambda Handler — Notification Retention Configuration (Authenticated Admin)
// ============================================================================
// Exposes:
//   GET  /notifications/retention-config — read the current Archive_Period
//   PUT  /notifications/retention-config — change the Archive_Period
//
// AuthN: standard JWT through `authorizedHandler` (the same path every
// other authenticated endpoint in this service uses).
// AuthZ: only admin-tier roles may read or change retention. Per REQ 13.4
// the change must be made through an authenticated configuration change
// that is recorded in an Audit_Log entry naming the actor, the previous
// value, the new value, and the timestamp. Per REQ 13.4a, if the
// Audit_Log subsystem is unavailable, the change MUST be rejected and
// the previous Archive_Period MUST remain in effect.
//
// We intentionally restrict the role set to {OWNER, ADMIN, SUPER_ADMIN}.
// Lower roles (CASHIER, STAFF, VIEWER, etc.) cannot read or change the
// retention because the policy controls how long their own notifications
// (and audit trails) survive — escalating privileges via this knob is a
// classic compliance hole.
//
// Validates: REQ 13.4, REQ 13.4a, REQ 12.7 (audit unauthorized attempts).
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody } from '../middleware/validation';
import { UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
    AuditLogUnavailableError,
    InvalidRetentionValueError,
    getRetentionConfig,
    setRetentionConfig,
    updateRetentionConfigSchema,
    type RetentionConfigRecord,
} from '../notifications/retention';
import { recordUnauthorizedAccessAttempt } from '../notifications/service';
import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';

/**
 * Roles permitted to read or change the notification Archive_Period.
 *
 * SUPER_ADMIN is the platform-wide operator (license management). OWNER
 * and ADMIN are the per-tenant admins. We do NOT include MANAGER or
 * ACCOUNTANT — both are operational roles, not policy roles.
 */
const ADMIN_ROLES: UserRole[] = [
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.SUPER_ADMIN,
];

interface RetentionConfigResponseShape {
    readonly archive_period_days: number;
    readonly updated_at: string;
    readonly updated_by: string | null;
    readonly version: number;
}

function toResponseShape(
    record: RetentionConfigRecord,
): RetentionConfigResponseShape {
    return {
        archive_period_days: record.archive_period_days,
        updated_at: record.updated_at,
        updated_by: record.updated_by,
        version: record.version,
    };
}

// ---- GET /notifications/retention-config --------------------------------

/**
 * Read the current retention configuration. Returns the persisted record
 * if one exists, otherwise the default derived from the environment.
 *
 * Anonymous and non-admin callers are rejected by the `authorizedHandler`
 * wrapper before this body executes; the wrapper logs the auth failure
 * via the existing `logAuthFailure` path. The
 * `unauthorized_access_attempt` Audit_Log entry (REQ 12.7) is written
 * by `withRetentionAccessAudit` below before the wrapper's deny path
 * runs.
 */
const getRetentionConfigInner = authorizedHandler(
    ADMIN_ROLES,
    async (_event, _context, auth) => {
        const record = await getRetentionConfig();
        logger.debug('Retention config read', {
            actor_id: auth.sub,
            archive_period_days: record.archive_period_days,
            version: record.version,
        });
        return response.success(toResponseShape(record));
    },
);

export const getRetentionConfigHandler = withRetentionAccessAudit(
    getRetentionConfigInner,
    'GET',
);

// ---- PUT /notifications/retention-config --------------------------------

/**
 * Change the retention configuration. Validates the body, writes an
 * Audit_Log entry naming the actor and previous/new values, and only
 * then persists the change. If the Audit_Log subsystem is unavailable,
 * the change is rejected with a 503 and the previous Archive_Period
 * remains in effect (REQ 13.4a).
 */
const updateRetentionConfigInner = authorizedHandler(
    ADMIN_ROLES,
    async (event, _context, auth) => {
        const parsed = parseBody(updateRetentionConfigSchema, event);
        if (!parsed.success) return parsed.error;

        try {
            const updated = await setRetentionConfig({
                archive_period_days: parsed.data.archive_period_days,
                actor_id: auth.sub,
            });
            logger.info('Retention config updated', {
                actor_id: auth.sub,
                archive_period_days: updated.archive_period_days,
                version: updated.version,
            });
            return response.success(toResponseShape(updated));
        } catch (err) {
            if (err instanceof InvalidRetentionValueError) {
                return response.badRequest(err.message, err.details);
            }
            if (err instanceof AuditLogUnavailableError) {
                // REQ 13.4a — reject the configuration change so the
                // previous Archive_Period remains in effect.
                logger.warn(
                    'Retention config change rejected: Audit_Log unavailable',
                    {
                        actor_id: auth.sub,
                        attempted_value: parsed.data.archive_period_days,
                    },
                );
                return response.serviceUnavailable(err.message, 30);
            }
            // Unknown errors propagate to the global handler-wrapper which
            // returns a structured 500.
            throw err;
        }
    },
);

export const updateRetentionConfigHandler = withRetentionAccessAudit(
    updateRetentionConfigInner,
    'PUT',
);

// ============================================================================
// withRetentionAccessAudit — REQ 12.7 audit wrapper
// ============================================================================
//
// Wraps the `authorizedHandler`-returned lambda with a post-flight check
// that writes an `unauthorized_access_attempt` Audit_Log entry whenever
// the underlying response is 401 or 403. The wrapper:
//
//   1. Delegates the call straight through to the inner handler.
//   2. Inspects the response statusCode.
//   3. If 401 or 403 → write the audit row best-effort.
//   4. Returns the response unchanged.
//
// We do NOT pre-flight the JWT verification ourselves because that would
// double-verify on every successful call (perf hit) AND make existing
// tests that mock `verifyAuth` with `mockResolvedValueOnce` break by
// consuming the queued mock value before `authorizedHandler` sees it.
// Post-flight inspection keeps the audit additive and side-effect free.
//
// The actor id is parsed from the Authorization header (a best-effort
// JWT decode without verification) when available — we cannot trust the
// content but the audit trail of denied attempts is allowed to record
// "the caller claimed to be X" since the entry itself is marked
// `outcome=denied`. When no token is supplied we record `'anonymous'`.
// The audit write is best-effort: any AuditLog failure is logged at warn
// inside `recordUnauthorizedAccessAttempt` and never propagates. The
// user-visible response is therefore identical to today's behaviour
// regardless of audit-trail availability — which is the explicit
// requirement of task 16.3.
type LambdaHandler = (
    event: APIGatewayProxyEventV2,
    context: Context,
) => Promise<APIGatewayProxyResultV2>;

function withRetentionAccessAudit(
    inner: LambdaHandler,
    operation: 'GET' | 'PUT',
): LambdaHandler {
    return async (event, context) => {
        const result = await inner(event, context);

        // The inner handler returns either a buffer or an object with a
        // statusCode field; we only audit object-shaped responses.
        const status =
            typeof result === 'object' && result !== null
                ? (result as { statusCode?: number }).statusCode
                : undefined;

        if (status === 401 || status === 403) {
            const actorId = unverifiedActorIdFromAuthHeader(event) || 'anonymous';
            await recordUnauthorizedAccessAttempt({
                actorId,
                reason: 'retention_admin_required',
                context: {
                    operation,
                    path: event.rawPath,
                    status_code: status,
                },
            });
        }

        return result;
    };
}

/**
 * Best-effort actor id extraction from the JWT in the Authorization
 * header WITHOUT verifying the signature. Used only to label the
 * `unauthorized_access_attempt` audit row — the entry itself is marked
 * `outcome=denied` so an attacker forging a `sub` claim only succeeds
 * in lying about themselves on a row that already records "this caller
 * was denied". Returns `null` when no token is present or the token
 * cannot be parsed; callers fall back to `'anonymous'` on null.
 */
function unverifiedActorIdFromAuthHeader(
    event: APIGatewayProxyEventV2,
): string | null {
    const header =
        event.headers?.authorization || event.headers?.Authorization;
    if (!header) return null;
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) return null;
    const parts = match[1].split('.');
    if (parts.length < 2) return null;
    try {
        // JWT payload is base64url; pad and decode without verification.
        const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
        const padded =
            payload + '='.repeat((4 - (payload.length % 4)) % 4);
        const decoded = Buffer.from(padded, 'base64').toString('utf8');
        const parsed = JSON.parse(decoded) as { sub?: string };
        return typeof parsed.sub === 'string' && parsed.sub.length > 0
            ? parsed.sub
            : null;
    } catch {
        return null;
    }
}
