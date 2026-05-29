import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withRetry } from '../shared/utils.mjs';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Tenant-Id',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

interface StaffRevenue {
  staffId: string;
  staffName: string;
  totalSales: number;
  transactionCount: number;
  paidTransactions: number;
  pendingTransactions: number;
}

interface OwnerDashboardData {
  todaySales: number;
  totalTransactions: number;
  paidTransactions: number;
  pendingTransactions: number;
  revenueByStaff: StaffRevenue[];
  recentTransactions: any[];
  fuelSold: {
    petrol: { liters: number; amount: number };
    diesel: { liters: number; amount: number };
  };
}

async function getOwnerLicenseProfile(userId: string) {
  const licenseTable = process.env.DYNAMODB_TABLE_LICENSE || 'FuelPOS_LicenseProfiles';

  return withRetry(async () => {
    const result = await docClient.send(
      new GetCommand({
        TableName: licenseTable,
        Key: {
          PK: `USER#${userId}`,
          SK: 'LICENSE',
        },
      })
    );
    return result.Item;
  });
}

async function getTodaySummary(stationId: string, date: string) {
  const tableName = process.env.DYNAMODB_TABLE_DAILY_SUMMARY || 'FuelPOS_DailySummary';

  return withRetry(async () => {
    const result = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${stationId}`,
          SK: `DATE#${date}`,
        },
      })
    );

    return result.Item || {
      totalSales: 0,
      transactionCount: 0,
      petrolLiters: 0,
      dieselLiters: 0,
    };
  });
}

async function getStaffList(stationId: string) {
  const tableName = process.env.DYNAMODB_TABLE_EMPLOYEES || 'FuelPOSEmployees';

  return withRetry(async () => {
    const result = await docClient.send(
      new QueryCommand({
        TableName: tableName,
        KeyConditionExpression: 'PK = :pk',
        ExpressionAttributeValues: {
          ':pk': `STATION#${stationId}`,
        },
      })
    );

    return result.Items || [];
  });
}

async function getTransactionsByStaff(
  stationId: string,
  date: string,
  staffId: string
) {
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
      })
    );

    return result.Items || [];
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

    const userId = claims.sub;
    const stationId = event.queryStringParameters?.stationId;
    const date = event.queryStringParameters?.date || new Date().toISOString().split('T')[0];

    if (!stationId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'stationId query parameter is required' }),
      };
    }

    // Verify owner access
    const licenseProfile = await getOwnerLicenseProfile(userId);
    if (!licenseProfile || licenseProfile.stationId !== stationId) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Forbidden - Invalid station access' }),
      };
    }

    // Get daily summary
    const summary = await getTodaySummary(stationId, date);

    // Get staff list
    const staffList = await getStaffList(stationId);

    // Get revenue by staff
    const revenueByStaff: StaffRevenue[] = await Promise.all(
      staffList.map(async (staff) => {
        const transactions = await getTransactionsByStaff(stationId, date, staff.employeeId);

        const totalSales = transactions
          .filter((t) => t.status === 'PAID')
          .reduce((sum, t) => sum + (t.amount || 0), 0);

        const paidTransactions = transactions.filter((t) => t.status === 'PAID').length;
        const pendingTransactions = transactions.filter((t) => t.status === 'PENDING').length;

        return {
          staffId: staff.employeeId,
          staffName: staff.name || staff.employeeId,
          totalSales: Math.round(totalSales * 100) / 100,
          transactionCount: transactions.length,
          paidTransactions,
          pendingTransactions,
        };
      })
    );

    // Sort by revenue (highest first)
    revenueByStaff.sort((a, b) => b.totalSales - a.totalSales);

    // Get recent transactions (all staff)
    const recentTransactions = await getTransactionsByStaff(stationId, date, '');
    const recent = recentTransactions
      .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
      .slice(0, 10)
      .map((t) => ({
        transactionId: t.transactionId,
        time: new Date(t.timestamp).toLocaleTimeString('en-IN', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: false,
          timeZone: 'Asia/Kolkata',
        }),
        vehicleNumber: t.vehicleNumber,
        fuelType: t.fuelType,
        liters: t.liters,
        amount: t.amount,
        status: t.status,
        staffName: revenueByStaff.find((s) => s.staffId === t.staffId)?.staffName || 'Unknown',
      }));

    const dashboardData: OwnerDashboardData = {
      todaySales: summary.totalSales || 0,
      totalTransactions: summary.transactionCount || 0,
      paidTransactions: recentTransactions.filter((t) => t.status === 'PAID').length,
      pendingTransactions: recentTransactions.filter((t) => t.status === 'PENDING').length,
      revenueByStaff,
      recentTransactions: recent,
      fuelSold: {
        petrol: {
          liters: summary.petrolLiters || 0,
          amount: revenueByStaff.reduce((sum, s) => sum + s.totalSales, 0) * 0.4, // Approximate
        },
        diesel: {
          liters: summary.dieselLiters || 0,
          amount: revenueByStaff.reduce((sum, s) => sum + s.totalSales, 0) * 0.5, // Approximate
        },
      },
    };

    return {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: dashboardData,
        meta: {
          stationId,
          date,
          ownerId: userId,
          currency: 'INR',
          timezone: 'Asia/Kolkata',
        },
      }),
    };
  } catch (error) {
    console.error('Owner dashboard error:', error);
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
