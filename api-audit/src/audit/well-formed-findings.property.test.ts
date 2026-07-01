/**
 * Property-based test for the Security_Auditor's well-formed-findings
 * guarantee.
 *
 * Feature: api-audit-testing-automation, Property 15: Security findings are
 * well-formed.
 *
 * Validates: Requirements 7.6, 7.7
 *
 * For any generated collection and any probe executor that reports
 * vulnerabilities, every SecurityFinding recorded in the Security_Audit_Report
 * is well-formed:
 *   - it references an affected endpoint (non-empty endpointId that maps to a
 *     real request in the collection) — Requirement 7.6;
 *   - it carries a valid VulnCategory — Requirement 7.6;
 *   - it carries a valid severity rating — Requirement 7.6;
 *   - it carries a non-empty payloadRef referencing the crafted payload that
 *     targeted the endpoint — Requirements 7.6, 7.7;
 *   - no supplied secret value appears verbatim in any finding's
 *     observedResponse — Requirement 7.7.
 *
 * The executor is injected so the deterministic recording logic can be
 * exercised without a live server: it reports every probe as vulnerable and
 * returns an observed response that deliberately embeds the generated secret
 * values, so the redaction-before-recording boundary is exercised on every run.
 */

import fc from 'fast-check';

import { auditSecurity, ProbeExecutor } from './security-auditor';
import {
  Domain,
  PostmanCollection,
  PostmanEnvironment,
  PostmanRequest,
  VulnCategory,
} from '../types';

// ── Constants ────────────────────────────────────────────────────────────────

/** The full enumerated Domain set (design.md → Domain Enumeration). */
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

/** Every valid vulnerability category (design.md → VulnCategory). */
const VALID_CATEGORIES: ReadonlySet<VulnCategory> = new Set<VulnCategory>([
  'sql-injection',
  'nosql-injection',
  'xss',
  'csrf',
  'jwt',
  'broken-auth',
  'broken-authz',
  'idor',
  'path-traversal',
  'header-injection',
  'privilege-escalation',
  'file-upload',
  'sensitive-data-exposure',
]);

/** Every valid severity rating (design.md → SecurityFinding.severity). */
const VALID_SEVERITIES: ReadonlySet<string> = new Set([
  'low',
  'medium',
  'high',
  'critical',
]);

// ── Generators ───────────────────────────────────────────────────────────────

/**
 * A secret value. Restricted to non-empty alphanumeric strings so that:
 *   - it is a value the redaction boundary actually redacts (empty values are
 *     ignored), and
 *   - it cannot contain the angle-bracket characters of the `<redacted>`
 *     placeholder, so redaction can never reconstruct it at a seam.
 */
const secretArb = fc.stringMatching(/^[A-Za-z0-9]{4,16}$/);

/** A set of secret values supplied through the environment. */
const secretsArb = fc.array(secretArb, { minLength: 1, maxLength: 5 });

/** A non-empty identifier-like string used for endpoint ids and names. */
const idArb = fc.stringMatching(/^[A-Za-z][A-Za-z0-9_-]{0,15}$/);

/** A URL path with optional path placeholder, query string, and file token. */
const urlArb = fc
  .record({
    segments: fc.array(fc.stringMatching(/^[A-Za-z][A-Za-z0-9_-]*$/), {
      minLength: 1,
      maxLength: 4,
    }),
    withPlaceholder: fc.boolean(),
    withQuery: fc.boolean(),
  })
  .map(({ segments, withPlaceholder, withQuery }) => {
    let url = '/' + segments.join('/');
    if (withPlaceholder) {
      url += '/:id';
    }
    if (withQuery) {
      url += '?page=1&sort=name';
    }
    return url;
  });

/** A single Postman request. Variety here exercises more probe categories. */
const requestArb: fc.Arbitrary<PostmanRequest> = fc.record({
  name: idArb,
  endpointId: idArb,
  method: fc.constantFrom('GET', 'POST', 'PUT', 'PATCH', 'DELETE'),
  url: urlArb,
  headers: fc.option(
    fc.array(
      fc.record({
        key: fc.constantFrom('Authorization', 'Content-Type', 'Accept'),
        value: fc.string({ minLength: 1, maxLength: 8 }),
      }),
      { maxLength: 3 }
    ),
    { nil: undefined }
  ),
  body: fc.option(fc.constant({ field: 'value' }), { nil: undefined }),
});

/** A domain folder of requests. */
const folderArb = fc.record({
  name: fc.constantFrom(...DOMAINS),
  items: fc.array(requestArb, { minLength: 0, maxLength: 4 }),
});

/** An arbitrary generated Postman collection. */
const collectionArb: fc.Arbitrary<PostmanCollection> = fc
  .array(folderArb, { minLength: 0, maxLength: 4 })
  .map((folders) => ({
    info: { schema: 'v2.1.0' as const },
    folders,
  }));

/** A minimal Postman environment (its contents are irrelevant to this test). */
const env: PostmanEnvironment = {
  name: 'Local',
  values: [{ key: 'BASE_URL', value: '{{BASE_URL}}' }],
};

/**
 * Builds a probe executor that reports every probe as vulnerable and returns an
 * observed response that embeds every supplied secret value verbatim (along
 * with surrounding noise). This forces the audit to record a finding for every
 * derived probe and forces the redaction boundary to run on a response that
 * genuinely contains secrets.
 */
function makeLeakyExecutor(secrets: string[]): ProbeExecutor {
  const observedResponse =
    'HTTP/1.1 200 OK\n' +
    secrets.map((s, i) => `token${i}=${s};`).join(' ') +
    '\n{"status":"leaked"}';
  return () => ({ vulnerable: true, observedResponse });
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: api-audit-testing-automation, Property 15: Security findings are well-formed', () => {
  it('records every finding with a real endpoint, valid category, valid severity, and non-empty payloadRef, leaking no secret', async () => {
    await fc.assert(
      fc.asyncProperty(collectionArb, secretsArb, async (collection, secrets) => {
        // Every endpoint id that a finding may legitimately reference.
        const knownEndpointIds = new Set<string>();
        for (const folder of collection.folders) {
          for (const request of folder.items) {
            knownEndpointIds.add(request.endpointId);
          }
        }

        const { findings } = await auditSecurity(collection, env, {
          probeExecutor: makeLeakyExecutor(secrets),
          secretValues: secrets,
        });

        for (const finding of findings) {
          // 7.6 — references the affected endpoint by a non-empty id that maps
          // to a real request in the collection.
          expect(typeof finding.endpointId).toBe('string');
          expect(finding.endpointId.length).toBeGreaterThan(0);
          expect(knownEndpointIds.has(finding.endpointId)).toBe(true);

          // 7.6 — a valid vulnerability category.
          expect(VALID_CATEGORIES.has(finding.category)).toBe(true);

          // 7.6 — a valid severity rating.
          expect(VALID_SEVERITIES.has(finding.severity)).toBe(true);

          // 7.6 / 7.7 — a non-empty payload reference for the crafted payload.
          expect(typeof finding.payloadRef).toBe('string');
          expect(finding.payloadRef.length).toBeGreaterThan(0);

          // 7.7 — no supplied secret appears verbatim in the observed response.
          if (finding.observedResponse !== undefined) {
            for (const secret of secrets) {
              expect(finding.observedResponse).not.toContain(secret);
            }
          }
        }
      }),
      { numRuns: 100 }
    );
  });
});
