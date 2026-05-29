import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';

const ddbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(ddbClient);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
};

// Get user info from JWT claims
function getUserInfo(event) {
  const claims = event.requestContext?.authorizer?.claims;
  if (!claims) return null;
  
  return {
    userId: claims.sub,
    email: claims.email,
    tenantId: claims['custom:tenant_id'],
    businessType: claims['custom:business_type'],
    stationId: claims['custom:station_id'],
    role: claims['custom:role'] || 'staff',
  };
}

// Revenue reports handler
export const handler = async (event) => {
  console.log('Event:', JSON.stringify(event));
  
  try {
    const userInfo = getUserInfo(event);
    if (!userInfo) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const { httpMethod, path, queryStringParameters } = event;

    // OPTIONS preflight
    if (httpMethod === 'OPTIONS') {
      return { statusCode: 200, headers: corsHeaders, body: '' };
    }

    const tableName = process.env.DYNAMODB_TABLE_TRANSACTIONS || 'FuelPOS_Transactions';
    const staffTable = process.env.DYNAMODB_TABLE_STAFF || 'FuelPOS_Staff';

    // GET /reports/revenue - Revenue report
    if (httpMethod === 'GET' && path.includes('/reports/revenue')) {
      const { startDate, endDate, staffId } = queryStringParameters || {};

      if (!startDate || !endDate) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'startDate and endDate are required' }),
        };
      }

      // Build query params
      const params = {
        TableName: tableName,
        IndexName: 'GSI_Tenant',
        KeyConditionExpression: 'tenantId = :tenantId',
        FilterExpression: 'createdAt BETWEEN :startDate AND :endDate',
        ExpressionAttributeValues: {
          ':tenantId': userInfo.tenantId,
          ':startDate': startDate,
          ':endDate': endDate,
        },
      };

      // Add staff filter if provided
      if (staffId) {
        params.FilterExpression += ' AND staffId = :staffId';
        params.ExpressionAttributeValues[':staffId'] = staffId;
      }

      const result = await docClient.send(new QueryCommand(params));
      const transactions = result.Items || [];

      // Calculate metrics
      const metrics = calculateRevenueMetrics(transactions);

      // Get staff summary
      const staffSummary = await calculateStaffSummary(staffTable, tableName, userInfo.tenantId, startDate, endDate);

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: {
            periodStart: startDate,
            periodEnd: endDate,
            ...metrics,
            staffSummary,
          },
        }),
      };
    }

    // GET /reports/hourly-sales
    if (httpMethod === 'GET' && path.includes('/reports/hourly-sales')) {
      const { date, staffId } = queryStringParameters || {};

      if (!date) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'date is required' }),
        };
      }

      const startOfDay = `${date}T00:00:00.000Z`;
      const endOfDay = `${date}T23:59:59.999Z`;

      const params = {
        TableName: tableName,
        IndexName: 'GSI_Tenant',
        KeyConditionExpression: 'tenantId = :tenantId',
        FilterExpression: 'createdAt BETWEEN :startDate AND :endDate',
        ExpressionAttributeValues: {
          ':tenantId': userInfo.tenantId,
          ':startDate': startOfDay,
          ':endDate': endOfDay,
        },
      };

      if (staffId) {
        params.FilterExpression += ' AND staffId = :staffId';
        params.ExpressionAttributeValues[':staffId'] = staffId;
      }

      const result = await docClient.send(new QueryCommand(params));
      const transactions = result.Items || [];

      // Group by hour
      const hourlyData = new Array(24).fill(0).map((_, hour) => ({
        hour,
        revenue: 0,
        transactions: 0,
        fuelLiters: 0,
      }));

      transactions.forEach((txn) => {
        const hour = new Date(txn.createdAt).getHours();
        hourlyData[hour].revenue += txn.amount || 0;
        hourlyData[hour].transactions += 1;
        hourlyData[hour].fuelLiters += txn.liters || 0;
      });

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: hourlyData,
        }),
      };
    }

    // GET /reports/staff-performance
    if (httpMethod === 'GET' && path.includes('/reports/staff-performance')) {
      const { startDate, endDate, staffId } = queryStringParameters || {};

      if (!startDate || !endDate) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'startDate and endDate are required' }),
        };
      }

      // Get all active staff
      const staffParams = {
        TableName: staffTable,
        IndexName: 'GSI_Tenant',
        KeyConditionExpression: 'tenantId = :tenantId',
        FilterExpression: '#status = :status',
        ExpressionAttributeNames: {
          '#status': 'status',
        },
        ExpressionAttributeValues: {
          ':tenantId': userInfo.tenantId,
          ':status': 'active',
        },
      };

      if (staffId) {
        staffParams.FilterExpression += ' AND userId = :staffId';
        staffParams.ExpressionAttributeValues[':staffId'] = staffId;
      }

      const staffResult = await docClient.send(new QueryCommand(staffParams));
      const staff = staffResult.Items || [];

      // Get performance for each staff member
      const performanceData = await Promise.all(
        staff.map(async (s) => {
          const txnParams = {
            TableName: tableName,
            IndexName: 'GSI_Staff',
            KeyConditionExpression: 'staffId = :staffId',
            FilterExpression: 'tenantId = :tenantId AND createdAt BETWEEN :startDate AND :endDate',
            ExpressionAttributeValues: {
              ':staffId': s.userId,
              ':tenantId': userInfo.tenantId,
              ':startDate': startDate,
              ':endDate': endDate,
            },
          };

          const txnResult = await docClient.send(new QueryCommand(txnParams));
          const transactions = txnResult.Items || [];

          const petrolTxns = transactions.filter(t => t.fuelType?.toLowerCase() === 'petrol');
          const dieselTxns = transactions.filter(t => t.fuelType?.toLowerCase() === 'diesel');

          return {
            staffId: s.userId,
            staffName: s.name,
            totalTransactions: transactions.length,
            totalRevenue: transactions.reduce((sum, t) => sum + (t.amount || 0), 0),
            totalFuelLiters: transactions.reduce((sum, t) => sum + (t.liters || 0), 0),
            petrolTransactions: petrolTxns.length,
            dieselTransactions: dieselTxns.length,
            petrolLiters: petrolTxns.reduce((sum, t) => sum + (t.liters || 0), 0),
            dieselLiters: dieselTxns.reduce((sum, t) => sum + (t.liters || 0), 0),
            periodStart: startDate,
            periodEnd: endDate,
          };
        })
      );

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: performanceData,
        }),
      };
    }

    // GET /reports/comparison
    if (httpMethod === 'GET' && path.includes('/reports/comparison')) {
      const { currentStart, currentEnd } = queryStringParameters || {};

      if (!currentStart || !currentEnd) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'currentStart and currentEnd are required' }),
        };
      }

      // Calculate previous period (same duration)
      const currentStartDate = new Date(currentStart);
      const currentEndDate = new Date(currentEnd);
      const duration = currentEndDate.getTime() - currentStartDate.getTime();
      
      const previousStart = new Date(currentStartDate.getTime() - duration).toISOString().split('T')[0];
      const previousEnd = new Date(currentEndDate.getTime() - duration).toISOString().split('T')[0];

      // Get current period data
      const currentResult = await docClient.send(new QueryCommand({
        TableName: tableName,
        IndexName: 'GSI_Tenant',
        KeyConditionExpression: 'tenantId = :tenantId',
        FilterExpression: 'createdAt BETWEEN :startDate AND :endDate',
        ExpressionAttributeValues: {
          ':tenantId': userInfo.tenantId,
          ':startDate': currentStart,
          ':endDate': currentEnd,
        },
      }));

      // Get previous period data
      const previousResult = await docClient.send(new QueryCommand({
        TableName: tableName,
        IndexName: 'GSI_Tenant',
        KeyConditionExpression: 'tenantId = :tenantId',
        FilterExpression: 'createdAt BETWEEN :startDate AND :endDate',
        ExpressionAttributeValues: {
          ':tenantId': userInfo.tenantId,
          ':startDate': previousStart,
          ':endDate': previousEnd,
        },
      }));

      const currentTxns = currentResult.Items || [];
      const previousTxns = previousResult.Items || [];

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: {
            currentRevenue: currentTxns.reduce((sum, t) => sum + (t.amount || 0), 0),
            previousRevenue: previousTxns.reduce((sum, t) => sum + (t.amount || 0), 0),
            currentTransactions: currentTxns.length,
            previousTransactions: previousTxns.length,
            currentFuelLiters: currentTxns.reduce((sum, t) => sum + (t.liters || 0), 0),
            previousFuelLiters: previousTxns.reduce((sum, t) => sum + (t.liters || 0), 0),
          },
        }),
      };
    }

    // GET /reports/export
    if (httpMethod === 'GET' && path.includes('/reports/export')) {
      const { startDate, endDate, format, staffId } = queryStringParameters || {};

      if (!startDate || !endDate || !format) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'startDate, endDate, and format are required' }),
        };
      }

      // In a real implementation, you would:
      // 1. Generate the report file
      // 2. Upload to S3
      // 3. Return a presigned URL

      // For now, return a mock URL
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: {
            downloadUrl: `https://fuelpos-reports.s3.amazonaws.com/reports/${userInfo.tenantId}/${format}/${startDate}_${endDate}.${format}`,
            expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(),
          },
        }),
      };
    }

    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Not found' }),
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Internal server error', message: error.message }),
    };
  }
};

// Helper function to calculate revenue metrics
function calculateRevenueMetrics(transactions) {
  let totalRevenue = 0;
  let totalFuelLiters = 0;
  let petrolRevenue = 0;
  let dieselRevenue = 0;
  let petrolLiters = 0;
  let dieselLiters = 0;
  let petrolTransactions = 0;
  let dieselTransactions = 0;
  let upiAmount = 0;
  let cashAmount = 0;
  let cardAmount = 0;
  let upiTransactions = 0;
  let cashTransactions = 0;
  let cardTransactions = 0;

  const revenueByDay = {};

  transactions.forEach((txn) => {
    const amount = txn.amount || 0;
    const liters = txn.liters || 0;
    const fuelType = txn.fuelType?.toLowerCase();
    const paymentMethod = txn.paymentMethod?.toLowerCase();
    const date = txn.createdAt?.split('T')[0];

    totalRevenue += amount;
    totalFuelLiters += liters;

    if (fuelType === 'petrol') {
      petrolRevenue += amount;
      petrolLiters += liters;
      petrolTransactions++;
    } else if (fuelType === 'diesel') {
      dieselRevenue += amount;
      dieselLiters += liters;
      dieselTransactions++;
    }

    if (paymentMethod === 'upi') {
      upiAmount += amount;
      upiTransactions++;
    } else if (paymentMethod === 'cash') {
      cashAmount += amount;
      cashTransactions++;
    } else if (paymentMethod === 'card') {
      cardAmount += amount;
      cardTransactions++;
    }

    if (date) {
      revenueByDay[date] = (revenueByDay[date] || 0) + amount;
    }
  });

  return {
    totalRevenue,
    totalTransactions: transactions.length,
    totalFuelLiters,
    averageTransactionValue: transactions.length > 0 ? totalRevenue / transactions.length : 0,
    revenueByDay,
    fuelBreakdown: {
      petrolLiters,
      dieselLiters,
      petrolRevenue,
      dieselRevenue,
      petrolTransactions,
      dieselTransactions,
    },
    paymentMethods: {
      upiAmount,
      upiTransactions,
      cashAmount,
      cashTransactions,
      cardAmount,
      cardTransactions,
    },
  };
}

// Helper function to calculate staff summary
async function calculateStaffSummary(staffTable, transactionsTable, tenantId, startDate, endDate) {
  try {
    // Get all staff
    const staffResult = await docClient.send(new QueryCommand({
      TableName: staffTable,
      IndexName: 'GSI_Tenant',
      KeyConditionExpression: 'tenantId = :tenantId',
      ExpressionAttributeValues: {
        ':tenantId': tenantId,
      },
    }));

    const staff = staffResult.Items || [];

    // Calculate summary for each staff
    const summary = await Promise.all(
      staff.map(async (s) => {
        const txnResult = await docClient.send(new QueryCommand({
          TableName: transactionsTable,
          IndexName: 'GSI_Staff',
          KeyConditionExpression: 'staffId = :staffId',
          FilterExpression: 'tenantId = :tenantId AND createdAt BETWEEN :startDate AND :endDate',
          ExpressionAttributeValues: {
            ':staffId': s.userId,
            ':tenantId': tenantId,
            ':startDate': startDate,
            ':endDate': endDate,
          },
        }));

        const txns = txnResult.Items || [];

        return {
          staffId: s.userId,
          staffName: s.name,
          revenue: txns.reduce((sum, t) => sum + (t.amount || 0), 0),
          transactions: txns.length,
          fuelLiters: txns.reduce((sum, t) => sum + (t.liters || 0), 0),
        };
      })
    );

    // Filter out staff with no transactions and sort by revenue
    return summary
      .filter((s) => s.revenue > 0)
      .sort((a, b) => b.revenue - a.revenue);
  } catch (error) {
    console.error('Error calculating staff summary:', error);
    return [];
  }
}
