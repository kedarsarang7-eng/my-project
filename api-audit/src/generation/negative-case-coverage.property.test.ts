/**
 * Property-based test for the Test_Generator's negative test-case coverage.
 *
 * Feature: api-audit-testing-automation, Property 14: Negative-case coverage
 * follows endpoint capabilities.
 *
 * Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
 *
 * For any API_Catalog entry, the generated negative cases must match its
 * recorded capabilities, with no fabricated cases for capabilities the endpoint
 * does not have (the mapping is iff in both directions):
 *   - missing-required-field and invalid-value cases  <-> it defines required
 *     submittable fields (6.1);
 *   - invalid-token and expired-token cases           <-> it requires
 *     authentication (6.2);
 *   - a missing-permission case                        <-> it requires
 *     authorization (6.3);
 *   - an invalid-identifier case                       <-> it accepts an
 *     identifier (6.4);
 *   - an invalid-upload case                           <-> it accepts file
 *     uploads (6.5);
 *   - a malformed-query case                           <-> it is a GraphQL
 *     operation, and a malformed-message case <-> it is a WebSocket
 *     route/event (6.6).
 *
 * The arbitrary builds each capability from an independent flag using parameter
 * names/types that unambiguously trigger (or avoid) exactly one detector, so
 * the expected negative-case set can be derived directly from the flags and
 * compared against the generator's output.
 */

import fc from 'fast-check';

import { buildNegativeTests } from './test-generator';
import {
  CatalogEntry,
  Determinable,
  GeneratedTest,
  ParamSpec,
  SecurityMeta,
} from '../types';

/** REST verbs — none of which are GraphQL or WebSocket operations (6.6). */
const REST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
/** GraphQL operation types recorded in `methodOrOperation` (6.6). */
const GRAPHQL_OPS = ['query', 'mutation', 'subscription'];
/** WebSocket operation types recorded in `methodOrOperation` (6.6). */
const WS_OPS = ['ws-route', 'ws-event'];

/**
 * Field names that are plain submittable fields: not identifiers (no `id`
 * suffix, no uuid/guid/objectId fragment) and not file uploads (no file/upload
 * name fragment). Using these for the required-field capability keeps it from
 * accidentally triggering the identifier (6.4) or file-upload (6.5) detectors.
 */
const PLAIN_FIELD_NAMES = [
  'title',
  'amount',
  'description',
  'status',
  'quantity',
  'note',
  'price',
  'color',
  'label',
  'message',
];

/** The independent capability flags an endpoint can carry. */
interface CapabilityFlags {
  requiredField: boolean;
  auth: SecurityMeta['enforcement'];
  identifier: boolean;
  fileUpload: boolean;
  kind: 'rest' | 'graphql' | 'ws';
  operation: string;
}

const flagsArb: fc.Arbitrary<CapabilityFlags> = fc
  .record({
    requiredField: fc.boolean(),
    auth: fc.constantFrom<SecurityMeta['enforcement']>(
      'public',
      'authenticated',
      'authorized',
    ),
    identifier: fc.boolean(),
    fileUpload: fc.boolean(),
    kind: fc.constantFrom<'rest' | 'graphql' | 'ws'>('rest', 'graphql', 'ws'),
  })
  .chain((base) => {
    const operationArb =
      base.kind === 'rest'
        ? fc.constantFrom(...REST_METHODS)
        : base.kind === 'graphql'
          ? fc.constantFrom(...GRAPHQL_OPS)
          : fc.constantFrom(...WS_OPS);
    return operationArb.map((operation) => ({ ...base, operation }));
  });

/** Build a catalog entry whose negative-case capabilities equal the flags. */
function entryFromFlags(
  flags: CapabilityFlags,
  fieldName: string,
): CatalogEntry {
  const bodyParams: ParamSpec[] = [];

  // 6.1 — a required submittable body field drives the missing/invalid cases.
  if (flags.requiredField) {
    bodyParams.push({ name: fieldName, in: 'body', type: 'string', required: true });
  }

  // 6.5 — a file-typed body param (kept optional so it never counts as a
  // required field) drives the invalid-upload case independently of 6.1.
  if (flags.fileUpload) {
    bodyParams.push({ name: 'upload', in: 'body', type: 'file', required: false });
  }

  // 6.4 — a path parameter is an identifier; path params are not counted as
  // required submittable fields, so this stays independent of 6.1.
  const pathParams: Determinable<ParamSpec[]> = flags.identifier
    ? [{ name: 'id', in: 'path', type: 'string', required: true }]
    : 'undetermined';

  const security: SecurityMeta =
    flags.auth === 'authorized'
      ? { enforcement: 'authorized', requiredPermission: 'records:write' }
      : { enforcement: flags.auth };

  return {
    id: `ep-${fieldName}-${flags.kind}-${flags.auth}`,
    urlPath: '/resource',
    methodOrOperation: flags.operation,
    module: 'undetermined',
    controllerOrHandler: 'undetermined',
    requestBodyParams: bodyParams.length > 0 ? bodyParams : 'undetermined',
    // Query params are left undetermined so identifier/file detection is driven
    // solely by the controlled body/path params above.
    queryParams: 'undetermined',
    pathParams,
    // Headers stay undetermined so no multipart content-type accidentally
    // triggers the file-upload detector.
    headers: 'undetermined',
    security,
    requestSchema: 'undetermined',
    responseSchema: 'undetermined',
    errorResponses: 'undetermined',
    validationRules: 'undetermined',
    businessRules: 'undetermined',
    undeterminedReasons: {},
  };
}

/** The negative-case test types expected for a given set of capability flags. */
function expectedNegativeTypes(flags: CapabilityFlags): Set<GeneratedTest['type']> {
  const expected = new Set<GeneratedTest['type']>();

  if (flags.requiredField) {
    expected.add('negative-missing-field');
    expected.add('negative-invalid-value');
  }
  if (flags.auth === 'authenticated' || flags.auth === 'authorized') {
    expected.add('negative-bad-token');
    expected.add('negative-expired-token');
  }
  if (flags.auth === 'authorized') {
    expected.add('negative-no-permission');
  }
  if (flags.identifier) {
    expected.add('negative-bad-id');
  }
  if (flags.fileUpload) {
    expected.add('negative-bad-upload');
  }
  if (flags.kind === 'graphql') {
    expected.add('negative-malformed-graphql');
  }
  if (flags.kind === 'ws') {
    expected.add('negative-malformed-ws');
  }

  return expected;
}

describe('Feature: api-audit-testing-automation, Property 14: Negative-case coverage follows endpoint capabilities', () => {
  it('generates exactly the negative cases the endpoint capabilities support, and no others', () => {
    fc.assert(
      fc.property(
        flagsArb,
        fc.constantFrom(...PLAIN_FIELD_NAMES),
        (flags, fieldName) => {
          const entry = entryFromFlags(flags, fieldName);
          const tests = buildNegativeTests(entry);

          // Every generated case is a well-formed negative test attached to the
          // entry, with a non-empty Postman script.
          for (const test of tests) {
            expect(test.endpointId).toBe(entry.id);
            expect(test.type.startsWith('negative-')).toBe(true);
            expect(test.script.length).toBeGreaterThan(0);
          }

          const expected = expectedNegativeTypes(flags);
          const actual = new Set(tests.map((t) => t.type));

          // iff in both directions: the generated negative-case types equal
          // exactly the set the capabilities demand — nothing missing, nothing
          // fabricated.
          expect(actual).toEqual(expected);

          // No capability produces a duplicate case, so one test per type.
          expect(tests.length).toBe(expected.size);
        },
      ),
      { numRuns: 200 },
    );
  });
});
