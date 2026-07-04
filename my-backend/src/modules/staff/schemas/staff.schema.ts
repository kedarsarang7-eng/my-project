// ============================================================================
// Staff Module — Employee / Department / Designation Zod Schemas (Task 3.2)
// ============================================================================
// Fail-closed input validation for the core staff entities. Handlers validate
// every request body against these schemas before any persistence.
//
// PII HANDLING (AD-6)
// -------------------
// The create/update schemas accept PII in PLAINTEXT (aadhaar, pan, passport,
// drivingLicence, bankAccount, upi). The handler encrypts these fields at the
// service boundary (pii-access.service.ts) BEFORE persistence — plaintext PII
// is NEVER stored. Full Aadhaar capture is additionally gated behind an OFF
// feature flag (Req 2.8) enforced in the handler.
//
// Requirements: 2.1 (create employee), 2.2 (Dept/Designation CRUD + deactivate),
// 1.1 (entity data structures).
// ============================================================================

import { z } from 'zod';

// ── Shared primitives ─────────────────────────────────────────────────────────

const statusSchema = z.enum(['active', 'inactive']);

// A non-empty, trimmed string that rejects the '#' key-injection character when
// used as an identifier reference.
const idRef = z
    .string()
    .trim()
    .min(1)
    .max(128)
    .refine((v) => !v.includes('#'), { message: "must not contain '#'" });

const contactSchema = z
    .object({
        phone: z.string().trim().min(1).max(20).optional(),
        email: z.string().trim().email().max(254).optional(),
    })
    .strict()
    .optional();

// PII plaintext inputs — all optional; encrypted at the service boundary.
const piiInputSchema = {
    aadhaar: z.string().trim().min(1).max(20).optional(),
    pan: z.string().trim().min(1).max(20).optional(),
    passport: z.string().trim().min(1).max(20).optional(),
    drivingLicence: z.string().trim().min(1).max(32).optional(),
    bankAccount: z.string().trim().min(1).max(34).optional(),
    upi: z.string().trim().min(1).max(64).optional(),
};

// ── Employee ────────────────────────────────────────────────────────────────

export const employeeCreateSchema = z
    .object({
        fullName: z.string().trim().min(1).max(200),
        designationId: idRef.optional(),
        departmentId: idRef.optional(),
        status: statusSchema.default('active'),
        contact: contactSchema,
        ...piiInputSchema,
    })
    .strict();

// Update: every field optional; at least one must be present.
export const employeeUpdateSchema = z
    .object({
        fullName: z.string().trim().min(1).max(200).optional(),
        designationId: idRef.optional(),
        departmentId: idRef.optional(),
        status: statusSchema.optional(),
        contact: contactSchema,
        ...piiInputSchema,
    })
    .strict()
    .refine((obj) => Object.keys(obj).length > 0, {
        message: 'at least one field is required to update',
    });

export type EmployeeCreateInput = z.infer<typeof employeeCreateSchema>;
export type EmployeeUpdateInput = z.infer<typeof employeeUpdateSchema>;

// ── Department ────────────────────────────────────────────────────────────────

export const departmentCreateSchema = z
    .object({
        name: z.string().trim().min(1).max(200),
        status: statusSchema.default('active'),
    })
    .strict();

export const departmentUpdateSchema = z
    .object({
        name: z.string().trim().min(1).max(200).optional(),
        status: statusSchema.optional(),
    })
    .strict()
    .refine((obj) => Object.keys(obj).length > 0, {
        message: 'at least one field is required to update',
    });

export type DepartmentCreateInput = z.infer<typeof departmentCreateSchema>;
export type DepartmentUpdateInput = z.infer<typeof departmentUpdateSchema>;

// ── Designation ───────────────────────────────────────────────────────────────

export const designationCreateSchema = z
    .object({
        title: z.string().trim().min(1).max(200),
        departmentId: idRef.optional(),
        status: statusSchema.default('active'),
    })
    .strict();

export const designationUpdateSchema = z
    .object({
        title: z.string().trim().min(1).max(200).optional(),
        departmentId: idRef.optional(),
        status: statusSchema.optional(),
    })
    .strict()
    .refine((obj) => Object.keys(obj).length > 0, {
        message: 'at least one field is required to update',
    });

export type DesignationCreateInput = z.infer<typeof designationCreateSchema>;
export type DesignationUpdateInput = z.infer<typeof designationUpdateSchema>;
