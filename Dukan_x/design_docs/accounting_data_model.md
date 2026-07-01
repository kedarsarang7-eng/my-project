# Production-Ready Accounting Data Model (Firestore + SQL)

This document outlines a robust, double-entry accounting data model designed for scalability, data consistency, and compliance with standard accounting practices (GAAP/IFRS). It supports both **NoSQL (Firestore)** and **SQL (PostgreSQL/MySQL)** implementations.

---

## 🧠 Core Principles

1.  **Single Source of Truth**: All reports are derived dynamically from `transactions` and `ledger_entries`. No pre-calculated report tables are stored.
2.  **Double-Entry Accounting**: Every financial transaction creates at least two `ledger_entries` where `SUM(Debit) = SUM(Credit)`.
3.  **Immutability**: Historical financial data is versioned; edits create reversing entries rather than destructive updates (optional but recommended for audit trails).
4.  **Tenancy**: All data is strictly scoped by `businessId`.

---

## 🗂️ Firestore Schema Structure

The hierarchy is designed for multi-tenancy and offline-first usage.

**Root Hierarchy:**
```text
/users/{userId}
/businesses/{businessId}
   ├── profile/info          (Business metadata)
   ├── parties/{partyId}     (Customers & Suppliers)
   ├── items/{itemId}        (Inventory Master)
   ├── transactions/{txnId}  (Heads of Invoices/Bills/Journals)
   ├── transaction_items/{txnItemId} (Line items for transactions)
   ├── payments/{paymentId}  (Receipts & Payments)
   ├── expenses/{expenseId}  (Direct/Indirect Expenses)
   ├── stock_ledger/{entryId}(Inventory movements)
   ├── ledgers/{ledgerId}    (Chart of Accounts)
   ├── ledger_entries/{entryId} (Journal Entries - Double Entry Core)
   └── settings/config       (App preferences)
```

### 1. Businesses
*Collection: `/businesses`*
Stores tenant information.

| Field | Type | Description |
| :--- | :--- | :--- |
| `businessId` | String (UUID) | **PK**. Unique Business ID. |
| `ownerId` | String | Owner's User ID. |
| `name` | String | Business Name. |
| `currency` | String | ISO Code (e.g., 'INR', 'USD'). |
| `financialYearStart` | Timestamp | Start of FY (e.g., April 1st). |
| `createdAt` | Timestamp | Creation date. |

### 2. Parties
*Collection: `/businesses/{bid}/parties`*
Unified collection for Customers and Suppliers (Sundry Debtors / Sundry Creditors).

| Field | Type | Description |
| :--- | :--- | :--- |
| `partyId` | String (UUID) | **PK**. |
| `type` | String | `CUSTOMER` or `SUPPLIER`. |
| `name` | String | Display Name. |
| `phone` | String | Contact Number. |
| `gstin` | String | Tax ID. |
| `ledgerId` | String | **FK**. Link to `ledgers` (Accounts Receivable/Payable). |
| `runningBalance` | Number | Cached balance (updated via triggers/functions). |

### 3. Items (Stock Master)
*Collection: `/businesses/{bid}/items`*
Inventory definitions.

| Field | Type | Description |
| :--- | :--- | :--- |
| `itemId` | String (UUID) | **PK**. |
| `name` | String | Item Name. |
| `type` | String | `PRODUCT` or `SERVICE`. |
| `salePrice` | Number | Standard Selling Price. |
| `purchasePrice` | Number | Standard Cost Price. |
| `gstRate` | Number | Tax Percentage. |
| `stockQty` | Number | Quantity on Hand (Derived from Stock Ledger). |
| `valuationMethod` | String | `FIFO`, `AVG_COST`. |

### 4. Transactions (🔥 Core)
*Collection: `/businesses/{bid}/transactions`*
The header record for any financial event.

| Field | Type | Description |
| :--- | :--- | :--- |
| `txnId` | String (UUID) | **PK**. |
| `refNo` | String | Invoice No / Receipt No. |
| `date` | Timestamp | Transaction Date. |
| `type` | String | `SALE`, `PURCHASE`, `SALE_RETURN`, `PURCHASE_RETURN`, `PAYMENT_IN`, `PAYMENT_OUT`, `EXPENSE`, `JOURNAL`. |
| `partyId` | String | **FK** (Nullable). Linked Party. |
| `subTotal` | Number | Amount before tax. |
| `taxAmount` | Number | Total Tax. |
| `totalAmount` | Number | Grand Total. |
| `balanceAmount` | Number | Unpaid amount (for aging reports). |
| `paymentStatus` | String | `PAID`, `PARTIAL`, `UNPAID`. |
| `dueDate` | Timestamp | Payment due date. |
| `createdAt` | Timestamp | Audit timestamp. |

### 5. Transaction Items
*Collection: `/businesses/{bid}/transaction_items`*
Detailed line items for Sales and Purchases.

| Field | Type | Description |
| :--- | :--- | :--- |
| `txnItemId` | String (UUID) | **PK**. |
| `txnId` | String | **FK**. Parent Transaction. |
| `itemId` | String | **FK**. Linked Stock Item. |
| `qty` | Number | Quantity. |
| `rate` | Number | Unit Price. |
| `gstAmount` | Number | Tax amount for this line. |
| `netAmount` | Number | (Qty * Rate) + Tax. |
| `costPrice` | Number | **CRITICAL**. COGS value at time of sale (from Stock Ledger). |

### 6. Payments
*Collection: `/businesses/{bid}/payments`*
Tracks money flow (Cash/Bank). Usually linked to a `txnId` (Invoice) or standalone.

| Field | Type | Description |
| :--- | :--- | :--- |
| `paymentId` | String (UUID) | **PK**. |
| `txnId` | String | **FK**. Linked Invoice (if specific bill payment). |
| `date` | Timestamp | Payment Date. |
| `mode` | String | `CASH`, `BANK`, `UPI`, `CHEQUE`. |
| `amount` | Number | Amount Paid/Received. |
| `direction` | String | `IN` (Receipt), `OUT` (Payment). |
| `ledgerId` | String | **FK**. Cash or Bank Ledger Account. |

### 7. Stock Ledger
*Collection: `/businesses/{bid}/stock_ledger`*
Granular history of inventory movement. Calculates Closing Stock & COGS.

| Field | Type | Description |
| :--- | :--- | :--- |
| `entryId` | String (UUID) | **PK**. |
| `date` | Timestamp | Movement Date. |
| `itemId` | String | **FK**. |
| `txnId` | String | **FK**. |
| `qtyIn` | Number | Quantity added (Purchase/Return). |
| `qtyOut` | Number | Quantity removed (Sale/Loss). |
| `rate` | Number | Purchase Rate / Cost Rate. |
| `costValue` | Number | Value of this movement (`qty` * `rate`). |

### 8. Ledgers (Chart of Accounts)
*Collection: `/businesses/{bid}/ledgers`*
Definitions of accounting heads.

| Field | Type | Description |
| :--- | :--- | :--- |
| `ledgerId` | String (UUID) | **PK**. |
| `name` | String | e.g., "Cash", "HDFC Bank", "Sales Account", "DukanX Systems". |
| `group` | String | `ASSETS`, `LIABILITIES`, `INCOME`, `EXPENSES`, `EQUITY`. |
| `subGroup` | String | e.g., `Current Assets`, `Indirect Expenses`. |

### 9. Ledger Entries (Journal)
*Collection: `/businesses/{bid}/ledger_entries`*
**The holy grail of accounting.** Every `txn` generates 2+ entries here.

| Field | Type | Description |
| :--- | :--- | :--- |
| `entryId` | String (UUID) | **PK**. |
| `txnId` | String | **FK**. Source Transaction. |
| `ledgerId` | String | **FK**. Account being debited/credited. |
| `date` | Timestamp | Entry Date. |
| `debit` | Number | Debit Amount (0 if Credit). |
| `credit` | Number | Credit Amount (0 if Debit). |
| `description` | String | Narration. |

---

## 🛠️ SQL Tables Definition

For a relational backend (PostgreSQL), use these definitions. Indexes are crucial for report performance.

```sql
-- 1. Businesses
CREATE TABLE businesses (
    business_id UUID PRIMARY KEY,
    owner_id VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Ledgers (Chart of Accounts)
CREATE TABLE ledgers (
    ledger_id UUID PRIMARY KEY,
    business_id UUID REFERENCES businesses(business_id),
    name VARCHAR(255) NOT NULL,
    account_group VARCHAR(50) NOT NULL, -- ASSET, LIABILITY, INCOME, EXPENSE
    curr_balance DECIMAL(15, 2) DEFAULT 0
);
CREATE INDEX idx_ledgers_biz ON ledgers(business_id);

-- 3. Parties
CREATE TABLE parties (
    party_id UUID PRIMARY KEY,
    business_id UUID REFERENCES businesses(business_id),
    ledger_id UUID REFERENCES ledgers(ledger_id), -- Link to GL
    name VARCHAR(255),
    type VARCHAR(20) CHECK (type IN ('CUSTOMER', 'SUPPLIER')),
    gstin VARCHAR(20)
);
CREATE INDEX idx_parties_biz ON parties(business_id);

-- 4. Transactions
CREATE TABLE transactions (
    txn_id UUID PRIMARY KEY,
    business_id UUID REFERENCES businesses(business_id),
    party_id UUID REFERENCES parties(party_id),
    date DATE NOT NULL,
    type VARCHAR(20) NOT NULL, -- SALE, PURCHASE...
    ref_no VARCHAR(50),
    total_amount DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_txn_biz_date ON transactions(business_id, date);

-- 5. Transaction Items
CREATE TABLE transaction_items (
    txn_item_id UUID PRIMARY KEY,
    txn_id UUID REFERENCES transactions(txn_id),
    item_id UUID, -- Link to Items table (omitted for brevity)
    qty DECIMAL(10, 2),
    rate DECIMAL(15, 2),
    cost_price DECIMAL(15, 2), -- Captured at time of sale for profit calc
    gst_amount DECIMAL(15, 2)
);
CREATE INDEX idx_txn_items_txn ON transaction_items(txn_id);

-- 6. Ledger Entries (Double Entry Journal)
CREATE TABLE ledger_entries (
    entry_id UUID PRIMARY KEY,
    business_id UUID REFERENCES businesses(business_id),
    txn_id UUID REFERENCES transactions(txn_id),
    ledger_id UUID REFERENCES ledgers(ledger_id),
    date DATE NOT NULL,
    debit DECIMAL(15, 2) DEFAULT 0,
    credit DECIMAL(15, 2) DEFAULT 0
);
CREATE INDEX idx_le_biz_date ON ledger_entries(business_id, date);
CREATE INDEX idx_le_ledger ON ledger_entries(ledger_id);

-- 7. Stock Ledger
CREATE TABLE stock_ledger (
    entry_id UUID PRIMARY KEY,
    business_id UUID REFERENCES businesses(business_id),
    item_id UUID,
    txn_id UUID REFERENCES transactions(txn_id),
    date DATE NOT NULL,
    qty_in DECIMAL(10, 2) DEFAULT 0,
    qty_out DECIMAL(10, 2) DEFAULT 0,
    rate DECIMAL(15, 2)
);
CREATE INDEX idx_stock_item_date ON stock_ledger(business_id, item_id, date);
```

---

## 📊 Report Generation Logic

### 1. Sale / Purchase Report
*   **Source**: `transactions` collection.
*   **Logic**: Query `where 'type' == 'SALE'` (or `'PURCHASE'`) AND `date` between range.
*   **Columns**: Date, Invoice No (`refNo`), Party Name, Payment Status, Amount.

### 2. Day Book
*   **Source**: `transactions` or `ledger_entries`.
*   **Logic**: Fetch all events (`SALE`, `PURCHASE`, `PAYMENT`, `EXPENSE`) for a specific `date`.
*   **Display**: Chronological list of activities.

### 3. Bill Wise Profit
*   **Source**: `transaction_items` linked with `transactions`.
*   **Logic**:
    *   For each Sale Item: `Profit = (Selling Price - Cost Price) * Qty`.
    *   `Cost Price` determines accuracy (FIFO vs. Weighted Avg). Ideally, `costPrice` is stamped onto the `transaction_item` at the time of creation by checking the `stock_ledger`.
*   **Total**: Sum of profits of all items in a bill.

### 4. Profit & Loss (Income Statement)
*   **Source**: `ledger_entries`.
*   **Logic**:
    1.  **Revenue**: `SUM(Credit) - SUM(Debit)` for all `INCOME` group ledgers (e.g., Sales).
    2.  **COGS (Cost of Goods Sold)**: Opening Stock + Purchase - Closing Stock.
    3.  **Gross Profit**: Revenue - COGS.
    4.  **Expenses**: `SUM(Debit) - SUM(Credit)` for all `EXPENSE` group ledgers.
    5.  **Net Profit**: Gross Profit - Expenses.

### 5. Balance Sheet
*   **Source**: `ledger_entries` (Running Balance).
*   **Logic**: Aggregates balances of `ASSETS`, `LIABILITIES`, and `EQUITY` groups as of a specific date.
    *   **Assets**: Cash + Bank + Debtors + Closing Stock + Fixed Assets.
    *   **Liabilities**: Creditors + Loans + Taxes Payable.
    *   **Equation**: Assets = Liabilities + Equity (Net Profit flows into Equity).

### 6. Trial Balance
*   **Source**: `ledger_entries`.
*   **Logic**: Group by `ledgerId`, sum `debit` and `credit`.
*   **Check**: Total Debits must equal Total Credits.

### 7. Cashflow
*   **Source**: `ledger_entries` filtering for Cash/Bank ledgers.
*   **Logic**:
    *   **Inflow**: `SUM(Debit)` on Cash/Bank ledgers.
    *   **Outflow**: `SUM(Credit)` on Cash/Bank ledgers.
    *   **Net Flow**: Inflow - Outflow.

---

## 🧩 Example: Double Entry Workflow (Sale of Goods)

**Scenario**: Sold goods worth ₹1,000 + ₹180 GST to Customer 'Rohan' on Credit.

1.  **Create Transaction**: `txnId: '101'`, Type: `SALE`, Total: `1180`.
2.  **Create Transaction Items**: Item 'A', Qty 1, Rate 1000.
3.  **Create Ledger Entries**:

| Ledger Name | Group | Debit | Credit | Logic |
| :--- | :--- | :--- | :--- | :--- |
| **Rohan (Debtors)** | Asset | 1180 | 0 | Customer owes us money. |
| **Sales Account** | Income | 0 | 1000 | Revenue recognized. |
| **Output GST** | Liability | 0 | 180 | Tax collected (liability). |

*Note: Total Debit (1180) = Total Credit (1180).*

**Scenario**: Rohan pays ₹1180 by Cash.

| Ledger Name | Group | Debit | Credit | Logic |
| :--- | :--- | :--- | :--- | :--- |
| **Cash Account** | Asset | 1180 | 0 | Cash comes in. |
| **Rohan (Debtors)** | Asset | 0 | 1180 | Customer balance clears. |

---

## ✅ Implementation Checklist for Developers

1.  [ ] **Triggers/Functions**: Implement Cloud Functions to auto-create `ledger_entries` whenever a `transaction` is created/updated.
2.  [ ] **Validation**: Ensure `stock_ledger` never allows negative stock (unless configured).
3.  [ ] **Indexing**: Add composite indexes in Firestore for `{businessId, date}` and `{businessId, type, date}`.
4.  [ ] **Batch Writes**: Always use `batch.commit()` when saving a bill to ensure `transaction`, `items`, and `ledger_entries` are saved atomically.
