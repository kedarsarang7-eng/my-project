// ============================================================================
// GET STAFF BY ID HANDLER - GET /staff/{staffId}
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, error, optionsResponse } from '../middleware/errorHandler';
import { validateParams, staffIdParamSchema } from '../middleware/validator';
import { extractAuthContext, assertRole, assertPumpAccess } from '../utils/auth';
import { getItem } from '../utils/dynamodb';
import { TABLES } from '../constants/tables';
import { StaffProfile } from '../types/staff';
import { NotFoundError } from '../middleware/errorHandler';

export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization
  const authContext = assertRole(event, ['owner', 'admin', 'manager', 'supervisor']);

  // Validate path parameters
  const params = validateParams(staffIdParamSchema, event.pathParameters || {});

  // Get staff from DynamoDB
  const staff = await getItem<StaffProfile>(
    TABLES.STAFF_PROFILES,
    { staffId: params.staffId, SK: 'PROFILE' }
  );

  if (!staff) {
    throw new NotFoundError(`Staff with ID ${params.staffId} not found`);
  }

  // Verify pump access
  assertPumpAccess(event, staff.petrolPumpId);

  // Sanitize and return
  const { SK, GSI1PK, GSI1SK, GSI2PK, GSI2SK, cognitoUserId, ...safeStaff } = staff as any;

  return success(safeStaff);
});
