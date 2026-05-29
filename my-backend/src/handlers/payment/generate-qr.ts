import { config } from '../../config/environment';
// ============================================================================
// Lambda: generatePaymentQR
// Purpose: Generate Razorpay QR code for bill payment
// Route: POST /billing/payment/generate-qr (Cognito protected)
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import axios, { AxiosError } from 'axios';
import { v4 as uuidv4 } from 'uuid';
import {
    docClient, TABLE_NAMES, PaymentKeys, Bill, BusinessOwner, PaymentEvent,
    BillItem, PaymentStatus, PaymentMode
} from '../../config/payment-tables.config';
import { GetCommand, PutCommand, UpdateCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

// ============================================================================
// Environment Configuration
// ============================================================================

const RAZORPAY_KEY_ID = config.payment.razorpay.keyId || '';
const RAZORPAY_KEY_SECRET = config.payment.razorpay.keySecret || '';
const RAZORPAY_BASE_URL = 'https://api.razorpay.com/v1';
const MAX_QR_AMOUNT = 100000; // ₹1 lakh

// ============================================================================
// Type Definitions
// ============================================================================

interface GenerateQRRequest {
    billId: string;
    businessId: string;
    amount: number;
    invoiceNumber: string;
    customerName?: string;
    customerPhone?: string;
    description?: string;
}

interface GenerateQRResponse {
    success: boolean;
    qrImageUrl: string;
    orderId: string;
    qrId: string;
    expiresAt: string;
    amount: number;
    currency: string;
}

interface CognitoClaims {
    sub: string;
    'custom:businessId'?: string;
    'custom:role'?: string;
    email?: string;
}

interface RazorpayOrder {
    id: string;
    amount: number;
    currency: string;
    status: string;
    receipt?: string;
}

interface RazorpayQRCode {
    id: string;
    image_url: string;
    status: string;
    close_by?: number;
}

interface RazorpayError {
    error: {
        code: string;
        description: string;
    };
}

// ============================================================================
// Utility Functions
// ============================================================================

function createRazorpayAuth(): string {
    return Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64');
}

function getCognitoClaims(event: APIGatewayProxyEvent): CognitoClaims | null {
    const authorizer = event.requestContext.authorizer as { claims?: Record<string, string> } | undefined;
    const claims = authorizer?.claims;
    
    if (!claims) return null;
    
    return {
        sub: claims.sub || claims['cognito:username'] || '',
        'custom:businessId': claims['custom:businessId'] || claims['custom:business_id'],
        'custom:role': claims['custom:role'] || claims['custom:user_role'],
        email: claims.email,
    };
}

function errorResponse(statusCode: number, message: string, errorCode?: string): APIGatewayProxyResult {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Cache-Control': 'no-store',
        },
        body: JSON.stringify({ success: false, error: message, errorCode }),
    };
}

function successResponse(data: GenerateQRResponse): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Cache-Control': 'no-store',
        },
        body: JSON.stringify(data),
    };
}

// ============================================================================
// DynamoDB Operations
// ============================================================================

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

async function updateBillWithQR(
    billId: string,
    orderId: string,
    qrId: string,
    qrImageUrl: string,
    expiresAt: string
): Promise<void> {
    const now = new Date().toISOString();
    
    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
        UpdateExpression: `SET paymentStatus = :status, razorpayOrderId = :orderId, 
            razorpayQrId = :qrId, qrImageUrl = :qrUrl, qrExpiresAt = :expiresAt, 
            updatedAt = :now, GSI2PK = :gsi2pk, paymentMode = :mode`,
        ExpressionAttributeValues: {
            ':status': 'PENDING' as PaymentStatus,
            ':orderId': orderId,
            ':qrId': qrId,
            ':qrUrl': qrImageUrl,
            ':expiresAt': expiresAt,
            ':now': now,
            ':gsi2pk': PaymentKeys.gsi2Order(orderId),
            ':mode': 'UPI' as PaymentMode,
        },
    }));
}

async function logPaymentEvent(
    billId: string,
    eventType: 'CREATED' | 'CAPTURED' | 'FAILED' | 'EXPIRED',
    razorpayEventId?: string,
    rawPayload?: Record<string, unknown>
): Promise<void> {
    const eventId = uuidv4();
    const now = new Date();
    
    const event: PaymentEvent = {
        PK: PaymentKeys.eventPK(eventId),
        SK: PaymentKeys.eventSK(billId),
        eventId,
        billId,
        eventType,
        razorpayEventId,
        rawPayload: rawPayload || {},
        processedAt: now.toISOString(),
        processedBy: 'generate-qr-lambda',
        TTL: Math.floor(now.getTime() / 1000) + (90 * 24 * 60 * 60), // 90 days
        GSI1PK: PaymentKeys.gsi1EventBill(billId),
        GSI1SK: PaymentKeys.gsi1EventTime(now.toISOString()),
    };
    
    await docClient.send(new PutCommand({
        TableName: TABLE_NAMES.PAYMENT_EVENTS,
        Item: event,
    }));
}

// ============================================================================
// Razorpay API Functions
// ============================================================================

async function createRazorpayOrder(
    amount: number,
    receipt: string,
    notes: Record<string, string>,
    linkedAccountId: string
): Promise<RazorpayOrder> {
    const url = `${RAZORPAY_BASE_URL}/orders`;
    
    // Truncate receipt to 40 chars max
    const truncatedReceipt = receipt.slice(0, 40);
    
    const payload = {
        amount: Math.round(amount * 100), // Convert to paise
        currency: 'INR',
        receipt: truncatedReceipt,
        notes,
        transfers: [
            {
                account: linkedAccountId,
                amount: Math.round(amount * 100),
                currency: 'INR',
                on_hold: false,
            },
        ],
    };
    
    try {
        const response = await axios.post<RazorpayOrder>(url, payload, {
            headers: {
                'Authorization': `Basic ${createRazorpayAuth()}`,
                'Content-Type': 'application/json',
            },
        });
        
        console.log('[RAZORPAY] Order created:', response.data.id);
        return response.data;
    } catch (error) {
        const axiosError = error as AxiosError<RazorpayError>;
        console.error('[RAZORPAY] Order creation failed:', 
            axiosError.response?.data?.error?.code,
            axiosError.response?.data?.error?.description
        );
        throw error;
    }
}

async function createRazorpayQR(
    orderId: string,
    amount: number,
    description: string,
    closeBy: number
): Promise<RazorpayQRCode> {
    const url = `${RAZORPAY_BASE_URL}/payments/qr_codes`;
    
    const payload = {
        type: 'upi_qr',
        usage: 'single_use',
        fixed_amount: true,
        payment_amount: Math.round(amount * 100),
        description,
        order_id: orderId,
        close_by: closeBy,
    };
    
    try {
        const response = await axios.post<RazorpayQRCode>(url, payload, {
            headers: {
                'Authorization': `Basic ${createRazorpayAuth()}`,
                'Content-Type': 'application/json',
            },
        });
        
        console.log('[RAZORPAY] QR created:', response.data.id);
        return response.data;
    } catch (error) {
        const axiosError = error as AxiosError<RazorpayError>;
        console.error('[RAZORPAY] QR creation failed:', 
            axiosError.response?.data?.error?.code,
            axiosError.response?.data?.error?.description
        );
        throw error;
    }
}

async function cancelRazorpayOrder(orderId: string): Promise<void> {
    const url = `${RAZORPAY_BASE_URL}/orders/${orderId}`;
    
    try {
        await axios.patch(url, { status: 'attempted' }, {
            headers: {
                'Authorization': `Basic ${createRazorpayAuth()}`,
                'Content-Type': 'application/json',
            },
        });
        console.log('[RAZORPAY] Order cancelled:', orderId);
    } catch (error) {
        console.error('[RAZORPAY] Failed to cancel order:', orderId, error);
    }
}

// ============================================================================
// Main Handler
// ============================================================================

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    console.log(`[${requestId}] Generate QR request received`);
    
    try {
        // Verify Cognito authentication
        const claims = getCognitoClaims(event);
        if (!claims) {
            return errorResponse(401, 'Unauthorized - Cognito claims not found');
        }
        
        // Parse request body
        if (!event.body) {
            return errorResponse(400, 'Request body is required');
        }
        
        let body: GenerateQRRequest;
        try {
            body = JSON.parse(event.body);
        } catch {
            return errorResponse(400, 'Invalid JSON in request body');
        }
        
        // Validate required fields
        if (!body.billId || !body.businessId || !body.amount || !body.invoiceNumber) {
            return errorResponse(400, 'Missing required fields: billId, businessId, amount, invoiceNumber');
        }
        
        // Validate JWT businessId matches request
        const jwtBusinessId = claims['custom:businessId'];
        if (jwtBusinessId && jwtBusinessId !== body.businessId) {
            return errorResponse(403, 'Business ID mismatch with JWT claims');
        }
        
        // Validate amount
        if (body.amount <= 0 || body.amount > MAX_QR_AMOUNT) {
            return errorResponse(400, `Amount must be between 0 and ${MAX_QR_AMOUNT}`, 'INVALID_AMOUNT');
        }
        
        // Fetch bill from DynamoDB
        const bill = await getBill(body.billId);
        if (!bill) {
            return errorResponse(404, 'Bill not found', 'BILL_NOT_FOUND');
        }
        
        // Verify bill belongs to this business
        if (bill.businessId !== body.businessId) {
            return errorResponse(403, 'Bill does not belong to this business');
        }
        
        // Check if already paid
        if (bill.paymentStatus === 'PAID') {
            return errorResponse(409, 'Bill is already paid', 'ALREADY_PAID');
        }
        
        // Check if QR already exists and is still valid
        if (bill.paymentStatus === 'PENDING' && bill.qrExpiresAt) {
            const expiresAt = new Date(bill.qrExpiresAt);
            if (expiresAt > new Date()) {
                console.log(`[${requestId}] Returning existing valid QR`);
                return successResponse({
                    success: true,
                    qrImageUrl: bill.qrImageUrl || '',
                    orderId: bill.razorpayOrderId || '',
                    qrId: bill.razorpayQrId || '',
                    expiresAt: bill.qrExpiresAt,
                    amount: bill.totalAmount,
                    currency: 'INR',
                });
            }
        }
        
        // Fetch business owner and verify Razorpay onboarding
        const businessOwner = await getBusinessOwner(body.businessId);
        if (!businessOwner?.razorpayLinkedAccountId) {
            return errorResponse(400, 'Merchant not onboarded to Razorpay', 'MERCHANT_NOT_ONBOARDED');
        }
        
        // Create Razorpay Order with Route
        console.log(`[${requestId}] Creating Razorpay order for amount: ${body.amount}`);
        let order: RazorpayOrder;
        try {
            order = await createRazorpayOrder(
                body.amount,
                body.billId,
                {
                    billId: body.billId,
                    businessId: body.businessId,
                    invoiceNumber: body.invoiceNumber,
                    platform: 'saas_billing_v1',
                },
                businessOwner.razorpayLinkedAccountId
            );
        } catch (error) {
            const axiosError = error as AxiosError<RazorpayError>;
            return errorResponse(
                502,
                axiosError.response?.data?.error?.description || 'Failed to create payment order',
                axiosError.response?.data?.error?.code || 'PAYMENT_GATEWAY_ERROR'
            );
        }
        
        // Create Razorpay QR Code
        console.log(`[${requestId}] Creating Razorpay QR for order: ${order.id}`);
        const closeBy = Math.floor(Date.now() / 1000) + 600; // 10 minutes from now
        const description = `Invoice ${body.invoiceNumber} - ${businessOwner.businessName}`.slice(0, 100);
        
        let qrCode: RazorpayQRCode;
        try {
            qrCode = await createRazorpayQR(order.id, body.amount, description, closeBy);
        } catch (error) {
            // Cancel the order if QR creation fails
            await cancelRazorpayOrder(order.id);
            
            const axiosError = error as AxiosError<RazorpayError>;
            return errorResponse(
                502,
                axiosError.response?.data?.error?.description || 'Failed to generate QR code',
                axiosError.response?.data?.error?.code || 'QR_GENERATION_ERROR'
            );
        }
        
        // Update DynamoDB bill record
        const expiresAtISO = new Date(closeBy * 1000).toISOString();
        await updateBillWithQR(body.billId, order.id, qrCode.id, qrCode.image_url, expiresAtISO);
        
        // Log event
        await logPaymentEvent(body.billId, 'CREATED', qrCode.id, {
            orderId: order.id,
            qrId: qrCode.id,
            amount: body.amount,
        });
        
        console.log(`[${requestId}] QR generated successfully: ${qrCode.id}`);
        
        return successResponse({
            success: true,
            qrImageUrl: qrCode.image_url,
            orderId: order.id,
            qrId: qrCode.id,
            expiresAt: expiresAtISO,
            amount: body.amount,
            currency: 'INR',
        });
        
    } catch (error) {
        console.error(`[${requestId}] Unexpected error:`, error);
        return errorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
    }
};

export default handler;
