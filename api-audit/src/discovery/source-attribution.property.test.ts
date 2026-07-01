/**
 * Property-based test for the Discovery_Engine's source-attribution guarantee.
 *
 * Feature: api-audit-testing-automation, Property 2: Every inventory entry is
 * source-attributed.
 *
 * Validates: Requirements 1.7
 *
 * For any API_Inventory produced from any set of raw discovered endpoints,
 * every resulting InventoryEntry must carry at least one SourceRef, and every
 * one of those source references must have a non-empty file path and a valid
 * artifact type (`code` or `configuration`).
 */

import fc from 'fast-check';

import { buildInventoryEntries, RawEndpoint } from './dedup';
import { EndpointIdentity, EndpointKind, SourceRef } from '../types';

const REST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Build an endpoint identity that is well-formed for its kind: REST entries
 * carry a method + path, ws-route entries carry a path, and the remaining
 * GraphQL/WebSocket-event kinds carry an operation name. This mirrors what the
 * source scanners emit.
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
 * A SourceRef as produced by the scanners: a non-empty file path, a valid
 * artifact type, and an optional locator.
 */
const sourceRefArb: fc.Arbitrary<SourceRef> = fc.record(
  {
    filePath: fc
      .array(fc.stringMatching(/^[a-zA-Z][a-zA-Z0-9_.-]*$/), {
        minLength: 1,
        maxLength: 5,
      })
      .map((segs) => segs.join('/')),
    artifactType: fc.constantFrom<'code' | 'configuration'>(
      'code',
      'configuration',
    ),
    locator: fc.option(fc.stringMatching(/^[a-zA-Z0-9_:./{}-]*$/), {
      nil: undefined,
    }),
  },
  { requiredKeys: ['filePath', 'artifactType'] },
);

const rawEndpointArb: fc.Arbitrary<RawEndpoint> = fc.record({
  identity: identityArb,
  source: sourceRefArb,
});

const VALID_ARTIFACT_TYPES = new Set<SourceRef['artifactType']>([
  'code',
  'configuration',
]);

describe('Feature: api-audit-testing-automation, Property 2: Every inventory entry is source-attributed', () => {
  it('attaches at least one valid source reference to every inventory entry', () => {
    fc.assert(
      fc.property(
        fc.array(rawEndpointArb, { minLength: 1, maxLength: 25 }),
        (rawEndpoints) => {
          const entries = buildInventoryEntries(rawEndpoints);

          for (const entry of entries) {
            // Every entry has at least one source reference (Requirement 1.7).
            expect(entry.sources.length).toBeGreaterThanOrEqual(1);

            for (const source of entry.sources) {
              // Each source has a non-empty file path...
              expect(typeof source.filePath).toBe('string');
              expect(source.filePath.length).toBeGreaterThan(0);

              // ...and a valid artifact type.
              expect(VALID_ARTIFACT_TYPES.has(source.artifactType)).toBe(true);
            }
          }
        },
      ),
      { numRuns: 100 },
    );
  });
});
