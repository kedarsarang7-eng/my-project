/**
 * Property-based test for the Test_Generator's baseline assertions.
 *
 * Feature: api-audit-testing-automation, Property 11: Baseline assertions on
 * every request.
 *
 * Validates: Requirements 4.1, 4.2
 *
 * For any generated request, the Test_Generator attaches both a status-code
 * assertion and a response-time-threshold assertion. This must hold for every
 * request in the collection regardless of the endpoint's metadata (and even
 * when no matching catalog entry exists), because the baseline assertions are
 * the floor of coverage every request carries.
 */

import fc from 'fast-check';

import { generateCollection } from './collection-generator';
import { attachTests } from './test-generator';
import { documentInventory } from '../documentation';
import { computeEndpointId } from '../discovery/identity';
import {
  ApiInventory,
  Domain,
  EndpointIdentity,
  EndpointKind,
  InventoryEntry,
  SourceRef,
} from '../types';

// The full enumerated Domain set (design.md → Domain Enumeration).
const DOMAINS: Domain[] = [
  'Authentication',
  'Authorization/RBAC',
  'Users',
  'Customers',
  'Products',
  'Inventory',
  'Billing',
  'Invoices',
  'Reports',
  'Search',
  'Settings',
  'License',
  'Subscription',
  'File-Transfer',
  'GraphQL',
  'WebSocket',
  'Admin',
  'AWS-Integrated',
  'Internal-Service',
];

const REST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Build a well-formed endpoint identity for its kind, mirroring discovery
 * output. Clean, URL-safe segments keep every endpoint representable so
 * generation never fails the run (Requirement 3.7) and the baseline pass runs
 * over a populated collection.
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

const sourceRefArb: fc.Arbitrary<SourceRef> = fc.record({
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
});

const inventoryEntryArb: fc.Arbitrary<InventoryEntry> = fc
  .record({
    identity: identityArb,
    domain: fc.constantFrom(...DOMAINS),
    sources: fc.array(sourceRefArb, { minLength: 1, maxLength: 3 }),
  })
  .map(({ identity, domain, sources }) => ({
    id: computeEndpointId(identity),
    identity,
    domain,
    sources,
  }));

/**
 * Generate a deduplicated API_Inventory (entries keyed by id, matching
 * discovery's dedup contract). The catalog is derived from it via the
 * Documentation_Engine, so the inputs are exactly what the Test_Generator
 * consumes in the real pipeline. At least one entry guarantees a non-empty
 * collection so the baseline pass has requests to cover.
 */
const inventoryArb: fc.Arbitrary<ApiInventory> = fc
  .array(inventoryEntryArb, { minLength: 1, maxLength: 12 })
  .map((rawEntries) => {
    const byId = new Map<string, InventoryEntry>();
    for (const entry of rawEntries) {
      if (!byId.has(entry.id)) {
        byId.set(entry.id, entry);
      }
    }
    return { entries: [...byId.values()], issues: [] };
  });

describe('Feature: api-audit-testing-automation, Property 11: Baseline assertions on every request', () => {
  it('attaches a status-code assertion and a response-time-threshold assertion to every generated request', () => {
    fc.assert(
      fc.property(
        inventoryArb,
        fc.integer({ min: 1, max: 60000 }),
        (inventory, thresholdMs) => {
          const { catalog } = documentInventory(inventory);
          const { collection } = generateCollection(catalog, inventory);

          const { collection: withTests } = attachTests(collection, catalog, {
            responseTimeThresholdMs: thresholdMs,
          });

          const requests = withTests.folders.flatMap((folder) => folder.items);

          // The generated collection must contain at least one request so the
          // property is exercised over real requests.
          expect(requests.length).toBeGreaterThan(0);

          for (const request of requests) {
            const tests = request.tests ?? [];

            const statusTests = tests.filter((t) => t.type === 'status');
            const responseTimeTests = tests.filter(
              (t) => t.type === 'response-time',
            );

            // Requirement 4.1 — a status-code assertion on every request.
            expect(statusTests.length).toBeGreaterThanOrEqual(1);
            // Requirement 4.2 — a response-time-threshold assertion on every request.
            expect(responseTimeTests.length).toBeGreaterThanOrEqual(1);

            // Each baseline assertion targets the request's own endpoint and
            // carries a non-empty Postman script.
            for (const test of [...statusTests, ...responseTimeTests]) {
              expect(test.endpointId).toBe(request.endpointId);
              expect(test.script.trim().length).toBeGreaterThan(0);
            }

            // The response-time assertion encodes the configured threshold,
            // confirming it checks the response time against that threshold.
            expect(
              responseTimeTests.some((t) =>
                t.script.includes(String(thresholdMs)),
              ),
            ).toBe(true);
          }
        },
      ),
      { numRuns: 100 },
    );
  });
});
