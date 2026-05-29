import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody, parseQuery } from '../middleware/validation';
import { FeatureKey } from '../config/plan-feature-registry';
import { BusinessType, UserRole } from '../types/tenant.types';
import { Keys, getItem, putItem, queryItems, updateItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logAudit } from '../middleware/audit';
import { recordRevision } from '../services/revision-history.service';

const HW_DEPOSIT_OPTS = {
    requiredBusinessType: BusinessType.HARDWARE,
    requiredFeature: FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
};

const createDepositSchema = z.object({
    customerId: z.string().uuid(),
    customerName: z.string().max(200).optional(),
    itemType: z.string().min(1).max(100),
    referenceNo: z.string().max(100).optional(),
    quantity: z.number().positive(),
    depositAmountCents: z.number().int().positive(),
    notes: z.string().max(1000).optional(),
});

const settleDepositSchema = z.object({
    returnedQuantity: z.number().positive(),
    refundAmountCents: z.number().int().min(0),
    notes: z.string().max(1000).optional(),
});

const listSchema = z.object({
    customerId: z.string().uuid().optional(),
    status: z.enum(['open', 'closed']).optional(),
});

export const createDeposit = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createDepositSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const id = uuidv4();
        const item = parsed.data;

        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `HWDEPOSIT#${id}`,
            entityType: 'HARDWARE_DEPOSIT',
            id,
            tenantId: auth.tenantId,
            customerId: item.customerId,
            customerName: item.customerName || null,
            itemType: item.itemType,
            referenceNo: item.referenceNo || null,
            quantity: item.quantity,
            returnedQuantity: 0,
            depositAmountCents: item.depositAmountCents,
            refundedAmountCents: 0,
            outstandingDepositCents: item.depositAmountCents,
            status: 'open',
            notes: item.notes || null,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        }, 'attribute_not_exists(PK)');
        await recordRevision(
            auth.tenantId,
            'hardware_deposits',
            id,
            'create',
            auth.sub,
            null,
            {
                customerId: item.customerId,
                itemType: item.itemType,
                quantity: item.quantity,
                depositAmountCents: item.depositAmountCents,
                status: 'open',
            },
            { source: 'hardware-deposits.createDeposit' },
        );

        logAudit({
            action: 'HW_DEPOSIT_CREATED',
            resource: 'hardware_deposit',
            resourceId: id,
            metadata: {
                customerId: item.customerId,
                itemType: item.itemType,
                quantity: item.quantity,
                depositAmountCents: item.depositAmountCents,
            },
        }).catch(() => { });

        return response.success({ id, status: 'open' }, 201);
    },
    HW_DEPOSIT_OPTS,
);

export const settleDeposit = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const depositId = event.pathParameters?.id;
        if (!depositId) return response.badRequest('Missing deposit id');

        const parsed = parseBody(settleDepositSchema, event);
        if (!parsed.success) return parsed.error;
        const payload = parsed.data;

        const existing = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), `HWDEPOSIT#${depositId}`);
        if (!existing || existing.isDeleted) return response.notFound('Deposit');
        if (existing.status === 'closed') return response.error(409, 'DEPOSIT_ALREADY_CLOSED', 'Deposit already closed');

        const newReturnedQty = Number(existing.returnedQuantity || 0) + payload.returnedQuantity;
        const totalQty = Number(existing.quantity || 0);
        if (newReturnedQty > totalQty) {
            return response.error(422, 'RETURN_QTY_EXCEEDS_DEPOSIT', `Cannot return ${newReturnedQty}; deposited qty is ${totalQty}`);
        }

        const newRefunded = Number(existing.refundedAmountCents || 0) + payload.refundAmountCents;
        const depositAmount = Number(existing.depositAmountCents || 0);
        if (newRefunded > depositAmount) {
            return response.error(422, 'REFUND_EXCEEDS_DEPOSIT', `Cannot refund ${newRefunded}; deposited amount is ${depositAmount}`);
        }

        const outstanding = depositAmount - newRefunded;
        const status = (newReturnedQty >= totalQty && outstanding <= 0) ? 'closed' : 'open';
        const now = new Date().toISOString();

        await updateItem(Keys.tenantPK(auth.tenantId), `HWDEPOSIT#${depositId}`, {
            updateExpression: 'SET returnedQuantity = :rq, refundedAmountCents = :ref, outstandingDepositCents = :out, #s = :st, settlementNotes = :n, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':rq': newReturnedQty,
                ':ref': newRefunded,
                ':out': outstanding,
                ':st': status,
                ':n': payload.notes || null,
                ':now': now,
            },
            conditionExpression: 'attribute_exists(PK)',
        });
        await recordRevision(
            auth.tenantId,
            'hardware_deposits',
            depositId,
            status === 'closed' ? 'status_change' : 'update',
            auth.sub,
            {
                returnedQuantity: Number(existing.returnedQuantity || 0),
                refundedAmountCents: Number(existing.refundedAmountCents || 0),
                outstandingDepositCents: Number(existing.outstandingDepositCents || existing.depositAmountCents || 0),
                status: existing.status || 'open',
            },
            {
                returnedQuantity: newReturnedQty,
                refundedAmountCents: newRefunded,
                outstandingDepositCents: outstanding,
                status,
            },
            { source: 'hardware-deposits.settleDeposit' },
        );

        return response.success({
            id: depositId,
            status,
            returnedQuantity: newReturnedQty,
            refundedAmountCents: newRefunded,
            outstandingDepositCents: outstanding,
        });
    },
    HW_DEPOSIT_OPTS,
);

export const listDeposits = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseQuery(listSchema, event);
        if (!parsed.success) return parsed.error;
        const { customerId, status } = parsed.data;

        const filters: string[] = ['(attribute_not_exists(isDeleted) OR isDeleted = :false)'];
        const values: Record<string, unknown> = { ':false': false };
        if (customerId) {
            filters.push('customerId = :cid');
            values[':cid'] = customerId;
        }
        if (status) {
            filters.push('#s = :st');
            values[':st'] = status;
        }

        const result = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'HWDEPOSIT#', {
            filterExpression: filters.join(' AND '),
            expressionAttributeValues: values,
            expressionAttributeNames: status ? { '#s': 'status' } : undefined,
            scanIndexForward: false,
            limit: 200,
        });

        return response.success({ items: result.items });
    },
    HW_DEPOSIT_OPTS,
);
