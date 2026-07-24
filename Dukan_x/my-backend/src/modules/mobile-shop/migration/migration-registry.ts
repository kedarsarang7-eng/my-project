/**
 * Migration Registry — Version Migration Functions
 *
 * Registry of pure, deterministic migration functions that transform a record
 * from one data model version to the next. Each function must be idempotent:
 * applying it to an already-migrated record produces the same output.
 *
 * Requirements: 6.20–6.21, 6.33–6.36
 */

// ─── Types ───────────────────────────────────────────────────────────────────

/** A migration function transforms a record from one version to the next */
export type MigrationFn = (item: Record<string, unknown>) => Record<string, unknown>;

/** Migration step key format: 'v{from}_to_v{to}' */
export type MigrationStepKey = `v${number}_to_v${number}`;

// ─── Registry ────────────────────────────────────────────────────────────────

/**
 * Registry of all version migration functions.
 * Each key is `v{from}_to_v{to}` and the value is a pure function.
 *
 * Rules:
 * - Every function MUST be pure/deterministic (same input → same output)
 * - Every function MUST be idempotent (applying twice yields same result)
 * - Functions MUST NOT perform I/O, network calls, or depend on external state
 * - Functions MUST return a new object (no mutation of input)
 */
export const MIGRATION_REGISTRY: Readonly<Record<MigrationStepKey, MigrationFn>> = {
  // As the schema evolves, add migration functions here:
  // 'v1_to_v2': migrateV1ToV2,
  // 'v2_to_v3': migrateV2ToV3,
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Build a migration step key from source and target versions.
 */
export function buildMigrationKey(from: number, to: number): MigrationStepKey {
  return `v${from}_to_v${to}`;
}

/**
 * Check if a migration function exists for a given step.
 */
export function hasMigration(from: number, to: number): boolean {
  return buildMigrationKey(from, to) in MIGRATION_REGISTRY;
}

/**
 * Get a migration function for a given step.
 * Returns undefined if no migration is registered.
 */
export function getMigration(from: number, to: number): MigrationFn | undefined {
  return MIGRATION_REGISTRY[buildMigrationKey(from, to)];
}
