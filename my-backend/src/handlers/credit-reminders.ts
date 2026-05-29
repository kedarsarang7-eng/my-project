import { APIGatewayProxyResultV2 } from 'aws-lambda';
import { runDailyCreditReminders } from '../services/credit-reminder.service';
import { logger } from '../utils/logger';

export async function runDailyCreditReminderJob(): Promise<APIGatewayProxyResultV2> {
    const result = await runDailyCreditReminders();
    logger.info('credit reminder cron done', result);
    return {
        statusCode: 200,
        body: JSON.stringify({ success: true, data: result }),
    };
}
