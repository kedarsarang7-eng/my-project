/**
 * MobileShop Transport Layer — Barrel Export
 *
 * Lambda API handlers for versioned sale, cancellation, return,
 * and reconciliation operations.
 *
 * Requirements: 3.3–3.11, 6.3–6.13, 6.42, 12.7–12.10
 */

// Route handlers
export {
  finalizeSaleHandler,
  cancelSaleHandler,
  deviceReturnHandler,
  getReconciliationStatusHandler,
} from './sale-routes';

// Response mapping utilities
export {
  mapSaleOutcomeToResponse,
  mapDeterministicOutcomeToResponse,
} from './response-mapper';
