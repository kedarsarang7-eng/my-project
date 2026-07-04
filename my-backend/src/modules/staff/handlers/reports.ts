// ============================================================================
// Staff Module — Reports, Export, Search, Dashboard & Insights Handlers
// (Tasks 13.1 + 13.2)
// ============================================================================
// REST handlers under /staff/reports/*, /staff/search/*, /staff/dashboard/*:
//
//   GET  /staff/dashboard/summary   → Dashboard overview with query-backed numbers
//   GET  /staff/dashboard/insights  → Rule-based insights (anomalies, ranking, patterns)
//   POST /staff/reports/export      → Export a report in Excel/PDF/CSV/JSON
//   GET  /staff/search?q=...        → Global search across staff entities
//   POST /staff/search/filters      → Create a saved filter
//   GET  /staff/search/filters      → List saved filters for the current user
//   GET  /staff/search/filters/:id  → Get a specific saved filter
//   DELETE /staff/search/filters/:id → Delete a saved filter
//
// Each handler runs behind `authorizedHandler`, resolves TenantContext via
// `resolveStaffTenantScope`, validates with Zod, and returns the standard
// response envelope. Export handlers return binary with appropriate headers.
//
// DASHBOARD (Req 9.1): Every numeric value is derived from an actual data
// query — never a placeholder.
// INSIGHTS (Req 9.2): Rule-based and statistical methods ONLY — no ML.
//   • Attendance anomalies via statistical variance thresholds (Req 9.3)
//   • Top/bottom performers by deterministic ordering (Req 9.4)
//   • Leave patterns per configured thresholds (Req 9.5)
//
// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError } from '../../../utils/errors';
import { resolveStaffTenantScope } from './tenant-scope';
import { parseJsonBody, pathId } from './http';
import { queryItems } from '../../../config/dynamodb.config';
import { businessPK } from '../../../dynamodb/keys';
import {
    EMP_SK_PREFIX,
    DEPT_SK_PREFIX,
    DESIG_SK_PREFIX,
    ATT_SK_PREFIX,
    TASK_SK_PREFIX,
    LVREQ_SK_PREFIX,
    LVBAL_SK_PREFIX,
    PERFSCORE_SK_PREFIX,
    STAFF_ENTITY_TYPE,
} from '../keys';
import { reportExportSchema, createSavedFilterSchema } from '../schemas/report.schema';
import {
    exportReport,
    ReportData,
    ReportColumn,
    ExportFormat,
} from '../services/report-export.service';
import {
    globalStaffSearch,
    createSavedFilter,
    listSavedFilters,
    getSavedFilter,
    deleteSavedFilter,
} from '../services/staff-search.service';
import { enforceStaffPermission } from '../services/staff-rbac.service';
import {
    detectAttendanceAnomalies,
    topPerformers,
    bottomPerformers,
    detectLeavePatterns,
    AnomalyThresholdConfig,
    LeavePatternConfig,
    AttendanceDataPoint,
    PerformerEntry,
    LeaveHistoryEntry,
    DashboardSummary,
} from '../services/dashboard-insights.service';

// Roles permitted to access reports and search
const REPORT_ROLES: UserRole[] = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT];
const SEARCH_ROLES: UserRole[] = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF];

/** Format Zod issues into flat details. */
function zodDetails(issues: { path: PropertyKey[]; message: string }[]): string[] {
    return issues.map((i) => `${i.path.map(String).join('.') || '(root)'}: ${i.message}`);
}

// ── Column Definitions by Report Type ───────────────────────────────────────

const REPORT_COLUMNS: Record<string, ReportColumn[]> = {
    employees: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Name', key: 'fullName', width: 25 },
        { header: 'Department', key: 'departmentId', width: 20 },
        { header: 'Designation', key: 'designationId', width: 20 },
        { header: 'Status', key: 'status', width: 12 },
        { header: 'Phone', key: 'phone', width: 15 },
        { header: 'Email', key: 'email', width: 25 },
    ],
    departments: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Name', key: 'name', width: 30 },
        { header: 'Status', key: 'status', width: 12 },
    ],
    designations: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Title', key: 'title', width: 30 },
        { header: 'Department', key: 'departmentId', width: 20 },
        { header: 'Status', key: 'status', width: 12 },
    ],
    attendance: [
        { header: 'Event ID', key: 'eventId', width: 20 },
        { header: 'Employee', key: 'employeeId', width: 20 },
        { header: 'Type', key: 'type', width: 12 },
        { header: 'Method', key: 'method', width: 10 },
        { header: 'Timestamp', key: 'timestamp', width: 22 },
        { header: 'Rejected', key: 'rejected', width: 8 },
    ],
    leave_requests: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Employee', key: 'employeeId', width: 20 },
        { header: 'Leave Type', key: 'leaveTypeId', width: 18 },
        { header: 'From', key: 'from', width: 12 },
        { header: 'To', key: 'to', width: 12 },
        { header: 'Status', key: 'status', width: 12 },
    ],
    leave_balances: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Employee', key: 'employeeId', width: 20 },
        { header: 'Leave Type', key: 'leaveTypeId', width: 18 },
        { header: 'Balance', key: 'balance', width: 10 },
    ],
    tasks: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Title', key: 'title', width: 30 },
        { header: 'Assignee', key: 'assigneeId', width: 20 },
        { header: 'Priority', key: 'priority', width: 10 },
        { header: 'Status', key: 'status', width: 12 },
    ],
    payslips: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Employee', key: 'employeeId', width: 20 },
        { header: 'Period', key: 'period', width: 10 },
        { header: 'Gross (₹)', key: 'grossRupees', width: 12 },
        { header: 'Net (₹)', key: 'netRupees', width: 12 },
    ],
    performance: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Employee', key: 'employeeId', width: 20 },
        { header: 'Period', key: 'period', width: 10 },
        { header: 'Score', key: 'score', width: 8 },
    ],
};

/** Map report type to SK prefix and entity type filter for DynamoDB query. */
const REPORT_QUERY_MAP: Record<string, { skPrefix: string; entityType: string }> = {
    employees: { skPrefix: EMP_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.EMPLOYEE },
    departments: { skPrefix: DEPT_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.DEPARTMENT },
    designations: { skPrefix: DESIG_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.DESIGNATION },
    attendance: { skPrefix: ATT_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.ATTENDANCE },
    leave_requests: { skPrefix: LVREQ_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.LEAVE_REQUEST },
    leave_balances: { skPrefix: LVBAL_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.LEAVE_BALANCE },
    tasks: { skPrefix: TASK_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.TASK },
    payslips: { skPrefix: 'PAYSLIP#', entityType: 'STAFF_PAYSLIP' },
    performance: { skPrefix: PERFSCORE_SK_PREFIX, entityType: STAFF_ENTITY_TYPE.PERFORMANCE_SCORE },
};

/** Map report type to the RBAC export permission key. */
const EXPORT_PERMISSION_MAP: Record<string, string> = {
    employees: 'export_employees',
    departments: 'export_employees',
    designations: 'export_employees',
    attendance: 'export_attendance',
    leave_requests: 'export_leave_data',
    leave_balances: 'export_leave_data',
    tasks: 'export_employees',
    payslips: 'export_payslips',
    performance: 'export_performance',
};

// ── Export Handler ───────────────────────────────────────────────────────────

/**
 * POST /staff/reports/export — Export a report in the specified format.
 *
 * Body: { reportType, format, from?, to?, filters? }
 * Returns binary content with appropriate Content-Type and Content-Disposition.
 */
export const exportReportHandler = authorizedHandler(
    REPORT_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const body = parseJsonBody(event);

        const parsed = reportExportSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid export request', zodDetails(parsed.error.issues));
        }
        const input = parsed.data;

        // Check export-level RBAC permission
        const permKey = EXPORT_PERMISSION_MAP[input.reportType];
        if (permKey) {
            enforceStaffPermission(permKey, auth.role);
        }

        // Query data from DynamoDB
        const queryConfig = REPORT_QUERY_MAP[input.reportType];
        if (!queryConfig) {
            throw new ValidationError(`Unknown report type: ${input.reportType}`);
        }

        const pk = businessPK(tenantContext.tenantId, tenantContext.businessId);

        // Build optional filter expression
        let filterExpression = 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)';
        const expressionValues: Record<string, unknown> = {
            ':et': queryConfig.entityType,
            ':false': false,
        };

        // Date range filter (if entity has a timestamp/from field)
        if (input.from) {
            filterExpression += ' AND createdAt >= :fromDate';
            expressionValues[':fromDate'] = input.from;
        }
        if (input.to) {
            filterExpression += ' AND createdAt <= :toDate';
            expressionValues[':toDate'] = input.to;
        }

        const { items } = await queryItems<Record<string, unknown>>(
            pk,
            queryConfig.skPrefix,
            {
                filterExpression,
                expressionAttributeValues: expressionValues,
            },
        );

        // Transform rows for the export
        const columns = REPORT_COLUMNS[input.reportType] || [];
        const rows = items.map((item) => {
            const row: Record<string, unknown> = {};
            for (const col of columns) {
                if (col.key === 'phone') {
                    row[col.key] = (item.contact as Record<string, unknown>)?.phone ?? '';
                } else if (col.key === 'email') {
                    row[col.key] = (item.contact as Record<string, unknown>)?.email ?? '';
                } else if (col.key === 'grossRupees') {
                    const gross = item.grossPaise;
                    row[col.key] = typeof gross === 'number'
                        ? (gross / 100).toFixed(2)
                        : '';
                } else if (col.key === 'netRupees') {
                    const net = item.netPaise;
                    row[col.key] = typeof net === 'number'
                        ? (net / 100).toFixed(2)
                        : '';
                } else {
                    row[col.key] = item[col.key] ?? '';
                }
            }
            return row;
        });

        const reportData: ReportData = {
            title: `Staff ${input.reportType.replace(/_/g, ' ')} Report`,
            columns,
            rows,
            meta: {
                generatedAt: new Date().toISOString(),
                filters: input.filters,
            },
        };

        const result = await exportReport(reportData, input.format as ExportFormat);

        // Return binary content with appropriate headers
        return {
            statusCode: 200,
            headers: {
                'Content-Type': result.contentType,
                'Content-Disposition': `attachment; filename="${result.filename}"`,
                'Cache-Control': 'no-store',
            },
            body: result.buffer.toString('base64'),
            isBase64Encoded: true,
        };
    },
);

// ── Search Handler ──────────────────────────────────────────────────────────

/**
 * GET /staff/search?q=...&entityTypes=...&limit=...
 *
 * Global search over staff entities scoped to the authenticated business.
 * Query params: q (required), entityTypes (comma-separated), limit (int).
 */
export const searchStaffHandler = authorizedHandler(
    SEARCH_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);

        const q = event.queryStringParameters?.q ?? '';
        const entityTypesRaw = event.queryStringParameters?.entityTypes;
        const limitRaw = event.queryStringParameters?.limit;
        const filtersRaw = event.queryStringParameters?.filters;

        if (!q.trim()) {
            throw new ValidationError("Query parameter 'q' is required");
        }

        const entityTypes = entityTypesRaw ? entityTypesRaw.split(',').map((s) => s.trim()) : undefined;
        const limit = limitRaw ? Math.min(Math.max(parseInt(limitRaw, 10) || 50, 1), 200) : 50;
        const filters = filtersRaw ? JSON.parse(filtersRaw) : undefined;

        const result = await globalStaffSearch(
            tenantContext.tenantId,
            tenantContext.businessId,
            q,
            { entityTypes, limit, filters },
        );

        return response.success(result);
    },
);

// ── Saved Filters CRUD ──────────────────────────────────────────────────────

/**
 * POST /staff/search/filters — Create a saved filter.
 */
export const createSavedFilterHandler = authorizedHandler(
    SEARCH_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const body = parseJsonBody(event);

        const parsed = createSavedFilterSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid filter input', zodDetails(parsed.error.issues));
        }

        const filter = await createSavedFilter(
            tenantContext.tenantId,
            tenantContext.businessId,
            {
                id: randomUUID(),
                userId: tenantContext.userId,
                name: parsed.data.name,
                entityTypes: parsed.data.entityTypes,
                filters: parsed.data.filters,
                sort: parsed.data.sort,
            },
        );

        return response.success(filter, 201);
    },
);

/**
 * GET /staff/search/filters — List saved filters for the current user.
 */
export const listSavedFiltersHandler = authorizedHandler(
    SEARCH_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);

        const filters = await listSavedFilters(
            tenantContext.tenantId,
            tenantContext.businessId,
            tenantContext.userId,
        );

        return response.success({ items: filters });
    },
);

/**
 * GET /staff/search/filters/:id — Get a specific saved filter.
 */
export const getSavedFilterHandler = authorizedHandler(
    SEARCH_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const filterId = pathId(event);
        if (!filterId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const filter = await getSavedFilter(
            tenantContext.tenantId,
            tenantContext.businessId,
            tenantContext.userId,
            filterId,
        );

        if (!filter) {
            return response.notFound('Saved filter');
        }
        return response.success(filter);
    },
);

/**
 * DELETE /staff/search/filters/:id — Delete a saved filter.
 */
export const deleteSavedFilterHandler = authorizedHandler(
    SEARCH_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const filterId = pathId(event);
        if (!filterId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const deleted = await deleteSavedFilter(
            tenantContext.tenantId,
            tenantContext.businessId,
            tenantContext.userId,
            filterId,
        );

        if (!deleted) {
            return response.notFound('Saved filter');
        }
        return response.success({ deleted: true });
    },
);

// ── Dashboard & Insights Handlers (Task 13.1) ──────────────────────────────

// Dashboard roles — managers and above can view dashboards
const DASHBOARD_ROLES: UserRole[] = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT];

// Default insight thresholds (overridable via query params)
const DEFAULT_ANOMALY_CONFIG: AnomalyThresholdConfig = {
    stdDevThreshold: 2.0,
};

const DEFAULT_LEAVE_PATTERN_CONFIG: LeavePatternConfig = {
    maxLeaveDaysPerPeriod: 15,
    maxSameDayOfWeekOccurrences: 3,
    maxFrequentShortLeaves: 5,
};

/**
 * GET /staff/dashboard/summary — Dashboard overview with query-backed numbers.
 *
 * Every numeric value is derived from an actual data query (Req 9.1).
 * No placeholders or hardcoded values.
 *
 * Query params (optional):
 *  - date: ISO date (YYYY-MM-DD) for "today" context (defaults to server today)
 */
export const getDashboardSummaryHandler = authorizedHandler(
    DASHBOARD_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        enforceStaffPermission('view_hr_dashboard', auth.role);

        const pk = businessPK(tenantContext.tenantId, tenantContext.businessId);
        const today = event.queryStringParameters?.date || new Date().toISOString().slice(0, 10);

        // Query actual data from DynamoDB to derive every numeric value (Req 9.1)
        const activeFilter = 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)';
        const baseVals = { ':false': false };

        // 1. Total & active employees
        const { items: employees } = await queryItems<Record<string, unknown>>(
            pk,
            EMP_SK_PREFIX,
            {
                filterExpression: activeFilter,
                expressionAttributeValues: { ':et': STAFF_ENTITY_TYPE.EMPLOYEE, ...baseVals },
            },
        );
        const totalEmployees = employees.length;
        const activeEmployees = employees.filter((e) => e.status === 'active').length;

        // 2. Total departments
        const { items: departments } = await queryItems<Record<string, unknown>>(
            pk,
            DEPT_SK_PREFIX,
            {
                filterExpression: activeFilter,
                expressionAttributeValues: { ':et': STAFF_ENTITY_TYPE.DEPARTMENT, ...baseVals },
            },
        );
        const totalDepartments = departments.length;

        // 3. Attendance today — count distinct employees with check_in events today
        const { items: attendanceToday } = await queryItems<Record<string, unknown>>(
            pk,
            `${ATT_SK_PREFIX}${today}`,
            {
                filterExpression: 'entity_type = :et AND (attribute_not_exists(rejected) OR rejected = :false)',
                expressionAttributeValues: { ':et': STAFF_ENTITY_TYPE.ATTENDANCE, ...baseVals },
            },
        );
        const presentEmployeeIds = new Set<string>();
        for (const att of attendanceToday) {
            if (att.type === 'check_in' && att.employeeId) {
                presentEmployeeIds.add(att.employeeId as string);
            }
        }
        const presentToday = presentEmployeeIds.size;
        const absentToday = Math.max(0, activeEmployees - presentToday);

        // 4. Leave requests — count approved leaves spanning today
        const { items: leaveRequests } = await queryItems<Record<string, unknown>>(
            pk,
            LVREQ_SK_PREFIX,
            {
                filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':et': STAFF_ENTITY_TYPE.LEAVE_REQUEST, ...baseVals },
            },
        );
        const onLeaveToday = leaveRequests.filter((lr) =>
            lr.status === 'approved' &&
            (lr.from as string) <= today &&
            (lr.to as string) >= today,
        ).length;
        const pendingLeaveRequests = leaveRequests.filter((lr) => lr.status === 'pending').length;

        // 5. Tasks — open and overdue
        const { items: tasks } = await queryItems<Record<string, unknown>>(
            pk,
            TASK_SK_PREFIX,
            {
                filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':et': STAFF_ENTITY_TYPE.TASK, ...baseVals },
            },
        );
        const openTasks = tasks.filter(
            (t) => t.status === 'open' || t.status === 'in_progress',
        ).length;
        const overdueTaskCount = tasks.filter((t) => {
            if (t.status === 'done') return false;
            const dueDate = t.dueDate as string | undefined;
            return dueDate !== undefined && dueDate < today;
        }).length;

        const summary: DashboardSummary = {
            totalEmployees,
            activeEmployees,
            totalDepartments,
            presentToday,
            absentToday,
            onLeaveToday,
            pendingLeaveRequests,
            openTasks,
            overdueTaskCount,
        };

        return response.success(summary);
    },
);

/**
 * GET /staff/dashboard/insights — Rule-based insights (no ML, Req 9.2).
 *
 * Returns:
 *  - attendanceAnomalies: points flagged by statistical variance (Req 9.3)
 *  - topPerformers / bottomPerformers: deterministic ranking (Req 9.4)
 *  - leavePatterns: flagged patterns per thresholds (Req 9.5)
 *
 * Query params (optional):
 *  - period: YYYY-MM to scope time-based queries (defaults to current month)
 *  - anomalyThreshold: stdDev threshold (default 2.0)
 *  - topN: number of top/bottom performers to return (default 5)
 *  - maxLeaveDays: threshold for excessive leave (default 15)
 *  - maxSameDayOccurrences: threshold for day-of-week pattern (default 3)
 *  - maxShortLeaves: threshold for frequent short leave (default 5)
 */
export const getDashboardInsightsHandler = authorizedHandler(
    DASHBOARD_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        enforceStaffPermission('view_hr_dashboard', auth.role);

        const pk = businessPK(tenantContext.tenantId, tenantContext.businessId);
        const params = event.queryStringParameters || {};

        // Parse configurable thresholds from query params
        const period = params.period || new Date().toISOString().slice(0, 7); // YYYY-MM
        const anomalyThreshold = parseFloat(params.anomalyThreshold || '') || DEFAULT_ANOMALY_CONFIG.stdDevThreshold;
        const topN = Math.min(Math.max(parseInt(params.topN || '5', 10) || 5, 1), 50);

        const leaveConfig: LeavePatternConfig = {
            maxLeaveDaysPerPeriod: parseInt(params.maxLeaveDays || '', 10) || DEFAULT_LEAVE_PATTERN_CONFIG.maxLeaveDaysPerPeriod,
            maxSameDayOfWeekOccurrences: parseInt(params.maxSameDayOccurrences || '', 10) || DEFAULT_LEAVE_PATTERN_CONFIG.maxSameDayOfWeekOccurrences,
            maxFrequentShortLeaves: parseInt(params.maxShortLeaves || '', 10) || DEFAULT_LEAVE_PATTERN_CONFIG.maxFrequentShortLeaves,
        };

        const baseVals = { ':false': false };

        // ── 1. Attendance Anomaly Detection (Req 9.3) ─────────────────────────

        // Query attendance events for the period
        const { items: attendanceEvents } = await queryItems<Record<string, unknown>>(
            pk,
            `${ATT_SK_PREFIX}${period}`,
            {
                filterExpression: 'entity_type = :et AND (attribute_not_exists(rejected) OR rejected = :false)',
                expressionAttributeValues: { ':et': STAFF_ENTITY_TYPE.ATTENDANCE, ...baseVals },
            },
        );

        // Compute minutes worked per employee per day from check_in/check_out pairs
        const attendanceDataPoints = computeAttendanceMinutes(attendanceEvents);

        const attendanceAnomalies = detectAttendanceAnomalies(
            attendanceDataPoints,
            { stdDevThreshold: anomalyThreshold },
        );

        // ── 2. Performer Ranking (Req 9.4) ────────────────────────────────────

        // Query performance scores for the period
        const { items: perfScores } = await queryItems<Record<string, unknown>>(
            pk,
            PERFSCORE_SK_PREFIX,
            {
                filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':et': STAFF_ENTITY_TYPE.PERFORMANCE_SCORE, ...baseVals },
            },
        );

        // Filter to the requested period and build PerformerEntry list
        const periodScores: PerformerEntry[] = perfScores
            .filter((ps) => (ps.period as string) === period || !params.period)
            .map((ps) => ({
                employeeId: ps.employeeId as string,
                score: ps.score as number,
                period: ps.period as string,
            }));

        const topPerformersList = topPerformers(periodScores, topN);
        const bottomPerformersList = bottomPerformers(periodScores, topN);

        // ── 3. Leave Pattern Flagging (Req 9.5) ───────────────────────────────

        // Query approved leave requests for the period
        const { items: leaveRequests } = await queryItems<Record<string, unknown>>(
            pk,
            LVREQ_SK_PREFIX,
            {
                filterExpression: 'entity_type = :et AND #s = :approved AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: {
                    ':et': STAFF_ENTITY_TYPE.LEAVE_REQUEST,
                    ':approved': 'approved',
                    ...baseVals,
                },
                expressionAttributeNames: { '#s': 'status' },
            },
        );

        // Filter to entries whose dates overlap the period
        const periodStart = `${period}-01`;
        const periodEnd = `${period}-31`; // safe upper bound (DynamoDB filter)

        const leaveHistory: LeaveHistoryEntry[] = leaveRequests
            .filter((lr) =>
                (lr.from as string) <= periodEnd &&
                (lr.to as string) >= periodStart,
            )
            .map((lr) => ({
                employeeId: lr.employeeId as string,
                from: lr.from as string,
                to: lr.to as string,
                leaveTypeId: lr.leaveTypeId as string,
            }));

        const leavePatterns = detectLeavePatterns(leaveHistory, leaveConfig);

        return response.success({
            period,
            thresholds: {
                anomaly: { stdDevThreshold: anomalyThreshold },
                leave: leaveConfig,
                topN,
            },
            attendanceAnomalies,
            topPerformers: topPerformersList,
            bottomPerformers: bottomPerformersList,
            leavePatterns,
        });
    },
);

// ── Helper: Compute minutes worked from attendance events ────────────────────

/**
 * Transform raw attendance events (check_in/check_out) into per-employee
 * per-day minutesWorked data points for anomaly detection.
 *
 * Groups events by (employeeId, date), pairs check_in→check_out, and sums
 * minutes for the day. Unpaired check_ins (no check_out) are excluded.
 */
function computeAttendanceMinutes(
    events: Record<string, unknown>[],
): AttendanceDataPoint[] {
    // Group by employee + date
    const grouped = new Map<string, { checkIns: string[]; checkOuts: string[] }>();

    for (const evt of events) {
        const empId = evt.employeeId as string;
        const ts = evt.timestamp as string;
        const type = evt.type as string;
        if (!empId || !ts || !type) continue;

        const date = ts.slice(0, 10); // YYYY-MM-DD
        const key = `${empId}|${date}`;

        if (!grouped.has(key)) {
            grouped.set(key, { checkIns: [], checkOuts: [] });
        }
        const group = grouped.get(key)!;

        if (type === 'check_in') {
            group.checkIns.push(ts);
        } else if (type === 'check_out') {
            group.checkOuts.push(ts);
        }
    }

    const dataPoints: AttendanceDataPoint[] = [];

    for (const [key, group] of grouped) {
        const [employeeId, date] = key.split('|');

        // Sort timestamps and pair check_in→check_out
        const ins = [...group.checkIns].sort();
        const outs = [...group.checkOuts].sort();

        let totalMinutes = 0;
        const pairCount = Math.min(ins.length, outs.length);

        for (let i = 0; i < pairCount; i++) {
            const inMs = Date.parse(ins[i]);
            const outMs = Date.parse(outs[i]);
            if (!Number.isNaN(inMs) && !Number.isNaN(outMs) && outMs > inMs) {
                totalMinutes += (outMs - inMs) / (1000 * 60);
            }
        }

        // Only include days where we have at least one valid pair
        if (pairCount > 0 && totalMinutes > 0) {
            dataPoints.push({ employeeId, date, minutesWorked: totalMinutes });
        }
    }

    return dataPoints;
}