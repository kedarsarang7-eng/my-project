// ============================================================================
// DEACTIVATE STAFF HANDLER - PATCH /staff/{staffId}/deactivate
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, optionsResponse } from '../middleware/errorHandler';
import { validateParams, staffIdParamSchema } from '../middleware/validator';
import { assertOwnerOrAdmin, assertPumpAccess, extractAuthContext } from '../utils/auth';
import { getItem, updateItem } from '../utils/dynamodb';
import { adminDisableUser } from '../utils/cognito';
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

  // Verify authorization - only owners/admins can deactivate
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

  // Disable in Cognito
  await adminDisableUser(params.staffId);

  // Update in DynamoDB
  const now = new Date().toISOString();
  await updateItem<StaffProfile>(
    TABLES.STAFF_PROFILES,
    { staffId: params.staffId, SK: 'PROFILE' },
    {
      isActive: false,
      deactivatedAt: now,
      deactivatedBy: authContext.userId,
      GSI2SK: `ACTIVE#false#DATE#${staff.createdAt}`,
    }
  );

  // Log activity
  await logActivity({
    staffId: params.staffId,
    eventType: 'DEACTIVATED',
    performedBy: authContext.userId,
    notes: 'Account deactivated by admin',
  });

  return success({
    staffId: params.staffId,
    message: 'Staff account deactivated successfully',
  });
});
