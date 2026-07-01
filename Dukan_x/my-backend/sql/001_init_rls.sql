-- ============================================================================
-- 1. Enable UUID Extension
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 2. Create Tenants Table (Shared)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'active'
);

-- ============================================================================
-- 3. Create Invoices Table (Tenant-Isolated)
-- ============================================================================
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_name VARCHAR(255) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index on tenant_id for performance
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_id ON invoices(tenant_id);

-- ============================================================================
-- 4. Enable Row Level Security (RLS)
-- ============================================================================
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. Create RLS Policy
-- ============================================================================
-- Policy: Users can only see rows where tenant_id matches the session variable 'app.current_tenant'
-- We cast to UUID to ensure type safety.
-- If 'app.current_tenant' is not set, it returns NULL, so no rows match (Default Deny).

DROP POLICY IF EXISTS tenant_isolation_policy ON invoices;

CREATE POLICY tenant_isolation_policy ON invoices
    USING (tenant_id = current_setting('app.current_tenant', true)::UUID)
    WITH CHECK (tenant_id = current_setting('app.current_tenant', true)::UUID);

-- ============================================================================
-- 6. Grant Permissions (Adjust based on your DB user)
-- ============================================================================
-- Ensure the application user has access to these tables
-- GRANT ALL PRIVILEGES ON TABLE tenants TO bizmate_user;
-- GRANT ALL PRIVILEGES ON TABLE invoices TO bizmate_user;
