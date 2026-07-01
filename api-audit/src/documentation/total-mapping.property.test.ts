/**
 * Property-based test for the Documentation_Engine's total mapping guarantee.
 *
 * Feature: api-audit-testing-automation, Property 5: Catalog is a total mapping
 * of the inventory.
 *
 * Validates: Requirements 2.1
 *
 * For any API_Inventory, the Documentation_Engine must produce exactly one
 * API_Catalog entry per inventory entry — including entries whose source
 * processing failed (i.e. entries referenced by a discovery `StageIssue`). The
 * set of catalog entry ids must therefore equal the set of inventory entry ids,
 * with a strict one-to-one correspondence.
 */

import fc from 'fast-check';

import { documentInventory } from './index';
import { computeEndpointId } from '../discovery/identity';
import {
  ApiInventory,
  Domain,
  EndpointIdentity,
  EndpointKind,
  InventoryEntry,
  SourceRef,
  StageIssue,
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
 * Build an endpoint identity that is well-formed for its kind: REST entries
 * carry a method + path, GraphQL/WebSocket-event entries carry an operation
 * name, and ws-route entries carry a path. This mirrors what the discovery
 * stage emits.
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
 * Generate a realistic, deduplicated API_Inventory plus a subset of discovery
 * issues that reference some of its entries (failed-source entries). Entries
 * are deduplicated by id so the inventory matches what discovery produces.
 */
const inventoryArb: fc.Arbitrary<ApiInventory> = fc
  .array(inventoryEntryArb, { minLength: 0, maxLength: 12 })
  .chain((rawEntries) => {
    // Deduplicate by id, mirroring discovery's dedup contract (1.8).
    const byId = new Map<string, InventoryEntry>();
    for (const entry of rawEntries) {
      if (!byId.has(entry.id)) {
        byId.set(entry.id, entry);
      }
    }
    const entries = [...byId.values()];
    const ids = entries.map((e) => e.id);

    // Pick a subset of entries to mark as failed-source via discovery issues,
    // plus optionally some issues that reference no endpoint at all.
    const failedSubsetArb =
      ids.length > 0 ? fc.subarray(ids) : fc.constant<string[]>([]);

    return failedSubsetArb.chain((failedIds) => {
      const endpointIssues: StageIssue[] = failedIds.map((id) => ({
        stage: 'discovery',
        endpointId: id,
        reason: 'parse error',
      }));
      return fc
        .array(
          fc.record({
            stage: fc.constant('discovery'),
            filePath: fc.stringMatching(/^[a-zA-Z][a-zA-Z0-9_./-]*$/),
            reason: fc.constant('unparseable file'),
          }),
          { maxLength: 3 },
        )
        .map((fileIssues) => ({
          entries,
          issues: [...endpointIssues, ...fileIssues] as StageIssue[],
        }));
    });
  });

describe('Feature: api-audit-testing-automation, Property 5: Catalog is a total mapping of the inventory', () => {
  it('produces exactly one catalog entry per inventory entry with ids matching one-to-one', () => {
    fc.assert(
      fc.property(inventoryArb, (inventory) => {
        const { catalog } = documentInventory(inventory);

        const inventoryIds = inventory.entries.map((e) => e.id);
        const catalogIds = catalog.map((c) => c.id);

        // Exactly one catalog entry per inventory entry (no drops, no extras).
        expect(catalog.length).toBe(inventory.entries.length);

        // The set of catalog ids equals the set of inventory ids.
        expect(new Set(catalogIds)).toEqual(new Set(inventoryIds));

        // One-to-one: each inventory id maps to exactly one catalog entry,
        // and catalog ids carry no duplicates.
        expect(new Set(catalogIds).size).toBe(catalogIds.length);
        for (const id of inventoryIds) {
          const matches = catalog.filter((c) => c.id === id);
          expect(matches).toHaveLength(1);
        }
      }),
      { numRuns: 100 },
    );
  });
});
