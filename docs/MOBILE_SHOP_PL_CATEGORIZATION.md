# Mobile Shop P&L Categorization Guide

## Overview
This document specifies how different transaction types should be categorized in the Profit & Loss (P&L) statement for Mobile Shop businesses.

---

## Transaction Categories

### 1. Sales Revenue

| Transaction Type | P&L Category | Treatment |
|----------------|--------------|-----------|
| **New Device Sales** | Revenue | Full sale amount (excluding GST) |
| **Accessory Sales** | Revenue | Full sale amount (excluding GST) |
| **Service/Repair Charges** | Service Revenue | Labor charges + parts markup |
| **Extended Warranty Sales** | Other Revenue | Warranty plan sales |

### 2. Cost of Goods Sold (COGS)

| Transaction Type | P&L Category | Treatment |
|----------------|--------------|-----------|
| **Device Purchases** | COGS | Purchase price from supplier |
| **Accessory Purchases** | COGS | Purchase price from supplier |
| **Parts for Repair** | COGS - Service | Cost of parts used in repairs |
| **Freight Inward** | COGS Add-on | Shipping costs on purchases |

### 3. Buyback / Exchange (CRITICAL)

**Important: Buyback transactions are NOT sales revenue**

| Transaction Type | P&L Category | Treatment |
|----------------|--------------|-----------|
| **Old Device Buyback** | Inventory Acquisition | Record as purchase of used inventory |
| **Exchange Value Given** | COGS Offset | Reduces new sale revenue |
| **Old Device Resale** | Revenue (when sold) | Separate sale of used device |

#### Buyback Accounting Flow

```
1. Customer trades in old device (value: ₹5,000)
   → Inventory (Used Devices) increases by ₹5,000
   → Cash/Bank decreases by ₹5,000 (or reduces new sale amount)

2. New device sold for ₹25,000
   → Revenue: ₹25,000
   → Less: Exchange value: ₹5,000
   → Net Revenue: ₹20,000

3. Old device resold later for ₹6,000
   → Revenue: ₹6,000
   → COGS: ₹5,000 (original buyback value)
   → Gross Profit: ₹1,000
```

### 4. Warranty Claims

| Transaction Type | P&L Category | Treatment |
|----------------|--------------|-----------|
| **Warranty Repair Costs** | Operating Expense | Parts + labor for warranty repairs |
| **Supplier Reimbursement** | Other Income | Amount recovered from supplier |
| **Net Warranty Cost** | Expense | Total cost minus reimbursements |

#### Warranty Cost Allocation

```
Total Warranty Costs: ₹10,000
- Parts replaced: ₹6,000
- Labor charges: ₹2,000
- Overhead: ₹2,000

Less: Supplier Reimbursement: ₹7,000
Net Warranty Expense: ₹3,000
```

### 5. Service & Repair

| Transaction Type | P&L Category | Treatment |
|----------------|--------------|-----------|
| **Service Labor** | Service Revenue | Billed labor charges |
| **Service Parts** | COGS - Service | Cost of parts used |
| **Diagnostic Fees** | Service Revenue | Diagnostic charges |

### 6. Operating Expenses

| Category | Examples |
|----------|----------|
| **Salaries & Wages** | Staff salaries, technician wages |
| **Rent** | Shop rent, service center rent |
| **Utilities** | Electricity, internet, phone |
| **Marketing** | Advertising, promotions |
| **Insurance** | Shop insurance, transit insurance |
| **Depreciation** | Store equipment, tools |

---

## Report Queries

### Query: Net Sales (excluding buyback)

```sql
SELECT 
  SUM(bill.totalAmount - bill.gstAmount) as net_sales
FROM bills b
WHERE b.type = 'SALE'
  AND b.isExchange = false
  AND b.deletedAt IS NULL
  AND b.date BETWEEN :startDate AND :endDate
```

### Query: Buyback Inventory Acquisition

```sql
SELECT 
  SUM(e.exchangeValue) as buyback_acquisition
FROM exchanges e
WHERE e.status = 'COMPLETED'
  AND e.exchangeDate BETWEEN :startDate AND :endDate
```

### Query: Used Device Resale

```sql
SELECT 
  SUM(b.totalAmount - b.gstAmount) as used_device_sales
FROM bills b
JOIN i_m_e_i_serials imei ON b.id = imei.billId
WHERE imei.purchasePrice > 0  -- Acquired via buyback
  AND b.date BETWEEN :startDate AND :endDate
```

### Query: Warranty Costs

```sql
SELECT 
  SUM(wc.totalClaimCost) as total_warranty_costs,
  SUM(wc.reimbursementAmount) as total_reimbursements,
  SUM(wc.totalClaimCost - COALESCE(wc.reimbursementAmount, 0)) as net_warranty_cost
FROM warranty_claims wc
WHERE wc.status IN ('COMPLETED', 'CLOSED')
  AND wc.closedAt BETWEEN :startDate AND :endDate
```

---

## Key Metrics for Mobile Shop

### Gross Profit Calculation

```
Gross Profit = 
  (New Device Sales - COGS) +
  (Used Device Sales - Buyback Value) +
  (Service Revenue - Parts Cost) -
  Net Warranty Costs
```

### Important Ratios

| Metric | Formula | Target |
|--------|---------|--------|
| Gross Margin | (Gross Profit / Revenue) × 100 | > 15% |
| Warranty Cost % | (Warranty Costs / Device Sales) × 100 | < 3% |
| Buyback Turnover | Used Sales / Avg Buyback Inventory | > 6x/year |
| Service Margin | (Service Revenue - Parts) / Service Revenue | > 40% |

---

## Implementation Notes

### For Exchange Transactions

1. **Invoice Level**: Show both new device price and exchange value
2. **Accounting Entry**: 
   - Debit: Cash/Bank (net amount)
   - Debit: Buyback Inventory (exchange value)
   - Credit: Sales Revenue (full new device price)

3. **GST Treatment**: 
   - GST calculated on net amount after exchange
   - Exchange value is not taxable (it's a purchase)

### For Warranty Claims

1. Track separately from regular service jobs
2. Categorize costs: parts, labor, overhead
3. Record supplier reimbursements as they occur
4. Monthly warranty reserve provision (if applicable)

### For Buyback Inventory

1. Track individual devices by IMEI
2. Record buyback value as cost basis
3. Markup policy: typically 10-20% margin on resale
4. Age tracking for inventory > 30 days

---

## Verification Checklist

- [ ] Buyback value NOT included in sales revenue
- [ ] Exchange transactions show both gross and net amounts
- [ ] Warranty costs tracked separately from regular service
- [ ] Used device resale shows correct COGS (original buyback value)
- [ ] Supplier reimbursements reduce warranty expense
- [ ] GST calculated correctly on exchange transactions

---

*Document Version: 1.0*  
*Last Updated: May 2026*  
*Applies to: Mobile Shop vertical*
