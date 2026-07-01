// ============================================
// App Backend — Express Application Entry Point
// ============================================
// DukanX Application Backend (Port 5000)
// Handles: Customer App, Staff App, RBAC, Prescriptions, Reminders, Invoices
//
// SEPARATED from sls/backend (Port 4000) which handles ONLY:
//   Admin Panel, Licensing, HWID, Resellers, Offline Activation, Analytics
// ============================================

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import dotenv from 'dotenv';

// Load environment variables FIRST
dotenv.config();

import { logger } from './utils/logger';
import { testConnection } from './config/database';
import { generalRateLimiter } from './middleware/rateLimiter';

// Controllers
import customerController from './controllers/customerController';
import prescriptionController from './controllers/prescriptionController';
import rbacController from './controllers/rbacController';
import reminderController from './controllers/reminderController';
import staffOnboardingController from './controllers/staffOnboardingController';
import invoiceController from './controllers/invoiceController';
import storageController from './controllers/storageController';

const app = express();
const PORT = parseInt(process.env.APP_BACKEND_PORT || '5000', 10);

// ============================================
// Global Middleware
// ============================================

// Security headers
app.use(helmet());

// CORS — allow Customer App + Staff App origins
app.use(cors({
    origin: (process.env.APP_CORS_ORIGIN || 'http://localhost:3000').split(',').map(s => s.trim()),
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

// General rate limiter (200 req/min — higher than admin backend for mobile traffic)
app.use('/api', generalRateLimiter);

// Request logging
app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        const duration = Date.now() - start;
        if (req.path !== '/api/health') {
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
        service: 'app-backend',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
    });
});

// Customer App (Mobile — Cognito Auth + Tenant Middleware)
app.use('/api/customer', customerController);

// Shared Prescriptions (Clinic <-> Pharmacy bridge)
app.use('/api/prescriptions', prescriptionController);

// RBAC — Staff Management & Permission Control
app.use('/api/rbac', rbacController);

// Payment Reminders (Manual + Auto)
app.use('/api/reminders', reminderController);

// Staff Onboarding — Invite Code Generation, Profile Claiming, Tenant-Scoped Operations
app.use('/api/staff-onboard', staffOnboardingController);

// Customer Invoices — IDOR-safe invoice access with 4-layer security
app.use('/api/invoices', invoiceController);

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

        // 2. Start Express server
        server = app.listen(PORT, () => {
            logger.info(`🚀 App Backend running on port ${PORT}`);
            logger.info(`📋 Health: http://localhost:${PORT}/api/health`);
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
