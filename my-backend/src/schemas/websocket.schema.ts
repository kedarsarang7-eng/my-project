// ============================================================================
// WebSocket Schemas — Zod Validation for WebSocket Messages
// ============================================================================

import { z } from 'zod';

/**
 * Validates the query string parameters sent during WebSocket $connect.
 */
export const wsConnectParamsSchema = z.object({
    authToken: z.string().min(1, 'authToken is required'),
    clientType: z.enum([
        'staff_app',
        'customer_app',
        'restaurant_staff_app',
        'admin_panel',
        'desktop_app',
    ]),
    businessId: z.string().min(1, 'businessId is required'),
    staffId: z.string().optional(),
    deviceId: z.string().optional(),
});

/**
 * Validates incoming messages from connected WebSocket clients.
 */
export const wsClientMessageSchema = z.object({
    action: z.enum(['subscribe', 'unsubscribe', 'ping', 'presence']),
    events: z.array(z.string()).optional(),
    status: z.enum(['online', 'away', 'offline']).optional(),
});
