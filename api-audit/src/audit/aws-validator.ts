/**
 * AWS_Validator — AWS service validation and CloudWatch logging checks
 * (Task 14.1).
 *
 * Verifies connectivity and configured behavior for the six AWS services the
 * platform depends on — Amazon Cognito, Amazon DynamoDB, Amazon S3, AWS
 * Lambda, Amazon API Gateway, and the WebSocket API — and verifies that
 * CloudWatch logging is configured for each (Requirements 9.1, 9.2).
 *
 * Design contract (design.md → AwsValidator):
 *   validate(env: EnvironmentConfig): Promise<{ validations: ServiceValidation[] }>
 *
 * The run is failure-resilient (Requirements 9.3, 9.4): the report always
 * contains exactly one `ServiceValidation` per service, an unreachable service
 * yields a `failed` entry carrying the failure detail, and validation always
 * continues to the next service — a single broken service never aborts the run.
 *
 * Mockability: the unit of work per service is an injectable {@link ServiceProbe}.
 * The default probes construct AWS SDK v3 clients, but each client (and the
 * probe set as a whole) can be overridden, so the orchestration and the probes
 * can be exercised without live AWS access.
 */

import {
  CognitoIdentityProviderClient,
  ListUserPoolsCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { DynamoDBClient, ListTablesCommand } from '@aws-sdk/client-dynamodb';
import { S3Client, ListBucketsCommand } from '@aws-sdk/client-s3';
import { LambdaClient, ListFunctionsCommand } from '@aws-sdk/client-lambda';
import { APIGatewayClient, GetRestApisCommand } from '@aws-sdk/client-api-gateway';
import {
  ApiGatewayManagementApiClient,
  GetConnectionCommand,
} from '@aws-sdk/client-apigatewaymanagementapi';
import {
  CloudWatchLogsClient,
  DescribeLogGroupsCommand,
} from '@aws-sdk/client-cloudwatch-logs';

import type {
  AwsService,
  EnvironmentConfig,
  ServiceValidation,
} from '../types';

/**
 * The canonical, deterministic order in which services are validated and
 * reported. Every AWS validation report contains exactly one entry per service
 * in this order (Requirement 9.3).
 */
export const AWS_SERVICES: readonly AwsService[] = [
  'cognito',
  'dynamodb',
  's3',
  'lambda',
  'apigateway',
  'websocket',
] as const;

/** The result of probing a single AWS service. Probes never throw. */
export interface ProbeResult {
  /** Whether the service responded to a connectivity check. */
  reachable: boolean;
  /** Detail describing why the service was unreachable, when applicable. */
  failureDetail?: string;
  /** Whether CloudWatch logging is configured for the service (Requirement 9.2). */
  loggingConfigured: boolean;
  /** Non-fatal configuration issues detected during validation. */
  configIssues: string[];
}

/** A function that validates connectivity and logging for one AWS service. */
export type ServiceProbe = (env: EnvironmentConfig) => Promise<ProbeResult>;

/** The full set of per-service probes, one per {@link AwsService}. */
export type ServiceProbes = Record<AwsService, ServiceProbe>;

/**
 * The AWS_Validator stage. Validates the configured AWS services and produces
 * a report that is complete (one entry per service) and failure-resilient
 * (Requirements 9.3, 9.4).
 */
export interface AwsValidator {
  validate(env: EnvironmentConfig): Promise<{ validations: ServiceValidation[] }>;
}

// ---------------------------------------------------------------------------
// Orchestration (pure, failure-resilient)
// ---------------------------------------------------------------------------

/**
 * Validates every AWS service using the supplied probes and assembles the
 * report. Each probe is awaited independently and guarded so that a probe
 * which rejects (or a missing probe) still produces a `failed` entry and the
 * run continues to the next service (Requirements 9.3, 9.4).
 */
export async function validateAwsServices(
  env: EnvironmentConfig,
  probes: ServiceProbes,
): Promise<{ validations: ServiceValidation[] }> {
  const validations: ServiceValidation[] = [];

  for (const service of AWS_SERVICES) {
    validations.push(await validateOneService(service, env, probes[service]));
  }

  return { validations };
}

/**
 * Runs a single service probe and maps its result into a `ServiceValidation`.
 * Any thrown error (including an absent probe) is captured as a `failed`
 * outcome so validation of the remaining services is never interrupted.
 */
async function validateOneService(
  service: AwsService,
  env: EnvironmentConfig,
  probe: ServiceProbe | undefined,
): Promise<ServiceValidation> {
  if (!probe) {
    return {
      service,
      outcome: 'failed',
      loggingConfigured: false,
      configIssues: [`No validation probe configured for service "${service}".`],
    };
  }

  try {
    const result = await probe(env);
    const configIssues = [...result.configIssues];
    if (!result.reachable && result.failureDetail) {
      configIssues.unshift(result.failureDetail);
    }
    return {
      service,
      outcome: result.reachable ? 'ok' : 'failed',
      loggingConfigured: result.loggingConfigured,
      configIssues,
    };
  } catch (error) {
    return {
      service,
      outcome: 'failed',
      loggingConfigured: false,
      configIssues: [`Validation error: ${describeError(error)}`],
    };
  }
}

// ---------------------------------------------------------------------------
// Default probe construction (AWS SDK v3)
// ---------------------------------------------------------------------------

/**
 * Injectable AWS SDK clients used by the default probes. Every client is
 * optional: when omitted, a real client is constructed for the resolved
 * region. Supplying clients (for example, mocked instances) lets the default
 * probes run without live AWS access.
 */
export interface DefaultProbeClients {
  cognito?: CognitoIdentityProviderClient;
  dynamodb?: DynamoDBClient;
  s3?: S3Client;
  lambda?: LambdaClient;
  apiGateway?: APIGatewayClient;
  cloudWatchLogs?: CloudWatchLogsClient;
  /**
   * Pre-built WebSocket management client. The management client is endpoint-
   * bound, so when omitted it is constructed from the WebSocket endpoint
   * resolved from configuration.
   */
  apiGatewayManagement?: ApiGatewayManagementApiClient;
}

/** Options controlling default probe construction. */
export interface DefaultProbeOptions {
  /** Override AWS SDK clients (for testing or shared client reuse). */
  clients?: DefaultProbeClients;
  /**
   * Source for resource identifiers and log-group names not carried in the
   * environment config's `variableValues`. Defaults to `process.env`.
   */
  envSource?: Record<string, string | undefined>;
}

/**
 * Reads a configuration value, preferring the environment config's resolved
 * `variableValues`, then falling back to the raw env source. Whitespace-only
 * values are treated as absent.
 */
function readVar(
  env: EnvironmentConfig,
  envSource: Record<string, string | undefined>,
  name: string,
): string | undefined {
  const fromConfig = env.variableValues.get(name);
  if (typeof fromConfig === 'string' && fromConfig.trim().length > 0) {
    return fromConfig;
  }
  const fromEnv = envSource[name];
  if (typeof fromEnv === 'string' && fromEnv.trim().length > 0) {
    return fromEnv;
  }
  return undefined;
}

/** Resolves the AWS region from configuration, defaulting to `us-east-1`. */
function resolveRegion(
  env: EnvironmentConfig,
  envSource: Record<string, string | undefined>,
): string {
  return readVar(env, envSource, 'AWS_REGION') ?? 'us-east-1';
}

/**
 * Checks whether a CloudWatch log group matching the given name/prefix exists,
 * confirming CloudWatch logging is configured for a service (Requirement 9.2).
 *
 * Returns `loggingConfigured: false` with a descriptive config issue when no
 * log-group name is configured or when no matching group is found. A failed
 * lookup is recorded as a config issue rather than failing the service, since
 * logging configuration is independent of service connectivity.
 */
async function checkCloudWatchLogging(
  client: CloudWatchLogsClient,
  service: AwsService,
  logGroupPrefix: string | undefined,
  configVarName: string,
): Promise<{ loggingConfigured: boolean; configIssues: string[] }> {
  if (!logGroupPrefix) {
    return {
      loggingConfigured: false,
      configIssues: [
        `CloudWatch logging not verifiable for ${service}: set ${configVarName} to the log group name.`,
      ],
    };
  }

  try {
    const response = await client.send(
      new DescribeLogGroupsCommand({ logGroupNamePrefix: logGroupPrefix, limit: 1 }),
    );
    const groups = response.logGroups ?? [];
    if (groups.length > 0) {
      return { loggingConfigured: true, configIssues: [] };
    }
    return {
      loggingConfigured: false,
      configIssues: [
        `No CloudWatch log group found for ${service} (prefix "${logGroupPrefix}").`,
      ],
    };
  } catch (error) {
    return {
      loggingConfigured: false,
      configIssues: [
        `CloudWatch logging check failed for ${service}: ${describeError(error)}`,
      ],
    };
  }
}

/**
 * Builds the default probe set backed by AWS SDK v3 clients. Each probe runs a
 * lightweight connectivity call against its service, then verifies CloudWatch
 * logging via the CloudWatch Logs client. Probes never throw — connectivity
 * errors are reported as `reachable: false` with a failure detail.
 */
export function createDefaultProbes(options: DefaultProbeOptions = {}): ServiceProbes {
  const envSource = options.envSource ?? process.env;
  const overrides = options.clients ?? {};

  // Lazily build clients per region so a missing region default still works.
  const clientFor = (env: EnvironmentConfig) => {
    const region = resolveRegion(env, envSource);
    return {
      cognito: overrides.cognito ?? new CognitoIdentityProviderClient({ region }),
      dynamodb: overrides.dynamodb ?? new DynamoDBClient({ region }),
      s3: overrides.s3 ?? new S3Client({ region }),
      lambda: overrides.lambda ?? new LambdaClient({ region }),
      apiGateway: overrides.apiGateway ?? new APIGatewayClient({ region }),
      cloudWatchLogs:
        overrides.cloudWatchLogs ?? new CloudWatchLogsClient({ region }),
    };
  };

  return {
    cognito: async (env) => {
      const { cognito, cloudWatchLogs } = clientFor(env);
      const connectivity = await probeConnectivity(() =>
        cognito.send(new ListUserPoolsCommand({ MaxResults: 1 })),
      );
      const logging = await checkCloudWatchLogging(
        cloudWatchLogs,
        'cognito',
        readVar(env, envSource, 'COGNITO_LOG_GROUP'),
        'COGNITO_LOG_GROUP',
      );
      return { ...connectivity, ...logging };
    },

    dynamodb: async (env) => {
      const { dynamodb, cloudWatchLogs } = clientFor(env);
      const connectivity = await probeConnectivity(() =>
        dynamodb.send(new ListTablesCommand({ Limit: 1 })),
      );
      const logging = await checkCloudWatchLogging(
        cloudWatchLogs,
        'dynamodb',
        readVar(env, envSource, 'DYNAMODB_LOG_GROUP'),
        'DYNAMODB_LOG_GROUP',
      );
      return { ...connectivity, ...logging };
    },

    s3: async (env) => {
      const { s3, cloudWatchLogs } = clientFor(env);
      const connectivity = await probeConnectivity(() =>
        s3.send(new ListBucketsCommand({})),
      );
      const logging = await checkCloudWatchLogging(
        cloudWatchLogs,
        's3',
        readVar(env, envSource, 'S3_LOG_GROUP'),
        'S3_LOG_GROUP',
      );
      return { ...connectivity, ...logging };
    },

    lambda: async (env) => {
      const { lambda, cloudWatchLogs } = clientFor(env);
      const connectivity = await probeConnectivity(() =>
        lambda.send(new ListFunctionsCommand({ MaxItems: 1 })),
      );
      const functionName = readVar(env, envSource, 'LAMBDA_FUNCTION_NAME');
      const logGroup =
        readVar(env, envSource, 'LAMBDA_LOG_GROUP') ??
        (functionName ? `/aws/lambda/${functionName}` : undefined);
      const logging = await checkCloudWatchLogging(
        cloudWatchLogs,
        'lambda',
        logGroup,
        'LAMBDA_LOG_GROUP',
      );
      return { ...connectivity, ...logging };
    },

    apigateway: async (env) => {
      const { apiGateway, cloudWatchLogs } = clientFor(env);
      const connectivity = await probeConnectivity(() =>
        apiGateway.send(new GetRestApisCommand({ limit: 1 })),
      );
      const restApiId = readVar(env, envSource, 'API_GATEWAY_REST_API_ID');
      const logGroup =
        readVar(env, envSource, 'API_GATEWAY_LOG_GROUP') ??
        (restApiId ? `API-Gateway-Execution-Logs_${restApiId}` : undefined);
      const logging = await checkCloudWatchLogging(
        cloudWatchLogs,
        'apigateway',
        logGroup,
        'API_GATEWAY_LOG_GROUP',
      );
      return { ...connectivity, ...logging };
    },

    websocket: async (env) => {
      const { cloudWatchLogs } = clientFor(env);
      const connectivity = await probeWebsocketConnectivity(env, envSource, overrides);
      const apiId = readVar(env, envSource, 'WEBSOCKET_API_ID');
      const logGroup =
        readVar(env, envSource, 'WEBSOCKET_LOG_GROUP') ??
        (apiId ? `/aws/apigateway/${apiId}` : undefined);
      const logging = await checkCloudWatchLogging(
        cloudWatchLogs,
        'websocket',
        logGroup,
        'WEBSOCKET_LOG_GROUP',
      );
      return { ...connectivity, ...logging };
    },
  };
}

/**
 * Runs a connectivity call and maps it to the reachable/unreachable portion of
 * a probe result. Any rejection is captured as `reachable: false`.
 */
async function probeConnectivity(
  call: () => Promise<unknown>,
): Promise<{ reachable: boolean; failureDetail?: string }> {
  try {
    await call();
    return { reachable: true };
  } catch (error) {
    return { reachable: false, failureDetail: describeError(error) };
  }
}

/**
 * Probes WebSocket API connectivity through the API Gateway Management API.
 *
 * The management API is endpoint-bound and has no list operation, so we issue a
 * `GetConnection` against a sentinel connection id. A live endpoint responds
 * with `GoneException` (the connection does not exist) — which still confirms
 * reachability — whereas a network/credential/configuration error indicates the
 * endpoint could not be reached.
 */
async function probeWebsocketConnectivity(
  env: EnvironmentConfig,
  envSource: Record<string, string | undefined>,
  overrides: DefaultProbeClients,
): Promise<{ reachable: boolean; failureDetail?: string }> {
  let client = overrides.apiGatewayManagement;
  if (!client) {
    const endpoint =
      readVar(env, envSource, 'WEBSOCKET_API_ENDPOINT') ??
      readVar(env, envSource, 'WEBSOCKET_API_URL');
    if (!endpoint) {
      return {
        reachable: false,
        failureDetail:
          'WebSocket endpoint not configured: set WEBSOCKET_API_ENDPOINT to the management API URL.',
      };
    }
    client = new ApiGatewayManagementApiClient({
      region: resolveRegion(env, envSource),
      endpoint,
    });
  }

  try {
    await client.send(
      new GetConnectionCommand({ ConnectionId: 'audit-connectivity-probe' }),
    );
    return { reachable: true };
  } catch (error) {
    // A "gone" connection proves the management API itself is reachable.
    if (errorName(error) === 'GoneException') {
      return { reachable: true };
    }
    return { reachable: false, failureDetail: describeError(error) };
  }
}

// ---------------------------------------------------------------------------
// Default validator
// ---------------------------------------------------------------------------

/**
 * Default {@link AwsValidator} implementation. Composes the supplied probes
 * (defaulting to the AWS SDK-backed probes) over the failure-resilient
 * orchestration.
 */
export class DefaultAwsValidator implements AwsValidator {
  private readonly probes: ServiceProbes;

  constructor(probesOrOptions: ServiceProbes | DefaultProbeOptions = {}) {
    this.probes = isServiceProbes(probesOrOptions)
      ? probesOrOptions
      : createDefaultProbes(probesOrOptions);
  }

  validate(
    env: EnvironmentConfig,
  ): Promise<{ validations: ServiceValidation[] }> {
    return validateAwsServices(env, this.probes);
  }
}

/** Type guard distinguishing an explicit probe set from construction options. */
function isServiceProbes(
  value: ServiceProbes | DefaultProbeOptions,
): value is ServiceProbes {
  return AWS_SERVICES.every(
    (service) => typeof (value as Record<string, unknown>)[service] === 'function',
  );
}

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

/** Extracts a stable error name (AWS SDK errors expose `name`). */
function errorName(error: unknown): string | undefined {
  if (error instanceof Error) {
    return error.name;
  }
  if (typeof error === 'object' && error !== null && 'name' in error) {
    const name = (error as { name?: unknown }).name;
    return typeof name === 'string' ? name : undefined;
  }
  return undefined;
}

/** Renders an unknown thrown value into a human-readable detail string. */
function describeError(error: unknown): string {
  if (error instanceof Error) {
    return error.message || error.name;
  }
  if (typeof error === 'string') {
    return error;
  }
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}
