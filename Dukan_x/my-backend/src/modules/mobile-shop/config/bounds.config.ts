/**
 * Operational Bounds Configuration
 *
 * Defines input sizes, value ranges, precision, debounce, and query limits.
 * All monetary values use integer minor units (paise/cents) — no floating point.
 */

export interface BoundsConfig {
  /** IMEI / device identity bounds */
  readonly imei: {
    /** Required digit length after normalization */
    readonly length: number;
    /** Minimum prefix length for catalogue/search (AP-15) */
    readonly minSearchPrefix: number;
  };

  /** Monetary value bounds (integer minor units, e.g. paise) */
  readonly money: {
    /** Minimum allowed minor-unit value (inclusive, usually 0) */
    readonly minMinorUnits: number;
    /** Maximum allowed minor-unit value (inclusive) */
    readonly maxMinorUnits: number;
    /** Minor units per major unit (e.g. 100 for INR paise) */
    readonly minorUnitsPerMajor: number;
  };

  /** Warranty bounds */
  readonly warranty: {
    /** Minimum warranty months (inclusive) */
    readonly minMonths: number;
    /** Maximum warranty months (inclusive) */
    readonly maxMonths: number;
  };

  /** Invoice/sale bounds */
  readonly invoice: {
    /** Maximum device lines per invoice */
    readonly maxDeviceLines: number;
    /** Maximum accessory lines per invoice */
    readonly maxAccessoryLines: number;
    /** Maximum total line items (device + accessory) */
    readonly maxTotalLines: number;
  };

  /** Input string length limits */
  readonly strings: {
    /** Maximum Operation_Id length */
    readonly maxOperationIdLength: number;
    /** Maximum entity ID length */
    readonly maxEntityIdLength: number;
    /** Maximum reason/description length */
    readonly maxReasonLength: number;
    /** Maximum fault description length */
    readonly maxFaultLength: number;
    /** Maximum notes field length */
    readonly maxNotesLength: number;
    /** Maximum correlation ID length */
    readonly maxCorrelationIdLength: number;
  };

  /** Search and filter bounds */
  readonly search: {
    /** Minimum query length to execute search */
    readonly minQueryLength: number;
    /** Maximum query length */
    readonly maxQueryLength: number;
    /** Debounce interval in milliseconds */
    readonly debounceMs: number;
  };

  /** Aggregate child/collection limits */
  readonly aggregates: {
    /** Maximum steps in a reconciliation plan */
    readonly maxReconciliationSteps: number;
    /** Maximum dependencies per outbox mutation */
    readonly maxMutationDependencies: number;
  };
}

export const BOUNDS_CONFIG: BoundsConfig = {
  imei: {
    length: 15,
    minSearchPrefix: 4,
  },

  money: {
    minMinorUnits: 0,
    maxMinorUnits: 999_999_999_99, // 9,99,99,999.99 in INR paise
    minorUnitsPerMajor: 100,
  },

  warranty: {
    minMonths: 1,
    maxMonths: 120, // 10 years
  },

  invoice: {
    maxDeviceLines: 50,
    maxAccessoryLines: 100,
    maxTotalLines: 100,
  },

  strings: {
    maxOperationIdLength: 64,
    maxEntityIdLength: 64,
    maxReasonLength: 500,
    maxFaultLength: 1000,
    maxNotesLength: 2000,
    maxCorrelationIdLength: 64,
  },

  search: {
    minQueryLength: 3,
    maxQueryLength: 200,
    debounceMs: 300,
  },

  aggregates: {
    maxReconciliationSteps: 20,
    maxMutationDependencies: 10,
  },
} as const;
