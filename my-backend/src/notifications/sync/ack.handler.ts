// ============================================================================
// Sub_App_Sync_Layer — Ack Handler
// ============================================================================
//
// HTTP entry for per-`notification_id` delivery acknowledgement:
//
//   POST /notifications/{id}/ack
//
// The Sub_App_Sync_Layer requires the receiving client to ack each
// delivered notification within 30 seconds; missed acks trigger a retry
// under the channel's policy (REQ 8.3, phase3-architecture §13.1).
// This handler is the HTTP entry the in-app channel calls into when
// the client confirms receipt.
//
// On success the operation is idempotent at the service layer: the
// first call sets `read_at`, subsequent calls leave it unchanged
// (REQ 4.6). We return HTTP 204 No Content per the task contract;
// the body is intentionally empty so polling clients do not waste
// bandwidth.
//
// Authentication: JWT via the existing Cognito auth middleware
// (REQ 8.2, REQ 19.1). The handler-wrapper rejects unauthenticated
// callers before this code runs.
//
// Validates: REQ 8.2, 8.3 (per-id ack), REQ 4.5, 4.6 (markAsRead).
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../middleware/handler-wrapper';
import { AuthContext } from '../../types/tenant.types';
import * as response from '../../utils/response';
import { logger } from '../../utils/logger';
import {
    getDefaultNotificationService,
    NotificationNotFoundError,
} from '../service';

// ---- Empty 204 response builder -----------------------------------------
//
// `utils/response.ts` does not export a 204 helper; we build one inline
// so the response shape stays compatible with the rest of the API
// (security headers are added by the handler-wrapper).

function noContent(): APIGatewayProxyResultV2 {
    return {
        statusCode: 204,
        headers: { 'Content-Type': 'application/json' },
        body: '',
    };
}

// ---- Handler ------------------------------------------------------------

/**
 * `POST /notifications/{id}/ack`
 *
 * Open to every authenticated user — only the Recipient of a notification
 * can ack their own copy of it. The service-layer `markAsRead` is
 * idempotent (REQ 4.6) so retries from the client are safe.
 */
export const ack = authorizedHandler(
    [],
    async (
        event: APIGatewayProxyEventV2,
        _context: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const notificationId = (event.pathParameters?.id || '').trim();

        if (!notificationId) {
            return response.badRequest(
                "Path parameter 'id' is required (notification_id).",
                { parameter: 'id' },
            );
        }

        try {
            const result = await getDefaultNotificationService().markAsRead(
                notificationId,
                auth.sub,
            );

            logger.info('[ack] markAsRead succeeded', {
                notification_id: notificationId,
                user_id: auth.sub,
                first_read: result.first_read,
            });

            return noContent();
        } catch (err) {
            // 404 if the notification does not exist; the wrapper would
            // also map this through AppError, but we surface it
            // explicitly here so the route's behaviour is visible at a
            // glance.
            if (err instanceof NotificationNotFoundError) {
                return response.notFound('Notification');
            }
            throw err;
        }
    },
);
