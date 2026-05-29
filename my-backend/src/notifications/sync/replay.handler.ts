// ============================================================================
// Sub_App_Sync_Layer — Replay Handler
// ============================================================================
//
// HTTP entry for the cross-app missed-event replay endpoint:
//
//   GET /notifications/replay?since=<ISO_DATE>&app=<sub_app_name>
//
// Returns notifications targeted at the authenticated user (within the
// `app` Sub_App scope) with `created_at >= since` in ascending order
// (REQ 8.4). Bounded by the Replay_Window default of 7 days
// (REQ 8.5); out-of-window requests return the structured error
// `replay_window_exceeded` (REQ 8.5a). In-window-with-no-matches
// returns HTTP 200 with an empty `notifications` array and
// `next_cursor` = `since` (REQ 8.5a).
//
// Authentication: JWT via the existing Cognito auth middleware
// (REQ 8.2, REQ 19.1) — the wrapper rejects unauthenticated callers
// before the handler runs.
//
// Validates: REQ 8.2, 8.3, 8.4, 8.5, 8.5a, 8.7.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../middleware/handler-wrapper';
import { AuthContext } from '../../types/tenant.types';
import * as response from '../../utils/response';
import { logger } from '../../utils/logger';
import {
    getDefaultNotificationService,
    ReplayWindowExceededError,
} from '../service';

// ---- Allowed Sub_App identifiers ----------------------------------------
//
// Pinned to the four workspace front-ends listed in
// `phase3-architecture.md` §13.1 and the Phase 2 registry. Mirrors the
// `SourceApp` union in `event-bus/types.ts`; kept as a local constant
// here so the validation surface is independent of any future
// additions to the union (a new Sub_App MUST be added explicitly to
// this list to be replay-eligible).

const ALLOWED_SUB_APPS = new Set<string>([
    'dukanx_desktop',
    'school_admin_app',
    'school_student_app',
    'school_teacher_app',
]);

// ---- ISO-8601 timestamp validator ---------------------------------------
//
// Accepts the canonical RFC 3339 / ISO 8601 form used everywhere else in
// the workspace (`Notification.created_at`, AuditLog timestamps, etc.).
// Requires an explicit timezone offset (`Z` or `±HH:MM`) so two clients
// emitting the same wall-clock time never disagree on the boundary.

const ISO_8601_RE =
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;

function isIso8601(value: string): boolean {
    if (!ISO_8601_RE.test(value)) return false;
    const ms = Date.parse(value);
    return Number.isFinite(ms);
}

// ---- Handler ------------------------------------------------------------

/**
 * `GET /notifications/replay?since=<ISO_DATE>&app=<sub_app_name>`
 *
 * Open to every authenticated user — `allowedRoles=[]` means the
 * `authorizedHandler` only enforces JWT presence (REQ 8.2). RBAC for
 * the replay payload itself happens at the per-recipient layer
 * inside `Notification_Service.dispatch`; replay only returns what the
 * caller was already authorised to see.
 */
export const replay = authorizedHandler(
    [],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const params = event.queryStringParameters || {};
        const since = (params.since || '').trim();
        const app = (params.app || '').trim();

        // 1) `since` is REQUIRED and MUST be ISO-8601 with offset.
        if (!since) {
            return response.badRequest(
                "Query parameter 'since' is required (ISO-8601 timestamp).",
                { parameter: 'since' },
            );
        }
        if (!isIso8601(since)) {
            return response.badRequest(
                "Query parameter 'since' must be a valid ISO-8601 timestamp " +
                    "with an explicit timezone offset (e.g. '2025-01-31T14:23:45Z').",
                { parameter: 'since', received: since },
            );
        }

        // 2) `app` is REQUIRED and MUST be one of the registered Sub_Apps.
        if (!app) {
            return response.badRequest(
                "Query parameter 'app' is required (Sub_App identifier).",
                { parameter: 'app' },
            );
        }
        if (!ALLOWED_SUB_APPS.has(app)) {
            return response.badRequest(
                `Unknown Sub_App '${app}'. Expected one of: ` +
                    `${[...ALLOWED_SUB_APPS].join(', ')}.`,
                { parameter: 'app', received: app },
            );
        }

        // 3) Delegate to the service. Recipient resolution for the
        //    requesting JWT is the caller's own user_id — until task 14
        //    wires the full Sub_App→user resolution table, the replay
        //    surface is per-user (REQ 8.2 — JWT-authenticated entry).
        try {
            const result = await getDefaultNotificationService().getReplay({
                since,
                app,
                userIds: [auth.sub],
            });

            // REQ 8.5a — empty in-window result returns next_cursor=since
            // (so the client can resume from the same point on the next
            // call without losing any pending events). When the service
            // already returned a cursor (future cursor-paginated
            // implementation), keep it; otherwise default to `since`.
            // Note: returning `null` here would force the client to choose
            // its own resume point, risking gaps if events arrive between
            // calls.
            const nextCursor =
                result.notifications.length === 0
                    ? since
                    : result.next_cursor ?? null;

            logger.info('[replay] returned', {
                user_id: auth.sub,
                app,
                since,
                count: result.notifications.length,
            });

            return response.success({
                notifications: result.notifications,
                next_cursor: nextCursor,
            });
        } catch (err) {
            // REQ 8.5a — out-of-window requests return the structured
            // `replay_window_exceeded` error. The wrapper would also
            // turn this into a 400 because `ReplayWindowExceededError`
            // extends AppError, but we surface the canonical code shape
            // explicitly here so clients can match on it without
            // depending on wrapper internals.
            if (err instanceof ReplayWindowExceededError) {
                return response.error(
                    err.statusCode,
                    err.code, // 'replay_window_exceeded'
                    err.message,
                    {
                        since: err.since,
                        replay_window_days: err.windowDays,
                    },
                );
            }
            throw err;
        }
    },
);
