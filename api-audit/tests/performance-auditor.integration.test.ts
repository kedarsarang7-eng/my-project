/**
 * Performance_Auditor — integration test for performance measurement and AWS
 * metric capture (Task 13.3).
 *
 * Feature: api-audit-testing-automation
 * Validates: Requirements 8.1, 8.2 — when a performance audit is executed
 * against an Endpoint the Performance_Auditor measures response time,
 * throughput, and latency (8.1); and where an Endpoint is backed by AWS Lambda
 * or API Gateway it records the Lambda execution duration and API Gateway
 * latency (8.2).
 *
 * Approach: this exercises the full Performance_Auditor wiring end-to-end while
 * performing NO real AWS or network I/O.
 *
 *   - A stub {@link TestRunner} returns deterministic per-endpoint response
 *     times so the measured response time / throughput / latency are exact and
 *     assertable (Requirement 8.1).
 *   - A MOCKED AWS SDK v3 CloudWatch Logs client (an object satisfying
 *     {@link CloudWatchLogsClientLike} whose `send` is a Jest mock) returns
 *     canned log events. It is wired through the *real*
 *     `createCloudWatchLogFetcher` adapter and the *real*
 *     `CloudWatchPerfMetricsProvider`, so the production code path that parses
 *     a Lambda `REPORT` line and an API Gateway access-log `responseLatency`
 *     field is what actually runs (Requirement 8.2).
 *
 * The mock is asserted to have been invoked, proving the metrics were captured
 * through the AWS client rather than fabricated, and a non-AWS-backed endpoint
 * is asserted to carry no AWS fields.
 */

import {
  FilterLogEventsCommand,
  FilterLogEventsCommandOutput,
} from '@aws-sdk/client-cloudwatch-logs';

import {
  AwsBacking,
  AwsBackingResolver,
  CloudWatchLogsClientLike,
  CloudWatchPerfMetricsProvider,
  DefaultPerformanceAuditor,
  createCloudWatchLogFetcher,
} from '../src/audit';
import { TestRunner } from '../src/runner';
import {
  PostmanCollection,
  PostmanEnvironment,
  RunResult,
} from '../src/types';

// ---------------------------------------------------------------------------
// Endpoint ids and their AWS backings
// ---------------------------------------------------------------------------

/** Lambda + API Gateway backed endpoint: both metrics should be captured. */
const LAMBDA_EP = 'lambda-ep';
/** API Gateway only backed endpoint: only API Gateway latency captured. */
const APIGW_EP = 'apigw-ep';
/** Plain endpoint with no AWS backing: no AWS metrics recorded. */
const PLAIN_EP = 'plain-ep';

/** Log group names used by the AWS-backed endpoints. */
const LAMBDA_LOG_GROUP = '/aws/lambda/orders-fn';
const LAMBDA_API_LOG_GROUP = 'API-Gateway-Execution-Logs_orders';
const APIGW_LOG_GROUP = 'API-Gateway-Execution-Logs_reports';

/** Deterministic per-endpoint response time (ms) returned by the stub runner. */
const RESPONSE_TIMES_MS: Record<string, number> = {
  [LAMBDA_EP]: 240,
  [APIGW_EP]: 120,
  [PLAIN_EP]: 80,
};

// ---------------------------------------------------------------------------
// Stub TestRunner — deterministic response times, no network I/O
// ---------------------------------------------------------------------------

/**
 * Returns a {@link RunResult} carrying one passing outcome per endpoint in the
 * collection, each with its fixed response time. Constant across runs so the
 * averaged response time, min latency, and derived throughput are exact.
 */
function makeStubRunner(): TestRunner {
  return {
    run(
      collection: PostmanCollection,
      env: PostmanEnvironment
    ): Promise<RunResult> {
      const outcomes = collection.folders
        .flatMap((folder) => folder.items)
        .map((item) => ({
          endpointId: item.endpointId,
          requestName: item.name,
          passed: true,
          assertionFailures: [],
          responseTimeMs: RESPONSE_TIMES_MS[item.endpointId] ?? 0,
          statusCode: 200,
        }));

      return Promise.resolve({
        environment: env.name as RunResult['environment'],
        outcomes,
        allPassed: true,
      });
    },
  };
}

// ---------------------------------------------------------------------------
// Mocked AWS SDK v3 CloudWatch Logs client
// ---------------------------------------------------------------------------

/**
 * Builds a mocked CloudWatch Logs client whose `send` returns canned log events
 * keyed on the requested log group. The shapes mirror real CloudWatch output:
 *   - a Lambda `REPORT` line carrying `Duration: <n> ms`
 *   - JSON API Gateway access-log entries carrying `responseLatency`
 *
 * Any unknown log group returns no events, so the provider yields no metric for
 * it — modelling a missing/unconfigured log group without throwing.
 */
function makeMockCloudWatchClient(): {
  client: CloudWatchLogsClientLike;
  send: jest.Mock;
} {
  const eventsByLogGroup: Record<string, string[]> = {
    [LAMBDA_LOG_GROUP]: [
      'START RequestId: 11111111-2222-3333-4444-555555555555 Version: $LATEST',
      'END RequestId: 11111111-2222-3333-4444-555555555555',
      'REPORT RequestId: 11111111-2222-3333-4444-555555555555\t' +
        'Duration: 123.45 ms\tBilled Duration: 200 ms\t' +
        'Memory Size: 128 MB\tMax Memory Used: 90 MB',
    ],
    [LAMBDA_API_LOG_GROUP]: [
      JSON.stringify({ requestId: 'a1', status: '200', responseLatency: 87 }),
    ],
    [APIGW_LOG_GROUP]: [
      JSON.stringify({ requestId: 'b2', status: '200', responseLatency: 45 }),
    ],
  };

  const send = jest.fn(
    (command: FilterLogEventsCommand): Promise<FilterLogEventsCommandOutput> => {
      const logGroupName = command.input.logGroupName ?? '';
      const messages = eventsByLogGroup[logGroupName] ?? [];
      const output: FilterLogEventsCommandOutput = {
        events: messages.map((message) => ({ message })),
        $metadata: {},
      };
      return Promise.resolve(output);
    }
  );

  return { client: { send } as unknown as CloudWatchLogsClientLike, send };
}

// ---------------------------------------------------------------------------
// Collection / environment helpers
// ---------------------------------------------------------------------------

function buildCollection(): PostmanCollection {
  return {
    info: { schema: 'v2.1.0' },
    folders: [
      {
        name: 'AWS-Integrated',
        items: [
          {
            name: 'Create order (Lambda)',
            endpointId: LAMBDA_EP,
            method: 'POST',
            url: '{{baseUrl}}/orders',
          },
          {
            name: 'Get report (API Gateway)',
            endpointId: APIGW_EP,
            method: 'GET',
            url: '{{baseUrl}}/reports/summary',
          },
        ],
      },
      {
        name: 'Internal-Service',
        items: [
          {
            name: 'Health check',
            endpointId: PLAIN_EP,
            method: 'GET',
            url: '{{baseUrl}}/health',
          },
        ],
      },
    ],
  };
}

function makeEnvironment(): PostmanEnvironment {
  return { name: 'AWS', values: [{ key: 'baseUrl', value: '{{baseUrl}}' }] };
}

/** Resolves each endpoint's AWS backing (undefined when not AWS-backed). */
const awsBackingResolver: AwsBackingResolver = (
  endpointId: string
): AwsBacking | undefined => {
  switch (endpointId) {
    case LAMBDA_EP:
      return {
        lambdaLogGroupName: LAMBDA_LOG_GROUP,
        apiAccessLogGroupName: LAMBDA_API_LOG_GROUP,
      };
    case APIGW_EP:
      return { apiAccessLogGroupName: APIGW_LOG_GROUP };
    default:
      return undefined;
  }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Performance_Auditor integration: measurement + AWS metric capture', () => {
  function runAudit(): {
    auditor: DefaultPerformanceAuditor;
    send: jest.Mock;
  } {
    const { client, send } = makeMockCloudWatchClient();
    const provider = new CloudWatchPerfMetricsProvider(
      createCloudWatchLogFetcher(client)
    );
    const auditor = new DefaultPerformanceAuditor({
      runner: makeStubRunner(),
      samples: 3,
      awsBackingResolver,
      awsMetricsProvider: provider,
    });
    return { auditor, send };
  }

  it('measures response time, throughput, and latency for every endpoint (Req 8.1)', async () => {
    const { auditor } = runAudit();

    const { measurements } = await auditor.measure(
      buildCollection(),
      makeEnvironment()
    );

    // Exactly one measurement per measured endpoint.
    expect(measurements.map((m) => m.endpointId).sort()).toEqual(
      [APIGW_EP, LAMBDA_EP, PLAIN_EP].sort()
    );

    for (const m of measurements) {
      const expectedTime = RESPONSE_TIMES_MS[m.endpointId];
      // Response time = average of constant samples; latency = min sample.
      expect(m.responseTimeMs).toBe(expectedTime);
      expect(m.latencyMs).toBe(expectedTime);
      // Throughput = req/s at single concurrency = 1000 / responseTimeMs.
      expect(m.throughput).toBeCloseTo(1000 / expectedTime, 2);
      // None exceed the default 1000ms slow threshold.
      expect(m.flaggedSlow).toBe(false);
    }
  });

  it('records Lambda duration and API Gateway latency for AWS-backed endpoints via the mocked client (Req 8.2)', async () => {
    const { auditor, send } = runAudit();

    const { measurements } = await auditor.measure(
      buildCollection(),
      makeEnvironment()
    );

    const byId = new Map(measurements.map((m) => [m.endpointId, m]));

    // Lambda + API Gateway backed endpoint captures BOTH metrics, parsed from
    // the mocked CloudWatch log events.
    const lambda = byId.get(LAMBDA_EP)!;
    expect(lambda.lambdaDurationMs).toBe(123); // 123.45 ms REPORT, rounded
    expect(lambda.apiGwLatencyMs).toBe(87);

    // API Gateway only endpoint captures latency but no Lambda duration.
    const apigw = byId.get(APIGW_EP)!;
    expect(apigw.apiGwLatencyMs).toBe(45);
    expect(apigw.lambdaDurationMs).toBeUndefined();

    // The metrics came from the mocked AWS client, not a real AWS call.
    expect(send).toHaveBeenCalled();
  });

  it('records no AWS metrics for a non-AWS-backed endpoint (Req 8.2)', async () => {
    const { auditor } = runAudit();

    const { measurements } = await auditor.measure(
      buildCollection(),
      makeEnvironment()
    );

    const plain = measurements.find((m) => m.endpointId === PLAIN_EP)!;
    expect(plain.lambdaDurationMs).toBeUndefined();
    expect(plain.apiGwLatencyMs).toBeUndefined();
  });
});
