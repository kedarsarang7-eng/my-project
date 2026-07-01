import { AsyncLocalStorage } from 'async_hooks';

export interface TenantContext {
    tenantId?: string;
    correlationId?: string;
    // Add other context fields here if needed (e.g., userId, role)
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
 * Run a function within a specific tenant context.
 */
export function runWithContext<T>(ctx: TenantContext, fn: () => T): T {
    return contextStorage.run(ctx, fn);
}
