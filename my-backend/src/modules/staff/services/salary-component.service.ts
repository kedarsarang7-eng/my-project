// ============================================================================
// Staff Module — Salary Component Service (Task 9.4)
// ============================================================================
// Wraps all salary-component mutations with audit-before-write semantics.
//
// CRITICAL INVARIANT (Req 6.8, Property 22):
// ------------------------------------------
// Every salary change MUST be audited BEFORE the change takes effect. The
// `auditSalaryChange` helper in staff-audit.service.ts is awaited prior to
// any DynamoDB write that modifies SalaryComponent.amountPaise.
//
// This service provides:
//   - createSalaryComponent  → audit(before=undefined, after=new) then persist
//   - updateSalaryComponent  → audit(before=current, after=new) then persist
//   - deleteSalaryComponent  → audit(before=current, after=undefined) then persist
//
// All operations are tenant + business scoped via the standard partition key.
// Money is always stored as integer paise (no floats).
//
// Requirements: 6.8
// ============================================================================

import { randomUUID } from 'crypto';
import { putItem, getItem, updateItem } from '../../../config/dynamodb.config';
import { businessPK } from '../../../dynamodb/keys';
import {
    buildSalaryComponentKeys,
    salaryComponentSK,
} from '../repositories/payroll.keys';
import { salaryComponentSchema, type SalaryComponentType } from '../schemas/payroll.schema';
import { auditSalaryChange } from './staff-audit.service';

// ── Types ────────────────────────────────────────────────────────────────────

export interface CreateSalaryComponentInput {
    tenantId: string;
    businessId: string;
    employeeId: string;
    type: SalaryComponentType;
    amountPaise: number;
    approverId: string;
    meta?: Record<string, unknown>;
}

export interface UpdateSalaryComponentInput {
    tenantId: string;
    businessId: string;
    employeeId: string;
    componentId: string;
    amountPaise: number;
    approverId: string;
    meta?: Record<string, unknown>;
}

export interface DeleteSalaryComponentInput {
    tenantId: string;
    businessId: string;
    employeeId: string;
    componentId: string;
    approverId: string;
}

export interface SalaryComponentRecord {
    id: string;
    businessId: string;
    employeeId: string;
    type: SalaryComponentType;
    amountPaise: number;
    meta?: Record<string, unknown>;
    createdAt: string;
    updatedAt: string;
}

// ── Create ───────────────────────────────────────────────────────────────────

/**
 * Create a new salary component. Audits BEFORE persisting (Req 6.8).
 *
 * Flow:
 *   1. Validate input via Zod schema
 *   2. Write audit entry (before=undefined, after=amountPaise)
 *   3. Persist the salary component item
 */
export async function createSalaryComponent(
    input: CreateSalaryComponentInput,
): Promise<SalaryComponentRecord> {
    const componentId = randomUUID();
    const now = new Date().toISOString();

    // Validate input
    salaryComponentSchema.parse({
        id: componentId,
        businessId: input.businessId,
        employeeId: input.employeeId,
        type: input.type,
        amountPaise: input.amountPaise,
        meta: input.meta,
    });

    // AUDIT BEFORE WRITE (Req 6.8, Property 22)
    await auditSalaryChange(
        input.tenantId,
        input.businessId,
        input.employeeId,
        undefined,           // beforePaise — new component, no prior value
        input.amountPaise,   // afterPaise
        input.approverId,
    );

    // Persist the salary component
    const keys = buildSalaryComponentKeys(
        input.tenantId,
        input.businessId,
        input.employeeId,
        componentId,
    );

    const item = {
        PK: keys.PK,
        SK: keys.SK,
        GSI1PK: keys.GSI1PK,
        GSI1SK: keys.GSI1SK,
        entityType: 'STAFF_SALCOMP',
        tenantId: input.tenantId,
        businessId: input.businessId,
        id: componentId,
        employeeId: input.employeeId,
        type: input.type,
        amountPaise: input.amountPaise,
        ...(input.meta ? { meta: input.meta } : {}),
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
    };

    await putItem(item as unknown as Record<string, unknown>);

    return {
        id: componentId,
        businessId: input.businessId,
        employeeId: input.employeeId,
        type: input.type,
        amountPaise: input.amountPaise,
        meta: input.meta,
        createdAt: now,
        updatedAt: now,
    };
}

// ── Update ───────────────────────────────────────────────────────────────────

/**
 * Update an existing salary component's amount. Audits BEFORE persisting (Req 6.8).
 *
 * Flow:
 *   1. Read current value (to capture `beforePaise`)
 *   2. Write audit entry (before=current, after=new)
 *   3. Persist the updated amount
 *
 * Throws if the component does not exist.
 */
export async function updateSalaryComponent(
    input: UpdateSalaryComponentInput,
): Promise<SalaryComponentRecord> {
    const pk = businessPK(input.tenantId, input.businessId);
    const sk = salaryComponentSK(input.employeeId, input.componentId);

    // Read current value to capture beforePaise
    const existing = await getItem<Record<string, unknown>>(pk, sk);
    if (!existing) {
        throw new Error(
            `SALARY_COMPONENT_NOT_FOUND: No salary component found for employee=${input.employeeId}, component=${input.componentId}`,
        );
    }

    const beforePaise = existing.amountPaise as number;

    // No-op if amount unchanged (skip audit + write)
    if (beforePaise === input.amountPaise) {
        return {
            id: existing.id as string,
            businessId: existing.businessId as string,
            employeeId: existing.employeeId as string,
            type: existing.type as SalaryComponentType,
            amountPaise: beforePaise,
            meta: existing.meta as Record<string, unknown> | undefined,
            createdAt: existing.createdAt as string,
            updatedAt: existing.updatedAt as string,
        };
    }

    // AUDIT BEFORE WRITE (Req 6.8, Property 22)
    await auditSalaryChange(
        input.tenantId,
        input.businessId,
        input.employeeId,
        beforePaise,
        input.amountPaise,
        input.approverId,
    );

    // Persist the update
    const now = new Date().toISOString();
    const updated = await updateItem(pk, sk, {
        updateExpression: 'SET amountPaise = :amt, updatedAt = :now' +
            (input.meta ? ', meta = :meta' : ''),
        expressionAttributeValues: {
            ':amt': input.amountPaise,
            ':now': now,
            ...(input.meta ? { ':meta': input.meta } : {}),
        },
    });

    return {
        id: (updated?.id ?? existing.id) as string,
        businessId: input.businessId,
        employeeId: input.employeeId,
        type: (updated?.type ?? existing.type) as SalaryComponentType,
        amountPaise: input.amountPaise,
        meta: (updated?.meta ?? input.meta ?? existing.meta) as Record<string, unknown> | undefined,
        createdAt: (updated?.createdAt ?? existing.createdAt) as string,
        updatedAt: now,
    };
}

// ── Delete (soft) ────────────────────────────────────────────────────────────

/**
 * Soft-delete a salary component. Audits BEFORE persisting (Req 6.8).
 *
 * Flow:
 *   1. Read current value (to capture `beforePaise`)
 *   2. Write audit entry (before=current, after=undefined)
 *   3. Mark the component as deleted
 *
 * Throws if the component does not exist.
 */
export async function deleteSalaryComponent(
    input: DeleteSalaryComponentInput,
): Promise<void> {
    const pk = businessPK(input.tenantId, input.businessId);
    const sk = salaryComponentSK(input.employeeId, input.componentId);

    // Read current value to capture beforePaise
    const existing = await getItem<Record<string, unknown>>(pk, sk);
    if (!existing) {
        throw new Error(
            `SALARY_COMPONENT_NOT_FOUND: No salary component found for employee=${input.employeeId}, component=${input.componentId}`,
        );
    }

    const beforePaise = existing.amountPaise as number;

    // AUDIT BEFORE WRITE (Req 6.8, Property 22)
    await auditSalaryChange(
        input.tenantId,
        input.businessId,
        input.employeeId,
        beforePaise,
        undefined, // afterPaise — deletion, no new value
        input.approverId,
    );

    // Soft-delete the component
    const now = new Date().toISOString();
    await updateItem(pk, sk, {
        updateExpression: 'SET isDeleted = :del, updatedAt = :now',
        expressionAttributeValues: {
            ':del': true,
            ':now': now,
        },
    });
}
