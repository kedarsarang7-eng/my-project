// ============================================================================
// Staff Module — Employee Repository (Task 3.2)
// ============================================================================
// CRUD + deactivate for Employee entities on the DynamoDB single table.
//
// PII HANDLING (AD-6)
// -------------------
// PII fields (aadhaarEnc, panEnc, passportEnc, drivingLicenceEnc, bankAccountEnc,
// upiEnc) are stored as CIPHERTEXT. Encryption happens at the handler/service
// boundary BEFORE this repository is called — this layer persists whatever values
// it receives. Masking and role-gated unmasking are handled by the PII access
// service (pii-access.service.ts), not here.
//
// SK: EMP#{id}
// ============================================================================

import {
    buildEmployeeKeys,
    EMP_SK_PREFIX,
    STAFF_ENTITY_TYPE,
    type StaffEntityKeys,
    type StaffEntityType,
} from '../keys';
import { BaseRepository, type BaseItem } from './base.repository';
import type { EmployeeCreateInput } from '../schemas/staff.schema';

// ── Domain type returned from the repository ──────────────────────────────────

export interface Employee {
    id: string;
    businessId: string;
    fullName: string;
    designationId?: string;
    departmentId?: string;
    status: 'active' | 'inactive';
    contact?: { phone?: string; email?: string };
    // PII cipher fields — present only when the record was created/updated with PII.
    aadhaarEnc?: string;
    panEnc?: string;
    passportEnc?: string;
    drivingLicenceEnc?: string;
    bankAccountEnc?: string;
    upiEnc?: string;
    createdAt: string;
    updatedAt: string;
}

type EmployeeItem = BaseItem & Employee;

export class EmployeeRepository extends BaseRepository<Employee, EmployeeCreateInput> {
    protected readonly entityType: StaffEntityType = STAFF_ENTITY_TYPE.EMPLOYEE;
    protected readonly skPrefix = EMP_SK_PREFIX;

    protected buildKeys(
        tenantId: string,
        businessId: string,
        id: string,
        extras?: Record<string, string>,
    ): StaffEntityKeys {
        const isoDate = extras?.isoDate ?? new Date().toISOString();
        return buildEmployeeKeys(tenantId, businessId, id, isoDate);
    }

    protected toDomain(item: BaseItem & Record<string, unknown>): Employee {
        return {
            id: item.id,
            businessId: item.businessId,
            fullName: item.fullName as string,
            designationId: item.designationId as string | undefined,
            departmentId: item.departmentId as string | undefined,
            status: (item.status as 'active' | 'inactive') ?? 'active',
            contact: item.contact as { phone?: string; email?: string } | undefined,
            aadhaarEnc: item.aadhaarEnc as string | undefined,
            panEnc: item.panEnc as string | undefined,
            passportEnc: item.passportEnc as string | undefined,
            drivingLicenceEnc: item.drivingLicenceEnc as string | undefined,
            bankAccountEnc: item.bankAccountEnc as string | undefined,
            upiEnc: item.upiEnc as string | undefined,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
        };
    }

    protected buildCreateItem(
        tenantId: string,
        businessId: string,
        id: string,
        keys: StaffEntityKeys,
        data: EmployeeCreateInput,
        now: string,
    ): BaseItem & Record<string, unknown> {
        return {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: this.entityType,
            tenantId,
            businessId,
            id,
            fullName: data.fullName,
            designationId: data.designationId,
            departmentId: data.departmentId,
            status: data.status ?? 'active',
            contact: data.contact,
            // PII cipher fields are NOT set here — they are set via update()
            // after encryption at the handler level (pii-access.service.ts).
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        };
    }
}
