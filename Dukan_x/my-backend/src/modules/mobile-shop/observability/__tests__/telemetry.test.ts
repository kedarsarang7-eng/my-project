/**
 * DynamoDB Telemetry Emitter Tests
 *
 * Verifies:
 * - emitDynamoDbTelemetry outputs valid JSON
 * - Output contains no secrets (no item content, no auth tokens)
 * - All expected fields are present in the output
 * - Default values are applied for optional params
 *
 * Requirements: 6.23, 13.6
 */

import { emitDynamoDbTelemetry } from '../telemetry';
import type { EmitDynamoDbTelemetryParams } from '../telemetry.types';

describe('emitDynamoDbTelemetry', () => {
  let consoleSpy: jest.SpyInstance;
  let lastOutput: string;

  beforeEach(() => {
    consoleSpy = jest.spyOn(console, 'log').mockImplementation((msg: string) => {
      lastOutput = msg;
    });
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  const fullParams: EmitDynamoDbTelemetryParams = {
    correlationId: 'corr-tel-001',
    tenantId: 'tenant-tel-001',
    operationId: 'op-tel-001',
    entityType: 'UNIT',
    accessPatternId: 'AP-01' as any,
    tableName: 'MobileShopTable',
    indexName: 'GSI1',
    operation: 'Query',
    consistency: 'strong',
    itemCount: 5,
    consumedCapacityUnits: 10.5,
    latencyMs: 42,
    conditionalResult: 'not_applicable',
    transactionResult: 'not_applicable',
    retryCount: 0,
    backoffMs: 0,
    throttlingReason: 'none',
    reconciliationOutcome: 'not_applicable',
    httpStatus: 200,
  };

  it('outputs valid JSON', () => {
    emitDynamoDbTelemetry(fullParams);

    expect(consoleSpy).toHaveBeenCalledTimes(1);
    const parsed = JSON.parse(lastOutput);
    expect(parsed).toBeDefined();
    expect(typeof parsed).toBe('object');
  });

  it('output contains no secrets (no item content, no auth tokens)', () => {
    emitDynamoDbTelemetry(fullParams);

    const parsed = JSON.parse(lastOutput);
    const outputStr = lastOutput.toLowerCase();

    // Must NOT contain any sensitive field names or patterns
    expect(outputStr).not.toContain('password');
    expect(outputStr).not.toContain('authorization');
    expect(outputStr).not.toContain('bearer');
    expect(outputStr).not.toContain('secret');
    expect(outputStr).not.toContain('token');
    expect(outputStr).not.toContain('imei');

    // Must NOT contain DynamoDB item fields (no record data)
    expect(parsed).not.toHaveProperty('Item');
    expect(parsed).not.toHaveProperty('Items');
    expect(parsed).not.toHaveProperty('requestBody');
    expect(parsed).not.toHaveProperty('responseBody');

    // All values should be primitive (string, number, boolean)
    for (const [_key, value] of Object.entries(parsed)) {
      expect(['string', 'number', 'boolean', 'undefined'].includes(typeof value)).toBe(true);
    }
  });

  it('all expected fields are present in the output', () => {
    emitDynamoDbTelemetry(fullParams);

    const parsed = JSON.parse(lastOutput);

    expect(parsed.eventType).toBe('DYNAMODB_OPERATION');
    expect(parsed.timestamp).toBeDefined();
    expect(parsed.correlationId).toBe('corr-tel-001');
    expect(parsed.tenantId).toBe('tenant-tel-001');
    expect(parsed.operationId).toBe('op-tel-001');
    expect(parsed.entityType).toBe('UNIT');
    expect(parsed.tableName).toBe('MobileShopTable');
    expect(parsed.indexName).toBe('GSI1');
    expect(parsed.operation).toBe('Query');
    expect(parsed.consistency).toBe('strong');
    expect(parsed.itemCount).toBe(5);
    expect(parsed.consumedCapacityUnits).toBe(10.5);
    expect(parsed.latencyMs).toBe(42);
    expect(parsed.conditionalResult).toBe('not_applicable');
    expect(parsed.transactionResult).toBe('not_applicable');
    expect(parsed.retryCount).toBe(0);
    expect(parsed.backoffMs).toBe(0);
    expect(parsed.throttlingReason).toBe('none');
    expect(parsed.reconciliationOutcome).toBe('not_applicable');
    expect(parsed.httpStatus).toBe(200);
  });

  it('default values are applied for optional params', () => {
    const minimalParams: EmitDynamoDbTelemetryParams = {
      correlationId: 'corr-min-001',
      tenantId: 'tenant-min-001',
      tableName: 'MobileShopTable',
      operation: 'Get',
      consistency: 'eventual',
      latencyMs: 15,
      httpStatus: 200,
    };

    emitDynamoDbTelemetry(minimalParams);

    const parsed = JSON.parse(lastOutput);

    // Defaults from the emitter
    expect(parsed.conditionalResult).toBe('not_applicable');
    expect(parsed.transactionResult).toBe('not_applicable');
    expect(parsed.retryCount).toBe(0);
    expect(parsed.backoffMs).toBe(0);
    expect(parsed.throttlingReason).toBe('none');
    expect(parsed.reconciliationOutcome).toBe('not_applicable');
    expect(parsed.eventType).toBe('DYNAMODB_OPERATION');
    expect(parsed.timestamp).toBeDefined();
  });
});
