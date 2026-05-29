// ============================================================================
// RESET PASSWORD HANDLER - POST /staff/{staffId}/reset-password
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, optionsResponse } from '../middleware/errorHandler';
import { validateParams, staffIdParamSchema } from '../middleware/validator';
import { assertOwnerOrAdmin, assertPumpAccess, extractAuthContext } from '../utils/auth';
import { getItem } from '../utils/dynamodb';
import { adminSetUserPassword } from '../utils/cognito';
import { generateTemporaryPassword } from '../utils/idGenerator';
import { TABLES } from '../constants/tables';
import { StaffProfile, ResetPasswordResponse } from '../types/staff';
import { NotFoundError } from '../middleware/errorHandler';
import { logActivity } from './activityLog';

export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization - only owners/admins can reset passwords
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

  // Generate new temporary password
  const tempPassword = generateTemporaryPassword();

  // Set password in Cognito (permanent = false forces change on next login)
  await adminSetUserPassword(params.staffId, tempPassword, false);

  // Log activity
  await logActivity({
    staffId: params.staffId,
    eventType: 'PASSWORD_RESET',
    performedBy: authContext.userId,
    notes: 'Password reset by admin',
  });

  const response: ResetPasswordResponse = {
    staffId: params.staffId,
    temporaryPassword: tempPassword,
    message: 'Password reset successfully. Staff must change password on next login.',
  };

  return success(response);
});
