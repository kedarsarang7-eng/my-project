import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, GetCommand, PutCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const ddbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(ddbClient);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
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
    name: claims.name || claims.email?.split('@')[0] || 'Staff',
  };
}

// Staff Mobile handler
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

    const { httpMethod, path, pathParameters, queryStringParameters, body } = event;
    const parsedBody = body ? JSON.parse(body) : {};

    // OPTIONS preflight
    if (httpMethod === 'OPTIONS') {
      return { statusCode: 200, headers: corsHeaders, body: '' };
    }

    const staffTable = process.env.DYNAMODB_TABLE_STAFF || 'FuelPOS_Staff';
    const transactionsTable = process.env.DYNAMODB_TABLE_TRANSACTIONS || 'FuelPOS_Transactions';

    // GET /staff-mobile/dashboard - Staff dashboard data
    if (httpMethod === 'GET' && path === '/staff-mobile/dashboard') {
      // Get staff profile
      const staffResult = await docClient.send(new GetCommand({
        TableName: staffTable,
        Key: { userId: userInfo.userId },
      }));

      const staffProfile = staffResult.Item || {
        userId: userInfo.userId,
        email: userInfo.email,
        name: userInfo.name,
        role: userInfo.role,
        tenantId: userInfo.tenantId,
        stationId: userInfo.stationId,
      };

      // Get today's stats
      const today = new Date().toISOString().split('T')[0];
      const startOfDay = `${today}T00:00:00.000Z`;
      const endOfDay = `${today}T23:59:59.999Z`;

      const todayTxns = await docClient.send(new QueryCommand({
        TableName: transactionsTable,
        IndexName: 'GSI_Staff',
        KeyConditionExpression: 'staffId = :staffId',
        FilterExpression: 'tenantId = :tenantId AND createdAt BETWEEN :startDate AND :endDate',
        ExpressionAttributeValues: {
          ':staffId': userInfo.userId,
          ':tenantId': userInfo.tenantId,
          ':startDate': startOfDay,
          ':endDate': endOfDay,
        },
      }));

      const todayTransactions = todayTxns.Items || [];
      const todayRevenue = todayTransactions.reduce((sum, t) => sum + (t.amount || 0), 0);
      const todayFuelLiters = todayTransactions.reduce((sum, t) => sum + (t.liters || 0), 0);

      // Get recent transactions (last 5)
      const recentTxns = await docClient.send(new QueryCommand({
        TableName: transactionsTable,
        IndexName: 'GSI_Staff',
        KeyConditionExpression: 'staffId = :staffId',
        FilterExpression: 'tenantId = :tenantId',
        ExpressionAttributeValues: {
          ':staffId': userInfo.userId,
          ':tenantId': userInfo.tenantId,
        },
        ScanIndexForward: false,
        Limit: 5,
      }));

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: {
            profile: staffProfile,
            todayStats: {
              revenue: todayRevenue,
              transactions: todayTransactions.length,
              fuelLiters: todayFuelLiters,
              averageTicket: todayTransactions.length > 0 ? todayRevenue / todayTransactions.length : 0,
            },
            recentTransactions: recentTxns.Items || [],
          },
        }),
      };
    }

    // GET /staff-mobile/shift-summary - Staff shift summary
    if (httpMethod === 'GET' && path === '/staff-mobile/shift-summary') {
      const { period = 'today' } = queryStringParameters || {};
      
      let startDate, endDate;
      const now = new Date();
      
      switch (period) {
        case 'today':
          startDate = `${now.toISOString().split('T')[0]}T00:00:00.000Z`;
          endDate = `${now.toISOString().split('T')[0]}T23:59:59.999Z`;
          break;
        case 'yesterday':
          const yesterday = new Date(now);
          yesterday.setDate(yesterday.getDate() - 1);
          startDate = `${yesterday.toISOString().split('T')[0]}T00:00:00.000Z`;
          endDate = `${yesterday.toISOString().split('T')[0]}T23:59:59.999Z`;
          break;
        case 'week':
          const weekAgo = new Date(now);
          weekAgo.setDate(weekAgo.getDate() - 7);
          startDate = weekAgo.toISOString();
          endDate = now.toISOString();
          break;
        case 'month':
          const monthAgo = new Date(now);
          monthAgo.setMonth(monthAgo.getMonth() - 1);
          startDate = monthAgo.toISOString();
          endDate = now.toISOString();
          break;
        default:
          startDate = `${now.toISOString().split('T')[0]}T00:00:00.000Z`;
          endDate = `${now.toISOString().split('T')[0]}T23:59:59.999Z`;
      }

      const result = await docClient.send(new QueryCommand({
        TableName: transactionsTable,
        IndexName: 'GSI_Staff',
        KeyConditionExpression: 'staffId = :staffId',
        FilterExpression: 'tenantId = :tenantId AND createdAt BETWEEN :startDate AND :endDate',
        ExpressionAttributeValues: {
          ':staffId': userInfo.userId,
          ':tenantId': userInfo.tenantId,
          ':startDate': startDate,
          ':endDate': endDate,
        },
      }));

      const transactions = result.Items || [];
      
      // Calculate stats
      const totalRevenue = transactions.reduce((sum, t) => sum + (t.amount || 0), 0);
      const totalFuelLiters = transactions.reduce((sum, t) => sum + (t.liters || 0), 0);
      const petrolTxns = transactions.filter(t => t.fuelType?.toLowerCase() === 'petrol');
      const dieselTxns = transactions.filter(t => t.fuelType?.toLowerCase() === 'diesel');
      
      // Get previous period for comparison
      const periodDuration = new Date(endDate).getTime() - new Date(startDate).getTime();
      const prevStartDate = new Date(new Date(startDate).getTime() - periodDuration).toISOString();
      const prevEndDate = startDate;
      
      const prevResult = await docClient.send(new QueryCommand({
        TableName: transactionsTable,
        IndexName: 'GSI_Staff',
        KeyConditionExpression: 'staffId = :staffId',
        FilterExpression: 'tenantId = :tenantId AND createdAt BETWEEN :startDate AND :endDate',
        ExpressionAttributeValues: {
          ':staffId': userInfo.userId,
          ':tenantId': userInfo.tenantId,
          ':startDate': prevStartDate,
          ':endDate': prevEndDate,
        },
      }));

      const prevTransactions = prevResult.Items || [];
      const prevRevenue = prevTransactions.reduce((sum, t) => sum + (t.amount || 0), 0);
      const revenueChangePercent = prevRevenue > 0 
        ? ((totalRevenue - prevRevenue) / prevRevenue) * 100 
        : 0;

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: {
            period,
            totalRevenue,
            totalTransactions: transactions.length,
            totalFuelLiters,
            averageTransactionValue: transactions.length > 0 ? totalRevenue / transactions.length : 0,
            revenueChangePercent,
            petrolRevenue: petrolTxns.reduce((sum, t) => sum + (t.amount || 0), 0),
            dieselRevenue: dieselTxns.reduce((sum, t) => sum + (t.amount || 0), 0),
            petrolLiters: petrolTxns.reduce((sum, t) => sum + (t.liters || 0), 0),
            dieselLiters: dieselTxns.reduce((sum, t) => sum + (t.liters || 0), 0),
            petrolTransactions: petrolTxns.length,
            dieselTransactions: dieselTxns.length,
          },
        }),
      };
    }

    // GET /staff-mobile/transactions - Staff personal transactions
    if (httpMethod === 'GET' && path === '/staff-mobile/transactions') {
      const { startDate, endDate, page = '1', limit = '20' } = queryStringParameters || {};

      let params = {
        TableName: transactionsTable,
        IndexName: 'GSI_Staff',
        KeyConditionExpression: 'staffId = :staffId',
        FilterExpression: 'tenantId = :tenantId',
        ExpressionAttributeValues: {
          ':staffId': userInfo.userId,
          ':tenantId': userInfo.tenantId,
        },
        ScanIndexForward: false, // Most recent first
        Limit: parseInt(limit),
      };

      // Add date filters if provided
      if (startDate && endDate) {
        params.FilterExpression += ' AND createdAt BETWEEN :startDate AND :endDate';
        params.ExpressionAttributeValues[':startDate'] = startDate;
        params.ExpressionAttributeValues[':endDate'] = endDate;
      }

      const result = await docClient.send(new QueryCommand(params));

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: result.Items || [],
          pagination: {
            page: parseInt(page),
            limit: parseInt(limit),
            hasMore: result.LastEvaluatedKey ? true : false,
          },
        }),
      };
    }

    // GET /staff-mobile/profile - Staff profile
    if (httpMethod === 'GET' && path === '/staff-mobile/profile') {
      const result = await docClient.send(new GetCommand({
        TableName: staffTable,
        Key: { userId: userInfo.userId },
      }));

      const profile = result.Item || {
        userId: userInfo.userId,
        email: userInfo.email,
        name: userInfo.name,
        role: userInfo.role,
        tenantId: userInfo.tenantId,
        stationId: userInfo.stationId,
        status: 'active',
        createdAt: new Date().toISOString(),
      };

      // Get this month's stats
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
      
      const monthTxns = await docClient.send(new QueryCommand({
        TableName: transactionsTable,
        IndexName: 'GSI_Staff',
        KeyConditionExpression: 'staffId = :staffId',
        FilterExpression: 'tenantId = :tenantId AND createdAt >= :monthStart',
        ExpressionAttributeValues: {
          ':staffId': userInfo.userId,
          ':tenantId': userInfo.tenantId,
          ':monthStart': monthStart,
        },
      }));

      const monthTransactions = monthTxns.Items || [];

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: {
            ...profile,
            monthlyStats: {
              revenue: monthTransactions.reduce((sum, t) => sum + (t.amount || 0), 0),
              transactions: monthTransactions.length,
              fuelLiters: monthTransactions.reduce((sum, t) => sum + (t.liters || 0), 0),
            },
          },
        }),
      };
    }

    // PUT /staff-mobile/profile - Update staff profile
    if (httpMethod === 'PUT' && path === '/staff-mobile/profile') {
      const { name, phone } = parsedBody;
      
      const updateExpressions = [];
      const expressionValues = {};

      if (name) {
        updateExpressions.push('name = :name');
        expressionValues[':name'] = name;
      }
      if (phone) {
        updateExpressions.push('phone = :phone');
        expressionValues[':phone'] = phone;
      }

      if (updateExpressions.length === 0) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'No fields to update' }),
        };
      }

      updateExpressions.push('updatedAt = :updatedAt');
      expressionValues[':updatedAt'] = new Date().toISOString();

      await docClient.send(new UpdateCommand({
        TableName: staffTable,
        Key: { userId: userInfo.userId },
        UpdateExpression: `SET ${updateExpressions.join(', ')}`,
        ExpressionAttributeValues: expressionValues,
      }));

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ success: true }),
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
