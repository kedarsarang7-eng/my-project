/**
 * Failed endpoint report and recommended-fix derivation (Task 11.1).
 *
 * After a test run completes, the Audit_System produces a failed endpoint
 * report that lists each failed request together with its assertion-failure
 * detail (Requirement 10.2), and derives a recommended fix for every failed
 * request (Requirement 10.3).
 *
 * Design contract (design.md → "Failed Endpoint Report + Recommended Fixes",
 * Property 19): from a `RunResult`, the report lists exactly the failed request
 * outcomes — those with `passed === false` — and never the passing ones, and
 * every listed failed request has a corresponding recommended-fix entry.
 *
 * The tool only *recommends* fixes; it never modifies backend source (design
 * Non-Goals). Recommendations are derived deterministically from each request's
 * assertion failures and observed status code so repeated runs over the same
 * inputs produce an equivalent report.
 */

import {
  FailedEndpointEntry,
  FailedEndpointReport,
  FixCategory,
  FixSuggestion,
  RecommendedFix,
  RequestOutcome,
  RunResult,
} from '../types';

/**
 * Builds the failed endpoint report from a run result.
 *
 * Lists exactly the failed outcomes (`passed === false`) with their assertion
 * failure detail (Requirement 10.2) and derives one recommended-fix entry per
 * failed request (Requirement 10.3). Entries are ordered to mirror the order of
 * failures so the report is stable for a given run.
 *
 * @param run The result of executing the collection against an environment.
 */
export function buildFailedEndpointReport(run: RunResult): FailedEndpointReport {
  const failedOutcomes = run.outcomes.filter((outcome) => !outcome.passed);

  const failures: FailedEndpointEntry[] = failedOutcomes.map((outcome) => ({
    endpointId: outcome.endpointId,
    requestName: outcome.requestName,
    assertionFailures: [...outcome.assertionFailures],
    responseTimeMs: outcome.responseTimeMs,
    statusCode: outcome.statusCode,
  }));

  const recommendedFixes: RecommendedFix[] = failedOutcomes.map(deriveRecommendedFix);

  return { failures, recommendedFixes };
}

/**
 * Derives the recommended-fix entry for a single failed request from its
 * assertion failures and observed status code.
 *
 * The result always contains at least one suggestion: when no specific signal
 * is recognized, a generic `unknown` suggestion is produced so every failed
 * request has actionable guidance.
 */
export function deriveRecommendedFix(outcome: RequestOutcome): RecommendedFix {
  const suggestions = new Map<FixCategory, FixSuggestion>();

  // 1. Status-code-driven signal (Requirement 10.3 — keyed on status code).
  const fromStatus = suggestionForStatus(outcome.statusCode);
  if (fromStatus) {
    suggestions.set(fromStatus.category, fromStatus);
  }

  // 2. Assertion-failure-driven signals (Requirement 10.3 — keyed on failures).
  for (const failure of outcome.assertionFailures) {
    const suggestion = suggestionForAssertion(failure);
    // Keep the first suggestion seen for each category for determinism.
    if (!suggestions.has(suggestion.category)) {
      suggestions.set(suggestion.category, suggestion);
    }
  }

  // 3. Fallback so every failed request has a non-empty recommendation.
  if (suggestions.size === 0) {
    suggestions.set('unknown', {
      category: 'unknown',
      trigger: 'no recognizable failure signal',
      recommendation:
        'Inspect the request and server logs to determine the failure cause; ' +
        'no specific category could be inferred from the assertions or status code.',
    });
  }

  return {
    endpointId: outcome.endpointId,
    requestName: outcome.requestName,
    suggestions: [...suggestions.values()],
  };
}

// ---------------------------------------------------------------------------
// Derivation helpers
// ---------------------------------------------------------------------------

/**
 * Maps an observed HTTP status code to a recommended fix, when the code carries
 * a clear signal. Returns `undefined` for codes that do not map to a category.
 */
function suggestionForStatus(
  statusCode: number | undefined
): FixSuggestion | undefined {
  if (statusCode === undefined) {
    return undefined;
  }
  const trigger = `status ${statusCode}`;

  if (statusCode === 401) {
    return {
      category: 'authentication',
      trigger,
      recommendation:
        'The endpoint returned 401 Unauthorized. Verify the request sends a ' +
        'valid authentication token and that authentication is configured for ' +
        'this endpoint.',
    };
  }
  if (statusCode === 403) {
    return {
      category: 'authorization',
      trigger,
      recommendation:
        'The endpoint returned 403 Forbidden. Verify the caller holds the ' +
        'required role/permission and that authorization rules match the ' +
        'documented contract.',
    };
  }
  if (statusCode === 404) {
    return {
      category: 'not-found',
      trigger,
      recommendation:
        'The endpoint returned 404 Not Found. Verify the route path and any ' +
        'path identifiers are correct and that the resource exists in the ' +
        'target environment.',
    };
  }
  if (statusCode === 400 || statusCode === 422) {
    return {
      category: 'validation',
      trigger,
      recommendation:
        `The endpoint returned ${statusCode}. Verify the request payload, ` +
        'query, and path parameters satisfy the documented validation rules ' +
        '(required fields, types, formats).',
    };
  }
  if (statusCode >= 500) {
    return {
      category: 'server-error',
      trigger,
      recommendation:
        `The endpoint returned ${statusCode}. Investigate the server-side ` +
        'handler and downstream dependencies; a 5xx indicates an unhandled ' +
        'error rather than a client problem.',
    };
  }
  return undefined;
}

/**
 * Classifies an assertion-failure message into a recommended fix. The message
 * text is matched case-insensitively against known assertion patterns produced
 * by the Test_Generator (status, response-time, schema, auth/authz, validation).
 */
function suggestionForAssertion(failure: string): FixSuggestion {
  const text = failure.toLowerCase();

  if (
    /\bschema\b/.test(text) ||
    /required field/.test(text) ||
    /data type/.test(text) ||
    /\btype mismatch\b/.test(text)
  ) {
    return {
      category: 'schema',
      trigger: failure,
      recommendation:
        'A response-schema assertion failed. Align the response body with the ' +
        'documented schema (required fields and declared data types), or update ' +
        'the recorded schema if the contract has changed.',
    };
  }
  if (/response time/.test(text) || /\bslow\b/.test(text) || /threshold/.test(text)) {
    return {
      category: 'performance',
      trigger: failure,
      recommendation:
        'A response-time assertion failed. Profile the handler and its database ' +
        'queries for inefficiency (including N+1 patterns), or revisit the ' +
        'configured response-time threshold for this endpoint.',
    };
  }
  if (/permission/.test(text) || /forbidden/.test(text) || /authoriz/.test(text)) {
    return {
      category: 'authorization',
      trigger: failure,
      recommendation:
        'An authorization assertion failed. Verify the endpoint enforces the ' +
        'required role/permission and that the test caller is provisioned ' +
        'accordingly.',
    };
  }
  if (
    /unauthor/.test(text) ||
    /\btoken\b/.test(text) ||
    /\bauth\b/.test(text) ||
    /authenticat/.test(text)
  ) {
    return {
      category: 'authentication',
      trigger: failure,
      recommendation:
        'An authentication assertion failed. Verify authentication enforcement ' +
        'and that a valid token is supplied for positive cases and rejected for ' +
        'negative cases.',
    };
  }
  if (/\bvalid/.test(text) || /\brequired\b/.test(text) || /\bempty\b/.test(text) || /\bnull\b/.test(text)) {
    return {
      category: 'validation',
      trigger: failure,
      recommendation:
        'An input-validation assertion failed. Verify the endpoint rejects ' +
        'null, empty, and invalid values with the documented error status and ' +
        'body.',
    };
  }
  if (/status/.test(text) || /\bcode\b/.test(text)) {
    return {
      category: 'status-mismatch',
      trigger: failure,
      recommendation:
        'The response status code did not match the expected value. Reconcile ' +
        'the handler behavior with the documented status code, or update the ' +
        'expectation if the contract has changed.',
    };
  }

  return {
    category: 'unknown',
    trigger: failure,
    recommendation:
      'Review this assertion failure against the endpoint contract; it did not ' +
      'match a known failure category.',
  };
}
