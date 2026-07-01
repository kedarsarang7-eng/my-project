/**
 * CloudWatch Logs adapter for the Performance_Auditor (Task 13.1).
 *
 * Isolates the AWS SDK coupling in one place: it turns a CloudWatch Logs client
 * into the plain `LogEventFetcher` function the Performance_Auditor depends on.
 * Keeping the SDK import here means the auditor and its pure aggregation core
 * stay free of AWS types and remain trivially mockable (Requirement 8.2).
 */

import {
  CloudWatchLogsClient,
  FilterLogEventsCommand,
  FilterLogEventsCommandOutput,
} from '@aws-sdk/client-cloudwatch-logs';

import { LogEventFetcher } from './performance-auditor';

/** Narrow view of the CloudWatch Logs client — just the `send` we use. */
export interface CloudWatchLogsClientLike {
  send(
    command: FilterLogEventsCommand
  ): Promise<FilterLogEventsCommandOutput>;
}

/** How many recent log events to scan when capturing a metric. */
const DEFAULT_EVENT_LIMIT = 25;

/**
 * Builds a `LogEventFetcher` backed by a CloudWatch Logs client. The returned
 * function fetches the most recent log messages for a group, optionally
 * filtered by a CloudWatch filter pattern (e.g. `REPORT` for Lambda reports).
 *
 * Accepts the real `CloudWatchLogsClient` (or any object exposing a compatible
 * `send`), so tests can pass a stub.
 */
export function createCloudWatchLogFetcher(
  client: CloudWatchLogsClientLike,
  limit: number = DEFAULT_EVENT_LIMIT
): LogEventFetcher {
  return async (
    logGroupName: string,
    filterPattern?: string
  ): Promise<string[]> => {
    const command = new FilterLogEventsCommand({
      logGroupName,
      limit,
      ...(filterPattern ? { filterPattern } : {}),
    });
    const output = await client.send(command);
    return (output.events ?? [])
      .map((event) => event.message)
      .filter((message): message is string => typeof message === 'string');
  };
}

/** Convenience constructor for the default CloudWatch Logs client. */
export function defaultCloudWatchLogsClient(
  region?: string
): CloudWatchLogsClient {
  return new CloudWatchLogsClient(region ? { region } : {});
}
