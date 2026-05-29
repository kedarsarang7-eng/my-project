import { config } from '../../config/environment';
// ============================================================================
// Lambda: getPaymentStatus
// Purpose: Poll payment status for QR payments
// Route: GET /billing/payment/status/{billId}
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import axios, { AxiosError } from 'axios';
import { v4 as uuidv4 } from 'uuid';
import {
    docClient, TABLE_NAMES, PaymentKeys, Bill, PaymentStatus, PaymentMode
} from '../../config/payment-tables.config';
import { GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';

// ============================================================================
// Environment Configuration
// ============================================================================

const RAZORPAY_KEY_ID = config.payment.razorpay.keyId || '';
const RAZORPAY_KEY_SECRET = config.payment.razorpay.keySecret || '';
const RAZORPAY_BASE_URL = 'https://api.razorpay.com/v1';

// ============================================================================
// Type Definitions
// ============================================================================

interface PaymentStatusResponse {
    success: boolean;
    billId: string;
    status: PaymentStatus;
    amount: number;
    paid?: boolean;
    paidAt?: string;
    paymentId?: string;
    paymentMode?: string;
    paymentMethod?: string;
    failureReason?: string;
    failureCode?: string;
    qrExpiresAt?: string;
}

interface RazorpayOrder {
    id: string;
    status: 'created' | 'attempted' | 'paid';
    amount_paid: number;
    amount_due: number;
    attempts: number;
}

// ============================================================================
// Utility Functions
// ============================================================================

function createRazorpayAuth(): string {
    return Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64');
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

function successResponse(data: PaymentStatusResponse): APIGatewayProxyResult {
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

async function updateBillToPaid(
    billId: string,
    razorpayPaymentId: string,
    paymentMethod: string
): Promise<void> {
    const now = new Date().toISOString();
    
    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
        UpdateExpression: `SET paymentStatus = :status, razorpayPaymentId = :paymentId, 
            paidAt = :now, updatedAt = :now, GSI3PK = :gsi3pk, actualPaymentMethod = :method`,
        ExpressionAttributeValues: {
            ':status': 'PAID' as PaymentStatus,
            ':paymentId': razorpayPaymentId,
            ':now': now,
            ':gsi3pk': PaymentKeys.gsi3Status('PAID'),
            ':method': paymentMethod,
        },
    }));
}

// ============================================================================
// Razorpay API Functions
// ============================================================================

async function getRazorpayOrder(orderId: string): Promise<RazorpayOrder> {
    const url = `${RAZORPAY_BASE_URL}/orders/${orderId}`;
    
    const response = await axios.get<RazorpayOrder>(url, {
        headers: {
            'Authorization': `Basic ${createRazorpayAuth()}`,
            'Content-Type': 'application/json',
        },
    });
    
    return response.data;
}

async function getRazorpayPaymentsForOrder(orderId: string): Promise<Array<{ id: string; status: string; method: string }>> {
    const url = `${RAZORPAY_BASE_URL}/orders/${orderId}/payments`;
    
    const response = await axios.get<{ items: Array<{ id: string; status: string; method: string }> }>(url, {
        headers: {
            'Authorization': `Basic ${createRazorpayAuth()}`,
            'Content-Type': 'application/json',
        },
    });
    
    return response.data.items || [];
}

// ============================================================================
// Main Handler
// ============================================================================


// Get Cognito claims from JWT
function getCognitoClaims(event: APIGatewayProxyEvent): Record<string, string> | null {
    const authorizer = event.requestContext.authorizer as { claims?: Record<string, string> } | undefined;
    const claims = authorizer?.claims;
    if (!claims) return null;
    return claims;
}
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    console.log(`[${requestId}] Get payment status request received`);
    
    try {
        // Extract billId from path parameters
        const billId = event.pathParameters?.billId;
        if (!billId) {
            return errorResponse(400, 'Bill ID is required in path', 'MISSING_BILL_ID');
        }
        
        // Fetch bill from DynamoDB
        const bill = await getBill(billId);
        if (!bill) {
            return errorResponse(404, 'Bill not found', 'BILL_NOT_FOUND');
        }

        // Verify Cognito authorization - tenant isolation
        const claims = getCognitoClaims(event);
        const jwtBusinessId = claims?.['custom:businessId'] || claims?.['custom:business_id'];
        if (jwtBusinessId && jwtBusinessId !== bill.businessId) {
            return errorResponse(403, 'Access denied - bill belongs to different business', 'UNAUTHORIZED');
        }

        
        // If already marked as PAID in DynamoDB
        if (bill.paymentStatus === 'PAID') {
            return successResponse({
                success: true,
                billId,
                status: 'PAID',
                amount: bill.totalAmount,
                paid: true,
                paidAt: bill.paidAt,
                paymentId: bill.razorpayPaymentId,
                paymentMode: bill.paymentMode,
                paymentMethod: bill.paymentMode,
            });
        }
        
        // If already marked as FAILED
        if (bill.paymentStatus === 'FAILED') {
            return successResponse({
                success: true,
                billId,
                status: 'FAILED',
                amount: bill.totalAmount,
                paid: false,
                failureReason: bill.failureReason,
                failureCode: bill.failureCode,
            });
        }
        
        // Check if QR has expired
        if (bill.qrExpiresAt && new Date(bill.qrExpiresAt) < new Date()) {
            if (bill.paymentStatus === 'PENDING') {
                // Update status to EXPIRED
                await docClient.send(new UpdateCommand({
                    TableName: TABLE_NAMES.BILLS,
                    Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
                    UpdateExpression: 'SET paymentStatus = :status, updatedAt = :now, GSI3PK = :gsi3pk',
                    ExpressionAttributeValues: {
                        ':status': 'EXPIRED' as PaymentStatus,
                        ':now': new Date().toISOString(),
                        ':gsi3pk': PaymentKeys.gsi3Status('EXPIRED'),
                    },
                }));
                
                return successResponse({
                    success: true,
                    billId,
                    status: 'EXPIRED',
                    amount: bill.totalAmount,
                    paid: false,
                    qrExpiresAt: bill.qrExpiresAt,
                });
            }
        }
        
        // If no Razorpay order yet, return current status
        if (!bill.razorpayOrderId) {
            return successResponse({
                success: true,
                billId,
                status: bill.paymentStatus,
                amount: bill.totalAmount,
                paid: false,
            });
        }
        
        // Check with Razorpay for latest status
        console.log(`[${requestId}] Checking Razorpay order: ${bill.razorpayOrderId}`);
        
        try {
            const order = await getRazorpayOrder(bill.razorpayOrderId);
            
            // If order is paid
            if (order.status === 'paid' || order.amount_paid >= order.amount_due) {
                // Get payment details
                const payments = await getRazorpayPaymentsForOrder(bill.razorpayOrderId);
                const capturedPayment = payments.find(p => p.status === 'captured');
                
                if (capturedPayment) {
                    // Update bill to PAID
                    await updateBillToPaid(billId, capturedPayment.id, capturedPayment.method);
                    
                    console.log(`[${requestId}] Payment confirmed via poll: ${capturedPayment.id}`);
                    
                    return successResponse({
                        success: true,
                        billId,
                        status: 'PAID',
                        amount: bill.totalAmount,
                        paid: true,
                        paidAt: new Date().toISOString(),
                        paymentId: capturedPayment.id,
                        paymentMode: bill.paymentMode,
                        paymentMethod: capturedPayment.method,
                    });
                }
            }
            
            // Order is still pending
            return successResponse({
                success: true,
                billId,
                status: 'PENDING',
                amount: bill.totalAmount,
                paid: false,
                qrExpiresAt: bill.qrExpiresAt,
            });
            
        } catch (error) {
            const axiosError = error as AxiosError;
            console.error(`[${requestId}] Razorpay API error:`, axiosError.response?.status, axiosError.message);
            
            // Return cached status on Razorpay error
            return successResponse({
                success: true,
                billId,
                status: bill.paymentStatus,
                amount: bill.totalAmount,
                paid: false,
                qrExpiresAt: bill.qrExpiresAt,
            });
        }
        
    } catch (error) {
        console.error(`[${requestId}] Unexpected error:`, error);
        return errorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
    }
};

export default handler;
