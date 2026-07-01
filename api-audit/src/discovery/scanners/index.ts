/**
 * Source scanners (task 4.2).
 *
 * Turns the raw source surface of the repository — application code, serverless
 * / SAM / CloudFormation templates, the OpenAPI document, and GraphQL
 * definitions — into the flat list of `RawEndpoint` sightings consumed by
 * {@link buildInventoryEntries}.
 *
 * Responsibilities are split so that deterministic ordering and per-file
 * parse-error tolerance (task 4.3) can wrap this layer:
 *
 * - {@link collectScanTargets} enumerates the files to scan.
 * - {@link scanTarget} reads and scans a single file, dispatching to the
 *   appropriate scanner by target kind. It throws on read/parse failure so the
 *   caller can record a `StageIssue` per file and continue.
 * - {@link scanSources} is a convenience that scans every target and
 *   concatenates the results, letting failures propagate.
 */
import * as fs from 'fs';
import type { RawEndpoint } from '../dedup';
import { scanCodeFile } from './code-scanner';
import { scanConfigFile } from './config-scanner';
import { scanGraphqlSource } from './graphql-scanner';
import { scanOpenApiFile } from './openapi-scanner';
import {
  collectScanTargets,
  sourceRef,
  type ScanRoots,
  type ScanTarget,
} from './scan-utils';

/**
 * Scan a single target file and return its endpoint sightings.
 *
 * Reads the file from disk and dispatches to the scanner matching the target
 * kind. Any read or parse error propagates to the caller (task 4.3), which is
 * responsible for recording it as a `StageIssue` and continuing the run.
 */
export function scanTarget(target: ScanTarget): RawEndpoint[] {
  const content = fs.readFileSync(target.filePath, 'utf8');

  switch (target.kind) {
    case 'code':
      return scanCodeFile(target.filePath, content);
    case 'config':
      return scanConfigFile(target.filePath, content);
    case 'openapi':
      return scanOpenApiFile(target.filePath, content);
    case 'graphql':
      return scanGraphqlSource(content, sourceRef(target.filePath, 'configuration'));
    default:
      return [];
  }
}

/**
 * Scan every source described by `roots` and return all endpoint sightings.
 *
 * This convenience does not catch per-file errors — that is task 4.3's job; it
 * exists so the scanner layer is usable on its own. Callers that need
 * resilience should iterate {@link collectScanTargets} and call
 * {@link scanTarget} within their own error handling.
 */
export function scanSources(roots: ScanRoots): RawEndpoint[] {
  return collectScanTargets(roots).flatMap(scanTarget);
}

export {
  collectScanTargets,
  collectCodeFiles,
  resolveDefaultScanRoots,
  CODE_SCAN_SUBDIRS,
  HTTP_METHODS,
} from './scan-utils';
export type { ScanRoots, ScanTarget, ScanTargetKind } from './scan-utils';

export { scanCodeFile } from './code-scanner';
export { scanConfigFile } from './config-scanner';
export { scanOpenApiFile } from './openapi-scanner';
export { scanGraphqlSource } from './graphql-scanner';
