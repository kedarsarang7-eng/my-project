// ============================================================================
// Lambda: paymentAnalytics
// Purpose: Payment analytics endpoints
// Routes:
//   GET /analytics/payments - Overall payment stats for date range
//   GET /analytics/payments/today - Today's real-time stats
//   GET /analytics/refunds - Refund history
//   GET /analytics/payment-methods - Method breakdown
//   GET /analytics/failures - Failure analysis
//   GET /analytics/daily-trend - Daily trend data
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
    docClient, TABLE_NAME, Keys
} from '../../config/dynamodb.config';
import { QueryCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';

interface CognitoClaims {
    sub: string;
    businessId?: string;
}

function getCognitoClaims(event: any): CognitoClaims | null {
    const authorizer = event.requestContext?.authorizer;
    if (!authorizer?.claims) return null;
    return {
        sub: authorizer.claims.sub || '',
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

// Get payment stats for date range
async function getPaymentAnalytics(
    businessId: string,
    startDate: string,
    endDate: string
): Promise<any> {
    try {
        // Query payments for business
        const paymentsResult = await docClient.send(new QueryCommand({
            TableName: TABLE_NAME,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :pk AND GSI1SK BETWEEN :start AND :end',
            ExpressionAttributeValues: {
                ':pk': `PAYMENT#BUSINESS#${businessId}`,
                ':start': `PAYMENT#${startDate}`,
                ':end': `PAYMENT#${endDate}`,
            },
        }));

        const payments = paymentsResult.Items || [];

        // Calculate stats
        let successfulPayments = 0;
        let failedPayments = 0;
        let refundedTransactions = 0;
        let totalVolume = 0;
        let refundVolume = 0;

        const paymentMethods: Record<string, number> = {};
        const failureReasons: Record<string, number> = {};

        for (const payment of payments) {
            const amount = payment.amount || 0;
            const status = payment.status || 'unknown';
            const method = payment.paymentMethod || 'unknown';

            // Count by status
            if (status === 'Completed' || status === 'captured') {
                successfulPayments++;
                totalVolume += amount;
            } else if (status === 'Failed' || status === 'failed') {
                failedPayments++;
                const reason = payment.failureReason || 'Unknown';
                failureReasons[reason] = (failureReasons[reason] || 0) + 1;
            } else if (status === 'Refunded' || status === 'refunded') {
                refundedTransactions++;
                refundVolume += amount;
            }

            // Count by method
            paymentMethods[method] = (paymentMethods[method] || 0) + 1;
        }

        const totalTransactions = payments.length;
        const successRate = totalTransactions > 0 
            ? (successfulPayments / totalTransactions) * 100 
            : 0;
        const averageTransactionValue = successfulPayments > 0 
            ? totalVolume / successfulPayments 
            : 0;

        return {
            totalTransactions,
            successfulPayments,
            failedPayments,
            refundedTransactions,
            totalVolume,
            refundVolume,
            successRate: parseFloat(successRate.toFixed(1)),
            averageTransactionValue: parseFloat(averageTransactionValue.toFixed(2)),
            paymentMethods,
            failureReasons,
        };
    } catch (error: any) {
        console.error('Payment analytics error:', error);
        throw error;
    }
}

// Get today's stats
async function getTodayStats(businessId: string, date: string): Promise<any> {
    const today = new Date(date);
    const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const endOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);

    return getPaymentAnalytics(
        businessId,
        startOfDay.toISOString(),
        endOfDay.toISOString()
    );
}

// Get refund history
async function getRefundHistory(
    businessId: string,
    startDate: string,
    endDate: string,
    limit: number = 50
): Promise<any[]> {
    try {
        const result = await docClient.send(new QueryCommand({
            TableName: TABLE_NAME,
            KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
            ExpressionAttributeValues: {
                ':pk': `TENANT#${businessId}`,
                ':sk': 'REFUND#',
            },
            ScanIndexForward: false,
            Limit: limit,
        }));

        const refunds = result.Items || [];

        // Filter by date range
        return refunds.filter((refund: any) => {
            const refundDate = new Date(refund.createdAt || 0);
            return refundDate >= new Date(startDate) && refundDate <= new Date(endDate);
        });
    } catch (error: any) {
        console.error('Refund history error:', error);
        return [];
    }
}

// Get daily trend
async function getDailyTrend(
    businessId: string,
    startDate: string,
    endDate: string
): Promise<any[]> {
    try {
        const result = await docClient.send(new QueryCommand({
            TableName: TABLE_NAME,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :pk AND GSI1SK BETWEEN :start AND :end',
            ExpressionAttributeValues: {
                ':pk': `PAYMENT#BUSINESS#${businessId}`,
                ':start': `PAYMENT#${startDate}`,
                ':end': `PAYMENT#${endDate}`,
            },
        }));

        const payments = result.Items || [];

        // Group by date
        const dailyStats: Record<string, { successful: number; failed: number }> = {};

        for (const payment of payments) {
            const date = new Date(payment.createdAt || Date.now()).toISOString().split('T')[0];
            if (!dailyStats[date]) {
                dailyStats[date] = { successful: 0, failed: 0 };
            }

            const status = payment.status || 'unknown';
            if (status === 'Completed' || status === 'captured') {
                dailyStats[date].successful++;
            } else if (status === 'Failed' || status === 'failed') {
                dailyStats[date].failed++;
            }
        }

        return Object.entries(dailyStats).map(([date, stats]) => ({
            date,
            ...stats,
        }));
    } catch (error: any) {
        console.error('Daily trend error:', error);
        return [];
    }
}

// Main handler
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    console.log('Analytics request:', event.path, event.queryStringParameters);

    const claims = getCognitoClaims(event);
    if (!claims) {
        return errorResponse(401, 'Unauthorized');
    }

    const { startDate, endDate, businessId, date, limit } = event.queryStringParameters || {};
    const jwtBusinessId = claims.businessId;
    const targetBusinessId = businessId || jwtBusinessId;

    if (!targetBusinessId) {
        return errorResponse(400, 'Missing businessId');
    }

    // Verify tenant authorization
    if (targetBusinessId !== jwtBusinessId) {
        return errorResponse(403, 'Cannot access analytics from other businesses');
    }

    const path = event.path || '';

    try {
        // Route to appropriate handler based on path
        if (path.includes('/today')) {
            // Today stats
            const today = date || new Date().toISOString();
            const stats = await getTodayStats(targetBusinessId, today);
            return successResponse(stats);
        } else if (path.includes('/refunds')) {
            // Refund history
            const refunds = await getRefundHistory(
                targetBusinessId,
                startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
                endDate || new Date().toISOString(),
                parseInt(limit || '50', 10)
            );
            return successResponse({ refunds });
        } else if (path.includes('/daily-trend')) {
            // Daily trend
            const trend = await getDailyTrend(
                targetBusinessId,
                startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
                endDate || new Date().toISOString()
            );
            return successResponse({ trend });
        } else {
            // Main payment analytics
            const analytics = await getPaymentAnalytics(
                targetBusinessId,
                startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
                endDate || new Date().toISOString()
            );
            return successResponse(analytics);
        }
    } catch (error: any) {
        console.error('Analytics handler error:', error);
        return errorResponse(500, `Error: ${error.message}`);
    }
};
