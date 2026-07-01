/**
 * Property-based test for the Test_Generator's metadata-driven test attachment.
 *
 * Feature: api-audit-testing-automation, Property 12: Metadata-driven test
 * attachment.
 *
 * Validates: Requirements 4.3, 4.4, 4.5, 4.6
 *
 * For any API_Catalog entry the Test_Generator attaches exactly the
 * metadata-driven tests that the recorded metadata supports — and nothing more.
 * Concretely, a test of a given kind is attached if and only if its driving
 * metadata is present:
 *   - a schema-validation test iff a response schema is recorded (4.3);
 *   - an authentication-enforcement test iff authentication (or authorization)
 *     is required, and an authorization-enforcement test iff authorization is
 *     required (4.4);
 *   - one null/empty/invalid-input test per recorded validation rule, and none
 *     when no validation rules are recorded (4.5);
 *   - one business-rule test per recorded business rule, and none when no
 *     business rules are recorded (4.6).
 *
 * The test drives the real attachment path: it builds a collection whose
 * requests reference the catalog entries by id, runs the Test_Generator's
 * `attachTests` over it, and asserts the metadata-driven tests landed on each
 * request match the entry's metadata exactly. Baseline, positive, and negative
 * tests carry distinct `type` tags, so filtering on the metadata test types
 * isolates the behavior under test.
 */

import fc from 'fast-check';

import { attachTests } from './test-generator';
import {
  BusinessRule,
  CatalogEntry,
  Determinable,
  GeneratedTest,
  JsonSchema,
  PostmanCollection,
  SecurityMeta,
  ValidationRule,
} from '../types';

// The metadata-driven test types (design.md → GeneratedTest). These are emitted
// only by the metadata pass; baseline/positive/negative passes use disjoint
// type tags, so filtering on these isolates Property 12's behavior.
const METADATA_TYPES = new Set<GeneratedTest['type']>([
  'schema',
  'auth',
  'authz',
  'validation',
  'business-rule',
]);

/** A concrete (determined) response schema, or the literal `"undetermined"`. */
const responseSchemaArb: fc.Arbitrary<Determinable<JsonSchema>> = fc.oneof(
  fc.constant<Determinable<JsonSchema>>('undetermined'),
  fc.record({
    type: fc.constant('object'),
    properties: fc.constant<Record<string, unknown>>({}),
  }),
);

/** Security metadata spanning all three enforcement levels (Requirement 4.4). */
const securityArb: fc.Arbitrary<SecurityMeta> = fc.oneof(
  fc.record<SecurityMeta>({ enforcement: fc.constant('public') }),
  fc.record<SecurityMeta>({ enforcement: fc.constant('authenticated') }),
  fc.record<SecurityMeta>({
    enforcement: fc.constant('authorized'),
    requiredPermission: fc.string({ minLength: 1, maxLength: 12 }),
  }),
);

const validationRuleArb: fc.Arbitrary<ValidationRule> = fc.record({
  field: fc.string({ minLength: 1, maxLength: 12 }),
  rule: fc.string({ minLength: 1, maxLength: 12 }),
});

const businessRuleArb: fc.Arbitrary<BusinessRule> = fc.record({
  id: fc.string({ minLength: 1, maxLength: 8 }),
  description: fc.string({ minLength: 1, maxLength: 20 }),
});

/**
 * Validation rules that are either `"undetermined"` or a concrete array. Empty
 * arrays are included so the "present iff non-empty" boundary (Requirement 4.5)
 * is exercised: an empty rule set drives zero validation tests.
 */
const validationRulesArb: fc.Arbitrary<Determinable<ValidationRule[]>> =
  fc.oneof(
    fc.constant<Determinable<ValidationRule[]>>('undetermined'),
    fc.array(validationRuleArb, { maxLength: 4 }),
  );

/** Business rules that are either `"undetermined"`, empty, or non-empty (4.6). */
const businessRulesArb: fc.Arbitrary<Determinable<BusinessRule[]>> = fc.oneof(
  fc.constant<Determinable<BusinessRule[]>>('undetermined'),
  fc.array(businessRuleArb, { maxLength: 4 }),
);

/**
 * A catalog entry whose Property-12-relevant fields (response schema, security,
 * validation rules, business rules) vary freely. The remaining fields are held
 * at `"undetermined"`/empty so they contribute no positive or negative tests
 * that could be confused with the metadata-driven tests under test. The `id` is
 * assigned later so every entry in a catalog is uniquely addressable.
 */
const partialEntryArb = fc.record({
  responseSchema: responseSchemaArb,
  security: securityArb,
  validationRules: validationRulesArb,
  businessRules: businessRulesArb,
});

type PartialEntry = {
  responseSchema: Determinable<JsonSchema>;
  security: SecurityMeta;
  validationRules: Determinable<ValidationRule[]>;
  businessRules: Determinable<BusinessRule[]>;
};

/** Materialize a full CatalogEntry with a unique id and inert other fields. */
function toCatalogEntry(partial: PartialEntry, id: string): CatalogEntry {
  return {
    id,
    urlPath: 'undetermined',
    methodOrOperation: 'undetermined',
    module: 'undetermined',
    controllerOrHandler: 'undetermined',
    requestBodyParams: 'undetermined',
    queryParams: 'undetermined',
    pathParams: 'undetermined',
    headers: 'undetermined',
    security: partial.security,
    requestSchema: 'undetermined',
    responseSchema: partial.responseSchema,
    errorResponses: 'undetermined',
    validationRules: partial.validationRules,
    businessRules: partial.businessRules,
    undeterminedReasons: {},
  };
}

/** A catalog of uniquely-identified entries derived from the partial entries. */
const catalogArb: fc.Arbitrary<CatalogEntry[]> = fc
  .array(partialEntryArb, { minLength: 0, maxLength: 12 })
  .map((partials) =>
    partials.map((partial, index) => toCatalogEntry(partial, `endpoint-${index}`)),
  );

/**
 * Build a minimal v2.1 collection with exactly one request per catalog entry,
 * referencing the entry by id. The Test_Generator looks up metadata by
 * `endpointId`, so this is the input shape the metadata pass consumes.
 */
function buildCollection(catalog: CatalogEntry[]): PostmanCollection {
  return {
    info: { schema: 'v2.1.0' },
    folders: [
      {
        name: 'Internal-Service',
        items: catalog.map((entry) => ({
          name: `request-${entry.id}`,
          endpointId: entry.id,
          method: 'GET',
          url: '{{baseUrl}}/x',
        })),
      },
    ],
  };
}

/** True when a Determinable schema field holds a concrete schema object. */
function schemaIsPresent(schema: Determinable<JsonSchema>): boolean {
  return schema !== 'undetermined' && typeof schema === 'object' && schema !== null;
}

/** Count of recorded rules for a Determinable rule array (empty/undetermined => 0). */
function ruleCount<T>(rules: Determinable<T[]>): number {
  return rules === 'undetermined' ? 0 : rules.length;
}

describe('Feature: api-audit-testing-automation, Property 12: Metadata-driven test attachment', () => {
  it('attaches schema/auth/authz/validation/business-rule tests iff the corresponding metadata is present', () => {
    fc.assert(
      fc.property(catalogArb, (catalog) => {
        const { collection } = attachTests(buildCollection(catalog), catalog);

        // Index every request's attached tests by the endpoint it represents.
        const testsByEndpoint = new Map<string, GeneratedTest[]>();
        for (const folder of collection.folders) {
          for (const request of folder.items) {
            testsByEndpoint.set(request.endpointId, request.tests ?? []);
          }
        }

        for (const entry of catalog) {
          const attached = testsByEndpoint.get(entry.id) ?? [];
          const metadataTests = attached.filter((t) => METADATA_TYPES.has(t.type));
          const countOf = (type: GeneratedTest['type']) =>
            metadataTests.filter((t) => t.type === type).length;

          // Every metadata test must be tagged to this endpoint (4.3-4.6).
          for (const test of metadataTests) {
            expect(test.endpointId).toBe(entry.id);
          }

          // 4.3 — exactly one schema test iff a response schema is recorded.
          const expectedSchema = schemaIsPresent(entry.responseSchema) ? 1 : 0;
          expect(countOf('schema')).toBe(expectedSchema);

          // 4.4 — auth test iff auth is required; authz test iff authz required.
          const requiresAuthn =
            entry.security.enforcement === 'authenticated' ||
            entry.security.enforcement === 'authorized';
          const requiresAuthz = entry.security.enforcement === 'authorized';
          expect(countOf('auth')).toBe(requiresAuthn ? 1 : 0);
          expect(countOf('authz')).toBe(requiresAuthz ? 1 : 0);

          // 4.5 — one input-handling test per recorded validation rule.
          expect(countOf('validation')).toBe(ruleCount(entry.validationRules));

          // 4.6 — one business-rule test per recorded business rule.
          expect(countOf('business-rule')).toBe(ruleCount(entry.businessRules));

          // The metadata pass attaches nothing beyond the five accounted-for
          // kinds, so the iff is total: no stray metadata tests appear.
          const accountedFor =
            countOf('schema') +
            countOf('auth') +
            countOf('authz') +
            countOf('validation') +
            countOf('business-rule');
          expect(metadataTests.length).toBe(accountedFor);
        }
      }),
      { numRuns: 100 },
    );
  });
});
