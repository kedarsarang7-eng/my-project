// ============================================================================
// Staff Module — Employee CRUD Handler (Task 3.2)
// ============================================================================
// Handles /staff/employees routes (POST, GET, PUT/PATCH, DELETE) with:
//   • Tenant scoping (BusinessID from session only, Req 11.1–11.3)
//   • Zod validation (staff.schema.ts)
//   • PII encryption before persistence (AD-6)
//   • Masked PII on read by default; role-gated unmasking (Req 2.5, 2.6)
//   • Deactivation (soft delete) instead of hard delete
//
// Requirements: 2.1, 2.2, 2.5, 2.6
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError, NotFoundError } from '../../../utils/errors';
import { resolveStaffTenantScope, requirePathId } from './tenant-scope';
import { httpMethod, pathId, parseJsonBody, unmaskFields } from './http';
import { EmployeeRepository } from '../repositories/employee.repository';
import {
    employeeCreateSchema,
    employeeUpdateSchema,
} from '../schemas/staff.schema';
import {
    encryptPiiInputs,
    maskEmployeePii,
    unmaskField,
    encFieldToKind,
    PII_INPUT_FIELDS,
    PII_ENC_FIELDS,
    type PiiInputField,
    type PiiEncField,
    type UnmaskEvent,
} from '../services/pii-access.service';
import { auditUnmaskedReads, writeAuditEntry } from '../services/staff-audit.service';

const STAFF_ROLES: UserRole[] = [
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.MANAGER,
];

const employeeRepo = new EmployeeRepository();

/**
 * Lambda handler for /staff/employees and /staff/employees/{id}.
 */
export const employeeHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const { tenantId, businessId } = tenantContext;
        const method = httpMethod(event);
        const id = pathId(event);

        switch (method) {
            case 'POST':
                return handleCreate(tenantId, businessId, event, auth);
            case 'GET':
                return id
                    ? handleGet(tenantId, businessId, id, event, auth)
                    : handleList(tenantId, businessId, event, auth);
            case 'PUT':
            case 'PATCH':
                return handleUpdate(tenantId, businessId, requirePathId(id), event, auth);
            case 'DELETE':
                return handleDeactivate(tenantId, businessId, requirePathId(id), auth);
            default:
                return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed`);
        }
    },
);

// ── Create ──────────────────────────────────────────────────────────────────

async function handleCreate(
    tenantId: string,
    businessId: string,
    event: APIGatewayProxyEventV2,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const body = parseJsonBody(event);
    const parsed = employeeCreateSchema.parse(body);

    // Encrypt PII fields at the service boundary (AD-6).
    const piiData: Partial<Record<PiiInputField, string | undefined>> = {};
    for (const field of PII_INPUT_FIELDS) {
        if ((parsed as Record<string, unknown>)[field]) {
            piiData[field] = (parsed as Record<string, unknown>)[field] as string;
        }
    }
    const encFields = await encryptPiiInputs(piiData, tenantId);

    // Strip plaintext PII from the data going into the repo (only non-PII fields).
    const repoData = { ...parsed };
    for (const field of PII_INPUT_FIELDS) {
        delete (repoData as Record<string, unknown>)[field];
    }

    // Create the employee with the core fields.
    const employee = await employeeRepo.create(tenantId, businessId, repoData);

    // Persist encrypted PII if any was provided (via update).
    if (Object.keys(encFields).length > 0) {
        await employeeRepo.update(tenantId, businessId, employee.id, encFields);
    }

    // Audit: record employee creation (Req 8.3, Task 11.2).
    await writeAuditEntry(tenantId, businessId, {
        actor: auth.sub,
        action: 'CREATE',
        target: `Employee:${employee.id}`,
    });

    // Return the created employee with masked PII.
    const masked = await maskEmployeePii(encFields as Partial<Record<PiiEncField, string>>, tenantId);
    return response.success(
        { ...stripEncFields(employee), ...masked },
        201,
    );
}

// ── Get single ──────────────────────────────────────────────────────────────

async function handleGet(
    tenantId: string,
    businessId: string,
    id: string,
    event: APIGatewayProxyEventV2,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const employee = await employeeRepo.get(tenantId, businessId, id);
    if (!employee) {
        throw new NotFoundError('Employee');
    }

    // Determine which fields should be unmasked (role-gated, Req 2.5, 2.6).
    const requestedUnmask = unmaskFields(event);
    const unmaskEvents: UnmaskEvent[] = [];
    const unmaskedValues: Record<string, string> = {};

    for (const fieldName of requestedUnmask) {
        const encField = inputToEncField(fieldName);
        if (!encField) continue;
        const cipher = (employee as unknown as Record<string, string | undefined>)[encField];
        if (!cipher) continue;

        const kind = encFieldToKind(encField);
        const { value, unmaskEvent } = await unmaskField(
            cipher,
            tenantId,
            kind,
            auth.role,
            id,
            auth.sub,
        );
        unmaskedValues[fieldName] = value;
        unmaskEvents.push(unmaskEvent);
    }

    // Build masked PII for all fields NOT being unmasked.
    const encFieldsForMask: Partial<Record<PiiEncField, string>> = {};
    for (const encField of PII_ENC_FIELDS) {
        const inputField = encFieldToInputField(encField);
        if (requestedUnmask.includes(inputField)) continue; // will be unmasked
        const val = (employee as unknown as Record<string, string | undefined>)[encField];
        if (val) {
            encFieldsForMask[encField] = val;
        }
    }
    const masked = await maskEmployeePii(encFieldsForMask, tenantId);

    // Task 3.3 — Audit every successful unmasked PII read (Req 2.7).
    // Emit append-only audit entries for each unmasked field. Fire-and-forget
    // to avoid blocking the response — audit failures are logged but do not
    // break the read path.
    if (unmaskEvents.length > 0) {
        (event as unknown as Record<string, unknown>).__unmaskEvents = unmaskEvents;
        // Emit audit entries asynchronously; await to guarantee persistence
        // before responding (audit must be append-only and reliable).
        await auditUnmaskedReads(tenantId, businessId, unmaskEvents);
    }

    return response.success({
        ...stripEncFields(employee),
        ...masked,
        ...unmaskedValues,
    });
}

// ── List ────────────────────────────────────────────────────────────────────

async function handleList(
    tenantId: string,
    businessId: string,
    event: APIGatewayProxyEventV2,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const employees = await employeeRepo.list(tenantId, businessId);

    // Mask PII for all employees in list view (always masked, Req 2.4, 2.6).
    const results = await Promise.all(
        employees.map(async (emp) => {
            const encFieldsForMask: Partial<Record<PiiEncField, string>> = {};
            for (const encField of PII_ENC_FIELDS) {
                const val = (emp as unknown as Record<string, string | undefined>)[encField];
                if (val) {
                    encFieldsForMask[encField] = val;
                }
            }
            const masked = await maskEmployeePii(encFieldsForMask, tenantId);
            return { ...stripEncFields(emp), ...masked };
        }),
    );

    return response.success(results);
}

// ── Update ──────────────────────────────────────────────────────────────────

async function handleUpdate(
    tenantId: string,
    businessId: string,
    id: string,
    event: APIGatewayProxyEventV2,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const body = parseJsonBody(event);
    const parsed = employeeUpdateSchema.parse(body);

    // Encrypt any PII fields present in the update.
    const piiData: Partial<Record<PiiInputField, string | undefined>> = {};
    for (const field of PII_INPUT_FIELDS) {
        if ((parsed as Record<string, unknown>)[field]) {
            piiData[field] = (parsed as Record<string, unknown>)[field] as string;
        }
    }
    const encFields = await encryptPiiInputs(piiData, tenantId);

    // Build update fields: non-PII fields + encrypted PII fields.
    const updateFields: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(parsed)) {
        if (!PII_INPUT_FIELDS.includes(key as PiiInputField) && value !== undefined) {
            updateFields[key] = value;
        }
    }
    Object.assign(updateFields, encFields);

    if (Object.keys(updateFields).length === 0) {
        throw new ValidationError('No updatable fields provided');
    }

    const updated = await employeeRepo.update(tenantId, businessId, id, updateFields);
    if (!updated) {
        throw new NotFoundError('Employee');
    }

    // Audit: record employee update (Req 8.3, Task 11.2).
    await writeAuditEntry(tenantId, businessId, {
        actor: auth.sub,
        action: 'UPDATE',
        target: `Employee:${id}`,
    });

    // Return with masked PII.
    const allEncFields: Partial<Record<PiiEncField, string>> = {};
    for (const encField of PII_ENC_FIELDS) {
        const val = (updated as unknown as Record<string, string | undefined>)[encField];
        if (val) {
            allEncFields[encField] = val;
        }
    }
    const masked = await maskEmployeePii(allEncFields, tenantId);

    return response.success({ ...stripEncFields(updated), ...masked });
}

// ── Deactivate (soft delete) ──────────────────────────────────────────────────

async function handleDeactivate(
    tenantId: string,
    businessId: string,
    id: string,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const success = await employeeRepo.deactivate(tenantId, businessId, id);
    if (!success) {
        throw new NotFoundError('Employee');
    }

    // Audit: record employee deactivation (Req 8.3, Task 11.2).
    await writeAuditEntry(tenantId, businessId, {
        actor: auth.sub,
        action: 'DEACTIVATE',
        target: `Employee:${id}`,
    });

    return response.success({ id, status: 'inactive', deactivated: true });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Strip raw encrypted cipher fields from the response object so they are never
 * exposed to the client. Only masked or unmasked values are returned.
 */
function stripEncFields(employee: unknown): Record<string, unknown> {
    const result = { ...(employee as Record<string, unknown>) };
    for (const field of PII_ENC_FIELDS) {
        delete result[field];
    }
    return result;
}

/** Map a plaintext input field name → its encrypted column name. */
function inputToEncField(inputField: string): PiiEncField | null {
    const map: Record<string, PiiEncField> = {
        aadhaar: 'aadhaarEnc',
        pan: 'panEnc',
        passport: 'passportEnc',
        drivingLicence: 'drivingLicenceEnc',
        bankAccount: 'bankAccountEnc',
        upi: 'upiEnc',
    };
    return map[inputField] ?? null;
}

/** Map an encrypted column name → its plaintext input field name. */
function encFieldToInputField(encField: PiiEncField): string {
    const map: Record<PiiEncField, string> = {
        aadhaarEnc: 'aadhaar',
        panEnc: 'pan',
        passportEnc: 'passport',
        drivingLicenceEnc: 'drivingLicence',
        bankAccountEnc: 'bankAccount',
        upiEnc: 'upi',
    };
    return map[encField];
}
