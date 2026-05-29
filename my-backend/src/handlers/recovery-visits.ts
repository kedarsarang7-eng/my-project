// ============================================================================
// Credit recovery visits — register + report (p21)
// PK=TENANT#{tenantId}, SK=RECOVERYVISIT#{uuid}
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { v4 as uuid } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, getItem, putItem, queryAllItems } from '../config/dynamodb.config';
import { parseBody, parseQuery } from '../middleware/validation';
import * as response from '../utils/response';
import { AuthContext, UserRole } from '../types/tenant.types';
import { recordRevision } from '../services/revision-history.service';

const RECOVERY_OUTCOMES = [
    'contacted',
    'promised_payment',
    'partial_received',
    'refused',
    'no_answer',
    'not_home',
    'legal_notice',
    'other',
] as const;

const recoveryVisitBodySchema = z.object({
    customerId: z.string().uuid(),
    outcome: z.enum(RECOVERY_OUTCOMES),
    outstandingSnapshotCents: z.number().int().nonnegative().optional(),
    promiseDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    invoiceId: z.string().uuid().optional(),
    notes: z.string().max(2000).optional(),
    visitedAt: z.string().datetime().optional(),
});

const recoveryRegisterQuerySchema = z.object({
    from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    customerId: z.string().uuid().optional(),
    outcome: z.enum(RECOVERY_OUTCOMES).optional(),
    customerSearch: z.string().min(1).max(80).optional(),
    promiseOverdueOnly: z.enum(['true', 'false']).optional(),
});

function visitDay(iso: string): string {
    return iso.length >= 10 ? iso.substring(0, 10) : '';
}

function promiseOverdue(promiseDate: unknown, todayYmd: string): boolean {
    const d = typeof promiseDate === 'string' && promiseDate.length >= 10 ? promiseDate.substring(0, 10) : '';
    return !!d && d < todayYmd;
}

/**
 * POST /customers/recovery-visits — log field visit / follow-up against udhar party
 */
export const recordRecoveryVisit = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(recoveryVisitBodySchema, event);
        if (!parsed.success) return parsed.error;

        const body = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const customer = await getItem<Record<string, any>>(pk, Keys.customerSK(body.customerId));
        if (!customer || customer.isDeleted) {
            return response.notFound('Customer');
        }

        const now = new Date().toISOString();
        const visitedAt = body.visitedAt ? new Date(body.visitedAt).toISOString() : now;
        const visitId = uuid();

        await putItem({
            PK: pk,
            SK: Keys.recoveryVisitSK(visitId),
            entityType: 'RECOVERY_VISIT',
            id: visitId,
            tenantId: auth.tenantId,
            customerId: body.customerId,
            customerName: String(customer.name || ''),
            customerPhone: customer.phone || null,
            outcome: body.outcome,
            outstandingSnapshotCents: body.outstandingSnapshotCents ?? null,
            promiseDate: body.promiseDate || null,
            invoiceId: body.invoiceId || null,
            notes: body.notes || null,
            visitedAt,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });
        await recordRevision(
            auth.tenantId,
            'recovery_visits',
            visitId,
            'create',
            auth.sub,
            null,
            {
                id: visitId,
                customerId: body.customerId,
                outcome: body.outcome,
                outstandingSnapshotCents: body.outstandingSnapshotCents ?? null,
                promiseDate: body.promiseDate || null,
                visitedAt,
            },
            { source: 'recovery-visits.recordRecoveryVisit' },
        );

        return response.success({
            id: visitId,
            customerId: body.customerId,
            outcome: body.outcome,
            visitedAt,
        }, 201);
    },
);

/**
 * GET /customers/recovery-visits — recovery register for period (filters optional)
 */
export const listRecoveryRegister = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(recoveryRegisterQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { from, to, customerId, outcome, customerSearch, promiseOverdueOnly } = parsed.data;
        if (from > to) {
            return response.badRequest('from must be <= to');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const rows = await queryAllItems<Record<string, any>>(pk, 'RECOVERYVISIT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const todayYmd = new Date().toISOString().substring(0, 10);
        const search = (customerSearch || '').trim().toLowerCase();

        let filtered = rows.filter((r) => {
            const day = visitDay(String(r.visitedAt || r.createdAt || ''));
            if (!day || day < from || day > to) return false;
            if (customerId && String(r.customerId) !== customerId) return false;
            if (outcome && String(r.outcome) !== outcome) return false;
            if (search) {
                const name = String(r.customerName || '').toLowerCase();
                const phone = String(r.customerPhone || '').toLowerCase();
                if (!name.includes(search) && !phone.includes(search)) return false;
            }
            return true;
        });

        const withOverdueFlag: Array<Record<string, any> & { _promiseOverdue: boolean }> = filtered.map((r) => ({
            ...r,
            _promiseOverdue: promiseOverdue(r.promiseDate, todayYmd),
        }));

        const filtered2 = promiseOverdueOnly === 'true'
            ? withOverdueFlag.filter((r) => r._promiseOverdue)
            : withOverdueFlag;

        filtered2.sort((a, b) =>
            String(b.visitedAt || b.createdAt || '').localeCompare(String(a.visitedAt || a.createdAt || '')),
        );

        const byOutcome: Record<string, number> = {};
        const partyIds = new Set<string>();
        let promiseOverdueCount = 0;
        let outstandingSnapshotSumCents = 0;

        for (const r of filtered2) {
            const o = String(r.outcome || 'unknown');
            byOutcome[o] = (byOutcome[o] || 0) + 1;
            if (r.customerId) partyIds.add(String(r.customerId));
            if (r._promiseOverdue) promiseOverdueCount += 1;
            const snap = Number(r.outstandingSnapshotCents || 0);
            if (snap > 0) outstandingSnapshotSumCents += snap;
        }

        const items = filtered2.map((r) => ({
            id: r.id,
            customerId: r.customerId,
            customerName: r.customerName,
            customerPhone: r.customerPhone,
            outcome: r.outcome,
            outstandingSnapshotCents: r.outstandingSnapshotCents ?? null,
            promiseDate: r.promiseDate ?? null,
            promiseOverdue: r._promiseOverdue,
            invoiceId: r.invoiceId ?? null,
            notes: r.notes ?? null,
            visitedAt: r.visitedAt || r.createdAt,
            createdBy: r.createdBy,
        }));

        return response.success({
            period: { from, to },
            filter: {
                customerId: customerId || null,
                outcome: outcome || null,
                customerSearch: customerSearch || null,
                promiseOverdueOnly: promiseOverdueOnly === 'true',
            },
            summary: {
                visitCount: items.length,
                uniqueParties: partyIds.size,
                promiseOverdueCount,
                outstandingSnapshotSumCents,
                byOutcome,
            },
            items,
        });
    },
);
