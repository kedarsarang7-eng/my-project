// ============================================================================
// Lambda Handler — Businesses (Multi-Business Context) (DynamoDB)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, queryItems } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

export const getMyAccess = authorizedHandler([], async (_event, _context, auth) => {
    logger.info('Fetching accessible businesses', { tenantId: auth.tenantId, userId: auth.sub, role: auth.role });

    try {
        if (auth.role === 'owner' || auth.role === 'admin') {
            const result = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'BUSINESS#', {
                filterExpression: 'isActive = :true',
                expressionAttributeValues: { ':true': true },
            });
            return response.success({ businesses: result.items });
        } else {
            const staffResult = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'STAFF#', {
                filterExpression: 'cognitoSub = :sub AND isActive = :true',
                expressionAttributeValues: { ':sub': auth.sub, ':true': true },
            });
            const businessIds = new Set(staffResult.items.map(s => s.businessId));
            const allBiz = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'BUSINESS#', {
                filterExpression: 'isActive = :true',
                expressionAttributeValues: { ':true': true },
            });
            const accessible = allBiz.items.filter(b => businessIds.has(b.id));
            return response.success({ businesses: accessible });
        }
    } catch (error) {
        logger.error('Failed to fetch businesses', { tenantId: auth.tenantId, error: (error as Error).message });
        throw error;
    }
});
