// ============================================================================
// STAFF CHECK-IN HANDLER - POST /staff/{staffId}/check-in
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { z } from 'zod';
import { getItem, putItem, queryItems, updateItem, transactWriteItems } from '../utils/dynamodb';
import { generateULID, getCurrentTimestamp, getCurrentDate, calculateTimeDifferenceMinutes } from '../utils/ulid';
import { TABLES, INDEXES, GRACE_PERIOD_MINUTES, SCHEDULED_HOURS } from '../constants/tables';
import { extractClaims, isSelfOrManager, unauthorizedResponse, forbiddenResponse, errorResponse, CORS_HEADERS } from '../utils/rbac';
import { ErrorCodes } from '../constants/errorCodes';
import { broadcastToStation, getWsEndpoint } from '../utils/websocketBroadcast';
import type { StaffShift, StaffAttendance, StaffAlert, StaffProfile, ShiftIdempotencyRecord } from '../types/attendance';

// Validation schema
const checkInSchema = z.object({
  stationId: z.string().min(1),
  scanImageBase64: z.string().optional(),
  scanTimestamp: z.string().datetime(),
  deviceInfo: z.object({
    model: z.string(),
    osVersion: z.string(),
    appVersion: z.string(),
  }),
  idCardNumber: z.string().optional(),
  // p28(a): client-generated UUID for idempotent retries. Optional so that
  // older app versions remain compatible (they get the previous behaviour).
  clientRequestId: z.string().uuid().optional(),
});

const IDEMPOTENCY_TTL_SECONDS = 24 * 60 * 60; // 24 h

// CORS headers
const corsHeaders = {
  ...CORS_HEADERS,
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  // Handle CORS preflight
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

    // Parse and validate body
    const body = JSON.parse(event.body || '{}');
    const validated = checkInSchema.parse(body);

    // Get staff profile
    const staff = await getItem<StaffProfile>(TABLES.STAFF_PROFILES, {
      staffId,
      SK: 'PROFILE',
    });

    if (!staff) {
      return errorResponse(404, 'Staff not found', ErrorCodes.STAFF_NOT_FOUND);
    }

    // p28(c) RBAC: only the staff member themselves or a manager+ may check in
    const claims = extractClaims(event);
    if (!claims) return unauthorizedResponse();
    if (!isSelfOrManager(claims, staffId)) {
      return forbiddenResponse('You can only check in for yourself');
    }

    if (!staff.isActive) {
      return errorResponse(403, 'Account is inactive. Contact manager.', ErrorCodes.ACCOUNT_INACTIVE);
    }

    // p28(a) Step 1: If client sent a clientRequestId, check the idempotency
    // sentinel FIRST (cheap point-read) before running the expensive GSI query.
    // This guarantees that concurrent retries of the same logical request all
    // resolve to the same shiftId without creating duplicate shifts.
    if (validated.clientRequestId) {
      const idempKey = `IDEMP#${validated.clientRequestId}`;
      const existing = await getItem<ShiftIdempotencyRecord>(TABLES.STAFF_SHIFTS, {
        PK: `STAFF#${staffId}`,
        SK: idempKey,
      });
      if (existing) {
        // Replay: fetch the real shift row and return its data as 200.
        const replayShift = await getItem<StaffShift>(TABLES.STAFF_SHIFTS, {
          PK: `STAFF#${staffId}`,
          SK: `SHIFT#${existing.shiftId}`,
        });
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: JSON.stringify({
            shiftId: existing.shiftId,
            checkInTime: replayShift?.checkInTime ?? existing.createdAt,
            isLate: replayShift?.isLate ?? false,
            lateByMinutes: replayShift?.lateMinutes ?? 0,
            message: 'Check-in already recorded (idempotent replay).',
            status: 'OPEN',
            staffName: staff.fullName,
            scheduledEnd: replayShift?.scheduledEnd ?? staff.shiftTiming?.end ?? '17:00',
            idempotentReplay: true,
          }),
        };
      }
    }

    // Check for existing open shift (prevent double check-in for legacy clients
    // that do not send clientRequestId)
    const openShifts = await queryItems<StaffShift>(
      TABLES.STAFF_SHIFTS,
      {
        indexName: INDEXES.GSI2,
        keyConditionExpression: 'GSI2PK = :stationId AND begins_with(GSI2SK, :status)',
        expressionAttributeValues: {
          ':stationId': `STATION#${validated.stationId}`,
          ':status': 'STATUS#OPEN#',
        },
        filterExpression: 'staffId = :staffId',
      }
    );

    const existingOpenShift = openShifts.items.find(s => s.staffId === staffId);
    if (existingOpenShift) {
      return errorResponse(409, 'Shift already active', ErrorCodes.SHIFT_ALREADY_ACTIVE, {
        shiftId: existingOpenShift.shiftId,
        checkInTime: existingOpenShift.checkInTime,
        message: `You have an active shift since ${existingOpenShift.checkInTime}`,
      });
    }

    // Calculate if late
    const now = new Date();
    const scheduledStart = staff.shiftTiming?.start || '09:00';
    const scheduledEnd = staff.shiftTiming?.end || '17:00';
    
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    const lateMinutes = calculateTimeDifferenceMinutes(scheduledStart, currentTime);
    const isLate = lateMinutes > GRACE_PERIOD_MINUTES;

    // Generate shift ID
    const shiftId = generateULID();
    const timestamp = getCurrentTimestamp();
    const date = getCurrentDate();

    // Store scan image to S3 if provided (simplified - would use S3 SDK)
    const scanImageS3Key = validated.scanImageBase64 
      ? `scans/${validated.stationId}/${date}/${staffId}/${timestamp}-${shiftId}.jpg`
      : undefined;

    // Create shift record
    const shift: StaffShift = {
      PK: `STAFF#${staffId}`,
      SK: `SHIFT#${shiftId}`,
      GSI1PK: `STATION#${validated.stationId}`,
      GSI1SK: `DATE#${date}#START#${currentTime}`,
      GSI2PK: `STATION#${validated.stationId}`,
      GSI2SK: `STATUS#OPEN#DATE#${date}`,
      shiftId,
      staffId,
      stationId: validated.stationId,
      status: 'OPEN',
      checkInTime: timestamp,
      scheduledStart,
      scheduledEnd,
      scanImageS3Key,
      totalHours: 0,
      overtimeHours: 0,
      isLate,
      lateMinutes: isLate ? lateMinutes : 0,
      isOvertime: false,
      totalPetrolLitres: 0,
      totalDieselLitres: 0,
      totalSalesAmount: 0,
      transactionCount: 0,
      createdAt: timestamp,
      updatedAt: timestamp,
      ttl: Math.floor(Date.now() / 1000) + 90 * 24 * 60 * 60, // 90 days
    };

    // Create/Update attendance record
    const attendance: StaffAttendance = {
      PK: `STAFF#${staffId}`,
      SK: `DATE#${date}`,
      GSI1PK: `STATION#${validated.stationId}`,
      GSI1SK: `DATE#${date}#STATUS#${isLate ? 'LATE' : 'PRESENT'}`,
      staffId,
      stationId: validated.stationId,
      date,
      status: isLate ? 'LATE' : 'PRESENT',
      checkInTime: timestamp,
      shiftId,
      hoursWorked: 0,
      overtimeHours: 0,
      isLate,
      lateMinutes: isLate ? lateMinutes : 0,
      scheduledStart,
      scheduledEnd,
      markedBy: 'SYSTEM',
      createdAt: timestamp,
      updatedAt: timestamp,
    };

    // p28(a) Step 2: Write shift + attendance (+ optional idempotency sentinel)
    // atomically so that a Lambda timeout or client retry can never produce a
    // second open shift for the same logical check-in.
    if (validated.clientRequestId) {
      const idempRecord: ShiftIdempotencyRecord = {
        PK: `STAFF#${staffId}`,
        SK: `IDEMP#${validated.clientRequestId}`,
        recordType: 'SHIFT_CHECKIN_IDEMP',
        clientRequestId: validated.clientRequestId,
        shiftId,
        stationId: validated.stationId,
        createdAt: timestamp,
        ttl: Math.floor(Date.now() / 1000) + IDEMPOTENCY_TTL_SECONDS,
      };

      try {
        await transactWriteItems({
          TransactItems: [
            {
              // Sentinel: fails the whole transaction if this clientRequestId
              // was already committed (race-condition guard).
              Put: {
                TableName: TABLES.STAFF_SHIFTS,
                Item: idempRecord,
                ConditionExpression: 'attribute_not_exists(PK)',
              },
            },
            {
              Put: {
                TableName: TABLES.STAFF_SHIFTS,
                Item: shift,
              },
            },
            {
              Put: {
                TableName: TABLES.STAFF_ATTENDANCE,
                Item: attendance,
              },
            },
          ],
        });
      } catch (txErr: unknown) {
        // If the idempotency sentinel already exists another concurrent request
        // just committed the same clientRequestId. Replay the result.
        const errName = txErr instanceof Error ? txErr.name : '';
        if (errName === 'TransactionCanceledException') {
          const idempKey = `IDEMP#${validated.clientRequestId}`;
          const existing = await getItem<ShiftIdempotencyRecord>(TABLES.STAFF_SHIFTS, {
            PK: `STAFF#${staffId}`,
            SK: idempKey,
          });
          if (existing) {
            const replayShift = await getItem<StaffShift>(TABLES.STAFF_SHIFTS, {
              PK: `STAFF#${staffId}`,
              SK: `SHIFT#${existing.shiftId}`,
            });
            return {
              statusCode: 200,
              headers: corsHeaders,
              body: JSON.stringify({
                shiftId: existing.shiftId,
                checkInTime: replayShift?.checkInTime ?? timestamp,
                isLate: replayShift?.isLate ?? false,
                lateByMinutes: replayShift?.lateMinutes ?? 0,
                message: 'Check-in already recorded (idempotent replay).',
                status: 'OPEN',
                staffName: staff.fullName,
                scheduledEnd: replayShift?.scheduledEnd ?? scheduledEnd,
                idempotentReplay: true,
              }),
            };
          }
        }
        // Not an idempotency conflict — re-throw for the outer catch.
        throw txErr;
      }
    } else {
      // Legacy path: no clientRequestId — use individual puts (original behaviour).
      await putItem(TABLES.STAFF_SHIFTS, shift);
      await putItem(TABLES.STAFF_ATTENDANCE, attendance);
    }

    // Create alert if late
    if (isLate) {
      const alertId = generateULID();
      const alert: StaffAlert = {
        PK: `STAFF#${staffId}`,
        SK: `ALERT#${timestamp}#${alertId}`,
        GSI1PK: `STATION#${validated.stationId}`,
        GSI1SK: `TYPE#LATE_CHECKIN#DATE#${date}`,
        alertId,
        staffId,
        stationId: validated.stationId,
        type: 'LATE_CHECKIN',
        severity: lateMinutes > 30 ? 'HIGH' : 'MEDIUM',
        message: `${staff.fullName} checked in ${lateMinutes} minutes late`,
        shiftId,
        date,
        isRead: false,
        notifiedVia: ['PUSH'],
        createdAt: timestamp,
        ttl: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60, // 30 days
      };

      await putItem(TABLES.STAFF_ALERTS, alert);
      
      // TODO: Send SNS notification to owner
    }

    // p28(b): Broadcast STAFF_CHECKED_IN to all station connections (fire-and-forget)
    const wsEndpoint = getWsEndpoint();
    if (wsEndpoint) {
      broadcastToStation(validated.stationId, wsEndpoint, {
        type: 'STAFF_CHECKED_IN',
        payload: {
          shiftId,
          staffId,
          staffName: staff.fullName,
          stationId: validated.stationId,
          checkInTime: timestamp,
          isLate,
        },
      }).catch((err) => console.error('WS broadcast error (checkIn):', err));
    }

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        shiftId,
        checkInTime: timestamp,
        isLate,
        lateByMinutes: isLate ? lateMinutes : 0,
        message: isLate 
          ? `Checked in successfully. You are ${lateMinutes} minutes late.` 
          : 'Checked in successfully. Have a great shift!',
        status: 'OPEN',
        staffName: staff.fullName,
        scheduledEnd,
      }),
    };

  } catch (error) {
    console.error('Check-in error:', error);
    
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
