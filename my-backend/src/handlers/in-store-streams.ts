// ============================================================================
// Lambda Handler — DynamoDB Streams: Post-Payment Automation
// ============================================================================
// Triggered by DynamoDB Stream on the main table.
// Filters for INSTORE_ORDER records transitioning to status=CONFIRMED.
//
// Fan-out actions (each in its own try/catch so one failure doesn't block):
//   1. Inventory reduction (deduct stock for each cart item)
//   2. Invoice PDF generation + S3 upload (async — does not block confirm)
//   3. Push notification to customer (FCM via SNS)
//   4. Analytics update (store sales dashboard)
// ============================================================================

import { DynamoDBStreamEvent, DynamoDBRecord } from 'aws-lambda';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import { AttributeValue } from '@aws-sdk/client-dynamodb';
import {
    Keys, getItem, updateItem, putItem, TABLE_NAME,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { InStoreOrder } from '../types/in-store.types';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import { config } from '../config/environment';

const sns = new SNSClient({ region: config.aws.region });
const sqs = new SQSClient({ region: config.aws.region });

const INVOICE_GEN_QUEUE_URL = config.awsQueue.invoiceGenQueueUrl || '';
const FCM_SNS_TOPIC_ARN = config.awsSns.fcmTopicArn || '';

// -- Main stream handler -------------------------------------------------------

export const handler = async (event: DynamoDBStreamEvent): Promise<void> => {
    for (const record of event.Records) {
        await processRecord(record);
    }
};

async function processRecord(record: DynamoDBRecord): Promise<void> {
    if (record.eventName !== 'MODIFY') return;

    const oldImage = record.dynamodb?.OldImage
        ? unmarshall(record.dynamodb.OldImage as Record<string, AttributeValue>)
        : null;
    const newImage = record.dynamodb?.NewImage
        ? unmarshall(record.dynamodb.NewImage as Record<string, AttributeValue>)
        : null;

    if (!newImage || !oldImage) return;

    // Only process INSTORE_ORDER records
    if (newImage.entityType !== 'INSTORE_ORDER') return;

    // Only process the PAYMENT_PENDING ? CONFIRMED transition
    if (oldImage.status !== 'PAYMENT_PENDING' || newImage.status !== 'CONFIRMED') return;

    const order = newImage as unknown as InStoreOrder;
    logger.info('InStore order confirmed — running post-payment automation', {
        orderId: order.orderId,
        tenantId: order.tenantId,
    });

    // Fan-out: all actions run in parallel, failures isolated
    await Promise.allSettled([
        reduceInventory(order),
        queueInvoiceGeneration(order),
        sendPushNotification(order),
        updateAnalytics(order),
    ]);
}

// -- 1. Inventory Reduction ----------------------------------------------------

async function reduceInventory(order: InStoreOrder): Promise<void> {
    const tenantPK = Keys.tenantPK(order.tenantId);

    for (const item of order.cartItems) {
        try {
            // Atomic decrement with floor at 0
            await updateItem(tenantPK, Keys.productSK(item.productId), {
                updateExpression: `SET stockQuantity = if_not_exists(stockQuantity, :zero) - :qty,
                    updatedAt = :now`,
                conditionExpression: 'attribute_exists(PK) AND stockQuantity >= :qty',
                expressionAttributeValues: {
                    ':qty': item.quantity,
                    ':zero': 0,
                    ':now': new Date().toISOString(),
                },
            });

            logger.info('Stock reduced', {
                productId: item.productId,
                qty: item.quantity,
                orderId: order.orderId,
            });
        } catch (err: unknown) {
            // ConditionalCheckFailed means stock went to 0 between checkout & confirm
            // Log for reconciliation — don't block order flow
            logger.error('Stock reduction failed', {
                productId: item.productId,
                productName: item.name,
                qty: item.quantity,
                orderId: order.orderId,
                error: (err as Error).message,
            });
        }
    }

    // Broadcast inventory update to store dashboard
    wsService.broadcastToBusiness(order.tenantId, WSEventName.INVENTORY_UPDATED, {
        orderId: order.orderId,
        updatedProducts: order.cartItems.map(i => i.productId),
    }).catch(() => { /* non-critical */ });
}

// -- 2. Invoice Generation (async via SQS) -------------------------------------

async function queueInvoiceGeneration(order: InStoreOrder): Promise<void> {
    if (!INVOICE_GEN_QUEUE_URL) {
        logger.warn('INVOICE_GEN_QUEUE_URL not set — skipping invoice generation');
        return;
    }

    await sqs.send(new SendMessageCommand({
        QueueUrl: INVOICE_GEN_QUEUE_URL,
        MessageBody: JSON.stringify({
            type: 'IN_STORE_INVOICE',
            orderId: order.orderId,
            tenantId: order.tenantId,
            customerId: order.customerId,
            cartItems: order.cartItems,
            totalCents: order.totalCents,
            gstBreakup: order.gstBreakup,
            createdAt: order.createdAt,
        }),
        MessageGroupId: order.tenantId,
        MessageDeduplicationId: `invoice-${order.orderId}`,
    }));

    logger.info('Invoice generation queued', { orderId: order.orderId });
}

// -- 3. FCM Push Notification (via SNS) ---------------------------------------

async function sendPushNotification(order: InStoreOrder): Promise<void> {
    if (!FCM_SNS_TOPIC_ARN) {
        logger.warn('FCM_SNS_TOPIC_ARN not set — skipping push notification');
        return;
    }

    // Fetch customer's FCM token from DynamoDB
    const tenantPK = Keys.tenantPK(order.tenantId);
    const customerRecord = await getItem<Record<string, any>>(
        tenantPK,
        Keys.userSK(order.customerId)
    );

    const fcmToken = customerRecord?.fcmToken;
    if (!fcmToken) {
        logger.info('No FCM token for customer — skipping push', { customerId: order.customerId });
        return;
    }

    const totalDisplay = `?${(order.totalCents / 100).toFixed(2)}`;

    const notification = {
        GCM: JSON.stringify({
            notification: {
                title: 'Payment Successful! ?',
                body: `Your in-store purchase of ${totalDisplay} is confirmed. Show QR at exit.`,
            },
            data: {
                type: 'IN_STORE_PAYMENT_SUCCESS',
                orderId: order.orderId,
                totalAmount: String(order.totalCents / 100),
            },
        }),
    };

    await sns.send(new PublishCommand({
        TopicArn: FCM_SNS_TOPIC_ARN,
        Message: JSON.stringify(notification),
        MessageStructure: 'json',
        MessageAttributes: {
            fcmToken: {
                DataType: 'String',
                StringValue: fcmToken,
            },
        },
    }));

    logger.info('Push notification sent', { customerId: order.customerId, orderId: order.orderId });
}

// -- 4. Analytics Update -------------------------------------------------------

async function updateAnalytics(order: InStoreOrder): Promise<void> {
    const tenantPK = Keys.tenantPK(order.tenantId);
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

    try {
        // Upsert daily analytics record
        await updateItem(
            tenantPK,
            `ANALYTICS#DAILY#${today}`,
            {
                updateExpression: `ADD inStoreSalesCount :one, inStoreSalesCents :total
                    SET updatedAt = :now, storeId = :sid`,
                expressionAttributeValues: {
                    ':one': 1,
                    ':total': order.totalCents,
                    ':now': new Date().toISOString(),
                    ':sid': order.storeId,
                },
            }
        );

        // Broadcast real-time dashboard update
        wsService.broadcastToBusiness(order.tenantId, WSEventName.DASHBOARD_UPDATED, {
            date: today,
            event: 'IN_STORE_SALE',
            totalCents: order.totalCents,
            orderId: order.orderId,
        }).catch(() => { /* non-critical */ });

        logger.info('Analytics updated', { orderId: order.orderId, date: today });
    } catch (err: unknown) {
        logger.error('Analytics update failed', {
            orderId: order.orderId,
            error: (err as Error).message,
        });
    }
}
