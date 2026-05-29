# Project_Scan_Report — Unified Notification System (Phase 1)

> **Phase 1 deliverable** for the Unified Notification System (UNS) spec at `.kiro/specs/unified-notification-system/`.
> Validates **Requirement 1.1 – 1.12** (and 1.11a) of `requirements.md`.
> Produced by scanning the live workspace; every entry is grounded in a real file or symbol that exists today.

## Table of Contents

1. [Scope and Method](#1-scope-and-method)
2. [Architecture_Overview](#2-architecture_overview)
3. [Tech_Stack](#3-tech_stack)
4. [Sub_Apps](#4-sub_apps)
5. [Flutter Screen Inventory (per app, per feature)](#5-flutter-screen-inventory-per-app-per-feature)
6. [Backend Module / Service / Controller / Endpoint Inventory](#6-backend-module--service--controller--endpoint-inventory)
7. [Cross-Module End-to-End Workflows](#7-cross-module-end-to-end-workflows)
8. [Existing Notification Helpers, Emitters, Webhooks, Sockets, Pub/Sub](#8-existing-notification-helpers-emitters-webhooks-sockets-pubsub)
9. [Trigger_Point Catalogue](#9-trigger_point-catalogue)
10. [Roles and Candidate Events](#10-roles-and-candidate-events)
11. [Gaps](#11-gaps)
12. [Phase-2 Hand-off Notes](#12-phase-2-hand-off-notes)

---

## 1. Scope and Method

The scan covers everything under the workspace root `g:\desktop app genuine\` except:

- `node_modules/` (every level)
- `.archive/` (archived restaurant POS / chef apps and old logs)
- `dukan_customer_app/`, `dukan_restro_pwa/`, `staff_petrol_pump_app/` (out-of-scope for this phase per the requirements; see Gaps for tracking)
- `tests/`, `test-results/`, `playwright-report/`, `graphify-out/`, `RID_SYSTEM/`, `ECOSYSTEM_MIGRATION/`, `local-cloud/`, `cloudformation/`, `docs/`

In-scope code roots:

- **Flutter**: `Dukan_x/lib/`, `school_admin_app/lib/`, `school_student_app/lib/`, `school_teacher_app/lib/`
- **Backend**: `my-backend/src/`, `voice-backend/`, `lambda/`, `lambda/staff-attendance/`

The scan was performed by enumerating every `.dart`, `.ts`, `.js`, `.mjs`, and `.py` file under those roots, then targeted searching for: notification helpers, websocket broadcasts, EventDispatcher dispatches, EventBridge / SNS publishes, SMS/Email/Push send sites, and notifications repositories. Every Trigger_Point and notification-helper entry below cites a real file path and symbol.

---

## 2. Architecture_Overview

**Classification: API-first hybrid (mostly serverless microservices on AWS, with one optional Python sidecar).**

The workspace is **not a monolith** and **not a single microservices mesh** in the traditional sense. It is an **API-first, multi-tenant SaaS** built on AWS serverless primitives. The architecture splits into four cooperating layers:

| Layer | Where | Style | Notes |
|---|---|---|---|
| **Flutter desktop (DukanX)** | `Dukan_x/lib/` | Single Flutter desktop app (Windows-first) with a client-side feature-module structure under `lib/features/<domain>/`. Uses Riverpod + GetIt (`sl<T>()`) DI, Drift (SQLite) for local cache, and the DukanX REST/WebSocket client for sync. | Not a microservice; it's the primary client for shopkeepers. |
| **Flutter sub-apps** | `school_admin_app/lib/`, `school_student_app/lib/`, `school_teacher_app/lib/` | Three independent Flutter mobile apps that share the same Cognito JWT auth and the `my-backend` REST API. Each has its own `school_ws_service.dart` that connects to the existing API Gateway WebSocket. | Sub-apps. Designed to plug into the same backend that DukanX uses. |
| **Backend `my-backend/`** | `my-backend/src/` | TypeScript on **AWS Lambda** behind **API Gateway HTTP API**, persisting to **DynamoDB**. Modular: handlers under `src/handlers/`, business logic under `src/services/`, DynamoDB access under `src/dynamodb/` and `src/repositories/`, middleware under `src/middleware/`. The school-ERP, restaurant, and pharmacy domains are isolated under `src/handlers/modules/<domain>/`. | This is the canonical backend for every Flutter app in scope. **API-first**, **microservices-shaped** (one Lambda per concern), single-DynamoDB-table-per-domain pattern with composite `(PK, SK)` keys. |
| **Backend `lambda/`** | `lambda/<service>/index.mjs` and `lambda/staff-attendance/`, `lambda/staff-management/`, `lambda/marketplace/` | A second tier of Node.js Lambdas (mostly `.mjs`) for cross-cutting concerns: customer auth/onboarding/streams (`customerHandler/`, `customerStreamProcessor/`, `customerWsHandler/`), trial/subscription lifecycle (`trialExpiryCronHandler/`, `trialNotificationSchedulerHandler/`, `trialProvisioningHandler/`), shared helpers (`shared/utils.mjs`, `shared/audit-logger.mjs`), and several Petrol-Pump and Marketplace handlers. | Older, parallel handlers maintained alongside `my-backend/`. They share the same Cognito user pool and DynamoDB account as `my-backend/`. **`lambda/marketplace/wsHandler/index.ts` already does WebSocket broadcasting for marketplace orders/deliveries.** **`lambda/staff-attendance/` already publishes `LEAVE_PROCESSED`, `STAFF_CHECKED_IN`, `STAFF_CHECKED_OUT` over WebSocket.** |
| **Voice sidecar `voice-backend/`** | Python (FastAPI / Flask hybrid) | An AI/voice agent (`voice_agent.py`, `dialogue_manager.py`, `nlu_engine.py`, `query_engine.py`, `bill_processor.py`, `app/main.py`) used as a side-car for AI assistant flows. Reads/writes via DynamoDB and the same auth tokens as `my-backend/`. Not currently a notification producer in production; it could become one in Phase 4. | Optional sidecar. Out-of-band of the main HTTP path. |

**Real-time today (already in production):**

- **AWS API Gateway WebSocket** is the single transport. The connection registry, fan-out, and per-tenant routing live in `my-backend/src/services/websocket.service.ts` (with type definitions in `my-backend/src/types/websocket.types.ts`) and the WebSocket Lambda is `my-backend/src/handlers/websocket.ts` (connect/disconnect/default, reused by `lambda/staff-attendance/src/handlers/websocketConnect.ts` and friends).
- **EventBridge** is wired in `my-backend/src/services/eventbridge.service.ts` and consumed by `my-backend/src/handlers/ws-broadcaster.ts`. Each event name (`WSEventName` enum) maps to an `EB_SOURCES` value; the broadcaster Lambda fans the event out to the right WebSocket audience (`business`, `staff`, `customer`, `owner`, `client_type`).
- **SNS** is used **only** for trial-lifecycle messages (`lambda/trialExpiryCronHandler/`, `lambda/trialNotificationSchedulerHandler/`, `lambda/trialProvisioningHandler/`) and as an FCM topic ARN consumed by `my-backend/src/handlers/in-store-streams.ts` (`FCM_SNS_TOPIC_ARN`). It is **not** the canonical event bus.
- **Per-process broadcast Stream** (Dart `StreamController.broadcast()`) is the *offline / single-machine* event bus inside DukanX, accessed through `Dukan_x/lib/core/services/event_dispatcher.dart` (`EventDispatcher.instance`). This is the in-app loose-coupling glue used by `bills_repository.dart`, `products_repository.dart`, `service_job_notification_service.dart`, `customer_payment_screen.dart`, etc.
- **Drift / SQLite** is the per-device persisted notification store for DukanX (`customer_notifications` table consumed by both `CustomerNotificationsRepository` and `VendorNotificationRepository`).

**Conclusion for UNS design**: there is already a partial notification mesh — three independent transports (WebSocket, EventBridge, in-process StreamController), plus several persistence stores (DynamoDB `NOTIF#<userId>` partition for school ERP, Drift `customer_notifications` table for DukanX, none for the school sub-apps which only buffer in-memory), plus several point delivery helpers (FCM via SNS, SES via `academic_coaching.ts`, Twilio-style SMS via SNS, WhatsApp Business API via `whatsapp.service.ts`). UNS will unify these.

There are **no `TODO` or `unknown` entries** in this Architecture_Overview section.

---

## 3. Tech_Stack

| Concern | Choice | Reference |
|---|---|---|
| Frontend framework | **Flutter** (desktop + mobile) | `Dukan_x/pubspec.yaml`, `school_admin_app/pubspec.yaml`, `school_student_app/pubspec.yaml`, `school_teacher_app/pubspec.yaml` |
| Frontend state mgmt | Riverpod + GetIt (`sl<T>()` service locator) | `Dukan_x/lib/core/di/service_locator.dart`, `school_*_app/lib/core/...` |
| Frontend local DB | **Drift** (SQLite) | `Dukan_x/lib/core/database/app_database.dart`, `customer_notifications` table |
| Backend runtime | **Node.js 18+ on AWS Lambda**, TypeScript (`my-backend/`) and ES-modules JavaScript (`lambda/*.mjs`) | `my-backend/package.json`, `lambda/package.json` |
| Backend HTTP transport | **API Gateway HTTP API v2** | `my-backend/src/handlers/*.ts` use `APIGatewayProxyHandlerV2` |
| Backend WebSocket | **API Gateway WebSocket API** | `my-backend/src/handlers/websocket.ts`, `my-backend/src/services/websocket.service.ts`, `lambda/marketplace/wsHandler/index.ts`, `lambda/staff-attendance/src/handlers/websocketConnect.ts` |
| Database | **DynamoDB** (single-table-per-domain, composite `PK + SK`) | `my-backend/src/config/dynamodb.config.ts`, `my-backend/src/dynamodb/keys.ts` |
| Auth | **AWS Cognito** + JWT bearer | `my-backend/src/middleware/cognito-auth.ts`, `my-backend/src/handlers/auth.ts`, `lambda/cognitoPreTokenTrigger/`, `lambda/customerAuthorizerHandler/` |
| Pub/sub (server) | **EventBridge** (canonical) + **SNS** (trial-lifecycle + FCM topic only) + **WebSocket fan-out** | `my-backend/src/services/eventbridge.service.ts`, `my-backend/src/handlers/ws-broadcaster.ts`, `lambda/trial*Handler/` |
| Push | **Firebase Cloud Messaging** via SNS topic (`FCM_SNS_TOPIC_ARN`) | `my-backend/src/handlers/in-store-streams.ts` |
| Email | **AWS SES** (via `@aws-sdk/client-ses`) | `my-backend/src/handlers/academic_coaching.ts` (`sendEmailViaSes`) |
| SMS | **AWS SNS Publish** to `phoneNumber` (transactional) | `my-backend/src/handlers/academic_coaching.ts` (`sendSmsViaSns`) |
| WhatsApp | **WhatsApp Cloud API** | `my-backend/src/services/whatsapp.service.ts`, used by `my-backend/src/handlers/suppliers.ts`, `my-backend/src/services/post-payment.service.ts`, `my-backend/src/handlers/academic_coaching.ts` |
| In-app local notification (Flutter) | **`flutter_local_notifications`** | `Dukan_x/lib/features/restaurant/domain/services/restaurant_notification_service.dart`, `Dukan_x/lib/core/services/notification_controller.dart` |
| Push registration (Flutter) | **`firebase_messaging`** | `Dukan_x/lib/core/services/notification_controller.dart` (`FirebaseMessaging.instance`) |
| Localization | **Dukan_x/lib/core/localization/** + `my-backend/src/i18n/notification-templates.ts` for server-side localized push/SMS/email | `my-backend/src/i18n/notification-templates.ts` |
| Voice / AI sidecar | **Python 3** (FastAPI/Flask) | `voice-backend/main.py`, `voice-backend/app/main.py` |
| IaC | **AWS SAM** (`template.yaml`) + custom CloudFormation under `cloudformation/` | `template.yaml`, `cloudformation/` |
| Test (backend) | **Jest** (`my-backend/src/__tests__/*.test.ts`, `lambda/staff-attendance/jest.config.js`) | `my-backend/jest.config.cjs` (implied) |
| Test (Flutter) | **flutter_test** + **glados** (Dart property-based) where applicable | `Dukan_x/test/` |
| E2E | **Playwright** | `playwright.config.ts`, `tests/e2e/`, `tests/visual/` |

There are **no `TODO` or `unknown` entries** in this Tech_Stack section.

---

## 4. Sub_Apps

| Sub_App | Primary domain | `pubspec.yaml` location | Auth mechanism with Backend |
|---|---|---|---|
| **DukanX** (the desktop core) | Multi-vertical billing, inventory, customers, payments, jewellery, restaurant, clinic, pharmacy, academic_coaching, auto_parts, computer_shop, clothing, hardware, decoration_catering, vegetable_broker, delivery_challan, purchase, revenue, refund, service warranty, petrol pump | `Dukan_x/pubspec.yaml` | **Cognito JWT** bearer token issued by `my-backend/src/handlers/auth.ts`. The token is acquired by `Dukan_x/lib/auth/` flows, stored in `core/session/session_manager.dart`, and attached by `Dukan_x/lib/core/api/api_client.dart`. The same JWT also authenticates the WebSocket connection via `Dukan_x/lib/core/services/websocket_service.dart` → `Dukan_x/lib/services/websocket_service.dart`. |
| **school_admin_app** | School administration: students, faculty, classes, fees, attendance, leave, transport, library, hostel, payroll, admissions, announcements, reports, settings | `school_admin_app/pubspec.yaml` | **Cognito JWT** bearer token issued by `my-backend/src/handlers/auth.ts` (same Cognito user pool, role `school_admin`). API calls go through `school_admin_app/lib/core/network/`, WebSocket through `school_admin_app/lib/core/websocket/school_ws_service.dart`. |
| **school_teacher_app** | Teacher daily ops: attendance marking, homework, lesson plans, materials, exams, leave, announcements, payslip, students, timetable, profile | `school_teacher_app/pubspec.yaml` | **Cognito JWT** bearer token (same pool, role `teacher`). API client and WebSocket service mirror the admin app at `school_teacher_app/lib/core/`. |
| **school_student_app** | Student/parent self-service: attendance view, homework, fees, fee payment, leave application, library, materials, notifications, profile, results, timetable, transport, exams | `school_student_app/pubspec.yaml` | **Cognito JWT** bearer token (same pool, role `student`/`parent`). Notification screen at `school_student_app/lib/features/notifications/screens/notifications_screen.dart` already pulls from a `notificationsProvider`. WebSocket through `school_student_app/lib/core/websocket/school_ws_service.dart`. |

The four apps **share the same Cognito user pool, the same DynamoDB account, and the same API Gateway**. There is no per-sub-app auth divergence: the role on the JWT determines access (`my-backend/src/middleware/role-guard.ts`, `my-backend/src/middleware/permission-guard.ts`).

There are **no `TODO` or `unknown` entries** in this Sub_Apps section.

---

## 5. Flutter Screen Inventory (per app, per feature)

> Screens were enumerated by globbing `**/*_screen.dart` under each app's `lib/`. `Dukan_x/lib/screens/` and `Dukan_x/lib/screens/sale/` are legacy top-level screens kept for migration compatibility; all newer screens live under `lib/features/<domain>/presentation/screens/` or `lib/features/<domain>/screens/`.

### 5.1 `Dukan_x/lib/`

#### Top-level / shared
- `app/startup_error_screen.dart`
- `core/auth/auth_error_screen.dart`
- `core/auth/auth_loading_screen.dart`
- `core/module/module_placeholder_screen.dart`
- `screens/admin_migrations_screen.dart`
- `screens/advanced_bill_creation_screen.dart`
- `screens/advanced_billing_screen.dart`
- `screens/app_management_screen.dart`
- `screens/bill_search_screen.dart`
- `screens/billing_reports_screen.dart`
- `screens/blacklist_management_screen.dart`
- `screens/business_type_selection_screen.dart`
- `screens/cloud_sync_settings_screen.dart`
- `screens/create_invoice_screen.dart`
- `screens/customer_edit_screen.dart`
- `screens/customer_home_screen.dart`
- `screens/customer_link_accept_screen.dart`
- `screens/customer_link_shop_screen.dart`
- `screens/customer_report_screen.dart`
- `screens/developer_health_screen.dart`
- `screens/dukanx_splash_screen.dart`
- `screens/edit_bill_screen.dart`
- `screens/edit_customer_screen.dart`
- `screens/editable_invoice_screen.dart`
- `screens/invoice_preview_screen.dart`
- `screens/owner_bill_list_screen.dart`
- `screens/owner_link_screen.dart`
- `screens/payment_dialog_screen.dart`
- `screens/payment_history_screen.dart`
- `screens/payment_management_screen.dart`
- `screens/pending_dues_screen.dart`
- `screens/pending_screen.dart`
- `screens/professional_startup_screen.dart`
- `screens/real_sync_screen.dart`
- `screens/sale/sale_home_screen.dart`
- `screens/shop_management_screen.dart`
- `screens/shop_selection_screen.dart`
- `screens/total_bills_screen.dart`
- `screens/total_paid_screen.dart`
- `screens/vendor_qr_code_screen.dart`

#### Feature: `academic_coaching`
- `features/academic_coaching/presentation/screens/ac_academic_year_screen.dart`
- `features/academic_coaching/presentation/screens/ac_admissions_screen.dart`
- `features/academic_coaching/presentation/screens/ac_attendance_screen.dart`
- `features/academic_coaching/presentation/screens/ac_batches_screen.dart`
- `features/academic_coaching/presentation/screens/ac_bulk_operations_screen.dart`
- `features/academic_coaching/presentation/screens/ac_certificate_generator_screen.dart`
- `features/academic_coaching/presentation/screens/ac_class_sections_screen.dart`
- `features/academic_coaching/presentation/screens/ac_classwise_fee_screen.dart`
- `features/academic_coaching/presentation/screens/ac_courses_screen.dart`
- `features/academic_coaching/presentation/screens/ac_dashboard_screen.dart`
- `features/academic_coaching/presentation/screens/ac_documents_screen.dart`
- `features/academic_coaching/presentation/screens/ac_exams_screen.dart`
- `features/academic_coaching/presentation/screens/ac_faculty_screen.dart`
- `features/academic_coaching/presentation/screens/ac_fee_collection_screen.dart`
- `features/academic_coaching/presentation/screens/ac_financial_reports_screen.dart`
- `features/academic_coaching/presentation/screens/ac_homework_screen.dart`
- `features/academic_coaching/presentation/screens/ac_hostel_screen.dart`
- `features/academic_coaching/presentation/screens/ac_id_cards_screen.dart`
- `features/academic_coaching/presentation/screens/ac_inventory_screen.dart`
- `features/academic_coaching/presentation/screens/ac_leave_screen.dart`
- `features/academic_coaching/presentation/screens/ac_lesson_plans_screen.dart`
- `features/academic_coaching/presentation/screens/ac_library_screen.dart`
- `features/academic_coaching/presentation/screens/ac_materials_screen.dart`
- `features/academic_coaching/presentation/screens/ac_notifications_screen.dart` *(legacy notification helper UI — listed in §8)*
- `features/academic_coaching/presentation/screens/ac_payments_screen.dart`
- `features/academic_coaching/presentation/screens/ac_report_cards_screen.dart`
- `features/academic_coaching/presentation/screens/ac_reports_screen.dart`
- `features/academic_coaching/presentation/screens/ac_risk_detection_screen.dart`
- `features/academic_coaching/presentation/screens/ac_sibling_screen.dart`
- `features/academic_coaching/presentation/screens/ac_student_registration_screen.dart`
- `features/academic_coaching/presentation/screens/ac_students_screen.dart`
- `features/academic_coaching/presentation/screens/ac_timetable_screen.dart`
- `features/academic_coaching/presentation/screens/ac_transport_screen.dart`

#### Feature: `accounting`
- `features/accounting/screens/accounting_reports_screen.dart`

#### Feature: `ai_assistant`
- `features/ai_assistant/presentation/screens/desktop_ai_assistant_screen.dart`

#### Feature: `alerts`
- `features/alerts/presentation/screens/alerts_notifications_screen.dart` *(legacy notification UI — see §8)*
- `features/alerts/presentation/screens/alerts_screen.dart`

#### Feature: `analytics`
- `features/analytics/analytics_dashboard_screen.dart`

#### Feature: `auth`
- `features/auth/presentation/screens/customer_auth_screen.dart`
- `features/auth/presentation/screens/forgot_password_screen.dart`
- `features/auth/presentation/screens/license_screen.dart`
- `features/auth/presentation/screens/otp_screen.dart`
- `features/auth/presentation/screens/pin_login_screen.dart`
- `features/auth/presentation/screens/pin_setup_screen.dart`
- `features/auth/presentation/screens/vendor_auth_screen.dart`

#### Feature: `auto_parts`
- `features/auto_parts/presentation/screens/job_card_management_screen.dart`

#### Feature: `avatar`
- `features/avatar/presentation/screens/avatar_editor_screen.dart`

#### Feature: `backup`
- `features/backup/screens/backup_screen.dart`

#### Feature: `bank`
- `features/bank/presentation/screens/bank_detail_screen.dart`
- `features/bank/presentation/screens/bank_screen.dart`

#### Feature: `barcode`
- `features/barcode/presentation/screens/barcode_label_printing_screen.dart`
- `features/barcode/presentation/screens/quick_bill_with_barcode_screen.dart`

#### Feature: `billing`
- `features/billing/presentation/screens/advanced_bill_creation_screen.dart`
- `features/billing/presentation/screens/advanced_billing_screen.dart`
- `features/billing/presentation/screens/bill_scan_screen.dart`
- `features/billing/presentation/screens/bill_search_screen.dart`
- `features/billing/presentation/screens/billing_reports_screen.dart`
- `features/billing/presentation/screens/create_invoice_screen.dart`
- `features/billing/presentation/screens/credit_note_screen.dart`
- `features/billing/presentation/screens/desktop_invoices_screen.dart`
- `features/billing/presentation/screens/edit_bill_screen.dart`
- `features/billing/presentation/screens/editable_invoice_screen.dart`
- `features/billing/presentation/screens/invoice_preview_screen.dart`
- `features/billing/presentation/screens/owner_bill_list_screen.dart`
- `features/billing/presentation/screens/return_bill_screen.dart`
- `features/billing/presentation/screens/total_bills_screen.dart`
- `features/billing/screens/bills_list_screen.dart`
- `features/billing/screens/dunning_config_screen.dart`
- `features/billing/screens/manage_subscriptions_screen.dart`

#### Feature: `book_store`
- `features/book_store/presentation/screens/book_inventory_screen.dart`
- `features/book_store/presentation/screens/book_pos_screen.dart`
- `features/book_store/presentation/screens/book_supplier_returns_screen.dart`
- `features/book_store/presentation/screens/consignment_settlement_screen.dart`
- `features/book_store/presentation/screens/school_order_screen.dart`

#### Feature: `buy_flow`
- `features/buy_flow/screens/buy_orders_screen.dart`
- `features/buy_flow/screens/procurement_log_screen.dart`
- `features/buy_flow/screens/stock_entry_screen.dart`
- `features/buy_flow/screens/stock_reversal_screen.dart`
- `features/buy_flow/screens/supplier_bills_screen.dart`
- `features/buy_flow/screens/vendor_payouts_screen.dart`

#### Feature: `cash_closing`
- `features/cash_closing/presentation/screens/day_end_close_screen.dart`

#### Feature: `catalogue`
- `features/catalogue/presentation/screens/catalogue_screen.dart`

#### Feature: `clinic`
- `features/clinic/presentation/screens/clinic_calendar_screen.dart`
- `features/clinic/presentation/screens/consultation_screen.dart`
- `features/clinic/presentation/screens/lab_order_screen.dart`
- `features/clinic/presentation/screens/patient_history_screen.dart`
- `features/clinic/presentation/screens/patient_management_screen.dart`
- `features/clinic/presentation/screens/patient_queue_screen.dart`
- `features/clinic/screens/clinic_dashboard_screen.dart`

#### Feature: `clothing`
- `features/clothing/presentation/screens/clothing_inventory_screen.dart`
- `features/clothing/presentation/screens/tailoring_measurements_screen.dart`
- `features/clothing/presentation/screens/variant_management_screen.dart`

#### Feature: `computer_shop`
- `features/computer_shop/presentation/screens/create_job_card_screen.dart`
- `features/computer_shop/presentation/screens/job_card_detail_screen.dart`
- `features/computer_shop/presentation/screens/job_card_list_screen.dart`
- `features/computer_shop/presentation/screens/multi_unit_screen.dart`
- `features/computer_shop/presentation/screens/serial_history_screen.dart`
- `features/computer_shop/presentation/screens/warranty_screen.dart`

#### Feature: `credit_notes`
- `features/credit_notes/presentation/screens/credit_note_screen.dart`

#### Feature: `customers`
- `features/customers/presentation/screens/add_customer_screen.dart`
- `features/customers/presentation/screens/customer_dashboard_screen.dart`
- `features/customers/presentation/screens/customer_detail_screen.dart`
- `features/customers/presentation/screens/customer_home_screen.dart`
- `features/customers/presentation/screens/customer_invoice_list_screen.dart`
- `features/customers/presentation/screens/customer_ledger_screen.dart`
- `features/customers/presentation/screens/customer_management_screen.dart`
- `features/customers/presentation/screens/customer_notifications_screen.dart` *(legacy notification UI — see §8)*
- `features/customers/presentation/screens/customer_payment_screen.dart`
- `features/customers/presentation/screens/customer_profile_screen.dart`
- `features/customers/presentation/screens/customers_list_screen.dart`
- `features/customers/presentation/screens/edit_profile_screen.dart`
- `features/customers/presentation/screens/my_linked_shops_screen.dart`
- `features/customers/presentation/screens/my_shops_screen.dart`
- `features/customers/presentation/screens/notification_settings_screen.dart` *(legacy preferences UI — see §8)*
- `features/customers/presentation/screens/security_settings_screen.dart`

#### Feature: `dashboard`
- `features/dashboard/presentation/screens/business_profile_screen.dart`
- `features/dashboard/presentation/screens/daily_snapshot_screen.dart`
- `features/dashboard/presentation/screens/dashboard_selection_screen.dart`
- `features/dashboard/presentation/screens/home_screen.dart`
- `features/dashboard/presentation/screens/live_business_health_screen.dart`
- `features/dashboard/presentation/screens/manage_business_screen.dart`
- `features/dashboard/presentation/screens/owner_dashboard_screen.dart`
- `features/dashboard/v2/screens/dashboard_v2_screen.dart`
- `features/dashboard/v2/screens/pharmacy_dashboard_screen.dart`

#### Feature: `daybook`
- `features/daybook/presentation/screens/day_book_screen.dart`

#### Feature: `decoration_catering`
- `features/decoration_catering/presentation/screens/dc_billing_screen.dart`
- `features/decoration_catering/presentation/screens/dc_bookings_screen.dart`
- `features/decoration_catering/presentation/screens/dc_calendar_screen.dart`
- `features/decoration_catering/presentation/screens/dc_catering_screen.dart`
- `features/decoration_catering/presentation/screens/dc_dashboard_screen.dart`
- `features/decoration_catering/presentation/screens/dc_decoration_screen.dart`
- `features/decoration_catering/presentation/screens/dc_event_detail_screen.dart`
- `features/decoration_catering/presentation/screens/dc_inventory_screen.dart`
- `features/decoration_catering/presentation/screens/dc_profitability_screen.dart`
- `features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart`
- `features/decoration_catering/presentation/screens/dc_quotes_screen.dart`
- `features/decoration_catering/presentation/screens/dc_reports_screen.dart`
- `features/decoration_catering/presentation/screens/dc_shopping_list_screen.dart`
- `features/decoration_catering/presentation/screens/dc_staff_attendance_screen.dart`
- `features/decoration_catering/presentation/screens/dc_staff_screen.dart`
- `features/decoration_catering/presentation/screens/dc_vendor_payments_screen.dart`

#### Feature: `delivery_challan`
- `features/delivery_challan/presentation/screens/create_delivery_challan_screen.dart`
- `features/delivery_challan/presentation/screens/delivery_challan_list_screen.dart`

#### Feature: `doctor`
- `features/doctor/presentation/screens/add_patient_screen.dart`
- `features/doctor/presentation/screens/add_prescription_screen.dart`
- `features/doctor/presentation/screens/appointment_screen.dart`
- `features/doctor/presentation/screens/doctor_dashboard_screen.dart`
- `features/doctor/presentation/screens/doctor_revenue_screen.dart`
- `features/doctor/presentation/screens/lab_reports_screen.dart`
- `features/doctor/presentation/screens/medicine_master_screen.dart`
- `features/doctor/presentation/screens/patient_history_screen.dart`
- `features/doctor/presentation/screens/patient_list_screen.dart`
- `features/doctor/presentation/screens/prescriptions_list_screen.dart`
- `features/doctor/presentation/screens/refill_data_repair_screen.dart`
- `features/doctor/presentation/screens/refill_queue_screen.dart`
- `features/doctor/presentation/screens/visit_screen.dart`

#### Feature: `document_scanner`
- `features/document_scanner/screens/document_scanner_screen.dart`

#### Feature: `e_invoice`
- `features/e_invoice/presentation/screens/e_invoices_list_screen.dart`

#### Feature: `expenses`
- `features/expenses/presentation/screens/expenses_screen.dart`

#### Feature: `gst`
- `features/gst/screens/gst_reports_screen.dart`
- `features/gst/screens/gst_settings_screen.dart`

#### Feature: `hardware`
- `features/hardware/presentation/screens/hardware_command_center_screen.dart`
- `features/hardware/presentation/screens/hardware_credit_control_screen.dart`
- `features/hardware/presentation/screens/hardware_invoice_profile_screen.dart`
- `features/hardware/presentation/screens/hardware_operations_screen.dart`
- `features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart`
- `features/hardware/presentation/screens/hardware_supplier_management_screen.dart`

#### Feature: `in_store`
- `features/in_store/presentation/screens/active_sessions_screen.dart`
- `features/in_store/presentation/screens/exit_verification_screen.dart`
- `features/in_store/presentation/screens/in_store_orders_screen.dart`

#### Feature: `insights`
- `features/insights/presentation/screens/health_score_detail_screen.dart`
- `features/insights/presentation/screens/insights_screen.dart`

#### Feature: `inventory`
- `features/inventory/presentation/screens/barcode_scanner_screen.dart`
- `features/inventory/presentation/screens/batch_tracking_screen.dart`
- `features/inventory/presentation/screens/categories_screen.dart`
- `features/inventory/presentation/screens/category_products_screen.dart`
- `features/inventory/presentation/screens/damage_logs_screen.dart`
- `features/inventory/presentation/screens/import_inventory_screen.dart`
- `features/inventory/presentation/screens/inventory_dashboard_screen.dart`
- `features/inventory/presentation/screens/low_stock_alerts_screen.dart`
- `features/inventory/presentation/screens/product_management_screen.dart`
- `features/inventory/presentation/screens/stock_adjustment_screen.dart`
- `features/inventory/presentation/screens/stock_summary_screen.dart`
- `features/inventory/presentation/screens/stock_valuation_screen.dart`

#### Feature: `invoice`
- `features/invoice/screens/invoice_preview_screen.dart`
- `features/invoice/screens/invoice_settings_screen.dart`

#### Feature: `jewellery`
- `features/jewellery/presentation/screens/custom_order_management_screen.dart`
- `features/jewellery/presentation/screens/gold_rate_alert_screen.dart`
- `features/jewellery/presentation/screens/gold_rate_management_screen.dart`
- `features/jewellery/presentation/screens/gold_scheme_screen.dart`
- `features/jewellery/presentation/screens/hallmark_inventory_screen.dart`
- `features/jewellery/presentation/screens/jewellery_repair_screen.dart`
- `features/jewellery/presentation/screens/making_charges_calculator_screen.dart`
- `features/jewellery/presentation/screens/old_gold_exchange_screen.dart`

#### Feature: `localization`
- `features/localization/presentation/screens/language_selection_screen.dart`
- `features/localization/presentation/screens/language_setup_screen.dart`

#### Feature: `marketing`
- `features/marketing/presentation/screens/campaigns_list_screen.dart`
- `features/marketing/presentation/screens/create_campaign_screen.dart`

#### Feature: `marketplace`
- `features/marketplace/presentation/screens/order_management_screen.dart`

#### Feature: `onboarding`
- `features/onboarding/login_onboarding_screen.dart`
- `features/onboarding/vendor_onboarding_screen.dart`

#### Feature: `party_ledger`
- `features/party_ledger/screens/add_vendor_screen.dart`
- `features/party_ledger/screens/collect_payment_screen.dart`
- `features/party_ledger/screens/party_ledger_list_screen.dart`
- `features/party_ledger/screens/party_statement_screen.dart`

#### Feature: `patient`
- `features/patient/presentation/screens/medical_records_screen.dart`
- `features/patient/presentation/screens/patient_appointments_screen.dart`
- `features/patient/presentation/screens/patient_home_screen.dart`

#### Feature: `patients`
- `features/patients/screens/patient_detail_screen.dart`
- `features/patients/screens/patient_list_screen.dart`
- `features/patients/screens/patient_registration_screen.dart`

#### Feature: `payment`
- `features/payment/presentation/screens/payment_analytics_screen.dart`
- `features/payment/presentation/screens/payment_gateway_settings_screen.dart`
- `features/payment/presentation/screens/payments_history_screen.dart`

#### Feature: `petrol_pump`
- `features/petrol_pump/presentation/screens/add_staff_screen.dart`
- `features/petrol_pump/presentation/screens/dispenser_list_screen.dart`
- `features/petrol_pump/presentation/screens/fuel_rates_screen.dart`
- `features/petrol_pump/presentation/screens/petrol_pump_management_screen.dart`
- `features/petrol_pump/presentation/screens/reports/ca_report_screen.dart`
- `features/petrol_pump/presentation/screens/reports/cash_deposit_report_screen.dart`
- `features/petrol_pump/presentation/screens/reports/density_report_screen.dart`
- `features/petrol_pump/presentation/screens/reports/dsr_report_screen.dart`
- `features/petrol_pump/presentation/screens/reports/fuel_profit_report_screen.dart`
- `features/petrol_pump/presentation/screens/reports/nozzle_sales_report_screen.dart`
- `features/petrol_pump/presentation/screens/reports/outstanding_analysis_screen.dart`
- `features/petrol_pump/presentation/screens/reports/shift_report_screen.dart`
- `features/petrol_pump/presentation/screens/reports/tank_stock_report_screen.dart`
- `features/petrol_pump/presentation/screens/revenue_dashboard_screen.dart`
- `features/petrol_pump/presentation/screens/shift_history_screen.dart`
- `features/petrol_pump/presentation/screens/staff_detail_screen.dart`
- `features/petrol_pump/presentation/screens/staff_list_screen.dart`
- `features/petrol_pump/presentation/screens/tank_list_screen.dart`

#### Feature: `pharmacy`
- `features/pharmacy/screens/narcotic_register_screen.dart`
- `features/pharmacy/screens/patient_registry_screen.dart`
- `features/pharmacy/screens/product_catalog_screen.dart`
- `features/pharmacy/screens/salt_search_screen.dart`

#### Feature: `physical_to_digital`
- `features/physical_to_digital/ui/screens/p2d_camera_screen.dart`
- `features/physical_to_digital/ui/screens/p2d_crop_screen.dart`
- `features/physical_to_digital/ui/screens/p2d_export_screen.dart`
- `features/physical_to_digital/ui/screens/p2d_filter_screen.dart`
- `features/physical_to_digital/ui/screens/p2d_ocr_screen.dart`

#### Feature: `pre_order`
- `features/pre_order/presentation/customer/customer_pre_order_screen.dart`
- `features/pre_order/presentation/customer/vendor_catalog_screen.dart`
- `features/pre_order/presentation/vendor/vendor_request_detail_screen.dart`
- `features/pre_order/presentation/vendor/vendor_requests_screen.dart`

#### Feature: `prescriptions`
- `features/prescriptions/presentation/screens/h1_register_screen.dart`
- `features/prescriptions/presentation/screens/narcotic_register_screen.dart`

#### Feature: `profile`
- `features/profile/screens/vendor_profile_screen.dart`

#### Feature: `purchase`
- `features/purchase/presentation/screens/purchase_entries_list_screen.dart`
- `features/purchase/presentation/screens/scan_bill_image_picker_screen.dart`
- `features/purchase/presentation/screens/scan_bill_processing_screen.dart`
- `features/purchase/presentation/screens/scan_bill_review_screen.dart`
- `features/purchase/presentation/screens/scan_bill_supplier_screen.dart`
- `features/purchase/screens/add_purchase_screen.dart`
- `features/purchase/screens/purchase_dashboard_screen.dart`
- `features/purchase/screens/purchase_detail_screen.dart`
- `features/purchase/screens/purchase_history_screen.dart`

#### Feature: `reports`
- `features/reports/presentation/screens/all_transactions_screen.dart`
- `features/reports/presentation/screens/balance_screen.dart`
- `features/reports/presentation/screens/bill_wise_profit_screen.dart`
- `features/reports/presentation/screens/cashflow_screen.dart`
- `features/reports/presentation/screens/commission_ledger_screen.dart`
- `features/reports/presentation/screens/discount_report_screen.dart`
- `features/reports/presentation/screens/expense_register_screen.dart`
- `features/reports/presentation/screens/hallmark_register_screen.dart`
- `features/reports/presentation/screens/job_card_report_screen.dart`
- `features/reports/presentation/screens/low_stock_report_screen.dart`
- `features/reports/presentation/screens/old_gold_register_screen.dart`
- `features/reports/presentation/screens/party_wise_pnl_screen.dart`
- `features/reports/presentation/screens/petty_cash_report_screen.dart`
- `features/reports/presentation/screens/pnl_screen.dart`
- `features/reports/presentation/screens/print_menu_screen.dart`
- `features/reports/presentation/screens/product_performance_screen.dart`
- `features/reports/presentation/screens/product_sales_breakdown_screen.dart`
- `features/reports/presentation/screens/purchase_report_screen.dart`
- `features/reports/presentation/screens/reports_hub_screen.dart`
- `features/reports/presentation/screens/rma_report_screen.dart`
- `features/reports/presentation/screens/salesman_report_screen.dart`
- `features/reports/presentation/screens/stock_summary_report_screen.dart`
- `features/reports/presentation/screens/tally_export_screen.dart`
- `features/reports/presentation/screens/tax_report_screen.dart`
- `features/reports/presentation/screens/trial_balance_screen.dart`

#### Feature: `restaurant`
- `features/restaurant/presentation/screens/customer/customer_menu_screen.dart`
- `features/restaurant/presentation/screens/customer/order_tracking_screen.dart`
- `features/restaurant/presentation/screens/customer/rate_review_screen.dart`
- `features/restaurant/presentation/screens/floor_management_screen.dart`
- `features/restaurant/presentation/screens/food_menu_management_screen.dart`
- `features/restaurant/presentation/screens/kitchen_display_screen.dart`
- `features/restaurant/presentation/screens/kot_report_screen.dart`
- `features/restaurant/presentation/screens/menu_item_management_screen.dart`
- `features/restaurant/presentation/screens/recipe_management_screen.dart`
- `features/restaurant/presentation/screens/restaurant_aggregator_receipt_screen.dart`
- `features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart`
- `features/restaurant/presentation/screens/restaurant_delivery_ops_screen.dart`
- `features/restaurant/presentation/screens/restaurant_inventory_screen.dart`
- `features/restaurant/presentation/screens/restaurant_owner_command_screen.dart`
- `features/restaurant/presentation/screens/restaurant_pricing_admin_screen.dart`
- `features/restaurant/presentation/screens/restaurant_table_ops_screen.dart`
- `features/restaurant/presentation/screens/table_management_screen.dart`

#### Feature: `revenue`
- `features/revenue/screens/booking_order_screen.dart`
- `features/revenue/screens/commission_ledger_screen.dart`
- `features/revenue/screens/dispatch_note_screen.dart`
- `features/revenue/screens/proforma_screen.dart`
- `features/revenue/screens/receipt_entry_screen.dart`
- `features/revenue/screens/refund_screen.dart`
- `features/revenue/screens/return_inwards_screen.dart`
- `features/revenue/screens/revenue_overview_screen.dart`
- `features/revenue/screens/sales_register_screen.dart`

#### Feature: `service`
- `features/service/presentation/screens/create_exchange_screen.dart`
- `features/service/presentation/screens/create_service_job_screen.dart`
- `features/service/presentation/screens/exchange_detail_screen.dart`
- `features/service/presentation/screens/exchange_list_screen.dart`
- `features/service/presentation/screens/service_job_detail_screen.dart`
- `features/service/presentation/screens/service_job_list_screen.dart`

#### Feature: `settings`
- `features/settings/business_settings_screen.dart`
- `features/settings/migration/migration_dashboard_screen.dart`
- `features/settings/presentation/screens/audit_log_screen.dart`
- `features/settings/presentation/screens/customer_app_entry_qr_screen.dart`
- `features/settings/presentation/screens/device_management_screen.dart`
- `features/settings/presentation/screens/device_settings_screen.dart`
- `features/settings/presentation/screens/error_logs_screen.dart`
- `features/settings/presentation/screens/main_settings_screen.dart`
- `features/settings/presentation/screens/payment_reminders_screen.dart`
- `features/settings/presentation/screens/printer_settings_screen.dart`
- `features/settings/presentation/screens/settings_screen.dart`
- `features/settings/presentation/screens/template_designer_screen.dart`
- `features/settings/presentation/screens/user_management_screen.dart`
- `features/settings/screens/currency_settings_screen.dart`
- `features/settings/screens/tax_config_screen.dart`

#### Feature: `shared`
- `features/shared/presentation/screens/no_internet_screen.dart`

#### Feature: `shop_linking`
- `features/shop_linking/presentation/screens/manual_shop_add_screen.dart`
- `features/shop_linking/presentation/screens/qr_display_screen.dart`
- `features/shop_linking/presentation/screens/qr_scanner_screen.dart`
- `features/shop_linking/presentation/screens/shop_confirmation_screen.dart`

#### Feature: `staff`
- `features/staff/presentation/screens/add_staff_screen.dart`
- `features/staff/presentation/screens/id_card_designer_screen.dart`
- `features/staff/presentation/screens/staff_attendance_screen.dart`
- `features/staff/presentation/screens/staff_list_screen.dart`
- `features/staff/presentation/screens/staff_management_screen.dart`
- `features/staff/presentation/screens/staff_payroll_screen.dart`
- `features/staff/presentation/screens/staff_sale_entry_screen.dart`
- `features/staff/presentation/screens/staff_transaction_history_screen.dart`
- `features/staff/presentation/screens/unified_staff_detail_screen.dart`

#### Feature: `stock`
- `features/stock/presentation/screens/add_stock_screen.dart`

#### Feature: `super_admin`
- `features/super_admin/presentation/screens/admin_dashboard_screen.dart`
- `features/super_admin/presentation/screens/alert_management_screen.dart`
- `features/super_admin/presentation/screens/audit_viewer_screen.dart`
- `features/super_admin/presentation/screens/generate_license_screen.dart`
- `features/super_admin/presentation/screens/license_detail_screen.dart`
- `features/super_admin/presentation/screens/license_feature_override_screen.dart`
- `features/super_admin/presentation/screens/license_list_screen.dart`
- `features/super_admin/presentation/screens/plan_override_screen.dart`
- `features/super_admin/presentation/screens/super_admin_screen.dart`
- `features/super_admin/presentation/screens/tenant_management_screen.dart`
- `features/super_admin/presentation/screens/usage_dashboard_screen.dart`

#### Feature: `visits`
- `features/visits/screens/clinic_invoice_preview_screen.dart`
- `features/visits/screens/consultation_screen.dart`
- `features/visits/screens/visit_queue_screen.dart`

### 5.2 `school_admin_app/lib/`

| Feature module | Screens |
|---|---|
| `admissions` | `features/admissions/screens/admissions_screen.dart` |
| `announcements` | `features/announcements/screens/announcements_screen.dart` |
| `attendance` | `features/attendance/screens/attendance_screen.dart` |
| `auth` | `features/auth/screens/login_screen.dart` |
| `classes` | `features/classes/screens/classes_screen.dart` |
| `dashboard` | `features/dashboard/screens/dashboard_screen.dart` |
| `faculty` | `features/faculty/screens/faculty_screen.dart` |
| `fees` | `features/fees/screens/fees_screen.dart` |
| `hostel` | `features/hostel/screens/hostel_screen.dart` |
| `leave` | `features/leave/screens/leave_screen.dart` |
| `library` | `features/library/screens/library_screen.dart` |
| `payroll` | `features/payroll/screens/payroll_screen.dart` |
| `reports` | `features/reports/screens/reports_screen.dart` |
| `settings` | `features/settings/screens/settings_screen.dart` |
| `students` | `features/students/screens/students_screen.dart` |
| `transport` | `features/transport/screens/transport_screen.dart` |
| `shell` | `features/shell/main_shell.dart` (navigation skeleton — no screen) |

### 5.3 `school_teacher_app/lib/`

| Feature module | Screens |
|---|---|
| `announcements` | `features/announcements/screens/announcements_screen.dart` |
| `attendance` | `features/attendance/screens/attendance_screen.dart` |
| `auth` | `features/auth/screens/login_screen.dart` |
| `dashboard` | `features/dashboard/screens/dashboard_screen.dart` |
| `exams` | `features/exams/screens/exams_screen.dart` |
| `homework` | `features/homework/screens/homework_screen.dart` |
| `leave` | `features/leave/screens/leave_screen.dart` |
| `lesson_plans` | `features/lesson_plans/screens/lesson_plans_screen.dart` |
| `materials` | `features/materials/screens/materials_screen.dart` |
| `payslip` | `features/payslip/screens/payslip_screen.dart` |
| `profile` | `features/profile/screens/profile_screen.dart` |
| `students` | `features/students/screens/students_screen.dart` |
| `timetable` | `features/timetable/screens/timetable_screen.dart` |
| `shell` | `features/shell/main_shell.dart` |

### 5.4 `school_student_app/lib/`

| Feature module | Screens |
|---|---|
| `attendance` | `features/attendance/screens/attendance_screen.dart` |
| `auth` | `features/auth/screens/login_screen.dart` |
| `dashboard` | `features/dashboard/screens/dashboard_screen.dart` |
| `exams` | `features/exams/screens/exams_screen.dart` |
| `fees` | `features/fees/screens/fees_screen.dart`, `features/fees/screens/fee_payment_screen.dart` |
| `homework` | `features/homework/screens/homework_screen.dart` |
| `leave` | `features/leave/screens/leave_screen.dart` |
| `library` | `features/library/screens/library_screen.dart` |
| `materials` | `features/materials/screens/materials_screen.dart` |
| `notifications` | `features/notifications/screens/notifications_screen.dart` *(legacy notification UI — see §8)* |
| `profile` | `features/profile/screens/profile_screen.dart` |
| `results` | `features/results/screens/results_screen.dart` |
| `timetable` | `features/timetable/screens/timetable_screen.dart` |
| `transport` | `features/transport/screens/transport_screen.dart` |
| `shell` | `features/shell/main_shell.dart` |


---

## 6. Backend Module / Service / Controller / Endpoint Inventory

### 6.1 `my-backend/` (TypeScript on AWS Lambda)

#### Handlers (`my-backend/src/handlers/`) — public REST endpoints behind API Gateway

> The handler files below all export `APIGatewayProxyHandlerV2` (or named exports for sub-routes) and are registered as Lambda functions in `template.yaml`. Each handler maps to one or more endpoints on the same shared HTTP API. Where endpoints are non-obvious from the file name, the route prefix is noted in the comment column.

| Handler file | Domain | Notes |
|---|---|---|
| `auth.ts` | Auth (sign in / sign up / refresh / OTP) | Cognito-backed |
| `admin.ts`, `admin-audit.ts` | Admin tools, audit log | |
| `ai.ts`, `ai-event-processor.ts`, `autonomous.ts` | AI assistant + autonomous agent | |
| `auto-parts.ts` | Auto parts vertical | Job cards |
| `barcode-label.ts` | Barcode label printing | |
| `billing.ts`, `invoices.ts`, `held-bills.ts`, `legacy-compat.ts`, `v1-bills.ts`, `v1-entity.ts` | Billing / invoices | Emits `BILL_CREATED`, `BILL_UPDATED`, `INVOICE_CREATED` |
| `book_store.ts` | Book store vertical | |
| `businesses.ts` | Multi-business management | |
| `cash-closings.ts` | End-of-day cash closing | |
| `challans.ts` | Delivery challans | |
| `clinic.ts`, `clinic-dashboard.handler.ts`, `clinic-pdf.ts`, `clinic-scheduler.ts` | Clinic vertical | |
| `clothing.ts` | Clothing vertical | |
| `cognito-triggers.ts` | Cognito post-confirm/pre-token | |
| `computer.ts` | Computer shop vertical | |
| `credit-reminders.ts` | Credit / dunning reminders | |
| `cron/grace-period-cron.ts`, `cron/trial-expiry.ts` | Scheduled cron jobs | |
| `customer.ts`, `customer-app.ts`, `customers.ts` | Customer side & customer-app proxy | |
| `dashboard-v2.ts` | Dashboard v2 KPIs | |
| `dc.ts` | Decoration & catering | Emits `DC_*` events |
| `duplicate-bill-detection.ts` | Duplicate-bill guard | |
| `einvoice.ts` | E-invoice (IRN/IRP/GSP) | |
| `entity-actions.ts` | Generic entity actions | |
| `estimates.ts` | Sales estimates | |
| `feature-flag.ts` | Plan feature flags | |
| `financial-reports.ts`, `reports.ts`, `pump-reports.ts` | Reports (financial + operational) | |
| `get-import-job-status.ts`, `import-product-file.ts`, `process-import-row.ts` | Smart-inventory import pipeline | Emits `IMPORT_PROGRESS`, `IMPORT_COMPLETED`, `IMPORT_FAILED` |
| `grocery-batches.ts`, `grocery-expiry.ts` | Grocery FEFO + expiry | |
| `hardware-deposits.ts`, `hardware-phase12.ts`, `hardware-phase2.ts`, `hardware-projects.ts` | Hardware vertical (multi-phase) | |
| `health.ts` | Health/heartbeat | |
| `hsn-seed.ts` | HSN seed data | |
| `insights.ts` | Business insights | |
| `in-store-barcode.ts`, `in-store-checkout.ts`, `in-store-session.ts`, `in-store-streams.ts` | In-store self-scan / checkout | Emits `IN_STORE_*` events; uses `FCM_SNS_TOPIC_ARN` for push |
| `internal.ts` | Internal-only utility | |
| `inventory.ts`, `stock.ts`, `stock-count.ts` | Inventory & stock | Emits `INVENTORY_UPDATED`, `STOCK_UPDATED`, `LOW_STOCK_ALERT` |
| `jewellery.ts`, `jewellery-extended.ts`, `jewellery-reports.ts` | Jewellery vertical | |
| `license.ts` | License | |
| `linking.ts` | Customer↔shop linking | |
| `low-stock-alerts.ts` | Low-stock alert evaluation | |
| `loyalty.ts` | Loyalty | |
| `migration.ts` | Tenant data migration | |
| `notification.ts` | DukanX-side push registration & basic notification CRUD | **Will be replaced by UNS** |
| `payment.ts`, `payments.ts`, `payment-config.ts`, `payment-webhook.ts`, `payment/cleanup-expired-qr.ts`, `payment/create-merchant.ts`, `payment/create-order.ts`, `payment/generate-qr.ts`, `payment/get-payment-status.ts`, `payment/get-refunds.ts`, `payment/process-cash.ts`, `payment/process-refund.ts`, `payment/verify-payment.ts`, `payment/webhook-handler.ts` | Payments + gateway (Razorpay/PhonePe) | Emits `PAYMENT_SUCCESS`, `PAYMENT_FAILED` |
| `analytics/payment-analytics.ts` | Payment analytics | |
| `pharmacy.ts`, `pharmacy-batch-expiry.ts`, `pharmacy-compliance.ts` | Pharmacy vertical | |
| `plan-admin.ts`, `plan-config-admin.ts` | Plan admin | |
| `products.ts`, `product-search.ts` | Products | |
| `pump.ts`, `pump-atg-scheduler.ts`, `pump-integrations.ts`, `pump-pricing.ts`, `v1-petrol-pump.ts` | Petrol pump | Emits `PETROL_SALE_UPDATE`, `DIESEL_SALE_UPDATE`, `SHIFT_OPENED`, `SHIFT_CLOSED`, `STAFF_ACTIVITY` |
| `purchase-order-matching.ts` | PO matching | |
| `reconciliation.ts` | Reconciliation | |
| `recovery-visits.ts` | Recovery visits | |
| `report-dispatch-worker.ts` | Scheduled report dispatch | |
| `restaurant-v1-public.ts`, `resto.ts`, `modules/restaurant/restaurant-billing.ts`, `modules/restaurant/restaurant-delivery.ts`, `modules/restaurant/restaurant-kot.ts`, `modules/restaurant/restaurant-menu.ts`, `modules/restaurant/restaurant-tables.ts`, `modules/restaurant/index.ts` | Restaurant | Emits `KOT_CREATED`, `KOT_STATUS_UPDATED`, `KOT_ITEM_CANCELLED`, `CHECKOUT_REQUESTED`, `ORDER_CREATED`, `ORDER_UPDATED`, `BILL_UPDATED` |
| `scan-bill.ts` | OCR bill scanning | |
| `search-indexer.ts`, `search-query.ts` | OpenSearch indexer/query | |
| `secret-rotation.ts` | KMS secret rotation | |
| `service.ts` | Service jobs / warranty | Emits `SERVICE_JOB_CREATED`, `SERVICE_STATUS_UPDATED` |
| `shared-prescriptions.ts` | Shared prescriptions | |
| `staff-sale.ts`, `staff-sale-history.ts` | Staff sales | Emits `STAFF_SALE_CREATED` |
| `storage.ts` | S3 file uploads | |
| `subscription.ts`, `subscription-webhook.ts` | Razorpay subscription billing | |
| `suppliers.ts` | Suppliers / vendor mgmt | Sends WhatsApp dunning |
| `sync.ts` | Sync engine | |
| `tenant-config.ts` | Tenant config | |
| `websocket.ts`, `ws-broadcaster.ts`, `ws-cleanup.ts` | WebSocket connect/disconnect + EventBridge → WS broadcaster | |
| `weighscale.ts` | Weighscale device integration | |
| **Pharmacy module** under `modules/pharmacy/` | `index.ts`, `pharmacy-batch.ts`, `pharmacy-claims.ts`, `pharmacy-compliance.ts`, `pharmacy-narcotic.ts`, `pharmacy-refills.ts` | |
| **School-ERP module** under `modules/school-erp/` | `index.ts`, `school-admissions.ts`, `school-attendance.ts`, `school-batches.ts`, `school-bulk.ts`, `school-communication.ts`, `school-config.ts`, `school-dashboard.ts`, `school-exams.ts`, `school-faculty.ts`, `school-fees.ts`, `school-homework.ts`, `school-hostel.ts`, `school-leave.ts`, `school-lesson-plans.ts`, `school-library.ts`, `school-materials.ts`, `school-notifications.ts`, `school-payslip.ts`, `school-reports.ts`, `school-students.ts`, `school-timetable.ts` | The `school-erp` module powers `school_admin_app`, `school_teacher_app`, `school_student_app` and `Dukan_x` AC feature. `school-notifications.ts` is the **legacy emitter** — it owns `pushNotification(userId, payload)` and the `GET/PUT /ac/notifications*` endpoints. **Will be replaced by UNS.** |
| **Academic-coaching primary handler** | `academic_coaching.ts` (large monolith) and `ac-*.ts` family: `ac-admissions.ts`, `ac-biometric.ts`, `ac-concession.ts`, `ac-department.ts`, `ac-documents.ts`, `ac-exam-extra.ts`, `ac-homework.ts`, `ac-hostel.ts`, `ac-inventory.ts`, `ac-leave.ts`, `ac-lesson-plans.ts`, `ac-library.ts`, `ac-messaging.ts`, `ac-payments.ts`, `ac-payslip.ts`, `ac-period-attendance.ts`, `ac-refund.ts`, `ac-reports.ts`, `ac-sibling.ts`, `ac-transport.ts` | Owns `sendSmsViaSns`, `sendEmailViaSes`, `sendWhatsApp` (the three direct delivery primitives). Triggers SMS/Email on absent students and fee reminders. **Will be replaced by UNS.** |

#### Services (`my-backend/src/services/`)

| Service file | Purpose |
|---|---|
| `ai.service.ts`, `ai-learning.service.ts`, `ai-memory.service.ts`, `ai-tools.registry.ts`, `autonomous-agent.service.ts` | AI assistant + tool registry |
| `atg-connector.service.ts` | Petrol pump ATG hardware connector |
| `audit.service.ts`, `audit-log.service.ts` | Audit logging |
| `auth.service.ts` | Auth |
| `barcode-detection.service.ts` | Barcode detection |
| `bill-parser.service.ts`, `bill-verification.service.ts`, `billing.service.ts` | Billing + bill scanning |
| `business/base.strategy.ts`, `business/book-store.strategy.ts`, `business/clinic.strategy.ts`, `business/clothing.strategy.ts`, `business/computer.strategy.ts`, `business/electronics.strategy.ts`, `business/grocery.strategy.ts`, `business/hardware.strategy.ts`, `business/petrol-pump.strategy.ts`, `business/pharmacy.strategy.ts`, `business/restaurant.strategy.ts`, `business/service.strategy.ts`, `business/wholesale.strategy.ts` | Per-business-type strategy plug-ins |
| `cash-closing.service.ts` | Cash closing logic |
| `category-keyword-map.ts` | Category resolution from keywords |
| `challan.service.ts` | Delivery challan |
| `clinic-dashboard.service.ts` | Clinic dashboard |
| `credit-reminder.service.ts` | Credit reminders (used by `cron/grace-period-cron.ts`) |
| `customer.service.ts` | Customer CRUD |
| `dashboard.service.ts`, `dashboard-v2.service.ts` | Dashboards |
| `einvoice.service.ts` | E-invoice |
| `estimate.service.ts` | Estimates |
| **`eventbridge.service.ts`** | **Canonical EventBridge publisher** for WS events |
| `feature-flag.service.ts`, `feature-manifest.service.ts` | Feature flags |
| `fraud-detection.service.ts` | Fraud detection |
| `gateway/gateway.factory.ts`, `gateway/gateway.interface.ts`, `gateway/phonepe.gateway.ts`, `gateway/razorpay.gateway.ts` | Payment gateway abstractions |
| `grace-period.service.ts` | Trial grace period |
| `grocery-batch.service.ts` | Grocery FEFO batch |
| `held-bill.service.ts` | Parked bills |
| `hsn.validator.ts` | HSN validation |
| `import-file-parser.ts` | Smart inventory import |
| `inventory.service.ts`, `stock.service.ts` | Inventory & stock |
| `invoice.service.ts` | Invoices (large; emits multiple WS events on save) |
| `kms.service.ts` | KMS encrypt/decrypt |
| `license.service.ts`, `license-denylist.service.ts` | License |
| `limit-check.service.ts` | Plan limit checks |
| `linking.service.ts` | Customer↔shop linking |
| `loyalty.service.ts` | Loyalty |
| `offline-queue.service.ts` | Offline producer queue |
| `payment-config.service.ts`, `payment-order.service.ts`, `post-payment.service.ts` | Payments |
| `pharmacy-batch.service.ts`, `pharmacy-dashboard.service.ts` | Pharmacy |
| `plan-config.service.ts`, `plan-management.service.ts`, `subscription.service.ts`, `trial.service.ts` | SaaS plans + trial |
| `presence.service.ts` | Presence (online/offline) |
| `product.service.ts`, `product-matcher.service.ts` | Products |
| `revision-history.service.ts` | Revision history |
| `secrets-manager.service.ts` | Secrets manager |
| `smart-suggestions.service.ts` | Smart suggestions |
| `storage.service.ts` | S3 |
| `sync.service.ts` | Cross-device sync |
| `tenant-onboarding.ts` | Tenant onboarding |
| **`websocket.service.ts`** | **Canonical WebSocket fan-out**: `broadcastToBusiness`, `broadcastToStaff`, `broadcastToCustomer`, `broadcastToOwner`, `broadcastToClientType`, `broadcastToDevice`, `broadcastToAll`, `emitEvent`, `saveConnection`, `removeConnection` |
| **`whatsapp.service.ts`** | **WhatsApp Cloud API client** (`sendTextMessage`, `sendPaymentConfirmation`, etc.) |

#### Controllers, Middleware, Routes, Repositories, Search, i18n, Workers

- `controllers/device.controller.ts`
- `core/db/cache.ts`, `core/registry/module-registry.ts`, `core/types/module.types.ts`, `core/websocket/channel-registry.ts`
- `dynamodb/audit.ts`, `dynamodb/bill-service.ts`, `dynamodb/client.ts`, `dynamodb/crud-factory.ts`, `dynamodb/entity-services.ts`, `dynamodb/keys.ts`, `dynamodb/petrol-pump-service.ts`, `dynamodb/tenant-guard.ts`, `dynamodb/types.ts`
- Middleware: `audit.ts`, `business-type-guard.ts`, `cloudwatch-logger.ts`, `cognito-auth.ts`, `handler-wrapper.ts`, `idempotency.ts`, `internal-auth.ts`, `limit-guard.ts`, `permission-guard.ts`, `plan-guard.ts`, `rate-limiter.ts`, `role-guard.ts`, `signature-guard.ts`, `software-lock.ts`, `super-admin-guard.ts`, `user-scope-guard.ts`, `validation.ts`
- Modules (manifests): `_template/manifest.ts`, `auto-parts/manifest.ts`, `book-store/manifest.ts`, `clinic/manifest.ts`, `clothing/manifest.ts`, `computer-shop/manifest.ts`, `decoration-catering/manifest.ts`, `grocery/manifest.ts`, `hardware/manifest.ts`, `jewellery/manifest.ts`, `mobile-shop/manifest.ts`, `petrol-pump/manifest.ts`, `pharmacy/manifest.ts`, `restaurant/manifest.ts`, `school-erp/manifest.ts`, `vegetables-broker/manifest.ts`, `wholesale/manifest.ts`
- Repositories: `base.repository.ts`, `dynamo.repository.ts`, `inventory.repository.ts`, `transaction.repository.ts`
- Routes: `pharmacy-dashboard.routes.ts`
- Schemas (Zod): `academic-coaching.schema.ts`, `index.ts`, `mobile.schema.ts`, `payment.schema.ts`, `pharmacy.schema.ts`, `product.schema.ts`, `websocket.schema.ts`
- Search: `opensearch-client.ts`, `opensearch-mappings.ts`
- i18n: `i18n.middleware.ts`, `i18n.service.ts`, `index.ts`, `localized-response.ts`, `multilingual-schema.ts`, **`notification-templates.ts`** (server-side push/SMS/email message templates)
- Types: `api.types.ts`, `events.ts`, `import.types.ts`, `in-store.types.ts`, `inventory.types.ts`, `license.types.ts`, `payment.types.ts`, `product.types.ts`, `refund.types.ts`, `tenant.types.ts`, `websocket.types.ts`
- Utils: `cache.ts`, `context.ts`, `credit-check.util.ts`, `dynamodb-errors.ts`, `errors.ts`, `fuzzy-match.ts`, `gstin.utils.ts`, `jwt-role.ts`, `logger.ts`, `low-stock-alerts.ts`, `response.ts`, `secrets-manager.ts`, `settings-batch.ts`, `settings-batch-integration.ts`, `timezone.ts`, `variant-detector.ts`, `vehicle.util.ts`, `websocket-cleanup.ts`
- WebSocket: `websocket/pharmacy-websocket.handler.ts`
- Workers: `workers/orderWorker.ts`

### 6.2 `voice-backend/` (Python)

- API entrypoints: `voice-backend/main.py`, `voice-backend/app/main.py`, `voice-backend/app/api/v1/endpoints/business.py`, `voice-backend/app/api/v1/endpoints/sync.py`, `voice-backend/api/bills.py`, `voice-backend/api/customers.py`
- Core: `voice-backend/app/core/auth.py`, `voice-backend/app/core/db.py`, `voice-backend/core/auth.py`, `voice-backend/core/database.py`
- Models: `voice-backend/app/models/base.py`, `voice-backend/models/bill.py`, `voice-backend/models/customer.py`
- Schemas: `voice-backend/app/schemas/sync.py`
- Services: `voice-backend/services/ai_service.py`
- Tools: `voice-backend/tools/calculators.py`, `voice-backend/tools/data_fetchers.py`, `voice-backend/tools/stock_tools.py`
- Voice agent core: `voice-backend/voice_agent.py`, `voice-backend/dialogue_manager.py`, `voice-backend/nlu_engine.py`, `voice-backend/query_engine.py`, `voice-backend/natural_voice_generator.py`, `voice-backend/bill_processor.py`, `voice-backend/data_validator.py`, `voice-backend/simple_groq.py`, `voice-backend/test_ai.py`, `voice-backend/config.py`

> **Notification footprint of `voice-backend/`**: none today. The voice agent reads/queries data only.

### 6.3 `lambda/` (Node.js Lambdas, mostly `.mjs`)

| Lambda | File | Purpose |
|---|---|---|
| `adminStaffHandler` | `index.mjs` | Admin staff CRUD |
| `auditHandler` | `index.mjs` | Audit log writer |
| `authHandler` | `index.mjs` | Auth (legacy) |
| `barcodeLookup` | `index.mjs` | Barcode lookup |
| `billingHandler` | `index.mjs`, `index-v2.mjs` | Billing (legacy + v2) |
| `cognitoPreTokenTrigger` | `index.mjs` | Cognito pre-token role injection |
| `customerAuthorizerHandler` | `index.mjs` | Customer-app JWT authorizer |
| `customerConnectionHandler` | `index.mjs` | Customer WS connect/disconnect |
| `customerHandler` | `index.mjs` | Customer CRUD |
| `customerInvoiceHandler` | `index.mjs` | Customer-side invoice list |
| `customerLedgerHandler` | `index.mjs` | Customer ledger |
| **`customerNotificationHandler`** | `index.mjs` | **Customer-side notification CRUD (legacy)** |
| `customerOnboardingTrigger` | `index.mjs` | Customer Cognito post-confirm |
| `customerPaymentHandler` | `index.mjs` | Customer payments |
| `customerStreamProcessor` | `index.mjs` | DynamoDB Streams processor for customer table |
| `customerWsHandler` | `index.mjs` | Customer WebSocket message router |
| **`fuelposHandler/`** | `generateQR.ts`, `getAlerts.ts`, `getDashboardSummary.ts`, `getFuelChart.ts`, `getOwnerDashboard.ts`, `getPaymentStatus.ts`, `getRevenueBreakdown.ts`, `getStaffTransactions.ts`, `getTransactions.ts`, `health.ts`, `razorpayWebhook.ts`, `revenueReportsHandler.mjs`, `staffHandler.mjs`, `staffMobileHandler.mjs`, `streamProcessor.ts`, `websocketConnect.ts`, `websocketDisconnect.ts` | Fuel POS — duplicate-of-pump implementation, kept for legacy clients |
| `jewelryDashboardHandler/` | `activity.mjs`, `category-split.mjs`, `index.mjs`, `inventory-overview.mjs`, `recent-transactions.mjs`, `revenue-chart.mjs` | Jewelry dashboard widgets |
| **`marketplace/`** | `cartHandler/index.ts`, `deliveryHandler/index.ts`, `inventoryHandler/index.ts`, `ordersHandler/index.ts`, `storeHandler/index.ts`, **`wsHandler/index.ts`** | Marketplace + customer-marketplace WebSocket. **`wsHandler/index.ts` already does `broadcastToRoom(...)` for real-time order/delivery updates.** |
| `shared/` | `audit-logger.mjs`, `auth.ts`, `dynamodb.ts`, `error-handler.mjs`, `errors.ts`, `helpers.mjs`, `logger.mjs`, `payment-service.mjs`, `response.ts`, `schemas.mjs`, `security.mjs`, `trial-abuse-middleware.mjs`, `types.ts`, `utils.mjs`, `validation.mjs`, `utils/audit-logger.mjs`, `utils/circuit-breaker.mjs`, `utils/dynamodb-with-rid.mjs`, `utils/logger.mjs`, `utils/request-context.mjs`, `utils/rid-generator.mjs`, `utils/tracing.mjs`, `utils/with-request-context.mjs` | Shared lambda utilities |
| `staffAuthHandler` | `index.mjs` | Staff auth |
| `tenantHandler` | `index.mjs` | Tenant CRUD |
| `tenantSubscriptionHandler` | `index.mjs` | Subscription/billing |
| `transactionValidator` | `index.mjs` | Transaction validation |
| **`trialExpiryCronHandler`** | `index.mjs` | **EventBridge cron — moves expired trials to TRIAL_EXPIRED, publishes to SNS `SNS_TRIAL_TOPIC_ARN`** |
| **`trialNotificationSchedulerHandler`** | `index.mjs` | **Schedules T-7 / T-3 / T-1 trial-expiry SNS reminders** |
| **`trialProvisioningHandler`** | `index.mjs` | **Publishes welcome / trial-started SNS message** |
| `userHandler` | `index.mjs` | User CRUD |

### 6.4 `lambda/staff-attendance/` (TypeScript)

- Constants: `src/constants/errorCodes.ts`, `src/constants/tables.ts`
- Handlers: `src/handlers/emailIDCard.ts`, `src/handlers/getStaffDashboard.ts`, **`src/handlers/processLeaveRequest.ts`**, `src/handlers/scheduledAttendanceMarker.ts`, **`src/handlers/staffCheckIn.ts`**, **`src/handlers/staffCheckOut.ts`**, **`src/handlers/submitLeaveRequest.ts`**, `src/handlers/uploadIDCard.ts`, `src/handlers/websocketConnect.ts`, `src/handlers/websocketDefault.ts`, `src/handlers/websocketDisconnect.ts`
- Types: `src/types/attendance.ts`
- Utils: `src/utils/dynamodb.ts`, `src/utils/rbac.ts`, `src/utils/ulid.ts`, **`src/utils/websocketBroadcast.ts`** (`broadcastToStation(stationId, wsEndpoint, message)`)

### 6.5 `lambda/staff-management/` (TypeScript) — present in workspace, not listed in spec but in scope (cross-cutting `staff` role)

- Constants: `src/constants/roles.ts`, `src/constants/tables.ts`
- Handlers: `src/handlers/activityLog.ts`, `src/handlers/createStaff.ts`, `src/handlers/deactivateStaff.ts`, `src/handlers/getStaffById.ts`, `src/handlers/getStaffStats.ts`, `src/handlers/listStaff.ts`, `src/handlers/reactivateStaff.ts`, `src/handlers/resetStaffPassword.ts`, `src/handlers/updateStaff.ts`
- Middleware: `src/middleware/errorHandler.ts`, `src/middleware/validator.ts`
- Types: `src/types/staff.ts`, `src/types/staff_abstraction.ts`
- Utils: `src/utils/auth.ts`, `src/utils/cognito.ts`, `src/utils/dynamodb.ts`, `src/utils/idGenerator.ts`


---

## 7. Cross-Module End-to-End Workflows

Each workflow below traces a real user journey through the live codebase, naming the producing files and the symbols that mutate state. These are the workflows the UNS must address (Phase 2 will turn the `notification touch points` column into Notification_Event_Registry rows).

### 7.1 Invoice creation → Payment → Reconciliation

| Step | Module | Files | Notification touch points |
|---|---|---|---|
| 1. Bill created (desktop) | DukanX → billing | `Dukan_x/lib/features/billing/presentation/screens/create_invoice_screen.dart`, `Dukan_x/lib/core/repository/bills_repository.dart` (`createBill` → `eventDispatcher.invoiceCreated`) | Local: `BusinessEvent.invoiceCreated`. Server: nothing (DukanX is offline-first) |
| 2. Bill synced to backend | DukanX → sync | `Dukan_x/lib/features/sync/...`, `my-backend/src/handlers/invoices.ts` `createInvoice` | Server emits `WSEventName.BILL_CREATED` (and `INVOICE_CREATED` from `invoice.service.ts`) on the tenant's WS channel |
| 3. UPI / card payment | DukanX → payment + backend | `Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart`, `my-backend/src/handlers/payments.ts`, `my-backend/src/handlers/payment-webhook.ts` | Server emits `WSEventName.PAYMENT_SUCCESS` / `PAYMENT_FAILED`. Local DukanX dispatches `BusinessEvent.paymentReceived`. WhatsApp confirmation via `post-payment.service.ts` → `whatsapp.service.sendPaymentConfirmation` |
| 4. Payment recorded against bill | DukanX → bills_repository | `Dukan_x/lib/core/repository/bills_repository.dart` lines around 670 (`eventDispatcher.paymentReceived`) | Updates customer ledger, persists customer notification via `customer_payment_screen.dart` calling `customerNotificationsRepository.createNotification` |
| 5. Reconciliation (daybook / EOD) | DukanX → cash_closing + reports | `Dukan_x/lib/features/cash_closing/presentation/screens/day_end_close_screen.dart`, `Dukan_x/lib/core/services/reconciliation_service.dart`, `my-backend/src/handlers/reconciliation.ts`, `my-backend/src/handlers/cash-closings.ts` | No event today |

### 7.2 Purchase order → Goods receipt → Inventory update

| Step | Module | Files | Notification touch points |
|---|---|---|---|
| 1. Purchase order created (manual) | DukanX → buy_flow / purchase | `Dukan_x/lib/features/purchase/screens/add_purchase_screen.dart`, `Dukan_x/lib/features/buy_flow/screens/buy_orders_screen.dart` | Local: `BusinessEvent.purchaseOrderCreated` via `eventDispatcher.purchaseOrderCreated` |
| 1a. Purchase order from scanned bill | DukanX → purchase scan | `Dukan_x/lib/features/purchase/presentation/screens/scan_bill_image_picker_screen.dart` → `scan_bill_review_screen.dart`, `my-backend/src/handlers/scan-bill.ts` | Local: same `purchaseOrderCreated` once review is committed |
| 2. Stock received & posted | DukanX → buy_flow / inventory | `Dukan_x/lib/features/buy_flow/screens/stock_entry_screen.dart`, `Dukan_x/lib/features/stock/presentation/screens/add_stock_screen.dart`, `Dukan_x/lib/core/repository/products_repository.dart` (`addStock`/`updateStock` → `eventDispatcher.stockChanged`) | Local: `BusinessEvent.stockChanged` |
| 3. Server stock side-effect | Backend → inventory + invoice | `my-backend/src/handlers/inventory.ts` (`stock_adjusted`), `my-backend/src/services/invoice.service.ts` (decrements stock during sale) | Server emits `WSEventName.INVENTORY_UPDATED`, `STOCK_UPDATED`, and `LOW_STOCK_ALERT` when threshold crossed |
| 4. Supplier ledger update | DukanX → party_ledger | `Dukan_x/lib/features/party_ledger/screens/party_ledger_list_screen.dart`, `Dukan_x/lib/features/buy_flow/screens/supplier_bills_screen.dart` | Today: dunning via WhatsApp from `my-backend/src/handlers/suppliers.ts` (manual trigger) |

### 7.3 Service job creation → Status update → Warranty claim

| Step | Module | Files | Notification touch points |
|---|---|---|---|
| 1. Service job created | DukanX → service / computer_shop / auto_parts | `Dukan_x/lib/features/service/presentation/screens/create_service_job_screen.dart`, `Dukan_x/lib/features/computer_shop/presentation/screens/create_job_card_screen.dart`, `Dukan_x/lib/features/auto_parts/presentation/screens/job_card_management_screen.dart`, `my-backend/src/handlers/service.ts` | Server emits `WSEventName.SERVICE_JOB_CREATED`. Local: `ServiceJobNotificationService.dispatchNotification` (also fires `BusinessEvent.jobStatusChanged`) |
| 2. Status transitions | DukanX → service | `Dukan_x/lib/features/service/services/service_job_notification_service.dart` (`dispatchNotification` for received/diagnosing/repairing/ready/delivered/cancelled) | Server emits `WSEventName.SERVICE_STATUS_UPDATED`. **Today the customer-facing channel is left as a `// TODO push` stub at line ~292 of `service_job_notification_service.dart` — UNS must close that.** |
| 3. Exchange / refurb tracking | DukanX → service | `Dukan_x/lib/features/service/presentation/screens/create_exchange_screen.dart`, `exchange_detail_screen.dart`, `exchange_list_screen.dart` | None today |
| 4. Warranty claim | DukanX → computer_shop / service | `Dukan_x/lib/features/computer_shop/presentation/screens/warranty_screen.dart`, `Dukan_x/lib/features/service/services/warranty_claim_service.dart` | None today |

### 7.4 Restaurant order → Kitchen → Billing

| Step | Module | Files | Notification touch points |
|---|---|---|---|
| 1. Customer places order | DukanX customer screen + restaurant POS | `Dukan_x/lib/features/restaurant/presentation/screens/customer/customer_menu_screen.dart`, `Dukan_x/lib/features/restaurant/presentation/screens/customer/order_tracking_screen.dart`, `my-backend/src/handlers/restaurant-v1-public.ts` | Server emits `WSEventName.ORDER_CREATED` to `RESTAURANT_STAFF_APP` via `wsService.broadcastToStaff(vendorId, ...)`. Local: `RestaurantNotificationService.notifyNewOrder` (flutter_local_notifications) |
| 2. KOT to kitchen | Backend → restaurant module | `my-backend/src/handlers/modules/restaurant/restaurant-kot.ts`, `my-backend/src/handlers/resto.ts` | Server emits `KOT_CREATED`, `KOT_STATUS_UPDATED`, `KOT_ITEM_CANCELLED` |
| 3. Item ready / served | Kitchen display | `Dukan_x/lib/features/restaurant/presentation/screens/kitchen_display_screen.dart`, `Dukan_x/lib/features/restaurant/presentation/screens/restaurant_table_ops_screen.dart` | Local: `RestaurantNotificationService.notifyOrderReady` |
| 4. Bill / checkout | Restaurant billing | `Dukan_x/lib/features/restaurant/presentation/screens/restaurant_owner_command_screen.dart`, `my-backend/src/handlers/modules/restaurant/restaurant-billing.ts`, `resto.ts` (lines around 2066 / 2150) | Server emits `BILL_UPDATED` via `wsService.broadcastToClientType(... RESTAURANT_STAFF_APP, BILL_UPDATED ...)`. `CHECKOUT_REQUESTED` event also exists in `WSEventName` |
| 5. Payment confirmation | Payment | `my-backend/src/handlers/payment-webhook.ts`, `my-backend/src/handlers/payments.ts` | Server emits `PAYMENT_SUCCESS`/`PAYMENT_FAILED`. Local DukanX consumes via `WebSocketService.subscribe(WSEventName.paymentSuccess, ...)` in `staff_sale_entry_screen.dart` and `restaurant_owner_command_screen.dart` |

### 7.5 School fee assignment → Payment → Receipt

| Step | Module | Files | Notification touch points |
|---|---|---|---|
| 1. Fee structure / assignment | school_admin_app + backend | `school_admin_app/lib/features/fees/screens/fees_screen.dart`, `my-backend/src/handlers/modules/school-erp/school-fees.ts`, `my-backend/src/handlers/ac-payments.ts`, `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_classwise_fee_screen.dart` | Server emits `WSEventName.AC_INVOICE_GENERATED` (per `WSEventName` enum). Today: `school-fees.ts` writes the invoice but does not call `pushNotification`. **Gap.** |
| 2. Fee due reminder | Backend → academic_coaching | `my-backend/src/handlers/academic_coaching.ts` (cron / scheduled bulk) — `sendSmsViaSns` + `sendEmailViaSes` + `sendWhatsApp` | Direct SMS/Email/WhatsApp send. Server can also emit `AC_FEE_OVERDUE` |
| 3. Student/parent makes payment | school_student_app | `school_student_app/lib/features/fees/screens/fee_payment_screen.dart`, `my-backend/src/handlers/payments.ts` (online), `my-backend/src/handlers/ac-payments.ts` (cash) | Server emits `WSEventName.AC_FEE_COLLECTED`, `AC_INVOICE_PAID`, `PAYMENT_SUCCESS` |
| 4. Receipt generation + admin/teacher visibility | school_admin / DukanX AC | `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_payments_screen.dart`, `school_admin_app/.../fees_screen.dart` | Today: payer sees confirmation in-app via WS push; school admin sees the WS event. `school-notifications.ts` `pushNotification` is called from inside fee handlers ad-hoc; **not consistent across all paths** |

### 7.6 Leave application → Approval → Attendance

| Step | Module | Files | Notification touch points |
|---|---|---|---|
| 1. Leave submitted | school_student_app + school_teacher_app | `school_student_app/lib/features/leave/screens/leave_screen.dart`, `school_teacher_app/lib/features/leave/screens/leave_screen.dart`, `lambda/staff-attendance/src/handlers/submitLeaveRequest.ts`, `my-backend/src/handlers/modules/school-erp/school-leave.ts`, `my-backend/src/handlers/ac-leave.ts` | None today on submission |
| 2. Admin/teacher review | school_admin_app | `school_admin_app/lib/features/leave/screens/leave_screen.dart`, `lambda/staff-attendance/src/handlers/processLeaveRequest.ts` | Already broadcasts `LEAVE_PROCESSED` via `broadcastToStation` in `lambda/staff-attendance/src/handlers/processLeaveRequest.ts` line ~129 |
| 3. Status returned to applicant | school_student_app + school_teacher_app | `school_student_app/lib/core/widgets/ws_notification_listener.dart` (`leave_update` event), same in `school_teacher_app` and `school_admin_app` | Real-time WS push consumed by `WsNotificationListener` |
| 4. Attendance auto-marked for approved leave | Backend → staff-attendance | `lambda/staff-attendance/src/handlers/scheduledAttendanceMarker.ts`, `my-backend/src/handlers/modules/school-erp/school-attendance.ts` | Server emits `WSEventName.AC_ATTENDANCE_MARKED` and `AC_LOW_ATTENDANCE_ALERT` when threshold crossed. `academic_coaching.ts` separately fires SMS/Email to parents on absent students (lines ~1157-1163) |

### 7.7 Exam creation → Result publication → Report card

| Step | Module | Files | Notification touch points |
|---|---|---|---|
| 1. Exam scheduled | school_teacher_app + DukanX AC | `school_teacher_app/lib/features/exams/screens/exams_screen.dart`, `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_exams_screen.dart`, `my-backend/src/handlers/modules/school-erp/school-exams.ts`, `my-backend/src/handlers/ac-exam-extra.ts` | Server emits `WSEventName.AC_EXAM_SCHEDULED` |
| 2. Marks entered | school_teacher_app | same screens, plus `school_teacher_app/.../students_screen.dart` | None today |
| 3. Results published | Backend → school-erp | `my-backend/src/handlers/modules/school-erp/school-exams.ts`, `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_report_cards_screen.dart` | Server emits `WSEventName.AC_RESULTS_PUBLISHED` |
| 4. Student/parent view results | school_student_app | `school_student_app/lib/features/results/screens/results_screen.dart`, `school_student_app/lib/features/exams/screens/exams_screen.dart` | Real-time via `wsNotificationsProvider`. SMS/Email/WhatsApp via `academic_coaching.ts` `sendNotification` flow |
| 5. Report card generated | DukanX AC | `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_report_cards_screen.dart`, `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_certificate_generator_screen.dart` | None today |

### 7.8 Other significant cross-module flows (informational)

- **Trial signup → expiry → block.** `lambda/trialProvisioningHandler/index.mjs` → `lambda/trialNotificationSchedulerHandler/index.mjs` → `lambda/trialExpiryCronHandler/index.mjs` (all SNS). Trigger points captured in §9.
- **Smart-inventory bulk import.** `my-backend/src/handlers/import-product-file.ts` → `process-import-row.ts` → emits `IMPORT_PROGRESS`, `IMPORT_COMPLETED`, `IMPORT_FAILED` via WS.
- **In-store self-scan checkout.** `my-backend/src/handlers/in-store-session.ts` → `in-store-barcode.ts` → `in-store-checkout.ts` → `in-store-streams.ts` (FCM push to customer + WS to store dashboard).
- **DC quote → invoice conversion.** `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart` → `my-backend/src/handlers/dc.ts` → `WSEventName.DC_QUOTE_CONVERTED` + `DC_INVOICE_CREATED`.
- **Jewellery: gold rate alert.** `Dukan_x/lib/features/jewellery/presentation/screens/gold_rate_alert_screen.dart` → `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` (uses local `NotificationService.showLocalNotification`).
- **Customer recovery visits.** `Dukan_x/lib/features/customers/presentation/screens/customer_management_screen.dart`, `my-backend/src/handlers/recovery-visits.ts`, `my-backend/src/handlers/credit-reminders.ts`.


---

## 8. Existing Notification Helpers, Emitters, Webhooks, Sockets, Pub/Sub

This is the **complete inventory** of code that today produces, persists, transports, or renders a notification. UNS will replace each entry per the migration plan in §12.

### 8.1 Per-feature notification helpers and services (Flutter)

| File | Symbol(s) | Role | Storage / channel today |
|---|---|---|---|
| `Dukan_x/lib/features/service/services/service_job_notification_service.dart` | `ServiceJobNotificationService`, `ServiceJobNotification`, `dispatchNotification`, `markAsDelivered` | Generates per-status (received/diagnosing/repairing/ready/delivered/cancelled) service-job notifications and fires `BusinessEvent.jobStatusChanged`. Has a `// TODO push integration` stub at line ~292. | In-process Stream + EventDispatcher |
| `Dukan_x/lib/features/restaurant/domain/services/restaurant_notification_service.dart` | `RestaurantNotificationService` (singleton), `_notificationsPlugin: FlutterLocalNotificationsPlugin`, `notifyNewOrder`, `notifyOrderReady`, `notifyKotItem` | Local OS-level desktop notifications for kitchen/staff. Initialized in `core/di/service_locator.dart` (`await sl<RestaurantNotificationService>().initialize()`) | `flutter_local_notifications` |
| `Dukan_x/lib/core/services/security_notification_service.dart` | `SecurityNotificationService`, `SecurityNotification`, `_handleAlert`, `startListening` / `stopListening` | Subscribes to `FraudDetectionService.fraudAlerts` stream, persists to `FraudAlertRepository`, exposes `SecurityNotification` Stream for UI. Initialized in `core/services/security_layer.dart` | In-process Stream + Drift table (via `FraudAlertRepository`) |
| `Dukan_x/lib/core/services/notification_listener_service.dart` | `NotificationListenerService` | Subscribes to `EventDispatcher` events and converts them to persisted vendor notifications via `VendorNotificationRepository` (e.g. `BusinessEvent.stockLow` → `createLowStockNotification`, `BusinessEvent.paymentReceived` → `createPaymentNotification`). | Drift `customer_notifications` table (reused) |
| `Dukan_x/lib/core/services/notification_controller.dart` | `NotificationController` (replaces `PushService`, `NotificationService`, `FirebaseMessagingService`) | Combined push + local notification controller. Wraps `FirebaseMessaging.instance` and `flutter_local_notifications`. | FCM + `flutter_local_notifications` |
| `Dukan_x/lib/core/repository/vendor_notification_repository.dart` | `VendorNotificationRepository`, `VendorNotificationType`, `VendorNotification`, `createNotification`, `createLowStockNotification`, `createExpiryNotification`, `createPaymentNotification`, `watchNotifications`, `watchUnreadCount`, `markAsRead`, `markAllAsRead`, `deleteOldNotifications` | DukanX-side persisted vendor notifications. Stores in Drift `customer_notifications` table (reused). | Drift |
| `Dukan_x/lib/features/customers/data/customer_notifications_repository.dart` | `CustomerNotificationsRepository`, `customerNotificationsRepositoryProvider`, `customerNotificationsProvider`, `customerUnreadNotificationsCountProvider`, `createNotification`, `markAsRead`, `markAllAsRead`, `watchNotifications`, `watchUnreadCount` | Customer-side persisted notifications. Used by `customer_payment_screen.dart` to record the payment notification event for the buyer. | Drift |
| `Dukan_x/lib/features/customers/presentation/screens/customer_notifications_screen.dart` | `CustomerNotificationsScreen` | Customer-app UI showing the persisted notifications, calls `repo.markAsRead(notification.id)` on tap. | UI consumer |
| `Dukan_x/lib/features/customers/presentation/screens/notification_settings_screen.dart` | `NotificationSettingsScreen` | Per-channel preferences UI for the customer side. | UI consumer |
| `Dukan_x/lib/features/alerts/presentation/screens/alerts_notifications_screen.dart` | `AlertsNotificationsScreen` (consumes `VendorNotificationRepository` + `AlertService`) | Vendor-side alerts/notifications inbox. | UI consumer |
| `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_notifications_screen.dart` | `AcNotificationsScreen`, `AcRepository.listNotificationTemplates`, `AcRepository.sendNotification` | Coaching/school admin UI for SMS/WhatsApp/Email templates and sending. Calls into `my-backend/src/handlers/academic_coaching.ts`. | UI consumer + backend bulk send |
| `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart` | `businessAlertsCountProvider`, alert card UI | Polls + listens to `EventDispatcher.whereAny([stockChanged, stockLow, ...])` to surface real-time alerts on the dashboard. | EventDispatcher consumer |
| `Dukan_x/lib/features/dashboard/presentation/widgets/upcoming_payments_panel.dart` | `UpcomingPaymentsPanel` | Polls (poll-driven) the credit-reminder API to surface upcoming dues. | Polling — to be replaced |
| `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` | `GoldRateAlertRepository`, inner `NotificationService` (with `showLocalNotification`), `_evaluateAlerts`, `_dispatchAlert` | Compares live gold rates against per-user thresholds; pushes a local notification when crossed. **Note: the inner `NotificationService` class is a name conflict that UNS must resolve.** | `flutter_local_notifications` |

### 8.2 Sub-app notification surfaces (Flutter)

| File | Role |
|---|---|
| `school_student_app/lib/features/notifications/screens/notifications_screen.dart` | `NotificationsScreen` — student-app inbox UI. Reads `notificationsProvider` (consumer of the `school_ws_service.dart` stream and the `/ac/notifications` REST endpoint). |
| `school_student_app/lib/core/widgets/ws_notification_listener.dart` | `WsNotificationListener` — wraps the entire screen tree, listens to `wsNotificationsProvider`, shows a real-time banner. |
| `school_admin_app/lib/core/widgets/ws_notification_listener.dart` | Same pattern, admin-side. |
| `school_teacher_app/lib/core/widgets/ws_notification_listener.dart` | Same pattern, teacher-side. |
| `school_admin_app/lib/core/websocket/school_ws_service.dart` | `SchoolWsService`, `wsNotificationsProvider` (filtered Stream of `WsEvent`s). |
| `school_student_app/lib/core/websocket/school_ws_service.dart` | Same per app. |
| `school_teacher_app/lib/core/websocket/school_ws_service.dart` | Same per app. |
| `school_admin_app/lib/features/announcements/screens/announcements_screen.dart`, `school_teacher_app/lib/features/announcements/screens/announcements_screen.dart` | UI-only producers that hit `my-backend/src/handlers/modules/school-erp/school-communication.ts` to fan out announcements (which itself calls `pushNotification` + `wsService.broadcastToBusiness`). |

### 8.3 Backend emitters (Lambda / TypeScript)

| File | Symbol(s) | Channel(s) emitted | Notes |
|---|---|---|---|
| `my-backend/src/services/websocket.service.ts` | `broadcastToBusiness`, `broadcastToStaff`, `broadcastToCustomer`, `broadcastToOwner`, `broadcastToClientType`, `broadcastToDevice`, `broadcastToAll`, `emitEvent`, `saveConnection`, `removeConnection` | API Gateway WebSocket | **Single canonical fan-out point inside `my-backend/`.** |
| `my-backend/src/services/eventbridge.service.ts` | `emitToEventBridge(source, event, detail)`, `EVENT_SOURCE_MAP`, `EVENT_AUDIENCE_MAP` | EventBridge default bus | Emits per-event-name on the bus; consumed by `ws-broadcaster.ts` |
| `my-backend/src/handlers/ws-broadcaster.ts` | `handler` (EventBridge target) | API Gateway WebSocket | Consumes EB events, routes to the right WS audience |
| `my-backend/src/handlers/modules/school-erp/school-notifications.ts` | `pushNotification(userId, payload)` (DynamoDB write), `GET /ac/notifications`, `PUT /ac/notifications/{id}/read`, `PUT /ac/notifications/read-all` | DynamoDB persistence (PK `NOTIF#<userId>`) | **The legacy school-side persisted notifications. Will be replaced by UNS Notification_Store.** |
| `my-backend/src/handlers/academic_coaching.ts` | `sendSmsViaSns(phone, msg, tenantId)`, `sendEmailViaSes(to, subj, body, tenantId)`, `sendWhatsApp(phone, msg, tenantId)` | SNS (SMS), SES (email), WhatsApp Cloud API | Direct delivery from cron + bulk handlers (absent students, fee reminders, exam notices) |
| `my-backend/src/services/whatsapp.service.ts` | `sendTextMessage`, `sendPaymentConfirmation`, etc. | WhatsApp Cloud API | Used by `post-payment.service.ts`, `suppliers.ts`, `academic_coaching.ts` |
| `my-backend/src/services/post-payment.service.ts` | `sendPaymentConfirmation` (calls `whatsapp.service.sendPaymentConfirmation`) | WhatsApp | Per-payment confirmation to customer |
| `my-backend/src/i18n/notification-templates.ts` | `NotificationTemplates.billCreatedPush`, `paymentReceivedPush`, `lowStockPush`, `expiryWarningPush`, `planExpiringPush`, `newOrderPush`, `dailySummaryPush` | Template strings (locale-aware) | **Will be reused by UNS for localized push/SMS/email content.** |
| `my-backend/src/handlers/notification.ts` | DukanX-side push registration & basic notification CRUD | DynamoDB | Will be replaced |
| `my-backend/src/handlers/in-store-streams.ts` | `sendPushNotification(order)` → SNS publish to `FCM_SNS_TOPIC_ARN`; `wsService.broadcastToBusiness(... INVENTORY_UPDATED ...)` | FCM via SNS, WS | Push to customer on in-store payment success |
| `my-backend/src/handlers/in-store-checkout.ts` | `wsService.broadcastToCustomer(tenantId, customerId, PAYMENT_SUCCESS, ...)` | WS | Exit-QR delivery to customer |
| `my-backend/src/handlers/invoices.ts` | `wsService.emitEvent(... BILL_CREATED ...)` (4 call sites: created, finalized, updated, returned) | WS | |
| `my-backend/src/services/invoice.service.ts` | `wsService.emitEvent(... STOCK_UPDATED ...)`, `wsService.emitEvent(... LOW_STOCK_ALERT ...)`, `wsService.emitEvent(... INVOICE_CREATED ...)` (lines ~1472, 1479, 1490) | WS | |
| `my-backend/src/handlers/inventory.ts` | `wsService.broadcastToBusiness(... INVENTORY_UPDATED ...)` (4 sites: created, updated, deleted, stock_adjusted), `wsService.emitEvent(... LOW_STOCK_ALERT ...)` (2 sites) | WS | |
| `my-backend/src/handlers/payments.ts` | `wsService.emitEvent(... PAYMENT_SUCCESS ...)` | WS | |
| `my-backend/src/handlers/payment-webhook.ts` | `wsService.broadcastToBusiness(... PAYMENT_SUCCESS / PAYMENT_FAILED ...)` | WS | |
| `my-backend/src/handlers/staff-sale.ts` | `wsService.broadcastToBusiness(... STAFF_SALE_CREATED ...)` | WS | |
| `my-backend/src/handlers/restaurant-v1-public.ts` | `wsService.broadcastToStaff(... ORDER_CREATED ...)` | WS | |
| `my-backend/src/handlers/resto.ts` | `wsService.broadcastToClientType(... RESTAURANT_STAFF_APP, BILL_UPDATED ...)` (2 sites) | WS | |
| `my-backend/src/handlers/pump.ts` | `wsService.emitEvent(... STAFF_ACTIVITY ...)` (multiple actions: readings_recorded, pump_sale, cash_drop), `wsService.emitEvent(... PETROL_SALE_UPDATE / DIESEL_SALE_UPDATE ...)`, `wsService.emitEvent(... SHIFT_OPENED ...)`, `wsService.emitEvent(... SHIFT_CLOSED ...)` | WS | |
| `my-backend/src/handlers/process-import-row.ts` | `emitEvent(tenantId, IMPORT_PROGRESS / IMPORT_COMPLETED / IMPORT_FAILED, ...)` (4 sites) | WS | |
| `my-backend/src/handlers/dc.ts` | `wsService.broadcastTo*(... DC_EVENT_CREATED / DC_EVENT_UPDATED / DC_EVENT_STATUS_CHANGED / DC_INVOICE_CREATED / DC_PAYMENT_RECEIVED / DC_EXPENSE_ADDED / DC_STAFF_ASSIGNED / DC_INVENTORY_LOW_STOCK / DC_QUOTE_CONVERTED / DC_KOT_CREATED / DC_KOT_UPDATED ...)` | WS | |
| `my-backend/src/handlers/suppliers.ts` | `whatsapp.sendTextMessage(phone, msg)` (manual dunning trigger) | WhatsApp | |
| `my-backend/src/websocket/pharmacy-websocket.handler.ts` | `sendToClient(... type: 'notification' ...)` (browser notification path), broadcasts on `inventory.update`, `prescription.dispensed`, `activity.new`, `stock.alert` | WS (browser-style notification frame) | |
| `lambda/marketplace/wsHandler/index.ts` | `broadcastToRoom(...)` (orders, deliveries, customer cart updates) | API Gateway WebSocket (marketplace) | |
| `lambda/marketplace/deliveryHandler/index.ts` | (location update WS broadcast — implementation comment only) | WS | |
| `lambda/staff-attendance/src/handlers/processLeaveRequest.ts` | `broadcastToStation(stationId, wsEndpoint, { type: 'LEAVE_PROCESSED', payload: ... })` | WS | |
| `lambda/staff-attendance/src/handlers/staffCheckIn.ts`, `staffCheckOut.ts` | `broadcastToStation(... STAFF_CHECKED_IN / STAFF_CHECKED_OUT ...)` | WS | |
| `lambda/trialProvisioningHandler/index.mjs` | `sns.send(new PublishCommand({ TopicArn: SNS_TRIAL_TOPIC_ARN, Message: ... }))` | SNS | |
| `lambda/trialNotificationSchedulerHandler/index.mjs` | Same pattern (T-7/T-3/T-1 reminders) | SNS | |
| `lambda/trialExpiryCronHandler/index.mjs` | Same pattern (TRIAL_EXPIRED) | SNS | |

### 8.4 Frontend WebSocket clients (consumers)

| File | Subscribed to |
|---|---|
| `Dukan_x/lib/core/services/websocket_service.dart` (canonical, re-exported by `Dukan_x/lib/services/websocket_service.dart`) | All `WSEventName` events; exposes `subscribe(eventName, handler)` |
| `Dukan_x/lib/app/app.dart` | `WSEventName.adminAction` |
| `Dukan_x/lib/features/inventory/presentation/screens/inventory_dashboard_screen.dart` | `inventoryUpdated`, `lowStockAlert` |
| `Dukan_x/lib/features/staff/presentation/screens/staff_sale_entry_screen.dart` | `paymentSuccess` |
| `Dukan_x/lib/features/restaurant/presentation/screens/restaurant_owner_command_screen.dart` | `orderCreated`, `orderUpdated`, `billUpdated`, `paymentSuccess`, `staffLogin`, `staffLogout`, `staffActivity` |
| `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_dashboard_screen.dart` | All `DC_*` event names |
| `Dukan_x/lib/features/dashboard/v2/providers/pharmacy_dashboard_providers.dart` | `inventoryUpdated`, `prescriptionCreated` |
| `Dukan_x/lib/features/dashboard/v2/providers/dashboard_v2_providers.dart` | `inventoryUpdated`, `lowStockAlert` |
| `Dukan_x/lib/providers/tenant_config_provider.dart` | `manifest_invalidated` |
| `school_*_app/lib/core/websocket/school_ws_service.dart` (×3) | All school-relevant events; `wsNotificationsProvider` exposes a filtered list |

### 8.5 Persistence stores in scope

| Store | Where | Used for |
|---|---|---|
| Drift `customer_notifications` table | `Dukan_x/lib/core/database/app_database.dart` | DukanX vendor-side + customer-side persisted notifications (reused by both `VendorNotificationRepository` and `CustomerNotificationsRepository`) |
| DynamoDB partition `NOTIF#<userId>` | `my-backend/src/handlers/modules/school-erp/school-notifications.ts` | School-side persisted notifications |
| DynamoDB `dukan-saas-dev-trial-notifications` (implied via SNS topic) | `lambda/trialNotificationSchedulerHandler/index.mjs` | Trial-lifecycle reminders |
| (Sub-apps have **no** persistent store today — only in-memory `wsNotificationsProvider`) | n/a | Gap captured in §11 |

### 8.6 Webhooks today

| Webhook receiver | File | Producer |
|---|---|---|
| Razorpay payment webhook | `my-backend/src/handlers/payment-webhook.ts`, `my-backend/src/handlers/payment/webhook-handler.ts`, `lambda/fuelposHandler/razorpayWebhook.ts` | Razorpay |
| Razorpay subscription webhook | `my-backend/src/handlers/subscription-webhook.ts` | Razorpay subscriptions |
| Cognito triggers (post-confirm / pre-token) | `my-backend/src/handlers/cognito-triggers.ts`, `lambda/cognitoPreTokenTrigger/index.mjs`, `lambda/customerOnboardingTrigger/index.mjs` | Cognito |

> Note: there is **no outbound webhook channel** today (UNS will add the `webhook` channel adapter — REQ 5.5, 5.12, 5.13).


---

## 9. Trigger_Point Catalogue

> **Format**: each row is `(file_path, symbol, event_name_candidate, observed_state_change)` followed by an explicit `justified` (with **recipient**, **reason**, **action**) or `rejected` (with **reason**) status, satisfying **REQ 1.5, 1.11, 1.11a**.
> **Convention**: `event_name_candidate` is in `<domain>.<entity>.<action>` snake_case to match REQ 2.6.
> **Status legend**: ✅ `justified` — has all three of recipient + reason + action; ❌ `rejected` — failed at least one of those three; counted in §12 hand-off.
> Trigger_Points are grouped by domain. Numbering is `T-<domain_short>-<n>`.

### 9.1 Billing / Invoicing

| ID | File | Symbol | Event candidate | State change | Status |
|---|---|---|---|---|---|
| T-BIL-1 | `Dukan_x/lib/core/repository/bills_repository.dart` | `createBill` (line ~600) calling `eventDispatcher.invoiceCreated(...)` | `billing.invoice.created` | New invoice persisted (offline-first) | ✅ **justified** — Recipient: shop owner + cashier on every connected device of the same tenant. Reason: keep dashboard KPIs and bills list in sync without polling. Action: refresh dashboard / bills list; shop owner sees new revenue. |
| T-BIL-2 | `my-backend/src/handlers/invoices.ts` | `createInvoice` → `wsService.emitEvent(... BILL_CREATED ...)` (line ~116) | `billing.invoice.created` | Server-side invoice committed | ✅ **justified** — Recipient: same tenant's connected DukanX devices and any sub-app with the user. Reason: cross-device sync. Action: refresh local cache + dashboard. |
| T-BIL-3 | `my-backend/src/handlers/invoices.ts` | `finalizeInvoice` → `BILL_CREATED` action `finalized` (line ~154) | `billing.invoice.finalized` | Invoice status `draft → final` | ✅ **justified** — Recipient: shop owner, cashier, accountant. Reason: finalized invoices are reportable; counts as revenue. Action: include in P&L, GST report. |
| T-BIL-4 | `my-backend/src/handlers/invoices.ts` | `updateInvoice` → `BILL_CREATED` action `updated` (line ~255) | `billing.invoice.updated` | Invoice header/items modified | ✅ **justified** — Recipient: shop owner, cashier. Reason: drift detection — invoice shape changed. Action: refresh views; if customer is the recipient (shared invoice), update their copy. |
| T-BIL-5 | `my-backend/src/handlers/invoices.ts` | `processReturn` → `BILL_CREATED` action `returned` (line ~295) | `billing.invoice.returned` | Return processed against invoice | ✅ **justified** — Recipient: shop owner, cashier, accountant; the customer who originated the return. Reason: refund processing kicks off; ledgers must update. Action: issue credit note, adjust outstanding. |
| T-BIL-6 | `my-backend/src/services/invoice.service.ts` | `saveInvoice` → `INVOICE_CREATED` (line ~1490) | `billing.invoice.created` (server canonical) | Same as T-BIL-2 from service layer | ❌ **rejected** — duplicate of T-BIL-2 from a different layer. UNS will collapse the two into one canonical emit at the service layer. Reason: avoid double-fan-out. |
| T-BIL-7 | `Dukan_x/lib/features/billing/presentation/screens/return_bill_screen.dart` | return action submit | `billing.invoice.returned` | Local-side return persisted | ✅ **justified** — Recipient: customer (returning party), shop owner. Reason: customer needs visibility, owner needs audit. Action: customer sees return acknowledged in their notification drawer. |
| T-BIL-8 | `Dukan_x/lib/features/credit_notes/presentation/screens/credit_note_screen.dart` | credit note save | `billing.credit_note.issued` | New credit note created | ✅ **justified** — Recipient: customer named on the note, accountant. Reason: customer must see the credit (it's their money). Action: customer's "available credit" balance updates. |
| T-BIL-9 | `Dukan_x/lib/features/billing/screens/dunning_config_screen.dart` | save dunning config | `billing.dunning.configured` | Dunning rules updated | ❌ **rejected** — configuration change with no external recipient who needs an action; only the configurator sees it. Reason: not user-actionable for any other role. |

### 9.2 Payments / Refunds

| ID | File | Symbol | Event candidate | State change | Status |
|---|---|---|---|---|---|
| T-PAY-1 | `Dukan_x/lib/core/repository/bills_repository.dart` | `eventDispatcher.paymentReceived(...)` (line ~672) | `payment.invoice.received` | Payment recorded against an invoice (offline-first) | ✅ **justified** — Recipient: shop owner, cashier, the paying customer. Reason: customer wants confirmation; shop wants ledger update. Action: customer's outstanding decreases; shop's daily collection increases. |
| T-PAY-2 | `my-backend/src/handlers/payments.ts` | `recordPayment` → `wsService.emitEvent(... PAYMENT_SUCCESS ...)` (line ~317) | `payment.invoice.received` (server canonical) | Server-side payment committed | ✅ **justified** — Recipient: shop owner, cashier, accountant, customer. Reason: cross-device + cross-app sync. Action: same as T-PAY-1 over the wire. |
| T-PAY-3 | `my-backend/src/handlers/payment-webhook.ts` | webhook `result.status === 'success'` → `PAYMENT_SUCCESS` (line ~194) | `payment.gateway.success` | Razorpay/PhonePe webhook says payment cleared | ✅ **justified** — Recipient: paying customer + shop owner. Reason: gateway is asynchronous; both parties learn here. Action: invoice marked paid; customer redirected from "pending" UI. |
| T-PAY-4 | `my-backend/src/handlers/payment-webhook.ts` | webhook `result.status === 'failed'` → `PAYMENT_FAILED` (line ~194) | `payment.gateway.failed` | Razorpay/PhonePe webhook says payment failed | ✅ **justified** — Recipient: paying customer + shop owner. Reason: customer must retry; shop must not ship. Action: customer sees retry CTA. |
| T-PAY-5 | `my-backend/src/services/post-payment.service.ts` | `whatsappService.sendPaymentConfirmation(...)` (line ~120) | `payment.confirmation.sent` | WhatsApp confirmation dispatched | ❌ **rejected** — this is a *delivery side-effect* of T-PAY-2, not a separate triggerable event. UNS subsumes this into the `payment.invoice.received` event with a `whatsapp` channel selection. |
| T-PAY-6 | `my-backend/src/handlers/payment/process-refund.ts` | refund creation | `payment.refund.processed` | Refund created against an invoice | ✅ **justified** — Recipient: customer being refunded + accountant. Reason: customer needs to know money is on the way; accountant must reconcile. Action: customer's transactions list shows refund; accountant adjusts books. |
| T-PAY-7 | `Dukan_x/lib/features/revenue/screens/refund_screen.dart` | refund submit | `payment.refund.processed` | Local-side refund persisted | ✅ **justified** — same as T-PAY-6, frontend trigger. |
| T-PAY-8 | `Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart` | `customerNotificationsRepository.createNotification(...)` (line ~515) | `payment.customer.confirmation` | Customer-app persisted notification on payment | ❌ **rejected** — duplicate persistence path of T-PAY-2's WS event. UNS replaces with a single notification emitted by the server and persisted in the canonical store. |
| T-PAY-9 | `Dukan_x/lib/features/staff/presentation/screens/staff_sale_entry_screen.dart` | WS subscribe to `WSEventName.paymentSuccess` (line ~664) | n/a (consumer) | Consumer of T-PAY-3 | n/a — consumer, not a producer; not a Trigger_Point. |

### 9.3 Inventory / Stock

| ID | File | Symbol | Event candidate | State change | Status |
|---|---|---|---|---|---|
| T-INV-1 | `Dukan_x/lib/core/repository/products_repository.dart` | `updateProduct` / `adjustStock` → `eventDispatcher.stockChanged(...)` (lines ~580, 691) | `inventory.stock.changed` | Local stock quantity changed | ✅ **justified** — Recipient: cashier on the same device, shop owner. Reason: keep cart and dashboards correct. Action: refresh availability before selling. |
| T-INV-2 | `Dukan_x/lib/core/repository/products_repository.dart` | post-update `if (currentStock <= lowStockThreshold) eventDispatcher.stockLow(...)` (lines ~590, 701) | `inventory.stock.low` | Stock crossed `lowStockThreshold` | ✅ **justified** — Recipient: shop owner, purchase manager. Reason: triggers reorder. Action: create PO. |
| T-INV-3 | `my-backend/src/handlers/inventory.ts` | `createInventoryItem` → `wsService.broadcastToBusiness(... INVENTORY_UPDATED action: 'created' ...)` (line ~81) | `inventory.item.created` | Server-side inventory item created | ✅ **justified** — Recipient: same tenant's connected devices. Reason: catalog sync. Action: refresh local product list. |
| T-INV-4 | `my-backend/src/handlers/inventory.ts` | `updateInventoryItem` → `INVENTORY_UPDATED action: 'updated'` (line ~162) | `inventory.item.updated` | Server-side item updated | ✅ **justified** — same as T-INV-3. |
| T-INV-5 | `my-backend/src/handlers/inventory.ts` | post-update low-stock branch → `LOW_STOCK_ALERT` (line ~169) | `inventory.stock.low` (server) | Stock <= threshold after update | ✅ **justified** — Recipient: shop owner, purchase manager, optionally accountant. Reason: reorder. Action: create PO. |
| T-INV-6 | `my-backend/src/handlers/inventory.ts` | `deleteInventoryItem` → `INVENTORY_UPDATED action: 'deleted'` (line ~194) | `inventory.item.deleted` | Server-side item removed | ✅ **justified** — Recipient: same tenant's connected devices. Reason: catalog sync. Action: drop item from cart, remove from list. |
| T-INV-7 | `my-backend/src/handlers/inventory.ts` | `adjustStock` → `INVENTORY_UPDATED action: 'stock_adjusted'` (line ~229) | `inventory.stock.adjusted` | Manual adjustment posted | ✅ **justified** — Recipient: shop owner, accountant (audit trail). Reason: anomalous adjustments require oversight. Action: review reason field. |
| T-INV-8 | `my-backend/src/services/invoice.service.ts` | post-sale stock decrement → `STOCK_UPDATED` (line ~1472) | `inventory.stock.decremented_by_sale` | Sale reduces stock | ✅ **justified** — Recipient: cashier on other devices of the same tenant. Reason: avoid overselling on a second terminal. Action: recompute available qty. |
| T-INV-9 | `my-backend/src/services/invoice.service.ts` | post-sale low-stock → `LOW_STOCK_ALERT` (line ~1479) | `inventory.stock.low` | Sale crosses threshold | ✅ **justified** — same as T-INV-5. |
| T-INV-10 | `Dukan_x/lib/features/inventory/services/pharmacy_migration_service.dart` (and `Dukan_x/lib/features/credit_notes/services/supplier_expiry_return_service.dart`) | expiry detection | `inventory.batch.expiring` / `inventory.batch.expired` | Batch crosses expiry threshold | ✅ **justified** — Recipient: shop owner, purchase manager (and pharmacist for pharmacy). Reason: prevent selling expired stock; trigger supplier return. Action: pull stock; initiate return. |
| T-INV-11 | `my-backend/src/handlers/grocery-expiry.ts` | scheduled scan | `inventory.batch.expiring` | Same as T-INV-10 (server canonical) | ✅ **justified** — same as T-INV-10. |
| T-INV-12 | `Dukan_x/lib/features/inventory/presentation/screens/import_inventory_screen.dart`, `my-backend/src/handlers/process-import-row.ts` | `emitEvent(... IMPORT_PROGRESS / IMPORT_COMPLETED / IMPORT_FAILED ...)` (4 sites) | `inventory.import.progress` / `inventory.import.completed` / `inventory.import.failed` | Bulk import lifecycle | ✅ **justified** — Recipient: the user who started the import. Reason: progress feedback for a long-running task. Action: review errors / open new catalog. |

### 9.4 Purchase / Goods receipt

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-PUR-1 | `Dukan_x/lib/features/purchase/screens/add_purchase_screen.dart` (commit) → eventually `eventDispatcher.purchaseOrderCreated(...)` via `bills_repository`/`buy_flow` | save | `purchase.order.created` | ✅ **justified** — Recipient: shop owner, accountant, supplier (if configured). Reason: PO creates a payable; supplier needs to fulfil. Action: send copy to supplier; record payable. |
| T-PUR-2 | `Dukan_x/lib/features/buy_flow/screens/stock_entry_screen.dart` | save | `purchase.goods.received` | ✅ **justified** — Recipient: shop owner, cashier (selling). Reason: stock now sellable. Action: refresh inventory. |
| T-PUR-3 | `Dukan_x/lib/features/buy_flow/screens/supplier_bills_screen.dart` | save | `purchase.bill.added` | ✅ **justified** — Recipient: accountant, shop owner. Reason: payables update. Action: schedule payment. |
| T-PUR-4 | `Dukan_x/lib/features/buy_flow/screens/vendor_payouts_screen.dart` | save | `purchase.payment.made` | ✅ **justified** — Recipient: supplier, accountant. Reason: supplier wants confirmation; accountant updates books. Action: supplier marks dues cleared. |
| T-PUR-5 | `Dukan_x/lib/features/purchase/presentation/screens/scan_bill_review_screen.dart` | review confirmed | `purchase.scan_bill.confirmed` | ✅ **justified** — same as T-PUR-1 from the OCR path. |
| T-PUR-6 | `my-backend/src/handlers/purchase-order-matching.ts` | match completed | `purchase.po.matched_to_grn` | ✅ **justified** — Recipient: accountant. Reason: 3-way match enables payment. Action: release payment. |
| T-PUR-7 | `Dukan_x/lib/features/buy_flow/screens/stock_reversal_screen.dart` | reversal | `purchase.goods.reversed` | ✅ **justified** — Recipient: shop owner, supplier (if return). Reason: rolling back inventory must be visible. Action: confirm return / adjust ledger. |
| T-PUR-8 | `my-backend/src/handlers/suppliers.ts` (around line 612) | `whatsapp.sendTextMessage(...)` for outstanding payables | `purchase.payable.reminder_sent` | ❌ **rejected** — manual operator-triggered reminder is *not* a system event; it's a user action that uses the delivery layer directly. UNS will fold this into a `purchase.payable.overdue` event whose `whatsapp` channel emit is the right place. |

### 9.5 Customer / Vendor management

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-CUS-1 | `Dukan_x/lib/features/customers/presentation/screens/add_customer_screen.dart` | save | `customer.profile.created` | ❌ **rejected** — internal CRUD with no recipient who needs an action beyond "this device's UI". REQ 2.9 requires a complete justification (recipient + reason + action) for *every* `*.create`/`*.update`/`*.delete`. None can be supplied. |
| T-CUS-2 | `Dukan_x/lib/features/customers/presentation/screens/customer_management_screen.dart` (delete) | delete | `customer.profile.deleted` | ❌ **rejected** — same as T-CUS-1. |
| T-CUS-3 | `Dukan_x/lib/features/shop_linking/presentation/screens/qr_scanner_screen.dart`, `qr_display_screen.dart`, `shop_confirmation_screen.dart` | accept link | `customer.shop.linked` | ✅ **justified** — Recipient: both customer and shop. Reason: bidirectional link establishes trust + enables future notifications to that customer. Action: shop appears in customer's "My linked shops"; shop sees the customer in their CRM. |
| T-CUS-4 | `Dukan_x/lib/screens/customer_link_accept_screen.dart` | accept | `customer.shop.link_accepted` | ✅ **justified** — same workflow as T-CUS-3, the acceptance event. |
| T-CUS-5 | `Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart` | manual collection | `customer.collection.recorded` | ✅ **justified** — Recipient: customer (their dues went down), shop owner. Reason: ledger update. Action: customer sees ledger reduce. |
| T-CUS-6 | `Dukan_x/lib/features/party_ledger/screens/collect_payment_screen.dart` | save | `vendor.payment.collected` | ✅ **justified** — Recipient: vendor / supplier, accountant. Reason: payable cleared. Action: vendor confirms; accountant updates books. |
| T-CUS-7 | `my-backend/src/handlers/recovery-visits.ts` | visit recorded | `customer.recovery.visit_recorded` | ✅ **justified** — Recipient: shop owner. Reason: dunning workflow audit. Action: review next-action plan. |
| T-CUS-8 | `my-backend/src/handlers/credit-reminders.ts` | reminder sent | `customer.credit.reminder_sent` | ✅ **justified** — Recipient: customer (the recipient of the reminder), shop owner (for tracking). Reason: customer needs to act; shop needs to track. Action: customer pays / arranges payment. |
| T-CUS-9 | `Dukan_x/lib/features/credit_network/...` (cross-shop credit) | shared assessment | `customer.credit_network.flag_added` | ❌ **rejected** — currently a closed-data feature; sharing with other shops is a privacy decision for Phase 2 to revisit. Reason: no documented recipient; cross-tenant share would need explicit justification. |

### 9.6 Jewellery operations

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-JEW-1 | `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` | `_dispatchAlert` → `_notificationService.showLocalNotification(...)` | `jewellery.gold_rate.alert_triggered` | ✅ **justified** — Recipient: shop owner (and registered customer with subscribed alert). Reason: real-time price thresholds drive buying/selling decisions. Action: place buy/sell order. |
| T-JEW-2 | `Dukan_x/lib/features/jewellery/presentation/screens/gold_rate_management_screen.dart` | save new rate | `jewellery.gold_rate.updated` | ✅ **justified** — Recipient: every connected device of the tenant. Reason: pricing changes invalidate quotes and bills. Action: refresh active POS sessions. |
| T-JEW-3 | `Dukan_x/lib/features/jewellery/presentation/screens/custom_order_management_screen.dart` | status change | `jewellery.custom_order.status_changed` | ✅ **justified** — Recipient: customer who placed the order, jewellery_artisan working on it, shop owner. Reason: customer is waiting; artisan owns next step. Action: customer sees ETA; artisan picks up next stage. |
| T-JEW-4 | `Dukan_x/lib/features/jewellery/presentation/screens/jewellery_repair_screen.dart` | status change | `jewellery.repair.status_changed` | ✅ **justified** — Recipient: customer, artisan, shop owner. Reason: same as T-JEW-3. Action: same. |
| T-JEW-5 | `Dukan_x/lib/features/jewellery/presentation/screens/gold_scheme_screen.dart` | scheme matured | `jewellery.gold_scheme.matured` | ✅ **justified** — Recipient: customer (the depositor), shop owner. Reason: maturity triggers a payout/redemption window. Action: customer redeems/extends scheme. |
| T-JEW-6 | `Dukan_x/lib/features/jewellery/presentation/screens/old_gold_exchange_screen.dart` | save | `jewellery.old_gold.exchange_recorded` | ✅ **justified** — Recipient: customer (their exchange credit issued), accountant. Reason: customer must see the credit. Action: customer applies credit on next purchase. |
| T-JEW-7 | `Dukan_x/lib/features/jewellery/presentation/screens/hallmark_inventory_screen.dart` | hallmark received | `jewellery.hallmark.received` | ✅ **justified** — Recipient: shop owner. Reason: hallmarked stock is sellable. Action: move from "in transit" to "available". |
| T-JEW-8 | `Dukan_x/lib/features/jewellery/presentation/screens/making_charges_calculator_screen.dart` | calculation only | `jewellery.making_charges.computed` | ❌ **rejected** — calculation, no state change requiring another user. Reason: stays inside the active session. |

### 9.7 Restaurant operations

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-RES-1 | `my-backend/src/handlers/restaurant-v1-public.ts` | `wsService.broadcastToStaff(... ORDER_CREATED ...)` (line ~351) | `restaurant.order.created` | ✅ **justified** — Recipient: chef, kitchen_staff, waiter. Reason: kitchen must start cooking. Action: produce KOT. |
| T-RES-2 | `my-backend/src/handlers/modules/restaurant/restaurant-kot.ts` | KOT create / status updates | `restaurant.kot.created` / `restaurant.kot.status_changed` / `restaurant.kot.item_cancelled` | ✅ **justified** — Recipient: kitchen (status change), waiter (ready), shop owner (audit). Reason: kitchen ↔ floor coordination. Action: serve / cancel. |
| T-RES-3 | `Dukan_x/lib/features/restaurant/presentation/screens/kitchen_display_screen.dart` | mark ready | `restaurant.kot.item_ready` | ✅ **justified** — Recipient: waiter, customer (if order-tracking enabled). Reason: dish ready for pickup. Action: waiter picks up; customer sees status. |
| T-RES-4 | `my-backend/src/handlers/resto.ts` (lines ~2066, 2150) | `BILL_UPDATED` to `RESTAURANT_STAFF_APP` | `restaurant.bill.updated` | ✅ **justified** — Recipient: cashier on staff app. Reason: keep terminal in sync with bill changes. Action: refresh bill view. |
| T-RES-5 | `Dukan_x/lib/features/restaurant/presentation/screens/restaurant_table_ops_screen.dart` | seat / settle table | `restaurant.table.status_changed` | ✅ **justified** — Recipient: waiter, host. Reason: table availability for new walk-ins. Action: seat next party. |
| T-RES-6 | `Dukan_x/lib/features/restaurant/presentation/screens/customer/order_tracking_screen.dart` | (consumer of T-RES-2/3) | n/a | n/a — consumer. |
| T-RES-7 | `my-backend/src/handlers/modules/restaurant/restaurant-delivery.ts` | dispatch | `restaurant.delivery.dispatched` | ✅ **justified** — Recipient: customer, delivery_agent. Reason: customer wants ETA; agent has next pickup. Action: agent goes to address. |
| T-RES-8 | `Dukan_x/lib/features/restaurant/presentation/screens/customer/rate_review_screen.dart` | review submitted | `restaurant.review.submitted` | ❌ **rejected** — at the moment, no operational role acts on a review immediately. Reason: review → analytics, not real-time notifications. (Phase 2 may revisit if shop owner subscribes.) |

### 9.8 Clinic / Pharmacy operations

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-CLN-1 | `Dukan_x/lib/features/clinic/presentation/screens/clinic_calendar_screen.dart`, `Dukan_x/lib/features/doctor/presentation/screens/appointment_screen.dart`, `my-backend/src/handlers/clinic-scheduler.ts` | appointment created | `clinic.appointment.created` | ✅ **justified** — Recipient: patient, clinic_doctor, front desk. Reason: schedule + reminders. Action: patient sees confirmation; doctor sees agenda. |
| T-CLN-2 | `my-backend/src/handlers/clinic-scheduler.ts` | reminder due | `clinic.appointment.reminder_due` | ✅ **justified** — Recipient: patient. Reason: reduce no-shows. Action: patient confirms / reschedules. |
| T-CLN-3 | `Dukan_x/lib/features/clinic/presentation/screens/patient_queue_screen.dart` | queue advance | `clinic.queue.advanced` | ✅ **justified** — Recipient: next patient. Reason: queue position changed, walk to room. Action: enter consultation room. |
| T-CLN-4 | `Dukan_x/lib/features/doctor/presentation/screens/add_prescription_screen.dart`, `my-backend/src/handlers/pharmacy.ts` | prescription saved | `clinic.prescription.created` | ✅ **justified** — Recipient: patient, pharmacist. Reason: patient picks up meds; pharmacist dispenses. Action: dispense / pay. |
| T-CLN-5 | `my-backend/src/handlers/modules/pharmacy/pharmacy-refills.ts` | refill due | `pharmacy.refill.due` | ✅ **justified** — Recipient: patient, pharmacist. Reason: medication adherence + restock cue. Action: patient orders; pharmacist preps. |
| T-CLN-6 | `Dukan_x/lib/features/pharmacy/screens/narcotic_register_screen.dart`, `my-backend/src/handlers/modules/pharmacy/pharmacy-narcotic.ts` | narcotic entry | `pharmacy.narcotic.entry_recorded` | ✅ **justified** — Recipient: pharmacist (acknowledgement), shop owner (compliance). Reason: regulatory audit trail. Action: confirm log; flag if anomaly. |
| T-CLN-7 | `Dukan_x/lib/features/doctor/presentation/screens/lab_reports_screen.dart`, `Dukan_x/lib/features/clinic/presentation/screens/lab_order_screen.dart` | lab order created | `clinic.lab.ordered` | ✅ **justified** — Recipient: patient, lab. Reason: patient awaits sample; lab queues task. Action: patient travels to lab; lab schedules. |
| T-CLN-8 | (lab result publication, currently manual) | lab result entered | `clinic.lab.result_published` | ✅ **justified** — Recipient: patient, doctor. Reason: doctor reviews; patient gets care plan. Action: book follow-up. |

### 9.9 Academic Coaching / School

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-SCH-1 | `my-backend/src/handlers/modules/school-erp/school-admissions.ts` | admission accepted | `school.admission.accepted` | ✅ **justified** — Recipient: parent, student, school_admin. Reason: enrollment confirmed; fee schedule activates. Action: pay first instalment. |
| T-SCH-2 | `my-backend/src/handlers/modules/school-erp/school-fees.ts` | fee assigned | `school.fee.assigned` | ✅ **justified** — Recipient: parent, student. Reason: visibility of new fee dues. Action: pay or schedule payment. |
| T-SCH-3 | `my-backend/src/handlers/academic_coaching.ts` (around line 2738) | fee reminder dispatched | `school.fee.reminder_sent` (and `school.fee.overdue` per `WSEventName.AC_FEE_OVERDUE`) | ✅ **justified** — Recipient: parent, school_admin (tracking). Reason: parent must pay; admin must follow up. Action: parent pays; admin escalates. |
| T-SCH-4 | `school_student_app/lib/features/fees/screens/fee_payment_screen.dart`, `my-backend/src/handlers/payments.ts` | fee payment success | `school.fee.collected` (`WSEventName.AC_FEE_COLLECTED`) | ✅ **justified** — Recipient: parent, student, school_admin. Reason: receipt generation; ledger update. Action: download receipt. |
| T-SCH-5 | `my-backend/src/handlers/modules/school-erp/school-attendance.ts`, `lambda/staff-attendance/src/handlers/scheduledAttendanceMarker.ts` | attendance marked | `school.attendance.marked` (`WSEventName.AC_ATTENDANCE_MARKED`) | ✅ **justified** — Recipient: parent, student. Reason: daily attendance visibility. Action: parent follows up on absence. |
| T-SCH-6 | `my-backend/src/handlers/academic_coaching.ts` (lines ~1157-1163) | absent student → SMS/Email parent | `school.attendance.absent_alert` | ✅ **justified** — Recipient: parent. Reason: same-day absence visibility. Action: contact school. |
| T-SCH-7 | `my-backend/src/handlers/modules/school-erp/school-attendance.ts` | low attendance threshold | `school.attendance.low_alert` (`WSEventName.AC_LOW_ATTENDANCE_ALERT`) | ✅ **justified** — Recipient: parent, school_admin, teacher. Reason: at risk of academic action. Action: intervene. |
| T-SCH-8 | `my-backend/src/handlers/modules/school-erp/school-exams.ts` | exam scheduled | `school.exam.scheduled` (`WSEventName.AC_EXAM_SCHEDULED`) | ✅ **justified** — Recipient: student, parent, teacher. Reason: prep + invigilation planning. Action: study; assign invigilator. |
| T-SCH-9 | `my-backend/src/handlers/modules/school-erp/school-exams.ts` | results published | `school.exam.results_published` (`WSEventName.AC_RESULTS_PUBLISHED`) | ✅ **justified** — Recipient: student, parent, teacher. Reason: result visibility. Action: review marks; download report card. |
| T-SCH-10 | `Dukan_x/lib/features/academic_coaching/presentation/screens/ac_report_cards_screen.dart` | report card generated | `school.report_card.generated` | ✅ **justified** — Recipient: parent, student. Reason: official document available. Action: download / print. |
| T-SCH-11 | `school_student_app/lib/features/leave/screens/leave_screen.dart`, `my-backend/src/handlers/modules/school-erp/school-leave.ts`, `lambda/staff-attendance/src/handlers/submitLeaveRequest.ts` | leave submitted | `school.leave.submitted` | ✅ **justified** — Recipient: teacher / school_admin (approver). Reason: requires approval. Action: approve/reject. |
| T-SCH-12 | `lambda/staff-attendance/src/handlers/processLeaveRequest.ts` (line ~129) | leave approved/rejected | `school.leave.processed` | ✅ **justified** — Recipient: applicant (student/teacher/parent). Reason: applicant needs the decision. Action: plan around result. |
| T-SCH-13 | `my-backend/src/handlers/modules/school-erp/school-students.ts` | student enrolled (transfer) | `school.student.transferred` (`WSEventName.AC_STUDENT_TRANSFERRED`) | ✅ **justified** — Recipient: parent, school_admin, teacher. Reason: roster update. Action: update class roster, parent acknowledges new section. |
| T-SCH-14 | `my-backend/src/handlers/modules/school-erp/school-batches.ts` | batch full | `school.batch.full` (`WSEventName.AC_BATCH_FULL`) | ✅ **justified** — Recipient: school_admin. Reason: stop accepting more admissions in batch. Action: open new batch / waitlist. |
| T-SCH-15 | `my-backend/src/handlers/modules/school-erp/school-timetable.ts` | timetable updated | `school.timetable.updated` (`WSEventName.AC_TIMETABLE_UPDATED`) | ✅ **justified** — Recipient: students, teachers, parents. Reason: class scheduling change. Action: update calendars. |
| T-SCH-16 | `my-backend/src/handlers/modules/school-erp/school-materials.ts` | material uploaded | `school.material.uploaded` (`WSEventName.AC_MATERIAL_UPLOADED`) | ✅ **justified** — Recipient: students, parents. Reason: new study material available. Action: download. |
| T-SCH-17 | `my-backend/src/handlers/modules/school-erp/school-homework.ts` | homework assigned | `school.homework.assigned` | ✅ **justified** — Recipient: students, parents. Reason: due date awareness. Action: complete and submit. |
| T-SCH-18 | `my-backend/src/handlers/modules/school-erp/school-library.ts` | book due / overdue | `school.library.due` / `school.library.overdue` | ✅ **justified** — Recipient: student, parent. Reason: avoid late fees. Action: return book. |
| T-SCH-19 | `my-backend/src/handlers/modules/school-erp/school-hostel.ts` | room assignment / mess update | `school.hostel.room_assigned` / `school.hostel.mess_updated` | ✅ **justified** — Recipient: student, parent. Reason: logistics + dietary planning. Action: occupy room; plan meals. |
| T-SCH-20 | `my-backend/src/handlers/modules/school-erp/school-communication.ts` | announcement | `school.announcement.published` | ✅ **justified** — Recipient: students, parents, teachers (audience-scoped). Reason: school-wide / class-wide info. Action: read; comply. |
| T-SCH-21 | `my-backend/src/handlers/ac-transport.ts` | route assignment / delay | `school.transport.delay` / `school.transport.route_assigned` | ✅ **justified** — Recipient: parent, student. Reason: pickup timing. Action: adjust pickup. |
| T-SCH-22 | `my-backend/src/handlers/ac-payslip.ts`, `my-backend/src/handlers/modules/school-erp/school-payslip.ts` | payslip generated | `school.payslip.generated` | ✅ **justified** — Recipient: teacher / staff. Reason: salary visibility. Action: download. |
| T-SCH-23 | `my-backend/src/handlers/ac-biometric.ts` | biometric punch | `school.biometric.punched` | ❌ **rejected** — captured silently into attendance store; the *attendance marked* event (T-SCH-5) is the user-facing one. Reason: this is a sensor input, not a user notification. |

### 9.10 Service jobs / Warranty (DukanX)

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-SVC-1 | `Dukan_x/lib/features/service/presentation/screens/create_service_job_screen.dart`, `my-backend/src/handlers/service.ts` | create | `service.job.created` (`WSEventName.SERVICE_JOB_CREATED`) | ✅ **justified** — Recipient: customer, service_technician, shop owner. Reason: customer awaits ETA; tech has new job. Action: schedule + drop-off. |
| T-SVC-2 | `Dukan_x/lib/features/service/services/service_job_notification_service.dart` `dispatchNotification` | status change (received/diagnosing/repairing/ready/delivered/cancelled) | `service.job.status_changed` (`WSEventName.SERVICE_STATUS_UPDATED`) | ✅ **justified** — Recipient: customer, service_technician. Reason: customer wants visibility; tech completes handoff. Action: customer comes to collect / pays. |
| T-SVC-3 | `Dukan_x/lib/features/service/services/warranty_claim_service.dart` | claim raised | `service.warranty.claim_raised` | ✅ **justified** — Recipient: shop owner, supplier (warranty provider). Reason: claim eligibility decision needed. Action: validate claim, escalate. |
| T-SVC-4 | `Dukan_x/lib/features/service/presentation/screens/exchange_detail_screen.dart` | exchange completed | `service.exchange.completed` | ✅ **justified** — Recipient: customer. Reason: replacement issued. Action: customer collects. |

### 9.11 Auto Parts / Computer Shop job cards

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-JOB-1 | `Dukan_x/lib/features/auto_parts/presentation/screens/job_card_management_screen.dart` | job card created/updated | `auto_parts.job_card.status_changed` | ✅ **justified** — Recipient: customer (vehicle owner), service_technician. Reason: customer awaits readiness. Action: collect. |
| T-JOB-2 | `Dukan_x/lib/features/computer_shop/presentation/screens/create_job_card_screen.dart`, `job_card_detail_screen.dart` | job card created/updated | `computer_shop.job_card.status_changed` | ✅ **justified** — same as T-JOB-1, computer-shop variant. |
| T-JOB-3 | `Dukan_x/lib/features/computer_shop/presentation/screens/warranty_screen.dart` | warranty registered | `computer_shop.warranty.registered` | ✅ **justified** — Recipient: customer. Reason: customer learns coverage. Action: store warranty card. |
| T-JOB-4 | `Dukan_x/lib/features/computer_shop/presentation/screens/serial_history_screen.dart` | view only | n/a | ❌ **rejected** — read-only screen. Reason: no state change. |

### 9.12 Decoration & Catering

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-DC-1 | `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart`, `my-backend/src/handlers/dc.ts` | quote → booking | `dc.quote.converted` (`WSEventName.DC_QUOTE_CONVERTED`) | ✅ **justified** — Recipient: customer, shop owner, accountant. Reason: confirmed booking creates revenue; advance due. Action: pay advance; block date. |
| T-DC-2 | `dc_event_detail_screen.dart`, handler | event status change | `dc.event.status_changed` (`WSEventName.DC_EVENT_STATUS_CHANGED`) | ✅ **justified** — Recipient: customer, dc_staff. Reason: timeline updates. Action: confirm next step. |
| T-DC-3 | `dc_billing_screen.dart`, handler | invoice created | `dc.invoice.created` (`WSEventName.DC_INVOICE_CREATED`) | ✅ **justified** — Recipient: customer, accountant. Reason: payment due. Action: pay. |
| T-DC-4 | handler | payment received | `dc.payment.received` (`WSEventName.DC_PAYMENT_RECEIVED`) | ✅ **justified** — Recipient: customer, accountant. Reason: receipt + ledger. Action: customer downloads receipt. |
| T-DC-5 | handler | expense added | `dc.expense.added` (`WSEventName.DC_EXPENSE_ADDED`) | ✅ **justified** — Recipient: shop owner. Reason: profitability impact. Action: review. |
| T-DC-6 | handler | staff assigned | `dc.staff.assigned` (`WSEventName.DC_STAFF_ASSIGNED`) | ✅ **justified** — Recipient: assigned staff. Reason: schedule. Action: arrive on time. |
| T-DC-7 | handler | inventory low | `dc.inventory.low` (`WSEventName.DC_INVENTORY_LOW_STOCK`) | ✅ **justified** — Recipient: shop owner. Reason: prevent service disruption. Action: reorder. |
| T-DC-8 | handler | KOT | `dc.kot.created` / `dc.kot.updated` (`WSEventName.DC_KOT_CREATED` / `DC_KOT_UPDATED`) | ✅ **justified** — Recipient: catering kitchen. Reason: cooking schedule. Action: prep. |

### 9.13 Vegetable Broker

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-VEG-1 | `Dukan_x/lib/features/vegetable_broker/data/repositories/vegetable_broker_repository.dart` | reconciliation posted | `vegetable_broker.reconciliation.posted` | ✅ **justified** — Recipient: farmer (supplier), trader. Reason: settlement amount visibility. Action: confirm or dispute. |
| T-VEG-2 | same | dispatch challan | `vegetable_broker.dispatch.created` | ✅ **justified** — Recipient: farmer, trader. Reason: traceability. Action: confirm dispatch. |

### 9.14 Delivery Challan / Dispatch

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-DLV-1 | `Dukan_x/lib/features/delivery_challan/services/delivery_challan_service.dart`, `Dukan_x/lib/features/delivery_challan/presentation/screens/create_delivery_challan_screen.dart`, `my-backend/src/handlers/challans.ts` | challan created | `delivery.challan.created` | ✅ **justified** — Recipient: customer (consignee), delivery_agent. Reason: shipment scheduled; agent has next task. Action: prepare for receipt; agent picks up. |
| T-DLV-2 | `Dukan_x/lib/features/revenue/screens/dispatch_note_screen.dart` | dispatch note created | `delivery.dispatch.created` | ✅ **justified** — same flow. |
| T-DLV-3 | `lambda/marketplace/deliveryHandler/index.ts` | location update | `delivery.location.updated` | ✅ **justified** — Recipient: customer (live tracking). Reason: ETA. Action: be ready. |

### 9.15 Petrol Pump / Staff

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-PMP-1 | `my-backend/src/handlers/pump.ts` (line ~432) | pump sale | `pump.sale.recorded` (`WSEventName.PETROL_SALE_UPDATE` / `DIESEL_SALE_UPDATE`) | ✅ **justified** — Recipient: shop owner. Reason: real-time sales visibility. Action: monitor / reconcile. |
| T-PMP-2 | `my-backend/src/handlers/pump.ts` (line ~440) | shift sales by staff | `pump.staff.activity` (`WSEventName.STAFF_ACTIVITY`) | ✅ **justified** — Recipient: shop owner. Reason: staff performance + audit. Action: review. |
| T-PMP-3 | `my-backend/src/handlers/pump.ts` (line ~544) | cash drop | `pump.cash.dropped` (`WSEventName.STAFF_ACTIVITY` action `cash_drop`) | ✅ **justified** — Recipient: shop owner, accountant. Reason: cash handling audit. Action: verify drop. |
| T-PMP-4 | `my-backend/src/handlers/pump.ts` (line ~662) | shift opened | `pump.shift.opened` (`WSEventName.SHIFT_OPENED`) | ✅ **justified** — Recipient: shop owner. Reason: shift accountability. Action: monitor. |
| T-PMP-5 | `my-backend/src/handlers/pump.ts` (line ~956) | shift closed | `pump.shift.closed` (`WSEventName.SHIFT_CLOSED`) | ✅ **justified** — Recipient: shop owner, accountant. Reason: cash + sales reconciliation. Action: verify totals. |
| T-PMP-6 | `lambda/staff-attendance/src/handlers/staffCheckIn.ts`, `staffCheckOut.ts` | check-in / check-out | `staff.attendance.checked_in` / `staff.attendance.checked_out` | ✅ **justified** — Recipient: shop owner / station manager. Reason: attendance audit. Action: monitor presence. |
| T-PMP-7 | `my-backend/src/handlers/staff-sale.ts` (line ~316) | staff product sale | `staff.sale.recorded` (`WSEventName.STAFF_SALE_CREATED`) | ✅ **justified** — Recipient: shop owner. Reason: incentive + audit. Action: monitor. |

### 9.16 Trial / Subscription / Plan

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-PLN-1 | `lambda/trialProvisioningHandler/index.mjs` | trial provisioned | `tenant.trial.started` | ✅ **justified** — Recipient: shop owner (tenant). Reason: welcome + trial countdown awareness. Action: start using; convert before expiry. |
| T-PLN-2 | `lambda/trialNotificationSchedulerHandler/index.mjs` | T-7 / T-3 / T-1 reminder | `tenant.trial.expiry_reminder` | ✅ **justified** — Recipient: shop owner. Reason: avoid lock-out. Action: upgrade plan. |
| T-PLN-3 | `lambda/trialExpiryCronHandler/index.mjs` | trial expired | `tenant.trial.expired` | ✅ **justified** — Recipient: shop owner. Reason: account locked. Action: pay to unlock. |
| T-PLN-4 | `my-backend/src/handlers/cron/grace-period-cron.ts` | grace period end | `tenant.grace_period.ended` | ✅ **justified** — Recipient: shop owner. Reason: account suspension imminent. Action: pay. |
| T-PLN-5 | `my-backend/src/handlers/subscription-webhook.ts` | renewal success / failure | `tenant.subscription.renewed` / `tenant.subscription.failed` | ✅ **justified** — Recipient: shop owner. Reason: billing visibility. Action: update payment method on failure. |
| T-PLN-6 | `my-backend/src/handlers/feature-flag.ts`, `Dukan_x/lib/providers/tenant_config_provider.dart` (subscribed to `manifest_invalidated`) | feature manifest invalidated | `tenant.manifest.invalidated` (`WSEventName.MANIFEST_INVALIDATED`) | ✅ **justified** — Recipient: every connected device of the tenant. Reason: feature toggle / plan upgrade re-render. Action: refetch manifest. |

### 9.17 Security / Audit / System

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-SEC-1 | `Dukan_x/lib/core/services/security_notification_service.dart` `_handleAlert` (subscribed to `FraudDetectionService.fraudAlerts`) | fraud alert | `security.fraud.alert_raised` | ✅ **justified** — Recipient: shop owner, super_admin. Reason: anomalous transaction needs review. Action: review and act (block / refund / call). |
| T-SEC-2 | `Dukan_x/lib/core/services/cash_closing_validation_service.dart` | cash mismatch detected | `security.cash.mismatch_detected` | ✅ **justified** — Recipient: shop owner, accountant. Reason: investigate cashier. Action: reconcile / interview. |
| T-SEC-3 | `Dukan_x/lib/core/services/stock_security_service.dart` | suspicious stock anomaly | `security.stock.anomaly_detected` | ✅ **justified** — Recipient: shop owner. Reason: investigate shrinkage. Action: stock count. |
| T-SEC-4 | `lambda/auditHandler/index.mjs` | audit row written | n/a | ❌ **rejected** — every audit row would flood. Reason: too high frequency; only specific *security-relevant* audit rows (e.g. `unauthorized_access_attempt` per REQ 12.7) trigger a notification. |
| T-SEC-5 | `my-backend/src/middleware/role-guard.ts`, `my-backend/src/middleware/permission-guard.ts` | unauthorized access attempt (denied) | `security.access.unauthorized_attempt` | ✅ **justified** — Recipient: super_admin (if cross-tenant), shop owner (if within tenant). Reason: security visibility per REQ 12.7. Action: review and possibly disable user. |
| T-SEC-6 | `Dukan_x/lib/core/services/cleanup_service.dart`, `reconciliation_service.dart`, `einvoice_status_service.dart` | scheduled job result | `system.background_job.completed` / `failed` | ❌ **rejected** — silent infrastructure tasks; no end-user action. Reason: noise. Operator dashboards consume them as metrics, not notifications. |
| T-SEC-7 | `my-backend/src/handlers/health.ts` | health-check failure | `system.health.degraded` | ✅ **justified** — Recipient: super_admin only. Reason: operational alerting. Action: investigate. |

### 9.18 Marketplace / Customer App / Pre-Order

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-MKT-1 | `lambda/marketplace/ordersHandler/index.ts` | order placed | `marketplace.order.placed` | ✅ **justified** — Recipient: customer, store/shop owner, delivery_agent. Reason: fulfilment kicks off. Action: pick + pack + ship. |
| T-MKT-2 | `lambda/marketplace/cartHandler/index.ts` | cart updated (push to other devices) | `marketplace.cart.updated` | ❌ **rejected** — high-frequency churn, no other user is interested. Reason: device-local; not a notification. |
| T-MKT-3 | `lambda/marketplace/wsHandler/index.ts` | broadcast notification (existing) | `marketplace.broadcast.sent` | ❌ **rejected** — pure transport mechanism, not a Trigger_Point. Reason: producer is whoever calls `broadcastToRoom`; UNS replaces this transport entirely. |
| T-MKT-4 | `Dukan_x/lib/features/pre_order/presentation/customer/customer_pre_order_screen.dart`, `Dukan_x/lib/features/pre_order/presentation/vendor/vendor_request_detail_screen.dart` | pre-order requested → vendor accepts/rejects | `pre_order.request.created` / `pre_order.request.responded` | ✅ **justified** — Recipient: customer + vendor. Reason: bidirectional negotiation. Action: customer awaits decision; vendor responds. |
| T-MKT-5 | `my-backend/src/handlers/in-store-checkout.ts` | exit QR generated | `in_store.exit_qr.ready` (`WSEventName.IN_STORE_EXIT_QR_READY`) | ✅ **justified** — Recipient: customer. Reason: customer needs to leave the store. Action: scan exit QR at the gate. |
| T-MKT-6 | `my-backend/src/handlers/in-store-streams.ts` | in-store sale dashboard update | `in_store.sale.dashboard_updated` (`WSEventName.DASHBOARD_UPDATED`) | ❌ **rejected** — operator dashboard refresh, not a per-user notification. Reason: dashboards refresh themselves on this event; it's not user-actionable. |

### 9.19 Loyalty / Marketing

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-MKT-LOY-1 | `Dukan_x/lib/features/marketing/presentation/screens/create_campaign_screen.dart`, `my-backend/src/handlers/loyalty.ts` | campaign sent | `marketing.campaign.sent` | ✅ **justified** — Recipient: targeted customers. Reason: campaign is intentional outreach. Action: customer engages with promo. |
| T-MKT-LOY-2 | `my-backend/src/handlers/loyalty.ts` | points awarded | `loyalty.points.awarded` | ✅ **justified** — Recipient: customer. Reason: balance changed. Action: redeem when threshold. |
| T-MKT-LOY-3 | `my-backend/src/handlers/loyalty.ts` | tier upgraded | `loyalty.tier.upgraded` | ✅ **justified** — Recipient: customer. Reason: new benefits unlocked. Action: use new perks. |

### 9.20 AI / Voice (informational; no producer today)

| ID | File | Symbol | Event candidate | Status |
|---|---|---|---|---|
| T-AI-1 | `voice-backend/voice_agent.py`, `Dukan_x/lib/features/ai_assistant/presentation/screens/desktop_ai_assistant_screen.dart` | agent triggered an action | `ai.action.executed` | ❌ **rejected** — at present, AI actions are conversational and visible inline; no separate notification needed. Reason: same-session UI feedback already exists. (Phase 2 may revisit if AI sends a `notify_owner` action.) |
| T-AI-2 | `my-backend/src/services/ai-tools.registry.ts` `notify_owner` tool | tool execution | `ai.notify_owner.requested` | ✅ **justified** — Recipient: shop owner. Reason: the tool's stated purpose is "send notification to owner". Action: owner reviews the AI's finding. |

### Status counts (REQ 1.11a satisfied: every Trigger_Point has explicit `justified` or `rejected`)

| Status | Count |
|---|---|
| ✅ justified | **126** |
| ❌ rejected | **19** |
| `n/a` consumers (listed for completeness, not Trigger_Points) | **2** (T-PAY-9, T-RES-6) |
| **Total Trigger_Points** (justified + rejected) | **145** |

> Every Trigger_Point row above carries an explicit `justified` or `rejected` status. The two `n/a` rows are pure consumers of other Trigger_Points (a WS subscriber and an order-tracking screen) and are listed so the inventory is complete; they are not themselves Trigger_Points. There are **no `TODO` or `unknown`** statuses among Trigger_Points (REQ 1.11a is met).


---

## 10. Roles and Candidate Events

> **REQ 1.7**: list every distinct user role identified in the workspace and, for each role, the set of candidate event names from §9 that the role has a legitimate need to receive.
> **Source for role list**: `lambda/staff-management/src/constants/roles.ts`, `my-backend/src/utils/jwt-role.ts`, `my-backend/src/middleware/role-guard.ts`, `my-backend/src/config/permission-matrix.ts`, plus the role tags used in `WSEventName` audience routing in `eventbridge.service.ts`.

### 10.1 Role inventory (distinct roles found in the workspace)

| Role | First seen in workspace | Notes |
|---|---|---|
| `super_admin` | `my-backend/src/middleware/super-admin-guard.ts` | Cross-tenant operator |
| `admin` / `shop_owner` (synonymous in many places, both used as the "owner" role on the JWT) | `my-backend/src/middleware/permission-guard.ts`, `eventbridge.service.ts` (`'owner'` audience) | Tenant owner |
| `cashier` | DukanX POS flows (`Dukan_x/lib/features/billing/...`) | Tenant operator |
| `accountant` | DukanX accounting (`Dukan_x/lib/features/accounting/...`) | Tenant finance |
| `staff` (generic) | `lambda/staff-management/`, `my-backend/src/handlers/staff-sale.ts` | Tenant employee |
| `delivery_agent` | `lambda/marketplace/deliveryHandler/`, `Dukan_x/lib/features/restaurant/.../restaurant_delivery_ops_screen.dart` | Last-mile |
| `vendor` / `supplier` | `Dukan_x/lib/features/onboarding/vendor_onboarding_screen.dart`, `Dukan_x/lib/features/auth/presentation/screens/vendor_auth_screen.dart`, `my-backend/src/handlers/suppliers.ts` | External party (sells to the shop) |
| `customer` | `Dukan_x/lib/features/customers/...`, `Dukan_x/lib/features/auth/presentation/screens/customer_auth_screen.dart`, `lambda/customerHandler/` | External party (buys from the shop) |
| `chef` | DukanX restaurant flows | Restaurant kitchen |
| `kitchen_staff` | DukanX restaurant flows | Restaurant kitchen support |
| `waiter` | DukanX restaurant flows | Restaurant floor |
| `school_admin` | `school_admin_app/` | School/coaching admin |
| `teacher` | `school_teacher_app/`, `Dukan_x/lib/features/academic_coaching/...` | Faculty |
| `student` | `school_student_app/` | Pupil |
| `parent` | `school_student_app/` (shared with student account in many flows; `parentPhone`/`parentEmail` fields in `academic_coaching.ts`) | Guardian |
| `clinic_doctor` | `Dukan_x/lib/features/doctor/...`, `Dukan_x/lib/features/clinic/...` | Doctor |
| `pharmacist` | `Dukan_x/lib/features/pharmacy/...`, `my-backend/src/handlers/modules/pharmacy/` | Pharmacy |
| `jewellery_artisan` | implied in `Dukan_x/lib/features/jewellery/presentation/screens/custom_order_management_screen.dart` and `jewellery_repair_screen.dart` | Jewellery craftsman |
| `service_technician` | `Dukan_x/lib/features/service/...` | Repair technician |
| `dc_staff` | `Dukan_x/lib/features/decoration_catering/presentation/screens/dc_staff_screen.dart` | Decoration & catering crew |
| `farmer` (vegetable broker counterparty) | `Dukan_x/lib/features/vegetable_broker/...` | Veg broker supplier |
| `pump_attendant` (a.k.a. `pumpboy`, alias `PUMPBOY`) | `lambda/staff-attendance/`, `my-backend/src/utils/jwt-role.ts` | Petrol pump staff |

### 10.2 Candidate events per role

> Each row maps a role to the candidate `event_name`s from §9 that role has a legitimate operational interest in receiving. Phase 2 will refine these into per-event consumer-role lists in the registry.

| Role | Candidate events (from §9 — `justified` only) |
|---|---|
| `super_admin` | `security.fraud.alert_raised`, `security.access.unauthorized_attempt`, `system.health.degraded`, `tenant.trial.expired`, `tenant.subscription.failed`, `tenant.manifest.invalidated` |
| `admin` / `shop_owner` | `billing.invoice.created`, `billing.invoice.finalized`, `billing.invoice.updated`, `billing.invoice.returned`, `billing.credit_note.issued`, `payment.invoice.received`, `payment.gateway.success`, `payment.gateway.failed`, `payment.refund.processed`, `inventory.stock.low`, `inventory.stock.changed`, `inventory.item.created/updated/deleted`, `inventory.stock.adjusted`, `inventory.batch.expiring`, `inventory.batch.expired`, `inventory.import.completed`, `purchase.order.created`, `purchase.bill.added`, `purchase.payment.made`, `purchase.po.matched_to_grn`, `customer.shop.linked`, `customer.recovery.visit_recorded`, `customer.credit.reminder_sent`, `jewellery.gold_rate.alert_triggered`, `jewellery.gold_rate.updated`, `jewellery.custom_order.status_changed`, `jewellery.repair.status_changed`, `jewellery.gold_scheme.matured`, `jewellery.hallmark.received`, `restaurant.order.created`, `restaurant.bill.updated`, `dc.quote.converted`, `dc.event.status_changed`, `dc.invoice.created`, `dc.payment.received`, `dc.expense.added`, `dc.inventory.low`, `service.job.created`, `service.warranty.claim_raised`, `auto_parts.job_card.status_changed`, `computer_shop.job_card.status_changed`, `pump.sale.recorded`, `pump.staff.activity`, `pump.cash.dropped`, `pump.shift.opened`, `pump.shift.closed`, `staff.sale.recorded`, `staff.attendance.checked_in`, `staff.attendance.checked_out`, `security.cash.mismatch_detected`, `security.stock.anomaly_detected`, `tenant.trial.started`, `tenant.trial.expiry_reminder`, `tenant.trial.expired`, `tenant.grace_period.ended`, `tenant.subscription.renewed`, `tenant.subscription.failed`, `tenant.manifest.invalidated`, `marketplace.order.placed`, `in_store.exit_qr.ready`, `loyalty.tier.upgraded`, `marketing.campaign.sent`, `ai.notify_owner.requested` |
| `cashier` | `billing.invoice.created`, `billing.invoice.updated`, `billing.invoice.returned`, `payment.invoice.received`, `inventory.stock.changed`, `inventory.stock.low`, `inventory.stock.decremented_by_sale`, `restaurant.bill.updated`, `customer.collection.recorded`, `tenant.manifest.invalidated` |
| `accountant` | `billing.invoice.finalized`, `billing.invoice.returned`, `billing.credit_note.issued`, `payment.invoice.received`, `payment.refund.processed`, `inventory.stock.adjusted`, `purchase.bill.added`, `purchase.payment.made`, `purchase.po.matched_to_grn`, `vendor.payment.collected`, `dc.invoice.created`, `dc.payment.received`, `pump.cash.dropped`, `pump.shift.closed`, `security.cash.mismatch_detected`, `tenant.subscription.renewed`, `tenant.subscription.failed`, `school.fee.collected`, `school.payslip.generated` |
| `delivery_agent` | `restaurant.delivery.dispatched`, `delivery.challan.created`, `delivery.dispatch.created`, `delivery.location.updated`, `marketplace.order.placed` |
| `vendor` / `supplier` | `purchase.order.created`, `purchase.payment.made`, `purchase.goods.reversed`, `service.warranty.claim_raised` |
| `customer` | `billing.invoice.created` (their own), `billing.invoice.returned` (their own), `billing.credit_note.issued`, `payment.invoice.received` (their own), `payment.gateway.success` (their own), `payment.gateway.failed` (their own), `payment.refund.processed` (their own), `customer.shop.linked`, `customer.shop.link_accepted`, `customer.collection.recorded` (their own), `customer.credit.reminder_sent` (when overdue), `jewellery.custom_order.status_changed` (their own), `jewellery.repair.status_changed` (their own), `jewellery.gold_scheme.matured` (their own), `jewellery.old_gold.exchange_recorded` (their own), `restaurant.kot.item_ready` (their own table/order), `restaurant.delivery.dispatched` (their own), `dc.quote.converted` (their own), `dc.event.status_changed` (their own), `dc.invoice.created` (their own), `dc.payment.received` (their own), `service.job.created` (their own), `service.job.status_changed` (their own), `service.exchange.completed` (their own), `auto_parts.job_card.status_changed` (their own), `computer_shop.job_card.status_changed` (their own), `computer_shop.warranty.registered` (their own), `delivery.challan.created` (their own), `delivery.location.updated` (their own), `pre_order.request.created` (their own), `pre_order.request.responded` (their own), `in_store.exit_qr.ready` (their own), `marketplace.order.placed` (their own), `loyalty.points.awarded` (their own), `loyalty.tier.upgraded` (their own), `marketing.campaign.sent` (when targeted) |
| `chef` | `restaurant.order.created`, `restaurant.kot.created`, `restaurant.kot.status_changed`, `restaurant.kot.item_cancelled`, `dc.kot.created`, `dc.kot.updated` |
| `kitchen_staff` | same set as `chef` |
| `waiter` | `restaurant.order.created`, `restaurant.kot.item_ready`, `restaurant.bill.updated`, `restaurant.table.status_changed`, `restaurant.delivery.dispatched` |
| `school_admin` | `school.admission.accepted`, `school.fee.assigned`, `school.fee.reminder_sent`, `school.fee.collected`, `school.attendance.low_alert`, `school.exam.scheduled`, `school.exam.results_published`, `school.report_card.generated`, `school.leave.submitted`, `school.leave.processed`, `school.student.transferred`, `school.batch.full`, `school.timetable.updated`, `school.material.uploaded`, `school.homework.assigned`, `school.library.due`, `school.library.overdue`, `school.hostel.room_assigned`, `school.hostel.mess_updated`, `school.announcement.published`, `school.transport.delay`, `school.transport.route_assigned`, `school.payslip.generated`, plus the same `tenant.*` admin events as above |
| `teacher` | `school.admission.accepted` (their class), `school.attendance.marked` (their class), `school.attendance.low_alert` (their student), `school.exam.scheduled` (their subject), `school.exam.results_published` (their subject), `school.leave.submitted` (their student), `school.leave.processed` (own + their student), `school.student.transferred` (their class), `school.timetable.updated`, `school.material.uploaded`, `school.homework.assigned`, `school.announcement.published`, `school.payslip.generated` (own) |
| `student` | `school.admission.accepted` (own), `school.fee.assigned` (own), `school.fee.collected` (own), `school.attendance.marked` (own), `school.exam.scheduled` (own), `school.exam.results_published` (own), `school.report_card.generated` (own), `school.leave.processed` (own), `school.timetable.updated`, `school.material.uploaded` (own class), `school.homework.assigned` (own class), `school.library.due` (own), `school.library.overdue` (own), `school.hostel.room_assigned` (own), `school.hostel.mess_updated` (own), `school.announcement.published`, `school.transport.delay` (own route), `school.transport.route_assigned` (own) |
| `parent` | every event listed for `student` for their child, plus `school.fee.reminder_sent`, `school.attendance.absent_alert`, `school.attendance.low_alert` |
| `clinic_doctor` | `clinic.appointment.created` (their schedule), `clinic.queue.advanced` (their queue), `clinic.prescription.created` (their patient — info only), `clinic.lab.ordered` (their patient), `clinic.lab.result_published` (their patient) |
| `pharmacist` | `clinic.prescription.created` (queued for dispense), `pharmacy.refill.due` (their patient), `pharmacy.narcotic.entry_recorded` (their work), `inventory.stock.low` (pharmacy stock), `inventory.batch.expiring` (medicine batches) |
| `jewellery_artisan` | `jewellery.custom_order.status_changed` (own assignments), `jewellery.repair.status_changed` (own assignments) |
| `service_technician` | `service.job.created` (own queue), `service.job.status_changed` (own queue), `auto_parts.job_card.status_changed` (own queue), `computer_shop.job_card.status_changed` (own queue) |
| `dc_staff` | `dc.event.status_changed` (assigned events), `dc.staff.assigned` (own), `dc.kot.created`, `dc.kot.updated` |
| `farmer` (veg broker counterparty) | `vegetable_broker.reconciliation.posted` (own), `vegetable_broker.dispatch.created` (own) |
| `pump_attendant` / `pumpboy` | `pump.shift.opened` (own shift), `pump.shift.closed` (own shift), `staff.sale.recorded` (own), `staff.attendance.checked_in/out` (own) |

> **No-events justification (per REQ 17.2)**: every role listed above receives at least one event. There are no roles requiring a `no_events` justification at this stage.


---

## 11. Gaps

> **REQ 1.10**: list missing event hooks, missing integrations, and code paths where polling currently substitutes for real-time events.

### 11.1 Missing event hooks (Trigger_Points without an emit today, but that the workflows in §7 require)

| Workflow | Missing emit | File where the emit should originate |
|---|---|---|
| Service job customer push | The `// TODO` stub in `Dukan_x/lib/features/service/services/service_job_notification_service.dart` line ~292 leaves customer-side push delivery unimplemented (`// await sl<PushNotificationService>().send(...)`). | Replace with UNS `Shared_SDK.emit('service.job.status_changed', ...)`. |
| School fee assignment | `my-backend/src/handlers/modules/school-erp/school-fees.ts` writes the invoice record but does not call `pushNotification` or any WS emit on assignment (only on collection via WS `AC_INVOICE_PAID`). | Add server emit on the `assignFee` path. |
| Lab result publication | No emit today (`clinic.lab.result_published` referenced in §9.8 has no code yet). | New emit needed in clinic lab flow. |
| Warranty claim status updates | `Dukan_x/lib/features/service/services/warranty_claim_service.dart` raises the claim but does not emit a status-change event when the supplier responds. | Add emit at supplier-response handling site. |
| `manifest_invalidated` server-side trigger | DukanX subscribes (`tenant_config_provider.dart` line ~282), but the *server* emit on plan/feature change is not consistently wired. | Ensure `my-backend/src/handlers/feature-flag.ts` always emits when manifest version changes. |
| Vegetable broker reconciliation | `Dukan_x/lib/features/vegetable_broker/data/repositories/vegetable_broker_repository.dart` persists reconciliations but does not emit. | Add emit. |
| Sub-app announcement publication | `school_admin_app/.../announcements_screen.dart` and `school_teacher_app/.../announcements_screen.dart` POST to `school-communication.ts` which has limited fan-out today. | Standardize on `Shared_SDK.emit('school.announcement.published', ...)`. |

### 11.2 Missing integrations / persistence

| Gap | Where | Impact for UNS |
|---|---|---|
| **Sub-apps have no persistent notification store.** `school_admin_app`, `school_student_app`, `school_teacher_app` only buffer notifications in-memory (`wsNotificationsProvider`). On app restart, history is lost. The student app *renders* `notificationsProvider` from REST + WS, but persistence is server-side only. | `school_*_app/lib/core/websocket/school_ws_service.dart` | UNS must replay missed notifications via `getReplay(since, app)` on reconnect (REQ 8.4) — covered by design. |
| **No outbound webhook channel.** No code in `my-backend/` or `lambda/` posts notifications to a configured external HTTPS endpoint with a signed payload. | n/a (Phase 4 build) | UNS will add `webhook.ts` adapter (REQ 5.5, 5.12-5.13). |
| **Three independent transports today** — WebSocket fan-out in `websocket.service.ts`, EventBridge bus in `eventbridge.service.ts`, in-process Stream in `event_dispatcher.dart`, plus per-feature direct SMS/SES/WhatsApp in `academic_coaching.ts`. There is no single `Event_Bus` (REQ 3.1). | `my-backend/src/services/`, `Dukan_x/lib/core/services/` | UNS replaces with one canonical SNS+SQS bus per design. |
| **Two DukanX-side notification stores share the `customer_notifications` Drift table** (`VendorNotificationRepository` and `CustomerNotificationsRepository` both write into it). | `Dukan_x/lib/core/repository/vendor_notification_repository.dart` (the comment "Reusing existing table structure" admits this). | UNS will introduce a single canonical store on the backend (`Notification_Store`) with the local Drift table relegated to a cache/outbox role. |
| **No deduplication today.** Duplicate WS broadcasts occur when both `invoice.service.ts` and `invoices.ts` emit on the same save. Trigger_Points T-BIL-2 vs T-BIL-6 are an example. | `my-backend/src/handlers/invoices.ts`, `my-backend/src/services/invoice.service.ts` | UNS deduplication step (REQ 4.4, 9.2) handles this; legacy duplicates removed during migration. |
| **No DLQ for failed deliveries today.** Failed WhatsApp/SMS/SES sends are silently caught (`.catch(() => {})` patterns in `academic_coaching.ts` and `pump.ts`). | several files | UNS DLQ + retry per channel (REQ 3.10, 5.9-5.13, 9.3-9.4) closes this. |
| **No lifecycle audit log today.** Fan-out today is fire-and-forget; there is no `emitted → queued → dispatched → delivered → read` trail. | n/a | UNS Audit_Log (REQ 12.5-12.6, REQ 14) closes this. |
| **No quiet-hours / mute support today.** | n/a | UNS Preference_Engine (REQ 7) closes this. |
| **No JSON-Schema validation at the publish boundary.** `my-backend/src/types/websocket.types.ts` declares `WSEvent` as a TypeScript interface, not a runtime-validated schema. | `my-backend/src/services/websocket.service.ts` | UNS Event_Contract (REQ 8.1, 8.6) closes this. |
| **No replay endpoint for offline sub-apps.** | n/a | UNS `getReplay(since, app)` (REQ 8.4-8.5a) closes this. |
| **No per-Producer publish rate limit.** `my-backend/src/middleware/rate-limiter.ts` exists but is HTTP-scoped, not bus-scoped. | `my-backend/src/middleware/rate-limiter.ts` | UNS adds a bus-side rate limit (REQ 12.4). |

### 11.3 Polling that should be real-time

| Code path | What it polls | Why it should be event-driven |
|---|---|---|
| `Dukan_x/lib/features/dashboard/presentation/widgets/upcoming_payments_panel.dart` | Periodically refetches credit-reminder data from the backend. | Subscribe to `customer.credit.reminder_sent` and `payment.invoice.received` instead. |
| `Dukan_x/lib/features/staff/presentation/screens/staff_sale_entry_screen.dart` (line ~671 mentions "Polling fallback already active every 3 seconds") | Polls payment status alongside the WS subscribe — fallback is doing real work today because WS reliability isn't guaranteed end-to-end. | UNS reliability tier (REQ 9.1) + reconnect replay (REQ 8.4) means polling can be removed. |
| `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` `_evaluateAlerts` | Periodically evaluates user's threshold against latest gold rate. | Should be triggered by a server-side `jewellery.gold_rate.updated` event consumed by an evaluator instead of a client-side timer. |
| `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart` `businessAlertsCountProvider` | Hybrid: subscribes to local `EventDispatcher` AND polls counts. | Once UNS bell widget exposes unread count via `Shared_SDK`, polling can be dropped. |
| `school_student_app/lib/features/notifications/screens/notifications_screen.dart` | `onRefresh: () async => ref.invalidate(notificationsProvider)` (pull-to-refresh) — implies people periodically pull because push is unreliable. | UNS reliable in-app channel + replay closes this. |
| `Dukan_x/lib/core/services/cleanup_service.dart`, `reconciliation_service.dart`, `einvoice_status_service.dart` | Timer-based scans. | These are *infrastructure* tasks, not user-facing — keep as-is. (Listed for completeness so we don't accidentally label them as polling notification gaps.) |

### 11.4 Non-blocking observations (not gaps for UNS, recorded for future cleanups)

- `Dukan_x/lib/services/websocket_service.dart` and `Dukan_x/lib/core/services/websocket_service.dart` both exist; the former just re-exports the latter. Functionally fine, but adds noise.
- `Dukan_x/lib/services/cleanup_service.dart` / `reconciliation_service.dart` / `einvoice_status_service.dart` are "old" copies; the canonical versions live under `core/services/`. Cleanup is out of scope for Phase 1 but tracked here.
- `Dukan_x/lib/features/jewellery/data/repositories/gold_rate_alert_repository.dart` ships its own private `class NotificationService` (not the same as UNS's). Naming collision must be resolved during Phase 4 migration (task 14.x).
- `my-backend/src/handlers/notification.ts` is the legacy DukanX-side push registration endpoint. UNS replaces it.
- `lambda/customerNotificationHandler/index.mjs` is the legacy customer-app notification CRUD lambda. UNS replaces it.


---

## 12. Phase-2 Hand-off Notes

This section is the bridge into the Phase 2 `Notification_Event_Registry`.

### 12.1 What Phase 2 inherits from this report

- **145 Trigger_Points** with explicit `justified` / `rejected` status (§9). Every `justified` row carries the **recipient + reason + action** triple required by REQ 2.7.
- **19 rejected** Trigger_Points with the explicit rejection reason recorded. Per REQ 2.8 these go to the `rejected_candidates` section of the Phase 2 registry.
- **22 distinct roles** with a candidate-event mapping each (§10). REQ 17.1 minimum role coverage is met.
- **Existing `WSEventName` enum** (`my-backend/src/types/websocket.types.ts`) lists 73+ event names already in production. Phase 2 must reconcile each enum value to the registry; many map 1:1 (e.g. `LOW_STOCK_ALERT → inventory.stock.low`, `KOT_CREATED → restaurant.kot.created`), and where the enum lacks an entry from §9, the registry adds one (e.g. `clinic.lab.result_published`, `school.fee.assigned`, `tenant.trial.expired`).
- **Existing localization templates** in `my-backend/src/i18n/notification-templates.ts` are reusable for Phase 4 channel adapter content.

### 12.2 Decisions Phase 2 still owes

These are open per REQ 2 but explicitly **not** open for Phase 1 (Phase 1 only catalogues; Phase 2 chooses):

- Per-event `priority` (`critical` / `high` / `normal` / `low`).
- Per-event `channels_per_role` (which roles get `in_app`, `push`, `sms`, `email`, `webhook`).
- Per-event `deduplication_rule` (Deduplication_Key fields + window).
- Per-event `silence_conditions` (mute, actor==recipient, quiet hours).
- Batched-event definitions (`batch_window_seconds`, `summary_payload`) where high-frequency events would otherwise flood (e.g. `inventory.stock.changed`, `marketplace.cart.updated` — though the latter is rejected outright in §9.18).
- `notification_fatigue_risks` table.

### 12.3 Resolution of REQ 1.12 (no `TODO`/`unknown` blockers)

REQ 1.12: *"IF the Project_Scan_Report contains any unresolved `TODO` or `unknown` entry under Architecture_Overview, Tech_Stack, or Sub_Apps, THEN THE Notification_System project SHALL block progression to Phase 2 until those entries are resolved."*

- **§2 Architecture_Overview** — no `TODO`, no `unknown`. Statement of fact at the bottom of §2 confirms.
- **§3 Tech_Stack** — no `TODO`, no `unknown`. Every row of the table is grounded in a concrete file. Statement of fact at the bottom of §3 confirms.
- **§4 Sub_Apps** — no `TODO`, no `unknown`. Each sub-app row names a concrete `pubspec.yaml` location and the same Cognito JWT auth mechanism. Statement of fact at the bottom of §4 confirms.

**Phase 2 is therefore unblocked by Phase 1.**

### 12.4 Document checklist against Requirement 1

| Acceptance criterion | Where in this report | Status |
|---|---|---|
| 1.1 Project_Scan_Report at `.kiro/specs/unified-notification-system/phase1-scan-report.md` | This file | ✅ |
| 1.2 Every Flutter screen file across the four apps, grouped by app + feature | §5.1 – §5.4 | ✅ |
| 1.3 Every backend module/service/controller/endpoint across `my-backend/`, `voice-backend/`, `lambda/`, `lambda/staff-attendance/` | §6.1 – §6.5 | ✅ |
| 1.4 Every cross-module workflow (invoice→payment, purchase→inventory, service-job→warranty, restaurant order→kitchen→billing, school fee→payment→receipt, leave→approval→attendance, exam→result→report card, …) | §7.1 – §7.8 | ✅ |
| 1.5 Every Trigger_Point as `(file_path, symbol, event_name_candidate, observed_state_change)` | §9.1 – §9.20 | ✅ |
| 1.6 Every existing notification helper / emitter (the explicit list of files in REQ 1.6) | §8.1 – §8.6 — every file in the spec list is included by name | ✅ |
| 1.7 Every distinct user role + candidate event names | §10.1 – §10.2 | ✅ |
| 1.8 Architecture_Overview classifying the workspace + tech stack | §2 + §3 | ✅ |
| 1.9 Sub_Apps section with primary domain, pubspec.yaml location, auth mechanism | §4 | ✅ |
| 1.10 Gaps section listing missing event hooks, missing integrations, polling-as-real-time | §11.1 – §11.3 | ✅ |
| 1.11 Every candidate Trigger_Point has explicit `justified` (recipient + reason + action) or `rejected` (reason) | §9 — every row | ✅ |
| 1.11a Every Trigger_Point carries an explicit status; counts table at end of §9 | §9 closing counts table | ✅ |
| 1.12 No `TODO`/`unknown` under Architecture_Overview, Tech_Stack, Sub_Apps | §12.3 | ✅ |

### 12.5 Authoring metadata

- Generated as the deliverable for **Task 1.1** in `.kiro/specs/unified-notification-system/tasks.md`.
- Validates **Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.11a, 1.12**.
- This document is the input contract for **Task 2.1** (the Phase 2 Notification_Event_Registry).
