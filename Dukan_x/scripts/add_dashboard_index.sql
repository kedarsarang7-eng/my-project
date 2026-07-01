-- ============================================================================
-- DukanX Dashboard Optimization Index
-- ============================================================================
-- Adds an index to the transactions table to optimize the analytical SUM 
-- queries performed by the DashboardService. This prevents full-table scans 
-- as the tenant data grows over time.
-- ============================================================================

CREATE INDEX idx_transactions_dashboard 
ON transactions(tenant_id, created_at) 
INCLUDE (total_cents, status);
