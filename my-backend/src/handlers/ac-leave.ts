// ============================================================================
// ACADEMIC COACHING — LEAVE MANAGEMENT MODULE
// ============================================================================
// Leave application and approval workflow for students and staff
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  queryItems,
  putItem,
  getItem,
  updateItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { z } from 'zod';
import {
  ApplyLeaveSchema,
  ApproveLeaveSchema,
} from '../schemas/academic-coaching.schema';

const AC_LEAVE_OPTS = {
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
// LEAVE APPLICATION
// ============================================================================

/**
 * GET /ac/leave
 * List leave applications
 */
export const listLeaveApplications = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let leaves = await queryAllItems(pk, 'AC_LEAVE#');

    if (p.personType) leaves = leaves.filter((l: any) => l.personType === p.personType);
    if (p.personId) leaves = leaves.filter((l: any) => l.personId === p.personId);
    if (p.status) leaves = leaves.filter((l: any) => l.status === p.status);
    if (p.leaveType) leaves = leaves.filter((l: any) => l.leaveType === p.leaveType);
    if (p.fromDate && p.toDate) {
      leaves = leaves.filter((l: any) => l.fromDate >= (p.fromDate || '') && l.toDate <= (p.toDate || ''));
    }

    // Sort by applied date desc
    leaves.sort((a: any, b: any) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = leaves.length;
    const paged = leaves.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_LEAVE_OPTS,
);

/**
 * GET /ac/leave/{id}
 * Get leave application details
 */
export const getLeaveApplication = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Leave ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const leave = await getItem(pk, `AC_LEAVE#${id}`);
    
    if (!leave) return response.notFound('Leave application not found');

    return response.success(leave);
  },
  AC_LEAVE_OPTS,
);

/**
 * POST /ac/leave
 * Apply for leave
 */
export const applyLeave = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = ApplyLeaveSchema.parse(body);

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    // Calculate leave days
    const fromDate = new Date(validated.fromDate);
    const toDate = new Date(validated.toDate);
    const leaveDays = Math.ceil((toDate.getTime() - fromDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;

    const leave = {
      PK: pk,
      SK: `AC_LEAVE#${id}`,
      GSI1PK: `AC_LEAVE_BY_PERSON#${auth.tenantId}#${validated.personType}#${validated.personId}`,
      GSI1SK: ts,
      id,
      ...validated,
      leaveDays,
      status: 'pending',
      appliedBy: auth.sub,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(leave);

    logger.info('Leave applied', { tenantId: auth.tenantId, leaveId: id, personType: validated.personType });

    return response.success(leave, 201);
  },
  AC_LEAVE_OPTS,
);

/**
 * POST /ac/leave/{id}/approve
 * Approve or reject leave
 */
export const approveLeave = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Leave ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = ApproveLeaveSchema.parse({ ...body, leaveId: id });

    const pk = Keys.tenantPK(auth.tenantId);
    const leave = await getItem<any>(pk, `AC_LEAVE#${id}`);
    
    if (!leave) return response.notFound('Leave application not found');
    if (leave.status !== 'pending') {
      return response.error(400, 'INVALID_STATUS', 'Leave already processed');
    }

    const ts = now();
    const newStatus = validated.approved ? 'approved' : 'rejected';

    await updateItem(pk, `AC_LEAVE#${id}`, {
      updateExpression: 'SET #status = :status, #approvedBy = :approvedBy, #approvedAt = :approvedAt, #remarks = :remarks, #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#approvedBy': 'approvedBy',
        '#approvedAt': 'approvedAt',
        '#remarks': 'remarks',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':status': newStatus,
        ':approvedBy': auth.sub,
        ':approvedAt': ts,
        ':remarks': validated.remarks || '',
        ':updatedAt': ts,
      },
    });

    // If approved, mark attendance as 'leave' for the date range
    if (validated.approved) {
      // This could be done via a scheduled job or DynamoDB stream
      logger.info('Leave approved - attendance update pending', {
        tenantId: auth.tenantId,
        leaveId: id,
        personId: leave.personId,
        fromDate: leave.fromDate,
        toDate: leave.toDate,
      });
    }

    return response.success({
      id,
      status: newStatus,
      approvedBy: auth.sub,
      approvedAt: ts,
    });
  },
  AC_LEAVE_OPTS,
);

/**
 * GET /ac/leave/person/{personType}/{personId}
 * Get leave history for a person
 */
export const getPersonLeaveHistory = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const { personType, personId } = event.pathParameters || {};
    if (!personType || !personId) return response.badRequest('personType and personId required');

    const p = event.queryStringParameters || {};

    const leaves = await queryAllItems(
      `AC_LEAVE_BY_PERSON#${auth.tenantId}#${personType}#${personId}`,
      '',
      { indexName: 'GSI1' }
    );

    // Calculate leave balance (simplified - per year)
    const currentYear = new Date().getFullYear().toString();
    const yearLeaves = leaves.filter((l: any) => 
      l.status === 'approved' && l.fromDate.startsWith(currentYear)
    );

    const summary = {
      totalLeaves: leaves.length,
      pending: leaves.filter((l: any) => l.status === 'pending').length,
      approved: leaves.filter((l: any) => l.status === 'approved').length,
      rejected: leaves.filter((l: any) => l.status === 'rejected').length,
      thisYearApproved: yearLeaves.length,
      thisYearDays: yearLeaves.reduce((sum: number, l: any) => sum + (l.leaveDays || 0), 0),
    };

    return response.success({ leaves, summary });
  },
  AC_LEAVE_OPTS,
);

/**
 * GET /ac/leave/balance/{personType}/{personId}
 * Get leave balance for a person
 */
export const getLeaveBalance = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const { personType, personId } = event.pathParameters || {};
    if (!personType || !personId) return response.badRequest('personType and personId required');

    const pk = Keys.tenantPK(auth.tenantId);
    const currentYear = new Date().getFullYear().toString();

    // Get all approved leaves for this year
    const leaves = await queryAllItems(
      `AC_LEAVE_BY_PERSON#${auth.tenantId}#${personType}#${personId}`,
      '',
      { indexName: 'GSI1' }
    );

    const yearLeaves = leaves.filter((l: any) => 
      l.status === 'approved' && l.fromDate.startsWith(currentYear)
    );

    // Default entitlements (can be configured per tenant)
    const entitlements: Record<string, number> = {
      sick: 12,
      casual: 10,
      emergency: 5,
      other: 2,
    };

    const used: Record<string, number> = {};
    for (const leave of yearLeaves as any[]) {
      used[leave.leaveType] = (used[leave.leaveType] || 0) + (leave.leaveDays || 1);
    }

    const balance: Record<string, { entitled: number; used: number; remaining: number }> = {};
    for (const [type, entitled] of Object.entries(entitlements)) {
      const typeUsed = used[type] || 0;
      balance[type] = {
        entitled,
        used: typeUsed,
        remaining: Math.max(0, entitled - typeUsed),
      };
    }

    return response.success({
      year: currentYear,
      personType,
      personId,
      balance,
    });
  },
  AC_LEAVE_OPTS,
);

/**
 * GET /ac/leave/pending
 * Get pending leave applications for approver dashboard
 */
export const getPendingLeaves = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const leaves = await queryAllItems(pk, 'AC_LEAVE#', {
      filterExpression: '#status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':status': 'pending' },
    });

    // Sort by application date
    leaves.sort((a: any, b: any) => (a.createdAt || '').localeCompare(b.createdAt || ''));

    // Group by person type
    const grouped = {
      student: leaves.filter((l: any) => l.personType === 'student'),
      faculty: leaves.filter((l: any) => l.personType === 'faculty'),
      staff: leaves.filter((l: any) => l.personType === 'staff'),
    };

    return response.success({
      total: leaves.length,
      grouped,
      all: leaves,
    });
  },
  AC_LEAVE_OPTS,
);
