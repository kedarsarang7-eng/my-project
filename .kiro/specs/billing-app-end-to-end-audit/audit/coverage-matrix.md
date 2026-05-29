# Audit Coverage Matrix

> Track A deliverable for spec `billing-app-end-to-end-audit`, satisfying
> `bugfix.md` clause **2.17**.
>
> One row per `(app, module, screen, workflow)`. Sources of truth:
>
> - `Dukan_x/lib/modules/<m>/routes/*_routes.dart` — declared routes.
> - `Dukan_x/lib/features/<m>/presentation/screens/*.dart` — concrete screens.
> - `school_*/lib/core/router/app_router.dart` — routes for the three school apps.
>
> Status legend:
>
> - **Audited** — screen / workflow exists in F and was inspected statically
>   for D1..D11 in Task 1.
> - **Audited (placeholder route)** — route is registered but resolves to
>   `ModulePlaceholderScreen` ("Coming soon"). Inspected and recorded as a
>   D1 / D2 defect in `defect-inventory.md`.
> - **Audited (no screen)** — module folder has no presentation screens at
>   all in `lib/features/<m>/presentation/screens/`. The route table is the
>   only entry point. Recorded as D2 / D11.
> - **Not-Applicable** — workflow does not apply to this app or module
>   (e.g., shift-handover does not exist outside `petrol_pump`; admissions
>   does not exist in `school_student_app`). Reason given inline.

## Summary

| App                   | Modules / feature areas covered                                                                                                                             | Total rows |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| `Dukan_x`             | 17 business-type modules + 9 shared feature areas                                                                                                           | 217        |
| `school_admin_app`    | 16 feature areas                                                                                                                                            | 16         |
| `school_teacher_app`  | 13 feature areas                                                                                                                                            | 13         |
| `school_student_app`  | 15 feature areas                                                                                                                                            | 15         |
| **Total**             |                                                                                                                                                             | **261**    |

---

## Dukan_x — business-type modules

### auto_parts

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/auto-parts/billing` (route)                   | Auto-parts billing entry            | Audited (placeholder route)  | Routes to `ModulePlaceholderScreen`. See AP-001.   |
| `/auto-parts/inventory` (route)                 | Parts inventory                     | Audited (placeholder route)  | Routes to `ModulePlaceholderScreen`. See AP-002.   |
| `/auto-parts/jobcards` (route)                  | Job-card list                       | Audited (placeholder route)  | Route placeholder; real screen exists at `features/auto_parts/presentation/screens/job_card_management_screen.dart` but not wired to route. See AP-003. |
| `/auto-parts/vehicle` (route)                   | Vehicle lookup                      | Audited (placeholder route)  | Routes to `ModulePlaceholderScreen`. See AP-004.   |
| `job_card_management_screen.dart` (feature)     | Job-card CRUD lifecycle             | Audited                      | Wired internally; see AP-101.                      |

### billing (shared)

| Screen                                            | Workflow                              | Status   | Notes                                              |
| ------------------------------------------------- | ------------------------------------- | -------- | -------------------------------------------------- |
| `advanced_billing_screen.dart`                    | Advanced bill list                    | Audited  |                                                    |
| `advanced_bill_creation_screen.dart`              | Advanced bill creation                | Audited  | See BL-101 (GST half-split rounding).              |
| `bill_creation_screen_v2.dart`                    | Bill creation v2                      | Audited  | See BL-102 (manual item entry GST split).          |
| `billing_reports_screen.dart`                     | Billing reports                       | Audited  |                                                    |
| `bill_scan_screen.dart`                           | Scan bill OCR entry                   | Audited  |                                                    |
| `bill_search_screen.dart`                         | Search bills                          | Audited  |                                                    |
| `create_invoice_screen.dart`                      | Create invoice                        | Audited  |                                                    |
| `credit_note_screen.dart`                         | Credit note                           | Audited  |                                                    |
| `desktop_invoices_screen.dart`                    | Desktop invoices list                 | Audited  |                                                    |
| `editable_invoice_screen.dart`                    | Edit invoice                          | Audited  |                                                    |
| `edit_bill_screen.dart`                           | Edit bill                             | Audited  |                                                    |
| `invoice_preview_screen.dart`                     | Preview invoice                       | Audited  |                                                    |
| `owner_bill_list_screen.dart`                     | Owner bill list                       | Audited  |                                                    |
| `return_bill_screen.dart`                         | Return bill                           | Audited  |                                                    |
| `total_bills_screen.dart`                         | Aggregate bill totals                 | Audited  |                                                    |
| `bills_list_screen.dart`                          | Bills list                            | Audited  |                                                    |
| `dunning_config_screen.dart`                      | Dunning rules config                  | Audited  |                                                    |
| `manage_subscriptions_screen.dart`                | Manage subscriptions                  | Audited  |                                                    |
| `manual_item_entry_sheet.dart`                    | Manual item entry (GST/CGST/SGST)     | Audited  | See BL-103 (floating-point GST math).              |
| `bill_line_item_row.dart`                         | Bill line-item edit                   | Audited  | See BL-104 (CGST/SGST half-split rounding).        |

### book_store

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/books/billing` (route)                        | Book billing                        | Audited (placeholder route)  | Routes to `ModulePlaceholderScreen`. See BK-001.   |
| `/books/inventory` (route)                      | Book inventory                      | Audited (placeholder route)  | Routes to `ModulePlaceholderScreen`. See BK-002.   |
| `/books/consignment` (route)                    | Consignment                         | Audited (placeholder route)  | Real screen `consignment_settlement_screen.dart` exists but not wired. See BK-003. |
| `/books/institutions` (route)                   | Institutions                        | Audited (placeholder route)  | See BK-004.                                        |
| `/books/used` (route)                           | Used books                          | Audited (placeholder route)  | See BK-005.                                        |
| `book_inventory_screen.dart`                    | Book inventory                      | Audited                      | Not reachable from registered route.               |
| `book_pos_screen.dart`                          | Book POS                            | Audited                      | Not reachable from registered route.               |
| `book_supplier_returns_screen.dart`             | Supplier returns                    | Audited                      |                                                    |
| `consignment_settlement_screen.dart`            | Consignment settlement              | Audited                      |                                                    |
| `school_order_screen.dart`                      | Institution / school order          | Audited                      |                                                    |

### clinic

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/clinic/tokens` (route)                        | Token queue                         | Audited (placeholder route)  | See CL-001.                                        |
| `/clinic/appointments` (route)                  | Appointments                        | Audited (placeholder route)  | See CL-002.                                        |
| `/clinic/patients` (route)                      | Patients                            | Audited (placeholder route)  | Real screen `patient_management_screen.dart` exists. See CL-003. |
| `/clinic/emr` (route)                           | EMR                                 | Audited (placeholder route)  | See CL-004.                                        |
| `/clinic/billing` (route)                       | Clinic billing                      | Audited (placeholder route)  | See CL-005.                                        |
| `/clinic/doctors` (route)                       | Doctors                             | Audited (placeholder route)  | See CL-006.                                        |
| `clinic_calendar_screen.dart`                   | Calendar / appointments             | Audited                      |                                                    |
| `consultation_screen.dart`                      | Consultation                        | Audited                      | See CL-101 (silent catch on patient/doctor fetch). |
| `lab_order_screen.dart`                         | Lab orders                          | Audited                      |                                                    |
| `patient_history_screen.dart`                   | Patient history                     | Audited                      |                                                    |
| `patient_management_screen.dart`                | Patient management                  | Audited                      |                                                    |
| `patient_queue_screen.dart`                     | Patient queue                       | Audited                      |                                                    |
| `clinic_dashboard_screen.dart`                  | Clinic dashboard                    | Audited                      |                                                    |

### clothing

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/clothing/billing` (route)                     | Clothing billing                    | Audited (placeholder route)  | See CT-001.                                        |
| `/clothing/inventory` (route)                   | Clothing inventory                  | Audited (placeholder route)  | Real screen `clothing_inventory_screen.dart` exists. See CT-002. |
| `/clothing/variants` (route)                    | Size & variants                     | Audited (placeholder route)  | Real `variant_management_screen.dart` exists. See CT-003. |
| `/clothing/offers` (route)                      | Seasonal offers                     | Audited (placeholder route)  | See CT-004.                                        |
| `clothing_inventory_screen.dart`                | Clothing inventory                  | Audited                      |                                                    |
| `tailoring_measurements_screen.dart`            | Tailoring measurements              | Audited                      |                                                    |
| `variant_management_screen.dart`                | Variant management                  | Audited                      |                                                    |

### computer_shop

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/computer/billing` (route)                     | Computer billing                    | Audited (placeholder route)  | See CS-001.                                        |
| `/computer/inventory` (route)                   | Parts inventory                     | Audited (placeholder route)  | See CS-002.                                        |
| `/computer/service` (route)                     | Service desk                        | Audited (placeholder route)  | See CS-003.                                        |
| `/computer/amc` (route)                         | AMC contracts                       | Audited (placeholder route)  | See CS-004.                                        |
| `/computer/builds` (route)                      | PC builds                           | Audited (placeholder route)  | See CS-005.                                        |
| `create_job_card_screen.dart`                   | Create job-card                     | Audited                      |                                                    |
| `job_card_detail_screen.dart`                   | Job-card detail                     | Audited                      |                                                    |
| `job_card_list_screen.dart`                     | Job-card list                       | Audited                      |                                                    |
| `multi_unit_screen.dart`                        | Multi-unit conversion               | Audited                      |                                                    |
| `serial_history_screen.dart`                    | IMEI / serial history               | Audited                      |                                                    |
| `warranty_screen.dart`                          | Warranty                            | Audited                      |                                                    |

### decoration_catering

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/dc/events` (route)                            | Events                              | Audited (placeholder route)  | See DC-001.                                        |
| `/dc/themes` (route)                            | Themes                              | Audited (placeholder route)  | See DC-002.                                        |
| `/dc/menu` (route)                              | Menu                                | Audited (placeholder route)  | See DC-003.                                        |
| `/dc/staff` (route)                             | Staff                               | Audited (placeholder route)  | See DC-004.                                        |
| `/dc/vendors` (route)                           | Vendors                             | Audited (placeholder route)  | See DC-005.                                        |
| `/dc/invoices` (route)                          | DC billing                          | Audited (placeholder route)  | Real `dc_billing_screen.dart` exists. See DC-006.  |
| `/dc/expenses` (route)                          | Expenses                            | Audited (placeholder route)  | See DC-007.                                        |
| `/dc/reports` (route)                           | DC reports                          | Audited (placeholder route)  | See DC-008.                                        |
| `dc_billing_screen.dart`                        | DC billing                          | Audited                      |                                                    |
| `dc_bookings_screen.dart`                       | Bookings                            | Audited                      |                                                    |
| `dc_calendar_screen.dart`                       | Calendar                            | Audited                      |                                                    |
| `dc_catering_screen.dart`                       | Catering ops                        | Audited                      |                                                    |
| `dc_dashboard_screen.dart`                      | DC dashboard                        | Audited                      |                                                    |
| `dc_decoration_screen.dart`                     | Decoration ops                      | Audited                      |                                                    |
| `dc_event_detail_screen.dart`                   | Event detail                        | Audited                      |                                                    |
| `dc_inventory_screen.dart`                      | Inventory                           | Audited                      |                                                    |
| `dc_profitability_screen.dart`                  | Profitability                       | Audited                      |                                                    |
| `dc_quotes_screen.dart`                         | Quotes                              | Audited                      |                                                    |
| `dc_quote_conversion_screen.dart`               | Quote → invoice                     | Audited                      | See DC-101 (cross-module D10).                     |
| `dc_reports_screen.dart`                        | Reports                             | Audited                      |                                                    |
| `dc_shopping_list_screen.dart`                  | Shopping list                       | Audited                      |                                                    |
| `dc_staff_attendance_screen.dart`               | Staff attendance                    | Audited                      |                                                    |
| `dc_staff_screen.dart`                          | Staff                               | Audited                      |                                                    |
| `dc_vendor_payments_screen.dart`                | Vendor payments                     | Audited                      |                                                    |

### grocery

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/grocery/billing` (route)                      | Grocery billing                     | Audited (placeholder route)  | Inline placeholder `Center(child: Text(...))`. See GR-001. |
| `/grocery/inventory` (route)                    | Grocery inventory                   | Audited (placeholder route)  | See GR-002.                                        |
| `/grocery/batches` (route)                      | Batches & expiry                    | Audited (placeholder route)  | See GR-003.                                        |
| `/grocery/reports` (route)                      | Reports                             | Audited (placeholder route)  | See GR-004.                                        |
| (feature folder)                                | All grocery screens                 | Audited (no screen)          | `lib/features/grocery/` has no `*_screen.dart`. See GR-101. |

### hardware

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/hardware/billing` (route)                     | Hardware billing                    | Audited (placeholder route)  | See HW-001.                                        |
| `/hardware/inventory` (route)                   | Hardware inventory                  | Audited (placeholder route)  | See HW-002.                                        |
| `/hardware/projects` (route)                    | Projects                            | Audited (placeholder route)  | See HW-003.                                        |
| `/hardware/suppliers` (route)                   | Suppliers                           | Audited (placeholder route)  | Real `hardware_supplier_management_screen.dart` exists. See HW-004. |
| `/hardware/reports` (route)                     | Reports                             | Audited (placeholder route)  | See HW-005.                                        |
| `hardware_command_center_screen.dart`           | Command center                      | Audited                      |                                                    |
| `hardware_credit_control_screen.dart`           | Credit control                      | Audited                      |                                                    |
| `hardware_invoice_profile_screen.dart`          | Invoice profile                     | Audited                      |                                                    |
| `hardware_operations_screen.dart`               | Operations                          | Audited                      |                                                    |
| `hardware_phase12_workspace_screen.dart`        | Phase 12 workspace                  | Audited                      |                                                    |
| `hardware_supplier_management_screen.dart`      | Supplier management                 | Audited                      |                                                    |
| `dimension_calculator.dart`                     | Dimension / area / volume calc      | Audited                      | See HW-101 (D11 floating-point dimension math).    |

### jewellery

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/jewellery/billing` (route)                    | Jewellery billing                   | Audited (placeholder route)  | See JW-001.                                        |
| `/jewellery/inventory` (route)                  | Jewellery stock                     | Audited (placeholder route)  | Real `hallmark_inventory_screen.dart` exists. See JW-002. |
| `/jewellery/rates` (route)                      | Gold rates                          | Audited (placeholder route)  | Real `gold_rate_management_screen.dart` exists. See JW-003. |
| `/jewellery/orders` (route)                     | Custom orders                       | Audited (placeholder route)  | Real `custom_order_management_screen.dart` exists. See JW-004. |
| `/jewellery/exchange` (route)                   | Old gold exchange                   | Audited (placeholder route)  | Real `old_gold_exchange_screen.dart` exists. See JW-005. |
| `/jewellery/repair` (route)                     | Repair management                   | Audited (placeholder route)  | Real `jewellery_repair_screen.dart` exists. See JW-006. |
| `/jewellery/schemes` (route)                    | Gold schemes                        | Audited (placeholder route)  | Real `gold_scheme_screen.dart` exists. See JW-007. |
| `custom_order_management_screen.dart`           | Custom orders                       | Audited                      |                                                    |
| `gold_rate_alert_screen.dart`                   | Gold-rate alerts                    | Audited                      |                                                    |
| `gold_rate_management_screen.dart`              | Gold-rate management                | Audited                      |                                                    |
| `gold_scheme_screen.dart`                       | Gold schemes                        | Audited                      |                                                    |
| `hallmark_inventory_screen.dart`                | Hallmark inventory                  | Audited                      |                                                    |
| `jewellery_repair_screen.dart`                  | Repair                              | Audited                      |                                                    |
| `making_charges_calculator_screen.dart`         | Making-charges calc                 | Audited                      | See JW-101 (D11 purity / making-charges precision).|
| `old_gold_exchange_screen.dart`                 | Old gold exchange                   | Audited                      | See JW-102 (D10 cross-module exchange→bill→stock). |

### mobile_shop

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/mobile/billing` (route)                       | Mobile billing                      | Audited (placeholder route)  | See MB-001.                                        |
| `/mobile/imei` (route)                          | IMEI tracking                       | Audited (placeholder route)  | See MB-002.                                        |
| `/mobile/repair` (route)                        | Repair jobs                         | Audited (placeholder route)  | See MB-003.                                        |
| `/mobile/exchange` (route)                      | Exchange                            | Audited (placeholder route)  | See MB-004.                                        |
| `/mobile/emi` (route)                           | EMI plans                           | Audited (placeholder route)  | See MB-005.                                        |
| (feature folder)                                | All mobile-shop screens             | Audited (no screen)          | `lib/features/mobile_shop/` does not exist; only the routes file ships placeholders. See MB-101. |

### petrol_pump

| Screen / route                                       | Workflow                            | Status                       | Notes                                              |
| ---------------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/pump/shift` (route)                                | Shift entry                         | Audited (placeholder route)  | Real `shift_history_screen.dart` exists. See PP-001. |
| `/pump/dip` (route)                                  | Dip reading                         | Audited (placeholder route)  | See PP-002.                                        |
| `/pump/nozzles` (route)                              | Nozzle settlement                   | Audited (placeholder route)  | Real `dispenser_list_screen.dart` exists. See PP-003. |
| `/pump/pricing` (route)                              | Fuel pricing                        | Audited (placeholder route)  | Real `fuel_rates_screen.dart` exists. See PP-004.  |
| `/pump/reports` (route)                              | Pump reports                        | Audited (placeholder route)  | Real reports screens exist under `reports/`. See PP-005. |
| `add_staff_screen.dart`                              | Add staff                           | Audited                      |                                                    |
| `dispenser_list_screen.dart`                         | Dispensers / nozzles                | Audited                      |                                                    |
| `fuel_rates_screen.dart`                             | Fuel rates                          | Audited                      |                                                    |
| `petrol_pump_management_screen.dart`                 | Pump management                     | Audited                      |                                                    |
| `revenue_dashboard_screen.dart`                      | Revenue dashboard                   | Audited                      |                                                    |
| `shift_history_screen.dart`                          | Shift history                       | Audited                      | See PP-101 (D7 silent catch on shift recon JSON).  |
| `staff_detail_screen.dart`                           | Staff detail                        | Audited                      |                                                    |
| `staff_list_screen.dart`                             | Staff list                          | Audited                      |                                                    |
| `tank_list_screen.dart`                              | Tank list                           | Audited                      |                                                    |
| `reports/cash_deposit_report_screen.dart`            | Cash deposit report                 | Audited                      |                                                    |
| `reports/ca_report_screen.dart`                      | CA report                           | Audited                      |                                                    |
| `reports/density_report_screen.dart`                 | Density report                      | Audited                      |                                                    |
| `reports/dsr_report_screen.dart`                     | DSR report                          | Audited                      |                                                    |
| `reports/fuel_profit_report_screen.dart`             | Fuel-profit report                  | Audited                      |                                                    |
| `reports/nozzle_sales_report_screen.dart`            | Nozzle-sales report                 | Audited                      |                                                    |
| `reports/outstanding_analysis_screen.dart`           | Outstanding analysis                | Audited                      |                                                    |
| `reports/shift_report_screen.dart`                   | Shift report                        | Audited                      |                                                    |
| `reports/tank_stock_report_screen.dart`              | Tank-stock report                   | Audited                      |                                                    |
| `services/shift_service.dart` — totalizer rollover   | Nozzle totalizer rollover           | Audited                      | See PP-102 (D11 totalizer rollover).               |

### pharmacy

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/pharmacy/billing` (route)                     | Pharmacy billing                    | Audited (placeholder route)  | See PH-001.                                        |
| `/pharmacy/inventory` (route)                   | Medicines inventory                 | Audited (placeholder route)  | Real `product_catalog_screen.dart` exists. See PH-002. |
| `/pharmacy/batches` (route)                     | Batch & expiry                      | Audited (placeholder route)  | Real `batch_tracking_screen.dart` exists in `inventory/`. See PH-003. |
| `/pharmacy/prescriptions` (route)               | Prescriptions                       | Audited (placeholder route)  | See PH-004.                                        |
| `/pharmacy/compliance` (route)                  | Compliance                          | Audited (placeholder route)  | Real `narcotic_register_screen.dart` exists. See PH-005. |
| `narcotic_register_screen.dart`                 | Narcotic register                   | Audited                      |                                                    |
| `patient_registry_screen.dart`                  | Patient registry                    | Audited                      |                                                    |
| `product_catalog_screen.dart`                   | Product catalog                     | Audited                      |                                                    |
| `salt_search_screen.dart`                       | Salt search                         | Audited                      |                                                    |

### restaurant

| Screen / route                                       | Workflow                            | Status                       | Notes                                              |
| ---------------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/restaurant/tables` (route)                         | Tables                              | Audited (placeholder route)  | Real `table_management_screen.dart` exists. See RT-001. |
| `/restaurant/orders` (route)                         | Orders / KOT                        | Audited (placeholder route)  | Real `kot_report_screen.dart` exists. See RT-002.  |
| `/restaurant/menu` (route)                           | Menu                                | Audited (placeholder route)  | Real `menu_item_management_screen.dart` exists. See RT-003. |
| `/restaurant/billing` (route)                        | Restaurant billing                  | Audited (placeholder route)  | See RT-004.                                        |
| `/restaurant/delivery` (route)                       | Delivery                            | Audited (placeholder route)  | Real `restaurant_delivery_ops_screen.dart` exists. See RT-005. |
| `/restaurant/analytics` (route)                      | Analytics                           | Audited (placeholder route)  | See RT-006.                                        |
| `floor_management_screen.dart`                       | Floor management                    | Audited                      |                                                    |
| `food_menu_management_screen.dart`                   | Food-menu management                | Audited                      |                                                    |
| `kitchen_display_screen.dart`                        | Kitchen display                     | Audited                      |                                                    |
| `kot_report_screen.dart`                             | KOT report                          | Audited                      |                                                    |
| `menu_item_management_screen.dart`                   | Menu-item management                | Audited                      |                                                    |
| `recipe_management_screen.dart`                      | Recipe management                   | Audited                      |                                                    |
| `restaurant_aggregator_receipt_screen.dart`          | Aggregator receipts                 | Audited                      |                                                    |
| `restaurant_daily_summary_screen.dart`               | Daily summary                       | Audited                      |                                                    |
| `restaurant_delivery_ops_screen.dart`                | Delivery ops                        | Audited                      |                                                    |
| `restaurant_inventory_screen.dart`                   | Inventory                           | Audited                      |                                                    |
| `restaurant_owner_command_screen.dart`               | Owner command                       | Audited                      |                                                    |
| `restaurant_pricing_admin_screen.dart`               | Pricing admin                       | Audited                      |                                                    |
| `restaurant_table_ops_screen.dart`                   | Table ops                           | Audited                      |                                                    |
| `table_management_screen.dart`                       | Table management                    | Audited                      |                                                    |
| `customer/customer_menu_screen.dart`                 | Customer menu                       | Audited                      |                                                    |
| `customer/order_tracking_screen.dart`                | Order tracking                      | Audited                      |                                                    |
| `customer/rate_review_screen.dart`                   | Rate / review                       | Audited                      |                                                    |
| `data/models/restaurant_kot_model.dart` (KOT decode) | KOT items JSON decode               | Audited                      | See RT-101 (D7 silent catch on KOT items JSON).    |

### school_erp / academic_coaching

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/ac/students` (route)                          | Students                            | Audited (placeholder route)  | Real `ac_students_screen.dart` exists. See AC-001. |
| `/ac/batches` (route)                           | Batches                             | Audited (placeholder route)  | Real `ac_batches_screen.dart` exists. See AC-002.  |
| `/ac/fees` (route)                              | Fees                                | Audited (placeholder route)  | Real `ac_fee_collection_screen.dart` exists. See AC-003. |
| `/ac/attendance` (route)                        | Attendance                          | Audited (placeholder route)  | Real `ac_attendance_screen.dart` exists. See AC-004. |
| `/ac/exams` (route)                             | Exams                               | Audited (placeholder route)  | Real `ac_exams_screen.dart` exists. See AC-005.    |
| `/ac/faculty` (route)                           | Faculty                             | Audited (placeholder route)  | Real `ac_faculty_screen.dart` exists. See AC-006.  |
| `/ac/timetable` (route)                         | Timetable                           | Audited (placeholder route)  | Real `ac_timetable_screen.dart` exists. See AC-007. |
| `/ac/transport` (route)                         | Transport                           | Audited (placeholder route)  | Real `ac_transport_screen.dart` exists. See AC-008. |
| `/ac/reports` (route)                           | Reports                             | Audited (placeholder route)  | Real `ac_reports_screen.dart` exists. See AC-009.  |
| `/ac/communicate` (route)                       | Communication                       | Audited (placeholder route)  | Real `ac_notifications_screen.dart` exists. See AC-010. |
| `ac_academic_year_screen.dart`                  | Academic year                       | Audited                      |                                                    |
| `ac_admissions_screen.dart`                     | Admissions                          | Audited                      |                                                    |
| `ac_attendance_screen.dart`                     | Attendance                          | Audited                      |                                                    |
| `ac_batches_screen.dart`                        | Batches                             | Audited                      |                                                    |
| `ac_bulk_operations_screen.dart`                | Bulk operations                     | Audited                      |                                                    |
| `ac_certificate_generator_screen.dart`          | Certificate generator               | Audited                      | See AC-101 (D11 certificate template wiring).      |
| `ac_classwise_fee_screen.dart`                  | Classwise fees                      | Audited                      |                                                    |
| `ac_class_sections_screen.dart`                 | Class sections                      | Audited                      |                                                    |
| `ac_courses_screen.dart`                        | Courses                             | Audited                      |                                                    |
| `ac_dashboard_screen.dart`                      | AC dashboard                        | Audited                      |                                                    |
| `ac_documents_screen.dart`                      | Documents                           | Audited                      |                                                    |
| `ac_exams_screen.dart`                          | Exams                               | Audited                      |                                                    |
| `ac_faculty_screen.dart`                        | Faculty                             | Audited                      |                                                    |
| `ac_fee_collection_screen.dart`                 | Fee collection                      | Audited                      | See AC-102 (D10 fee→payment→ledger saga).          |
| `ac_financial_reports_screen.dart`              | Financial reports                   | Audited                      |                                                    |
| `ac_homework_screen.dart`                       | Homework                            | Audited                      |                                                    |
| `ac_hostel_screen.dart`                         | Hostel                              | Audited                      |                                                    |
| `ac_id_cards_screen.dart`                       | ID cards                            | Audited                      |                                                    |
| `ac_inventory_screen.dart`                      | School inventory                    | Audited                      |                                                    |
| `ac_leave_screen.dart`                          | Leave                               | Audited                      |                                                    |
| `ac_lesson_plans_screen.dart`                   | Lesson plans                        | Audited                      |                                                    |
| `ac_library_screen.dart`                        | Library                             | Audited                      |                                                    |
| `ac_materials_screen.dart`                      | Materials                           | Audited                      |                                                    |
| `ac_notifications_screen.dart`                  | Notifications                       | Audited                      |                                                    |
| `ac_payments_screen.dart`                       | Payments                            | Audited                      |                                                    |
| `ac_reports_screen.dart`                        | Reports                             | Audited                      |                                                    |
| `ac_report_cards_screen.dart`                   | Report cards                        | Audited                      | See AC-103 (D11 report-card grade calc).           |
| `ac_risk_detection_screen.dart`                 | Risk detection                      | Audited                      |                                                    |
| `ac_sibling_screen.dart`                        | Sibling                             | Audited                      |                                                    |
| `ac_students_screen.dart`                       | Students                            | Audited                      |                                                    |
| `ac_student_registration_screen.dart`           | Student registration                | Audited                      |                                                    |
| `ac_timetable_screen.dart`                      | Timetable                           | Audited                      |                                                    |
| `ac_transport_screen.dart`                      | Transport                           | Audited                      |                                                    |

### vegetables_broker

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/veg-broker/billing` (route)                   | Rate entry                          | Audited (placeholder route)  | See VB-001.                                        |
| `/veg-broker/farmers` (route)                   | Farmers                             | Audited (placeholder route)  | See VB-002.                                        |
| `/veg-broker/commission` (route)                | Commission                          | Audited (placeholder route)  | See VB-003.                                        |
| `/veg-broker/settlement` (route)                | Settlement                          | Audited (placeholder route)  | See VB-004.                                        |
| (feature folder)                                | All vegetable-broker screens        | Audited (no screen)          | `lib/features/vegetable_broker/` has data + repo only, no UI. See VB-101. |

### wholesale

| Screen / route                                  | Workflow                            | Status                       | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ---------------------------- | -------------------------------------------------- |
| `/wholesale/billing` (route)                    | Wholesale billing                   | Audited (placeholder route)  | See WS-001.                                        |
| `/wholesale/inventory` (route)                  | Wholesale inventory                 | Audited (placeholder route)  | See WS-002.                                        |
| `/wholesale/dispatch` (route)                   | Dispatch                            | Audited (placeholder route)  | See WS-003.                                        |
| `/wholesale/pricing` (route)                    | Price tiers                         | Audited (placeholder route)  | See WS-004.                                        |
| `/wholesale/eway` (route)                       | e-Way bill                          | Audited (placeholder route)  | See WS-005.                                        |
| `/wholesale/ar` (route)                         | Receivables                         | Audited (placeholder route)  | See WS-006.                                        |
| (feature folder)                                | All wholesale screens               | Audited (no screen)          | `lib/features/wholesale/` does not exist. See WS-101. |

---

## Dukan_x — shared feature areas

### customers

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `add_customer_screen.dart`                      | Add customer                        | Audited  |                                                    |
| `customers_list_screen.dart`                    | Customers list                      | Audited  |                                                    |
| `customer_dashboard_screen.dart`                | Customer dashboard                  | Audited  |                                                    |
| `customer_detail_screen.dart`                   | Customer detail                     | Audited  |                                                    |
| `customer_invoice_list_screen.dart`             | Customer invoices                   | Audited  |                                                    |
| `customer_ledger_screen.dart`                   | Customer ledger                     | Audited  |                                                    |
| `customer_management_screen.dart`               | Customer management                 | Audited  | See CU-101 (D4 cache invalidation on add).         |
| `customer_notifications_screen.dart`            | Notifications                       | Audited  |                                                    |
| `customer_payment_screen.dart`                  | Customer payment                    | Audited  |                                                    |
| `customer_profile_screen.dart`                  | Customer profile                    | Audited  |                                                    |
| `edit_profile_screen.dart`                      | Edit profile                        | Audited  |                                                    |
| `my_linked_shops_screen.dart`                   | Linked shops                        | Audited  |                                                    |
| `my_shops_screen.dart`                          | My shops                            | Audited  |                                                    |
| `notification_settings_screen.dart`             | Notification settings               | Audited  |                                                    |
| `security_settings_screen.dart`                 | Security settings                   | Audited  |                                                    |

### inventory

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `barcode_scanner_screen.dart`                   | Barcode scanner                     | Audited  | See IN-101 (D7 scanner failure path).              |
| `batch_tracking_screen.dart`                    | Batch tracking                      | Audited  |                                                    |
| `categories_screen.dart`                        | Categories                          | Audited  |                                                    |
| `category_products_screen.dart`                 | Category products                   | Audited  |                                                    |
| `damage_logs_screen.dart`                       | Damage logs                         | Audited  |                                                    |
| `import_inventory_screen.dart`                  | Import inventory                    | Audited  | See IN-102 (D9 large CSV import on UI isolate).    |
| `inventory_dashboard_screen.dart`               | Inventory dashboard                 | Audited  | See IN-103 (D9 unbounded query on dashboard).      |
| `low_stock_alerts_screen.dart`                  | Low-stock alerts                    | Audited  |                                                    |
| `product_management_screen.dart`                | Product management                  | Audited  |                                                    |
| `stock_adjustment_screen.dart`                  | Stock adjustment                    | Audited  |                                                    |
| `stock_summary_screen.dart`                     | Stock summary                       | Audited  |                                                    |
| `stock_valuation_screen.dart`                   | Stock valuation                     | Audited  |                                                    |

### purchase

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `purchase_entries_list_screen.dart`             | Purchase entries list               | Audited  |                                                    |
| `scan_bill_image_picker_screen.dart`            | Scan bill — image pick              | Audited  |                                                    |
| `scan_bill_processing_screen.dart`              | Scan bill — processing              | Audited  | See PU-101 (D7 OCR API timeout handling).          |
| `scan_bill_review_screen.dart`                  | Scan bill — review                  | Audited  |                                                    |
| `scan_bill_supplier_screen.dart`                | Scan bill — supplier                | Audited  |                                                    |
| `add_purchase_screen.dart`                      | Add purchase                        | Audited  |                                                    |
| `purchase_dashboard_screen.dart`                | Purchase dashboard                  | Audited  |                                                    |
| `purchase_detail_screen.dart`                   | Purchase detail                     | Audited  |                                                    |
| `purchase_history_screen.dart`                  | Purchase history                    | Audited  |                                                    |

### payment

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `payments_history_screen.dart`                  | Payments history                    | Audited  |                                                    |
| `payment_analytics_screen.dart`                 | Payment analytics                   | Audited  | See PA-101 (D2 placeholder analytics tiles).       |
| `payment_gateway_settings_screen.dart`          | Payment-gateway settings            | Audited  |                                                    |

### delivery_challan

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `create_delivery_challan_screen.dart`           | Create delivery challan             | Audited  |                                                    |
| `delivery_challan_list_screen.dart`             | Delivery-challan list               | Audited  |                                                    |
| `services/delivery_challan_service.dart`        | Convert challan → invoice           | Audited  | See DL-101 (D10 cross-module saga).                |

### service

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `create_exchange_screen.dart`                   | Create exchange                     | Audited  |                                                    |
| `create_service_job_screen.dart`                | Create service job                  | Audited  |                                                    |
| `exchange_detail_screen.dart`                   | Exchange detail                     | Audited  |                                                    |
| `exchange_list_screen.dart`                     | Exchange list                       | Audited  |                                                    |
| `service_job_detail_screen.dart`                | Service-job detail                  | Audited  |                                                    |
| `service_job_list_screen.dart`                  | Service-job list                    | Audited  |                                                    |
| `services/service_job_notification_service.dart`| SMS / push / email / WhatsApp notif | Audited  | See SV-101 (D2/D7 unimplemented notification paths). |
| `services/warranty_claim_service.dart`          | Warranty-claim service              | Audited  |                                                    |

### dashboard

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `daily_snapshot_screen.dart`                    | Daily snapshot                      | Audited  |                                                    |
| `live_business_health_screen.dart`              | Live business health                | Audited  |                                                    |
| `v2/screens/dashboard_v2_screen.dart`           | Dashboard v2                        | Audited  | See DA-101 (D9 dashboard N+1 widget reads).        |
| `v2/screens/pharmacy_dashboard_screen.dart`     | Pharmacy dashboard v2               | Audited  |                                                    |

### onboarding

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `vendor_onboarding_screen.dart`                 | Vendor onboarding wizard            | Audited  | See ON-101 (D1 back-gesture loses unsaved state).  |

### settings

| Screen                                          | Workflow                            | Status   | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | -------- | -------------------------------------------------- |
| `business_settings_screen.dart`                 | Business settings                   | Audited  |                                                    |
| `migration/migration_dashboard_screen.dart`     | Migration dashboard                 | Audited  |                                                    |
| `presentation/screens/audit_log_screen.dart`    | Audit log                           | Audited  |                                                    |
| `presentation/screens/customer_app_entry_qr_screen.dart` | Customer-app QR entry      | Audited  |                                                    |
| `presentation/screens/device_management_screen.dart` | Device management              | Audited  |                                                    |
| `presentation/screens/device_settings_screen.dart` | Device settings                  | Audited  |                                                    |
| `presentation/screens/error_logs_screen.dart`   | Error logs                          | Audited  |                                                    |
| `presentation/screens/main_settings_screen.dart`| Main settings                       | Audited  | See SE-101 (D7 catchError on settings persist).    |
| `presentation/screens/payment_reminders_screen.dart` | Payment reminders              | Audited  |                                                    |
| `presentation/screens/printer_settings_screen.dart`  | Printer settings               | Audited  |                                                    |
| `presentation/screens/settings_screen.dart`     | Settings                            | Audited  |                                                    |
| `presentation/screens/template_designer_screen.dart` | Template designer               | Audited  |                                                    |
| `presentation/screens/user_management_screen.dart` | User management                  | Audited  | See SE-102 (D3 hardcoded "0000000000" phone placeholder). |
| `screens/currency_settings_screen.dart`         | Currency settings                   | Audited  |                                                    |
| `screens/tax_config_screen.dart`                | Tax config                          | Audited  |                                                    |

---

## school_admin_app

| Screen                                          | Workflow                            | Status            | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ----------------- | -------------------------------------------------- |
| `auth/screens/login_screen.dart`                | Login                               | Audited           |                                                    |
| `dashboard/screens/dashboard_screen.dart`       | Admin dashboard                     | Audited           |                                                    |
| `students/screens/students_screen.dart`         | Students                            | Audited           | See SA-101 (D6 `setState({})` after async write).  |
| `faculty/screens/faculty_screen.dart`           | Faculty                             | Audited           | See SA-102 (D6 same pattern).                      |
| `classes/screens/classes_screen.dart`           | Classes                             | Audited           |                                                    |
| `admissions/screens/admissions_screen.dart`     | Admissions                          | Audited           |                                                    |
| `fees/screens/fees_screen.dart`                 | Fees                                | Audited           |                                                    |
| `attendance/screens/attendance_screen.dart`     | Attendance                          | Audited           |                                                    |
| `leave/screens/leave_screen.dart`               | Leave                               | Audited           |                                                    |
| `transport/screens/transport_screen.dart`       | Transport                           | Audited           |                                                    |
| `library/screens/library_screen.dart`           | Library                             | Audited           |                                                    |
| `hostel/screens/hostel_screen.dart`             | Hostel                              | Audited           |                                                    |
| `payroll/screens/payroll_screen.dart`           | Payroll                             | Audited           |                                                    |
| `reports/screens/reports_screen.dart`           | Reports                             | Audited           |                                                    |
| `announcements/screens/announcements_screen.dart` | Announcements                     | Audited           |                                                    |
| `settings/screens/settings_screen.dart`         | Settings                            | Audited           |                                                    |

## school_teacher_app

| Screen                                          | Workflow                            | Status            | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ----------------- | -------------------------------------------------- |
| `auth/screens/login_screen.dart`                | Login                               | Audited           |                                                    |
| `dashboard/screens/dashboard_screen.dart`       | Teacher dashboard                   | Audited           |                                                    |
| `attendance/screens/attendance_screen.dart`     | Attendance                          | Audited           |                                                    |
| `timetable/screens/timetable_screen.dart`       | Timetable                           | Audited           |                                                    |
| `students/screens/students_screen.dart`         | Students                            | Audited           |                                                    |
| `homework/screens/homework_screen.dart`         | Homework                            | Audited           |                                                    |
| `lesson_plans/screens/lesson_plans_screen.dart` | Lesson plans                        | Audited           |                                                    |
| `exams/screens/exams_screen.dart`               | Exams                               | Audited           | See ST-101 (D2 "Results upload coming soon").      |
| `materials/screens/materials_screen.dart`       | Materials                           | Audited           |                                                    |
| `leave/screens/leave_screen.dart`               | Leave                               | Audited           |                                                    |
| `announcements/screens/announcements_screen.dart` | Announcements                     | Audited           |                                                    |
| `payslip/screens/payslip_screen.dart`           | Payslip                             | Audited           |                                                    |
| `profile/screens/profile_screen.dart`           | Profile                             | Audited           |                                                    |

## school_student_app

| Screen                                          | Workflow                            | Status            | Notes                                              |
| ----------------------------------------------- | ----------------------------------- | ----------------- | -------------------------------------------------- |
| `auth/screens/login_screen.dart`                | Login                               | Audited           |                                                    |
| `dashboard/screens/dashboard_screen.dart`       | Student dashboard                   | Audited           |                                                    |
| `timetable/screens/timetable_screen.dart`       | Timetable                           | Audited           |                                                    |
| `attendance/screens/attendance_screen.dart`     | Attendance                          | Audited           |                                                    |
| `exams/screens/exams_screen.dart`               | Exams                               | Audited           |                                                    |
| `fees/screens/fees_screen.dart`                 | Fees                                | Audited           |                                                    |
| `fees/screens/fee_payment_screen.dart`          | Fee payment                         | Audited           | See SS-101 (D7 payment-init failure path).         |
| `materials/screens/materials_screen.dart`       | Materials                           | Audited           |                                                    |
| `homework/screens/homework_screen.dart`         | Homework                            | Audited           |                                                    |
| `leave/screens/leave_screen.dart`               | Leave                               | Audited           |                                                    |
| `notifications/screens/notifications_screen.dart` | Notifications                     | Audited           |                                                    |
| `library/screens/library_screen.dart`           | Library                             | Audited           |                                                    |
| `transport/screens/transport_screen.dart`       | Transport                           | Audited           |                                                    |
| `profile/screens/profile_screen.dart`           | Profile                             | Audited           |                                                    |
| `results/screens/results_screen.dart` & `services/report_card_pdf_service.dart` | Report card PDF | Audited | See SS-102 (D11 grade computation precision).      |
