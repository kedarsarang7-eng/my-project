/**
 * Correlation ID — Extraction and Generation
 *
 * Reads correlation ID from the `X-Correlation-Id` request header.
 * Generates a UUID v4 if the header is absent or empty.
 * Propagated to all downstream calls and telemetry.
 *
 * Requirements: 6.23, 12.3
 */

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';

/** Header name used for correlation ID propagation */
export const CORRELATION_HEADER = 'x-correlation-id';

/**
 * Extracts the correlation ID from request headers.
 * Generates a new UUID v4 if absent or empty.
 *
 * @param event - The API Gateway event (or headers object)
 * @returns A non-empty correlation ID string
 */
export function extractCorrelationId(event: APIGatewayProxyEventV2): string {
  const headers = event.headers ?? {};

  // API Gateway lowercases headers in V2 payload format
  const value =
    headers[CORRELATION_HEADER] ||
    headers['X-Correlation-Id'] ||
    headers['X-Correlation-ID'];

  if (value && value.trim().length > 0) {
    return value.trim();
  }

  return generateCorrelationId();
}

/**
 * Generates a new correlation ID (UUID v4).
 */
export function generateCorrelationId(): string {
  return uuidv4();
}
