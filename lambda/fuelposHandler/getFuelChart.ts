import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

interface FuelChartData {
  hours: string[];
  petrol: number[];
  diesel: number[];
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

function generateHourLabels(): string[] {
  const hours: string[] = [];
  for (let i = 6; i <= 22; i++) {
    hours.push(`${i.toString().padStart(2, '0')}:00`);
  }
  return hours;
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

async function getFuelChartData(stationId: string, date: string): Promise<FuelChartData> {
  const tableName = process.env.DYNAMODB_TABLE_FUEL_CHART || 'FuelPOS_FuelChart';
  const pk = `STATION#${stationId}#DATE#${date}`;

  try {
    const result = await docClient.send(
      new QueryCommand({
        TableName: tableName,
        KeyConditionExpression: 'PK = :pk',
        ExpressionAttributeValues: {
          ':pk': pk,
        },
        ScanIndexForward: true,
      })
    );

    // Create a map of hour -> data for quick lookup
    const hourDataMap = new Map<number, { petrol: number; diesel: number }>();

    if (result.Items) {
      for (const item of result.Items) {
        const hour = parseInt(item.SK.replace('HOUR#', ''), 10);
        hourDataMap.set(hour, {
          petrol: item.petrolLiters || 0,
          diesel: item.dieselLiters || 0,
        });
      }
    }

    // Build the response arrays (6 AM to 10 PM = 17 hours)
    const hours: string[] = [];
    const petrol: number[] = [];
    const diesel: number[] = [];

    for (let h = 6; h <= 22; h++) {
      hours.push(`${h.toString().padStart(2, '0')}:00`);
      const data = hourDataMap.get(h) || { petrol: 0, diesel: 0 };
      petrol.push(data.petrol);
      diesel.push(data.diesel);
    }

    return { hours, petrol, diesel };
  } catch (error) {
    console.error('Error fetching fuel chart data:', error);
    // Return empty chart on error
    return {
      hours: generateHourLabels(),
      petrol: new Array(17).fill(0),
      diesel: new Array(17).fill(0),
    };
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

    const chartData = await getFuelChartData(stationId, date);

    return {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: chartData,
        meta: {
          stationId,
          date,
          hourRange: '06:00 - 22:00',
          timezone: 'Asia/Kolkata',
        },
      }),
    };
  } catch (error) {
    console.error('Error in getFuelChart:', error);
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
