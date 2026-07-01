/**
 * Test_Runner — Newman runner (Task 10.1).
 *
 * Executes a generated Postman collection against a target Postman environment
 * via Newman and maps the run summary into the internal `RunResult` /
 * `RequestOutcome` artifacts (Requirements 10.1, 11.3).
 *
 * Design contract (design.md → Test_Runner):
 *   run(collection: PostmanCollection, env: PostmanEnvironment): Promise<RunResult>
 *
 * Responsibilities:
 *   1. Convert the internal `PostmanCollection` / `PostmanEnvironment` shapes
 *      into the Postman Collection Format v2.1 JSON that Newman consumes.
 *   2. Invoke `newman.run` and await its summary.
 *   3. Map the summary's per-request executions into one `RequestOutcome` each
 *      (passed flag, assertion failures, response time, status code), and roll
 *      them up into a `RunResult`.
 *
 * The conversion is the only place that bridges our internal model and the
 * Postman wire format, so all Newman-specific shape concerns live here.
 */

import {
  run as newmanRun,
  NewmanRunExecution,
  NewmanRunOptions,
  NewmanRunSummary,
} from 'newman';
import { CollectionDefinition, VariableScopeDefinition } from 'postman-collection';

import {
  EnvironmentConfig,
  GeneratedTest,
  PostmanCollection,
  PostmanEnvironment,
  PostmanRequest,
  RequestOutcome,
  RunResult,
} from '../types';

/** Signature of the Newman `run` function, kept narrow for dependency injection. */
export type NewmanRunFn = typeof newmanRun;

/** Options controlling a single Newman run. */
export interface NewmanRunnerOptions {
  /**
   * Override for the Newman `run` function. Defaults to the real Newman
   * runner; tests can substitute a stub to exercise the mapping logic without
   * a live server.
   */
  newmanRun?: NewmanRunFn;
  /**
   * Per-request timeout in milliseconds. Forwarded to Newman so a hung server
   * cannot block the run indefinitely. Optional; Newman defaults to Infinity.
   */
  timeoutRequestMs?: number;
}

/**
 * The Test_Runner executes the collection via Newman against one environment
 * and returns the aggregated outcomes.
 */
export interface TestRunner {
  run(
    collection: PostmanCollection,
    env: PostmanEnvironment
  ): Promise<RunResult>;
}

// ---------------------------------------------------------------------------
// Raw Postman v2.1 JSON shapes emitted for Newman.
//
// These mirror the Postman Collection Format v2.1 wire schema, which differs
// from the postman-collection SDK's TypeScript types in one important way: the
// JSON key for an item's scripts is `event` (singular), not `events`. We build
// the raw JSON explicitly so the runtime shape is correct, then hand it to
// Newman through its `CollectionDefinition` parameter.
// ---------------------------------------------------------------------------

interface RawScript {
  type: 'text/javascript';
  exec: string[];
}

interface RawEvent {
  listen: 'test';
  script: RawScript;
}

interface RawHeader {
  key: string;
  value: string;
}

interface RawBody {
  mode: 'raw';
  raw: string;
  options?: { raw: { language: 'json' } };
}

interface RawRequest {
  method: string;
  header: RawHeader[];
  url: string;
  body?: RawBody;
}

interface RawItem {
  /** Unique id used to map an execution back to its source endpoint. */
  id: string;
  name: string;
  request: RawRequest;
  event: RawEvent[];
}

interface RawItemGroup {
  name: string;
  item: RawItem[];
}

interface RawCollection {
  info: { name: string; schema: string };
  item: RawItemGroup[];
}

/** The canonical Postman Collection Format v2.1 schema URL. */
const POSTMAN_V21_SCHEMA =
  'https://schema.getpostman.com/json/collection/v2.1.0/collection.json';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Runs the collection against a single environment via Newman and returns the
 * mapped `RunResult` (Requirements 10.1, 11.3).
 *
 * Rejects only when Newman itself fails to execute the run (a hard invocation
 * error). Assertion failures are not errors — they are reported as failed
 * `RequestOutcome`s with `RunResult.allPassed === false`.
 */
export function runCollection(
  collection: PostmanCollection,
  env: PostmanEnvironment,
  options: NewmanRunnerOptions = {}
): Promise<RunResult> {
  const run = options.newmanRun ?? newmanRun;

  // Convert to the Postman wire format, keeping the item-id → endpoint-id map
  // so executions can be attributed back to their source endpoint.
  const { collectionDefinition, endpointIdByItemId } =
    toNewmanCollection(collection);
  const environment = toNewmanEnvironment(env);

  const runOptions: NewmanRunOptions = {
    collection: collectionDefinition as unknown as CollectionDefinition,
    environment,
  };
  if (typeof options.timeoutRequestMs === 'number') {
    runOptions.timeoutRequest = options.timeoutRequestMs;
  }

  return new Promise<RunResult>((resolve, reject) => {
    run(runOptions, (err: Error | null, summary: NewmanRunSummary) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(toRunResult(summary, env.name, endpointIdByItemId));
    });
  });
}

/** Default implementation of the TestRunner interface backed by Newman. */
export class NewmanTestRunner implements TestRunner {
  constructor(private readonly options: NewmanRunnerOptions = {}) {}

  run(
    collection: PostmanCollection,
    env: PostmanEnvironment
  ): Promise<RunResult> {
    return runCollection(collection, env, this.options);
  }
}

// ---------------------------------------------------------------------------
// Collection conversion (internal model → Postman v2.1 JSON)
// ---------------------------------------------------------------------------

/**
 * Converts the internal `PostmanCollection` into Postman v2.1 JSON for Newman.
 *
 * Each request is assigned a unique item id (derived from its endpoint id plus
 * a running index, so multiple requests sharing an endpoint stay distinct).
 * The returned map lets `toRunResult` attribute each execution back to the
 * originating endpoint.
 */
export function toNewmanCollection(collection: PostmanCollection): {
  collectionDefinition: RawCollection;
  endpointIdByItemId: Map<string, string>;
} {
  const endpointIdByItemId = new Map<string, string>();
  let itemIndex = 0;

  const item: RawItemGroup[] = collection.folders.map((folder) => ({
    name: folder.name,
    item: folder.items.map((request) => {
      const itemId = `${request.endpointId}::${itemIndex++}`;
      endpointIdByItemId.set(itemId, request.endpointId);
      return toRawItem(request, itemId);
    }),
  }));

  return {
    collectionDefinition: {
      info: { name: 'API Audit Collection', schema: POSTMAN_V21_SCHEMA },
      item,
    },
    endpointIdByItemId,
  };
}

/** Converts a single internal request into a raw Postman v2.1 item. */
function toRawItem(request: PostmanRequest, itemId: string): RawItem {
  const header = toRawHeaders(request);
  const body = toRawBody(request.body);

  const rawRequest: RawRequest = {
    method: request.method,
    header,
    url: request.url,
  };
  if (body) {
    rawRequest.body = body;
  }

  return {
    id: itemId,
    name: request.name,
    request: rawRequest,
    event: toRawEvents(request.tests),
  };
}

/** Maps the internal header list to raw Postman headers. */
function toRawHeaders(request: PostmanRequest): RawHeader[] {
  const headers: RawHeader[] = (request.headers ?? []).map((h) => ({
    key: h.key,
    value: h.value,
  }));

  // A JSON body needs a matching Content-Type unless one is already present.
  if (
    request.body !== undefined &&
    request.body !== null &&
    typeof request.body !== 'string' &&
    !headers.some((h) => h.key.toLowerCase() === 'content-type')
  ) {
    headers.push({ key: 'Content-Type', value: 'application/json' });
  }

  return headers;
}

/**
 * Maps the internal request body to a raw Postman body. Objects are serialized
 * as JSON; strings are passed through verbatim. Absent bodies yield undefined.
 */
function toRawBody(body: unknown): RawBody | undefined {
  if (body === undefined || body === null) {
    return undefined;
  }
  if (typeof body === 'string') {
    return { mode: 'raw', raw: body };
  }
  return {
    mode: 'raw',
    raw: JSON.stringify(body),
    options: { raw: { language: 'json' } },
  };
}

/**
 * Collapses the generated tests for a request into a single Postman `test`
 * event. The individual script texts are concatenated; an empty test list
 * yields no events.
 */
function toRawEvents(tests: GeneratedTest[] | undefined): RawEvent[] {
  if (!tests || tests.length === 0) {
    return [];
  }

  const exec: string[] = [];
  for (const test of tests) {
    if (exec.length > 0) {
      exec.push('');
    }
    exec.push(...test.script.split('\n'));
  }

  return [{ listen: 'test', script: { type: 'text/javascript', exec } }];
}

// ---------------------------------------------------------------------------
// Environment conversion
// ---------------------------------------------------------------------------

/**
 * Converts the internal `PostmanEnvironment` into the Postman variable-scope
 * definition Newman expects. Values are passed through unchanged — they are
 * Postman variable references (e.g. `{{baseUrl}}`), never secret values.
 */
export function toNewmanEnvironment(
  env: PostmanEnvironment
): VariableScopeDefinition {
  return {
    name: env.name,
    values: env.values.map((v) => ({
      key: v.key,
      value: v.value,
      type: 'string',
    })),
  };
}

// ---------------------------------------------------------------------------
// Summary mapping (Newman summary → RunResult)
// ---------------------------------------------------------------------------

/**
 * Maps a Newman run summary into a `RunResult`: one `RequestOutcome` per
 * executed request, plus the aggregate pass flag.
 */
export function toRunResult(
  summary: NewmanRunSummary,
  environmentName: string,
  endpointIdByItemId: Map<string, string>
): RunResult {
  const executions = summary?.run?.executions ?? [];
  const outcomes: RequestOutcome[] = executions.map((execution) =>
    toRequestOutcome(execution, endpointIdByItemId)
  );

  const allPassed = !summary?.error && outcomes.every((o) => o.passed);

  return {
    environment: environmentName as EnvironmentConfig['name'],
    outcomes,
    allPassed,
  };
}

/** Maps a single Newman execution into a `RequestOutcome`. */
function toRequestOutcome(
  execution: NewmanRunExecution,
  endpointIdByItemId: Map<string, string>
): RequestOutcome {
  const itemId = execution.item?.id ?? '';
  const endpointId = endpointIdByItemId.get(itemId) ?? '';
  const requestName = execution.item?.name ?? '';

  const assertionFailures = collectAssertionFailures(execution);

  // A request-level error (connection refused, timeout, etc.) means the
  // request did not complete; surface it as a failure alongside any assertion
  // failures. Newman exposes this as `requestError` at runtime; it is not in
  // the published type, so we read it defensively.
  const requestError = (execution as unknown as { requestError?: Error })
    .requestError;
  if (requestError) {
    assertionFailures.push(`Request error: ${requestError.message}`);
  }

  const response = execution.response;

  return {
    endpointId,
    requestName,
    passed: assertionFailures.length === 0,
    assertionFailures,
    responseTimeMs: typeof response?.responseTime === 'number' ? response.responseTime : 0,
    statusCode: typeof response?.code === 'number' ? response.code : undefined,
  };
}

/**
 * Collects the human-readable failure messages for a single execution's failed
 * (non-skipped) assertions.
 */
function collectAssertionFailures(execution: NewmanRunExecution): string[] {
  const failures: string[] = [];
  for (const assertion of execution.assertions ?? []) {
    if (assertion.skipped || !assertion.error) {
      continue;
    }
    const message = assertion.error.message
      ? `${assertion.assertion}: ${assertion.error.message}`
      : assertion.assertion;
    failures.push(message);
  }
  return failures;
}
