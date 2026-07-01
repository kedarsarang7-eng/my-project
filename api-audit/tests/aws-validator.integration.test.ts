/**
 * AWS_Validator — integration test for AWS connectivity and CloudWatch logging
 * (Task 14.3).
 *
 * Feature: api-audit-testing-automation
 * Validates: Requirements 9.1, 9.2 — when an AWS validation run is executed the
 * AWS_Validator verifies connectivity and configured behavior for Amazon
 * Cognito, Amazon DynamoDB, Amazon S3, AWS Lambda, Amazon API Gateway, and the
 * WebSocket API (9.1), and verifies that CloudWatch logging is configured for
 * each validated service (9.2).
 *
 * Approach: this exercises the *default* AWS SDK-backed probes end to end — the
 * real connectivity calls (`ListUserPools`, `ListTables`, `ListBuckets`,
 * `ListFunctions`, `GetRestApis`, the WebSocket management `GetConnection`) and
 * the real CloudWatch `DescribeLogGroups` logging check — but every AWS SDK v3
 * client is replaced with a mock that exposes only the `send(command)` method
 * the probes use. No real AWS account, network, or credentials are touched.
 *
 * The mocks let us drive both halves of each `ServiceValidation`:
 *   - connectivity: each service client's `send` resolves (reachable) or
 *     rejects (unreachable), and the WebSocket management client's
 *     `GoneException` rejection is treated as reachable by design.
 *   - logging: the shared CloudWatch Logs client's `DescribeLogGroups` response
 *     reports a matching log group (configured) or none (not configured).
 *
 * Because everything runs in-process against mocked clients, the suite runs
 * unconditionally and performs no external I/O.
 */

import {
  CognitoIdentityProviderClient,
  ListUserPoolsCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { DynamoDBClient, ListTablesCommand } from '@aws-sdk/client-dynamodb';
import { S3Client, ListBucketsCommand } from '@aws-sdk/client-s3';
import { LambdaClient, ListFunctionsCommand } from '@aws-sdk/client-lambda';
import {
  APIGatewayClient,
  GetRestApisCommand,
} from '@aws-sdk/client-api-gateway';
import {
  ApiGatewayManagementApiClient,
  GetConnectionCommand,
} from '@aws-sdk/client-apigatewaymanagementapi';
import {
  CloudWatchLogsClient,
  DescribeLogGroupsCommand,
} from '@aws-sdk/client-cloudwatch-logs';

import {
  AWS_SERVICES,
  DefaultAwsValidator,
  DefaultProbeClients,
} from '../src/audit/aws-validator';
import { AwsService, EnvironmentConfig } from '../src/types';

// ---------------------------------------------------------------------------
// Mock AWS SDK v3 clients
//
// Each probe only ever calls `client.send(command)`, so a mock that records the
// command it received and resolves/rejects a canned response fully stands in
// for the real client without any AWS coupling.
// ---------------------------------------------------------------------------

/** A recorded `send` invocation against a mock client. */
interface SentCommand {
  command: unknown;
}

/** A minimal mock client exposing the `send` the probes depend on. */
interface MockClient {
  send: jest.Mock<Promise<unknown>, [unknown]>;
  sent: SentCommand[];
}

/** Builds a mock client whose `send` resolves the given response. */
function reachableClient(response: unknown): MockClient {
  const sent: SentCommand[] = [];
  const send = jest.fn(async (command: unknown) => {
    sent.push({ command });
    return response;
  });
  return { send, sent };
}

/** Builds a mock client whose `send` rejects with the given error. */
function unreachableClient(error: Error): MockClient {
  const sent: SentCommand[] = [];
  const send = jest.fn(async (command: unknown) => {
    sent.push({ command });
    throw error;
  });
  return { send, sent };
}

/** Casts a mock client to the requested SDK client type for injection. */
function asClient<T>(mock: MockClient): T {
  return mock as unknown as T;
}

// ---------------------------------------------------------------------------
// Environment configuration
//
// The default probes read region + per-service log-group names from the
// environment config's `variableValues` (preferred) or the injected
// `envSource`. We provide every log-group name so the CloudWatch logging check
// has a prefix to look up for each service (Requirement 9.2).
// ---------------------------------------------------------------------------

const LOG_GROUP_VARS: Record<string, string> = {
  AWS_REGION: 'us-east-1',
  COGNITO_LOG_GROUP: '/aws/cognito/userpool',
  DYNAMODB_LOG_GROUP: '/aws/dynamodb/contributor-insights',
  S3_LOG_GROUP: '/aws/s3/access-logs',
  LAMBDA_LOG_GROUP: '/aws/lambda/audit-fn',
  API_GATEWAY_LOG_GROUP: 'API-Gateway-Execution-Logs_abc123',
  WEBSOCKET_LOG_GROUP: '/aws/apigateway/ws-xyz789',
};

function makeEnv(): EnvironmentConfig {
  return {
    name: 'AWS',
    baseUrl: 'https://api.example.test',
    requiredVars: [],
    variableValues: new Map(Object.entries(LOG_GROUP_VARS)),
  };
}

/**
 * Builds the full set of mocked SDK clients used by the default probes. By
 * default every connectivity call succeeds and CloudWatch reports a matching
 * log group, so every service validates as reachable with logging configured.
 */
function buildMocks(): {
  clients: DefaultProbeClients;
  mocks: {
    cognito: MockClient;
    dynamodb: MockClient;
    s3: MockClient;
    lambda: MockClient;
    apiGateway: MockClient;
    apiGatewayManagement: MockClient;
    cloudWatchLogs: MockClient;
  };
} {
  // A "gone" connection proves the WebSocket management API is reachable.
  const goneError = new Error('connection not found');
  goneError.name = 'GoneException';

  const mocks = {
    cognito: reachableClient({ UserPools: [] }),
    dynamodb: reachableClient({ TableNames: [] }),
    s3: reachableClient({ Buckets: [] }),
    lambda: reachableClient({ Functions: [] }),
    apiGateway: reachableClient({ items: [] }),
    apiGatewayManagement: unreachableClient(goneError),
    // One CloudWatch client is shared across all services; it always returns a
    // matching log group so every service's logging check passes.
    cloudWatchLogs: reachableClient({
      logGroups: [{ logGroupName: 'matched-group' }],
    }),
  };

  const clients: DefaultProbeClients = {
    cognito: asClient<CognitoIdentityProviderClient>(mocks.cognito),
    dynamodb: asClient<DynamoDBClient>(mocks.dynamodb),
    s3: asClient<S3Client>(mocks.s3),
    lambda: asClient<LambdaClient>(mocks.lambda),
    apiGateway: asClient<APIGatewayClient>(mocks.apiGateway),
    apiGatewayManagement: asClient<ApiGatewayManagementApiClient>(
      mocks.apiGatewayManagement
    ),
    cloudWatchLogs: asClient<CloudWatchLogsClient>(mocks.cloudWatchLogs),
  };

  return { clients, mocks };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AWS_Validator integration: connectivity and CloudWatch logging (mocked SDK)', () => {
  it('verifies connectivity and logging for every service, one entry per service', async () => {
    const { clients, mocks } = buildMocks();
    const validator = new DefaultAwsValidator({
      clients,
      envSource: LOG_GROUP_VARS,
    });

    const { validations } = await validator.validate(makeEnv());

    // Requirement 9.1/9.3: exactly one entry per validated service, in the
    // canonical order, covering all six dependencies.
    expect(validations.map((v) => v.service)).toEqual([...AWS_SERVICES]);
    expect(new Set(validations.map((v) => v.service))).toEqual(
      new Set<AwsService>([
        'cognito',
        'dynamodb',
        's3',
        'lambda',
        'apigateway',
        'websocket',
      ])
    );

    // Requirement 9.1: every service is reachable (connectivity verified).
    for (const validation of validations) {
      expect(validation.outcome).toBe('ok');
      expect(validation.configIssues).toEqual([]);
    }

    // Requirement 9.2: CloudWatch logging is confirmed configured for each.
    for (const validation of validations) {
      expect(validation.loggingConfigured).toBe(true);
    }

    // The default probes actually issued the expected connectivity calls
    // against the mocked clients — proving real probe logic ran end to end.
    expect(mocks.cognito.sent[0].command).toBeInstanceOf(ListUserPoolsCommand);
    expect(mocks.dynamodb.sent[0].command).toBeInstanceOf(ListTablesCommand);
    expect(mocks.s3.sent[0].command).toBeInstanceOf(ListBucketsCommand);
    expect(mocks.lambda.sent[0].command).toBeInstanceOf(ListFunctionsCommand);
    expect(mocks.apiGateway.sent[0].command).toBeInstanceOf(GetRestApisCommand);
    expect(mocks.apiGatewayManagement.sent[0].command).toBeInstanceOf(
      GetConnectionCommand
    );

    // The logging check ran once per service via DescribeLogGroups.
    expect(mocks.cloudWatchLogs.send).toHaveBeenCalledTimes(AWS_SERVICES.length);
    for (const sent of mocks.cloudWatchLogs.sent) {
      expect(sent.command).toBeInstanceOf(DescribeLogGroupsCommand);
    }
  });

  it('records logging as not configured when no matching CloudWatch log group exists', async () => {
    const { clients, mocks } = buildMocks();
    // CloudWatch returns no groups -> logging cannot be confirmed (Req 9.2).
    mocks.cloudWatchLogs.send.mockImplementation(async (command: unknown) => {
      mocks.cloudWatchLogs.sent.push({ command });
      return { logGroups: [] };
    });

    const validator = new DefaultAwsValidator({
      clients,
      envSource: LOG_GROUP_VARS,
    });

    const { validations } = await validator.validate(makeEnv());

    // Connectivity still verified for every service (Requirement 9.1)...
    expect(validations).toHaveLength(AWS_SERVICES.length);
    for (const validation of validations) {
      expect(validation.outcome).toBe('ok');
      // ...but logging is reported absent with an explanatory config issue.
      expect(validation.loggingConfigured).toBe(false);
      expect(validation.configIssues.length).toBeGreaterThan(0);
    }
  });

  it('continues past an unreachable service while still checking the rest (Req 9.4)', async () => {
    const { clients, mocks } = buildMocks();
    // DynamoDB connectivity fails; the remaining services must still validate.
    const networkError = new Error('ECONNREFUSED: DynamoDB unreachable');
    mocks.dynamodb.send.mockImplementation(async (command: unknown) => {
      mocks.dynamodb.sent.push({ command });
      throw networkError;
    });

    const validator = new DefaultAwsValidator({
      clients,
      envSource: LOG_GROUP_VARS,
    });

    const { validations } = await validator.validate(makeEnv());

    // Still one entry per service, none skipped.
    expect(validations.map((v) => v.service)).toEqual([...AWS_SERVICES]);

    const dynamo = validations.find((v) => v.service === 'dynamodb');
    expect(dynamo?.outcome).toBe('failed');
    // The failure detail is recorded for the unreachable service.
    expect(dynamo?.configIssues.join(' ')).toContain('DynamoDB unreachable');

    // Every other service still validated as reachable.
    for (const validation of validations) {
      if (validation.service !== 'dynamodb') {
        expect(validation.outcome).toBe('ok');
      }
    }
  });
});
