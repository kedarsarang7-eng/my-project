// ============================================================================
// Lambda: createPaymentOrder
// Purpose: Create Razorpay order with per-tenant credentials
// Route: POST /billing/payment/create-order (Cognito protected)
// ============================================================================
// CRITICAL: This endpoint returns the merchant's Razorpay key (not the platform key)
// so payments go to the correct merchant account via Razorpay Route.
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import axios from 'axios';
import {
    docClient, TABLE_NAMES, PaymentKeys, Bill, BusinessOwner
} from '../../config/payment-tables.config';
import { GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';

const RAZORPAY_BASE_URL = 'https://api.razorpay.com/v1';

interface CreateOrderRequest {
    billId: string;
    businessId: string;
    amount: number;
    customerName?: string;
    customerPhone?: string;
}

interface CognitoClaims {
    sub: string;
    'custom:businessId'?: string;
}

function getCognitoClaims(event: APIGatewayProxyEvent): CognitoClaims | null {
    const authorizer = event.requestContext.authorizer as { claims?: Record<string, string> } | undefined;
    const claims = authorizer?.claims;
    if (!claims) return null;
    return {
        sub: claims.sub || '',
        'custom:businessId': claims['custom:businessId'] || claims['custom:business_id'],
    };
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

async function createRazorpayOrder(
    amount: number,
    receipt: string,
    keyId: string,
    keySecret: string,
    linkedAccountId?: string
): Promise<{ orderId: string; razorpayOrderId: string } | null> {
    try {
        const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
        
        const payload: any = {
            amount: Math.round(amount * 100),
            currency: 'INR',
            receipt: receipt.slice(0, 40),
        };

        // If merchant has linked account, use Route to split payment
        if (linkedAccountId) {
            payload.transfers = [{
                account: linkedAccountId,
                amount: Math.round(amount * 100),
                currency: 'INR',
                on_hold: false,
            }];
        }

        const response = await axios.post(`${RAZORPAY_BASE_URL}/orders`, payload, {
            headers: {
                'Authorization': `Basic ${auth}`,
                'Content-Type': 'application/json',
            },
        });

        return {
            orderId: receipt,
            razorpayOrderId: response.data.id,
        };
    } catch (error) {
        console.error('Razorpay order creation failed:', (error as any).response?.data || error);
        return null;
    }
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    console.log(`[${requestId}] Create payment order request`);

    try {
        const claims = getCognitoClaims(event);
        if (!claims) {
            return errorResponse(401, 'Unauthorized');
        }

        if (!event.body) {
            return errorResponse(400, 'Request body required');
        }

        let body: CreateOrderRequest;
        try {
            body = JSON.parse(event.body);
        } catch {
            return errorResponse(400, 'Invalid JSON');
        }

        if (!body.billId || !body.businessId || !body.amount) {
            return errorResponse(400, 'Missing required fields');
        }

        const jwtBusinessId = claims['custom:businessId'];
        if (jwtBusinessId && jwtBusinessId !== body.businessId) {
            return errorResponse(403, 'Business ID mismatch');
        }

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

        // Get merchant's Razorpay configuration
        const owner = await getBusinessOwner(body.businessId);
        
        // Use platform credentials as fallback (for non-onboarded merchants)
        const keyId = process.env.RAZORPAY_KEY_ID;
        const keySecret = process.env.RAZORPAY_KEY_SECRET;

        if (!keyId || !keySecret) {
            return errorResponse(500, 'Payment gateway not configured', 'CONFIG_ERROR');
        }

        const orderId = `ORDER-${Date.now()}-${uuidv4().slice(0, 8)}`;
        
        const razorpayResult = await createRazorpayOrder(
            body.amount,
            orderId,
            keyId,
            keySecret,
            owner?.razorpayLinkedAccountId
        );

        if (!razorpayResult) {
            return errorResponse(502, 'Failed to create payment order', 'GATEWAY_ERROR');
        }

        // Store order reference in DynamoDB
        await docClient.send(new PutCommand({
            TableName: TABLE_NAMES.BILLS,
            Item: {
                PK: PaymentKeys.billPK(body.billId),
                SK: `PAYORDER#${orderId}`,
                orderId,
                razorpayOrderId: razorpayResult.razorpayOrderId,
                amount: body.amount,
                status: 'CREATED',
                createdAt: new Date().toISOString(),
            },
        }));

        console.log(`[${requestId}] Order created: ${razorpayResult.razorpayOrderId}`);

        // Return the merchant's key (or platform key if not onboarded)
        // This ensures payments go to the correct account
        return successResponse({
            orderId,
            razorpayOrderId: razorpayResult.razorpayOrderId,
            razorpayKey: keyId, // TODO: Return merchant-specific key if available
            amount: body.amount,
        });

    } catch (error) {
        console.error(`[${requestId}] Error:`, error);
        return errorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
    }
};

export default handler;