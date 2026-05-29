// ============================================================================
// ACADEMIC COACHING — PERIOD-WISE ATTENDANCE MODULE
// ============================================================================
// Track attendance for each class period (not just daily)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  putItem,
  getItem,
  updateItem,
  queryAllItems,
} from '../config/dynamodb.config';

const AC_PERIOD_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_ATTENDANCE_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// PERIOD MARKING
// ============================================================================

/**
 * POST /ac/attendance/period
 * Mark attendance for a specific period
 */
export const markPeriodAttendance = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const {
      batchId,
      date,
      periodNumber, // 1-8 for 8 periods in a day
      subjectId,
      facultyId,
      attendanceList, // [{studentId, status: 'present'|'absent'|'late'}]
    } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    // Validate period number
    if (periodNumber < 1 || periodNumber > 8) {
      return response.error(400, 'INVALID_PERIOD', 'Period number must be 1-8');
    }

    const periodAttendance = {
      PK: pk,
      SK: `AC_PERIOD_ATTENDANCE#${date}#${batchId}#${periodNumber}`,
      GSI1PK: `AC_PERIOD_BY_BATCH#${auth.tenantId}#${batchId}`,
      GSI1SK: `${date}#${periodNumber}`,
      id,
      batchId,
      date,
      periodNumber,
      subjectId,
      facultyId,
      attendanceList: attendanceList || [],
      totalStudents: attendanceList?.length || 0,
      presentCount: attendanceList?.filter((a: any) => a.status === 'present').length || 0,
      absentCount: attendanceList?.filter((a: any) => a.status === 'absent').length || 0,
      lateCount: attendanceList?.filter((a: any) => a.status === 'late').length || 0,
      markedAt: ts,
      markedBy: auth.sub,
    };

    await putItem(periodAttendance);

    // Also update daily attendance for each student (aggregated)
    for (const record of attendanceList || []) {
      const dailyId = `${date}#${batchId}`;
      
      // Check if daily record exists
      const existingDaily = await queryAllItems(pk, 'AC_ATTENDANCE#', {
        filterExpression: 'studentId = :studentId AND #date = :date',
        expressionAttributeNames: { '#date': 'date' },
        expressionAttributeValues: { ':studentId': record.studentId, ':date': date },
      });

      if (existingDaily.length > 0) {
        // Update with period info
        const daily = existingDaily[0] as any;
        const periods = daily.periods || {};
        periods[periodNumber] = {
          status: record.status,
          subjectId,
          facultyId,
        };

        await updateItem(pk, daily.SK, {
          updateExpression: 'SET #periods = :periods, #updatedAt = :updatedAt',
          expressionAttributeNames: { '#periods': 'periods', '#updatedAt': 'updatedAt' },
          expressionAttributeValues: { ':periods': periods, ':updatedAt': ts },
        });
      }
    }

    logger.info('Period attendance marked', {
      tenantId: auth.tenantId,
      batchId,
      date,
      periodNumber,
      totalStudents: attendanceList?.length || 0,
    });

    return response.success(periodAttendance, 201);
  },
  AC_PERIOD_OPTS,
);

/**
 * GET /ac/attendance/period
 * Get period-wise attendance for a batch/date
 */
export const getPeriodAttendance = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { batchId, date, periodNumber } = p;

    if (!batchId || !date) {
      return response.badRequest('batchId and date are required');
    }

    const pk = Keys.tenantPK(auth.tenantId);

    if (periodNumber) {
      // Get specific period
      const attendance = await getItem(pk, `AC_PERIOD_ATTENDANCE#${date}#${batchId}#${periodNumber}`);
      if (!attendance) return response.notFound('Attendance not found');
      return response.success(attendance);
    }

    // Get all periods for the day
    const periods = await queryAllItems(
      `AC_PERIOD_BY_BATCH#${auth.tenantId}#${batchId}`,
      '',
      { indexName: 'GSI1' }
    );

    // Filter by date prefix
    const dayPeriods = periods.filter((p: any) => p.date === date);

    return response.success({
      batchId,
      date,
      periods: dayPeriods.sort((a: any, b: any) => a.periodNumber - b.periodNumber),
      totalPeriods: dayPeriods.length,
    });
  },
  AC_PERIOD_OPTS,
);

/**
 * GET /ac/attendance/student/{studentId}/periods
 * Get period-wise attendance for a student
 */
export const getStudentPeriodAttendance = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const p = event.queryStringParameters || {};
    const { fromDate, toDate } = p;

    const pk = Keys.tenantPK(auth.tenantId);

    // Get daily attendance records with period info
    const attendance = await queryAllItems(pk, 'AC_ATTENDANCE#', {
      filterExpression: 'studentId = :studentId',
      expressionAttributeValues: { ':studentId': studentId },
    });

    // Filter by date range
    let filtered = attendance;
    if (fromDate && toDate) {
      filtered = attendance.filter((a: any) => a.date >= fromDate && a.date <= toDate);
    }

    // Calculate period-wise statistics
    const periodStats: Record<number, { present: number; absent: number; late: number; total: number }> = {};

    for (const record of filtered as any[]) {
      const periods = record.periods || {};
      for (const [periodNum, data] of Object.entries(periods)) {
        const num = parseInt(periodNum);
        if (!periodStats[num]) {
          periodStats[num] = { present: 0, absent: 0, late: 0, total: 0 };
        }
        periodStats[num].total++;
        const status = (data as any).status;
        if (status === 'present') periodStats[num].present++;
        else if (status === 'absent') periodStats[num].absent++;
        else if (status === 'late') periodStats[num].late++;
      }
    }

    return response.success({
      studentId,
      dateRange: { fromDate, toDate },
      records: filtered,
      periodStats,
    });
  },
  AC_PERIOD_OPTS,
);

/**
 * POST /ac/attendance/period/{id}/correction
 * Request correction for period attendance
 */
export const requestCorrection = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const periodAttendanceId = event.pathParameters?.id;
    if (!periodAttendanceId) return response.badRequest('Attendance ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { studentId, currentStatus, requestedStatus, reason } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();
    const id = uid();

    const correctionRequest = {
      PK: pk,
      SK: `AC_ATTENDANCE_CORRECTION#${id}`,
      id,
      periodAttendanceId,
      studentId,
      currentStatus,
      requestedStatus,
      reason,
      status: 'pending',
      requestedBy: auth.sub,
      requestedAt: ts,
      reviewedBy: null,
      reviewedAt: null,
    };

    await putItem(correctionRequest);

    logger.info('Attendance correction requested', {
      tenantId: auth.tenantId,
      correctionId: id,
      periodAttendanceId,
      studentId,
    });

    return response.success(correctionRequest, 201);
  },
  AC_PERIOD_OPTS,
);

/**
 * POST /ac/attendance/correction/{id}/review
 * Review attendance correction request
 */
export const reviewCorrection = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const correctionId = event.pathParameters?.id;
    if (!correctionId) return response.badRequest('Correction ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { approved, remarks } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const correction = await getItem<any>(pk, `AC_ATTENDANCE_CORRECTION#${correctionId}`);
    
    if (!correction) return response.notFound('Correction request not found');
    if (correction.status !== 'pending') {
      return response.error(400, 'ALREADY_REVIEWED', 'Correction already reviewed');
    }

    const ts = now();
    const newStatus = approved ? 'approved' : 'rejected';

    await updateItem(pk, `AC_ATTENDANCE_CORRECTION#${correctionId}`, {
      updateExpression: 'SET #status = :status, #reviewedBy = :reviewedBy, #reviewedAt = :reviewedAt, #remarks = :remarks',
      expressionAttributeNames: {
        '#status': 'status',
        '#reviewedBy': 'reviewedBy',
        '#reviewedAt': 'reviewedAt',
        '#remarks': 'remarks',
      },
      expressionAttributeValues: {
        ':status': newStatus,
        ':reviewedBy': auth.sub,
        ':reviewedAt': ts,
        ':remarks': remarks || '',
      },
    });

    // If approved, update the attendance record
    if (approved) {
      // Get the period attendance record
      const periodAttendance = await getItem(pk, `AC_PERIOD_ATTENDANCE#${correction.periodAttendanceId}`);
      if (periodAttendance) {
        // Update the student's status in the attendance list
        const attendanceList = (periodAttendance as any).attendanceList || [];
        const studentIndex = attendanceList.findIndex((a: any) => a.studentId === correction.studentId);
        if (studentIndex >= 0) {
          attendanceList[studentIndex].status = correction.requestedStatus;
          
          await updateItem(pk, `AC_PERIOD_ATTENDANCE#${correction.periodAttendanceId}`, {
            updateExpression: 'SET #attendanceList = :attendanceList, #updatedAt = :updatedAt',
            expressionAttributeNames: { '#attendanceList': 'attendanceList', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':attendanceList': attendanceList, ':updatedAt': ts },
          });
        }
      }
    }

    return response.success({
      correctionId,
      status: newStatus,
      reviewedBy: auth.sub,
      reviewedAt: ts,
    });
  },
  AC_PERIOD_OPTS,
);

/**
 * GET /ac/attendance/defaulters
 * Get students with low attendance
 */
export const getDefaulters = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { batchId, threshold = '75', fromDate, toDate } = p;

    const pk = Keys.tenantPK(auth.tenantId);

    // Get all students in batch
    const students = await queryAllItems(pk, 'AC_STUDENT#');
    const batchStudents = batchId
      ? students.filter((s: any) => s.enrolledBatchIds?.includes(batchId))
      : students;

    const defaulters = [];

    for (const student of batchStudents as any[]) {
      // Get attendance for date range
      const attendance = await queryAllItems(pk, 'AC_ATTENDANCE#', {
        filterExpression: 'studentId = :studentId AND #date BETWEEN :from AND :to',
        expressionAttributeNames: { '#date': 'date' },
        expressionAttributeValues: {
          ':studentId': student.id,
          ':from': fromDate || '2000-01-01',
          ':to': toDate || '2099-12-31',
        },
      });

      const totalDays = attendance.length;
      const presentDays = attendance.filter((a: any) => a.status === 'present').length;
      const percentage = totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

      if (percentage < parseInt(threshold, 10)) {
        defaulters.push({
          studentId: student.id,
          name: `${student.firstName} ${student.lastName}`,
          totalDays,
          presentDays,
          absentDays: totalDays - presentDays,
          percentage: Math.round(percentage * 100) / 100,
          status: percentage < 60 ? 'critical' : percentage < 75 ? 'warning' : 'good',
        });
      }
    }

    // Sort by percentage ascending
    defaulters.sort((a, b) => a.percentage - b.percentage);

    return response.success({
      threshold: parseInt(threshold, 10),
      totalDefaulters: defaulters.length,
      defaulters,
    });
  },
  AC_PERIOD_OPTS,
);
