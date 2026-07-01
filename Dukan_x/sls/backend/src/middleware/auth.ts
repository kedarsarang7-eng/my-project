// ============================================
// JWT Authentication Middleware
// ============================================
// Protects admin/reseller routes using Bearer token authentication.
// Access tokens are short-lived (15min), refresh tokens are longer (7d).

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { JwtPayload } from '../models/types';
import { logger } from '../utils/logger';

// Extend Express Request to include authenticated user
declare global {
    namespace Express {
        interface Request {
            user?: JwtPayload;
        }
    }
}

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'dev-access-secret';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret';
const ACCESS_EXPIRY = process.env.JWT_ACCESS_EXPIRY || '15m';
const REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRY || '7d';

// ---- Token Generation ----

export function generateAccessToken(payload: Omit<JwtPayload, 'type' | 'iat' | 'exp'>): string {
    return jwt.sign(
        { ...payload, type: 'access' },
        ACCESS_SECRET,
        { expiresIn: ACCESS_EXPIRY } as jwt.SignOptions
    );
}

export function generateRefreshToken(payload: Omit<JwtPayload, 'type' | 'iat' | 'exp'>): string {
    return jwt.sign(
        { ...payload, type: 'refresh' },
        REFRESH_SECRET,
        { expiresIn: REFRESH_EXPIRY } as jwt.SignOptions
    );
}

// ---- Token Verification ----

export function verifyAccessToken(token: string): JwtPayload {
    return jwt.verify(token, ACCESS_SECRET) as JwtPayload;
}

export function verifyRefreshToken(token: string): JwtPayload {
    return jwt.verify(token, REFRESH_SECRET) as JwtPayload;
}

// ---- Middleware: Require Authentication ----

/**
 * Middleware that verifies the JWT access token from the Authorization header.
 * Sets req.user with the decoded payload.
 */
export function requireAuth(req: Request, res: Response, next: NextFunction): void {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({
            error: 'Authentication required',
            code: 'AUTH_MISSING',
        });
        return;
    }

    const token = authHeader.split(' ')[1];

    try {
        const payload = verifyAccessToken(token);

        if (payload.type !== 'access') {
            res.status(401).json({
                error: 'Invalid token type',
                code: 'AUTH_INVALID_TYPE',
            });
            return;
        }

        req.user = payload;
        next();
    } catch (error: any) {
        if (error.name === 'TokenExpiredError') {
            res.status(401).json({
                error: 'Token expired',
                code: 'AUTH_EXPIRED',
            });
            return;
        }

        logger.warn('Invalid JWT token', { error: error.message });
        res.status(401).json({
            error: 'Invalid token',
            code: 'AUTH_INVALID',
        });
    }
}

// ---- Middleware: Require Admin Role ----

/**
 * Middleware that ensures the authenticated user is an admin (not a reseller).
 * Must be used AFTER requireAuth.
 */
export function requireAdmin(req: Request, res: Response, next: NextFunction): void {
    if (!req.user) {
        res.status(401).json({ error: 'Authentication required', code: 'AUTH_MISSING' });
        return;
    }

    if (req.user.role !== 'admin' && req.user.role !== 'superadmin') {
        res.status(403).json({
            error: 'Admin access required',
            code: 'AUTH_FORBIDDEN',
        });
        return;
    }

    next();
}

// ---- Middleware: Require Superadmin Role ----

export function requireSuperAdmin(req: Request, res: Response, next: NextFunction): void {
    if (!req.user) {
        res.status(401).json({ error: 'Authentication required', code: 'AUTH_MISSING' });
        return;
    }

    if (req.user.role !== 'superadmin') {
        res.status(403).json({
            error: 'Super-admin access required',
            code: 'AUTH_FORBIDDEN_SUPERADMIN',
        });
        return;
    }

    next();
}

// ---- Middleware: Allow Admin OR Reseller ----

export function requireAuthenticatedUser(req: Request, res: Response, next: NextFunction): void {
    if (!req.user) {
        res.status(401).json({ error: 'Authentication required', code: 'AUTH_MISSING' });
        return;
    }

    // Any authenticated user (admin, superadmin, reseller) can access
    next();
}
