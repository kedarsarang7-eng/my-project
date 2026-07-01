/**
 * Property-Based Test: Exactly the five required environments are generated.
 *
 * Feature: api-audit-testing-automation, Property 8: Exactly the five required
 * environments are generated.
 *
 * Validates: Requirements 3.3, 3.4
 *
 * For any API_Catalog, the set of generated Postman environment names equals
 * exactly {Development, Local, Staging, AWS, Production}, and the base URL and
 * auth token values are expressed as named Postman variable references
 * (e.g. `{{DEV_AUTH_TOKEN}}`) — never literal secret or connection values.
 */

import * as fc from 'fast-check';
import {
  generateCollection,
  AUTH_TOKEN_VARIABLE_NAME,
  BASE_URL_VARIABLE_NAME,
} from './collection-generator';
import {
  CatalogEntry,
  Determinable,
  ParamSpec,
  SecurityMeta,
} from '../types';

// ── Generators ───────────────────────────────────────────────────────────────

/**
 * Safe URL-path characters. Excludes whitespace and control characters so the
 * generated catalog is always *representable* — `generateCollection` throws on
 * non-representable endpoints before it builds the environment set, and this
 * property is about the environments that a successful run emits.
 */
const safePathArb = fc
  .array(
    fc.stringOf(
      fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-_'.split('')),
      { minLength: 1, maxLength: 10 }
    ),
    { minLength: 0, maxLength: 4 }
  )
  .map((segments) => '/' + segments.join('/'));

/** Wraps a value generator so it can also be the literal `"undetermined"`. */
function determinableArb<T>(valueArb: fc.Arbitrary<T>): fc.Arbitrary<Determinable<T>> {
  return fc.oneof(fc.constant<Determinable<T>>('undetermined'), valueArb);
}

const methodArb = fc.constantFrom('GET', 'POST', 'PUT', 'PATCH', 'DELETE');

const paramArb: fc.Arbitrary<ParamSpec> = fc.record({
  name: fc.string({ minLength: 1, maxLength: 8 }),
  in: fc.constantFrom('body', 'query', 'path', 'header'),
  type: fc.constantFrom('string', 'number', 'boolean'),
  required: fc.boolean(),
});

const securityArb: fc.Arbitrary<SecurityMeta> = fc.record({
  enforcement: fc.constantFrom('public', 'authenticated', 'authorized'),
});

/** A single representable catalog entry. */
const catalogEntryArb: fc.Arbitrary<CatalogEntry> = fc
  .record({
    id: fc.string({ minLength: 1, maxLength: 12 }),
    urlPath: determinableArb(safePathArb),
    methodOrOperation: determinableArb(methodArb),
    module: determinableArb(fc.string({ minLength: 1, maxLength: 10 })),
    controllerOrHandler: determinableArb(fc.string({ minLength: 1, maxLength: 10 })),
    requestBodyParams: determinableArb(fc.array(paramArb, { maxLength: 3 })),
    queryParams: determinableArb(fc.array(paramArb, { maxLength: 3 })),
    pathParams: determinableArb(fc.array(paramArb, { maxLength: 3 })),
    headers: determinableArb(fc.array(paramArb, { maxLength: 3 })),
    security: securityArb,
    requestSchema: determinableArb(fc.constant({} as Record<string, unknown>)),
    responseSchema: determinableArb(fc.constant({} as Record<string, unknown>)),
    errorResponses: determinableArb(fc.constant([])),
    validationRules: determinableArb(fc.constant([])),
    businessRules: determinableArb(fc.constant([])),
  })
  .map((entry) => ({ ...entry, undeterminedReasons: {} }));

/** An arbitrary API_Catalog (possibly empty). */
const catalogArb = fc.array(catalogEntryArb, { minLength: 0, maxLength: 8 });

// ── Constants ────────────────────────────────────────────────────────────────

/** The exact set of environment names required by Requirement 3.3. */
const REQUIRED_ENVIRONMENT_NAMES = [
  'Development',
  'Local',
  'Staging',
  'AWS',
  'Production',
] as const;

/**
 * A named Postman variable reference, e.g. `{{DEV_AUTH_TOKEN}}`. A value that
 * matches this pattern is a reference, not a literal secret/connection value.
 */
const POSTMAN_VARIABLE_REFERENCE = /^\{\{[^}]+\}\}$/;

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Property 8: Exactly the five required environments are generated', () => {
  it('generates exactly {Development, Local, Staging, AWS, Production} for any catalog', () => {
    fc.assert(
      fc.property(catalogArb, (catalog) => {
        const { environments } = generateCollection(catalog);

        const names = environments.map((env) => env.name);

        // Exactly five environments, no duplicates.
        expect(names).toHaveLength(REQUIRED_ENVIRONMENT_NAMES.length);
        expect(new Set(names).size).toBe(REQUIRED_ENVIRONMENT_NAMES.length);

        // The set of names equals exactly the required set.
        expect(new Set(names)).toEqual(new Set(REQUIRED_ENVIRONMENT_NAMES));
      }),
      { numRuns: 100 }
    );
  });

  it('expresses base URL and auth token as named variable references, never literal values', () => {
    fc.assert(
      fc.property(catalogArb, (catalog) => {
        const { environments } = generateCollection(catalog);

        for (const env of environments) {
          const keys = env.values.map((v) => v.key);
          // Each environment exposes the baseUrl and authToken variables (3.4).
          expect(keys).toContain(BASE_URL_VARIABLE_NAME);
          expect(keys).toContain(AUTH_TOKEN_VARIABLE_NAME);

          // Every value is a Postman variable reference (e.g. {{DEV_AUTH_TOKEN}}),
          // i.e. a named reference rather than a literal secret value (3.4, 3.5).
          for (const { value } of env.values) {
            expect(value).toMatch(POSTMAN_VARIABLE_REFERENCE);
          }
        }
      }),
      { numRuns: 100 }
    );
  });
});
