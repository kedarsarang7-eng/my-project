// ============================================================================
// ACADEMIC COACHING — CONCESSION MANAGEMENT MODULE
// ============================================================================
// Fee concessions for staff children, siblings, merit students
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

const AC_CONCESSION_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_FEE_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

/**
 * POST /ac/concessions
 * Apply for fee concession
 */
export const applyConcession = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const {
      studentId,
      concessionType, // 'staff_child', 'sibling', 'merit', 'sports', 'financial_aid', 'other'
      percentage,
      amountPaisa,
      reason,
      documents,
      effectiveFrom,
      effectiveTo,
    } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify student exists
    const student = await getItem(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    const id = uid();
    const ts = now();

    const concession = {
      PK: pk,
      SK: `AC_CONCESSION#${id}`,
      GSI1PK: `AC_CONCESSIONS_BY_STUDENT#${auth.tenantId}#${studentId}`,
      GSI1SK: ts,
      id,
      studentId,
      studentName: `${(student as any).firstName} ${(student as any).lastName}`,
      concessionType,
      percentage: percentage || 0,
      amountPaisa: amountPaisa || 0,
      reason,
      documents: documents || [],
      effectiveFrom,
      effectiveTo,
      status: 'pending',
      appliedBy: auth.sub,
      appliedAt: ts,
      approvedBy: null,
      approvedAt: null,
      remarks: '',
    };

    await putItem(concession);

    logger.info('Concession applied', { tenantId: auth.tenantId, concessionId: id, studentId, type: concessionType });

    return response.success(concession, 201);
  },
  AC_CONCESSION_OPTS,
);

/**
 * POST /ac/concessions/{id}/approve
 * Approve/reject concession
 */
export const approveConcession = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Concession ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { approved, remarks } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const concession = await getItem<any>(pk, `AC_CONCESSION#${id}`);
    
    if (!concession) return response.notFound('Concession not found');
    if (concession.status !== 'pending') {
      return response.error(400, 'ALREADY_PROCESSED', 'Concession already processed');
    }

    const ts = now();
    const newStatus = approved ? 'approved' : 'rejected';

    await updateItem(pk, `AC_CONCESSION#${id}`, {
      updateExpression: 'SET #status = :status, #approvedBy = :approvedBy, #approvedAt = :approvedAt, #remarks = :remarks',
      expressionAttributeNames: {
        '#status': 'status',
        '#approvedBy': 'approvedBy',
        '#approvedAt': 'approvedAt',
        '#remarks': 'remarks',
      },
      expressionAttributeValues: {
        ':status': newStatus,
        ':approvedBy': auth.sub,
        ':approvedAt': ts,
        ':remarks': remarks || '',
      },
    });

    logger.info('Concession approved', { tenantId: auth.tenantId, concessionId: id, approved, approvedBy: auth.sub });

    return response.success({
      id,
      status: newStatus,
      approvedBy: auth.sub,
      approvedAt: ts,
    });
  },
  AC_CONCESSION_OPTS,
);

/**
 * GET /ac/concessions
 * List concessions with filters
 */
export const listConcessions = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let concessions = [];

    if (p.studentId) {
      concessions = await queryAllItems(
        `AC_CONCESSIONS_BY_STUDENT#${auth.tenantId}#${p.studentId}`,
        '',
        { indexName: 'GSI1' }
      );
    } else {
      concessions = await queryAllItems(pk, 'AC_CONCESSION#');
    }

    if (p.status) concessions = concessions.filter((c: any) => c.status === p.status);
    if (p.type) concessions = concessions.filter((c: any) => c.concessionType === p.type);

    // Sort by applied date desc
    concessions.sort((a: any, b: any) => (b.appliedAt || '').localeCompare(a.appliedAt || ''));

    return response.success(concessions);
  },
  AC_CONCESSION_OPTS,
);

/**
 * GET /ac/concessions/student/{studentId}/active
 * Get active concession for a student
 */
export const getActiveConcession = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    const concessions = await queryAllItems(
      `AC_CONCESSIONS_BY_STUDENT#${auth.tenantId}#${studentId}`,
      '',
      { indexName: 'GSI1' }
    );

    const today = now().split('T')[0];
    const active = concessions.filter((c: any) =>
      c.status === 'approved' &&
      c.effectiveFrom <= today &&
      (c.effectiveTo >= today || !c.effectiveTo)
    );

    // Calculate total concession percentage
    const totalPercentage = active.reduce((sum: number, c: any) => sum + (c.percentage || 0), 0);
    const totalAmountPaisa = active.reduce((sum: number, c: any) => sum + (c.amountPaisa || 0), 0);

    return response.success({
      studentId,
      activeConcessions: active,
      totalPercentage,
      totalAmount: totalAmountPaisa / 100,
      count: active.length,
    });
  },
  AC_CONCESSION_OPTS,
);

/**
 * GET /ac/concessions/types
 * Get concession types and auto-calculation rules
 */
export const getConcessionTypes = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const types = [
      { id: 'staff_child', name: 'Staff Child', autoPercentage: 25, maxSiblings: null },
      { id: 'sibling', name: 'Sibling Discount', autoPercentage: 5, maxSiblings: null },
      { id: 'merit', name: 'Merit Scholarship', autoPercentage: 0, maxSiblings: null },
      { id: 'sports', name: 'Sports Excellence', autoPercentage: 0, maxSiblings: null },
      { id: 'financial_aid', name: 'Financial Aid', autoPercentage: 0, maxSiblings: null },
      { id: 'other', name: 'Other', autoPercentage: 0, maxSiblings: null },
    ];

    return response.success(types);
  },
  AC_CONCESSION_OPTS,
);

/**
 * POST /ac/concessions/auto-apply
 * Auto-apply sibling and staff concessions
 */
export const autoApplyConcessions = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { studentId } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const applied = [];

    // Get student
    const student = await getItem<any>(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    // Check for siblings
    const familyGroupId = student.familyGroupId;
    if (familyGroupId) {
      // Check if already has sibling concession
      const existingSibling = await queryAllItems(pk, 'AC_CONCESSION#', {
        filterExpression: 'studentId = :studentId AND concessionType = :type AND #status = :status',
        expressionAttributeNames: { '#status': 'status' },
        expressionAttributeValues: { ':studentId': studentId, ':type': 'sibling', ':status': 'approved' },
      });

      if (existingSibling.length === 0) {
        // Get siblings
        const siblings = await queryAllItems(pk, 'AC_SIBLING_LINK#', {
          filterExpression: '(student1Id = :id OR student2Id = :id)',
          expressionAttributeValues: { ':id': studentId },
        });

        if (siblings.length > 0) {
          // Apply 5% sibling concession
          const id = uid();
          const ts = now();

          const concession = {
            PK: pk,
            SK: `AC_CONCESSION#${id}`,
            GSI1PK: `AC_CONCESSIONS_BY_STUDENT#${auth.tenantId}#${studentId}`,
            GSI1SK: ts,
            id,
            studentId,
            studentName: `${student.firstName} ${student.lastName}`,
            concessionType: 'sibling',
            percentage: 5,
            amountPaisa: 0,
            reason: `Has ${siblings.length} sibling(s) enrolled`,
            documents: [],
            effectiveFrom: ts.split('T')[0],
            effectiveTo: null,
            status: 'approved', // Auto-approved
            appliedBy: auth.sub,
            appliedAt: ts,
            approvedBy: auth.sub,
            approvedAt: ts,
            remarks: 'Auto-applied based on sibling records',
          };

          await putItem(concession);
          applied.push(concession);
        }
      }
    }

    // Check for staff child
    const parentStaffId = student.parentStaffId;
    if (parentStaffId) {
      const existingStaff = await queryAllItems(pk, 'AC_CONCESSION#', {
        filterExpression: 'studentId = :studentId AND concessionType = :type AND #status = :status',
        expressionAttributeNames: { '#status': 'status' },
        expressionAttributeValues: { ':studentId': studentId, ':type': 'staff_child', ':status': 'approved' },
      });

      if (existingStaff.length === 0) {
        const id = uid();
        const ts = now();

        const concession = {
          PK: pk,
          SK: `AC_CONCESSION#${id}`,
          GSI1PK: `AC_CONCESSIONS_BY_STUDENT#${auth.tenantId}#${studentId}`,
          GSI1SK: ts,
          id,
          studentId,
          studentName: `${student.firstName} ${student.lastName}`,
          concessionType: 'staff_child',
          percentage: 25,
          amountPaisa: 0,
          reason: 'Parent is staff member',
          documents: [],
          effectiveFrom: ts.split('T')[0],
          effectiveTo: null,
          status: 'approved',
          appliedBy: auth.sub,
          appliedAt: ts,
          approvedBy: auth.sub,
          approvedAt: ts,
          remarks: 'Auto-applied: Staff child',
        };

        await putItem(concession);
        applied.push(concession);
      }
    }

    return response.success({
      studentId,
      applied: applied.length,
      concessions: applied,
    });
  },
  AC_CONCESSION_OPTS,
);

/**
 * GET /ac/concessions/summary
 * Concession summary for reporting
 */
export const getConcessionSummary = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { month, year } = p;

    const pk = Keys.tenantPK(auth.tenantId);

    const concessions = await queryAllItems(pk, 'AC_CONCESSION#');

    const summary = {
      totalApplied: concessions.length,
      byStatus: {} as Record<string, number>,
      byType: {} as Record<string, number>,
      totalPercentageApproved: 0,
      totalAmountApprovedPaisa: 0,
    };

    for (const c of concessions as any[]) {
      summary.byStatus[c.status] = (summary.byStatus[c.status] || 0) + 1;
      summary.byType[c.concessionType] = (summary.byType[c.concessionType] || 0) + 1;
      
      if (c.status === 'approved') {
        summary.totalPercentageApproved += c.percentage || 0;
        summary.totalAmountApprovedPaisa += c.amountPaisa || 0;
      }
    }

    return response.success(summary);
  },
  AC_CONCESSION_OPTS,
);
