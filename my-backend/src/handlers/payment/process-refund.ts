// ============================================================================
// Lambda: processRefund
// Purpose: Process refunds for completed payments
// Route: POST /billing/payment/refund (Cognito protected - Admin/Manager only)
// ============================================================================
// Handles both full and partial refunds via Razorpay API
// Records refund in database and updates bill status if fully refunded
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import axios from 'axios';
import {
    docClient, TABLE_NAME as TABLE_NAME, Keys
} from '../../config/dynamodb.config';
import type { RefundRecord } from '../../types/refund.types';
import { GetCommand, PutCommand, UpdateCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
// Simple auth helper
function getCognitoClaims(event: any): any {
    const authorizer = event.requestContext?.authorizer;
    if (!authorizer?.claims) return null;
    return {
        sub: authorizer.claims.sub || '',
        email: authorizer.claims.email || '',
        name: authorizer.claims.name || '',
        role: authorizer.claims['custom:role'] || '',
        businessId: authorizer.claims['custom:businessId'] || authorizer.claims['custom:business_id'],
    };
}

const RAZORPAY_BASE_URL = 'https://api.razorpay.com/v1';

interface RefundRequest {
    billId: string;
    businessId: string;
    amount?: number; // Optional - if not provided, full refund
    reason?: string;
    notes?: string;
}

interface BusinessOwner {
    razorpayKeyId?: string;
    razorpayKeySecret?: string;
}

function errorResponse(statusCode: number, message: string, errorCode?: string): APIGatewayProxyResult {
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ success: false, error: message, errorCode }),
    };
}

function successResponse(data: Record<string, unknown>): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ success: true, ...data }),
    };
}

async function getBill(billId: string): Promise<any | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: { PK: `INVOICE#${billId}`, SK: `INVOICE#${billId}` },
    }));
    return result.Item || null;
}

async function getBusinessOwner(businessId: string): Promise<any | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: { PK: `TENANT#${businessId}`, SK: `BUSINESS#${businessId}` },
    }));
    return result.Item || null;
}

async function getPaymentByBillId(billId: string): Promise<any | null> {
    const result = await docClient.send(new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk',
        ExpressionAttributeValues: {
            ':pk': `PAYMENT#BILL#${billId}`,
        },
        ScanIndexForward: false,
        Limit: 1,
    }));
    return result.Items?.[0] || null;
}

async function createRazorpayRefund(
    paymentId: string,
    amount: number | undefined, // undefined = full refund
    keyId: string,
    keySecret: string,
    notes?: string
): Promise<{ id: string; status: string; amount: number } | null> {
    try {
        const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
        
        const payload: any = {
            notes: {
                reason: notes || 'Customer refund request',
                timestamp: new Date().toISOString(),
            },
        };
        
        // If amount specified, it's a partial refund (in paise)
        if (amount !== undefined && amount > 0) {
            payload.amount = Math.round(amount * 100); // Convert to paise
        }
        
        const response = await axios.post(
            `${RAZORPAY_BASE_URL}/payments/${paymentId}/refund`,
            payload,
            {
                headers: {
                    'Authorization': `Basic ${auth}`,
                    'Content-Type': 'application/json',
                },
            }
        );

        return {
            id: response.data.id,
            status: response.data.status,
            amount: response.data.amount / 100, // Convert from paise to rupees
        };
    } catch (error: any) {
        console.error('Razorpay refund error:', error.response?.data || error.message);
        return null;
    }
}

async function recordRefund(refund: RefundRecord): Promise<void> {
    await docClient.send(new PutCommand({
        TableName: TABLE_NAME,
        Item: refund,
    }));
}

async function updateBillAfterRefund(
    billId: string,
    refundAmount: number,
    totalRefunded: number,
    billTotal: number
): Promise<void> {
    // Determine new bill status
    let newStatus = 'Partially Refunded';
    let paidAmountUpdate = -refundAmount; // Reduce paid amount
    
    if (totalRefunded >= billTotal) {
        newStatus = 'Fully Refunded';
    }

    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { PK: `INVOICE#${billId}`, SK: `INVOICE#${billId}` },
        UpdateExpression: 'SET #status = :status, refundedAmount = :refundedAmount, paidAmount = paidAmount + :paidAdjust, updatedAt = :now',
        ExpressionAttributeNames: {
            '#status': 'status',
        },
        ExpressionAttributeValues: {
            ':status': newStatus,
            ':refundedAmount': totalRefunded,
            ':paidAdjust': paidAmountUpdate,
            ':now': new Date().toISOString(),
        },
    }));
}

async function getTotalRefundedForBill(billId: string): Promise<number> {
    const result = await docClient.send(new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk',
        ExpressionAttributeValues: {
            ':pk': `BILL#${billId}`,
        },
    }));

    return (result.Items || []).reduce((sum, item) => sum + (item.amount || 0), 0);
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    console.log('Refund request received:', event.body);

    // Verify authentication
    const claims = getCognitoClaims(event);
    if (!claims) {
        return errorResponse(401, 'Unauthorized - Invalid token');
    }

    // Only admins and managers can process refunds
    const allowedRoles = ['Admin', 'Manager', 'SUPER_ADMIN'];
    if (!allowedRoles.includes(claims.role || '')) {
        return errorResponse(403, 'Forbidden - Insufficient permissions to process refunds');
    }

    // Parse request
    let request: RefundRequest;
    try {
        request = JSON.parse(event.body || '{}');
    } catch {
        return errorResponse(400, 'Invalid JSON in request body');
    }

    const { billId, businessId, amount, reason, notes } = request;

    // Validation
    if (!billId || !businessId) {
        return errorResponse(400, 'Missing required fields: billId, businessId');
    }

    // Verify tenant authorization
    const jwtBusinessId = claims.businessId || claims['custom:businessId'];
    if (jwtBusinessId !== businessId) {
        return errorResponse(403, 'Forbidden - Cannot refund bills from other businesses');
    }

    // Get bill details
    const bill = await getBill(billId);
    if (!bill) {
        return errorResponse(404, 'Bill not found');
    }

    // Check if bill is paid
    if (bill.status !== 'Paid' && !bill.status?.includes('Refunded')) {
        return errorResponse(400, 'Cannot refund - Bill is not in paid status', 'BILL_NOT_PAID');
    }

    // Get original payment
    const payment = await getPaymentByBillId(billId);
    if (!payment || !payment.razorpayPaymentId) {
        return errorResponse(404, 'Original payment not found or no Razorpay payment ID');
    }

    // Calculate refund amount
    const billTotal = bill.grandTotal || bill.total || 0;
    const alreadyRefunded = await getTotalRefundedForBill(billId);
    const remainingRefundable = billTotal - alreadyRefunded;

    if (remainingRefundable <= 0) {
        return errorResponse(400, 'Bill is already fully refunded', 'ALREADY_FULLY_REFUNDED');
    }

    const refundAmount = amount || remainingRefundable;

    if (refundAmount > remainingRefundable) {
        return errorResponse(400, `Cannot refund more than remaining amount: ₹${remainingRefundable}`, 'REFUND_AMOUNT_EXCEEDS');
    }

    // Get business Razorpay credentials
    const business = await getBusinessOwner(businessId);
    if (!business?.razorpayKeyId || !business?.razorpayKeySecret) {
        return errorResponse(400, 'Business Razorpay credentials not configured');
    }

    // Create Razorpay refund
    const razorpayRefund = await createRazorpayRefund(
        payment.razorpayPaymentId,
        refundAmount < remainingRefundable ? refundAmount : undefined, // undefined for full refund
        business.razorpayKeyId,
        business.razorpayKeySecret,
        notes || reason
    );

    if (!razorpayRefund) {
        return errorResponse(502, 'Failed to create refund with payment provider');
    }

    // Record refund in database
    const refundId = uuidv4();
    const now = Date.now();
    const refundRecord: RefundRecord = {
        PK: Keys.refundPK(refundId),
        SK: Keys.refundSK(),
        GSI1PK: Keys.refundByBillGSI(billId),
        GSI1SK: `REFUND#${now}`,
        id: refundId,
        billId,
        businessId,
        paymentId: payment.id,
        razorpayRefundId: razorpayRefund.id,
        razorpayPaymentId: payment.razorpayPaymentId,
        amount: refundAmount,
        currency: 'INR',
        status: razorpayRefund.status === 'processed' ? 'Completed' : 'Pending',
        reason: reason || 'Customer request',
        notes: notes || '',
        processedBy: claims.sub,
        processedByName: claims.name || claims.email || 'Unknown',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
    };

    await recordRefund(refundRecord);

    // Update bill status
    const newTotalRefunded = alreadyRefunded + refundAmount;
    await updateBillAfterRefund(billId, refundAmount, newTotalRefunded, billTotal);

    // Log audit
    console.log('Refund processed:', {
        refundId,
        billId,
        amount: refundAmount,
        processedBy: claims.sub,
        razorpayRefundId: razorpayRefund.id,
    });

    return successResponse({
        refundId,
        billId,
        amount: refundAmount,
        status: refundRecord.status,
        razorpayRefundId: razorpayRefund.id,
        remainingRefundable: billTotal - newTotalRefunded,
        isFullyRefunded: newTotalRefunded >= billTotal,
        message: `Refund of ₹${refundAmount} processed successfully`,
    });
};
