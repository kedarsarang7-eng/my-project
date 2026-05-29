// ============================================================================
// AsyncLocalStorage Context — Request-scoped Context Propagation
// ============================================================================
// Provides tenant ID, correlation ID, and user ID across the entire
// request lifecycle without passing them through every function argument.
// ============================================================================

import { AsyncLocalStorage } from 'async_hooks';

export interface TenantContext {
    tenantId?: string;
    correlationId?: string;
    userId?: string;
    businessId?: string;
    role?: string;
}

// Singleton storage instance
export const contextStorage = new AsyncLocalStorage<TenantContext>();

/**
 * Get the current tenant ID from the async storage.
 */
export function getTenantId(): string | undefined {
    const store = contextStorage.getStore();
    return store?.tenantId;
}

/**
 * Get the current business ID from the async storage.
 */
export function getBusinessId(): string | undefined {
    const store = contextStorage.getStore();
    return store?.businessId;
}

/**
 * Get the current user role from the async storage.
 */
export function getUserRole(): string | undefined {
    const store = contextStorage.getStore();
    return store?.role;
}



/**
 * Get the current correlation ID from the async storage.
 */
export function getCorrelationId(): string | undefined {
    const store = contextStorage.getStore();
    return store?.correlationId;
}

/**
 * Get the current user ID from the async storage.
 */
export function getUserId(): string | undefined {
    const store = contextStorage.getStore();
    return store?.userId;
}

/**
 * Run a function within a specific tenant context.
 */
export function runWithContext<T>(ctx: TenantContext, fn: () => T): T {
    return contextStorage.run(ctx, fn);
}

/**
 * Generate a Request ID (RID) for tracking.
 * Format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
 */
export function generateRID(tenantId: string): string {
    const ts = Date.now();
    const shortUuid = Math.random().toString(36).substring(2, 10);
    return `${tenantId}-${ts}-${shortUuid}`;
}

/**
 * Execute a handler with request context and RID generation.
 * Automatically sets up correlation ID and tenant context.
 */
export async function withRequestContext<T>(
    tenantId: string,
    handler: (rid: string) => Promise<T>
): Promise<T> {
    const rid = generateRID(tenantId);
    const ctx: TenantContext = {
        tenantId,
        correlationId: rid,
    };
    return runWithContext(ctx, () => handler(rid));
}
