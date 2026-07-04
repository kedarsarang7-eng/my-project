// ============================================================================
// WhatsApp Automation Module — Low-Stock Alert Service (Task 10.6)
// ============================================================================
// Pure computation logic for low-stock alert hysteresis.
//
// DESIGN CONTRACTS:
// - A low-stock alert fires ONCE when inventory crosses from at/above the
//   threshold to below it.
// - NO further alert fires for the same product (per business) until inventory
//   returns to or above the threshold.
// - Threshold is configurable: 0..999,999 units inclusive.
// - Alerts are scoped per product per business — one product's low stock must
//   not trigger another product's alert.
// - This service is pure computation (deterministic, side-effect-free).
//   The actual DynamoDB hysteresis marker writes (WALOW# prefix) are done by
//   the engine/caller.
//
// Requirements: 11.3
// ============================================================================

// ── Constants ─────────────────────────────────────────────────────────────────

/** Minimum configurable low-stock threshold (inclusive). */
export const MIN_THRESHOLD = 0;

/** Maximum configurable low-stock threshold (inclusive). */
export const MAX_THRESHOLD = 999_999;

// ── Types ─────────────────────────────────────────────────────────────────────

/**
 * Represents the hysteresis state for a single product within a business.
 * The marker is `true` when a low-stock alert has already been fired and the
 * product has NOT yet recovered to/above the threshold.
 */
export interface LowStockHysteresisState {
  /** The business that owns this product. */
  businessId: string;
  /** The product identifier (unique within the business). */
  productId: string;
  /**
   * Whether the hysteresis marker is active (alert already fired, awaiting
   * recovery). `true` = alert was fired and product hasn't recovered yet.
   * `false` or absent = no active marker (ready to fire on next crossing).
   */
  alertFired: boolean;
}

/**
 * Input representing a stock level change event for evaluation.
 */
export interface StockLevelEvent {
  /** The business that owns this product. */
  businessId: string;
  /** The product identifier (unique within the business). */
  productId: string;
  /** The current inventory level (units). */
  currentLevel: number;
  /** The configured low-stock threshold for this product (0..999,999). */
  threshold: number;
}

/**
 * Result of evaluating whether a low-stock alert should fire.
 */
export interface LowStockAlertDecision {
  /** Whether a new low-stock alert should be enqueued. */
  shouldAlert: boolean;
  /**
   * The new hysteresis marker state to persist.
   * - `alertFired: true` — marker is set (alert just fired or was already active)
   * - `alertFired: false` — marker is cleared (product recovered)
   */
  newMarkerState: boolean;
  /** Human-readable reason for the decision (useful for logging). */
  reason: string;
}

// ── Validation ────────────────────────────────────────────────────────────────

/**
 * Validates that a threshold is within the allowed range [0, 999_999].
 * Returns true if the threshold is a finite integer in range.
 */
export function isValidThreshold(threshold: number): boolean {
  return (
    Number.isFinite(threshold) &&
    Number.isInteger(threshold) &&
    threshold >= MIN_THRESHOLD &&
    threshold <= MAX_THRESHOLD
  );
}

/**
 * Validates that an inventory level is a non-negative finite integer.
 */
export function isValidInventoryLevel(level: number): boolean {
  return Number.isFinite(level) && Number.isInteger(level) && level >= 0;
}

// ── Core Hysteresis Logic ─────────────────────────────────────────────────────

/**
 * Evaluates whether a low-stock alert should fire for a given stock level event,
 * applying hysteresis to prevent repeat alerts.
 *
 * Hysteresis behavior:
 * 1. When inventory is BELOW threshold and NO prior alert is active (marker = false):
 *    → Fire alert, set marker to true.
 * 2. When inventory is BELOW threshold and a prior alert IS active (marker = true):
 *    → Do NOT fire again. Marker remains true.
 * 3. When inventory is AT or ABOVE threshold (regardless of marker state):
 *    → Do NOT fire. Clear the marker (set to false) so the next drop below
 *      threshold can trigger a new alert.
 *
 * This is scoped per (businessId, productId) — the caller must supply the
 * correct hysteresis state for the specific product in the specific business.
 *
 * @param event - The stock level change event with current level and threshold.
 * @param currentMarker - The current hysteresis marker state for this product.
 *                        `true` means an alert was previously fired and the
 *                        product hasn't recovered yet. `false` means no active marker.
 * @returns The decision: whether to alert, the new marker state, and a reason.
 */
export function evaluateLowStockAlert(
  event: StockLevelEvent,
  currentMarker: boolean,
): LowStockAlertDecision {
  const { currentLevel, threshold } = event;

  // Case 3: Inventory is at or above threshold → clear the marker (recovery)
  if (currentLevel >= threshold) {
    return {
      shouldAlert: false,
      newMarkerState: false,
      reason: currentMarker
        ? `Inventory recovered to ${currentLevel} (threshold: ${threshold}). Hysteresis marker cleared.`
        : `Inventory at ${currentLevel} is at/above threshold ${threshold}. No action needed.`,
    };
  }

  // Inventory is below threshold (currentLevel < threshold)

  // Case 2: Alert already fired, product hasn't recovered → suppress repeat
  if (currentMarker) {
    return {
      shouldAlert: false,
      newMarkerState: true,
      reason: `Inventory at ${currentLevel} is below threshold ${threshold}, but alert already fired. Suppressed (hysteresis active).`,
    };
  }

  // Case 1: First crossing below threshold → fire alert
  return {
    shouldAlert: true,
    newMarkerState: true,
    reason: `Inventory dropped to ${currentLevel} below threshold ${threshold}. Firing low-stock alert.`,
  };
}

/**
 * Builds the unique hysteresis marker key for a (businessId, productId) pair.
 * This key is used by the caller/engine to store and retrieve the marker from
 * DynamoDB (SK prefix: WALOW#).
 *
 * @param businessId - The business identifier.
 * @param productId - The product identifier within the business.
 * @returns A composite key string scoped to the business and product.
 */
export function buildHysteresisMarkerKey(
  businessId: string,
  productId: string,
): string {
  return `${businessId}#${productId}`;
}

/**
 * Batch-evaluates low-stock alerts for multiple products in a single business.
 * Each product is evaluated independently — one product's state does not affect
 * another's (Req 11.3 per-product scoping).
 *
 * @param events - Array of stock level events (all should share the same businessId
 *                 but each has a distinct productId).
 * @param markerStates - Map of productId → current hysteresis marker state.
 *                       Missing entries are treated as `false` (no active marker).
 * @returns Array of decisions, one per input event, in the same order.
 */
export function evaluateLowStockAlertsBatch(
  events: StockLevelEvent[],
  markerStates: Map<string, boolean>,
): LowStockAlertDecision[] {
  return events.map((event) => {
    const currentMarker = markerStates.get(event.productId) ?? false;
    return evaluateLowStockAlert(event, currentMarker);
  });
}
