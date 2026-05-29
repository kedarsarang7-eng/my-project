// ============================================================================
// REACTIVATE STAFF HANDLER - PATCH /staff/{staffId}/reactivate
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, optionsResponse } from '../middleware/errorHandler';
import { validateParams, staffIdParamSchema } from '../middleware/validator';
import { assertOwnerOrAdmin, assertPumpAccess, extractAuthContext } from '../utils/auth';
import { getItem, updateItem } from '../utils/dynamodb';
import { adminEnableUser } from '../utils/cognito';
import { TABLES } from '../constants/tables';
import { StaffProfile } from '../types/staff';
import { NotFoundError } from '../middleware/errorHandler';
import { logActivity } from './activityLog';

export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization - only owners/admins can reactivate
  const authContext = assertOwnerOrAdmin(event);

  // Validate path parameters
  const params = validateParams(staffIdParamSchema, event.pathParameters || {});

  // Get existing staff
  const staff = await getItem<StaffProfile>(
    TABLES.STAFF_PROFILES,
    { staffId: params.staffId, SK: 'PROFILE' }
  );

  if (!staff) {
    throw new NotFoundError(`Staff with ID ${params.staffId} not found`);
  }

  // Verify pump access
  assertPumpAccess(event, staff.petrolPumpId);

  // Enable in Cognito
  await adminEnableUser(params.staffId);

  // Update in DynamoDB
  const now = new Date().toISOString();
  await updateItem<StaffProfile>(
    TABLES.STAFF_PROFILES,
    { staffId: params.staffId, SK: 'PROFILE' },
    {
      isActive: true,
      reactivatedAt: now,
      reactivatedBy: authContext.userId,
      GSI2SK: `ACTIVE#true#DATE#${staff.createdAt}`,
    }
  );

  // Log activity
  await logActivity({
    staffId: params.staffId,
    eventType: 'REACTIVATED',
    performedBy: authContext.userId,
    notes: 'Account reactivated by admin',
  });

  return success({
    staffId: params.staffId,
    message: 'Staff account reactivated successfully',
  });
});
