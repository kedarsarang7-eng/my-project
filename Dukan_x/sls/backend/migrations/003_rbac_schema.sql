-- ============================================================================
-- RBAC SCHEMA — Role-Based Access Control for Multi-Tenant DukanX
-- ============================================================================
-- Supports: Grocery, Pharmacy, Petrol Pump, Restaurant, Clinic, etc.
-- All tables include tenant_id for strict data isolation.
-- ============================================================================

-- 1. Master permissions catalog — every feature in the system
CREATE TABLE IF NOT EXISTS permissions (
    id              TEXT PRIMARY KEY,                    -- e.g. 'view_inventory', 'edit_billing'
    category        TEXT NOT NULL,                       -- e.g. 'billing', 'inventory', 'reports', 'staff', 'settings'
    display_name    TEXT NOT NULL,                       -- Human-readable: 'View Inventory'
    description     TEXT,                                -- Tooltip text
    sort_order      INTEGER NOT NULL DEFAULT 0,          -- For UI ordering within category
    is_sensitive    BOOLEAN NOT NULL DEFAULT FALSE,      -- If TRUE, only Owner can grant this
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Seed all DukanX permissions
INSERT INTO permissions (id, category, display_name, description, sort_order, is_sensitive) VALUES
    -- Billing
    ('create_bill',         'billing',    'Create Bill / Invoice',       'Create new sales invoices',                 10, FALSE),
    ('edit_bill',           'billing',    'Edit Bill',                   'Modify existing invoices',                  20, FALSE),
    ('delete_bill',         'billing',    'Delete Bill',                 'Permanently delete invoices',               30, TRUE),
    ('reverse_bill',        'billing',    'Reverse / Credit Note',      'Issue credit notes and reversals',          40, TRUE),
    ('print_bill',          'billing',    'Print Bill',                  'Print or share invoices',                   50, FALSE),
    ('apply_discount',      'billing',    'Apply Discount',             'Apply discounts on invoices',               60, FALSE),
    ('apply_high_discount', 'billing',    'Apply High Discount (>20%)', 'Apply discounts above 20%',                 70, TRUE),
    ('process_refund',      'billing',    'Process Refund',             'Process customer refunds',                  80, TRUE),

    -- Inventory
    ('view_inventory',      'inventory',  'View Inventory',             'View stock levels and items',               10, FALSE),
    ('edit_inventory',      'inventory',  'Edit Inventory',             'Add/modify inventory items',                20, FALSE),
    ('adjust_stock',        'inventory',  'Adjust Stock',               'Manual stock adjustments',                  30, FALSE),
    ('view_stock_value',    'inventory',  'View Stock Valuation',       'See total stock value',                     40, TRUE),
    ('manage_categories',   'inventory',  'Manage Categories',          'Create/edit item categories',               50, FALSE),
    ('manage_batches',      'inventory',  'Manage Batches / Expiry',    'Batch tracking and expiry management',      60, FALSE),

    -- Customers & Parties
    ('view_customers',      'parties',    'View Customers',             'View customer list and details',            10, FALSE),
    ('create_customer',     'parties',    'Create Customer',            'Add new customers',                         20, FALSE),
    ('edit_customer',       'parties',    'Edit Customer',              'Modify customer details',                   30, FALSE),
    ('delete_customer',     'parties',    'Delete Customer',            'Remove customers permanently',              40, TRUE),
    ('view_customer_balance','parties',   'View Customer Balance',      'See outstanding balances',                  50, FALSE),
    ('view_suppliers',      'parties',    'View Suppliers',             'View supplier list',                        60, FALSE),
    ('manage_suppliers',    'parties',    'Manage Suppliers',           'Add/edit/delete suppliers',                 70, FALSE),

    -- Purchases
    ('create_purchase',     'purchases',  'Create Purchase',            'Record purchase entries',                   10, FALSE),
    ('edit_purchase',       'purchases',  'Edit Purchase',              'Modify purchase entries',                   20, FALSE),
    ('view_purchase_report','purchases',  'View Purchase Reports',      'Access purchase reports',                   30, FALSE),

    -- Financial
    ('view_reports',        'financial',  'View Reports',               'Access business reports',                   10, FALSE),
    ('view_profit',         'financial',  'View Profit & Loss',         'See P&L, margins, profitability',           20, TRUE),
    ('view_cashbook',       'financial',  'View Cash Book',             'Access cash book entries',                  30, FALSE),
    ('view_ledger',         'financial',  'View Ledger',                'Access ledger accounts',                    40, FALSE),
    ('make_payment',        'financial',  'Make Payment',               'Record outgoing payments',                  50, FALSE),
    ('receive_payment',     'financial',  'Receive Payment',            'Record incoming payments',                  60, FALSE),
    ('journal_entry',       'financial',  'Journal Entry',              'Create journal entries',                    70, TRUE),
    ('view_daybook',        'financial',  'View Day Book',              'Access day book',                           80, FALSE),
    ('manage_expenses',     'financial',  'Manage Expenses',            'Record and manage expenses',                90, FALSE),
    ('manage_bank_accounts','financial',  'Manage Bank Accounts',       'Add/edit bank accounts',                   100, TRUE),
    ('close_cash_day',      'financial',  'Close Cash Day',             'End-of-day cash closure',                  110, FALSE),

    -- Tax & GST
    ('view_gst_reports',    'tax',        'View GST Reports',           'Access GSTR-1, B2B/B2C, HSN reports',       10, FALSE),
    ('file_gst_returns',    'tax',        'File GST Returns',           'Submit GST filings',                        20, TRUE),

    -- Staff & Admin
    ('manage_staff',        'admin',      'Manage Staff',               'Add/remove staff, assign roles',            10, TRUE),
    ('manage_settings',     'admin',      'Manage Settings',            'Change business settings',                  20, TRUE),
    ('view_audit_log',      'admin',      'View Audit Log',             'Access audit trail',                        30, TRUE),
    ('lock_period',         'admin',      'Lock Accounting Period',     'Lock financial periods',                    40, TRUE),
    ('unlock_period',       'admin',      'Unlock Accounting Period',   'Unlock locked periods',                    50, TRUE),
    ('close_financial_year','admin',      'Close Financial Year',       'Year-end closing',                          60, TRUE),

    -- Security & Fraud
    ('view_security_dashboard','security','View Security Dashboard',    'Access security monitoring',                10, TRUE),
    ('manage_fraud_alerts', 'security',   'Manage Fraud Alerts',        'Configure fraud detection rules',           20, TRUE),
    ('accept_cash_mismatch','security',   'Accept Cash Mismatch',       'Override cash discrepancies',               30, TRUE),

    -- Petrol Pump specific
    ('manage_dispensers',   'petrol',     'Manage Dispensers',          'Configure dispensers and nozzles',          10, FALSE),
    ('manage_tanks',        'petrol',     'Manage Tanks',               'Tank level management',                    20, FALSE),
    ('manage_shifts',       'petrol',     'Manage Shifts',              'Shift management and handover',            30, FALSE),
    ('view_fuel_rates',     'petrol',     'View Fuel Rates',            'See current fuel pricing',                 40, FALSE),
    ('edit_fuel_rates',     'petrol',     'Edit Fuel Rates',            'Change fuel pricing',                      50, TRUE),
    ('nozzle_reading',      'petrol',     'Submit Nozzle Reading',      'Submit opening/closing readings',          60, FALSE),
    ('credit_sale',         'petrol',     'Credit Sale',                'Process credit sales to parties',          70, FALSE),
    ('lube_sale',           'petrol',     'Lube Sales',                 'Process lubricant sales',                  80, FALSE),

    -- Restaurant specific
    ('manage_tables',       'restaurant', 'Manage Tables',              'Table layout and management',               10, FALSE),
    ('manage_kot',          'restaurant', 'Manage KOT',                 'Kitchen order ticket management',           20, FALSE),
    ('manage_menu',         'restaurant', 'Manage Menu',                'Edit menu items and pricing',               30, FALSE),
    ('kitchen_display',     'restaurant', 'Kitchen Display Access',     'View kitchen display system',               40, FALSE),

    -- Clinic specific
    ('manage_patients',     'clinic',     'Manage Patients',            'Add/edit patient records',                  10, FALSE),
    ('view_patient_history','clinic',     'View Patient History',       'Access patient medical history',            20, FALSE),
    ('manage_prescriptions','clinic',     'Manage Prescriptions',       'Create and manage prescriptions',           30, FALSE),
    ('manage_appointments', 'clinic',     'Manage Appointments',        'Schedule and manage appointments',          40, FALSE),
    ('view_lab_reports',    'clinic',     'View Lab Reports',           'Access laboratory reports',                 50, FALSE),

    -- Pharmacy specific
    ('scan_prescription',   'pharmacy',   'Scan Prescription',          'Scan and process digital prescriptions',    10, FALSE),
    ('manage_batches_pharma','pharmacy',  'Manage Batches (Pharmacy)',  'Pharmacy batch and expiry tracking',        20, FALSE)

ON CONFLICT (id) DO NOTHING;

-- 3. Predefined roles per tenant (tenant can customize)
CREATE TABLE IF NOT EXISTS roles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       TEXT NOT NULL,                       -- FK to tenants.id
    name            TEXT NOT NULL,                       -- 'owner', 'manager', 'salesman', 'accountant', 'cashier', 'viewer'
    display_name    TEXT NOT NULL,                       -- Human-readable
    description     TEXT,
    is_system       BOOLEAN NOT NULL DEFAULT FALSE,      -- TRUE = cannot be deleted
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_roles_tenant ON roles(tenant_id);

-- 4. Role → Permission mapping
CREATE TABLE IF NOT EXISTS role_permissions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id         UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id   TEXT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    tenant_id       TEXT NOT NULL,                       -- Denormalized for RLS
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by      TEXT,                                -- Cognito sub of who granted
    UNIQUE(role_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_tenant ON role_permissions(tenant_id);

-- 5. Staff members belonging to a tenant
CREATE TABLE IF NOT EXISTS staff_members (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       TEXT NOT NULL,                       -- FK to tenants.id
    cognito_sub     TEXT,                                -- Cognito user ID (NULL until they accept invite)
    email           TEXT,
    phone           TEXT,
    name            TEXT NOT NULL,
    role_id         UUID NOT NULL REFERENCES roles(id),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    invite_status   TEXT NOT NULL DEFAULT 'pending',     -- 'pending', 'accepted', 'revoked'
    invite_code     TEXT,                                -- One-time invite code
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      TEXT,                                -- Owner's Cognito sub
    UNIQUE(tenant_id, email),
    UNIQUE(tenant_id, phone)
);

CREATE INDEX IF NOT EXISTS idx_staff_tenant ON staff_members(tenant_id);
CREATE INDEX IF NOT EXISTS idx_staff_cognito ON staff_members(cognito_sub);
CREATE INDEX IF NOT EXISTS idx_staff_invite ON staff_members(invite_code);

-- 6. Per-staff permission overrides (granular toggles on top of role)
--    If a record exists here, it OVERRIDES the role default for that permission.
CREATE TABLE IF NOT EXISTS staff_permission_overrides (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id        UUID NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    permission_id   TEXT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    tenant_id       TEXT NOT NULL,                       -- Denormalized for RLS
    granted         BOOLEAN NOT NULL,                    -- TRUE = allow, FALSE = deny
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by      TEXT,                                -- Owner's Cognito sub
    UNIQUE(staff_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_staff_overrides_staff ON staff_permission_overrides(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_overrides_tenant ON staff_permission_overrides(tenant_id);

-- 7. Materialized effective permissions view (for fast lookups)
CREATE OR REPLACE VIEW v_effective_permissions AS
SELECT
    sm.id AS staff_id,
    sm.tenant_id,
    sm.cognito_sub,
    sm.name AS staff_name,
    sm.role_id,
    r.name AS role_name,
    p.id AS permission_id,
    p.category AS permission_category,
    p.display_name AS permission_display_name,
    CASE
        WHEN spo.granted IS NOT NULL THEN spo.granted       -- Override takes priority
        WHEN rp.permission_id IS NOT NULL THEN TRUE          -- Role grants it
        ELSE FALSE                                           -- Not granted
    END AS is_granted
FROM staff_members sm
JOIN roles r ON r.id = sm.role_id
CROSS JOIN permissions p
LEFT JOIN role_permissions rp ON rp.role_id = sm.role_id AND rp.permission_id = p.id
LEFT JOIN staff_permission_overrides spo ON spo.staff_id = sm.id AND spo.permission_id = p.id
WHERE sm.is_active = TRUE;

-- 8. Function: Get effective permissions for a user (used by API)
CREATE OR REPLACE FUNCTION get_effective_permissions(p_cognito_sub TEXT, p_tenant_id TEXT)
RETURNS TABLE(permission_id TEXT, is_granted BOOLEAN) AS $$
BEGIN
    RETURN QUERY
    SELECT vep.permission_id, vep.is_granted
    FROM v_effective_permissions vep
    WHERE vep.cognito_sub = p_cognito_sub
      AND vep.tenant_id = p_tenant_id
      AND vep.is_granted = TRUE;
END;
$$ LANGUAGE plpgsql;

-- 9. Function: Check single permission (used by middleware)
CREATE OR REPLACE FUNCTION check_permission(p_cognito_sub TEXT, p_tenant_id TEXT, p_permission TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    result BOOLEAN;
BEGIN
    SELECT vep.is_granted INTO result
    FROM v_effective_permissions vep
    WHERE vep.cognito_sub = p_cognito_sub
      AND vep.tenant_id = p_tenant_id
      AND vep.permission_id = p_permission;

    RETURN COALESCE(result, FALSE);
END;
$$ LANGUAGE plpgsql;

-- 10. Function: Bootstrap default roles for a new tenant
CREATE OR REPLACE FUNCTION bootstrap_tenant_roles(p_tenant_id TEXT)
RETURNS VOID AS $$
DECLARE
    v_owner_role_id UUID;
    v_manager_role_id UUID;
    v_cashier_role_id UUID;
    v_accountant_role_id UUID;
    v_viewer_role_id UUID;
BEGIN
    -- Create system roles
    INSERT INTO roles (tenant_id, name, display_name, description, is_system)
    VALUES (p_tenant_id, 'owner', 'Owner', 'Full access to everything', TRUE)
    RETURNING id INTO v_owner_role_id;

    INSERT INTO roles (tenant_id, name, display_name, description, is_system)
    VALUES (p_tenant_id, 'manager', 'Manager', 'Operational access with limited financial', TRUE)
    RETURNING id INTO v_manager_role_id;

    INSERT INTO roles (tenant_id, name, display_name, description, is_system)
    VALUES (p_tenant_id, 'cashier', 'Cashier / Salesman', 'POS and basic billing only', TRUE)
    RETURNING id INTO v_cashier_role_id;

    INSERT INTO roles (tenant_id, name, display_name, description, is_system)
    VALUES (p_tenant_id, 'accountant', 'Accountant', 'Full financial access, no user management', TRUE)
    RETURNING id INTO v_accountant_role_id;

    INSERT INTO roles (tenant_id, name, display_name, description, is_system)
    VALUES (p_tenant_id, 'viewer', 'Viewer (Read-Only)', 'Read-only access for CA/Auditor', TRUE)
    RETURNING id INTO v_viewer_role_id;

    -- Owner gets ALL permissions
    INSERT INTO role_permissions (role_id, permission_id, tenant_id)
    SELECT v_owner_role_id, p.id, p_tenant_id FROM permissions p;

    -- Manager: billing + inventory + parties + purchases + basic financial
    INSERT INTO role_permissions (role_id, permission_id, tenant_id)
    SELECT v_manager_role_id, p.id, p_tenant_id
    FROM permissions p
    WHERE p.id IN (
        'create_bill', 'edit_bill', 'print_bill', 'apply_discount',
        'view_inventory', 'edit_inventory', 'adjust_stock', 'manage_categories', 'manage_batches',
        'view_customers', 'create_customer', 'edit_customer', 'view_customer_balance',
        'view_suppliers', 'manage_suppliers',
        'create_purchase', 'edit_purchase', 'view_purchase_report',
        'view_reports', 'view_cashbook', 'make_payment', 'receive_payment',
        'manage_dispensers', 'manage_tanks', 'manage_shifts', 'view_fuel_rates',
        'nozzle_reading', 'credit_sale', 'lube_sale',
        'manage_tables', 'manage_kot', 'kitchen_display',
        'manage_patients', 'view_patient_history', 'manage_prescriptions', 'manage_appointments',
        'scan_prescription', 'manage_batches_pharma'
    );

    -- Cashier: create bill + print + view stock + receive payment
    INSERT INTO role_permissions (role_id, permission_id, tenant_id)
    SELECT v_cashier_role_id, p.id, p_tenant_id
    FROM permissions p
    WHERE p.id IN (
        'create_bill', 'print_bill',
        'view_inventory',
        'view_customers', 'create_customer', 'view_customer_balance',
        'receive_payment', 'close_cash_day',
        'nozzle_reading', 'lube_sale',
        'manage_kot', 'kitchen_display',
        'scan_prescription'
    );

    -- Accountant: financial + reports + GST (no staff/settings)
    INSERT INTO role_permissions (role_id, permission_id, tenant_id)
    SELECT v_accountant_role_id, p.id, p_tenant_id
    FROM permissions p
    WHERE p.id IN (
        'create_bill', 'edit_bill', 'reverse_bill', 'print_bill',
        'view_inventory', 'adjust_stock', 'view_stock_value',
        'view_customers', 'create_customer', 'edit_customer', 'view_customer_balance',
        'view_suppliers', 'manage_suppliers',
        'create_purchase', 'edit_purchase', 'view_purchase_report',
        'view_reports', 'view_profit', 'view_cashbook', 'view_ledger',
        'make_payment', 'receive_payment', 'journal_entry', 'view_daybook', 'manage_expenses',
        'lock_period', 'view_audit_log',
        'view_gst_reports', 'file_gst_returns'
    );

    -- Viewer: read-only
    INSERT INTO role_permissions (role_id, permission_id, tenant_id)
    SELECT v_viewer_role_id, p.id, p_tenant_id
    FROM permissions p
    WHERE p.id IN (
        'view_inventory', 'view_stock_value',
        'view_customers', 'view_customer_balance', 'view_suppliers',
        'view_purchase_report',
        'view_reports', 'view_profit', 'view_cashbook', 'view_ledger', 'view_daybook',
        'view_gst_reports', 'view_audit_log'
    );
END;
$$ LANGUAGE plpgsql;

-- 11. RLS Policies
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_permission_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY roles_tenant_isolation ON roles
    USING (tenant_id = current_setting('app.tenant_id', TRUE));
CREATE POLICY role_permissions_tenant_isolation ON role_permissions
    USING (tenant_id = current_setting('app.tenant_id', TRUE));
CREATE POLICY staff_tenant_isolation ON staff_members
    USING (tenant_id = current_setting('app.tenant_id', TRUE));
CREATE POLICY staff_overrides_tenant_isolation ON staff_permission_overrides
    USING (tenant_id = current_setting('app.tenant_id', TRUE));
