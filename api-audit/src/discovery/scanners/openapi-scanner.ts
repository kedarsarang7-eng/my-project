/**
 * OpenAPI scanner (task 4.2, Requirement 1.3).
 *
 * Parses an OpenAPI document (`openapi.yaml`) and emits one REST `RawEndpoint`
 * per declared path + HTTP method, attaching the operation identifier as the
 * source locator when present.
 *
 * The document is parsed directly with the `yaml` library and the `paths`
 * object is read structurally. This keeps the scan synchronous, deterministic,
 * and resilient: an unrecognized or partially invalid document still yields the
 * paths it can read, and a genuinely unparseable file throws for task 4.3 to
 * record. (Full schema validation/dereferencing via `swagger-parser` is a
 * separate concern handled by the Documentation_Engine, not discovery.)
 */
import { parse as parseYaml } from 'yaml';
import type { RawEndpoint } from '../dedup';
import { dedupeWithinSource, restEndpoint, sourceRef } from './scan-utils';

/** HTTP methods that may appear as keys under an OpenAPI path item. */
const OPENAPI_METHODS = new Set([
  'get',
  'post',
  'put',
  'patch',
  'delete',
  'head',
  'options',
  'trace',
]);

/** Extract REST endpoints from the contents of an OpenAPI document. */
export function scanOpenApiFile(filePath: string, content: string): RawEndpoint[] {
  const document = parseYaml(content) as unknown;
  if (!isRecord(document)) {
    return [];
  }

  const paths = document.paths;
  if (!isRecord(paths)) {
    return [];
  }

  const raw: RawEndpoint[] = [];

  for (const [routePath, pathItem] of Object.entries(paths)) {
    if (!isRecord(pathItem)) {
      continue;
    }
    for (const [method, operation] of Object.entries(pathItem)) {
      if (!OPENAPI_METHODS.has(method.toLowerCase())) {
        continue;
      }
      const operationId =
        isRecord(operation) && typeof operation.operationId === 'string'
          ? operation.operationId
          : undefined;

      raw.push(
        restEndpoint(method, routePath, sourceRef(filePath, 'configuration', operationId)),
      );
    }
  }

  return dedupeWithinSource(raw);
}

/** Narrow an unknown value to a plain object record. */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
