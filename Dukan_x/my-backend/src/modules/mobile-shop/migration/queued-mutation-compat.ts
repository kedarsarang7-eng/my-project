/**
 * Queued Mutation Compatibility — Version Validation & Upgrade
 *
 * Validates queued offline mutations against the supported version window,
 * upgrades payloads when version adapters exist, and rejects mutations with
 * unsupported model versions (returns upgrade-required).
 *
 * Requirements: 6.20–6.21, 6.33–6.36
 */

import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import { VersionAdapter } from './version-adapter';
import type { VersionAdapterError } from './version-adapter';

// ─── Types ───────────────────────────────────────────────────────────────────

export type QueuedMutationCompatResult =
  | { readonly status: 'COMPATIBLE'; readonly payload: Record<string, unknown>; readonly upgraded: boolean }
  | { readonly status: 'UPGRADE_REQUIRED'; readonly reason: string; readonly clientVersion: number }
  | { readonly status: 'REJECTED'; readonly reason: string; readonly error: VersionAdapterError };

export interface QueuedMutation {
  /** The mutation payload */
  readonly payload: Record<string, unknown>;
  /** Data model version the mutation was created with */
  readonly dataModelVersion: number;
  /** Operation ID for idempotency */
  readonly operationId: string;
  /** Mutation fingerprint */
  readonly mutationFingerprint: string;
}

// ─── Queued Mutation Compatibility Checker ───────────────────────────────────

export class QueuedMutationCompat {
  private readonly adapter: VersionAdapter;
  private readonly currentVersion: number;
  private readonly minSupportedVersion: number;
  private readonly maxQueuedAge: number;

  constructor(config?: {
    currentVersion?: number;
    minSupportedVersion?: number;
    maxQueuedAge?: number;
  }) {
    this.currentVersion = config?.currentVersion ?? MODEL_VERSION_CONFIG.currentVersion;
    this.minSupportedVersion = config?.minSupportedVersion ?? MODEL_VERSION_CONFIG.minSupportedVersion;
    this.maxQueuedAge = config?.maxQueuedAge ?? MODEL_VERSION_CONFIG.queuedMutationMaxAge;
    this.adapter = new VersionAdapter({
      currentVersion: this.currentVersion,
      minSupportedVersion: this.minSupportedVersion,
      maxSupportedVersion: this.currentVersion,
    });
  }

  /**
   * Validate a queued mutation's data model version and upgrade if possible.
   *
   * - If the version is current: return COMPATIBLE (no upgrade needed)
   * - If the version is older but within queuedMutationMaxAge and supported:
   *   attempt upgrade using version adapters
   * - If the version is too old or unsupported: return UPGRADE_REQUIRED
   */
  validate(mutation: QueuedMutation): QueuedMutationCompatResult {
    const { dataModelVersion, payload } = mutation;

    // Check if version is a valid integer
    if (!Number.isInteger(dataModelVersion)) {
      return {
        status: 'UPGRADE_REQUIRED',
        reason: `Invalid data model version: ${dataModelVersion}`,
        clientVersion: dataModelVersion,
      };
    }

    // If already at current version, no upgrade needed
    if (dataModelVersion === this.currentVersion) {
      return { status: 'COMPATIBLE', payload, upgraded: false };
    }

    // If version is newer than current (future client?), reject
    if (dataModelVersion > this.currentVersion) {
      return {
        status: 'UPGRADE_REQUIRED',
        reason: `Mutation version ${dataModelVersion} is newer than current backend version ${this.currentVersion}`,
        clientVersion: dataModelVersion,
      };
    }

    // Check age window: mutation must be within configured max age
    const versionDelta = this.currentVersion - dataModelVersion;
    if (versionDelta > this.maxQueuedAge) {
      return {
        status: 'UPGRADE_REQUIRED',
        reason: `Mutation version ${dataModelVersion} is too old (delta ${versionDelta} exceeds max ${this.maxQueuedAge})`,
        clientVersion: dataModelVersion,
      };
    }

    // Check if version is within supported range
    if (!this.adapter.isSupported(dataModelVersion)) {
      return {
        status: 'UPGRADE_REQUIRED',
        reason: `Data model version ${dataModelVersion} is below minimum supported version ${this.minSupportedVersion}`,
        clientVersion: dataModelVersion,
      };
    }

    // Attempt upgrade using version adapter
    const payloadWithVersion = { ...payload, dataModelVersion };
    const result = this.adapter.readAndUpgrade(payloadWithVersion, this.currentVersion);

    if ('error' in result) {
      return {
        status: 'REJECTED',
        reason: result.error.message,
        error: result.error,
      };
    }

    return {
      status: 'COMPATIBLE',
      payload: result.item,
      upgraded: result.upgraded,
    };
  }

  /**
   * Batch validate multiple queued mutations.
   * Returns results in the same order as input.
   */
  validateBatch(mutations: readonly QueuedMutation[]): readonly QueuedMutationCompatResult[] {
    return mutations.map((m) => this.validate(m));
  }

  /**
   * Check if a data model version is acceptable for queued mutations
   * without performing the actual upgrade.
   */
  isAcceptableVersion(version: number): boolean {
    if (!Number.isInteger(version)) return false;
    if (version > this.currentVersion) return false;
    if (version < this.minSupportedVersion) return false;
    const delta = this.currentVersion - version;
    return delta <= this.maxQueuedAge;
  }
}
