/**
 * Discovery_Engine entry point (task 4.3).
 *
 * Wraps the source scanners (task 4.2) and the deduplication / classification
 * core (task 4.1) into the final `ApiInventory`. This layer owns the two
 * guarantees the lower layers deliberately left to it:
 *
 * - **Deterministic ordering (Requirement 1.9):** entries are sorted by their
 *   stable `id`, so a discovery run over an unchanged codebase produces an
 *   equivalent inventory on every run.
 * - **Parse-error tolerance (Requirement 1.10):** each file is scanned inside
 *   its own try/catch. An unparseable (or unreadable) file contributes exactly
 *   one `StageIssue` recording the file path and the error, and scanning
 *   continues with the remaining sources.
 */
import type { ApiInventory, StageIssue } from '../types';
import type { RawEndpoint } from './dedup';
import { buildInventoryEntries } from './dedup';
import { collectScanTargets, scanTarget } from './scanners';
import type { ScanRoots } from './scanners';

/** The stage name recorded on issues raised during discovery. */
const STAGE_NAME = 'discovery';

/**
 * Discover every endpoint reachable from `roots` and return the deduplicated,
 * deterministically ordered `ApiInventory`.
 *
 * Files that cannot be read or parsed are skipped with a recorded
 * `StageIssue`; they never abort the run.
 */
export function discover(roots: ScanRoots): ApiInventory {
  const rawEndpoints: RawEndpoint[] = [];
  const issues: StageIssue[] = [];

  for (const target of collectScanTargets(roots)) {
    try {
      rawEndpoints.push(...scanTarget(target));
    } catch (error) {
      issues.push({
        stage: STAGE_NAME,
        filePath: target.filePath,
        reason: describeError(error),
      });
    }
  }

  const entries = buildInventoryEntries(rawEndpoints).sort((a, b) =>
    a.id < b.id ? -1 : a.id > b.id ? 1 : 0,
  );

  return { entries, issues };
}

/** Render an unknown thrown value as a stable, human-readable reason string. */
function describeError(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}
