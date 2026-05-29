import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, GetCommand, PutCommand, UpdateCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import { CognitoIdentityProviderClient, AdminCreateUserCommand, AdminSetUserPasswordCommand, AdminAddUserToGroupCommand } from '@aws-sdk/client-cognito-identity-provider';
import crypto from 'crypto';

const ddbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(ddbClient);
const cognitoClient = new CognitoIdentityProviderClient({});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,PATCH,OPTIONS',
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

// Check if user is owner or manager
function isOwnerOrManager(userInfo) {
  return userInfo?.role === 'owner' || userInfo?.role === 'admin' || userInfo?.role === 'manager';
}

// Generate temporary password
function generateTempPassword() {
  return crypto.randomBytes(8).toString('hex').toUpperCase();
}

// Staff handler
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

    // Route handlers
    const tableName = process.env.DYNAMODB_TABLE_STAFF || 'FuelPOS_Staff';
    const transactionsTable = process.env.DYNAMODB_TABLE_TRANSACTIONS || 'FuelPOS_Transactions';
    const userPoolId = process.env.COGNITO_USER_POOL_ID;

    // GET /staff - List all staff
    if (httpMethod === 'GET' && path === '/staff') {
      // Only owners/managers can list all staff
      if (!isOwnerOrManager(userInfo)) {
        return {
          statusCode: 403,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Only owners and managers can view staff list' }),
        };
      }

      const { status, role, page = '1', limit = '20' } = queryStringParameters || {};
      const pageNum = parseInt(page);
      const limitNum = parseInt(limit);

      const params = {
        TableName: tableName,
        IndexName: 'GSI_Tenant',
        KeyConditionExpression: 'tenantId = :tenantId',
        FilterExpression: undefined,
        ExpressionAttributeValues: {
          ':tenantId': userInfo.tenantId,
        },
        Limit: limitNum,
      };

      // Add filters
      const filterExpressions = [];
      if (status) {
        filterExpressions.push('status = :status');
        params.ExpressionAttributeValues[':status'] = status;
      }
      if (role) {
        filterExpressions.push('role = :role');
        params.ExpressionAttributeValues[':role'] = role;
      }
      if (filterExpressions.length > 0) {
        params.FilterExpression = filterExpressions.join(' AND ');
      }

      const result = await docClient.send(new QueryCommand(params));

      // Get performance stats for each staff member
      const staffWithStats = await Promise.all(
        (result.Items || []).map(async (staff) => {
          const stats = await getStaffStats(transactionsTable, userInfo.tenantId, staff.userId);
          return {
            ...staff,
            transactionsCount: stats.count,
            totalRevenue: stats.revenue,
          };
        })
      );

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: staffWithStats,
          pagination: {
            page: pageNum,
            limit: limitNum,
            hasMore: result.LastEvaluatedKey ? true : false,
          },
        }),
      };
    }

    // GET /staff/:id - Get staff details
    if (httpMethod === 'GET' && pathParameters?.id) {
      const staffId = pathParameters.id;
      
      // Users can view their own details or owners/managers can view anyone
      if (staffId !== userInfo.userId && !isOwnerOrManager(userInfo)) {
        return {
          statusCode: 403,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Permission denied' }),
        };
      }

      const result = await docClient.send(new GetCommand({
        TableName: tableName,
        Key: { userId: staffId },
      }));

      if (!result.Item || result.Item.tenantId !== userInfo.tenantId) {
        return {
          statusCode: 404,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Staff not found' }),
        };
      }

      // Get stats
      const stats = await getStaffStats(transactionsTable, userInfo.tenantId, staffId);
      
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: {
            ...result.Item,
            transactionsCount: stats.count,
            totalRevenue: stats.revenue,
          },
        }),
      };
    }

    // POST /staff/invite - Invite new staff
    if (httpMethod === 'POST' && path === '/staff/invite') {
      // Only owners can invite staff
      if (userInfo.role !== 'owner' && userInfo.role !== 'admin') {
        return {
          statusCode: 403,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Only owners can invite staff' }),
        };
      }

      const { name, email, phone, role = 'staff' } = parsedBody;

      if (!name || !email) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Name and email are required' }),
        };
      }

      // Generate temporary password
      const tempPassword = generateTempPassword();

      try {
        // Create user in Cognito
        await cognitoClient.send(new AdminCreateUserCommand({
          UserPoolId: userPoolId,
          Username: email,
          UserAttributes: [
            { Name: 'email', Value: email },
            { Name: 'email_verified', Value: 'true' },
            { Name: 'name', Value: name },
            { Name: 'custom:tenant_id', Value: userInfo.tenantId },
            { Name: 'custom:business_type', Value: userInfo.businessType },
            { Name: 'custom:station_id', Value: userInfo.stationId },
            { Name: 'custom:role', Value: role },
            { Name: 'custom:created_by', Value: userInfo.userId },
          ],
          TemporaryPassword: tempPassword,
          MessageAction: 'SUPPRESS', // We'll send our own email
        }));

        // Add to staff group
        await cognitoClient.send(new AdminAddUserToGroupCommand({
          UserPoolId: userPoolId,
          Username: email,
          GroupName: 'Staff',
        }));

        // Get the new user's sub
        // Note: In production, you'd get this from the AdminCreateUser response
        const newUserId = crypto.randomUUID();

        // Create staff record in DynamoDB
        const staffRecord = {
          userId: newUserId,
          email,
          name,
          phone: phone || '',
          role,
          status: 'active',
          tenantId: userInfo.tenantId,
          stationId: userInfo.stationId,
          createdAt: new Date().toISOString(),
          createdBy: userInfo.userId,
          invitationStatus: 'pending',
        };

        await docClient.send(new PutCommand({
          TableName: tableName,
          Item: staffRecord,
        }));

        return {
          statusCode: 201,
          headers: corsHeaders,
          body: JSON.stringify({
            success: true,
            data: {
              invitationId: newUserId,
              email,
              status: 'pending',
              temporaryPassword: tempPassword,
              expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
            },
          }),
        };
      } catch (error) {
        console.error('Error inviting staff:', error);
        return {
          statusCode: 500,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Failed to invite staff: ' + error.message }),
        };
      }
    }

    // PATCH /staff/:id - Update staff
    if (httpMethod === 'PATCH' && pathParameters?.id) {
      const staffId = pathParameters.id;
      
      if (!isOwnerOrManager(userInfo)) {
        return {
          statusCode: 403,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Permission denied' }),
        };
      }

      const { name, phone, role, status } = parsedBody;
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
      if (role) {
        updateExpressions.push('role = :role');
        expressionValues[':role'] = role;
      }
      if (status) {
        updateExpressions.push('status = :status');
        expressionValues[':status'] = status;
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
        TableName: tableName,
        Key: { userId: staffId },
        UpdateExpression: `SET ${updateExpressions.join(', ')}`,
        ExpressionAttributeValues: expressionValues,
      }));

      const result = await docClient.send(new GetCommand({
        TableName: tableName,
        Key: { userId: staffId },
      }));

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          data: result.Item,
        }),
      };
    }

    // POST /staff/:id/deactivate
    if (httpMethod === 'POST' && path.endsWith('/deactivate') && pathParameters?.id) {
      const staffId = pathParameters.id;
      
      if (!isOwnerOrManager(userInfo)) {
        return {
          statusCode: 403,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Permission denied' }),
        };
      }

      await docClient.send(new UpdateCommand({
        TableName: tableName,
        Key: { userId: staffId },
        UpdateExpression: 'SET status = :status, deactivatedAt = :deactivatedAt, deactivatedBy = :deactivatedBy',
        ExpressionAttributeValues: {
          ':status': 'inactive',
          ':deactivatedAt': new Date().toISOString(),
          ':deactivatedBy': userInfo.userId,
        },
      }));

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ success: true }),
      };
    }

    // POST /staff/:id/reactivate
    if (httpMethod === 'POST' && path.endsWith('/reactivate') && pathParameters?.id) {
      const staffId = pathParameters.id;
      
      if (!isOwnerOrManager(userInfo)) {
        return {
          statusCode: 403,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Permission denied' }),
        };
      }

      await docClient.send(new UpdateCommand({
        TableName: tableName,
        Key: { userId: staffId },
        UpdateExpression: 'SET status = :status, reactivatedAt = :reactivatedAt, reactivatedBy = :reactivatedBy',
        ExpressionAttributeValues: {
          ':status': 'active',
          ':reactivatedAt': new Date().toISOString(),
          ':reactivatedBy': userInfo.userId,
        },
      }));

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ success: true }),
      };
    }

    // GET /staff/:id/transactions
    if (httpMethod === 'GET' && path.includes('/transactions') && pathParameters?.id) {
      const staffId = pathParameters.id;
      const { startDate, endDate, page = '1', limit = '20' } = queryStringParameters || {};

      // Users can view their own transactions or owners/managers can view anyone's
      if (staffId !== userInfo.userId && !isOwnerOrManager(userInfo)) {
        return {
          statusCode: 403,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'Permission denied' }),
        };
      }

      const params = {
        TableName: transactionsTable,
        IndexName: 'GSI_Staff',
        KeyConditionExpression: 'staffId = :staffId',
        FilterExpression: 'tenantId = :tenantId',
        ExpressionAttributeValues: {
          ':staffId': staffId,
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

// Helper function to get staff statistics
async function getStaffStats(tableName, tenantId, staffId) {
  try {
    const result = await docClient.send(new QueryCommand({
      TableName: tableName,
      IndexName: 'GSI_Staff',
      KeyConditionExpression: 'staffId = :staffId',
      FilterExpression: 'tenantId = :tenantId',
      ExpressionAttributeValues: {
        ':staffId': staffId,
        ':tenantId': tenantId,
      },
    }));

    const items = result.Items || [];
    const count = items.length;
    const revenue = items.reduce((sum, item) => sum + (item.amount || 0), 0);

    return { count, revenue };
  } catch (error) {
    console.error('Error getting staff stats:', error);
    return { count: 0, revenue: 0 };
  }
}
