/**
 * Property-based test for the Discovery_Engine's domain classification.
 *
 * Feature: api-audit-testing-automation, Property 1: Endpoint classification is
 * total and well-formed.
 *
 * Validates: Requirements 1.6
 *
 * For any discovered endpoint, `classifyDomain` must return exactly one value
 * drawn from the enumerated `Domain` set, regardless of endpoint kind or the
 * (possibly empty, possibly arbitrary) set of contributing sources.
 * Classification is therefore total: every well-formed `EndpointIdentity`
 * produces a defined, in-set domain and never `undefined` or an out-of-set
 * value.
 */

import fc from 'fast-check';

import { classifyDomain } from './classification';
import {
  Domain,
  EndpointIdentity,
  EndpointKind,
  SourceRef,
} from '../types';

// The full enumerated Domain set (design.md → Domain Enumeration). The test
// asserts every classification result is a member of this set.
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

const ALL_KINDS: EndpointKind[] = [
  'rest',
  'graphql-query',
  'graphql-mutation',
  'graphql-subscription',
  'ws-route',
  'ws-event',
];

const REST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Generate a path that may include keyword-bearing and free-form segments, so
 * classification is exercised across both the keyword-matching and
 * default-fallback branches. Free-form strings are unconstrained (including
 * empty) to stress totality.
 */
const pathArb: fc.Arbitrary<string> = fc
  .array(fc.oneof(fc.string(), fc.constantFrom('admin', 'auth', 'billing', 'user', 'report', 'xyz')), {
    minLength: 0,
    maxLength: 4,
  })
  .map((segs) => `/${segs.join('/')}`);

const nameArb: fc.Arbitrary<string> = fc.oneof(
  fc.string(),
  fc.constantFrom('login', 'createInvoice', 'onMessage', 'getStock', 'doThing'),
);

/**
 * Build a well-formed identity per kind (mirroring discovery output): REST
 * carries a method + path, ws-route carries a path, and the operation kinds
 * carry an operation name. Optional fields are sometimes omitted to cover the
 * empty-text branch of the classifier.
 */
const identityArb: fc.Arbitrary<EndpointIdentity> = fc
  .constantFrom<EndpointKind>(...ALL_KINDS)
  .chain((kind): fc.Arbitrary<EndpointIdentity> => {
    if (kind === 'rest') {
      return fc.record(
        {
          kind: fc.constant<EndpointKind>('rest'),
          method: fc.constantFrom(...REST_METHODS),
          path: pathArb,
        },
        { requiredKeys: ['kind'] },
      );
    }
    if (kind === 'ws-route') {
      return fc.record(
        {
          kind: fc.constant<EndpointKind>('ws-route'),
          path: pathArb,
        },
        { requiredKeys: ['kind'] },
      );
    }
    return fc.record(
      {
        kind: fc.constant<EndpointKind>(kind),
        operationName: nameArb,
      },
      { requiredKeys: ['kind'] },
    );
  });

const sourceRefArb: fc.Arbitrary<SourceRef> = fc.record({
  filePath: fc.string(),
  artifactType: fc.constantFrom<'code' | 'configuration'>('code', 'configuration'),
});

describe('Feature: api-audit-testing-automation, Property 1: Endpoint classification is total and well-formed', () => {
  it('returns exactly one Domain from the enumerated set for any endpoint and sources', () => {
    fc.assert(
      fc.property(identityArb, fc.array(sourceRefArb, { maxLength: 4 }), (identity, sources) => {
        const domain = classifyDomain(identity, sources);

        // Well-formed: the result is a defined value drawn from the Domain set.
        expect(DOMAIN_SET.has(domain)).toBe(true);
      }),
      { numRuns: 100 },
    );
  });

  it('is total across every endpoint kind even with no sources', () => {
    fc.assert(
      fc.property(identityArb, (identity) => {
        // Totality must hold for the default (no sources) call signature too.
        const domain = classifyDomain(identity);
        expect(DOMAIN_SET.has(domain)).toBe(true);

        // GraphQL/WebSocket surfaces are classified by kind, unambiguously.
        if (identity.kind.startsWith('graphql')) {
          expect(domain).toBe<Domain>('GraphQL');
        } else if (identity.kind.startsWith('ws')) {
          expect(domain).toBe<Domain>('WebSocket');
        }
      }),
      { numRuns: 100 },
    );
  });
});
