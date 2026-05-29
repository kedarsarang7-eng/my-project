// ============================================================================
// Lambda: processCashPayment
// Purpose: Process immediate cash payments without Razorpay
// Route: POST /billing/payment/cash (Cognito protected)
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import {
    docClient, TABLE_NAMES, PaymentKeys, Bill, PaymentEvent, PaymentStatus
} from '../../config/payment-tables.config';
import { GetCommand, PutCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';

// ============================================================================
// Type Definitions
// ============================================================================

interface CashPaymentRequest {
    billId: string;
    businessId: string;
    amountReceived: number;
    changeGiven?: number;
    staffId: string;
    notes?: string;
}

interface CashPaymentResponse {
    success: boolean;
    billId: string;
    paymentId: string;
    status: PaymentStatus;
    amount: number;
    change: number;
    paidAt: string;
}

interface CognitoClaims {
    sub: string;
    'custom:businessId'?: string;
    'custom:role'?: string;
}

// ============================================================================
// Utility Functions
// ============================================================================

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
            'Cache-Control': 'no-store',
        },
        body: JSON.stringify({ success: false, error: message, errorCode }),
    };
}

function successResponse(data: CashPaymentResponse): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
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

async function processCashPaymentInDB(
    billId: string,
    amountReceived: number,
    changeGiven: number,
    staffId: string,
    notes?: string
): Promise<string> {
    const paymentId = `CASH-${uuidv4().slice(0, 8).toUpperCase()}`;
    const now = new Date().toISOString();
    
    // Update bill
    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
        UpdateExpression: `SET paymentStatus = :status, razorpayPaymentId = :paymentId, 
            paidAt = :now, updatedAt = :now, GSI3PK = :gsi3pk, paymentMode = :mode, 
            actualPaymentMethod = :method, cashAmountReceived = :received, 
            cashChangeGiven = :change, staffId = :staff, notes = :notes`,
        ExpressionAttributeValues: {
            ':status': 'PAID' as PaymentStatus,
            ':paymentId': paymentId,
            ':now': now,
            ':gsi3pk': PaymentKeys.gsi3Status('PAID'),
            ':mode': 'CASH' as const,
            ':method': 'cash',
            ':received': amountReceived,
            ':change': changeGiven,
            ':staff': staffId,
            ':notes': notes || '',
        },
    }));
    
    // Log payment event
    const event: PaymentEvent = {
        PK: PaymentKeys.eventPK(uuidv4()),
        SK: PaymentKeys.eventSK(billId),
        eventId: paymentId,
        billId,
        eventType: 'CAPTURED',
        processedAt: now,
        processedBy: staffId,
        TTL: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60),
        GSI1PK: PaymentKeys.gsi1EventBill(billId),
        GSI1SK: PaymentKeys.gsi1EventTime(now),
        rawPayload: {
            amountReceived,
            changeGiven,
            staffId,
            notes,
            paymentMode: 'CASH',
        },
    };
    
    await docClient.send(new PutCommand({
        TableName: TABLE_NAMES.PAYMENT_EVENTS,
        Item: event,
    }));
    
    return paymentId;
}

// ============================================================================
// Main Handler
// ============================================================================

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    console.log(`[${requestId}] Cash payment request received`);
    
    try {
        // Verify Cognito authentication
        const claims = getCognitoClaims(event);
        if (!claims) {
            return errorResponse(401, 'Unauthorized');
        }
        
        // Parse request body
        if (!event.body) {
            return errorResponse(400, 'Request body is required');
        }
        
        let body: CashPaymentRequest;
        try {
            body = JSON.parse(event.body);
        } catch {
            return errorResponse(400, 'Invalid JSON in request body');
        }
        
        // Validate required fields
        if (!body.billId || !body.businessId || !body.amountReceived || !body.staffId) {
            return errorResponse(400, 'Missing required fields: billId, businessId, amountReceived, staffId');
        }
        
        // Validate business ID matches JWT
        const jwtBusinessId = claims['custom:businessId'];
        if (jwtBusinessId && jwtBusinessId !== body.businessId) {
            return errorResponse(403, 'Business ID mismatch');
        }
        
        // Validate amount
        if (body.amountReceived <= 0) {
            return errorResponse(400, 'Amount received must be positive');
        }
        
        // Fetch bill
        const bill = await getBill(body.billId);
        if (!bill) {
            return errorResponse(404, 'Bill not found', 'BILL_NOT_FOUND');
        }
        
        // Verify bill belongs to business
        if (bill.businessId !== body.businessId) {
            return errorResponse(403, 'Bill does not belong to this business');
        }
        
        // Check if already paid
        if (bill.paymentStatus === 'PAID') {
            return errorResponse(409, 'Bill is already paid', 'ALREADY_PAID');
        }
        
        // Calculate change
        const changeGiven = body.changeGiven ?? Math.max(0, body.amountReceived - bill.totalAmount);
        
        // Verify sufficient amount received
        if (body.amountReceived < bill.totalAmount && changeGiven > 0) {
            return errorResponse(400, 'Insufficient amount received', 'INSUFFICIENT_AMOUNT');
        }
        
        // Process cash payment
        console.log(`[${requestId}] Processing cash payment for bill ${body.billId}`);
        
        const paymentId = await processCashPaymentInDB(
            body.billId,
            body.amountReceived,
            changeGiven,
            body.staffId,
            body.notes
        );
        
        console.log(`[${requestId}] Cash payment processed: ${paymentId}`);
        
        return successResponse({
            success: true,
            billId: body.billId,
            paymentId,
            status: 'PAID',
            amount: bill.totalAmount,
            change: changeGiven,
            paidAt: new Date().toISOString(),
        });
        
    } catch (error) {
        console.error(`[${requestId}] Unexpected error:`, error);
        return errorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
    }
};

export default handler;
