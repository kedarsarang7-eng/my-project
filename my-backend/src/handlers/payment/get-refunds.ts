// ============================================================================
// Lambda: getRefunds
// Purpose: Fetch refund history for a bill or business
// Route: GET /billing/payment/refunds (Cognito protected)
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
    docClient, TABLE_NAME, Keys
} from '../../config/dynamodb.config';
import { QueryCommand } from '@aws-sdk/lib-dynamodb';

interface CognitoClaims {
    sub: string;
    email?: string;
    name?: string;
    role?: string;
    businessId?: string;
}

function getCognitoClaims(event: any): CognitoClaims | null {
    const authorizer = event.requestContext?.authorizer;
    if (!authorizer?.claims) return null;
    return {
        sub: authorizer.claims.sub || '',
        email: authorizer.claims.email || '',
        name: authorizer.claims.name || '',
        role: authorizer.claims['custom:role'] || '',
        businessId: authorizer.claims['custom:businessId'] || authorizer.claims['custom:business_id'],
    };
}

function errorResponse(statusCode: number, message: string): APIGatewayProxyResult {
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ success: false, error: message }),
    };
}

function successResponse(data: Record<string, unknown>): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ success: true, ...data }),
    };
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    console.log('Get refunds request:', event.queryStringParameters);

    // Verify authentication
    const claims = getCognitoClaims(event);
    if (!claims) {
        return errorResponse(401, 'Unauthorized');
    }

    const { billId, businessId, limit = '20' } = event.queryStringParameters || {};
    const jwtBusinessId = claims.businessId;

    try {
        // If billId provided, get refunds for specific bill
        if (billId) {
            const result = await docClient.send(new QueryCommand({
                TableName: TABLE_NAME,
                IndexName: 'GSI1',
                KeyConditionExpression: 'GSI1PK = :pk',
                ExpressionAttributeValues: {
                    ':pk': Keys.refundByBillGSI(billId),
                },
                ScanIndexForward: false, // Newest first
                Limit: parseInt(limit, 10),
            }));

            const refunds = result.Items || [];

            // Verify tenant authorization for each refund
            const authorizedRefunds = refunds.filter((refund: any) => refund.businessId === jwtBusinessId);

            return successResponse({
                refunds: authorizedRefunds,
                count: authorizedRefunds.length,
            });
        }

        // If businessId provided (or use JWT), get all refunds for business
        const targetBusinessId = businessId || jwtBusinessId;
        if (!targetBusinessId) {
            return errorResponse(400, 'Missing billId or businessId');
        }

        // Verify tenant authorization
        if (targetBusinessId !== jwtBusinessId) {
            return errorResponse(403, 'Cannot access refunds from other businesses');
        }

        // Query by business ID using main table
        const result = await docClient.send(new QueryCommand({
            TableName: TABLE_NAME,
            KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
            ExpressionAttributeValues: {
                ':pk': `TENANT#${targetBusinessId}`,
                ':sk': 'REFUND#',
            },
            ScanIndexForward: false,
            Limit: parseInt(limit, 10),
        }));

        const refunds = result.Items || [];

        return successResponse({
            refunds,
            count: refunds.length,
        });

    } catch (error: any) {
        console.error('Get refunds error:', error);
        return errorResponse(500, `Error fetching refunds: ${error.message}`);
    }
};
