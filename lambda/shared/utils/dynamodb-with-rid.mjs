// ============================================================================
// DYNAMODB WITH RID - Auto-inject requestId into all writes
// ============================================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, UpdateCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { info, error } from './logger.mjs';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
});

/**
 * Wrap DynamoDB put operation with auto RID injection
 */
export async function putWithRID(tableName, item, context, options = {}) {
  const itemWithRID = {
    ...item,
    requestId: context.requestId,
    tenantId: context.tenantId,
    // Add GSI fields for trace lookup if enabled
    ...(options.gsiRequestId && {
      GSI2PK: `REQUEST#${context.requestId}`,
      GSI2SK: item.PK || item.SK,
    }),
  };
  
  try {
    await docClient.send(new PutCommand({
      TableName: tableName,
      Item: itemWithRID,
    }));
    
    info('DynamoDB Put', {
      table: tableName,
      pk: item.PK,
      sk: item.SK,
    });
  } catch (err) {
    error('DynamoDB Put failed', err, {
      table: tableName,
      pk: item.PK,
      sk: item.SK,
    });
    throw err;
  }
}

/**
 * Wrap DynamoDB update operation with RID tracking
 */
export async function updateWithRID(tableName, key, updates, context) {
  const updateExpression = buildUpdateExpression(updates);
  
  try {
    await docClient.send(new UpdateCommand({
      TableName: tableName,
      Key: key,
      UpdateExpression: updateExpression.expression,
      ExpressionAttributeNames: updateExpression.names,
      ExpressionAttributeValues: {
        ...updateExpression.values,
        ':requestId': context.requestId,
        ':updatedAt': new Date().toISOString(),
      },
    }));
    
    info('DynamoDB Update', { table: tableName, key });
  } catch (err) {
    error('DynamoDB Update failed', err, { table: tableName, key });
    throw err;
  }
}

/**
 * Build update expression from object
 */
function buildUpdateExpression(updates) {
  const names = {};
  const values = {};
  const sets = [];
  
  let i = 0;
  for (const [key, value] of Object.entries(updates)) {
    const attrName = `#attr${i}`;
    const attrValue = `:val${i}`;
    
    names[attrName] = key;
    values[attrValue] = value;
    sets.push(`${attrName} = ${attrValue}`);
    
    i++;
  }
  
  // Always add requestId and updatedAt
  sets.push('#requestId = :requestId');
  sets.push('#updatedAt = :updatedAt');
  names['#requestId'] = 'requestId';
  names['#updatedAt'] = 'updatedAt';
  
  return {
    expression: `SET ${sets.join(', ')}`,
    names,
    values,
  };
}

/**
 * Query by Request ID using GSI
 */
export async function queryByRequestId(tableName, requestId) {
  try {
    const result = await docClient.send(new QueryCommand({
      TableName: tableName,
      IndexName: 'RequestIdIndex',
      KeyConditionExpression: 'GSI2PK = :rid',
      ExpressionAttributeValues: {
        ':rid': `REQUEST#${requestId}`,
      },
    }));
    
    return result.Items || [];
  } catch (err) {
    error('Query by RequestId failed', err, { table: tableName, requestId });
    return [];
  }
}
