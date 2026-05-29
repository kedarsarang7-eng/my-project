// ============================================================================
// ACADEMIC COACHING — LESSON PLAN MODULE
// ============================================================================
// Teacher lesson planning with approval workflow
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
  deleteItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { z } from 'zod';
import {
  CreateLessonPlanSchema,
  UpdateLessonPlanSchema,
} from '../schemas/academic-coaching.schema';

const AC_LESSON_PLAN_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_MATERIAL_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

/**
 * GET /ac/lesson-plans
 * List lesson plans with filters
 */
export const listLessonPlans = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let plans = await queryAllItems(pk, 'AC_LESSON_PLAN#');

    // Apply filters
    if (p.batchId) {
      plans = plans.filter((lp: any) => lp.batchId === p.batchId);
    }
    if (p.facultyId) {
      plans = plans.filter((lp: any) => lp.facultyId === p.facultyId);
    }
    if (p.subject) {
      plans = plans.filter((lp: any) => lp.subject === p.subject);
    }
    if (p.status) {
      plans = plans.filter((lp: any) => lp.status === p.status);
    }
    if (p.fromDate && p.toDate) {
      plans = plans.filter((lp: any) => lp.date >= (p.fromDate || '') && lp.date <= (p.toDate || ''));
    }

    // Sort by date desc
    plans.sort((a: any, b: any) => (b.date || '').localeCompare(a.date || ''));

    // Pagination
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = plans.length;
    const paged = plans.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_LESSON_PLAN_OPTS,
);

/**
 * GET /ac/lesson-plans/{id}
 * Get single lesson plan
 */
export const getLessonPlan = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Lesson plan ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const plan = await getItem(pk, `AC_LESSON_PLAN#${id}`);
    
    if (!plan) return response.notFound('Lesson plan not found');

    return response.success(plan);
  },
  AC_LESSON_PLAN_OPTS,
);

/**
 * POST /ac/lesson-plans
 * Create lesson plan
 */
export const createLessonPlan = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = CreateLessonPlanSchema.parse(body);

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const plan = {
      PK: pk,
      SK: `AC_LESSON_PLAN#${id}`,
      GSI1PK: `AC_LESSON_BY_BATCH#${auth.tenantId}#${validated.batchId}`,
      GSI1SK: `${validated.date}#${(validated as any).startTime || '00:00'}`,
      id,
      ...validated,
      submittedBy: auth.sub,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(plan);

    logger.info('Lesson plan created', { tenantId: auth.tenantId, planId: id, batchId: validated.batchId });

    return response.success(plan, 201);
  },
  AC_LESSON_PLAN_OPTS,
);

/**
 * PUT /ac/lesson-plans/{id}
 * Update lesson plan
 */
export const updateLessonPlan = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Lesson plan ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = UpdateLessonPlanSchema.parse(body);

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_LESSON_PLAN#${id}`);
    
    if (!existing) return response.notFound('Lesson plan not found');

    // Only creator or admin can edit
    if (existing.submittedBy !== auth.sub && !['OWNER', 'ADMIN'].includes(auth.role)) {
      return response.error(403, 'FORBIDDEN', 'You can only edit your own lesson plans');
    }

    // Cannot edit approved plans without unapproving first
    if (existing.status === 'approved' && validated.status !== 'draft') {
      return response.error(400, 'INVALID_STATUS', 'Cannot modify approved lesson plan. Set to draft first.');
    }

    const ts = now();
    const updates: any = { ...validated, updatedAt: ts };

    await updateItem(pk, `AC_LESSON_PLAN#${id}`, {
      updateExpression: `SET ${Object.keys(updates).map(k => `#${k} = :${k}`).join(', ')}`,
      expressionAttributeNames: Object.fromEntries(Object.keys(updates).map(k => [`#${k}`, k])),
      expressionAttributeValues: Object.fromEntries(Object.entries(updates).map(([k, v]) => [`:${k}`, v])),
    });

    return response.success({ id, ...updates });
  },
  AC_LESSON_PLAN_OPTS,
);

/**
 * POST /ac/lesson-plans/{id}/approve
 * Approve/reject lesson plan
 */
export const approveLessonPlan = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Lesson plan ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { approved, remarks } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_LESSON_PLAN#${id}`);
    
    if (!existing) return response.notFound('Lesson plan not found');

    const ts = now();
    const newStatus = approved ? 'approved' : 'rejected';

    await updateItem(pk, `AC_LESSON_PLAN#${id}`, {
      updateExpression: 'SET #status = :status, #approvedBy = :approvedBy, #approvedAt = :approvedAt, #approvalRemarks = :remarks, #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#approvedBy': 'approvedBy',
        '#approvedAt': 'approvedAt',
        '#approvalRemarks': 'approvalRemarks',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':status': newStatus,
        ':approvedBy': auth.sub,
        ':approvedAt': ts,
        ':remarks': remarks || '',
        ':updatedAt': ts,
      },
    });

    return response.success({ id, status: newStatus, approvedBy: auth.sub, approvedAt: ts });
  },
  AC_LESSON_PLAN_OPTS,
);

/**
 * DELETE /ac/lesson-plans/{id}
 * Delete lesson plan
 */
export const deleteLessonPlan = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Lesson plan ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_LESSON_PLAN#${id}`);
    
    if (!existing) return response.notFound('Lesson plan not found');

    // Only creator or admin can delete
    if (existing.submittedBy !== auth.sub && !['OWNER', 'ADMIN'].includes(auth.role)) {
      return response.error(403, 'FORBIDDEN', 'You can only delete your own lesson plans');
    }

    await deleteItem(pk, `AC_LESSON_PLAN#${id}`);

    return response.success({ id, deleted: true });
  },
  AC_LESSON_PLAN_OPTS,
);

/**
 * GET /ac/lesson-plans/calendar
 * Get lesson plans in calendar format
 */
export const getLessonPlanCalendar = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { month, year, batchId, facultyId } = p;

    if (!month || !year) {
      return response.badRequest('month and year are required');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const startDate = `${year}-${month.padStart(2, '0')}-01`;
    const endDate = `${year}-${month.padStart(2, '0')}-31`;

    let plans = await queryAllItems(pk, 'AC_LESSON_PLAN#');

    // Filter by date range
    plans = plans.filter((lp: any) => lp.date >= startDate && lp.date <= endDate);

    if (batchId) {
      plans = plans.filter((lp: any) => lp.batchId === batchId);
    }
    if (facultyId) {
      plans = plans.filter((lp: any) => lp.facultyId === facultyId);
    }

    // Group by date
    const calendar: Record<string, any[]> = {};
    for (const plan of plans as any[]) {
      if (!calendar[plan.date]) calendar[plan.date] = [];
      calendar[plan.date].push(plan);
    }

    return response.success({ month, year, calendar, total: plans.length });
  },
  AC_LESSON_PLAN_OPTS,
);
