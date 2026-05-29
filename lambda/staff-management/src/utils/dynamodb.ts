// ============================================================================
// DYNAMODB UTILITIES
// ============================================================================

import { 
  DynamoDBClient, 
  DynamoDBClientConfig 
} from '@aws-sdk/client-dynamodb';
import { 
  DynamoDBDocumentClient, 
  GetCommand, 
  PutCommand, 
  UpdateCommand, 
  DeleteCommand, 
  QueryCommand,
  ScanCommand,
  GetCommandOutput,
  PutCommandOutput,
  UpdateCommandOutput,
  DeleteCommandOutput,
  QueryCommandOutput,
  ScanCommandOutput
} from '@aws-sdk/lib-dynamodb';

// Client configuration
const clientConfig: DynamoDBClientConfig = {
  region: process.env.AWS_REGION || 'ap-south-1'
};

// Create clients
const dynamoClient = new DynamoDBClient(clientConfig);
export const docClient = DynamoDBDocumentClient.from(dynamoClient, {
  marshallOptions: {
    removeUndefinedValues: true,
    convertEmptyValues: false
  }
});

// Retry configuration
const MAX_RETRIES = 3;
const RETRY_DELAY = 100; // ms

async function withRetry<T>(operation: () => Promise<T>, retries = MAX_RETRIES): Promise<T> {
  try {
    return await operation();
  } catch (error: any) {
    if (retries > 0 && error.name === 'ProvisionedThroughputExceededException') {
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY * (MAX_RETRIES - retries + 1)));
      return withRetry(operation, retries - 1);
    }
    throw error;
  }
}

// Typed helper functions
export async function getItem<T>(
  tableName: string, 
  key: Record<string, any>
): Promise<T | null> {
  const command = new GetCommand({
    TableName: tableName,
    Key: key
  });
  
  const result: GetCommandOutput = await withRetry(() => docClient.send(command));
  return (result.Item as T) || null;
}

export async function putItem<T>(
  tableName: string, 
  item: Record<string, any>
): Promise<T> {
  const command = new PutCommand({
    TableName: tableName,
    Item: item
  });
  
  await withRetry(() => docClient.send(command));
  return item as T;
}

export async function updateItem<T>(
  tableName: string,
  key: Record<string, any>,
  updates: Record<string, any>,
  options?: {
    conditionExpression?: string;
    expressionAttributeNames?: Record<string, string>;
  }
): Promise<T> {
  const updateExpressions: string[] = [];
  const expressionAttributeNames: Record<string, string> = options?.expressionAttributeNames || {};
  const expressionAttributeValues: Record<string, any> = {};

  Object.entries(updates).forEach(([k, v], i) => {
    const attrName = `#attr${i}`;
    const valName = `:val${i}`;
    expressionAttributeNames[attrName] = k;
    expressionAttributeValues[valName] = v;
    updateExpressions.push(`${attrName} = ${valName}`);
  });

  const command = new UpdateCommand({
    TableName: tableName,
    Key: key,
    UpdateExpression: `SET ${updateExpressions.join(', ')}`,
    ExpressionAttributeNames: expressionAttributeNames,
    ExpressionAttributeValues: expressionAttributeValues,
    ConditionExpression: options?.conditionExpression,
    ReturnValues: 'ALL_NEW'
  });

  const result: UpdateCommandOutput = await withRetry(() => docClient.send(command));
  return result.Attributes as T;
}

export async function deleteItem(
  tableName: string,
  key: Record<string, any>
): Promise<void> {
  const command = new DeleteCommand({
    TableName: tableName,
    Key: key
  });
  
  await withRetry(() => docClient.send(command));
}

export interface QueryOptions {
  indexName?: string;
  keyConditionExpression: string;
  filterExpression?: string;
  expressionAttributeNames?: Record<string, string>;
  expressionAttributeValues: Record<string, any>;
  limit?: number;
  scanIndexForward?: boolean;
  exclusiveStartKey?: Record<string, any>;
}

export async function queryItems<T>(
  tableName: string,
  options: QueryOptions
): Promise<{ items: T[]; lastKey?: Record<string, any> }> {
  const command = new QueryCommand({
    TableName: tableName,
    IndexName: options.indexName,
    KeyConditionExpression: options.keyConditionExpression,
    FilterExpression: options.filterExpression,
    ExpressionAttributeNames: options.expressionAttributeNames,
    ExpressionAttributeValues: options.expressionAttributeValues,
    Limit: options.limit,
    ScanIndexForward: options.scanIndexForward,
    ExclusiveStartKey: options.exclusiveStartKey
  });

  const result: QueryCommandOutput = await withRetry(() => docClient.send(command));
  
  return {
    items: (result.Items || []) as T[],
    lastKey: result.LastEvaluatedKey
  };
}

export async function scanItems<T>(
  tableName: string,
  options?: {
    filterExpression?: string;
    expressionAttributeNames?: Record<string, string>;
    expressionAttributeValues?: Record<string, any>;
    limit?: number;
  }
): Promise<{ items: T[]; lastKey?: Record<string, any> }> {
  const command = new ScanCommand({
    TableName: tableName,
    FilterExpression: options?.filterExpression,
    ExpressionAttributeNames: options?.expressionAttributeNames,
    ExpressionAttributeValues: options?.expressionAttributeValues,
    Limit: options?.limit
  });

  const result: ScanCommandOutput = await withRetry(() => docClient.send(command));
  
  return {
    items: (result.Items || []) as T[],
    lastKey: result.LastEvaluatedKey
  };
}
