/**
 * Production readiness aggregation (Task 17.1).
 *
 * When all preceding reports are available, the Audit_System produces a
 * production readiness report that aggregates the coverage metrics, the open
 * security findings, the open performance issues, and the unresolved failed
 * endpoints (Requirement 13.4).
 *
 * Aggregation degrades partially (Requirement 13.5, Property 24): each of the
 * four sections is extracted independently, and if extracting one or more
 * inputs fails, the report is marked `partial`, records exactly which
 * aggregation steps failed, and still includes the sections that succeeded.
 *
 * This module implements only the `aggregateReadiness` half of the Report
 * Aggregator interface. Persisting deliverables through `writeArtifact`
 * (`writeAll`) is wired separately in Task 17.2, so this function stays a pure,
 * composable transformation: it reads the artifacts and returns a report
 * without touching the filesystem.
 */

import {
  AuditArtifacts,
  CoverageMetric,
  PerfMeasurement,
  ProductionReadinessReport,
  RequestOutcome,
  RunResult,
  SecurityFinding,
} from '../types';

/**
 * The stable identifier of each aggregation step, recorded in
 * `failedAggregationSteps` when that step fails (Requirement 13.5). Using fixed
 * identifiers keeps the failure list deterministic and machine-readable.
 */
export type AggregationStep =
  | 'coverage'
  | 'open-security-findings'
  | 'open-performance-issues'
  | 'unresolved-failed-endpoints';

/**
 * Aggregates the production readiness report from the run's artifacts
 * (Requirement 13.4) with partial degradation (Requirement 13.5).
 *
 * Each section is extracted in isolation. A section that throws (because its
 * source artifact is missing or malformed) is recorded as a failed step and
 * substituted with an empty section, while the remaining sections are still
 * aggregated. The report is `partial` if and only if at least one step failed.
 *
 * @param artifacts The artifacts produced by the run so far.
 * @returns The aggregated (possibly partial) production readiness report.
 */
export function aggregateReadiness(
  artifacts: AuditArtifacts,
): ProductionReadinessReport {
  const failedAggregationSteps: string[] = [];

  const coverage = runStep(
    'coverage',
    failedAggregationSteps,
    () => extractCoverage(artifacts),
  );
  const openSecurityFindings = runStep(
    'open-security-findings',
    failedAggregationSteps,
    () => extractOpenSecurityFindings(artifacts),
  );
  const openPerformanceIssues = runStep(
    'open-performance-issues',
    failedAggregationSteps,
    () => extractOpenPerformanceIssues(artifacts),
  );
  const unresolvedFailedEndpoints = runStep(
    'unresolved-failed-endpoints',
    failedAggregationSteps,
    () => extractUnresolvedFailedEndpoints(artifacts),
  );

  return {
    coverage,
    openSecurityFindings,
    openPerformanceIssues,
    unresolvedFailedEndpoints,
    partial: failedAggregationSteps.length > 0,
    failedAggregationSteps,
  };
}

// ---------------------------------------------------------------------------
// Step runner
// ---------------------------------------------------------------------------

/**
 * Runs a single aggregation step. On success the extracted section is returned;
 * on failure the step name is appended to `failed` and an empty section is
 * returned so the surrounding aggregation still emits the successful sections
 * (Requirement 13.5).
 */
function runStep<T>(
  step: AggregationStep,
  failed: string[],
  extract: () => T[],
): T[] {
  try {
    return extract();
  } catch {
    failed.push(step);
    return [];
  }
}

// ---------------------------------------------------------------------------
// Section extractors
//
// Each extractor copies values out of the source artifact so the readiness
// report does not share mutable references with the inputs, and throws when its
// source is absent or malformed so the step runner can degrade partially.
// ---------------------------------------------------------------------------

/** Extracts the coverage metrics from the coverage report (Requirement 13.4). */
function extractCoverage(artifacts: AuditArtifacts): CoverageMetric[] {
  const coverage = artifacts.coverage;
  if (coverage === null || coverage === undefined || !Array.isArray(coverage.metrics)) {
    throw new Error('coverage report is missing or malformed');
  }
  return coverage.metrics.map((metric) => ({
    ...metric,
    contributingGaps: [...metric.contributingGaps],
  }));
}

/**
 * Extracts the open security findings (Requirement 13.4). Every recorded
 * finding represents an open vulnerability, so all findings are carried over.
 */
function extractOpenSecurityFindings(
  artifacts: AuditArtifacts,
): SecurityFinding[] {
  const findings = artifacts.securityFindings;
  if (!Array.isArray(findings)) {
    throw new Error('security findings are missing or malformed');
  }
  return findings.map((finding) => ({ ...finding }));
}

/**
 * Extracts the open performance issues (Requirement 13.4): the measurements
 * flagged slow or carrying a suspected inefficiency. Measurements within
 * threshold and free of suspected inefficiency are not open issues.
 */
function extractOpenPerformanceIssues(
  artifacts: AuditArtifacts,
): PerfMeasurement[] {
  const measurements = artifacts.perfMeasurements;
  if (!Array.isArray(measurements)) {
    throw new Error('performance measurements are missing or malformed');
  }
  return measurements
    .filter(isOpenPerformanceIssue)
    .map((measurement) => ({ ...measurement }));
}

/** A measurement is an open issue when flagged slow or suspected inefficient. */
function isOpenPerformanceIssue(measurement: PerfMeasurement): boolean {
  const hasSuspectedInefficiency =
    typeof measurement.suspectedInefficiency === 'string' &&
    measurement.suspectedInefficiency.length > 0;
  return measurement.flaggedSlow === true || hasSuspectedInefficiency;
}

/**
 * Extracts the unresolved failed endpoints (Requirement 13.4): every request
 * outcome that did not pass, gathered from whichever run results are present
 * (local first, then AWS). Under the local-first gate the AWS run only exists
 * after a clean local run, so in normal flow these do not overlap; collecting
 * both keeps the aggregation faithful to all available sources.
 */
function extractUnresolvedFailedEndpoints(
  artifacts: AuditArtifacts,
): RequestOutcome[] {
  const runs: (RunResult | undefined)[] = [artifacts.localRun, artifacts.awsRun];
  const unresolved: RequestOutcome[] = [];

  for (const run of runs) {
    if (run === undefined) {
      continue;
    }
    if (!Array.isArray(run.outcomes)) {
      throw new Error('run result is malformed');
    }
    for (const outcome of run.outcomes) {
      if (!outcome.passed) {
        unresolved.push({
          ...outcome,
          assertionFailures: [...outcome.assertionFailures],
        });
      }
    }
  }

  return unresolved;
}
