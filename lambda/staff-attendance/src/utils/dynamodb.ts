// ============================================================================
// DynamoDB Utilities - Staff Attendance System
// ============================================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, DeleteCommand, QueryCommand, ScanCommand, TransactWriteCommand } from '@aws-sdk/lib-dynamodb';
import type { TransactWriteCommandInput } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

interface RetryConfig {
  maxRetries: number;
  baseDelay: number;
}

const defaultRetryConfig: RetryConfig = {
  maxRetries: 3,
  baseDelay: 100,
};

async function withRetry<T>(operation: () => Promise<T>, config: RetryConfig = defaultRetryConfig): Promise<T> {
  let lastError: Error | undefined;
  
  for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;
      
      // Don't retry on certain errors
      if (error instanceof Error) {
        const errorName = error.name;
        if (errorName === 'ConditionalCheckFailedException' || 
            errorName === 'ValidationException' ||
            errorName === 'ResourceNotFoundException') {
          throw error;
        }
      }
      
      if (attempt < config.maxRetries) {
        const delay = config.baseDelay * Math.pow(2, attempt);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  
  throw lastError;
}

export async function getItem<T>(tableName: string, key: Record<string, string>): Promise<T | null> {
  return withRetry(async () => {
    const command = new GetCommand({
      TableName: tableName,
      Key: key,
    });
    
    const response = await docClient.send(command);
    return (response.Item as T) || null;
  });
}

export async function putItem<T>(tableName: string, item: T): Promise<void> {
  return withRetry(async () => {
    const command = new PutCommand({
      TableName: tableName,
      Item: item as Record<string, unknown>,
    });
    
    await docClient.send(command);
  });
}

export async function updateItem<T>(
  tableName: string,
  key: Record<string, string>,
  updates: Partial<T>
): Promise<void> {
  return withRetry(async () => {
    const updateExpression: string[] = [];
    const expressionAttributeNames: Record<string, string> = {};
    const expressionAttributeValues: Record<string, unknown> = {};
    
    let index = 0;
    for (const [field, value] of Object.entries(updates)) {
      const nameKey = `#field${index}`;
      const valueKey = `:value${index}`;
      
      updateExpression.push(`${nameKey} = ${valueKey}`);
      expressionAttributeNames[nameKey] = field;
      expressionAttributeValues[valueKey] = value;
      
      index++;
    }
    
    const command = new UpdateCommand({
      TableName: tableName,
      Key: key,
      UpdateExpression: `SET ${updateExpression.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
    });
    
    await docClient.send(command);
  });
}

export async function deleteItem(tableName: string, key: Record<string, string>): Promise<void> {
  return withRetry(async () => {
    const command = new DeleteCommand({
      TableName: tableName,
      Key: key,
    });
    
    await docClient.send(command);
  });
}

interface QueryOptions {
  indexName?: string;
  keyConditionExpression: string;
  expressionAttributeValues: Record<string, unknown>;
  expressionAttributeNames?: Record<string, string>;
  filterExpression?: string;
  limit?: number;
  scanIndexForward?: boolean;
  exclusiveStartKey?: Record<string, unknown>;
}

export async function queryItems<T>(tableName: string, options: QueryOptions): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  return withRetry(async () => {
    const command = new QueryCommand({
      TableName: tableName,
      IndexName: options.indexName,
      KeyConditionExpression: options.keyConditionExpression,
      ExpressionAttributeValues: options.expressionAttributeValues,
      ExpressionAttributeNames: options.expressionAttributeNames,
      FilterExpression: options.filterExpression,
      Limit: options.limit,
      ScanIndexForward: options.scanIndexForward,
      ExclusiveStartKey: options.exclusiveStartKey,
    });
    
    const response = await docClient.send(command);
    return {
      items: (response.Items as T[]) || [],
      lastKey: response.LastEvaluatedKey,
    };
  });
}

interface ScanOptions {
  filterExpression?: string;
  expressionAttributeValues?: Record<string, unknown>;
  limit?: number;
  exclusiveStartKey?: Record<string, unknown>;
}

export async function scanItems<T>(tableName: string, options: ScanOptions = {}): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  return withRetry(async () => {
    const command = new ScanCommand({
      TableName: tableName,
      FilterExpression: options.filterExpression,
      ExpressionAttributeValues: options.expressionAttributeValues,
      Limit: options.limit,
      ExclusiveStartKey: options.exclusiveStartKey,
    });
    
    const response = await docClient.send(command);
    return {
      items: (response.Items as T[]) || [],
      lastKey: response.LastEvaluatedKey,
    };
  });
}

// ============================================================================
// p28(a) Atomic multi-item write with conditional expressions
// ----------------------------------------------------------------------------
// Wraps DynamoDB TransactWriteItems. Up to 25 items per transaction.
// Callers should NOT wrap this in withRetry — TransactionCanceledException must
// be handled by the caller because individual cancellation reasons matter
// (e.g. ConditionalCheckFailed on the idempotency sentinel vs a real write error).
// ============================================================================
export async function transactWriteItems(
  input: TransactWriteCommandInput
): Promise<void> {
  const command = new TransactWriteCommand(input);
  await docClient.send(command);
}

// Atomic counter update for aggregations
export async function incrementCounters(
  tableName: string,
  key: Record<string, string>,
  counters: Record<string, number>
): Promise<void> {
  return withRetry(async () => {
    const setExpressions: string[] = [];
    const addExpressions: string[] = [];
    const expressionAttributeNames: Record<string, string> = {};
    const expressionAttributeValues: Record<string, unknown> = {};
    
    let index = 0;
    for (const [field, value] of Object.entries(counters)) {
      const nameKey = `#field${index}`;
      const valueKey = `:value${index}`;
      
      expressionAttributeNames[nameKey] = field;
      expressionAttributeValues[valueKey] = value;
      
      if (value >= 0) {
        addExpressions.push(`${nameKey} ${valueKey}`);
      } else {
        // For negative values, we need a different approach
        addExpressions.push(`${nameKey} ${valueKey}`);
      }
      
      index++;
    }
    
    const command = new UpdateCommand({
      TableName: tableName,
      Key: key,
      UpdateExpression: `SET updatedAt = :updatedAt ADD ${addExpressions.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: {
        ...expressionAttributeValues,
        ':updatedAt': new Date().toISOString(),
      },
    });
    
    await docClient.send(command);
  });
}
