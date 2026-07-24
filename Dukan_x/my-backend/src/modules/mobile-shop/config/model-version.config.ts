/**
 * Model Version Configuration
 *
 * Defines supported data-model versions, migration paths, and compatibility windows.
 * Every authoritative record carries a dataModelVersion; readers use pure adapters
 * for earlier supported versions.
 *
 * Requirements: 6.20, 6.33–6.36
 */

export interface ModelVersionConfig {
  /** Current data model version written by the backend */
  readonly currentVersion: number;
  /** Minimum version the backend can read and upgrade transparently */
  readonly minSupportedVersion: number;
  /** Maximum version (equals currentVersion for forward compat) */
  readonly maxSupportedVersion: number;
  /** Minimum API version the backend accepts from clients */
  readonly minSupportedApiVersion: number;
  /** Current API version */
  readonly currentApiVersion: number;
  /** Versions that have explicit migration/backfill support */
  readonly migrationPaths: readonly MigrationPath[];
  /** Version window for queued offline mutations — older payloads are rejected */
  readonly queuedMutationMaxAge: number;
}

export interface MigrationPath {
  /** Source version */
  readonly from: number;
  /** Target version */
  readonly to: number;
  /** Description of what changed */
  readonly description: string;
  /** Whether this migration can run in-place (lazy on read) vs batch backfill */
  readonly lazyUpgrade: boolean;
}

export const MODEL_VERSION_CONFIG: ModelVersionConfig = {
  currentVersion: 1,
  minSupportedVersion: 1,
  maxSupportedVersion: 1,
  minSupportedApiVersion: 1,
  currentApiVersion: 1,

  // As the schema evolves, add migration paths here:
  migrationPaths: [
    // Example for future use:
    // { from: 1, to: 2, description: 'Add reservation expiry field', lazyUpgrade: true },
  ],

  // Queued mutations older than this version delta are rejected on push
  queuedMutationMaxAge: 1, // Must be within 1 version of current
} as const;
