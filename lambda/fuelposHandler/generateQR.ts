import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { QRGenerateSchema, validateSchema, sanitizeObject } from '../shared/schemas.mjs';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Tenant-Id',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

interface LicenseProfile {
  userId: string;
  tenantId: string;
  businessType: string;
  stationId: string;
  ownerId: string;
  razorpayLinkedAccountId?: string;
}

interface RazorpayOrderResponse {
  id: string;
  amount: number;
  currency: string;
  status: string;
}

/**
 * Validate user access and return license profile
 */
async function validateUserAccess(userId: string, stationId: string): Promise<LicenseProfile | null> {
  const licenseTable = process.env.DYNAMODB_TABLE_LICENSE || 'FuelPOS_LicenseProfiles';

  try {
    const result = await docClient.send(
      new GetCommand({
        TableName: licenseTable,
        Key: {
          PK: `USER#${userId}`,
          SK: 'LICENSE',
        },
      })
    );

    if (!result.Item) return null;

    const profile = result.Item as LicenseProfile;

    // Validate business type
    if (profile.businessType !== 'petrol_pump') {
      console.warn(`User ${userId} has business type ${profile.businessType}`);
      return null;
    }

    // Validate station access
    if (profile.stationId !== stationId) {
      console.warn(`User ${userId} attempted access to station ${stationId}, owns ${profile.stationId}`);
      return null;
    }

    return profile;
  } catch (error) {
    console.error('Error validating user access:', error);
    return null;
  }
}

/**
 * Get owner's Razorpay linked account ID
 */
async function getOwnerRazorpayAccount(ownerId: string): Promise<string | null> {
  const tableName = process.env.DYNAMODB_TABLE_OWNERS || 'FuelPOS_Owners';

  try {
    const result = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: {
          PK: `OWNER#${ownerId}`,
          SK: 'RAZORPAY_ACCOUNT',
        },
      })
    );

    return result.Item?.linkedAccountId || null;
  } catch (error) {
    console.error('Error fetching Razorpay account:', error);
    return null;
  }
}

/**
 * Create Razorpay order for the linked account
 */
async function createRazorpayOrder(
  amount: number,
  linkedAccountId: string,
  transactionId: string
): Promise<RazorpayOrderResponse | null> {
  try {
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keyId || !keySecret) {
      console.error('Razorpay credentials not configured');
      return null;
    }

    const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');

    const response = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${auth}`,
      },
      body: JSON.stringify({
        amount: Math.round(amount * 100), // Convert to paise
        currency: 'INR',
        receipt: transactionId,
        transfers: [
          {
            account: linkedAccountId,
            amount: Math.round(amount * 100),
            currency: 'INR',
            on_hold: 0,
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Razorpay API error:', errorText);
      return null;
    }

    return await response.json();
  } catch (error) {
    console.error('Error creating Razorpay order:', error);
    return null;
  }
}

/**
 * Create pending transaction record
 */
async function createPendingTransaction(
  transactionId: string,
  stationId: string,
  staffId: string,
  ownerId: string,
  amount: number,
  vehicleNumber: string,
  fuelType: string,
  liters: number,
  razorpayOrderId: string
): Promise<boolean> {
  const tableName = process.env.DYNAMODB_TABLE_TRANSACTIONS || 'FuelPOS_Transactions';
  const now = new Date();
  const date = now.toISOString().split('T')[0];
  const ttl = Math.floor(now.getTime() / 1000) + (10 * 60); // 10 minutes expiry

  try {
    await docClient.send(
      new PutCommand({
        TableName: tableName,
        Item: {
          PK: `STATION#${stationId}`,
          SK: `TXN#${date}#${transactionId}`,
          transactionId,
          stationId,
          tenantId: `TENANT#${stationId}`,
          date,
          timestamp: now.toISOString(),
          vehicleNumber: vehicleNumber || 'Unknown',
          fuelType: fuelType || 'Unknown',
          liters: liters || 0,
          amount,
          status: 'PENDING',
          staffId,
          ownerId,
          razorpayOrderId,
          pendingTTL: ttl,
          GSI2PK: `RAZORPAY#ORDER#${razorpayOrderId}`,
          GSI2SK: `TXN#${transactionId}`, // For TTL cleanup
          GSI1PK: `DATE#${date}#${stationId}`,
          GSI1SK: `${now.toTimeString().slice(0, 5)}#${transactionId}`,
        },
      })
    );
    return true;
  } catch (error) {
    console.error('Error creating transaction:', error);
    return false;
  }
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  try {
    // Extract user from JWT
    const authorizerContext = event.requestContext?.authorizer?.jwt;
    const claims = authorizerContext?.claims;

    if (!claims || !claims.sub) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Unauthorized - Valid JWT required' }),
      };
    }

    const userId = claims.sub;
    const stationId = event.queryStringParameters?.stationId;

    if (!stationId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'stationId query parameter is required' }),
      };
    }

    // Validate user access
    const licenseProfile = await validateUserAccess(userId, stationId);
    if (!licenseProfile) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Forbidden - Invalid station access' }),
      };
    }

    // Parse and validate request body with Zod
    let parsedBody;
    try {
      parsedBody = JSON.parse(event.body || '{}');
    } catch {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Invalid JSON in request body' }),
      };
    }

    // Sanitize inputs to prevent XSS
    const sanitizedBody = sanitizeObject(parsedBody);

    // Validate with Zod schema
    const validation = validateSchema(QRGenerateSchema, sanitizedBody);
    if (!validation.success) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Validation failed',
          details: validation.errors,
        }),
      };
    }

    const body = validation.data;

    // Get owner's Razorpay linked account
    const linkedAccountId = licenseProfile.razorpayLinkedAccountId ||
                           await getOwnerRazorpayAccount(licenseProfile.ownerId || userId);

    if (!linkedAccountId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Payment account not configured for this station' }),
      };
    }

    // Generate transaction ID
    const transactionId = randomUUID();

    // Create Razorpay order
    const razorpayOrder = await createRazorpayOrder(
      body.amount,
      linkedAccountId,
      transactionId
    );

    if (!razorpayOrder) {
      return {
        statusCode: 502,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Failed to create payment order' }),
      };
    }

    // Create pending transaction
    const created = await createPendingTransaction(
      transactionId,
      stationId,
      userId,
      licenseProfile.ownerId || userId,
      body.amount,
      body.vehicleNumber || '',
      body.fuelType || 'Petrol',
      body.liters || 0,
      razorpayOrder.id
    );

    if (!created) {
      return {
        statusCode: 500,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Failed to create transaction record' }),
      };
    }

    // Return QR code data
    return {
      statusCode: 201,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: {
          transactionId,
          qrData: {
            orderId: razorpayOrder.id,
            amount: body.amount,
            currency: 'INR',
            expiryMinutes: 10,
          },
          // QR code can be generated client-side using this data
          paymentUrl: `upi://pay?pa=${linkedAccountId}&pn=FuelStation&am=${body.amount}&tr=${razorpayOrder.id}&cu=INR`,
        },
        meta: {
          stationId,
          staffId: userId,
          expiresAt: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
        },
      }),
    };
  } catch (error) {
    console.error('QR generation error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
};
