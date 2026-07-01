/**
 * Property-based test for the Collection_Generator's collection validity and
 * domain organization.
 *
 * Feature: api-audit-testing-automation, Property 7: Generated collection is
 * valid and domain-organized.
 *
 * Validates: Requirements 3.1, 3.2
 *
 * For any API_Catalog (optionally accompanied by its source API_Inventory), the
 * generated Postman collection must:
 *   - conform to Postman Collection Format v2.1 (`info.schema === 'v2.1.0'`),
 *   - place every request under a folder whose name is a valid `Domain`, and
 *   - group each request under the folder for the domain its endpoint resolves
 *     to (authoritative inventory domain when present, inferred domain when the
 *     catalog stands alone).
 */

import fc from 'fast-check';

import { generateCollection, resolveDomain } from './collection-generator';
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

// The full enumerated Domain set (design.md → Domain Enumeration). The test
// asserts every generated folder name is a member of this set.
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
const DOMAIN_SET = new Set<Domain>(DOMAINS);

const REST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Build an endpoint identity that is well-formed for its kind, mirroring
 * discovery output. Paths and operation names use clean, URL-safe segments so
 * every generated endpoint is representable (no control characters or embedded
 * whitespace) and generation never fails the run (Requirement 3.7).
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
    // Domain is chosen freely from the enumerated set so the generator's
    // folder placement is exercised across every domain, not just inferred ones.
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
 * Generate a realistic, deduplicated API_Inventory (entries keyed by id,
 * matching discovery's dedup contract). The catalog is derived from it via the
 * Documentation_Engine so the inputs are exactly what the generator consumes in
 * the real pipeline.
 */
const inventoryArb: fc.Arbitrary<ApiInventory> = fc
  .array(inventoryEntryArb, { minLength: 0, maxLength: 12 })
  .map((rawEntries) => {
    const byId = new Map<string, InventoryEntry>();
    for (const entry of rawEntries) {
      if (!byId.has(entry.id)) {
        byId.set(entry.id, entry);
      }
    }
    return { entries: [...byId.values()], issues: [] };
  });

describe('Feature: api-audit-testing-automation, Property 7: Generated collection is valid and domain-organized', () => {
  it('produces a v2.1 collection whose folders are valid Domains with requests grouped by their inventory domain', () => {
    fc.assert(
      fc.property(inventoryArb, (inventory) => {
        const { catalog } = documentInventory(inventory);
        const { collection } = generateCollection(catalog, inventory);

        const inventoryById = new Map(
          inventory.entries.map((e) => [e.id, e] as const),
        );

        // Postman Collection Format v2.1 (Requirement 3.1).
        expect(collection.info.schema).toBe('v2.1.0');

        // Every folder name is a valid Domain, and no domain folder repeats
        // (Requirement 3.2).
        const folderNames = collection.folders.map((f) => f.name);
        for (const name of folderNames) {
          expect(DOMAIN_SET.has(name)).toBe(true);
        }
        expect(new Set(folderNames).size).toBe(folderNames.length);

        // Every request resides under the folder for its resolved domain, and
        // every cataloged endpoint is represented exactly once.
        const seenEndpointIds = new Set<string>();
        for (const folder of collection.folders) {
          for (const request of folder.items) {
            const entry = catalog.find((c) => c.id === request.endpointId);
            expect(entry).toBeDefined();

            const expectedDomain = resolveDomain(
              entry!,
              inventoryById.get(entry!.id),
            );
            expect(folder.name).toBe(expectedDomain);

            seenEndpointIds.add(request.endpointId);
          }
        }
        expect(seenEndpointIds.size).toBe(catalog.length);
      }),
      { numRuns: 100 },
    );
  });

  it('organizes a stand-alone catalog (no inventory) into valid Domain folders with inferred grouping', () => {
    fc.assert(
      fc.property(inventoryArb, (inventory) => {
        const { catalog } = documentInventory(inventory);

        // No inventory is supplied: the generator must infer each endpoint's
        // domain and still place every request under a valid Domain folder.
        const { collection } = generateCollection(catalog);

        expect(collection.info.schema).toBe('v2.1.0');

        const folderNames = collection.folders.map((f) => f.name);
        for (const name of folderNames) {
          expect(DOMAIN_SET.has(name)).toBe(true);
        }
        expect(new Set(folderNames).size).toBe(folderNames.length);

        const seenEndpointIds = new Set<string>();
        for (const folder of collection.folders) {
          for (const request of folder.items) {
            const entry = catalog.find((c) => c.id === request.endpointId);
            expect(entry).toBeDefined();

            // Inferred (inventory-free) grouping must match the folder.
            const expectedDomain = resolveDomain(entry!);
            expect(folder.name).toBe(expectedDomain);

            seenEndpointIds.add(request.endpointId);
          }
        }
        expect(seenEndpointIds.size).toBe(catalog.length);
      }),
      { numRuns: 100 },
    );
  });
});
