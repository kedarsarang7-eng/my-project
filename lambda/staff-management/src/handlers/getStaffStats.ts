// ============================================================================
// GET STAFF STATS HANDLER - GET /staff/stats
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, optionsResponse } from '../middleware/errorHandler';
import { assertRole, extractPetrolPumpId } from '../utils/auth';
import { queryItems } from '../utils/dynamodb';
import { TABLES, INDEXES } from '../constants/tables';
import { StaffListItem, StaffStats, StaffRole } from '../types/staff';

export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization
  assertRole(event, ['owner', 'admin', 'manager', 'supervisor']);

  const pumpId = extractPetrolPumpId(event) || 'default';

  // Query all staff for this pump
  const result = await queryItems<StaffListItem>(
    TABLES.STAFF_PROFILES,
    {
      indexName: INDEXES.GSI1,
      keyConditionExpression: 'GSI1PK = :pumpId',
      expressionAttributeValues: {
        ':pumpId': `PUMP#${pumpId}`,
      },
    }
  );

  const staff = result.items;

  // Calculate stats
  const totalStaff = staff.length;
  const activeStaff = staff.filter(s => s.isActive).length;
  const inactiveStaff = totalStaff - activeStaff;

  // Staff by role
  const staffByRole: Record<string, number> = {};
  for (const s of staff) {
    const roleKey = s.role;
    staffByRole[roleKey] = (staffByRole[roleKey] || 0) + 1;
  }

  // Recent joins (last 30 days)
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const recentJoins = staff.filter(s => {
    if (!s.joiningDate) return false;
    try {
      const joinDate = new Date(s.joiningDate);
      return joinDate >= thirtyDaysAgo;
    } catch {
      return false;
    }
  }).length;

  const stats: StaffStats = {
    totalStaff,
    activeStaff,
    inactiveStaff,
    staffByRole,
    recentJoins,
  };

  return success(stats);
});
