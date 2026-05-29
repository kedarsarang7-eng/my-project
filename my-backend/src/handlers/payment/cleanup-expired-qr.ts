import { config } from '../../config/environment';
// ============================================================================
// Lambda: cleanupExpiredQRCodes
// Purpose: Background cleanup of expired QR codes via EventBridge schedule
// Trigger: EventBridge (cron) - runs every 15 minutes
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import axios, { AxiosError } from 'axios';
import { v4 as uuidv4 } from 'uuid';
import {
    docClient, TABLE_NAMES, PaymentKeys, Bill, PaymentStatus
} from '../../config/payment-tables.config';
import { UpdateCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

// ============================================================================
// Environment Configuration
// ============================================================================

const RAZORPAY_KEY_ID = config.payment.razorpay.keyId || '';
const RAZORPAY_KEY_SECRET = config.payment.razorpay.keySecret || '';
const RAZORPAY_BASE_URL = 'https://api.razorpay.com/v1';

// ============================================================================
// Type Definitions
// ============================================================================

interface CleanupResult {
    scanned: number;
    expired: number;
    closed: number;
    errors: number;
    failedBills: string[];
}

// ============================================================================
// Utility Functions
// ============================================================================

function createRazorpayAuth(): string {
    return Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64');
}

function errorResponse(statusCode: number, message: string): APIGatewayProxyResult {
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ success: false, error: message }),
    };
}

function successResponse(result: CleanupResult): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ success: true, result }),
    };
}

// ============================================================================
// DynamoDB Operations
// ============================================================================

async function getExpiredPendingBills(): Promise<Pick<Bill, 'PK' | 'SK' | 'billId' | 'qrExpiresAt' | 'razorpayOrderId' | 'razorpayQrId'>[]> {
    const now = new Date().toISOString();
    
    const result = await docClient.send(new QueryCommand({
        TableName: TABLE_NAMES.BILLS,
        IndexName: 'GSI3',
        KeyConditionExpression: 'GSI3PK = :status',
        FilterExpression: 'qrExpiresAt < :now',
        ExpressionAttributeValues: {
            ':status': PaymentKeys.gsi3Status('PENDING'),
            ':now': now,
        },
    }));
    
    return (result.Items || []) as Pick<Bill, 'PK' | 'SK' | 'billId' | 'qrExpiresAt' | 'razorpayOrderId' | 'razorpayQrId'>[];
}

async function updateBillToExpired(billId: string): Promise<void> {
    const now = new Date().toISOString();
    
    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
        UpdateExpression: `SET paymentStatus = :status, updatedAt = :now, 
            GSI3PK = :gsi3pk, failureReason = :reason`,
        ExpressionAttributeValues: {
            ':status': 'EXPIRED' as PaymentStatus,
            ':now': now,
            ':gsi3pk': PaymentKeys.gsi3Status('EXPIRED'),
            ':reason': 'QR code expired - payment not completed within time limit',
        },
    }));
}

// ============================================================================
// Razorpay API Functions
// ============================================================================

async function closeRazorpayOrder(orderId: string): Promise<boolean> {
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
        console.warn('Razorpay credentials not configured, skipping order close');
        return false;
    }
    
    const url = `${RAZORPAY_BASE_URL}/orders/${orderId}`;
    
    try {
        await axios.patch(url, { status: 'attempted' }, {
            headers: {
                'Authorization': `Basic ${createRazorpayAuth()}`,
                'Content-Type': 'application/json',
            },
        });
        return true;
    } catch (error) {
        const axiosError = error as AxiosError;
        // Order might already be closed or doesn't exist - not a critical error
        console.warn(`Failed to close order ${orderId}:`, axiosError.response?.status);
        return false;
    }
}

// ============================================================================
// Main Handler
// ============================================================================

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    console.log(`[${requestId}] Starting expired QR cleanup job`);
    
    try {
        const result: CleanupResult = {
            scanned: 0,
            expired: 0,
            closed: 0,
            errors: 0,
            failedBills: [],
        };
        
        // Find expired pending bills
        const expiredBills = await getExpiredPendingBills();
        result.scanned = expiredBills.length;
        
        console.log(`[${requestId}] Found ${expiredBills.length} expired pending bills`);
        
        // Process each expired bill
        for (const bill of expiredBills) {
            try {
                console.log(`[${requestId}] Processing expired bill: ${bill.billId}`);
                
                // Update bill status to EXPIRED
                await updateBillToExpired(bill.billId);
                result.expired++;
                
                // Close Razorpay order if exists
                if (bill.razorpayOrderId) {
                    const closed = await closeRazorpayOrder(bill.razorpayOrderId);
                    if (closed) result.closed++;
                }
                
            } catch (error) {
                console.error(`[${requestId}] Failed to process bill ${bill.billId}:`, error);
                result.errors++;
                result.failedBills.push(bill.billId);
            }
        }
        
        console.log(`[${requestId}] Cleanup completed:`, result);
        return successResponse(result);
        
    } catch (error) {
        console.error(`[${requestId}] Cleanup job failed:`, error);
        return errorResponse(500, 'Cleanup job failed');
    }
};

// Export for direct invocation (can also be triggered by EventBridge)
export const cleanupJob = handler;

export default handler;
