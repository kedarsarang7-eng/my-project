// ============================================================================
// PROCESS LEAVE REQUEST (Owner) - PUT /owner/leave/{leaveId}
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { z } from 'zod';
import { getItem, updateItem, putItem } from '../utils/dynamodb';
import { getCurrentTimestamp } from '../utils/ulid';
import { TABLES } from '../constants/tables';
import { extractClaims, hasMinimumRole, ROLES, unauthorizedResponse, forbiddenResponse, errorResponse, CORS_HEADERS } from '../utils/rbac';
import { ErrorCodes } from '../constants/errorCodes';
import { broadcastToStation, getWsEndpoint } from '../utils/websocketBroadcast';
import type { StaffLeave, StaffAttendance } from '../types/attendance';

const processSchema = z.object({
  action: z.enum(['APPROVE', 'REJECT']),
  remarks: z.string().max(500).optional(),
});

const corsHeaders = {
  ...CORS_HEADERS,
  'Access-Control-Allow-Methods': 'PUT,OPTIONS',
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
    const leaveId = event.pathParameters?.leaveId;
    if (!leaveId) {
      return errorResponse(400, 'Leave ID is required', ErrorCodes.MISSING_PARAM);
    }

    // p28(c) RBAC: only manager or admin may process leave requests
    const claims = extractClaims(event);
    if (!claims) return unauthorizedResponse();
    if (!hasMinimumRole(claims, ROLES.MANAGER)) {
      return forbiddenResponse('Only managers and admins can approve or reject leave requests');
    }
    const ownerId = claims.sub;

    const body = JSON.parse(event.body || '{}');
    const validated = processSchema.parse(body);

    // Find leave request by scanning (in production, use GSI)
    // For now, we need staffId to construct PK
    // This is a simplified version - in production would use GSI on leaveId
    const staffId = event.queryStringParameters?.staffId;
    if (!staffId) {
      return errorResponse(400, 'staffId query parameter required', ErrorCodes.MISSING_PARAM);
    }

    const leave = await getItem<StaffLeave>(TABLES.STAFF_LEAVE, {
      PK: `STAFF#${staffId}`,
      SK: `LEAVE#${leaveId}`,
    });

    if (!leave) {
      return errorResponse(404, 'Leave request not found', ErrorCodes.LEAVE_NOT_FOUND);
    }

    if (leave.status !== 'PENDING') {
      return errorResponse(409, 'Leave request already processed', ErrorCodes.LEAVE_ALREADY_PROCESSED, {
        currentStatus: leave.status,
      });
    }

    const timestamp = getCurrentTimestamp();
    const newStatus = validated.action === 'APPROVE' ? 'APPROVED' : 'REJECTED';

    // Update leave record
    await updateItem<StaffLeave>(
      TABLES.STAFF_LEAVE,
      { PK: `STAFF#${staffId}`, SK: `LEAVE#${leaveId}` },
      {
        status: newStatus,
        approvedBy: ownerId,
        approvedAt: timestamp,
        rejectionReason: validated.action === 'REJECT' ? validated.remarks : undefined,
        updatedAt: timestamp,
        GSI1SK: `STATUS#${newStatus}#DATE#${leave.fromDate}`,
      }
    );

    // If approved, mark attendance as LEAVE for those days
    if (validated.action === 'APPROVE') {
      const fromDate = new Date(leave.fromDate);
      const toDate = new Date(leave.toDate);

      for (let d = new Date(fromDate); d <= toDate; d.setDate(d.getDate() + 1)) {
        const dateStr = d.toISOString().split('T')[0];
        
        const attendance: StaffAttendance = {
          PK: `STAFF#${staffId}`,
          SK: `DATE#${dateStr}`,
          GSI1PK: `STATION#${leave.stationId}`,
          GSI1SK: `DATE#${dateStr}#STATUS#LEAVE`,
          staffId,
          stationId: leave.stationId,
          date: dateStr,
          status: 'LEAVE',
          hoursWorked: 0,
          overtimeHours: 0,
          isLate: false,
          lateMinutes: 0,
          scheduledStart: '09:00',
          scheduledEnd: '17:00',
          markedBy: 'SYSTEM',
          notes: `Leave: ${leave.leaveType}`,
          createdAt: timestamp,
          updatedAt: timestamp,
        };

        await putItem(TABLES.STAFF_ATTENDANCE, attendance);
      }
    }

    // p28(b): Broadcast LEAVE_PROCESSED to station connections (fire-and-forget)
    const wsEndpoint = getWsEndpoint();
    if (wsEndpoint && leave.stationId) {
      broadcastToStation(leave.stationId, wsEndpoint, {
        type: 'LEAVE_PROCESSED',
        payload: {
          leaveId,
          staffId,
          stationId: leave.stationId,
          action: validated.action,
          newStatus,
          processedBy: ownerId,
          remarks: validated.remarks,
          fromDate: leave.fromDate,
          toDate: leave.toDate,
        },
      }).catch((err) => console.error('WS broadcast error (processLeave):', err));
    }

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        leaveId,
        status: newStatus,
        message: validated.action === 'APPROVE' 
          ? `Leave approved for ${leave.days} days` 
          : 'Leave request rejected',
        processedBy: ownerId,
        processedAt: timestamp,
      }),
    };

  } catch (error) {
    console.error('Leave processing error:', error);
    
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
