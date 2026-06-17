// ============================================================================
// Lambda Handler — Academic Coaching Module (DynamoDB)
// ============================================================================
// Entities: Students, Batches, Courses, Fee Records, Attendance, Faculty,
//           Exams, Results, Timetable, Study Materials, Invoices, Dashboard
// All routes: /ac/*   (require JWT + BusinessType.SCHOOL_ERP)
// ============================================================================
import { configureAwsClient } from '../config/aws.config';
import { authorizedHandler } from '../middleware/handler-wrapper';
import {
    Keys,
    queryAllItems,
    putItem,
    getItem,
    updateItem,
    deleteItem,
    batchWrite,
    queryItems,
} from '../config/dynamodb.config';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import * as wsService from '../services/websocket.service';
import { WSEventName, ClientType } from '../types/websocket.types';
import { StorageService } from '../services/storage.service';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses'; // install: npm i @aws-sdk/client-ses
import { config } from '../config/environment';

const storageService = new StorageService();
const snsClient = new SNSClient(configureAwsClient({ region: config.aws.region }));
const sesClient = new SESClient(configureAwsClient({ region: config.aws.region }));

async function sendSmsViaSns(phone: string, message: string, tenantId: string): Promise<void> {
    if (!config.aws.region || phone.length < 10) return;
    try {
        await snsClient.send(new PublishCommand({
            PhoneNumber: phone.startsWith('+') ? phone : `+91${phone}`,
            Message: message,
            MessageAttributes: {
                'AWS.SNS.SMS.SMSType': { DataType: 'String', StringValue: 'Transactional' },
                'AWS.SNS.SMS.SenderID': { DataType: 'String', StringValue: 'DukanX' },
            },
        }));
        logger.info('SMS sent', { tenantId, phone: phone.slice(-4) });
    } catch (err) {
        logger.error('SMS send failed', { tenantId, error: (err as Error).message });
    }
}

async function sendEmailViaSes(to: string, subject: string, body: string, tenantId: string): Promise<void> {
    if (!to || !to.includes('@')) return;
    const fromEmail = process.env.SES_FROM_EMAIL || 'noreply@dukanx.in';
    try {
        await sesClient.send(new SendEmailCommand({
            Source: fromEmail,
            Destination: { ToAddresses: [to] },
            Message: {
                Subject: { Data: subject },
                Body: { Text: { Data: body } },
            },
        }));
        logger.info('Email sent', { tenantId, to });
    } catch (err) {
        logger.error('Email send failed', { tenantId, error: (err as Error).message });
    }
}

async function sendWhatsApp(phone: string, message: string, tenantId: string): Promise<void> {
    const waUrl = config.whatsapp.apiUrl || '';
    const waToken = config.whatsapp.accessToken || '';
    const waPhoneId = config.whatsapp.phoneNumberId || '';
    if (!waUrl || !waToken || !waPhoneId) return;
    const normalized = phone.startsWith('+') ? phone.replace('+', '') : `91${phone}`;
    try {
        const { default: https } = await import('https');
        const payload = JSON.stringify({
            messaging_product: 'whatsapp',
            to: normalized,
            type: 'text',
            text: { body: message },
        });
        await new Promise<void>((resolve, reject) => {
            const req = https.request(`${waUrl}/${waPhoneId}/messages`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${waToken}`, 'Content-Type': 'application/json' },
            }, (res) => { res.resume(); resolve(); });
            req.on('error', reject);
            req.write(payload);
            req.end();
        });
        logger.info('WhatsApp sent', { tenantId, phone: phone.slice(-4) });
    } catch (err) {
        logger.error('WhatsApp send failed', { tenantId, error: (err as Error).message });
    }
}

// ── Handler Options ────────────────────────────────────────────────────────
const AC_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_STUDENT_MANAGEMENT,
};
const AC_BATCH_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_BATCH_MANAGEMENT,
};
const AC_COURSE_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_COURSE_MANAGEMENT,
};
const AC_FEE_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_FEE_MANAGEMENT,
};
const AC_ATTENDANCE_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_ATTENDANCE_MANAGEMENT,
};
const AC_FACULTY_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_FACULTY_MANAGEMENT,
};
const AC_EXAM_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_EXAM_MANAGEMENT,
};
const AC_TIMETABLE_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_TIMETABLE_MANAGEMENT,
};
const AC_MATERIAL_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_MATERIAL_MANAGEMENT,
};
const AC_REPORTS_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_REPORTS_ANALYTICS,
};

// ── Helpers ────────────────────────────────────────────────────────────────
function uid(): string {
    return crypto.randomUUID().replace(/-/g, '').substring(0, 16).toUpperCase();
}

function now(): string {
    return new Date().toISOString();
}

function parseBody<T>(event: any): T {
    if (!event.body) throw new Error('Request body is required');
    return typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
}

function paisaToRupee(paisa: number): number {
    return Math.round(paisa) / 100;
}

function rupeeToPaisa(rupee: number): number {
    return Math.round(rupee * 100);
}

// ============================================================================
// STUDENT MANAGEMENT
// ============================================================================

/**
 * GET /ac/students?batchId=&search=&status=&page=&limit=
 */
export const listStudents = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);

    let students: Record<string, any>[] = [];

    if (p.batchId) {
        // Query by batch using GSI
        const batchStudents = await queryAllItems<Record<string, any>>(
            Keys.acStudentByBatchGSI1PK(auth.tenantId, p.batchId),
            '',
            { indexName: 'GSI1' }
        );
        students = batchStudents;
    } else {
        students = await queryAllItems<Record<string, any>>(pk, 'AC_STUDENT#');
    }

    // Apply filters
    if (p.search) {
        const s = p.search.toLowerCase();
        students = students.filter((st: Record<string, any>) =>
            (st.firstName || '').toLowerCase().includes(s) ||
            (st.lastName || '').toLowerCase().includes(s) ||
            (st.phone || '').toLowerCase().includes(s) ||
            (st.studentId || '').toLowerCase().includes(s)
        );
    }
    if (p.status) {
        students = students.filter((st: Record<string, any>) => st.status === p.status);
    }

    // Sort by createdAt desc
    students.sort((a: Record<string, any>, b: Record<string, any>) =>
        (b.createdAt || '').localeCompare(a.createdAt || '')
    );

    const total = students.length;
    const paged = students.slice((page - 1) * limit, page * limit);

    // Enrich with batch names
    const batchIds = [...new Set(paged.flatMap((s: Record<string, any>) => s.enrolledBatchIds || []))];
    if (batchIds.length > 0) {
        const batchKeys = batchIds.map(id => ({ PK: pk, SK: Keys.acBatchSK(id) }));
        const { batchGetItems } = await import('../config/dynamodb.config');
        const batches = await batchGetItems(batchKeys);
        const batchMap = new Map(batches.map((b: any) => [b.id, b.name]));
        paged.forEach((s: Record<string, any>) => {
            s.batchNames = (s.enrolledBatchIds || []).map((id: string) => batchMap.get(id) || 'Unknown');
        });
    }

    return response.paginated(paged, total, page, limit);
}, AC_OPTS);

/**
 * GET /ac/students/{id}
 */
export const getStudent = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Student ID required');
    const pk = Keys.tenantPK(auth.tenantId);
    const item = await getItem(pk, Keys.acStudentSK(id));
    if (!item) return response.notFound('Student not found');

    // Get fee summary
    const fees = await queryAllItems<Record<string, any>>(
        Keys.acFeeByStudentGSI1PK(auth.tenantId, id),
        '',
        { indexName: 'GSI1' }
    );
    const totalFees = fees.reduce((sum, f) => sum + (f.totalAmountPaisa || 0), 0);
    const totalPaid = fees.reduce((sum, f) => sum + (f.paidAmountPaisa || 0), 0);

    // Get attendance summary
    const attendance = await queryAllItems<Record<string, any>>(pk, `AC_ATTENDANCE#`, {
        filterExpression: 'contains(studentIds, :studentId)',
        expressionAttributeValues: { ':studentId': id }
    });
    const presentCount = attendance.filter(a => a.records?.[id] === 'P').length;
    const totalClasses = attendance.length;

    return response.success({
        ...item,
        feeSummary: {
            totalFeesPaisa: totalFees,
            totalPaidPaisa: totalPaid,
            balancePaisa: totalFees - totalPaid,
            totalFees: paisaToRupee(totalFees),
            totalPaid: paisaToRupee(totalPaid),
            balance: paisaToRupee(totalFees - totalPaid),
        },
        attendanceSummary: {
            totalClasses,
            presentCount,
            percentage: totalClasses > 0 ? Math.round((presentCount / totalClasses) * 100) : 0,
        },
    });
}, AC_OPTS);

/**
 * POST /ac/students
 */
export const createStudent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            firstName, lastName, dob, gender,
            phone, parentPhone, parentName, email, address,
            schoolName, currentClass, board,
            enrolledCourseIds = [], enrolledBatchIds = [],
            photoS3Key, referralSource, branchId,
        } = body;

        if (!firstName || !lastName || !phone) {
            return response.badRequest('firstName, lastName, phone are required');
        }

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const studentId = `STU-${auth.tenantId.substring(0, 8)}-${new Date().toISOString().slice(0, 7).replace('-', '')}-${id.substring(0, 6)}`;

        const item: Record<string, any> = {
            PK: pk,
            SK: Keys.acStudentSK(id),
            GSI1PK: enrolledBatchIds.length > 0 ? Keys.acStudentByBatchGSI1PK(auth.tenantId, enrolledBatchIds[0]) : null,
            GSI1SK: `STUDENT#${id}`,
            id,
            studentId,
            firstName,
            lastName,
            dob,
            gender,
            phone,
            parentPhone,
            parentName,
            email,
            address,
            schoolName,
            currentClass,
            board,
            enrolledCourseIds,
            enrolledBatchIds,
            photoS3Key,
            referralSource,
            branchId,
            status: 'active',
            createdAt: ts,
            updatedAt: ts,
            createdBy: auth.sub,
        };

        // Remove null GSI1PK if no batch
        if (!item.GSI1PK) delete item.GSI1PK;

        await putItem(item);
        logger.info('AC student created', { tenantId: auth.tenantId, studentId: id });

        // Broadcast to desktop app
        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.AC_STUDENT_ENROLLED,
            { studentId: id, firstName, lastName, batchIds: enrolledBatchIds },
        ).catch(() => { /* non-critical */ });

        // Generate real S3 presigned PUT URL for photo upload
        let photoUploadUrl: string | null = null;
        if (photoS3Key) {
            const s3Key = `tenants/${auth.tenantId}/students/${id}/${photoS3Key}`;
            photoUploadUrl = await storageService.getUploadUrl(s3Key, 'image/jpeg').catch(() => null);
        }

        return response.success({ ...item, photoUploadUrl }, 201);
    },
    AC_OPTS,
);

/**
 * PUT /ac/students/{id}
 */
export const updateStudent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Student ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);

        const existing = await getItem<Record<string, any>>(pk, Keys.acStudentSK(id));
        if (!existing) return response.notFound('Student not found');

        const allowed = [
            'firstName', 'lastName', 'dob', 'gender', 'phone', 'parentPhone',
            'parentName', 'email', 'address', 'schoolName', 'currentClass', 'board',
            'enrolledCourseIds', 'enrolledBatchIds', 'photoS3Key', 'status', 'notes',
        ];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) {
            if (body[k] !== undefined) updates[k] = body[k];
        }

        // Update GSI1 if batch changed
        if (body.enrolledBatchIds !== undefined && body.enrolledBatchIds.length > 0) {
            updates.GSI1PK = Keys.acStudentByBatchGSI1PK(auth.tenantId, body.enrolledBatchIds[0]);
        }

        // Atomically sync enrolledCount on batch when batch assignment changes
        const oldBatchIds: string[] = existing.enrolledBatchIds || [];
        const newBatchIds: string[] = body.enrolledBatchIds ?? oldBatchIds;
        const added = newBatchIds.filter((b: string) => !oldBatchIds.includes(b));
        const removed = oldBatchIds.filter((b: string) => !newBatchIds.includes(b));
        for (const bId of added) {
            await updateItem(pk, Keys.acBatchSK(bId), {
                updateExpression: 'SET #ec = if_not_exists(#ec, :zero) + :one',
                expressionAttributeNames: { '#ec': 'enrolledCount' },
                expressionAttributeValues: { ':zero': 0, ':one': 1 },
            }).catch(() => { });
        }
        for (const bId of removed) {
            await updateItem(pk, Keys.acBatchSK(bId), {
                updateExpression: 'SET #ec = if_not_exists(#ec, :one) - :one',
                expressionAttributeNames: { '#ec': 'enrolledCount' },
                expressionAttributeValues: { ':one': 1, ':zero': 0 },
                conditionExpression: '#ec > :zero',
            }).catch(() => { });
        }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }

        await updateItem(pk, Keys.acStudentSK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        logger.info('AC student updated', { tenantId: auth.tenantId, studentId: id });
        return response.success({ id, ...updates });
    },
    AC_OPTS,
);

/**
 * DELETE /ac/students/{id}
 */
export const deleteStudent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Student ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const existing = await getItem<Record<string, any>>(pk, Keys.acStudentSK(id));
        if (!existing) return response.notFound('Student not found');

        // Soft delete - update status
        await updateItem(pk, Keys.acStudentSK(id), {
            updateExpression: 'SET #status = :status, #updatedAt = :updatedAt',
            expressionAttributeNames: { '#status': 'status', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':status': 'inactive', ':updatedAt': now() },
        });

        logger.info('AC student soft deleted', { tenantId: auth.tenantId, studentId: id });
        return response.success({ id, status: 'inactive' });
    },
    AC_OPTS,
);

/**
 * POST /ac/students/{id}/transfer
 */
export const transferStudent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Student ID required');
        const body = parseBody<Record<string, any>>(event);
        const { fromBatchId, toBatchId, transferDate, reason } = body;

        if (!fromBatchId || !toBatchId) {
            return response.badRequest('fromBatchId and toBatchId are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(id));
        if (!student) return response.notFound('Student not found');

        const batchIds = student.enrolledBatchIds || [];
        if (!batchIds.includes(fromBatchId)) {
            return response.badRequest('Student not enrolled in fromBatchId');
        }

        // Update batch IDs
        const newBatchIds = batchIds.filter((b: string) => b !== fromBatchId);
        if (!newBatchIds.includes(toBatchId)) {
            newBatchIds.push(toBatchId);
        }

        // Adjust enrolledCount on both batches atomically
        await Promise.all([
            updateItem(pk, Keys.acBatchSK(fromBatchId), {
                updateExpression: 'SET #ec = if_not_exists(#ec, :one) - :one',
                expressionAttributeNames: { '#ec': 'enrolledCount' },
                expressionAttributeValues: { ':one': 1 },
            }).catch(() => { }),
            updateItem(pk, Keys.acBatchSK(toBatchId), {
                updateExpression: 'SET #ec = if_not_exists(#ec, :zero) + :one',
                expressionAttributeNames: { '#ec': 'enrolledCount' },
                expressionAttributeValues: { ':zero': 0, ':one': 1 },
            }).catch(() => { }),
        ]);

        await updateItem(pk, Keys.acStudentSK(id), {
            updateExpression: 'SET #enrolledBatchIds = :batchIds, #GSI1PK = :gsi1pk, #updatedAt = :updatedAt, #transferHistory = list_append(if_not_exists(#transferHistory, :empty), :transfer)',
            expressionAttributeNames: {
                '#enrolledBatchIds': 'enrolledBatchIds',
                '#GSI1PK': 'GSI1PK',
                '#updatedAt': 'updatedAt',
                '#transferHistory': 'transferHistory',
            },
            expressionAttributeValues: {
                ':batchIds': newBatchIds,
                ':gsi1pk': Keys.acStudentByBatchGSI1PK(auth.tenantId, toBatchId),
                ':updatedAt': now(),
                ':empty': [],
                ':transfer': [{
                    fromBatchId, toBatchId, transferDate: transferDate || now(), reason, transferredAt: now(),
                }],
            },
        });

        logger.info('AC student transferred', { tenantId: auth.tenantId, studentId: id, fromBatchId, toBatchId });
        return response.success({ id, enrolledBatchIds: newBatchIds });
    },
    AC_OPTS,
);

// BATCH & COURSE MANAGEMENT
// ============================================================================

/**
 * GET /ac/batches?page=&limit=&status=
 */
export const listBatches = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);

    let batches = await queryAllItems<Record<string, any>>(pk, 'AC_BATCH#');

    // Filter by status if provided
    if (p.status) {
        batches = batches.filter((b: Record<string, any>) => b.status === p.status);
    }

    // Sort by createdAt desc
    batches.sort((a: Record<string, any>, b: Record<string, any>) =>
        (b.createdAt || '').localeCompare(a.createdAt || '')
    );

    const total = batches.length;
    const paged = batches.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
}, AC_BATCH_OPTS);

/**
 * POST /ac/batches
 */
export const createBatch = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            name, courseId, branchId, batchCode,
            schedule = [], startDate, endDate,
            maxCapacity = 30, batchType = 'regular',
        } = body;

        if (!name || !courseId) {
            return response.badRequest('name and courseId are required');
        }

        const id = uid();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk,
            SK: Keys.acBatchSK(id),
            id,
            name,
            courseId,
            branchId,
            batchCode: batchCode || `BATCH-${id.substring(0, 6)}`,
            schedule,
            startDate,
            endDate,
            maxCapacity: Number(maxCapacity),
            enrolledCount: 0,
            status: 'upcoming',
            batchType,
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('AC batch created', { tenantId: auth.tenantId, batchId: id });
        return response.success(item, 201);
    },
    AC_BATCH_OPTS,
);

/**
 * GET /ac/batches/{id}
 */
export const getBatch = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Batch ID required');
    const pk = Keys.tenantPK(auth.tenantId);

    const batch = await getItem<Record<string, any>>(pk, Keys.acBatchSK(id));
    if (!batch) return response.notFound('Batch not found');

    // Get course details
    const course = await getItem<Record<string, any>>(pk, Keys.acCourseSK(batch.courseId));

    return response.success({
        ...batch,
        courseName: course?.name,
    });
}, AC_BATCH_OPTS);

/**
 * PUT /ac/batches/{id}
 */
export const updateBatch = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Batch ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const batch = await getItem<Record<string, any>>(pk, Keys.acBatchSK(id));
        if (!batch) return response.notFound('Batch not found');

        const body = parseBody<Record<string, any>>(event);
        const exprParts: string[] = ['#updatedAt = :updatedAt'];
        const names: Record<string, string> = { '#updatedAt': 'updatedAt' };
        const values: Record<string, any> = { ':updatedAt': now() };

        if (body.name) { exprParts.push('#name = :name'); names['#name'] = 'name'; values[':name'] = body.name; }
        if (body.courseId) { exprParts.push('#courseId = :courseId'); names['#courseId'] = 'courseId'; values[':courseId'] = body.courseId; }
        if (body.schedule) { exprParts.push('#schedule = :schedule'); names['#schedule'] = 'schedule'; values[':schedule'] = body.schedule; }
        if (body.startDate) { exprParts.push('#startDate = :startDate'); names['#startDate'] = 'startDate'; values[':startDate'] = body.startDate; }
        if (body.endDate) { exprParts.push('#endDate = :endDate'); names['#endDate'] = 'endDate'; values[':endDate'] = body.endDate; }
        if (body.maxCapacity) { exprParts.push('#maxCapacity = :maxCapacity'); names['#maxCapacity'] = 'maxCapacity'; values[':maxCapacity'] = Number(body.maxCapacity); }
        if (body.status) { exprParts.push('#status = :status'); names['#status'] = 'status'; values[':status'] = body.status; }
        if (body.batchType) { exprParts.push('#batchType = :batchType'); names['#batchType'] = 'batchType'; values[':batchType'] = body.batchType; }
        if (body.facultyIds) { exprParts.push('#facultyIds = :facultyIds'); names['#facultyIds'] = 'facultyIds'; values[':facultyIds'] = body.facultyIds; }

        await updateItem(pk, Keys.acBatchSK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        logger.info('AC batch updated', { tenantId: auth.tenantId, batchId: id });
        return response.success({ ...batch, ...body, updatedAt: now() });
    },
    AC_BATCH_OPTS,
);

/**
 * DELETE /ac/batches/{id}
 */
export const deleteBatch = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Batch ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const batch = await getItem<Record<string, any>>(pk, Keys.acBatchSK(id));
        if (!batch) return response.notFound('Batch not found');

        // Check if batch has enrolled students
        if (batch.enrolledCount > 0) {
            return response.conflict('Cannot delete batch with enrolled students. Transfer students first.');
        }

        await deleteItem(pk, Keys.acBatchSK(id));
        logger.info('AC batch deleted', { tenantId: auth.tenantId, batchId: id });
        return response.success({ message: 'Batch deleted successfully' });
    },
    AC_BATCH_OPTS,
);

/**
 * GET /ac/batches/{id}/seats
 */
export const getBatchSeats = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Batch ID required');
    const pk = Keys.tenantPK(auth.tenantId);

    const batch = await getItem<Record<string, any>>(pk, Keys.acBatchSK(id));
    if (!batch) return response.notFound('Batch not found');

    // Count enrolled students
    const students = await queryAllItems<Record<string, any>>(
        Keys.acStudentByBatchGSI1PK(auth.tenantId, id),
        '',
        { indexName: 'GSI1' }
    );

    return response.success({
        batchId: id,
        batchName: batch.name,
        maxCapacity: batch.maxCapacity,
        enrolledCount: students.length,
        availableSeats: batch.maxCapacity - students.length,
        waitlistCount: Math.max(0, students.length - batch.maxCapacity),
    });
}, AC_BATCH_OPTS);

/**
 * GET /ac/courses?page=&limit=&isActive=
 */
export const listCourses = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);

    let courses = await queryAllItems<Record<string, any>>(pk, 'AC_COURSE#');

    // Filter by isActive if provided
    if (p.isActive !== undefined) {
        const active = p.isActive === 'true';
        courses = courses.filter((c: Record<string, any>) => c.isActive === active);
    }

    // Sort by name
    courses.sort((a: Record<string, any>, b: Record<string, any>) =>
        (a.name || '').localeCompare(b.name || '')
    );

    const total = courses.length;
    const paged = courses.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
}, AC_COURSE_OPTS);

/**
 * POST /ac/courses
 */
export const createCourse = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            name, description, subjects = [],
            duration, targetExam,
            totalFee, materialFee, admissionFee,
        } = body;

        if (!name) return response.badRequest('name is required');

        const id = uid();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk,
            SK: Keys.acCourseSK(id),
            id,
            name,
            description,
            subjects,
            duration,
            targetExam,
            totalFeePaisa: rupeeToPaisa(totalFee || 0),
            materialFeePaisa: rupeeToPaisa(materialFee || 0),
            admissionFeePaisa: rupeeToPaisa(admissionFee || 0),
            totalFee: totalFee || 0,
            materialFee: materialFee || 0,
            admissionFee: admissionFee || 0,
            isActive: true,
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('AC course created', { tenantId: auth.tenantId, courseId: id });
        return response.success(item, 201);
    },
    AC_COURSE_OPTS,
);

/**
 * GET /ac/courses/{id}
 */
export const getCourse = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Course ID required');
    const pk = Keys.tenantPK(auth.tenantId);

    const course = await getItem<Record<string, any>>(pk, Keys.acCourseSK(id));
    if (!course) return response.notFound('Course not found');

    return response.success(course);
}, AC_COURSE_OPTS);

/**
 * PUT /ac/courses/{id}
 */
export const updateCourse = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Course ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const course = await getItem<Record<string, any>>(pk, Keys.acCourseSK(id));
        if (!course) return response.notFound('Course not found');

        const body = parseBody<Record<string, any>>(event);
        const exprParts: string[] = ['#updatedAt = :updatedAt'];
        const names: Record<string, string> = { '#updatedAt': 'updatedAt' };
        const values: Record<string, any> = { ':updatedAt': now() };

        if (body.name) { exprParts.push('#name = :name'); names['#name'] = 'name'; values[':name'] = body.name; }
        if (body.description) { exprParts.push('#description = :description'); names['#description'] = 'description'; values[':description'] = body.description; }
        if (body.subjects) { exprParts.push('#subjects = :subjects'); names['#subjects'] = 'subjects'; values[':subjects'] = body.subjects; }
        if (body.duration) { exprParts.push('#duration = :duration'); names['#duration'] = 'duration'; values[':duration'] = body.duration; }
        if (body.targetExam) { exprParts.push('#targetExam = :targetExam'); names['#targetExam'] = 'targetExam'; values[':targetExam'] = body.targetExam; }
        if (body.totalFee !== undefined) {
            exprParts.push('#totalFee = :totalFee', '#totalFeePaisa = :totalFeePaisa');
            names['#totalFee'] = 'totalFee'; names['#totalFeePaisa'] = 'totalFeePaisa';
            values[':totalFee'] = body.totalFee; values[':totalFeePaisa'] = rupeeToPaisa(body.totalFee);
        }
        if (body.materialFee !== undefined) {
            exprParts.push('#materialFee = :materialFee', '#materialFeePaisa = :materialFeePaisa');
            names['#materialFee'] = 'materialFee'; names['#materialFeePaisa'] = 'materialFeePaisa';
            values[':materialFee'] = body.materialFee; values[':materialFeePaisa'] = rupeeToPaisa(body.materialFee);
        }
        if (body.admissionFee !== undefined) {
            exprParts.push('#admissionFee = :admissionFee', '#admissionFeePaisa = :admissionFeePaisa');
            names['#admissionFee'] = 'admissionFee'; names['#admissionFeePaisa'] = 'admissionFeePaisa';
            values[':admissionFee'] = body.admissionFee; values[':admissionFeePaisa'] = rupeeToPaisa(body.admissionFee);
        }
        if (body.isActive !== undefined) { exprParts.push('#isActive = :isActive'); names['#isActive'] = 'isActive'; values[':isActive'] = body.isActive; }

        await updateItem(pk, Keys.acCourseSK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        logger.info('AC course updated', { tenantId: auth.tenantId, courseId: id });
        return response.success({ ...course, ...body, updatedAt: now() });
    },
    AC_COURSE_OPTS,
);

/**
 * DELETE /ac/courses/{id}
 */
export const deleteCourse = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Course ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const course = await getItem<Record<string, any>>(pk, Keys.acCourseSK(id));
        if (!course) return response.notFound('Course not found');

        // Check if course has active batches
        const batches = await queryAllItems<Record<string, any>>(pk, 'AC_BATCH#');
        const activeBatches = batches.filter(b => b.courseId === id && b.status === 'active');

        if (activeBatches.length > 0) {
            return response.conflict(`Cannot delete course with ${activeBatches.length} active batches`);
        }

        await deleteItem(pk, Keys.acCourseSK(id));
        logger.info('AC course deleted', { tenantId: auth.tenantId, courseId: id });
        return response.success({ message: 'Course deleted successfully' });
    },
    AC_COURSE_OPTS,
);

// ============================================================================
// FEE MANAGEMENT
// ============================================================================

/**
 * GET /ac/fees/student/{studentId}
 */
export const getStudentFees = authorizedHandler([], async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const fees = await queryAllItems<Record<string, any>>(
        Keys.acFeeByStudentGSI1PK(auth.tenantId, studentId),
        '',
        { indexName: 'GSI1' }
    );

    // Convert paisa to rupees for display
    fees.forEach(f => {
        f.totalAmount = paisaToRupee(f.totalAmountPaisa || 0);
        f.paidAmount = paisaToRupee(f.paidAmountPaisa || 0);
        f.balance = paisaToRupee((f.totalAmountPaisa || 0) - (f.paidAmountPaisa || 0));
    });

    return response.success(fees);
}, AC_FEE_OPTS);

/**
 * POST /ac/invoices
 */
export const createInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            studentId, feeComponents = [], discountIds = [],
            adjustmentAmount = 0, adjustmentNote, dueDate,
        } = body;

        if (!studentId) return response.badRequest('studentId is required');

        const pk = Keys.tenantPK(auth.tenantId);
        const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(studentId));
        if (!student) return response.notFound('Student not found');

        // Calculate amounts
        let totalPaisa = 0;
        const components = feeComponents.map((fc: any) => {
            const amountPaisa = rupeeToPaisa(fc.amount || 0);
            totalPaisa += amountPaisa;
            return { ...fc, amountPaisa, amount: fc.amount || 0 };
        });

        // Apply discounts
        let discountPaisa = 0;
        // TODO: Fetch and apply discount rules

        const finalTotalPaisa = totalPaisa - discountPaisa + rupeeToPaisa(adjustmentAmount);
        const id = uid();
        const invoiceNumber = `INV-AC-${new Date().toISOString().slice(0, 7).replace('-', '')}-${id.substring(0, 6)}`;

        const item = {
            PK: pk,
            SK: Keys.acInvoiceSK(id),
            GSI1PK: Keys.acFeeByStudentGSI1PK(auth.tenantId, studentId),
            GSI1SK: `INVOICE#${dueDate || now()}#${id}`,
            id,
            invoiceNumber,
            studentId,
            studentName: `${student.firstName} ${student.lastName}`,
            feeComponents: components,
            discountIds,
            discountAmountPaisa: discountPaisa,
            discountAmount: paisaToRupee(discountPaisa),
            adjustmentAmountPaisa: rupeeToPaisa(adjustmentAmount),
            adjustmentAmount,
            adjustmentNote,
            totalAmountPaisa: finalTotalPaisa,
            totalAmount: paisaToRupee(finalTotalPaisa),
            paidAmountPaisa: 0,
            paidAmount: 0,
            balancePaisa: finalTotalPaisa,
            balance: paisaToRupee(finalTotalPaisa),
            status: 'pending',
            dueDate: dueDate || new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);

        // Create fee record for tracking
        const feeRecordId = uid();
        await putItem({
            PK: pk,
            SK: Keys.acFeeRecordSK(feeRecordId),
            GSI1PK: Keys.acFeeByStudentGSI1PK(auth.tenantId, studentId),
            GSI1SK: `FEE#${item.dueDate}#${feeRecordId}`,
            id: feeRecordId,
            invoiceId: id,
            studentId,
            type: 'invoice',
            totalAmountPaisa: finalTotalPaisa,
            paidAmountPaisa: 0,
            status: 'pending',
            dueDate: item.dueDate,
            createdAt: now(),
        });

        logger.info('AC invoice created', { tenantId: auth.tenantId, invoiceId: id });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.AC_INVOICE_GENERATED,
            { invoiceId: id, studentId, amount: paisaToRupee(finalTotalPaisa) },
        ).catch(() => { });

        return response.success({ ...item, pdfUrl: null }, 201);
    },
    AC_FEE_OPTS,
);

/**
 * POST /ac/payments
 */
export const recordPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            invoiceId, studentId, amount, paymentMethod,
            transactionRef, paymentDate, remarks,
        } = body;

        if (!invoiceId || !studentId || !amount) {
            return response.badRequest('invoiceId, studentId, amount are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const invoice = await getItem<Record<string, any>>(pk, Keys.acInvoiceSK(invoiceId));
        if (!invoice) return response.notFound('Invoice not found');

        const amountPaisa = rupeeToPaisa(amount);
        const newPaidPaisa = (invoice.paidAmountPaisa || 0) + amountPaisa;
        const balancePaisa = (invoice.totalAmountPaisa || 0) - newPaidPaisa;

        let status = 'partial';
        if (balancePaisa <= 0) status = 'paid';
        else if (new Date(invoice.dueDate) < new Date() && balancePaisa > 0) {
            status = 'overdue';
        }

        // Update invoice
        await updateItem(pk, Keys.acInvoiceSK(invoiceId), {
            updateExpression: 'SET #paidAmountPaisa = :paid, #paidAmount = :paidRupees, #balancePaisa = :balance, #balance = :balanceRupees, #status = :status, #updatedAt = :updatedAt',
            expressionAttributeNames: {
                '#paidAmountPaisa': 'paidAmountPaisa',
                '#paidAmount': 'paidAmount',
                '#balancePaisa': 'balancePaisa',
                '#balance': 'balance',
                '#status': 'status',
                '#updatedAt': 'updatedAt',
            },
            expressionAttributeValues: {
                ':paid': newPaidPaisa,
                ':paidRupees': paisaToRupee(newPaidPaisa),
                ':balance': balancePaisa,
                ':balanceRupees': paisaToRupee(balancePaisa),
                ':status': status,
                ':updatedAt': now(),
            },
        });

        // Create payment record
        const paymentId = uid();
        const payment = {
            PK: pk,
            SK: Keys.acPaymentSK(paymentId),
            id: paymentId,
            invoiceId,
            studentId,
            amountPaisa,
            amount,
            paymentMethod,
            transactionRef,
            paymentDate: paymentDate || now(),
            remarks,
            collectedBy: auth.sub,
            createdAt: now(),
        };
        await putItem(payment);

        logger.info('AC payment recorded', { tenantId: auth.tenantId, paymentId, invoiceId });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.AC_FEE_COLLECTED,
            { studentId, amount, invoiceId, collectedBy: auth.sub },
        ).catch(() => { });

        return response.success({ ...payment, receiptUrl: null }, 201);
    },
    AC_FEE_OPTS,
);

// ============================================================================
// ATTENDANCE MANAGEMENT
// ============================================================================

/**
 * POST /ac/attendance
 */
export const markAttendance = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            batchId, subjectId, date, facultyId,
            schedule, attendanceRecords = [],
        } = body;

        if (!batchId || !date || !attendanceRecords.length) {
            return response.badRequest('batchId, date, attendanceRecords are required');
        }

        // Validate not future date
        if (new Date(date) > new Date()) {
            return response.badRequest('Cannot mark attendance for future dates');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const attendanceId = `${batchId}#${date}`;

        // Build records map
        const records: Record<string, string> = {};
        let presentCount = 0;
        let absentCount = 0;
        let leaveCount = 0;

        attendanceRecords.forEach((r: any) => {
            records[r.studentId] = r.status; // P, A, L
            if (r.status === 'P') presentCount++;
            else if (r.status === 'A') absentCount++;
            else if (r.status === 'L') leaveCount++;
        });

        const item = {
            PK: pk,
            SK: Keys.acAttendanceSK(attendanceId),
            GSI1PK: Keys.acAttendanceByBatchGSI1PK(auth.tenantId, batchId),
            GSI1SK: `DATE#${date}`,
            id: attendanceId,
            batchId,
            subjectId,
            date,
            facultyId,
            schedule,
            records,
            presentCount,
            absentCount,
            leaveCount,
            totalCount: attendanceRecords.length,
            createdAt: now(),
            updatedAt: now(),
            markedBy: auth.sub,
        };

        await putItem(item);

        // Check for low attendance and alert
        const lowAttendanceStudents = attendanceRecords
            .filter((r: any) => r.status === 'A')
            .map((r: any) => r.studentId);

        if (lowAttendanceStudents.length > 0) {
            // Send absence notifications to parents
            for (const sid of lowAttendanceStudents) {
                const absentStudent = await getItem<Record<string, any>>(pk, Keys.acStudentSK(sid)).catch(() => null);
                if (!absentStudent) continue;
                const msg = `DukanX: ${absentStudent.firstName} ${absentStudent.lastName} was marked ABSENT for ${subjectId ? subjectId + ' ' : ''}class on ${date}. Please contact the institute if needed.`;
                if (absentStudent.parentPhone) {
                    sendSmsViaSns(absentStudent.parentPhone, msg, auth.tenantId).catch(() => { });
                }
                if (absentStudent.parentEmail) {
                    sendEmailViaSes(absentStudent.parentEmail, 'Attendance Alert', msg, auth.tenantId).catch(() => { });
                }
            }
        }

        logger.info('AC attendance marked', { tenantId: auth.tenantId, batchId, date });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.AC_ATTENDANCE_MARKED,
            { batchId, date, presentCount, absentCount, leaveCount },
        ).catch(() => { });

        return response.success(item, 201);
    },
    AC_ATTENDANCE_OPTS,
);

/**
 * GET /ac/attendance/report
 */
export const getAttendanceReport = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { batchId, studentId, fromDate, toDate } = p;
    const pk = Keys.tenantPK(auth.tenantId);

    let attendance: Record<string, any>[] = [];

    if (batchId) {
        attendance = await queryAllItems<Record<string, any>>(
            Keys.acAttendanceByBatchGSI1PK(auth.tenantId, batchId),
            '',
            { indexName: 'GSI1' }
        );
    } else {
        attendance = await queryAllItems<Record<string, any>>(pk, 'AC_ATTENDANCE#');
    }

    // Filter by date range
    if (fromDate) {
        attendance = attendance.filter(a => a.date >= fromDate);
    }
    if (toDate) {
        attendance = attendance.filter(a => a.date <= toDate);
    }

    // If studentId provided, calculate individual stats
    if (studentId) {
        let present = 0;
        let absent = 0;
        let leave = 0;
        const calendar: Record<string, string> = {};

        attendance.forEach(a => {
            const status = a.records?.[studentId];
            if (status) {
                calendar[a.date] = status;
                if (status === 'P') present++;
                else if (status === 'A') absent++;
                else if (status === 'L') leave++;
            }
        });

        const total = present + absent + leave;
        return response.success({
            studentId,
            totalClasses: total,
            present,
            absent,
            leave,
            percentage: total > 0 ? Math.round((present / total) * 100) : 0,
            calendar,
        });
    }

    // Batch-wise summary
    const summary = attendance.map(a => ({
        date: a.date,
        batchId: a.batchId,
        presentCount: a.presentCount,
        absentCount: a.absentCount,
        leaveCount: a.leaveCount,
        totalCount: a.totalCount,
    }));

    return response.success(summary);
}, AC_ATTENDANCE_OPTS);

// ============================================================================
// FACULTY MANAGEMENT
// ============================================================================

/**
 * GET /ac/faculty?page=&limit=&isActive=
 */
export const listFaculty = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);

    let faculty = await queryAllItems<Record<string, any>>(pk, 'AC_FACULTY#');

    // Filter by isActive if provided
    if (p.isActive !== undefined) {
        const active = p.isActive === 'true';
        faculty = faculty.filter((f: Record<string, any>) => f.isActive === active);
    }

    // Sort by name
    faculty.sort((a: Record<string, any>, b: Record<string, any>) =>
        (a.name || '').localeCompare(b.name || '')
    );

    const total = faculty.length;
    const paged = faculty.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
}, AC_FACULTY_OPTS);

/**
 * POST /ac/faculty
 */
export const createFaculty = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            name, phone, email, specialization = [],
            qualifications = [], experience = {},
            employmentType = 'full_time', salaryStructure = {},
            joiningDate, branchIds = [],
        } = body;

        if (!name || !phone) return response.badRequest('name and phone are required');

        const id = uid();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk,
            SK: Keys.acFacultySK(id),
            id,
            name,
            phone,
            email,
            specialization,
            qualifications,
            experience,
            employmentType,
            salaryStructure: {
                type: salaryStructure.type || 'fixed',
                fixedAmountPaisa: rupeeToPaisa(salaryStructure.fixedAmount || 0),
                fixedAmount: salaryStructure.fixedAmount || 0,
                perClassRatePaisa: rupeeToPaisa(salaryStructure.perClassRate || 0),
                perClassRate: salaryStructure.perClassRate || 0,
                classesCommitted: salaryStructure.classesCommitted || 0,
            },
            joiningDate,
            branchIds,
            isActive: true,
            assignedBatchIds: [],
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('AC faculty created', { tenantId: auth.tenantId, facultyId: id });
        return response.success(item, 201);
    },
    AC_FACULTY_OPTS,
);

/**
 * GET /ac/faculty/{id}
 */
export const getFaculty = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Faculty ID required');
    const pk = Keys.tenantPK(auth.tenantId);

    const faculty = await getItem<Record<string, any>>(pk, Keys.acFacultySK(id));
    if (!faculty) return response.notFound('Faculty not found');

    return response.success(faculty);
}, AC_FACULTY_OPTS);

/**
 * PUT /ac/faculty/{id}
 */
export const updateFaculty = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Faculty ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const faculty = await getItem<Record<string, any>>(pk, Keys.acFacultySK(id));
        if (!faculty) return response.notFound('Faculty not found');

        const body = parseBody<Record<string, any>>(event);
        const exprParts: string[] = ['#updatedAt = :updatedAt'];
        const names: Record<string, string> = { '#updatedAt': 'updatedAt' };
        const values: Record<string, any> = { ':updatedAt': now() };

        if (body.name) { exprParts.push('#name = :name'); names['#name'] = 'name'; values[':name'] = body.name; }
        if (body.phone) { exprParts.push('#phone = :phone'); names['#phone'] = 'phone'; values[':phone'] = body.phone; }
        if (body.email) { exprParts.push('#email = :email'); names['#email'] = 'email'; values[':email'] = body.email; }
        if (body.specialization) { exprParts.push('#specialization = :specialization'); names['#specialization'] = 'specialization'; values[':specialization'] = body.specialization; }
        if (body.qualifications) { exprParts.push('#qualifications = :qualifications'); names['#qualifications'] = 'qualifications'; values[':qualifications'] = body.qualifications; }
        if (body.experience) { exprParts.push('#experience = :experience'); names['#experience'] = 'experience'; values[':experience'] = body.experience; }
        if (body.employmentType) { exprParts.push('#employmentType = :employmentType'); names['#employmentType'] = 'employmentType'; values[':employmentType'] = body.employmentType; }
        if (body.salaryStructure) { exprParts.push('#salaryStructure = :salaryStructure'); names['#salaryStructure'] = 'salaryStructure'; values[':salaryStructure'] = body.salaryStructure; }
        if (body.joiningDate) { exprParts.push('#joiningDate = :joiningDate'); names['#joiningDate'] = 'joiningDate'; values[':joiningDate'] = body.joiningDate; }
        if (body.branchIds) { exprParts.push('#branchIds = :branchIds'); names['#branchIds'] = 'branchIds'; values[':branchIds'] = body.branchIds; }
        if (body.isActive !== undefined) { exprParts.push('#isActive = :isActive'); names['#isActive'] = 'isActive'; values[':isActive'] = body.isActive; }
        if (body.assignedBatchIds) { exprParts.push('#assignedBatchIds = :assignedBatchIds'); names['#assignedBatchIds'] = 'assignedBatchIds'; values[':assignedBatchIds'] = body.assignedBatchIds; }

        await updateItem(pk, Keys.acFacultySK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        logger.info('AC faculty updated', { tenantId: auth.tenantId, facultyId: id });
        return response.success({ ...faculty, ...body, updatedAt: now() });
    },
    AC_FACULTY_OPTS,
);

/**
 * DELETE /ac/faculty/{id}
 */
export const deleteFaculty = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Faculty ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const faculty = await getItem<Record<string, any>>(pk, Keys.acFacultySK(id));
        if (!faculty) return response.notFound('Faculty not found');

        // Soft delete - mark as inactive
        await updateItem(pk, Keys.acFacultySK(id), {
            updateExpression: 'SET #isActive = :isActive, #updatedAt = :updatedAt',
            expressionAttributeNames: { '#isActive': 'isActive', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':isActive': false, ':updatedAt': now() },
        });

        logger.info('AC faculty soft-deleted', { tenantId: auth.tenantId, facultyId: id });
        return response.success({ message: 'Faculty deactivated successfully' });
    },
    AC_FACULTY_OPTS,
);

/**
 * POST /ac/faculty/{id}/attendance
 */
export const markFacultyAttendance = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Faculty ID required');

        const body = parseBody<Record<string, any>>(event);
        const { date, classesTaken = 0, batchIds = [] } = body;

        const pk = Keys.tenantPK(auth.tenantId);
        const recordId = `${id}#${date}`;

        const item = {
            PK: pk,
            SK: `AC_FACULTY_ATTENDANCE#${recordId}`,
            id: recordId,
            facultyId: id,
            date,
            classesTaken,
            batchIds,
            createdAt: now(),
            markedBy: auth.sub,
        };

        await putItem(item);
        return response.success(item, 201);
    },
    AC_FACULTY_OPTS,
);

/**
 * GET /ac/faculty/{id}/payroll
 */
export const getFacultyPayroll = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Faculty ID required');

        const p = event.queryStringParameters || {};
        const month = p.month || new Date().toISOString().slice(0, 7);

        const pk = Keys.tenantPK(auth.tenantId);
        const faculty = await getItem<Record<string, any>>(pk, Keys.acFacultySK(id));
        if (!faculty) return response.notFound('Faculty not found');

        // Get attendance for the month
        const [year, monthNum] = month.split('-');
        const startDate = `${month}-01`;
        const endDate = `${month}-${new Date(parseInt(year), parseInt(monthNum), 0).getDate()}`;

        const attendance = await queryAllItems<Record<string, any>>(pk, 'AC_FACULTY_ATTENDANCE#', {
            filterExpression: 'facultyId = :facultyId AND #date BETWEEN :start AND :end',
            expressionAttributeNames: { '#date': 'date' },
            expressionAttributeValues: { ':facultyId': id, ':start': startDate, ':end': endDate }
        });

        const totalClasses = attendance.reduce((sum, a) => sum + (a.classesTaken || 0), 0);

        // Calculate salary
        const salaryType = faculty.salaryStructure?.type || 'fixed';
        let grossSalaryPaisa = 0;

        if (salaryType === 'fixed') {
            grossSalaryPaisa = faculty.salaryStructure?.fixedAmountPaisa || 0;
        } else if (salaryType === 'per_class') {
            grossSalaryPaisa = totalClasses * (faculty.salaryStructure?.perClassRatePaisa || 0);
        } else if (salaryType === 'hybrid') {
            const fixed = faculty.salaryStructure?.fixedAmountPaisa || 0;
            const variable = totalClasses * (faculty.salaryStructure?.perClassRatePaisa || 0);
            grossSalaryPaisa = fixed + variable;
        }

        // Calculate deductions (10% TDS as example)
        const tdsPaisa = Math.round(grossSalaryPaisa * 0.1);
        const netSalaryPaisa = grossSalaryPaisa - tdsPaisa;

        return response.success({
            facultyId: id,
            facultyName: faculty.name,
            month,
            totalClasses,
            classesMissed: (faculty.salaryStructure?.classesCommitted || 0) - totalClasses,
            salaryStructure: faculty.salaryStructure,
            grossSalary: paisaToRupee(grossSalaryPaisa),
            grossSalaryPaisa,
            tds: paisaToRupee(tdsPaisa),
            tdsPaisa,
            netSalary: paisaToRupee(netSalaryPaisa),
            netSalaryPaisa,
            calculationBreakdown: {
                baseSalary: paisaToRupee(faculty.salaryStructure?.fixedAmountPaisa || 0),
                variableComponent: paisaToRupee(grossSalaryPaisa - (faculty.salaryStructure?.fixedAmountPaisa || 0)),
            },
        });
    },
    AC_FACULTY_OPTS,
);

// ============================================================================
// EXAM & RESULT MANAGEMENT
// ============================================================================

/**
 * GET /ac/exams?page=&limit=&status=&batchId=
 */
export const listExams = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);

    let exams = await queryAllItems<Record<string, any>>(pk, 'AC_EXAM#');

    // Filter by status if provided
    if (p.status) {
        exams = exams.filter((e: Record<string, any>) => e.status === p.status);
    }

    // Filter by batchId if provided
    if (p.batchId) {
        exams = exams.filter((e: Record<string, any>) =>
            e.batchIds?.includes(p.batchId)
        );
    }

    // Sort by date desc
    exams.sort((a: Record<string, any>, b: Record<string, any>) =>
        (b.date || '').localeCompare(a.date || '')
    );

    const total = exams.length;
    const paged = exams.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
}, AC_EXAM_OPTS);

/**
 * POST /ac/exams
 */
export const createExam = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            name, type = 'internal', batchIds = [],
            date, duration, venue, subjects = [],
            syllabusS3Key,
        } = body;

        if (!name || !date) return response.badRequest('name and date are required');

        const id = uid();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk,
            SK: Keys.acExamSK(id),
            id,
            name,
            type,
            batchIds,
            date,
            duration,
            venue,
            subjects: subjects.map((s: any) => ({
                ...s,
                maxMarks: s.maxMarks || 100,
                passingMarks: s.passingMarks || 35,
            })),
            syllabusS3Key,
            status: 'scheduled',
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('AC exam created', { tenantId: auth.tenantId, examId: id });
        return response.success(item, 201);
    },
    AC_EXAM_OPTS,
);

/**
 * GET /ac/exams/{id}
 */
export const getExam = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Exam ID required');
    const pk = Keys.tenantPK(auth.tenantId);

    const exam = await getItem<Record<string, any>>(pk, Keys.acExamSK(id));
    if (!exam) return response.notFound('Exam not found');

    return response.success(exam);
}, AC_EXAM_OPTS);

/**
 * PUT /ac/exams/{id}
 */
export const updateExam = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Exam ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const exam = await getItem<Record<string, any>>(pk, Keys.acExamSK(id));
        if (!exam) return response.notFound('Exam not found');

        // Cannot update if already completed
        if (exam.status === 'completed') {
            return response.conflict('Cannot update completed exam');
        }

        const body = parseBody<Record<string, any>>(event);
        const exprParts: string[] = ['#updatedAt = :updatedAt'];
        const names: Record<string, string> = { '#updatedAt': 'updatedAt' };
        const values: Record<string, any> = { ':updatedAt': now() };

        if (body.name) { exprParts.push('#name = :name'); names['#name'] = 'name'; values[':name'] = body.name; }
        if (body.type) { exprParts.push('#type = :type'); names['#type'] = 'type'; values[':type'] = body.type; }
        if (body.batchIds) { exprParts.push('#batchIds = :batchIds'); names['#batchIds'] = 'batchIds'; values[':batchIds'] = body.batchIds; }
        if (body.date) { exprParts.push('#date = :date'); names['#date'] = 'date'; values[':date'] = body.date; }
        if (body.duration) { exprParts.push('#duration = :duration'); names['#duration'] = 'duration'; values[':duration'] = body.duration; }
        if (body.venue) { exprParts.push('#venue = :venue'); names['#venue'] = 'venue'; values[':venue'] = body.venue; }
        if (body.subjects) { exprParts.push('#subjects = :subjects'); names['#subjects'] = 'subjects'; values[':subjects'] = body.subjects; }
        if (body.syllabusS3Key) { exprParts.push('#syllabusS3Key = :syllabusS3Key'); names['#syllabusS3Key'] = 'syllabusS3Key'; values[':syllabusS3Key'] = body.syllabusS3Key; }
        if (body.status) { exprParts.push('#status = :status'); names['#status'] = 'status'; values[':status'] = body.status; }

        await updateItem(pk, Keys.acExamSK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        logger.info('AC exam updated', { tenantId: auth.tenantId, examId: id });
        return response.success({ ...exam, ...body, updatedAt: now() });
    },
    AC_EXAM_OPTS,
);

/**
 * DELETE /ac/exams/{id}
 */
export const deleteExam = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Exam ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const exam = await getItem<Record<string, any>>(pk, Keys.acExamSK(id));
        if (!exam) return response.notFound('Exam not found');

        // Cannot delete if results uploaded
        if (exam.status === 'completed') {
            return response.conflict('Cannot delete exam with uploaded results');
        }

        await deleteItem(pk, Keys.acExamSK(id));
        logger.info('AC exam deleted', { tenantId: auth.tenantId, examId: id });
        return response.success({ message: 'Exam deleted successfully' });
    },
    AC_EXAM_OPTS,
);

/**
 * POST /ac/results
 */
export const uploadResults = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { examId, results = [] } = body;

        if (!examId || !results.length) {
            return response.badRequest('examId and results are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const exam = await getItem<Record<string, any>>(pk, Keys.acExamSK(examId));
        if (!exam) return response.notFound('Exam not found');

        const processedResults = [];

        for (const result of results) {
            const { studentId, subjectMarks = [], remarks } = result;

            // Calculate totals
            let totalObtained = 0;
            let totalMax = 0;
            const subjectResults = subjectMarks.map((sm: any) => {
                totalObtained += sm.marksObtained || 0;
                totalMax += sm.maxMarks || 100;
                return {
                    subjectId: sm.subjectId,
                    subjectName: sm.subjectName,
                    marksObtained: sm.marksObtained || 0,
                    maxMarks: sm.maxMarks || 100,
                    isAbsent: sm.isAbsent || false,
                };
            });

            const percentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;
            const grade = percentage >= 90 ? 'A+' :
                percentage >= 80 ? 'A' :
                    percentage >= 70 ? 'B+' :
                        percentage >= 60 ? 'B' :
                            percentage >= 50 ? 'C' :
                                percentage >= 35 ? 'D' : 'F';

            const resultId = uid();
            const item = {
                PK: pk,
                SK: Keys.acResultSK(resultId),
                GSI1PK: Keys.acResultByExamGSI1PK(auth.tenantId, examId),
                GSI1SK: `STUDENT#${studentId}`,
                id: resultId,
                examId,
                studentId,
                subjectResults,
                totalObtained,
                totalMax,
                percentage: Math.round(percentage * 100) / 100,
                grade,
                remarks,
                status: percentage >= 35 ? 'pass' : 'fail',
                createdAt: now(),
                updatedAt: now(),
                uploadedBy: auth.sub,
            };

            await putItem(item);
            processedResults.push(item);
        }

        // Update exam status
        await updateItem(pk, Keys.acExamSK(examId), {
            updateExpression: 'SET #status = :status, #resultsUploadedAt = :uploadedAt, #updatedAt = :updatedAt',
            expressionAttributeNames: { '#status': 'status', '#resultsUploadedAt': 'resultsUploadedAt', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':status': 'completed', ':uploadedAt': now(), ':updatedAt': now() },
        });

        logger.info('AC results uploaded', { tenantId: auth.tenantId, examId, count: results.length });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.AC_RESULTS_PUBLISHED,
            { examId, examName: exam.name, count: results.length },
        ).catch(() => { });

        return response.success({ examId, results: processedResults }, 201);
    },
    AC_EXAM_OPTS,
);

/**
 * GET /ac/exams/{id}/results
 */
export const getExamResults = authorizedHandler([], async (event, _ctx, auth) => {
    const examId = event.pathParameters?.id;
    if (!examId) return response.badRequest('Exam ID required');

    const results = await queryAllItems<Record<string, any>>(
        Keys.acResultByExamGSI1PK(auth.tenantId, examId),
        '',
        { indexName: 'GSI1' }
    );

    // Calculate statistics
    const totalStudents = results.length;
    const passCount = results.filter(r => r.status === 'pass').length;
    const failCount = totalStudents - passCount;
    const avgPercentage = totalStudents > 0
        ? results.reduce((sum, r) => sum + (r.percentage || 0), 0) / totalStudents
        : 0;

    return response.success({
        examId,
        totalStudents,
        passCount,
        failCount,
        passPercentage: totalStudents > 0 ? Math.round((passCount / totalStudents) * 100) : 0,
        averagePercentage: Math.round(avgPercentage * 100) / 100,
        results: results.sort((a, b) => (b.percentage || 0) - (a.percentage || 0)),
    });
}, AC_EXAM_OPTS);

// ============================================================================
// TIMETABLE MANAGEMENT
// ============================================================================

/**
 * GET /ac/timetable?batchId=&facultyId=&weekOf=
 */
export const getTimetable = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let slots: Record<string, any>[] = [];

    if (p.batchId) {
        slots = await queryAllItems<Record<string, any>>(
            Keys.acTimetableByBatchGSI1PK(auth.tenantId, p.batchId),
            '',
            { indexName: 'GSI1' }
        );
    } else if (p.facultyId) {
        // Use faculty GSI for efficient query instead of full scan
        slots = await queryAllItems<Record<string, any>>(
            Keys.acTimetableByFacultyGSI2PK(auth.tenantId, p.facultyId),
            '',
            { indexName: 'GSI2' }
        ).catch(() => []);
        // Fallback to filter if GSI2 not available
        if (!slots.length) {
            slots = await queryAllItems<Record<string, any>>(pk, 'AC_TIMETABLE#', {
                filterExpression: 'facultyId = :facultyId',
                expressionAttributeValues: { ':facultyId': p.facultyId },
            });
        }
    } else {
        slots = await queryAllItems<Record<string, any>>(pk, 'AC_TIMETABLE#');
    }

    // Filter by week if provided
    if (p.weekOf) {
        const weekStart = new Date(p.weekOf);
        const weekEnd = new Date(weekStart);
        weekEnd.setDate(weekEnd.getDate() + 7);

        slots = slots.filter((s: Record<string, any>) => {
            const slotDate = new Date(s.date || s.startTime);
            return slotDate >= weekStart && slotDate < weekEnd;
        });
    }

    // Enrich with batch names
    const batchIds = [...new Set(slots.map((s: Record<string, any>) => s.batchId).filter(Boolean))];
    if (batchIds.length > 0) {
        const batchKeys = batchIds.map(id => ({ PK: pk, SK: Keys.acBatchSK(id) }));
        const { batchGetItems } = await import('../config/dynamodb.config');
        const batches = await batchGetItems(batchKeys);
        const batchMap = new Map(batches.map((b: any) => [b.id, b.name]));
        slots.forEach((s: Record<string, any>) => {
            s.batchName = batchMap.get(s.batchId) || 'Unknown';
        });
    }

    return response.success(slots);
}, AC_TIMETABLE_OPTS);

/**
 * POST /ac/timetable/slots
 */
export const createTimetableSlot = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            batchId, subjectId, facultyId,
            dayOfWeek, startTime, endTime, roomNo, date,
        } = body;

        if (!batchId || !subjectId || !startTime || !endTime) {
            return response.badRequest('batchId, subjectId, startTime, endTime are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const id = uid();

        // Check for faculty conflicts
        if (facultyId) {
            const existingSlots = await queryAllItems<Record<string, any>>(pk, 'AC_TIMETABLE#', {
                filterExpression: 'facultyId = :facultyId AND #date = :date AND ((startTime <= :end AND endTime >= :start))',
                expressionAttributeNames: { '#date': 'date' },
                expressionAttributeValues: {
                    ':facultyId': facultyId,
                    ':date': date,
                    ':start': startTime,
                    ':end': endTime,
                }
            });

            if (existingSlots.length > 0) {
                return response.conflict('Faculty has conflicting schedule at this time');
            }
        }

        // Check for room conflicts
        if (roomNo) {
            const roomConflicts = await queryAllItems<Record<string, any>>(pk, 'AC_TIMETABLE#', {
                filterExpression: 'roomNo = :roomNo AND #date = :date AND ((startTime <= :end AND endTime >= :start))',
                expressionAttributeNames: { '#date': 'date' },
                expressionAttributeValues: {
                    ':roomNo': roomNo,
                    ':date': date,
                    ':start': startTime,
                    ':end': endTime,
                }
            });

            if (roomConflicts.length > 0) {
                return response.conflict('Room is already booked at this time');
            }
        }

        const item: Record<string, any> = {
            PK: pk,
            SK: Keys.acTimetableSlotSK(id),
            GSI1PK: Keys.acTimetableByBatchGSI1PK(auth.tenantId, batchId),
            GSI1SK: `${dayOfWeek || 1}#${startTime}`,
            id,
            batchId,
            subjectId,
            facultyId,
            dayOfWeek: dayOfWeek || 1,
            startTime,
            endTime,
            roomNo,
            date,
            isActive: true,
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };
        // Index by faculty for efficient teacher timetable queries
        if (facultyId) {
            item.GSI2PK = Keys.acTimetableByFacultyGSI2PK(auth.tenantId, facultyId);
            item.GSI2SK = `${date || dayOfWeek || 1}#${startTime}`;
        }

        await putItem(item);

        // Notify affected faculty
        if (facultyId) {
            wsService.broadcastToClientType(
                auth.tenantId,
                ClientType.DESKTOP_APP,
                WSEventName.AC_TIMETABLE_UPDATED,
                { facultyId, batchId, slotId: id, action: 'created' },
            ).catch(() => { });
        }

        return response.success(item, 201);
    },
    AC_TIMETABLE_OPTS,
);

// ============================================================================
// STUDY MATERIAL MANAGEMENT
// ============================================================================

/**
 * GET /ac/materials
 */
export const listMaterials = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let materials = await queryAllItems<Record<string, any>>(pk, 'AC_MATERIAL#');

    if (p.subjectId) {
        materials = materials.filter(m => m.subjectId === p.subjectId);
    }
    if (p.batchId) {
        materials = materials.filter(m => (m.batchIds || []).includes(p.batchId));
    }
    if (p.type) {
        materials = materials.filter(m => m.type === p.type);
    }

    return response.success(materials);
}, AC_MATERIAL_OPTS);

/**
 * POST /ac/materials
 */
export const createMaterial = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            title, subjectId, batchIds = [], courseIds = [],
            type = 'notes', s3Key, fileSize, fileType,
            isFree = false, materialFee = 0,
            publishedAt, expiresAt,
        } = body;

        if (!title || !subjectId) {
            return response.badRequest('title and subjectId are required');
        }

        const id = uid();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk,
            SK: Keys.acMaterialSK(id),
            id,
            title,
            subjectId,
            batchIds,
            courseIds,
            type,
            s3Key,
            fileSize,
            fileType,
            isFree,
            materialFeePaisa: rupeeToPaisa(materialFee),
            materialFee,
            publishedAt: publishedAt || now(),
            expiresAt,
            downloadCount: 0,
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('AC material created', { tenantId: auth.tenantId, materialId: id });
        return response.success(item, 201);
    },
    AC_MATERIAL_OPTS,
);

/**
 * GET /ac/materials/{id}
 */
export const getMaterial = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Material ID required');
    const pk = Keys.tenantPK(auth.tenantId);

    const material = await getItem<Record<string, any>>(pk, Keys.acMaterialSK(id));
    if (!material) return response.notFound('Material not found');

    return response.success(material);
}, AC_MATERIAL_OPTS);

/**
 * PUT /ac/materials/{id}
 */
export const updateMaterial = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Material ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const material = await getItem<Record<string, any>>(pk, Keys.acMaterialSK(id));
        if (!material) return response.notFound('Material not found');

        const body = parseBody<Record<string, any>>(event);
        const exprParts: string[] = ['#updatedAt = :updatedAt'];
        const names: Record<string, string> = { '#updatedAt': 'updatedAt' };
        const values: Record<string, any> = { ':updatedAt': now() };

        if (body.title) { exprParts.push('#title = :title'); names['#title'] = 'title'; values[':title'] = body.title; }
        if (body.subjectId) { exprParts.push('#subjectId = :subjectId'); names['#subjectId'] = 'subjectId'; values[':subjectId'] = body.subjectId; }
        if (body.batchIds) { exprParts.push('#batchIds = :batchIds'); names['#batchIds'] = 'batchIds'; values[':batchIds'] = body.batchIds; }
        if (body.courseIds) { exprParts.push('#courseIds = :courseIds'); names['#courseIds'] = 'courseIds'; values[':courseIds'] = body.courseIds; }
        if (body.type) { exprParts.push('#type = :type'); names['#type'] = 'type'; values[':type'] = body.type; }
        if (body.s3Key) { exprParts.push('#s3Key = :s3Key'); names['#s3Key'] = 's3Key'; values[':s3Key'] = body.s3Key; }
        if (body.fileSize) { exprParts.push('#fileSize = :fileSize'); names['#fileSize'] = 'fileSize'; values[':fileSize'] = body.fileSize; }
        if (body.fileType) { exprParts.push('#fileType = :fileType'); names['#fileType'] = 'fileType'; values[':fileType'] = body.fileType; }
        if (body.isFree !== undefined) { exprParts.push('#isFree = :isFree'); names['#isFree'] = 'isFree'; values[':isFree'] = body.isFree; }
        if (body.materialFee !== undefined) {
            exprParts.push('#materialFee = :materialFee', '#materialFeePaisa = :materialFeePaisa');
            names['#materialFee'] = 'materialFee'; names['#materialFeePaisa'] = 'materialFeePaisa';
            values[':materialFee'] = body.materialFee; values[':materialFeePaisa'] = rupeeToPaisa(body.materialFee);
        }
        if (body.publishedAt) { exprParts.push('#publishedAt = :publishedAt'); names['#publishedAt'] = 'publishedAt'; values[':publishedAt'] = body.publishedAt; }
        if (body.expiresAt) { exprParts.push('#expiresAt = :expiresAt'); names['#expiresAt'] = 'expiresAt'; values[':expiresAt'] = body.expiresAt; }

        await updateItem(pk, Keys.acMaterialSK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        logger.info('AC material updated', { tenantId: auth.tenantId, materialId: id });
        return response.success({ ...material, ...body, updatedAt: now() });
    },
    AC_MATERIAL_OPTS,
);

/**
 * DELETE /ac/materials/{id}
 */
export const deleteMaterial = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Material ID required');
        const pk = Keys.tenantPK(auth.tenantId);

        const material = await getItem<Record<string, any>>(pk, Keys.acMaterialSK(id));
        if (!material) return response.notFound('Material not found');

        await deleteItem(pk, Keys.acMaterialSK(id));
        logger.info('AC material deleted', { tenantId: auth.tenantId, materialId: id });
        return response.success({ message: 'Material deleted successfully' });
    },
    AC_MATERIAL_OPTS,
);

/**
 * GET /ac/materials/{id}/download
 */
export const getMaterialDownloadUrl = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Material ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const material = await getItem<Record<string, any>>(pk, Keys.acMaterialSK(id));
    if (!material) return response.notFound('Material not found');

    // Check access (if not free, student must have paid)
    // TODO: Verify student enrollment and fee payment status

    // Increment download count
    await updateItem(pk, Keys.acMaterialSK(id), {
        updateExpression: 'SET #downloadCount = if_not_exists(#downloadCount, :zero) + :one, #updatedAt = :updatedAt',
        expressionAttributeNames: { '#downloadCount': 'downloadCount', '#updatedAt': 'updatedAt' },
        expressionAttributeValues: { ':zero': 0, ':one': 1, ':updatedAt': now() },
    });

    // Generate presigned URL (placeholder - actual implementation would use S3)
    return response.success({
        materialId: id,
        title: material.title,
        downloadUrl: material.s3Key ? `https://s3.presigned.url/${material.s3Key}` : null,
        expiresIn: 900, // 15 minutes
    });
}, AC_MATERIAL_OPTS);

// ============================================================================
// DASHBOARD & ANALYTICS
// ============================================================================

/**
 * GET /ac/dashboard
 */
export const getDashboard = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { fromDate, toDate, branchId } = p;

    const pk = Keys.tenantPK(auth.tenantId);
    const today = new Date().toISOString().split('T')[0];
    const currentMonth = today.slice(0, 7);

    // Parallel queries for performance
    const [
        students,
        batches,
        courses,
        faculty,
        invoices,
        todayAttendance,
    ] = await Promise.all([
        queryAllItems<Record<string, any>>(pk, 'AC_STUDENT#'),
        queryAllItems<Record<string, any>>(pk, 'AC_BATCH#'),
        queryAllItems<Record<string, any>>(pk, 'AC_COURSE#'),
        queryAllItems<Record<string, any>>(pk, 'AC_FACULTY#'),
        queryAllItems<Record<string, any>>(pk, 'AC_INVOICE#'),
        queryAllItems<Record<string, any>>(pk, 'AC_ATTENDANCE#', {
            filterExpression: '#date = :today',
            expressionAttributeNames: { '#date': 'date' },
            expressionAttributeValues: { ':today': today }
        }),
    ]);

    // Calculate metrics
    const totalStudents = students.length;
    const activeStudents = students.filter(s => s.status === 'active').length;
    const newStudentsThisMonth = students.filter(s =>
        s.createdAt?.startsWith(currentMonth)
    ).length;

    const totalBatches = batches.length;
    const activeBatches = batches.filter(b => b.status === 'active').length;
    const upcomingBatches = batches.filter(b => b.status === 'upcoming').length;

    // Revenue calculations
    const totalRevenuePaisa = invoices.reduce((sum, inv) =>
        sum + (inv.totalAmountPaisa || 0), 0);
    const collectedRevenuePaisa = invoices.reduce((sum, inv) =>
        sum + (inv.paidAmountPaisa || 0), 0);
    const pendingRevenuePaisa = totalRevenuePaisa - collectedRevenuePaisa;

    const monthInvoices = invoices.filter(i => i.createdAt?.startsWith(currentMonth));
    const monthlyRevenuePaisa = monthInvoices.reduce((sum, inv) =>
        sum + (inv.paidAmountPaisa || 0), 0);

    // Overdue fees
    const overdueInvoices = invoices.filter(i =>
        i.status === 'pending' && i.dueDate < today
    );
    const overdueAmountPaisa = overdueInvoices.reduce((sum, i) =>
        sum + (i.balancePaisa || 0), 0);

    // Attendance
    const todayTotalPresent = todayAttendance.reduce((sum, a) => sum + (a.presentCount || 0), 0);
    const todayTotalAbsent = todayAttendance.reduce((sum, a) => sum + (a.absentCount || 0), 0);

    return response.success({
        students: {
            total: totalStudents,
            active: activeStudents,
            newThisMonth: newStudentsThisMonth,
            inactive: totalStudents - activeStudents,
        },
        batches: {
            total: totalBatches,
            active: activeBatches,
            upcoming: upcomingBatches,
            completed: batches.filter(b => b.status === 'completed').length,
        },
        courses: courses.length,
        faculty: faculty.filter(f => f.isActive).length,
        revenue: {
            total: paisaToRupee(totalRevenuePaisa),
            totalPaisa: totalRevenuePaisa,
            collected: paisaToRupee(collectedRevenuePaisa),
            collectedPaisa: collectedRevenuePaisa,
            pending: paisaToRupee(pendingRevenuePaisa),
            pendingPaisa: pendingRevenuePaisa,
            monthly: paisaToRupee(monthlyRevenuePaisa),
            monthlyPaisa: monthlyRevenuePaisa,
        },
        overdue: {
            count: overdueInvoices.length,
            amount: paisaToRupee(overdueAmountPaisa),
            amountPaisa: overdueAmountPaisa,
        },
        todayAttendance: {
            present: todayTotalPresent,
            absent: todayTotalAbsent,
            total: todayTotalPresent + todayTotalAbsent,
            percentage: (todayTotalPresent + todayTotalAbsent) > 0
                ? Math.round((todayTotalPresent / (todayTotalPresent + todayTotalAbsent)) * 100)
                : 0,
        },
        recentActivity: {
            newStudents: newStudentsThisMonth,
            upcomingExams: 0, // TODO: Query exams
            pendingFeeReminders: overdueInvoices.length,
        },
    });
}, AC_REPORTS_OPTS);

/**
 * GET /ac/students/birthdays?days=7
 * Get upcoming student birthdays for reminders
 */
export const getUpcomingBirthdays = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const daysAhead = Math.min(parseInt(p.days || '7', 10), 30); // Max 30 days

    const pk = Keys.tenantPK(auth.tenantId);
    const students = await queryAllItems<Record<string, any>>(pk, 'AC_STUDENT#');

    const today = new Date();
    const upcomingBirthdays = [];

    for (const student of students) {
        if (!student.dateOfBirth) continue;

        const dob = new Date(student.dateOfBirth);
        if (isNaN(dob.getTime())) continue;

        // Create birthday date for this year
        const thisYearBday = new Date(today.getFullYear(), dob.getMonth(), dob.getDate());

        // If birthday has passed this year, check next year
        if (thisYearBday < today) {
            thisYearBday.setFullYear(today.getFullYear() + 1);
        }

        const daysUntil = Math.ceil((thisYearBday.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

        if (daysUntil <= daysAhead) {
            upcomingBirthdays.push({
                studentId: student.id,
                studentCode: student.studentId,
                name: `${student.firstName} ${student.lastName}`.trim(),
                phone: student.phone,
                parentPhone: student.parentPhone,
                dateOfBirth: student.dateOfBirth,
                ageTurning: thisYearBday.getFullYear() - dob.getFullYear(),
                daysUntil,
                isToday: daysUntil === 0,
                isTomorrow: daysUntil === 1,
                batchNames: student.batchNames || [],
            });
        }
    }

    // Sort by days until (ascending)
    upcomingBirthdays.sort((a, b) => a.daysUntil - b.daysUntil);

    return response.success({
        today: upcomingBirthdays.filter(b => b.isToday),
        tomorrow: upcomingBirthdays.filter(b => b.isTomorrow),
        thisWeek: upcomingBirthdays.filter(b => b.daysUntil > 1 && b.daysUntil <= 7),
        upcoming: upcomingBirthdays.filter(b => b.daysUntil > 7),
        total: upcomingBirthdays.length,
    });
}, AC_OPTS);

/**
 * GET /ac/reports/summary
 */
export const getReportsSummary = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _ctx, auth) => {
        const p = event.queryStringParameters || {};
        const reportType = p.type || 'overview';

        const pk = Keys.tenantPK(auth.tenantId);

        switch (reportType) {
            case 'fee_collection': {
                const invoices = await queryAllItems<Record<string, any>>(pk, 'AC_INVOICE#');
                const byMonth: Record<string, { collected: number; pending: number }> = {};

                invoices.forEach(inv => {
                    const month = inv.createdAt?.slice(0, 7) || 'unknown';
                    if (!byMonth[month]) {
                        byMonth[month] = { collected: 0, pending: 0 };
                    }
                    byMonth[month].collected += inv.paidAmountPaisa || 0;
                    byMonth[month].pending += inv.balancePaisa || 0;
                });

                return response.success({
                    type: 'fee_collection',
                    byMonth: Object.entries(byMonth).map(([month, data]) => ({
                        month,
                        collected: paisaToRupee(data.collected),
                        pending: paisaToRupee(data.pending),
                    })).sort((a, b) => b.month.localeCompare(a.month)),
                });
            }

            case 'attendance': {
                const attendance = await queryAllItems<Record<string, any>>(pk, 'AC_ATTENDANCE#');
                const byBatch: Record<string, { total: number; present: number }> = {};

                attendance.forEach(a => {
                    if (!byBatch[a.batchId]) {
                        byBatch[a.batchId] = { total: 0, present: 0 };
                    }
                    byBatch[a.batchId].total += a.totalCount || 0;
                    byBatch[a.batchId].present += a.presentCount || 0;
                });

                return response.success({
                    type: 'attendance',
                    byBatch: Object.entries(byBatch).map(([batchId, data]) => ({
                        batchId,
                        averageAttendance: data.total > 0
                            ? Math.round((data.present / data.total) * 100)
                            : 0,
                    })),
                });
            }

            case 'enrollment': {
                const students = await queryAllItems<Record<string, any>>(pk, 'AC_STUDENT#');
                const byMonth: Record<string, number> = {};

                students.forEach(s => {
                    const month = s.createdAt?.slice(0, 7) || 'unknown';
                    byMonth[month] = (byMonth[month] || 0) + 1;
                });

                return response.success({
                    type: 'enrollment',
                    byMonth: Object.entries(byMonth)
                        .map(([month, count]) => ({ month, count }))
                        .sort((a, b) => b.month.localeCompare(a.month)),
                });
            }

            default:
                return response.success({ type: 'overview', message: 'Use /ac/dashboard for overview' });
        }
    },
    AC_REPORTS_OPTS,
);

// ============================================================================
// AI RISK DETECTION & STUDENT ANALYTICS
// ============================================================================

const AC_ANALYTICS_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_REPORTS_ANALYTICS,
};

/**
 * GET /ac/analytics/at-risk-students
 */
export const getAtRiskStudents = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (_event, _ctx, auth) => {
        const pk = Keys.tenantPK(auth.tenantId);

        // Get all students
        const students = await queryAllItems<Record<string, any>>(pk, 'AC_STUDENT#');
        const activeStudents = students.filter(s => s.status === 'active');

        // Get attendance data for last 30 days
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const cutoffDate = thirtyDaysAgo.toISOString().split('T')[0];

        const attendance = await queryAllItems<Record<string, any>>(pk, 'AC_ATTENDANCE#', {
            filterExpression: '#date >= :cutoff',
            expressionAttributeNames: { '#date': 'date' },
            expressionAttributeValues: { ':cutoff': cutoffDate }
        });

        // Get fee data
        const invoices = await queryAllItems<Record<string, any>>(pk, 'AC_INVOICE#');
        const today = new Date().toISOString().split('T')[0];

        const atRiskStudents = [];

        for (const student of activeStudents) {
            const studentId = student.id;
            let riskScore = 0;
            const riskFactors = [];

            // Calculate attendance rate
            let totalClasses = 0;
            let presentCount = 0;

            for (const att of attendance) {
                if (att.records && att.records[studentId]) {
                    totalClasses++;
                    if (att.records[studentId] === 'P') {
                        presentCount++;
                    }
                }
            }

            const attendanceRate = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 100;

            if (attendanceRate < 60) {
                riskScore += 40;
                riskFactors.push(`Attendance critically low (${attendanceRate.toFixed(1)}%)`);
            } else if (attendanceRate < 75) {
                riskScore += 25;
                riskFactors.push(`Attendance below threshold (${attendanceRate.toFixed(1)}%)`);
            }

            // Check overdue fees
            const studentInvoices = invoices.filter(i => i.studentId === studentId && i.status !== 'paid');
            const overdueInvoices = studentInvoices.filter(i => i.dueDate < today);
            const totalDue = studentInvoices.reduce((sum, i) => sum + (i.balancePaisa || 0), 0);
            const totalOverdue = overdueInvoices.reduce((sum, i) => sum + (i.balancePaisa || 0), 0);

            if (totalOverdue > 0) {
                riskScore += 30;
                riskFactors.push(`Overdue fees: ₹${paisaToRupee(totalOverdue).toFixed(0)}`);
            } else if (totalDue > 0) {
                riskScore += 15;
                riskFactors.push(`Pending fees: ₹${paisaToRupee(totalDue).toFixed(0)}`);
            }

            // Check for recent exam failures (if results exist)
            const results = await queryAllItems<Record<string, any>>(pk, 'AC_RESULT#', {
                filterExpression: 'studentId = :studentId',
                expressionAttributeValues: { ':studentId': studentId }
            });

            const recentFailures = results.filter(r => r.status === 'fail').length;
            if (recentFailures > 0) {
                riskScore += 20 * recentFailures;
                riskFactors.push(`${recentFailures} recent exam failure(s)`);
            }

            // Categorize risk level
            let riskLevel = 'low';
            if (riskScore >= 60) riskLevel = 'critical';
            else if (riskScore >= 40) riskLevel = 'high';
            else if (riskScore >= 20) riskLevel = 'medium';

            if (riskScore > 0) {
                atRiskStudents.push({
                    studentId,
                    studentName: `${student.firstName} ${student.lastName}`,
                    studentCode: student.studentId,
                    phone: student.phone,
                    parentPhone: student.parentPhone,
                    riskScore,
                    riskLevel,
                    riskFactors,
                    attendanceRate: Math.round(attendanceRate * 100) / 100,
                    totalDuePaisa: totalDue,
                    totalDue: paisaToRupee(totalDue),
                    lastUpdated: now(),
                });
            }
        }

        // Sort by risk score descending
        atRiskStudents.sort((a, b) => b.riskScore - a.riskScore);

        // Summary statistics
        const summary = {
            totalAtRisk: atRiskStudents.length,
            critical: atRiskStudents.filter(s => s.riskLevel === 'critical').length,
            high: atRiskStudents.filter(s => s.riskLevel === 'high').length,
            medium: atRiskStudents.filter(s => s.riskLevel === 'medium').length,
            low: atRiskStudents.filter(s => s.riskLevel === 'low').length,
        };

        return response.success({
            summary,
            students: atRiskStudents,
            generatedAt: now(),
        });
    },
    AC_ANALYTICS_OPTS,
);

// ============================================================================
// NOTIFICATION SYSTEM
// ============================================================================

const AC_NOTIFICATION_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_NOTIFICATIONS,
};

interface NotificationTemplate {
    id: string;
    name: string;
    type: 'fee_reminder' | 'attendance_alert' | 'exam_notice' | 'result_published' | 'custom';
    channels: ('sms' | 'email' | 'whatsapp')[];
    subjectTemplate?: string;
    bodyTemplate: string;
    schedule?: 'immediate' | 'scheduled';
    triggerEvent?: string;
    isActive: boolean;
}

/**
 * GET /ac/notifications/templates
 */
export const listNotificationTemplates = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const templates = await queryAllItems<NotificationTemplate>(pk, 'AC_NOTIFICATION_TEMPLATE#');
    return response.success(templates);
}, AC_NOTIFICATION_OPTS);

/**
 * POST /ac/notifications/send
 */
export const sendNotification = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { templateId, recipients, variables, channels = ['sms'], scheduledAt } = body;

        if (!templateId || !recipients || recipients.length === 0) {
            return response.badRequest('templateId and recipients are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const notificationId = uid();

        // Get template
        const template = await getItem<NotificationTemplate>(pk, `AC_NOTIFICATION_TEMPLATE#${templateId}`);
        if (!template) return response.notFound('Notification template not found');

        // Process each recipient
        const sentNotifications = [];
        for (const recipient of recipients) {
            const { studentId, phone, email } = recipient;

            // Get student data for personalization
            const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(studentId));
            if (!student) continue;

            // Replace template variables
            let message = template.bodyTemplate
                .replace(/\{\{studentName\}\}/g, `${student.firstName} ${student.lastName}`)
                .replace(/\{\{studentId\}\}/g, student.studentId)
                .replace(/\{\{balance\}\}/g, variables?.balance || '0')
                .replace(/\{\{dueDate\}\}/g, variables?.dueDate || '');

            const notification = {
                PK: pk,
                SK: `AC_NOTIFICATION#${notificationId}#${studentId}`,
                id: `${notificationId}-${studentId}`,
                notificationId,
                templateId,
                studentId,
                phone,
                email,
                message,
                channels,
                status: scheduledAt ? 'scheduled' : 'pending',
                scheduledAt,
                sentAt: null,
                deliveredAt: null,
                error: null,
                createdAt: now(),
                createdBy: auth.sub,
            };

            await putItem(notification);
            sentNotifications.push(notification);

            // Dispatch immediately if not scheduled
            if (!scheduledAt) {
                const deliveryPromises: Promise<void>[] = [];
                if (channels.includes('sms') && notification.phone) {
                    deliveryPromises.push(sendSmsViaSns(notification.phone, message, auth.tenantId));
                }
                if (channels.includes('email') && notification.email) {
                    const subj = template.subjectTemplate
                        ? template.subjectTemplate.replace(/\{\{studentName\}\}/g, `${student.firstName} ${student.lastName}`)
                        : 'Notification from your Institute';
                    deliveryPromises.push(sendEmailViaSes(notification.email, subj, message, auth.tenantId));
                }
                if (channels.includes('whatsapp') && notification.phone) {
                    deliveryPromises.push(sendWhatsApp(notification.phone, message, auth.tenantId));
                }
                await Promise.allSettled(deliveryPromises);
                // Update status to sent
                await updateItem(pk, notification.SK as string || `AC_NOTIFICATION#${notificationId}#${studentId}`, {
                    updateExpression: 'SET #status = :s, #sentAt = :t',
                    expressionAttributeNames: { '#status': 'status', '#sentAt': 'sentAt' },
                    expressionAttributeValues: { ':s': 'sent', ':t': now() },
                }).catch(() => { });
            }
        }

        return response.success({
            notificationId,
            totalRecipients: recipients.length,
            notifications: sentNotifications,
            status: scheduledAt ? 'scheduled' : 'queued',
        }, 201);
    },
    AC_NOTIFICATION_OPTS,
);

/**
 * POST /ac/notifications/fee-reminders
 */
export const sendFeeReminders = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (_event, _ctx, auth) => {
        const pk = Keys.tenantPK(auth.tenantId);
        const today = new Date().toISOString().split('T')[0];

        // Find students with overdue or upcoming fees
        const invoices = await queryAllItems<Record<string, any>>(pk, 'AC_INVOICE#');
        const pendingInvoices = invoices.filter(i => i.status !== 'paid');

        // Group by student
        const byStudent = new Map<string, { invoices: any[], totalDue: number }>();
        for (const inv of pendingInvoices) {
            if (!byStudent.has(inv.studentId)) {
                byStudent.set(inv.studentId, { invoices: [], totalDue: 0 });
            }
            const data = byStudent.get(inv.studentId)!;
            data.invoices.push(inv);
            data.totalDue += inv.balancePaisa || 0;
        }

        const reminders = [];
        const threeDaysFromNow = new Date();
        threeDaysFromNow.setDate(threeDaysFromNow.getDate() + 3);

        for (const [studentId, data] of byStudent) {
            const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(studentId));
            if (!student || !student.parentPhone) continue;

            const hasOverdue = data.invoices.some(i => i.dueDate < today);
            const dueSoon = data.invoices.some(i => {
                const due = new Date(i.dueDate);
                return due <= threeDaysFromNow && due >= new Date();
            });

            if (hasOverdue || dueSoon) {
                const message = hasOverdue
                    ? `Fee Reminder: ${student.firstName} ${student.lastName} has overdue fees of ₹${paisaToRupee(data.totalDue).toFixed(0)}. Please clear dues immediately.`
                    : `Fee Reminder: ${student.firstName} ${student.lastName} has pending fees of ₹${paisaToRupee(data.totalDue).toFixed(0)} due soon. Please pay on time.`;

                const reminder = {
                    PK: pk,
                    SK: `AC_FEE_REMINDER#${studentId}#${today}`,
                    id: uid(),
                    studentId,
                    parentPhone: student.parentPhone,
                    message,
                    totalDuePaisa: data.totalDue,
                    totalDue: paisaToRupee(data.totalDue),
                    invoiceCount: data.invoices.length,
                    hasOverdue,
                    dueSoon,
                    status: 'pending',
                    createdAt: now(),
                };

                await putItem(reminder);
                reminders.push(reminder);

                // Dispatch SMS + WhatsApp fee reminder
                sendSmsViaSns(student.parentPhone, message, auth.tenantId).catch(() => { });
                if (student.parentWhatsapp || student.parentPhone) {
                    sendWhatsApp(student.parentWhatsapp || student.parentPhone, message, auth.tenantId).catch(() => { });
                }
                if (student.email) {
                    sendEmailViaSes(student.email, 'Fee Reminder', message, auth.tenantId).catch(() => { });
                }
                logger.info('Fee reminder dispatched', {
                    tenantId: auth.tenantId,
                    studentId,
                    amount: paisaToRupee(data.totalDue),
                });
            }
        }

        return response.success({
            totalReminders: reminders.length,
            reminders,
        }, 201);
    },
    AC_NOTIFICATION_OPTS,
);

// ============================================================================
// BULK OPERATIONS
// ============================================================================

const AC_BULK_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_BULK_OPERATIONS,
};

/**
 * POST /ac/bulk/student-import
 */
export const bulkImportStudents = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { students = [], courseId, batchId, defaultValues = {} } = body;

        if (!students.length) return response.badRequest('students array is required');
        if (students.length > 100) return response.badRequest('Maximum 100 students per batch import');

        const pk = Keys.tenantPK(auth.tenantId);
        const ts = now();
        const importedStudents = [];
        const errors = [];

        for (let i = 0; i < students.length; i++) {
            const studentData = students[i];

            // Validate required fields
            if (!studentData.firstName || !studentData.lastName || !studentData.phone) {
                errors.push({ row: i + 1, error: 'Missing required fields (firstName, lastName, phone)' });
                continue;
            }

            const id = uid();
            const studentId = `STU-${auth.tenantId.substring(0, 8)}-${new Date().toISOString().slice(0, 7).replace('-', '')}-${id.substring(0, 6)}`;

            const item: Record<string, any> = {
                PK: pk,
                SK: Keys.acStudentSK(id),
                GSI1PK: batchId ? Keys.acStudentByBatchGSI1PK(auth.tenantId, batchId) : null,
                GSI1SK: `STUDENT#${id}`,
                id,
                studentId,
                firstName: studentData.firstName,
                lastName: studentData.lastName,
                phone: studentData.phone,
                parentPhone: studentData.parentPhone || defaultValues.parentPhone,
                parentName: studentData.parentName || defaultValues.parentName,
                email: studentData.email,
                address: studentData.address,
                dob: studentData.dob,
                gender: studentData.gender,
                schoolName: studentData.schoolName,
                currentClass: studentData.currentClass,
                board: studentData.board,
                enrolledCourseIds: courseId ? [courseId] : (studentData.enrolledCourseIds || []),
                enrolledBatchIds: batchId ? [batchId] : (studentData.enrolledBatchIds || []),
                status: 'active',
                source: 'bulk_import',
                createdAt: ts,
                updatedAt: ts,
                createdBy: auth.sub,
            };

            if (!item.GSI1PK) delete item.GSI1PK;

            try {
                await putItem(item);
                importedStudents.push(item);
            } catch (err) {
                errors.push({ row: i + 1, error: (err as Error).message });
            }
        }

        // Update batch enrolled count if batchId provided
        if (batchId && importedStudents.length > 0) {
            const batch = await getItem<Record<string, any>>(pk, Keys.acBatchSK(batchId));
            if (batch) {
                await updateItem(pk, Keys.acBatchSK(batchId), {
                    updateExpression: 'SET #enrolledCount = if_not_exists(#enrolledCount, :zero) + :increment',
                    expressionAttributeNames: { '#enrolledCount': 'enrolledCount' },
                    expressionAttributeValues: { ':zero': 0, ':increment': importedStudents.length },
                });
            }
        }

        logger.info('Bulk student import completed', {
            tenantId: auth.tenantId,
            imported: importedStudents.length,
            errors: errors.length,
        });

        return response.success({
            totalProcessed: students.length,
            imported: importedStudents.length,
            failed: errors.length,
            students: importedStudents,
            errors,
        }, 201);
    },
    AC_BULK_OPTS,
);

/**
 * POST /ac/bulk/generate-invoices
 */
export const bulkGenerateInvoices = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { batchId, courseId, feeComponents = [], dueDate, description } = body;

        if (!batchId && !courseId) {
            return response.badRequest('Either batchId or courseId is required');
        }

        const pk = Keys.tenantPK(auth.tenantId);

        // Get students
        let students: Record<string, any>[] = [];
        if (batchId) {
            students = await queryAllItems<Record<string, any>>(
                Keys.acStudentByBatchGSI1PK(auth.tenantId, batchId),
                '',
                { indexName: 'GSI1' }
            );
        } else {
            const allStudents = await queryAllItems<Record<string, any>>(pk, 'AC_STUDENT#');
            students = allStudents.filter(s =>
                s.enrolledCourseIds?.includes(courseId) && s.status === 'active'
            );
        }

        const generatedInvoices = [];

        for (const student of students) {
            // Calculate total
            let totalPaisa = 0;
            const components = feeComponents.map((fc: any) => {
                const amountPaisa = rupeeToPaisa(fc.amount || 0);
                totalPaisa += amountPaisa;
                return { ...fc, amountPaisa, amount: fc.amount || 0 };
            });

            const id = uid();
            const invoiceNumber = `INV-BULK-${new Date().toISOString().slice(0, 7).replace('-', '')}-${id.substring(0, 6)}`;

            const item = {
                PK: pk,
                SK: Keys.acInvoiceSK(id),
                GSI1PK: Keys.acFeeByStudentGSI1PK(auth.tenantId, student.id),
                GSI1SK: `INVOICE#${dueDate || now()}#${id}`,
                id,
                invoiceNumber,
                studentId: student.id,
                studentName: `${student.firstName} ${student.lastName}`,
                feeComponents: components,
                totalAmountPaisa: totalPaisa,
                totalAmount: paisaToRupee(totalPaisa),
                paidAmountPaisa: 0,
                paidAmount: 0,
                balancePaisa: totalPaisa,
                balance: paisaToRupee(totalPaisa),
                status: 'pending',
                dueDate: dueDate || new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
                description,
                source: 'bulk_generation',
                batchId,
                courseId,
                createdAt: now(),
                updatedAt: now(),
                createdBy: auth.sub,
            };

            await putItem(item);
            generatedInvoices.push(item);
        }

        logger.info('Bulk invoice generation completed', {
            tenantId: auth.tenantId,
            generated: generatedInvoices.length,
            batchId,
            courseId,
        });

        return response.success({
            totalStudents: students.length,
            generated: generatedInvoices.length,
            invoices: generatedInvoices,
        }, 201);
    },
    AC_BULK_OPTS,
);

// ============================================================================
// FINANCIAL REPORTS
// ============================================================================

const AC_FINANCIAL_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_FINANCIAL_REPORTS,
};

/**
 * GET /ac/reports/financial
 */
export const getFinancialReports = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _ctx, auth) => {
        const p = event.queryStringParameters || {};
        const { fromDate, toDate, reportType = 'overview' } = p;

        const pk = Keys.tenantPK(auth.tenantId);

        // Get date range
        const endDate = toDate || new Date().toISOString().split('T')[0];
        const startDate = fromDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

        // Parallel queries
        const [invoices, faculty, expenses] = await Promise.all([
            queryAllItems<Record<string, any>>(pk, 'AC_INVOICE#'),
            queryAllItems<Record<string, any>>(pk, 'AC_FACULTY#'),
            queryAllItems<Record<string, any>>(pk, 'AC_EXPENSE#'),
        ]);

        // Filter by date range
        const periodInvoices = invoices.filter(i =>
            i.createdAt >= startDate && i.createdAt <= `${endDate}T23:59:59`
        );

        const periodExpenses = expenses.filter(e =>
            e.date >= startDate && e.date <= endDate
        );

        switch (reportType) {
            case 'pl': {
                // Revenue
                const totalRevenuePaisa = periodInvoices.reduce((sum, i) =>
                    sum + (i.paidAmountPaisa || 0), 0);

                // Expenses
                const totalExpensePaisa = periodExpenses.reduce((sum, e) =>
                    sum + (e.amountPaisa || 0), 0);

                // Calculate faculty payroll from actual attendance records
                let totalPayrollPaisa = 0;
                const facultyAttendance = await queryAllItems<Record<string, any>>(pk, 'AC_FACULTY_ATTENDANCE#', {
                    filterExpression: '#date >= :start AND #date <= :end',
                    expressionAttributeNames: { '#date': 'date' },
                    expressionAttributeValues: { ':start': startDate, ':end': endDate },
                }).catch(() => [] as Record<string, any>[]);

                for (const f of faculty.filter((fac: Record<string, any>) => fac.isActive)) {
                    const salaryType = f.salaryStructure?.type || 'fixed';
                    if (salaryType === 'fixed') {
                        // Pro-rate fixed salary by days in period
                        const totalDays = Math.max(1, Math.ceil((new Date(endDate).getTime() - new Date(startDate).getTime()) / (1000 * 60 * 60 * 24)));
                        const monthDays = 30;
                        totalPayrollPaisa += Math.round((f.salaryStructure?.fixedAmountPaisa || 0) * (totalDays / monthDays));
                    } else if (salaryType === 'per_class') {
                        // Count actual classes from attendance records
                        const classesTaken = facultyAttendance
                            .filter((fa: Record<string, any>) => fa.facultyId === f.id)
                            .reduce((sum: number, fa: Record<string, any>) => sum + (fa.classesTaken || 0), 0);
                        totalPayrollPaisa += classesTaken * (f.salaryStructure?.perClassRatePaisa || 0);
                    } else if (salaryType === 'hybrid') {
                        const classesTaken = facultyAttendance
                            .filter((fa: Record<string, any>) => fa.facultyId === f.id)
                            .reduce((sum: number, fa: Record<string, any>) => sum + (fa.classesTaken || 0), 0);
                        totalPayrollPaisa += (f.salaryStructure?.fixedAmountPaisa || 0) +
                            classesTaken * (f.salaryStructure?.perClassRatePaisa || 0);
                    }
                }

                const netProfitPaisa = totalRevenuePaisa - totalExpensePaisa - totalPayrollPaisa;

                return response.success({
                    type: 'profit_loss',
                    period: { from: startDate, to: endDate },
                    revenue: {
                        total: paisaToRupee(totalRevenuePaisa),
                        totalPaisa: totalRevenuePaisa,
                    },
                    expenses: {
                        operational: paisaToRupee(totalExpensePaisa),
                        operationalPaisa: totalExpensePaisa,
                        payroll: paisaToRupee(totalPayrollPaisa),
                        payrollPaisa: totalPayrollPaisa,
                        total: paisaToRupee(totalExpensePaisa + totalPayrollPaisa),
                        totalPaisa: totalExpensePaisa + totalPayrollPaisa,
                    },
                    netProfit: paisaToRupee(netProfitPaisa),
                    netProfitPaisa,
                    profitMargin: totalRevenuePaisa > 0
                        ? (netProfitPaisa / totalRevenuePaisa) * 100
                        : 0,
                });
            }

            case 'batch_profitability': {
                const batches = await queryAllItems<Record<string, any>>(pk, 'AC_BATCH#');

                const batchStats = await Promise.all(batches.map(async (batch) => {
                    const batchStudents = await queryAllItems<Record<string, any>>(
                        Keys.acStudentByBatchGSI1PK(auth.tenantId, batch.id),
                        '',
                        { indexName: 'GSI1' }
                    );

                    const batchInvoices = invoices.filter(i =>
                        batchStudents.some(s => s.id === i.studentId) &&
                        i.createdAt >= startDate && i.createdAt <= `${endDate}T23:59:59`
                    );

                    const revenuePaisa = batchInvoices.reduce((sum, i) =>
                        sum + (i.paidAmountPaisa || 0), 0);

                    return {
                        batchId: batch.id,
                        batchName: batch.name,
                        studentCount: batchStudents.length,
                        revenue: paisaToRupee(revenuePaisa),
                        revenuePaisa,
                        avgRevenuePerStudent: batchStudents.length > 0
                            ? paisaToRupee(revenuePaisa / batchStudents.length)
                            : 0,
                    };
                }));

                batchStats.sort((a, b) => b.revenuePaisa - a.revenuePaisa);

                return response.success({
                    type: 'batch_profitability',
                    period: { from: startDate, to: endDate },
                    batches: batchStats,
                    totalRevenue: paisaToRupee(batchStats.reduce((sum, b) => sum + b.revenuePaisa, 0)),
                });
            }

            case 'outstanding_fees': {
                const outstanding = invoices.filter(i => i.status !== 'paid');

                // Aging buckets
                const today = new Date();
                const buckets = {
                    current: { count: 0, amountPaisa: 0 },
                    days30: { count: 0, amountPaisa: 0 },
                    days60: { count: 0, amountPaisa: 0 },
                    days90: { count: 0, amountPaisa: 0 },
                    over90: { count: 0, amountPaisa: 0 },
                };

                for (const inv of outstanding) {
                    const dueDate = new Date(inv.dueDate);
                    const daysDiff = Math.floor((today.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24));
                    const balance = inv.balancePaisa || 0;

                    if (daysDiff <= 0) {
                        buckets.current.count++;
                        buckets.current.amountPaisa += balance;
                    } else if (daysDiff <= 30) {
                        buckets.days30.count++;
                        buckets.days30.amountPaisa += balance;
                    } else if (daysDiff <= 60) {
                        buckets.days60.count++;
                        buckets.days60.amountPaisa += balance;
                    } else if (daysDiff <= 90) {
                        buckets.days90.count++;
                        buckets.days90.amountPaisa += balance;
                    } else {
                        buckets.over90.count++;
                        buckets.over90.amountPaisa += balance;
                    }
                }

                return response.success({
                    type: 'outstanding_fees',
                    generatedAt: now(),
                    totalOutstanding: {
                        count: outstanding.length,
                        amount: paisaToRupee(outstanding.reduce((sum, i) => sum + (i.balancePaisa || 0), 0)),
                        amountPaisa: outstanding.reduce((sum, i) => sum + (i.balancePaisa || 0), 0),
                    },
                    agingBuckets: {
                        current: { ...buckets.current, amount: paisaToRupee(buckets.current.amountPaisa) },
                        days30: { ...buckets.days30, amount: paisaToRupee(buckets.days30.amountPaisa) },
                        days60: { ...buckets.days60, amount: paisaToRupee(buckets.days60.amountPaisa) },
                        days90: { ...buckets.days90, amount: paisaToRupee(buckets.days90.amountPaisa) },
                        over90: { ...buckets.over90, amount: paisaToRupee(buckets.over90.amountPaisa) },
                    },
                });
            }

            default:
                return response.success({ type: 'overview', message: 'Use reportType: pl, batch_profitability, outstanding_fees' });
        }
    },
    AC_FINANCIAL_OPTS,
);

// ============================================================================
// CERTIFICATE & PDF GENERATION
// ============================================================================

const AC_CERTIFICATE_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_CERTIFICATES,
};

/**
 * POST /ac/certificates/generate
 */
export const generateCertificate = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { studentId, type, templateId, issueDate, expiryDate, metadata = {} } = body;

        if (!studentId || !type) {
            return response.badRequest('studentId and type are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(studentId));
        if (!student) return response.notFound('Student not found');

        // Validate certificate type
        const validTypes = ['course_completion', 'achievement', 'attendance', 'ranking', 'transfer'];
        if (!validTypes.includes(type)) {
            return response.badRequest(`Invalid type. Must be one of: ${validTypes.join(', ')}`);
        }

        const id = uid();
        const certificateNumber = `CERT-${type.toUpperCase()}-${new Date().toISOString().slice(0, 7).replace('-', '')}-${id.substring(0, 6)}`;

        // Get course info if applicable
        let courseName = metadata.courseName;
        if (!courseName && student.enrolledCourseIds?.length > 0) {
            const course = await getItem<Record<string, any>>(pk, Keys.acCourseSK(student.enrolledCourseIds[0]));
            courseName = course?.name;
        }

        const certificate = {
            PK: pk,
            SK: `AC_CERTIFICATE#${id}`,
            id,
            certificateNumber,
            studentId,
            studentName: `${student.firstName} ${student.lastName}`,
            type,
            templateId: templateId || 'default',
            courseName,
            issueDate: issueDate || now().split('T')[0],
            expiryDate,
            metadata: {
                ...metadata,
                studentCode: student.studentId,
                batchIds: student.enrolledBatchIds,
            },
            status: 'issued',
            downloadUrl: null, // Generated on-demand
            createdAt: now(),
            createdBy: auth.sub,
        };

        await putItem(certificate);

        // Generate certificate S3 key and a presigned upload URL for the PDF
        const certS3Key = `tenants/${auth.tenantId}/certificates/${type}/${id}.pdf`;
        const certUploadUrl = await storageService.getUploadUrl(certS3Key, 'application/pdf').catch(() => null);

        // Store the S3 key so download works once PDF is uploaded
        await updateItem(pk, `AC_CERTIFICATE#${id}`, {
            updateExpression: 'SET #s3Key = :s3Key',
            expressionAttributeNames: { '#s3Key': 's3Key' },
            expressionAttributeValues: { ':s3Key': certS3Key },
        }).catch(() => { });

        logger.info('Certificate generated', {
            tenantId: auth.tenantId,
            certificateId: id,
            type,
            studentId,
        });

        return response.success({
            ...certificate,
            s3Key: certS3Key,
            pdfUploadUrl: certUploadUrl, // caller uploads rendered PDF here
            pdfGenerationStatus: 'awaiting_upload',
        }, 201);
    },
    AC_CERTIFICATE_OPTS,
);

/**
 * GET /ac/certificates
 */
export const listCertificates = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let certificates = await queryAllItems<Record<string, any>>(pk, 'AC_CERTIFICATE#');

    if (p.studentId) {
        certificates = certificates.filter(c => c.studentId === p.studentId);
    }
    if (p.type) {
        certificates = certificates.filter(c => c.type === p.type);
    }

    return response.success(certificates);
}, AC_CERTIFICATE_OPTS);

/**
 * GET /ac/certificates/{id}/download
 */
export const downloadCertificate = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Certificate ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const certificate = await getItem<Record<string, any>>(pk, `AC_CERTIFICATE#${id}`);
    if (!certificate) return response.notFound('Certificate not found');

    if (!certificate.s3Key) {
        return response.success({
            certificateId: id,
            status: 'not_generated',
            message: 'Certificate PDF has not been uploaded yet. Generate and upload via POST /ac/certificates/generate.',
        });
    }

    // Generate fresh presigned GET URL (5 min TTL)
    const downloadUrl = await storageService.getDownloadUrl(certificate.s3Key).catch(() => null);

    return response.success({
        certificateId: id,
        certificateNumber: certificate.certificateNumber,
        downloadUrl,
        expiresIn: 300,
    });
}, AC_CERTIFICATE_OPTS);

/**
 * POST /ac/bulk/certificates
 */
export const bulkGenerateCertificates = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { studentIds = [], type, templateId, courseId, issueDate } = body;

        if (!studentIds.length || !type) {
            return response.badRequest('studentIds and type are required');
        }
        if (studentIds.length > 50) {
            return response.badRequest('Maximum 50 certificates per bulk operation');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const generated = [];
        const errors = [];

        for (const studentId of studentIds) {
            const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(studentId));
            if (!student) {
                errors.push({ studentId, error: 'Student not found' });
                continue;
            }

            // Skip if student not in course (if specified)
            if (courseId && !student.enrolledCourseIds?.includes(courseId)) {
                errors.push({ studentId, error: 'Student not enrolled in specified course' });
                continue;
            }

            const id = uid();
            const certificateNumber = `CERT-BULK-${new Date().toISOString().slice(0, 7).replace('-', '')}-${id.substring(0, 6)}`;

            let courseName = null;
            if (courseId) {
                const course = await getItem<Record<string, any>>(pk, Keys.acCourseSK(courseId));
                courseName = course?.name;
            }

            const certificate = {
                PK: pk,
                SK: `AC_CERTIFICATE#${id}`,
                id,
                certificateNumber,
                studentId,
                studentName: `${student.firstName} ${student.lastName}`,
                type,
                templateId: templateId || 'default',
                courseName,
                issueDate: issueDate || now().split('T')[0],
                status: 'issued',
                downloadUrl: null,
                createdAt: now(),
                createdBy: auth.sub,
            };

            await putItem(certificate);
            generated.push(certificate);
        }

        logger.info('Bulk certificate generation completed', {
            tenantId: auth.tenantId,
            generated: generated.length,
            errors: errors.length,
        });

        return response.success({
            totalRequested: studentIds.length,
            generated: generated.length,
            errors,
            certificates: generated,
        }, 201);
    },
    AC_CERTIFICATE_OPTS,
);

// ============================================================================
// STUDENT PHOTO UPLOAD
// ============================================================================

/**
 * POST /ac/students/{id}/photo-upload
 * Returns a presigned PUT URL for uploading the student photo to S3.
 */
export const getStudentPhotoUploadUrl = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Student ID required');

        const body = parseBody<Record<string, any>>(event);
        const contentType = body.contentType || 'image/jpeg';
        const allowed = ['image/jpeg', 'image/png', 'image/webp'];
        if (!allowed.includes(contentType)) {
            return response.badRequest(`contentType must be one of: ${allowed.join(', ')}`);
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(id));
        if (!student) return response.notFound('Student not found');

        const ext = contentType.split('/')[1];
        const s3Key = `tenants/${auth.tenantId}/students/${id}/photo.${ext}`;

        const uploadUrl = await storageService.getUploadUrl(s3Key, contentType);

        // Persist the s3Key on the student record so it can be retrieved later
        await updateItem(pk, Keys.acStudentSK(id), {
            updateExpression: 'SET #photoS3Key = :key, #updatedAt = :updatedAt',
            expressionAttributeNames: { '#photoS3Key': 'photoS3Key', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':key': s3Key, ':updatedAt': now() },
        });

        logger.info('Student photo upload URL generated', { tenantId: auth.tenantId, studentId: id });
        return response.success({ studentId: id, uploadUrl, s3Key, expiresIn: 300 });
    },
    AC_OPTS,
);

/**
 * GET /ac/students/{id}/photo
 * Returns a presigned GET URL to view the student photo.
 */
export const getStudentPhotoUrl = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(id));
    if (!student) return response.notFound('Student not found');

    if (!student.photoS3Key) {
        return response.success({ studentId: id, photoUrl: null, message: 'No photo uploaded yet' });
    }

    const photoUrl = await storageService.getDownloadUrl(student.photoS3Key).catch(() => null);
    return response.success({ studentId: id, photoUrl, expiresIn: 300 });
}, AC_OPTS);

// ============================================================================
// ID CARDS
// ============================================================================

const AC_ID_CARD_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_CERTIFICATES,
};

/**
 * POST /ac/id-cards/generate
 * Generates an ID card record and returns a presigned upload URL for the rendered PDF/image.
 */
export const generateIdCard = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { studentId, validUntil, templateId } = body;

        if (!studentId) return response.badRequest('studentId is required');

        const pk = Keys.tenantPK(auth.tenantId);
        const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(studentId));
        if (!student) return response.notFound('Student not found');

        const id = uid();
        const cardNumber = `ID-${auth.tenantId.substring(0, 6)}-${student.studentId || id.substring(0, 8)}`;
        const s3Key = `tenants/${auth.tenantId}/id-cards/${studentId}/${id}.pdf`;

        const item = {
            PK: pk,
            SK: Keys.acIdCardSK(id),
            id,
            cardNumber,
            studentId,
            studentName: `${student.firstName} ${student.lastName}`,
            studentCode: student.studentId,
            phone: student.phone,
            photoS3Key: student.photoS3Key || null,
            enrolledBatchIds: student.enrolledBatchIds || [],
            enrolledCourseIds: student.enrolledCourseIds || [],
            templateId: templateId || 'default',
            validUntil: validUntil || new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
            s3Key,
            status: 'awaiting_upload',
            createdAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);

        // Presigned PUT URL so Flutter can upload the rendered card
        const uploadUrl = await storageService.getUploadUrl(s3Key, 'application/pdf').catch(() => null);

        // Also provide photo download URL if available
        let photoUrl: string | null = null;
        if (student.photoS3Key) {
            photoUrl = await storageService.getDownloadUrl(student.photoS3Key).catch(() => null);
        }

        logger.info('ID card generated', { tenantId: auth.tenantId, idCardId: id, studentId });
        return response.success({ ...item, uploadUrl, photoUrl }, 201);
    },
    AC_ID_CARD_OPTS,
);

/**
 * GET /ac/id-cards?studentId=
 */
export const listIdCards = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let cards = await queryAllItems<Record<string, any>>(pk, 'AC_ID_CARD#');

    if (p.studentId) {
        cards = cards.filter(c => c.studentId === p.studentId);
    }

    return response.success(cards);
}, AC_ID_CARD_OPTS);

/**
 * GET /ac/id-cards/{id}/download
 */
export const downloadIdCard = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('ID card ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const card = await getItem<Record<string, any>>(pk, Keys.acIdCardSK(id));
    if (!card) return response.notFound('ID card not found');

    if (!card.s3Key) {
        return response.success({ id, status: 'not_generated', downloadUrl: null });
    }

    const downloadUrl = await storageService.getDownloadUrl(card.s3Key).catch(() => null);
    return response.success({ id, cardNumber: card.cardNumber, downloadUrl, expiresIn: 300 });
}, AC_ID_CARD_OPTS);

// ============================================================================
// CONSOLIDATED PENDING FEES
// ============================================================================

/**
 * GET /ac/fees/pending?batchId=&status=overdue|pending|partial&page=&limit=
 * Returns a consolidated list of all students with outstanding fee balances.
 */
export const getPendingFees = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _ctx, auth) => {
        const p = event.queryStringParameters || {};
        const pk = Keys.tenantPK(auth.tenantId);
        const page = Math.max(1, parseInt(p.page || '1', 10));
        const limit = Math.min(parseInt(p.limit || '50', 10), 200);
        const today = new Date().toISOString().split('T')[0];

        // Get all non-paid invoices
        let invoices = await queryAllItems<Record<string, any>>(pk, 'AC_INVOICE#');
        invoices = invoices.filter(i => i.status !== 'paid' && (i.balancePaisa || 0) > 0);

        // Apply status filter
        if (p.status === 'overdue') {
            invoices = invoices.filter(i => i.dueDate < today);
        } else if (p.status === 'partial') {
            invoices = invoices.filter(i => i.status === 'partial');
        } else if (p.status === 'pending') {
            invoices = invoices.filter(i => i.status === 'pending');
        }

        // Group by student
        const byStudent = new Map<string, { invoices: any[]; totalDuePaisa: number; overduePaisa: number }>();
        for (const inv of invoices) {
            if (!byStudent.has(inv.studentId)) {
                byStudent.set(inv.studentId, { invoices: [], totalDuePaisa: 0, overduePaisa: 0 });
            }
            const entry = byStudent.get(inv.studentId)!;
            entry.invoices.push(inv);
            entry.totalDuePaisa += inv.balancePaisa || 0;
            if (inv.dueDate < today) entry.overduePaisa += inv.balancePaisa || 0;
        }

        // Build result rows — enrich with student name
        const rows: Record<string, any>[] = [];
        for (const [studentId, data] of byStudent) {
            const student = await getItem<Record<string, any>>(pk, Keys.acStudentSK(studentId)).catch(() => null);
            rows.push({
                studentId,
                studentName: student ? `${student.firstName} ${student.lastName}` : 'Unknown',
                studentCode: student?.studentId,
                phone: student?.phone,
                parentPhone: student?.parentPhone,
                batchIds: student?.enrolledBatchIds || [],
                invoiceCount: data.invoices.length,
                totalDuePaisa: data.totalDuePaisa,
                totalDue: paisaToRupee(data.totalDuePaisa),
                overduePaisa: data.overduePaisa,
                overdue: paisaToRupee(data.overduePaisa),
                hasOverdue: data.overduePaisa > 0,
                oldestDueDate: data.invoices.map(i => i.dueDate).sort()[0],
            });
        }

        // Filter by batchId if provided
        let filtered = rows;
        if (p.batchId) {
            filtered = rows.filter(r => (r.batchIds || []).includes(p.batchId));
        }

        // Sort by overdue first, then by totalDue descending
        filtered.sort((a, b) => {
            if (b.overduePaisa !== a.overduePaisa) return b.overduePaisa - a.overduePaisa;
            return b.totalDuePaisa - a.totalDuePaisa;
        });

        const total = filtered.length;
        const paged = filtered.slice((page - 1) * limit, page * limit);

        const summary = {
            totalStudentsWithDues: total,
            totalOutstandingPaisa: rows.reduce((s, r) => s + r.totalDuePaisa, 0),
            totalOutstanding: paisaToRupee(rows.reduce((s, r) => s + r.totalDuePaisa, 0)),
            totalOverduePaisa: rows.reduce((s, r) => s + r.overduePaisa, 0),
            totalOverdue: paisaToRupee(rows.reduce((s, r) => s + r.overduePaisa, 0)),
        };

        return response.success({
            items: paged,
            summary,
            pagination: { page, limit, total },
        });
    },
    AC_FEE_OPTS,
);

// ============================================================================
// DEMO CLASSES
// ============================================================================

const AC_DEMO_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_STUDENT_MANAGEMENT,
};

/**
 * GET /ac/demo-classes
 */
export const listDemoClasses = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);

    let demos = await queryAllItems<Record<string, any>>(pk, 'AC_DEMO#');

    if (p.status) demos = demos.filter(d => d.status === p.status);
    if (p.courseId) demos = demos.filter(d => d.courseId === p.courseId);
    if (p.search) {
        const s = p.search.toLowerCase();
        demos = demos.filter(d =>
            (d.prospectName || '').toLowerCase().includes(s) ||
            (d.phone || '').toLowerCase().includes(s)
        );
    }

    demos.sort((a, b) => (b.scheduledAt || '').localeCompare(a.scheduledAt || ''));

    const total = demos.length;
    const paged = demos.slice((page - 1) * limit, page * limit);
    return response.paginated(paged, total, page, limit);
}, AC_DEMO_OPTS);

/**
 * POST /ac/demo-classes
 */
export const createDemoClass = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            prospectName, phone, email, courseId, batchId,
            scheduledAt, facultyId, notes, source,
        } = body;

        if (!prospectName || !phone || !scheduledAt) {
            return response.badRequest('prospectName, phone, scheduledAt are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const id = uid();

        // Get course name if provided
        let courseName: string | undefined;
        if (courseId) {
            const course = await getItem<Record<string, any>>(pk, Keys.acCourseSK(courseId));
            courseName = course?.name;
        }

        const item = {
            PK: pk,
            SK: Keys.acDemoClassSK(id),
            GSI1PK: Keys.acDemoByStatusGSI1PK(auth.tenantId, 'scheduled'),
            GSI1SK: scheduledAt,
            id,
            prospectName,
            phone,
            email,
            courseId,
            courseName,
            batchId,
            scheduledAt,
            facultyId,
            notes,
            source: source || 'walk_in',
            status: 'scheduled',
            outcome: null,
            convertedStudentId: null,
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('Demo class created', { tenantId: auth.tenantId, demoId: id });
        return response.success(item, 201);
    },
    AC_DEMO_OPTS,
);

/**
 * PUT /ac/demo-classes/{id}
 * Update demo class status/outcome after the class is conducted.
 */
export const updateDemoClass = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Demo class ID required');

        const pk = Keys.tenantPK(auth.tenantId);
        const demo = await getItem<Record<string, any>>(pk, Keys.acDemoClassSK(id));
        if (!demo) return response.notFound('Demo class not found');

        const body = parseBody<Record<string, any>>(event);
        const allowed = ['scheduledAt', 'facultyId', 'notes', 'status', 'outcome', 'rescheduledAt'];
        const exprParts: string[] = ['#updatedAt = :updatedAt'];
        const names: Record<string, string> = { '#updatedAt': 'updatedAt' };
        const values: Record<string, any> = { ':updatedAt': now() };

        for (const k of allowed) {
            if (body[k] !== undefined) {
                exprParts.push(`#${k} = :${k}`);
                names[`#${k}`] = k;
                values[`:${k}`] = body[k];
            }
        }

        // Update GSI1PK if status changed
        if (body.status) {
            exprParts.push('#GSI1PK = :gsi1pk');
            names['#GSI1PK'] = 'GSI1PK';
            values[':gsi1pk'] = Keys.acDemoByStatusGSI1PK(auth.tenantId, body.status);
        }

        await updateItem(pk, Keys.acDemoClassSK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        logger.info('Demo class updated', { tenantId: auth.tenantId, demoId: id, status: body.status });
        return response.success({ ...demo, ...body, updatedAt: now() });
    },
    AC_DEMO_OPTS,
);

/**
 * POST /ac/demo-classes/{id}/convert
 * Converts a demo class prospect into a fully enrolled student.
 */
export const convertDemoToEnrollment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Demo class ID required');

        const pk = Keys.tenantPK(auth.tenantId);
        const demo = await getItem<Record<string, any>>(pk, Keys.acDemoClassSK(id));
        if (!demo) return response.notFound('Demo class not found');

        if (demo.convertedStudentId) {
            return response.conflict('Demo class already converted to enrollment');
        }
        if (demo.status === 'cancelled') {
            return response.badRequest('Cannot convert a cancelled demo class');
        }

        const body = parseBody<Record<string, any>>(event);
        const {
            enrolledBatchIds = demo.batchId ? [demo.batchId] : [],
            enrolledCourseIds = demo.courseId ? [demo.courseId] : [],
            parentName, parentPhone, dob, gender, address,
        } = body;

        // Create student from demo prospect data
        const studentUid = uid();
        const studentId = `STU-${auth.tenantId.substring(0, 8)}-${new Date().toISOString().slice(0, 7).replace('-', '')}-${studentUid.substring(0, 6)}`;

        const nameParts = demo.prospectName.trim().split(' ');
        const firstName = nameParts[0];
        const lastName = nameParts.slice(1).join(' ') || '';

        const studentItem: Record<string, any> = {
            PK: pk,
            SK: Keys.acStudentSK(studentUid),
            id: studentUid,
            studentId,
            firstName,
            lastName,
            phone: demo.phone,
            email: demo.email,
            parentName,
            parentPhone,
            dob,
            gender,
            address,
            enrolledBatchIds,
            enrolledCourseIds,
            status: 'active',
            source: 'demo_conversion',
            demoClassId: id,
            createdAt: now(),
            updatedAt: now(),
            createdBy: auth.sub,
        };

        if (enrolledBatchIds.length > 0) {
            studentItem.GSI1PK = Keys.acStudentByBatchGSI1PK(auth.tenantId, enrolledBatchIds[0]);
            studentItem.GSI1SK = `STUDENT#${studentUid}`;
        }

        await putItem(studentItem);

        // Increment enrolledCount on each assigned batch
        for (const bId of enrolledBatchIds) {
            await updateItem(pk, Keys.acBatchSK(bId), {
                updateExpression: 'SET #ec = if_not_exists(#ec, :zero) + :one',
                expressionAttributeNames: { '#ec': 'enrolledCount' },
                expressionAttributeValues: { ':zero': 0, ':one': 1 },
            }).catch(() => { });
        }

        // Mark demo as converted
        await updateItem(pk, Keys.acDemoClassSK(id), {
            updateExpression: 'SET #status = :status, #convertedStudentId = :sid, #convertedAt = :at, #GSI1PK = :gsi1pk, #updatedAt = :updatedAt',
            expressionAttributeNames: {
                '#status': 'status',
                '#convertedStudentId': 'convertedStudentId',
                '#convertedAt': 'convertedAt',
                '#GSI1PK': 'GSI1PK',
                '#updatedAt': 'updatedAt',
            },
            expressionAttributeValues: {
                ':status': 'converted',
                ':sid': studentUid,
                ':at': now(),
                ':gsi1pk': Keys.acDemoByStatusGSI1PK(auth.tenantId, 'converted'),
                ':updatedAt': now(),
            },
        });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.AC_STUDENT_ENROLLED,
            { studentId: studentUid, firstName, lastName, source: 'demo_conversion', demoClassId: id },
        ).catch(() => { });

        logger.info('Demo class converted to enrollment', {
            tenantId: auth.tenantId,
            demoId: id,
            studentId: studentUid,
        });

        return response.success({
            demoId: id,
            student: studentItem,
            message: 'Demo class successfully converted to student enrollment',
        }, 201);
    },
    AC_DEMO_OPTS,
);

// ============================================================================
// CLASSES & SECTIONS (NEW SCHOOL ERP)
// ============================================================================

const AC_CLASS_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_CLASS_SECTION_MANAGEMENT,
};

function classSK(classId: string) { return `CLASS#${classId}`; }
function sectionSK(classId: string, sectionId: string) { return `CLASS#${classId}#SECTION#${sectionId}`; }

/** GET /ac/classes */
export const listClasses = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const items = await queryAllItems<Record<string, any>>(pk, 'CLASS#');
    const classes = items.filter((i: any) => !i.SK.includes('#SECTION#'));
    const sections = items.filter((i: any) => i.SK.includes('#SECTION#'));
    const result = classes.map((cls: any) => ({
        ...cls,
        id: cls.classId,
        sections: sections.filter((s: any) => s.SK.startsWith(`CLASS#${cls.classId}#SECTION#`)).map((s: any) => ({ ...s, id: s.sectionId })),
        totalStudents: cls.studentCount ?? 0,
    }));
    return response.success({ classes: result, total: result.length });
}, AC_CLASS_OPTS);

/** POST /ac/classes */
export const createClass = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<{ name: string; classTeacherName?: string }>(event);
        if (!body?.name) return response.badRequest('name is required');
        const pk = Keys.tenantPK(auth.tenantId);
        const classId = uid();
        await putItem({ PK: pk, SK: classSK(classId), classId, name: body.name, classTeacherName: body.classTeacherName ?? null, studentCount: 0, createdAt: now(), updatedAt: now(), entityType: 'CLASS' });
        return response.success({ classId, name: body.name }, 201);
    }, AC_CLASS_OPTS,
);

/** PUT /ac/classes/:classId */
export const updateClass = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const classId = event.pathParameters?.classId ?? '';
        const body = parseBody<{ name?: string; classTeacherName?: string }>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        await updateItem(pk, classSK(classId), {
            updateExpression: 'SET #n = :n, classTeacherName = :t, updatedAt = :u',
            expressionAttributeNames: { '#n': 'name' },
            expressionAttributeValues: { ':n': body?.name ?? '', ':t': body?.classTeacherName ?? null, ':u': now() },
        });
        return response.success({ classId });
    }, AC_CLASS_OPTS,
);

/** DELETE /ac/classes/:classId */
export const deleteClass = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const classId = event.pathParameters?.classId ?? '';
        const pk = Keys.tenantPK(auth.tenantId);
        await deleteItem(pk, classSK(classId));
        return response.success({ deleted: classId });
    }, AC_CLASS_OPTS,
);

/** POST /ac/classes/:classId/sections */
export const addSection = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const classId = event.pathParameters?.classId ?? '';
        const body = parseBody<{ name: string; teacherName?: string }>(event);
        if (!body?.name) return response.badRequest('name is required');
        const pk = Keys.tenantPK(auth.tenantId);
        const sectionId = uid();
        await putItem({ PK: pk, SK: sectionSK(classId, sectionId), classId, sectionId, name: body.name, teacherName: body.teacherName ?? null, studentCount: 0, createdAt: now(), updatedAt: now(), entityType: 'SECTION' });
        return response.success({ sectionId, name: body.name }, 201);
    }, AC_CLASS_OPTS,
);

/** PUT /ac/classes/:classId/sections/:sectionId */
export const updateSection = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const { classId, sectionId } = event.pathParameters ?? {};
        const body = parseBody<{ teacherName?: string }>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        await updateItem(pk, sectionSK(classId ?? '', sectionId ?? ''), {
            updateExpression: 'SET teacherName = :t, updatedAt = :u',
            expressionAttributeNames: {},
            expressionAttributeValues: { ':t': body?.teacherName ?? null, ':u': now() },
        });
        return response.success({ sectionId });
    }, AC_CLASS_OPTS,
);

/** DELETE /ac/classes/:classId/sections/:sectionId */
export const deleteSection = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const { classId, sectionId } = event.pathParameters ?? {};
        const pk = Keys.tenantPK(auth.tenantId);
        await deleteItem(pk, sectionSK(classId ?? '', sectionId ?? ''));
        return response.success({ deleted: sectionId });
    }, AC_CLASS_OPTS,
);

// ============================================================================
// ACADEMIC YEAR & TERMS (NEW SCHOOL ERP)
// ============================================================================

const AC_YEAR_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_ACADEMIC_YEAR_MANAGEMENT,
};

function yearSK(yearId: string) { return `ACYEAR#${yearId}`; }
function termSK(yearId: string, termId: string) { return `ACYEAR#${yearId}#TERM#${termId}`; }

/** GET /ac/academic-years */
export const listAcademicYears = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const items = await queryAllItems<Record<string, any>>(pk, 'ACYEAR#');
    const years = items.filter((i) => !i.SK.includes('#TERM#'));
    const terms = items.filter((i) => i.SK.includes('#TERM#'));
    const result = years.map((y) => ({
        ...y, id: y.yearId,
        terms: terms.filter((t) => t.SK.startsWith(`ACYEAR#${y.yearId}#TERM#`)).map((t) => ({ ...t, id: t.termId })),
    }));
    return response.success({ years: result, total: result.length });
}, AC_YEAR_OPTS);

/** POST /ac/academic-years */
export const createAcademicYear = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const body = parseBody<{ name: string; startDate: string; endDate: string }>(event);
        if (!body?.name || !body.startDate || !body.endDate) return response.badRequest('name, startDate, endDate required');
        const pk = Keys.tenantPK(auth.tenantId);
        const yearId = uid();
        await putItem({ PK: pk, SK: yearSK(yearId), yearId, name: body.name, startDate: body.startDate, endDate: body.endDate, isActive: false, createdAt: now(), updatedAt: now(), entityType: 'ACADEMIC_YEAR' });
        return response.success({ yearId, name: body.name }, 201);
    }, AC_YEAR_OPTS,
);

/** PUT /ac/academic-years/:yearId */
export const updateAcademicYear = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const yearId = event.pathParameters?.yearId ?? '';
        const body = parseBody<{ name?: string }>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        await updateItem(pk, yearSK(yearId), {
            updateExpression: 'SET #n = :n, updatedAt = :u',
            expressionAttributeNames: { '#n': 'name' },
            expressionAttributeValues: { ':n': body?.name ?? '', ':u': now() },
        });
        return response.success({ yearId });
    }, AC_YEAR_OPTS,
);

/** DELETE /ac/academic-years/:yearId */
export const deleteAcademicYear = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const yearId = event.pathParameters?.yearId ?? '';
        const pk = Keys.tenantPK(auth.tenantId);
        await deleteItem(pk, yearSK(yearId));
        return response.success({ deleted: yearId });
    }, AC_YEAR_OPTS,
);

/** POST /ac/academic-years/:yearId/set-active */
export const setActiveAcademicYear = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const yearId = event.pathParameters?.yearId ?? '';
        const pk = Keys.tenantPK(auth.tenantId);
        // Deactivate all years first
        const allYears = await queryAllItems<Record<string, any>>(pk, 'ACYEAR#');
        for (const y of allYears.filter((i) => !i.SK.includes('#TERM#'))) {
            await updateItem(pk, yearSK(y.yearId as string), {
                updateExpression: 'SET isActive = :f, updatedAt = :u',
                expressionAttributeNames: {},
                expressionAttributeValues: { ':f': false, ':u': now() },
            }).catch(() => {});
        }
        await updateItem(pk, yearSK(yearId), {
            updateExpression: 'SET isActive = :t, updatedAt = :u',
            expressionAttributeNames: {},
            expressionAttributeValues: { ':t': true, ':u': now() },
        });
        return response.success({ yearId, isActive: true });
    }, AC_YEAR_OPTS,
);

/** POST /ac/academic-years/:yearId/terms */
export const addTerm = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const yearId = event.pathParameters?.yearId ?? '';
        const body = parseBody<{ name: string; startDate: string; endDate: string }>(event);
        if (!body?.name || !body.startDate || !body.endDate) return response.badRequest('name, startDate, endDate required');
        const pk = Keys.tenantPK(auth.tenantId);
        const termId = uid();
        await putItem({ PK: pk, SK: termSK(yearId, termId), termId, yearId, name: body.name, startDate: body.startDate, endDate: body.endDate, createdAt: now(), entityType: 'TERM' });
        return response.success({ termId, name: body.name }, 201);
    }, AC_YEAR_OPTS,
);

// ============================================================================
// LIBRARY MANAGEMENT (NEW SCHOOL ERP)
// ============================================================================

const AC_LIB_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_LIBRARY_MANAGEMENT,
};

function bookSK(bookId: string) { return `BOOK#${bookId}`; }
function issueSK(issueId: string) { return `BOOKISSUE#${issueId}`; }

/** GET /ac/library/books */
export const listBooks = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const items = await queryAllItems<Record<string, any>>(pk, 'BOOK#');
    return response.success({ books: items.map((i: any) => ({ ...i, id: i.bookId })), total: items.length });
}, AC_LIB_OPTS);

/** POST /ac/library/books */
export const addBook = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<{ title: string; author: string; isbn?: string; copies?: number }>(event);
        if (!body?.title || !body.author) return response.badRequest('title and author required');
        const pk = Keys.tenantPK(auth.tenantId);
        const bookId = uid();
        const copies = body.copies ?? 1;
        await putItem({ PK: pk, SK: bookSK(bookId), bookId, title: body.title, author: body.author, isbn: body.isbn ?? null, totalCopies: copies, availableCopies: copies, createdAt: now(), updatedAt: now(), entityType: 'BOOK' });
        return response.success({ bookId }, 201);
    }, AC_LIB_OPTS,
);

/** DELETE /ac/library/books/:bookId */
export const deleteBook = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const bookId = event.pathParameters?.bookId ?? '';
        await deleteItem(Keys.tenantPK(auth.tenantId), bookSK(bookId));
        return response.success({ deleted: bookId });
    }, AC_LIB_OPTS,
);

/** GET /ac/library/issues */
export const listBookIssues = authorizedHandler([], async (event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const status = event.queryStringParameters?.status ?? 'active';
    const allIssues = await queryAllItems<Record<string, any>>(pk, 'BOOKISSUE#');
    const now_ = new Date();
    const filtered = allIssues.filter((i: any) => {
        if (i.returnedDate) return false;
        if (status === 'overdue') return new Date(i.dueDate) < now_;
        return true;
    });
    return response.success({ issues: filtered.map((i: any) => ({ ...i, id: i.issueId })), total: filtered.length });
}, AC_LIB_OPTS);

/** POST /ac/library/issues */
export const issueBook = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<{ bookId: string; studentName: string; dueDate: string }>(event);
        if (!body?.bookId || !body.studentName || !body.dueDate) return response.badRequest('bookId, studentName, dueDate required');
        const pk = Keys.tenantPK(auth.tenantId);
        const bookItem = await getItem(pk, bookSK(body.bookId));
        if (!bookItem || (bookItem.availableCopies as number) < 1) return response.badRequest('Book not available');
        const issueId = uid();
        // Get book title
        const bookTitle = bookItem.title ?? '';
        await putItem({ PK: pk, SK: issueSK(issueId), issueId, bookId: body.bookId, bookTitle, studentName: body.studentName, issuedDate: now(), dueDate: body.dueDate, finePerDay: 2, returnedDate: null, entityType: 'BOOK_ISSUE' });
        await updateItem(pk, bookSK(body.bookId), {
            updateExpression: 'SET availableCopies = availableCopies - :one, updatedAt = :u',
            expressionAttributeNames: {},
            expressionAttributeValues: { ':one': 1, ':u': now() },
        });
        return response.success({ issueId }, 201);
    }, AC_LIB_OPTS,
);

/** POST /ac/library/issues/:issueId/return */
export const returnBook = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const issueId = event.pathParameters?.issueId ?? '';
        const body = parseBody<{ fineCollected?: number }>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const issue = await getItem(pk, issueSK(issueId));
        if (!issue) return response.notFound('Issue record not found');
        await updateItem(pk, issueSK(issueId), {
            updateExpression: 'SET returnedDate = :rd, fineCollected = :fc, updatedAt = :u',
            expressionAttributeNames: {},
            expressionAttributeValues: { ':rd': now(), ':fc': body?.fineCollected ?? 0, ':u': now() },
        });
        await updateItem(pk, bookSK(issue.bookId as string), {
            updateExpression: 'SET availableCopies = availableCopies + :one, updatedAt = :u',
            expressionAttributeNames: {},
            expressionAttributeValues: { ':one': 1, ':u': now() },
        }).catch(() => {});
        return response.success({ issueId, returned: true });
    }, AC_LIB_OPTS,
);

// ============================================================================
// TRANSPORT MANAGEMENT (NEW SCHOOL ERP)
// ============================================================================

const AC_TRANSPORT_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_TRANSPORT_MANAGEMENT,
};

function routeSK(routeId: string) { return `ROUTE#${routeId}`; }
function stopSK(routeId: string, stopId: string) { return `ROUTE#${routeId}#STOP#${stopId}`; }
function vehicleSK(vehicleId: string) { return `VEHICLE#${vehicleId}`; }

/** GET /ac/transport/routes */
export const listTransportRoutes = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const items = await queryAllItems<Record<string, any>>(pk, 'ROUTE#');
    const routes = items.filter((i) => !i.SK.includes('#STOP#'));
    const stops = items.filter((i) => i.SK.includes('#STOP#'));
    const result = routes.map((r) => ({
        ...r, id: r.routeId,
        stops: stops.filter((s) => s.SK.startsWith(`ROUTE#${r.routeId}#STOP#`)).map((s) => ({ ...s, id: s.stopId })),
    }));
    return response.success({ routes: result, total: result.length });
}, AC_TRANSPORT_OPTS);

/** POST /ac/transport/routes */
export const createTransportRoute = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<{ name: string; driverName?: string; vehicleNumber?: string }>(event);
        if (!body?.name) return response.badRequest('name is required');
        const pk = Keys.tenantPK(auth.tenantId);
        const routeId = uid();
        await putItem({ PK: pk, SK: routeSK(routeId), routeId, name: body.name, driverName: body.driverName ?? null, vehicleNumber: body.vehicleNumber ?? null, studentCount: 0, createdAt: now(), updatedAt: now(), entityType: 'TRANSPORT_ROUTE' });
        return response.success({ routeId }, 201);
    }, AC_TRANSPORT_OPTS,
);

/** PUT /ac/transport/routes/:routeId */
export const updateTransportRoute = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const routeId = event.pathParameters?.routeId ?? '';
        const body = parseBody<{ name?: string; driverName?: string }>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        await updateItem(pk, routeSK(routeId), {
            updateExpression: 'SET #n = :n, driverName = :d, updatedAt = :u',
            expressionAttributeNames: { '#n': 'name' },
            expressionAttributeValues: { ':n': body?.name ?? '', ':d': body?.driverName ?? null, ':u': now() },
        });
        return response.success({ routeId });
    }, AC_TRANSPORT_OPTS,
);

/** DELETE /ac/transport/routes/:routeId */
export const deleteTransportRoute = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const routeId = event.pathParameters?.routeId ?? '';
        await deleteItem(Keys.tenantPK(auth.tenantId), routeSK(routeId));
        return response.success({ deleted: routeId });
    }, AC_TRANSPORT_OPTS,
);

/** POST /ac/transport/routes/:routeId/stops */
export const addTransportStop = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const routeId = event.pathParameters?.routeId ?? '';
        const body = parseBody<{ name: string; pickupTime?: string }>(event);
        if (!body?.name) return response.badRequest('name required');
        const pk = Keys.tenantPK(auth.tenantId);
        const stopId = uid();
        await putItem({ PK: pk, SK: stopSK(routeId, stopId), stopId, routeId, name: body.name, pickupTime: body.pickupTime ?? null, createdAt: now(), entityType: 'TRANSPORT_STOP' });
        return response.success({ stopId }, 201);
    }, AC_TRANSPORT_OPTS,
);

/** GET /ac/transport/vehicles */
export const listVehicles = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const items = await queryAllItems<Record<string, any>>(pk, 'VEHICLE#');
    return response.success({ vehicles: items.map((i: any) => ({ ...i, id: i.vehicleId })), total: items.length });
}, AC_TRANSPORT_OPTS);

/** POST /ac/transport/vehicles */
export const createVehicle = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const body = parseBody<{ number: string; driverName?: string; driverPhone?: string; capacity?: number }>(event);
        if (!body?.number) return response.badRequest('number required');
        const pk = Keys.tenantPK(auth.tenantId);
        const vehicleId = uid();
        await putItem({ PK: pk, SK: vehicleSK(vehicleId), vehicleId, number: body.number, driverName: body.driverName ?? null, driverPhone: body.driverPhone ?? null, capacity: body.capacity ?? 40, isActive: true, createdAt: now(), updatedAt: now(), entityType: 'VEHICLE' });
        return response.success({ vehicleId }, 201);
    }, AC_TRANSPORT_OPTS,
);

// ============================================================================
// REPORT CARDS (NEW SCHOOL ERP)
// ============================================================================

const AC_REPORT_CARD_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_REPORT_CARDS,
};

function reportCardSK(rcId: string) { return `REPORTCARD#${rcId}`; }

/** GET /ac/report-cards */
export const listReportCards = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters ?? {};
    const pk = Keys.tenantPK(auth.tenantId);
    const items = await queryAllItems<Record<string, any>>(pk, 'REPORTCARD#');
    const filtered = items.filter((i: any) => {
        if (p.classId && i.classId !== p.classId) return false;
        if (p.examName && i.examName !== p.examName) return false;
        return true;
    });
    return response.success({ reportCards: filtered.map((i: any) => ({ ...i, id: i.reportCardId })), total: filtered.length });
}, AC_REPORT_CARD_OPTS);

/** POST /ac/report-cards/generate */
export const generateReportCards = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<{ classId: string; examName: string }>(event);
        if (!body?.classId || !body.examName) return response.badRequest('classId and examName required');
        const pk = Keys.tenantPK(auth.tenantId);
        // Fetch all exam results for this class
        const examResults = await queryAllItems<Record<string, any>>(pk, `RESULT#${body.classId}#`);
        const generated: string[] = [];
        for (const result of examResults) {
            const rcId = uid();
            const subjects: any[] = (result.subjects as any[]) ?? [];
            const totalObtained = subjects.reduce((s: number, sub: any) => s + (sub.marksObtained ?? 0), 0);
            const totalMax = subjects.reduce((s: number, sub: any) => s + (sub.maxMarks ?? 100), 0);
            const pct = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;
            const grade = pct >= 90 ? 'A+' : pct >= 75 ? 'A' : pct >= 60 ? 'B+' : pct >= 50 ? 'B' : pct >= 40 ? 'C' : 'F';
            const isPassed = pct >= 33;
            await putItem({
                PK: pk, SK: reportCardSK(rcId), reportCardId: rcId,
                studentId: result.studentId, studentName: result.studentName ?? '',
                classId: body.classId, className: result.className ?? '',
                examName: body.examName, subjects,
                totalMarksObtained: totalObtained, totalMaxMarks: totalMax,
                percentage: Math.round(pct * 10) / 10, grade, isPassed,
                generatedAt: now(), entityType: 'REPORT_CARD',
            });
            generated.push(rcId);
        }
        return response.success({ generated: generated.length, reportCardIds: generated }, 201);
    }, AC_REPORT_CARD_OPTS,
);

/** GET /ac/report-cards/:reportCardId/pdf */
export const getReportCardPdf = authorizedHandler([], async (event, _ctx, auth) => {
    const rcId = event.pathParameters?.reportCardId ?? '';
    const pk = Keys.tenantPK(auth.tenantId);
    const rc = await getItem(pk, reportCardSK(rcId));
    if (!rc) return response.notFound('Report card not found');
    // Return a signed URL if pdfUrl exists, otherwise indicate PDF generation is pending
    return response.success({ pdfUrl: rc.pdfUrl ?? null, reportCard: { ...rc, id: rc.reportCardId } });
}, AC_REPORT_CARD_OPTS);

/** POST /ac/report-cards/:reportCardId/share */
export const shareReportCard = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const rcId = event.pathParameters?.reportCardId ?? '';
        const pk = Keys.tenantPK(auth.tenantId);
        const rc = await getItem(pk, reportCardSK(rcId));
        if (!rc) return response.notFound('Report card not found');
        // Mark as shared
        await updateItem(pk, reportCardSK(rcId), {
            updateExpression: 'SET sharedAt = :s, updatedAt = :u',
            expressionAttributeNames: {},
            expressionAttributeValues: { ':s': now(), ':u': now() },
        });
        return response.success({ reportCardId: rcId, shared: true });
    }, AC_REPORT_CARD_OPTS,
);

// ============================================================================
// CLASSWISE FEE STRUCTURE (NEW SCHOOL ERP)
// ============================================================================

const AC_FEE_STRUCT_OPTS = {
    requiredBusinessType: BusinessType.SCHOOL_ERP,
    requiredFeature: FeatureKey.AC_STUDENT_MANAGEMENT,
};

function feeStructureSK(structureId: string) { return `FEESTRUCT#${structureId}`; }

/** GET /ac/fee-structure?classId=xxx */
export const listFeeStructures = authorizedHandler([], async (event, _ctx, auth) => {
    const classId = event.queryStringParameters?.classId ?? '';
    const pk = Keys.tenantPK(auth.tenantId);
    const items = await queryAllItems<Record<string, any>>(pk, 'FEESTRUCT#');
    const filtered = classId ? items.filter((i) => i.classId === classId) : items;
    return response.success({ structures: filtered.map((i) => ({ ...i, id: i.structureId })), total: filtered.length });
}, AC_FEE_STRUCT_OPTS);

/** POST /ac/fee-structure */
export const createFeeStructure = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const body = parseBody<{ classId: string; feeHead: string; amountRupees: number; frequency: string; dueDayOfMonth?: number; isOptional?: boolean }>(event);
        if (!body?.classId || !body.feeHead || body.amountRupees == null) {
            return response.badRequest('classId, feeHead, amountRupees required');
        }
        const pk = Keys.tenantPK(auth.tenantId);
        const structureId = uid();
        await putItem({
            PK: pk, SK: feeStructureSK(structureId), structureId,
            classId: body.classId, feeHead: body.feeHead,
            amountRupees: body.amountRupees,
            frequency: body.frequency ?? 'monthly',
            dueDayOfMonth: body.dueDayOfMonth ?? null,
            isOptional: body.isOptional ?? false,
            createdAt: now(), updatedAt: now(), entityType: 'FEE_STRUCTURE',
        });
        return response.success({ structureId }, 201);
    }, AC_FEE_STRUCT_OPTS,
);

/** PUT /ac/fee-structure/:structureId */
export const updateFeeStructure = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const structureId = event.pathParameters?.structureId ?? '';
        const body = parseBody<{ feeHead?: string; amountRupees?: number; frequency?: string; dueDayOfMonth?: number; isOptional?: boolean }>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        await updateItem(pk, feeStructureSK(structureId), {
            updateExpression: 'SET feeHead = :fh, amountRupees = :ar, frequency = :fr, dueDayOfMonth = :dd, isOptional = :io, updatedAt = :u',
            expressionAttributeNames: {},
            expressionAttributeValues: {
                ':fh': body?.feeHead ?? '',
                ':ar': body?.amountRupees ?? 0,
                ':fr': body?.frequency ?? 'monthly',
                ':dd': body?.dueDayOfMonth ?? null,
                ':io': body?.isOptional ?? false,
                ':u': now(),
            },
        });
        return response.success({ structureId, updated: true });
    }, AC_FEE_STRUCT_OPTS,
);

/** DELETE /ac/fee-structure/:structureId */
export const deleteFeeStructure = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const structureId = event.pathParameters?.structureId ?? '';
        await deleteItem(Keys.tenantPK(auth.tenantId), feeStructureSK(structureId));
        return response.success({ deleted: structureId });
    }, AC_FEE_STRUCT_OPTS,
);
