import { DynamoDBClient } from '\''@aws-sdk/client-dynamodb'\'';
import { DynamoDBDocumentClient, UpdateCommand, GetCommand, QueryCommand } from '\''@aws-sdk/lib-dynamodb'\'';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from '\''aws-lambda'\'';
import * as crypto from '\''crypto'\'';
import { RazorpayWebhookSchema, validateSchema } from '\''../shared/schemas.mjs'\'';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const corsHeaders = {
  '\''Access-Control-Allow-Origin'\'': '\''*'\'',
  '\''Access-Control-Allow-Headers'\'': '\''Content-Type,Authorization,X-Tenant-Id'\'',
  '\''Access-Control-Allow-Methods'\'': '\''POST,OPTIONS'\'',
};

/**
 * Verify Razorpay webhook signature using HMAC SHA256
 * CRITICAL: Prevents fake payment webhooks
 */
const verifyRazorpayWebhook = (body: string, signature: string): boolean => {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
  if (!secret) {
    console.error('\''RAZORPAY_WEBHOOK_SECRET not configured'\'');
    return false;
  }

  const expectedSignature = crypto
    .createHmac('\''sha256'\'', secret)
    .update(body)
    .digest('\''hex'\'');

  try {
    return crypto.timingSafeEqual(
      Buffer.from(expectedSignature, '\''hex'\''),
      Buffer.from(signature, '\''hex'\''),
    );
  } catch {
    return false;
  }
};

/**
 * Get transaction by Razorpay order ID using GSI2
 * FIXED: Uses GSI query instead of Scan, returns stored date for correct SK
 */
async function getTransactionByOrderId(orderId: string): Promise<{
  transactionId: string;
  stationId: string;
  amount: number;
  status: string;
  staffId: string;
  ownerId: string;
  date: string;
  sk: string;
} | null> {
  const tableName = process.env.DYNAMODB_TABLE_TRANSACTIONS || '\''FuelPOS_Transactions'\'';

  try {
    const result = await docClient.send(
      new QueryCommand({
        TableName: tableName,
        IndexName: '\''GSI2'\'', // GSI3PK = RAZORPAY#ORDER#{orderId}
        KeyConditionExpression: '\''GSI3PK = :GSI3PK'\'',
        ExpressionAttributeValues: {
          '\'':GSI3PK'\'': `RAZORPAY#ORDER#${orderId}`,
        },
        Limit: 1,
      })
    );

    if (result.Items && result.Items.length > 0) {
      const item = result.Items[0];
      return {
        transactionId: item.transactionId || item.SK?.split('\''#'\'')[2],
        stationId: item.stationId,
        amount: item.amount,
        status: item.status,
        staffId: item.staffId,
        ownerId: item.ownerId,
        date: item.date, // CRITICAL: Use stored date, not current date
        sk: item.SK,     // CRITICAL: Use stored SK directly
      };
    }
    return null;
  } catch (error) {
    console.error('\''Error fetching transaction:'\'', error);
    return null;
  }
}
/**
 * Send real-time notification via WebSocket
 */
async function notifyPaymentSuccess(
  staffId: string,
  transactionId: string,
  amount: number
): Promise<void> {
  try {
    const connectionsTable = process.env.DYNAMODB_TABLE_WEBSOCKET_CONNECTIONS || '\''WebSocketConnections'\'';

    const result = await docClient.send(
      new QueryCommand({
        TableName: connectionsTable,
        IndexName: '\''GSI_StaffId'\'',
        KeyConditionExpression: '\''staffId = :staffId'\'',
        ExpressionAttributeValues: {
          '\'':staffId'\'': staffId,
        },
      })
    );

    if (!result.Items || result.Items.length === 0) {
      console.log(`No WebSocket connections for staff ${staffId}`);
      return;
    }

    const { ApiGatewayManagementApi } = await import('\''@aws-sdk/client-apigatewaymanagementapi'\'');
    const wsEndpoint = process.env.WEBSOCKET_ENDPOINT;
    if (!wsEndpoint) {
      console.error('\''WEBSOCKET_ENDPOINT not configured'\'');
      return;
    }

    const apiGwManagement = new ApiGatewayManagementApi({
      endpoint: wsEndpoint.replace('\''wss://'\'', '\''https://'\''),
    });

    for (const connection of result.Items) {
      try {
        await apiGwManagement.postToConnection({
          ConnectionId: connection.connectionId,
          Data: JSON.stringify({
            type: '\''PAYMENT_SUCCESS'\'',
            transactionId,
            amount,
            timestamp: new Date().toISOString(),
          }),
        });
      } catch (err: any) {
        if (err.name === '\''GoneException'\'') {
          const { DeleteCommand } = await import('\''@aws-sdk/lib-dynamodb'\'');
          await docClient.send(
            new DeleteCommand({
              TableName: connectionsTable,
              Key: { connectionId: connection.connectionId },
            })
          );
        }
      }
    }
  } catch (error) {
    console.error('\''Error sending WebSocket notification:'\'', error);
  }
}
/**
 * Update transaction status with idempotency check
 * FIXED: Uses stored SK directly to avoid midnight boundary bug
 */
async function updateTransactionStatus(
  transactionId: string,
  stationId: string,
  status: string,
  paymentId: string,
  razorpaySignature: string,
  storedSK: string // FIXED: Pass stored SK instead of reconstructing
): Promise<boolean> {
  const tableName = process.env.DYNAMODB_TABLE_TRANSACTIONS || '\''FuelPOS_Transactions'\'';

  try {
    await docClient.send(
      new UpdateCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${stationId}`,
          SK: storedSK, // FIXED: Use stored SK, not reconstructed date
        },
        UpdateExpression: '\''SET #status = :status, paymentId = :paymentId, razorpaySignature = :sig, updatedAt = :now, #ttl = :ttl REMOVE pendingTTL'\'',
        ConditionExpression: '\''#status = :pending OR attribute_not_exists(#status)'\'', // Idempotency
        ExpressionAttributeNames: {
          '\''#status'\'': '\''status'\'',
          '\''#ttl'\'': '\''ttl'\'',
        },
        ExpressionAttributeValues: {
          '\'':status'\'': status,
          '\'':pending'\'': '\''PENDING'\'',
          '\'':paymentId'\'': paymentId,
          '\'':sig'\'': razorpaySignature,
          '\'':now'\'': new Date().toISOString(),
          '\'':ttl'\'': Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60), // 90 days
        },
      })
    );
    return true;
  } catch (error: any) {
    if (error.name === '\''ConditionalCheckFailedException'\'') {
      console.log(`Transaction ${transactionId} already processed, skipping`);
      return false;
    }
    throw error;
  }
}
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === '\''OPTIONS'\'') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: ''',
    };
  }

  try {
    const body = event.body || '\''{}'\'';
    const signature = event.headers['\''x-razorpay-signature'\''] || event.headers['\''X-Razorpay-Signature'\''];

    if (!signature) {
      console.error('\''Missing Razorpay signature header'\'');
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: '\''Missing signature'\'' }),
      };
    }

    if (!verifyRazorpayWebhook(body, signature)) {
      console.error('\''Invalid Razorpay signature'\'');
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: '\''Invalid signature'\'' }),
      };
    }

    let payload;
    try {
      payload = JSON.parse(body);
    } catch {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: '\''Invalid JSON payload'\'' }),
      };
    }

    const validation = validateSchema(RazorpayWebhookSchema, payload);
    if (!validation.success) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: '\''Invalid webhook payload structure'\'',
          details: validation.errors,
        }),
      };
    }

    const eventType = payload.event;
    const paymentEntity = payload.payload?.payment?.entity;

    if (!paymentEntity) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: '\''Missing payment entity in payload'\'' }),
      };
    }

    const orderId = paymentEntity.order_id;
    const paymentId = paymentEntity.id;
    const paymentAmount = paymentEntity.amount;

    const transaction = await getTransactionByOrderId(orderId);
    if (!transaction) {
      console.error(`Transaction not found for order ${orderId}`);
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: '\''Transaction not found'\'' }),
      };
    }

    const expectedAmountPaise = Math.round(transaction.amount * 100);
    if (paymentAmount !== expectedAmountPaise) {
      console.error('\''AMOUNT_MISMATCH'\'', {
        orderId,
        transactionId: transaction.transactionId,
        expected: expectedAmountPaise,
        received: paymentAmount,
      });
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: '\''Amount mismatch - possible tampering'\'' }),
      };
    }

    let newStatus: string;
    switch (eventType) {
      case '\''payment.captured'\'':
        newStatus = '\''PAID'\'';
        break;
      case '\''payment.failed'\'':
        newStatus = '\''FAILED'\'';
        break;
      default:
        console.log(`Unhandled event type: ${eventType}`);
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: JSON.stringify({ message: '\''Event ignored'\'' }),
        };
    }

    // FIXED: Pass stored SK to avoid midnight boundary bug
    const updated = await updateTransactionStatus(
      transaction.transactionId,
      transaction.stationId,
      newStatus,
      paymentId,
      signature,
      transaction.sk // FIXED: Use stored SK
    );

    if (updated && newStatus === '\''PAID'\'') {
      await notifyPaymentSuccess(transaction.staffId, transaction.transactionId, transaction.amount);
    }

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: `Payment ${newStatus.toLowerCase()}`,
        transactionId: transaction.transactionId,
      }),
    };
  } catch (error) {
    console.error('\''Webhook processing error:'\'', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: '\''Internal server error'\'',
        message: error instanceof Error ? error.message : '\''Unknown error'\'',
      }),
    };
  }
};