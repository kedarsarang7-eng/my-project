/**
 * Unit tests for Lambda Handler Auditor
 *
 * Tests all detection patterns:
 * - Missing validation
 * - Missing correlation ID
 * - Missing logging
 * - Inadequate catch blocks
 * - Batch operation opportunities
 * - Repository bypass
 * - Sensitive data in logs
 */

import { auditHandler, LambdaAuditResult } from './lambda_auditor';

// ─── Test Helpers ───────────────────────────────────────────────────────────

function getViolationTypes(result: LambdaAuditResult): string[] {
  return result.violations.map((v) => v.type);
}

function hasViolation(result: LambdaAuditResult, type: string): boolean {
  return result.violations.some((v) => v.type === type);
}

// ─── Missing Validation Detection ───────────────────────────────────────────

describe('detectMissingValidation', () => {
  it('should flag handlers without Zod or schema validation', () => {
    const content = `
export const handler = async (event) => {
  const body = JSON.parse(event.body);
  return { statusCode: 200, body: JSON.stringify({ success: true }) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_validation')).toBe(true);
  });

  it('should not flag handlers using z.object', () => {
    const content = `
import { z } from 'zod';
const schema = z.object({ name: z.string(), age: z.number() });
export const handler = async (event) => {
  const body = schema.parse(JSON.parse(event.body));
  return { statusCode: 200, body: JSON.stringify(body) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_validation')).toBe(false);
  });

  it('should not flag handlers using Joi', () => {
    const content = `
import Joi from 'joi';
const schema = Joi.object({ name: Joi.string().required() });
export const handler = async (event) => {
  const { value } = schema.validate(JSON.parse(event.body));
  return { statusCode: 200, body: JSON.stringify(value) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_validation')).toBe(false);
  });

  it('should not flag handlers using .validate()', () => {
    const content = `
import { schema } from './schemas';
export const handler = async (event) => {
  const result = schema.validate(event.body);
  return { statusCode: 200, body: JSON.stringify(result) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_validation')).toBe(false);
  });
});

// ─── Missing Correlation ID Detection ───────────────────────────────────────

describe('detectMissingCorrelationId', () => {
  it('should flag error responses without correlationId', () => {
    const content = `
export const handler = async (event) => {
  try {
    return { statusCode: 200, body: '{}' };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ message: 'error' }) };
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_correlation_id')).toBe(true);
  });

  it('should not flag error responses with correlationId', () => {
    const content = `
export const handler = async (event) => {
  const correlationId = event.headers['x-correlation-id'];
  try {
    return { statusCode: 200, body: '{}' };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ correlationId, message: 'error' }) };
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_correlation_id')).toBe(false);
  });

  it('should not flag error responses with requestId', () => {
    const content = `
export const handler = async (event) => {
  const requestId = event.requestContext.requestId;
  try {
    return { statusCode: 200, body: '{}' };
  } catch (err) {
    return { statusCode: 400, body: JSON.stringify({ requestId, error: 'bad request' }) };
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_correlation_id')).toBe(false);
  });
});

// ─── Missing Logging Detection ──────────────────────────────────────────────

describe('detectMissingLogging', () => {
  it('should flag handlers without any logging', () => {
    const content = `
export const handler = async (event) => {
  const body = JSON.parse(event.body);
  return { statusCode: 200, body: JSON.stringify(body) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_logging')).toBe(true);
  });

  it('should not flag handlers with console.log', () => {
    const content = `
export const handler = async (event) => {
  console.log('Request received:', event.httpMethod, event.path);
  const body = JSON.parse(event.body);
  console.log('Response:', 200);
  return { statusCode: 200, body: JSON.stringify(body) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_logging')).toBe(false);
  });

  it('should not flag handlers with logger usage', () => {
    const content = `
import { logger } from '../utils/logger';
export const handler = async (event) => {
  logger.info('Processing request');
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'missing_logging')).toBe(false);
  });
});

// ─── Inadequate Catch Block Detection ───────────────────────────────────────

describe('detectInadequateCatchBlocks', () => {
  it('should flag empty catch blocks', () => {
    const content = `
export const handler = async (event) => {
  try {
    const data = await fetchData();
    return { statusCode: 200, body: JSON.stringify(data) };
  } catch (err) {
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'inadequate_catch')).toBe(true);
  });

  it('should flag catch blocks that only set a variable', () => {
    const content = `
export const handler = async (event) => {
  try {
    const data = await fetchData();
    return { statusCode: 200, body: JSON.stringify(data) };
  } catch (err) {
    const x = 'failed';
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'inadequate_catch')).toBe(true);
  });

  it('should not flag catch blocks that re-throw', () => {
    const content = `
export const handler = async (event) => {
  try {
    const data = await fetchData();
    return { statusCode: 200, body: JSON.stringify(data) };
  } catch (err) {
    throw err;
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'inadequate_catch')).toBe(false);
  });

  it('should not flag catch blocks that return error response', () => {
    const content = `
export const handler = async (event) => {
  try {
    const data = await fetchData();
    return { statusCode: 200, body: JSON.stringify(data) };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Internal error' }) };
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'inadequate_catch')).toBe(false);
  });

  it('should not flag catch blocks that log the error', () => {
    const content = `
export const handler = async (event) => {
  try {
    const data = await fetchData();
    return { statusCode: 200, body: JSON.stringify(data) };
  } catch (err) {
    console.error('Failed:', err);
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'inadequate_catch')).toBe(false);
  });
});

// ─── Batch Operation Opportunity Detection ──────────────────────────────────

describe('detectBatchOpportunities', () => {
  it('should flag 2+ DynamoDB reads on the same table', () => {
    const content = `
import { GetItemCommand } from '@aws-sdk/client-dynamodb';
export const handler = async (event) => {
  console.log('Processing');
  const item1 = await client.send(new GetItemCommand({ TableName: 'Users', Key: { id: '1' } }));
  const item2 = await client.send(new GetItemCommand({ TableName: 'Users', Key: { id: '2' } }));
  return { statusCode: 200, body: JSON.stringify({ item1, item2 }) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'batch_opportunity')).toBe(true);
    const batchViolation = result.violations.find((v) => v.type === 'batch_opportunity');
    expect(batchViolation?.severity).toBe('P2');
  });

  it('should flag 2+ DynamoDB writes on the same table', () => {
    const content = `
import { PutItemCommand } from '@aws-sdk/client-dynamodb';
export const handler = async (event) => {
  console.log('Processing');
  await client.send(new PutItemCommand({ TableName: 'Orders', Item: { id: '1' } }));
  await client.send(new PutItemCommand({ TableName: 'Orders', Item: { id: '2' } }));
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'batch_opportunity')).toBe(true);
  });

  it('should not flag operations on different tables', () => {
    const content = `
import { GetItemCommand } from '@aws-sdk/client-dynamodb';
export const handler = async (event) => {
  console.log('Processing');
  const user = await client.send(new GetItemCommand({ TableName: 'Users', Key: { id: '1' } }));
  const order = await client.send(new GetItemCommand({ TableName: 'Orders', Key: { id: '1' } }));
  return { statusCode: 200, body: JSON.stringify({ user, order }) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'batch_opportunity')).toBe(false);
  });

  it('should not flag a single operation on a table', () => {
    const content = `
import { GetItemCommand } from '@aws-sdk/client-dynamodb';
export const handler = async (event) => {
  console.log('Processing');
  const item = await client.send(new GetItemCommand({ TableName: 'Users', Key: { id: '1' } }));
  return { statusCode: 200, body: JSON.stringify(item) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'batch_opportunity')).toBe(false);
  });
});

// ─── Repository Bypass Detection ────────────────────────────────────────────

describe('detectRepositoryBypass', () => {
  it('should flag direct DynamoDBClient creation in a handler', () => {
    const content = `
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
export const handler = async (event) => {
  const client = new DynamoDBClient({});
  console.log('Querying directly');
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'repository_bypass')).toBe(true);
    const violation = result.violations.find((v) => v.type === 'repository_bypass');
    expect(violation?.severity).toBe('P1');
  });

  it('should flag docClient.send usage', () => {
    const content = `
export const handler = async (event) => {
  console.log('Processing');
  const result = await docClient.send(new QueryCommand(params));
  return { statusCode: 200, body: JSON.stringify(result) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'repository_bypass')).toBe(true);
  });

  it('should not flag repository files', () => {
    const content = `
/**
 * User Repository — handles all DynamoDB operations for users
 */
export class UserRepository {
  private client = new DynamoDBClient({});

  async getUser(id: string) {
    return this.client.send(new GetItemCommand({ TableName: 'Users', Key: { id } }));
  }
}
`;
    const result = auditHandler('user-repository.ts', content);
    expect(hasViolation(result, 'repository_bypass')).toBe(false);
  });

  it('should not flag import lines', () => {
    const content = `
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { userRepository } from '../repositories/user-repository';
export const handler = async (event) => {
  console.log('Processing');
  const user = await userRepository.getUser(event.pathParameters.id);
  return { statusCode: 200, body: JSON.stringify(user) };
};
`;
    const result = auditHandler('handler.ts', content);
    // The import line should be skipped; only actual instantiation in code matters
    expect(
      result.violations.filter((v) => v.type === 'repository_bypass').length
    ).toBe(0);
  });
});

// ─── Sensitive Data in Logs Detection ───────────────────────────────────────

describe('detectSensitiveDataInLogs', () => {
  it('should flag logging password values', () => {
    const content = `
export const handler = async (event) => {
  const body = JSON.parse(event.body);
  console.log('User login attempt:', body.password);
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'sensitive_data_logged')).toBe(true);
  });

  it('should flag logging token values', () => {
    const content = `
export const handler = async (event) => {
  const token = event.headers.Authorization;
  console.log('Auth token received:', token);
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'sensitive_data_logged')).toBe(true);
  });

  it('should flag logging email addresses', () => {
    const content = `
export const handler = async (event) => {
  const { email } = JSON.parse(event.body);
  console.log('Processing for email:', email);
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'sensitive_data_logged')).toBe(true);
  });

  it('should flag logging phone numbers', () => {
    const content = `
export const handler = async (event) => {
  const { phone } = JSON.parse(event.body);
  console.log('Sending OTP to phone:', phone);
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'sensitive_data_logged')).toBe(true);
  });

  it('should flag logging government IDs (aadhaar)', () => {
    const content = `
export const handler = async (event) => {
  const { aadhaar } = JSON.parse(event.body);
  console.log('Verifying aadhaar:', aadhaar);
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'sensitive_data_logged')).toBe(true);
  });

  it('should not flag non-log lines with sensitive words', () => {
    const content = `
export const handler = async (event) => {
  const { email, password } = JSON.parse(event.body);
  console.log('Processing login request');
  const result = await authenticate(email, password);
  return { statusCode: 200, body: JSON.stringify(result) };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'sensitive_data_logged')).toBe(false);
  });

  it('should not flag logging error descriptions mentioning field names', () => {
    const content = `
export const handler = async (event) => {
  console.log('Invalid email format provided');
  return { statusCode: 400, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    expect(hasViolation(result, 'sensitive_data_logged')).toBe(false);
  });
});

// ─── Severity Assignment ────────────────────────────────────────────────────

describe('severity assignment', () => {
  it('should assign P1 to missing_validation', () => {
    const content = `
export const handler = async (event) => {
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    const violation = result.violations.find((v) => v.type === 'missing_validation');
    expect(violation?.severity).toBe('P1');
  });

  it('should assign P1 to repository_bypass', () => {
    const content = `
export const handler = async (event) => {
  console.log('test');
  const result = await docClient.send(new GetCommand({}));
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    const violation = result.violations.find((v) => v.type === 'repository_bypass');
    expect(violation?.severity).toBe('P1');
  });

  it('should assign P2 to inadequate_catch', () => {
    const content = `
export const handler = async (event) => {
  try {
    await doSomething();
  } catch (err) {
    const x = 1;
  }
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    const violation = result.violations.find((v) => v.type === 'inadequate_catch');
    expect(violation?.severity).toBe('P2');
  });

  it('should assign P2 to batch_opportunity', () => {
    const content = `
import { PutCommand } from '@aws-sdk/lib-dynamodb';
export const handler = async (event) => {
  console.log('writing');
  await client.send(new PutCommand({ TableName: 'Items', Item: { id: '1' } }));
  await client.send(new PutCommand({ TableName: 'Items', Item: { id: '2' } }));
  return { statusCode: 200, body: '{}' };
};
`;
    const result = auditHandler('handler.ts', content);
    const violation = result.violations.find((v) => v.type === 'batch_opportunity');
    expect(violation?.severity).toBe('P2');
  });
});

// ─── Integration: Full Compliant Handler ────────────────────────────────────

describe('full compliant handler', () => {
  it('should produce zero violations for a fully compliant handler', () => {
    const content = `
import { z } from 'zod';
import { logger } from '../utils/logger';
import { userRepository } from '../repositories/user-repository';

const inputSchema = z.object({
  name: z.string().min(1),
  age: z.number().int().positive(),
});

export const handler = async (event) => {
  const correlationId = event.headers['x-correlation-id'] || crypto.randomUUID();
  logger.info('Request received', { correlationId, method: event.httpMethod, path: event.path });

  try {
    const body = inputSchema.parse(JSON.parse(event.body));
    const result = await userRepository.createUser(body);
    logger.info('Response', { correlationId, statusCode: 201 });
    return { statusCode: 201, body: JSON.stringify({ correlationId, data: result }) };
  } catch (err) {
    logger.error('Handler failed', { correlationId, error: err.message });
    return { statusCode: 500, body: JSON.stringify({ correlationId, message: 'Internal error' }) };
  }
};
`;
    const result = auditHandler('handler.ts', content);
    expect(result.violations).toHaveLength(0);
  });
});
