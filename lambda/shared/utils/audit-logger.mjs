// ============================================================================
// AUDIT LOGGER - Fire-and-forget audit logging
// ============================================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { createHash } from 'crypto';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const AUDIT_TABLE = process.env.AUDIT_TABLE_NAME || 'AuditLogs';

/**
 * Fire-and-forget audit logging (async, non-blocking)
 */
export function logAudit(context, action, status, details) {
  // Fire and forget - don't await
  _writeAuditLog(context, action, status, details).catch(err => {
    console.error('Audit log failed:', err);
  });
}

async function _writeAuditLog(context, action, status, details) {
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0];
  const timeStr = now.toISOString().split('T')[1].substring(0, 8);
  
  const entry = {
    PK: context.requestId,
    SK: `AUDIT#${now.toISOString()}`,
    tenantId: context.tenantId,
    userId: context.userId,
    action,
    resourceType: details.resourceType,
    resourceId: details.resourceId,
    payloadHash: details.payload ? hashPayload(details.payload) : 'no-payload',
    timestamp: now.toISOString(),
    status,
    durationMs: Date.now() - context.startTime,
    sourceIp: context.sourceIp,
    userAgent: context.userAgent,
    errorCode: details.errorCode,
    errorMessage: details.errorMessage,
    GSI1PK: `TENANT#${context.tenantId}`,
    GSI1SK: `DATE#${dateStr}#TIME#${timeStr}`,
    GSI2PK: `USER#${context.userId}`,
    GSI2SK: `DATE#${dateStr}#TIME#${timeStr}`,
  };
  
  await docClient.send(new PutCommand({
    TableName: AUDIT_TABLE,
    Item: entry,
  }));
}

function hashPayload(payload) {
  const str = typeof payload === 'string' ? payload : JSON.stringify(payload);
  return createHash('sha256').update(str).digest('hex').substring(0, 16);
}
