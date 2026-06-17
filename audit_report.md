# DukanX Codebase Scan & Audit Report

**Date**: 2026-06-08 14:27:01
**Target Codebase**: DukanX POS & Billing Suite
**Auditor**: Senior Full-Stack Billing Software Engineer

---

## Executive Summary

This audit report presents the architectural layout, frontend screens, routing configurations, and backend endpoints of the DukanX multi-tenant SaaS application. 

### Codebase Health Metrics

| Metric | Count | Percentage |
| :--- | :--- | :--- |
| **Total Screens Scanned** | 532 | 100% |
| **Screens with Mock/Placeholder Issues** | 17 | 3.2% |
| **API Connected Screens** | 276 | 51.88% |
| **Offline Ready Screens** | 10 | 1.88% |
| **UI Consistent Screens** | 13 | 2.44% |
| **Total Named Routes** | 133 | â€” |
| **Total Backend Endpoints** | 247 | â€” |
| **Total Sidebar Menu Items** | 125 | â€” |

---

## 0.1 â€” Screen Inventory & Mock Data Issues

We scanned 532 screens. The following **17 screens** contain hardcoded mock data, placeholder UI elements, or // TODO comments indicating unfinished API connections.

### Screens Requiring Attention (Mock Data / Placeholders)

| Screen File | Business Types | Issue / Mock Reasons | Priority |
| :--- | :--- | :--- | :--- |
| **customer_auth_screen.dart** | All | mock/placeholder comment | High |
| **credit_note_screen.dart** | All | Mock keywords found; mock/placeholder comment | Medium |
| **buy_flow_dashboard.dart** | All | mock/placeholder comment | High |
| **patient_management_screen.dart** | Clinic | mock/placeholder comment | Medium |
| **customer_management_screen.dart** | All | mock/placeholder comment | Medium |
| **customer_profile_screen.dart** | All | mock/placeholder comment | Medium |
| **product_management_screen.dart** | All | mock/placeholder comment | Medium |
| **gold_scheme_screen.dart** | Jewellery | mock/placeholder comment | Medium |
| **jewellery_repair_screen.dart** | Jewellery | mock/placeholder comment | Medium |
| **old_gold_exchange_screen.dart** | Jewellery | mock/placeholder comment | Medium |
| **create_campaign_screen.dart** | All | mock/placeholder comment | Medium |
| **bill_template_system.dart** | All | Mock keywords found | Medium |
| **menu_item_management_screen.dart** | Restaurant | mock/placeholder comment | Medium |
| **user_management_screen.dart** | All | mock/placeholder comment | Medium |
| **app_management_screen.dart** | All | mock/placeholder comment | Medium |
| **pending_screen.dart** | All | mock/placeholder comment | Medium |
| **checkout_screen.dart** | All | mock/placeholder comment | Medium |

---

## 0.2 â€” Backend Endpoint Inventory

A total of **247** REST endpoints defined in openapi.yaml were audited. 

### Endpoint Security & Validation Summary
* **Cognito Authorized Endpoints**: 236
* **Zod Input-Validated**: 205
* **Tenant-Isolated (TenantContext)**: 228
* **Stale (Removed from Serverless)**: 8

### Complete Endpoint Registry

| Method | Path | Lambda Handler | DynamoDB Pattern | Auth? | Tenant-Isolated? | Zod Validated? | Status |
| :---: | :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **POST** | `/admin/hsn-seed` | src/handlers/hsn-seed.ts:handler | Put/Write | No | No | No | Implemented |
| **POST** | `/ai/chat` | src/handlers/ai.ts:chat | Update/Get | No | No | Yes | Implemented |
| **GET** | `/ai/settings` | src/handlers/ai.ts:getSettings | Update/Get | Yes | Yes | Yes | Implemented |
| **PUT** | `/ai/settings` | src/handlers/ai.ts:updateSettings | Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/api/v1/bills` | src/handlers/v1-bills.ts:listBillsHandler | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **POST** | `/api/v1/bills` | src/handlers/v1-bills.ts:createBillHandler | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/bills/count` | src/handlers/v1-bills.ts:billCountHandler | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/bills/cross-business` | src/handlers/v1-bills.ts:listBillsCrossBusinessHandler | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **DELETE** | `/api/v1/bills/{id}` | src/handlers/v1-bills.ts:deleteBillHandler | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/bills/{id}` | src/handlers/v1-bills.ts:getBillHandler | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **PUT** | `/api/v1/bills/{id}` | src/handlers/v1-bills.ts:updateBillHandler | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/connections` | src/handlers/v1-entity.ts:listEntity | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **POST** | `/api/v1/connections` | src/handlers/v1-entity.ts:createEntity | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **DELETE** | `/api/v1/connections/{id}` | src/handlers/v1-entity.ts:deleteEntity | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/connections/{id}` | src/handlers/v1-entity.ts:getEntity | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **PUT** | `/api/v1/connections/{id}` | src/handlers/v1-entity.ts:updateEntity | Put/Write/Update/Delete/Get | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/petrol/dsr` | src/handlers/v1-petrol-pump.ts:generateDsrHandler | Query | Yes | Yes | No | Implemented |
| **POST** | `/api/v1/petrol/fuel-receipt` | src/handlers/v1-petrol-pump.ts:recordFuelReceiptHandler | Query | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/petrol/fuel-types` | src/handlers/v1-petrol-pump.ts:listFuelTypesHandler | Query | Yes | Yes | No | Implemented |
| **POST** | `/api/v1/petrol/fuel-types/rate` | src/handlers/v1-petrol-pump.ts:updateFuelRateHandler | Query | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/petrol/nozzles` | src/handlers/v1-petrol-pump.ts:listNozzlesHandler | Query | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/petrol/shifts` | src/handlers/v1-petrol-pump.ts:listShiftsHandler | Query | Yes | Yes | No | Implemented |
| **POST** | `/api/v1/petrol/shifts` | src/handlers/v1-petrol-pump.ts:openShiftHandler | Query | Yes | Yes | No | Implemented |
| **POST** | `/api/v1/petrol/shifts/close` | src/handlers/v1-petrol-pump.ts:closeShiftHandler | Query | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/petrol/shifts/{id}` | src/handlers/v1-petrol-pump.ts:getShiftHandler | Query | Yes | Yes | No | Implemented |
| **GET** | `/api/v1/petrol/tanks` | src/handlers/v1-petrol-pump.ts:listTanksHandler | Query | Yes | Yes | No | Implemented |
| **POST** | `/auth/change-password` | src/handlers/auth.ts:changePassword | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **POST** | `/auth/login` | src/handlers/auth.ts:login | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **POST** | `/auth/logout` | src/handlers/auth.ts:logout | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **GET** | `/auth/me` | src/handlers/auth.ts:me | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **POST** | `/auth/mfa/confirm-setup` | src/handlers/auth.ts:mfaSetupConfirm | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **POST** | `/auth/mfa/setup` | src/handlers/auth.ts:mfaSetup | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **POST** | `/auth/mfa/verify` | src/handlers/auth.ts:mfaVerify | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **POST** | `/auth/refresh` | src/handlers/auth.ts:refresh | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **POST** | `/auth/signup` | src/handlers/auth.ts:signup | Get | No (Public/Pre-auth) | No (Auth level) | Yes | Implemented |
| **GET** | `/book-store/books` | src/handlers/book_store.ts:getBooks | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/book-store/customer-loyalty` | src/handlers/book_store.ts:customerLoyaltyLookup | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/book-store/isbn/{isbn}` | src/handlers/book_store.ts:lookupBookByIsbn | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/book-store/low-stock` | src/handlers/book_store.ts:getLowStockBooks | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/book-store/returns` | src/handlers/book_store.ts:listBookReturns | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/book-store/returns` | src/handlers/book_store.ts:createBookReturn | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/books/consignments` | src/handlers/book_store.ts:getConsignments | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/books/consignments` | src/handlers/book_store.ts:createConsignment | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/books/consignments/{id}/settle` | src/handlers/book_store.ts:settleConsignment | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/books/school-orders` | src/handlers/book_store.ts:getSchoolOrders | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/books/school-orders` | src/handlers/book_store.ts:createInstitutionalOrder | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/books/school-orders/{id}/fulfill` | src/handlers/book_store.ts:fulfillSchoolOrder | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/businesses/my-access` | src/handlers/businesses.ts:getMyAccess | Read/Write | Yes | Yes | Yes | Implemented |
| **GET** | `/category-sales` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **GET** | `/challans` | src/handlers/challans.ts:list | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/challans` | src/handlers/challans.ts:create | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/challans/{id}` | src/handlers/challans.ts:get | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/challans/{id}/delivered` | src/handlers/challans.ts:delivered | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/clinic/consultation` | src/handlers/clinic.ts:createSoapNote | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/clinic/follow-ups` | src/handlers/clinic.ts:createFollowUp | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/clinic/labs/orders` | src/handlers/clinic.ts:createLabOrder | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/clinic/labs/orders/{id}/results` | src/handlers/clinic.ts:attachLabResult | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/clinic/patients/{id}/history` | src/handlers/clinic.ts:getPatientHistory | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **PUT** | `/clinic/queue/{id}/status` | src/handlers/clinic.ts:updateQueueStatus | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **PUT** | `/clothing/variants/bulk` | src/handlers/clothing.ts:bulkUpdateVariants | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/clothing/variants/{productId}` | src/handlers/clothing.ts:getVariants | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/computer/checkout` | src/handlers/computer.ts:checkoutBuild | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/computer/job-cards` | src/handlers/computer.ts:getJobCards | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/computer/job-cards` | src/handlers/computer.ts:createJobCard | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **PATCH** | `/computer/job-cards/{id}/status` | src/handlers/computer.ts:updateJobCardStatus | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/computer/rma` | src/handlers/computer.ts:createRma | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **PATCH** | `/computer/rma/{id}/status` | src/handlers/computer.ts:updateRmaStatus | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/computer/serials` | src/handlers/computer.ts:getSerials | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/customer/fuel-fills` | src/handlers/customer-app.ts:getMyFillHistory | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/customers/credit/reminder-candidates` | src/handlers/customers.ts:getCreditReminderCandidates | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/customers/recovery-visits` | src/handlers/recovery-visits.ts:listRecoveryRegister | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/customers/recovery-visits` | src/handlers/recovery-visits.ts:recordRecoveryVisit | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/dashboard` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **GET** | `/dashboard-summary` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **GET** | `/estimates` | src/handlers/estimates.ts:list | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/estimates` | src/handlers/estimates.ts:create | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/estimates/{id}` | src/handlers/estimates.ts:get | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/estimates/{id}/convert` | src/handlers/estimates.ts:convert | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/estimates/{id}/void` | src/handlers/estimates.ts:voidEst | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/grocery/batches` | src/handlers/grocery-batches.ts:listBatches | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/grocery/batches` | src/handlers/grocery-batches.ts:createBatch | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/deposits` | src/handlers/hardware-deposits.ts:listDeposits | Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/deposits` | src/handlers/hardware-deposits.ts:createDeposit | Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/deposits/{id}/settle` | src/handlers/hardware-deposits.ts:settleDeposit | Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/grn` | src/handlers/hardware-phase12.ts:createGrn | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/indents` | src/handlers/hardware-projects.ts:listIndents | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/indents` | src/handlers/hardware-projects.ts:createIndent | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/indents/{id}/close` | src/handlers/hardware-projects.ts:closeIndent | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/invoice-profiles` | src/handlers/hardware-phase2.ts:getInvoiceProfiles | Get | Yes | Yes | Yes | Implemented |
| **PUT** | `/hardware/invoice-profiles` | src/handlers/hardware-phase2.ts:saveInvoiceProfiles | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/parties` | src/handlers/hardware-phase12.ts:listParties | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/parties` | src/handlers/hardware-phase12.ts:createParty | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/parties-aging` | src/handlers/hardware-phase12.ts:getPartyAging | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/parties/{id}/ledger` | src/handlers/hardware-phase12.ts:getPartyLedger | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/parties/{id}/ledger` | src/handlers/hardware-phase12.ts:postPartyLedger | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/pos/quick-invoice` | src/handlers/hardware-phase2.ts:quickCreateInvoice | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/project-outstanding` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **GET** | `/hardware/projects` | src/handlers/hardware-projects.ts:listProjects | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/projects` | src/handlers/hardware-projects.ts:createProject | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/projects/{id}/close` | src/handlers/hardware-projects.ts:closeProject | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/purchase-bills` | src/handlers/hardware-phase12.ts:createPurchaseBill | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/purchase-orders` | src/handlers/hardware-phase12.ts:listPurchaseOrders | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/purchase-orders` | src/handlers/hardware-phase12.ts:createPurchaseOrder | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/purchase-orders/pending` | src/handlers/hardware-phase2.ts:getPendingPurchaseOrders | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/purchase-orders/{id}/status` | src/handlers/hardware-phase12.ts:updatePurchaseOrderStatus | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/rate-comparison` | src/handlers/hardware-phase2.ts:getSupplierRateComparison | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/reports/dead-stock` | src/handlers/hardware-phase2.ts:getDeadStockReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/reports/item-velocity` | src/handlers/hardware-phase2.ts:getItemVelocityReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/hardware/sales-orders` | src/handlers/hardware-phase2.ts:listSalesOrders | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/sales-orders` | src/handlers/hardware-phase2.ts:createSalesOrder | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/hardware/sales-orders/{id}/status` | src/handlers/hardware-phase2.ts:updateSalesOrderStatus | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/inventory/expiry-alerts` | src/handlers/grocery-expiry.ts:getExpiryAlerts | Query/Get | Yes | Yes | No | Implemented |
| **POST** | `/inventory/labels` | src/handlers/barcode-label.ts:generateBatchLabels | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/inventory/{id}/adjust` | src/handlers/inventory.ts:adjustStock | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/inventory/{id}/label` | src/handlers/barcode-label.ts:generateLabel | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/invoices/{id}/einvoice` | src/handlers/einvoice.ts:getEInvoiceStatus | Put/Write/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/invoices/{id}/einvoice` | src/handlers/einvoice.ts:generateEInvoice | Put/Write/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/invoices/{id}/einvoice/cancel` | src/handlers/einvoice.ts:cancelEInvoice | Put/Write/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/invoices/{id}/ewaybill` | src/handlers/einvoice.ts:generateEWayBill | Put/Write/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/invoices/{id}/return` | src/handlers/invoices.ts:returnInvoice | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/jewellery/reports/hallmark-register` | src/handlers/jewellery-reports.ts:hallmarkRegisterReport | Query/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/jewellery/reports/old-gold-register` | src/handlers/jewellery-reports.ts:oldGoldRegisterReport | Query/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/license/activate` | src/handlers/license.ts:activate | Update/Get | Yes | Yes | No | Implemented |
| **POST** | `/license/generate` | src/handlers/license.ts:generate | Update/Get | Yes | Yes | No | Implemented |
| **POST** | `/license/manage` | src/handlers/license.ts:manage | Update/Get | Yes | Yes | No | Implemented |
| **GET** | `/license/status` | src/handlers/license.ts:status | Update/Get | Yes | Yes | No | Implemented |
| **POST** | `/license/validate` | src/handlers/license.ts:validate | Update/Get | Yes | Yes | No | Implemented |
| **POST** | `/loyalty/earn` | src/handlers/loyalty.ts:earnPoints | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/loyalty/history/{customerId}` | src/handlers/loyalty.ts:getHistory | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/loyalty/redeem` | src/handlers/loyalty.ts:redeemPoints | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/loyalty/{customerId}` | src/handlers/loyalty.ts:getBalance | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/notifications/register-device` | src/handlers/notification.ts:registerDevice | Update | Yes | Yes | Yes | Implemented |
| **GET** | `/payment-config` | src/handlers/payment-config.ts:getConfigs | Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/payment-config` | src/handlers/payment-config.ts:saveConfig | Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/payment-config/verify` | src/handlers/payment-config.ts:verifyConfig | Delete/Get | Yes | Yes | Yes | Implemented |
| **DELETE** | `/payment-config/{gateway}` | src/handlers/payment-config.ts:deleteConfig | Delete/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/payment-status` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **POST** | `/payment/initiate` | src/handlers/payment.ts:initiatePayment | Query/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/payment/reconcile` | src/handlers/payment.ts:reconcilePayments | Query/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/payment/status` | src/handlers/payment.ts:getPaymentStatus | Query/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/payment/webhook/phonepe` | src/handlers/payment-webhook.ts:phonePeWebhook | Update | Yes | Yes | No | Implemented |
| **POST** | `/payment/webhook/razorpay` | src/handlers/payment-webhook.ts:razorpayWebhook | Update | Yes | Yes | No | Implemented |
| **POST** | `/pharmacy/batch-intake` | src/handlers/pharmacy.ts:batchIntake | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/cds/screen` | src/handlers/pharmacy.ts:runClinicalScreening | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/claims` | src/handlers/pharmacy.ts:listClaims | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/claims/transmit` | src/handlers/pharmacy.ts:transmitNcpdpClaim | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/claims/{id}` | src/handlers/pharmacy.ts:getClaimById | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/claims/{id}/adjudicate` | src/handlers/pharmacy.ts:adjudicateClaim | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/claims/{id}/cob/next` | src/handlers/pharmacy.ts:createNextCobClaim | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/drug-master/mappings` | src/handlers/pharmacy.ts:listDrugMasterMappings | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/drug-master/mappings` | src/handlers/pharmacy.ts:upsertDrugMasterMapping | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/fefo-override/authorize` | src/handlers/pharmacy.ts:authorizeFefoOverride | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/formulary` | src/handlers/pharmacy.ts:listFormulary | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/formulary` | src/handlers/pharmacy.ts:upsertFormulary | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/h1-register` | src/handlers/pharmacy.ts:getH1Register | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/h1-register` | src/handlers/pharmacy.ts:createH1Entry | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/h1-register/export` | src/handlers/pharmacy.ts:exportH1Register | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/narcotic-register` | src/handlers/pharmacy.ts:getNarcoticRegister | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/narcotic-register` | src/handlers/pharmacy.ts:createNarcoticEntry | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/narcotic-register/export` | src/handlers/pharmacy.ts:exportNarcoticRegister | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/prescriptions/evidence` | src/handlers/pharmacy-compliance.ts:listPrescriptionEvidence | Read/Write | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prescriptions/evidence` | src/handlers/pharmacy-compliance.ts:uploadPrescriptionEvidence | Read/Write | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prescriptions/partial-fills` | src/handlers/pharmacy.ts:recordPartialFill | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/prescriptions/refills` | src/handlers/pharmacy.ts:listRefillRequests | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prescriptions/refills` | src/handlers/pharmacy.ts:createRefillRequest | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prescriptions/refills/backfill` | src/handlers/pharmacy.ts:backfillRefillTrace | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prescriptions/refills/backfill/bulk` | src/handlers/pharmacy.ts:bulkBackfillRefillTrace | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/prescriptions/refills/incomplete` | src/handlers/pharmacy.ts:listIncompleteRefills | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prescriptions/refills/{id}/status` | src/handlers/pharmacy.ts:updateRefillStatus | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/prior-auth` | src/handlers/pharmacy.ts:listPriorAuthorizations | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prior-auth` | src/handlers/pharmacy.ts:createPriorAuthorization | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pharmacy/prior-auth/{id}` | src/handlers/pharmacy.ts:getPriorAuthorizationById | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/prior-auth/{id}/status` | src/handlers/pharmacy.ts:updatePriorAuthorization | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/program-track/events` | src/handlers/pharmacy.ts:recordProgramTrackEvent | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pharmacy/return-policy/evaluate` | src/handlers/pharmacy-compliance.ts:evaluateReturnPolicy | Read/Write | Yes | Yes | Yes | Implemented |
| **POST** | `/prescriptions` | src/handlers/shared-prescriptions.ts:uploadSharedPrescription | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/prescriptions/check/{rxId}` | src/handlers/shared-prescriptions.ts:checkSharedPrescription | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/prescriptions/{rxId}` | src/handlers/shared-prescriptions.ts:getSharedPrescription | Get | Yes | Yes | Yes | Implemented |
| **PATCH** | `/prescriptions/{rxId}/dispense` | src/handlers/shared-prescriptions.ts:dispenseSharedPrescription | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/atg/ingest` | src/handlers/pump-integrations.ts:ingestAtgReading | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/atg/poll` | src/handlers/pump-integrations.ts:pollAtgReadings | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/cash-drop` | src/handlers/pump.ts:recordCashDrop | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/dip-chart/convert` | src/handlers/pump-integrations.ts:convertDipToVolume | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/dip-chart/upload` | src/handlers/pump-integrations.ts:uploadDipChart | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/fleet/authorize` | src/handlers/pump-integrations.ts:authorizeFleetCard | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/fuel-prices` | src/handlers/pump-pricing.ts:getFuelPriceHistory | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/fuel-prices` | src/handlers/pump-pricing.ts:updateFuelPrice | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/ppm-reading` | src/handlers/pump-integrations.ts:recordPpmReading | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/atg-readings` | src/handlers/pump-reports.ts:atgReadingsReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/cashier-collection` | src/handlers/pump-reports.ts:cashierCollectionReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/dip-variance` | src/handlers/pump-reports.ts:dipVarianceReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/dsr` | src/handlers/pump-reports.ts:dsrReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/nozzle-sales` | src/handlers/pump-reports.ts:nozzleSalesReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/rate-variation` | src/handlers/pump-reports.ts:rateVariationReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/shift-collection` | src/handlers/pump-reports.ts:shiftCollectionReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/stock-valuation` | src/handlers/pump-reports.ts:stockValuationReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/tank-stock` | src/handlers/pump-reports.ts:tankStockReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/tanker-receipts` | src/handlers/pump-reports.ts:tankerReceiptReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/pump/reports/vehicle-ledger` | src/handlers/pump-reports.ts:vehicleLedgerReport | Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/shift/approve-dsr` | src/handlers/pump.ts:approveShiftDsr | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/shift/close` | src/handlers/pump.ts:closeShift | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/shift/handover-ack` | src/handlers/pump.ts:acknowledgeShiftHandover | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/shift/open` | src/handlers/pump.ts:openShift | Query/Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/tank-dip` | src/handlers/pump-integrations.ts:recordManualDip | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/pump/tanker-receipts` | src/handlers/pump-integrations.ts:recordTankerReceipt | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/balance-sheet` | src/handlers/financial-reports.ts:balanceSheetReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/cash-flow` | src/handlers/financial-reports.ts:cashFlowReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/expense-register` | src/handlers/financial-reports.ts:expenseRegisterReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/export` | src/handlers/reports.ts:exportReport | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/fund-flow` | src/handlers/financial-reports.ts:fundFlowReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/gstr3b` | src/handlers/reports.ts:gstr3bReport | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/petty-cash` | src/handlers/financial-reports.ts:pettyCashReport | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/pnl` | src/handlers/reports.ts:profitLossReport | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/reports/share` | src/handlers/reports.ts:shareReport | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/reports/share-dispatches/{id}/mark-attempt` | src/handlers/reports.ts:markReportDispatchAttempt | Query/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/reports/stock-adjustments` | src/handlers/inventory.ts:getStockAdjustments | Query/Put/Write/Update/Delete/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/revenue-monthly` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **GET** | `/sales-trend` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **GET** | `/service/jobs` | src/handlers/service.ts:getMyJobs | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/service/jobs/{id}/parts` | src/handlers/service.ts:addJobParts | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **PUT** | `/service/jobs/{id}/status` | src/handlers/service.ts:updateJobStatus | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/settings/einvoice` | src/handlers/einvoice.ts:getEInvoiceSettings | Put/Write/Get | Yes | Yes | Yes | Implemented |
| **PUT** | `/settings/einvoice` | src/handlers/einvoice.ts:upsertEInvoiceSettings | Put/Write/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/staff/sale` | src/handlers/staff-sale.ts:createSale | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/staff/sale/daily-summary` | src/handlers/staff-sale.ts:getDailySummary | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/staff/sale/generate-qr` | src/handlers/staff-sale.ts:generateSaleQr | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/staff/sale/history` | src/handlers/staff-sale.ts:getMyHistory | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/staff/transactions` | src/handlers/staff-sale-history.ts:getStaffTransactions | Get | Yes | Yes | No | Implemented |
| **GET** | `/staff/transactions/summary` | src/handlers/staff-sale-history.ts:getTransactionSummary | Get | Yes | Yes | No | Implemented |
| **GET** | `/staff/transactions/{id}` | src/handlers/staff-sale-history.ts:getTransactionDetail | Get | Yes | Yes | No | Implemented |
| **GET** | `/stock-count` | src/handlers/stock-count.ts:listCounts | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/stock-count` | src/handlers/stock-count.ts:startCount | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/stock-count/{id}` | src/handlers/stock-count.ts:getCount | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/stock-count/{id}/finalize` | src/handlers/stock-count.ts:finalize | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/stock-count/{id}/items` | src/handlers/stock-count.ts:submitItems | Put/Write/Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/storage/signed-url` | src/handlers/storage.ts:getSignedUrl | Get | Yes | Yes | Yes | Implemented |
| **GET** | `/suppliers` | src/handlers/suppliers.ts:listSuppliers | Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/suppliers` | src/handlers/suppliers.ts:createSupplier | Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/suppliers/payables/ageing` | src/handlers/suppliers.ts:getSupplierPayableAgeing | Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/suppliers/payables/reminder-candidates` | src/handlers/suppliers.ts:getSupplierReminderCandidates | Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/suppliers/payables/reminders/trigger` | src/handlers/suppliers.ts:triggerSupplierReminders | Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/suppliers/payables/summary` | src/handlers/suppliers.ts:getSupplierPayablesSummary | Update/Get | Yes | Yes | Yes | Implemented |
| **POST** | `/suppliers/payments` | src/handlers/suppliers.ts:recordSupplierPayment | Update/Get | Yes | Yes | Yes | Implemented |
| **PUT** | `/suppliers/{id}` | src/handlers/suppliers.ts:updateSupplier | Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/suppliers/{id}/ledger` | src/handlers/suppliers.ts:getSupplierLedger | Update/Get | Yes | Yes | Yes | Implemented |
| **GET** | `/top-products` | N/A:N/A | N/A | Yes | No | No | No serverless handler mapping |
| **POST** | `/weighscale/read` | src/handlers/weighscale.ts:readWeighScale | Get | Yes | Yes | Yes | Implemented |

---

## 0.3 â€” Navigation Graph

The named route table from outes.dart was parsed. There are **133** unique routes configured.

### Route Registry

| Route | Target Screen | Reachable From | Business Type Guard | Role Guard | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/auth_gate` | **Unknown** | vendor_onboarding_screen, app, dukanx_splash_screen | All | None | Active |
| `/login` | **LoginPage** | protected_route, customer_profile_screen, pharmacy_dashboard_redirect | All | None | Active |
| `/license` | **LicenseScreen** | Deep Link / Direct Navigation | All | None | Active |
| `/onboarding` | **VendorOnboardingScreen** | login_page | All | None | Active |
| `/dashboard_selection` | **DashboardSelectionScreen** | Deep Link / Direct Navigation | All | None | Active |
| `/vendor_qr_code` | **VendorQRCodeScreen** | Deep Link / Direct Navigation | All | manageStaff | Active |
| `/customer_link_shop` | **CustomerLinkShopScreen** | my_shops_screen | All | None | Active |
| `/startup` | **Unknown** | professional_customer_portal, cloud_sync_settings_screen | All | None | Active |
| `/home` | **AdaptiveShell** | otp_screen | All | viewInvoices | Active |
| `/home_modern` | **AdaptiveShell** | Deep Link / Direct Navigation | All | viewInvoices | Active |
| `/enhanced_dashboard` | **OwnerDashboardRedirect** | Deep Link / Direct Navigation | All | None | Active |
| `/specialized_dashboard/restaurant` | **SpecializedDashboardRedirect** | Deep Link / Direct Navigation | All | None | Active |
| `/specialized_dashboard/clinic` | **SpecializedDashboardRedirect** | Deep Link / Direct Navigation | All | None | Active |
| `/owner_dashboard` | **AdaptiveShell** | owner_dashboard_redirect, pharmacy_dashboard_screen, pharmacy_dashboard_redirect | All | viewInvoices | Active |
| `/pharmacy/dashboard` | **PharmacyDashboardScreen** | owner_dashboard_redirect, pharmacy_dashboard_redirect | All | viewInvoices | Active |
| `/pharmacy/patients` | **PatientRegistryScreen** | patient_registry_service | All | viewCustomers | Active |
| `/pharmacy/salt-search` | **SaltSearchScreen** | salt_search_screen | All | viewProducts | Active |
| `/signup` | **LoginPage** | Deep Link / Direct Navigation | All | None | Active |
| `/owner_login` | **LoginPage** | professional_startup_screen, owner_auth_guard | All | None | Active |
| `/customer_login` | **LoginPage** | professional_startup_screen | All | None | Active |
| `/shop_selection` | **ShopSelectionScreen** | Deep Link / Direct Navigation | All | None | Active |
| `/business_type_selection` | **Unknown** | Deep Link / Direct Navigation | All | None | Active |
| `/business_settings` | **BusinessSettingsScreen** | main_settings_screen | All | systemSettings | Active |
| `/vendor_profile` | **VendorProfileScreen** | main_settings_screen | All | systemSettings | Active |
| `/pending` | **PendingScreen** | concrete_strategies | All | viewInvoices | Active |
| `/billing_flow` | **BillingFlow** | shortcut_definitions, global_keyboard_handler | All | createInvoices | Active |
| `/customer_bills` | **CustomerBillsScreen** | Deep Link / Direct Navigation | All | viewInvoices | Active |
| `/bill_search` | **BillSearchScreen** | Deep Link / Direct Navigation | All | viewInvoices | Active |
| `/advanced_billing` | **AdvancedBillingScreen** | Deep Link / Direct Navigation | All | createInvoices | Active |
| `/blacklist` | **BlacklistManagementScreen** | Deep Link / Direct Navigation | All | manageStaff | Active |
| `/reports` | **BillingReportsScreen** | shortcut_definitions, concrete_strategies, global_keyboard_handler | All | viewReports | Active |
| `/add_customer` | **AddCustomerScreen** | shortcut_definitions, concrete_strategies | All | viewClients | Active |
| `/total_bills` | **TotalBillsScreen** | Deep Link / Direct Navigation | All | viewInvoices | Active |
| `/total_paid` | **TotalPaidScreen** | Deep Link / Direct Navigation | All | viewInvoices | Active |
| `/pending_dues` | **PendingDuesScreen** | Deep Link / Direct Navigation | All | viewInvoices | Active |
| `/customers_list` | **CustomersListScreen** | Deep Link / Direct Navigation | All | viewClients | Active |
| `/settings` | **SettingsScreen** | shortcut_definitions, global_keyboard_handler | All | systemSettings | Active |
| `/printer-settings` | **PrinterSettingsScreen** | settings_screen, device_settings_screen | All | systemSettings | Active |
| `/admin/recompute_dues` | **AdminMigrationsScreen** | Deep Link / Direct Navigation | All | manageStaff | Active |
| `/dev_health` | **DeveloperHealthScreen** | main_settings_screen, shortcut_definitions | All | systemSettings | Active |
| `/dev_business_type_switcher` | **DevBusinessTypeSwitcherScreen** | main_settings_screen | All | None | Active |
| `/owner_link` | **OwnerLinkScreen** | Deep Link / Direct Navigation | All | manageStaff | Active |
| `/customer_link_accept` | **CustomerLinkAcceptScreen** | Deep Link / Direct Navigation | All | None | Active |
| `/customer_portal` | **CustomerDashboardScreen** | Deep Link / Direct Navigation | All | None | Active |
| `/my-linked-shops` | **MyLinkedShopsScreen** | Deep Link / Direct Navigation | All | None | Active |
| `/bill_scan` | **BillScanScreen** | Deep Link / Direct Navigation | All | createInvoices | Active |
| `/barcode_scanner` | **BarcodeScannerScreen** | Deep Link / Direct Navigation | All | createInvoices | Active |
| `/insights` | **InsightsScreen** | Deep Link / Direct Navigation | All | viewAnalytics | Active |
| `/bill_template` | **BillTemplateDesignerScreen** | Deep Link / Direct Navigation | All | systemSettings | Active |
| `/alerts` | **AlertsScreen** | Deep Link / Direct Navigation | All | viewAnalytics | Active |
| `/app_management` | **AppManagementScreen** | Deep Link / Direct Navigation | All | systemSettings | Active |
| `/inventory` | **InventoryDashboardScreen** | shortcut_definitions, concrete_strategies, hardware_ops_repository | All | viewInvoices | Active |
| `/delivery_challans` | **DeliveryChallanListScreen** | hardware_command_center_screen | All | viewInvoices | Active |
| `/proforma` | **ProformaScreen** | customer_detail_screen, hardware_command_center_screen, sale_home_screen | All | createInvoices | Active |
| `/hardware/operations` | **Builder** | hardware_command_center_screen | hardware | viewReports | Active |
| `/hardware/credit-control` | **BusinessGuard** | hardware_command_center_screen | hardware | viewReports | Active |
| `/hardware/fast-billing` | **BusinessGuard** | hardware_command_center_screen | hardware | createInvoices | Active |
| `/hardware/invoice-profiles` | **BusinessGuard** | hardware_phase12_contracts, hardware_ops_repository, hardware_command_center_screen | hardware | systemSettings | Active |
| `/analytics` | **AnalyticsDashboardScreen** | hardware_command_center_screen | All | viewAnalytics | Active |
| `/backup` | **BackupScreen** | shortcut_definitions, global_keyboard_handler | All | exportReports | Active |
| `/gst-reports` | **GstReportsScreen** | hardware_command_center_screen, tax_report_screen | All | viewReports | Active |
| `/daybook` | **DayBookScreen** | shortcut_definitions, global_keyboard_handler | All | viewReports | Active |
| `/party_ledger` | **PartyLedgerListScreen** | shortcut_definitions, hardware_command_center_screen, global_keyboard_handler | All | viewClients | Active |
| `/notifications` | **CustomerNotificationsScreen** | Deep Link / Direct Navigation | All | viewClients | Active |
| `/payment-history` | **PaymentHistoryScreen** | shortcut_definitions, global_keyboard_handler, customer_app_view_modern | All | viewInvoices | Active |
| `/sync-status` | **RealSyncScreen** | enterprise_desktop_shell, sync_status_indicator | All | viewReports | Active |
| `/service_jobs` | **ServiceJobListScreen** | Deep Link / Direct Navigation | All | manageStaff | Active |
| `/exchanges` | **ExchangeListScreen** | Deep Link / Direct Navigation | All | manageStaff | Active |
| `/catalogue` | **CatalogueScreen** | concrete_strategies | All | viewClients | Active |
| `/clinic/appointment` | **BusinessGuard** | dashboard_strategies | clinic | viewClients | Active |
| `/clinic/prescription` | **BusinessGuard** | dashboard_strategies | clinic | viewClients | Active |
| `/clinic/queue` | **BusinessGuard** | clinic_repository, dashboard_strategies | clinic | viewClients | Active |
| `/clinic/consultation` | **BusinessGuard** | clinic_repository | clinic | viewClients | Active |
| `/clinic/history` | **BusinessGuard** | Deep Link / Direct Navigation | clinic | viewClients | Active |
| `/clinic/labs` | **BusinessGuard** | Deep Link / Direct Navigation | clinic | viewClients | Active |
| `/clothing/variants` | **BusinessGuard** | clothing_module | clothing | manageStaff | Active |
| `/book_store/school_orders` | **BusinessGuard** | Deep Link / Direct Navigation | bookStore | viewReports | Active |
| `/book_store/consignments` | **BusinessGuard** | Deep Link / Direct Navigation | bookStore | viewReports | Active |
| `/job/create` | **BusinessGuard** | dashboard_strategies | mobileShop, computerShop, service, electronics | manageStaff | Active |
| `/job/status` | **BusinessGuard** | dashboard_strategies | mobileShop, computerShop, service, electronics | manageStaff | Active |
| `/job/deliver` | **BusinessGuard** | dashboard_strategies | mobileShop, computerShop, service, electronics | manageStaff | Active |
| `/pump/reading` | **BusinessGuard** | dashboard_strategies | petrolPump | viewReports | Active |
| `/pump/density` | **BusinessGuard** | dashboard_strategies | petrolPump | viewReports | Active |
| `/customer_app` | **CustomerDashboardScreen** | Deep Link / Direct Navigation | All | None | Active |
| `/customer_report` | **CustomerReportScreen** | Deep Link / Direct Navigation | All | viewReports | Active |
| `/advanced_bill_creation` | **AdvancedBillCreationScreen** | concrete_strategies, customer_app_view_modern | All | createInvoices | Active |
| `/cloud_sync_settings` | **CloudSyncSettingsScreen** | main_settings_screen | All | systemSettings | Active |
| `/editable_invoice` | **EditableInvoiceScreen** | Deep Link / Direct Navigation | All | systemSettings | Active |
| `/dc/dashboard` | **BusinessGuard** | dc_repository | decorationCatering | viewInvoices | Active |
| `/dc/bookings` | **BusinessGuard** | dc_dashboard_screen | decorationCatering | viewInvoices | Active |
| `/dc/bookings/new` | **BusinessGuard** | dc_dashboard_screen | decorationCatering | createInvoices | Active |
| `/dc/decoration` | **BusinessGuard** | dc_dashboard_screen | decorationCatering | viewInvoices | Active |
| `/dc/catering` | **BusinessGuard** | dc_dashboard_screen | decorationCatering | viewInvoices | Active |
| `/dc/staff` | **BusinessGuard** | dc_repository, dc_dashboard_screen, decoration_catering_module | decorationCatering | viewInvoices | Active |
| `/dc/vendors` | **BusinessGuard** | dc_repository, decoration_catering_module | decorationCatering | viewInvoices | Active |
| `/dc/inventory` | **BusinessGuard** | dc_repository, dc_dashboard_screen | decorationCatering | viewInvoices | Active |
| `/dc/inventory_low` | **BusinessGuard** | Deep Link / Direct Navigation | decorationCatering | viewInvoices | Active |
| `/dc/reports` | **BusinessGuard** | dc_dashboard_screen, decoration_catering_module | decorationCatering | viewReports | Active |
| `/dc/expense_report` | **BusinessGuard** | Deep Link / Direct Navigation | decorationCatering | viewReports | Active |
| `/dc/billing` | **BusinessGuard** | dc_dashboard_screen | decorationCatering | createInvoices | Active |
| `/dc/kitchen` | **BusinessGuard** | Deep Link / Direct Navigation | decorationCatering | viewInvoices | Active |
| `/dc/venue` | **BusinessGuard** | Deep Link / Direct Navigation | decorationCatering | viewInvoices | Active |
| `/ac/dashboard` | **BusinessGuard** | ac_repository | schoolErp | viewInvoices | Active |
| `/ac/students` | **BusinessGuard** | school_erp_sync_handler, school_erp_module, ac_repository | schoolErp | viewClients | Active |
| `/ac/classes` | **BusinessGuard** | ac_repository | schoolErp | viewInvoices | Active |
| `/ac/academic-year` | **BusinessGuard** | Deep Link / Direct Navigation | schoolErp | viewInvoices | Active |
| `/ac/batches` | **BusinessGuard** | school_erp_module, ac_repository | schoolErp | viewInvoices | Active |
| `/ac/courses` | **BusinessGuard** | ac_repository | schoolErp | viewInvoices | Active |
| `/ac/faculty` | **BusinessGuard** | school_erp_module, ac_repository | schoolErp | viewInvoices | Active |
| `/ac/fees` | **BusinessGuard** | school_erp_module | schoolErp | viewInvoices | Active |
| `/ac/attendance` | **BusinessGuard** | school_erp_module, ac_dashboard_screen, ac_repository | schoolErp | viewInvoices | Active |
| `/ac/timetable` | **BusinessGuard** | school_erp_module, ac_repository | schoolErp | viewInvoices | Active |
| `/ac/exams` | **BusinessGuard** | school_erp_module, ac_repository | schoolErp | viewInvoices | Active |
| `/ac/report-cards` | **BusinessGuard** | ac_repository | schoolErp | viewReports | Active |
| `/ac/materials` | **BusinessGuard** | ac_repository | schoolErp | viewInvoices | Active |
| `/ac/library` | **BusinessGuard** | Deep Link / Direct Navigation | schoolErp | viewInvoices | Active |
| `/ac/transport` | **BusinessGuard** | school_erp_module | schoolErp | viewInvoices | Active |
| `/ac/risk` | **BusinessGuard** | Deep Link / Direct Navigation | schoolErp | viewReports | Active |
| `/ac/notifications` | **BusinessGuard** | Deep Link / Direct Navigation | schoolErp | viewInvoices | Active |
| `/ac/bulk` | **BusinessGuard** | Deep Link / Direct Navigation | schoolErp | createInvoices | Active |
| `/ac/financial` | **BusinessGuard** | Deep Link / Direct Navigation | schoolErp | viewReports | Active |
| `/ac/certificates` | **BusinessGuard** | ac_repository | schoolErp | createInvoices | Active |
| `/ac/fee-structure` | **BusinessGuard** | ac_repository | schoolErp | viewInvoices | Active |
| `/computer-shop/job-cards` | **BusinessGuard** | computer_shop_sidebar | computerShop | viewInvoices | Active |
| `/computer-shop/create-job-card` | **BusinessGuard** | warranty_screen, serial_history_screen, computer_shop_sidebar | computerShop | createInvoices | Active |
| `/computer-shop/job-card-detail` | **Text** | serial_history_screen, job_card_list_screen | computerShop | viewInvoices | Active |
| `/computer-shop/warranty` | **BusinessGuard** | computer_shop_sidebar | computerShop | viewInvoices | Active |
| `/computer-shop/serial-history` | **Text** | warranty_screen | computerShop | viewInvoices | Active |
| `/computer-shop/multi-unit` | **BusinessGuard** | computer_shop_sidebar | computerShop | systemSettings | Active |
| `/purchase/scan-bill` | **ScanBillImagePickerScreen** | jewellery_module, mobile_shop_module, hardware_module | All | createInvoices | Active |
| `/purchase/scan-bill/review` | **ScanBillReviewScreen** | scan_bill_image_picker_screen | All | createInvoices | Active |
| `/purchase/entries` | **PurchaseEntriesListScreen** | scan_bill_api_client | All | viewReports | Active |
| `/invoice_preview` | **InvoicePreviewScreen** | Deep Link / Direct Navigation | All | viewReports | Active |

---

## 0.4 â€” Sidebar Feature Inventory

The dynamic sidebar options available across different business types were audited. There are **125** sidebar configurations mapped.

### Sidebar Menu Item Registry

| Business Type | Sidebar Item Name | Item ID | Route | Target Screen | Connected? | Implemented? | Functional? |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| **clinic** | Overview | `clinic_dashboard` | `/app/clinic_dashboard` | DoctorDashboardScreen | Yes | Yes | Yes |
| **clinic** | Today\ | `daily_appointments` | `/app/daily_appointments` | AppointmentScreen | Yes | Yes | Yes |
| **clinic** | All Patients | `patients_list` | `/app/patients_list` | PatientListScreen | Yes | Yes | Yes |
| **clinic** | Register Patient | `add_patient` | `/app/add_patient` | AddPatientScreen | Yes | Yes | Yes |
| **clinic** | Patient History | `patient_history` | `/app/patient_history` | PatientListScreen | Yes | Yes | Yes |
| **clinic** | Scan Patient QR | `scan_qr` | `/app/scan_qr` | QrScannerScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **clinic** | Appointments | `appointments` | `/app/appointments` |  | No | No | No |
| **clinic** | Prescriptions | `prescriptions` | `/app/prescriptions` | SafePrescriptionListScreen | Yes | Yes | Yes |
| **clinic** | Medicine Master | `medicine_master` | `/app/medicine_master` | MedicineMasterScreen | Yes | Yes | Yes |
| **clinic** | Lab Reports | `lab_reports` | `/app/lab_reports` | LabReportsScreen | Yes | Yes | Yes |
| **clinic** | Revenue Analytics | `doctor_revenue` | `/app/doctor_revenue` | DoctorRevenueScreen | Yes | Yes | Yes |
| **clinic** | Create Bill | `new_sale` | `/app/new_sale` | BillCreationScreenV2 | Yes | Yes | Yes |
| **clinic** | Revenue Overview | `revenue_overview` | `/app/revenue_overview` | RevenueOverviewScreen | Yes | Yes | Yes |
| **clinic** | Sync Status | `sync_status` | `/app/sync_status` | BackupScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **clinic** | Settings | `device_settings` | `/app/device_settings` | DeviceSettingsScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **pharmacy** | Dashboard | `executive_dashboard` | `/app/executive_dashboard` | DashboardController | Yes | Yes | Partial (Mocked or Unconnected) |
| **pharmacy** | Live Health | `live_health` | `/app/live_health` | LiveBusinessHealthScreen | Yes | Yes | Yes |
| **pharmacy** | Daily Snapshot | `daily_snapshot` | `/app/daily_snapshot` | DailySnapshotScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **pharmacy** |  | `new_sale` | `/app/new_sale` | BillCreationScreenV2 | Yes | Yes | Yes |
| **pharmacy** | Prescriptions | `prescriptions` | `/app/prescriptions` | SafePrescriptionListScreen | Yes | Yes | Yes |
| **pharmacy** | Revenue Overview | `revenue_overview` | `/app/revenue_overview` | RevenueOverviewScreen | Yes | Yes | Yes |
| **pharmacy** | Sales Register | `sales_register` | `/app/sales_register` | SalesRegisterScreen | Yes | Yes | Yes |
| **pharmacy** | Medicine Stock | `item_stock` | `/app/item_stock` | InventoryDashboardScreen | Yes | Yes | Yes |
| **pharmacy** | Batch / Expiry View | `batch_tracking` | `/app/batch_tracking` | BatchTrackingScreen | Yes | Yes | Yes |
| **pharmacy** | Low Stock / Expiry | `low_stock` | `/app/low_stock` | LowStockAlertsScreen | Yes | Yes | Yes |
| **pharmacy** | Stock Valuation | `stock_valuation` | `/app/stock_valuation` | StockValuationScreen | Yes | Yes | Yes |
| **pharmacy** | Purchase Orders | `purchase_orders` | `/app/purchase_orders` | BuyOrdersScreen | Yes | Yes | Yes |
| **pharmacy** | Stock Entry | `stock_entry` | `/app/stock_entry` | StockEntryScreen | Yes | Yes | Yes |
| **pharmacy** | Supplier Bills | `supplier_bills` | `/app/supplier_bills` | SupplierBillsScreen | Yes | Yes | Yes |
| **restaurant** | Dashboard | `executive_dashboard` | `/app/executive_dashboard` | DashboardController | Yes | Yes | Partial (Mocked or Unconnected) |
| **restaurant** | Table Management | `restaurant_tables` | `/app/restaurant_tables` | TableManagementScreen | Yes | Yes | Yes |
| **restaurant** | Kitchen / KOT View | `kitchen_display` | `/app/kitchen_display` | KitchenDisplayScreen | Yes | Yes | Yes |
| **restaurant** | Menu Management | `menu_management` | `/app/menu_management` | FoodMenuManagementScreen | Yes | Yes | Yes |
| **restaurant** | Daily Summary | `daily_summary` | `/app/daily_summary` | RestaurantDailySummaryScreen | Yes | Yes | Yes |
| **restaurant** | Quick Bill / Invoice | `new_sale` | `/app/new_sale` | BillCreationScreenV2 | Yes | Yes | Yes |
| **restaurant** | Live Sales | `revenue_overview` | `/app/revenue_overview` | RevenueOverviewScreen | Yes | Yes | Yes |
| **restaurant** | Sales History | `sales_register` | `/app/sales_register` | SalesRegisterScreen | Yes | Yes | Yes |
| **restaurant** | Stock Summary | `stock_summary` | `/app/stock_summary` | StockSummaryScreen | Yes | Yes | Yes |
| **restaurant** | Ingredients Stock | `item_stock` | `/app/item_stock` | InventoryDashboardScreen | Yes | Yes | Yes |
| **restaurant** | Low Stock Alerts | `low_stock` | `/app/low_stock` | LowStockAlertsScreen | Yes | Yes | Yes |
| **petrolPump** | Station Dashboard | `petrol_dashboard` | `/app/petrol_dashboard` | PetrolPumpManagementScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Shift Management | `shift_management` | `/app/shift_management` | ShiftHistoryScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Dispensers / Nozzles | `dispenser_management` | `/app/dispenser_management` | DispenserListScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Tank Levels | `tank_management` | `/app/tank_management` | TankListScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Create Invoice | `new_sale` | `/app/new_sale` | BillCreationScreenV2 | Yes | Yes | Yes |
| **petrolPump** | Revenue Overview | `revenue_overview` | `/app/revenue_overview` | RevenueOverviewScreen | Yes | Yes | Yes |
| **petrolPump** | Sales Register | `sales_register` | `/app/sales_register` | SalesRegisterScreen | Yes | Yes | Yes |
| **petrolPump** | Fuel Rates Config | `fuel_rates` | `/app/fuel_rates` | FuelRatesScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Profit Analysis | `fuel_profit_report` | `/app/fuel_profit_report` | FuelProfitReportScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Nozzle Sales | `nozzle_sales_report` | `/app/nozzle_sales_report` | NozzleSalesReportScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Shift Reports | `shift_report` | `/app/shift_report` | ShiftReportScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **petrolPump** | Tank Stock | `tank_stock_report` | `/app/tank_stock_report` | TankStockReportScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Executive Dashboard | `executive_dashboard` | `/app/executive_dashboard` | DashboardController | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Live Business Health | `live_health` | `/app/live_health` | LiveBusinessHealthScreen | Yes | Yes | Yes |
| **retail** | Alerts & Notifications | `alerts` | `/app/alerts` | AlertsNotificationsScreen | Yes | Yes | Yes |
| **retail** | Daily Snapshot | `daily_snapshot` | `/app/daily_snapshot` | DailySnapshotScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Revenue Overview | `revenue_overview` | `/app/revenue_overview` | RevenueOverviewScreen | Yes | Yes | Yes |
| **retail** | Invoice / Bill Creation | `new_sale` | `/app/new_sale` | BillCreationScreenV2 | Yes | Yes | Yes |
| **retail** | Receipt Entry | `receipt_entry` | `/app/receipt_entry` | ReceiptEntryScreen | Yes | Yes | Yes |
| **retail** | Return Inwards | `return_inwards` | `/app/return_inwards` | ReturnInwardsScreen | Yes | Yes | Yes |
| **retail** | Proforma & Bids | `proforma_bids` | `/app/proforma_bids` | ProformaScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Booking Orders | `booking_orders` | `/app/booking_orders` | BookingOrderScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Dispatch Notes | `dispatch_notes` | `/app/dispatch_notes` | DispatchNoteScreen | Yes | Yes | Yes |
| **retail** | Sales Register | `sales_register` | `/app/sales_register` | SalesRegisterScreen | Yes | Yes | Yes |
| **retail** | BuyFlow Dashboard | `buyflow_dashboard` | `/app/buyflow_dashboard` | BuyFlowDashboard | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Purchase Orders | `purchase_orders` | `/app/purchase_orders` | BuyOrdersScreen | Yes | Yes | Yes |
| **retail** | Stock Entry | `stock_entry` | `/app/stock_entry` | StockEntryScreen | Yes | Yes | Yes |
| **retail** | Stock Reversal | `stock_reversal` | `/app/stock_reversal` | StockReversalScreen | Yes | Yes | Yes |
| **retail** | Procurement Log | `procurement_log` | `/app/procurement_log` | ProcurementLogScreen | Yes | Yes | Yes |
| **retail** | Supplier Bills | `supplier_bills` | `/app/supplier_bills` | SupplierBillsScreen | Yes | Yes | Yes |
| **retail** | Purchase Register | `purchase_register` | `/app/purchase_register` | ProcurementLogScreen | Yes | Yes | Yes |
| **retail** | Stock Summary | `stock_summary` | `/app/stock_summary` | StockSummaryScreen | Yes | Yes | Yes |
| **retail** | Item-wise Stock | `item_stock` | `/app/item_stock` | InventoryDashboardScreen | Yes | Yes | Yes |
| **retail** | Batch / Variant Tracking | `batch_tracking` | `/app/batch_tracking` | BatchTrackingScreen | Yes | Yes | Yes |
| **retail** | Low Stock Alerts | `low_stock` | `/app/low_stock` | LowStockAlertsScreen | Yes | Yes | Yes |
| **retail** | Stock Valuation | `stock_valuation` | `/app/stock_valuation` | StockValuationScreen | Yes | Yes | Yes |
| **retail** | Damage / Adjustment | `damage_logs` | `/app/damage_logs` | DamageLogsScreen | Yes | Yes | Yes |
| **retail** | Customers | `customers` | `/app/customers` | CustomersListScreen | Yes | Yes | Yes |
| **retail** | Suppliers | `suppliers` | `/app/suppliers` | PartyLedgerListScreen | Yes | Yes | Yes |
| **retail** | Party Ledger | `party_ledger` | `/app/party_ledger` | PartyLedgerListScreen | Yes | Yes | Yes |
| **retail** | Master Ledger History | `ledger_history` | `/app/ledger_history` | AllTransactionsScreen | Yes | Yes | Yes |
| **retail** | Ledger Abstract | `ledger_abstract` | `/app/ledger_abstract` | TrialBalanceScreen | Yes | Yes | Yes |
| **retail** | Outstanding Reports | `outstanding` | `/app/outstanding` | PartyLedgerListScreen | Yes | Yes | Yes |
| **retail** | Analytics Hub | `analytics_hub` | `/app/analytics_hub` | ReportsHubScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Turnover Analysis | `turnover_analysis` | `/app/turnover_analysis` | AllTransactionsScreen | Yes | Yes | Yes |
| **retail** | Product Performance | `product_performance` | `/app/product_performance` | ProductPerformanceScreen | Yes | Yes | Yes |
| **retail** | Daily Activity Register | `daily_activity` | `/app/daily_activity` | AllTransactionsScreen | Yes | Yes | Yes |
| **retail** | Procurement Insights | `procurement_insights` | `/app/procurement_insights` | PurchaseReportScreen | Yes | Yes | Yes |
| **retail** | Margin Analysis | `margin_analysis` | `/app/margin_analysis` | BillWiseProfitScreen | Yes | Yes | Yes |
| **retail** | AI Insights | `insights` | `/app/insights` | InsightsScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Share Catalogue | `catalogue` | `/app/catalogue` | CatalogueScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Invoice Margin View | `invoice_margin` | `/app/invoice_margin` | PnlScreen | Yes | Yes | Yes |
| **retail** |  | `income_statement` | `/app/income_statement` | PnlScreen | Yes | Yes | Yes |
| **retail** | Funds Flow Analysis | `funds_flow` | `/app/funds_flow` | CashflowScreen | Yes | Yes | Yes |
| **retail** | Financial Position | `financial_position` | `/app/financial_position` | BalanceScreen | Yes | Yes | Yes |
| **retail** | Cash / Bank Summary | `cash_bank` | `/app/cash_bank` | CashflowScreen | Yes | Yes | Yes |
| **retail** | Trial Balance / P&L | `accounting_reports` | `/app/accounting_reports` | AccountingReportsScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Bank Accounts | `bank_accounts` | `/app/bank_accounts` | BankScreen | Yes | Yes | Yes |
| **retail** | Day Book | `daybook` | `/app/daybook` | DayBookScreen | Yes | Yes | Yes |
| **retail** | Credit Notes | `credit_notes` | `/app/credit_notes` | CreditNotesListScreen | Yes | Yes | Yes |
| **retail** | Expenses | `expenses` | `/app/expenses` | ExpensesScreen | Yes | Yes | Yes |
| **retail** | GSTR-1 Reports | `gstr1` | `/app/gstr1` | GstReportsScreen | Yes | Yes | Yes |
| **retail** | B2B / B2C Summary | `b2b_b2c` | `/app/b2b_b2c` | GstReportsScreen | Yes | Yes | Yes |
| **retail** | HSN Reports | `hsn_reports` | `/app/hsn_reports` | GstReportsScreen | Yes | Yes | Yes |
| **retail** | Tax Liability | `tax_liability` | `/app/tax_liability` | GstReportsScreen | Yes | Yes | Yes |
| **retail** | Filing Readiness | `filing_status` | `/app/filing_status` | GstReportsScreen | Yes | Yes | Yes |
| **retail** | Transaction Reports | `transaction_reports` | `/app/transaction_reports` | AllTransactionsScreen | Yes | Yes | Yes |
| **retail** | Master Activity Logs | `activity_logs` | `/app/activity_logs` | AllTransactionsScreen | Yes | Yes | Yes |
| **retail** | Audit Trail | `audit_trail` | `/app/audit_trail` | AllTransactionsScreen | Yes | Yes | Yes |
| **retail** | Error & Sync Logs | `error_logs` | `/app/error_logs` | ErrorLogsScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Print Settings | `print_settings` | `/app/print_settings` | PrintMenuScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Document Templates | `doc_templates` | `/app/doc_templates` | PrintMenuScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Backup & Restore | `backup` | `/app/backup` | BackupScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Sync Status | `sync_status` | `/app/sync_status` | BackupScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **retail** | Device Settings | `device_settings` | `/app/device_settings` | DeviceSettingsScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **service** | Overview | `executive_dashboard` | `/app/executive_dashboard` | DashboardController | Yes | Yes | Partial (Mocked or Unconnected) |
| **service** | Daily Activity | `daily_activity` | `/app/daily_activity` | AllTransactionsScreen | Yes | Yes | Yes |
| **service** | Daily Snapshot | `daily_snapshot` | `/app/daily_snapshot` | DailySnapshotScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **service** | Create Invoice | `new_sale` | `/app/new_sale` | BillCreationScreenV2 | Yes | Yes | Yes |
| **service** | Revenue Overview | `revenue_overview` | `/app/revenue_overview` | RevenueOverviewScreen | Yes | Yes | Yes |
| **service** | Receipt Entry | `receipt_entry` | `/app/receipt_entry` | ReceiptEntryScreen | Yes | Yes | Yes |
| **service** | Invoice History | `sales_register` | `/app/sales_register` | SalesRegisterScreen | Yes | Yes | Yes |
| **service** | Quotes / Estimates | `proforma_bids` | `/app/proforma_bids` | ProformaScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **service** | Service Jobs | `service_jobs` | `/app/service_jobs` | ServiceJobListScreen | Yes | Yes | Partial (Mocked or Unconnected) |
| **service** | Device Exchanges | `exchanges` | `/app/exchanges` | ExchangeListScreen | Yes | Yes | Partial (Mocked or Unconnected) |
