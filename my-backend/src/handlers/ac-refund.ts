// ============================================================================
// ACADEMIC COACHING — REFUND WORKFLOW MODULE
// ============================================================================
// Fee refund processing with approval workflow
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

const AC_REFUND_OPTS = {
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
 * POST /ac/refunds
 * Request a refund
 */
export const requestRefund = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const {
      studentId,
      invoiceId,
      paymentId,
      refundType, // 'withdrawal', 'duplicate_payment', 'excess_payment', 'cancellation', 'other'
      amountPaisa,
      reason,
      documents,
    } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify student exists
    const student = await getItem(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    // Verify payment exists
    const payment = await getItem<any>(pk, `AC_PAYMENT#${paymentId}`);
    if (!payment) return response.notFound('Payment not found');

    // Check refund amount doesn't exceed payment
    if (amountPaisa > payment.amountPaisa) {
      return response.error(400, 'EXCESS_AMOUNT', 'Refund amount exceeds payment amount');
    }

    const id = uid();
    const ts = now();

    const refund = {
      PK: pk,
      SK: `AC_REFUND#${id}`,
      GSI1PK: `AC_REFUNDS_BY_STUDENT#${auth.tenantId}#${studentId}`,
      GSI1SK: ts,
      id,
      studentId,
      studentName: `${(student as any).firstName} ${(student as any).lastName}`,
      invoiceId,
      paymentId,
      originalAmountPaisa: payment.amountPaisa,
      refundType,
      amountPaisa,
      reason,
      documents: documents || [],
      status: 'pending',
      requestedBy: auth.sub,
      requestedAt: ts,
      approvedBy: null,
      approvedAt: null,
      processedBy: null,
      processedAt: null,
      utrNumber: null, // UTR for tracking
      remarks: '',
    };

    await putItem(refund);

    logger.info('Refund requested', { tenantId: auth.tenantId, refundId: id, studentId, amount: amountPaisa });

    return response.success(refund, 201);
  },
  AC_REFUND_OPTS,
);

/**
 * POST /ac/refunds/{id}/approve
 * Approve/reject refund request
 */
export const approveRefund = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Refund ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { approved, remarks } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const refund = await getItem<any>(pk, `AC_REFUND#${id}`);
    
    if (!refund) return response.notFound('Refund request not found');
    if (refund.status !== 'pending') {
      return response.error(400, 'ALREADY_PROCESSED', 'Refund already processed');
    }

    const ts = now();
    const newStatus = approved ? 'approved' : 'rejected';

    await updateItem(pk, `AC_REFUND#${id}`, {
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

    logger.info('Refund approved', { tenantId: auth.tenantId, refundId: id, approved, by: auth.sub });

    return response.success({ id, status: newStatus, approvedAt: ts });
  },
  AC_REFUND_OPTS,
);

/**
 * POST /ac/refunds/{id}/process
 * Process approved refund (mark as paid)
 */
export const processRefund = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Refund ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { utrNumber, paymentDate, paymentMethod } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const refund = await getItem<any>(pk, `AC_REFUND#${id}`);
    
    if (!refund) return response.notFound('Refund not found');
    if (refund.status !== 'approved') {
      return response.error(400, 'NOT_APPROVED', 'Refund must be approved before processing');
    }

    const ts = now();

    await updateItem(pk, `AC_REFUND#${id}`, {
      updateExpression: 'SET #status = :status, #processedBy = :processedBy, #processedAt = :processedAt, #utrNumber = :utrNumber, #paymentDate = :paymentDate, #paymentMethod = :paymentMethod',
      expressionAttributeNames: {
        '#status': 'status',
        '#processedBy': 'processedBy',
        '#processedAt': 'processedAt',
        '#utrNumber': 'utrNumber',
        '#paymentDate': 'paymentDate',
        '#paymentMethod': 'paymentMethod',
      },
      expressionAttributeValues: {
        ':status': 'processed',
        ':processedBy': auth.sub,
        ':processedAt': ts,
        ':utrNumber': utrNumber || '',
        ':paymentDate': paymentDate || ts.split('T')[0],
        ':paymentMethod': paymentMethod || 'bank_transfer',
      },
    });

    // Update invoice balance if applicable
    if (refund.invoiceId) {
      const invoice = await getItem<any>(pk, `AC_INVOICE#${refund.invoiceId}`);
      if (invoice) {
        const newBalance = (invoice.balancePaisa || 0) + refund.amountPaisa;
        await updateItem(pk, `AC_INVOICE#${refund.invoiceId}`, {
          updateExpression: 'SET #balancePaisa = :balance, #updatedAt = :updatedAt',
          expressionAttributeNames: { '#balancePaisa': 'balancePaisa', '#updatedAt': 'updatedAt' },
          expressionAttributeValues: { ':balance': newBalance, ':updatedAt': ts },
        });
      }
    }

    logger.info('Refund processed', { tenantId: auth.tenantId, refundId: id, utr: utrNumber });

    return response.success({ id, status: 'processed', processedAt: ts });
  },
  AC_REFUND_OPTS,
);

/**
 * GET /ac/refunds
 * List refunds with filters
 */
export const listRefunds = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let refunds = [];

    if (p.studentId) {
      refunds = await queryAllItems(
        `AC_REFUNDS_BY_STUDENT#${auth.tenantId}#${p.studentId}`,
        '',
        { indexName: 'GSI1' }
      );
    } else {
      refunds = await queryAllItems(pk, 'AC_REFUND#');
    }

    if (p.status) refunds = refunds.filter((r: any) => r.status === p.status);
    if (p.type) refunds = refunds.filter((r: any) => r.refundType === p.type);

    // Sort by requested date desc
    refunds.sort((a: any, b: any) => (b.requestedAt || '').localeCompare(a.requestedAt || ''));

    return response.success(refunds);
  },
  AC_REFUND_OPTS,
);

/**
 * GET /ac/refunds/pending
 * Get pending refunds for approval dashboard
 */
export const getPendingRefunds = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const refunds = await queryAllItems(pk, 'AC_REFUND#', {
      filterExpression: '#status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':status': 'pending' },
    });

    // Sort by amount (highest first)
    refunds.sort((a: any, b: any) => (b.amountPaisa || 0) - (a.amountPaisa || 0));

    const totalAmount = refunds.reduce((sum: number, r: any) => sum + (r.amountPaisa || 0), 0);

    return response.success({
      pendingCount: refunds.length,
      totalAmountPaisa: totalAmount,
      totalAmount: totalAmount / 100,
      refunds,
    });
  },
  AC_REFUND_OPTS,
);

/**
 * GET /ac/refunds/summary
 * Refund summary for reporting
 */
export const getRefundSummary = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { month, year } = p;

    const pk = Keys.tenantPK(auth.tenantId);

    const refunds = await queryAllItems(pk, 'AC_REFUND#');

    // Filter by date if provided
    let filtered = refunds;
    if (month && year) {
      filtered = refunds.filter((r: any) => r.requestedAt?.startsWith(`${year}-${month}`));
    }

    const summary = {
      totalRequested: filtered.length,
      totalAmountPaisa: filtered.reduce((sum: number, r: any) => sum + (r.amountPaisa || 0), 0),
      byStatus: {} as Record<string, { count: number; amountPaisa: number }>,
      byType: {} as Record<string, { count: number; amountPaisa: number }>,
    };

    for (const r of filtered as any[]) {
      const status = r.status;
      if (!summary.byStatus[status]) {
        summary.byStatus[status] = { count: 0, amountPaisa: 0 };
      }
      summary.byStatus[status].count++;
      summary.byStatus[status].amountPaisa += r.amountPaisa || 0;

      const type = r.refundType;
      if (!summary.byType[type]) {
        summary.byType[type] = { count: 0, amountPaisa: 0 };
      }
      summary.byType[type].count++;
      summary.byType[type].amountPaisa += r.amountPaisa || 0;
    }

    return response.success(summary);
  },
  AC_REFUND_OPTS,
);
