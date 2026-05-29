import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody, parseQuery } from '../middleware/validation';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, putItem, queryItems } from '../config/dynamodb.config';
import * as response from '../utils/response';

const PHARMACY_COMPLIANCE_OPTS = {
    requiredBusinessType: BusinessType.PHARMACY,
    requiredFeature: FeatureKey.PHARMACY_PRESCRIPTION,
};

const SCHEDULE_RETURN_POLICY: Record<string, { allowed: boolean; code: string; message: string }> = {
    X: { allowed: false, code: 'BLOCK_SCHEDULE_X', message: 'Schedule X medicine returns are blocked.' },
    H1: { allowed: false, code: 'BLOCK_SCHEDULE_H1', message: 'Schedule H1 medicine returns are blocked.' },
};

const STRICT_NO_RETURN_STATES = new Set(['MH', 'KA', 'TN', 'GJ', 'DL']);

const uploadEvidenceSchema = z.object({
    prescriptionId: z.string().min(1).max(100),
    invoiceId: z.string().min(1).max(100).optional(),
    storagePath: z.string().min(1).max(500),
    fileHashSha256: z.string().regex(/^[a-fA-F0-9]{64}$/),
    mimeType: z.string().max(100).optional(),
    doctorName: z.string().max(200).optional(),
    doctorRegNo: z.string().max(50).regex(/^[A-Z]{2,5}-\d{4,8}$/, {
        message: 'doctorRegNo must match format e.g. MCI-12345',
    }).optional(),
    patientName: z.string().max(200).optional(),
    notes: z.string().max(1000).optional(),
});

const evaluatePolicySchema = z.object({
    stateCode: z.string().length(2).toUpperCase(),
    drugSchedule: z.enum(['H', 'H1', 'X', 'OTC', 'UNKNOWN']),
    hasInvoice: z.boolean().default(true),
    invoiceAgeDays: z.number().int().min(0).max(3650).default(0),
    reason: z.string().max(300).optional(),
});

const listEvidenceQuerySchema = z.object({
    prescriptionId: z.string().min(1).max(100).optional(),
    limit: z.coerce.number().int().min(1).max(200).default(50),
});

export const uploadPrescriptionEvidence = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(uploadEvidenceSchema, event);
        if (!parsed.success) return parsed.error;

        const id = uuidv4();
        const now = new Date().toISOString();
        const payload = parsed.data;

        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `RXEVIDENCE#${payload.prescriptionId}#${now}#${id}`,
            entityType: 'RX_EVIDENCE',
            id,
            tenantId: auth.tenantId,
            prescriptionId: payload.prescriptionId,
            invoiceId: payload.invoiceId || null,
            storagePath: payload.storagePath,
            fileHashSha256: payload.fileHashSha256.toLowerCase(),
            mimeType: payload.mimeType || null,
            doctorName: payload.doctorName || null,
            doctorRegNo: payload.doctorRegNo || null,
            patientName: payload.patientName || null,
            notes: payload.notes || null,
            uploadedBy: auth.sub,
            uploadedAt: now,
            createdAt: now,
        }, 'attribute_not_exists(PK)');

        return response.success({ id, prescriptionId: payload.prescriptionId, uploadedAt: now }, 201);
    },
    PHARMACY_COMPLIANCE_OPTS,
);

export const listPrescriptionEvidence = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseQuery(listEvidenceQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { prescriptionId, limit } = parsed.data;
        const prefix = prescriptionId ? `RXEVIDENCE#${prescriptionId}#` : 'RXEVIDENCE#';
        const rows = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), prefix, {
            scanIndexForward: false,
            limit,
        });

        return response.success({
            items: rows.items.map((r) => ({
                id: r.id,
                prescriptionId: r.prescriptionId,
                invoiceId: r.invoiceId,
                storagePath: r.storagePath,
                fileHashSha256: r.fileHashSha256,
                uploadedBy: r.uploadedBy,
                uploadedAt: r.uploadedAt,
            })),
        });
    },
    PHARMACY_COMPLIANCE_OPTS,
);

export const evaluateReturnPolicy = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(evaluatePolicySchema, event);
        if (!parsed.success) return parsed.error;

        const input = parsed.data;
        let allowed = true;
        let policyCode = 'DEFAULT_ALLOW';
        let message = 'Return allowed under default policy.';

        const schedulePolicy = SCHEDULE_RETURN_POLICY[input.drugSchedule];
        if (schedulePolicy) {
            allowed = schedulePolicy.allowed;
            policyCode = schedulePolicy.code;
            message = schedulePolicy.message;
        } else if (STRICT_NO_RETURN_STATES.has(input.stateCode) && input.invoiceAgeDays > 0) {
            allowed = false;
            policyCode = 'STATE_STRICT_NO_RETURN';
            message = `State policy (${input.stateCode}) blocks non-immediate medicine returns.`;
        } else if (!input.hasInvoice) {
            allowed = false;
            policyCode = 'NO_INVOICE';
            message = 'Return blocked: invoice reference required.';
        }

        return response.success({
            allowed,
            policyCode,
            message,
            evaluatedAt: new Date().toISOString(),
            input,
        });
    },
    PHARMACY_COMPLIANCE_OPTS,
);
