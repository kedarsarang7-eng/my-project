import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withRetry } from '../shared/utils.mjs';
import { PaginationSchema, validateSchema, sanitizeObject } from '../shared/schemas.mjs';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Tenant-Id',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

interface StaffTransaction {
  transactionId: string;
  date: string;
  time: string;
  vehicleNumber: string;
  fuelType: string;
  liters: number;
  amount: number;
  status: string;
  pumpNumber?: string;
}

async function getStaffTransactions(
  staffId: string,
  stationId: string,
  date: string,
  limit: number,
  lastKey?: Record<string, unknown>
): Promise<{ transactions: StaffTransaction[]; lastEvaluatedKey?: Record<string, unknown> }> {
  const tableName = process.env.DYNAMODB_TABLE_TRANSACTIONS || 'FuelPOS_Transactions';

  return withRetry(async () => {
    const result = await docClient.send(
      new QueryCommand({
        TableName: tableName,
        IndexName: 'GSI_DateRange',
        KeyConditionExpression: 'GSI1PK = :pk',
        FilterExpression: 'staffId = :staffId',
        ExpressionAttributeValues: {
          ':pk': `DATE#${date}#${stationId}`,
          ':staffId': staffId,
        },
        ScanIndexForward: false,
        Limit: limit,
        ExclusiveStartKey: lastKey,
      })
    );

    const transactions: StaffTransaction[] = (result.Items || []).map((item) => ({
      transactionId: item.transactionId,
      date: item.date,
      time: item.timestamp ? new Date(item.timestamp).toLocaleTimeString('en-IN', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
        timeZone: 'Asia/Kolkata',
      }) : '-',
      vehicleNumber: item.vehicleNumber || '-',
      fuelType: item.fuelType || '-',
      liters: Math.round((item.liters || 0) * 10) / 10,
      amount: Math.round((item.amount || 0) * 100) / 100,
      status: item.status || 'UNKNOWN',
      pumpNumber: item.pumpNumber,
    }));

    return {
      transactions,
      lastEvaluatedKey: result.LastEvaluatedKey,
    };
  });
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

    const staffId = claims.sub;
    const stationId = event.queryStringParameters?.stationId;
    const date = event.queryStringParameters?.date || new Date().toISOString().split('T')[0];

    if (!stationId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'stationId query parameter is required' }),
      };
    }

    // Validate pagination params
    const paginationValidation = validateSchema(
      PaginationSchema,
      sanitizeObject(event.queryStringParameters || {})
    );

    const limit = paginationValidation.success ? paginationValidation.data.limit : 10;
    const { transactions, lastEvaluatedKey } = await getStaffTransactions(
      staffId,
      stationId,
      date,
      limit
    );

    // Calculate staff totals
    const totalAmount = transactions
      .filter((t) => t.status === 'PAID')
      .reduce((sum, t) => sum + t.amount, 0);
    const totalTransactions = transactions.length;
    const paidTransactions = transactions.filter((t) => t.status === 'PAID').length;

    return {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: {
          transactions,
          summary: {
            totalAmount,
            totalTransactions,
            paidTransactions,
            pendingTransactions: totalTransactions - paidTransactions,
          },
        },
        meta: {
          staffId,
          stationId,
          date,
          hasMore: !!lastEvaluatedKey,
          lastEvaluatedKey,
        },
      }),
    };
  } catch (error) {
    console.error('Staff transactions error:', error);
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
