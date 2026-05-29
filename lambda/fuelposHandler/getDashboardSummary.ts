import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { logger } from '../shared/logger.mjs';
import { StationIdQuerySchema, validateSchema, sanitizeObject } from '../shared/schemas.mjs';
import { withRetry } from '../shared/utils.mjs';
import { corsHeaders, getISTDate, getYesterdayDate, round2 } from '../shared/helpers.mjs';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

interface DashboardSummary {
  todaySales: { total: number; changePercent: number };
  fuelSoldLiters: { total: number; petrol: number; diesel: number };
  totalTransactions: { count: number; changePercent: number };
  inventory: {
    petrol: { percent: number; liters: number };
    diesel: { percent: number; liters: number };
  };
}

interface LicenseProfile {
  userId: string;
  tenantId: string;
  businessType: string;
  stationId: string;
  features: string[];
}

// formatINR, getISTDate, getYesterdayDate now imported from ../shared/helpers.mjs

async function validateUserAccess(
  userId: string,
  requestedStationId: string
): Promise<LicenseProfile | null> {
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

    // Verify stationId matches user's assigned station
    if (profile.stationId !== requestedStationId) {
      console.warn(`User ${userId} attempted to access station ${requestedStationId} but is assigned to ${profile.stationId}`);
      return null;
    }

    // Verify business type is petrol_pump
    if (profile.businessType !== 'petrol_pump') {
      console.warn(`User ${userId} has business type ${profile.businessType}, not petrol_pump`);
      return null;
    }

    return profile;
  } catch (error) {
    logger.error('Error validating user access', { error, userId, requestedStationId });
    return null;
  }
}

async function getTodaySummary(stationId: string, date: string): Promise<{
  totalSales: number;
  totalLiters: number;
  petrolLiters: number;
  dieselLiters: number;
  transactionCount: number;
} | null> {
  const tableName = process.env.DYNAMODB_TABLE_DAILY_SUMMARY || 'FuelPOS_DailySummary';

  try {
    const result = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${stationId}`,
          SK: `DATE#${date}`,
        },
      })
    );

    if (!result.Item) {
      return {
        totalSales: 0,
        totalLiters: 0,
        petrolLiters: 0,
        dieselLiters: 0,
        transactionCount: 0,
      };
    }

    return {
      totalSales: result.Item.totalSales || 0,
      totalLiters: result.Item.totalLiters || 0,
      petrolLiters: result.Item.petrolLiters || 0,
      dieselLiters: result.Item.dieselLiters || 0,
      transactionCount: result.Item.transactionCount || 0,
    };
  } catch (error) {
    logger.error('Error fetching today summary', { error, stationId, date });
    return null;
  }
}

async function getYesterdaySummary(stationId: string, date: string): Promise<{
  totalSales: number;
  transactionCount: number;
} | null> {
  const yesterday = getYesterdayDate(date);
  const tableName = process.env.DYNAMODB_TABLE_DAILY_SUMMARY || 'FuelPOS_DailySummary';

  try {
    const result = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${stationId}`,
          SK: `DATE#${yesterday}`,
        },
      })
    );

    if (!result.Item) {
      return { totalSales: 0, transactionCount: 0 };
    }

    return {
      totalSales: result.Item.totalSales || 0,
      transactionCount: result.Item.transactionCount || 0,
    };
  } catch (error) {
    logger.error('Error fetching yesterday summary', { error, stationId, date });
    return null;
  }
}

async function getInventoryLevels(stationId: string): Promise<{
  petrol: { percent: number; liters: number };
  diesel: { percent: number; liters: number };
} | null> {
  const tableName = process.env.DYNAMODB_TABLE_INVENTORY || 'FuelPOS_Inventory';

  try {
    const [petrolResult, dieselResult] = await Promise.all([
      docClient.send(
        new GetCommand({
          TableName: tableName,
          Key: {
            PK: `STATION#${stationId}`,
            SK: 'INVENTORY#PETROL',
          },
        })
      ),
      docClient.send(
        new GetCommand({
          TableName: tableName,
          Key: {
            PK: `STATION#${stationId}`,
            SK: 'INVENTORY#DIESEL',
          },
        })
      ),
    ]);

    const petrol = petrolResult.Item || { currentLiters: 0, capacityLiters: 1, percentFull: 0 };
    const diesel = dieselResult.Item || { currentLiters: 0, capacityLiters: 1, percentFull: 0 };

    return {
      petrol: {
        percent: Math.round(petrol.percentFull || (petrol.currentLiters / petrol.capacityLiters) * 100),
        liters: Math.round(petrol.currentLiters || 0),
      },
      diesel: {
        percent: Math.round(diesel.percentFull || (diesel.currentLiters / diesel.capacityLiters) * 100),
        liters: Math.round(diesel.currentLiters || 0),
      },
    };
  } catch (error) {
    logger.error('Error fetching inventory levels', { error, stationId });
    return null;
  }
}

function calculateChangePercent(current: number, previous: number): number {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100 * 10) / 10;
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const startTime = Date.now();
  let userId: string | undefined;
  let stationId: string | undefined;
  
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  try {
    // Extract user info from Cognito JWT (authorizer context)
    const authorizerContext = event.requestContext?.authorizer?.jwt;
    const claims = authorizerContext?.claims;

    if (!claims || !claims.sub) {
      logger.security('Unauthorized access attempt', '');
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Unauthorized - Valid JWT required' }),
      };
    }

    userId = claims.sub;

    // Validate and sanitize query parameters
    const queryValidation = validateSchema(
      StationIdQuerySchema,
      sanitizeObject(event.queryStringParameters || {})
    );
    
    if (!queryValidation.success) {
      logger.warn('Invalid query parameters', { errors: queryValidation.errors, userId });
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Invalid query parameters',
          details: queryValidation.errors,
        }),
      };
    }

    const validatedData = queryValidation.data;
    stationId = validatedData.stationId;
    const date = validatedData.date || getISTDate();

    // Validate user has access to this station
    const licenseProfile = await validateUserAccess(userId!, stationId!);
    if (!licenseProfile) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Forbidden - You do not have access to this station' }),
      };
    }

    // Fetch all data in parallel
    const [todayData, yesterdayData, inventory] = await Promise.all([
      getTodaySummary(stationId!, date),
      getYesterdaySummary(stationId!, date),
      getInventoryLevels(stationId!),
    ]);

    if (!todayData || !inventory) {
      return {
        statusCode: 500,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Failed to fetch dashboard data' }),
      };
    }

    // Calculate percentage changes
    const salesChangePercent = calculateChangePercent(todayData.totalSales, yesterdayData?.totalSales || 0);
    const transactionChangePercent = calculateChangePercent(todayData.transactionCount, yesterdayData?.transactionCount || 0);

    const summary: DashboardSummary = {
      todaySales: {
        total: round2(todayData.totalSales),
        changePercent: salesChangePercent,
      },
      fuelSoldLiters: {
        total: todayData.totalLiters,
        petrol: todayData.petrolLiters,
        diesel: todayData.dieselLiters,
      },
      totalTransactions: {
        count: todayData.transactionCount,
        changePercent: transactionChangePercent,
      },
      inventory,
    };

    const response = {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: summary,
        meta: {
          stationId,
          date,
          currency: 'INR',
          timezone: 'Asia/Kolkata',
        },
      }),
    };

    // Log successful response
    logger.response('GET', '/dashboard/summary', 200, Date.now() - startTime, {
      userId,
      stationId,
      date,
    });

    return response;
  } catch (error) {
    logger.error('Error in getDashboardSummary', { 
      error, 
      userId: userId || 'unknown', 
      stationId: stationId || 'unknown' 
    });
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
