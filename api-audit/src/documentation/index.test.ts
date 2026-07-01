/**
 * Documentation_Engine tests.
 *
 * Property 6 (Feature: api-audit-testing-automation, Property 6):
 *   Every catalog field is determined or explicitly undetermined.
 *
 * For any API_Catalog entry, every documented Determinable field is either a
 * concrete value or the literal "undetermined", and every field equal to
 * "undetermined" has a corresponding recorded reason. Security metadata is
 * never empty: enforcement is one of `public`, `authenticated`, or
 * `authorized`, defaulting to `public` when no enforcement is present.
 *
 * Validates: Requirements 2.2, 2.3, 2.4, 2.5, 2.6, 2.7
 */
import fc from 'fast-check';

import { documentInventory } from './index';
import {
  ApiInventory,
  CatalogEntry,
  Domain,
  EndpointKind,
  InventoryEntry,
  SourceRef,
  StageIssue,
} from '../types';

// The Determinable fields on a CatalogEntry that the invariant covers. The
// `security` field is checked separately because it is a concrete object, not
// a Determinable<T>.
const DETERMINABLE_FIELDS: (keyof CatalogEntry)[] = [
  'urlPath',
  'methodOrOperation',
  'module',
  'controllerOrHandler',
  'requestBodyParams',
  'queryParams',
  'pathParams',
  'headers',
  'requestSchema',
  'responseSchema',
  'errorResponses',
  'validationRules',
  'businessRules',
];

const VALID_ENFORCEMENTS = ['public', 'authenticated', 'authorized'];

// ---------------------------------------------------------------------------
// Arbitraries
// ---------------------------------------------------------------------------

const kindArb = fc.constantFrom<EndpointKind>(
  'rest',
  'graphql-query',
  'graphql-mutation',
  'graphql-subscription',
  'ws-route',
  'ws-event'
);

const methodArb = fc.constantFrom(
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'OPTIONS',
  'HEAD'
);

const domainArb = fc.constantFrom<Domain>(
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
  'Internal-Service'
);

// Candidate paths, including Express (:id) and OpenAPI ({id}) param styles, and
// some with no params. None equals the literal "undetermined".
const pathArb = fc.constantFrom(
  '/users',
  '/users/:id',
  '/customers/{customerId}',
  '/v1/products/:productId/variants/{variantId}',
  '/a/b/c',
  '/'
);

// File paths spanning the project's known code layout plus configuration files.
const sourceArb: fc.Arbitrary<SourceRef> = fc.record({
  filePath: fc.constantFrom(
    'my-backend/src/modules/customers/customer.controller.ts',
    'my-backend/src/routes/users.routes.ts',
    'my-backend/src/websocket/handler.ts',
    'lambda/payments/index.ts',
    'serverless.yml',
    'openapi.yaml'
  ),
  artifactType: fc.constantFrom<'code' | 'configuration'>(
    'code',
    'configuration'
  ),
  locator: fc.option(fc.string({ minLength: 1, maxLength: 8 }), {
    nil: undefined,
  }),
});

const entryArb: fc.Arbitrary<InventoryEntry> = fc.record({
  id: fc.string({ minLength: 1, maxLength: 10 }),
  identity: fc.record({
    kind: kindArb,
    method: fc.option(methodArb, { nil: undefined }),
    path: fc.option(pathArb, { nil: undefined }),
    operationName: fc.option(fc.string({ minLength: 1, maxLength: 12 }), {
      nil: undefined,
    }),
  }),
  domain: domainArb,
  sources: fc.array(sourceArb, { minLength: 1, maxLength: 4 }),
});

// An ApiInventory whose `issues` reference an arbitrary subset of the entry ids
// (exercising the failed-source path) plus some unattributed issues.
const inventoryArb: fc.Arbitrary<ApiInventory> = fc
  .array(entryArb, { minLength: 1, maxLength: 8 })
  .chain((entries) => {
    const ids = entries.map((e) => e.id);
    const attributedIssueArb: fc.Arbitrary<StageIssue> = fc.record({
      stage: fc.constant('discovery'),
      endpointId: fc.constantFrom(...ids),
      reason: fc.string({ minLength: 1, maxLength: 20 }),
    });
    const looseIssueArb: fc.Arbitrary<StageIssue> = fc.record({
      stage: fc.constant('discovery'),
      filePath: fc.constantFrom('serverless.yml', 'openapi.yaml'),
      reason: fc.string({ minLength: 1, maxLength: 20 }),
    });
    return fc
      .array(fc.oneof(attributedIssueArb, looseIssueArb), { maxLength: 6 })
      .map((issues) => ({ entries, issues }));
  });

// ---------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------

function assertEntryInvariant(entry: CatalogEntry): void {
  for (const field of DETERMINABLE_FIELDS) {
    const value = entry[field];

    if (value === 'undetermined') {
      // An undetermined field must carry a recorded, non-empty reason (2.7).
      const reason = entry.undeterminedReasons[field as string];
      expect(typeof reason).toBe('string');
      expect((reason as string).length).toBeGreaterThan(0);
    } else {
      // Otherwise it must be a concrete (defined, non-null) value (2.2-2.6).
      expect(value).not.toBeUndefined();
      expect(value).not.toBeNull();
    }
  }

  // Security metadata is never empty and carries a valid enforcement level.
  expect(entry.security).toBeDefined();
  expect(VALID_ENFORCEMENTS).toContain(entry.security.enforcement);
  // No enforcement signal is carried by the inventory, so it defaults to
  // `public` (2.4).
  expect(entry.security.enforcement).toBe('public');
}

// ---------------------------------------------------------------------------
// Property test
// ---------------------------------------------------------------------------

describe('Documentation_Engine', () => {
  it('Feature: api-audit-testing-automation, Property 6: every catalog field is determined or explicitly undetermined', () => {
    fc.assert(
      fc.property(inventoryArb, (inventory) => {
        const { catalog } = documentInventory(inventory);

        for (const entry of catalog) {
          assertEntryInvariant(entry);
        }
      }),
      { numRuns: 200 }
    );
  });
});
