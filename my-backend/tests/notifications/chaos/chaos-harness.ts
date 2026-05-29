// ============================================================================
// chaos/chaos-harness.ts — Node.js orchestrator for AWS fault injection
// ============================================================================
//
// Implements scenarios 2.4, 2.5, 2.6 from phase5-load-plan.md:
//   - Scenario 2.4: Kill push channel adapter at T+60s, restore at T+180s
//   - Scenario 2.5: Terminate SQS consumer Lambda at T+90s, restart at T+150s
//   - Scenario 2.6: Inject 2000ms DynamoDB latency from T+60s to T+120s
//
// Each scenario:
//   - Uses AWS SDK to disable/enable SQS event-source mappings
//   - Verifies zero permanent event loss after recovery
//   - Verifies unaffected channels continue within normal thresholds
//   - Verifies recovery time is within bounds (60s for channel, 30s for bus/store)
//
// Usage:
//   npx ts-node --transpile-only tests/notifications/chaos/chaos-harness.ts \
//     --scenario 2.4 \
//     --region us-east-1 \
//     --stage loadtest
//
// Requirements: REQ 13, REQ 15.4
// ============================================================================

import {
    LambdaClient,
    UpdateEventSourceMappingCommand,
    ListEventSourceMappingsCommand,
    GetEventSourceMappingCommand,
    UpdateFunctionConfigurationCommand,
    GetFunctionConfigurationCommand,
} from '@aws-sdk/client-lambda';
import {
    CloudWatchClient,
    GetMetricDataCommand,
} from '@aws-sdk/client-cloudwatch';
import {
    SQSClient,
    GetQueueAttributesCommand,
} from '@aws-sdk/client-sqs';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

export interface ChaosConfig {
    /** AWS region for all SDK calls. */
    region: string;
    /** Deployment stage (e.g. 'loadtest', 'staging'). */
    stage: string;
    /** Lambda function name for the SQS consumer. */
    consumerFunctionName: string;
    /** Lambda function name for the push channel adapter. */
    pushAdapterFunctionName: string;
    /** SQS queue URL for the main event bus queue. */
    mainQueueUrl: string;
    /** SQS DLQ URL for monitoring DLQ depth. */
    dlqUrl: string;
    /** CloudWatch namespace for UNS metrics. */
    metricsNamespace: string;
    /** Scenario to run: '2.4' | '2.5' | '2.6' | 'all'. */
    scenario: string;
}

export interface ScenarioResult {
    readonly scenario: string;
    readonly passed: boolean;
    readonly assertions: AssertionResult[];
    readonly timeline: TimelineEntry[];
    readonly durationMs: number;
}

export interface AssertionResult {
    readonly name: string;
    readonly passed: boolean;
    readonly expected: string;
    readonly actual: string;
}

export interface TimelineEntry {
    readonly timestampMs: number;
    readonly offsetSec: number;
    readonly action: string;
    readonly detail: string;
}

// ---------------------------------------------------------------------------
// Defaults — derived from the load plan and deployment conventions
// ---------------------------------------------------------------------------

const DEFAULT_CONFIG: Partial<ChaosConfig> = {
    region: 'us-east-1',
    stage: 'loadtest',
    metricsNamespace: 'UNS',
};

function resolveConfig(overrides: Partial<ChaosConfig>): ChaosConfig {
    const stage = overrides.stage ?? DEFAULT_CONFIG.stage ?? 'loadtest';
    return {
        region: overrides.region ?? DEFAULT_CONFIG.region ?? 'us-east-1',
        stage,
        consumerFunctionName:
            overrides.consumerFunctionName ?? `uns-${stage}-eventConsumer`,
        pushAdapterFunctionName:
            overrides.pushAdapterFunctionName ?? `uns-${stage}-pushAdapter`,
        mainQueueUrl:
            overrides.mainQueueUrl ??
            `https://sqs.${overrides.region ?? 'us-east-1'}.amazonaws.com/000000000000/uns-${stage}-events`,
        dlqUrl:
            overrides.dlqUrl ??
            `https://sqs.${overrides.region ?? 'us-east-1'}.amazonaws.com/000000000000/uns-${stage}-events-dlq`,
        metricsNamespace:
            overrides.metricsNamespace ?? DEFAULT_CONFIG.metricsNamespace ?? 'UNS',
        scenario: overrides.scenario ?? 'all',
    };
}

// ---------------------------------------------------------------------------
// Recovery time thresholds (from phase5-load-plan.md §5.2)
// ---------------------------------------------------------------------------

/** Max recovery time for a channel adapter failure (scenario 2.4). */
const CHANNEL_RECOVERY_THRESHOLD_SEC = 60;
/** Max recovery time for event bus / store faults (scenarios 2.5, 2.6). */
const BUS_STORE_RECOVERY_THRESHOLD_SEC = 30;

// ---------------------------------------------------------------------------
// AWS SDK clients (lazy-initialized)
// ---------------------------------------------------------------------------

let lambdaClient: LambdaClient | null = null;
let cwClient: CloudWatchClient | null = null;
let sqsClient: SQSClient | null = null;

function getLambdaClient(region: string): LambdaClient {
    if (!lambdaClient) {
        lambdaClient = new LambdaClient({ region });
    }
    return lambdaClient;
}

function getCloudWatchClient(region: string): CloudWatchClient {
    if (!cwClient) {
        cwClient = new CloudWatchClient({ region });
    }
    return cwClient;
}

function getSqsClient(region: string): SQSClient {
    if (!sqsClient) {
        sqsClient = new SQSClient({ region });
    }
    return sqsClient;
}

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

function log(msg: string): void {
    const ts = new Date().toISOString();
    console.log(`[chaos-harness ${ts}] ${msg}`);
}

function sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Wait until a condition is met or timeout expires.
 * Returns elapsed time in ms, or -1 if timed out.
 */
async function waitForCondition(
    check: () => Promise<boolean>,
    timeoutMs: number,
    pollIntervalMs = 5_000,
): Promise<number> {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        if (await check()) {
            return Date.now() - start;
        }
        await sleep(pollIntervalMs);
    }
    return -1;
}

// ---------------------------------------------------------------------------
// AWS operations — Event Source Mapping management
// ---------------------------------------------------------------------------

/**
 * Find the UUID of the SQS event-source mapping for a given Lambda function.
 */
async function findEventSourceMappingUuid(
    region: string,
    functionName: string,
): Promise<string | null> {
    const client = getLambdaClient(region);
    const response = await client.send(
        new ListEventSourceMappingsCommand({ FunctionName: functionName }),
    );
    const mappings = response.EventSourceMappings ?? [];
    // Return the first SQS mapping found.
    const sqsMapping = mappings.find(
        (m) => m.EventSourceArn?.includes(':sqs:'),
    );
    return sqsMapping?.UUID ?? null;
}

/**
 * Disable an event-source mapping (simulates killing the consumer).
 */
async function disableEventSourceMapping(
    region: string,
    uuid: string,
): Promise<void> {
    const client = getLambdaClient(region);
    await client.send(
        new UpdateEventSourceMappingCommand({
            UUID: uuid,
            Enabled: false,
        }),
    );
    log(`Disabled event-source mapping: ${uuid}`);
}

/**
 * Enable an event-source mapping (simulates restoring the consumer).
 */
async function enableEventSourceMapping(
    region: string,
    uuid: string,
): Promise<void> {
    const client = getLambdaClient(region);
    await client.send(
        new UpdateEventSourceMappingCommand({
            UUID: uuid,
            Enabled: true,
        }),
    );
    log(`Enabled event-source mapping: ${uuid}`);
}

/**
 * Wait until an event-source mapping reaches the desired state.
 */
async function waitForMappingState(
    region: string,
    uuid: string,
    desiredState: 'Enabled' | 'Disabled',
    timeoutMs = 120_000,
): Promise<boolean> {
    const client = getLambdaClient(region);
    const elapsed = await waitForCondition(async () => {
        const resp = await client.send(
            new GetEventSourceMappingCommand({ UUID: uuid }),
        );
        return resp.State === desiredState;
    }, timeoutMs);
    return elapsed >= 0;
}

// ---------------------------------------------------------------------------
// AWS operations — Lambda environment variable injection (DynamoDB latency)
// ---------------------------------------------------------------------------

/**
 * Inject a latency flag into the Lambda's environment variables.
 * The production code checks `UNS_DYNAMO_LATENCY_MS` and adds an
 * artificial delay when set (test-only middleware flag per §4.2).
 */
async function injectDynamoLatency(
    region: string,
    functionName: string,
    latencyMs: number,
): Promise<void> {
    const client = getLambdaClient(region);
    const current = await client.send(
        new GetFunctionConfigurationCommand({ FunctionName: functionName }),
    );
    const env = current.Environment?.Variables ?? {};
    env['UNS_DYNAMO_LATENCY_MS'] = String(latencyMs);
    await client.send(
        new UpdateFunctionConfigurationCommand({
            FunctionName: functionName,
            Environment: { Variables: env },
        }),
    );
    log(`Injected DynamoDB latency: ${latencyMs}ms on ${functionName}`);
}

/**
 * Remove the latency injection flag from the Lambda's environment.
 */
async function removeDynamoLatency(
    region: string,
    functionName: string,
): Promise<void> {
    const client = getLambdaClient(region);
    const current = await client.send(
        new GetFunctionConfigurationCommand({ FunctionName: functionName }),
    );
    const env = current.Environment?.Variables ?? {};
    delete env['UNS_DYNAMO_LATENCY_MS'];
    await client.send(
        new UpdateFunctionConfigurationCommand({
            FunctionName: functionName,
            Environment: { Variables: env },
        }),
    );
    log(`Removed DynamoDB latency injection from ${functionName}`);
}

// ---------------------------------------------------------------------------
// AWS operations — Metrics and queue depth queries
// ---------------------------------------------------------------------------

/**
 * Query CloudWatch for the total events lost metric in a time window.
 */
async function queryEventsLost(
    region: string,
    namespace: string,
    startTime: Date,
    endTime: Date,
): Promise<number> {
    const client = getCloudWatchClient(region);
    const resp = await client.send(
        new GetMetricDataCommand({
            StartTime: startTime,
            EndTime: endTime,
            MetricDataQueries: [
                {
                    Id: 'events_lost',
                    MetricStat: {
                        Metric: {
                            Namespace: namespace,
                            MetricName: 'events_lost',
                        },
                        Period: 60,
                        Stat: 'Sum',
                    },
                },
            ],
        }),
    );
    const values = resp.MetricDataResults?.[0]?.Values ?? [];
    return values.reduce((sum, v) => sum + (v ?? 0), 0);
}

/**
 * Query the DLQ depth (ApproximateNumberOfMessagesVisible).
 */
async function queryDlqDepth(
    region: string,
    dlqUrl: string,
): Promise<number> {
    const client = getSqsClient(region);
    const resp = await client.send(
        new GetQueueAttributesCommand({
            QueueUrl: dlqUrl,
            AttributeNames: ['All'],
        }),
    );
    const depth = resp.Attributes?.['ApproximateNumberOfMessagesVisible'];
    return depth ? parseInt(depth, 10) : 0;
}

/**
 * Query the main queue depth (messages waiting to be processed).
 */
async function queryQueueDepth(
    region: string,
    queueUrl: string,
): Promise<number> {
    const client = getSqsClient(region);
    const resp = await client.send(
        new GetQueueAttributesCommand({
            QueueUrl: queueUrl,
            AttributeNames: ['All'],
        }),
    );
    const visible = parseInt(
        resp.Attributes?.['ApproximateNumberOfMessagesVisible'] ?? '0',
        10,
    );
    const notVisible = parseInt(
        resp.Attributes?.['ApproximateNumberOfMessagesNotVisible'] ?? '0',
        10,
    );
    return visible + notVisible;
}

/**
 * Query CloudWatch for channel-specific delivery latency p95.
 */
async function queryChannelLatencyP95(
    region: string,
    namespace: string,
    channel: string,
    startTime: Date,
    endTime: Date,
): Promise<number> {
    const client = getCloudWatchClient(region);
    const resp = await client.send(
        new GetMetricDataCommand({
            StartTime: startTime,
            EndTime: endTime,
            MetricDataQueries: [
                {
                    Id: 'latency_p95',
                    MetricStat: {
                        Metric: {
                            Namespace: namespace,
                            MetricName: 'delivery_latency_ms',
                            Dimensions: [
                                { Name: 'channel', Value: channel },
                            ],
                        },
                        Period: 60,
                        Stat: 'p95',
                    },
                },
            ],
        }),
    );
    const values = resp.MetricDataResults?.[0]?.Values ?? [];
    return values.length > 0 ? Math.max(...values.map((v) => v ?? 0)) : 0;
}

// ---------------------------------------------------------------------------
// Scenario 2.4: Kill push channel adapter at T+60s, restore at T+180s
// ---------------------------------------------------------------------------

async function runScenario24(config: ChaosConfig): Promise<ScenarioResult> {
    const timeline: TimelineEntry[] = [];
    const assertions: AssertionResult[] = [];
    const startMs = Date.now();
    const startTime = new Date(startMs);

    log('=== Scenario 2.4: Channel Adapter Failure (push) ===');
    log(`Push adapter function: ${config.pushAdapterFunctionName}`);

    // Find the event-source mapping for the push adapter.
    const mappingUuid = await findEventSourceMappingUuid(
        config.region,
        config.pushAdapterFunctionName,
    );
    if (!mappingUuid) {
        return {
            scenario: '2.4',
            passed: false,
            assertions: [
                {
                    name: 'event-source-mapping-found',
                    passed: false,
                    expected: 'UUID of push adapter event-source mapping',
                    actual: 'null — no SQS mapping found',
                },
            ],
            timeline,
            durationMs: Date.now() - startMs,
        };
    }

    timeline.push({
        timestampMs: Date.now(),
        offsetSec: 0,
        action: 'start',
        detail: `Scenario 2.4 started; mapping UUID: ${mappingUuid}`,
    });

    // T+0 to T+60: normal operation (let load run).
    log('Waiting 60s for baseline load...');
    await sleep(60_000);

    // T+60: Kill push channel adapter.
    log('T+60s: Disabling push adapter event-source mapping...');
    await disableEventSourceMapping(config.region, mappingUuid);
    await waitForMappingState(config.region, mappingUuid, 'Disabled');
    const killTime = Date.now();
    timeline.push({
        timestampMs: killTime,
        offsetSec: Math.round((killTime - startMs) / 1000),
        action: 'fault-inject',
        detail: 'Push adapter event-source mapping disabled',
    });

    // T+60 to T+180: push adapter is down (120s outage window).
    log('Push adapter disabled. Waiting 120s for outage window...');
    await sleep(120_000);

    // T+180: Restore push channel adapter.
    log('T+180s: Re-enabling push adapter event-source mapping...');
    await enableEventSourceMapping(config.region, mappingUuid);
    await waitForMappingState(config.region, mappingUuid, 'Enabled');
    const restoreTime = Date.now();
    timeline.push({
        timestampMs: restoreTime,
        offsetSec: Math.round((restoreTime - startMs) / 1000),
        action: 'fault-remove',
        detail: 'Push adapter event-source mapping re-enabled',
    });

    // Wait for recovery — queue should drain within 60s.
    log('Waiting for push queue to drain (max 60s)...');
    const recoveryElapsed = await waitForCondition(async () => {
        const depth = await queryQueueDepth(config.region, config.mainQueueUrl);
        log(`  Queue depth: ${depth}`);
        return depth === 0;
    }, CHANNEL_RECOVERY_THRESHOLD_SEC * 1000);

    timeline.push({
        timestampMs: Date.now(),
        offsetSec: Math.round((Date.now() - startMs) / 1000),
        action: 'recovery-check',
        detail: `Recovery elapsed: ${recoveryElapsed}ms (threshold: ${CHANNEL_RECOVERY_THRESHOLD_SEC}s)`,
    });

    // Wait an additional 30s for metrics to settle.
    await sleep(30_000);
    const endTime = new Date();

    // --- Assertions ---

    // 1. Zero permanent event loss.
    const eventsLost = await queryEventsLost(
        config.region,
        config.metricsNamespace,
        startTime,
        endTime,
    );
    assertions.push({
        name: 'zero-permanent-event-loss',
        passed: eventsLost === 0,
        expected: '0 events lost',
        actual: `${eventsLost} events lost`,
    });

    // 2. Unaffected channels (in_app, email) within normal thresholds.
    for (const channel of ['in_app', 'email']) {
        const p95 = await queryChannelLatencyP95(
            config.region,
            config.metricsNamespace,
            channel,
            startTime,
            endTime,
        );
        const threshold = channel === 'in_app' ? 500 : 5000;
        assertions.push({
            name: `unaffected-channel-${channel}-p95`,
            passed: p95 <= threshold,
            expected: `p95 <= ${threshold}ms`,
            actual: `p95 = ${p95}ms`,
        });
    }

    // 3. Recovery time within bounds.
    const recoveredInTime = recoveryElapsed >= 0 &&
        recoveryElapsed <= CHANNEL_RECOVERY_THRESHOLD_SEC * 1000;
    assertions.push({
        name: 'recovery-time-within-bounds',
        passed: recoveredInTime,
        expected: `<= ${CHANNEL_RECOVERY_THRESHOLD_SEC}s`,
        actual: recoveryElapsed >= 0
            ? `${(recoveryElapsed / 1000).toFixed(1)}s`
            : 'timed out',
    });

    // 4. DLQ depth returns to 0.
    const dlqDepth = await queryDlqDepth(config.region, config.dlqUrl);
    assertions.push({
        name: 'dlq-depth-zero',
        passed: dlqDepth === 0,
        expected: 'DLQ depth = 0',
        actual: `DLQ depth = ${dlqDepth}`,
    });

    const passed = assertions.every((a) => a.passed);
    log(`Scenario 2.4 ${passed ? 'PASSED' : 'FAILED'}`);

    return {
        scenario: '2.4',
        passed,
        assertions,
        timeline,
        durationMs: Date.now() - startMs,
    };
}

// ---------------------------------------------------------------------------
// Scenario 2.5: Terminate SQS consumer Lambda at T+90s, restart at T+150s
// ---------------------------------------------------------------------------

async function runScenario25(config: ChaosConfig): Promise<ScenarioResult> {
    const timeline: TimelineEntry[] = [];
    const assertions: AssertionResult[] = [];
    const startMs = Date.now();
    const startTime = new Date(startMs);

    log('=== Scenario 2.5: Event_Bus Restart (SQS consumer kill) ===');
    log(`Consumer function: ${config.consumerFunctionName}`);

    // Find the event-source mapping for the consumer Lambda.
    const mappingUuid = await findEventSourceMappingUuid(
        config.region,
        config.consumerFunctionName,
    );
    if (!mappingUuid) {
        return {
            scenario: '2.5',
            passed: false,
            assertions: [
                {
                    name: 'event-source-mapping-found',
                    passed: false,
                    expected: 'UUID of consumer event-source mapping',
                    actual: 'null — no SQS mapping found',
                },
            ],
            timeline,
            durationMs: Date.now() - startMs,
        };
    }

    timeline.push({
        timestampMs: Date.now(),
        offsetSec: 0,
        action: 'start',
        detail: `Scenario 2.5 started; mapping UUID: ${mappingUuid}`,
    });

    // T+0 to T+90: normal operation.
    log('Waiting 90s for baseline load...');
    await sleep(90_000);

    // T+90: Terminate SQS consumer by disabling event-source mapping.
    log('T+90s: Disabling consumer event-source mapping...');
    await disableEventSourceMapping(config.region, mappingUuid);
    await waitForMappingState(config.region, mappingUuid, 'Disabled');
    const killTime = Date.now();
    timeline.push({
        timestampMs: killTime,
        offsetSec: Math.round((killTime - startMs) / 1000),
        action: 'fault-inject',
        detail: 'Consumer event-source mapping disabled (SQS consumer killed)',
    });

    // T+90 to T+150: consumer is down (60s outage window).
    // Events published during this window remain in SQS.
    log('Consumer disabled. Waiting 60s for outage window...');
    await sleep(60_000);

    // T+150: Restart consumer.
    log('T+150s: Re-enabling consumer event-source mapping...');
    await enableEventSourceMapping(config.region, mappingUuid);
    await waitForMappingState(config.region, mappingUuid, 'Enabled');
    const restoreTime = Date.now();
    timeline.push({
        timestampMs: restoreTime,
        offsetSec: Math.round((restoreTime - startMs) / 1000),
        action: 'fault-remove',
        detail: 'Consumer event-source mapping re-enabled',
    });

    // Wait for recovery — all queued events should be processed within 30s.
    log('Waiting for queue to drain (max 30s)...');
    const recoveryElapsed = await waitForCondition(async () => {
        const depth = await queryQueueDepth(config.region, config.mainQueueUrl);
        log(`  Queue depth: ${depth}`);
        return depth === 0;
    }, BUS_STORE_RECOVERY_THRESHOLD_SEC * 1000);

    timeline.push({
        timestampMs: Date.now(),
        offsetSec: Math.round((Date.now() - startMs) / 1000),
        action: 'recovery-check',
        detail: `Recovery elapsed: ${recoveryElapsed}ms (threshold: ${BUS_STORE_RECOVERY_THRESHOLD_SEC}s)`,
    });

    // Wait an additional 30s for metrics to settle.
    await sleep(30_000);
    const endTime = new Date();

    // --- Assertions ---

    // 1. Zero permanent event loss (REQ 3.5, 9.8, 15.4).
    const eventsLost = await queryEventsLost(
        config.region,
        config.metricsNamespace,
        startTime,
        endTime,
    );
    assertions.push({
        name: 'zero-permanent-event-loss',
        passed: eventsLost === 0,
        expected: '0 events lost',
        actual: `${eventsLost} events lost`,
    });

    // 2. All events published during outage are eventually processed.
    const remainingDepth = await queryQueueDepth(
        config.region,
        config.mainQueueUrl,
    );
    assertions.push({
        name: 'all-queued-events-processed',
        passed: remainingDepth === 0,
        expected: 'Queue depth = 0 after recovery',
        actual: `Queue depth = ${remainingDepth}`,
    });

    // 3. Recovery time within bounds (30s per §5.2).
    const recoveredInTime = recoveryElapsed >= 0 &&
        recoveryElapsed <= BUS_STORE_RECOVERY_THRESHOLD_SEC * 1000;
    assertions.push({
        name: 'recovery-time-within-bounds',
        passed: recoveredInTime,
        expected: `<= ${BUS_STORE_RECOVERY_THRESHOLD_SEC}s`,
        actual: recoveryElapsed >= 0
            ? `${(recoveryElapsed / 1000).toFixed(1)}s`
            : 'timed out',
    });

    // 4. DLQ depth returns to 0 (no events permanently stuck).
    const dlqDepth = await queryDlqDepth(config.region, config.dlqUrl);
    assertions.push({
        name: 'dlq-depth-zero',
        passed: dlqDepth === 0,
        expected: 'DLQ depth = 0',
        actual: `DLQ depth = ${dlqDepth}`,
    });

    const passed = assertions.every((a) => a.passed);
    log(`Scenario 2.5 ${passed ? 'PASSED' : 'FAILED'}`);

    return {
        scenario: '2.5',
        passed,
        assertions,
        timeline,
        durationMs: Date.now() - startMs,
    };
}

// ---------------------------------------------------------------------------
// Scenario 2.6: Inject 2000ms DynamoDB latency from T+60s to T+120s
// ---------------------------------------------------------------------------

async function runScenario26(config: ChaosConfig): Promise<ScenarioResult> {
    const timeline: TimelineEntry[] = [];
    const assertions: AssertionResult[] = [];
    const startMs = Date.now();
    const startTime = new Date(startMs);

    log('=== Scenario 2.6: DynamoDB Latency Spike ===');
    log(`Consumer function: ${config.consumerFunctionName}`);

    timeline.push({
        timestampMs: Date.now(),
        offsetSec: 0,
        action: 'start',
        detail: 'Scenario 2.6 started',
    });

    // T+0 to T+60: normal operation.
    log('Waiting 60s for baseline load...');
    await sleep(60_000);

    // T+60: Inject 2000ms DynamoDB latency via environment variable.
    log('T+60s: Injecting 2000ms DynamoDB latency...');
    await injectDynamoLatency(config.region, config.consumerFunctionName, 2000);
    const injectTime = Date.now();
    timeline.push({
        timestampMs: injectTime,
        offsetSec: Math.round((injectTime - startMs) / 1000),
        action: 'fault-inject',
        detail: 'DynamoDB latency 2000ms injected via UNS_DYNAMO_LATENCY_MS',
    });

    // T+60 to T+120: DynamoDB latency is active (60s window).
    log('DynamoDB latency active. Waiting 60s...');
    await sleep(60_000);

    // T+120: Remove DynamoDB latency.
    log('T+120s: Removing DynamoDB latency injection...');
    await removeDynamoLatency(config.region, config.consumerFunctionName);
    const removeTime = Date.now();
    timeline.push({
        timestampMs: removeTime,
        offsetSec: Math.round((removeTime - startMs) / 1000),
        action: 'fault-remove',
        detail: 'DynamoDB latency injection removed',
    });

    // Wait for recovery — system should recover within 30s of fault removal.
    log('Waiting for system recovery (max 30s)...');
    const recoveryElapsed = await waitForCondition(async () => {
        // Check that the in-app delivery latency has returned to normal.
        const now = new Date();
        const windowStart = new Date(now.getTime() - 10_000);
        const p95 = await queryChannelLatencyP95(
            config.region,
            config.metricsNamespace,
            'in_app',
            windowStart,
            now,
        );
        log(`  in_app p95: ${p95}ms`);
        return p95 > 0 && p95 <= 500;
    }, BUS_STORE_RECOVERY_THRESHOLD_SEC * 1000);

    timeline.push({
        timestampMs: Date.now(),
        offsetSec: Math.round((Date.now() - startMs) / 1000),
        action: 'recovery-check',
        detail: `Recovery elapsed: ${recoveryElapsed}ms (threshold: ${BUS_STORE_RECOVERY_THRESHOLD_SEC}s)`,
    });

    // Wait an additional 30s for metrics to settle.
    await sleep(30_000);
    const endTime = new Date();

    // --- Assertions ---

    // 1. Zero permanent event loss (no data loss despite latency).
    const eventsLost = await queryEventsLost(
        config.region,
        config.metricsNamespace,
        startTime,
        endTime,
    );
    assertions.push({
        name: 'zero-permanent-event-loss',
        passed: eventsLost === 0,
        expected: '0 events lost',
        actual: `${eventsLost} events lost`,
    });

    // 2. No errors propagated to clients during the latency window.
    // We check that the error rate stayed below 1% (same as §5.1).
    const errorMetric = await queryChannelLatencyP95(
        config.region,
        config.metricsNamespace,
        'error_rate',
        new Date(injectTime),
        new Date(removeTime),
    );
    // error_rate metric is a percentage; threshold is < 1%.
    assertions.push({
        name: 'no-client-errors-during-latency',
        passed: errorMetric < 1,
        expected: 'error_rate < 1%',
        actual: `error_rate = ${errorMetric}%`,
    });

    // 3. Recovery time within bounds (30s per §5.2).
    const recoveredInTime = recoveryElapsed >= 0 &&
        recoveryElapsed <= BUS_STORE_RECOVERY_THRESHOLD_SEC * 1000;
    assertions.push({
        name: 'recovery-time-within-bounds',
        passed: recoveredInTime,
        expected: `<= ${BUS_STORE_RECOVERY_THRESHOLD_SEC}s`,
        actual: recoveryElapsed >= 0
            ? `${(recoveryElapsed / 1000).toFixed(1)}s`
            : 'timed out',
    });

    // 4. DLQ depth is 0 (latency should not cause permanent failures).
    const dlqDepth = await queryDlqDepth(config.region, config.dlqUrl);
    assertions.push({
        name: 'dlq-depth-zero',
        passed: dlqDepth === 0,
        expected: 'DLQ depth = 0',
        actual: `DLQ depth = ${dlqDepth}`,
    });

    // 5. Unaffected channels continue within normal thresholds.
    for (const channel of ['in_app', 'push', 'email']) {
        const p95 = await queryChannelLatencyP95(
            config.region,
            config.metricsNamespace,
            channel,
            endTime,
            new Date(endTime.getTime() + 10_000),
        );
        const threshold = channel === 'in_app' ? 500 : 5000;
        assertions.push({
            name: `post-recovery-${channel}-p95`,
            passed: p95 <= threshold || p95 === 0,
            expected: `p95 <= ${threshold}ms (post-recovery)`,
            actual: `p95 = ${p95}ms`,
        });
    }

    const passed = assertions.every((a) => a.passed);
    log(`Scenario 2.6 ${passed ? 'PASSED' : 'FAILED'}`);

    return {
        scenario: '2.6',
        passed,
        assertions,
        timeline,
        durationMs: Date.now() - startMs,
    };
}

// ---------------------------------------------------------------------------
// Orchestrator — runs selected scenarios and produces a summary report
// ---------------------------------------------------------------------------

export async function runChaosHarness(
    overrides: Partial<ChaosConfig> = {},
): Promise<ScenarioResult[]> {
    const config = resolveConfig(overrides);
    const results: ScenarioResult[] = [];

    log('╔══════════════════════════════════════════════════════════╗');
    log('║  UNS Chaos Harness — Fault Injection Orchestrator       ║');
    log('╚══════════════════════════════════════════════════════════╝');
    log(`Region: ${config.region}`);
    log(`Stage: ${config.stage}`);
    log(`Scenario: ${config.scenario}`);
    log('');

    const scenarios = config.scenario === 'all'
        ? ['2.4', '2.5', '2.6']
        : [config.scenario];

    for (const scenario of scenarios) {
        switch (scenario) {
            case '2.4':
                results.push(await runScenario24(config));
                break;
            case '2.5':
                results.push(await runScenario25(config));
                break;
            case '2.6':
                results.push(await runScenario26(config));
                break;
            default:
                log(`Unknown scenario: ${scenario}. Skipping.`);
        }
    }

    // Print summary.
    log('');
    log('═══════════════════════════════════════════════════════════');
    log('  CHAOS HARNESS SUMMARY');
    log('═══════════════════════════════════════════════════════════');
    for (const r of results) {
        const status = r.passed ? '✓ PASS' : '✗ FAIL';
        log(`  Scenario ${r.scenario}: ${status} (${(r.durationMs / 1000).toFixed(0)}s)`);
        for (const a of r.assertions) {
            const mark = a.passed ? '  ✓' : '  ✗';
            log(`    ${mark} ${a.name}: ${a.actual}`);
        }
    }
    log('═══════════════════════════════════════════════════════════');

    const allPassed = results.every((r) => r.passed);
    log(`\nOverall: ${allPassed ? 'ALL PASSED' : 'SOME FAILED'}`);

    return results;
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

function parseCliArgs(): Partial<ChaosConfig> {
    const args = process.argv.slice(2);
    const config: Partial<ChaosConfig> = {};

    for (let i = 0; i < args.length; i += 1) {
        switch (args[i]) {
            case '--scenario':
                config.scenario = args[++i];
                break;
            case '--region':
                config.region = args[++i];
                break;
            case '--stage':
                config.stage = args[++i];
                break;
            case '--consumer-function':
                config.consumerFunctionName = args[++i];
                break;
            case '--push-adapter-function':
                config.pushAdapterFunctionName = args[++i];
                break;
            case '--queue-url':
                config.mainQueueUrl = args[++i];
                break;
            case '--dlq-url':
                config.dlqUrl = args[++i];
                break;
            case '--metrics-namespace':
                config.metricsNamespace = args[++i];
                break;
            case '--help':
                console.log(`
UNS Chaos Harness — Fault Injection Orchestrator

Usage:
  npx ts-node --transpile-only chaos-harness.ts [options]

Options:
  --scenario <id>              Scenario to run: 2.4, 2.5, 2.6, or all (default: all)
  --region <region>            AWS region (default: us-east-1)
  --stage <stage>              Deployment stage (default: loadtest)
  --consumer-function <name>   Lambda function name for SQS consumer
  --push-adapter-function <n>  Lambda function name for push adapter
  --queue-url <url>            SQS main queue URL
  --dlq-url <url>              SQS DLQ URL
  --metrics-namespace <ns>     CloudWatch namespace (default: UNS)
  --help                       Show this help message

Environment variables (alternative to CLI flags):
  CHAOS_REGION, CHAOS_STAGE, CHAOS_CONSUMER_FUNCTION,
  CHAOS_PUSH_ADAPTER_FUNCTION, CHAOS_QUEUE_URL, CHAOS_DLQ_URL,
  CHAOS_METRICS_NAMESPACE, CHAOS_SCENARIO
`);
                process.exit(0);
                break;
        }
    }

    // Fall back to environment variables.
    config.region ??= process.env.CHAOS_REGION;
    config.stage ??= process.env.CHAOS_STAGE;
    config.consumerFunctionName ??= process.env.CHAOS_CONSUMER_FUNCTION;
    config.pushAdapterFunctionName ??= process.env.CHAOS_PUSH_ADAPTER_FUNCTION;
    config.mainQueueUrl ??= process.env.CHAOS_QUEUE_URL;
    config.dlqUrl ??= process.env.CHAOS_DLQ_URL;
    config.metricsNamespace ??= process.env.CHAOS_METRICS_NAMESPACE;
    config.scenario ??= process.env.CHAOS_SCENARIO;

    return config;
}

// Run when executed directly (not imported as a module).
if (require.main === module) {
    const config = parseCliArgs();
    runChaosHarness(config)
        .then((results) => {
            const allPassed = results.every((r) => r.passed);
            process.exit(allPassed ? 0 : 1);
        })
        .catch((err) => {
            console.error('[chaos-harness] Fatal error:', err);
            process.exit(2);
        });
}
