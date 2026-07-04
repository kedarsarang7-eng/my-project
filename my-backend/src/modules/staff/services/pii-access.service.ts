// ============================================================================
// Staff Module — PII Access Service (Task 3.2)
// ============================================================================
// Role-gated PII field access: encrypts PII before persistence, and controls
// unmasking based on the caller's role.
//
// AD-6 — FIELD-LEVEL ENCRYPTION AT THE SERVICE BOUNDARY
// -----------------------------------------------------
// • On CREATE/UPDATE: encrypts PII plaintext inputs → ciphertext fields.
// • On READ: returns masked values by default. Unmasking requires:
//     - Payroll role for bank account / UPI (Req 2.6)
//     - Granted unmasking role for PAN / Passport / Driving Licence (Req 2.5)
// • Aadhaar: masked with last 4 digits only; full capture gated by feature flag.
//
// AUDIT INTEGRATION POINT (Task 3.3)
// -----------------------------------
// The `unmaskField` method returns an `unmaskEvent` descriptor when a field is
// successfully unmasked. Task 3.3 hooks into this to emit an audit entry.
// This keeps the unmask decision clean and testable without coupling to the
// audit writer (which is not yet wired).
//
// Requirements: 2.1, 2.2, 2.5, 2.6
// ============================================================================

import { UserRole } from '../../../types/tenant.types';
import { encryptField, decryptField, mask, type PiiFieldKind } from './pii-crypto.service';
import { AuthError } from '../../../utils/errors';

// ── PII field → encryption key mapping ──────────────────────────────────────

/** Input PII field names as they arrive from the Zod-validated request body. */
export type PiiInputField =
    | 'aadhaar'
    | 'pan'
    | 'passport'
    | 'drivingLicence'
    | 'bankAccount'
    | 'upi';

/** Encrypted column names persisted in DynamoDB. */
export type PiiEncField =
    | 'aadhaarEnc'
    | 'panEnc'
    | 'passportEnc'
    | 'drivingLicenceEnc'
    | 'bankAccountEnc'
    | 'upiEnc';

/** Mapping from input field name → encrypted column name. */
const INPUT_TO_ENC: Record<PiiInputField, PiiEncField> = {
    aadhaar: 'aadhaarEnc',
    pan: 'panEnc',
    passport: 'passportEnc',
    drivingLicence: 'drivingLicenceEnc',
    bankAccount: 'bankAccountEnc',
    upi: 'upiEnc',
};

/** Mapping from encrypted column → PiiFieldKind for masking. */
const ENC_TO_KIND: Record<PiiEncField, PiiFieldKind> = {
    aadhaarEnc: 'aadhaar',
    panEnc: 'pan',
    passportEnc: 'passport',
    drivingLicenceEnc: 'driving_licence',
    bankAccountEnc: 'bank_account',
    upiEnc: 'upi',
};

// ── Unmasking role rules (Req 2.5, 2.6) ─────────────────────────────────────

/**
 * Roles authorized to unmask each PII field category:
 *   - bank_account, upi → payroll role (ACCOUNTANT, OWNER, ADMIN)
 *   - pan, passport, driving_licence → granted unmasking role (OWNER, ADMIN)
 *   - aadhaar → OWNER only (and only if full-capture flag is ON, enforced elsewhere)
 */
const UNMASK_ROLES: Record<PiiFieldKind, UserRole[]> = {
    bank_account: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    upi: [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    pan: [UserRole.OWNER, UserRole.ADMIN],
    passport: [UserRole.OWNER, UserRole.ADMIN],
    driving_licence: [UserRole.OWNER, UserRole.ADMIN],
    aadhaar: [UserRole.OWNER],
};

// ── Unmask event descriptor (integration point for task 3.3 audit) ─────────

export interface UnmaskEvent {
    field: PiiFieldKind;
    employeeId: string;
    userId: string;
    timestamp: string;
}

// ── Encrypt PII inputs ──────────────────────────────────────────────────────

/**
 * Encrypt all PII plaintext inputs that are present in the data object.
 * Returns a Record of encrypted column names → ciphertext values suitable for
 * merging into the persistence item.
 *
 * This is called by the handler BEFORE calling the repository create/update.
 */
export async function encryptPiiInputs(
    data: Partial<Record<PiiInputField, string | undefined>>,
    tenantId: string,
): Promise<Partial<Record<PiiEncField, string>>> {
    const result: Partial<Record<PiiEncField, string>> = {};

    for (const [inputField, encField] of Object.entries(INPUT_TO_ENC) as [PiiInputField, PiiEncField][]) {
        const value = data[inputField];
        if (value && value.trim().length > 0) {
            result[encField] = await encryptField(value, tenantId);
        }
    }

    return result;
}

// ── Mask PII for default display ──────────────────────────────────────────────

/**
 * Masked representation of an employee's PII fields. This is what READ
 * endpoints return by default. Values are masked strings (e.g. 'XXXXXXXX1234').
 * Fields that were never set are omitted.
 */
export interface MaskedPiiFields {
    aadhaarMasked?: string;
    panMasked?: string;
    passportMasked?: string;
    drivingLicenceMasked?: string;
    bankAccountMasked?: string;
    upiMasked?: string;
}

/**
 * Decrypt and mask all PII fields present in an employee record. Returns the
 * masked representations only (default display, Req 2.3, 2.4, 2.6).
 *
 * This is called on READ paths when no unmasking is requested.
 */
export async function maskEmployeePii(
    encFields: Partial<Record<PiiEncField, string>>,
    tenantId: string,
): Promise<MaskedPiiFields> {
    const result: MaskedPiiFields = {};

    for (const [encField, kind] of Object.entries(ENC_TO_KIND) as [PiiEncField, PiiFieldKind][]) {
        const cipher = encFields[encField];
        if (!cipher) continue;

        const plaintext = await decryptField(cipher, tenantId);
        const maskedKey = `${kind.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase())}Masked` as keyof MaskedPiiFields;
        (result as Record<string, string>)[maskedKey] = mask(plaintext, kind);
    }

    return result;
}

// ── Role-gated unmask ─────────────────────────────────────────────────────────

/**
 * Check whether the caller's role permits unmasking a specific PII field kind.
 */
export function canUnmask(callerRole: UserRole, fieldKind: PiiFieldKind): boolean {
    const allowed = UNMASK_ROLES[fieldKind];
    return allowed.includes(callerRole);
}

/**
 * Unmask a single PII field for an authorized caller. Returns the plaintext
 * value and an `UnmaskEvent` descriptor for audit logging (Task 3.3).
 *
 * @throws AuthError(403) if the caller's role is not authorized.
 */
export async function unmaskField(
    encValue: string,
    tenantId: string,
    fieldKind: PiiFieldKind,
    callerRole: UserRole,
    employeeId: string,
    userId: string,
): Promise<{ value: string; unmaskEvent: UnmaskEvent }> {
    if (!canUnmask(callerRole, fieldKind)) {
        throw new AuthError(
            `Role '${callerRole}' is not authorized to unmask ${fieldKind}`,
            403,
        );
    }

    const plaintext = await decryptField(encValue, tenantId);
    const unmaskEvent: UnmaskEvent = {
        field: fieldKind,
        employeeId,
        userId,
        timestamp: new Date().toISOString(),
    };

    return { value: plaintext, unmaskEvent };
}

/**
 * Build the field-kind from the encrypted column name. Used when the handler
 * receives a request to unmask a specific field.
 */
export function encFieldToKind(encField: PiiEncField): PiiFieldKind {
    return ENC_TO_KIND[encField];
}

/** All PII input fields. */
export const PII_INPUT_FIELDS: PiiInputField[] = Object.keys(INPUT_TO_ENC) as PiiInputField[];

/** All PII encrypted column names. */
export const PII_ENC_FIELDS: PiiEncField[] = Object.values(INPUT_TO_ENC);
