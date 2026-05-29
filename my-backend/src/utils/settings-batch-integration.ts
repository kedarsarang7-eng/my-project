// ============================================================================
// Tenant Settings Batching Integration Guide
// ============================================================================
//
// USAGE EXAMPLES:
//
// 1. Queue a single setting update (debounced):
//    await queueSettingUpdate(tenantId, 'lastLoginAt', new Date().toISOString());
//
// 2. Queue multiple updates in succession:
//    await queueSettingUpdate(tenantId, 'totalSalesCounter', 1500);
//    await queueSettingUpdate(tenantId, 'lastTransactionAt', now);
//    // Both are batched into a single write after 100ms
//
// 3. Force immediate flush (e.g., on critical operation):
//    await queueSettingUpdate(tenantId, 'settingName', value, true);
//
// 4. Flush all pending batches before shutdown:
//    process.on('SIGTERM', async () => {
//        await flushAllSettingsBatches();
//        process.exit(0);
//    });
//
// ============================================================================
//
// INTEGRATION POINTS (recommended):
//
// - dashboard.ts: Update 'lastDashboardAccessAt' (debounced)
// - auth.ts: Update 'lastLoginAt', 'loginCount' (batched)
// - invoice.service.ts: Update 'totalSalesCounter', 'lastSaleAt' (batched)
// - payment-order.service.ts: Update 'totalPaymentsProcessed' (batched)
// - sync.service.ts: Update 'lastSyncAt' after pull/push (batched)
//
// ============================================================================
//
// PERFORMANCE IMPACT:
//
// Before (without batching):
//   - 10 setting updates = 10 DynamoDB writes
//   - High write contention during batch operations
//   - Potential throttling with PAY_PER_REQUEST billing
//
// After (with batching):
//   - 10 setting updates = 1 DynamoDB write (per 100ms window)
//   - 90% reduction in write load
//   - Max latency of 100ms for update visibility
//   - Trade-off: Update visibility delayed by ~100ms
//
// ============================================================================

import { queueSettingUpdate, flushAllSettingsBatches } from './settings-batch';

// EXAMPLE: Integrating into auth handler
export async function handleLastLoginUpdate(tenantId: string) {
    // Debounce-batched update (waits 100ms, may batch with other updates)
    await queueSettingUpdate(tenantId, 'lastLoginAt', new Date().toISOString());
}

// EXAMPLE: Integrating into invoice handler
export async function handleInvoiceCompleted(tenantId: string, amount: number) {
    // Multiple updates get batched together
    await queueSettingUpdate(tenantId, 'totalSalesCounter', amount);
    await queueSettingUpdate(tenantId, 'lastSaleAt', new Date().toISOString());
}

// EXAMPLE: Graceful shutdown handler
export async function setupGracefulShutdown() {
    process.on('SIGTERM', async () => {
        console.log('Received SIGTERM, flushing pending batches...');
        await flushAllSettingsBatches();
        process.exit(0);
    });
}
