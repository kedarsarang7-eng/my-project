/**
 * customerStreamProcessor/index.mjs
 * DynamoDB Streams processor → pushes real-time events to customers via API Gateway WebSocket.
 *
 * Triggered by:
 *   - CustomerInvoicesTable stream  (NEW_AND_OLD_IMAGES)
 *   - CustomerLedgerTable stream    (NEW_AND_OLD_IMAGES)
 *   - CustomerPaymentsTable stream  (NEW_AND_OLD_IMAGES)
 *
 * For each relevant change, it:
 *   1. Identifies the affected customerId
 *   2. Looks up all active WebSocket connection IDs for that customer
 *   3. Posts the event payload to each connection via API Gateway Management API
 *   4. Prunes stale connections (410 GONE)
 *   5. Writes a notification record to CustomerNotificationsTable
 */

import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
  DeleteConnectionCommand,
} from '@aws-sdk/client-apigatewaymanagementapi';
import {
  DynamoDBClient,
  QueryCommand,
  DeleteItemCommand,
  PutItemCommand,
} from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { randomUUID } from 'crypto';

const CONNECTIONS_TABLE = process.env.WS_CONNECTIONS_TABLE;
const NOTIFICATIONS_TABLE = process.env.NOTIFICATIONS_TABLE;
const WS_ENDPOINT = process.env.WS_ENDPOINT; // e.g. https://abc.execute-api.region.amazonaws.com/prod

const ddb = new DynamoDBClient({});

export const handler = async (event) => {
  const results = await Promise.allSettled(
    event.Records.map(processRecord),
  );

  const failures = results.filter((r) => r.status === 'rejected');
  if (failures.length > 0) {
    console.error(`${failures.length} records failed:`, failures.map((f) => f.reason));
  }
};

async function processRecord(record) {
  if (record.eventName === 'REMOVE') return;

  const newImage = record.dynamodb?.NewImage
    ? unmarshall(record.dynamodb.NewImage)
    : null;
  const oldImage = record.dynamodb?.OldImage
    ? unmarshall(record.dynamodb.OldImage)
    : null;

  if (!newImage) return;

  const event = buildEvent(record.eventName, newImage, oldImage, record.eventSourceARN);
  if (!event) return;

  const { customerId, payload } = event;

  await Promise.all([
    pushToConnections(customerId, payload),
    writeNotification(customerId, payload),
  ]);
}

function buildEvent(eventName, newImage, oldImage, sourceArn) {
  // Determine source table from ARN
  const isInvoice = sourceArn?.includes('customer-invoices');
  const isLedger = sourceArn?.includes('customer-ledger');
  const isPayment = sourceArn?.includes('customer-payments');

  if (isInvoice) {
    const customerId = newImage.customerId;
    if (!customerId) return null;

    const isNew = eventName === 'INSERT';
    const statusChanged = oldImage && oldImage.status !== newImage.status;

    if (!isNew && !statusChanged) return null;

    return {
      customerId,
      payload: {
        type: isNew ? 'INVOICE_CREATED' : 'INVOICE_UPDATED',
        invoiceId: newImage.invoiceId,
        invoiceNumber: newImage.invoiceNumber,
        vendorName: newImage.vendorName,
        totalAmount: newImage.totalAmount,
        status: newImage.status,
        balanceDue: newImage.balanceDue,
        timestamp: new Date().toISOString(),
      },
    };
  }

  if (isPayment) {
    const customerId = newImage.customerId;
    if (!customerId || eventName !== 'INSERT') return null;

    return {
      customerId,
      payload: {
        type: 'PAYMENT_RECORDED',
        paymentId: newImage.paymentId,
        vendorName: newImage.vendorName,
        amount: newImage.amount,
        paymentMethod: newImage.paymentMethod,
        timestamp: new Date().toISOString(),
      },
    };
  }

  if (isLedger) {
    const customerId = newImage.customerId;
    if (!customerId || eventName !== 'INSERT') return null;

    return {
      customerId,
      payload: {
        type: newImage.entryType === 'credit' ? 'PAYMENT_APPLIED' : 'INVOICE_CHARGED',
        entryId: newImage.entryId,
        vendorName: newImage.vendorName,
        amount: newImage.amount,
        runningBalance: newImage.runningBalance,
        timestamp: new Date().toISOString(),
      },
    };
  }

  return null;
}

async function pushToConnections(customerId, payload) {
  // Query active WebSocket connections for this customer
  const result = await ddb.send(new QueryCommand({
    TableName: CONNECTIONS_TABLE,
    IndexName: 'GSI_Customer',
    KeyConditionExpression: 'customerId = :cid',
    ExpressionAttributeValues: marshall({ ':cid': customerId }),
  }));

  const connections = (result.Items || []).map(unmarshall);
  if (!connections.length) return;

  const apigw = new ApiGatewayManagementApiClient({ endpoint: WS_ENDPOINT });
  const message = JSON.stringify(payload);

  await Promise.allSettled(
    connections.map(async (conn) => {
      try {
        await apigw.send(new PostToConnectionCommand({
          ConnectionId: conn.connectionId,
          Data: Buffer.from(message),
        }));
      } catch (err) {
        if (err.$metadata?.httpStatusCode === 410) {
          // Connection stale — prune it
          await pruneConnection(conn.connectionId);
        } else {
          console.warn(`Failed to push to ${conn.connectionId}:`, err.message);
        }
      }
    }),
  );
}

async function pruneConnection(connectionId) {
  try {
    await ddb.send(new DeleteItemCommand({
      TableName: CONNECTIONS_TABLE,
      Key: marshall({ connectionId }),
    }));
  } catch (err) {
    console.warn('Failed to prune connection:', err.message);
  }
}

async function writeNotification(customerId, payload) {
  const notificationId = randomUUID();
  const now = new Date().toISOString();

  const { title, body, category } = buildNotificationText(payload);

  try {
    await ddb.send(new PutItemCommand({
      TableName: NOTIFICATIONS_TABLE,
      Item: marshall({
        PK: `NOTIF#${customerId}`,
        SK: `NOTIF#${notificationId}`,
        notificationId,
        customerId,
        vendorId: payload.vendorId || null,
        vendorName: payload.vendorName || null,
        category,
        title,
        body,
        payload,
        isRead: false,
        createdAt: now,
        // TTL: 90 days
        expiresAt: Math.floor(Date.now() / 1000) + 90 * 24 * 60 * 60,
      }),
    }));
  } catch (err) {
    console.warn('Failed to write notification:', err.message);
  }
}

function buildNotificationText(payload) {
  switch (payload.type) {
    case 'INVOICE_CREATED':
      return {
        category: 'invoice',
        title: 'New invoice from ' + (payload.vendorName || 'your shop'),
        body: `Invoice #${payload.invoiceNumber} for ₹${payload.totalAmount?.toFixed(2)} has been raised.`,
      };
    case 'INVOICE_UPDATED':
      return {
        category: 'invoice',
        title: 'Invoice updated',
        body: `Invoice #${payload.invoiceNumber} status changed to ${payload.status}.`,
      };
    case 'PAYMENT_RECORDED':
      return {
        category: 'payment',
        title: 'Payment recorded',
        body: `Payment of ₹${payload.amount?.toFixed(2)} via ${payload.paymentMethod} has been recorded.`,
      };
    case 'PAYMENT_APPLIED':
      return {
        category: 'payment',
        title: 'Payment applied',
        body: `₹${payload.amount?.toFixed(2)} credited. Balance: ₹${payload.runningBalance?.toFixed(2)}.`,
      };
    case 'INVOICE_CHARGED':
      return {
        category: 'due',
        title: 'New charge from ' + (payload.vendorName || 'your shop'),
        body: `₹${payload.amount?.toFixed(2)} charged. Balance: ₹${payload.runningBalance?.toFixed(2)}.`,
      };
    default:
      return {
        category: 'system',
        title: 'Account update',
        body: 'There is an update on your account.',
      };
  }
}
