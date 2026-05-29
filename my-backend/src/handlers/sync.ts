// ============================================================================
// Lambda Handler — Offline-First Sync (Push/Pull)
// ============================================================================
// Endpoints:
//   POST /sync/push  — Client pushes local changes to server
//   POST /sync/pull  — Client pulls server changes since last sync
//
// Uses Zod validation to prevent malformed sync payloads.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { parseBody } from '../middleware/validation';
import { syncPushSchema, syncPullSchema } from '../schemas';
import * as syncService from '../services/sync.service';
import * as response from '../utils/response';
import { withIdempotency } from '../middleware/idempotency';

/**
 * POST /sync/push
 * Client sends local changes (new bills, inventory updates, etc.)
 */
export const pushChanges = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    withIdempotency(async (event, _context, auth) => {
    const parsed = parseBody(syncPushSchema, event);
    if (!parsed.success) return parsed.error;

    const result = await syncService.pushChanges(auth.tenantId, {
        changes: parsed.data.changes,
        deviceId: parsed.data.deviceId,
        lastSyncedAt: parsed.data.lastSyncedAt,
    });

    return response.success(result);
    }),
);

/**
 * POST /sync/pull
 * Client requests server changes since last sync timestamp.
 */
export const pullChanges = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event, _context, auth) => {
    const parsed = parseBody(syncPullSchema, event);
    if (!parsed.success) return parsed.error;

    const result = await syncService.pullChanges(auth.tenantId, {
        lastSyncedAt: parsed.data.lastSyncedAt,
        tables: parsed.data.tables,
    });

    return response.success(result);
    },
);
