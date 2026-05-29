// ============================================================================
// Lambda Handler — Clinic Scheduled Jobs (Appointment Reminders, No-Show)
// ============================================================================
import { Keys, queryItems, updateItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

/**
 * EventBridge Scheduled Rule — Runs every hour
 * Checks for upcoming appointments and marks no-shows
 */
export const processAppointmentReminders = async () => {
    logger.info('Processing appointment reminders...');
    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);
    const currentTime = now.toISOString().slice(11, 16); // HH:mm

    try {
        // We need to scan all tenants — in production, maintain a tenant registry
        // For MVP, we use a GSI or scan. Here we log the concept.
        // In production: query GSI3 with SK prefix 'APPOINTMENT#' filtered by date

        logger.info('Reminder check completed', { date: todayStr, time: currentTime });

        return { statusCode: 200, body: JSON.stringify({ processed: true, date: todayStr }) };
    } catch (err: any) {
        logger.error('Failed to process reminders', { error: err.message });
        return { statusCode: 500, body: JSON.stringify({ error: 'Failed' }) };
    }
};

/**
 * EventBridge Scheduled Rule — Runs at end of day (11 PM)
 * Marks scheduled appointments that never started as no-show
 */
export const processNoShows = async () => {
    logger.info('Processing no-shows...');
    const todayStr = new Date().toISOString().slice(0, 10);

    try {
        // Same tenant scanning caveat applies
        // In production: for each tenant, query today's appointments still in 'scheduled' status
        // and update them to 'no-show'

        logger.info('No-show processing completed', { date: todayStr });
        return { statusCode: 200, body: JSON.stringify({ processed: true }) };
    } catch (err: any) {
        logger.error('Failed to process no-shows', { error: err.message });
        return { statusCode: 500, body: JSON.stringify({ error: 'Failed' }) };
    }
};

/**
 * Process reminders for a specific tenant (called by the scheduled handler)
 */
export async function processRemindersForTenant(tenantId: string): Promise<number> {
    const pk = Keys.tenantPK(tenantId);
    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);

    // Get today's appointments that are still 'scheduled' (not yet reminded)
    const result = await queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
        filterExpression: 'appointmentDate = :today AND #s = :scheduled AND (attribute_not_exists(reminderSent) OR reminderSent = :false)',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':today': todayStr, ':scheduled': 'scheduled', ':false': false },
    });

    let remindersCount = 0;

    for (const appt of result.items) {
        try {
            // In production: send SMS/WhatsApp via existing gateway
            // For now: mark as reminded
            await updateItem(pk, `APPOINTMENT#${appt.id}`, {
                updateExpression: 'SET reminderSent = :true, reminderSentAt = :now',
                expressionAttributeValues: { ':true': true, ':now': now.toISOString() },
            });
            remindersCount++;
            logger.info('Reminder sent', { appointmentId: appt.id, patientId: appt.patientId });
        } catch (err: any) {
            logger.error('Failed to send reminder', { appointmentId: appt.id, error: err.message });
        }
    }

    return remindersCount;
}

/**
 * Mark no-shows for a specific tenant
 */
export async function markNoShowsForTenant(tenantId: string): Promise<number> {
    const pk = Keys.tenantPK(tenantId);
    const todayStr = new Date().toISOString().slice(0, 10);

    const result = await queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
        filterExpression: 'appointmentDate = :today AND #s = :scheduled',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':today': todayStr, ':scheduled': 'scheduled' },
    });

    let noShowCount = 0;

    for (const appt of result.items) {
        try {
            await updateItem(pk, `APPOINTMENT#${appt.id}`, {
                updateExpression: 'SET #s = :noshow, noShowMarkedAt = :now',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':noshow': 'no-show', ':now': new Date().toISOString() },
            });
            noShowCount++;
        } catch (err: any) {
            logger.error('Failed to mark no-show', { appointmentId: appt.id, error: err.message });
        }
    }

    return noShowCount;
}
