-- SQL Equivalent Schema for Business Billing App
-- Designed for PostgreSQL / MySQL
-- Ensures normalization and referential integrity

-- 1. Users (Business Owners)
CREATE TABLE users (
    user_id VARCHAR(50) PRIMARY KEY, -- Firebase UID
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(20) DEFAULT 'owner',
    subscription_plan VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Business Profiles
CREATE TABLE business_profiles (
    profile_id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    business_name VARCHAR(200) NOT NULL,
    gst_number VARCHAR(20),
    email VARCHAR(100),
    phone VARCHAR(20),
    street_address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(20),
    logo_url TEXT,
    currency CHAR(3) DEFAULT 'INR',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Customers
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY, -- UUID or composed ID
    user_id VARCHAR(50) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    billing_address TEXT,
    shipping_address TEXT,
    gstin VARCHAR(20),
    opening_balance DECIMAL(15, 2) DEFAULT 0.00,
    current_balance DECIMAL(15, 2) DEFAULT 0.00, -- Receivable (+) / Payable (-)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idx_user_customer_phone UNIQUE (user_id, phone)
);

-- 4. Inventory Items
CREATE TABLE items (
    item_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    item_name VARCHAR(200) NOT NULL,
    sku VARCHAR(50),
    hsn_code VARCHAR(20),
    unit VARCHAR(20), -- pcs, kg, ltr
    sale_price DECIMAL(10, 2) NOT NULL,
    purchase_price DECIMAL(10, 2),
    tax_percent DECIMAL(5, 2) DEFAULT 0.00,
    current_stock DECIMAL(10, 2) DEFAULT 0.00,
    low_stock_limit DECIMAL(10, 2) DEFAULT 5.00,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idx_user_sku UNIQUE (user_id, sku)
);

-- 5. Sales (Invoices)
CREATE TABLE sales (
    sale_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(customer_id) ON DELETE SET NULL,
    invoice_number VARCHAR(50) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE,
    
    subtotal DECIMAL(15, 2) NOT NULL,
    discount_total DECIMAL(15, 2) DEFAULT 0.00,
    tax_total DECIMAL(15, 2) DEFAULT 0.00,
    round_off DECIMAL(5, 2) DEFAULT 0.00,
    grand_total DECIMAL(15, 2) NOT NULL,
    
    paid_amount DECIMAL(15, 2) DEFAULT 0.00,
    balance_amount DECIMAL(15, 2) NOT NULL, -- (GrandTotal - PaidAmount)
    
    status VARCHAR(20) DEFAULT 'UNPAID', -- PAID, PARTIAL, UNPAID, CANCELLED
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idx_user_invoice_no UNIQUE (user_id, invoice_number)
);

-- 6. Sale Items (Line Items)
CREATE TABLE sale_items (
    sale_item_id SERIAL PRIMARY KEY,
    sale_id VARCHAR(50) NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    item_id VARCHAR(50) REFERENCES items(item_id),
    item_name VARCHAR(200) NOT NULL, -- Snapshot incase item is deleted
    qty DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    tax_percent DECIMAL(5, 2) DEFAULT 0.00,
    tax_amount DECIMAL(10, 2) DEFAULT 0.00,
    total_amount DECIMAL(15, 2) NOT NULL
);

-- 7. Payments (Received)
CREATE TABLE payments (
    payment_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(customer_id) ON DELETE SET NULL,
    receipt_number VARCHAR(50),
    payment_date DATE NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    payment_mode VARCHAR(20) DEFAULT 'CASH', -- CASH, UPI, BANK, CHEQUE
    reference_number VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Payment-Sale Mapping (Many-to-Many)
-- Which payment paid which invoice
CREATE TABLE payment_allocations (
    allocation_id SERIAL PRIMARY KEY,
    payment_id VARCHAR(50) NOT NULL REFERENCES payments(payment_id) ON DELETE CASCADE,
    sale_id VARCHAR(50) NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    allocated_amount DECIMAL(15, 2) NOT NULL
);

-- 9. Transaction Ledger (The Source of Truth)
CREATE TABLE transactions (
    txn_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(customer_id),
    
    txn_type VARCHAR(20) NOT NULL, -- SALE, PAYMENT, RETURN
    reference_id VARCHAR(50) NOT NULL, -- SaleID or PaymentID
    display_number VARCHAR(50), -- Invoice No or Receipt No
    
    debit_amount DECIMAL(15, 2) DEFAULT 0.00, -- Increases Receivable
    credit_amount DECIMAL(15, 2) DEFAULT 0.00, -- Decreases Receivable
    
    running_balance DECIMAL(15, 2) NOT NULL,
    txn_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. Sale Returns (Credit Notes)
CREATE TABLE sale_returns (
    return_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES users(user_id),
    sale_id VARCHAR(50) REFERENCES sales(sale_id),
    customer_id VARCHAR(50) REFERENCES customers(customer_id),
    credit_note_number VARCHAR(50) NOT NULL,
    return_date DATE NOT NULL,
    refund_amount DECIMAL(15, 2) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sale_return_items (
    return_item_id SERIAL PRIMARY KEY,
    return_id VARCHAR(50) NOT NULL REFERENCES sale_returns(return_id) ON DELETE CASCADE,
    item_id VARCHAR(50) REFERENCES items(item_id),
    qty DECIMAL(10, 2) NOT NULL,
    refund_amount DECIMAL(15, 2) NOT NULL
);

-- Additional Tables for Orders, Challans would follow similar structure
-- Indexes for Performance
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_date ON sales(invoice_date);
CREATE INDEX idx_txn_customer ON transactions(customer_id);
CREATE INDEX idx_items_name ON items(item_name);
