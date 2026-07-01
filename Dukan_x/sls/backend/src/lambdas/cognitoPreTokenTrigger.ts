// ============================================
// Cognito Pre-Token Generation Lambda Trigger
// ============================================
// This Lambda is invoked by Cognito BEFORE issuing tokens.
// It injects the user's role and tenant_id into the ID token
// as custom claims, so the Flutter client and backend middleware
// can read them directly from the JWT without a DB lookup.
//
// Configure in Cognito User Pool → Triggers → Pre Token Generation.
//
// Custom claims added:
//   custom:role         — 'owner' | 'manager' | 'cashier' | 'accountant' | 'viewer' | 'staff'
//   custom:tenant_id    — The business/shop ID
//   custom:staff_id     — The staff_members.id (for staff users)
//   custom:permissions   — Comma-separated list of top-level permission IDs (max 50)
// ============================================

import { PreTokenGenerationTriggerEvent } from 'aws-lambda';
import { Pool } from 'pg';

// Lightweight PG pool for Lambda (reused across warm invocations)
let pool: Pool | null = null;

function getPool(): Pool {
    if (!pool) {
        pool = new Pool({
            connectionString: process.env.DATABASE_URL,
            max: 2,
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 5000,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
        });
    }
    return pool;
}

export async function handler(
    event: PreTokenGenerationTriggerEvent
): Promise<PreTokenGenerationTriggerEvent> {
    const cognitoSub = event.request.userAttributes.sub;
    const existingRole = event.request.userAttributes['custom:role'];
    const existingTenantId = event.request.userAttributes['custom:tenant_id'];

    console.log('[CognitoPreToken] Processing', { cognitoSub, existingRole, existingTenantId });

    // If user already has role=owner set during signup, keep it and skip DB lookup
    if (existingRole === 'owner') {
        event.response = {
            claimsOverrideDetails: {
                claimsToAddOrOverride: {
                    'custom:role': 'owner',
                    ...(existingTenantId ? { 'custom:tenant_id': existingTenantId } : {}),
                },
            },
        };
        return event;
    }

    // For staff users — look up their role and permissions from the DB
    try {
        const db = getPool();

        // Find staff member by Cognito sub
        const staffResult = await db.query(
            `SELECT sm.id AS staff_id, sm.tenant_id, sm.is_active,
                    r.name AS role_name
             FROM staff_members sm
             JOIN roles r ON r.id = sm.role_id
             WHERE sm.cognito_sub = $1 AND sm.is_active = TRUE
             LIMIT 1`,
            [cognitoSub]
        );

        if (staffResult.rows.length === 0) {
            // Not a staff member — use existing attributes or default
            console.log('[CognitoPreToken] No staff record found, using defaults');
            event.response = {
                claimsOverrideDetails: {
                    claimsToAddOrOverride: {
                        'custom:role': existingRole || 'owner',
                        ...(existingTenantId ? { 'custom:tenant_id': existingTenantId } : {}),
                    },
                },
            };
            return event;
        }

        const staff = staffResult.rows[0];

        // Fetch effective permissions (limited to 50 for token size)
        const permsResult = await db.query(
            `SELECT permission_id
             FROM get_effective_permissions($1, $2)
             LIMIT 50`,
            [cognitoSub, staff.tenant_id]
        );

        const permissionsList = permsResult.rows.map((r: any) => r.permission_id).join(',');

        console.log('[CognitoPreToken] Staff found', {
            staffId: staff.staff_id,
            role: staff.role_name,
            tenantId: staff.tenant_id,
            permCount: permsResult.rows.length,
        });

        event.response = {
            claimsOverrideDetails: {
                claimsToAddOrOverride: {
                    'custom:role': staff.role_name,
                    'custom:tenant_id': staff.tenant_id,
                    'custom:staff_id': staff.staff_id,
                    'custom:permissions': permissionsList,
                },
            },
        };
    } catch (error: any) {
        console.error('[CognitoPreToken] DB error, falling back to existing claims', error.message);
        // On error, don't block login — just pass through existing claims
        event.response = {
            claimsOverrideDetails: {
                claimsToAddOrOverride: {
                    'custom:role': existingRole || 'staff',
                    ...(existingTenantId ? { 'custom:tenant_id': existingTenantId } : {}),
                },
            },
        };
    }

    return event;
}
