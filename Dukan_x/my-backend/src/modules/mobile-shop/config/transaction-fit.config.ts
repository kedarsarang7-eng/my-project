/**
 * Transaction Fit Configuration
 *
 * Defines DynamoDB transaction limits with configurable headroom.
 * The transaction planner uses these values to decide between:
 * - Atomic TransactWriteItems (within limits)
 * - Accepted-pending + Reconciliation_Record (exceeds limits)
 *
 * Requirements: 6.31–6.32
 */

export interface TransactionFitConfig {
  /** DynamoDB service maximum distinct items per TransactWriteItems */
  readonly serviceMaxItems: number;
  /** DynamoDB service maximum aggregate encoded size (bytes) */
  readonly serviceMaxBytes: number;
  /** Configured headroom — max items the application will use */
  readonly configuredMaxItems: number;
  /** Configured headroom — max aggregate size the application will use (bytes) */
  readonly configuredMaxBytes: number;
  /** Safety margin items (difference between service max and configured max) */
  readonly headroomItems: number;
  /** Safety margin bytes */
  readonly headroomBytes: number;
  /**
   * Minimum items required for a typical atomic sale:
   * invoice header + device lines + IMEI state updates + claims + idempotency + audit + change
   */
  readonly typicalSaleItemEstimate: number;
}

export const TRANSACTION_FIT_CONFIG: TransactionFitConfig = {
  // DynamoDB documented limits
  serviceMaxItems: 100,
  serviceMaxBytes: 4 * 1024 * 1024, // 4 MB

  // Application headroom — leave margin for safety
  configuredMaxItems: 80,
  configuredMaxBytes: 3 * 1024 * 1024, // 3 MB

  // Calculated headroom
  headroomItems: 20,
  headroomBytes: 1 * 1024 * 1024, // 1 MB

  // Estimate for preflight planning
  typicalSaleItemEstimate: 12, // header + 2 device lines + 2 IMEI updates + 2 claims + idempotency + audit + change + reservation release + fingerprint
} as const;
