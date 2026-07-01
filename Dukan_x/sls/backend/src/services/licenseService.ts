// ============================================
// License Service — Core Business Logic
// ============================================

import { query, queryOne } from '../config/database';
import { invalidateLicenseCache } from '../config/redis';
import { generateLicenseKey, hashKey } from '../utils/crypto';
import {
    License, CreateLicenseRequest, LicenseStatus,
    PaginationQuery, PaginatedResponse,
} from '../models/types';
import { logger } from '../utils/logger';

/**
 * Create a new license key.
 * Generates a cryptographically secure key and stores it with SHA-256 hash.
 */
export async function createLicense(
    data: CreateLicenseRequest,
    issuedBy: string,
    resellerId?: string
): Promise<License> {
    const licenseKey = generateLicenseKey();
    const keyHash = hashKey(licenseKey);

    // Calculate expiry for trial licenses
    let expiresAt = data.expires_at || null;
    if (data.license_type === 'trial' && data.trial_days && !expiresAt) {
        const expiry = new Date();
        expiry.setDate(expiry.getDate() + data.trial_days);
        expiresAt = expiry.toISOString();
    }

    // Lifetime licenses never expire
    if (data.license_type === 'lifetime') {
        expiresAt = null;
    }

    const result = await queryOne<License>(
        `INSERT INTO licenses (
      license_key, key_hash, license_type, tier, feature_flags,
      max_devices, allowed_countries, expires_at, trial_days,
      issued_to_email, issued_to_name, issued_by, reseller_id, notes
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
    RETURNING *`,
        [
            licenseKey, keyHash, data.license_type, data.tier,
            JSON.stringify(data.feature_flags || {}),
            data.max_devices || 1,
            data.allowed_countries || [],
            expiresAt,
            data.trial_days || null,
            data.issued_to_email || null,
            data.issued_to_name || null,
            issuedBy,
            resellerId || null,
            data.notes || null,
        ]
    );

    logger.info('License created', { id: result!.id, type: data.license_type, tier: data.tier });
    return result!;
}

/**
 * Get a license by its ID.
 */
export async function getLicenseById(id: string): Promise<License | null> {
    return queryOne<License>(
        'SELECT * FROM licenses WHERE id = $1 AND is_deleted = FALSE',
        [id]
    );
}

/**
 * Get a license by its key hash (used during validation).
 */
export async function getLicenseByKeyHash(keyHash: string): Promise<License | null> {
    return queryOne<License>(
        'SELECT * FROM licenses WHERE key_hash = $1 AND is_deleted = FALSE',
        [keyHash]
    );
}

/**
 * List licenses with pagination, filtering, and search.
 */
export async function listLicenses(params: PaginationQuery): Promise<PaginatedResponse<License>> {
    const {
        page = 1, limit = 25, sort_by = 'created_at', sort_order = 'desc',
        search, status, tier, license_type,
    } = params;

    const offset = (page - 1) * limit;
    const conditions: string[] = ['is_deleted = FALSE'];
    const values: any[] = [];
    let paramIndex = 1;

    if (status) {
        conditions.push(`status = $${paramIndex++}`);
        values.push(status);
    }
    if (tier) {
        conditions.push(`tier = $${paramIndex++}`);
        values.push(tier);
    }
    if (license_type) {
        conditions.push(`license_type = $${paramIndex++}`);
        values.push(license_type);
    }
    if (search) {
        conditions.push(`(
      license_key ILIKE $${paramIndex} OR 
      issued_to_email ILIKE $${paramIndex} OR 
      issued_to_name ILIKE $${paramIndex} OR
      notes ILIKE $${paramIndex}
    )`);
        values.push(`%${search}%`);
        paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // Whitelist sortable columns to prevent SQL injection
    const allowedSortColumns = ['created_at', 'updated_at', 'expires_at', 'license_key', 'status', 'tier'];
    const safeSort = allowedSortColumns.includes(sort_by) ? sort_by : 'created_at';
    const safeOrder = sort_order === 'asc' ? 'ASC' : 'DESC';

    // Count total
    const countResult = await queryOne<{ count: string }>(
        `SELECT COUNT(*) as count FROM licenses ${whereClause}`,
        values
    );
    const total = parseInt(countResult?.count || '0', 10);

    // Fetch page
    const data = await query<License>(
        `SELECT * FROM licenses ${whereClause} 
     ORDER BY ${safeSort} ${safeOrder} 
     LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
        [...values, limit, offset]
    );

    return {
        data,
        pagination: {
            page,
            limit,
            total,
            total_pages: Math.ceil(total / limit),
        },
    };
}

/**
 * Update a license's properties.
 */
export async function updateLicense(
    id: string,
    updates: Partial<License>
): Promise<License | null> {
    const fields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    const updatable: (keyof License)[] = [
        'status', 'tier', 'feature_flags', 'max_devices',
        'allowed_countries', 'expires_at', 'issued_to_email',
        'issued_to_name', 'notes',
    ];

    for (const field of updatable) {
        if (updates[field] !== undefined) {
            if (field === 'feature_flags') {
                fields.push(`${field} = $${paramIndex++}`);
                values.push(JSON.stringify(updates[field]));
            } else {
                fields.push(`${field} = $${paramIndex++}`);
                values.push(updates[field]);
            }
        }
    }

    if (fields.length === 0) return getLicenseById(id);

    values.push(id);
    const result = await queryOne<License>(
        `UPDATE licenses SET ${fields.join(', ')} WHERE id = $${paramIndex} AND is_deleted = FALSE RETURNING *`,
        values
    );

    // Invalidate cache
    if (result) {
        await invalidateLicenseCache(result.key_hash);
        logger.info('License updated', { id, fields: fields.map(f => f.split(' =')[0]) });
    }

    return result;
}

/**
 * Change license status (suspend, ban, reactivate).
 */
export async function changeStatus(id: string, newStatus: LicenseStatus): Promise<License | null> {
    return updateLicense(id, { status: newStatus } as Partial<License>);
}

/**
 * Soft-delete a license.
 */
export async function deleteLicense(id: string): Promise<boolean> {
    const result = await queryOne<License>(
        `UPDATE licenses SET is_deleted = TRUE, deleted_at = NOW(), status = 'revoked'
     WHERE id = $1 AND is_deleted = FALSE RETURNING id, key_hash`,
        [id]
    );

    if (result) {
        await invalidateLicenseCache(result.key_hash);
        logger.info('License deleted (soft)', { id });
        return true;
    }
    return false;
}

/**
 * Check if a license is currently valid (not expired, not suspended/banned).
 */
export function isLicenseValid(license: License): { valid: boolean; reason?: string } {
    if (license.status === 'suspended') return { valid: false, reason: 'License is suspended' };
    if (license.status === 'banned') return { valid: false, reason: 'License is banned' };
    if (license.status === 'revoked') return { valid: false, reason: 'License is revoked' };
    if (license.status === 'expired') return { valid: false, reason: 'License has expired' };

    // Check expiry date
    if (license.expires_at && new Date(license.expires_at) < new Date()) {
        return { valid: false, reason: 'License has expired' };
    }

    // Check start date
    if (new Date(license.starts_at) > new Date()) {
        return { valid: false, reason: 'License is not yet active' };
    }

    return { valid: true };
}
