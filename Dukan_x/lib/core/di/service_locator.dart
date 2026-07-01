// ============================================================================
// SERVICE LOCATOR - DEPENDENCY INJECTION
// ============================================================================
// Central dependency injection using GetIt
// ALL services, repositories, and managers are registered here
// NO direct instantiation allowed in UI
//
// ARCHITECTURE ENFORCEMENT:
// - UI MUST use repositories only (never direct Firestore)
// - All data flows through Drift → SyncManager → Firestore
// - SessionManager is the ONLY auth state source
//
// Author: DukanX Engineering
// Version: 3.0.0 (Production Hardened)
// ============================================================================

import '../../features/dashboard/data/dashboard_analytics_repository.dart';

import 'package:get_it/get_it.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:dukanx/core/compat/firestore_compat.dart' as cf;
import '../api/api_client.dart';
// PHASE 1 FIX A: Previously imported '../auth/token_manager.dart' here.
// That file (lib/core/auth/token_manager.dart) has STUB JSON helpers
// (`_parseJson` returns `{}`, `_stringifyJson` returns `'{}'`) — see
// Phase 0 Section A.1. Its global `tokenManager` singleton could therefore
// never persist a token across restarts, which caused the "login screen
// reappears after restart" symptom.
//
// The correct, secure-storage-backed implementation lives in
// `lib/core/services/token_manager.dart` (real jsonEncode/jsonDecode +
// FlutterSecureStorage). We now register THAT one in GetIt and wire
// ApiClient + the FirebaseAuth compat layer to it.
import '../services/token_manager.dart';
import '../services/currency_service.dart';
import '../../features/academic_coaching/data/repositories/ac_repository.dart';
// firebase_storage migrated to S3 — FirebaseStorage stub in firestore_compat.dart
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:async';
import '../database/app_database.dart';
import '../sync/sync_manager.dart';

import '../sync/background_sync_service.dart';
import '../sync/engine/sync_engine.dart'; // Added
import '../sync/data/drift_sync_repository.dart'; // Added
import '../sync/abstractions/sync_repository.dart'; // Added
import '../error/error_handler.dart';
import '../monitoring/monitoring_service.dart';
import '../services/notification_controller.dart';
import '../../services/audit_service.dart';
import '../services/device_id_service.dart';
import '../../services/daybook_service.dart';

// Event System & Daily Snapshot
import '../services/event_dispatcher.dart';
// import '../services/daily_snapshot_service.dart';
import '../services/notification_listener_service.dart';
import '../repository/vendor_notification_repository.dart';

// Repositories (Single Source of Truth)
import '../repository/bills_repository.dart';
import '../repository/audit_repository.dart';
import '../repository/customers_repository.dart';
import '../services/customer_enforcement_service.dart';

import '../repository/products_repository.dart';
import '../repository/revenue_repository.dart';
import '../repository/purchase_repository.dart';
import '../repository/reports_repository.dart';
import '../repository/statements_repository.dart';
import '../services/statements_service.dart';
import '../repository/bank_repository.dart';
import '../repository/expenses_repository.dart';
import '../repository/udhar_repository.dart';
import '../repository/shop_repository.dart';
import '../repository/onboarding_repository.dart';
import '../repository/vendors_repository.dart';
import '../repository/user_repository.dart';
import '../repository/connection_repository.dart';
import '../repository/customer_profile_repository.dart';
import '../repository/shop_link_repository.dart';

import '../repository/patients_repository.dart';
import '../repository/visits_repository.dart';
import '../repository/clinical_prescription_repository.dart';

// Delivery Challan
import '../../features/delivery_challan/data/repositories/delivery_challan_repository.dart';
import '../../features/delivery_challan/services/delivery_challan_service.dart';

// Reports & Tally
import '../../features/reports/services/tally_xml_service.dart';

// Petrol Pump Services
import '../../features/petrol_pump/services/services.dart';

// Session (Unified)
import '../session/session_manager.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import '../config/app_config.dart';
import '../../services/auth_service.dart';

// Role Management (RBAC)
import '../../services/role_management_service.dart';

// Access Control Service (RBAC enforcement for CRUD operations)
import '../services/access_control_service.dart';

import '../../features/accounting/accounting.dart' as acc;
import '../../features/inventory/data/product_batch_repository.dart';
import '../../features/inventory/services/pharmacy_migration_service.dart';
import '../../features/inventory/services/batch_allocation_service.dart';
import '../../features/inventory/services/inventory_service.dart';

import '../../services/data_integrity_service.dart';

import '../../features/ai_assistant/services/recommendation_service.dart';
import '../../features/ai_assistant/services/customer_recommendation_service.dart';
import '../../features/ai_assistant/services/morning_briefing_service.dart';
import '../../features/ai_assistant/services/voice_intent_service.dart';
import '../../features/pre_order/data/repositories/customer_item_request_repository.dart';
import '../../features/pre_order/data/repositories/vendor_item_snapshot_repository.dart';
import '../../features/pre_order/data/repositories/stock_transaction_repository.dart';
import '../../features/pre_order/services/pre_order_service.dart';
import '../../features/customers/services/customer_link_service.dart';
import '../../features/reports/services/gstr1_service.dart';
import '../../features/party_ledger/services/party_ledger_service.dart';

// Invoice Safety
import '../services/invoice_number_service.dart';

// e-Invoice Module
import '../../features/e_invoice/data/repositories/e_invoice_repository.dart';
import '../../features/e_invoice/data/services/e_invoice_service.dart';
import '../../features/e_invoice/data/services/e_way_bill_service.dart';

// Marketing Module
import '../../features/marketing/data/repositories/marketing_repository.dart';
import '../../features/marketing/data/services/whatsapp_service.dart';

// Billing / Dunning
import '../billing/dunning_service.dart';

// Payment
import '../../features/payment/services/payment_gateway_api_service.dart';
import '../../features/payment/services/upi_payment_service.dart';
import '../../features/doctor/data/repositories/appointment_repository.dart';
import '../../features/doctor/data/repositories/prescription_repository.dart';
import '../../features/doctor/services/patient_service.dart';
import '../../features/doctor/services/clinic_billing_service.dart';
import '../../features/payment/data/repositories/payment_repository.dart';

import '../../features/payment/services/payment_orchestrator.dart'; // Payment Orchestrator
import '../../features/doctor/data/repositories/doctor_dashboard_repository.dart';
import '../../features/doctor/data/repositories/patient_repository.dart';
import '../../features/doctor/data/repositories/doctor_repository.dart';

// Staff Management Module
import '../../features/staff/data/repositories/staff_repository.dart';
import '../../features/staff/services/staff_service.dart'; // Added StaffService
import '../../features/staff/data/services/payroll_service.dart';

// ML Services
import '../../features/ml/ml_services/ocr_service.dart';
import '../../features/ml/ml_services/ocr_router.dart';
import '../../features/ml/ml_services/language_service.dart';
import '../../features/ml/ml_services/translation_service.dart';
import '../../features/billing/services/barcode_scanner_service.dart';
import '../../features/billing/services/broker_billing_service.dart'; // Mandi
import '../../features/service/services/imei_validation_service.dart'; // IMEI pipeline (Phase 1)

// Credit Network

// Restaurant / Hotel Module
import '../../features/restaurant/restaurant.dart';
import '../../features/doctor/data/repositories/medical_template_repository.dart';
import '../../features/doctor/data/repositories/lab_report_repository.dart';

// GST Module
import '../../features/gst/repositories/gst_repository.dart';

// Legacy Services (Deprecated)
import '../../services/local_storage_service.dart';
import '../../services/connection_service.dart';

// Licensing System
import '../../services/license_service.dart';
import '../../services/device_fingerprint_service.dart';
import '../services/module_loader_service.dart';

// ============================================
// OFFLINE LICENSE ACTIVATION (Offline_Lifetime_Mode service layer)
// ============================================
// These services power Offline_Lifetime_Mode. Cloud_Subscription_Mode is the
// default, so every registration below is LAZY — nothing offline is constructed
// or started unless offline mode is actually active (preserves Req 1.7, 2.1,
// 2.3, 11.1, 11.5, 11.7). None of these are referenced from the widget tree.
import '../mode/local_config.dart';
import '../mode/mode_manager.dart';
import '../mode/backend_supervisor.dart';
import '../mode/offline_gating_engine.dart';
import '../mode/online_only_feature_gate.dart';
import '../mode/sync_foundation.dart';
import '../mode/data_archival_service.dart';
import '../mode/update_service.dart';
import '../mode/lan_coordinator.dart';
import '../mode/license_token.dart';
import '../mode/offline_startup_coordinator.dart';
import '../backup/backup_service.dart' as offline_backup;
import '../licensing/migration/migration_wizard.dart';
import '../licensing/local_license_file.dart';
import '../security/offline_security_layer.dart';

// Unified Notification System (UNS) — Shared SDK (Phase 4 migrations).
// Required by RestaurantNotificationService, ServiceJobNotificationService,
// SecurityNotificationService etc. once each module's migration window opens.
// See: .kiro/specs/unified-notification-system/tasks.md (task 14.x).
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

/// Global service locator instance
final GetIt sl = GetIt.instance;

/// Track initialization state
bool _isInitialized = false;

/// Initialize all dependencies
/// MUST be called in main.dart BEFORE runApp()
Future<void> initializeDependencies() async {
  if (_isInitialized) {
    monitoring.warning('ServiceLocator', 'Already initialized, skipping');
    return;
  }

  monitoring.info('ServiceLocator', 'Initializing dependencies...');

  // ============================================
  // EXTERNAL SERVICES (Firebase)
  // ============================================
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<cf.FirebaseFirestore>(
    () => cf.FirebaseFirestore.instance,
  );
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // ============================================
  // CORE INFRASTRUCTURE
  // ============================================

  // PHASE 1 FIX A: TokenManager — the secure-storage-backed implementation
  // (lib/core/services/token_manager.dart). MUST be registered BEFORE
  // FirebaseAuth/ApiClient because:
  //   - firebase_auth_compat.dart resolves it via `sl<TokenManager>()`
  //     during FirebaseAuth.instance construction (its private constructor
  //     calls restoreSession() → sl<TokenManager>().getIdToken()).
  //   - ApiClient (registered just below) needs it for tokenProvider.
  // Previously this was never registered, so `sl<TokenManager>()` threw
  // StateError inside restoreSession()'s try/catch, which silently emitted
  // `_currentUser = null` → AuthGate showed the login screen every restart.
  // See Phase 0 Section A.2.
  if (!sl.isRegistered<TokenManager>()) {
    sl.registerLazySingleton<TokenManager>(
      () => TokenManager(apiBaseUrl: AppConfig.apiBaseUrl),
    );
  }

  // Monitoring Service (already a singleton via global)
  sl.registerLazySingleton<MonitoringService>(() => monitoring);

  // Currency Service (multi-currency formatting)
  sl.registerLazySingleton<CurrencyService>(() => CurrencyService());

  // Api Client (Singleton)
  // PHASE 1 FIX A: Wire tokenProvider/tokenRefresher to the registered
  // secure-storage TokenManager via `sl<TokenManager>()`. Previously this
  // referenced the broken global `tokenManager` singleton from
  // lib/core/auth/token_manager.dart, whose getAccessToken() always
  // returned null after restart (stub JSON could not be deserialized).
  // Note: getIdToken() already performs auto-refresh internally, so we
  // reuse it for both provider and refresher callbacks.
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      tokenProvider: () => sl<TokenManager>().getIdToken(),
      tokenRefresher: () => sl<TokenManager>().getIdToken(autoRefresh: true),
    ),
  );

  // Database (Singleton - shared across app)
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase.instance);

  // Error Handler (Singleton)
  sl.registerLazySingleton<ErrorHandler>(() => ErrorHandler.instance);

  // Dashboard Analytics Repository
  sl.registerLazySingleton<DashboardAnalyticsRepository>(
    () => DashboardAnalyticsRepository(
      database: sl<AppDatabase>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // Customer Enforcement Service (Credit Limit & Blocking)
  sl.registerLazySingleton<CustomerEnforcementService>(
    () => CustomerEnforcementService(sl<CustomersRepository>()),
  );
  sl.registerLazySingleton<CustomerLinkService>(
    () => CustomerLinkService(
      database: sl<AppDatabase>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // Local Storage Service (Deprecated - for backward compatibility)
  sl.registerLazySingleton<LocalStorageService>(() => LocalStorageService());

  // Connection Service
  sl.registerLazySingleton<ConnectionService>(() => ConnectionService());

  // Device ID Service (Singleton)
  sl.registerLazySingleton<DeviceIdService>(() => DeviceIdService.instance);

  // ============================================
  // LICENSING SYSTEM (Enterprise)
  // ============================================

  // Device Fingerprint Service - Cross-platform device identification
  sl.registerLazySingleton<DeviceFingerprintService>(
    () => DeviceFingerprintService(),
  );

  // License Service - License validation, activation, and caching
  sl.registerLazySingleton<LicenseService>(
    () => LicenseService(sl<AppDatabase>()),
  );

  // Module Loader Service - Loading business modules based on license/tenant
  sl.registerLazySingleton<ModuleLoaderService>(() => ModuleLoaderService());

  // Audit System
  sl.registerLazySingleton<AuditRepository>(
    () => AuditRepository(
      database: sl<AppDatabase>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<AuditService>(
    () => AuditService(sl<AuditRepository>(), sl<DeviceIdService>()),
  );

  // Udhar Repository
  sl.registerLazySingleton<UdharRepository>(
    () => UdharRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // Cognito User Pool
  sl.registerLazySingleton<CognitoUserPool>(
    () =>
        CognitoUserPool(AppConfig.cognitoUserPoolId, AppConfig.cognitoClientId),
  );

  // Compatibility/Legacy AuthService
  sl.registerLazySingleton<AuthService>(() => AuthService());

  // Session Manager (THE ONLY AUTH STATE SOURCE)
  // Replaces old SessionService completely
  sl.registerLazySingleton<SessionManager>(
    () => SessionManager(
      auth: sl<FirebaseAuth>(),
      firestore: sl<cf.FirebaseFirestore>(),
    ),
  );

  // Wire the v46 SYSTEM-owner backfill resolver (clinic task 4.4) to the single
  // owner-id source. Static hook (does NOT instantiate the DB here), best-effort:
  // returns null when no session/owner exists so the migration fails safe (skips)
  // rather than fabricating an owner id or re-bucketing under 'SYSTEM'.
  AppDatabase.systemOwnerBackfillResolver = () {
    try {
      return sl<SessionManager>().ownerId;
    } catch (_) {
      return null;
    }
  };

  // Role Management Service (RBAC - queries business_users collection)
  sl.registerLazySingleton<RoleManagementService>(
    () => RoleManagementService(firestore: sl<cf.FirebaseFirestore>()),
  );

  // Access Control Service (RBAC enforcement for CRUD operations)
  // Provides canPerform() / enforcePermission() using SessionManager's
  // effective role and RolePermissions matrix. Does NOT modify Firestore
  // write patterns — only adds a permission-check layer before writes.
  sl.registerLazySingleton<AccessControlService>(
    () => AccessControlService(
      sessionManager: sl<SessionManager>(),
      auditRepository: sl<AuditRepository>(),
    ),
  );

  // Sync Queue Local Operations
  sl.registerLazySingleton<SyncQueueLocalOperations>(() => sl<AppDatabase>());

  // Sync Manager (Singleton)
  sl.registerLazySingleton<SyncManager>(() => SyncManager.instance);

  // Background Sync Service (Singleton)
  sl.registerLazySingleton<BackgroundSyncService>(
    () => BackgroundSyncService.instance,
  );

  // Unified Notification Controller
  sl.registerLazySingleton<NotificationController>(
    () => NotificationController(),
  );

  // Event Dispatcher
  sl.registerLazySingleton<EventDispatcher>(() => EventDispatcher.instance);

  // Notification Listener Service
  sl.registerLazySingleton<NotificationListenerService>(
    () => NotificationListenerService(
      dispatcher: sl<EventDispatcher>(),
      notificationRepo: sl<VendorNotificationRepository>(),
      customersRepo: sl<CustomersRepository>(),
    ),
  );

  // Vendor Notification Repository
  sl.registerLazySingleton<VendorNotificationRepository>(
    () => VendorNotificationRepository(db: sl<AppDatabase>()),
  );

  // ============================================
  // REPOSITORIES (Single Source of Truth for UI)
  // ============================================

  sl.registerLazySingleton<BillsRepository>(
    () => BillsRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
      accountingService: sl<acc.AccountingService>(),
      inventoryService: sl<InventoryService>(),
      customerRecommendationService: sl<CustomerRecommendationService>(),
      auditService: sl<AuditService>(),
      productBatchRepository: sl<ProductBatchRepository>(),
      batchAllocationService: sl<BatchAllocationService>(),
      gstRepository: sl<GstRepository>(),
      brokerBillingService: sl<BrokerBillingService>(), // Mandi
      imeiValidationService: IMEIValidationService(
        sl<AppDatabase>(),
      ), // Phase 1: activates IMEI pipeline
    ),
  );

  // Mandi: Broker Billing Service
  sl.registerLazySingleton<BrokerBillingService>(
    () => BrokerBillingService(
      sl<AppDatabase>(),
      sl<ErrorHandler>(),
      sl<acc.AccountingService>(),
    ),
  );

  sl.registerLazySingleton<CustomersRepository>(
    () => CustomersRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<ProductsRepository>(
    () => ProductsRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<RevenueRepository>(
    () => RevenueRepository(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<ProductBatchRepository>(
    () => ProductBatchRepository(sl<AppDatabase>()),
  );

  sl.registerLazySingleton<PurchaseRepository>(
    () => PurchaseRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
      inventoryService: sl<InventoryService>(),
      productBatchRepository: sl<ProductBatchRepository>(),
    ),
  );

  sl.registerLazySingleton<BankRepository>(
    () => BankRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<ReportsRepository>(
    () => ReportsRepository(
      database: sl<AppDatabase>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // STATEMENTS REPOSITORY - Comprehensive statement generation
  sl.registerLazySingleton<StatementsRepository>(
    () => StatementsRepository(
      database: sl<AppDatabase>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // STATEMENTS SERVICE - Business logic layer for statement generation
  sl.registerLazySingleton<StatementsService>(
    () => StatementsService(
      repository: sl<StatementsRepository>(),
      sessionManager: sl<SessionManager>(),
    ),
  );

  sl.registerLazySingleton<ExpensesRepository>(
    () => ExpensesRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // OnboardingRepository - Firestore-first onboarding persistence
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<VendorsRepository>(
    () => VendorsRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<ConnectionRepository>(
    () => ConnectionRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // Customer-Shop QR Linking Repositories
  sl.registerLazySingleton<CustomerProfileRepository>(
    () => CustomerProfileRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<ShopLinkRepository>(
    () => ShopLinkRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<PatientsRepository>(
    () => PatientsRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<VisitsRepository>(
    () => VisitsRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<ClinicalPrescriptionRepository>(
    () => ClinicalPrescriptionRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  // DOCTOR / CLINIC MODULE SERVICES
  sl.registerLazySingleton<PatientRepository>(
    () => PatientRepository(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
    ),
  );

  sl.registerLazySingleton<DoctorRepository>(
    () =>
        DoctorRepository(db: sl<AppDatabase>(), syncManager: sl<SyncManager>()),
  );

  // Academic Coaching Repository
  sl.registerLazySingleton<AcRepository>(() => AcRepository(sl<ApiClient>()));

  sl.registerLazySingleton<AppointmentRepository>(
    () => AppointmentRepository(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
    ),
  );

  sl.registerLazySingleton<PrescriptionRepository>(
    () => PrescriptionRepository(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
    ),
  );

  sl.registerLazySingleton<DoctorDashboardRepository>(
    () => DoctorDashboardRepository(sl<AppDatabase>()),
  );

  sl.registerLazySingleton<MedicalTemplateRepository>(
    () => MedicalTemplateRepository(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
    ),
  );

  sl.registerLazySingleton<LabReportRepository>(
    () => LabReportRepository(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
    ),
  );

  sl.registerLazySingleton<ClinicBillingService>(
    () => ClinicBillingService(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      inventoryService: sl<InventoryService>(),
      doctorRepository: sl<DoctorRepository>(),
    ),
  );

  // ============================================
  // NEW COMPETITIVE FEATURE REPOSITORIES
  // ============================================

  // Staff Management Repository
  sl.registerLazySingleton<StaffRepository>(
    () => StaffRepository(sl<AppDatabase>()),
  );

  // Staff Payroll Service
  sl.registerLazySingleton<PayrollService>(
    () => PayrollService(sl<StaffRepository>()),
  );

  // NEW Staff Service (Replaces/Enhances StaffRepository)
  sl.registerLazySingleton<StaffService>(
    () => StaffService(
      db: sl<AppDatabase>(),
      auditRepo: sl<AuditRepository>(),
      sessionManager: sl<SessionManager>(),
    ),
  );

  // Marketing/CRM Repository
  sl.registerLazySingleton<MarketingRepository>(
    () => MarketingRepository(sl<AppDatabase>()),
  );

  // WhatsApp Service
  sl.registerLazySingleton<WhatsAppService>(() => WhatsAppService());

  // Dunning Service (Automated Payment Reminders)
  sl.registerLazySingleton<DunningService>(
    () => DunningService(
      db: sl<AppDatabase>(),
      billsRepo: sl<BillsRepository>(),
      customersRepo: sl<CustomersRepository>(),
      whatsAppService: sl<WhatsAppService>(),
    ),
  );

  // e-Invoice Repository
  sl.registerLazySingleton<EInvoiceRepository>(
    () => EInvoiceRepository(sl<AppDatabase>()),
  );

  // e-Invoice Service
  sl.registerLazySingleton<EInvoiceService>(
    () => EInvoiceService(
      sl<EInvoiceRepository>(),
      auditService: sl<AuditService>(),
    ),
  );

  // e-Way Bill Service
  sl.registerLazySingleton<EWayBillService>(
    () => EWayBillService(sl<EInvoiceRepository>()),
  );

  sl.registerLazySingleton<CustomerItemRequestRepository>(
    () => CustomerItemRequestRepository(
      db: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
    ),
  );

  sl.registerLazySingleton<VendorItemSnapshotRepository>(
    () => VendorItemSnapshotRepository(
      firestore: sl<cf.FirebaseFirestore>(),
      localStorage: sl<LocalStorageService>(),
    ),
  );

  sl.registerLazySingleton<StockTransactionRepository>(
    () => StockTransactionRepository(
      firestore: sl<cf.FirebaseFirestore>(),
      syncManager: sl<SyncManager>(),
    ),
  );

  sl.registerLazySingleton<PreOrderService>(
    () => PreOrderService(
      requestRepository: sl<CustomerItemRequestRepository>(),
      billsRepository: sl<BillsRepository>(),
      productsRepository: sl<ProductsRepository>(),
      stockTxnRepo: sl<StockTransactionRepository>(),
      snapshotRepo: sl<VendorItemSnapshotRepository>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<UserRepository>(
    () => UserRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
    ),
  );

  sl.registerLazySingleton<acc.AccountingRepository>(
    () => acc.AccountingRepository(db: sl<AppDatabase>()),
  );

  // Accounting Services
  // Internal service for journaling - separate from policy
  sl.registerLazySingleton<acc.JournalEntryService>(
    () => acc.JournalEntryService(repo: sl<acc.AccountingRepository>()),
  );

  // Public service with locking policy
  sl.registerLazySingleton<acc.AccountingService>(
    () => acc.AccountingService(
      sl<acc.JournalEntryService>(),
      sl<acc.LockingService>(),
    ),
  );

  sl.registerLazySingleton<acc.FinancialReportsService>(
    () => acc.FinancialReportsService(repo: sl<acc.AccountingRepository>()),
  );

  sl.registerLazySingleton<DayBookService>(
    () => DayBookService(sl<AppDatabase>(), syncManager: sl<SyncManager>()),
  );

  sl.registerLazySingleton<acc.LockingService>(
    () => acc.LockingService(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<PartyLedgerService>(
    () => PartyLedgerService(
      accountingRepo: sl<acc.AccountingRepository>(),
      reportsService: sl<acc.FinancialReportsService>(),
      db: sl<AppDatabase>(),
    ),
  );

  // Inventory
  sl.registerLazySingleton<InventoryService>(
    () => InventoryService(
      sl<AppDatabase>(),
      sl<acc.LockingService>(),
      sl<acc.AccountingService>(),
      sl<SyncManager>(),
      sl<ProductBatchRepository>(),
    ),
  );

  sl.registerLazySingleton<BatchAllocationService>(
    () => BatchAllocationService(
      productBatchRepository: sl<ProductBatchRepository>(),
    ),
  );

  sl.registerLazySingleton<PharmacyMigrationService>(
    () => PharmacyMigrationService(
      sl<ProductsRepository>(),
      sl<ProductBatchRepository>(),
    ),
  );

  // Data Integrity & Crash Recovery
  sl.registerLazySingleton<DataIntegrityService>(
    () => DataIntegrityService(database: sl<AppDatabase>()),
  );

  // Invoice Number Safety Service
  sl.registerLazySingleton<InvoiceNumberService>(
    () => InvoiceNumberService(sl<AppDatabase>()),
  );

  // ============================================
  // PETROL PUMP SERVICES
  // ============================================

  sl.registerLazySingleton<FuelService>(() => FuelService());
  sl.registerLazySingleton<DispenserService>(() => DispenserService());
  sl.registerLazySingleton<ShiftService>(() => ShiftService());
  sl.registerLazySingleton<TankService>(() => TankService());
  sl.registerLazySingleton<PetrolPumpBillingService>(
    () => PetrolPumpBillingService(),
  );
  sl.registerLazySingleton<CalibrationReminderService>(
    () => CalibrationReminderService(sl<AppDatabase>()),
  );

  // ============================================
  // AI / RECOMMENDATION SERVICES
  // ============================================

  sl.registerLazySingleton<CustomerRecommendationService>(
    () => CustomerRecommendationService(
      sl<AppDatabase>(),
      sl<CustomersRepository>(),
    ),
  );

  // ============================================
  // ML KIT SERVICES
  // ============================================
  sl.registerLazySingleton<MLKitOcrService>(() {
    final service = MLKitOcrService();
    // Disposal is handled by the service itself if needed, or we can use lazy singleton lifecycle
    // For services that need explicit disposal on app exit, we might need a disposal logic in main
    return service;
  });

  sl.registerLazySingleton<LanguageDetectionService>(() {
    final service = LanguageDetectionService();
    return service;
  });

  // OcrRouter
  sl.registerLazySingleton<OcrRouter>(() => OcrRouter());

  sl.registerLazySingleton<TranslationService>(() {
    final service = TranslationService();
    return service;
  });

  sl.registerLazySingleton<BarcodeScannerService>(
    () => BarcodeScannerService(),
  );

  // AI Assistant
  sl.registerLazySingleton<RecommendationService>(
    () =>
        RecommendationService(sl<ProductsRepository>(), sl<BillsRepository>()),
  );
  sl.registerLazySingleton<MorningBriefingService>(
    () => MorningBriefingService(sl<ReportsRepository>()),
  );
  sl.registerLazySingleton<VoiceIntentService>(() => VoiceIntentService());
  sl.registerLazySingleton<GSTR1Service>(
    () => GSTR1Service(sl<BillsRepository>(), sl<CustomersRepository>()),
  );

  // NOTE: Marketing, Staff modules already registered in "NEW COMPETITIVE FEATURE REPOSITORIES" section above

  // ============================================
  // RESTAURANT / HOTEL MODULE
  // ============================================

  // ----------------------------------------------------------------------
  // Unified Notification System (UNS) — Shared_SDK lazy singleton.
  // ----------------------------------------------------------------------
  // Initialised before the restaurant helpers because
  // RestaurantNotificationService now emits canonical events through this
  // SDK as part of task 14.3 (migration window for T-RES-1..5, T-RES-7).
  //
  // Construction is deliberately fault-tolerant: if the schema asset or the
  // documents directory is unavailable (e.g. during early bootstrap on web,
  // or in unit-test contexts that don't run the Flutter binding), we fall
  // back to an in-memory outbox and a no-op SDK so the app keeps booting.
  // The legacy local-notification rendering path is unaffected either way.
  if (!sl.isRegistered<uns.NotificationsSdk>()) {
    sl.registerSingletonAsync<uns.NotificationsSdk>(() async {
      final apiBase =
          (dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1').trim();
      final baseUrl = Uri.parse(apiBase.endsWith('/') ? apiBase : '$apiBase/');

      // Schema asset is bundled with the notifications-sdk package and
      // exposed via Flutter's standard packages/<name>/<asset> path.
      late final uns.SchemaValidator validator;
      try {
        final schemaText = await rootBundle.loadString(
          'packages/notifications_sdk/event-contract.schema.json',
        );
        validator = uns.SchemaValidator.fromString(schemaText);
      } catch (e) {
        monitoring.warning(
          'ServiceLocator',
          'UNS schema asset unavailable, validator falls back to permissive '
              'object schema: $e',
        );
        validator = uns.SchemaValidator.fromString(
          '{"\$schema":"https://json-schema.org/draft/2020-12/schema",'
          '"type":"object"}',
        );
      }

      uns.OutboxStorage outbox;
      try {
        final docs = await getApplicationDocumentsDirectory();
        outbox = uns.FileOutboxStorage(
          uns.FileOutboxStorage.defaultPath(docs.path),
        );
      } catch (e) {
        monitoring.warning(
          'ServiceLocator',
          'UNS file outbox unavailable, using in-memory fallback: $e',
        );
        outbox = uns.InMemoryOutboxStorage();
      }

      final sdk = uns.NotificationsSdk(
        apiBaseUrl: baseUrl,
        tokenProvider: () => sl<SessionManager>().getAccessToken(),
        validator: validator,
        outbox: outbox,
      );

      // Open the WebSocket / SSE asynchronously; failure here is tolerated
      // because emit() will buffer events to the outbox until the SDK
      // reconnects.
      sdk.connect().catchError((Object e) {
        monitoring.warning('ServiceLocator', 'UNS SDK connect deferred: $e');
      });

      return sdk;
    });
  }

  // ============================================
  // RESTAURANT REPOSITORIES & SERVICES
  // ============================================
  sl.registerLazySingleton<FoodMenuRepository>(() => FoodMenuRepository());
  sl.registerLazySingleton<FoodOrderRepository>(() => FoodOrderRepository());
  sl.registerLazySingleton<RestaurantTableRepository>(
    () => RestaurantTableRepository(),
  );
  sl.registerLazySingleton<RestaurantBillRepository>(
    () => RestaurantBillRepository(),
  );
  sl.registerLazySingleton<QrCodeService>(() => QrCodeService());
  sl.registerLazySingleton<RestaurantSyncService>(
    () => RestaurantSyncService(
      menuRepo: sl<FoodMenuRepository>(),
      orderRepo: sl<FoodOrderRepository>(),
      tableRepo: sl<RestaurantTableRepository>(),
      billRepo: sl<RestaurantBillRepository>(),
      syncManager: sl<SyncManager>(),
    ),
  );
  sl.registerLazySingleton<RestaurantNotificationService>(
    () => RestaurantNotificationService(),
  );
  sl.registerLazySingleton<RestaurantPdfBillService>(
    () => RestaurantPdfBillService(),
  );

  // ============================================
  // PAYMENT SERVICES
  // ============================================
  sl.registerLazySingleton<UpiPaymentService>(
    () => UpiPaymentService(sl<AppDatabase>()),
  );

  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepository(
      database: sl<AppDatabase>(),
      syncManager: sl<SyncManager>(),
      errorHandler: sl<ErrorHandler>(),
      auditService: sl<AuditService>(),
    ),
  );

  // Payment Gateway API Service (Desktop ↔ Backend Integration)
  sl.registerLazySingleton<PaymentGatewayApiService>(
    () => PaymentGatewayApiService(sl<ApiClient>()),
  );

  // Delivery Challan Module
  sl.registerLazySingleton<DeliveryChallanRepository>(
    () => DeliveryChallanRepository(sl<AppDatabase>()),
  );

  sl.registerLazySingleton<DeliveryChallanService>(
    () => DeliveryChallanService(
      sl<DeliveryChallanRepository>(),
      sl<BillsRepository>(),
      sl<ProductsRepository>(),
      sl<InvoiceNumberService>(),
      sl<SessionManager>(),
    ),
  );

  // Reports
  sl.registerLazySingleton<TallyXmlService>(
    () => TallyXmlService(
      sl<BillsRepository>(),
      sl<PaymentRepository>(),
      sl<CustomersRepository>(),
      sl<GstRepository>(),
      sl<PurchaseRepository>(),
      sl<VendorsRepository>(),
      sl<ShopRepository>(),
    ),
  );

  // GST Module
  sl.registerLazySingleton<GstRepository>(
    () => GstRepository(db: sl<AppDatabase>()),
  );

  // Payment Orchestrator
  sl.registerLazySingleton<PaymentOrchestrator>(() => PaymentOrchestrator());

  // Initialize Restaurant Services
  await sl<RestaurantNotificationService>().initialize();

  // Wire the RestaurantNotificationService → Shared_SDK bridge (task 14.3).
  // The bindings hand back the SDK + actor pair via short closures so the
  // helper file itself stays free of GetIt and SessionManager imports
  // (which keeps unit tests for the helper compilable in isolation).
  registerRestaurantUnsBindings(
    sdkResolver: () {
      try {
        if (sl.isRegistered<uns.NotificationsSdk>()) {
          return sl<uns.NotificationsSdk>();
        }
      } catch (_) {
        // SDK still resolving asynchronously — caller treats null as "skip".
      }
      return null;
    },
    actorResolver: () {
      try {
        final session = sl<SessionManager>().currentSession;
        final actorId = session.odId.isNotEmpty
            ? session.odId
            : (session.ownerId ?? '');
        final vendorId = (session.ownerId?.isNotEmpty ?? false)
            ? session.ownerId!
            : session.odId;
        if (actorId.isEmpty && vendorId.isEmpty) return null;
        return (actorId: actorId, vendorId: vendorId);
      } catch (_) {
        return null;
      }
    },
  );

  // Initialize Event Listeners
  sl<NotificationListenerService>().initialize();

  // ============================================
  // INITIALIZE SYNC ENGINE (Isolated)
  // ============================================
  try {
    // Register Sync Repository and Engine if not already registered (lazy singletons)
    if (!sl.isRegistered<SyncRepository>()) {
      sl.registerLazySingleton<SyncRepository>(
        () => DriftSyncRepository(sl<AppDatabase>()),
      );
    }
    if (!sl.isRegistered<SyncEngine>()) {
      sl.registerLazySingleton<SyncEngine>(() => SyncEngine.instance);
    }

    // Initialize Engine
    final engine = sl<SyncEngine>();
    engine.initialize(
      repository: sl<SyncRepository>(),
      // process: sl<TaskProcessor>() // optional if we registered it
    );
    monitoring.info('ServiceLocator', 'SyncEngine (Isolated) initialized');

    // Initialize Local Storage Service (Deprecated)
    await sl<LocalStorageService>().init();
    monitoring.info('ServiceLocator', 'LocalStorageService initialized');

    // LEGACY SyncManager - WRITE-ONLY MODE
    // initialized to allow legacy enqueue() calls to write to Drift
    // but DISABLED processing to prevent double-execution.
    if (kIsWeb) {
      // On web, defer sync manager init slightly to let IndexedDB stabilize
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await sl<SyncManager>().initialize(
            localOperations: sl<SyncQueueLocalOperations>(),
            config: const SyncManagerConfig(
              maxConcurrency: 1,
              batchSize: 5,
              autoStart: false,
              enabled: false, // DISABLE PROCESSING
            ),
          );
          monitoring.info(
            'ServiceLocator',
            'SyncManager initialized (Write-Only)',
          );
        } catch (e) {
          monitoring.warning(
            'ServiceLocator',
            'SyncManager init skipped on web: ${e.toString()}',
          );
        }
      });
    } else {
      await sl<SyncManager>().initialize(
        localOperations: sl<SyncQueueLocalOperations>(),
        config: const SyncManagerConfig(
          maxConcurrency: 1,
          batchSize: 10,
          autoStart: false,
          enabled: false, // DISABLE PROCESSING
        ),
      );
      monitoring.info('ServiceLocator', 'SyncManager initialized (Write-Only)');
    }
  } catch (e, stack) {
    monitoring.warning('ServiceLocator', 'SyncEngine init failed: $e');
    debugPrint('SyncEngine init stack: $stack');
  }

  // ==========================================================================
  // OFFLINE LICENSE ACTIVATION — Offline_Lifetime_Mode service layer
  // ==========================================================================
  // Registers every Offline_Lifetime_Mode service through the existing `sl`
  // (task 20.1). ALL registrations are LAZY so that in the default
  // Cloud_Subscription_Mode nothing offline is ever constructed or started:
  // the offline switch stays entirely at the service/repository layer and the
  // Flutter UI + cloud `ApiClient` behavior are byte-for-byte unchanged
  // (Req 1.7, 2.1, 2.3, 11.1, 11.5, 11.7). None of these are referenced from
  // the widget tree.
  _registerOfflineServices();

  _isInitialized = true;
  monitoring.info('ServiceLocator', 'All dependencies initialized');
}

/// Registers the Offline_Lifetime_Mode service layer (offline-license-activation
/// feature, task 20.1) through the existing `sl`.
///
/// Every service is registered with `registerLazySingleton`, matching the
/// existing registration style, and guarded with `isRegistered` so a repeated
/// init (or a test that pre-registers a fake) is never clobbered. Because the
/// registrations are lazy, the offline backend is constructed only when the
/// Backend_Supervisor / Offline_Startup_Coordinator is actually resolved in
/// Offline_Lifetime_Mode — Cloud_Subscription_Mode startup touches none of them.
void _registerOfflineServices() {
  // --- Foundation: secure config + the single mode-switch point -------------

  // Local_Config — secure persistence of operating_mode + runtime settings.
  if (!sl.isRegistered<LocalConfig>()) {
    sl.registerLazySingleton<LocalConfig>(() => LocalConfig());
  }

  // Mode_Manager — the ONLY online/offline routing decision point. `ApiClient`
  // already resolves its baseUrl through this when registered (task 1.3); in
  // Cloud_Subscription_Mode it returns the AWS host == ApiConfig.baseUrl, so
  // cloud behavior is unchanged (Req 2.1).
  if (!sl.isRegistered<ModeManager>()) {
    sl.registerLazySingleton<ModeManager>(
      () => DefaultModeManager(localConfig: sl<LocalConfig>()),
    );
  }

  // --- Cross-cutting security layer (key derivation, integrity, tamper) -----
  if (!sl.isRegistered<OfflineSecurityLayer>()) {
    sl.registerLazySingleton<OfflineSecurityLayer>(
      () => OfflineSecurityLayer(),
    );
  }

  // --- Backend_Supervisor — packaged Local_Backend process lifecycle --------
  // All collaborators are injected as production seams. The license/session
  // steps reuse existing components: license presence + decrypt/validate via
  // OfflineSecurityLayer (Req 17.11/17.12), session restore via SessionManager.
  // The repository-connection seam connects/disconnects the cloud-resolving
  // ApiClient against the loopback backend purely by toggling the mode target;
  // it never alters Cloud_Subscription_Mode.
  if (!sl.isRegistered<BackendSupervisor>()) {
    sl.registerLazySingleton<BackendSupervisor>(
      () => DefaultBackendSupervisor(
        processController: NodeBackendProcessController.bundled(),
        healthProbe: HttpBackendHealthProbe(),
        repository: CallbackRepositoryConnection(
          onConnect: () => monitoring.info(
            'BackendSupervisor',
            'Repository layer connected to Local_Backend.',
          ),
          onDisconnect: () => monitoring.warning(
            'BackendSupervisor',
            'Repository layer marked disconnected from Local_Backend.',
          ),
        ),
        localLicenseCheck: OfflineStartupCoordinator.buildLocalLicenseCheck(
          sl<LocalLicenseFile>(),
        ),
        licenseDecryptValidate:
            OfflineStartupCoordinator.buildLicenseDecryptValidate(
              sl<OfflineSecurityLayer>(),
            ),
        sessionRestore: () => sl<SessionManager>().refreshSession(),
      ),
    );
  }

  // Local_License_File — AES-256-GCM activation result on disk (reused by the
  // supervisor's license-check seam and the migration wizard default).
  if (!sl.isRegistered<LocalLicenseFile>()) {
    sl.registerLazySingleton<LocalLicenseFile>(() => LocalLicenseFile());
  }

  // Offline_Startup_Coordinator — drives the end-to-end offline Startup_Sequence
  // ONLY when Offline_Lifetime_Mode is active; returns early (touching nothing
  // offline) in Cloud_Subscription_Mode. The supervisor is resolved lazily via
  // a closure so it is constructed only when actually offline.
  if (!sl.isRegistered<OfflineStartupCoordinator>()) {
    sl.registerLazySingleton<OfflineStartupCoordinator>(
      () => OfflineStartupCoordinator(
        modeManager: sl<ModeManager>(),
        supervisorProvider: () => sl<BackendSupervisor>(),
      ),
    );
  }

  // --- Feature gating + parity ----------------------------------------------

  // Online_Only_Feature gate — blocks online-only features while offline; in
  // Cloud_Subscription_Mode it allows everything (UI/behavior unchanged).
  if (!sl.isRegistered<OnlineOnlyFeatureGate>()) {
    sl.registerLazySingleton<OnlineOnlyFeatureGate>(
      () => OnlineOnlyFeatureGate(sl<ModeManager>()),
    );
  }

  // Offline_Gating_Engine — bound to the active License_Token. Until activation
  // populates a real token, an empty, most-restrictive token is used; the
  // License_Validator re-binds the engine with the decrypted token when the
  // Local_License_File is read. Registered as a factory so each resolution
  // reflects the currently bound token.
  if (!sl.isRegistered<OfflineGatingEngine>()) {
    sl.registerLazySingleton<OfflineGatingEngine>(
      () => DefaultOfflineGatingEngine(
        LicenseToken(
          tenantId: '',
          plan: '',
          allowedBusinessTypes: const <String>[],
          features: const <String>[],
          superAdminOverride: false,
        ),
      ),
    );
  }

  // --- Data: atomic offline writes, archival, backup, migration -------------

  // Sync_Foundation — atomic offline-write recording into the existing SyncQueue.
  if (!sl.isRegistered<SyncFoundation>()) {
    sl.registerLazySingleton<SyncFoundation>(
      () => SyncFoundation(sl<AppDatabase>()),
    );
  }

  // Data_Archival_Service — two-year archival partition over the Local_Store.
  if (!sl.isRegistered<DataArchivalService>()) {
    sl.registerLazySingleton<DataArchivalService>(
      () => DataArchivalService(sl<AppDatabase>()),
    );
  }

  // Backup_Service — scheduled verified backups + restore (offline data dir).
  // Namespaced import alias avoids the legacy cloud/security BackupService types.
  if (!sl.isRegistered<offline_backup.BackupService>()) {
    sl.registerLazySingleton<offline_backup.BackupService>(
      () => offline_backup.BackupService(config: sl<LocalConfig>()),
    );
  }

  // Migration_Wizard — move an activated install to a new machine (48h overlap).
  if (!sl.isRegistered<MigrationWizard>()) {
    sl.registerLazySingleton<MigrationWizard>(() => DefaultMigrationWizard());
  }

  // --- Update_Service --------------------------------------------------------
  // Registered with documented no-op source/installer seams (production
  // defaults until a concrete release feed / desktop updater is wired). The
  // deferral policy (Req 18.2–18.4) and the "updates never touch Local_Store"
  // guarantee (Req 18.5) hold regardless of the seams.
  if (!sl.isRegistered<UpdateService>()) {
    sl.registerLazySingleton<UpdateService>(
      () => DefaultUpdateService(
        source: const NoOpUpdateSource(),
        installer: const NoOpUpdateInstaller(),
        config: sl<LocalConfig>(),
      ),
    );
  }

  // --- LAN_Coordinator -------------------------------------------------------
  // Reuses LocalConfig (role/host), the activated License_Token's maxDevices
  // (default allowance resolver), and the existing offline auth/JWT session via
  // the registered SessionManager access token — no new auth scheme.
  if (!sl.isRegistered<LanCoordinator>()) {
    sl.registerLazySingleton<LanCoordinator>(
      () => DefaultLanCoordinator(
        localConfig: sl<LocalConfig>(),
        authTokenProvider: () => sl<SessionManager>().getAccessToken(),
      ),
    );
  }

  monitoring.info(
    'ServiceLocator',
    'Offline_Lifetime_Mode services registered (lazy; cloud unchanged).',
  );
}

/// Reset all dependencies (for testing)
Future<void> resetDependencies() async {
  await sl.reset();
  _isInitialized = false;
}

/// Check if dependencies are initialized
bool get isDependenciesInitialized => _isInitialized;

// ============================================================================
// CONVENIENCE GETTERS (Type-safe access)
// ============================================================================

/// Get the session manager (ONLY auth state source)
SessionManager get sessionManager => sl<SessionManager>();

/// Get the database
AppDatabase get database => sl<AppDatabase>();

/// Get the sync manager
SyncManager get syncManagerInstance => sl<SyncManager>();

/// Get the error handler
ErrorHandler get errorHandlerInstance => sl<ErrorHandler>();

// Repositories
BillsRepository get billsRepository => sl<BillsRepository>();
PatientsRepository get patientsRepository => sl<PatientsRepository>();
VisitsRepository get visitsRepository => sl<VisitsRepository>();
CustomersRepository get customersRepository => sl<CustomersRepository>();
ProductsRepository get productsRepository => sl<ProductsRepository>();
RevenueRepository get revenueRepository => sl<RevenueRepository>();
PurchaseRepository get purchaseRepository => sl<PurchaseRepository>();
BankRepository get bankRepository => sl<BankRepository>();
ReportsRepository get reportsRepository => sl<ReportsRepository>();
ExpensesRepository get expensesRepository => sl<ExpensesRepository>();
UdharRepository get udharRepository => sl<UdharRepository>();
ShopRepository get shopRepository => sl<ShopRepository>();
VendorsRepository get vendorsRepository => sl<VendorsRepository>();
UserRepository get userRepository => sl<UserRepository>();
CustomerItemRequestRepository get customerItemRequestRepository =>
    sl<CustomerItemRequestRepository>();

PatientRepository get patientRepository => sl<PatientRepository>();
DoctorRepository get doctorRepository => sl<DoctorRepository>();
AppointmentRepository get appointmentRepository => sl<AppointmentRepository>();
PrescriptionRepository get prescriptionRepository =>
    sl<PrescriptionRepository>();

PatientService get patientService => sl<PatientService>();

// Petrol Pump Services
FuelService get fuelService => sl<FuelService>();
DispenserService get dispenserService => sl<DispenserService>();
ShiftService get shiftService => sl<ShiftService>();
TankService get tankService => sl<TankService>();
PetrolPumpBillingService get petrolPumpBillingService =>
    sl<PetrolPumpBillingService>();

// Restaurant Module
FoodMenuRepository get foodMenuRepository => sl<FoodMenuRepository>();
FoodOrderRepository get foodOrderRepository => sl<FoodOrderRepository>();
RestaurantTableRepository get restaurantTableRepository =>
    sl<RestaurantTableRepository>();
RestaurantBillRepository get restaurantBillRepository =>
    sl<RestaurantBillRepository>();
QrCodeService get qrCodeService => sl<QrCodeService>();
RestaurantSyncService get restaurantSyncService => sl<RestaurantSyncService>();
RestaurantNotificationService get restaurantNotificationService =>
    sl<RestaurantNotificationService>();
RestaurantPdfBillService get restaurantPdfBillService =>
    sl<RestaurantPdfBillService>();

// Payment Repository

// ============================================================================
// DEPRECATED: Old session service compatibility
// Use SessionManager instead
// ============================================================================

/// @Deprecated('Use sessionManager instead')
/// This getter provides backward compatibility during migration
/// It returns the SessionManager which has compatible API
SessionManager get sessionService => sessionManager;

/// @Deprecated('Use repositories instead')
LocalStorageService get localStorageService => sl<LocalStorageService>();
