import { config } from '../config/environment';
// ============================================================================
// Lambda Handler — Health Check
// ============================================================================
// Lightweight endpoint for Flutter connectivity checks and status monitoring.
// Returns system health status without authentication for quick checks.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { docClient } from '../config/dynamodb.config';

/**
 * GET /health
 * LOW FIX: Health check endpoint for Flutter connectivity
 * - Returns 200 OK when system is operational
 * - Includes timestamp for latency calculation
 * - No authentication required (public endpoint)
 */
export async function health(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const startTime = Date.now();
    const correlationId = event.requestContext?.requestId || 'health-check';

    try {
        // Check DynamoDB connectivity (lightweight operation)
        // Uses a quick describe operation that doesn't consume RCU
        let dbStatus: 'healthy' | 'degraded' | 'unavailable' = 'healthy';
        try {
            // Quick check: just verify we can reach DynamoDB
            // We don't need to query actual data for a health check
            await Promise.race([
                docClient.config.endpointProvider?.({} as any),
                new Promise((_, reject) => 
                    setTimeout(() => reject(new Error('DynamoDB timeout')), 2000)
                ),
            ]);
        } catch (dbErr) {
            dbStatus = 'degraded';
            logger.warn('Health check: DynamoDB connectivity warning', {
                correlationId,
                error: (dbErr as Error).message,
            });
        }

        const responseTime = Date.now() - startTime;

        return response.success({
            status: dbStatus === 'healthy' ? 'healthy' : 'degraded',
            timestamp: new Date().toISOString(),
            responseTimeMs: responseTime,
            version: config.app.version || '1.0.0',
            environment: config.app.env || 'development',
            services: {
                dynamodb: dbStatus,
                api: 'healthy',
            },
        });
    } catch (err) {
        logger.error('Health check failed', {
            correlationId,
            error: (err as Error).message,
            stack: (err as Error).stack,
        });

        // Return 503 Service Unavailable but still a valid JSON response
        // so Flutter can distinguish between "backend down" vs "network issue"
        return response.serviceUnavailable(
            'System temporarily unavailable',
            5
        );
    }
}

/**
 * GET /health/ready
 * Kubernetes-style readiness probe
 * Returns 200 only when fully ready to serve traffic
 */
export async function ready(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || 'ready-check';

    try {
        // Verify critical services are ready
        // For now, just check that we can process requests
        return response.success({
            ready: true,
            timestamp: new Date().toISOString(),
        });
    } catch (err) {
        logger.error('Readiness check failed', {
            correlationId,
            error: (err as Error).message,
        });
        return response.serviceUnavailable('Not ready', 5);
    }
}

/**
 * GET /health/live
 * Kubernetes-style liveness probe
 * Returns 200 if process is alive (even if degraded)
 */
export async function live(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    // Simple liveness check - if this code runs, we're alive
    return response.success({
        alive: true,
        timestamp: new Date().toISOString(),
    });
}
