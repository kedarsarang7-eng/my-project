// ============================================================================
// LIST STAFF HANDLER - GET /staff
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, optionsResponse } from '../middleware/errorHandler';
import { validateQuery } from '../middleware/validator';
import { listStaffQuerySchema } from '../middleware/validator';
import { extractAuthContext, assertRole, AuthContext } from '../utils/auth';
import { queryItems } from '../utils/dynamodb';
import { TABLES, INDEXES } from '../constants/tables';
import { StaffListItem, StaffListResponse } from '../types/staff';

export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization - owners, managers, or supervisors can list staff
  const authContext = assertRole(event, ['owner', 'admin', 'manager', 'supervisor']);

  // Validate query parameters
  const query = validateQuery(listStaffQuerySchema, event.queryStringParameters || {}) as {
    role?: string;
    isActive?: boolean;
    limit?: number;
    lastKey?: string;
  };

  // Get petrol pump ID from query or auth context
  const pumpId = authContext.petrolPumpId || 'default';

  // Build query parameters
  const keyConditionExpression = 'GSI1PK = :pumpId';
  const expressionAttributeValues: Record<string, any> = {
    ':pumpId': `PUMP#${pumpId}`
  };

  // Add role filter if specified
  let filterExpression: string | undefined;
  const expressionAttributeNames: Record<string, string> = {};

  if (query.role) {
    filterExpression = 'role = :role';
    expressionAttributeValues[':role'] = query.role;
  }

  if (query.isActive !== undefined) {
    const activeFilter = 'isActive = :isActive';
    filterExpression = filterExpression 
      ? `${filterExpression} AND ${activeFilter}` 
      : activeFilter;
    expressionAttributeValues[':isActive'] = query.isActive;
  }

  // Execute query using GSI1
  const result = await queryItems<StaffListItem>(
    TABLES.STAFF_PROFILES,
    {
      indexName: INDEXES.GSI1,
      keyConditionExpression,
      filterExpression,
      expressionAttributeNames: Object.keys(expressionAttributeNames).length > 0 
        ? expressionAttributeNames 
        : undefined,
      expressionAttributeValues,
      limit: query.limit || 20,
      exclusiveStartKey: query.lastKey 
        ? JSON.parse(Buffer.from(query.lastKey, 'base64').toString()) 
        : undefined
    }
  );

  // Map to list items
  const staff: StaffListItem[] = result.items.map(item => ({
    staffId: item.staffId,
    fullName: item.fullName,
    role: item.role,
    phoneNumber: item.phoneNumber,
    email: item.email,
    isActive: item.isActive,
    profilePhotoUrl: item.profilePhotoUrl,
    joiningDate: item.joiningDate,
    lastLoginAt: item.lastLoginAt
  }));

  // Build pagination info
  const lastKey = result.lastKey 
    ? Buffer.from(JSON.stringify(result.lastKey)).toString('base64')
    : undefined;

  const response: StaffListResponse = {
    staff,
    pagination: {
      limit: query.limit || 20,
      lastKey,
      hasMore: !!result.lastKey
    }
  };

  return success(response);
});
