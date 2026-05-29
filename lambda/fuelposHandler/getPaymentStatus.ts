import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Tenant-Id',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

interface LicenseProfile {
  userId: string;
  tenantId: string;
  businessType: string;
  stationId: string;
}

async function validateUserAccess(userId: string, stationId: string): Promise<LicenseProfile | null> {
  const licenseTable = process.env.DYNAMODB_TABLE_LICENSE || 'FuelPOS_LicenseProfiles';

  try {
    const { GetCommand } = await import('@aws-sdk/lib-dynamodb');
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

    if (profile.stationId !== stationId || profile.businessType !== 'petrol_pump') {
      return null;
    }

    return profile;
  } catch (error) {
    console.error('Error validating user access:', error);
    return null;
  }
}

async function getTransactionByOrderId(orderId: string, stationId: string): Promise<any | null> {
  const tableName = process.env.DYNAMODB_TABLE_TRANSACTIONS || 'FuelPOS_Transactions';

  try {
    // First try to query by order ID using GSI if available
    const { QueryCommand } = await import('@aws-sdk/lib-dynamodb');
    const result = await docClient.send(
      new QueryCommand({
        TableName: tableName,
        IndexName: 'GSI_OrderId',
        KeyConditionExpression: 'razorpayOrderId = :orderId',
        ExpressionAttributeValues: {
          ':orderId': orderId,
        },
        Limit: 1,
      })
    );

    if (result.Items && result.Items.length > 0) {
      return result.Items[0];
    }

    // Fallback: Scan by PK prefix if GSI not available
    const { ScanCommand } = await import('@aws-sdk/lib-dynamodb');
    const scanResult = await docClient.send(
      new ScanCommand({
        TableName: tableName,
        FilterExpression: 'razorpayOrderId = :orderId AND PK = :pk',
        ExpressionAttributeValues: {
          ':orderId': orderId,
          ':pk': `STATION#${stationId}`,
        },
        Limit: 1,
      })
    );

    return scanResult.Items?.[0] || null;
  } catch (error) {
    console.error('Error fetching transaction:', error);
    return null;
  }
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  try {
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
    const orderId = event.pathParameters?.orderId;
    const stationId = event.queryStringParameters?.stationId;

    if (!orderId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'orderId path parameter is required' }),
      };
    }

    if (!stationId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'stationId query parameter is required' }),
      };
    }

    // Validate access
    const licenseProfile = await validateUserAccess(userId, stationId);
    if (!licenseProfile) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Forbidden - Invalid station access' }),
      };
    }

    // Get transaction
    const transaction = await getTransactionByOrderId(orderId, stationId);

    if (!transaction) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Transaction not found' }),
      };
    }

    // Check if expired
    const isExpired = transaction.pendingTTL && transaction.pendingTTL < Math.floor(Date.now() / 1000);
    const status = isExpired && transaction.status === 'PENDING' ? 'EXPIRED' : transaction.status;

    return {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: {
          transactionId: transaction.transactionId,
          orderId: transaction.razorpayOrderId,
          status,
          amount: transaction.amount,
          vehicleNumber: transaction.vehicleNumber,
          fuelType: transaction.fuelType,
          liters: transaction.liters,
          createdAt: transaction.timestamp,
          paidAt: transaction.status === 'PAID' ? transaction.updatedAt : null,
          isExpired,
        },
        meta: {
          stationId,
          polledAt: new Date().toISOString(),
        },
      }),
    };
  } catch (error) {
    console.error('Payment status error:', error);
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
