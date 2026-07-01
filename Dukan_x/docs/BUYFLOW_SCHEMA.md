# BuyFlow Database Schema Design

This document outlines the comprehensive database schema for the **BuyFlow** module, designed for both Firestore (NoSQL) and SQL (PostgreSQL/MySQL) implementations. It supports multi-tenant architecture with strict data isolation.

---

## 1. Firestore Collection Tree (NoSQL)

All root collections handle data for all users. Security rules MUST enforce `request.auth.uid == resource.data.ownerId`.

### **Core Collections**

**`users`**
*   `/{userId}`: User profile and business settings.

**`vendors`**
*   `/{vendorId}`: Vendor master data.

**`items`**
*   `/{itemId}`: Product/Service master data with stock info.

**`stockEntries`** (Purchase Bills)
*   `/{entryId}`: Header details for a stock purchase.
    *   `items/{lineId}`: Sub-collection for invoice line items.

**`vendorPayments`** (Payouts)
*   `/{paymentId}`: Records of payments made to vendors.

**`stockReversals`** (Returns/Debit Notes)
*   `/{reversalId}`: Header details for returned stock.
    *   `items/{lineId}`: Sub-collection for returned items.

**`buyOrders`** (Purchase Orders)
*   `/{orderId}`: Orders placed but not yet received.
    *   `items/{lineId}`: Sub-collection for order items.

**`ledgers`** (General Ledger)
*   `/{ledgerId}`: Flattened transaction history for accounting.

---

## 2. Sample Document Models (JSON)

### **Vendor** (`/vendors/{vendorId}`)
```json
{
  "vendorId": "v_123456",
  "ownerId": "user_xyz",
  "name": "Raj Hardware Traders",
  "phone": "+919876543210",
  "email": "raj@hardware.com",
  "gstNumber": "27ABCDE1234F1Z5",
  "openingBalance": 0.0,
  "currentBalance": -5000.0,  // Negative means we owe them (Credit)
  "createdAt": "2023-10-25T10:00:00Z",
  "updatedAt": "2023-10-26T14:30:00Z",
  "isDeleted": false
}
```

### **Stock Entry** (`/stockEntries/{entryId}`)
```json
{
  "entryId": "se_987654",
  "ownerId": "user_xyz",
  "vendorId": "v_123456",
  "invoiceNumber": "INV-2023-001",
  "invoiceDate": "2023-10-26T00:00:00Z",
  "totalAmount": 11800.0,
  "taxAmount": 1800.0,
  "discountAmount": 0.0,
  "paidAmount": 5000.0,
  "dueAmount": 6800.0,
  "paymentStatus": "PARTIAL", // UNPAID, PARTIAL, PAID
  "billImageUrl": "https://storage.../bills/img.jpg",
  "notes": "Delivered by truck",
  "createdAt": "2023-10-26T10:00:00Z"
}
```

### **Stock Entry Item** (`/stockEntries/{entryId}/items/{lineId}`)
```json
{
  "lineId": "item_1",
  "itemId": "prod_001",
  "name": "Cement Bag 50kg",
  "quantity": 20.0,
  "rate": 500.0,
  "taxPercent": 18.0,
  "taxAmount": 1800.0, // Total tax for this line
  "total": 11800.0     // (20 * 500) + 1800
}
```

### **Vendor Payment** (`/vendorPayments/{paymentId}`)
```json
{
  "paymentId": "vp_555",
  "ownerId": "user_xyz",
  "vendorId": "v_123456",
  "amount": 5000.0,
  "mode": "UPI", // CASH, BANK, CHEQUE
  "referenceNo": "UPI-1234567890",
  "linkedEntryIds": ["se_987654"], // Bills this payment settles
  "createdAt": "2023-10-26T10:05:00Z"
}
```

---

## 3. SQL Schema (PostgreSQL/MySQL Compatible)

```sql
-- 1. USERS TABLE
CREATE TABLE users (
    user_id VARCHAR(50) PRIMARY KEY,
    owner_id VARCHAR(50) NOT NULL, -- Often same as user_id for owner
    business_name VARCHAR(100),
    role VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_users_owner ON users(owner_id);

-- 2. VENDORS TABLE
CREATE TABLE vendors (
    vendor_id VARCHAR(50) PRIMARY KEY,
    owner_id VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    gst_number VARCHAR(20),
    opening_balance DECIMAL(20, 2) DEFAULT 0,
    current_balance DECIMAL(20, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_vendors_owner ON vendors(owner_id);

-- 3. ITEMS TABLE (Inventory)
CREATE TABLE items (
    item_id VARCHAR(50) PRIMARY KEY,
    owner_id VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    sku VARCHAR(50),
    purchase_rate DECIMAL(20, 2),
    sale_rate DECIMAL(20, 2),
    tax_percent DECIMAL(5, 2),
    stock_qty DECIMAL(20, 4) DEFAULT 0,
    unit VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_items_owner ON items(owner_id);

-- 4. STOCK ENTRIES (Purchase Bills)
CREATE TABLE stock_entries (
    entry_id VARCHAR(50) PRIMARY KEY,
    owner_id VARCHAR(50) NOT NULL,
    vendor_id VARCHAR(50) NOT NULL REFERENCES vendors(vendor_id),
    invoice_number VARCHAR(50),
    invoice_date TIMESTAMP NOT NULL,
    total_amount DECIMAL(20, 2) NOT NULL,
    tax_amount DECIMAL(20, 2) DEFAULT 0,
    discount_amount DECIMAL(20, 2) DEFAULT 0,
    paid_amount DECIMAL(20, 2) DEFAULT 0,
    due_amount DECIMAL(20, 2) DEFAULT 0,
    payment_status VARCHAR(20) CHECK (payment_status IN ('PAID', 'PARTIAL', 'UNPAID')),
    bill_image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_stock_entries_owner_vendor ON stock_entries(owner_id, vendor_id);

-- 5. STOCK ENTRY ITEMS (Line Items)
CREATE TABLE stock_entry_items (
    line_id VARCHAR(50) PRIMARY KEY,
    entry_id VARCHAR(50) NOT NULL REFERENCES stock_entries(entry_id) ON DELETE CASCADE,
    item_id VARCHAR(50) NOT NULL REFERENCES items(item_id),
    quantity DECIMAL(20, 4) NOT NULL,
    rate DECIMAL(20, 2) NOT NULL,
    tax_percent DECIMAL(5, 2) DEFAULT 0,
    total DECIMAL(20, 2) NOT NULL
);
CREATE INDEX idx_entry_items_entry ON stock_entry_items(entry_id);

-- 6. VENDOR PAYMENTS
CREATE TABLE vendor_payments (
    payment_id VARCHAR(50) PRIMARY KEY,
    owner_id VARCHAR(50) NOT NULL,
    vendor_id VARCHAR(50) NOT NULL REFERENCES vendors(vendor_id),
    amount DECIMAL(20, 2) NOT NULL,
    mode VARCHAR(20) CHECK (mode IN ('CASH', 'UPI', 'BANK', 'CHEQUE')),
    reference_no VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_payments_owner_vendor ON vendor_payments(owner_id, vendor_id);

-- 7. STOCK REVERSALS (Purchase Returns)
CREATE TABLE stock_reversals (
    reversal_id VARCHAR(50) PRIMARY KEY,
    owner_id VARCHAR(50) NOT NULL,
    vendor_id VARCHAR(50) NOT NULL REFERENCES vendors(vendor_id),
    original_entry_id VARCHAR(50) REFERENCES stock_entries(entry_id),
    total_amount DECIMAL(20, 2) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. LEDGER (Accounting)
CREATE TABLE ledger (
    ledger_id VARCHAR(50) PRIMARY KEY,
    owner_id VARCHAR(50) NOT NULL,
    vendor_id VARCHAR(50) REFERENCES vendors(vendor_id),
    transaction_type VARCHAR(50), -- STOCK_ENTRY, PAYMENT, REVERSAL
    transaction_id VARCHAR(50) NOT NULL,
    debit DECIMAL(20, 2) DEFAULT 0,
    credit DECIMAL(20, 2) DEFAULT 0,
    balance_after DECIMAL(20, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_ledger_owner_vendor ON ledger(owner_id, vendor_id);
```

---

## 4. Entity Explanations

1.  **Users/Owners**: The root of the tenancy. Every query MUST exclude data where `owner_id` does not match the current user.
2.  **Vendors**: Entities we buy from. Contains financial standing (`currentBalance`).
3.  **Items**: Products. `stockQty` here is the *calculated current stock*.
4.  **Stock Entries**: The immutable record of goods entering the business. Acts as the source of truth for stock increase and liability increase (Credit Vendor).
5.  **Vendor Payments**: Records of money leaving the business. Decreases liability (Debit Vendor).
6.  **Stock Reversals**: Goods leaving back to vendor. Decreases stock and decreases liability (Debit Vendor).
7.  **Ledger**: A flattened, chronological view of all financial interactions with a vendor. Crucial for generating "Account Statements".

---

## 5. Business Logic Flow

### **A. Creating a Stock Entry (Buy)**
1.  **Validate**: Check if Vendor exists.
2.  **Stock Update**: Loop through items. For each item, `stockQty = stockQty + newQty`.
3.  **Financials**:
    *   `Liability` increases by `Entry.dueAmount`.
    *   `Vendor.currentBalance` updates (becomes more negative if buying on credit).
    *   **Ledger**: Insert Credit entry for Vendor.
4.  **Persistence**: Save `StockEntry` header and `StockEntryItems`.

### **B. Making a Payment**
1.  **Input**: Select Vendor, Amount, Mode.
2.  **Allocation**:
    *   Optionally select specific `StockEntries` to mark as "PAID".
    *   Or, just treat as "On Account" payment.
3.  **Financials**:
    *   `Liability` decreases.
    *   `Vendor.currentBalance` updates (becomes positive/less negative).
    *   **Ledger**: Insert Debit entry for Vendor.
4.  **Persistence**: Save `VendorPayment`.

### **C. Purchase Return (Reversal)**
1.  **Validation**: Ensure return qty <= original qty (optional, but good practice).
2.  **Stock Update**: `stockQty = stockQty - returnQty`.
3.  **Financials**:
    *   Treat as a Debit Note.
    *   Vendor owes us money/credit for this.
    *   `Liability` decreases.
    *   **Ledger**: Insert Debit entry.

---

## 6. Edge Cases & Safety

1.  **Network Failure**:
    *   **Firestore**: Enable `persistenceEnabled`. Writes queue locally.
    *   **Sync**: When online, queued writes commit.
    *   **Logic**: Use *Cloud Functions* or *Transactions* for stock updates to avoid race conditions (e.g., two devices selling same item). For "Blind Writes" (increment), use `FieldValue.increment()`.

2.  **Concurrency**:
    *   Two users editing same vendor?
    *   Use `FieldValue.increment()` for balance updates. Never read-modify-write balances on client side if high concurrency is expected.

3.  **Data Integrity**:
    *   **Deleting a Bill**: Must reverse the stock additions and reverse the vendor balance impact.
    *   **Soft Delete**: Use `isDeleted = true`. Exclude these from queries.

4.  **Precision**:
    *   Always use high-precision decimals (or integers representing cents) for currency to avoid floating point errors.

