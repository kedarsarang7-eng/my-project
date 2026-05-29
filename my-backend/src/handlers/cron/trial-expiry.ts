// ============================================================================
// Trial Expiry Cron Handler — EventBridge Daily Trigger
// ============================================================================
// Processes expired trials and sends notification reminders.
// Triggered daily at 00:00 UTC by EventBridge.
//
// Endpoints:
//   - GET /cron/trial-expiry (called by EventBridge)
//   - POST /cron/trial-notify (manual trigger for testing)
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { processExpiredTrials, getTrialsForNotification } from '../../services/trial.service';
import { logger } from '../../utils/logger';
import * as response from '../../utils/response';

/**
 * Daily cron handler - processes expired trials
 * Triggered by EventBridge schedule
 */
export async function handler(
    event: APIGatewayProxyEventV2,
    _context: Context
): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || crypto.randomUUID();
    logger.info('Trial expiry cron started', { correlationId });

    try {
        // Process expired trials
        const result = await processExpiredTrials();

        // Check for notification thresholds (7, 3, 1 days)
        const notifications7Days = await getTrialsForNotification(7);
        const notifications3Days = await getTrialsForNotification(3);
        const notifications1Day = await getTrialsForNotification(1);

        // Log notification targets (actual sending handled by separate notification service)
        if (notifications7Days.length > 0) {
            logger.info('Trial expiry notifications: 7 days', {
                count: notifications7Days.length,
                tenants: notifications7Days.map((t) => t.tenantId),
            });
        }

        if (notifications3Days.length > 0) {
            logger.info('Trial expiry notifications: 3 days', {
                count: notifications3Days.length,
                tenants: notifications3Days.map((t) => t.tenantId),
            });
        }

        if (notifications1Day.length > 0) {
            logger.info('Trial expiry notifications: 1 day', {
                count: notifications1Day.length,
                tenants: notifications1Day.map((t) => t.tenantId),
            });
        }

        logger.info('Trial expiry cron completed', {
            correlationId,
            processed: result.processed,
            downgraded: result.downgraded,
            errors: result.errors,
            notifications7d: notifications7Days.length,
            notifications3d: notifications3Days.length,
            notifications1d: notifications1Day.length,
        });

        return response.success({
            success: true,
            processed: result.processed,
            downgraded: result.downgraded,
            errors: result.errors,
            notifications: {
                '7days': notifications7Days.length,
                '3days': notifications3Days.length,
                '1day': notifications1Day.length,
            },
            correlationId,
        });
    } catch (err) {
        logger.error('Trial expiry cron failed', {
            correlationId,
            error: (err as Error).message,
        });

        return response.error(500, 'CRON_FAILED', 'Trial expiry processing failed');
    }
}

/**
 * Manual trigger for testing notification system
 */
export async function notifyHandler(
    event: APIGatewayProxyEventV2,
    _context: Context
): Promise<APIGatewayProxyResultV2> {
    try {
        const days = parseInt(event.queryStringParameters?.days || '7', 10);
        const trials = await getTrialsForNotification(days);

        return response.success({
            days,
            count: trials.length,
            trials,
        });
    } catch (err) {
        logger.error('Trial notify handler failed', { error: (err as Error).message });
        return response.error(500, 'NOTIFY_FAILED', 'Failed to get trial notifications');
    }
}
