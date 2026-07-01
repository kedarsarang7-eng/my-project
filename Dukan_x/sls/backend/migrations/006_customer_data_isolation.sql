-- ============================================
-- 006: Customer Data Isolation — Shop Links + Invoice Security
-- ============================================
-- Ensures customers can ONLY access shops they are explicitly linked to.
-- Prevents cross-customer data leakage (IDOR attacks).
--
-- Tables:
--   1. customer_shop_links — Tracks which customers are linked to which shops
--
-- Security Model:
--   Layer 1: Cognito JWT → verified customer identity (sub)
--   Layer 2: x-shop-id → tenant isolation via RLS (SET LOCAL app.tenant_id)
--   Layer 3: customer_shop_links → explicit customer ↔ shop authorization
--   Layer 4: WHERE customer_id = $1 → row-level customer filtering on queries
-- ============================================

-- ============================================
-- 1. CUSTOMER_SHOP_LINKS TABLE
-- ============================================
-- Tracks explicit customer-to-shop associations.
-- A customer MUST have a link before accessing any shop data.
--
-- The link is created when:
--   a) Customer scans a shop QR code and confirms
--   b) Shop owner manually adds a customer
--   c) Customer's first purchase auto-creates a link
--
CREATE TABLE IF NOT EXISTS customer_shop_links (
    -- Deterministic PK: {customer_cognito_sub}_{tenant_id}
    -- This prevents duplicates without needing a unique constraint
    id              VARCHAR(200) PRIMARY KEY,

    customer_id     VARCHAR(128) NOT NULL,    -- Cognito sub (UUID format)
    tenant_id       UUID NOT NULL,             -- References the shop/tenant

    -- Link metadata
    linked_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    linked_via      VARCHAR(50) NOT NULL DEFAULT 'manual',  -- manual | qr_scan | auto_purchase | admin_invite
    display_name    VARCHAR(200),              -- Customer's display name at time of linking
    phone           VARCHAR(20),               -- Customer's phone at time of linking

    -- Status
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    unlinked_at     TIMESTAMPTZ,
    unlinked_reason VARCHAR(200),

    -- Audit
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- 2. INDEXES
-- ============================================

-- Fast lookup: "Is this customer linked to this shop?"
CREATE INDEX IF NOT EXISTS idx_csl_customer_tenant
    ON customer_shop_links (customer_id, tenant_id)
    WHERE is_active = TRUE;

-- Fast lookup: "Which shops is this customer linked to?"
CREATE INDEX IF NOT EXISTS idx_csl_customer_active
    ON customer_shop_links (customer_id)
    WHERE is_active = TRUE;

-- Fast lookup: "Which customers are linked to this shop?"
CREATE INDEX IF NOT EXISTS idx_csl_tenant_active
    ON customer_shop_links (tenant_id)
    WHERE is_active = TRUE;

-- ============================================
-- 3. HELPER FUNCTION: Check customer-shop link
-- ============================================
CREATE OR REPLACE FUNCTION is_customer_linked(
    p_customer_id VARCHAR,
    p_tenant_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS(
        SELECT 1
        FROM customer_shop_links
        WHERE customer_id = p_customer_id
          AND tenant_id = p_tenant_id
          AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 4. HELPER FUNCTION: Create or reactivate link
-- ============================================
CREATE OR REPLACE FUNCTION link_customer_to_shop(
    p_customer_id VARCHAR,
    p_tenant_id UUID,
    p_linked_via VARCHAR DEFAULT 'manual',
    p_display_name VARCHAR DEFAULT NULL,
    p_phone VARCHAR DEFAULT NULL
) RETURNS customer_shop_links AS $$
DECLARE
    v_link_id VARCHAR;
    v_result customer_shop_links;
BEGIN
    v_link_id := p_customer_id || '_' || p_tenant_id::TEXT;

    INSERT INTO customer_shop_links (id, customer_id, tenant_id, linked_via, display_name, phone)
    VALUES (v_link_id, p_customer_id, p_tenant_id, p_linked_via, p_display_name, p_phone)
    ON CONFLICT (id) DO UPDATE SET
        is_active = TRUE,
        unlinked_at = NULL,
        unlinked_reason = NULL,
        updated_at = NOW()
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. AUDIT INDEX on transactions for customer queries
-- ============================================
-- Composite index for the most common customer query pattern:
-- SELECT ... FROM transactions WHERE customer_id = $1 AND NOT is_deleted
-- (Only create if it doesn't exist — the table may or may not have this index)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_transactions_customer_active'
    ) THEN
        BEGIN
            CREATE INDEX idx_transactions_customer_active
                ON transactions (customer_id, created_at DESC)
                WHERE NOT is_deleted;
        EXCEPTION WHEN undefined_table THEN
            -- transactions table may not exist yet in this environment
            RAISE NOTICE 'transactions table not found, skipping index creation';
        END;
    END IF;
END $$;

-- ============================================
-- 6. TRIGGER: Auto-update updated_at
-- ============================================
DROP TRIGGER IF EXISTS set_updated_at_customer_shop_links ON customer_shop_links;
CREATE TRIGGER set_updated_at_customer_shop_links
    BEFORE UPDATE ON customer_shop_links
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
