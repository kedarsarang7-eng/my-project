/**
 * Discovery_Engine stage.
 *
 * Scans code and configuration sources, classifies endpoints into domains,
 * deduplicates by endpoint identity, and emits the API_Inventory
 * (Requirement 1).
 *
 * This module re-exports the deterministic identity / deduplication /
 * classification core (task 4.1). Source scanners (task 4.2) produce the
 * `RawEndpoint[]` consumed by {@link buildInventoryEntries}, and deterministic
 * ordering plus parse-error tolerance (task 4.3) wrap the result into the final
 * `ApiInventory`.
 */
export {
  computeEndpointId,
  identityKey,
  normalizeIdentity,
  normalizePath,
} from './identity';

export { classifyDomain } from './classification';

export { buildInventoryEntries } from './dedup';
export type { RawEndpoint } from './dedup';

export { discover } from './discover';

export {
  scanSources,
  scanTarget,
  scanCodeFile,
  scanConfigFile,
  scanOpenApiFile,
  scanGraphqlSource,
  collectScanTargets,
  collectCodeFiles,
  resolveDefaultScanRoots,
  CODE_SCAN_SUBDIRS,
  HTTP_METHODS,
} from './scanners';
export type { ScanRoots, ScanTarget, ScanTargetKind } from './scanners';
