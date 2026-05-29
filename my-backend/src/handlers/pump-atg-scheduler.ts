import { APIGatewayProxyResultV2 } from 'aws-lambda';
import { pollAtgReadingsAllTenants } from '../services/atg-connector.service';
import { logger } from '../utils/logger';

export async function pollAtgScheduled(): Promise<APIGatewayProxyResultV2> {
    const result = await pollAtgReadingsAllTenants();
    logger.info('ATG scheduled poll done', result);
    return {
        statusCode: 200,
        body: JSON.stringify({ success: true, data: result }),
    };
}
