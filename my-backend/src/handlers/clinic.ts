// ============================================================================
// Lambda Handler — Clinic Module (DynamoDB)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, putItem, updateItem, getItem, batchGetItems } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import * as schemas from '../schemas/mobile.schema';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import { recordRevision } from '../services/revision-history.service';

const CLINIC_OPTS = { requiredBusinessType: BusinessType.CLINIC, requiredFeature: FeatureKey.CLINIC_TOKEN_SCREEN };
const CLINIC_PRESCRIPTION_OPTS = {
    requiredBusinessType: BusinessType.CLINIC,
    requiredFeature: FeatureKey.CLINIC_E_PRESCRIPTION,
};
const CLINIC_FOLLOWUP_OPTS = {
    requiredBusinessType: BusinessType.CLINIC,
    requiredFeature: FeatureKey.CLINIC_AUTO_FOLLOWUP,
};
const CLINIC_EMR_OPTS = {
    requiredBusinessType: BusinessType.CLINIC,
    requiredFeature: FeatureKey.CLINIC_BASIC_EMR,
};
const CLINIC_LAB_OPTS = {
    requiredBusinessType: BusinessType.CLINIC,
    requiredFeature: FeatureKey.CLINIC_FULL_EMR,
};
const CLINIC_PATIENT_OPTS = {
    requiredBusinessType: BusinessType.CLINIC,
    requiredFeature: FeatureKey.CLINIC_PATIENT_MGMT,
};
const CLINIC_APPOINTMENT_OPTS = {
    requiredBusinessType: BusinessType.CLINIC,
    requiredFeature: FeatureKey.CLINIC_APPOINTMENT_MGMT,
};
const CLINIC_DOCTOR_OPTS = {
    requiredBusinessType: BusinessType.CLINIC,
    requiredFeature: FeatureKey.CLINIC_DOCTOR_PROFILE,
};

function parseLimit(raw: string | undefined, fallback: number, max: number): number {
    const parsed = Number.parseInt(raw || '', 10);
    if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
    return Math.min(parsed, max);
}

function decodePageToken(raw: string | undefined): Record<string, unknown> | undefined {
    if (!raw) return undefined;
    try {
        const decoded = Buffer.from(raw, 'base64').toString('utf8');
        const parsed = JSON.parse(decoded);
        if (parsed && typeof parsed === 'object') return parsed as Record<string, unknown>;
    } catch {
        return undefined;
    }
    return undefined;
}

function encodePageToken(lastKey: Record<string, unknown> | undefined): string | null {
    if (!lastKey) return null;
    return Buffer.from(JSON.stringify(lastKey), 'utf8').toString('base64');
}

/**
 * GET /clinic/appointments — Today's queue for logged-in doctor
 */
export const getMyQueue = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const todayStr = new Date().toISOString().slice(0, 10);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const nextToken = decodePageToken(event.queryStringParameters?.nextToken);

    // Get doctor profile for this user
    const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
        filterExpression: 'userId = :userId',
        expressionAttributeValues: { ':userId': auth.sub },
        limit: 1,
    });
    if (!doctors.items.length) return response.success([]);
    const doctorId = doctors.items[0].id;

    // Get today's appointments
    const appointments = await queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
        filterExpression: 'doctorId = :docId AND appointmentDate = :today AND #s IN (:s1, :s2) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':docId': doctorId, ':today': todayStr, ':s1': 'scheduled', ':s2': 'waiting', ':false': false },
        expressionAttributeNames: { '#s': 'status' },
        limit,
        exclusiveStartKey: nextToken,
    });

    // Enrich with patient info (batch to avoid N+1 lookups)
    const uniquePatientIds = Array.from(new Set(appointments.items.map(a => a.patientId).filter(Boolean)));
    const patientRows = uniquePatientIds.length
        ? await batchGetItems<Record<string, any>>(uniquePatientIds.map((id) => ({ PK: pk, SK: `PATIENT#${id}` })))
        : [];
    const patientById = new Map<string, Record<string, any>>();
    for (const row of patientRows) {
        if (row?.id) patientById.set(String(row.id), row);
    }

    const result = appointments.items.map((a) => {
        const patient = patientById.get(String(a.patientId));
        return {
            id: a.id, patientId: a.patientId,
            patientName: patient?.name || '', age: patient?.age, gender: patient?.gender, bloodGroup: patient?.bloodGroup,
            status: a.status, appointmentTime: a.appointmentTime, reasonForVisit: a.reasonForVisit,
            tokenNumber: a.tokenNumber || 0,
        };
    });

    result.sort((a, b) => (a.appointmentTime || '').localeCompare(b.appointmentTime || ''));
    return response.success(result, 200, {
        limit,
        total: result.length,
        hasMore: !!appointments.lastKey,
        nextCursor: encodePageToken(appointments.lastKey),
    });
}, CLINIC_OPTS);

/**
 * POST /clinic/visits — Record a consultation
 */
export const recordVisit = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicVisitSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        // Get doctor profile
        const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
            filterExpression: 'userId = :userId',
            expressionAttributeValues: { ':userId': auth.sub },
            limit: 1,
        });
        if (!doctors.items.length) throw new Error('Doctor profile not found');
        const doctorId = doctors.items[0].id;

        const patient = await getItem<Record<string, any>>(pk, `PATIENT#${body.patientId}`);
        if (!patient || patient.isDeleted) return response.notFound('Patient');

        if (body.appointmentId) {
            const appointment = await getItem<Record<string, any>>(pk, `APPOINTMENT#${body.appointmentId}`);
            if (!appointment || appointment.isDeleted) return response.notFound('Appointment');
            if (appointment.patientId !== body.patientId) return response.forbidden('Appointment patient mismatch');
            if (appointment.doctorId && appointment.doctorId !== doctorId) return response.forbidden('Appointment not assigned to current doctor');
        }

        const visitId = crypto.randomUUID();

        // Insert visit
        await putItem({
            PK: pk, SK: `VISIT#${visitId}`,
            entityType: 'VISIT', id: visitId, tenantId: auth.tenantId,
            patientId: body.patientId, doctorId,
            appointmentId: body.appointmentId || null,
            visitDate: now, symptoms: body.symptoms,
            diagnosis: body.diagnosis || null,
            vitals: body.vitals || {}, notes: body.notes || null,
            createdAt: now, updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'clinic_visits',
            visitId,
            'create',
            auth.sub,
            null,
            {
                patientId: body.patientId,
                doctorId,
                appointmentId: body.appointmentId || null,
                diagnosis: body.diagnosis || null,
            },
            { source: 'clinic.recordVisit' },
        );

        // Mark appointment as completed
        if (body.appointmentId) {
            // Reuse appointment fetched at L137 to avoid double read (BUG-C014 fix)
            const appointmentBefore = await getItem<Record<string, any>>(pk, `APPOINTMENT#${body.appointmentId}`);
            const prevStatus = appointmentBefore?.status || null;
            await updateItem(pk, `APPOINTMENT#${body.appointmentId}`, {
                updateExpression: 'SET #s = :completed, updatedAt = :now',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':completed': 'completed', ':now': now },
            });
            await recordRevision(
                auth.tenantId,
                'clinic_appointments',
                body.appointmentId,
                'status_change',
                auth.sub,
                { status: prevStatus },
                { status: 'completed' },
                { source: 'clinic.recordVisit' },
            );
        }

        // Medical record
        const medRecordId = crypto.randomUUID();
        await putItem({
            PK: pk, SK: `MEDRECORD#${medRecordId}`,
            entityType: 'MEDICAL_RECORD', tenantId: auth.tenantId,
            id: medRecordId,
            patientId: body.patientId, recordType: 'visit',
            recordDate: now, description: `Consultation for ${(body.symptoms || '').substring(0, 50)}`,
            referenceId: visitId, createdAt: now,
        });
        return response.success({ message: 'Visit recorded successfully', visitId }, 201);
    } catch (err: any) {
        logger.error('Failed to record visit', { error: err.message });
        return response.internalError('Failed to record visit');
    }
}, CLINIC_OPTS);

/**
 * POST /clinic/prescriptions — Generate a digital prescription
 */
export const generatePrescription = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.prescriptionSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        const visit = await getItem<Record<string, any>>(pk, `VISIT#${body.visitId}`);
        if (!visit || visit.isDeleted) return response.notFound('Visit');
        if (visit.patientId !== body.patientId) return response.forbidden('Visit patient mismatch');

        const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
            filterExpression: 'userId = :userId',
            expressionAttributeValues: { ':userId': auth.sub },
            limit: 1,
        });
        const doctorId = doctors.items[0]?.id;
        if (doctorId && visit.doctorId && visit.doctorId !== doctorId) {
            return response.forbidden('Visit not assigned to current doctor');
        }

        const prescriptionId = crypto.randomUUID();

        // Insert prescription header
        await putItem({
            PK: pk, SK: `PRESCRIPTION#${prescriptionId}`,
            entityType: 'PRESCRIPTION', id: prescriptionId, tenantId: auth.tenantId,
            patientId: body.patientId, visitId: body.visitId,
            nextVisitDate: body.nextVisitDate || null,
            createdAt: now, updatedAt: now, isDeleted: false,
        });
        await recordRevision(
            auth.tenantId,
            'clinic_prescriptions',
            prescriptionId,
            'create',
            auth.sub,
            null,
            {
                patientId: body.patientId,
                visitId: body.visitId,
                medicineCount: body.medicines.length,
                nextVisitDate: body.nextVisitDate || null,
            },
            { source: 'clinic.generatePrescription' },
        );

        // Insert prescription items
        for (const med of body.medicines) {
            await putItem({
                PK: pk, SK: `PRESCRIPTIONITEM#${crypto.randomUUID()}`,
                entityType: 'PRESCRIPTION_ITEM', tenantId: auth.tenantId,
                prescriptionId, medicineName: med.medicineName,
                inventoryId: med.inventoryId || null, dosage: med.dosage,
                duration: med.duration, instructions: med.instructions || null,
                createdAt: now,
            });
        }

        return response.success({ message: 'Prescription generated', prescriptionId }, 201);
    } catch (err: any) {
        logger.error('Failed to generate prescription', { error: err.message });
        return response.internalError('Failed to generate prescription');
    }
}, CLINIC_PRESCRIPTION_OPTS);

/**
 * POST /clinic/follow-ups — Schedule a follow-up visit and add EMR note
 */
export const createFollowUp = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicFollowUpSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const followUpId = crypto.randomUUID();

    try {
        const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
            filterExpression: 'userId = :userId',
            expressionAttributeValues: { ':userId': auth.sub },
            limit: 1,
        });
        const doctorId = doctors.items[0]?.id || null;

        const patient = await getItem<Record<string, any>>(pk, `PATIENT#${body.patientId}`);
        if (!patient || patient.isDeleted) return response.notFound('Patient');

        if (body.appointmentId) {
            const appointment = await getItem<Record<string, any>>(pk, `APPOINTMENT#${body.appointmentId}`);
            if (!appointment || appointment.isDeleted) return response.notFound('Appointment');
            if (appointment.patientId !== body.patientId) return response.forbidden('Appointment patient mismatch');
            if (doctorId && appointment.doctorId && appointment.doctorId !== doctorId) return response.forbidden('Appointment not assigned to current doctor');
        }

        await putItem({
            PK: pk,
            SK: `FOLLOWUP#${followUpId}`,
            entityType: 'FOLLOW_UP',
            id: followUpId,
            tenantId: auth.tenantId,
            patientId: body.patientId,
            doctorId,
            appointmentId: body.appointmentId || null,
            followUpDate: body.followUpDate,
            reason: body.reason,
            notes: body.notes || null,
            vitals: body.vitals || {},
            status: 'scheduled',
            createdAt: now,
            updatedAt: now,
        });

        const medRecordId = crypto.randomUUID();
        await putItem({
            PK: pk,
            SK: `MEDRECORD#${medRecordId}`,
            entityType: 'MEDICAL_RECORD',
            tenantId: auth.tenantId,
            id: medRecordId,
            patientId: body.patientId,
            recordType: 'follow_up',
            recordDate: now,
            description: `Follow-up scheduled for ${body.followUpDate}: ${body.reason}`,
            referenceId: followUpId,
            createdAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'clinic_followups',
            followUpId,
            'create',
            auth.sub,
            null,
            {
                patientId: body.patientId,
                doctorId,
                appointmentId: body.appointmentId || null,
                followUpDate: body.followUpDate,
                status: 'scheduled',
            },
            { source: 'clinic.createFollowUp' },
        );

        if (body.appointmentId) {
            await updateItem(pk, `APPOINTMENT#${body.appointmentId}`, {
                updateExpression: 'SET followUpId = :followUpId, followUpDate = :followUpDate, updatedAt = :now',
                expressionAttributeValues: {
                    ':followUpId': followUpId,
                    ':followUpDate': body.followUpDate,
                    ':now': now,
                },
            });
        }

        return response.success({ message: 'Follow-up scheduled successfully', followUpId }, 201);
    } catch (err: any) {
        logger.error('Failed to schedule follow-up', { error: err.message });
        return response.internalError('Failed to schedule follow-up');
    }
}, CLINIC_FOLLOWUP_OPTS);

/**
 * POST /clinic/emr/soap — Save SOAP EMR note and optionally complete appointment
 */
export const createSoapNote = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.soapNoteSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const soapId = crypto.randomUUID();

    try {
        const patient = await getItem<Record<string, any>>(pk, `PATIENT#${body.patientId}`);
        if (!patient || patient.isDeleted) return response.notFound('Patient');

        let doctorId: string | null = null;
        const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
            filterExpression: 'userId = :userId',
            expressionAttributeValues: { ':userId': auth.sub },
            limit: 1,
        });
        doctorId = doctors.items[0]?.id || null;

        if (body.appointmentId) {
            const appointment = await getItem<Record<string, any>>(pk, `APPOINTMENT#${body.appointmentId}`);
            if (!appointment || appointment.isDeleted) return response.notFound('Appointment');
            if (appointment.patientId !== body.patientId) return response.forbidden('Appointment patient mismatch');
            if (doctorId && appointment.doctorId && appointment.doctorId !== doctorId) return response.forbidden('Appointment not assigned to current doctor');
        }

        await putItem({
            PK: pk,
            SK: `SOAPNOTE#${soapId}`,
            entityType: 'SOAP_NOTE',
            id: soapId,
            tenantId: auth.tenantId,
            patientId: body.patientId,
            appointmentId: body.appointmentId || null,
            subjective: body.subjective,
            objective: body.objective,
            assessment: body.assessment,
            plan: body.plan,
            notes: body.notes || null,
            vitals: body.vitals || {},
            createdAt: now,
            updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'clinic_soap_notes',
            soapId,
            'create',
            auth.sub,
            null,
            {
                patientId: body.patientId,
                appointmentId: body.appointmentId || null,
            },
            { source: 'clinic.createSoapNote' },
        );

        const medRecordId = crypto.randomUUID();
        await putItem({
            PK: pk,
            SK: `MEDRECORD#${medRecordId}`,
            entityType: 'MEDICAL_RECORD',
            tenantId: auth.tenantId,
            id: medRecordId,
            patientId: body.patientId,
            recordType: 'soap_note',
            recordDate: now,
            description: `SOAP note: ${(body.assessment || '').substring(0, 80)}`,
            referenceId: soapId,
            createdAt: now,
        });

        if (body.appointmentId) {
            await updateItem(pk, `APPOINTMENT#${body.appointmentId}`, {
                updateExpression: 'SET #s = :completed, soapNoteId = :soapNoteId, updatedAt = :now',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: {
                    ':completed': 'completed',
                    ':soapNoteId': soapId,
                    ':now': now,
                },
            });
        }

        return response.success({ message: 'SOAP note saved', soapId }, 201);
    } catch (err: any) {
        logger.error('Failed to save SOAP note', { error: err.message });
        return response.internalError('Failed to save SOAP note');
    }
}, CLINIC_EMR_OPTS);

/**
 * POST /clinic/lab-orders — Create a lab order from consultation
 */
export const createLabOrder = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicLabOrderSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const labOrderId = crypto.randomUUID();

    try {
        const patient = await getItem<Record<string, any>>(pk, `PATIENT#${body.patientId}`);
        if (!patient || patient.isDeleted) return response.notFound('Patient');

        let doctorId: string | null = null;
        const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
            filterExpression: 'userId = :userId',
            expressionAttributeValues: { ':userId': auth.sub },
            limit: 1,
        });
        doctorId = doctors.items[0]?.id || null;

        if (body.appointmentId) {
            const appointment = await getItem<Record<string, any>>(pk, `APPOINTMENT#${body.appointmentId}`);
            if (!appointment || appointment.isDeleted) return response.notFound('Appointment');
            if (appointment.patientId !== body.patientId) return response.forbidden('Appointment patient mismatch');
            if (doctorId && appointment.doctorId && appointment.doctorId !== doctorId) return response.forbidden('Appointment not assigned to current doctor');
        }

        await putItem({
            PK: pk,
            SK: `LABORDER#${labOrderId}`,
            entityType: 'LAB_ORDER',
            id: labOrderId,
            tenantId: auth.tenantId,
            patientId: body.patientId,
            appointmentId: body.appointmentId || null,
            priority: body.priority,
            tests: body.tests,
            notes: body.notes || null,
            status: 'ordered',
            createdAt: now,
            updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'clinic_lab_orders',
            labOrderId,
            'create',
            auth.sub,
            null,
            {
                patientId: body.patientId,
                appointmentId: body.appointmentId || null,
                priority: body.priority,
                testCount: body.tests.length,
                status: 'ordered',
            },
            { source: 'clinic.createLabOrder' },
        );

        const medRecordId = crypto.randomUUID();
        await putItem({
            PK: pk,
            SK: `MEDRECORD#${medRecordId}`,
            entityType: 'MEDICAL_RECORD',
            tenantId: auth.tenantId,
            id: medRecordId,
            patientId: body.patientId,
            recordType: 'lab_order',
            recordDate: now,
            description: `Lab order: ${body.tests.map(t => t.testName).join(', ')}`,
            referenceId: labOrderId,
            createdAt: now,
        });

        return response.success({ message: 'Lab order created', labOrderId }, 201);
    } catch (err: any) {
        logger.error('Failed to create lab order', { error: err.message });
        return response.internalError('Failed to create lab order');
    }
}, CLINIC_LAB_OPTS);

/**
 * POST /clinic/lab-orders/{id}/results — Attach lab result and complete order
 */
export const attachLabResult = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicLabResultSchema, event);
    if (!valid.success) return valid.error;

    const labOrderId = event.pathParameters?.id;
    if (!labOrderId) return response.badRequest('Missing lab order id');

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = body.reportedAt || new Date().toISOString();
    const labResultId = crypto.randomUUID();

    try {
        const order = await getItem<Record<string, any>>(pk, `LABORDER#${labOrderId}`);
        if (!order) return response.notFound('Lab order');

        await putItem({
            PK: pk,
            SK: `LABRESULT#${labResultId}`,
            entityType: 'LAB_RESULT',
            id: labResultId,
            tenantId: auth.tenantId,
            patientId: order.patientId,
            labOrderId,
            resultSummary: body.resultSummary,
            attachments: body.attachments || [],
            notes: body.notes || null,
            reportedAt: now,
            createdAt: new Date().toISOString(),
        });

        await updateItem(pk, `LABORDER#${labOrderId}`, {
            updateExpression: 'SET #s = :completed, resultId = :resultId, reportedAt = :reportedAt, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':completed': 'completed',
                ':resultId': labResultId,
                ':reportedAt': now,
                ':now': new Date().toISOString(),
            },
        });
        await recordRevision(
            auth.tenantId,
            'clinic_lab_orders',
            labOrderId,
            'status_change',
            auth.sub,
            { status: order.status || 'ordered' },
            { status: 'completed', resultId: labResultId },
            { source: 'clinic.attachLabResult' },
        );

        return response.success({ message: 'Lab result attached', labResultId }, 201);
    } catch (err: any) {
        logger.error('Failed to attach lab result', { error: err.message });
        return response.internalError('Failed to attach lab result');
    }
}, CLINIC_LAB_OPTS);

/**
 * PUT /clinic/queue/{id}/status — Update appointment status
 */
export const updateQueueStatus = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const appointmentId = event.pathParameters?.id;
    if (!appointmentId) return response.badRequest('Missing appointment id');

    const valid = parseBody(schemas.updateQueueStatusSchema, event);
    if (!valid.success) return valid.error;

    const pk = Keys.tenantPK(auth.tenantId);
    
    try {
        const existing = await getItem<Record<string, any>>(pk, `APPOINTMENT#${appointmentId}`);
        if (!existing) return response.notFound('Appointment');
        if (existing.isDeleted) return response.notFound('Appointment');

        const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
            filterExpression: 'userId = :userId',
            expressionAttributeValues: { ':userId': auth.sub },
            limit: 1,
        });
        const doctorId = doctors.items[0]?.id || null;
        if (doctorId && existing.doctorId && existing.doctorId !== doctorId) {
            return response.forbidden('Appointment not assigned to current doctor');
        }

        await updateItem(pk, `APPOINTMENT#${appointmentId}`, {
            updateExpression: 'SET #s = :status, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':status': valid.data.status,
                ':now': new Date().toISOString(),
            },
        });
        await recordRevision(
            auth.tenantId,
            'clinic_appointments',
            appointmentId,
            'status_change',
            auth.sub,
            { status: existing.status || null },
            { status: valid.data.status },
            { source: 'clinic.updateQueueStatus' },
        );
        return response.success({ message: 'Status updated successfully' });
    } catch (err: any) {
        logger.error('Failed to update status', { error: err.message });
        return response.internalError('Failed to update status');
    }
}, CLINIC_OPTS);

/**
 * GET /clinic/patients/{id}/history — Fetch chronological visit history
 */
export const getPatientHistory = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const patientId = event.pathParameters?.id;
    if (!isValidUUID(patientId)) return response.badRequest('Invalid patient ID format');

    const pk = Keys.tenantPK(auth.tenantId);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const nextToken = decodePageToken(event.queryStringParameters?.nextToken);

    try {
        const patient = await getItem<Record<string, any>>(pk, `PATIENT#${patientId}`);
        if (!patient || patient.isDeleted) return response.notFound('Patient');

        // IDOR protection: STAFF can only access patients they have appointments with
        if (auth.role === UserRole.STAFF) {
            const staffAppts = await queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
                filterExpression: 'patientId = :pid AND doctorId = :did',
                expressionAttributeValues: { ':pid': patientId, ':did': auth.sub },
                limit: 1,
            });
            if (!staffAppts.items.length) return response.forbidden('Not authorized to view this patient');
        }

        const history = await queryItems<Record<string, any>>(pk, 'MEDRECORD#', {
            filterExpression: 'patientId = :patientId AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':patientId': patientId, ':false': false },
            scanIndexForward: false,
            limit,
            exclusiveStartKey: nextToken,
        });

        const items = history.items.map(h => ({
            id: h.id || (typeof h.SK === 'string' ? h.SK.replace('MEDRECORD#', '') : null),
            recordType: h.recordType,
            recordDate: h.recordDate,
            description: h.description,
            referenceId: h.referenceId,
        }));

        return response.success(items, 200, {
            limit,
            total: items.length,
            hasMore: !!history.lastKey,
            nextCursor: encodePageToken(history.lastKey),
        });
    } catch (err: any) {
        logger.error('Failed to fetch patient history', { error: err.message });
        return response.internalError('Failed to fetch patient history');
    }
}, CLINIC_OPTS);

// ── Helper: UUID path param validation ──────────────────────────────────────
function isValidUUID(s: string | undefined): s is string {
    return !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
}

// ── Helper: Auto-generate MRN (Medical Record Number) ───────────────────────
async function generateMRN(pk: string): Promise<string> {
    const patients = await queryItems<Record<string, any>>(pk, 'PATIENT#', { limit: 1, scanIndexForward: false });
    const lastMrn = patients.items[0]?.mrn;
    let nextNum = 1;
    if (lastMrn && typeof lastMrn === 'string') {
        const match = lastMrn.match(/CLN-(\d+)/);
        if (match) nextNum = parseInt(match[1], 10) + 1;
    }
    return `CLN-${String(nextNum).padStart(4, '0')}`;
}

// ============================================================================
// Patient CRUD
// ============================================================================

/**
 * POST /clinic/patients — Register a new patient
 */
export const registerPatient = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicPatientSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const patientId = crypto.randomUUID();
    const mrn = await generateMRN(pk);

    try {
        await putItem({
            PK: pk, SK: `PATIENT#${patientId}`,
            entityType: 'PATIENT', id: patientId, tenantId: auth.tenantId,
            mrn, name: body.name, phone: body.phone || null,
            age: body.age ?? null, gender: body.gender || null,
            bloodGroup: body.bloodGroup || null,
            address: body.address || null, email: body.email || null,
            emergencyContactName: body.emergencyContactName || null,
            emergencyContactPhone: body.emergencyContactPhone || null,
            allergies: body.allergies || null,
            chronicConditions: body.chronicConditions || null,
            insuranceProvider: body.insuranceProvider || null,
            insurancePolicyNumber: body.insurancePolicyNumber || null,
            isDeleted: false, createdAt: now, updatedAt: now,
            GSI1PK: Keys.entityGSI1PK('PATIENT'),
            GSI1SK: `TENANT#${auth.tenantId}#${now}`,
        });
        await recordRevision(auth.tenantId, 'clinic_patients', patientId, 'create', auth.sub, null, { mrn, name: body.name }, { source: 'clinic.registerPatient' });
        return response.success({ message: 'Patient registered', patientId, mrn }, 201);
    } catch (err: any) {
        logger.error('Failed to register patient', { error: err.message });
        return response.internalError('Failed to register patient');
    }
}, CLINIC_PATIENT_OPTS);

/**
 * GET /clinic/patients/{id} — Get a single patient
 */
export const getPatient = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const patientId = event.pathParameters?.id;
    if (!isValidUUID(patientId)) return response.badRequest('Invalid patient ID format');

    const pk = Keys.tenantPK(auth.tenantId);
    const patient = await getItem<Record<string, any>>(pk, `PATIENT#${patientId}`);
    if (!patient || patient.isDeleted) return response.notFound('Patient');
    return response.success(patient);
}, CLINIC_PATIENT_OPTS);

/**
 * PUT /clinic/patients/{id} — Update patient demographics
 */
export const updatePatient = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const patientId = event.pathParameters?.id;
    if (!isValidUUID(patientId)) return response.badRequest('Invalid patient ID format');

    const valid = parseBody(schemas.clinicPatientUpdateSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        const existing = await getItem<Record<string, any>>(pk, `PATIENT#${patientId}`);
        if (!existing || existing.isDeleted) return response.notFound('Patient');

        const updates: string[] = ['updatedAt = :now'];
        const values: Record<string, any> = { ':now': now };
        const names: Record<string, string> = {};
        const fields = ['name', 'phone', 'age', 'gender', 'bloodGroup', 'address', 'email',
            'emergencyContactName', 'emergencyContactPhone', 'allergies', 'chronicConditions',
            'insuranceProvider', 'insurancePolicyNumber'] as const;

        for (const field of fields) {
            if (body[field] !== undefined) {
                const alias = `#${field}`;
                names[alias] = field;
                values[`:${field}`] = body[field];
                updates.push(`${alias} = :${field}`);
            }
        }

        await updateItem(pk, `PATIENT#${patientId}`, {
            updateExpression: `SET ${updates.join(', ')}`,
            expressionAttributeValues: values,
            expressionAttributeNames: Object.keys(names).length ? names : undefined,
        });
        await recordRevision(auth.tenantId, 'clinic_patients', patientId, 'update', auth.sub, existing, body, { source: 'clinic.updatePatient' });
        return response.success({ message: 'Patient updated' });
    } catch (err: any) {
        logger.error('Failed to update patient', { error: err.message });
        return response.internalError('Failed to update patient');
    }
}, CLINIC_PATIENT_OPTS);

/**
 * GET /clinic/patients — List/search patients
 */
export const listPatients = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const nextToken = decodePageToken(event.queryStringParameters?.nextToken);
    const search = event.queryStringParameters?.search?.toLowerCase();

    try {
        const result = await queryItems<Record<string, any>>(pk, 'PATIENT#', {
            filterExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
            expressionAttributeValues: { ':false': false },
            limit: search ? 500 : limit,
            exclusiveStartKey: nextToken,
        });

        let items = result.items.map(p => ({
            id: p.id, mrn: p.mrn, name: p.name, phone: p.phone,
            age: p.age, gender: p.gender, bloodGroup: p.bloodGroup,
            createdAt: p.createdAt,
        }));

        if (search) {
            items = items.filter(p =>
                (p.name || '').toLowerCase().includes(search) ||
                (p.mrn || '').toLowerCase().includes(search) ||
                (p.phone || '').includes(search)
            );
            items = items.slice(0, limit);
        }

        return response.success(items, 200, {
            limit, total: items.length,
            hasMore: !!result.lastKey,
            nextCursor: encodePageToken(result.lastKey),
        });
    } catch (err: any) {
        logger.error('Failed to list patients', { error: err.message });
        return response.internalError('Failed to list patients');
    }
}, CLINIC_PATIENT_OPTS);

// ============================================================================
// Appointment CRUD
// ============================================================================

/**
 * POST /clinic/appointments — Book a new appointment
 */
export const createAppointment = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicAppointmentSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const appointmentId = crypto.randomUUID();

    try {
        const patient = await getItem<Record<string, any>>(pk, `PATIENT#${body.patientId}`);
        if (!patient || patient.isDeleted) return response.notFound('Patient');

        let doctorId = body.doctorId || null;
        if (!doctorId) {
            const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
                filterExpression: 'userId = :userId',
                expressionAttributeValues: { ':userId': auth.sub },
                limit: 1,
            });
            doctorId = doctors.items[0]?.id || null;
        }

        // Generate token number for the day
        const dayAppointments = await queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
            filterExpression: 'appointmentDate = :date AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':date': body.scheduledDate, ':false': false },
        });
        const tokenNumber = dayAppointments.items.length + 1;

        await putItem({
            PK: pk, SK: `APPOINTMENT#${appointmentId}`,
            entityType: 'APPOINTMENT', id: appointmentId, tenantId: auth.tenantId,
            patientId: body.patientId, doctorId,
            appointmentDate: body.scheduledDate,
            appointmentTime: body.scheduledTime,
            duration: body.duration || 15,
            purpose: body.purpose || null, notes: body.notes || null,
            appointmentType: body.appointmentType || 'scheduled',
            status: 'scheduled', tokenNumber,
            reasonForVisit: body.purpose || null,
            isDeleted: false, createdAt: now, updatedAt: now,
        });
        await recordRevision(auth.tenantId, 'clinic_appointments', appointmentId, 'create', auth.sub, null,
            { patientId: body.patientId, doctorId, date: body.scheduledDate, time: body.scheduledTime },
            { source: 'clinic.createAppointment' });

        return response.success({ message: 'Appointment booked', appointmentId, tokenNumber }, 201);
    } catch (err: any) {
        logger.error('Failed to create appointment', { error: err.message });
        return response.internalError('Failed to create appointment');
    }
}, CLINIC_APPOINTMENT_OPTS);

/**
 * GET /clinic/appointments/{id} — Get single appointment
 */
export const getAppointment = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid appointment ID format');

    const pk = Keys.tenantPK(auth.tenantId);
    const appointment = await getItem<Record<string, any>>(pk, `APPOINTMENT#${id}`);
    if (!appointment || appointment.isDeleted) return response.notFound('Appointment');

    const patient = await getItem<Record<string, any>>(pk, `PATIENT#${appointment.patientId}`);
    return response.success({
        ...appointment,
        patientName: patient?.name || '',
        patientMrn: patient?.mrn || '',
    });
}, CLINIC_APPOINTMENT_OPTS);

/**
 * GET /clinic/appointments — List appointments (filterable by date, doctor, status)
 */
export const listAppointments = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const nextToken = decodePageToken(event.queryStringParameters?.nextToken);
    const dateFilter = event.queryStringParameters?.date;
    const statusFilter = event.queryStringParameters?.status;

    try {
        let filterParts = ['(attribute_not_exists(isDeleted) OR isDeleted = :false)'];
        const values: Record<string, any> = { ':false': false };

        if (dateFilter) {
            filterParts.push('appointmentDate = :date');
            values[':date'] = dateFilter;
        }
        if (statusFilter) {
            filterParts.push('#s = :status');
            values[':status'] = statusFilter;
        }

        const result = await queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
            filterExpression: filterParts.join(' AND '),
            expressionAttributeValues: values,
            expressionAttributeNames: statusFilter ? { '#s': 'status' } : undefined,
            limit,
            exclusiveStartKey: nextToken,
            scanIndexForward: false,
        });

        // Enrich with patient names
        const patientIds = [...new Set(result.items.map(a => a.patientId).filter(Boolean))];
        const patientRows = patientIds.length
            ? await batchGetItems<Record<string, any>>(patientIds.map(id => ({ PK: pk, SK: `PATIENT#${id}` })))
            : [];
        const patientMap = new Map(patientRows.filter(p => p?.id).map(p => [String(p.id), p]));

        const items = result.items.map(a => {
            const patient = patientMap.get(String(a.patientId));
            return {
                id: a.id, patientId: a.patientId,
                patientName: patient?.name || '', patientMrn: patient?.mrn || '',
                doctorId: a.doctorId, appointmentDate: a.appointmentDate,
                appointmentTime: a.appointmentTime, duration: a.duration,
                status: a.status, tokenNumber: a.tokenNumber,
                purpose: a.purpose, appointmentType: a.appointmentType,
            };
        });

        return response.success(items, 200, {
            limit, total: items.length,
            hasMore: !!result.lastKey,
            nextCursor: encodePageToken(result.lastKey),
        });
    } catch (err: any) {
        logger.error('Failed to list appointments', { error: err.message });
        return response.internalError('Failed to list appointments');
    }
}, CLINIC_APPOINTMENT_OPTS);

/**
 * PUT /clinic/appointments/{id} — Update/reschedule appointment
 */
export const updateAppointment = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid appointment ID format');

    const valid = parseBody(schemas.clinicAppointmentUpdateSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        const existing = await getItem<Record<string, any>>(pk, `APPOINTMENT#${id}`);
        if (!existing || existing.isDeleted) return response.notFound('Appointment');

        const updates: string[] = ['updatedAt = :now'];
        const values: Record<string, any> = { ':now': now };
        const names: Record<string, string> = {};

        if (body.scheduledDate !== undefined) { updates.push('appointmentDate = :date'); values[':date'] = body.scheduledDate; }
        if (body.scheduledTime !== undefined) { updates.push('appointmentTime = :time'); values[':time'] = body.scheduledTime; }
        if (body.duration !== undefined) { updates.push('duration = :dur'); values[':dur'] = body.duration; }
        if (body.purpose !== undefined) { updates.push('purpose = :purpose'); values[':purpose'] = body.purpose; }
        if (body.notes !== undefined) { updates.push('notes = :notes'); values[':notes'] = body.notes; }
        if (body.status !== undefined) { updates.push('#s = :status'); values[':status'] = body.status; names['#s'] = 'status'; }

        await updateItem(pk, `APPOINTMENT#${id}`, {
            updateExpression: `SET ${updates.join(', ')}`,
            expressionAttributeValues: values,
            expressionAttributeNames: Object.keys(names).length ? names : undefined,
        });
        await recordRevision(auth.tenantId, 'clinic_appointments', id, 'update', auth.sub, existing, body, { source: 'clinic.updateAppointment' });
        return response.success({ message: 'Appointment updated' });
    } catch (err: any) {
        logger.error('Failed to update appointment', { error: err.message });
        return response.internalError('Failed to update appointment');
    }
}, CLINIC_APPOINTMENT_OPTS);

/**
 * DELETE /clinic/appointments/{id} — Cancel (soft-delete)
 */
export const cancelAppointment = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid appointment ID format');

    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const existing = await getItem<Record<string, any>>(pk, `APPOINTMENT#${id}`);
        if (!existing || existing.isDeleted) return response.notFound('Appointment');

        await updateItem(pk, `APPOINTMENT#${id}`, {
            updateExpression: 'SET #s = :cancelled, isDeleted = :true, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':cancelled': 'cancelled', ':true': true, ':now': new Date().toISOString() },
        });
        await recordRevision(auth.tenantId, 'clinic_appointments', id, 'status_change', auth.sub, { status: existing.status }, { status: 'cancelled' }, { source: 'clinic.cancelAppointment' });
        return response.success({ message: 'Appointment cancelled' });
    } catch (err: any) {
        logger.error('Failed to cancel appointment', { error: err.message });
        return response.internalError('Failed to cancel appointment');
    }
}, CLINIC_APPOINTMENT_OPTS);

// ============================================================================
// Doctor Profile
// ============================================================================

/**
 * POST /clinic/doctors — Register a doctor profile (links to current user)
 */
export const registerDoctor = authorizedHandler([UserRole.OWNER, UserRole.ADMIN], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicDoctorSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const doctorId = crypto.randomUUID();

    try {
        await putItem({
            PK: pk, SK: `DOCTOR#${doctorId}`,
            entityType: 'DOCTOR', id: doctorId, tenantId: auth.tenantId,
            userId: auth.sub, name: body.name,
            specialization: body.specialization || null,
            qualification: body.qualification || null,
            registrationNumber: body.registrationNumber || null,
            consultationFee: body.consultationFee ?? 500,
            phone: body.phone || null, email: body.email || null,
            availableSlots: body.availableSlots || [],
            isActive: true, createdAt: now, updatedAt: now,
        });
        await recordRevision(auth.tenantId, 'clinic_doctors', doctorId, 'create', auth.sub, null, { name: body.name }, { source: 'clinic.registerDoctor' });
        return response.success({ message: 'Doctor registered', doctorId }, 201);
    } catch (err: any) {
        logger.error('Failed to register doctor', { error: err.message });
        return response.internalError('Failed to register doctor');
    }
}, CLINIC_DOCTOR_OPTS);

/**
 * GET /clinic/doctors/me — Get own doctor profile
 */
export const getDoctorProfile = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
        filterExpression: 'userId = :userId',
        expressionAttributeValues: { ':userId': auth.sub },
        limit: 1,
    });
    if (!doctors.items.length) return response.notFound('Doctor profile');
    return response.success(doctors.items[0]);
}, CLINIC_DOCTOR_OPTS);

/**
 * PUT /clinic/doctors/me — Update own doctor profile
 */
export const updateDoctorProfile = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicDoctorUpdateSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        const doctors = await queryItems<Record<string, any>>(pk, 'DOCTOR#', {
            filterExpression: 'userId = :userId',
            expressionAttributeValues: { ':userId': auth.sub },
            limit: 1,
        });
        if (!doctors.items.length) return response.notFound('Doctor profile');
        const doctor = doctors.items[0];
        const doctorId = doctor.id;

        const updates: string[] = ['updatedAt = :now'];
        const values: Record<string, any> = { ':now': now };
        const names: Record<string, string> = {};
        const fields = ['name', 'specialization', 'qualification', 'registrationNumber',
            'consultationFee', 'phone', 'email', 'availableSlots'] as const;

        for (const field of fields) {
            if ((body as any)[field] !== undefined) {
                const alias = `#${field}`;
                names[alias] = field;
                values[`:${field}`] = (body as any)[field];
                updates.push(`${alias} = :${field}`);
            }
        }

        await updateItem(pk, `DOCTOR#${doctorId}`, {
            updateExpression: `SET ${updates.join(', ')}`,
            expressionAttributeValues: values,
            expressionAttributeNames: Object.keys(names).length ? names : undefined,
        });
        await recordRevision(auth.tenantId, 'clinic_doctors', doctorId, 'update', auth.sub, doctor, body, { source: 'clinic.updateDoctorProfile' });
        return response.success({ message: 'Doctor profile updated' });
    } catch (err: any) {
        logger.error('Failed to update doctor profile', { error: err.message });
        return response.internalError('Failed to update doctor profile');
    }
}, CLINIC_DOCTOR_OPTS);

// ============================================================================
// Phase 3: READ/LIST endpoints for Visits, Prescriptions, Labs, Dashboard
// ============================================================================

/**
 * GET /clinic/visits/{id} — Get single visit
 */
export const getVisit = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid visit ID format');
    const pk = Keys.tenantPK(auth.tenantId);
    const visit = await getItem<Record<string, any>>(pk, `VISIT#${id}`);
    if (!visit || visit.isDeleted) return response.notFound('Visit');
    return response.success(visit);
}, CLINIC_OPTS);

/**
 * GET /clinic/visits — List visits (by date, doctor, patient)
 */
export const listVisits = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const nextToken = decodePageToken(event.queryStringParameters?.nextToken);
    const patientFilter = event.queryStringParameters?.patientId;

    let filterExpr = 'attribute_not_exists(isDeleted) OR isDeleted = :false';
    const values: Record<string, any> = { ':false': false };
    if (patientFilter) { filterExpr += ' AND patientId = :pid'; values[':pid'] = patientFilter; }

    const result = await queryItems<Record<string, any>>(pk, 'VISIT#', {
        filterExpression: filterExpr,
        expressionAttributeValues: values,
        limit, exclusiveStartKey: nextToken, scanIndexForward: false,
    });
    return response.success(result.items, 200, {
        limit, total: result.items.length,
        hasMore: !!result.lastKey, nextCursor: encodePageToken(result.lastKey),
    });
}, CLINIC_OPTS);

/**
 * GET /clinic/prescriptions/{id} — Get single prescription with items
 */
export const getPrescription = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid prescription ID format');
    const pk = Keys.tenantPK(auth.tenantId);
    const prescription = await getItem<Record<string, any>>(pk, `PRESCRIPTION#${id}`);
    if (!prescription || prescription.isDeleted) return response.notFound('Prescription');

    const items = await queryItems<Record<string, any>>(pk, 'PRESCRIPTIONITEM#', {
        filterExpression: 'prescriptionId = :rxId',
        expressionAttributeValues: { ':rxId': id },
    });
    return response.success({ ...prescription, medicines: items.items });
}, CLINIC_PRESCRIPTION_OPTS);

/**
 * GET /clinic/prescriptions — List prescriptions
 */
export const listPrescriptions = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const nextToken = decodePageToken(event.queryStringParameters?.nextToken);
    const patientFilter = event.queryStringParameters?.patientId;

    let filterExpr = 'attribute_not_exists(isDeleted) OR isDeleted = :false';
    const values: Record<string, any> = { ':false': false };
    if (patientFilter) { filterExpr += ' AND patientId = :pid'; values[':pid'] = patientFilter; }

    const result = await queryItems<Record<string, any>>(pk, 'PRESCRIPTION#', {
        filterExpression: filterExpr, expressionAttributeValues: values,
        limit, exclusiveStartKey: nextToken, scanIndexForward: false,
    });
    return response.success(result.items, 200, {
        limit, total: result.items.length,
        hasMore: !!result.lastKey, nextCursor: encodePageToken(result.lastKey),
    });
}, CLINIC_PRESCRIPTION_OPTS);

/**
 * GET /clinic/labs/orders/{id} — Get single lab order
 */
export const getLabOrder = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid lab order ID format');
    const pk = Keys.tenantPK(auth.tenantId);
    const order = await getItem<Record<string, any>>(pk, `LABORDER#${id}`);
    if (!order) return response.notFound('Lab order');

    // Attach result if exists
    if (order.resultId) {
        const result = await getItem<Record<string, any>>(pk, `LABRESULT#${order.resultId}`);
        return response.success({ ...order, result });
    }
    return response.success(order);
}, CLINIC_LAB_OPTS);

/**
 * GET /clinic/labs/orders — List lab orders
 */
export const listLabOrders = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const statusFilter = event.queryStringParameters?.status;

    let filterExpr = 'attribute_not_exists(isDeleted) OR isDeleted = :false';
    const values: Record<string, any> = { ':false': false };
    const names: Record<string, string> = {};
    if (statusFilter) { filterExpr += ' AND #s = :status'; values[':status'] = statusFilter; names['#s'] = 'status'; }

    const result = await queryItems<Record<string, any>>(pk, 'LABORDER#', {
        filterExpression: filterExpr, expressionAttributeValues: values,
        expressionAttributeNames: Object.keys(names).length ? names : undefined,
        limit, scanIndexForward: false,
    });
    return response.success(result.items, 200, { limit, total: result.items.length });
}, CLINIC_LAB_OPTS);

/**
 * GET /clinic/follow-ups — List follow-ups
 */
export const listFollowUps = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const limit = parseLimit(event.queryStringParameters?.limit, 50, 200);
    const statusFilter = event.queryStringParameters?.status;

    let filterExpr = 'attribute_not_exists(isDeleted) OR isDeleted = :false';
    const values: Record<string, any> = { ':false': false };
    const names: Record<string, string> = {};
    if (statusFilter) { filterExpr += ' AND #s = :status'; values[':status'] = statusFilter; names['#s'] = 'status'; }

    const result = await queryItems<Record<string, any>>(pk, 'FOLLOWUP#', {
        filterExpression: filterExpr, expressionAttributeValues: values,
        expressionAttributeNames: Object.keys(names).length ? names : undefined,
        limit, scanIndexForward: false,
    });
    return response.success(result.items, 200, { limit, total: result.items.length });
}, CLINIC_FOLLOWUP_OPTS);

/**
 * PUT /clinic/follow-ups/{id}/status — Update follow-up status
 */
export const updateFollowUpStatus = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid follow-up ID format');

    const valid = parseBody(schemas.updateQueueStatusSchema, event);
    if (!valid.success) return valid.error;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<Record<string, any>>(pk, `FOLLOWUP#${id}`);
    if (!existing) return response.notFound('Follow-up');

    await updateItem(pk, `FOLLOWUP#${id}`, {
        updateExpression: 'SET #s = :status, updatedAt = :now',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':status': valid.data.status, ':now': new Date().toISOString() },
    });
    return response.success({ message: 'Follow-up status updated' });
}, CLINIC_FOLLOWUP_OPTS);

/**
 * GET /clinic/dashboard/stats — Dashboard statistics
 */
export const getDashboardStats = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const todayStr = new Date().toISOString().slice(0, 10);

    try {
        const [appointments, patients, labOrders] = await Promise.all([
            queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
                filterExpression: 'appointmentDate = :today AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':today': todayStr, ':false': false },
            }),
            queryItems<Record<string, any>>(pk, 'PATIENT#', {
                filterExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
                expressionAttributeValues: { ':false': false },
            }),
            queryItems<Record<string, any>>(pk, 'LABORDER#', {
                filterExpression: '#s = :pending',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':pending': 'ordered' },
            }),
        ]);

        const todayAppts = appointments.items;
        const completed = todayAppts.filter(a => a.status === 'completed').length;
        const waiting = todayAppts.filter(a => a.status === 'waiting' || a.status === 'scheduled').length;

        return response.success({
            todayAppointments: todayAppts.length,
            completedToday: completed,
            waitingCount: waiting,
            totalPatients: patients.items.length,
            pendingLabOrders: labOrders.items.length,
            date: todayStr,
        });
    } catch (err: any) {
        logger.error('Failed to get dashboard stats', { error: err.message });
        return response.internalError('Failed to get dashboard stats');
    }
}, CLINIC_OPTS);

// ── SOAP Note Read ──────────────────────────────────────────────────────────
export const getSoapNote = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid SOAP note ID');
    try {
        const pk = Keys.tenantPK(auth.tenantId);
        const item = await getItem<Record<string, any>>(pk, `SOAPNOTE#${id}`);
        if (!item || item.isDeleted) return response.notFound('SOAP Note');
        return response.success(item);
    } catch (err: any) {
        logger.error('Failed to get SOAP note', { error: err.message });
        return response.internalError('Failed to get SOAP note');
    }
}, CLINIC_EMR_OPTS);

// ── Visit Update ────────────────────────────────────────────────────────────
export const updateVisit = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid visit ID');
    const valid = parseBody(schemas.clinicVisitUpdateSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const existing = await getItem<Record<string, any>>(pk, `VISIT#${id}`);
        if (!existing || existing.isDeleted) return response.notFound('Visit');
        const updates: string[] = [];
        const values: Record<string, any> = { ':now': new Date().toISOString(), ':user': auth.sub };
        const names: Record<string, string> = {};
        if (body.symptoms !== undefined) { updates.push('symptoms = :symptoms'); values[':symptoms'] = body.symptoms; }
        if (body.diagnosis !== undefined) { updates.push('diagnosis = :diagnosis'); values[':diagnosis'] = body.diagnosis; }
        if (body.notes !== undefined) { updates.push('notes = :notes'); values[':notes'] = body.notes; }
        if (body.vitals !== undefined) { updates.push('vitals = :vitals'); values[':vitals'] = body.vitals; }
        if (body.status !== undefined) { updates.push('#s = :status'); values[':status'] = body.status; names['#s'] = 'status'; }
        if (body.consultationStartTime) { updates.push('consultationStartTime = :cst'); values[':cst'] = body.consultationStartTime; }
        if (body.consultationEndTime) { updates.push('consultationEndTime = :cet'); values[':cet'] = body.consultationEndTime; }
        if (!updates.length) return response.badRequest('No fields to update');
        updates.push('updatedAt = :now', 'updatedBy = :user');
        await updateItem(pk, `VISIT#${id}`, { updateExpression: `SET ${updates.join(', ')}`, expressionAttributeValues: values, ...(Object.keys(names).length ? { expressionAttributeNames: names } : {}) });
        await recordRevision(auth.tenantId, 'clinic_visits', id, 'update', auth.sub, existing, body, { source: 'clinic.updateVisit' });
        return response.success({ message: 'Visit updated' });
    } catch (err: any) {
        logger.error('Failed to update visit', { error: err.message });
        return response.internalError('Failed to update visit');
    }
}, CLINIC_EMR_OPTS);

// ── Prescription Update ─────────────────────────────────────────────────────
export const updatePrescription = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid prescription ID');
    const valid = parseBody(schemas.clinicPrescriptionUpdateSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const existing = await getItem<Record<string, any>>(pk, `PRESCRIPTION#${id}`);
        if (!existing || existing.isDeleted) return response.notFound('Prescription');
        const updates: string[] = [];
        const values: Record<string, any> = { ':now': new Date().toISOString(), ':user': auth.sub };
        if (body.medicines) { updates.push('medicines = :meds'); values[':meds'] = body.medicines; }
        if (body.nextVisitDate) { updates.push('nextVisitDate = :nvd'); values[':nvd'] = body.nextVisitDate; }
        if (body.advice) { updates.push('advice = :advice'); values[':advice'] = body.advice; }
        if (!updates.length) return response.badRequest('No fields to update');
        updates.push('updatedAt = :now', 'updatedBy = :user');
        await updateItem(pk, `PRESCRIPTION#${id}`, { updateExpression: `SET ${updates.join(', ')}`, expressionAttributeValues: values });
        await recordRevision(auth.tenantId, 'clinic_prescriptions', id, 'update', auth.sub, existing, body, { source: 'clinic.updatePrescription' });
        return response.success({ message: 'Prescription updated' });
    } catch (err: any) {
        logger.error('Failed to update prescription', { error: err.message });
        return response.internalError('Failed to update prescription');
    }
}, CLINIC_PRESCRIPTION_OPTS);

// ── Soft-Delete Visit ───────────────────────────────────────────────────────
export const deleteVisit = authorizedHandler([UserRole.OWNER, UserRole.ADMIN], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid visit ID');
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const existing = await getItem<Record<string, any>>(pk, `VISIT#${id}`);
        if (!existing || existing.isDeleted) return response.notFound('Visit');
        await updateItem(pk, `VISIT#${id}`, { updateExpression: 'SET isDeleted = :true, deletedAt = :now, deletedBy = :user', expressionAttributeValues: { ':true': true, ':now': new Date().toISOString(), ':user': auth.sub } });
        await recordRevision(auth.tenantId, 'clinic_visits', id, 'delete', auth.sub, existing, { isDeleted: true }, { source: 'clinic.deleteVisit' });
        return response.success({ message: 'Visit deleted' });
    } catch (err: any) {
        logger.error('Failed to delete visit', { error: err.message });
        return response.internalError('Failed to delete visit');
    }
}, CLINIC_EMR_OPTS);

// ── Soft-Delete Prescription ────────────────────────────────────────────────
export const deletePrescription = authorizedHandler([UserRole.OWNER, UserRole.ADMIN], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid prescription ID');
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const existing = await getItem<Record<string, any>>(pk, `PRESCRIPTION#${id}`);
        if (!existing || existing.isDeleted) return response.notFound('Prescription');
        await updateItem(pk, `PRESCRIPTION#${id}`, { updateExpression: 'SET isDeleted = :true, deletedAt = :now, deletedBy = :user', expressionAttributeValues: { ':true': true, ':now': new Date().toISOString(), ':user': auth.sub } });
        await recordRevision(auth.tenantId, 'clinic_prescriptions', id, 'delete', auth.sub, existing, { isDeleted: true }, { source: 'clinic.deletePrescription' });
        return response.success({ message: 'Prescription deleted' });
    } catch (err: any) {
        logger.error('Failed to delete prescription', { error: err.message });
        return response.internalError('Failed to delete prescription');
    }
}, CLINIC_PRESCRIPTION_OPTS);

// ── Clinic Billing ──────────────────────────────────────────────────────────
export const createClinicBill = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicBillingSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const id = crypto.randomUUID();
    try {
        const patient = await getItem<Record<string, any>>(pk, `PATIENT#${body.patientId}`);
        if (!patient || patient.isDeleted) return response.notFound('Patient');
        const subtotal = body.items.reduce((sum, i) => sum + (i.unitPrice * i.quantity * (1 - i.discount / 100)), 0);
        const bill = {
            PK: pk, SK: `CLINICBILL#${id}`, id, ...body,
            patientName: patient.name, subtotal, grandTotal: subtotal,
            invoiceNumber: `CLB-${Date.now()}`, status: 'unpaid',
            createdAt: new Date().toISOString(), createdBy: auth.sub,
        };
        await putItem(bill);
        await recordRevision(auth.tenantId, 'clinic_bills', id, 'create', auth.sub, null, bill, { source: 'clinic.createClinicBill' });
        return response.success({ id, invoiceNumber: bill.invoiceNumber, grandTotal: subtotal }, 201);
    } catch (err: any) {
        logger.error('Failed to create clinic bill', { error: err.message });
        return response.internalError('Failed to create bill');
    }
}, CLINIC_OPTS);

export const getClinicBill = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid bill ID');
    try {
        const item = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), `CLINICBILL#${id}`);
        if (!item || item.isDeleted) return response.notFound('Bill');
        return response.success(item);
    } catch (err: any) {
        logger.error('Failed to get clinic bill', { error: err.message });
        return response.internalError('Failed to get bill');
    }
}, CLINIC_OPTS);

// ── ICD-10 Search (in-memory seed) ──────────────────────────────────────────
const ICD10_CODES: { code: string; description: string }[] = [
    { code: 'J06.9', description: 'Acute upper respiratory infection, unspecified' },
    { code: 'J20.9', description: 'Acute bronchitis, unspecified' },
    { code: 'A09', description: 'Infectious gastroenteritis and colitis' },
    { code: 'J18.9', description: 'Pneumonia, unspecified organism' },
    { code: 'N39.0', description: 'Urinary tract infection, site not specified' },
    { code: 'R50.9', description: 'Fever, unspecified' },
    { code: 'K29.7', description: 'Gastritis, unspecified' },
    { code: 'M54.5', description: 'Low back pain' },
    { code: 'I10', description: 'Essential (primary) hypertension' },
    { code: 'E11.9', description: 'Type 2 diabetes mellitus without complications' },
    { code: 'J45.9', description: 'Asthma, unspecified' },
    { code: 'L30.9', description: 'Dermatitis, unspecified' },
    { code: 'H10.9', description: 'Conjunctivitis, unspecified' },
    { code: 'B34.9', description: 'Viral infection, unspecified' },
    { code: 'K21.0', description: 'Gastro-esophageal reflux disease with esophagitis' },
    { code: 'R51', description: 'Headache' },
    { code: 'J00', description: 'Acute nasopharyngitis (common cold)' },
    { code: 'K59.0', description: 'Constipation' },
    { code: 'R11.2', description: 'Nausea with vomiting, unspecified' },
    { code: 'J02.9', description: 'Acute pharyngitis, unspecified' },
    { code: 'M79.3', description: 'Panniculitis, unspecified' },
    { code: 'E78.5', description: 'Dyslipidemia, unspecified' },
    { code: 'G43.9', description: 'Migraine, unspecified' },
    { code: 'J30.1', description: 'Allergic rhinitis due to pollen' },
    { code: 'B37.0', description: 'Candidal stomatitis (oral thrush)' },
];

export const searchICD10 = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const query = (event.queryStringParameters?.query || '').toLowerCase().trim();
    const limit = parseLimit(event.queryStringParameters?.limit, 10, 50);
    if (query.length < 2) return response.badRequest('Query must be at least 2 characters');
    const results = ICD10_CODES.filter(c => c.code.toLowerCase().includes(query) || c.description.toLowerCase().includes(query)).slice(0, limit);
    return response.success(results);
}, CLINIC_EMR_OPTS);

// ── Drug Search (common medicines seed) ─────────────────────────────────────
const COMMON_DRUGS: { name: string; genericName: string; category: string }[] = [
    { name: 'Paracetamol 500mg', genericName: 'Acetaminophen', category: 'Analgesic' },
    { name: 'Amoxicillin 500mg', genericName: 'Amoxicillin', category: 'Antibiotic' },
    { name: 'Azithromycin 500mg', genericName: 'Azithromycin', category: 'Antibiotic' },
    { name: 'Cetirizine 10mg', genericName: 'Cetirizine', category: 'Antihistamine' },
    { name: 'Omeprazole 20mg', genericName: 'Omeprazole', category: 'PPI' },
    { name: 'Pantoprazole 40mg', genericName: 'Pantoprazole', category: 'PPI' },
    { name: 'Metformin 500mg', genericName: 'Metformin', category: 'Antidiabetic' },
    { name: 'Amlodipine 5mg', genericName: 'Amlodipine', category: 'Antihypertensive' },
    { name: 'Atorvastatin 10mg', genericName: 'Atorvastatin', category: 'Statin' },
    { name: 'Ibuprofen 400mg', genericName: 'Ibuprofen', category: 'NSAID' },
    { name: 'Dolo 650', genericName: 'Paracetamol', category: 'Analgesic' },
    { name: 'Montelukast 10mg', genericName: 'Montelukast', category: 'Leukotriene inhibitor' },
    { name: 'Levocetrizine 5mg', genericName: 'Levocetirizine', category: 'Antihistamine' },
    { name: 'Ranitidine 150mg', genericName: 'Ranitidine', category: 'H2 blocker' },
    { name: 'Ciprofloxacin 500mg', genericName: 'Ciprofloxacin', category: 'Antibiotic' },
    { name: 'Cefixime 200mg', genericName: 'Cefixime', category: 'Antibiotic' },
    { name: 'Diclofenac 50mg', genericName: 'Diclofenac', category: 'NSAID' },
    { name: 'Ondansetron 4mg', genericName: 'Ondansetron', category: 'Antiemetic' },
    { name: 'Salbutamol Inhaler', genericName: 'Salbutamol', category: 'Bronchodilator' },
    { name: 'Metronidazole 400mg', genericName: 'Metronidazole', category: 'Antibiotic' },
];

export const searchDrugs = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const query = (event.queryStringParameters?.query || '').toLowerCase().trim();
    const limit = parseLimit(event.queryStringParameters?.limit, 10, 50);
    if (query.length < 2) return response.badRequest('Query must be at least 2 characters');
    const results = COMMON_DRUGS.filter(d => d.name.toLowerCase().includes(query) || d.genericName.toLowerCase().includes(query) || d.category.toLowerCase().includes(query)).slice(0, limit);
    return response.success(results);
}, CLINIC_PRESCRIPTION_OPTS);

// ── Refill Queue ────────────────────────────────────────────────────────────
export const createRefillRequest = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.clinicRefillRequestSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const id = crypto.randomUUID();
    try {
        const rx = await getItem<Record<string, any>>(pk, `PRESCRIPTION#${body.prescriptionId}`);
        if (!rx || rx.isDeleted) return response.notFound('Prescription');
        const item = {
            PK: pk, SK: `REFILL#${id}`, id, ...body,
            status: 'pending', createdAt: new Date().toISOString(), createdBy: auth.sub,
        };
        await putItem(item);
        return response.success({ id, status: 'pending' }, 201);
    } catch (err: any) {
        logger.error('Failed to create refill request', { error: err.message });
        return response.internalError('Failed to create refill request');
    }
}, CLINIC_PRESCRIPTION_OPTS);

export const listRefillRequests = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const status = event.queryStringParameters?.status;
    try {
        const opts: any = { filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)', expressionAttributeValues: { ':false': false } };
        if (status) { opts.filterExpression += ' AND #s = :status'; opts.expressionAttributeValues[':status'] = status; opts.expressionAttributeNames = { '#s': 'status' }; }
        const result = await queryItems<Record<string, any>>(pk, 'REFILL#', opts);
        return response.success(result.items);
    } catch (err: any) {
        logger.error('Failed to list refill requests', { error: err.message });
        return response.internalError('Failed to list refill requests');
    }
}, CLINIC_PRESCRIPTION_OPTS);

// ── Rate Limiter Helper (DynamoDB TTL-based) ────────────────────────────────
async function checkRateLimit(key: string, maxRequests: number, windowSeconds: number): Promise<boolean> {
    const now = Math.floor(Date.now() / 1000);
    const ttl = now + windowSeconds;
    try {
        const result = await updateItem('RATELIMIT', key, {
            updateExpression: 'SET #count = if_not_exists(#count, :zero) + :inc, #ttl = if_not_exists(#ttl, :ttl)',
            expressionAttributeNames: { '#count': 'requestCount', '#ttl': 'ttl' },
            expressionAttributeValues: { ':zero': 0, ':inc': 1, ':ttl': ttl },
        });
        const count = (result as any)?.requestCount || 0;
        return count <= maxRequests;
    } catch { return true; }
}

// ── Payment Collection ──────────────────────────────────────────────────────
export const collectPayment = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const billId = event.pathParameters?.id;
    if (!isValidUUID(billId)) return response.badRequest('Invalid bill ID');
    let body: any;
    try { body = JSON.parse(event.body || '{}'); } catch { return response.badRequest('Invalid JSON'); }
    const { paymentMode, amount, transactionRef } = body;
    if (!amount || amount <= 0) return response.badRequest('Amount must be positive');
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const bill = await getItem<Record<string, any>>(pk, `CLINICBILL#${billId}`);
        if (!bill || bill.isDeleted) return response.notFound('Bill');
        const paymentId = crypto.randomUUID();
        const payment = {
            PK: pk, SK: `CLINICPAYMENT#${paymentId}`, id: paymentId,
            billId, patientId: bill.patientId, amount,
            paymentMode: paymentMode || 'cash', transactionRef: transactionRef || null,
            status: 'completed', createdAt: new Date().toISOString(), createdBy: auth.sub,
        };
        await putItem(payment);
        // Update bill status
        const totalPaid = (bill.totalPaid || 0) + amount;
        const newStatus = totalPaid >= bill.grandTotal ? 'paid' : 'partial';
        await updateItem(pk, `CLINICBILL#${billId}`, {
            updateExpression: 'SET #s = :status, totalPaid = :paid, lastPaymentAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':status': newStatus, ':paid': totalPaid, ':now': new Date().toISOString() },
        });
        await recordRevision(auth.tenantId, 'clinic_payments', paymentId, 'create', auth.sub, null, payment, { source: 'clinic.collectPayment' });
        return response.success({ paymentId, billStatus: newStatus, totalPaid, remaining: bill.grandTotal - totalPaid }, 201);
    } catch (err: any) {
        logger.error('Failed to collect payment', { error: err.message });
        return response.internalError('Failed to collect payment');
    }
}, CLINIC_OPTS);

export const getBillPayments = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const billId = event.pathParameters?.id;
    if (!isValidUUID(billId)) return response.badRequest('Invalid bill ID');
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const result = await queryItems<Record<string, any>>(pk, 'CLINICPAYMENT#', {
            filterExpression: 'billId = :billId',
            expressionAttributeValues: { ':billId': billId },
        });
        return response.success(result.items);
    } catch (err: any) {
        logger.error('Failed to get payments', { error: err.message });
        return response.internalError('Failed to get payments');
    }
}, CLINIC_OPTS);

// ── Patient Portal (public-facing endpoints for logged-in patients) ─────────
export const getPatientPortalProfile = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        // Find patient linked to this user
        const patients = await queryItems<Record<string, any>>(pk, 'PATIENT#', {
            filterExpression: 'userId = :uid',
            expressionAttributeValues: { ':uid': auth.sub },
            limit: 1,
        });
        if (!patients.items.length) return response.notFound('Patient profile');
        const patient = patients.items[0];
        return response.success({
            id: patient.id, name: patient.name, phone: patient.phone,
            age: patient.age, gender: patient.gender, bloodGroup: patient.bloodGroup,
            allergies: patient.allergies, mrn: patient.mrn,
        });
    } catch (err: any) {
        logger.error('Failed to get patient portal profile', { error: err.message });
        return response.internalError('Failed to get profile');
    }
}, CLINIC_OPTS);

export const getPatientPortalAppointments = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        // Find patient linked to this user
        const patients = await queryItems<Record<string, any>>(pk, 'PATIENT#', {
            filterExpression: 'userId = :uid',
            expressionAttributeValues: { ':uid': auth.sub },
            limit: 1,
        });
        if (!patients.items.length) return response.notFound('Patient profile');
        const patientId = patients.items[0].id;
        const appointments = await queryItems<Record<string, any>>(pk, 'APPOINTMENT#', {
            filterExpression: 'patientId = :pid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':pid': patientId, ':false': false },
            scanIndexForward: false,
        });
        return response.success(appointments.items.map(a => ({
            id: a.id, scheduledDate: a.scheduledDate || a.appointmentDate,
            scheduledTime: a.scheduledTime || a.appointmentTime,
            status: a.status, purpose: a.purpose, tokenNumber: a.tokenNumber,
        })));
    } catch (err: any) {
        logger.error('Failed to get patient appointments', { error: err.message });
        return response.internalError('Failed to get appointments');
    }
}, CLINIC_OPTS);

export const getPatientPortalRecords = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    try {
        const patients = await queryItems<Record<string, any>>(pk, 'PATIENT#', {
            filterExpression: 'userId = :uid',
            expressionAttributeValues: { ':uid': auth.sub },
            limit: 1,
        });
        if (!patients.items.length) return response.notFound('Patient profile');
        const patientId = patients.items[0].id;
        const [visits, prescriptions] = await Promise.all([
            queryItems<Record<string, any>>(pk, 'VISIT#', {
                filterExpression: 'patientId = :pid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':pid': patientId, ':false': false },
                scanIndexForward: false, limit: 20,
            }),
            queryItems<Record<string, any>>(pk, 'PRESCRIPTION#', {
                filterExpression: 'patientId = :pid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':pid': patientId, ':false': false },
                scanIndexForward: false, limit: 20,
            }),
        ]);
        return response.success({ visits: visits.items, prescriptions: prescriptions.items });
    } catch (err: any) {
        logger.error('Failed to get patient records', { error: err.message });
        return response.internalError('Failed to get records');
    }
}, CLINIC_OPTS);
