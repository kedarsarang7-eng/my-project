import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

interface RevenueSegment {
  label: string;
  value: number;
  percent: number;
}

interface RevenueBreakdown {
  totalRevenue: number;
  segments: RevenueSegment[];
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

    if (profile.stationId !== requestedStationId || profile.businessType !== 'petrol_pump') {
      return null;
    }

    return profile;
  } catch (error) {
    console.error('Error validating user access:', error);
    return null;
  }
}

async function getRevenueData(stationId: string, date: string): Promise<RevenueBreakdown | null> {
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
      // Return empty breakdown if no data
      return {
        totalRevenue: 0,
        segments: [
          { label: 'Petrol', value: 0, percent: 0 },
          { label: 'Diesel', value: 0, percent: 0 },
          { label: 'Lubricants', value: 0, percent: 0 },
          { label: 'Shop Items', value: 0, percent: 0 },
        ],
      };
    }

    const revenueBySegment = result.Item.revenueBySegment || {};
    const totalRevenue = result.Item.totalSales || 0;

    // Calculate percentages dynamically
    const segments: RevenueSegment[] = [
      {
        label: 'Petrol',
        value: revenueBySegment.petrol?.amount || 0,
        percent: totalRevenue > 0
          ? Math.round(((revenueBySegment.petrol?.amount || 0) / totalRevenue) * 100)
          : 0,
      },
      {
        label: 'Diesel',
        value: revenueBySegment.diesel?.amount || 0,
        percent: totalRevenue > 0
          ? Math.round(((revenueBySegment.diesel?.amount || 0) / totalRevenue) * 100)
          : 0,
      },
      {
        label: 'Lubricants',
        value: revenueBySegment.lubricants?.amount || 0,
        percent: totalRevenue > 0
          ? Math.round(((revenueBySegment.lubricants?.amount || 0) / totalRevenue) * 100)
          : 0,
      },
      {
        label: 'Shop Items',
        value: revenueBySegment.shopItems?.amount || 0,
        percent: totalRevenue > 0
          ? Math.round(((revenueBySegment.shopItems?.amount || 0) / totalRevenue) * 100)
          : 0,
      },
    ];

    // Ensure percentages sum to 100 (adjust largest if needed)
    const totalPercent = segments.reduce((sum, s) => sum + s.percent, 0);
    if (totalPercent !== 100 && totalPercent > 0) {
      const diff = 100 - totalPercent;
      // Find largest segment and adjust
      const largestSegment = segments.reduce((max, s) => s.percent > max.percent ? s : max, segments[0]);
      largestSegment.percent += diff;
    }

    return {
      totalRevenue: Math.round(totalRevenue * 100) / 100,
      segments,
    };
  } catch (error) {
    console.error('Error fetching revenue data:', error);
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
    const stationId = event.queryStringParameters?.stationId;
    const date = event.queryStringParameters?.date || getISTDate();

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

    const revenueData = await getRevenueData(stationId, date);

    if (!revenueData) {
      return {
        statusCode: 500,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Failed to fetch revenue data' }),
      };
    }

    return {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: revenueData,
        meta: {
          stationId,
          date,
          currency: 'INR',
          currencySymbol: '₹',
        },
      }),
    };
  } catch (error) {
    console.error('Error in getRevenueBreakdown:', error);
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
