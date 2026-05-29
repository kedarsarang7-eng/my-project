import { config } from '../../config/environment';
// ============================================================================
// Lambda: createMerchantLinkedAccount
// Purpose: Create Razorpay Linked Account for business owner onboarding
// Route: POST /billing/merchants/onboard
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import axios, { AxiosError } from 'axios';
import { v4 as uuidv4 } from 'uuid';
import { docClient, TABLE_NAMES, PaymentKeys, BusinessOwner, BusinessType } from '../../config/payment-tables.config';
import { GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { createHmac } from 'crypto';

// ============================================================================
// Environment Configuration
// ============================================================================

const RAZORPAY_KEY_ID = config.payment.razorpay.keyId || '';
const RAZORPAY_KEY_SECRET = config.payment.razorpay.keySecret || '';
const RAZORPAY_BASE_URL = 'https://api.razorpay.com/v1';

// ============================================================================
// Type Definitions
// ============================================================================

interface CreateMerchantRequest {
    businessId: string;
    ownerId: string;
    businessName: string;
    businessType: BusinessType;
    email: string;
    phone: string;
    legalName: string;
    gstNumber?: string;
    bankAccountNumber?: string;
    ifscCode?: string;
}

interface CreateMerchantResponse {
    success: boolean;
    linkedAccountId?: string;
    accountStatus?: string;
    message: string;
    businessId: string;
}

interface RazorpayAccountResponse {
    id: string;
    status: 'created' | 'active' | 'suspended';
    email: string;
    phone: string;
    legal_name?: string;
}

interface RazorpayStakeholderResponse {
    id: string;
    status: string;
}

interface RazorpayError {
    error: {
        code: string;
        description: string;
        source?: string;
        step?: string;
        reason?: string;
    };
}

// ============================================================================
// Utility Functions
// ============================================================================

function createRazorpayAuth(): string {
    return Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64');
}

function hashBankAccount(accountNumber: string): string {
    return createHmac('sha256', RAZORPAY_KEY_SECRET || 'fallback-secret')
        .update(accountNumber)
        .digest('hex');
}

function logRazorpayCall(
    operation: string,
    request: unknown,
    response: unknown,
    error?: AxiosError<RazorpayError>
): void {
    const timestamp = new Date().toISOString();
    const logEntry = {
        timestamp,
        operation,
        request: sanitizeLog(request),
        response: error ? undefined : sanitizeLog(response),
        error: error ? {
            code: error.response?.data?.error?.code,
            description: error.response?.data?.error?.description,
            status: error.response?.status,
        } : undefined,
    };
    console.log('[RAZORPAY_API]', JSON.stringify(logEntry));
}

function sanitizeLog(data: unknown): unknown {
    if (!data || typeof data !== 'object') return data;
    
    const sensitive = ['bankAccountNumber', 'account_number', 'ifscCode', 'secret', 'key_secret', 'password'];
    const sanitized = { ...data as Record<string, unknown> };
    
    for (const key of Object.keys(sanitized)) {
        if (sensitive.some(s => key.toLowerCase().includes(s.toLowerCase()))) {
            sanitized[key] = '[REDACTED]';
        } else if (typeof sanitized[key] === 'object') {
            sanitized[key] = sanitizeLog(sanitized[key]);
        }
    }
    
    return sanitized;
}

function validatePhone(phone: string): boolean {
    return /^[6-9]\d{9}$/.test(phone);
}

function validateEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function validateIFSC(ifsc: string): boolean {
    return /^[A-Z]{4}0[A-Z0-9]{6}$/.test(ifsc);
}

// ============================================================================
// Razorpay API Functions
// ============================================================================

async function createRazorpayLinkedAccount(
    legalName: string,
    email: string,
    phone: string
): Promise<RazorpayAccountResponse> {
    const url = `${RAZORPAY_BASE_URL}/accounts`;
    const payload = {
        legal_name: legalName,
        email,
        phone,
        type: 'standard',
    };
    
    try {
        const response = await axios.post<RazorpayAccountResponse>(url, payload, {
            headers: {
                'Authorization': `Basic ${createRazorpayAuth()}`,
                'Content-Type': 'application/json',
            },
        });
        
        logRazorpayCall('CREATE_ACCOUNT', payload, response.data);
        return response.data;
    } catch (error) {
        const axiosError = error as AxiosError<RazorpayError>;
        logRazorpayCall('CREATE_ACCOUNT', payload, null, axiosError);
        throw error;
    }
}

async function addBankAccountToStakeholder(
    accountId: string,
    bankAccountNumber: string,
    ifscCode: string
): Promise<RazorpayStakeholderResponse> {
    const url = `${RAZORPAY_BASE_URL}/accounts/${accountId}/stakeholders`;
    const payload = {
        email: 'stakeholder@business.com', // Required by API
        phone: '9999999999', // Required by API
        legal_name: 'Business Owner',
        type: 'individual',
        bank_account: {
            account_number: bankAccountNumber,
            ifsc_code: ifscCode,
        },
    };
    
    try {
        const response = await axios.post<RazorpayStakeholderResponse>(url, payload, {
            headers: {
                'Authorization': `Basic ${createRazorpayAuth()}`,
                'Content-Type': 'application/json',
            },
        });
        
        logRazorpayCall('ADD_BANK_ACCOUNT', payload, response.data);
        return response.data;
    } catch (error) {
        const axiosError = error as AxiosError<RazorpayError>;
        logRazorpayCall('ADD_BANK_ACCOUNT', payload, null, axiosError);
        throw error;
    }
}

// ============================================================================
// DynamoDB Functions
// ============================================================================

async function getBusinessOwner(businessId: string): Promise<BusinessOwner | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAMES.BUSINESS_OWNERS,
        Key: {
            PK: PaymentKeys.businessPK(businessId),
            SK: PaymentKeys.businessSK(),
        },
    }));
    return result.Item as BusinessOwner | null;
}

async function saveBusinessOwner(owner: BusinessOwner): Promise<void> {
    await docClient.send(new PutCommand({
        TableName: TABLE_NAMES.BUSINESS_OWNERS,
        Item: owner,
    }));
}

// ============================================================================
// Validation
// ============================================================================

function validateRequest(body: CreateMerchantRequest): string | null {
    const required = ['businessId', 'ownerId', 'businessName', 'businessType', 'email', 'phone', 'legalName'];
    
    for (const field of required) {
        if (!body[field as keyof CreateMerchantRequest]) {
            return `Missing required field: ${field}`;
        }
    }
    
    if (!validateEmail(body.email)) {
        return 'Invalid email format';
    }
    
    if (!validatePhone(body.phone)) {
        return 'Invalid phone number. Must be 10 digits starting with 6-9';
    }
    
    if (body.bankAccountNumber && body.ifscCode) {
        if (!validateIFSC(body.ifscCode)) {
            return 'Invalid IFSC code format (e.g., SBIN0001234)';
        }
        if (body.bankAccountNumber.length < 9 || body.bankAccountNumber.length > 18) {
            return 'Invalid bank account number length';
        }
    }
    
    return null;
}

// ============================================================================
// Response Helpers
// ============================================================================

function successResponse(data: CreateMerchantResponse): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify(data),
    };
}

function errorResponse(statusCode: number, message: string, errorCode?: string): APIGatewayProxyResult {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({
            success: false,
            error: message,
            errorCode,
        }),
    };
}

// ============================================================================
// Main Handler
// ============================================================================

export const handler = async (
    event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    console.log(`[${requestId}] Merchant onboarding request received`);
    
    try {
        // Parse request body
        if (!event.body) {
            return errorResponse(400, 'Request body is required');
        }
        
        let body: CreateMerchantRequest;
        try {
            body = JSON.parse(event.body);
        } catch {
            return errorResponse(400, 'Invalid JSON in request body');
        }
        
        // Validate request
        const validationError = validateRequest(body);
        if (validationError) {
            return errorResponse(400, validationError, 'VALIDATION_ERROR');
        }
        
        // Check if Razorpay credentials are configured
        if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
            console.error(`[${requestId}] Razorpay credentials not configured`);
            return errorResponse(500, 'Payment gateway not configured', 'CONFIG_ERROR');
        }
        
        // Check for existing account (idempotency)
        const existingOwner = await getBusinessOwner(body.businessId);
        
        if (existingOwner?.razorpayLinkedAccountId) {
            console.log(`[${requestId}] Existing linked account found: ${existingOwner.razorpayLinkedAccountId}`);
            return successResponse({
                success: true,
                linkedAccountId: existingOwner.razorpayLinkedAccountId,
                accountStatus: existingOwner.razorpayAccountStatus,
                message: 'Merchant already onboarded',
                businessId: body.businessId,
            });
        }
        
        // Create Razorpay Linked Account
        console.log(`[${requestId}] Creating Razorpay linked account for ${body.legalName}`);
        
        let razorpayAccount: RazorpayAccountResponse;
        try {
            razorpayAccount = await createRazorpayLinkedAccount(
                body.legalName,
                body.email,
                body.phone
            );
        } catch (error) {
            const axiosError = error as AxiosError<RazorpayError>;
            const errorCode = axiosError.response?.data?.error?.code || 'UNKNOWN_ERROR';
            const errorDesc = axiosError.response?.data?.error?.description || 'Failed to create linked account';
            
            console.error(`[${requestId}] Razorpay account creation failed:`, errorCode, errorDesc);
            return errorResponse(502, errorDesc, errorCode);
        }
        
        // Add bank account if provided
        let bankVerified = false;
        if (body.bankAccountNumber && body.ifscCode) {
            console.log(`[${requestId}] Adding bank account to linked account`);
            try {
                await addBankAccountToStakeholder(
                    razorpayAccount.id,
                    body.bankAccountNumber,
                    body.ifscCode
                );
                bankVerified = true;
            } catch (error) {
                const axiosError = error as AxiosError<RazorpayError>;
                console.warn(`[${requestId}] Bank account addition failed (non-critical):`, 
                    axiosError.response?.data?.error?.description);
                // Don't fail onboarding if bank addition fails - can retry later
            }
        }
        
        // Save to DynamoDB
        const now = new Date().toISOString();
        const businessOwner: BusinessOwner = {
            PK: PaymentKeys.businessPK(body.businessId),
            SK: PaymentKeys.businessSK(),
            businessId: body.businessId,
            tenantId: body.businessId.split('-')[0] || body.businessId, // Extract tenant from businessId
            ownerId: body.ownerId,
            businessName: body.businessName,
            businessType: body.businessType,
            email: body.email,
            phone: body.phone,
            razorpayLinkedAccountId: razorpayAccount.id,
            razorpayAccountStatus: 'active',
            bankVerified,
            onboardingComplete: true,
            bankAccountNumberHash: body.bankAccountNumber ? hashBankAccount(body.bankAccountNumber) : undefined,
            ifscCode: body.ifscCode,
            createdAt: existingOwner?.createdAt || now,
            updatedAt: now,
            GSI1PK: PaymentKeys.gsi1Owner(body.ownerId),
            GSI1SK: PaymentKeys.gsi1Date(now),
        };
        
        await saveBusinessOwner(businessOwner);
        
        console.log(`[${requestId}] Merchant onboarding completed successfully: ${razorpayAccount.id}`);
        
        return successResponse({
            success: true,
            linkedAccountId: razorpayAccount.id,
            accountStatus: 'active',
            message: bankVerified 
                ? 'Merchant onboarded successfully with bank account' 
                : 'Merchant onboarded successfully. Add bank account to receive payouts.',
            businessId: body.businessId,
        });
        
    } catch (error) {
        console.error(`[${requestId}] Unexpected error:`, error);
        return errorResponse(500, 'Internal server error', 'INTERNAL_ERROR');
    }
};

export default handler;
