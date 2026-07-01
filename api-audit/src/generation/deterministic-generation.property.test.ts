/**
 * Property-based test for the deterministic-generation guarantee.
 *
 * Feature: api-audit-testing-automation, Property 26: Generation is
 * deterministic across repeated runs.
 *
 * Validates: Requirements 1.9, 3.8, 14.3
 *
 * For any fixed inputs and unchanged codebase, two full generation passes must
 * produce deeply-equal generated artifacts. The deterministic transformation
 * core here is: an API_Inventory documented into an API_Catalog
 * (Documentation_Engine) and the catalog turned into a Postman collection plus
 * environment set (Collection_Generator). We generate an arbitrary, realistic
 * (deduplicated, representable) inventory, run the full pass twice on the *same*
 * input, and assert the JSON serializations of the API_Catalog, the Postman
 * collection, and the environment set are deeply equal across both runs.
 */

import fc from 'fast-check';

import { documentInventory } from '../documentation';
import { generateCollection } from './collection-generator';
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
 * Build a well-formed (and therefore representable) endpoint identity for its
 * kind: REST entries carry an HTTP method + clean URL path, GraphQL/ws-event
 * entries carry an operation name, ws-route entries carry a path. Restricting
 * paths and names to URL-safe segments keeps every endpoint representable so
 * generation never fails the run (Requirement 3.7) and the determinism property
 * is exercised on the success path.
 */
const representableIdentityArb: fc.Arbitrary<EndpointIdentity> = fc
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
  artifactType: fc.constantFrom<'code' | 'configuration'>('code', 'configuration'),
});

const inventoryEntryArb: fc.Arbitrary<InventoryEntry> = fc
  .record({
    identity: representableIdentityArb,
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
 * Generate a realistic, deduplicated API_Inventory of representable endpoints.
 * Entries are keyed by id (matching discovery's dedup contract, Requirement
 * 1.8) so the inventory is exactly the kind of fixed input the pipeline
 * consumes in a real run.
 */
const inventoryArb: fc.Arbitrary<ApiInventory> = fc
  .array(inventoryEntryArb, { minLength: 0, maxLength: 15 })
  .map((rawEntries) => {
    const byId = new Map<string, InventoryEntry>();
    for (const entry of rawEntries) {
      if (!byId.has(entry.id)) {
        byId.set(entry.id, entry);
      }
    }
    return { entries: [...byId.values()], issues: [] };
  });

describe('Feature: api-audit-testing-automation, Property 26: Generation is deterministic across repeated runs', () => {
  it('produces deeply-equal catalog, collection, and environments across two independent passes on the same input', () => {
    fc.assert(
      fc.property(inventoryArb, (inventory) => {
        // Two fully independent generation passes over the SAME fixed input.
        const { catalog: catalog1 } = documentInventory(inventory);
        const run1 = generateCollection(catalog1, inventory);

        const { catalog: catalog2 } = documentInventory(inventory);
        const run2 = generateCollection(catalog2, inventory);

        // Deep equality via JSON serialization (Requirements 1.9, 3.8, 14.3):
        // the API_Catalog, the Postman collection, and the environment set are
        // byte-equivalent across repeated runs of the deterministic core.
        expect(JSON.stringify(catalog2)).toEqual(JSON.stringify(catalog1));
        expect(JSON.stringify(run2.collection)).toEqual(
          JSON.stringify(run1.collection),
        );
        expect(JSON.stringify(run2.environments)).toEqual(
          JSON.stringify(run1.environments),
        );

        // Structural deep-equality as a second, order-sensitive check on the
        // combined generated artifact set.
        expect(run2.environments).toEqual(run1.environments);
        expect(run2.collection).toEqual(run1.collection);
        expect(catalog2).toEqual(catalog1);
      }),
      { numRuns: 100 },
    );
  });
});
