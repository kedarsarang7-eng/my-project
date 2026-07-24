/**
 * Pagination Configuration
 *
 * Defines page sizes, token expiry, and query limits for DynamoDB bounded queries.
 * Every list uses a configured `Limit` and returns an opaque continuation token.
 *
 * Requirements: 6.14–6.17, 6.29
 */

export interface PaginationConfig {
  /** Default page size when not specified by client */
  readonly defaultPageSize: number;
  /** Maximum allowed page size (client cannot request more) */
  readonly maxPageSize: number;
  /** Minimum allowed page size */
  readonly minPageSize: number;
  /** Continuation token validity (seconds) */
  readonly tokenExpirySeconds: number;
  /** Per-access-pattern overrides (AP-ID → page size) */
  readonly accessPatternDefaults: Readonly<Record<string, number>>;
}

export const PAGINATION_CONFIG: PaginationConfig = {
  defaultPageSize: 25,
  maxPageSize: 100,
  minPageSize: 1,
  tokenExpirySeconds: 5 * 60, // 5 minutes

  accessPatternDefaults: {
    'AP-01': 25,   // Entity aggregate by ID
    'AP-03': 50,   // Units by lifecycle/date
    'AP-04': 25,   // Invoice associations
    'AP-05': 25,   // Customer device history
    'AP-06': 25,   // Service jobs by status/due
    'AP-07': 25,   // Warranty expiry/claim status
    'AP-08': 25,   // Exchanges/intakes/returns/finance by status
    'AP-10': 50,   // Tenant change feed (sync pulls)
    'AP-11': 25,   // Audit timeline
    'AP-12': 10,   // Reconciliation work (worker-only)
    'AP-15': 20,   // Prefix catalogue/search
  },
} as const;
