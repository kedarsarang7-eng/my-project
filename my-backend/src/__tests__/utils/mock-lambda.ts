// Mock Lambda Utilities for Testing
// Provides helper functions to create mock API Gateway events and contexts

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, UserRole, BusinessType } from '../../types/tenant.types';

export interface MockEventOptions {
  body?: string;
  pathParameters?: Record<string, string>;
  queryStringParameters?: Record<string, string>;
  headers?: Record<string, string>;
}

export function mockEvent(
  options: MockEventOptions = {},
  auth?: AuthContext
): APIGatewayProxyEventV2 {
  return {
    version: '2.0',
    routeKey: 'ANY /mock',
    rawPath: '/mock',
    rawQueryString: '',
    headers: {
      'content-type': 'application/json',
      ...options.headers,
      ...(auth && { authorization: 'Bearer mock-token' }),
    },
    queryStringParameters: options.queryStringParameters || undefined,
    pathParameters: options.pathParameters || undefined,
    body: options.body || undefined,
    requestContext: {
      accountId: '123456789',
      apiId: 'mock-api',
      domainName: 'mock.execute-api.amazonaws.com',
      domainPrefix: 'mock',
      http: {
        method: 'POST',
        path: '/mock',
        protocol: 'HTTP/1.1',
        sourceIp: '127.0.0.1',
        userAgent: 'jest-test',
      },
      requestId: 'mock-request-id',
      routeKey: 'ANY /mock',
      stage: 'test',
      time: new Date().toISOString(),
      timeEpoch: Date.now(),
    } as any,
    isBase64Encoded: false,
  };
}

export const mockContext: Context = {
  callbackWaitsForEmptyEventLoop: false,
  functionName: 'test-function',
  functionVersion: '$LATEST',
  invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789:function:test-function',
  memoryLimitInMB: '256',
  awsRequestId: 'mock-request-id',
  logGroupName: '/aws/lambda/test-function',
  logStreamName: '2024/01/01/[$LATEST]mock-stream',
  getRemainingTimeInMillis: () => 30000,
  done: () => {},
  fail: () => {},
  succeed: () => {},
};

export function mockAuth(overrides: Partial<AuthContext> = {}): AuthContext {
  return {
    sub: 'test-user-123',
    email: 'test@example.com',
    tenantId: 'test-tenant-456',
    businessId: 'test-tenant-456',
    role: UserRole.OWNER,
    userRole: 'owner',
    businessType: BusinessType.JEWELLERY,
    licenseStatus: 'active',
    planStatus: 'active',
    ...overrides,
  };
}
