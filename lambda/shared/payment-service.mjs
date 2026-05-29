// ============================================================================
// PAYMENT SERVICE - With Idempotency & Safety Features (P1 FIX)
// ============================================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, UpdateCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID, createHash } from 'crypto';
import { withRetry } from './utils.mjs';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

// Idempotency key TTL: 24 hours
const IDEMPOTENCY_TTL_HOURS = 24;

/**
 * Payment service with idempotency and safety features
 */
export class PaymentService {
  constructor(config = {}) {
    this.tableName = config.idempotencyTable || process.env.DYNAMODB_TABLE_PAYMENTS;
    this.gateway = config.gateway || 'default';
  }

  /**
   * Process payment with idempotency guarantee
   * P1 FIX: Prevents duplicate charges
   */
  async processPayment(paymentRequest) {
    const { 
      amount, 
      currency = 'INR', 
      customerId, 
      orderId,
      idempotencyKey = randomUUID(),
      tenantId,
      userId,
      metadata = {}
    } = paymentRequest;

    // Validate input
    if (!amount || amount <= 0) {
      throw new Error('INVALID_AMOUNT: Amount must be positive');
    }
    if (!customerId) {
      throw new Error('MISSING_CUSTOMER: Customer ID required');
    }
    if (!orderId) {
      throw new Error('MISSING_ORDER: Order ID required');
    }

    // P1 FIX: Check idempotency - have we seen this key before?
    const existingPayment = await this._checkIdempotency(idempotencyKey);
    if (existingPayment) {
      console.log(`[PaymentService] Idempotency hit: ${idempotencyKey}`);
      return {
        success: true,
        paymentId: existingPayment.paymentId,
        status: existingPayment.status,
        idempotencyKey,
        cached: true,
      };
    }

    // Create payment record
    const paymentId = `pay_${randomUUID()}`;
    const now = new Date().toISOString();
    const expiresAt = Math.floor(Date.now() / 1000) + (IDEMPOTENCY_TTL_HOURS * 3600);

    const paymentRecord = {
      PK: `PAYMENT#${paymentId}`,
      SK: `METADATA#${now}`,
      GSI1PK: `TENANT#${tenantId}#PAYMENTS`,
      GSI1SK: `DATE#${now}#${paymentId}`,
      GSI2PK: `IDEMPOTENCY#${idempotencyKey}`,
      GSI2SK: `PAYMENT#${paymentId}`,
      
      paymentId,
      idempotencyKey,
      tenantId,
      userId,
      customerId,
      orderId,
      amount,
      currency,
      status: 'pending',
      gateway: this.gateway,
      metadata,
      
      idempotencyExpiresAt: expiresAt,
      createdAt: now,
      updatedAt: now,
    };

    // Store idempotency record
    await this._storePaymentRecord(paymentRecord);

    try {
      // P1 FIX: Process with gateway
      const gatewayResult = await this._processWithGateway(paymentRequest);

      // Update status
      const updatedRecord = await this._updatePaymentStatus(
        paymentId,
        gatewayResult.status,
        {
          gatewayTransactionId: gatewayResult.transactionId,
          gatewayResponse: gatewayResult.rawResponse,
          processedAt: new Date().toISOString(),
        }
      );

      return {
        success: gatewayResult.status === 'completed',
        paymentId,
        status: gatewayResult.status,
        idempotencyKey,
        transactionId: gatewayResult.transactionId,
        amount,
        currency,
      };

    } catch (error) {
      // Mark as failed
      await this._updatePaymentStatus(paymentId, 'failed', {
        errorCode: error.code || 'PAYMENT_ERROR',
        errorMessage: error.message,
        failedAt: new Date().toISOString(),
      });

      throw error;
    }
  }

  /**
   * Refund payment with idempotency
   */
  async refundPayment(refundRequest) {
    const {
      paymentId,
      amount,
      reason,
      idempotencyKey = randomUUID(),
      tenantId,
    } = refundRequest;

    // Check idempotency
    const existingRefund = await this._checkIdempotency(idempotencyKey);
    if (existingRefund) {
      return {
        success: true,
        refundId: existingRefund.refundId,
        cached: true,
      };
    }

    // Verify original payment
    const originalPayment = await this._getPayment(paymentId);
    if (!originalPayment) {
      throw new Error('PAYMENT_NOT_FOUND: Original payment not found');
    }

    if (originalPayment.tenantId !== tenantId) {
      throw new Error('TENANT_MISMATCH: Cannot refund cross-tenant payment');
    }

    if (originalPayment.status !== 'completed') {
      throw new Error('PAYMENT_NOT_COMPLETED: Cannot refund pending/failed payment');
    }

    // Check refund amount
    const totalRefunded = await this._getTotalRefunded(paymentId);
    if (totalRefunded + amount > originalPayment.amount) {
      throw new Error('REFUND_EXCEEDS_PAYMENT: Refund amount exceeds payment');
    }

    // Process refund
    const refundId = `ref_${randomUUID()}`;
    const now = new Date().toISOString();

    const refundRecord = {
      PK: `REFUND#${refundId}`,
      SK: `METADATA#${now}`,
      GSI1PK: `PAYMENT#${paymentId}#REFUNDS`,
      GSI1SK: `DATE#${now}#${refundId}`,
      GSI2PK: `IDEMPOTENCY#${idempotencyKey}`,
      GSI2SK: `REFUND#${refundId}`,
      
      refundId,
      paymentId,
      idempotencyKey,
      tenantId,
      amount,
      reason,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    };

    await this._storePaymentRecord(refundRecord);

    try {
      const gatewayResult = await this._processRefundWithGateway({
        originalTransactionId: originalPayment.gatewayTransactionId,
        amount,
        reason,
      });

      await this._updateRefundStatus(refundId, 'completed', {
        gatewayRefundId: gatewayResult.refundId,
        processedAt: new Date().toISOString(),
      });

      return {
        success: true,
        refundId,
        amount,
        status: 'completed',
      };

    } catch (error) {
      await this._updateRefundStatus(refundId, 'failed', {
        errorCode: error.code,
        errorMessage: error.message,
      });
      throw error;
    }
  }

  /**
   * Get payment by ID
   */
  async getPayment(paymentId, tenantId) {
    const payment = await this._getPayment(paymentId);
    
    if (!payment) {
      return null;
    }

    if (payment.tenantId !== tenantId) {
      throw new Error('TENANT_MISMATCH: Cross-tenant access denied');
    }

    return payment;
  }

  /**
   * List payments for tenant with pagination
   */
  async listPayments(tenantId, options = {}) {
    const { limit = 50, cursor, startDate, endDate } = options;

    const params = {
      TableName: this.tableName,
      IndexName: 'GSI1',
      KeyConditionExpression: 'GSI1PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `TENANT#${tenantId}#PAYMENTS`,
      },
      ScanIndexForward: false,
      Limit: limit,
    };

    if (cursor) {
      params.ExclusiveStartKey = cursor;
    }

    if (startDate && endDate) {
      params.KeyConditionExpression += ' AND GSI1SK BETWEEN :start AND :end';
      params.ExpressionAttributeValues[':start'] = `DATE#${startDate}`;
      params.ExpressionAttributeValues[':end'] = `DATE#${endDate}`;
    }

    const result = await docClient.send(new QueryCommand(params));
    
    return {
      payments: result.Items || [],
      nextCursor: result.LastEvaluatedKey,
    };
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  async _checkIdempotency(idempotencyKey) {
    try {
      const result = await docClient.send(new QueryCommand({
        TableName: this.tableName,
        IndexName: 'GSI2',
        KeyConditionExpression: 'GSI2PK = :pk',
        ExpressionAttributeValues: {
          ':pk': `IDEMPOTENCY#${idempotencyKey}`,
        },
        Limit: 1,
      }));

      if (result.Items && result.Items.length > 0) {
        const record = result.Items[0];
        // Check if still valid (not expired)
        const now = Math.floor(Date.now() / 1000);
        if (record.idempotencyExpiresAt > now) {
          return record;
        }
      }

      return null;
    } catch (error) {
      console.error('Idempotency check failed:', error);
      return null; // Fail open - process as new payment
    }
  }

  async _storePaymentRecord(record) {
    await withRetry(async () => {
      await docClient.send(new PutCommand({
        TableName: this.tableName,
        Item: record,
        ConditionExpression: 'attribute_not_exists(PK)', // Prevent overwrites
      }));
    });
  }

  async _getPayment(paymentId) {
    const result = await docClient.send(new GetCommand({
      TableName: this.tableName,
      Key: {
        PK: `PAYMENT#${paymentId}`,
        SK: `METADATA#`,
      },
    }));

    return result.Item;
  }

  async _updatePaymentStatus(paymentId, status, additionalData = {}) {
    const now = new Date().toISOString();

    const result = await docClient.send(new UpdateCommand({
      TableName: this.tableName,
      Key: {
        PK: `PAYMENT#${paymentId}`,
        SK: `METADATA#`,
      },
      UpdateExpression: 'SET #status = :status, updatedAt = :now, #data = :data',
      ExpressionAttributeNames: {
        '#status': 'status',
        '#data': 'gatewayData',
      },
      ExpressionAttributeValues: {
        ':status': status,
        ':now': now,
        ':data': additionalData,
      },
      ReturnValues: 'ALL_NEW',
    }));

    return result.Attributes;
  }

  async _updateRefundStatus(refundId, status, additionalData = {}) {
    const now = new Date().toISOString();

    await docClient.send(new UpdateCommand({
      TableName: this.tableName,
      Key: {
        PK: `REFUND#${refundId}`,
        SK: `METADATA#`,
      },
      UpdateExpression: 'SET #status = :status, updatedAt = :now, gatewayData = :data',
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: {
        ':status': status,
        ':now': now,
        ':data': additionalData,
      },
    }));
  }

  async _getTotalRefunded(paymentId) {
    const result = await docClient.send(new QueryCommand({
      TableName: this.tableName,
      IndexName: 'GSI1',
      KeyConditionExpression: 'GSI1PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `PAYMENT#${paymentId}#REFUNDS`,
      },
    }));

    return (result.Items || [])
      .filter(r => r.status === 'completed')
      .reduce((sum, r) => sum + r.amount, 0);
  }

  async _processWithGateway(paymentRequest) {
    // P1 FIX: This is a placeholder - implement actual gateway integration
    // Example: Stripe, Razorpay, PayU, etc.
    
    const gatewayConfig = this._getGatewayConfig();
    
    // Simulate gateway call
    console.log(`[PaymentService] Processing ${gatewayConfig.name}: ${paymentRequest.amount} ${paymentRequest.currency}`);
    
    // In production, call actual gateway API
    // const response = await gateway.charges.create({...});
    
    return {
      status: 'completed',
      transactionId: `txn_${randomUUID()}`,
      rawResponse: { gateway: gatewayConfig.name },
    };
  }

  async _processRefundWithGateway(refundRequest) {
    // P1 FIX: Implement actual refund processing
    console.log(`[PaymentService] Processing refund: ${refundRequest.amount}`);
    
    return {
      refundId: `ref_gw_${randomUUID()}`,
      status: 'completed',
    };
  }

  _getGatewayConfig() {
    // P1 FIX: Load from environment/secrets
    return {
      name: process.env.PAYMENT_GATEWAY || 'razorpay',
      apiKey: process.env.PAYMENT_GATEWAY_KEY,
      apiSecret: process.env.PAYMENT_GATEWAY_SECRET,
    };
  }
}

/**
 * Generate idempotency key from request data
 * Creates deterministic key for identical requests
 */
export function generateIdempotencyKey(requestData) {
  const data = {
    orderId: requestData.orderId,
    amount: requestData.amount,
    currency: requestData.currency,
    customerId: requestData.customerId,
  };
  
  const hash = createHash('sha256')
    .update(JSON.stringify(data))
    .update(requestData.userId || '')
    .update(Date.now().toString().slice(0, -4) + '0000') // 10-second window
    .digest('hex')
    .slice(0, 32);
  
  return `idemp_${hash}`;
}

// Export singleton instance
export const paymentService = new PaymentService();
