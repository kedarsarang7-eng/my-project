-- ============================================================================
-- CUSTOMER SHOP LINKS — Multi-Tenant Customer-Shop Association
-- ============================================================================
-- Tracks which customers are linked to which shops (tenants).
-- This is the RDS equivalent of the Drift `shop_links` table and
-- Firestore `connections` subcollection.
--
-- CRITICAL for:
--   1. Verifying a customer has access to a shop's data
--   2. Aggregating cross-shop stats for a customer
--   3. Enforcing data isolation at the API layer
--
-- NOTE: This table does NOT use RLS because it spans tenants.
-- Access control is enforced at the application layer via customer_id.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS customer_shop_links (
    id VARCHAR(100) PRIMARY KEY,  -- Deterministic: {customer_id}_{tenant_id}

    -- Foreign Keys
    customer_id VARCHAR(100) NOT NULL,  -- Firebase UID of the customer
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- Customer's profile ID within this shop (maps to shop's customer record)
    customer_profile_id VARCHAR(100),

    -- Denormalized shop info (for offline/fast display)
    shop_name VARCHAR(200),
    business_type VARCHAR(50),
    shop_phone VARCHAR(20),

    -- Link Status
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    -- Values: ACTIVE, UNLINKED, BLOCKED

    -- Billing Summary (updated by triggers or sync)
    total_billed_cents BIGINT NOT NULL DEFAULT 0,
    total_paid_cents BIGINT NOT NULL DEFAULT 0,
    outstanding_balance_cents BIGINT NOT NULL DEFAULT 0,

    -- Timestamps
    linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unlinked_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Sync tracking
    is_synced BOOLEAN NOT NULL DEFAULT FALSE,
    last_synced_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT uq_customer_tenant UNIQUE(customer_id, tenant_id),
    CONSTRAINT chk_link_status CHECK (status IN ('ACTIVE', 'UNLINKED', 'BLOCKED'))
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_csl_customer ON customer_shop_links(customer_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_csl_tenant ON customer_shop_links(tenant_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_csl_customer_tenant ON customer_shop_links(customer_id, tenant_id);

-- ============================================================================
-- HELPER FUNCTION: Check if customer is linked to a shop
-- ============================================================================
CREATE OR REPLACE FUNCTION is_customer_linked(
    p_customer_id VARCHAR,
    p_tenant_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS(
        SELECT 1 FROM customer_shop_links
        WHERE customer_id = p_customer_id
          AND tenant_id = p_tenant_id
          AND status = 'ACTIVE'
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- SCHEMA VERSION
-- ============================================================================
INSERT INTO schema_migrations (version, name)
VALUES (3, '003_customer_shop_links.sql')
ON CONFLICT (version) DO NOTHING;

COMMIT;
