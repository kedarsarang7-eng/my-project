// ============================================
// Session Service — Floating License Management
// ============================================
// Tracks active device sessions for concurrency control.
// A license with max_devices=3 can have at most 3 active sessions.
// Sessions auto-expire after 30 minutes without a heartbeat.

import { query, queryOne } from '../config/database';
import { generateSecureToken } from '../utils/crypto';
import { ActiveSession } from '../models/types';
import { logger } from '../utils/logger';

const SESSION_TTL_MINUTES = 30; // Sessions expire after 30min without heartbeat

/**
 * Create or refresh a session for a device.
 * If a session already exists for this HWID binding, refresh it.
 * If max concurrent sessions reached, reject.
 */
export async function createOrRefreshSession(
    licenseId: string,
    hwidBindingId: string,
    ipAddress: string | null,
    countryCode: string | null,
    maxDevices: number
): Promise<{ session: ActiveSession | null; error?: string }> {

    // First, clean up expired sessions
    await cleanExpiredSessions(licenseId);

    // Check if session already exists for this HWID binding
    const existing = await queryOne<ActiveSession>(
        `SELECT * FROM active_sessions 
     WHERE license_id = $1 AND hwid_binding_id = $2 AND expires_at > NOW()`,
        [licenseId, hwidBindingId]
    );

    if (existing) {
        // Refresh the session (heartbeat)
        const refreshed = await queryOne<ActiveSession>(
            `UPDATE active_sessions 
       SET last_heartbeat = NOW(), 
           expires_at = NOW() + INTERVAL '${SESSION_TTL_MINUTES} minutes',
           ip_address = $2,
           country_code = $3
       WHERE id = $1 RETURNING *`,
            [existing.id, ipAddress, countryCode]
        );
        return { session: refreshed };
    }

    // Count current active sessions
    const countResult = await queryOne<{ count: string }>(
        `SELECT COUNT(*) as count FROM active_sessions 
     WHERE license_id = $1 AND expires_at > NOW()`,
        [licenseId]
    );
    const activeCount = parseInt(countResult?.count || '0', 10);

    if (activeCount >= maxDevices) {
        return {
            session: null,
            error: `Concurrent device limit reached (${activeCount}/${maxDevices}). Close the application on another device first.`,
        };
    }

    // Create new session
    const sessionToken = generateSecureToken(32);
    const session = await queryOne<ActiveSession>(
        `INSERT INTO active_sessions (
      license_id, hwid_binding_id, session_token, ip_address, country_code,
      expires_at
    ) VALUES ($1, $2, $3, $4, $5, NOW() + INTERVAL '${SESSION_TTL_MINUTES} minutes')
    RETURNING *`,
        [licenseId, hwidBindingId, sessionToken, ipAddress, countryCode]
    );

    logger.info('Session created', {
        licenseId,
        activeCount: activeCount + 1,
        maxDevices,
    });

    return { session: session! };
}

/**
 * Process a heartbeat — keep the session alive.
 */
export async function heartbeat(sessionToken: string): Promise<boolean> {
    const result = await queryOne<ActiveSession>(
        `UPDATE active_sessions 
     SET last_heartbeat = NOW(), 
         expires_at = NOW() + INTERVAL '${SESSION_TTL_MINUTES} minutes'
     WHERE session_token = $1 AND expires_at > NOW()
     RETURNING id`,
        [sessionToken]
    );
    return result !== null;
}

/**
 * End a session (user closes the application).
 */
export async function endSession(sessionToken: string): Promise<boolean> {
    const result = await queryOne<ActiveSession>(
        'DELETE FROM active_sessions WHERE session_token = $1 RETURNING id',
        [sessionToken]
    );
    return result !== null;
}

/**
 * Clean up expired sessions for a license.
 */
export async function cleanExpiredSessions(licenseId: string): Promise<number> {
    const result = await query<ActiveSession>(
        'DELETE FROM active_sessions WHERE license_id = $1 AND expires_at <= NOW() RETURNING id',
        [licenseId]
    );
    return result.length;
}

/**
 * Get all active sessions for a license.
 */
export async function getActiveSessions(licenseId: string): Promise<ActiveSession[]> {
    return query<ActiveSession>(
        'SELECT * FROM active_sessions WHERE license_id = $1 AND expires_at > NOW() ORDER BY created_at DESC',
        [licenseId]
    );
}

/**
 * Get count of all active sessions across all licenses (for analytics).
 */
export async function getTotalActiveSessions(): Promise<number> {
    const result = await queryOne<{ count: string }>(
        'SELECT COUNT(*) as count FROM active_sessions WHERE expires_at > NOW()'
    );
    return parseInt(result?.count || '0', 10);
}
