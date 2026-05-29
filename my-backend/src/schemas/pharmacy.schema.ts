// ============================================================================
// Pharmacy Schemas — Zod Validation for Pharmacy Batch Operations
// ============================================================================
// Provides input validation for MEDBATCH# creation and batch deduction.
// ============================================================================

import { z } from 'zod';

// ── Date Validation Helper ──────────────────────────────────────────────────

const isoDateRegex = /^\d{4}-\d{2}-\d{2}$/;
const ncpdpBinRegex = /^\d{6}$/;
const ncpdpPcnRegex = /^[A-Za-z0-9]{2,15}$/;
const memberIdRegex = /^[A-Za-z0-9\-]{3,30}$/;
const groupIdRegex = /^[A-Za-z0-9\-]{1,30}$/;
const ndc11Regex = /^\d{10,11}$/;

// ── MEDBATCH# Creation Schema ───────────────────────────────────────────────

/**
 * Schema for creating a new MEDBATCH# record.
 * Used during drug batch intake (purchase/GRN).
 */
export const createMedBatchSchema = z.object({
    productId: z.string().uuid(),
    batchNumber: z.string()
        .min(1, 'Batch number is required')
        .max(50, 'Batch number must be ≤50 characters')
        .trim(),
    expiryDate: z.string()
        .regex(isoDateRegex, 'Expiry date must be YYYY-MM-DD format')
        .refine(
            (date) => {
                const parsed = new Date(date + 'T00:00:00Z');
                return !isNaN(parsed.getTime());
            },
            { message: 'Invalid expiry date' },
        )
        .refine(
            (date) => {
                const expiry = new Date(date + 'T00:00:00Z');
                const today = new Date();
                const todayUTC = new Date(Date.UTC(
                    today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(),
                ));
                return expiry >= todayUTC;
            },
            { message: 'Cannot create a batch with a past expiry date' },
        ),
    batchStock: z.number()
        .int('Batch stock must be a whole number')
        .positive('Batch stock must be positive'),
    costPricePaise: z.number()
        .int('Cost price must be an integer (paise)')
        .min(0, 'Cost price cannot be negative'),
    productName: z.string().max(200).optional(),
    notes: z.string().max(500).optional(),
});

/**
 * Schema for POST /pharmacy/batch-intake.
 * Creates MEDBATCH# records when a pharmacist receives drug stock.
 */
export const batchIntakeSchema = z.object({
    productId: z.string().uuid(),
    batches: z.array(z.object({
        batchNumber: z.string()
            .min(1, 'Batch number is required')
            .max(50, 'Batch number must be ≤50 characters')
            .trim(),
        expiryDate: z.string()
            .regex(isoDateRegex, 'Expiry date must be YYYY-MM-DD format')
            .refine(
                (date) => {
                    const parsed = new Date(date + 'T00:00:00Z');
                    return !isNaN(parsed.getTime());
                },
                { message: 'Invalid expiry date' },
            )
            .refine(
                (date) => {
                    const expiry = new Date(date + 'T00:00:00Z');
                    const today = new Date();
                    const todayUTC = new Date(Date.UTC(
                        today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(),
                    ));
                    return expiry > todayUTC;
                },
                { message: 'Expiry date must be in the future' },
            ),
        quantityReceived: z.number()
            .int('Quantity must be a whole number')
            .positive('Quantity must be positive'),
        costPricePaise: z.number()
            .int('Cost price must be an integer (paise)')
            .positive('Cost price must be positive'),
        supplierName: z.string().max(200).optional(),
        invoiceRef: z.string().max(100).optional(),
    })).min(1, 'At least one batch is required').max(25, 'Maximum 25 batches per intake'),
    purchaseDate: z.string()
        .regex(isoDateRegex, 'Purchase date must be YYYY-MM-DD format')
        .optional(),
});

// ── Batch Deduction Result Schema (for documentation/response validation) ───

/**
 * Schema describing the result of a FIFO batch deduction.
 * Used for response validation and API documentation.
 */
export const batchDeductionResultSchema = z.object({
    totalDeducted: z.number().int().positive(),
    cogsPaise: z.number().int().min(0),
    batchesDepleted: z.number().int().min(0),
    operations: z.array(z.object({
        batchNumber: z.string(),
        expiryDate: z.string(),
        deductedQty: z.number().int().positive(),
        remainingStock: z.number().int().min(0),
        wasDepleted: z.boolean(),
        costPricePaise: z.number().int().min(0),
    })),
});

// ── Batch Query Schema ──────────────────────────────────────────────────────

/**
 * Schema for querying batch stock status.
 */
export const batchQuerySchema = z.object({
    productId: z.string().uuid().optional(),
    status: z.enum(['active', 'depleted', 'expired']).optional(),
    expiringWithinDays: z.coerce.number().int().min(1).max(365).optional(),
    limit: z.coerce.number().int().min(1).max(200).default(100),
});

// ── Narcotic Drug Register Schemas (NDPS Act compliance) ────────────────────

/** Indian MCI/DMC doctor registration number pattern: XX-NNNNN */
const DOCTOR_REG_PATTERN = /^[A-Z]{2,5}-\d{4,8}$/i;

/**
 * Schema for POST /pharmacy/narcotic-register.
 * All fields are mandatory for Schedule X drugs per NDPS Act.
 */
export const narcoticRegisterSchema = z.object({
    patientName: z.string()
        .min(2, 'Patient name is required (min 2 characters)')
        .max(200),
    patientAddress: z.string()
        .min(5, 'Patient address is required (min 5 characters)')
        .max(500),
    prescribingDoctorName: z.string()
        .min(2, 'Prescribing doctor name is required')
        .max(200),
    doctorRegNo: z.string()
        .regex(
            DOCTOR_REG_PATTERN,
            'Doctor registration number must match XX-NNNNN format (e.g., MCI-12345)',
        ),
    prescriptionId: z.string()
        .min(1, 'Prescription ID is required')
        .max(100),
    drugName: z.string()
        .min(1, 'Drug name is required')
        .max(200),
    quantitySold: z.number()
        .int('Quantity must be a whole number')
        .positive('Quantity must be positive'),
    batchNumber: z.string()
        .min(1, 'Batch number is required')
        .max(50),
    expiryDate: z.string()
        .regex(isoDateRegex, 'Expiry date must be YYYY-MM-DD format'),
    invoiceId: z.string()
        .min(1, 'Invoice ID is required'),
});

/**
 * Schema for GET /pharmacy/narcotic-register query params.
 * Supports date range filtering and pagination.
 */
export const narcoticRegisterQuerySchema = z.object({
    startDate: z.string()
        .regex(isoDateRegex, 'Start date must be YYYY-MM-DD format')
        .optional(),
    endDate: z.string()
        .regex(isoDateRegex, 'End date must be YYYY-MM-DD format')
        .optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
});

/**
 * Schema for GET /pharmacy/narcotic-register/export query params.
 * Uses same date filters as register API and format selection.
 */
export const narcoticRegisterExportQuerySchema = z.object({
    startDate: z.string()
        .regex(isoDateRegex, 'Start date must be YYYY-MM-DD format')
        .optional(),
    endDate: z.string()
        .regex(isoDateRegex, 'End date must be YYYY-MM-DD format')
        .optional(),
    format: z.enum(['json', 'csv', 'pdf']).default('json'),
});

// ── Schedule H1 Register Schemas (D&C Act / CDSCO H1 Register) ──────────────
//
// Schedule H1 drugs (antibiotics, certain habit-forming substances) require
// pharmacies to maintain a 3-year register with patient + prescriber + drug
// + quantity + supply date — per Drugs and Cosmetics Rules, 1945 (H1 Rule).
// ────────────────────────────────────────────────────────────────────────────

/**
 * Schema for POST /pharmacy/h1-register.
 * Mandatory fields per CDSCO H1 register requirements.
 * Standalone insertion — invoice-driven entries are written by the invoice
 * service via buildH1RegisterTransactItem (atomic with the invoice).
 */
export const h1RegisterSchema = z.object({
    patientName: z.string()
        .min(2, 'Patient name is required (min 2 characters)')
        .max(200),
    patientAddress: z.string()
        .min(0)
        .max(500)
        .optional(),
    prescribingDoctorName: z.string()
        .min(2, 'Prescribing doctor name is required')
        .max(200),
    doctorRegNo: z.string()
        .regex(
            DOCTOR_REG_PATTERN,
            'Doctor registration number must match XX-NNNNN format (e.g., MCI-12345)',
        ),
    prescriptionId: z.string()
        .min(1, 'Prescription ID is required')
        .max(100),
    drugName: z.string()
        .min(1, 'Drug name is required')
        .max(200),
    quantitySold: z.number()
        .int('Quantity must be a whole number')
        .positive('Quantity must be positive'),
    batchNumber: z.string()
        .min(1, 'Batch number is required')
        .max(50),
    expiryDate: z.string()
        .regex(isoDateRegex, 'Expiry date must be YYYY-MM-DD format'),
    invoiceId: z.string()
        .min(1, 'Invoice ID is required'),
});

/** Schema for GET /pharmacy/h1-register query params. */
export const h1RegisterQuerySchema = z.object({
    startDate: z.string()
        .regex(isoDateRegex, 'Start date must be YYYY-MM-DD format')
        .optional(),
    endDate: z.string()
        .regex(isoDateRegex, 'End date must be YYYY-MM-DD format')
        .optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
});

/** Schema for GET /pharmacy/h1-register/export query params. */
export const h1RegisterExportQuerySchema = z.object({
    startDate: z.string()
        .regex(isoDateRegex, 'Start date must be YYYY-MM-DD format')
        .optional(),
    endDate: z.string()
        .regex(isoDateRegex, 'End date must be YYYY-MM-DD format')
        .optional(),
    format: z.enum(['json', 'csv', 'pdf']).default('json'),
});

// ── FEFO Override Authorization ─────────────────────────────────────────────

/**
 * Body for POST /pharmacy/fefo-override/authorize.
 *
 * Replaces the previous client-side hardcoded supervisor PIN. The backend
 * validates the supplied PIN against the supervisor user's stored
 * `managerPin`/`overridePin`, ensures the supervisor belongs to the same
 * tenant and has owner/manager privileges, then writes an audit row.
 */
export const fefoOverrideAuthorizeSchema = z.object({
    supervisorPin: z.string().min(4).max(20),
    productId: z.string().min(1).max(100).optional(),
    autoSelectedBatchId: z.string().min(1).max(100).optional(),
    selectedBatchId: z.string().min(1).max(100).optional(),
    reason: z.string().max(500).optional(),
});

/**
 * Schema for POST /pharmacy/prescriptions/refills.
 */
export const refillRequestSchema = z.object({
    prescriptionId: z.string().min(1).max(100),
    productId: z.string().min(1).max(100),
    patientName: z.string().min(2).max(200),
    patientPhone: z.string().min(8).max(20).optional(),
    drugName: z.string().min(1).max(200),
    requestedQty: z.number().int().positive(),
    prescribedQty: z.number().int().positive(),
    notes: z.string().max(500).optional(),
});

/**
 * Schema for GET /pharmacy/prescriptions/refills.
 */
export const refillListQuerySchema = z.object({
    status: z.enum(['requested', 'approved', 'rejected', 'dispensed']).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
    cursor: z.string().min(1).optional(),
});

/**
 * Schema for POST /pharmacy/prescriptions/refills/{id}/status.
 */
export const refillStatusUpdateSchema = z.object({
    status: z.enum(['approved', 'rejected', 'dispensed']),
    reason: z.string().max(300).optional(),
    invoiceId: z.string().max(100).optional(),
    dispensedQty: z.number().int().positive().optional(),
});

/**
 * Schema for POST /pharmacy/prescriptions/refills/backfill.
 * Patches legacy refill rows missing required traceability fields.
 */
export const refillBackfillSchema = z.object({
    refillId: z.string().min(1).max(100),
    productId: z.string().min(1).max(100),
    prescribedQty: z.number().int().positive(),
});

/**
 * Schema for GET /pharmacy/prescriptions/refills/incomplete.
 */
export const refillIncompleteQuerySchema = z.object({
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
    cursor: z.string().min(1).optional(),
});

/**
 * Schema for POST /pharmacy/prescriptions/refills/backfill/bulk.
 */
export const refillBulkBackfillSchema = z.object({
    items: z.array(
        z.object({
            refillId: z.string().min(1).max(100),
            productId: z.string().min(1).max(100),
            prescribedQty: z.number().int().positive(),
        }),
    ).min(1).max(200),
    preview: z.boolean().optional().default(false),
});

/**
 * Schema for POST /pharmacy/prescriptions/partial-fills.
 */
export const partialFillSchema = z.object({
    prescriptionId: z.string().min(1).max(100),
    invoiceId: z.string().min(1).max(100),
    productId: z.string().min(1).max(100),
    productName: z.string().min(1).max(200),
    prescribedQty: z.number().int().positive(),
    dispensedQty: z.number().int().positive(),
    reason: z.string().max(300).optional(),
}).refine((v) => v.dispensedQty <= v.prescribedQty, {
    message: 'dispensedQty cannot exceed prescribedQty',
    path: ['dispensedQty'],
});

/**
 * Schema for POST /pharmacy/claims/transmit.
 * Stores NCPDP D.0 claim payload for payer submission.
 */
export const claimTransmitSchema = z.object({
    patientId: z.string().min(1).max(100),
    prescriptionId: z.string().min(1).max(100),
    pharmacyNpi: z.string().regex(/^\d{10}$/, 'pharmacyNpi must be 10 digits'),
    dateOfService: z.string().regex(isoDateRegex, 'dateOfService must be YYYY-MM-DD format'),
    payerId: z.string().min(1).max(50),
    payerBin: z.string().regex(ncpdpBinRegex, 'payerBin must be 6 digits'),
    payerPcn: z.string().regex(ncpdpPcnRegex, 'payerPcn must be alphanumeric (2-15 chars)'),
    memberId: z.string().regex(memberIdRegex, 'memberId must be 3-30 chars'),
    groupId: z.string().regex(groupIdRegex, 'groupId must be 1-30 chars'),
    dawCode: z.coerce.number().int().min(0).max(9).default(0),
    lines: z.array(z.object({
        productId: z.string().min(1).max(100),
        ndc: z.string().regex(ndc11Regex, 'ndc must be 10 or 11 digits'),
        quantity: z.number().positive(),
        daysSupply: z.number().int().positive().max(365),
        quantityQualifier: z.enum(['EA', 'ML', 'GM']).default('EA'),
        refillNumber: z.coerce.number().int().min(0).max(99).default(0),
    })).min(1).max(20),
    coordinationLevel: z.enum(['primary', 'secondary', 'tertiary']).default('primary'),
    priorAuthId: z.string().min(1).max(100).optional(),
    metadata: z.record(z.string(), z.unknown()).optional(),
});

/**
 * Schema for POST /pharmacy/claims/{id}/adjudicate.
 * Captures real-time payer response.
 */
export const claimAdjudicationSchema = z.object({
    outcome: z.enum(['approved', 'rejected', 'pended']),
    payerClaimRef: z.string().min(1).max(120).optional(),
    rejectCodes: z.array(z.string().min(1).max(20)).max(25).optional(),
    approvedAmountPaise: z.number().int().min(0).optional(),
    patientPayPaise: z.number().int().min(0).optional(),
    notes: z.string().max(500).optional(),
}).superRefine((value, ctx) => {
    if (value.outcome === 'rejected' && (!value.rejectCodes || value.rejectCodes.length === 0)) {
        ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: 'rejectCodes required when outcome is rejected',
            path: ['rejectCodes'],
        });
    }
    if (value.outcome === 'approved') {
        if (value.approvedAmountPaise === undefined) {
            ctx.addIssue({
                code: z.ZodIssueCode.custom,
                message: 'approvedAmountPaise required when outcome is approved',
                path: ['approvedAmountPaise'],
            });
        }
        if (value.patientPayPaise === undefined) {
            ctx.addIssue({
                code: z.ZodIssueCode.custom,
                message: 'patientPayPaise required when outcome is approved',
                path: ['patientPayPaise'],
            });
        }
    }
});

/**
 * Schema for POST /pharmacy/claims/{id}/cob/next.
 * Builds next COB stage claim.
 */
export const claimCobNextSchema = z.object({
    nextPayerId: z.string().min(1).max(50),
    reason: z.string().max(300).optional(),
});

export const claimListQuerySchema = z.object({
    status: z.enum(['submitted', 'approved', 'rejected', 'pended']).optional(),
    coordinationLevel: z.enum(['primary', 'secondary', 'tertiary']).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
    cursor: z.string().min(1).optional(),
});

export const priorAuthCreateSchema = z.object({
    patientId: z.string().min(1).max(100),
    prescriptionId: z.string().min(1).max(100),
    productId: z.string().min(1).max(100),
    payerId: z.string().min(1).max(50),
    reason: z.string().min(3).max(500),
    diagnosisCodes: z.array(z.string().min(1).max(20)).min(1).max(10),
});

export const priorAuthUpdateSchema = z.object({
    status: z.enum(['submitted', 'approved', 'denied', 'expired']),
    authorizationCode: z.string().max(100).optional(),
    notes: z.string().max(500).optional(),
});

export const priorAuthListQuerySchema = z.object({
    status: z.enum(['submitted', 'approved', 'denied', 'expired']).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
    cursor: z.string().min(1).optional(),
});

export const cdsScreenSchema = z.object({
    patient: z.object({
        ageYears: z.number().int().min(0).max(130).optional(),
        pregnant: z.boolean().optional(),
        lactating: z.boolean().optional(),
        allergies: z.array(z.string().min(1).max(120)).optional(),
        diagnoses: z.array(z.string().min(1).max(120)).optional(),
        renalImpairment: z.boolean().optional(),
        hepaticImpairment: z.boolean().optional(),
    }),
    drugs: z.array(z.object({
        productId: z.string().min(1).max(100),
        drugName: z.string().min(1).max(200),
        atc: z.string().min(1).max(20).optional(),
        rxNorm: z.string().min(1).max(50).optional(),
        ndc: z.string().min(1).max(20).optional(),
        dosePerDay: z.number().positive().optional(),
        maxDosePerDay: z.number().positive().optional(),
        ingredients: z.array(z.string().min(1).max(120)).optional(),
        contraindications: z.array(z.string().min(1).max(120)).optional(),
        interactionTags: z.array(z.string().min(1).max(120)).optional(),
        pregnancyRisk: z.enum(['safe', 'caution', 'avoid']).optional(),
        lactationRisk: z.enum(['safe', 'caution', 'avoid']).optional(),
    })).min(1).max(20),
});

export const drugMasterMappingSchema = z.object({
    productId: z.string().min(1).max(100),
    ndc: z.string().min(4).max(20),
    rxNorm: z.string().min(1).max(50),
    atc: z.string().min(1).max(20),
    indiaBrandCode: z.string().min(1).max(80).optional(),
    indiaBrandName: z.string().min(1).max(200).optional(),
    manufacturer: z.string().max(200).optional(),
});

export const formularyUpsertSchema = z.object({
    formularyId: z.string().min(1).max(100),
    payerId: z.string().min(1).max(50),
    name: z.string().min(1).max(200),
    products: z.array(z.object({
        productId: z.string().min(1).max(100),
        tier: z.number().int().min(1).max(6),
        requiresPriorAuth: z.boolean().optional(),
        quantityLimit: z.number().positive().optional(),
        stepTherapy: z.boolean().optional(),
    })).min(1).max(500),
});

export const formularyListQuerySchema = z.object({
    payerId: z.string().min(1).max(50).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
    cursor: z.string().min(1).optional(),
});

export const drugMasterListQuerySchema = z.object({
    productId: z.string().min(1).max(100).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(200).default(50),
    cursor: z.string().min(1).optional(),
});

export const programTrackEventSchema = z.object({
    programType: z.enum(['340B', 'PBM']),
    eventType: z.enum(['accumulate', 'reverse', 'dispense', 'rebill']),
    claimId: z.string().min(1).max(120),
    prescriptionId: z.string().min(1).max(100),
    amountPaise: z.number().int(),
    notes: z.string().max(300).optional(),
});

// ── Type Exports ────────────────────────────────────────────────────────────

export type CreateMedBatchInput = z.infer<typeof createMedBatchSchema>;
export type BatchIntakeInput = z.infer<typeof batchIntakeSchema>;
export type BatchDeductionResult = z.infer<typeof batchDeductionResultSchema>;
export type BatchQueryInput = z.infer<typeof batchQuerySchema>;
export type NarcoticRegisterInput = z.infer<typeof narcoticRegisterSchema>;
export type NarcoticRegisterQuery = z.infer<typeof narcoticRegisterQuerySchema>;
export type NarcoticRegisterExportQuery = z.infer<typeof narcoticRegisterExportQuerySchema>;
export type H1RegisterInput = z.infer<typeof h1RegisterSchema>;
export type H1RegisterQuery = z.infer<typeof h1RegisterQuerySchema>;
export type H1RegisterExportQuery = z.infer<typeof h1RegisterExportQuerySchema>;
export type FefoOverrideAuthorizeInput = z.infer<typeof fefoOverrideAuthorizeSchema>;
export type RefillRequestInput = z.infer<typeof refillRequestSchema>;
export type RefillListQuery = z.infer<typeof refillListQuerySchema>;
export type RefillStatusUpdateInput = z.infer<typeof refillStatusUpdateSchema>;
export type RefillBackfillInput = z.infer<typeof refillBackfillSchema>;
export type RefillIncompleteQueryInput = z.infer<typeof refillIncompleteQuerySchema>;
export type RefillBulkBackfillInput = z.infer<typeof refillBulkBackfillSchema>;
export type PartialFillInput = z.infer<typeof partialFillSchema>;
export type ClaimTransmitInput = z.infer<typeof claimTransmitSchema>;
export type ClaimAdjudicationInput = z.infer<typeof claimAdjudicationSchema>;
export type ClaimCobNextInput = z.infer<typeof claimCobNextSchema>;
export type ClaimListQueryInput = z.infer<typeof claimListQuerySchema>;
export type PriorAuthCreateInput = z.infer<typeof priorAuthCreateSchema>;
export type PriorAuthUpdateInput = z.infer<typeof priorAuthUpdateSchema>;
export type PriorAuthListQueryInput = z.infer<typeof priorAuthListQuerySchema>;
export type CdsScreenInput = z.infer<typeof cdsScreenSchema>;
export type DrugMasterMappingInput = z.infer<typeof drugMasterMappingSchema>;
export type FormularyUpsertInput = z.infer<typeof formularyUpsertSchema>;
export type FormularyListQueryInput = z.infer<typeof formularyListQuerySchema>;
export type DrugMasterListQueryInput = z.infer<typeof drugMasterListQuerySchema>;
export type ProgramTrackEventInput = z.infer<typeof programTrackEventSchema>;
