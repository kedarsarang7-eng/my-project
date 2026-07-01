// ============================================
// SLS Backend — Express Application Entry Point (Port 4000)
// ============================================
// Admin Panel + Licensing ONLY
// Handles: License Management, Validation, HWID, Resellers, Offline Activation, Analytics, Cognito Auth
//
// App-facing routes (Customer, RBAC, Prescriptions, Reminders, Staff, Invoices)
// have been MOVED to sls/app-backend (Port 5000).

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import dotenv from 'dotenv';

// Load environment variables FIRST
dotenv.config();

import { logger } from './utils/logger';
import { testConnection } from './config/database';
import { generateRsaKeyPair } from './utils/crypto';
import { generalRateLimiter } from './middleware/rateLimiter';
import fs from 'fs';

// Controllers
import authController from './controllers/authController';
import licenseController from './controllers/licenseController';
import validateController from './controllers/validateController';
import hwidController from './controllers/hwidController';
import resellerController from './controllers/resellerController';
import offlineController from './controllers/offlineController';
import analyticsController from './controllers/analyticsController';
// MOVED to sls/app-backend (port 5000):
// customerController, prescriptionController, rbacController,
// reminderController, staffOnboardingController, invoiceController
import adminDynamoController from './controllers/adminDynamoController';
import clientValidateController from './controllers/clientValidateController';
import cognitoAuthController from './controllers/cognitoAuthController';
import storageController from './controllers/storageController';

const app = express();
const PORT = parseInt(process.env.PORT || '4000', 10);

// ============================================
// Global Middleware
// ============================================

// Security headers
app.use(helmet());

// CORS — allow Admin Panel only (Customer/Staff apps use app-backend)
app.use(cors({
    origin: (process.env.CORS_ORIGIN || 'http://localhost:3000').split(',').map(s => s.trim()),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-shop-id'],
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Compression
app.use(compression());

// Trust proxy (for correct IP behind reverse proxy)
app.set('trust proxy', 1);

// General rate limiter (100 req/min for all routes)
app.use('/api', generalRateLimiter);

// Request logging
app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        const duration = Date.now() - start;
        if (req.path !== '/api/health') { // Don't log health checks
            logger.debug(`${req.method} ${req.path}`, {
                status: res.statusCode,
                duration: `${duration}ms`,
                ip: req.ip,
            });
        }
    });
    next();
});

// ============================================
// API Routes
// ============================================

// Health check
app.get('/api/health', (_req, res) => {
    res.json({
        status: 'ok',
        service: 'sls-backend',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
    });
});

// Auth routes
app.use('/api/auth', authController);

// License management (Admin)
app.use('/api/licenses', licenseController);

// License validation (Client-facing)
app.use('/api/validate', validateController);

// HWID management (Admin, nested under licenses)
app.use('/api/licenses', hwidController);

// Reseller management
app.use('/api/resellers', resellerController);

// Offline activation
app.use('/api/offline', offlineController);

// Analytics
app.use('/api/analytics', analyticsController);


// Admin DynamoDB License Key Management (Express wrappers for Lambda logic)
app.use('/api/admin', adminDynamoController);

// Client-facing DynamoDB License Validation (no auth required — desktop client)
app.use('/api/client', clientValidateController);

// Cognito Auth — Dual-Portal Login (Owner/Staff), MFA, Staff Account Creation
app.use('/api/cognito-auth', cognitoAuthController);

// S3 Storage — Tenant-scoped file upload/download via pre-signed URLs
app.use('/api/storage', storageController);

// ============================================
// 404 Handler
// ============================================
app.use((_req, res) => {
    res.status(404).json({ error: 'Endpoint not found', code: 'NOT_FOUND' });
});

// ============================================
// Global Error Handler
// ============================================
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    logger.error('Unhandled error', { error: err.message, stack: err.stack });
    res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        ...(process.env.NODE_ENV === 'development' ? { details: err.message } : {}),
    });
});

// ============================================
// Server Startup
// ============================================

async function startServer(): Promise<void> {
    try {
        // 1. Test database connection
        const dbConnected = await testConnection();
        if (!dbConnected) {
            logger.error('Failed to connect to database. Exiting.');
            process.exit(1);
        }

        // 2. Ensure RSA keys exist for offline activation
        const privateKeyPath = process.env.RSA_PRIVATE_KEY_PATH || './keys/private.pem';
        const publicKeyPath = process.env.RSA_PUBLIC_KEY_PATH || './keys/public.pem';

        if (!fs.existsSync(privateKeyPath) || !fs.existsSync(publicKeyPath)) {
            logger.info('RSA keys not found, generating new key pair...');
            generateRsaKeyPair(privateKeyPath, publicKeyPath);
            logger.info('RSA key pair generated successfully');
        }

        // 3. Start Express server
        server = app.listen(PORT, () => {
            logger.info(`🚀 SLS Backend running on port ${PORT}`);
            logger.info(`📋 API docs: http://localhost:${PORT}/api/health`);
            logger.info(`🔐 Environment: ${process.env.NODE_ENV || 'development'}`);
        });
    } catch (error: any) {
        logger.error('Failed to start server', { error: error.message });
        process.exit(1);
    }
}

// Graceful shutdown — drain DB pool + close HTTP server
let server: ReturnType<typeof app.listen> | null = null;

function gracefulShutdown(signal: string) {
    logger.info(`${signal} received. Shutting down gracefully...`);
    if (server) {
        server.close(async () => {
            logger.info('HTTP server closed');
            try {
                const { pool } = await import('./config/database');
                await pool.end();
                logger.info('Database pool drained');
            } catch (e: any) {
                logger.error('Error draining pool', { error: e.message });
            }
            process.exit(0);
        });
        // Force exit after 5s if graceful shutdown hangs
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
