/**
 * Property-based test for the Discovery_Engine's deduplication and source
 * merging guarantee.
 *
 * Feature: api-audit-testing-automation, Property 3: Discovery deduplicates and
 * merges sources.
 *
 * Validates: Requirements 1.8
 *
 * For any set of raw discovered endpoints, `buildInventoryEntries` must produce
 * exactly one entry per distinct endpoint identity (keyed by the stable id from
 * `computeEndpointId`), and that entry's source list must equal the
 * de-duplicated union of the sources of every raw endpoint sharing the identity.
 */

import fc from 'fast-check';

import { buildInventoryEntries, RawEndpoint } from './dedup';
import { computeEndpointId } from './identity';
import { EndpointIdentity, EndpointKind, SourceRef } from '../types';

const REST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Build a well-formed identity for its kind, mirroring what discovery emits:
 * REST entries carry method + path, ws-route entries carry a path, and the
 * GraphQL/ws-event kinds carry an operation name.
 */
const identityArb: fc.Arbitrary<EndpointIdentity> = fc
  .constantFrom<EndpointKind>(
    'rest',
    'graphql-query',
    'graphql-mutation',
    'graphql-subscription',
    'ws-route',
    'ws-event',
  )
  .chain((kind): fc.Arbitrary<EndpointIdentity> => {
    const segmentArb = fc.stringMatching(/^[a-zA-Z][a-zA-Z0-9_-]*$/);
    const pathArb = fc
      .array(segmentArb, { minLength: 1, maxLength: 4 })
      .map((segs) => `/${segs.join('/')}`);
    const nameArb = fc.stringMatching(/^[a-zA-Z][a-zA-Z0-9_]*$/);

    if (kind === 'rest') {
      return fc.record({
        kind: fc.constant<EndpointKind>('rest'),
        method: fc.constantFrom(...REST_METHODS),
        path: pathArb,
      });
    }
    if (kind === 'ws-route') {
      return fc.record({
        kind: fc.constant<EndpointKind>('ws-route'),
        path: pathArb,
      });
    }
    return fc.record({
      kind: fc.constant<EndpointKind>(kind),
      operationName: nameArb,
    });
  });

/**
 * A source may or may not carry a locator. Sources are drawn from a small pool
 * (below) so that exact duplicates occur across raw sightings, exercising the
 * de-duplicated-union guarantee.
 */
const sourceRefArb: fc.Arbitrary<SourceRef> = fc
  .record({
    filePath: fc
      .array(fc.stringMatching(/^[a-zA-Z][a-zA-Z0-9_.-]*$/), {
        minLength: 1,
        maxLength: 4,
      })
      .map((segs) => segs.join('/')),
    artifactType: fc.constantFrom<'code' | 'configuration'>('code', 'configuration'),
    locator: fc.option(fc.stringMatching(/^[a-zA-Z0-9_:.-]+$/), { nil: undefined }),
  })
  .map(({ filePath, artifactType, locator }) =>
    locator === undefined ? { filePath, artifactType } : { filePath, artifactType, locator },
  );

/** Canonical source equality, matching dedup's internal `sameSource`. */
function sameSource(a: SourceRef, b: SourceRef): boolean {
  return (
    a.filePath === b.filePath &&
    a.artifactType === b.artifactType &&
    (a.locator ?? '') === (b.locator ?? '')
  );
}

/** Independently compute the de-duplicated union of a list of sources. */
function dedupSources(sources: SourceRef[]): SourceRef[] {
  const out: SourceRef[] = [];
  for (const s of sources) {
    if (!out.some((existing) => sameSource(existing, s))) {
      out.push(s);
    }
  }
  return out;
}

/**
 * Generate a small pool of distinct identities and a small pool of sources,
 * then build the raw sightings by repeatedly drawing one identity + one source
 * from those pools. Drawing from small pools guarantees that identities repeat
 * across different sources (and that some sources repeat), which is exactly the
 * input space this property must cover.
 */
const rawEndpointsArb: fc.Arbitrary<RawEndpoint[]> = fc
  .record({
    identityPool: fc.array(identityArb, { minLength: 1, maxLength: 4 }),
    sourcePool: fc.array(sourceRefArb, { minLength: 1, maxLength: 4 }),
  })
  .chain(({ identityPool, sourcePool }) =>
    fc
      .array(
        fc.record({
          identityIndex: fc.nat({ max: identityPool.length - 1 }),
          sourceIndex: fc.nat({ max: sourcePool.length - 1 }),
        }),
        { minLength: 1, maxLength: 20 },
      )
      .map((picks) =>
        picks.map<RawEndpoint>(({ identityIndex, sourceIndex }) => ({
          identity: identityPool[identityIndex],
          source: sourcePool[sourceIndex],
        })),
      ),
  );

describe('Feature: api-audit-testing-automation, Property 3: Discovery deduplicates and merges sources', () => {
  it('produces one entry per distinct identity whose sources are the de-duplicated union of all contributors', () => {
    fc.assert(
      fc.property(rawEndpointsArb, (rawEndpoints) => {
        const entries = buildInventoryEntries(rawEndpoints);

        // (1) Result entries have unique ids.
        const ids = entries.map((e) => e.id);
        expect(new Set(ids).size).toBe(ids.length);

        // Expected grouping: one group per distinct id, sources accumulated in
        // first-seen order, then de-duplicated.
        const expected = new Map<string, SourceRef[]>();
        for (const raw of rawEndpoints) {
          const id = computeEndpointId(raw.identity);
          const bucket = expected.get(id);
          if (bucket) {
            bucket.push(raw.source);
          } else {
            expected.set(id, [raw.source]);
          }
        }

        // (2) Entries with the same identity are merged into one: the set of
        // produced ids equals the set of distinct contributor ids.
        expect(new Set(ids)).toEqual(new Set(expected.keys()));
        expect(entries.length).toBe(expected.size);

        // (3) Each merged entry's sources are the de-duplicated union of all
        // contributing sources.
        for (const entry of entries) {
          const contributors = expected.get(entry.id);
          expect(contributors).toBeDefined();
          const expectedSources = dedupSources(contributors as SourceRef[]);

          // No exact duplicates remain in the merged source list.
          expect(entry.sources.length).toBe(dedupSources(entry.sources).length);

          // Same multiset of sources as the expected de-duplicated union.
          expect(entry.sources.length).toBe(expectedSources.length);
          for (const src of expectedSources) {
            expect(entry.sources.some((s) => sameSource(s, src))).toBe(true);
          }
          for (const src of entry.sources) {
            expect(expectedSources.some((s) => sameSource(s, src))).toBe(true);
          }
        }
      }),
      { numRuns: 100 },
    );
  });
});
