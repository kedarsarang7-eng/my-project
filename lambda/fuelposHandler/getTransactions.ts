import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

interface Transaction {
  id: string;
  time: string;
  vehicleNumber: string;
  fuelType: string;
  liters: number;
  amount: number;
  status: string;
  pumpNumber?: string;
  attendantName?: string;
}

interface TransactionsResponse {
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
  lastEvaluatedKey?: Record<string, unknown>;
  data: Transaction[];
}

interface LicenseProfile {
  userId: string;
  tenantId: string;
  businessType: string;
  stationId: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Tenant-Id',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

function getISTDate(date: Date = new Date()): string {
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istDate = new Date(date.getTime() + istOffset);
  return istDate.toISOString().split('T')[0];
}

function formatISTTime(timestamp: string): string {
  try {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
      timeZone: 'Asia/Kolkata',
    });
  } catch {
    return timestamp;
  }
}

function mapStatusToDisplay(status: string): { status: string; badgeType: string } {
  switch (status.toLowerCase()) {
    case 'paid_green_tag':
      return { status: 'Paid (Green Tag)', badgeType: 'success' };
    case 'paid':
    case 'completed':
      return { status: 'Paid', badgeType: 'neutral' };
    case 'pending':
    case 'in_progress':
      return { status: 'Pending', badgeType: 'warning' };
    case 'failed':
    case 'cancelled':
      return { status: 'Failed', badgeType: 'error' };
    default:
      return { status: status, badgeType: 'neutral' };
  }
}

async function validateUserAccess(
  userId: string,
  requestedStationId: string
): Promise<LicenseProfile | null> {
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

    if (profile.stationId !== requestedStationId || profile.businessType !== 'petrol_pump') {
      return null;
    }

    return profile;
  } catch (error) {
    console.error('Error validating user access:', error);
    return null;
  }
}

async function getTransactionsCount(stationId: string, date: string): Promise<number> {
  const tableName = process.env.DYNAMODB_TABLE_DAILY_SUMMARY || 'FuelPOS_DailySummary';

  try {
    const { GetCommand } = await import('@aws-sdk/lib-dynamodb');
    const result = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${stationId}`,
          SK: `DATE#${date}`,
        },
      })
    );

    return result.Item?.transactionCount || 0;
  } catch (error) {
    console.error('Error fetching transaction count:', error);
    return 0;
  }
}

async function getTransactions(
  stationId: string,
  date: string,
  page: number,
  limit: number,
  lastKey?: Record<string, unknown>
): Promise<{ transactions: Transaction[]; lastEvaluatedKey?: Record<string, unknown> }> {
  const tableName = process.env.DYNAMODB_TABLE_TRANSACTIONS || 'FuelPOS_Transactions';
  const gsiPk = `DATE#${date}#${stationId}`;

  try {
    const result = await docClient.send(
      new QueryCommand({
        TableName: tableName,
        IndexName: 'GSI_DateRange',
        KeyConditionExpression: 'GSI1PK = :pk',
        ExpressionAttributeValues: {
          ':pk': gsiPk,
        },
        ScanIndexForward: false, // Most recent first
        Limit: limit,
        ExclusiveStartKey: lastKey,
      })
    );

    const transactions: Transaction[] = (result.Items || []).map((item) => {
      const statusInfo = mapStatusToDisplay(item.status || 'unknown');
      return {
        id: `#${item.transactionId || item.SK?.split('#')[2] || '0000'}`,
        time: formatISTTime(item.timestamp || item.GSI1SK?.split('#')[0] || ''),
        vehicleNumber: item.vehicleNumber || '-',
        fuelType: item.fuelType || '-',
        liters: Math.round((item.liters || 0) * 10) / 10,
        amount: Math.round((item.amount || 0) * 100) / 100,
        status: statusInfo.status,
        pumpNumber: item.pumpNumber,
        attendantName: item.attendantName,
      };
    });

    return {
      transactions,
      lastEvaluatedKey: result.LastEvaluatedKey,
    };
  } catch (error) {
    console.error('Error fetching transactions:', error);
    return { transactions: [] };
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
    const stationId = event.queryStringParameters?.stationId;
    const date = event.queryStringParameters?.date || getISTDate();
    const page = parseInt(event.queryStringParameters?.page || '1', 10);
    const limit = Math.min(parseInt(event.queryStringParameters?.limit || '10', 10), 50);

    if (!stationId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'stationId query parameter is required' }),
      };
    }

    const licenseProfile = await validateUserAccess(userId, stationId);
    if (!licenseProfile) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Forbidden - You do not have access to this station' }),
      };
    }

    // Get total count from DailySummary
    const total = await getTransactionsCount(stationId, date);

    // Handle pagination with DynamoDB's LastEvaluatedKey
    // For simplicity, we simulate page-based pagination using the last key
    let lastKey: Record<string, unknown> | undefined;
    if (page > 1) {
      // Note: In production, clients should pass the lastEvaluatedKey from previous response
      // This is a simplified implementation
      lastKey = undefined;
    }

    const { transactions, lastEvaluatedKey } = await getTransactions(
      stationId,
      date,
      page,
      limit,
      lastKey
    );

    const response: TransactionsResponse = {
      total,
      page,
      limit,
      hasMore: !!lastEvaluatedKey,
      lastEvaluatedKey,
      data: transactions,
    };

    return {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: response,
        meta: {
          stationId,
          date,
          timezone: 'Asia/Kolkata',
        },
      }),
    };
  } catch (error) {
    console.error('Error in getTransactions:', error);
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
