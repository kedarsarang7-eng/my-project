/**
 * Property-based test for the Test_Generator's positive-case coverage.
 *
 * Feature: api-audit-testing-automation, Property 13: Positive-case coverage
 * follows endpoint capabilities.
 *
 * Validates: Requirements 5.1, 5.2, 5.3, 5.4
 *
 * For any API_Catalog entry, the generated positive cases must match the
 * endpoint's recorded capabilities:
 *   - a valid-payload / valid-parameters case when it accepts input (5.1);
 *   - a valid-token case when it requires authentication (5.2);
 *   - the applicable create/read/update/delete cases when it participates in
 *     CRUD (5.3); and
 *   - pagination/sorting/filtering/search cases when its query parameters
 *     indicate those capabilities (5.4).
 *
 * The test drives `buildPositiveTests` with catalog entries whose capabilities
 * are independently controlled, then derives the expected set of positive cases
 * from the entry at the requirement level and asserts the generated cases match
 * it exactly — no fabricated cases for unsupported capabilities, and no missing
 * cases for supported ones.
 */

import fc from 'fast-check';

import { buildPositiveTests } from './test-generator';
import {
  CatalogEntry,
  Determinable,
  JsonSchema,
  ParamSpec,
  SecurityMeta,
} from '../types';

// Exact positive-case labels emitted by the Test_Generator (test-generator.ts).
const VALID_PAYLOAD_LABEL = 'Positive: valid payload and parameters are accepted';
const VALID_TOKEN_LABEL = 'Positive: a valid authentication token is accepted';
const crudLabel = (operation: string): string =>
  `Positive: ${operation} operation succeeds`;
const capabilityLabel = (capability: string): string =>
  `Positive: ${capability} parameters are honored`;

// One representative query-parameter name per capability. Each name matches
// exactly one capability's fragment set and none of the others, so the set of
// supported capabilities is fully determined by which of these we include.
const CAPABILITY_PARAM: Record<string, string> = {
  pagination: 'page',
  sorting: 'sort',
  filtering: 'filter',
  search: 'search',
};
// Stable capability ordering, mirroring the generator's deterministic order.
const CAPABILITY_ORDER = ['pagination', 'sorting', 'filtering', 'search'];

/** REST verbs / operation tokens and their requirement-level CRUD mapping. */
const METHOD_TO_CRUD: Record<string, string[]> = {
  GET: ['read'],
  HEAD: ['read'],
  QUERY: ['read'],
  POST: ['create'],
  PUT: ['update'],
  PATCH: ['update'],
  DELETE: ['delete'],
};

const methodArb = fc.constantFrom(
  'GET',
  'HEAD',
  'QUERY',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  // Non-CRUD operations: must contribute no CRUD positive case.
  'mutation',
  'subscription',
  'CONNECT',
  'undetermined',
);

const enforcementArb = fc.constantFrom<SecurityMeta['enforcement']>(
  'public',
  'authenticated',
  'authorized',
);

const paramArb = (name: string, where: ParamSpec['in']): ParamSpec => ({
  name,
  in: where,
  required: false,
});

/**
 * Build a catalog entry whose capability dimensions are independently chosen so
 * the expected positive cases can be derived from those choices directly.
 */
const entryArb: fc.Arbitrary<CatalogEntry> = fc
  .record({
    id: fc.stringMatching(/^[a-z0-9]{1,12}$/),
    method: methodArb,
    enforcement: enforcementArb,
    // Whether the endpoint accepts input via a request body (independent of
    // query params, which are driven by the capability selection below).
    hasBodyParams: fc.boolean(),
    hasRequestSchema: fc.boolean(),
    hasPathParams: fc.boolean(),
    // Subset of query-driven capabilities the endpoint supports.
    capabilities: fc.subarray(CAPABILITY_ORDER, { minLength: 0, maxLength: 4 }),
  })
  .map(
    ({
      id,
      method,
      enforcement,
      hasBodyParams,
      hasRequestSchema,
      hasPathParams,
      capabilities,
    }): CatalogEntry => {
      const queryParams: ParamSpec[] = capabilities.map((cap) =>
        paramArb(CAPABILITY_PARAM[cap], 'query'),
      );

      const requestBodyParams: Determinable<ParamSpec[]> = hasBodyParams
        ? [paramArb('payloadField', 'body')]
        : [];
      const requestSchema: Determinable<JsonSchema> = hasRequestSchema
        ? { type: 'object' }
        : 'undetermined';
      const pathParams: Determinable<ParamSpec[]> = hasPathParams
        ? [paramArb('resourceId', 'path')]
        : [];

      const security: SecurityMeta = { enforcement };

      return {
        id,
        urlPath: '/resource',
        methodOrOperation: method,
        module: 'undetermined',
        controllerOrHandler: 'undetermined',
        requestBodyParams,
        queryParams: queryParams.length > 0 ? queryParams : [],
        pathParams,
        headers: [],
        security,
        requestSchema,
        responseSchema: 'undetermined',
        errorResponses: 'undetermined',
        validationRules: 'undetermined',
        businessRules: 'undetermined',
        undeterminedReasons: {},
      };
    },
  );

/** Requirement-level expected positive-case labels for an entry. */
function expectedPositiveLabels(entry: CatalogEntry): string[] {
  const labels: string[] = [];

  // 5.1 — accepts input via body params, request schema, query params, or path params.
  const bodyParams = entry.requestBodyParams;
  const queryParams = entry.queryParams;
  const pathParams = entry.pathParams;
  const acceptsInput =
    (Array.isArray(bodyParams) && bodyParams.length > 0) ||
    entry.requestSchema !== 'undetermined' ||
    (Array.isArray(queryParams) && queryParams.length > 0) ||
    (Array.isArray(pathParams) && pathParams.length > 0);
  if (acceptsInput) {
    labels.push(VALID_PAYLOAD_LABEL);
  }

  // 5.2 — requires authentication.
  if (
    entry.security.enforcement === 'authenticated' ||
    entry.security.enforcement === 'authorized'
  ) {
    labels.push(VALID_TOKEN_LABEL);
  }

  // 5.3 — applicable CRUD operations.
  const method = entry.methodOrOperation;
  if (method !== 'undetermined') {
    const operations = METHOD_TO_CRUD[method.toUpperCase()] ?? [];
    for (const operation of operations) {
      labels.push(crudLabel(operation));
    }
  }

  // 5.4 — pagination/sorting/filtering/search capabilities, in stable order.
  if (Array.isArray(queryParams) && queryParams.length > 0) {
    const names = new Set(queryParams.map((p) => p.name));
    for (const capability of CAPABILITY_ORDER) {
      if (names.has(CAPABILITY_PARAM[capability])) {
        labels.push(capabilityLabel(capability));
      }
    }
  }

  return labels;
}

/** Extract the `pm.test(...)` label from a generated positive script. */
function labelOf(script: string): string {
  const match = script.match(/pm\.test\((['"])(.*?)\1/);
  return match ? match[2] : '';
}

describe('Feature: api-audit-testing-automation, Property 13: Positive-case coverage follows endpoint capabilities', () => {
  it('generates exactly the positive cases supported by each endpoint capability', () => {
    fc.assert(
      fc.property(entryArb, (entry) => {
        const tests = buildPositiveTests(entry);

        // Every generated positive case is typed 'positive' and bound to the entry.
        for (const test of tests) {
          expect(test.type).toBe('positive');
          expect(test.endpointId).toBe(entry.id);
        }

        const actualLabels = tests.map((t) => labelOf(t.script)).sort();
        const expectedLabels = expectedPositiveLabels(entry).sort();

        // The generated positive cases match the endpoint's capabilities exactly:
        // none fabricated for unsupported capabilities, none missing for supported ones.
        expect(actualLabels).toEqual(expectedLabels);
      }),
      { numRuns: 100 },
    );
  });
});
