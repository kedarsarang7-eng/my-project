-- Multi-Tenant PostgreSQL Schema for DukanX
-- Supports Sync (Offline-First) and Saas (Multi-Business)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users (Global/Owner Level)
-- Users exist across businesses (an owner involves in multiple businesses)
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Businesses (Tenants)
CREATE TABLE businesses (
    business_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES users(user_id),
    name VARCHAR(200) NOT NULL,
    business_type VARCHAR(50), -- retail, hotel, petrol_pump
    address TEXT,
    gstin VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- 3. Business Users (Staff/Role Mapping)
CREATE TABLE business_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(business_id),
    user_id UUID NOT NULL REFERENCES users(user_id),
    role VARCHAR(50) NOT NULL DEFAULT 'staff', -- owner, manager, staff
    permissions JSONB, -- Granular permissions
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(business_id, user_id)
);

-- MACRO: Standard Columns for Sync-Enabled Tables
-- All following tables must have:
-- business_id (Tenant Isolation)
-- updated_at (Sync Logic)
-- is_deleted (Soft Delete)

-- 4. Customers
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(business_id),
    
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    balance DECIMAL(15, 2) DEFAULT 0.00,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- Sync Metadata
    last_synced_at TIMESTAMP WITH TIME ZONE
);
CREATE INDEX idx_customers_biz ON customers(business_id);
CREATE INDEX idx_customers_updated ON customers(updated_at);

-- 5. Products / Inventory
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(business_id),
    
    name VARCHAR(200) NOT NULL,
    sku VARCHAR(50),
    price DECIMAL(10, 2) NOT NULL,
    stock_qty DECIMAL(10, 2) DEFAULT 0.00,
    unit VARCHAR(20),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_products_biz ON products(business_id);

-- 6. Bills / Invoices
CREATE TABLE bills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(business_id),
    customer_id UUID REFERENCES customers(id),
    
    invoice_number VARCHAR(50) NOT NULL,
    bill_date TIMESTAMP WITH TIME ZONE NOT NULL,
    total_amount DECIMAL(15, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'PAID',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_bills_biz ON bills(business_id);
CREATE INDEX idx_bills_updated ON bills(updated_at);

-- 7. Bill Items
CREATE TABLE bill_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(business_id), -- Denormalized for RLS efficiency
    bill_id UUID NOT NULL REFERENCES bills(id),
    product_id UUID REFERENCES products(id),
    
    qty DECIMAL(10, 2) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    total DECIMAL(15, 2) NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_bill_items_biz ON bill_items(business_id);

-- ROW LEVEL SECURITY (RLS) POLICIES
-- Example for Customers table

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_policy ON customers
    USING (business_id = current_setting('app.current_business_id')::UUID);

-- Similar policies should be applied to all business-scoped tables.
