// ============================================================================
// Lambda Handler — Offline-First Sync (Push/Pull)
// ============================================================================
// Endpoints:
//   POST /sync/push  — Client pushes local changes to server
//   POST /sync/pull  — Client pulls server changes since last sync
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import * as syncService from '../services/sync.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /sync/push
 * Client sends local changes (new bills, inventory updates, etc.)
 */
export const pushChanges = authorizedHandler([], async (event, _context, auth) => {
    const body = JSON.parse(event.body || '{}');

    if (!body.changes || !Array.isArray(body.changes)) {
        return response.badRequest('Missing required field: changes (array)');
    }

    const result = await syncService.pushChanges(auth.tenantId, {
        changes: body.changes,
        deviceId: body.deviceId,
        lastSyncedAt: body.lastSyncedAt,
    });

    return response.success(result);
});

/**
 * POST /sync/pull
 * Client requests server changes since last sync timestamp.
 */
export const pullChanges = authorizedHandler([], async (event, _context, auth) => {
    const body = JSON.parse(event.body || '{}');

    if (!body.lastSyncedAt) {
        return response.badRequest('Missing required field: lastSyncedAt (ISO timestamp)');
    }

    const result = await syncService.pullChanges(auth.tenantId, {
        lastSyncedAt: body.lastSyncedAt,
        tables: body.tables,
    });

    return response.success(result);
});
