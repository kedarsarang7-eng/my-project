/**
 * Property-based test for the Collection_Generator's full-representation
 * guarantee.
 *
 * Feature: api-audit-testing-automation, Property 9: Every cataloged endpoint
 * is represented by a request.
 *
 * Validates: Requirements 3.6
 *
 * For any API_Catalog in which all endpoints are representable, every catalog
 * entry id must map to at least one request in the generated Postman
 * collection. We generate arbitrary, deduplicated inventories of representable
 * endpoints (REST with well-formed paths, GraphQL operations, WebSocket
 * routes/events — all of which the generator can always represent), document
 * them into a catalog, generate the collection, and assert that the set of
 * endpoint ids appearing across all folders' requests covers every catalog id.
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
 * Build an endpoint identity that is well-formed (and therefore representable)
 * for its kind: REST entries carry an HTTP method + a clean URL path,
 * GraphQL/WebSocket-event entries carry an operation name, and ws-route entries
 * carry a path. Paths are restricted to URL-safe segments so the resulting
 * endpoints are always representable (no control characters or embedded
 * whitespace), which is the precondition of Property 9.
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
 * Entries are deduplicated by id so the inventory matches what discovery
 * produces (Requirement 1.8) and the catalog is a faithful 1:1 mapping.
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

describe('Feature: api-audit-testing-automation, Property 9: Every cataloged endpoint is represented by a request', () => {
  it('maps every catalog entry id to at least one request across all collection folders', () => {
    fc.assert(
      fc.property(inventoryArb, (inventory) => {
        const { catalog } = documentInventory(inventory);
        const { collection } = generateCollection(catalog, inventory);

        // Collect every endpoint id represented by a request, across all folders.
        const representedIds = new Set<string>();
        for (const folder of collection.folders) {
          for (const request of folder.items) {
            representedIds.add(request.endpointId);
          }
        }

        const catalogIds = catalog.map((c) => c.id);

        // Every cataloged endpoint is represented by at least one request (3.6).
        for (const id of catalogIds) {
          expect(representedIds.has(id)).toBe(true);
        }

        // No request references an endpoint absent from the catalog (no extras).
        for (const id of representedIds) {
          expect(catalogIds).toContain(id);
        }

        // The represented set covers exactly the catalog id set.
        expect(representedIds).toEqual(new Set(catalogIds));
      }),
      { numRuns: 100 },
    );
  });
});
