/**
 * Version Adapter — Data Model Version Reads/Upgrades
 *
 * Handles reading records with older supported versions and transparently
 * upgrading them to the current version using registered migration functions.
 * For version 1 (current): identity transformation (no-op).
 *
 * Requirements: 6.20–6.21, 6.33–6.36
 */

import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import { getMigration, hasMigration, buildMigrationKey } from './migration-registry';
import type { MigrationFn, MigrationStepKey } from './migration-registry';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface VersionAdapterResult {
  /** The (possibly upgraded) record */
  readonly item: Record<string, unknown>;
  /** Original version found on the record */
  readonly originalVersion: number;
  /** Final version after upgrade */
  readonly currentVersion: number;
  /** Whether any upgrade was applied */
  readonly upgraded: boolean;
  /** Ordered list of migration steps applied */
  readonly appliedSteps: readonly MigrationStepKey[];
}

export interface UpgradePath {
  /** Ordered migration steps from source to target */
  readonly steps: readonly MigrationStepKey[];
  /** Whether all steps have registered migration functions */
  readonly complete: boolean;
  /** Missing step keys (if incomplete) */
  readonly missingSteps: readonly MigrationStepKey[];
}

export type VersionAdapterError =
  | { readonly type: 'VERSION_MISSING'; readonly message: string }
  | { readonly type: 'VERSION_UNSUPPORTED'; readonly message: string; readonly version: number }
  | { readonly type: 'UPGRADE_PATH_INCOMPLETE'; readonly message: string; readonly missingSteps: readonly MigrationStepKey[] }
  | { readonly type: 'MIGRATION_FAILED'; readonly message: string; readonly step: MigrationStepKey; readonly cause: unknown };

// ─── Version Adapter ─────────────────────────────────────────────────────────

export class VersionAdapter {
  private readonly currentVersion: number;
  private readonly minSupportedVersion: number;
  private readonly maxSupportedVersion: number;

  constructor(config?: {
    currentVersion?: number;
    minSupportedVersion?: number;
    maxSupportedVersion?: number;
  }) {
    this.currentVersion = config?.currentVersion ?? MODEL_VERSION_CONFIG.currentVersion;
    this.minSupportedVersion = config?.minSupportedVersion ?? MODEL_VERSION_CONFIG.minSupportedVersion;
    this.maxSupportedVersion = config?.maxSupportedVersion ?? MODEL_VERSION_CONFIG.maxSupportedVersion;
  }

  /**
   * Check whether a data model version is within the supported range.
   */
  isSupported(version: number): boolean {
    return (
      Number.isInteger(version) &&
      version >= this.minSupportedVersion &&
      version <= this.maxSupportedVersion
    );
  }

  /**
   * Get the ordered upgrade path from one version to another.
   * Returns the list of step keys and whether all steps have registered functions.
   */
  getUpgradePath(fromVersion: number, toVersion: number): UpgradePath {
    if (fromVersion >= toVersion) {
      return { steps: [], complete: true, missingSteps: [] };
    }

    const steps: MigrationStepKey[] = [];
    const missingSteps: MigrationStepKey[] = [];

    for (let v = fromVersion; v < toVersion; v++) {
      const key = buildMigrationKey(v, v + 1);
      steps.push(key);
      if (!hasMigration(v, v + 1)) {
        missingSteps.push(key);
      }
    }

    return {
      steps,
      complete: missingSteps.length === 0,
      missingSteps,
    };
  }

  /**
   * Apply migration transformations to upgrade a record from one version to another.
   * Returns the upgraded record without mutating the input.
   */
  upgradeRecord(
    item: Record<string, unknown>,
    fromVersion: number,
    toVersion: number,
  ): { item: Record<string, unknown>; appliedSteps: MigrationStepKey[] } | { error: VersionAdapterError } {
    if (fromVersion >= toVersion) {
      // No upgrade needed — identity transformation
      return { item: { ...item }, appliedSteps: [] };
    }

    const path = this.getUpgradePath(fromVersion, toVersion);
    if (!path.complete) {
      return {
        error: {
          type: 'UPGRADE_PATH_INCOMPLETE',
          message: `Missing migration functions for steps: ${path.missingSteps.join(', ')}`,
          missingSteps: path.missingSteps,
        },
      };
    }

    let current = { ...item };
    const appliedSteps: MigrationStepKey[] = [];

    for (let v = fromVersion; v < toVersion; v++) {
      const migrationFn = getMigration(v, v + 1);
      if (!migrationFn) {
        // Should not happen since we checked path.complete, but defensive
        const key = buildMigrationKey(v, v + 1);
        return {
          error: {
            type: 'UPGRADE_PATH_INCOMPLETE',
            message: `Migration function not found for step: ${key}`,
            missingSteps: [key],
          },
        };
      }

      try {
        current = migrationFn(current);
        appliedSteps.push(buildMigrationKey(v, v + 1));
      } catch (cause) {
        const key = buildMigrationKey(v, v + 1);
        return {
          error: {
            type: 'MIGRATION_FAILED',
            message: `Migration step ${key} failed`,
            step: key,
            cause,
          },
        };
      }
    }

    // Stamp the final version on the record
    current['dataModelVersion'] = toVersion;

    return { item: current, appliedSteps };
  }

  /**
   * Read a record's dataModelVersion and apply the upgrade path if needed.
   * This is the primary entry point for transparent version handling.
   *
   * - If version is current: returns the item unchanged (identity)
   * - If version is older but supported: applies upgrade path
   * - If version is missing or unsupported: returns error
   */
  readAndUpgrade(
    item: Record<string, unknown>,
    targetVersion?: number,
  ): VersionAdapterResult | { error: VersionAdapterError } {
    const target = targetVersion ?? this.currentVersion;
    const recordVersion = item['dataModelVersion'];

    // Version field is required on every authoritative record
    if (recordVersion === undefined || recordVersion === null) {
      return {
        error: {
          type: 'VERSION_MISSING',
          message: 'Record is missing dataModelVersion field',
        },
      };
    }

    const version = Number(recordVersion);
    if (!Number.isInteger(version)) {
      return {
        error: {
          type: 'VERSION_UNSUPPORTED',
          message: `dataModelVersion is not a valid integer: ${recordVersion}`,
          version: NaN,
        },
      };
    }

    // Check if within supported window
    if (!this.isSupported(version)) {
      return {
        error: {
          type: 'VERSION_UNSUPPORTED',
          message: `dataModelVersion ${version} is outside supported range [${this.minSupportedVersion}, ${this.maxSupportedVersion}]`,
          version,
        },
      };
    }

    // If already at target version, return as-is (identity/no-op for v1)
    if (version >= target) {
      return {
        item: { ...item },
        originalVersion: version,
        currentVersion: version,
        upgraded: false,
        appliedSteps: [],
      };
    }

    // Apply upgrade path
    const result = this.upgradeRecord(item, version, target);
    if ('error' in result) {
      return result;
    }

    return {
      item: result.item,
      originalVersion: version,
      currentVersion: target,
      upgraded: true,
      appliedSteps: result.appliedSteps,
    };
  }
}
