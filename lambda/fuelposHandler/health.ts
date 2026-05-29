import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';

const client = new DynamoDBClient({});

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Content-Type': 'application/json',
  };

  try {
    // Basic health check - can we reach DynamoDB?
    const checks: Record<string, string> = {
      lambda: 'healthy',
      timestamp: new Date().toISOString(),
    };

    try {
      // Try to list tables (lightweight operation)
      const { ListTablesCommand } = await import('@aws-sdk/client-dynamodb');
      await client.send(new ListTablesCommand({ Limit: 1 }));
      checks.dynamodb = 'connected';
    } catch (err) {
      checks.dynamodb = 'unavailable';
    }

    const allHealthy = Object.values(checks).every(
      (v) => v === 'healthy' || v === 'connected'
    );

    return {
      statusCode: allHealthy ? 200 : 503,
      headers: corsHeaders,
      body: JSON.stringify({
        status: allHealthy ? 'healthy' : 'degraded',
        service: 'fuelpos-api',
        checks,
      }),
    };
  } catch (error) {
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        status: 'error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
};
