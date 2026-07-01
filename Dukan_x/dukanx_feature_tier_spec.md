# DukanX — Rebalanced Feature Tier Specification

## Purpose
This document defines the **rebalanced feature distribution** across all plan tiers for DukanX.
Use this as the source of truth when implementing plan gating, upgrade prompts, or UI feature flags.

## Rebalancing Principles
- **Basic** → Daily operational survival only. No analytics, no compliance, no advanced inventory.
- **Pro** → Growth & insight tools. Reports, analytics, profitability. Owner starts making data-driven decisions.
- **Premium** → Compliance & control. GST filings, audit trail, role permissions, cloud backup.
- **Enterprise** → Scale tools. Multi-branch, API access, integrations, BI hub.

## Plan Pricing Reference

| Plan | Monthly | Yearly | Lifetime (One-time) |
|---|:---:|:---:|:---:|
| Basic | ₹249/mo | ₹2,499/yr | ₹4,999 |
| Pro | ₹499/mo | ₹4,999/yr | ₹9,999 |
| Premium | ₹999/mo | ₹9,999/yr | ₹19,999 |
| Enterprise | ₹1,999/mo | ₹19,999/yr | ₹39,999 |

## Legend
- ✅ Included in plan
- 🔒 Upgrade required
- ❌ Not available for this business type

---

## 1. Universal Features (All Business Types)

### Core Operations
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Create Invoice / Bill | ✅ | ✅ | ✅ | ✅ |
| Invoice list & search | ✅ | ✅ | ✅ | ✅ |
| Dashboard — daily snapshot | ✅ | ✅ | ✅ | ✅ |
| Revenue overview | ✅ | ✅ | ✅ | ✅ |
| Customer ledger / Khata | ✅ | ✅ | ✅ | ✅ |
| Expense tracker | ✅ | ✅ | ✅ | ✅ |
| GST billing & tax calculation | ✅ | ✅ | ✅ | ✅ |
| WhatsApp / PDF invoice share | ✅ | ✅ | ✅ | ✅ |
| Basic user roles (Owner/Staff) | ✅ | ✅ | ✅ | ✅ |
| Multi-language support (11 langs) | ✅ | ✅ | ✅ | ✅ |

### Reports & Analytics (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Advanced reports & analytics | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation report | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |

### Compliance & Control (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Advanced role permissions | 🔒 | 🔒 | ✅ | ✅ |
| Vendor PO automation | 🔒 | 🔒 | ✅ | ✅ |
| Aging reports (receivables / payables) | 🔒 | 🔒 | ✅ | ✅ |
| Audit trail & logs | 🔒 | 🔒 | ✅ | ✅ |
| Cloud backup & restore | 🔒 | 🔒 | ✅ | ✅ |
| GST compliance reports (GSTR-1/3B) | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Financial reconciliation engine | 🔒 | 🔒 | 🔒 | ✅ |
| Multi-branch / multi-location | 🔒 | 🔒 | 🔒 | ✅ |
| Centralized inventory sync | 🔒 | 🔒 | 🔒 | ✅ |
| API access (integrations) | 🔒 | 🔒 | 🔒 | ✅ |
| Hierarchical role control | 🔒 | 🔒 | 🔒 | ✅ |
| Advanced BI hub & analytics | 🔒 | 🔒 | 🔒 | ✅ |

---

## 2. Grocery Store / General Store
**Business Type Key:** `grocery`
**Best for:** Kirana shops, daily essentials, FMCG retail, supermarkets

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Fast POS billing (MRP-based) | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner (USB/Bluetooth) | ✅ | ✅ | ✅ | ✅ |
| Item category management | ✅ | ✅ | ✅ | ✅ |
| Multiple units (Kg / Pcs / Ltr) | ✅ | ✅ | ✅ | ✅ |
| Discount per item | ✅ | ✅ | ✅ | ✅ |
| GST (optional, editable per item) | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list & search | ✅ | ✅ | ✅ | ✅ |
| Visible stock tracking | ✅ | ✅ | ✅ | ✅ |
| Low stock alerts | ✅ | ✅ | ✅ | ✅ |
| Dead stock report | ✅ | ✅ | ✅ | ✅ |
| Stock entry (purchase) | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Batch & expiry tracking | 🔒 | ✅ | ✅ | ✅ |
| Purchase order to supplier | 🔒 | ✅ | ✅ | ✅ |
| Supplier bill management | 🔒 | ✅ | ✅ | ✅ |
| OCR smart import (photo/CSV) | 🔒 | ✅ | ✅ | ✅ |
| Voice input billing | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation report | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Purchase register | 🔒 | 🔒 | ✅ | ✅ |
| Stock reversal | 🔒 | 🔒 | ✅ | ✅ |
| Inventory export (CSV/Excel) | 🔒 | 🔒 | ✅ | ✅ |
| GST reports (GSTR-1/3B) | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch inventory | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small kirana / single-counter shop
- Pro → Growing retail store with batch tracking & supplier orders
- Premium → Multi-staff store needing GST compliance
- Enterprise → Chain stores / supermarkets

---

## 3. Medical / Pharmacy
**Business Type Key:** `pharmacy`
**Best for:** Medicine shops, drug stores, medical distributors, chemists

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Medicine billing (MRP + schedule) | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner | ✅ | ✅ | ✅ | ✅ |
| Drug schedule classification (H/H1/X) | ✅ | ✅ | ✅ | ✅ |
| GST per item (item-wise rate) | ✅ | ✅ | ✅ | ✅ |
| Prescription linking | ✅ | ✅ | ✅ | ✅ |
| Doctor linking per bill | ✅ | ✅ | ✅ | ✅ |
| Patient registry | ✅ | ✅ | ✅ | ✅ |
| Salt / composition search | ✅ | ✅ | ✅ | ✅ |
| Sales return | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list | ✅ | ✅ | ✅ | ✅ |
| Low stock & expiry alerts | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Batch number & expiry date tracking | 🔒 | ✅ | ✅ | ✅ |
| Purchase order & supplier bill | 🔒 | ✅ | ✅ | ✅ |
| Purchase register | 🔒 | ✅ | ✅ | ✅ |
| Stock reversal | 🔒 | ✅ | ✅ | ✅ |
| OCR smart import | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Narcotic register (Schedule X) | 🔒 | 🔒 | ✅ | ✅ |
| H1 register / Schedule H1 register | 🔒 | 🔒 | ✅ | ✅ |
| GST reports (GSTR-1/3B) | 🔒 | 🔒 | ✅ | ✅ |
| Aging reports (supplier payables) | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch sync | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small standalone pharmacy
- Pro → Growing pharmacy with batch tracking & supplier management
- Premium → Licensed pharmacy needing narcotic/H1 compliance registers
- Enterprise → Pharmacy chain / wholesale distributor

---

## 4. Restaurant / Hotel
**Business Type Key:** `restaurant`
**Best for:** Restaurants, cloud kitchens, dhabas, QSR, cafes, hotels

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| KOT (Kitchen Order Ticket) | ✅ | ✅ | ✅ | ✅ |
| Table management | ✅ | ✅ | ✅ | ✅ |
| Dine-in / Takeaway / Parcel | ✅ | ✅ | ✅ | ✅ |
| Half-plate / Full-plate support | ✅ | ✅ | ✅ | ✅ |
| GST @ 5% (Fixed, No ITC) | ✅ | ✅ | ✅ | ✅ |
| Menu with images | ✅ | ✅ | ✅ | ✅ |
| Item variants (size / spice level) | ✅ | ✅ | ✅ | ✅ |
| Waiter linking per order | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list & raw material | ✅ | ✅ | ✅ | ✅ |
| Low stock alert (kitchen stock) | ✅ | ✅ | ✅ | ✅ |
| Purchase order | ✅ | ✅ | ✅ | ✅ |
| Supplier bill | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Kitchen Display System (KDS) | 🔒 | ✅ | ✅ | ✅ |
| Dish-wise profitability | 🔒 | ✅ | ✅ | ✅ |
| Sales by category / waiter report | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory export | 🔒 | 🔒 | ✅ | ✅ |
| GST reports | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-outlet management | 🔒 | 🔒 | 🔒 | ✅ |
| Online order integration (Swiggy/Zomato) | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Single-outlet restaurant / dhaba
- Pro → Restaurant needing KDS, dish profitability & waiter reports
- Premium → Full-service restaurant with GST compliance
- Enterprise → Restaurant chain / multi-outlet food business

---

## 5. Clothing / Fashion
**Business Type Key:** `clothing`
**Best for:** Garment shops, boutiques, fashion retail, footwear stores

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| POS billing | ✅ | ✅ | ✅ | ✅ |
| Size & color variant tracking | ✅ | ✅ | ✅ | ✅ |
| Discount per item | ✅ | ✅ | ✅ | ✅ |
| GST (5%/12% based on value) | ✅ | ✅ | ✅ | ✅ |
| Item images | ✅ | ✅ | ✅ | ✅ |
| Tailoring notes per bill | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner | ✅ | ✅ | ✅ | ✅ |
| Variant-wise stock (size/color) | ✅ | ✅ | ✅ | ✅ |
| Sales return | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list & search | ✅ | ✅ | ✅ | ✅ |
| Purchase order | ✅ | ✅ | ✅ | ✅ |
| Supplier bill | ✅ | ✅ | ✅ | ✅ |
| Daily snapshot & revenue | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| OCR smart import (stock entry) | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing (variant-wise) | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation | 🔒 | ✅ | ✅ | ✅ |
| Season / collection analytics | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| GST reports | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small boutique / single garment counter
- Pro → Fashion store with barcode scanning, season analytics & returns
- Premium → Multi-staff store with full GST compliance
- Enterprise → Clothing chain / franchise outlets

---

## 6. Electronics / Mobile Shop
**Business Type Keys:** `electronics`, `mobileShop`
**Best for:** Mobile phone retailers, gadget stores, electronics dealers, phone repair shops

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| POS billing with IMEI per unit | ✅ | ✅ | ✅ | ✅ |
| Warranty period capture | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner | ✅ | ✅ | ✅ | ✅ |
| Brand & model tracking | ✅ | ✅ | ✅ | ✅ |
| GST @ 18% (fixed) | ✅ | ✅ | ✅ | ✅ |
| IMEI validation (Luhn algorithm) | ✅ | ✅ | ✅ | ✅ |
| Buyback / exchange | ✅ | ✅ | ✅ | ✅ |
| Repair job sheet | ✅ | ✅ | ✅ | ✅ |
| Repair status tracking | ✅ | ✅ | ✅ | ✅ |
| Color variant per model | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list & search | ✅ | ✅ | ✅ | ✅ |
| Low stock alert | ✅ | ✅ | ✅ | ✅ |
| Purchase order | ✅ | ✅ | ✅ | ✅ |
| Supplier bill | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| IMEI-wise sales audit | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| HSN-wise GST report | 🔒 | 🔒 | ✅ | ✅ |
| Aging reports (receivables) | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch / service centers | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Single counter mobile shop
- Pro → Shop with repairs, buyback & IMEI audit
- Premium → Full compliance with HSN-based GST reports
- Enterprise → Mobile shop chain / authorized service centers

---

## 7. Computer Shop / IT Store
**Business Type Key:** `computerShop`
**Best for:** Computer dealers, laptop stores, IT hardware suppliers, AMC service providers

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| POS billing | ✅ | ✅ | ✅ | ✅ |
| Serial number tracking | ✅ | ✅ | ✅ | ✅ |
| Warranty management | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner | ✅ | ✅ | ✅ | ✅ |
| Spec notes (RAM/Storage per item) | ✅ | ✅ | ✅ | ✅ |
| GST @ 18% | ✅ | ✅ | ✅ | ✅ |
| Custom build / assembly job sheet | ✅ | ✅ | ✅ | ✅ |
| Repair job sheet | ✅ | ✅ | ✅ | ✅ |
| Repair status tracking | ✅ | ✅ | ✅ | ✅ |
| Multi-unit parts (Pcs / Set) | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list & search | ✅ | ✅ | ✅ | ✅ |
| Low stock alert | ✅ | ✅ | ✅ | ✅ |
| Purchase order | ✅ | ✅ | ✅ | ✅ |
| Supplier bill | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Stock valuation | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |
| AMC contract tracking | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| HSN-wise GST report | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch / service centers | 🔒 | 🔒 | 🔒 | ✅ |
| API integration (ERP) | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small IT shop / single counter
- Pro → Store with AMC contracts & repair tracking
- Premium → Full GST compliance with HSN reports
- Enterprise → IT chain / enterprise service provider

---

## 8. Hardware Store
**Business Type Key:** `hardware`
**Best for:** Hardware shops, building material stores, tools & equipment dealers

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| POS billing | ✅ | ✅ | ✅ | ✅ |
| Multiple units (Pcs / Kg / Meter / Box) | ✅ | ✅ | ✅ | ✅ |
| Discount per item | ✅ | ✅ | ✅ | ✅ |
| GST @ 18% (fixed) | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner | ✅ | ✅ | ✅ | ✅ |
| Credit sale / khata per party | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list & search | ✅ | ✅ | ✅ | ✅ |
| Low stock alert | ✅ | ✅ | ✅ | ✅ |
| Stock entry (purchase) | ✅ | ✅ | ✅ | ✅ |
| Dead stock report | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Purchase order to supplier | 🔒 | ✅ | ✅ | ✅ |
| Supplier bill management | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation report | 🔒 | ✅ | ✅ | ✅ |
| Part compatibility lookup | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Purchase register | 🔒 | 🔒 | ✅ | ✅ |
| Stock reversal | 🔒 | 🔒 | ✅ | ✅ |
| Inventory export (CSV/Excel) | 🔒 | 🔒 | ✅ | ✅ |
| GST reports (GSTR-1/3B) | 🔒 | 🔒 | ✅ | ✅ |
| Aging reports (receivables) | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch inventory | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small hardware shop / single counter
- Pro → Growing hardware store with supplier management
- Premium → Multi-staff store needing GST compliance
- Enterprise → Hardware chain / building material group

---

## 9. Service Business
**Business Type Key:** `service`
**Best for:** Salons, repair shops, electricians, plumbers, consultants, AC service
**Note:** No product inventory module — service-only billing.

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Service invoice | ✅ | ✅ | ✅ | ✅ |
| Labor charges per job | ✅ | ✅ | ✅ | ✅ |
| Parts charges (if any) | ✅ | ✅ | ✅ | ✅ |
| GST @ 18% | ✅ | ✅ | ✅ | ✅ |
| Job sheet creation | ✅ | ✅ | ✅ | ✅ |
| Service status tracking | ✅ | ✅ | ✅ | ✅ |
| Appointment scheduling | ✅ | ✅ | ✅ | ✅ |
| Customer service history | ✅ | ✅ | ✅ | ✅ |
| Daily snapshot & revenue | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Advanced revenue reports | 🔒 | ✅ | ✅ | ✅ |
| Recurring invoices | 🔒 | ✅ | ✅ | ✅ |
| Technician performance reports | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| GST reports | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch / service centers | 🔒 | 🔒 | 🔒 | ✅ |

### Not Available (Service Business)
- ❌ Product inventory
- ❌ Stock management
- ❌ Purchase orders
- ❌ Barcode scanning

**Recommended Plans:**
- Basic → Freelancer / solo service provider
- Pro → Service shop with recurring billing & technician analytics
- Premium → Multi-technician service center with GST reports
- Enterprise → Service chain / franchise (multi-location)

---

## 10. Wholesale / Distributor / B2B
**Business Type Key:** `wholesale`
**Best for:** FMCG distributors, bulk traders, C&F agents, sub-distributors

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Wholesale invoice (full suite) | ✅ | ✅ | ✅ | ✅ |
| Proforma invoice | ✅ | ✅ | ✅ | ✅ |
| Dispatch / delivery note | ✅ | ✅ | ✅ | ✅ |
| Sales return | ✅ | ✅ | ✅ | ✅ |
| Multi-unit (Box / Pcs / Case) | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner | ✅ | ✅ | ✅ | ✅ |
| Transport details on invoice | ✅ | ✅ | ✅ | ✅ |
| Credit management (party-wise) | ✅ | ✅ | ✅ | ✅ |
| Credit limit per party | ✅ | ✅ | ✅ | ✅ |
| Dead stock report | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Batch & expiry tracking | 🔒 | ✅ | ✅ | ✅ |
| Purchase register | 🔒 | ✅ | ✅ | ✅ |
| Stock reversal | 🔒 | ✅ | ✅ | ✅ |
| Inventory export (CSV) | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |
| Margin / profitability analysis | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Aging reports (receivables) | 🔒 | 🔒 | ✅ | ✅ |
| GST reports (GSTR-1/GSTR-3B) | 🔒 | 🔒 | ✅ | ✅ |
| Vendor PO automation | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch inventory | 🔒 | 🔒 | 🔒 | ✅ |
| API integration (ERP/Tally) | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small distributor / trader
- Pro → Distributor needing profitability & stock analytics
- Premium → Full B2B with GST compliance & aging reports *(Most Popular)*
- Enterprise → Large distributor / C&F agent with multi-location

---

## 11. Petrol Pump / Fuel Station
**Business Type Key:** `petrolPump`
**Best for:** Petrol pumps, CNG/LPG stations, fuel depots

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Fuel sale billing (Petrol/Diesel/CNG) | ✅ | ✅ | ✅ | ✅ |
| Nozzle-wise sales | ✅ | ✅ | ✅ | ✅ |
| Vehicle number capture | ✅ | ✅ | ✅ | ✅ |
| GST on fuel | ✅ | ✅ | ✅ | ✅ |
| Pump / nozzle reading entry | ✅ | ✅ | ✅ | ✅ |
| Shift management (Day/Night) | ✅ | ✅ | ✅ | ✅ |
| Tanker / fuel receipt entry | ✅ | ✅ | ✅ | ✅ |
| Fuel stock management | ✅ | ✅ | ✅ | ✅ |
| Vehicle-wise account (Fleet) | ✅ | ✅ | ✅ | ✅ |
| Low stock / low fuel alert | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Shift-wise profitability report | 🔒 | ✅ | ✅ | ✅ |
| Nozzle-wise performance analytics | 🔒 | ✅ | ✅ | ✅ |
| Fleet credit management | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| GST reports | 🔒 | 🔒 | ✅ | ✅ |
| DU calibration logs | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-pump outlet management | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Single petrol pump / small fuel station
- Pro → Pump with fleet customers & shift analytics
- Premium → Full compliance with GST & DU calibration logs
- Enterprise → Multi-pump group / fuel distribution company

---

## 12. Vegetable Broker / Mandi Agent
**Business Type Key:** `vegetablesBroker`
**Best for:** Mandi commission agents, vegetable brokers, APMC traders, fruit & veg wholesalers

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Mandi bill (weight-based) | ✅ | ✅ | ✅ | ✅ |
| Gross / Net / Tare weight entry | ✅ | ✅ | ✅ | ✅ |
| Rate per Kg / Crate | ✅ | ✅ | ✅ | ✅ |
| GST exempt (agricultural produce) | ✅ | ✅ | ✅ | ✅ |
| Commission calculation | ✅ | ✅ | ✅ | ✅ |
| Crate management (Issue / Return) | ✅ | ✅ | ✅ | ✅ |
| Farmer linking per lot | ✅ | ✅ | ✅ | ✅ |
| Buyer linking per lot | ✅ | ✅ | ✅ | ✅ |
| Daily market rate entry | ✅ | ✅ | ✅ | ✅ |
| Credit management (party) | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Commodity-wise profitability | 🔒 | ✅ | ✅ | ✅ |
| Farmer-wise transaction history | 🔒 | ✅ | ✅ | ✅ |
| Market fee / APMC levy tracking | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Lot-wise auction report | 🔒 | 🔒 | ✅ | ✅ |
| Seasonal analytics | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-location mandi | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small commission agent / single mandi
- Pro → Active broker needing farmer/commodity analytics
- Premium → Full APMC levy tracking & auction reports
- Enterprise → Multi-mandi operations / large trading house

---

## 13. Doctor Clinic / OPD
**Business Type Key:** `clinic`
**Best for:** General physicians, specialist clinics, OPD practices, diagnostic centers
**Note:** No product inventory — clinical billing & patient management only.

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Consultation fee billing | ✅ | ✅ | ✅ | ✅ |
| Procedure billing | ✅ | ✅ | ✅ | ✅ |
| Invoice list & search | ✅ | ✅ | ✅ | ✅ |
| Patient registry | ✅ | ✅ | ✅ | ✅ |
| Appointment scheduling | ✅ | ✅ | ✅ | ✅ |
| Prescription generation | ✅ | ✅ | ✅ | ✅ |
| Doctor linking | ✅ | ✅ | ✅ | ✅ |
| Daily revenue overview | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Doctor revenue analytics | 🔒 | ✅ | ✅ | ✅ |
| Patient visit history | 🔒 | ✅ | ✅ | ✅ |
| Referral tracking | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| GST reports | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-doctor / multi-specialty | 🔒 | 🔒 | 🔒 | ✅ |

### Not Available (Clinic)
- ❌ Product inventory
- ❌ Stock management
- ❌ Purchase orders
- ❌ Barcode scanning

**Recommended Plans:**
- Basic → Solo doctor / single OPD
- Pro → Clinic with multiple doctors & analytics
- Premium → Multi-specialty clinic with GST compliance
- Enterprise → Hospital / multi-branch clinic group

---

## 14. Book Store / Stationery
**Business Type Key:** `bookStore`
**Best for:** Bookshops, educational publishers, stationery stores, library suppliers

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Book sale billing (ISBN-based) | ✅ | ✅ | ✅ | ✅ |
| Barcode / ISBN scanner | ✅ | ✅ | ✅ | ✅ |
| Author / publisher fields | ✅ | ✅ | ✅ | ✅ |
| Discount per item | ✅ | ✅ | ✅ | ✅ |
| GST exempt (books in India) | ✅ | ✅ | ✅ | ✅ |
| ISBN lookup & auto-fill | ✅ | ✅ | ✅ | ✅ |
| Sales return / publisher return | ✅ | ✅ | ✅ | ✅ |
| Loyalty points system | ✅ | ✅ | ✅ | ✅ |
| Dead stock report | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Full inventory suite | ✅ | ✅ | ✅ | ✅ |
| Low stock alert | ✅ | ✅ | ✅ | ✅ |
| Purchase order & supplier bill | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| OCR smart import | 🔒 | ✅ | ✅ | ✅ |
| Stock valuation | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |
| Title / subject analytics | 🔒 | ✅ | ✅ | ✅ |
| Purchase register | 🔒 | ✅ | ✅ | ✅ |
| Inventory export (CSV) | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| GST reports (stationery items) | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small neighbourhood bookshop
- Pro → Bookstore with loyalty program & title analytics
- Premium → Educational publisher / stationery distributor with GST
- Enterprise → Book chain / multi-location educational store

---

## 15. Jewellery Store
**Business Type Key:** `jewellery`
**Best for:** Gold/silver jewellers, gem stores, hallmarking centers, ornament retailers

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Ornament billing (weight-based) | ✅ | ✅ | ✅ | ✅ |
| Rate per gram (Gold / Silver) | ✅ | ✅ | ✅ | ✅ |
| Making charges | ✅ | ✅ | ✅ | ✅ |
| Purity / carat tracking | ✅ | ✅ | ✅ | ✅ |
| GST @ 3% (fixed) | ✅ | ✅ | ✅ | ✅ |
| Hallmark number | ✅ | ✅ | ✅ | ✅ |
| Old gold / exchange entry | ✅ | ✅ | ✅ | ✅ |
| Repair / karigar job sheet | ✅ | ✅ | ✅ | ✅ |
| Barcode (tag-wise) | ✅ | ✅ | ✅ | ✅ |
| Item image catalogue | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Customer KYC (Aadhaar/PAN) | 🔒 | ✅ | ✅ | ✅ |
| Live gold rate API integration | 🔒 | ✅ | ✅ | ✅ |
| Metal-wise stock valuation | 🔒 | ✅ | ✅ | ✅ |
| Karigar-wise profitability | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| GST reports (GSTR-1) | 🔒 | 🔒 | ✅ | ✅ |
| High-value transaction reporting | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch showroom | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small jewellery shop / single counter
- Pro → Jeweller with live gold rate & karigar analytics
- Premium → Jeweller needing GSTR-1 & high-value compliance *(Recommended)*
- Enterprise → Multi-showroom jewellery group

---

## 16. Auto Parts / Garage
**Business Type Key:** `autoParts`
**Best for:** Auto parts dealers, garages, vehicle service centers, tyre shops

### Core Billing
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Parts + labor bill | ✅ | ✅ | ✅ | ✅ |
| Vehicle number on bill | ✅ | ✅ | ✅ | ✅ |
| Brand & part number | ✅ | ✅ | ✅ | ✅ |
| GST @ 28% (auto parts) | ✅ | ✅ | ✅ | ✅ |
| Barcode scanner | ✅ | ✅ | ✅ | ✅ |
| Repair job sheet | ✅ | ✅ | ✅ | ✅ |
| Repair status tracking | ✅ | ✅ | ✅ | ✅ |
| Warranty on parts | ✅ | ✅ | ✅ | ✅ |
| Vehicle compatibility lookup | ✅ | ✅ | ✅ | ✅ |
| Service history per vehicle | ✅ | ✅ | ✅ | ✅ |

### Inventory — Basic
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Inventory list & search | ✅ | ✅ | ✅ | ✅ |
| Low stock alert | ✅ | ✅ | ✅ | ✅ |
| Purchase order | ✅ | ✅ | ✅ | ✅ |
| Supplier bill | ✅ | ✅ | ✅ | ✅ |

### Growth Tools (Pro+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Stock valuation | 🔒 | ✅ | ✅ | ✅ |
| Barcode label printing | 🔒 | ✅ | ✅ | ✅ |
| Vehicle-wise revenue report | 🔒 | ✅ | ✅ | ✅ |

### Compliance (Premium+)
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Mechanic performance reports | 🔒 | 🔒 | ✅ | ✅ |
| GST reports | 🔒 | 🔒 | ✅ | ✅ |

### Enterprise Scale
| Feature | Basic | Pro | Premium | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Multi-branch garages | 🔒 | 🔒 | 🔒 | ✅ |

**Recommended Plans:**
- Basic → Small garage / single-counter parts shop
- Pro → Auto parts shop with vehicle-wise analytics
- Premium → Full-service garage with mechanic reports & GST
- Enterprise → Multi-branch garage chain / authorized service center

---

## Summary: Business Type to Key Mapping

| # | Business Type | Business Type Key |
|---|---|---|
| 1 | Grocery Store / General Store | `grocery` |
| 2 | Medical / Pharmacy | `pharmacy` |
| 3 | Restaurant / Hotel | `restaurant` |
| 4 | Clothing / Fashion | `clothing` |
| 5 | Electronics / Mobile Shop | `electronics`, `mobileShop` |
| 6 | Computer Shop / IT Store | `computerShop` |
| 7 | Hardware Store | `hardware` |
| 8 | Service Business | `service` |
| 9 | Wholesale / Distributor / B2B | `wholesale` |
| 10 | Petrol Pump / Fuel Station | `petrolPump` |
| 11 | Vegetable Broker / Mandi Agent | `vegetablesBroker` |
| 12 | Doctor Clinic / OPD | `clinic` |
| 13 | Book Store / Stationery | `bookStore` |
| 14 | Jewellery Store | `jewellery` |
| 15 | Auto Parts / Garage | `autoParts` |

---

## Implementation Notes for AI Agent

1. **Feature gating logic:** Check `plan >= requiredPlan` where Basic=1, Pro=2, Premium=3, Enterprise=4.
2. **Universal features apply to all business types** — always evaluate universal table first, then overlay business-type-specific table.
3. **Business types with no inventory** (`service`, `clinic`) — suppress all inventory-related UI elements entirely regardless of plan.
4. **Upgrade prompt trigger:** When a locked feature is accessed, show upgrade CTA with the minimum plan required.
5. **Lifetime plan for ofline activation contact to team buyers** — apply feature gates based on the plan tier purchased; do not grant higher-tier features automatically. it must base on super admin ok dont include it in subcription module
6. **Cloud Backup** is Premium+, not Enterprise — a common error to avoid when implementing gating.
7. **Audit Trail & Logs** is Premium+, not Enterprise — same as above.
8. **GST Reports** are Premium+ across all business types — no exceptions.
9. **Multi-branch / multi-location** is always Enterprise — no exceptions across any business type.
10. **API Access** is always Enterprise — no exceptions.
