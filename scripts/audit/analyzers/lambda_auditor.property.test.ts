/**
 * Property Test: Handler Compliance Detection
 *
 * Feature: full-stack-audit-remediation, Property 22: Handler Compliance Detection
 *
 * Validates: Requirements 11.1, 11.3, 11.4, 11.5
 *
 * For any Lambda handler file, the audit SHALL correctly identify:
 * - Missing input validation (no Zod/schema library usage)
 * - Missing correlation IDs in error responses
 * - Incorrect HTTP status codes (not checked here — requires semantic analysis)
 * - Missing request/response logging
 * - Catch blocks that neither re-throw nor log nor return error responses
 * - Direct DynamoDB client usage bypassing the repository layer
 * - Sensitive data appearing in log statements
 */

import * as fc from 'fast-check';
import { auditHandler, LambdaViolation } from './lambda_auditor';

// ─── Generators ──────────────────────────────────────────────────────────────

/** Generates a valid handler export line */
const handlerExportArb = fc.constantFrom(
  'export const handler = async (event) => {',
  'export async function handler(event) {',
  'export const processRequest = async (event) => {',
  'module.exports.handler = async (event) => {'
);

/** Generates a Zod validation snippet */
const zodValidationArb = fc.constantFrom(
  "import { z } from 'zod';\nconst schema = z.object({ name: z.string() });\nschema.parse(event.body);",
  "import { z } from 'zod';\nconst input = z.safeParse(event.body);",
  "const Joi = require('joi');\nconst schema = Joi.object({ id: Joi.string() });\nschema.validate(input);"
);

/** Generates logging snippets */
const loggingSnippetArb = fc.constantFrom(
  "console.log('Processing request', { method: event.httpMethod });",
  "logger.info('Request received', { path: event.path });",
  "log.debug('Handler invoked');"
);

/** Generates correlation ID snippets */
const correlationIdSnippetArb = fc.constantFrom(
  "const correlationId = event.headers['x-correlation-id'] || uuid();",
  "const requestId = event.requestContext.requestId;",
  "body: JSON.stringify({ error: message, correlationId })"
);

/** Generates error response lines */
const errorResponseArb = fc.constantFrom(
  "return { statusCode: 400, body: JSON.stringify({ error: 'Bad request' }) };",
  "return { statusCode: 500, body: JSON.stringify({ error: 'Internal error' }) };",
  "return { statusCode: 403, body: JSON.stringify({ error: 'Forbidden' }) };"
);

/** Generates DynamoDB direct client usage */
const directDynamoDbArb = fc.constantFrom(
  "const client = new DynamoDBClient({});",
  "const docClient = DynamoDBDocumentClient.from(client);",
  "await docClient.send(new GetCommand({ TableName: 'users', Key: { id } }));",
  "await client.send(new PutItemCommand({ TableName: 'orders', Item: data }));"
);

/** Generates repository import usage (safe pattern) */
const repositoryUsageArb = fc.constantFrom(
  "import { UserRepository } from '../repositories/user-repository';",
  "const result = await repository.getById(id);",
  "import { OrderRepo } from '../repo/order-repo';"
);

/** Generates sensitive data in log statements */
const sensitiveLogArb = fc.constantFrom(
  "console.log('User data:', { email: user.email, password: user.password });",
  "logger.info('Auth token:', { token: authToken });",
  "console.log('Phone number:', phoneNumber);",
  "log.info('SSN:', user.ssn);"
);

/** Generates safe log statements (no sensitive data) */
const safeLogArb = fc.constantFrom(
  "console.log('Request processed', { statusCode: 200, duration: elapsed });",
  "logger.info('Item created', { itemId: result.id });",
  "console.log('Batch complete', { count: items.length });"
);

/** Generates adequate catch blocks */
const adequateCatchArb = fc.constantFrom(
  "try {\n  await doWork();\n} catch (err) {\n  console.error('Failed:', err);\n  return { statusCode: 500, body: 'error' };\n}",
  "try {\n  await process();\n} catch (err) {\n  throw err;\n}",
  "try {\n  await save();\n} catch (err) {\n  logger.error('Save failed', err);\n}"
);

/** Generates inadequate catch blocks (empty or only comment) */
const inadequateCatchArb = fc.constantFrom(
  "try {\n  await doWork();\n} catch (err) {\n  // swallow\n}",
  "try {\n  await process();\n} catch (err) {\n}",
  "try {\n  await save();\n} catch (err) {\n  const x = 1;\n}"
);

// ─── Property Tests ──────────────────────────────────────────────────────────

describe('Feature: full-stack-audit-remediation, Property 22: Handler Compliance Detection', () => {
  describe('Missing validation detection', () => {
    it('should flag handlers without Zod/schema validation', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          loggingSnippetArb,
          correlationIdSnippetArb,
          errorResponseArb,
          (handlerLine, logging, correlationId, errorResp) => {
            const content = [
              handlerLine,
              '  ' + logging,
              '  ' + correlationId,
              '  ' + errorResp,
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const validationViolations = result.violations.filter(
              (v) => v.type === 'missing_validation'
            );

            // Without any validation library, should flag missing_validation
            expect(validationViolations.length).toBeGreaterThanOrEqual(1);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should NOT flag handlers with Zod/schema validation', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          loggingSnippetArb,
          (handlerLine, validation, logging) => {
            const content = [
              validation,
              handlerLine,
              '  ' + logging,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const validationViolations = result.violations.filter(
              (v) => v.type === 'missing_validation'
            );

            expect(validationViolations).toHaveLength(0);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Missing correlation ID detection', () => {
    it('should flag error responses without correlation ID', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          loggingSnippetArb,
          errorResponseArb,
          (handlerLine, validation, logging, errorResp) => {
            const content = [
              validation,
              handlerLine,
              '  ' + logging,
              '  ' + errorResp,
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const correlationViolations = result.violations.filter(
              (v) => v.type === 'missing_correlation_id'
            );

            // Has error response but no correlation ID → should flag
            expect(correlationViolations.length).toBeGreaterThanOrEqual(1);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should NOT flag when correlation ID is present', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          correlationIdSnippetArb,
          (handlerLine, validation, correlationId) => {
            const content = [
              validation,
              handlerLine,
              '  ' + correlationId,
              '  return { statusCode: 400, body: JSON.stringify({ error: "bad", correlationId }) };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const correlationViolations = result.violations.filter(
              (v) => v.type === 'missing_correlation_id'
            );

            expect(correlationViolations).toHaveLength(0);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Missing logging detection', () => {
    it('should flag handlers without any logging', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          correlationIdSnippetArb,
          (handlerLine, validation, correlationId) => {
            // Build content with NO logging patterns
            const content = [
              validation,
              handlerLine,
              '  const data = JSON.parse(event.body);',
              '  ' + correlationId,
              '  return { statusCode: 200, body: JSON.stringify({ ok: true, correlationId }) };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const loggingViolations = result.violations.filter(
              (v) => v.type === 'missing_logging'
            );

            expect(loggingViolations.length).toBeGreaterThanOrEqual(1);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should NOT flag handlers with logging present', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          loggingSnippetArb,
          correlationIdSnippetArb,
          (handlerLine, validation, logging, correlationId) => {
            const content = [
              validation,
              handlerLine,
              '  ' + logging,
              '  ' + correlationId,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const loggingViolations = result.violations.filter(
              (v) => v.type === 'missing_logging'
            );

            expect(loggingViolations).toHaveLength(0);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Inadequate catch block detection', () => {
    it('should flag catch blocks that do nothing useful', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          loggingSnippetArb,
          inadequateCatchArb,
          (handlerLine, validation, logging, catchBlock) => {
            const content = [
              validation,
              handlerLine,
              '  ' + logging,
              '  ' + catchBlock,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const catchViolations = result.violations.filter(
              (v) => v.type === 'inadequate_catch'
            );

            expect(catchViolations.length).toBeGreaterThanOrEqual(1);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should NOT flag adequate catch blocks', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          loggingSnippetArb,
          adequateCatchArb,
          (handlerLine, validation, logging, catchBlock) => {
            const content = [
              validation,
              handlerLine,
              '  ' + logging,
              '  ' + catchBlock,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const catchViolations = result.violations.filter(
              (v) => v.type === 'inadequate_catch'
            );

            expect(catchViolations).toHaveLength(0);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Repository bypass detection', () => {
    it('should flag direct DynamoDB client usage in non-repository files', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          loggingSnippetArb,
          directDynamoDbArb,
          correlationIdSnippetArb,
          (handlerLine, validation, logging, dynamoDb, correlationId) => {
            const content = [
              validation,
              handlerLine,
              '  ' + logging,
              '  ' + correlationId,
              '  ' + dynamoDb,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const bypassViolations = result.violations.filter(
              (v) => v.type === 'repository_bypass'
            );

            expect(bypassViolations.length).toBeGreaterThanOrEqual(1);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should NOT flag files using the repository pattern', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          loggingSnippetArb,
          repositoryUsageArb,
          correlationIdSnippetArb,
          (handlerLine, validation, logging, repoUsage, correlationId) => {
            const content = [
              validation,
              repoUsage,
              handlerLine,
              '  ' + logging,
              '  ' + correlationId,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const bypassViolations = result.violations.filter(
              (v) => v.type === 'repository_bypass'
            );

            expect(bypassViolations).toHaveLength(0);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Sensitive data in logs detection', () => {
    it('should flag log statements containing sensitive data', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          sensitiveLogArb,
          correlationIdSnippetArb,
          (handlerLine, validation, sensitiveLog, correlationId) => {
            const content = [
              validation,
              handlerLine,
              '  ' + correlationId,
              '  ' + sensitiveLog,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const sensitiveViolations = result.violations.filter(
              (v) => v.type === 'sensitive_data_logged'
            );

            expect(sensitiveViolations.length).toBeGreaterThanOrEqual(1);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should NOT flag safe log statements', () => {
      fc.assert(
        fc.property(
          handlerExportArb,
          zodValidationArb,
          safeLogArb,
          correlationIdSnippetArb,
          (handlerLine, validation, safeLog, correlationId) => {
            const content = [
              validation,
              handlerLine,
              '  ' + correlationId,
              '  ' + safeLog,
              '  return { statusCode: 200, body: "ok" };',
              '}',
            ].join('\n');

            const result = auditHandler('handler.ts', content);
            const sensitiveViolations = result.violations.filter(
              (v) => v.type === 'sensitive_data_logged'
            );

            expect(sensitiveViolations).toHaveLength(0);
          }
        ),
        { numRuns: 100 }
      );
    });
  });
});
