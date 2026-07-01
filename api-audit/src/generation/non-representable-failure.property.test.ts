/**
 * Property-based test for the Collection_Generator's explicit-failure guarantee
 * on non-representable endpoints.
 *
 * Feature: api-audit-testing-automation, Property 10: Non-representable
 * endpoints fail generation explicitly.
 *
 * Validates: Requirements 3.7
 *
 * For any API_Catalog containing one or more non-representable endpoints, the
 * generation run must fail and record each offending endpoint together with a
 * failure reason. A non-representable endpoint is one whose *determined* URL
 * path carries characters that cannot form a valid Postman request URL —
 * control characters or embedded whitespace (an undetermined path is still
 * representable via the id-based fallback, so it must NOT trigger a failure).
 *
 * We generate mixed catalogs that contain at least one non-representable
 * endpoint and assert that `generateCollection` throws a
 * `CollectionGenerationError` whose `issues` record exactly the offending
 * endpoints (each with a non-empty reason). We also assert the converse: a
 * fully-representable catalog never throws.
 */

import * as fc from 'fast-check';

import {
  generateCollection,
  CollectionGenerationError,
} from './collection-generator';
import { CatalogEntry, Determinable } from '../types';

// ── Generators ───────────────────────────────────────────────────────────────

/** A single URL-safe path segment (no whitespace, no control characters). */
const segmentArb = fc.stringMatching(/^[a-zA-Z][a-zA-Z0-9_-]*$/);

/**
 * A *determined*, well-formed URL path — always representable. The generator
 * can always build a valid Postman request URL from it.
 */
const safePathArb: fc.Arbitrary<Determinable<string>> = fc
  .array(segmentArb, { minLength: 1, maxLength: 4 })
  .map((segs) => `/${segs.join('/')}`);

/**
 * A representable URL-path value: either a well-formed determined path or the
 * literal `"undetermined"` (which the generator resolves to a stable id-based
 * fallback path and is therefore still representable — Requirement 3.6).
 */
const representablePathArb: fc.Arbitrary<Determinable<string>> = fc.oneof(
  safePathArb,
  fc.constant<Determinable<string>>('undetermined')
);

/**
 * Characters that cannot appear in a valid URL: assorted ASCII control
 * characters and whitespace (space, tab, CR, LF).
 */
const badCharArb = fc.constantFrom(
  ' ',
  '\t',
  '\n',
  '\r',
  '\u0001',
  '\u0007',
  '\u001f',
  '\u007f'
);

/**
 * A *determined*, non-representable URL path: a leading slash followed by a
 * word, an embedded bad character, and another word. Surrounding the bad
 * character with word characters guarantees it survives trimming, so the path
 * always contains genuine embedded whitespace / control characters and can
 * never form a valid Postman request URL.
 */
const nonRepresentablePathArb: fc.Arbitrary<Determinable<string>> = fc
  .tuple(segmentArb, badCharArb, segmentArb)
  .map(([head, bad, tail]) => `/${head}${bad}${tail}`);

/**
 * Builds a minimal, valid `CatalogEntry` with the given id and URL path. Every
 * other field is `"undetermined"` so the entry's representability is determined
 * solely by its URL path — keeping the property focused on Requirement 3.7.
 */
function makeEntry(id: string, urlPath: Determinable<string>): CatalogEntry {
  return {
    id,
    urlPath,
    methodOrOperation: 'GET',
    module: 'undetermined',
    controllerOrHandler: 'undetermined',
    requestBodyParams: 'undetermined',
    queryParams: 'undetermined',
    pathParams: 'undetermined',
    headers: 'undetermined',
    security: { enforcement: 'public' },
    requestSchema: 'undetermined',
    responseSchema: 'undetermined',
    errorResponses: 'undetermined',
    validationRules: 'undetermined',
    businessRules: 'undetermined',
    undeterminedReasons: {},
  };
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: api-audit-testing-automation, Property 10: Non-representable endpoints fail generation explicitly', () => {
  it('throws CollectionGenerationError recording exactly the offending endpoints (each with a reason)', () => {
    fc.assert(
      fc.property(
        fc.array(representablePathArb, { minLength: 0, maxLength: 6 }),
        fc.array(nonRepresentablePathArb, { minLength: 1, maxLength: 6 }),
        (representablePaths, nonRepresentablePaths) => {
          // Combine representable and non-representable endpoints, assigning a
          // unique id to each so issues can be matched 1:1 to their endpoint.
          const tagged = [
            ...representablePaths.map((p) => ({ path: p, representable: true })),
            ...nonRepresentablePaths.map((p) => ({ path: p, representable: false })),
          ];
          const catalog = tagged.map((t, i) => makeEntry(`e${i}`, t.path));
          const offendingIds = new Set(
            tagged
              .map((t, i) => (t.representable ? null : `e${i}`))
              .filter((id): id is string => id !== null)
          );

          let thrown: unknown;
          try {
            generateCollection(catalog);
          } catch (err) {
            thrown = err;
          }

          // Generation must fail explicitly for non-representable endpoints.
          expect(thrown).toBeInstanceOf(CollectionGenerationError);

          const { issues } = thrown as CollectionGenerationError;

          // Exactly one issue per offending endpoint, and no representable
          // endpoint is recorded as a failure.
          const issueIds = issues.map((issue) => issue.endpointId);
          expect(new Set(issueIds)).toEqual(offendingIds);
          expect(issues).toHaveLength(offendingIds.size);

          // Each recorded issue identifies its endpoint and carries a
          // non-empty failure reason from the generation stage (Requirement 3.7).
          for (const issue of issues) {
            expect(issue.stage).toBe('generation');
            expect(issue.endpointId).toBeDefined();
            expect(offendingIds.has(issue.endpointId as string)).toBe(true);
            expect(typeof issue.reason).toBe('string');
            expect(issue.reason.length).toBeGreaterThan(0);
          }
        }
      ),
      { numRuns: 100 }
    );
  });

  it('does not throw for a fully-representable catalog', () => {
    fc.assert(
      fc.property(
        fc.array(representablePathArb, { minLength: 0, maxLength: 8 }),
        (representablePaths) => {
          const catalog = representablePaths.map((p, i) => makeEntry(`e${i}`, p));

          expect(() => generateCollection(catalog)).not.toThrow();

          // The successful run yields a collection (sanity check).
          const { collection } = generateCollection(catalog);
          expect(collection.info.schema).toBe('v2.1.0');
        }
      ),
      { numRuns: 100 }
    );
  });
});
