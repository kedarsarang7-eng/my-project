import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

interface InventoryAlert {
  type: 'low_stock' | 'critical_stock';
  fuel: string;
  currentPercent: number;
  threshold: number;
  message: string;
  severity: 'high' | 'medium' | 'low';
}

interface OperationalAlert {
  type: 'reorder' | 'price_update' | 'maintenance' | 'shift_change';
  item?: string;
  message: string;
  severity: 'high' | 'medium' | 'low';
}

interface PumpStatus {
  active: number;
  total: number;
  offline: number;
}

interface AlertsResponse {
  inventory: InventoryAlert[];
  operational: OperationalAlert[];
  pumps: PumpStatus;
  employeesOnDuty: number;
  lastUpdated: string;
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

function getISTDateTime(): string {
  return new Date().toISOString();
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

async function getInventoryAlerts(stationId: string): Promise<InventoryAlert[]> {
  const tableName = process.env.DYNAMODB_TABLE_INVENTORY || 'FuelPOS_Inventory';
  const alerts: InventoryAlert[] = [];

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

    const petrol = petrolResult.Item;
    const diesel = dieselResult.Item;

    if (petrol) {
      const percent = Math.round(petrol.percentFull || (petrol.currentLiters / petrol.capacityLiters) * 100);
      const threshold = petrol.alertThresholdPercent || 35;

      if (percent < threshold) {
        alerts.push({
          type: 'low_stock',
          fuel: 'Petrol',
          currentPercent: percent,
          threshold,
          message: `Petrol Tank Low (${percent}%)`,
          severity: percent < 20 ? 'high' : 'medium',
        });
      } else if (percent < threshold + 15) {
        alerts.push({
          type: 'low_stock',
          fuel: 'Petrol',
          currentPercent: percent,
          threshold,
          message: `Petrol Tank approaching low (${percent}%)`,
          severity: 'low',
        });
      }
    }

    if (diesel) {
      const percent = Math.round(diesel.percentFull || (diesel.currentLiters / diesel.capacityLiters) * 100);
      const threshold = diesel.alertThresholdPercent || 35;

      if (percent < threshold) {
        alerts.push({
          type: 'low_stock',
          fuel: 'Diesel',
          currentPercent: percent,
          threshold,
          message: `Diesel Tank Low (${percent}%)`,
          severity: percent < 20 ? 'high' : 'medium',
        });
      } else if (percent < threshold + 15) {
        alerts.push({
          type: 'low_stock',
          fuel: 'Diesel',
          currentPercent: percent,
          threshold,
          message: `Diesel Tank approaching low (${percent}%)`,
          severity: 'low',
        });
      }
    }

    return alerts;
  } catch (error) {
    console.error('Error fetching inventory alerts:', error);
    return [];
  }
}

async function getOperationalAlerts(stationId: string): Promise<OperationalAlert[]> {
  const tableName = process.env.DYNAMODB_TABLE_PRICES || 'FuelPOS_Prices';
  const alerts: OperationalAlert[] = [];

  try {
    // Check for recent price updates
    const priceResult = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${stationId}`,
          SK: 'PRICE#CURRENT',
        },
      })
    );

    if (priceResult.Item) {
      const updatedAt = new Date(priceResult.Item.updatedAt || Date.now());
      const hoursSinceUpdate = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60);

      if (hoursSinceUpdate < 24) {
        const petrolPrice = priceResult.Item.petrolPrice || 0;
        const dieselPrice = priceResult.Item.dieselPrice || 0;
        alerts.push({
          type: 'price_update',
          message: `Price Update (Petrol: ₹${petrolPrice.toFixed(2)}/L, Diesel: ₹${dieselPrice.toFixed(2)}/L)`,
          severity: 'low',
        });
      }
    }

    // Check for reorder items (lubricants, etc.)
    const inventoryTable = process.env.DYNAMODB_TABLE_INVENTORY || 'FuelPOS_Inventory';
    const lubricantsResult = await docClient.send(
      new GetCommand({
        TableName: inventoryTable,
        Key: {
          PK: `STATION#${stationId}`,
          SK: 'INVENTORY#LUBRICANTS',
        },
      })
    );

    if (lubricantsResult.Item) {
      const current = lubricantsResult.Item.currentUnits || 0;
      const threshold = lubricantsResult.Item.reorderThreshold || 10;

      if (current <= threshold) {
        alerts.push({
          type: 'reorder',
          item: 'Lubricants',
          message: 'Lubricants Reorder Required',
          severity: 'medium',
        });
      } else if (current <= threshold * 1.5) {
        alerts.push({
          type: 'reorder',
          item: 'Lubricants',
          message: 'Lubricants Reorder Soon',
          severity: 'low',
        });
      }
    }

    return alerts;
  } catch (error) {
    console.error('Error fetching operational alerts:', error);
    return [];
  }
}

async function getPumpStatus(stationId: string): Promise<PumpStatus> {
  // In a real system, this would query a pumps table or IoT Core
  // For now, return simulated data based on station
  return {
    active: 8,
    total: 10,
    offline: 2,
  };
}

async function getEmployeesOnDuty(stationId: string): Promise<number> {
  const tableName = process.env.DYNAMODB_TABLE_EMPLOYEES || 'FuelPOS_Employees';

  try {
    const result = await docClient.send(
      new QueryCommand({
        TableName: tableName,
        IndexName: 'GSI_OnDuty',
        KeyConditionExpression: 'GSI1PK = :pk',
        ExpressionAttributeValues: {
          ':pk': `ONDUTY#${stationId}`,
        },
      })
    );

    return result.Count || 0;
  } catch (error) {
    console.error('Error fetching employees on duty:', error);
    return 0;
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

    // Fetch all alert data in parallel
    const [inventoryAlerts, operationalAlerts, pumps, employeesOnDuty] = await Promise.all([
      getInventoryAlerts(stationId),
      getOperationalAlerts(stationId),
      getPumpStatus(stationId),
      getEmployeesOnDuty(stationId),
    ]);

    const alerts: AlertsResponse = {
      inventory: inventoryAlerts,
      operational: operationalAlerts,
      pumps,
      employeesOnDuty,
      lastUpdated: getISTDateTime(),
    };

    return {
      statusCode: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        data: alerts,
        meta: {
          stationId,
          timezone: 'Asia/Kolkata',
        },
      }),
    };
  } catch (error) {
    console.error('Error in getAlerts:', error);
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
