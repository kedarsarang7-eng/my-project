/**
 * Local-vs-AWS comparison (Task 16.1).
 *
 * After both the local and AWS test cycles have run, the Audit_System compares
 * the two `RunResult`s and produces one row per request that appeared in either
 * run, carrying both the local and the AWS outcome (Requirement 11.4). A
 * request is classified as an environment-specific issue if and only if it
 * passed locally and failed on AWS (Requirement 11.5).
 *
 * Design contract (design.md → "Local vs AWS Comparison", Property 21):
 *   compareRuns(local: RunResult, aws: RunResult): LocalVsAwsComparison
 *
 * The comparison is keyed on `endpointId`: each distinct endpoint id appearing
 * in either run yields exactly one row. When the same endpoint id appears more
 * than once within a single run, the first reported outcome is used so the
 * mapping stays total and deterministic.
 */

import {
  LocalVsAwsComparison,
  RequestComparisonRow,
  RequestOutcome,
  RunResult,
} from '../types';

/**
 * Compares a local and an AWS run, producing one row per request appearing in
 * either run together with the environment-specific issue classification.
 *
 * Rows are ordered deterministically by `endpointId` so repeated comparisons
 * over the same inputs produce an equivalent artifact.
 *
 * @param local The result of the local test cycle.
 * @param aws The result of the AWS test cycle.
 */
export function compareRuns(
  local: RunResult,
  aws: RunResult
): LocalVsAwsComparison {
  const localByEndpoint = indexByEndpoint(local.outcomes);
  const awsByEndpoint = indexByEndpoint(aws.outcomes);

  // The set of endpoint ids appearing in either run, sorted for determinism.
  const endpointIds = Array.from(
    new Set([...localByEndpoint.keys(), ...awsByEndpoint.keys()])
  ).sort();

  const rows: RequestComparisonRow[] = endpointIds.map((endpointId) => {
    const localOutcome = localByEndpoint.get(endpointId);
    const awsOutcome = awsByEndpoint.get(endpointId);

    // Environment-specific iff the request passed locally AND failed on AWS.
    // If either outcome is absent, the condition cannot hold.
    const environmentSpecific =
      localOutcome?.passed === true && awsOutcome?.passed === false;

    return {
      endpointId,
      requestName:
        localOutcome?.requestName ?? awsOutcome?.requestName ?? endpointId,
      local: localOutcome,
      aws: awsOutcome,
      environmentSpecific,
    };
  });

  const environmentSpecificIssues = rows
    .filter((row) => row.environmentSpecific)
    .map((row) => row.endpointId);

  return { rows, environmentSpecificIssues };
}

/**
 * Indexes outcomes by their endpoint id, keeping the first outcome reported for
 * each endpoint id so the result is one outcome per endpoint id.
 */
function indexByEndpoint(
  outcomes: RequestOutcome[]
): Map<string, RequestOutcome> {
  const byEndpoint = new Map<string, RequestOutcome>();
  for (const outcome of outcomes) {
    if (!byEndpoint.has(outcome.endpointId)) {
      byEndpoint.set(outcome.endpointId, outcome);
    }
  }
  return byEndpoint;
}
