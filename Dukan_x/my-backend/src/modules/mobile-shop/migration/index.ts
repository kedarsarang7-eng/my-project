/**
 * MobileShop Migration — Barrel Export
 *
 * Version adapters, resumable backfill, migration registry,
 * queued-mutation compatibility, and non-authoritative path
 * documentation for data model evolution and authority tracking.
 *
 * Requirements: 6.20–6.21, 6.33–6.36, 13.3–13.4; 1.4, 2.8, 6.1–6.2, 6.22, 6.24; GR-1.2
 */

// Migration Registry
export {
  MIGRATION_REGISTRY,
  buildMigrationKey,
  hasMigration,
  getMigration,
  type MigrationFn,
  type MigrationStepKey,
} from './migration-registry';

// Version Adapter
export {
  VersionAdapter,
  type VersionAdapterResult,
  type UpgradePath,
  type VersionAdapterError,
} from './version-adapter';

// Resumable Backfill
export {
  ResumableBackfill,
  type BackfillStatus,
  type BackfillParams,
  type BackfillCheckpoint,
  type PageResult,
  type BackfillContext,
} from './resumable-backfill';

// Queued Mutation Compatibility
export {
  QueuedMutationCompat,
  type QueuedMutationCompatResult,
  type QueuedMutation,
} from './queued-mutation-compat';

// Non-Authoritative Paths Documentation (Task 8.4)
export {
  NON_AUTHORITATIVE_PATHS,
  SOLE_DEPLOYMENT_PATH,
  SOLE_AUTHORITATIVE_DATASTORE,
  getVerifiedRemovedPaths,
  getPendingRemovalPaths,
  assertAllPathsDocumented,
  type NonAuthoritativePath,
  type RemovalStatus,
} from './non-authoritative-paths';
