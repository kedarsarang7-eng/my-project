// ============================================================================
// Lambda Handler — Service/Repair Center (DynamoDB)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, putItem, updateItem, getItem } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import * as schemas from '../schemas/mobile.schema';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';

const SERVICE_OPTS = { requiredBusinessType: BusinessType.SERVICE, requiredFeature: FeatureKey.SERVICE_BASIC_APPOINTMENT };

/**
 * GET /service/jobs — Active repair jobs for logged-in technician
 */
export const getMyJobs = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const jobs = await queryItems<Record<string, any>>(pk, 'SERVICEJOB#', {
        filterExpression: 'assignedTechnicianId = :techId AND NOT #s IN (:s1, :s2) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':techId': auth.sub, ':s1': 'delivered', ':s2': 'cancelled', ':false': false },
        expressionAttributeNames: { '#s': 'status' },
    });

    // Enrich with customer info
    const result = await Promise.all(jobs.items.map(async j => {
        const customer = j.customerId ? await getItem<Record<string, any>>(pk, `UDHARPERSON#${j.customerId}`) : null;
        return {
            id: j.id, customerId: j.customerId, deviceMake: j.deviceMake,
            deviceModel: j.deviceModel, imeiSerial: j.imeiSerial,
            problemDescription: j.problemDescription, status: j.status,
            estimatedDeliveryDate: j.estimatedDeliveryDate,
            estimatedCostCents: j.estimatedCostCents,
            customerName: customer?.name || '',
        };
    }));

    result.sort((a, b) => (a.estimatedDeliveryDate || '').localeCompare(b.estimatedDeliveryDate || ''));
    return response.success(result);
}, SERVICE_OPTS);

/**
 * PUT /service/jobs/{id}/status — Update repair status
 */
export const updateJobStatus = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const jobId = event.pathParameters?.id;
    if (!jobId) return response.badRequest('Missing job ID');

    const valid = parseBody(schemas.serviceJobStatusSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        await updateItem(pk, `SERVICEJOB#${jobId}`, {
            updateExpression: 'SET #s = :status, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':status': body.status, ':now': now },
        });

        await putItem({
            PK: pk, SK: `SERVICEJOBSTATUS#${crypto.randomUUID()}`,
            entityType: 'SERVICE_JOB_STATUS', tenantId: auth.tenantId,
            serviceJobId: jobId, status: body.status,
            notes: body.techNotes || null, changedBy: auth.sub,
            createdAt: now,
        });

        return response.success({ message: 'Job status updated' });
    } catch (err) {
        logger.error('Failed to update job status', { error: err });
        return response.internalError('Failed to update job status');
    }
}, SERVICE_OPTS);

/**
 * POST /service/jobs/{id}/parts — Consume inventory parts for a repair
 */
export const addJobParts = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const jobId = event.pathParameters?.id;
    if (!jobId) return response.badRequest('Missing job ID');

    const valid = parseBody(schemas.serviceJobPartsSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        // Verify job exists
        const job = await getItem<Record<string, any>>(pk, `SERVICEJOB#${jobId}`);
        if (!job || job.isDeleted || job.assignedTechnicianId !== auth.sub) {
            throw new Error('Job not found or unauthorized');
        }

        let partsCost = 0;

        for (const part of body.parts) {
            // Deduct stock
            const product = await getItem<Record<string, any>>(pk, Keys.productSK(part.inventoryId));
            if (product) {
                const newStock = Math.max((Number(product.currentStock) || 0) - part.quantity, 0);
                await updateItem(pk, Keys.productSK(part.inventoryId), {
                    updateExpression: 'SET currentStock = :stock, updatedAt = :now',
                    expressionAttributeValues: { ':stock': newStock, ':now': now },
                });
            }

            // Record part usage
            await putItem({
                PK: pk, SK: `SERVICEJOBPART#${crypto.randomUUID()}`,
                entityType: 'SERVICE_JOB_PART', tenantId: auth.tenantId,
                serviceJobId: jobId, inventoryId: part.inventoryId,
                quantity: part.quantity, unitPriceCents: part.priceCents,
                totalPriceCents: part.priceCents * part.quantity,
                createdAt: now,
            });

            partsCost += part.priceCents * part.quantity;
        }

        // Update estimated cost
        const newCost = (Number(job.estimatedCostCents) || 0) + partsCost;
        await updateItem(pk, `SERVICEJOB#${jobId}`, {
            updateExpression: 'SET estimatedCostCents = :cost, updatedAt = :now',
            expressionAttributeValues: { ':cost': newCost, ':now': now },
        });

        return response.success({ message: `${body.parts.length} parts added to job` }, 201);
    } catch (err: any) {
        logger.error('Failed to add parts to job', { error: err.message });
        return response.internalError(err.message || 'Failed to add parts to job');
    }
}, SERVICE_OPTS);
