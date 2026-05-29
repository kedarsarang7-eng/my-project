// ============================================================================
// Lambda: verifyRazorpayPayment
// Purpose: Server-side verification of Razorpay payment before marking bill paid
// Route: POST /billing/payment/verify (Cognito protected)
// ============================================================================
// CRITICAL SECURITY: This endpoint verifies the payment signature using the
// merchant's stored Razorpay keySecret. The Flutter app MUST call this endpoint
// and receive a success response before marking any bill as PAID.
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import * as crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import {
    docClient, TABLE_NAMES, PaymentKeys, Bill, BusinessOwner
} from '../../config/payment-tables.config';
import { GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const RAZORPAY_API_URL = 'https://api.razorpay.com';

interface VerifyPaymentRequest {
    billId: string;
    businessId: string;
    razorpayPaymentId: string;
    razorpayOrderId: string;
    razorpaySignature: string;
}

interface CognitoClaims {
    sub: string;
    'custom:businessId'?: string;
    'custom:role'?: string;
}

function getCognitoClaims(event: APIGatewayProxyEvent): CognitoClaims | null {
    const authorizer = event.requestContext.authorizer as { claims?: Record<string, string> } | undefined;
    const claims = authorizer?.claims;
    if (!claims) return null;
    return {
        sub: claims.sub || claims['cognito:username'] || '',
        'custom:businessId': claims['custom:businessId'] || claims['custom:business_id'],
        'custom:role': claims['custom:role'] || claims['custom:user_role'],
    };
}

function errorResponse(statusCode: number, message: string, errorCode?: string): APIGatewayProxyResult {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({ success: false, error: message, errorCode }),
    };
}

function successResponse(data: Record<string, unknown>): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({ success: true, ...data }),
    };
}

async function getBill(billId: string): Promise<Bill | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
    }));
    return result.Item as Bill | null;
}

async function getBusinessOwner(businessId: string): Promise<BusinessOwner | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAMES.BUSINESS_OWNERS,
        Key: { PK: PaymentKeys.businessPK(businessId), SK: PaymentKeys.businessSK() },
    }));
    return result.Item as BusinessOwner | null;
}

async function fetchRazorpayPaymentDetails(
    paymentId: string,
    keyId: string,
    keySecret: string
): Promise<{ status: string; amount: number; order_id: string } | null> {
    try {
        const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
        const response = await fetch(`${RAZORPAY_API_URL}/v1/payments/${paymentId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Basic ${auth}`,
                'Content-Type': 'application/json',
            },
        });

        if (!response.ok) {
            console.error('Razorpay payment fetch failed:', response.status);
            return null;
        }

        const data = await response.json() as Record<string, any>;
        return {
            status: data.status,
            amount: data.amount,
            order_id: data.order_id,
        };
    } catch (error) {
        console.error('Error fetching Razorpay payment:', error);
        return null;
    }
}

function verifyRazorpaySignature(
    orderId: string,
    paymentId: string,
    secret: string,
    signature: string
): boolean {
    const body = `${orderId}|${paymentId}`;
    const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(body)
        .digest('hex');

    try {
        return crypto.timingSafeEqual(
            Buffer.from(signature, 'hex'),
            Buffer.from(expectedSignature, 'hex'),
        );
    } catch {
        return false;
    }
}

async function updateBillAsPaid(
    billId: string,
    razorpayPaymentId: string,
    actualPaymentMethod: string
): Promise<void> {
    const now = new Date().toISOString();
    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
        UpdateExpression: `SET paymentStatus = :status, razorpayPaymentId = :paymentId,
            paidAt = :now, updatedAt = :now, actualPaymentMethod = :method,
            GSI3PK = :gsi3pk`,
        ExpressionAttributeValues: {
            ':status': 'PAID',
            ':paymentId': razorpayPaymentId,
            ':now': now,
            ':method': actualPaymentMethod,
            ':gsi3pk': PaymentKeys.gsi3Status('PAID'),
        },
    }));
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    console.log(`[${requestId}] Payment verification request`);

    try {
        // Verify Cognito authentication
        const claims = getCognitoClaims(event);
        if (!claims) {
            return errorResponse(401, 'Unauthorized - Cognito claims not found');
        }

        if (!event.body) {
            return errorResponse(400, 'Request body required');
        }

        let body: VerifyPaymentRequest;
        try {
            body = JSON.parse(event.body);
        } catch {
            return errorResponse(400, 'Invalid JSON');
        }

        // Validate required fields
        if (!body.billId || !body.businessId || !body.razorpayPaymentId || !body.razorpayOrderId || !body.razorpaySignature) {
            return errorResponse(400, 'Missing required fields');
        }

        // Verify JWT businessId matches request
        const jwtBusinessId = claims['custom:businessId'];
        if (jwtBusinessId && jwtBusinessId !== body.businessId) {
            return errorResponse(403, 'Business ID mismatch with JWT claims');
        }

        // Fetch bill
        const bill = await getBill(body.billId);
        if (!bill) {
            return errorResponse(404, 'Bill not found', 'BILL_NOT_FOUND');
        }

        if (bill.businessId !== body.businessId) {
            return errorResponse(403, 'Bill does not belong to this business');
        }

        if (bill.paymentStatus === 'PAID') {
            return errorResponse(409, 'Bill already paid', 'ALREADY_PAID');
        }

        // Fetch business owner to get Razorpay credentials
        const owner = await getBusinessOwner(body.businessId);
        if (!owner?.razorpayLinkedAccountId) {
            // Fall back to platform credentials for non-onboarded merchants
            console.log(`[${requestId}] Merchant not onboarded, using platform credentials`);
        }

        // Get Razorpay credentials from environment (platform-level for now)
        // In production, these should be per-tenant encrypted credentials
        const keyId = process.env.RAZORPAY_KEY_ID;
        const keySecret = process.env.RAZORPAY_KEY_SECRET;

        if (!keyId || !keySecret) {
            console.error(`[${requestId}] Razorpay credentials not configured`);
            return errorResponse(500, 'Payment gateway not configured', 'CONFIG_ERROR');
        }

        // CRITICAL: Server-side signature verification
        const isSignatureValid = verifyRazorpaySignature(
            body.razorpayOrderId,
            body.razorpayPaymentId,
            keySecret,
            body.razorpaySignature
        );

        if (!isSignatureValid) {
            console.error(`[${requestId}] Signature verification failed`);
            return errorResponse(400, 'Invalid payment signature', 'INVALID_SIGNATURE');
        }

        // Fetch payment details from Razorpay to confirm
        const paymentDetails = await fetchRazorpayPaymentDetails(
            body.razorpayPaymentId,
            keyId,
            keySecret
        );

        if (!paymentDetails) {
            return errorResponse(502, 'Could not verify payment with gateway', 'GATEWAY_ERROR');
        }

        if (paymentDetails.status !== 'captured' && paymentDetails.status !== 'authorized') {
            return errorResponse(400, `Payment not successful: ${paymentDetails.status}`, 'PAYMENT_FAILED');
        }

        // Verify amount matches
        const expectedAmountPaise = Math.round(bill.totalAmount * 100);
        if (paymentDetails.amount !== expectedAmountPaise) {
            console.error(`[${requestId}] Amount mismatch: expected ${expectedAmountPaise}, got ${paymentDetails.amount}`);
            return errorResponse(400, 'Payment amount mismatch', 'AMOUNT_MISMATCH');
        }

        // Verify order_id matches
        if (paymentDetails.order_id !== body.razorpayOrderId) {
            console.error(`[${requestId}] Order ID mismatch`);
            return errorResponse(400, 'Order ID mismatch', 'ORDER_MISMATCH');
        }

        // Mark bill as paid
        await updateBillAsPaid(body.billId, body.razorpayPaymentId, 'upi');

        console.log(`[${requestId}] Payment verified and bill marked paid: ${body.billId}`);

        return successResponse({
            billId: body.billId,
            paymentId: body.razorpayPaymentId,
            status: 'PAID',
            amount: bill.totalAmount,
        });

    } catch (error) {
        console.error(`[${requestId}] Unexpected error:`, error);
        return errorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
    }
};

export default handler;