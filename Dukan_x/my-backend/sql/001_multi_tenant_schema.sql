-- ============================================================================
-- BIZMATE MULTI-TENANT POSTGRESQL SCHEMA
-- ============================================================================
--
-- Unified schema for the BizMate SaaS POS/ERP application.
-- Supports 14 business types with polymorphic inventory.
--
-- DESIGN PRINCIPLES:
--   1. ALL monetary values stored as BIGINT (paise/cents) — NO FLOAT!
--   2. UUID primary keys for distributed systems
--   3. Multi-tenant isolation via tenant_id + Row-Level Security (RLS)
--   4. Polymorphic inventory via product_type + attributes JSONB
--   5. ACID-compliant financial records
--
-- RUNNING THIS SCRIPT:
--   psql -h <rds-host> -U bizmate_admin -d bizmate -f 001_multi_tenant_schema.sql
--
-- ============================================================================

BEGIN;

-- =============================================================================
-- EXTENSIONS
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- CUSTOM TYPES
-- =============================================================================

DO $$ BEGIN
    CREATE TYPE subscription_plan AS ENUM (
        'free', 'starter', 'professional', 'enterprise'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM (
        'owner', 'admin', 'manager', 'accountant', 'cashier', 'staff'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE transaction_status AS ENUM (
        'draft', 'finalized', 'paid', 'partially_paid', 'voided', 'refunded'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_method AS ENUM (
        'cash', 'upi', 'card', 'bank_transfer', 'cheque', 'credit', 'wallet'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- 1. TENANTS (Business Profiles)
-- =============================================================================

CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Business Identity
    name VARCHAR(200) NOT NULL,
    display_name VARCHAR(200),
    business_type VARCHAR(50) NOT NULL DEFAULT 'other',
    -- Supported: grocery, pharmacy, restaurant, clothing, electronics,
    --            mobile_shop, computer_shop, hardware, service, wholesale,
    --            petrol_pump, vegetables_broker, clinic, other

    -- Subscription
    subscription_plan subscription_plan NOT NULL DEFAULT 'free',
    subscription_valid_until TIMESTAMPTZ,
    max_users INTEGER NOT NULL DEFAULT 3,     -- Free Tier limit
    max_products INTEGER NOT NULL DEFAULT 500, -- Free Tier limit

    -- GST / Tax (India)
    gstin VARCHAR(20),
    pan VARCHAR(10),
    state_code CHAR(2),

    -- Contact
    phone VARCHAR(20),
    email VARCHAR(100),
    website VARCHAR(200),

    -- Address (JSONB for flexibility)
    address JSONB DEFAULT '{}',
    -- Schema: {street, city, state, pincode, country}

    -- Settings (per-tenant customization)
    settings JSONB DEFAULT '{}',
    -- Schema: {currency, timezone, fiscalYearStart, invoicePrefix,
    --          enableGst, enableMultiCurrency, dateFormat, ...}

    -- Branding
    logo_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_tenants_business_type ON tenants(business_type);
CREATE INDEX IF NOT EXISTS idx_tenants_subscription ON tenants(subscription_plan);

-- =============================================================================
-- 2. USERS (Staff & Owners — linked to Cognito)
-- =============================================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- Cognito Link
    cognito_sub VARCHAR(100) UNIQUE NOT NULL,
    -- This is the Cognito User Pool "sub" claim

    -- Profile
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    phone VARCHAR(20),

    -- Role & Permissions
    role user_role NOT NULL DEFAULT 'staff',
    permissions JSONB NOT NULL DEFAULT '[]',
    -- Fine-grained permissions: ["create_invoice", "manage_inventory", ...]

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_tenant_email UNIQUE(tenant_id, email)
);

CREATE INDEX IF NOT EXISTS idx_users_tenant ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_cognito_sub ON users(cognito_sub);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- =============================================================================
-- 3. INVENTORY (Polymorphic — All Business Types)
-- =============================================================================
-- The `product_type` column discriminates the kind of product.
-- Business-specific data lives in the `attributes` JSONB column.
-- See types/inventory.types.ts for the attribute schemas.

CREATE TABLE IF NOT EXISTS inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- Polymorphic Discriminator
    product_type VARCHAR(30) NOT NULL DEFAULT 'general',
    -- Values: general, fuel, medicine, food_item, clothing, electronic,
    --         hardware_item, service, vegetable, medical_supply

    -- Core Fields (Universal)
    name VARCHAR(200) NOT NULL,
    display_name VARCHAR(200),
    sku VARCHAR(50),
    barcode VARCHAR(50),
    alt_barcodes JSONB DEFAULT '[]',

    -- Classification
    category VARCHAR(100),
    subcategory VARCHAR(100),
    brand VARCHAR(100),

    -- Tax (HSN for India)
    hsn_code VARCHAR(10),
    unit VARCHAR(20) NOT NULL DEFAULT 'pcs',

    -- Pricing (ALL in BIGINT paise — NO FLOATING POINT)
    sale_price_cents BIGINT NOT NULL DEFAULT 0,
    purchase_price_cents BIGINT,
    mrp_cents BIGINT,
    wholesale_price_cents BIGINT,

    -- Tax Rates (Basis Points: 18% = 1800)
    cgst_rate_bp INTEGER NOT NULL DEFAULT 0,
    sgst_rate_bp INTEGER NOT NULL DEFAULT 0,
    igst_rate_bp INTEGER NOT NULL DEFAULT 0,
    cess_rate_bp INTEGER DEFAULT 0,

    -- Stock
    current_stock DECIMAL(12,3) NOT NULL DEFAULT 0,
    low_stock_threshold DECIMAL(12,3) DEFAULT 5,
    reorder_qty DECIMAL(12,3),

    -- ── Business-Specific Attributes (JSONB) ──
    -- Fuel:     {fuelType, tankId, densityAt15C, currentRate}
    -- Medicine: {batchNumber, expiryDate, drugSchedule, requiresPrescription,
    --            manufacturer, composition, rackLocation}
    -- Clothing: {size, color, material, groupId}
    -- Food:     {isVeg, spiceLevel, preparationTime, allergens}
    -- etc.
    attributes JSONB NOT NULL DEFAULT '{}',

    -- Variants (for clothing size/color combos)
    group_id UUID,
    variant_attributes JSONB,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_service BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT chk_sale_price_positive CHECK (sale_price_cents >= 0),
    CONSTRAINT chk_stock_nonnegative CHECK (current_stock >= 0 OR is_service = TRUE)
);

CREATE INDEX IF NOT EXISTS idx_inventory_tenant ON inventory(tenant_id) WHERE NOT is_deleted;
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_sku
    ON inventory(tenant_id, sku) WHERE sku IS NOT NULL AND NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_inventory_barcode
    ON inventory(tenant_id, barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inventory_category
    ON inventory(tenant_id, category) WHERE category IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inventory_product_type ON inventory(tenant_id, product_type);
CREATE INDEX IF NOT EXISTS idx_inventory_low_stock
    ON inventory(tenant_id)
    WHERE current_stock <= low_stock_threshold AND is_active AND NOT is_deleted;

-- =============================================================================
-- 4. TRANSACTIONS (Sales Ledger)
-- =============================================================================

CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id UUID,

    -- Identification
    invoice_number VARCHAR(50) NOT NULL,
    customer_name VARCHAR(100),
    customer_phone VARCHAR(20),

    -- Amounts (BIGINT paise)
    subtotal_cents BIGINT NOT NULL DEFAULT 0,
    discount_cents BIGINT NOT NULL DEFAULT 0,
    tax_cents BIGINT NOT NULL DEFAULT 0,
    cgst_cents BIGINT NOT NULL DEFAULT 0,
    sgst_cents BIGINT NOT NULL DEFAULT 0,
    igst_cents BIGINT NOT NULL DEFAULT 0,
    round_off_cents BIGINT NOT NULL DEFAULT 0,
    total_cents BIGINT NOT NULL,
    paid_cents BIGINT NOT NULL DEFAULT 0,
    balance_cents BIGINT NOT NULL DEFAULT 0,

    -- Payment
    payment_mode payment_method DEFAULT 'cash',

    -- Status
    status transaction_status NOT NULL DEFAULT 'draft',

    -- Metadata (Business-specific extra fields)
    metadata JSONB DEFAULT '{}',
    -- Pharmacy: {prescriptionId, doctorName}
    -- Restaurant: {tableNumber, orderType: 'dine_in'|'takeaway'|'delivery'}
    -- Petrol Pump: {shiftId, nozzleId}

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    version INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT chk_txn_total_positive CHECK (total_cents >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_txn_invoice_number
    ON transactions(tenant_id, invoice_number) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_txn_tenant_date ON transactions(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_txn_status ON transactions(tenant_id, status);

-- =============================================================================
-- 5. TRANSACTION ITEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS transaction_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    item_id UUID REFERENCES inventory(id),

    name VARCHAR(200) NOT NULL,
    quantity DECIMAL(12,3) NOT NULL,
    unit VARCHAR(20) DEFAULT 'pcs',

    -- Pricing (BIGINT paise)
    unit_price_cents BIGINT NOT NULL,
    discount_cents BIGINT NOT NULL DEFAULT 0,
    tax_cents BIGINT NOT NULL DEFAULT 0,
    total_cents BIGINT NOT NULL,

    -- Batch (for pharmacy)
    batch_number VARCHAR(50),
    expiry_date DATE,

    -- Metadata
    attributes JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_txn_items_transaction ON transaction_items(transaction_id);
CREATE INDEX IF NOT EXISTS idx_txn_items_item ON transaction_items(item_id);

-- =============================================================================
-- 6. PETROL PUMP SPECIFIC TABLES
-- =============================================================================

-- Fuel Tanks
CREATE TABLE IF NOT EXISTS fuel_tanks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tank_name VARCHAR(50) NOT NULL,
    fuel_type VARCHAR(20) NOT NULL, -- PETROL, DIESEL, CNG, LPG
    capacity_litres DECIMAL(10,2) NOT NULL,
    current_stock_litres DECIMAL(10,2) NOT NULL DEFAULT 0,
    last_dip_reading DECIMAL(10,2),
    last_dip_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fuel_tanks_tenant ON fuel_tanks(tenant_id);

-- Nozzles
CREATE TABLE IF NOT EXISTS nozzles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tank_id UUID NOT NULL REFERENCES fuel_tanks(id),
    nozzle_name VARCHAR(50) NOT NULL,
    fuel_type VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Shifts
CREATE TABLE IF NOT EXISTS shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    shift_name VARCHAR(50) NOT NULL,
    shift_date DATE NOT NULL DEFAULT CURRENT_DATE,
    staff_name VARCHAR(100),
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, closed
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shifts_tenant_date ON shifts(tenant_id, shift_date);

-- Nozzle Readings (per shift)
CREATE TABLE IF NOT EXISTS nozzle_readings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    nozzle_id UUID NOT NULL REFERENCES nozzles(id),
    shift_id UUID REFERENCES shifts(id),
    reading_date DATE NOT NULL DEFAULT CURRENT_DATE,
    opening_reading DECIMAL(12,2) NOT NULL,
    closing_reading DECIMAL(12,2) NOT NULL,
    testing_qty DECIMAL(10,2) DEFAULT 0,
    payment_mode VARCHAR(20) DEFAULT 'CASH',
    amount_cents BIGINT NOT NULL DEFAULT 0,
    fuel_type VARCHAR(20),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nozzle_readings_date ON nozzle_readings(tenant_id, reading_date);

-- Loss Entries (Evaporation / Handling)
CREATE TABLE IF NOT EXISTS loss_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    tank_id UUID NOT NULL REFERENCES fuel_tanks(id),
    loss_date DATE NOT NULL DEFAULT CURRENT_DATE,
    fuel_type VARCHAR(20) NOT NULL,
    loss_type VARCHAR(30) NOT NULL, -- evaporation, handling, spillage, other
    quantity_litres DECIMAL(10,3) NOT NULL,
    reason TEXT,
    approved_by VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5-Litre Tests
CREATE TABLE IF NOT EXISTS five_litre_tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    test_date DATE NOT NULL DEFAULT CURRENT_DATE,
    nozzle_name VARCHAR(50) NOT NULL,
    fuel_type VARCHAR(20) NOT NULL,
    measured_quantity_ml DECIMAL(8,2) NOT NULL, -- actual measured
    expected_quantity_ml DECIMAL(8,2) NOT NULL DEFAULT 5000, -- 5 litres = 5000ml
    variance_ml DECIMAL(8,2) GENERATED ALWAYS AS
        (measured_quantity_ml - expected_quantity_ml) STORED,
    tested_by VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cash Deposits
CREATE TABLE IF NOT EXISTS cash_deposits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    deposit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    shift_name VARCHAR(50),
    staff_name VARCHAR(100),
    expected_cash_cents BIGINT NOT NULL DEFAULT 0,
    actual_cash_cents BIGINT NOT NULL DEFAULT 0,
    bank_deposited_cents BIGINT NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fuel Prices (Daily rate changes)
CREATE TABLE IF NOT EXISTS fuel_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    effective_date DATE NOT NULL,
    fuel_type VARCHAR(20) NOT NULL,
    price_per_litre_cents BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_fuel_price UNIQUE(tenant_id, effective_date, fuel_type)
);

-- =============================================================================
-- 7. PHARMACY SPECIFIC TABLES
-- =============================================================================

-- Medicine Batches (Expiry Tracking)
CREATE TABLE IF NOT EXISTS medicine_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES inventory(id),
    batch_number VARCHAR(50) NOT NULL,
    manufacturing_date DATE,
    expiry_date DATE NOT NULL,
    purchase_price_cents BIGINT,
    sale_price_cents BIGINT,
    mrp_cents BIGINT,
    initial_qty DECIMAL(12,3) NOT NULL,
    current_qty DECIMAL(12,3) NOT NULL,
    supplier_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_batch_qty CHECK (current_qty >= 0)
);

CREATE INDEX IF NOT EXISTS idx_medicine_batches_product ON medicine_batches(product_id);
CREATE INDEX IF NOT EXISTS idx_medicine_batches_expiry
    ON medicine_batches(tenant_id, expiry_date) WHERE current_qty > 0;

-- =============================================================================
-- 8. VENDORS / SUPPLIERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    gstin VARCHAR(20),
    state_code CHAR(2),
    address JSONB DEFAULT '{}',
    opening_balance_cents BIGINT NOT NULL DEFAULT 0,
    current_balance_cents BIGINT NOT NULL DEFAULT 0,
    bank_details JSONB,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_vendors_tenant ON vendors(tenant_id) WHERE NOT is_deleted;

-- =============================================================================
-- 9. PURCHASE ORDERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES vendors(id),
    order_number VARCHAR(50) NOT NULL,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_cents BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- 10. RETURNS
-- =============================================================================

CREATE TABLE IF NOT EXISTS returns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(id),
    return_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount_cents BIGINT NOT NULL,
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- 11. ROW-LEVEL SECURITY (RLS)
-- =============================================================================
-- Ensures every query is automatically filtered by tenant_id.
-- The app sets `app.tenant_id` via SET_CONFIG at the start of each request.

-- Helper function to get current tenant
CREATE OR REPLACE FUNCTION current_tenant_id() RETURNS UUID AS $$
BEGIN
    RETURN current_setting('app.tenant_id', true)::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Enable RLS on all tenant-scoped tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_tanks ENABLE ROW LEVEL SECURITY;
ALTER TABLE nozzles ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE nozzle_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE loss_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE five_litre_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE medicine_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE returns ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (SELECT, INSERT, UPDATE, DELETE scoped to tenant)
DO $$ 
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'users', 'inventory', 'transactions', 'transaction_items',
        'fuel_tanks', 'nozzles', 'shifts', 'nozzle_readings',
        'loss_entries', 'five_litre_tests', 'cash_deposits', 'fuel_prices',
        'medicine_batches', 'vendors', 'purchase_orders', 'returns'
    ])
    LOOP
        EXECUTE format(
            'CREATE POLICY tenant_isolation_%s ON %I
             USING (tenant_id = current_tenant_id())
             WITH CHECK (tenant_id = current_tenant_id())',
            tbl, tbl
        );
    EXCEPTION WHEN duplicate_object THEN
        -- Policy already exists, skip
        NULL;
    END LOOP;
END $$;

-- =============================================================================
-- 12. VIEWS (for reporting convenience)
-- =============================================================================

-- GST-wise Fuel Sales View (used by PetrolPumpStrategy)
CREATE OR REPLACE VIEW fuel_sales_gst_view AS
SELECT
    nr.tenant_id,
    nr.reading_date AS sale_date,
    n.fuel_type,
    (nr.closing_reading - nr.opening_reading - COALESCE(nr.testing_qty, 0))
        AS net_sale_litres,
    nr.amount_cents,
    -- Assume 18% composite GST split for fuel (9% CGST + 9% SGST)
    -- Actual rates should come from fuel_prices or inventory tax config
    ROUND(nr.amount_cents * 900 / 10000) AS cgst_cents,
    ROUND(nr.amount_cents * 900 / 10000) AS sgst_cents,
    0::BIGINT AS cess_cents
FROM nozzle_readings nr
JOIN nozzles n ON n.id = nr.nozzle_id;

-- =============================================================================
-- SCHEMA VERSION TRACKING
-- =============================================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO schema_migrations (version, name)
VALUES (1, '001_multi_tenant_schema.sql')
ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ============================================================================
-- POST-DEPLOY NOTES
-- ============================================================================
--
-- 1. RDS Free Tier Config (db.t3.micro):
--    - 1 vCPU, 1 GB RAM
--    - 20 GB SSD storage
--    - Max ~60 connections (reserve 5 per Lambda, limit concurrency)
--    - Enable Performance Insights (free for 7-day retention)
--    - Set backup retention to 7 days (free)
--    - DISABLE Multi-AZ (not free tier)
--
-- 2. Connection Limits:
--    - Lambda concurrency: 10 (to avoid exceeding ~60 connections)
--    - Pool size per Lambda: 5
--    - Total: 10 × 5 = 50 connections (under limit)
--
-- 3. Monitoring:
--    - CloudWatch alarms for CPU > 80%, FreeableMemory < 100MB
--    - Enable slow query logging: SET log_min_duration_statement = 1000;
--
-- ============================================================================
