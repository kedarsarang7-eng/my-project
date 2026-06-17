// ============================================================================
// ACADEMIC COACHING — EXAM EXTRAS MODULE
// ============================================================================
// Seating arrangement, hall ticket generation, progress charts
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
import { StorageService } from '../services/storage.service';

const AC_EXAM_EXTRA_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_EXAM_MANAGEMENT,
};

const storageSvc = new StorageService();

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// SEATING ARRANGEMENT
// ============================================================================

/**
 * POST /ac/exams/seating-arrangement
 * Create seating arrangement for exam
 */
export const createSeatingArrangement = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { examId, examDate, roomAllocations } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();
    const id = uid();

    // roomAllocations: [{ roomId, roomName, seats: [{ row, col, studentId }] }]
    const arrangement = {
      PK: pk,
      SK: `AC_SEATING_ARRANGEMENT#${id}`,
      GSI1PK: `AC_SEATING_BY_EXAM#${auth.tenantId}#${examId}`,
      GSI1SK: examDate,
      id,
      examId,
      examDate,
      roomAllocations: roomAllocations || [],
      totalStudents: roomAllocations?.reduce((sum: number, r: any) => sum + (r.seats?.length || 0), 0) || 0,
      createdAt: ts,
      createdBy: auth.sub,
    };

    await putItem(arrangement);

    logger.info('Seating arrangement created', { tenantId: auth.tenantId, arrangementId: id, examId });

    return response.success(arrangement, 201);
  },
  AC_EXAM_EXTRA_OPTS,
);

/**
 * GET /ac/exams/{examId}/seating-arrangement
 * Get seating arrangement for exam
 */
export const getSeatingArrangement = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const examId = event.pathParameters?.examId;
    if (!examId) return response.badRequest('Exam ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    const arrangements = await queryAllItems(
      `AC_SEATING_BY_EXAM#${auth.tenantId}#${examId}`,
      '',
      { indexName: 'GSI1' }
    );

    if (arrangements.length === 0) {
      return response.notFound('Seating arrangement not found');
    }

    // Get the latest
    const arrangement = arrangements[0];

    // Enrich with student details
    const enrichedRooms = [];
    for (const room of (arrangement as any).roomAllocations || []) {
      const enrichedSeats = [];
      for (const seat of room.seats || []) {
        const student = await getItem(pk, Keys.acStudentSK(seat.studentId));
        enrichedSeats.push({
          ...seat,
          studentName: student ? `${(student as any).firstName} ${(student as any).lastName}` : 'Unknown',
          rollNumber: (student as any)?.studentId || '',
        });
      }
      enrichedRooms.push({ ...room, seats: enrichedSeats });
    }

    return response.success({ ...arrangement, roomAllocations: enrichedRooms });
  },
  AC_EXAM_EXTRA_OPTS,
);

/**
 * GET /ac/exams/seating-arrangement/{id}/download
 * Download seating arrangement as PDF
 */
export const downloadSeatingArrangement = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Arrangement ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const arrangement = await getItem<any>(pk, `AC_SEATING_ARRANGEMENT#${id}`);
    
    if (!arrangement) return response.notFound('Seating arrangement not found');

    // In production: Generate PDF
    // For now, return structured data
    return response.success({
      downloadUrl: null, // Would be PDF URL
      arrangement,
      format: 'json',
    });
  },
  AC_EXAM_EXTRA_OPTS,
);

// ============================================================================
// HALL TICKET GENERATION
// ============================================================================

/**
 * POST /ac/exams/{examId}/hall-tickets
 * Generate hall tickets for all students
 */
export const generateHallTickets = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const examId = event.pathParameters?.examId;
    if (!examId) return response.badRequest('Exam ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    // Get exam details
    const exam = await getItem<any>(pk, `AC_EXAM#${examId}`);
    if (!exam) return response.notFound('Exam not found');

    // Get students in batch
    const students = await queryAllItems(pk, 'AC_STUDENT#', {
      filterExpression: 'enrolledBatchIds contains :batchId',
      expressionAttributeValues: { ':batchId': exam.batchId },
    });

    const generated = [];

    for (const student of students as any[]) {
      // Check if hall ticket already exists
      const existing = await queryAllItems(pk, 'AC_HALL_TICKET#', {
        filterExpression: 'examId = :examId AND studentId = :studentId',
        expressionAttributeValues: { ':examId': examId, ':studentId': student.id },
      });

      if (existing.length === 0) {
        const htId = uid();
        const hallTicketNumber = `HT-${examId.substring(0, 4)}-${student.studentId}`;

        const hallTicket = {
          PK: pk,
          SK: `AC_HALL_TICKET#${htId}`,
          GSI1PK: `AC_HALL_TICKETS_BY_EXAM#${auth.tenantId}#${examId}`,
          GSI1SK: student.id,
          id: htId,
          hallTicketNumber,
          examId,
          examName: exam.name,
          examDate: exam.date,
          examTime: exam.startTime,
          studentId: student.id,
          studentName: `${student.firstName} ${student.lastName}`,
          rollNumber: student.studentId,
          batchId: exam.batchId,
          status: 'generated',
          s3Key: null,
          generatedAt: ts,
          generatedBy: auth.sub,
        };

        await putItem(hallTicket);
        generated.push(hallTicket);
      }
    }

    logger.info('Hall tickets generated', { tenantId: auth.tenantId, examId, generated: generated.length });

    return response.success({
      examId,
      generated: generated.length,
      hallTickets: generated,
    });
  },
  AC_EXAM_EXTRA_OPTS,
);

/**
 * GET /ac/exams/hall-tickets/{id}
 * Get hall ticket with download URL
 */
export const getHallTicket = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Hall ticket ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const hallTicket = await getItem<any>(pk, `AC_HALL_TICKET#${id}`);
    
    if (!hallTicket) return response.notFound('Hall ticket not found');

    // Generate download URL
    let downloadUrl = null;
    if (hallTicket.s3Key) {
      downloadUrl = await storageSvc.getDownloadUrl(hallTicket.s3Key);
    }

    return response.success({ ...hallTicket, downloadUrl });
  },
  AC_EXAM_EXTRA_OPTS,
);

/**
 * GET /ac/students/{studentId}/hall-tickets
 * Get all hall tickets for a student
 */
export const getStudentHallTickets = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    const hallTickets = await queryAllItems(pk, 'AC_HALL_TICKET#', {
      filterExpression: 'studentId = :studentId',
      expressionAttributeValues: { ':studentId': studentId },
    });

    // Sort by exam date
    hallTickets.sort((a: any, b: any) => (a.examDate || '').localeCompare(b.examDate || ''));

    return response.success(hallTickets);
  },
  AC_EXAM_EXTRA_OPTS,
);

/**
 * POST /ac/exams/hall-tickets/{id}/download
 * Download hall ticket PDF
 */
export const downloadHallTicket = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Hall ticket ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const hallTicket = await getItem<any>(pk, `AC_HALL_TICKET#${id}`);
    
    if (!hallTicket) return response.notFound('Hall ticket not found');

    // In production: Generate PDF if not exists
    // const pdfKey = `tenants/${auth.tenantId}/hall-tickets/${id}.pdf`;
    // const downloadUrl = await storageSvc.getDownloadUrl(pdfKey);

    return response.success({
      hallTicket,
      downloadUrl: null, // Would be actual URL
      message: 'PDF generation to be implemented',
    });
  },
  AC_EXAM_EXTRA_OPTS,
);

// ============================================================================
// PROGRESS CHARTS / ACADEMIC PERFORMANCE
// ============================================================================

/**
 * GET /ac/students/{studentId}/progress-chart
 * Get academic progress chart data
 */
export const getProgressChart = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    // Get student
    const student = await getItem(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    // Get all exam results for student
    const results = await queryAllItems(pk, 'AC_EXAM_RESULT#', {
      filterExpression: 'studentId = :studentId',
      expressionAttributeValues: { ':studentId': studentId },
    });

    // Group by subject/exam type
    const byExam: Record<string, { examName: string; marks: number; totalMarks: number; percentage: number; grade: string }> = {};
    
    for (const result of results as any[]) {
      const exam = await getItem(pk, `AC_EXAM#${result.examId}`);
      if (exam) {
        const key = result.examId;
        byExam[key] = {
          examName: (exam as any).name,
          marks: result.marksObtained,
          totalMarks: result.totalMarks,
          percentage: Math.round((result.marksObtained / result.totalMarks) * 100),
          grade: result.grade,
        };
      }
    }

    // Calculate trends
    const sortedExams = Object.values(byExam).sort((a: any, b: any) => a.examDate?.localeCompare(b.examDate));
    
    // Attendance trend
    const attendance = await queryAllItems(pk, 'AC_ATTENDANCE#', {
      filterExpression: 'studentId = :studentId',
      expressionAttributeValues: { ':studentId': studentId },
    });

    const monthlyAttendance: Record<string, { present: number; total: number }> = {};
    for (const record of attendance as any[]) {
      const month = record.date?.substring(0, 7);
      if (month) {
        if (!monthlyAttendance[month]) monthlyAttendance[month] = { present: 0, total: 0 };
        monthlyAttendance[month].total++;
        if (record.status === 'present') monthlyAttendance[month].present++;
      }
    }

    return response.success({
      studentId,
      studentName: `${(student as any).firstName} ${(student as any).lastName}`,
      examResults: sortedExams,
      examTrend: sortedExams.map((e: any) => e.percentage),
      attendanceTrend: Object.entries(monthlyAttendance).map(([month, data]: [string, any]) => ({
        month,
        percentage: Math.round((data.present / data.total) * 100),
      })),
      overallGrade: calculateOverallGrade(Object.values(byExam) as any[]),
      summary: {
        totalExams: sortedExams.length,
        averagePercentage: sortedExams.length > 0 
          ? Math.round(sortedExams.reduce((sum: number, e: any) => sum + e.percentage, 0) / sortedExams.length)
          : 0,
        highestMarks: Math.max(...sortedExams.map((e: any) => e.marks), 0),
        lowestMarks: sortedExams.length > 0 ? Math.min(...sortedExams.map((e: any) => e.marks)) : 0,
      },
    });
  },
  AC_EXAM_EXTRA_OPTS,
);

/**
 * GET /ac/batches/{batchId}/progress-comparison
 * Compare progress across batch students
 */
export const getBatchProgressComparison = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const batchId = event.pathParameters?.batchId;
    if (!batchId) return response.badRequest('Batch ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    // Get batch
    const batch = await getItem(pk, Keys.acBatchSK(batchId));
    if (!batch) return response.notFound('Batch not found');

    // Get students in batch
    const students = await queryAllItems(pk, 'AC_STUDENT#', {
      filterExpression: 'enrolledBatchIds contains :batchId',
      expressionAttributeValues: { ':batchId': batchId },
    });

    const studentProgress = [];

    for (const student of students as any[]) {
      // Get results
      const results = await queryAllItems(pk, 'AC_EXAM_RESULT#', {
        filterExpression: 'studentId = :studentId',
        expressionAttributeValues: { ':studentId': student.id },
      });

      const avgMarks = results.length > 0
        ? results.reduce((sum: number, r: any) => sum + ((r.marksObtained / r.totalMarks) * 100), 0) / results.length
        : 0;

      studentProgress.push({
        studentId: student.id,
        studentName: `${student.firstName} ${student.lastName}`,
        rollNumber: student.studentId,
        totalExams: results.length,
        averagePercentage: Math.round(avgMarks),
        rank: 0, // Will be calculated
      });
    }

    // Sort by average and assign ranks
    studentProgress.sort((a, b) => b.averagePercentage - a.averagePercentage);
    studentProgress.forEach((s, index) => s.rank = index + 1);

    return response.success({
      batchId,
      batchName: (batch as any).name,
      totalStudents: studentProgress.length,
      students: studentProgress,
      classAverage: Math.round(studentProgress.reduce((sum, s) => sum + s.averagePercentage, 0) / studentProgress.length),
      topPerformer: studentProgress[0] || null,
    });
  },
  AC_EXAM_EXTRA_OPTS,
);

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function calculateOverallGrade(exams: any[]): string {
  if (exams.length === 0) return 'N/A';
  
  const avg = exams.reduce((sum, e) => sum + e.percentage, 0) / exams.length;
  
  if (avg >= 90) return 'A+';
  if (avg >= 80) return 'A';
  if (avg >= 70) return 'B';
  if (avg >= 60) return 'C';
  if (avg >= 50) return 'D';
  return 'F';
}
