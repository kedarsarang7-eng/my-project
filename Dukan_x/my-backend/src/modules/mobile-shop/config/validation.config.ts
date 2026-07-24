/**
 * Validation Precedence Configuration
 *
 * Defines the order in which validation rules fire and associated field codes.
 * The same precedence is shared by UI, repository, synchronization, and backend
 * enforcement (Requirement 3.12).
 */

/** Validation rule priority — lower number fires first. */
export interface ValidationPrecedenceRule {
  /** Stable rule identifier */
  readonly code: string;
  /** Evaluation order (ascending) */
  readonly priority: number;
  /** Human-readable description */
  readonly description: string;
  /** Associated input field(s) for field-level error association */
  readonly fields: readonly string[];
}

export interface ValidationConfig {
  /** Ordered validation rules for IMEI submission */
  readonly imeiValidation: readonly ValidationPrecedenceRule[];
  /** Ordered validation rules for device-sale submission */
  readonly saleMutation: readonly ValidationPrecedenceRule[];
  /** Ordered validation rules for second-hand intake */
  readonly secondHandIntake: readonly ValidationPrecedenceRule[];
  /** Ordered validation rules for service-job submission */
  readonly serviceJob: readonly ValidationPrecedenceRule[];
  /** Characters treated as presentation separators (removed during normalization) */
  readonly imeiSeparators: readonly string[];
  /** Required IMEI digit length after normalization */
  readonly imeiLength: number;
}

/**
 * Default validation configuration.
 * Override per environment via `createValidationConfig()`.
 */
export const VALIDATION_CONFIG: ValidationConfig = {
  imeiSeparators: ['-', ' ', '.'],
  imeiLength: 15,

  imeiValidation: [
    { code: 'IMEI_REQUIRED', priority: 10, description: 'IMEI field must not be empty', fields: ['imei'] },
    { code: 'IMEI_FORMAT', priority: 20, description: 'Must contain only ASCII digits after separator removal', fields: ['imei'] },
    { code: 'IMEI_LENGTH', priority: 30, description: 'Must be exactly 15 digits after normalization', fields: ['imei'] },
    { code: 'IMEI_LUHN', priority: 40, description: 'Must pass Luhn checksum', fields: ['imei'] },
    { code: 'IMEI_UNIQUENESS', priority: 50, description: 'Must be unique within the tenant scope', fields: ['imei'] },
    { code: 'IMEI_LIFECYCLE', priority: 60, description: 'Must be in a saleable lifecycle state', fields: ['imei'] },
  ],

  saleMutation: [
    { code: 'AUTH_REQUIRED', priority: 1, description: 'Authentication must be valid', fields: [] },
    { code: 'BUSINESS_TYPE_REQUIRED', priority: 2, description: 'Business type must be mobile_shop', fields: [] },
    { code: 'PERMISSION_REQUIRED', priority: 3, description: 'Caller must have sale permission', fields: [] },
    { code: 'TENANT_CONTEXT', priority: 4, description: 'Tenant context must resolve', fields: [] },
    { code: 'SCHEMA_VALID', priority: 5, description: 'Request schema must validate', fields: [] },
    { code: 'OPERATION_ID_PRESENT', priority: 10, description: 'Operation ID must be present', fields: ['operationId'] },
    { code: 'FINGERPRINT_VALID', priority: 11, description: 'Mutation fingerprint must be present and consistent', fields: ['mutationFingerprint'] },
    { code: 'INVOICE_VALID', priority: 20, description: 'Invoice draft must pass validation', fields: ['invoice'] },
    { code: 'DEVICE_LINES_VALID', priority: 30, description: 'Device lines must be non-empty with valid IMEIs', fields: ['deviceLines'] },
    { code: 'VERSIONS_EXPECTED', priority: 40, description: 'Expected entity versions must be present', fields: ['expectedVersions'] },
    { code: 'LIFECYCLE_PRECONDITION', priority: 50, description: 'All IMEIs must be in allowed lifecycle states', fields: ['deviceLines'] },
  ],

  secondHandIntake: [
    { code: 'AUTH_REQUIRED', priority: 1, description: 'Authentication must be valid', fields: [] },
    { code: 'IMEI_VALID', priority: 10, description: 'Normalized IMEI must pass all checks', fields: ['imei'] },
    { code: 'SELLER_IDENTITY', priority: 20, description: 'Seller identity reference must be present', fields: ['sellerId'] },
    { code: 'OWNERSHIP_EVIDENCE', priority: 30, description: 'Ownership evidence status must be present', fields: ['ownershipEvidence'] },
    { code: 'INSPECTION_RESULT', priority: 40, description: 'Inspection result must be recorded', fields: ['inspectionResult'] },
    { code: 'VALUATION_APPROVAL', priority: 50, description: 'Valuation must be approved', fields: ['valuation'] },
    { code: 'POLICY_CHECK', priority: 60, description: 'Device must not be prohibited by documented policy', fields: ['imei'] },
    { code: 'LIFECYCLE_COMPATIBLE', priority: 70, description: 'IMEI must not be active in incompatible state', fields: ['imei'] },
  ],

  serviceJob: [
    { code: 'AUTH_REQUIRED', priority: 1, description: 'Authentication must be valid', fields: [] },
    { code: 'UNIT_OWNED', priority: 10, description: 'IMEI unit must be tenant-owned', fields: ['unitId'] },
    { code: 'CUSTOMER_VALID', priority: 20, description: 'Customer reference must be valid', fields: ['customerId'] },
    { code: 'FAULT_DESCRIBED', priority: 30, description: 'Fault description must be present', fields: ['fault'] },
    { code: 'ESTIMATE_VALID', priority: 40, description: 'Estimate must be a valid minor-unit amount', fields: ['estimateMinorUnits'] },
    { code: 'TECHNICIAN_ASSIGNED', priority: 50, description: 'Technician reference must be present', fields: ['technicianId'] },
    { code: 'WARRANTY_STATUS', priority: 60, description: 'Warranty status must be determined', fields: ['warrantyStatus'] },
  ],
} as const;
