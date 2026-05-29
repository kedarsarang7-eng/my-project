// ============================================================================
// Restaurant Module — Tables Handler
// Domain-split file. Re-exports from resto.ts for clean module boundaries.
// When resto.ts is fully migrated, implement handlers directly here.
// ============================================================================
export { getTables, transferTable, mergeTables, checkoutTable, releaseTable } from '../../resto';
