/**
 * Shared scanner utilities (task 4.2).
 *
 * Source scanners turn raw source artifacts (code files, configuration
 * templates, OpenAPI, GraphQL) into `RawEndpoint[]` sightings consumed by
 * {@link buildInventoryEntries}. This module holds the pieces shared across
 * those scanners: the description of where to scan (`ScanRoots`), the
 * filesystem walker that enumerates candidate files, small builders for the
 * different `RawEndpoint` kinds, and the HTTP-method vocabulary.
 *
 * Deterministic ordering of the final inventory and tolerance of unparseable
 * files are intentionally NOT handled here — that is task 4.3. These helpers
 * only enumerate and read; per-file parse errors are allowed to propagate so
 * the surrounding orchestrator (4.3) can catch them and record a `StageIssue`.
 */
import * as fs from 'fs';
import * as path from 'path';
import type { EndpointIdentity, EndpointKind, SourceRef } from '../../types';
import type { RawEndpoint } from '../dedup';

/** HTTP methods recognized across code and configuration scanning. */
export const HTTP_METHODS = [
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'HEAD',
  'OPTIONS',
  'ANY',
] as const;

/** Lower-cased HTTP method names, as they appear in Express-style route calls. */
export const HTTP_METHOD_CALLS = new Set(
  HTTP_METHODS.map((method) => method.toLowerCase()),
);

/**
 * Subdirectories of `my-backend/src` that are scanned for code-level endpoints
 * (Requirement 1.1). Config-only and non-endpoint folders (config, types,
 * utils, __tests__) are deliberately excluded to keep the scan focused.
 */
export const CODE_SCAN_SUBDIRS = [
  'routes',
  'controllers',
  'services',
  'middleware',
  'modules',
  'schemas',
  'websocket',
  'handlers',
  'repositories',
  'search',
  'notifications',
] as const;

/** File extensions treated as scannable source code. */
const CODE_EXTENSIONS = new Set(['.ts', '.js', '.mjs', '.cjs']);

/** Directory names never descended into while walking the tree. */
const IGNORED_DIRS = new Set(['node_modules', 'dist', 'build', '.git', 'coverage']);

/** Description of every place a discovery run should look for endpoints. */
export interface ScanRoots {
  /** Absolute path to `my-backend/src`, scanned by {@link CODE_SCAN_SUBDIRS}. */
  backendSrcDir?: string;
  /** Absolute path to the top-level `lambda/` directory. */
  lambdaDir?: string;
  /** Serverless / SAM / CloudFormation template file paths. */
  configFiles?: string[];
  /** OpenAPI document paths (for example `openapi.yaml`). */
  openApiFiles?: string[];
  /** Standalone GraphQL SDL/operation files (`*.graphql`, `*.gql`). */
  graphqlFiles?: string[];
}

/** The kind of artifact a scan target represents, selecting which scanner runs. */
export type ScanTargetKind = 'code' | 'config' | 'openapi' | 'graphql';

/** A single file queued for scanning together with the scanner to apply. */
export interface ScanTarget {
  filePath: string;
  kind: ScanTargetKind;
}

/** True when a file is a test/declaration file that must not be scanned. */
export function isExcludedSourceFile(filePath: string): boolean {
  const base = path.basename(filePath).toLowerCase();
  if (base.endsWith('.d.ts')) {
    return true;
  }
  if (/\.(test|spec)\.[cm]?[jt]s$/.test(base)) {
    return true;
  }
  // Anything living under a __tests__ / __mocks__ folder.
  return /[\\/]__(tests|mocks)__[\\/]/.test(filePath);
}

/**
 * Recursively list scannable code files under `dir`. Returns an empty list when
 * the directory does not exist so callers need not pre-check. Test and
 * declaration files and ignored directories are skipped. Results are sorted for
 * stable iteration (final inventory ordering remains task 4.3's responsibility).
 */
export function collectCodeFiles(dir: string | undefined): string[] {
  if (!dir || !fs.existsSync(dir)) {
    return [];
  }

  const found: string[] = [];
  const walk = (current: string): void => {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      return; // Unreadable directory: skip it, scanning continues elsewhere.
    }

    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (!IGNORED_DIRS.has(entry.name)) {
          walk(full);
        }
        continue;
      }
      if (!entry.isFile()) {
        continue;
      }
      const ext = path.extname(entry.name).toLowerCase();
      if (CODE_EXTENSIONS.has(ext) && !isExcludedSourceFile(full)) {
        found.push(full);
      }
    }
  };

  walk(dir);
  return found.sort();
}

/**
 * Build the ordered list of files to scan from a set of roots. Code files come
 * from the configured `my-backend/src` subdirectories plus the whole `lambda/`
 * tree; configuration, OpenAPI, and GraphQL files are taken as given.
 */
export function collectScanTargets(roots: ScanRoots): ScanTarget[] {
  const targets: ScanTarget[] = [];

  // Code: only the endpoint-bearing subdirectories of my-backend/src.
  if (roots.backendSrcDir) {
    for (const subdir of CODE_SCAN_SUBDIRS) {
      for (const file of collectCodeFiles(path.join(roots.backendSrcDir, subdir))) {
        targets.push({ filePath: file, kind: 'code' });
      }
    }
  }

  // Code: the entire top-level lambda/ directory.
  for (const file of collectCodeFiles(roots.lambdaDir)) {
    targets.push({ filePath: file, kind: 'code' });
  }

  for (const file of (roots.configFiles ?? []).filter(fs.existsSync).sort()) {
    targets.push({ filePath: file, kind: 'config' });
  }
  for (const file of (roots.openApiFiles ?? []).filter(fs.existsSync).sort()) {
    targets.push({ filePath: file, kind: 'openapi' });
  }
  for (const file of (roots.graphqlFiles ?? []).filter(fs.existsSync).sort()) {
    targets.push({ filePath: file, kind: 'graphql' });
  }

  return targets;
}

/**
 * Resolve a default set of scan roots for the DukanX repository, given its
 * root. Only files/directories that actually exist are included, so missing
 * optional artifacts (a serverless file that is not present, for example) are
 * simply omitted rather than causing a failure.
 */
export function resolveDefaultScanRoots(repoRoot: string): ScanRoots {
  const candidateConfigs = [
    'serverless.yml',
    'serverless.compose.yml',
    'serverless-jewellery-extended.yml',
    'template-payment-api.yaml',
    'template-subscription-api.yaml',
    'template.yaml',
    path.join('cloudformation', 'api-gateway.yml'),
    path.join('cloudformation', 'api-gateway-marketplace.yml'),
  ].map((rel) => path.join(repoRoot, rel));

  return {
    backendSrcDir: path.join(repoRoot, 'my-backend', 'src'),
    lambdaDir: path.join(repoRoot, 'lambda'),
    configFiles: candidateConfigs.filter(fs.existsSync),
    openApiFiles: [path.join(repoRoot, 'openapi.yaml')].filter(fs.existsSync),
    graphqlFiles: [],
  };
}

// ---------------------------------------------------------------------------
// RawEndpoint builders
// ---------------------------------------------------------------------------

/** Build a `SourceRef` for a file with the given artifact type and locator. */
export function sourceRef(
  filePath: string,
  artifactType: SourceRef['artifactType'],
  locator?: string,
): SourceRef {
  return locator === undefined
    ? { filePath, artifactType }
    : { filePath, artifactType, locator };
}

/** Build a REST `RawEndpoint` sighting. */
export function restEndpoint(
  method: string,
  routePath: string,
  source: SourceRef,
): RawEndpoint {
  const identity: EndpointIdentity = {
    kind: 'rest',
    method: method.toUpperCase(),
    path: routePath,
  };
  return { identity, source };
}

/** Build a GraphQL `RawEndpoint` sighting for a query/mutation/subscription. */
export function graphqlEndpoint(
  kind: Extract<EndpointKind, `graphql-${string}`>,
  operationName: string,
  source: SourceRef,
): RawEndpoint {
  return { identity: { kind, operationName }, source };
}

/** Build a WebSocket route `RawEndpoint` sighting (e.g. `$connect`). */
export function wsRouteEndpoint(routeKey: string, source: SourceRef): RawEndpoint {
  return { identity: { kind: 'ws-route', operationName: routeKey }, source };
}

/** Build a WebSocket event `RawEndpoint` sighting (e.g. `inventory.updated`). */
export function wsEventEndpoint(eventName: string, source: SourceRef): RawEndpoint {
  return { identity: { kind: 'ws-event', operationName: eventName }, source };
}

/**
 * De-duplicate raw endpoints discovered within a single source by their
 * identity, so one file that mentions the same route twice contributes a single
 * sighting. Cross-source merging is handled later by {@link buildInventoryEntries}.
 */
export function dedupeWithinSource(rawEndpoints: RawEndpoint[]): RawEndpoint[] {
  const seen = new Set<string>();
  const result: RawEndpoint[] = [];
  for (const raw of rawEndpoints) {
    const { identity } = raw;
    const key = [
      identity.kind,
      (identity.method ?? '').toUpperCase(),
      identity.path ?? '',
      identity.operationName ?? '',
    ].join('|');
    if (!seen.has(key)) {
      seen.add(key);
      result.push(raw);
    }
  }
  return result;
}
