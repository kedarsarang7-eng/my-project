// ============================================================================
// GET STAFF DASHBOARD - GET /staff/{staffId}/dashboard?month=MM&year=YYYY
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { z } from 'zod';
import { getItem, queryItems } from '../utils/dynamodb';
import { TABLES, INDEXES } from '../constants/tables';
import { extractClaims, isSelfOrManager, unauthorizedResponse, forbiddenResponse } from '../utils/rbac';
import type { 
  StaffProfile, StaffShift, StaffAttendance, StaffAlert, StaffLeave,
  StaffDashboardOutput, CalendarDay 
} from '../types/attendance';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

const querySchema = z.object({
  month: z.string().regex(/^\d{2}$/).optional(),
  year: z.string().regex(/^\d{4}$/).optional(),
});

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
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Staff ID is required' }),
      };
    }

    // p28(c) RBAC: staff may only read their own dashboard; manager+ may read any
    const claims = extractClaims(event);
    if (!claims) return unauthorizedResponse();
    if (!isSelfOrManager(claims, staffId)) {
      return forbiddenResponse('You can only view your own dashboard');
    }

    // Parse query parameters
    const queryParams = querySchema.parse(event.queryStringParameters || {});
    const now = new Date();
    const month = queryParams.month || String(now.getMonth() + 1).padStart(2, '0');
    const year = queryParams.year || String(now.getFullYear());

    // Get staff profile
    const staff = await getItem<StaffProfile>(TABLES.STAFF_PROFILES, {
      staffId,
      SK: 'PROFILE',
    });

    if (!staff) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Staff not found' }),
      };
    }

    const stationId = staff.petrolPumpId;
    const datePrefix = `${year}-${month}`;

    // Parallel queries for dashboard data
    const [
      attendanceResult,
      shiftsResult,
      alertsResult,
      leaveResult,
    ] = await Promise.all([
      // Attendance for month
      queryItems<StaffAttendance>(TABLES.STAFF_ATTENDANCE, {
        keyConditionExpression: 'PK = :staffId AND begins_with(SK, :datePrefix)',
        expressionAttributeValues: {
          ':staffId': `STAFF#${staffId}`,
          ':datePrefix': `DATE#${datePrefix}`,
        },
      }),
      // Shifts for month (via GSI)
      queryItems<StaffShift>(TABLES.STAFF_SHIFTS, {
        indexName: INDEXES.GSI1,
        keyConditionExpression: 'GSI1PK = :stationId AND begins_with(GSI1SK, :datePrefix)',
        expressionAttributeValues: {
          ':stationId': `STATION#${stationId}`,
          ':datePrefix': `DATE#${datePrefix}`,
        },
      }),
      // Alerts for month
      queryItems<StaffAlert>(TABLES.STAFF_ALERTS, {
        keyConditionExpression: 'PK = :staffId',
        filterExpression: 'begins_with(#date, :datePrefix)',
        expressionAttributeNames: { '#date': 'date' },
        expressionAttributeValues: {
          ':staffId': `STAFF#${staffId}`,
          ':datePrefix': datePrefix,
        },
      }),
      // Leave requests
      queryItems<StaffLeave>(TABLES.STAFF_LEAVE, {
        keyConditionExpression: 'PK = :staffId',
        expressionAttributeValues: {
          ':staffId': `STAFF#${staffId}`,
        },
      }),
    ]);

    // Calculate attendance summary
    const attendance = attendanceResult.items;
    const attendanceSummary = {
      presentDays: attendance.filter(a => a.status === 'PRESENT').length,
      absentDays: attendance.filter(a => a.status === 'ABSENT').length,
      lateDays: attendance.filter(a => a.status === 'LATE').length,
      halfDays: attendance.filter(a => a.status === 'HALF_DAY').length,
      onLeaveDays: attendance.filter(a => a.status === 'LEAVE').length,
    };

    // Calculate shift summary
    const shifts = shiftsResult.items.filter(s => s.staffId === staffId);
    const totalHoursWorked = shifts.reduce((sum, s) => sum + (s.totalHours || 0), 0);
    const totalOvertimeHours = shifts.reduce((sum, s) => sum + (s.overtimeHours || 0), 0);
    
    const checkIns = shifts.filter(s => s.checkInTime).map(s => 
      new Date(s.checkInTime!).getHours() * 60 + new Date(s.checkInTime!).getMinutes()
    );
    const avgCheckInMinutes = checkIns.length > 0 
      ? Math.round(checkIns.reduce((a, b) => a + b, 0) / checkIns.length) 
      : 0;
    const avgCheckInTime = `${Math.floor(avgCheckInMinutes / 60).toString().padStart(2, '0')}:${(avgCheckInMinutes % 60).toString().padStart(2, '0')}`;

    // Calculate sales summary
    const salesSummary = {
      totalPetrolLitres: shifts.reduce((sum, s) => sum + (s.totalPetrolLitres || 0), 0),
      totalDieselLitres: shifts.reduce((sum, s) => sum + (s.totalDieselLitres || 0), 0),
      totalPetrolAmount: 0, // Would need transaction aggregation
      totalDieselAmount: 0,
      totalTransactions: shifts.reduce((sum, s) => sum + (s.transactionCount || 0), 0),
      paymentMethodBreakdown: {
        cash: 0,
        card: 0,
        upi: 0,
      },
    };

    // Calculate performance scores
    const workingDays = attendance.filter(a => ['PRESENT', 'LATE', 'HALF_DAY'].includes(a.status)).length;
    const totalWorkingDays = attendance.length;
    
    const punctualityScore = totalWorkingDays > 0 
      ? Math.round(((attendanceSummary.presentDays + (attendanceSummary.halfDays * 0.5)) / totalWorkingDays) * 100)
      : 100;
    
    const attendanceScore = totalWorkingDays > 0
      ? Math.round((workingDays / totalWorkingDays) * 100)
      : 100;
    
    // Sales score based on transaction count vs target (simplified)
    const salesTarget = 50; // transactions per month target
    const salesScore = Math.min(100, Math.round((salesSummary.totalTransactions / salesTarget) * 100));
    
    const overallScore = Math.round((punctualityScore * 0.3) + (attendanceScore * 0.4) + (salesScore * 0.3));

    // Weekly hours trend (last 4 weeks)
    const weeklyHoursTrend: Array<{ week: string; hours: number }> = [];
    for (let i = 3; i >= 0; i--) {
      const weekStart = new Date();
      weekStart.setDate(weekStart.getDate() - (i * 7));
      const weekKey = `Week ${4 - i}`;
      
      const weekHours = shifts
        .filter(s => {
          const shiftDate = new Date(s.checkInTime);
          const daysDiff = Math.floor((weekStart.getTime() - shiftDate.getTime()) / (1000 * 60 * 60 * 24));
          return daysDiff >= 0 && daysDiff < 7;
        })
        .reduce((sum, s) => sum + (s.totalHours || 0), 0);
      
      weeklyHoursTrend.push({ week: weekKey, hours: Math.round(weekHours * 10) / 10 });
    }

    // Recent alerts (unread first, then by date)
    const recentAlerts = alertsResult.items
      .sort((a, b) => {
        if (a.isRead !== b.isRead) return a.isRead ? 1 : -1;
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      })
      .slice(0, 10);

    // Leave balance (simplified - would come from leave policy config)
    const leaveBalance = {
      casual: { used: 2, total: 12 },
      sick: { used: 1, total: 10 },
      earned: { used: 0, total: 15 },
    };

    const dashboard: StaffDashboardOutput = {
      staff: {
        staffId: staff.staffId,
        fullName: staff.fullName,
        role: staff.role,
        profilePhotoUrl: staff.profilePhotoUrl,
      },
      attendanceSummary,
      shiftSummary: {
        totalShifts: shifts.length,
        totalHoursWorked: Math.round(totalHoursWorked * 10) / 10,
        totalOvertimeHours: Math.round(totalOvertimeHours * 10) / 10,
        avgCheckInTime,
        avgCheckOutTime: '17:00', // Simplified
      },
      salesSummary,
      performanceScore: {
        overall: overallScore,
        punctualityScore,
        attendanceScore,
        salesScore,
      },
      weeklyHoursTrend,
      recentAlerts,
      leaveBalance,
    };

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify(dashboard),
    };

  } catch (error) {
    console.error('Dashboard error:', error);

    if (error instanceof z.ZodError) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Invalid query parameters',
          details: error.errors,
        }),
      };
    }

    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
};
