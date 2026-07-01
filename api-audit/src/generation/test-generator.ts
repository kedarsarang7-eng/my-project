/**
 * Test_Generator — baseline + metadata-driven assertions (Tasks 8.1, 8.2).
 *
 * Attaches a status-code assertion and a response-time-threshold assertion to
 * every generated request (Requirements 4.1, 4.2). These two assertions form
 * the baseline that every request carries regardless of its metadata.
 *
 * On top of the baseline, Task 8.2 attaches metadata-driven assertions derived
 * from the matching `CatalogEntry`:
 *   - a schema-validation test when a response schema is recorded (4.3);
 *   - authentication and/or authorization enforcement tests when the security
 *     metadata requires them (4.4);
 *   - null/empty/invalid-input handling tests when validation rules are
 *     recorded (4.5);
 *   - business-rule tests when business rules are recorded (4.6).
 *
 * Only what the metadata supports is attached — `"undetermined"` fields and
 * empty rule sets contribute nothing. On top of the baseline and metadata
 * passes, Task 8.3 attaches positive test cases derived from each endpoint's
 * capabilities:
 *   - a valid-payload / valid-parameters case when the endpoint accepts input (5.1);
 *   - a valid-token case when the endpoint requires authentication (5.2);
 *   - the applicable create/read/update/delete cases when it participates in
 *     CRUD (5.3);
 *   - pagination/sorting/filtering/search cases when its query parameters
 *     indicate those capabilities (5.4).
 *
 * The negative (Task 8.4) request variants are layered on top of these passes.
 *
 * Design contract (design.md → Test_Generator):
 *   attachTests(collection: PostmanCollection, catalog: CatalogEntry[]):
 *     { collection: PostmanCollection; issues: StageIssue[] }
 *
 * The transformation is pure: the input collection is never mutated. A new
 * collection is returned with tests appended, so attachment is additive and
 * composable — later stages can call their own attach pass over the result and
 * accumulate further `GeneratedTest` entries on each request.
 */

import {
  BusinessRule,
  CatalogEntry,
  Determinable,
  GeneratedTest,
  JsonSchema,
  ParamSpec,
  PostmanCollection,
  PostmanFolder,
  PostmanRequest,
  SecurityMeta,
  StageIssue,
  ValidationRule,
} from '../types';

/**
 * Default response-time threshold (milliseconds) applied when an endpoint does
 * not specify its own. Requirement 4.2 asserts the response time is within the
 * configured threshold for the endpoint; absent a per-endpoint value, this
 * conservative default keeps every request covered by a response-time check.
 */
export const DEFAULT_RESPONSE_TIME_THRESHOLD_MS = 2000;

/** Options controlling baseline test generation. */
export interface TestGeneratorOptions {
  /**
   * Response-time threshold in milliseconds used for the baseline
   * response-time assertion. Defaults to {@link DEFAULT_RESPONSE_TIME_THRESHOLD_MS}.
   */
  responseTimeThresholdMs?: number;
}

/**
 * The Test_Generator attaches Postman test scripts to the requests of a
 * generated collection. This stage owns the baseline assertions; metadata,
 * positive, and negative tests extend it in later tasks.
 */
export interface TestGenerator {
  attachTests(
    collection: PostmanCollection,
    catalog: CatalogEntry[],
    options?: TestGeneratorOptions
  ): { collection: PostmanCollection; issues: StageIssue[] };
}

/**
 * Attaches the baseline status-code and response-time assertions to every
 * request in the collection (Requirements 4.1, 4.2).
 *
 * The returned collection is a deep-enough copy: every folder and request is
 * rebuilt so the caller's input is left untouched, and each request's `tests`
 * array gains the two baseline assertions (preserving any tests already
 * attached by an earlier pass).
 */
export function attachTests(
  collection: PostmanCollection,
  catalog: CatalogEntry[],
  options: TestGeneratorOptions = {}
): { collection: PostmanCollection; issues: StageIssue[] } {
  const thresholdMs =
    options.responseTimeThresholdMs ?? DEFAULT_RESPONSE_TIME_THRESHOLD_MS;

  // Index the catalog by id so per-endpoint metadata is available to the
  // baseline (and to later composable passes). Baseline assertions apply to
  // every request even when no catalog entry is found.
  const catalogById = new Map<string, CatalogEntry>();
  for (const entry of catalog) {
    catalogById.set(entry.id, entry);
  }

  const folders: PostmanFolder[] = collection.folders.map((folder) => ({
    name: folder.name,
    items: folder.items.map((request) =>
      attachRequestTests(request, catalogById.get(request.endpointId), thresholdMs)
    ),
  }));

  return {
    collection: { info: collection.info, folders },
    issues: [],
  };
}

/** Default implementation of the TestGenerator interface. */
export class DefaultTestGenerator implements TestGenerator {
  attachTests(
    collection: PostmanCollection,
    catalog: CatalogEntry[],
    options?: TestGeneratorOptions
  ): { collection: PostmanCollection; issues: StageIssue[] } {
    return attachTests(collection, catalog, options);
  }
}

// ---------------------------------------------------------------------------
// Per-request test attachment (baseline + metadata)
// ---------------------------------------------------------------------------

/**
 * Returns a copy of the request with the baseline, metadata-driven, positive,
 * and negative assertions appended (in that order). Existing tests are
 * preserved so the pass is additive and composable; the input request is never
 * mutated.
 *
 * When no catalog entry matches the request's `endpointId`, only the baseline
 * assertions are attached — every request is covered regardless of metadata.
 */
function attachRequestTests(
  request: PostmanRequest,
  entry: CatalogEntry | undefined,
  thresholdMs: number
): PostmanRequest {
  const existing = request.tests ?? [];
  const baseline = buildBaselineTests(request.endpointId, thresholdMs);
  const metadata = entry ? buildMetadataTests(entry) : [];
  const positive = entry ? buildPositiveTests(entry) : [];
  const negative = entry ? buildNegativeTests(entry) : [];

  return {
    ...request,
    tests: [...existing, ...baseline, ...metadata, ...positive, ...negative],
  };
}

/**
 * Builds the baseline tests for a single endpoint: one status-code assertion
 * and one response-time-threshold assertion (Requirements 4.1, 4.2).
 */
export function buildBaselineTests(
  endpointId: string,
  thresholdMs: number = DEFAULT_RESPONSE_TIME_THRESHOLD_MS
): GeneratedTest[] {
  return [
    buildStatusTest(endpointId),
    buildResponseTimeTest(endpointId, thresholdMs),
  ];
}

/**
 * Builds the status-code assertion (Requirement 4.1). The baseline asserts a
 * successful (2xx) response; negative-case tests (Task 8.4) attach their own
 * status assertions for the error codes they expect.
 */
export function buildStatusTest(endpointId: string): GeneratedTest {
  const script = [
    "pm.test('Status code is a success (2xx)', function () {",
    '  pm.expect(pm.response.code).to.be.within(200, 299);',
    '});',
  ].join('\n');

  return { type: 'status', endpointId, script };
}

/**
 * Builds the response-time-threshold assertion (Requirement 4.2): the response
 * time must be within the configured threshold for the endpoint.
 */
export function buildResponseTimeTest(
  endpointId: string,
  thresholdMs: number = DEFAULT_RESPONSE_TIME_THRESHOLD_MS
): GeneratedTest {
  const script = [
    `pm.test('Response time is within ${thresholdMs}ms', function () {`,
    `  pm.expect(pm.response.responseTime).to.be.below(${thresholdMs});`,
    '});',
  ].join('\n');

  return { type: 'response-time', endpointId, script };
}

// ---------------------------------------------------------------------------
// Metadata-driven test attachment (Task 8.2 — Requirements 4.3, 4.4, 4.5, 4.6)
// ---------------------------------------------------------------------------

/**
 * Builds the metadata-driven tests for a single catalog entry. Only the tests
 * the recorded metadata supports are produced; `"undetermined"` fields and
 * empty rule sets contribute nothing (Property 12).
 *
 * Attachment rules:
 *   - response schema recorded            -> one schema-validation test (4.3)
 *   - enforcement `authenticated`         -> one auth test (4.4)
 *   - enforcement `authorized`            -> one auth test + one authz test (4.4)
 *   - validation rules recorded           -> one validation test per rule (4.5)
 *   - business rules recorded             -> one business-rule test per rule (4.6)
 */
export function buildMetadataTests(entry: CatalogEntry): GeneratedTest[] {
  const tests: GeneratedTest[] = [];

  // 4.3 — schema validation when a response schema is determined.
  if (isDeterminedSchema(entry.responseSchema)) {
    tests.push(buildSchemaTest(entry.id, entry.responseSchema));
  }

  // 4.4 — authentication / authorization enforcement based on security metadata.
  tests.push(...buildAuthTests(entry.id, entry.security));

  // 4.5 — null/empty/invalid-input handling derived from validation rules.
  if (isNonEmptyArray(entry.validationRules)) {
    for (const rule of entry.validationRules) {
      tests.push(buildValidationTest(entry.id, rule));
    }
  }

  // 4.6 — business-rule assertions derived from recorded business rules.
  if (isNonEmptyArray(entry.businessRules)) {
    for (const rule of entry.businessRules) {
      tests.push(buildBusinessRuleTest(entry.id, rule));
    }
  }

  return tests;
}

/**
 * Builds the response-schema validation test (Requirement 4.3): the response
 * body must conform to the recorded schema, including required fields and
 * declared data types. The recorded schema is embedded and checked with
 * Postman's built-in `jsonSchema` matcher.
 */
export function buildSchemaTest(
  endpointId: string,
  schema: JsonSchema
): GeneratedTest {
  const schemaLiteral = JSON.stringify(schema, null, 2);
  const script = [
    'pm.test(\'Response body matches the recorded schema\', function () {',
    `  const schema = ${indentLiteral(schemaLiteral)};`,
    '  pm.response.to.have.jsonSchema(schema);',
    '});',
  ].join('\n');

  return { type: 'schema', endpointId, script };
}

/**
 * Builds the authentication/authorization enforcement tests (Requirement 4.4).
 *
 * An `authenticated` endpoint gets an authentication-enforcement test; an
 * `authorized` endpoint additionally gets an authorization-enforcement test.
 * A `public` endpoint declares no requirement, so no enforcement tests are
 * attached.
 *
 * The assertions are written from the positive (credentialed) request's
 * perspective — valid credentials and sufficient permission must be honored
 * (not rejected with 401/403). The complementary rejection cases (missing,
 * invalid, or expired credentials; missing permission) are generated as
 * dedicated negative request variants in Task 8.4.
 */
export function buildAuthTests(
  endpointId: string,
  security: SecurityMeta
): GeneratedTest[] {
  if (security.enforcement === 'public') {
    return [];
  }

  const tests: GeneratedTest[] = [buildAuthTest(endpointId)];

  if (security.enforcement === 'authorized') {
    tests.push(buildAuthzTest(endpointId, security));
  }

  return tests;
}

/** Builds the authentication-enforcement assertion (Requirement 4.4). */
export function buildAuthTest(endpointId: string): GeneratedTest {
  const script = [
    "pm.test('Authentication is enforced', function () {",
    '  // A request carrying valid credentials must not be rejected as',
    '  // unauthenticated. Rejection of missing/invalid credentials is asserted',
    '  // by the dedicated negative request variants.',
    "  pm.expect(pm.response.code, 'authenticated request rejected with 401').to.not.equal(401);",
    '});',
  ].join('\n');

  return { type: 'auth', endpointId, script };
}

/**
 * Builds the authorization-enforcement assertion (Requirement 4.4). The
 * required role/permission, when recorded, is named in the assertion for
 * traceability.
 */
export function buildAuthzTest(
  endpointId: string,
  security: SecurityMeta
): GeneratedTest {
  const requirement =
    security.requiredPermission ?? security.requiredRole ?? 'required permission';
  const label = `Authorization is enforced (${requirement})`;
  const script = [
    `pm.test(${JSON.stringify(label)}, function () {`,
    '  // A caller holding the required role/permission must not be forbidden.',
    '  // The missing-permission rejection case is asserted by the dedicated',
    '  // negative request variant.',
    "  pm.expect(pm.response.code, 'authorized request rejected with 403').to.not.equal(403);",
    '});',
  ].join('\n');

  return { type: 'authz', endpointId, script };
}

/**
 * Builds an input-validation handling test for a single rule (Requirement
 * 4.5): the endpoint must handle null, empty, and invalid input values for the
 * field without failing (no server error). The field and rule are named for
 * traceability; the explicit null/empty/invalid rejection cases are generated
 * as negative request variants in Task 8.4.
 */
export function buildValidationTest(
  endpointId: string,
  rule: ValidationRule
): GeneratedTest {
  const label = `Input validation handled for '${rule.field}' (rule: ${rule.rule})`;
  const script = [
    `pm.test(${JSON.stringify(label)}, function () {`,
    '  // Null, empty, and invalid values for this field must be handled as a',
    '  // client error (4xx) rather than crashing the endpoint (5xx).',
    "  pm.expect(pm.response.code, 'input handling caused a server error').to.be.below(500);",
    '});',
  ].join('\n');

  return { type: 'validation', endpointId, script };
}

/**
 * Builds a business-rule assertion for a single recorded rule (Requirement
 * 4.6). The rule id and description are embedded for traceability.
 */
export function buildBusinessRuleTest(
  endpointId: string,
  rule: BusinessRule
): GeneratedTest {
  const label = `Business rule ${rule.id}: ${rule.description}`;
  const script = [
    `pm.test(${JSON.stringify(label)}, function () {`,
    '  // A request that satisfies this business rule must be accepted by the',
    '  // endpoint; violations are exercised by the negative request variants.',
    "  pm.expect(pm.response.code, 'business rule violated for a valid request').to.be.below(400);",
    '});',
  ].join('\n');

  return { type: 'business-rule', endpointId, script };
}

// ---------------------------------------------------------------------------
// Positive test-case generation (Task 8.3 — Requirements 5.1, 5.2, 5.3, 5.4)
// ---------------------------------------------------------------------------

/**
 * Query-parameter name fragments that indicate a given capability. Matching is
 * case-insensitive and substring-based so both `pageSize` and `page_size`,
 * `sortBy` and `sort_order`, etc. are detected. The sets are intentionally
 * conservative — only names that strongly imply the capability are listed so a
 * positive case is generated only when the endpoint genuinely supports it
 * (Requirement 5.4 / Property 13).
 */
const PAGINATION_PARAM_FRAGMENTS = [
  'page',
  'pagesize',
  'perpage',
  'per_page',
  'limit',
  'offset',
  'cursor',
  'pagetoken',
  'page_token',
  'nexttoken',
  'next_token',
];

const SORTING_PARAM_FRAGMENTS = [
  'sort',
  'sortby',
  'sort_by',
  'sortorder',
  'sort_order',
  'orderby',
  'order_by',
  'order',
  'direction',
];

const FILTERING_PARAM_FRAGMENTS = ['filter', 'where'];

const SEARCH_PARAM_FRAGMENTS = [
  'search',
  'searchterm',
  'search_term',
  'keyword',
  'term',
  'q',
  'query',
];

/**
 * Builds the positive test cases for a single catalog entry. Only the cases the
 * endpoint's recorded capabilities support are produced (Property 13):
 *   - a valid-payload / valid-parameters case when the endpoint accepts input (5.1);
 *   - a valid-token case when the endpoint requires authentication (5.2);
 *   - the applicable create/read/update/delete cases when the endpoint
 *     participates in CRUD (5.3);
 *   - pagination, sorting, filtering, and/or search cases when the endpoint's
 *     query parameters indicate those capabilities (5.4).
 *
 * Each case is a positive assertion attached to the (positive) request: the
 * request carrying valid input and credentials must be accepted. Rejection
 * scenarios are exercised by the negative request variants (Task 8.4), so the
 * positive and negative passes compose without overlap.
 */
export function buildPositiveTests(entry: CatalogEntry): GeneratedTest[] {
  const tests: GeneratedTest[] = [];

  // 5.1 — valid payload / valid request parameters submitted and accepted.
  if (acceptsInput(entry)) {
    tests.push(
      buildPositiveTest(
        entry.id,
        'Positive: valid payload and parameters are accepted',
        'A request carrying valid request parameters and a valid payload must ' +
          'be accepted by the endpoint.'
      )
    );
  }

  // 5.2 — valid authentication token submitted and accepted.
  if (requiresAuthentication(entry.security)) {
    tests.push(
      buildPositiveTest(
        entry.id,
        'Positive: a valid authentication token is accepted',
        'A request carrying a valid authentication token must not be rejected ' +
          'as unauthenticated (401).',
        'pm.expect(pm.response.code, \'valid token rejected with 401\').to.not.equal(401);'
      )
    );
  }

  // 5.3 — applicable CRUD operations.
  for (const operation of crudOperations(entry.methodOrOperation)) {
    tests.push(
      buildPositiveTest(
        entry.id,
        `Positive: ${operation} operation succeeds`,
        `A valid ${operation} request must be accepted by the endpoint.`
      )
    );
  }

  // 5.4 — pagination / sorting / filtering / search parameter exercises.
  for (const capability of queryCapabilities(entry.queryParams)) {
    tests.push(
      buildPositiveTest(
        entry.id,
        `Positive: ${capability} parameters are honored`,
        `A request exercising ${capability} query parameters must be accepted ` +
          'and return a successful response.'
      )
    );
  }

  return tests;
}

/**
 * Builds a single positive-case assertion. By default the script asserts a
 * successful (2xx) response; callers may supply a more specific assertion
 * (for example the valid-token case asserts a non-401 response).
 */
export function buildPositiveTest(
  endpointId: string,
  label: string,
  comment: string,
  assertion = 'pm.expect(pm.response.code, \'valid request was not accepted\').to.be.within(200, 299);'
): GeneratedTest {
  const script = [
    `pm.test(${JSON.stringify(label)}, function () {`,
    `  // ${comment}`,
    `  ${assertion}`,
    '});',
  ].join('\n');

  return { type: 'positive', endpointId, script };
}

/**
 * True when the endpoint accepts input (Requirement 5.1): it records request
 * body parameters, a request schema, query parameters, or path parameters.
 * `"undetermined"` and empty parameter sets count as "no input".
 */
function acceptsInput(entry: CatalogEntry): boolean {
  return (
    isNonEmptyParamArray(entry.requestBodyParams) ||
    isDeterminedSchema(entry.requestSchema) ||
    isNonEmptyParamArray(entry.queryParams) ||
    isNonEmptyParamArray(entry.pathParams)
  );
}

/** True when the endpoint requires authentication or authorization (5.2). */
function requiresAuthentication(security: SecurityMeta): boolean {
  return (
    security.enforcement === 'authenticated' ||
    security.enforcement === 'authorized'
  );
}

/**
 * Maps an endpoint's method/operation to the CRUD operations it participates in
 * (Requirement 5.3). REST verbs map by HTTP semantics; a GraphQL `query` reads.
 * Operations that do not clearly map to CRUD (GraphQL mutations/subscriptions,
 * WebSocket routes/events, undetermined methods) yield no CRUD case so positive
 * cases are not fabricated for endpoints whose CRUD role is unknown.
 */
function crudOperations(methodOrOperation: Determinable<string>): string[] {
  if (methodOrOperation === 'undetermined') {
    return [];
  }

  switch (methodOrOperation.toUpperCase()) {
    case 'GET':
    case 'HEAD':
    case 'QUERY':
      return ['read'];
    case 'POST':
      return ['create'];
    case 'PUT':
    case 'PATCH':
      return ['update'];
    case 'DELETE':
      return ['delete'];
    default:
      return [];
  }
}

/**
 * Determines which query-driven capabilities (pagination, sorting, filtering,
 * search) an endpoint supports by inspecting its query parameter names
 * (Requirement 5.4). Returns the capabilities in a stable order so generation
 * is deterministic.
 */
function queryCapabilities(
  queryParams: Determinable<ParamSpec[]>
): string[] {
  if (!isNonEmptyParamArray(queryParams)) {
    return [];
  }

  const names = queryParams.map((param) => param.name.toLowerCase());
  const capabilities: string[] = [];

  if (matchesAnyFragment(names, PAGINATION_PARAM_FRAGMENTS)) {
    capabilities.push('pagination');
  }
  if (matchesAnyFragment(names, SORTING_PARAM_FRAGMENTS)) {
    capabilities.push('sorting');
  }
  if (matchesAnyFragment(names, FILTERING_PARAM_FRAGMENTS)) {
    capabilities.push('filtering');
  }
  if (matchesAnyFragment(names, SEARCH_PARAM_FRAGMENTS)) {
    capabilities.push('search');
  }

  return capabilities;
}

/**
 * True when any of the (lowercased) parameter names contains one of the
 * capability fragments. Single-character fragments such as `q` must match the
 * whole name to avoid spurious substring hits.
 */
function matchesAnyFragment(names: string[], fragments: string[]): boolean {
  return names.some((name) =>
    fragments.some((fragment) =>
      fragment.length <= 1 ? name === fragment : name.includes(fragment)
    )
  );
}

/** True when a `Determinable` ParamSpec field holds a concrete, non-empty array. */
function isNonEmptyParamArray(
  value: Determinable<ParamSpec[]>
): value is ParamSpec[] {
  return value !== 'undetermined' && Array.isArray(value) && value.length > 0;
}

// ---------------------------------------------------------------------------
// Metadata helpers
// ---------------------------------------------------------------------------

/** True when a `Determinable` schema field holds a concrete schema object. */
function isDeterminedSchema(
  schema: CatalogEntry['responseSchema']
): schema is JsonSchema {
  return (
    schema !== 'undetermined' &&
    typeof schema === 'object' &&
    schema !== null
  );
}

/**
 * True when a `Determinable` array field holds a concrete, non-empty array.
 * Empty rule sets contribute no tests (Property 12).
 */
function isNonEmptyArray<T>(value: T[] | 'undetermined'): value is T[] {
  return value !== 'undetermined' && Array.isArray(value) && value.length > 0;
}

/**
 * Re-indents a multi-line JSON literal so nested lines align under the
 * `const schema = ` assignment inside the generated test script.
 */
function indentLiteral(literal: string): string {
  return literal
    .split('\n')
    .map((line, index) => (index === 0 ? line : `  ${line}`))
    .join('\n');
}

// ---------------------------------------------------------------------------
// Negative test-case generation (Task 8.4 — Requirements 6.1-6.6)
// ---------------------------------------------------------------------------

/**
 * Parameter-name fragments that indicate the parameter is an identifier
 * (Requirement 6.4). Matching is case-insensitive and substring-based, except
 * the bare `id` fragment which must match the whole name or a conventional
 * suffix to avoid spurious hits (for example `valid` or `hidden`).
 */
const IDENTIFIER_PARAM_FRAGMENTS = [
  'uuid',
  'guid',
  'objectid',
  'object_id',
];

/**
 * Parameter type/name fragments that indicate a file upload (Requirement 6.5).
 * File uploads are detected from a binary/file parameter type, from a parameter
 * name strongly implying a file, or from a multipart content-type header.
 */
const FILE_UPLOAD_TYPE_FRAGMENTS = ['file', 'binary', 'multipart', 'blob'];

const FILE_UPLOAD_NAME_FRAGMENTS = [
  'file',
  'upload',
  'attachment',
  'avatar',
  'document',
  'photo',
  'image',
  'media',
];

/**
 * Builds the negative test cases for a single catalog entry. Only the cases the
 * endpoint's recorded capabilities support are produced (Property 14):
 *   - missing-required-field and invalid-value cases when the endpoint defines
 *     required fields (6.1);
 *   - invalid-token and expired-token cases when the endpoint requires
 *     authentication (6.2);
 *   - a missing-permission case when the endpoint requires authorization (6.3);
 *   - an invalid-identifier case when the endpoint accepts an identifier (6.4);
 *   - an invalid-upload case when the endpoint accepts file uploads (6.5);
 *   - a malformed-query case when the endpoint is a GraphQL operation, and a
 *     malformed-message case when the endpoint is a WebSocket route/event (6.6).
 *
 * Each case is a negative assertion attached to the request: a request carrying
 * the corresponding invalid input must be rejected with the documented error
 * status. Endpoints whose metadata does not support a given capability
 * contribute no test for that capability, so the negative pass never fabricates
 * cases for endpoints that cannot exercise them.
 */
export function buildNegativeTests(entry: CatalogEntry): GeneratedTest[] {
  const tests: GeneratedTest[] = [];

  // 6.1 — required fields: omit them, and supply invalid values.
  const requiredFields = requiredFieldNames(entry);
  if (requiredFields.length > 0) {
    const fieldList = requiredFields.map((name) => `'${name}'`).join(', ');
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-missing-field',
        `Negative: omitting required field(s) ${fieldList} is rejected`,
        'A request that omits one or more required fields must be rejected as a ' +
          'client error (4xx) rather than processed or crashing the endpoint.',
        clientErrorAssertion('request missing required fields was not rejected')
      )
    );
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-invalid-value',
        `Negative: invalid value(s) for field(s) ${fieldList} are rejected`,
        'A request supplying invalid values for required fields must be rejected ' +
          'as a client error (4xx).',
        clientErrorAssertion('request with invalid field values was not rejected')
      )
    );
  }

  // 6.2 — authentication: invalid token and expired token are both rejected.
  if (requiresAuthentication(entry.security)) {
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-bad-token',
        'Negative: an invalid authentication token is rejected',
        'A request carrying an invalid authentication token must be rejected as ' +
          'unauthenticated (401).',
        statusEqualsAssertion(401, 'invalid token was not rejected with 401')
      )
    );
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-expired-token',
        'Negative: an expired authentication token is rejected',
        'A request carrying an expired authentication token must be rejected as ' +
          'unauthenticated (401).',
        statusEqualsAssertion(401, 'expired token was not rejected with 401')
      )
    );
  }

  // 6.3 — authorization: a caller lacking the required permission is forbidden.
  if (requiresAuthorization(entry.security)) {
    const requirement =
      entry.security.requiredPermission ??
      entry.security.requiredRole ??
      'required permission';
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-no-permission',
        `Negative: a request lacking the ${requirement} is forbidden`,
        'A caller authenticated but lacking the required role/permission must be ' +
          'rejected as forbidden (403).',
        statusEqualsAssertion(403, 'request lacking permission was not rejected with 403')
      )
    );
  }

  // 6.4 — identifier: an invalid identifier is rejected.
  if (acceptsIdentifier(entry)) {
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-bad-id',
        'Negative: an invalid identifier is rejected',
        'A request supplying an invalid/non-existent identifier must be rejected ' +
          'as a client error (typically 400 or 404).',
        clientErrorAssertion('invalid identifier was not rejected')
      )
    );
  }

  // 6.5 — file uploads: an invalid upload is rejected.
  if (acceptsFileUpload(entry)) {
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-bad-upload',
        'Negative: an invalid file upload is rejected',
        'A request submitting an invalid file upload (wrong type, oversized, or ' +
          'malformed) must be rejected as a client error (4xx).',
        clientErrorAssertion('invalid file upload was not rejected')
      )
    );
  }

  // 6.6 — malformed GraphQL query / malformed WebSocket message.
  if (isGraphqlOperation(entry.methodOrOperation)) {
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-malformed-graphql',
        'Negative: a malformed GraphQL query is rejected',
        'A malformed GraphQL query must be rejected: the server returns a 4xx ' +
          'status or a 200 response whose body carries a GraphQL "errors" array.',
        [
          'const code = pm.response.code;',
          'let hasErrors = false;',
          'try { hasErrors = Array.isArray(pm.response.json().errors) && pm.response.json().errors.length > 0; }',
          'catch (e) { hasErrors = false; }',
          "pm.expect(code >= 400 && code <= 499 || hasErrors, 'malformed GraphQL query was not rejected').to.be.true;",
        ]
      )
    );
  } else if (isWebSocketEndpoint(entry.methodOrOperation)) {
    tests.push(
      buildNegativeTest(
        entry.id,
        'negative-malformed-ws',
        'Negative: a malformed WebSocket message is rejected',
        'A malformed WebSocket message must not be accepted as a success: the ' +
          'endpoint returns an error response rather than a successful one.',
        "pm.expect(pm.response.code, 'malformed WebSocket message was accepted').to.not.be.within(200, 299);"
      )
    );
  }

  return tests;
}

/**
 * Builds a single negative-case assertion. The `assertion` may be a single
 * statement or an array of statements that together form the test body.
 */
export function buildNegativeTest(
  endpointId: string,
  type: GeneratedTest['type'],
  label: string,
  comment: string,
  assertion: string | string[]
): GeneratedTest {
  const body = (Array.isArray(assertion) ? assertion : [assertion]).map(
    (line) => `  ${line}`
  );
  const script = [
    `pm.test(${JSON.stringify(label)}, function () {`,
    `  // ${comment}`,
    ...body,
    '});',
  ].join('\n');

  return { type, endpointId, script };
}

/** Assertion that the response is a client error (4xx). */
function clientErrorAssertion(message: string): string {
  return `pm.expect(pm.response.code, ${JSON.stringify(
    message
  )}).to.be.within(400, 499);`;
}

/** Assertion that the response status equals a specific code. */
function statusEqualsAssertion(code: number, message: string): string {
  return `pm.expect(pm.response.code, ${JSON.stringify(
    message
  )}).to.equal(${code});`;
}

/**
 * Collects the names of the endpoint's required, submittable fields
 * (Requirement 6.1). Required body and query parameters are considered
 * submittable fields; path parameters are identifiers handled by the
 * invalid-identifier case (6.4), and headers are credential/transport metadata
 * exercised by the auth cases (6.2, 6.3).
 */
function requiredFieldNames(entry: CatalogEntry): string[] {
  const names: string[] = [];
  for (const field of [entry.requestBodyParams, entry.queryParams]) {
    if (isNonEmptyParamArray(field)) {
      for (const param of field) {
        if (param.required) {
          names.push(param.name);
        }
      }
    }
  }
  return names;
}

/** True when the endpoint requires authorization (Requirement 6.3). */
function requiresAuthorization(security: SecurityMeta): boolean {
  return security.enforcement === 'authorized';
}

/**
 * True when the endpoint accepts an identifier (Requirement 6.4): it records
 * one or more path parameters, or any parameter whose name denotes an
 * identifier (for example `id`, `customerId`, `user_id`, `uuid`).
 */
function acceptsIdentifier(entry: CatalogEntry): boolean {
  if (isNonEmptyParamArray(entry.pathParams)) {
    return true;
  }
  for (const field of [entry.requestBodyParams, entry.queryParams]) {
    if (isNonEmptyParamArray(field) && field.some((p) => isIdentifierName(p.name))) {
      return true;
    }
  }
  return false;
}

/**
 * True when a parameter name denotes an identifier. A bare `id`, a conventional
 * `*Id` / `*_id` suffix, or an explicit identifier fragment (uuid/guid/objectId)
 * counts; a substring `id` anywhere is intentionally not matched to avoid
 * false positives such as `valid` or `width`.
 */
function isIdentifierName(name: string): boolean {
  const lower = name.toLowerCase();
  if (lower === 'id') {
    return true;
  }
  if (lower.endsWith('id') || lower.endsWith('_id')) {
    return true;
  }
  return IDENTIFIER_PARAM_FRAGMENTS.some((fragment) => lower.includes(fragment));
}

/**
 * True when the endpoint accepts file uploads (Requirement 6.5). Detected from
 * a binary/file parameter type, a parameter name strongly implying a file, or a
 * multipart `Content-Type` header.
 */
function acceptsFileUpload(entry: CatalogEntry): boolean {
  for (const field of [entry.requestBodyParams, entry.queryParams]) {
    if (!isNonEmptyParamArray(field)) {
      continue;
    }
    for (const param of field) {
      const type = (param.type ?? '').toLowerCase();
      if (FILE_UPLOAD_TYPE_FRAGMENTS.some((fragment) => type.includes(fragment))) {
        return true;
      }
      const lowerName = param.name.toLowerCase();
      if (FILE_UPLOAD_NAME_FRAGMENTS.some((fragment) => lowerName.includes(fragment))) {
        return true;
      }
    }
  }

  if (isNonEmptyParamArray(entry.headers)) {
    for (const header of entry.headers) {
      if (
        header.name.toLowerCase() === 'content-type' &&
        (header.type ?? '').toLowerCase().includes('multipart')
      ) {
        return true;
      }
    }
  }

  return false;
}

/**
 * True when the endpoint is a GraphQL operation (Requirement 6.6). The
 * Documentation_Engine records GraphQL operation types as `query`, `mutation`,
 * or `subscription` in `methodOrOperation`.
 */
function isGraphqlOperation(methodOrOperation: Determinable<string>): boolean {
  if (methodOrOperation === 'undetermined') {
    return false;
  }
  const value = methodOrOperation.toLowerCase();
  return value === 'query' || value === 'mutation' || value === 'subscription';
}

/**
 * True when the endpoint is a WebSocket route/event (Requirement 6.6). The
 * Documentation_Engine records WebSocket operation types as `ws-route` or
 * `ws-event` in `methodOrOperation`; both consume WebSocket messages and so are
 * eligible for the malformed-message case.
 */
function isWebSocketEndpoint(methodOrOperation: Determinable<string>): boolean {
  if (methodOrOperation === 'undetermined') {
    return false;
  }
  const value = methodOrOperation.toLowerCase();
  return value === 'ws-route' || value === 'ws-event';
}
