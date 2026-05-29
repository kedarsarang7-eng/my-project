// ============================================================================
// SUBMIT LEAVE REQUEST - POST /staff/{staffId}/leave
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { z } from 'zod';
import { putItem, queryItems, getItem } from '../utils/dynamodb';
import { generateULID, getCurrentTimestamp } from '../utils/ulid';
import { TABLES, INDEXES } from '../constants/tables';
import { extractClaims, isSelfOrManager, unauthorizedResponse, forbiddenResponse, errorResponse, CORS_HEADERS } from '../utils/rbac';
import { ErrorCodes } from '../constants/errorCodes';
import { broadcastToStation, getWsEndpoint } from '../utils/websocketBroadcast';
import type { StaffLeave, StaffProfile, StaffAttendance } from '../types/attendance';

const leaveSchema = z.object({
  leaveType: z.enum(['CASUAL', 'SICK', 'EARNED', 'EMERGENCY']),
  fromDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  toDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  reason: z.string().min(1).max(500),
});

const corsHeaders = {
  ...CORS_HEADERS,
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  try {
    const staffId = event.pathParameters?.staffId;
    if (!staffId) {
      return errorResponse(400, 'Staff ID is required', ErrorCodes.MISSING_PARAM);
    }

    const body = JSON.parse(event.body || '{}');
    const validated = leaveSchema.parse(body);

    // p28(c) RBAC: staff can only submit leave for themselves; manager+ can act on behalf
    const claims = extractClaims(event);
    if (!claims) return unauthorizedResponse();
    if (!isSelfOrManager(claims, staffId)) {
      return forbiddenResponse('You can only submit leave requests for yourself');
    }

    // Get staff profile
    const staff = await getItem<StaffProfile>(TABLES.STAFF_PROFILES, {
      staffId,
      SK: 'PROFILE',
    });

    if (!staff) {
      return errorResponse(404, 'Staff not found', ErrorCodes.STAFF_NOT_FOUND);
    }

    // Validate dates
    const fromDate = new Date(validated.fromDate);
    const toDate = new Date(validated.toDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (fromDate < today) {
      return errorResponse(400, 'From date cannot be in the past', ErrorCodes.VALIDATION_FAILED);
    }

    if (toDate < fromDate) {
      return errorResponse(400, 'To date must be after from date', ErrorCodes.VALIDATION_FAILED);
    }

    // Calculate days
    const diffTime = Math.abs(toDate.getTime() - fromDate.getTime());
    const days = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;

    if (days > 30) {
      return errorResponse(400, 'Leave cannot exceed 30 days', ErrorCodes.VALIDATION_FAILED);
    }

    // Check for overlapping approved leaves
    const existingLeaves = await queryItems<StaffLeave>(TABLES.STAFF_LEAVE, {
      keyConditionExpression: 'PK = :staffId',
      filterExpression: '#status = :approved AND ((fromDate <= :toDate AND toDate >= :fromDate))',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: {
        ':staffId': `STAFF#${staffId}`,
        ':approved': 'APPROVED',
        ':fromDate': validated.fromDate,
        ':toDate': validated.toDate,
      },
    });

    if (existingLeaves.items.length > 0) {
      return errorResponse(409, 'Overlapping leave request exists', ErrorCodes.LEAVE_OVERLAP, {
        existingLeave: existingLeaves.items[0],
      });
    }

    // Check for existing pending request for same dates
    const pendingLeaves = await queryItems<StaffLeave>(TABLES.STAFF_LEAVE, {
      keyConditionExpression: 'PK = :staffId',
      filterExpression: '#status = :pending AND fromDate = :fromDate AND toDate = :toDate',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: {
        ':staffId': `STAFF#${staffId}`,
        ':pending': 'PENDING',
        ':fromDate': validated.fromDate,
        ':toDate': validated.toDate,
      },
    });

    if (pendingLeaves.items.length > 0) {
      return errorResponse(409, 'Duplicate leave request already pending', ErrorCodes.LEAVE_DUPLICATE_PENDING, {
        leaveId: pendingLeaves.items[0].leaveId,
      });
    }

    // Create leave request
    const leaveId = generateULID();
    const timestamp = getCurrentTimestamp();
    const stationId = staff.petrolPumpId;

    const leave: StaffLeave = {
      PK: `STAFF#${staffId}`,
      SK: `LEAVE#${leaveId}`,
      GSI1PK: `STATION#${stationId}`,
      GSI1SK: `STATUS#PENDING#DATE#${validated.fromDate}`,
      leaveId,
      staffId,
      stationId,
      leaveType: validated.leaveType,
      fromDate: validated.fromDate,
      toDate: validated.toDate,
      days,
      reason: validated.reason,
      status: 'PENDING',
      appliedAt: timestamp,
      updatedAt: timestamp,
    };

    await putItem(TABLES.STAFF_LEAVE, leave);

    // p28(b): Broadcast LEAVE_REQUESTED to station connections (fire-and-forget)
    const wsEndpoint = getWsEndpoint();
    if (wsEndpoint && stationId) {
      broadcastToStation(stationId, wsEndpoint, {
        type: 'LEAVE_REQUESTED',
        payload: {
          leaveId,
          staffId,
          staffName: staff.fullName,
          stationId,
          leaveType: validated.leaveType,
          fromDate: validated.fromDate,
          toDate: validated.toDate,
          days,
          reason: validated.reason,
        },
      }).catch((err) => console.error('WS broadcast error (submitLeave):', err));
    }

    return {
      statusCode: 201,
      headers: corsHeaders,
      body: JSON.stringify({
        leaveId,
        status: 'PENDING',
        days,
        message: `Leave request submitted for ${days} days. Awaiting approval.`,
      }),
    };

  } catch (error) {
    console.error('Leave submission error:', error);
    
    if (error instanceof z.ZodError) {
      return errorResponse(400, 'Validation failed', ErrorCodes.VALIDATION_FAILED, {
        details: error.errors,
      });
    }

    return errorResponse(500, 'Internal server error', ErrorCodes.INTERNAL_ERROR, {
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};
