// ============================================================================
// Lambda Handler — Shared Prescription Bridge (Clinic <-> Pharmacy)
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { getItem, putItem, updateItem } from '../config/dynamodb.config';
import { AuthContext, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

type SharedRxItem = {
    medicineName: string;
    dosage: string | null;
    duration: string | null;
    instructions: string | null;
    quantity: number | null;
};

function sharedRxPK(): string {
    return 'PRESCRIPTION';
}

function sharedRxSK(rxId: string): string {
    return `PRESCRIPTION#${rxId}`;
}

function parseBody(event: APIGatewayProxyEventV2): Record<string, any> {
    if (!event.body) return {};
    try {
        return JSON.parse(event.body);
    } catch {
        return {};
    }
}

function normalizeItems(raw: unknown): SharedRxItem[] {
    if (!Array.isArray(raw)) return [];
    return raw
        .map((item) => {
            if (!item || typeof item !== 'object') return null;
            const row = item as Record<string, unknown>;
            const medicineName = String(row.medicineName || row.name || '').trim();
            if (!medicineName) return null;
            return {
                medicineName,
                dosage: row.dosage ? String(row.dosage) : null,
                duration: row.duration ? String(row.duration) : null,
                instructions: row.instructions ? String(row.instructions) : null,
                quantity: Number.isFinite(Number(row.quantity)) ? Number(row.quantity) : null,
            };
        })
        .filter((v): v is SharedRxItem => !!v);
}

const ALLOWED = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER];

/**
 * POST /prescriptions — Upload shared prescription
 */
export const uploadSharedPrescription = authorizedHandler(ALLOWED, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const body = parseBody(event);
    const rxId = String(body.rx_id || body.rxId || '').trim();
    const patientName = String(body.patient_name || body.patientName || '').trim();
    const doctorName = String(body.doctor_name || body.doctorName || '').trim();
    const items = normalizeItems(body.items);

    if (!rxId || !patientName || !doctorName) {
        return response.badRequest('Missing required fields: rx_id, patient_name, doctor_name');
    }
    if (!items.length) return response.badRequest('Prescription must have at least one medicine item');

    const existing = await getItem<Record<string, any>>(sharedRxPK(), sharedRxSK(rxId));
    if (existing) return response.conflict('Prescription with this ID already exists');

    const now = new Date().toISOString();
    await putItem({
        PK: sharedRxPK(),
        SK: sharedRxSK(rxId),
        entityType: 'SHARED_PRESCRIPTION',
        rx_id: rxId,
        clinic_shop_id: auth.tenantId,
        doctor_id: String(body.doctor_id || body.doctorId || auth.sub),
        doctor_name: doctorName,
        clinic_name: String(body.clinic_name || body.clinicName || 'Clinic'),
        patient_name: patientName,
        patient_phone: body.patient_phone ? String(body.patient_phone) : (body.patientPhone ? String(body.patientPhone) : null),
        prescription_date: body.prescription_date ? String(body.prescription_date) : now,
        advice: body.advice ? String(body.advice) : null,
        items,
        status: 'pending',
        fulfilled_by: null,
        fulfilled_at: null,
        created_at: now,
        updated_at: now,
    });

    logger.info('Shared prescription uploaded', {
        rxId,
        clinicShopId: auth.tenantId,
        actor: auth.sub,
        itemCount: items.length,
    });
    return response.success({ success: true, rx_id: rxId, message: 'Prescription uploaded successfully' }, 201);
});

/**
 * GET /prescriptions/{rxId} — Fetch shared prescription
 */
export const getSharedPrescription = authorizedHandler(ALLOWED, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const rxId = event.pathParameters?.rxId;
    if (!rxId) return response.badRequest('Missing rxId');

    const row = await getItem<Record<string, any>>(sharedRxPK(), sharedRxSK(rxId));
    if (!row) return response.notFound('Prescription');
    if (row.clinic_shop_id !== auth.tenantId) return response.forbidden('Access denied');

    return response.success({
        prescription: {
            rx_id: row.rx_id,
            clinic_shop_id: row.clinic_shop_id,
            doctor_id: row.doctor_id,
            doctor_name: row.doctor_name,
            clinic_name: row.clinic_name,
            patient_name: row.patient_name,
            patient_phone: row.patient_phone,
            prescription_date: row.prescription_date,
            advice: row.advice,
            items: row.items || [],
            status: row.status,
            fulfilled_by: row.fulfilled_by,
            fulfilled_at: row.fulfilled_at,
            created_at: row.created_at,
        },
    });
});

/**
 * GET /prescriptions/check/{rxId} — Check dispensed status
 */
export const checkSharedPrescription = authorizedHandler(ALLOWED, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const rxId = event.pathParameters?.rxId;
    if (!rxId) return response.badRequest('Missing rxId');

    const row = await getItem<Record<string, any>>(sharedRxPK(), sharedRxSK(rxId));
    if (!row) return response.success({ exists: false, dispensed: false });
    if (row.clinic_shop_id !== auth.tenantId) return response.forbidden('Access denied');

    return response.success({
        exists: true,
        dispensed: row.status === 'dispensed',
        status: row.status,
    });
});

/**
 * PATCH /prescriptions/{rxId}/dispense — Mark as dispensed
 */
export const dispenseSharedPrescription = authorizedHandler(ALLOWED, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const rxId = event.pathParameters?.rxId;
    if (!rxId) return response.badRequest('Missing rxId');

    const row = await getItem<Record<string, any>>(sharedRxPK(), sharedRxSK(rxId));
    if (!row) return response.notFound('Prescription');
    if (row.clinic_shop_id !== auth.tenantId) return response.forbidden('Access denied');
    if (row.status === 'dispensed') return response.conflict('Prescription has already been dispensed');

    const now = new Date().toISOString();
    await updateItem(sharedRxPK(), sharedRxSK(rxId), {
        updateExpression: 'SET #status = :status, fulfilled_by = :fulfilledBy, fulfilled_at = :fulfilledAt, updated_at = :updatedAt',
        expressionAttributeNames: { '#status': 'status' },
        expressionAttributeValues: {
            ':status': 'dispensed',
            ':fulfilledBy': auth.tenantId,
            ':fulfilledAt': now,
            ':updatedAt': now,
        },
    });

    logger.info('Shared prescription dispensed', {
        rxId,
        tenantId: auth.tenantId,
        actor: auth.sub,
    });
    return response.success({ success: true, message: 'Prescription marked as dispensed' });
});
