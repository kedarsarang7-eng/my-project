// ============================================
// Auth Controller — Login & Token Refresh
// ============================================

import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { queryOne } from '../config/database';
import {
    generateAccessToken,
    generateRefreshToken,
    verifyRefreshToken,
    requireAuth,
} from '../middleware/auth';
import { authRateLimiter } from '../middleware/rateLimiter';
import { loginSchema, validateBody } from '../utils/validators';
import { Admin, Reseller } from '../models/types';
import { logger } from '../utils/logger';

const router = Router();

/**
 * POST /api/auth/login
 * Authenticate admin or reseller and return JWT tokens.
 */
router.post('/login', authRateLimiter, async (req: Request, res: Response) => {
    try {
        const { email, password } = validateBody(loginSchema, req.body);

        // Try admin first, then reseller
        let user: (Admin | Reseller) & { user_type: string } | null = null;

        const admin = await queryOne<Admin>(
            'SELECT * FROM admins WHERE email = $1 AND is_active = TRUE',
            [email]
        );

        if (admin) {
            user = { ...admin, user_type: 'admin' };
        } else {
            const reseller = await queryOne<Reseller>(
                'SELECT * FROM resellers WHERE email = $1 AND is_active = TRUE',
                [email]
            );
            if (reseller) {
                user = { ...reseller, user_type: 'reseller' };
            }
        }

        if (!user) {
            res.status(401).json({ error: 'Invalid credentials', code: 'AUTH_INVALID_CREDENTIALS' });
            return;
        }

        // Verify password
        const passwordValid = await bcrypt.compare(password, user.password_hash);
        if (!passwordValid) {
            logger.warn('Failed login attempt', { email });
            res.status(401).json({ error: 'Invalid credentials', code: 'AUTH_INVALID_CREDENTIALS' });
            return;
        }

        // Generate tokens
        const role = user.user_type === 'admin' ? (user as Admin).role : 'reseller';
        const tokenPayload = { sub: user.id, email: user.email, role };

        const accessToken = generateAccessToken(tokenPayload);
        const refreshToken = generateRefreshToken(tokenPayload);

        // Update last login
        const table = user.user_type === 'admin' ? 'admins' : 'resellers';
        await queryOne(`UPDATE ${table} SET last_login_at = NOW() WHERE id = $1`, [user.id]);

        logger.info('Login successful', { email, role });

        res.json({
            access_token: accessToken,
            refresh_token: refreshToken,
            user: {
                id: user.id,
                email: user.email,
                display_name: user.display_name,
                role,
            },
        });
    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({ error: 'Validation failed', details: error.errors });
            return;
        }
        logger.error('Login error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/auth/refresh
 * Refresh the access token using a valid refresh token.
 */
router.post('/refresh', async (req: Request, res: Response) => {
    try {
        const { refresh_token } = req.body;
        if (!refresh_token) {
            res.status(400).json({ error: 'Refresh token required' });
            return;
        }

        const payload = verifyRefreshToken(refresh_token);
        if (payload.type !== 'refresh') {
            res.status(401).json({ error: 'Invalid token type' });
            return;
        }

        const tokenPayload = { sub: payload.sub, email: payload.email, role: payload.role };
        const newAccessToken = generateAccessToken(tokenPayload);

        res.json({ access_token: newAccessToken });
    } catch (error: any) {
        if (error.name === 'TokenExpiredError') {
            res.status(401).json({ error: 'Refresh token expired. Please login again.', code: 'REFRESH_EXPIRED' });
            return;
        }
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

export default router;
