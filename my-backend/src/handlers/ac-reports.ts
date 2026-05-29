// ============================================================================
// ACADEMIC COACHING — CUSTOM REPORT BUILDER MODULE
// ============================================================================
// Dynamic report generation with filters and export options
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
  queryAllItems,
} from '../config/dynamodb.config';

const AC_REPORT_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_REPORTS_ANALYTICS,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// REPORT DEFINITIONS
// ============================================================================

/**
 * GET /ac/reports/templates
 * Get available report templates
 */
export const getReportTemplates = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const templates = [
      {
        id: 'student_list',
        name: 'Student List',
        description: 'Complete list of students with filters',
        entity: 'students',
        columns: ['studentId', 'name', 'class', 'batch', 'contact', 'status'],
        filters: ['batchId', 'status', 'dateRange', 'gender'],
      },
      {
        id: 'attendance_summary',
        name: 'Attendance Summary',
        description: 'Daily/period-wise attendance summary',
        entity: 'attendance',
        columns: ['date', 'batch', 'present', 'absent', 'percentage'],
        filters: ['batchId', 'dateRange', 'period'],
      },
      {
        id: 'fee_collection',
        name: 'Fee Collection Report',
        description: 'Fee collection and pending amounts',
        entity: 'invoices',
        columns: ['invoiceNumber', 'student', 'amount', 'paid', 'balance', 'status'],
        filters: ['batchId', 'dateRange', 'status'],
      },
      {
        id: 'admission_conversion',
        name: 'Admission Conversion',
        description: 'Application to admission conversion rates',
        entity: 'applications',
        columns: ['month', 'applications', 'admitted', 'conversionRate'],
        filters: ['dateRange', 'course'],
      },
      {
        id: 'library_activity',
        name: 'Library Activity',
        description: 'Book issues, returns, and overdue',
        entity: 'library',
        columns: ['date', 'action', 'book', 'member', 'status'],
        filters: ['dateRange', 'memberType'],
      },
      {
        id: 'transport_utilization',
        name: 'Transport Utilization',
        description: 'Route-wise student counts and occupancy',
        entity: 'transport',
        columns: ['route', 'capacity', 'students', 'occupancy'],
        filters: ['routeId'],
      },
      {
        id: 'exam_results',
        name: 'Exam Results',
        description: 'Student performance in exams',
        entity: 'exams',
        columns: ['student', 'exam', 'marks', 'grade', 'rank'],
        filters: ['batchId', 'examId', 'dateRange'],
      },
      {
        id: 'faculty_attendance',
        name: 'Faculty Attendance',
        description: 'Faculty attendance and classes taken',
        entity: 'faculty',
        columns: ['faculty', 'daysPresent', 'daysAbsent', 'classesTaken'],
        filters: ['facultyId', 'dateRange'],
      },
      {
        id: 'hostel_occupancy',
        name: 'Hostel Occupancy',
        description: 'Room-wise occupancy statistics',
        entity: 'hostel',
        columns: ['hostel', 'room', 'capacity', 'occupied', 'vacant'],
        filters: ['hostelId'],
      },
      {
        id: 'inventory_status',
        name: 'Inventory Status',
        description: 'Stock levels and low stock items',
        entity: 'inventory',
        columns: ['item', 'currentStock', 'minStock', 'status'],
        filters: ['category', 'lowStock'],
      },
    ];

    return response.success(templates);
  },
  AC_REPORT_OPTS,
);

// ============================================================================
// REPORT EXECUTION
// ============================================================================

/**
 * POST /ac/reports/execute
 * Execute a report with filters
 */
export const executeReport = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { reportId, filters, format = 'json' } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Execute report based on type
    let result: any = { data: [], summary: {} };

    switch (reportId) {
      case 'student_list':
        result = await generateStudentListReport(pk, filters);
        break;
      case 'attendance_summary':
        result = await generateAttendanceReport(pk, filters);
        break;
      case 'fee_collection':
        result = await generateFeeCollectionReport(pk, filters);
        break;
      case 'admission_conversion':
        result = await generateAdmissionConversionReport(pk, filters);
        break;
      case 'library_activity':
        result = await generateLibraryReport(pk, filters);
        break;
      case 'exam_results':
        result = await generateExamResultsReport(pk, filters);
        break;
      default:
        return response.error(400, 'INVALID_REPORT', 'Report template not found');
    }

    // Store report execution
    const executionId = uid();
    const execution = {
      PK: pk,
      SK: `AC_REPORT_EXECUTION#${executionId}`,
      id: executionId,
      reportId,
      filters,
      format,
      resultSummary: {
        rowCount: result.data?.length || 0,
        generatedAt: now(),
      },
      executedBy: auth.sub,
      executedAt: now(),
    };

    await putItem(execution);

    return response.success({
      executionId,
      reportId,
      data: result.data,
      summary: result.summary,
      format,
      generatedAt: execution.resultSummary.generatedAt,
    });
  },
  AC_REPORT_OPTS,
);

/**
 * POST /ac/reports/schedule
 * Schedule a recurring report
 */
export const scheduleReport = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { reportId, filters, frequency, recipients, format } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    const schedule = {
      PK: pk,
      SK: `AC_REPORT_SCHEDULE#${id}`,
      id,
      reportId,
      filters,
      frequency, // 'daily', 'weekly', 'monthly'
      recipients, // Array of emails
      format: format || 'pdf',
      isActive: true,
      createdAt: ts,
      createdBy: auth.sub,
      nextRunAt: calculateNextRun(frequency),
    };

    await putItem(schedule);

    logger.info('Report scheduled', { tenantId: auth.tenantId, scheduleId: id, reportId, frequency });

    return response.success(schedule, 201);
  },
  AC_REPORT_OPTS,
);

/**
 * GET /ac/reports/executions
 * List report execution history
 */
export const listReportExecutions = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let executions = await queryAllItems(pk, 'AC_REPORT_EXECUTION#');

    if (p.reportId) {
      executions = executions.filter((e: any) => e.reportId === p.reportId);
    }

    // Sort by executedAt desc
    executions.sort((a: any, b: any) => (b.executedAt || '').localeCompare(a.executedAt || ''));

    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = executions.length;
    const paged = executions.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_REPORT_OPTS,
);

/**
 * GET /ac/reports/dashboard-summary
 * Quick dashboard summary statistics
 */
export const getDashboardSummary = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const today = now().split('T')[0];

    // Get counts from various entities
    const [
      students,
      faculty,
      applications,
      books,
      vehicles,
      hostels,
    ] = await Promise.all([
      queryAllItems(pk, 'AC_STUDENT#'),
      queryAllItems(pk, 'AC_FACULTY#'),
      queryAllItems(pk, 'AC_APPLICATION#'),
      queryAllItems(pk, 'AC_BOOK#'),
      queryAllItems(pk, 'AC_VEHICLE#'),
      queryAllItems(pk, 'AC_HOSTEL#'),
    ]);

    // Get today's attendance
    const todayAttendance = await queryAllItems(pk, 'AC_ATTENDANCE#', {
      filterExpression: '#date = :today',
      expressionAttributeNames: { '#date': 'date' },
      expressionAttributeValues: { ':today': today },
    });

    // Get pending fees
    const invoices = await queryAllItems(pk, 'AC_INVOICE#');
    const pendingInvoices = invoices.filter((i: any) => i.status === 'pending' || i.status === 'partial');
    const totalPendingPaisa = pendingInvoices.reduce((sum: number, i: any) => sum + (i.balancePaisa || 0), 0);

    const summary = {
      students: {
        total: students.length,
        active: students.filter((s: any) => s.status === 'active').length,
        inactive: students.filter((s: any) => s.status === 'inactive').length,
      },
      faculty: {
        total: faculty.length,
        active: faculty.filter((f: any) => f.isActive).length,
      },
      attendance: {
        today: todayAttendance.length,
        present: todayAttendance.filter((a: any) => a.status === 'present').length,
        absent: todayAttendance.filter((a: any) => a.status === 'absent').length,
      },
      admissions: {
        pending: applications.filter((a: any) => a.status === 'pending').length,
        thisMonth: applications.filter((a: any) => a.createdAt?.startsWith(today.substring(0, 7))).length,
      },
      fees: {
        pendingAmount: totalPendingPaisa / 100,
        pendingInvoices: pendingInvoices.length,
      },
      library: {
        totalBooks: books.length,
        issued: books.reduce((sum: number, b: any) => sum + (b.issuedCount || 0), 0),
      },
      transport: {
        totalVehicles: vehicles.length,
        active: vehicles.filter((v: any) => v.isActive).length,
      },
      hostel: {
        total: hostels.length,
        capacity: hostels.reduce((sum: number, h: any) => sum + (h.totalBeds || 0), 0),
        occupied: hostels.reduce((sum: number, h: any) => sum + (h.occupiedBeds || 0), 0),
      },
    };

    return response.success(summary);
  },
  AC_REPORT_OPTS,
);

// ============================================================================
// REPORT GENERATORS (Internal)
// ============================================================================

async function generateStudentListReport(pk: string, filters: any): Promise<any> {
  let students = await queryAllItems(pk, 'AC_STUDENT#');

  if (filters.batchId) {
    students = students.filter((s: any) => s.enrolledBatchIds?.includes(filters.batchId));
  }
  if (filters.status) {
    students = students.filter((s: any) => s.status === filters.status);
  }
  if (filters.gender) {
    students = students.filter((s: any) => s.gender === filters.gender);
  }

  const data = students.map((s: any) => ({
    studentId: s.studentId,
    name: `${s.firstName} ${s.lastName}`,
    class: s.currentClass,
    batch: s.enrolledBatchIds?.join(', ') || '-',
    contact: s.phone,
    status: s.status,
  }));

  return {
    data,
    summary: {
      total: data.length,
      byStatus: data.reduce((acc: any, s: any) => {
        acc[s.status] = (acc[s.status] || 0) + 1;
        return acc;
      }, {}),
    },
  };
}

async function generateAttendanceReport(pk: string, filters: any): Promise<any> {
  const attendance = await queryAllItems(pk, 'AC_ATTENDANCE#');

  // Filter by date range
  let filtered = attendance;
  if (filters.fromDate && filters.toDate) {
    filtered = attendance.filter((a: any) => a.date >= filters.fromDate && a.date <= filters.toDate);
  }
  if (filters.batchId) {
    filtered = filtered.filter((a: any) => a.batchId === filters.batchId);
  }

  // Group by date
  const byDate: Record<string, { present: number; absent: number; total: number }> = {};
  for (const record of filtered as any[]) {
    if (!byDate[record.date]) {
      byDate[record.date] = { present: 0, absent: 0, total: 0 };
    }
    byDate[record.date].total++;
    if (record.status === 'present') byDate[record.date].present++;
    else if (record.status === 'absent') byDate[record.date].absent++;
  }

  const data = Object.entries(byDate).map(([date, stats]) => ({
    date,
    ...stats,
    percentage: Math.round((stats.present / stats.total) * 100),
  }));

  return {
    data,
    summary: {
      totalDays: data.length,
      avgAttendance: data.length > 0
        ? Math.round(data.reduce((sum: number, d: any) => sum + d.percentage, 0) / data.length)
        : 0,
    },
  };
}

async function generateFeeCollectionReport(pk: string, filters: any): Promise<any> {
  let invoices = await queryAllItems(pk, 'AC_INVOICE#');

  if (filters.fromDate && filters.toDate) {
    invoices = invoices.filter((i: any) => i.createdAt >= filters.fromDate && i.createdAt <= filters.toDate);
  }
  if (filters.status) {
    invoices = invoices.filter((i: any) => i.status === filters.status);
  }

  const data = invoices.map((i: any) => ({
    invoiceNumber: i.invoiceNumber,
    student: i.studentName,
    amount: i.totalAmountPaisa / 100,
    paid: i.paidAmountPaisa / 100,
    balance: i.balancePaisa / 100,
    status: i.status,
  }));

  return {
    data,
    summary: {
      totalInvoices: data.length,
      totalAmount: data.reduce((sum: number, i: any) => sum + i.amount, 0),
      totalCollected: data.reduce((sum: number, i: any) => sum + i.paid, 0),
      totalPending: data.reduce((sum: number, i: any) => sum + i.balance, 0),
    },
  };
}

async function generateAdmissionConversionReport(pk: string, filters: any): Promise<any> {
  let applications = await queryAllItems(pk, 'AC_APPLICATION#');

  if (filters.fromDate && filters.toDate) {
    applications = applications.filter((a: any) => a.createdAt >= filters.fromDate && a.createdAt <= filters.toDate);
  }

  // Group by month
  const byMonth: Record<string, { applications: number; admitted: number }> = {};
  for (const app of applications as any[]) {
    const month = app.createdAt?.substring(0, 7) || 'unknown';
    if (!byMonth[month]) {
      byMonth[month] = { applications: 0, admitted: 0 };
    }
    byMonth[month].applications++;
    if (app.status === 'admitted') {
      byMonth[month].admitted++;
    }
  }

  const data = Object.entries(byMonth).map(([month, stats]) => ({
    month,
    ...stats,
    conversionRate: stats.applications > 0 ? Math.round((stats.admitted / stats.applications) * 100) : 0,
  }));

  return {
    data,
    summary: {
      totalApplications: data.reduce((sum: number, m: any) => sum + m.applications, 0),
      totalAdmitted: data.reduce((sum: number, m: any) => sum + m.admitted, 0),
      avgConversionRate: data.length > 0
        ? Math.round(data.reduce((sum: number, m: any) => sum + m.conversionRate, 0) / data.length)
        : 0,
    },
  };
}

async function generateLibraryReport(pk: string, filters: any): Promise<any> {
  let issues = await queryAllItems(pk, 'AC_BOOK_ISSUE#');

  if (filters.fromDate && filters.toDate) {
    issues = issues.filter((i: any) => i.createdAt >= filters.fromDate && i.createdAt <= filters.toDate);
  }

  const data = issues.map((i: any) => ({
    date: i.createdAt?.split('T')[0],
    action: i.status === 'returned' ? 'return' : 'issue',
    book: i.bookTitle || i.bookId,
    member: i.memberName || i.memberId,
    status: i.status,
  }));

  return {
    data,
    summary: {
      totalIssues: issues.filter((i: any) => i.status === 'issued').length,
      totalReturns: issues.filter((i: any) => i.status === 'returned').length,
      overdue: issues.filter((i: any) => i.status === 'issued' && new Date() > new Date(i.dueDate)).length,
    },
  };
}

async function generateExamResultsReport(pk: string, filters: any): Promise<any> {
  let results = await queryAllItems(pk, 'AC_EXAM_RESULT#');

  if (filters.batchId) {
    results = results.filter((r: any) => r.batchId === filters.batchId);
  }
  if (filters.examId) {
    results = results.filter((r: any) => r.examId === filters.examId);
  }

  const data = results.map((r: any, index: number) => ({
    student: r.studentName || r.studentId,
    exam: r.examName || r.examId,
    marks: r.marksObtained,
    grade: r.grade,
    rank: index + 1,
  }));

  return {
    data,
    summary: {
      totalStudents: data.length,
      passed: data.filter((r: any) => r.grade !== 'F').length,
      failed: data.filter((r: any) => r.grade === 'F').length,
      highestMarks: Math.max(...data.map((r: any) => r.marks)),
      lowestMarks: Math.min(...data.map((r: any) => r.marks)),
      averageMarks: Math.round(data.reduce((sum: number, r: any) => sum + r.marks, 0) / data.length),
    },
  };
}

// ============================================================================
// UTILITY
// ============================================================================

function calculateNextRun(frequency: string): string {
  const now = new Date();
  switch (frequency) {
    case 'daily':
      now.setDate(now.getDate() + 1);
      break;
    case 'weekly':
      now.setDate(now.getDate() + 7);
      break;
    case 'monthly':
      now.setMonth(now.getMonth() + 1);
      break;
    default:
      now.setDate(now.getDate() + 1);
  }
  return now.toISOString();
}
