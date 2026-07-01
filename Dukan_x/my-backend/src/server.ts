// ============================================================================
// Express Server — Lambda Handler Adapter for EC2 Deployment
// ============================================================================
// Wraps all Lambda handlers in Express routes so my-backend can run on EC2
// alongside sls-backend (port 4000) and app-backend (port 5000).
//
// Each Lambda handler receives a synthetic APIGatewayProxyEventV2 object
// built from the Express request, and the Lambda response is translated
// back into an Express response.
//
// Usage:
//   npm run start:ec2    (runs this file)
//   pm2 start ecosystem.config.js --only my-backend
// ============================================================================

import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { logger } from './utils/logger';

dotenv.config();

const app = express();
const PORT = parseInt(process.env.MY_BACKEND_PORT || '8000', 10);

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// ── Lambda → Express Adapter ────────────────────────────────────────────────

// Accepts both plain Lambda handlers and authorizedHandler-wrapped functions
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type LambdaHandler = (...args: any[]) => Promise<any>;

/**
 * Converts an Express request into a synthetic APIGatewayProxyEventV2,
 * invokes the Lambda handler, then writes the Lambda response to Express.
 */
function adaptHandler(handler: LambdaHandler) {
    return async (req: express.Request, res: express.Response): Promise<void> => {
        try {
            // Build synthetic API Gateway event from Express request
            const event: APIGatewayProxyEventV2 = {
                version: '2.0',
                routeKey: `${req.method} ${req.route?.path || req.path}`,
                rawPath: req.path,
                rawQueryString: req.url.includes('?') ? req.url.split('?')[1] : '',
                headers: req.headers as Record<string, string>,
                queryStringParameters: (req.query as Record<string, string>) || undefined,
                pathParameters: req.params || undefined,
                body: req.body ? JSON.stringify(req.body) : undefined,
                isBase64Encoded: false,
                requestContext: {
                    accountId: 'local',
                    apiId: 'local',
                    domainName: req.hostname,
                    domainPrefix: '',
                    http: {
                        method: req.method,
                        path: req.path,
                        protocol: req.protocol,
                        sourceIp: req.ip || '127.0.0.1',
                        userAgent: req.get('user-agent') || '',
                    },
                    requestId: `ec2-${Date.now()}`,
                    routeKey: `${req.method} ${req.path}`,
                    stage: '$default',
                    time: new Date().toISOString(),
                    timeEpoch: Date.now(),
                },
            };

            // Invoke Lambda handler
            const result = await handler(event);

            // Translate Lambda response → Express response
            // Result can be string or structured object
            if (typeof result === 'string') {
                res.status(200).send(result);
                return;
            }

            if (result.headers) {
                Object.entries(result.headers).forEach(([key, value]: [string, any]) => {
                    res.setHeader(key, String(value));
                });
            }

            res.status(result.statusCode || 200);

            if (result.body) {
                res.send(result.body);
            } else {
                res.end();
            }
        } catch (err: any) {
            logger.error('Handler adapter error', { error: err.message, path: req.path });
            res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: err.message } });
        }
    };
}

// ── Health Check ────────────────────────────────────────────────────────────
app.get('/api/health', (_req: express.Request, res: express.Response) => {
    res.json({
        status: 'healthy',
        service: 'my-backend',
        port: PORT,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
    });
});

// ── Route Registration ──────────────────────────────────────────────────────
// Mirrors the routes from serverless.yml exactly.

async function registerRoutes() {
    // Auth
    const auth = await import('./handlers/auth');
    app.post('/auth/signup', adaptHandler(auth.signup));
    app.post('/auth/login', adaptHandler(auth.login));
    app.post('/auth/refresh', adaptHandler(auth.refresh));

    // Dashboard
    const dashboard = await import('./handlers/dashboard');
    app.get('/dashboard', adaptHandler(dashboard.getDashboard));

    // Inventory
    const inventory = await import('./handlers/inventory');
    app.get('/inventory', adaptHandler(inventory.getItems));
    app.post('/inventory', adaptHandler(inventory.createItem));
    app.put('/inventory/:id', adaptHandler(inventory.updateItem));
    app.delete('/inventory/:id', adaptHandler(inventory.deleteItem));

    // Payment (legacy — Firebase)
    const payment = await import('./handlers/payment');
    app.post('/payment/initiate', adaptHandler(payment.initiatePayment));
    app.post('/payment/webhook', adaptHandler(payment.paymentWebhook as unknown as LambdaHandler));

    // Storage (S3 signed URLs)
    const storage = await import('./handlers/storage');
    app.get('/storage/signed-url', adaptHandler(storage.getSignedUrl));

    // Notifications
    const notification = await import('./handlers/notification');
    app.post('/notifications/register-device', adaptHandler(notification.registerDevice));

    // Vendor-Customer Linking
    const linking = await import('./handlers/linking');
    app.post('/linking/generate-token', adaptHandler(linking.generateToken));
    app.post('/linking/link', adaptHandler(linking.link));
    app.get('/linking/my-vendors', adaptHandler(linking.myVendors));
    app.get('/linking/my-customers', adaptHandler(linking.myCustomers));
    app.delete('/linking/:userId', adaptHandler(linking.revokeLink));

    // Invoices
    const invoices = await import('./handlers/invoices');
    app.post('/invoices', adaptHandler(invoices.createInvoice));
    app.post('/invoices/:id/finalize', adaptHandler(invoices.finalizeInvoice));
    app.post('/invoices/:id/void', adaptHandler(invoices.voidInvoice));
    app.post('/invoices/:id/send', adaptHandler(invoices.sendInvoice));

    // Stock Management
    const stock = await import('./handlers/stock');
    app.post('/stock/lookup-barcode', adaptHandler(stock.lookupBarcode));
    app.post('/stock/analyze-image', adaptHandler(stock.analyzeImage));
    app.post('/stock/add', adaptHandler(stock.addStock));

    // Offline Sync
    const sync = await import('./handlers/sync');
    app.post('/sync/push', adaptHandler(sync.pushChanges));
    app.post('/sync/pull', adaptHandler(sync.pullChanges));

    // AI Insights
    const insights = await import('./handlers/insights');
    app.post('/insights/ai-insight', adaptHandler(insights.aiInsight));

    // Payments (CRUD)
    const payments = await import('./handlers/payments');
    app.get('/payments', adaptHandler(payments.listPayments));
    app.get('/payments/:id', adaptHandler(payments.getPayment));
    app.post('/payments', adaptHandler(payments.recordPayment));

    // Customers
    const customers = await import('./handlers/customers');
    app.get('/customers', adaptHandler(customers.listCustomers));
    app.get('/customers/:id/ledger', adaptHandler(customers.getCustomerLedger));

    // Products
    const products = await import('./handlers/products');
    app.get('/products', adaptHandler(products.listProducts));

    // Reports
    const reports = await import('./handlers/reports');
    app.get('/reports/sales', adaptHandler(reports.salesReport));
    app.get('/reports/gstr1', adaptHandler(reports.gstr1Report));

    // Admin
    const admin = await import('./handlers/admin');
    app.post('/admin/kill-switch', adaptHandler(admin.killSwitch));
    app.get('/admin/status', adaptHandler(admin.systemStatus));

    logger.info('All routes registered (30 handlers across 16 modules)');
}

// ── 404 Handler ─────────────────────────────────────────────────────────────
function register404() {
    app.use((_req: express.Request, res: express.Response) => {
        res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Endpoint not found' } });
    });
}

// ── Server Startup ──────────────────────────────────────────────────────────
let server: ReturnType<typeof app.listen> | null = null;

async function startServer() {
    try {
        await registerRoutes();
        register404();

        server = app.listen(PORT, () => {
            logger.info(`🚀 my-backend running on port ${PORT} (EC2 mode)`);
            logger.info(`📋 Health: http://localhost:${PORT}/api/health`);
            logger.info(`🔐 Environment: ${process.env.NODE_ENV || 'development'}`);
        });
    } catch (err: any) {
        logger.error('Failed to start my-backend', { error: err.message });
        process.exit(1);
    }
}

// ── Graceful Shutdown ───────────────────────────────────────────────────────
function gracefulShutdown(signal: string) {
    logger.info(`${signal} received. Shutting down my-backend...`);
    if (server) {
        server.close(async () => {
            logger.info('HTTP server closed');
            try {
                const { getPool } = await import('./config/db.config');
                const pool = getPool();
                await pool.end();
                logger.info('Database pool drained');
            } catch (e: any) {
                logger.error('Error draining pool', { error: e.message });
            }
            process.exit(0);
        });
        setTimeout(() => {
            logger.error('Graceful shutdown timed out, forcing exit');
            process.exit(1);
        }, 5000);
    } else {
        process.exit(0);
    }
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

startServer();

export default app;
