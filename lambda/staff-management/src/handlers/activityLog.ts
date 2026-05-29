// ============================================================================
// ACTIVITY LOG HANDLER - GET /staff/{staffId}/activity
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, error, optionsResponse } from '../middleware/errorHandler';
import { queryItems, putItem } from '../utils/dynamodb';
import { TABLES } from '../constants/tables';
import { ActivityLogEntry } from '../types/staff';
import { assertRole } from '../utils/auth';

/**
 * Log an activity event
 */
export async function logActivity(params: {
  staffId: string;
  eventType: ActivityLogEntry['eventType'];
  performedBy: string;
  ipAddress?: string;
  deviceInfo?: string;
  notes?: string;
}): Promise<void> {
  const now = new Date().toISOString();
  const entry: ActivityLogEntry = {
    staffId: params.staffId,
    timestamp: now,
    eventType: params.eventType,
    performedBy: params.performedBy,
    ipAddress: params.ipAddress,
    deviceInfo: params.deviceInfo,
    notes: params.notes,
  };

  await putItem(TABLES.STAFF_ACTIVITY_LOG, {
    PK: params.staffId,
    SK: `${now}#${params.eventType}`,
    ...entry,
  });
}

/**
 * Lambda handler for listing activity log
 */
export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization
  assertRole(event, ['owner', 'admin', 'manager']);

  const staffId = event.pathParameters?.staffId;
  if (!staffId) {
    return error('Staff ID is required', 400, 'VALIDATION_ERROR');
  }

  const { limit = '50' } = event.queryStringParameters || {};

  try {
    const result = await queryItems<ActivityLogEntry>(
      TABLES.STAFF_ACTIVITY_LOG,
      {
        keyConditionExpression: 'PK = :staffId',
        expressionAttributeValues: {
          ':staffId': staffId,
        },
        limit: parseInt(limit),
        scanIndexForward: false, // Most recent first
      }
    );

    return success({
      staffId,
      activities: result.items,
      count: result.items.length,
    });
  } catch (e: any) {
    return error('Failed to load activity log', 500, 'QUERY_ERROR');
  }
});
