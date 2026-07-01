# DukanX – Features List by Business Type

> **Source of truth:** `lib/core/isolation/business_capability.dart`
> Generated from the `businessCapabilityRegistry` map. Anything not listed here is
> **STRICTLY FORBIDDEN** for that business type (Hard Isolation rule).

Legend: ✅ = enabled · ❌ = not available (hard-isolated)

---

## Quick Summary (count per type)

| # | Business Type              | Registry key         | Features |
|---|----------------------------|----------------------|----------|
| 1 | Grocery Store              | `grocery`            | 24 |
| 2 | Pharmacy                   | `pharmacy`           | 28 |
| 3 | Restaurant / Hotel         | `restaurant`         | 21 |
| 4 | Clothing / Fashion         | `clothing`           | 18 |
| 5 | Electronics                | `electronics`        | 19 |
| 6 | Mobile Shop                | `mobileShop`         | 22 |
| 7 | Computer Shop              | `computerShop`       | 21 |
| 8 | Hardware Store             | `hardware`           | 20 |
| 9 | Service Business           | `service`            |  9 |
|10 | Wholesale / B2B            | `wholesale`          | 28 |
|11 | Petrol Pump                | `petrolPump`         | 22 |
|12 | Vegetable Broker           | `vegetablesBroker`   | 18 |
|13 | Doctor Clinic              | `clinic`             | 10 |
|14 | Book Store                 | `bookStore`          | 24 |
|15 | Jewellery                  | `jewellery`          | 14 |
|16 | Auto Parts                 | `autoParts`          | 23 |
|17 | Decoration & Catering      | `decorationCatering` | 21 |
|18 | School ERP / Coaching      | `schoolErp`          | 23 |
|19 | Other / General            | `other`              |  6 |

---

## 1. 🛒 Grocery Store (`grocery`)

**Product / Item Management**
- ✅ Add Product
- ✅ Item Name
- ✅ Sale Price
- ✅ Stock Quantity
- ✅ Unit
- ✅ Tax / GST
- ✅ Category

**Inventory**
- ✅ Inventory List
- ✅ Visible Stock
- ✅ Dead Stock
- ✅ Inventory Search
- ❌ Export CSV

**Invoice**
- ✅ Invoice List
- ✅ Invoice Search
- ✅ Create Invoice
- ❌ Sales Return
- ❌ Proforma
- ❌ Dispatch Note

**Alerts & Health**
- ✅ Low Stock Alert
- ✅ General Alerts
- ✅ Daily Snapshot
- ✅ Revenue Overview

**Purchase & Stock Flow**
- ✅ Purchase Order
- ✅ Stock Entry
- ❌ Stock Reversal
- ✅ Supplier Bill
- ❌ Purchase Register

**Specialized / Input**
- ✅ Barcode Scanner
- ✅ OCR Scan
- ✅ Stock Management
- ✅ Low Stock Alerts (legacy)
- ✅ Batch & Expiry
- ✅ Voice Input

---

## 2. 💊 Pharmacy (`pharmacy`)

**Product / Item Management** — all ✅ (Add, Name, Sale Price, Stock Qty, Unit, Tax, Category)

**Inventory**
- ✅ Inventory List, Visible Stock, Dead Stock, Search
- ❌ Export CSV

**Invoice**
- ✅ List, Search, Create
- ✅ Sales Return
- ❌ Proforma, Dispatch

**Alerts & Health** — all ✅ (Low Stock, General, Daily Snapshot, Revenue)

**Purchase & Stock Flow** — all ✅ (PO, Stock Entry, Reversal, Supplier Bill, Register)

**Specialized**
- ✅ Prescription
- ✅ Doctor Linking
- ✅ Patient Registry
- ✅ Drug Schedule (H / H1 / X)
- ✅ Salt Search
- ✅ Batch & Expiry
- ✅ Barcode Scanner
- ✅ OCR Scan
- ✅ Stock Management
- ✅ Low Stock Alerts

---

## 3. 🍽️ Restaurant / Hotel (`restaurant`)

**Product** — all ✅ (limited semantics handled in UI)

**Inventory**
- ✅ List, Visible Stock, Dead Stock, Search
- ❌ Export CSV

**Invoice**
- ✅ List, Search, Create
- ❌ Sales Return, Proforma, Dispatch

**Alerts & Health** — all ✅

**Purchase & Stock Flow**
- ✅ PO, Stock Entry, Supplier Bill
- ❌ Reversal, Register

**Specialized**
- ✅ KOT (Kitchen Order Ticket)
- ✅ Table Management
- ✅ Waiter Linking
- ✅ Kitchen Display
- ✅ Barcode Scanner (P1: packaged items — bottled drinks, snacks)

---

## 4. 👕 Clothing / Fashion (`clothing`)

**Product** — all ✅

**Inventory**
- ✅ List, Visible Stock, Search
- ❌ Dead Stock, Export

**Invoice**
- ✅ List, Search, Create
- ❌ Sales Return, Proforma, Dispatch

**Alerts & Health**
- ✅ Daily Snapshot, Revenue Overview
- ❌ Low Stock Alert, General Alerts

**Purchase & Stock Flow**
- ✅ PO, Stock Entry, Supplier Bill
- ❌ Reversal, Register

**Specialized**
- ✅ Variants (Size / Color)
- ✅ Tailoring Notes
- ✅ Barcode Scanner
- ✅ OCR Scan
- ✅ Stock Management

---

## 5. 📱 Electronics (`electronics`)

**Product** — all ✅

**Inventory** — List, Visible Stock, Search ✅ · Dead Stock & Export ❌

**Invoice** — List, Search, Create ✅ · Returns / Proforma / Dispatch ❌

**Alerts & Health** — Low Stock, Daily Snapshot, Revenue ✅ · General Alerts ❌

**Purchase & Stock Flow** — PO, Stock Entry, Supplier Bill ✅ · Reversal, Register ❌

**Specialized**
- ✅ IMEI Tracking
- ✅ Warranty
- ✅ Barcode Scanner
- ✅ OCR Scan
- ✅ Stock Management

---

## 6. 📲 Mobile Shop (`mobileShop`)

**Product** — all ✅

**Inventory** — List, Visible Stock, Search ✅

**Invoice** — List, Search, Create ✅

**Alerts** — Low Stock, Daily Snapshot, Revenue ✅

**Purchase** — PO, Stock Entry, Supplier Bill ✅

**Specialized**
- ✅ IMEI Tracking
- ✅ Warranty
- ✅ Buyback
- ✅ Exchange
- ✅ Job Sheets (Repairs)
- ✅ Repair Status
- ✅ Stock Management
- ✅ Barcode Scanner

---

## 7. 🖥️ Computer Shop (`computerShop`)

**Product** — all ✅

**Inventory** — List, Visible Stock, Search ✅

**Invoice** — List, Search, Create ✅

**Alerts** — Low Stock, Daily Snapshot, Revenue ✅

**Purchase** — PO, Stock Entry, Supplier Bill ✅

**Specialized**
- ✅ IMEI / Serial Tracking
- ✅ Warranty
- ✅ Job Sheets (Custom builds / Repairs)
- ✅ Repair Status
- ✅ Stock Management
- ✅ Barcode Scanner
- ✅ Multi-Unit (Parts)

---

## 8. 🔧 Hardware Store (`hardware`)

**Product** — all ✅

**Inventory** — List, Visible Stock, Search ✅ · Dead Stock, Export ❌

**Invoice** — List, Search, Create ✅ · Returns / Proforma / Dispatch ❌

**Alerts** — Low Stock, Daily Snapshot, Revenue ✅ · General Alerts ❌

**Purchase** — PO, Stock Entry, Supplier Bill ✅ · Reversal, Register ❌

**Specialized**
- ✅ Dimensions (Sq.ft / Mtr)
- ✅ Loose Quantities
- ✅ Barcode Scanner
- ✅ Stock Management
- ✅ Transport Details

---

## 9. 🛠️ Service Business (`service`)

> Service businesses **don't** sell items — they sell services / jobs.

**Product** — ❌ ALL DISABLED (Add, Name, Price, Stock, Unit, Tax, Category)

**Inventory** — ❌ ALL DISABLED

**Invoice**
- ✅ List, Search, Create
- ❌ Returns, Proforma, Dispatch

**Alerts & Health**
- ✅ Daily Snapshot, Revenue Overview
- ❌ Low Stock, General Alerts

**Purchase & Stock Flow** — ❌ ALL DISABLED

**Specialized**
- ✅ Job Sheets
- ✅ Service Status
- ✅ Labor Charges
- ✅ Appointments

---

## 10. 🏭 Wholesale / B2B (`wholesale`)

**Product** — all ✅

**Inventory** — all ✅ (List, Visible, Dead Stock, Search, **Export CSV**)

**Invoice** — all ✅ (List, Search, Create, **Sales Return**, **Proforma**, **Dispatch Note**)

**Alerts & Health** — all ✅

**Purchase & Stock Flow** — all ✅ (PO, Stock Entry, **Reversal**, Supplier Bill, **Register**)

**Specialized**
- ✅ Stock Management
- ✅ Multi-Unit (Box / Pcs)
- ✅ Credit Management
- ✅ Credit Limit
- ✅ Transport Details
- ✅ Barcode Scanner
- ✅ Batch & Expiry

---

## 11. ⛽ Petrol Pump (`petrolPump`)

**Product** — all ✅

**Inventory** — List, Visible Stock, Search ✅ · Dead Stock, Export ❌

**Invoice** — List, Search, Create ✅ · Returns, Proforma, Dispatch ❌

**Alerts** — Low Stock, Daily Snapshot, Revenue ✅ · General Alerts ❌

**Purchase** — PO, Stock Entry, Supplier Bill ✅ · Reversal, Register ❌

**Specialized**
- ✅ Fuel Management
- ✅ Pump Readings
- ✅ Shift Management
- ✅ Vehicle Details
- ✅ Tanker Entry
- ✅ Stock Management (fuel)
- ✅ Barcode Scanner (P2: convenience store items at pump)

---

## 12. 🥦 Vegetable Broker / Mandi (`vegetablesBroker`)

**Product** — Add, Name, Sale Price, Stock Qty, Unit, Category ✅ · Tax ❌

**Inventory** — List, Visible Stock, Search ✅ · Dead Stock, Export ❌

**Invoice** — List, Search, Create ✅ · Returns, Proforma, Dispatch ❌

**Alerts** — Low Stock, Daily Snapshot, Revenue ✅ · General Alerts ❌

**Purchase** — PO, Stock Entry, Supplier Bill ✅ · Reversal, Register ❌

**Specialized**
- ✅ Commission
- ✅ Crate Management
- ✅ Farmer Linking
- ✅ Daily Rates
- ✅ Credit Management

---

## 13. 🩺 Doctor Clinic / OPD (`clinic`)

> Clinics don't manage product inventory — billing & patient flow only.

**Product** — ❌ ALL DISABLED

**Inventory** — ❌ ALL DISABLED

**Invoice**
- ✅ List, Search, Create
- ❌ Returns, Proforma, Dispatch

**Alerts**
- ✅ Daily Snapshot, Revenue
- ❌ Low Stock, General Alerts

**Purchase & Stock Flow** — ❌ ALL DISABLED

**Specialized**
- ✅ Appointments
- ✅ Consultation Billing
- ✅ Patient Registry
- ✅ Prescription
- ✅ Doctor Linking

---

## 14. 📚 Book Store (`bookStore`)

**Product** — all ✅

**Inventory** — all ✅ (List, Visible, Dead Stock, Search, **Export CSV**)

**Invoice** — List, Search, Create, **Sales Return** ✅ · Proforma, Dispatch ❌

**Alerts** — all ✅ (Low Stock, General, Daily Snapshot, Revenue)

**Purchase** — PO, Stock Entry, Supplier Bill, **Register** ✅ · Reversal ❌

**Specialized**
- ✅ ISBN Tracking
- ✅ Publisher Returns
- ✅ Loyalty Points
- ✅ Barcode Scanner
- ✅ OCR Scan
- ✅ Stock Management
- ✅ Low Stock Alerts (legacy)

---

## 15. 💎 Jewellery (`jewellery`)

**Product** — Add, Name, Sale Price, Stock Qty, Category ✅ · Unit, Tax ❌

**Inventory** — List, Visible Stock, Search ✅

**Invoice** — List, Search, Create ✅

**Alerts** — Daily Snapshot, Revenue ✅ · Low Stock, General ❌

**Purchase & Stock Flow** — ❌ ALL DISABLED

**Specialized**
- ✅ Stock Management
- ✅ Barcode Scanner

---

## 16. 🚗 Auto Parts / Garage (`autoParts`)

**Product** — all ✅

**Inventory** — List, Visible Stock, Search ✅

**Invoice** — List, Search, Create ✅

**Alerts** — Low Stock, Daily Snapshot, Revenue ✅

**Purchase** — PO, Stock Entry, Supplier Bill ✅

**Specialized**
- ✅ Warranty
- ✅ Job Sheets
- ✅ Repair Status
- ✅ Stock Management
- ✅ Barcode Scanner

---

## 17. 🎊 Decoration & Catering (`decorationCatering`)

> Event-based businesses handling decoration setups, catering orders, and venue management.

**Product / Item Management**
- ✅ Add Product
- ✅ Item Name
- ✅ Sale Price
- ❌ Stock Quantity
- ❌ Unit
- ❌ Tax / GST
- ✅ Category

**Inventory**
- ✅ Inventory List
- ❌ Visible Stock
- ❌ Dead Stock
- ❌ Inventory Search
- ❌ Export CSV

> Note: Only top-level `useInventoryList` is enabled; `useVisibleStock` and `useInventorySearch` are excluded in registry.

**Invoice**
- ✅ Invoice List
- ✅ Invoice Search
- ✅ Create Invoice
- ❌ Sales Return
- ✅ Proforma Invoice
- ❌ Dispatch Note

**Alerts & Health**
- ❌ Low Stock Alert
- ✅ General Alerts
- ✅ Daily Snapshot
- ✅ Revenue Overview

**Purchase & Stock Flow**
- ❌ Purchase Order
- ❌ Stock Entry
- ❌ Stock Reversal
- ❌ Supplier Bill
- ❌ Purchase Register

**Specialized**
- ✅ Event Booking
- ✅ Decoration Themes
- ✅ Catering Menu
- ✅ Event Staff Allocation
- ✅ Venue Management
- ✅ Event Inventory
- ✅ Catering Kitchen
- ✅ Event Reports
- ✅ Appointments
- ✅ Labor Charges
- ✅ Stock Management

---

## 18. 🏫 School ERP / Coaching (`schoolErp`)

> Full school ERP, coaching centres, tuition classes, and training institutes — no physical product sales.

**Product / Item Management** — ❌ ALL DISABLED (sells courses/services, not products)

**Inventory** — ❌ ALL DISABLED

**Invoice (Fee Receipts)**
- ✅ Invoice List
- ✅ Invoice Search
- ✅ Create Invoice
- ❌ Sales Return
- ❌ Proforma
- ❌ Dispatch Note

**Alerts & Health**
- ❌ Low Stock Alert
- ✅ General Alerts
- ✅ Daily Snapshot
- ✅ Revenue Overview

**Purchase & Stock Flow** — ❌ ALL DISABLED

**Specialized**
- ✅ School ERP Mode (`schoolErp` flag)
- ✅ Student Registry
- ✅ Batch / Class Management
- ✅ Fee Collection & Billing
- ✅ Attendance Tracking
- ✅ Test / Exam Results
- ✅ Course Material
- ✅ Timetable / Schedule
- ✅ Staff / Teacher Management
- ✅ Parent Notifications / SMS
- ✅ Certificates & ID Cards
- ✅ Scholarship / Discount Management
- ✅ Demo / Trial Classes
- ✅ Appointments (demo scheduling)
- ✅ Class & Section Management
- ✅ Academic Year Management
- ✅ Report Cards
- ✅ Library Management
- ✅ Transport Management
- ✅ Class-wise Fee Structure
- ✅ Institution Type Config

---

## 19. 🏬 Other / General (`other`)

> Minimal safe defaults for unclassified businesses.

- ✅ Add Product
- ✅ Item Name
- ✅ Stock Management
- ✅ Barcode Scanner
- ✅ Create Invoice
- ✅ Invoice List
- ❌ Everything else

---

## Cross-Type Capability Matrix (key features only)

| Capability            | Grocery | Pharmacy | Restaurant | Clothing | Electronics | MobileShop | Computer | Hardware | Service | Wholesale | PetrolPump | Mandi | Clinic | BookStore | Jewellery | AutoParts | Deco/Cater | SchoolERP | Other |
|-----------------------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Add Product           | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Inventory List        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Dead Stock            | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Inventory Export CSV  | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Invoice Create        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Sales Return          | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Proforma Invoice      | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Dispatch Note         | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Low Stock Alert       | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| General Alerts        | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Daily Snapshot        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Revenue Overview      | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Purchase Order        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Stock Reversal        | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Purchase Register     | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Barcode Scanner       | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| Batch & Expiry        | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Multi-Unit            | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Credit Management     | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Transport Details     | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## Specialized-only Features (where they live)

| Feature                    | Found in                                             |
|----------------------------|------------------------------------------------------|
| Prescription               | Pharmacy, Clinic                                     |
| Doctor Linking             | Pharmacy, Clinic                                     |
| Patient Registry           | Pharmacy, Clinic                                     |
| Drug Schedule (H/H1/X)    | Pharmacy                                             |
| Salt Search                | Pharmacy                                             |
| KOT                        | Restaurant                                           |
| Table Management           | Restaurant                                           |
| Waiter Linking             | Restaurant                                           |
| Kitchen Display            | Restaurant                                           |
| Barcode Scanner (packaged) | Restaurant (P1), Petrol Pump (P2)                    |
| Variants (Size/Color)      | Clothing                                             |
| Tailoring Notes            | Clothing                                             |
| IMEI                       | Electronics, Mobile Shop, Computer Shop              |
| Warranty                   | Electronics, Mobile Shop, Computer Shop, Auto Parts  |
| Buyback                    | Mobile Shop                                          |
| Exchange                   | Mobile Shop                                          |
| Job Sheets                 | Mobile Shop, Computer Shop, Service, Auto Parts      |
| Repair Status              | Mobile Shop, Computer Shop, Auto Parts               |
| Service Status             | Service                                              |
| Labor Charges              | Service, Decoration & Catering                       |
| Appointments               | Service, Clinic, Decoration & Catering, School ERP   |
| Consultation Billing       | Clinic                                               |
| Dimensions                 | Hardware                                             |
| Loose Quantities           | Hardware                                             |
| Fuel Management            | Petrol Pump                                          |
| Pump Readings              | Petrol Pump                                          |
| Shift Management           | Petrol Pump                                          |
| Vehicle Details            | Petrol Pump                                          |
| Tanker Entry               | Petrol Pump                                          |
| Commission                 | Vegetable Broker                                     |
| Crate Management           | Vegetable Broker                                     |
| Farmer Linking             | Vegetable Broker                                     |
| Daily Rates                | Vegetable Broker                                     |
| ISBN                       | Book Store                                           |
| Publisher Returns          | Book Store                                           |
| Loyalty Points             | Book Store                                           |
| Credit Limit               | Wholesale                                            |
| Event Booking              | Decoration & Catering                                |
| Decoration Themes          | Decoration & Catering                                |
| Catering Menu              | Decoration & Catering                                |
| Event Staff Allocation     | Decoration & Catering                                |
| Venue Management           | Decoration & Catering                                |
| Event Inventory            | Decoration & Catering                                |
| Catering Kitchen           | Decoration & Catering                                |
| Event Reports              | Decoration & Catering                                |
| School ERP Mode            | School ERP / Coaching                                |
| Student Registry           | School ERP / Coaching                                |
| Batch / Class Management   | School ERP / Coaching                                |
| Fee Collection & Billing   | School ERP / Coaching                                |
| Attendance Tracking        | School ERP / Coaching                                |
| Test / Exam Results        | School ERP / Coaching                                |
| Course Material            | School ERP / Coaching                                |
| Timetable / Schedule       | School ERP / Coaching                                |
| Staff / Teacher Mgmt       | School ERP / Coaching                                |
| Parent Notifications / SMS | School ERP / Coaching                                |
| Certificates & ID Cards    | School ERP / Coaching                                |
| Scholarship / Discount     | School ERP / Coaching                                |
| Demo / Trial Classes       | School ERP / Coaching                                |
| Class & Section Mgmt       | School ERP / Coaching                                |
| Academic Year Management   | School ERP / Coaching                                |
| Report Cards               | School ERP / Coaching                                |
| Library Management         | School ERP / Coaching                                |
| Transport Management       | School ERP / Coaching                                |
| Class-wise Fee Structure   | School ERP / Coaching                                |
| Institution Type Config    | School ERP / Coaching                                |

---

_Maintain this file in sync with `lib/core/isolation/business_capability.dart`._
_When adding a new capability, append to the enum, register it under the relevant business types, then update this document._
