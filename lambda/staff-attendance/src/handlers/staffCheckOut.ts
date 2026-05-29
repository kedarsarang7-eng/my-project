// ============================================================================
// STAFF CHECK-OUT HANDLER - POST /staff/{staffId}/check-out
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { z } from 'zod';
import { getItem, updateItem, queryItems } from '../utils/dynamodb';
import { calculateHoursBetween, getCurrentTimestamp, getCurrentDate } from '../utils/ulid';
import { TABLES, INDEXES, SCHEDULED_HOURS } from '../constants/tables';
import { extractClaims, isSelfOrManager, unauthorizedResponse, forbiddenResponse, errorResponse, CORS_HEADERS } from '../utils/rbac';
import { ErrorCodes } from '../constants/errorCodes';
import { broadcastToStation, getWsEndpoint } from '../utils/websocketBroadcast';
import type { StaffShift, StaffAttendance, StaffProfile } from '../types/attendance';

// Validation schema
const checkOutSchema = z.object({
  shiftId: z.string().min(1),
  stationId: z.string().min(1),
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

    // p28(c) RBAC: only the staff member themselves or a manager+ may check out
    const claims = extractClaims(event);
    if (!claims) return unauthorizedResponse();
    if (!isSelfOrManager(claims, staffId)) {
      return forbiddenResponse('You can only check out for yourself');
    }

    // Parse and validate body
    const body = JSON.parse(event.body || '{}');
    const validated = checkOutSchema.parse(body);

    // Get the shift
    const shift = await getItem<StaffShift>(TABLES.STAFF_SHIFTS, {
      PK: `STAFF#${staffId}`,
      SK: `SHIFT#${validated.shiftId}`,
    });

    if (!shift) {
      return errorResponse(404, 'Shift not found', ErrorCodes.SHIFT_NOT_FOUND);
    }

    if (shift.status !== 'OPEN') {
      return errorResponse(409, 'Shift already closed', ErrorCodes.SHIFT_ALREADY_CLOSED, {
        status: shift.status,
        checkOutTime: shift.checkOutTime,
      });
    }

    // Calculate hours
    const timestamp = getCurrentTimestamp();
    const totalHours = calculateHoursBetween(shift.checkInTime, timestamp);
    const scheduledHours = SCHEDULED_HOURS;
    const overtimeHours = totalHours > scheduledHours ? totalHours - scheduledHours : 0;
    const isOvertime = overtimeHours > 0;

    // Aggregate transactions for this shift
    const transactions = await queryItems<{
      amount: number;
      fuelType: string;
      litres: number;
    }>(
      TABLES.TRANSACTIONS,
      {
        keyConditionExpression: 'PK = :stationId AND begins_with(SK, :txnPrefix)',
        expressionAttributeValues: {
          ':stationId': `STATION#${validated.stationId}`,
          ':txnPrefix': 'TXN#',
        },
        filterExpression: 'attendantId = :staffId AND shiftId = :shiftId',
      }
    );

    let totalPetrolLitres = 0;
    let totalDieselLitres = 0;
    let totalSalesAmount = 0;
    let transactionCount = 0;

    for (const txn of transactions.items) {
      transactionCount++;
      totalSalesAmount += txn.amount || 0;
      
      if (txn.fuelType?.toLowerCase() === 'petrol') {
        totalPetrolLitres += txn.litres || 0;
      } else if (txn.fuelType?.toLowerCase() === 'diesel') {
        totalDieselLitres += txn.litres || 0;
      }
    }

    // Update shift record
    await updateItem<StaffShift>(
      TABLES.STAFF_SHIFTS,
      { PK: `STAFF#${staffId}`, SK: `SHIFT#${validated.shiftId}` },
      {
        status: 'CLOSED',
        checkOutTime: timestamp,
        totalHours,
        overtimeHours,
        isOvertime,
        totalPetrolLitres,
        totalDieselLitres,
        totalSalesAmount,
        transactionCount,
        updatedAt: timestamp,
        GSI2SK: `STATUS#CLOSED#DATE#${getCurrentDate()}`,
      }
    );

    // Update attendance record
    const date = getCurrentDate();
    await updateItem<StaffAttendance>(
      TABLES.STAFF_ATTENDANCE,
      { PK: `STAFF#${staffId}`, SK: `DATE#${date}` },
      {
        checkOutTime: timestamp,
        hoursWorked: totalHours,
        overtimeHours,
        updatedAt: timestamp,
      }
    );

    // p28(b): Broadcast STAFF_CHECKED_OUT fire-and-forget
    const wsEndpoint = getWsEndpoint();
    if (wsEndpoint) {
      broadcastToStation(validated.stationId, wsEndpoint, {
        type: 'STAFF_CHECKED_OUT',
        payload: {
          shiftId: validated.shiftId,
          staffId,
          stationId: validated.stationId,
          checkOutTime: timestamp,
          totalHours,
          totalSalesAmount,
          transactionCount,
        },
      }).catch((err) => console.error('WS broadcast error (checkOut):', err));
    }

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        shiftId: validated.shiftId,
        checkOutTime: timestamp,
        totalHours,
        overtimeHours,
        shiftSummary: {
          totalPetrolLitres,
          totalDieselLitres,
          totalSalesAmount,
          transactionCount,
        },
        message: isOvertime 
          ? `Shift ended. You worked ${totalHours} hours (${overtimeHours} hours overtime).` 
          : `Shift ended. You worked ${totalHours} hours.`,
      }),
    };

  } catch (error) {
    console.error('Check-out error:', error);
    
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
