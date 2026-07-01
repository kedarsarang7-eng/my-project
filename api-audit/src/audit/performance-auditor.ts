/**
 * Performance_Auditor (Task 13.1).
 *
 * Measures per-endpoint performance and produces the Performance_Report — a set
 * of `PerfMeasurement` records (Requirement 8).
 *
 * Design contract (design.md → Performance_Auditor):
 *   measure(collection, env): Promise<{ measurements: PerfMeasurement[] }>
 *
 * Responsibilities:
 *   1. Sample each endpoint's response time by executing the collection a small
 *      number of times via the Test_Runner, then derive response time,
 *      throughput, and latency per endpoint (Requirement 8.1).
 *   2. Where an endpoint is backed by AWS Lambda or API Gateway, capture the
 *      Lambda execution duration and API Gateway latency through an injectable,
 *      mockable AWS metrics provider (Requirement 8.2).
 *   3. Flag an endpoint as slow when its measured response time exceeds the
 *      configured response-time threshold (Requirement 8.3).
 *   4. Emit exactly one `PerfMeasurement` per measured endpoint carrying its
 *      response time, throughput, latency, and any flagged issue — including a
 *      suspected inefficient / N+1 database query pattern (Requirement 8.4).
 *
 * The design notes that this is a sampling probe, not a sustained load test:
 * "performance measurement samples representative requests rather than
 * sustained high-volume load."
 *
 * The module is split into a pure aggregation core (which turns raw samples +
 * AWS metrics into `PerfMeasurement`s deterministically) and a thin I/O shell
 * (`PerformanceAuditor.measure`) that drives the runner and AWS clients. The
 * pure core makes the slow-flag rule and reporting verifiable in isolation; all
 * AWS access is funnelled through an injectable provider so it can be mocked.
 */

import {
  PerfMeasurement,
  PostmanCollection,
  PostmanEnvironment,
  RunResult,
} from '../types';
import { NewmanTestRunner, TestRunner } from '../runner';

// ---------------------------------------------------------------------------
// Tunable thresholds (Requirement 8.3 slow rule + N+1 heuristic)
// ---------------------------------------------------------------------------

/** Default thresholds for flagging slow endpoints and suspected inefficiency. */
export const DEFAULT_PERF_THRESHOLDS = {
  /** Response time (ms) above which an endpoint is flagged slow (8.3). */
  responseTimeThresholdMs: 1000,
  /**
   * Backend processing time (ms) above which a backend-bound endpoint is
   * treated as a suspected inefficient / N+1 query pattern.
   */
  inefficiencyThresholdMs: 500,
  /**
   * Fraction of response time attributable to Lambda execution above which the
   * endpoint is considered "backend-bound" (and thus N+1-suspect).
   */
  backendBoundFraction: 0.8,
  /**
   * Max/min response-time ratio across samples above which the endpoint is
   * flagged as having high variance (a weaker N+1 / inefficiency signal used
   * when no Lambda duration is available).
   */
  varianceRatioThreshold: 3,
} as const;

/** The resolved set of thresholds used for a single measurement run. */
export type PerfThresholds = typeof DEFAULT_PERF_THRESHOLDS;

// ---------------------------------------------------------------------------
// AWS metric capture (injectable / mockable) — Requirement 8.2
// ---------------------------------------------------------------------------

/**
 * Identifies the AWS resources backing an endpoint so their metrics can be
 * captured. A resolver returning `undefined` means the endpoint is not backed
 * by AWS Lambda / API Gateway, so no AWS metrics are recorded.
 */
export interface AwsBacking {
  /** CloudWatch log group emitting the Lambda `REPORT` lines for this endpoint. */
  lambdaLogGroupName?: string;
  /** CloudWatch log group carrying the API Gateway access logs for this endpoint. */
  apiAccessLogGroupName?: string;
}

/** Maps an endpoint id to its AWS backing, or `undefined` when not AWS-backed. */
export type AwsBackingResolver = (
  endpointId: string
) => AwsBacking | undefined;

/** AWS-sourced metrics captured for a single endpoint (Requirement 8.2). */
export interface AwsEndpointMetrics {
  /** Lambda execution duration in milliseconds, when available. */
  lambdaDurationMs?: number;
  /** API Gateway latency in milliseconds, when available. */
  apiGwLatencyMs?: number;
}

/**
 * Captures Lambda / API Gateway metrics for an endpoint. Implementations talk
 * to AWS; the auditor depends only on this narrow interface so tests can
 * substitute a stub (Requirement 8.2, supports integration task 13.3).
 */
export interface AwsPerfMetricsProvider {
  getMetrics(backing: AwsBacking): Promise<AwsEndpointMetrics>;
}

/**
 * Fetches the most recent log messages from a CloudWatch log group. Kept as a
 * plain function so the only AWS-SDK coupling lives in `createCloudWatchLogFetcher`.
 */
export type LogEventFetcher = (
  logGroupName: string,
  filterPattern?: string
) => Promise<string[]>;

/**
 * Default `AwsPerfMetricsProvider` that derives metrics from CloudWatch Logs:
 *   - Lambda duration is parsed from the `REPORT` line ("Duration: <n> ms").
 *   - API Gateway latency is read from the `responseLatency` field of JSON
 *     access-log entries.
 *
 * Any failure to fetch or parse yields `undefined` for that metric rather than
 * throwing, so a missing log group never aborts the performance audit.
 */
export class CloudWatchPerfMetricsProvider implements AwsPerfMetricsProvider {
  constructor(private readonly fetchLogEvents: LogEventFetcher) {}

  async getMetrics(backing: AwsBacking): Promise<AwsEndpointMetrics> {
    const metrics: AwsEndpointMetrics = {};

    if (backing.lambdaLogGroupName) {
      metrics.lambdaDurationMs = await this.readLambdaDuration(
        backing.lambdaLogGroupName
      );
    }
    if (backing.apiAccessLogGroupName) {
      metrics.apiGwLatencyMs = await this.readApiGatewayLatency(
        backing.apiAccessLogGroupName
      );
    }

    return metrics;
  }

  /** Parses the latest Lambda `REPORT` line for its `Duration: <n> ms` value. */
  private async readLambdaDuration(
    logGroupName: string
  ): Promise<number | undefined> {
    try {
      const messages = await this.fetchLogEvents(logGroupName, 'REPORT');
      // Scan newest-to-oldest for the first parseable duration.
      for (const message of [...messages].reverse()) {
        const match = /Duration:\s*([\d.]+)\s*ms/i.exec(message);
        if (match) {
          return roundMs(Number(match[1]));
        }
      }
    } catch {
      // Swallow: a missing/unreadable log group simply yields no metric.
    }
    return undefined;
  }

  /** Reads `responseLatency` from the latest JSON API Gateway access-log entry. */
  private async readApiGatewayLatency(
    logGroupName: string
  ): Promise<number | undefined> {
    try {
      const messages = await this.fetchLogEvents(logGroupName);
      for (const message of [...messages].reverse()) {
        const latency = extractResponseLatency(message);
        if (latency !== undefined) {
          return roundMs(latency);
        }
      }
    } catch {
      // Swallow: missing/unreadable access logs simply yield no metric.
    }
    return undefined;
  }
}

/** Extracts a numeric `responseLatency` from a JSON access-log line, if present. */
function extractResponseLatency(message: string): number | undefined {
  try {
    const parsed = JSON.parse(message) as Record<string, unknown>;
    const value = parsed.responseLatency;
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string' && value.trim() !== '' && !isNaN(Number(value))) {
      return Number(value);
    }
  } catch {
    // Not JSON / no field — no latency available.
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Pure aggregation core (deterministic; no I/O) — Requirements 8.1, 8.3, 8.4
// ---------------------------------------------------------------------------

/** Raw response-time samples collected for a single endpoint. */
export interface EndpointSamples {
  endpointId: string;
  responseTimesMs: number[];
}

/**
 * Builds a single `PerfMeasurement` from an endpoint's samples, thresholds, and
 * any captured AWS metrics. This is the authoritative slow-flag and reporting
 * rule (Requirements 8.1, 8.3, 8.4):
 *
 *   - responseTimeMs = average of the samples (representative response time).
 *   - latencyMs      = minimum sample (best-case latency floor).
 *   - throughput     = requests/second achievable at single concurrency
 *                      (1000 / responseTimeMs), 0 when not measurable.
 *   - flaggedSlow    = responseTimeMs strictly exceeds the threshold.
 *   - suspectedInefficiency = set when the endpoint looks backend-bound (Lambda
 *                      duration dominates response time) or shows high
 *                      response-time variance, both classic N+1 signals.
 */
export function buildMeasurement(
  samples: EndpointSamples,
  thresholds: PerfThresholds,
  aws: AwsEndpointMetrics = {}
): PerfMeasurement {
  const times = samples.responseTimesMs.filter((t) => Number.isFinite(t) && t >= 0);

  const responseTimeMs = times.length > 0 ? roundMs(average(times)) : 0;
  const latencyMs = times.length > 0 ? roundMs(Math.min(...times)) : 0;
  const throughput =
    responseTimeMs > 0 ? round2(1000 / responseTimeMs) : 0;

  const measurement: PerfMeasurement = {
    endpointId: samples.endpointId,
    responseTimeMs,
    throughput,
    latencyMs,
    flaggedSlow: responseTimeMs > thresholds.responseTimeThresholdMs,
  };

  if (typeof aws.lambdaDurationMs === 'number') {
    measurement.lambdaDurationMs = roundMs(aws.lambdaDurationMs);
  }
  if (typeof aws.apiGwLatencyMs === 'number') {
    measurement.apiGwLatencyMs = roundMs(aws.apiGwLatencyMs);
  }

  const inefficiency = detectInefficiency(
    responseTimeMs,
    times,
    measurement.lambdaDurationMs,
    thresholds
  );
  if (inefficiency) {
    measurement.suspectedInefficiency = inefficiency;
  }

  return measurement;
}

/**
 * Heuristic for a suspected inefficient / N+1 database query pattern
 * (Requirement 8.4). Two signals are used:
 *
 *   1. Backend-bound: a known Lambda duration that both exceeds the
 *      inefficiency threshold and accounts for most of the response time —
 *      processing time dominates, which is the hallmark of repeated/serial
 *      queries.
 *   2. High variance: when no Lambda duration is available, a large spread
 *      between the slowest and fastest samples on an already-slow endpoint
 *      suggests data-dependent repeated work (e.g. N queries scaling with N
 *      rows).
 */
function detectInefficiency(
  responseTimeMs: number,
  times: number[],
  lambdaDurationMs: number | undefined,
  thresholds: PerfThresholds
): string | undefined {
  if (
    typeof lambdaDurationMs === 'number' &&
    responseTimeMs > 0 &&
    lambdaDurationMs >= thresholds.inefficiencyThresholdMs &&
    lambdaDurationMs / responseTimeMs >= thresholds.backendBoundFraction
  ) {
    const pct = Math.round((lambdaDurationMs / responseTimeMs) * 100);
    return (
      `Backend-bound: Lambda duration ${lambdaDurationMs}ms is ${pct}% of ` +
      `response time (${responseTimeMs}ms); suspected inefficient or N+1 query pattern.`
    );
  }

  if (
    times.length >= 2 &&
    responseTimeMs >= thresholds.inefficiencyThresholdMs
  ) {
    const max = Math.max(...times);
    const min = Math.min(...times);
    if (min > 0 && max / min >= thresholds.varianceRatioThreshold) {
      return (
        `High response-time variance (${roundMs(min)}ms..${roundMs(max)}ms); ` +
        `suspected inefficient or N+1 query pattern.`
      );
    }
  }

  return undefined;
}

/**
 * Aggregates raw per-endpoint samples into the Performance_Report measurement
 * set: exactly one `PerfMeasurement` per measured endpoint (Requirement 8.4),
 * emitted in a deterministic, endpoint-id-sorted order.
 */
export function aggregateMeasurements(
  samplesByEndpoint: EndpointSamples[],
  thresholds: PerfThresholds,
  awsByEndpoint: Map<string, AwsEndpointMetrics> = new Map()
): PerfMeasurement[] {
  return [...samplesByEndpoint]
    .sort((a, b) => a.endpointId.localeCompare(b.endpointId))
    .map((samples) =>
      buildMeasurement(
        samples,
        thresholds,
        awsByEndpoint.get(samples.endpointId)
      )
    );
}

/**
 * Collapses one or more `RunResult`s into per-endpoint samples, gathering every
 * response time observed for each endpoint across all sampling runs.
 */
export function collectSamples(runs: RunResult[]): EndpointSamples[] {
  const byEndpoint = new Map<string, number[]>();
  for (const run of runs) {
    for (const outcome of run.outcomes) {
      const list = byEndpoint.get(outcome.endpointId) ?? [];
      list.push(outcome.responseTimeMs);
      byEndpoint.set(outcome.endpointId, list);
    }
  }
  return [...byEndpoint.entries()].map(([endpointId, responseTimesMs]) => ({
    endpointId,
    responseTimesMs,
  }));
}

// ---------------------------------------------------------------------------
// Performance_Auditor (I/O shell) — drives the runner + AWS metric capture
// ---------------------------------------------------------------------------

/** Options controlling a performance audit. */
export interface PerformanceAuditorOptions {
  /** Runner used to sample response times. Defaults to the Newman runner. */
  runner?: TestRunner;
  /** Number of sampling passes over the collection (default 3). */
  samples?: number;
  /** Threshold overrides; unspecified values fall back to the defaults. */
  thresholds?: Partial<PerfThresholds>;
  /** Resolves an endpoint's AWS backing for metric capture (Requirement 8.2). */
  awsBackingResolver?: AwsBackingResolver;
  /** Provider used to capture Lambda / API Gateway metrics (Requirement 8.2). */
  awsMetricsProvider?: AwsPerfMetricsProvider;
}

/** The result of a performance audit: the Performance_Report measurement set. */
export interface PerformanceReport {
  measurements: PerfMeasurement[];
}

/**
 * The Performance_Auditor measures a collection against one environment and
 * produces the Performance_Report (Requirement 8).
 */
export interface PerformanceAuditor {
  measure(
    collection: PostmanCollection,
    env: PostmanEnvironment
  ): Promise<PerformanceReport>;
}

/** Default Performance_Auditor implementation. */
export class DefaultPerformanceAuditor implements PerformanceAuditor {
  private readonly runner: TestRunner;
  private readonly samples: number;
  private readonly thresholds: PerfThresholds;
  private readonly awsBackingResolver?: AwsBackingResolver;
  private readonly awsMetricsProvider?: AwsPerfMetricsProvider;

  constructor(options: PerformanceAuditorOptions = {}) {
    this.runner = options.runner ?? new NewmanTestRunner();
    this.samples = Math.max(1, options.samples ?? 3);
    this.thresholds = { ...DEFAULT_PERF_THRESHOLDS, ...options.thresholds };
    this.awsBackingResolver = options.awsBackingResolver;
    this.awsMetricsProvider = options.awsMetricsProvider;
  }

  async measure(
    collection: PostmanCollection,
    env: PostmanEnvironment
  ): Promise<PerformanceReport> {
    // 1. Sample response times by executing the collection `samples` times.
    const runs: RunResult[] = [];
    for (let i = 0; i < this.samples; i++) {
      runs.push(await this.runner.run(collection, env));
    }
    const samplesByEndpoint = collectSamples(runs);

    // 2. Capture AWS Lambda / API Gateway metrics for AWS-backed endpoints.
    const awsByEndpoint = await this.captureAwsMetrics(samplesByEndpoint);

    // 3. Aggregate into the Performance_Report.
    const measurements = aggregateMeasurements(
      samplesByEndpoint,
      this.thresholds,
      awsByEndpoint
    );

    return { measurements };
  }

  /**
   * Captures AWS metrics for every endpoint that resolves to an AWS backing.
   * Endpoints with no backing, or when no resolver/provider is configured, are
   * simply skipped — their measurements carry no AWS fields.
   */
  private async captureAwsMetrics(
    samplesByEndpoint: EndpointSamples[]
  ): Promise<Map<string, AwsEndpointMetrics>> {
    const result = new Map<string, AwsEndpointMetrics>();
    if (!this.awsBackingResolver || !this.awsMetricsProvider) {
      return result;
    }

    for (const { endpointId } of samplesByEndpoint) {
      const backing = this.awsBackingResolver(endpointId);
      if (!backing) {
        continue;
      }
      const metrics = await this.awsMetricsProvider.getMetrics(backing);
      result.set(endpointId, metrics);
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Numeric helpers
// ---------------------------------------------------------------------------

function average(values: number[]): number {
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

/** Rounds a millisecond value to the nearest whole millisecond. */
function roundMs(value: number): number {
  return Math.round(value);
}

/** Rounds to two decimal places (used for throughput req/s). */
function round2(value: number): number {
  return Math.round(value * 100) / 100;
}
