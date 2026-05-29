// ============================================================================
// Grace Period Cron Handler — Daily Processing via EventBridge
// ============================================================================
// Triggered daily at 9:00 AM IST to:
// 1. Process all subscriptions in grace period
// 2. Auto-downgrade expired trials
// 3. Send notifications for approaching deadlines
// ============================================================================

import { ScheduledHandler } from 'aws-lambda';
import { processDailyGracePeriods, sendGracePeriodNotification } from '../../services/grace-period.service';
import { logger } from '../../utils/logger';

export const handler: ScheduledHandler = async (_event) => {
    const startTime = Date.now();

    try {
        logger.info('Starting daily grace period processing', {
            timestamp: new Date().toISOString(),
        });

        // Process grace periods and expired trials
        const actions = await processDailyGracePeriods();

        // Send notifications for actions taken
        for (const action of actions) {
            if (action.notificationRequired) {
                await sendNotification(action);
            }
        }

        const duration = Date.now() - startTime;

        logger.info('Grace period processing complete', {
            duration: `${duration}ms`,
            actionsProcessed: actions.length,
        });

    } catch (error) {
        logger.error('Grace period cron failed', { error });
        throw error; // Re-throw to trigger Lambda retry and CloudWatch alarm
    }
};

async function sendNotification(action: { tenantId: string; action: string; newStatus: string }): Promise<void> {
    let notificationType: 'PAYMENT_FAILED' | 'GRACE_PERIOD_START' | 'GRACE_PERIOD_WARNING' | 'FULL_LOCK' | 'TRIAL_EXPIRY';
    let message: string;

    switch (action.action) {
        case 'WARN':
            notificationType = 'PAYMENT_FAILED';
            message = 'Payment failed. Please update your payment method within 7 days to avoid service interruption.';
            break;
        case 'PARTIAL_LOCK':
            notificationType = 'GRACE_PERIOD_START';
            message = 'Your account is now in read-only mode. Please complete payment to restore full access.';
            break;
        case 'FULL_LOCK':
            notificationType = 'FULL_LOCK';
            message = 'Your subscription has expired. Please renew immediately to continue using all features.';
            break;
        default:
            return; // No notification needed
    }

    await sendGracePeriodNotification({
        tenantId: action.tenantId,
        type: notificationType,
        message,
    });
}
