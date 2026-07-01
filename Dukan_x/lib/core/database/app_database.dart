// ============================================================================
// DUKANX ENTERPRISE DATABASE
// ============================================================================
// Main Drift database class with all tables and DAOs
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'tables.dart';

import 'connection.dart';
import 'migrations/system_owner_backfill.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';

part 'app_database.g.dart';

// ============================================================================
// DATABASE CLASS
// ============================================================================

@DriftDatabase(
  tables: [
    SyncQueue,
    Bills,
    BillItems,
    Customers,
    Products,
    Payments,
    PaymentTransactions, // NEW: Dynamic QR Audit
    DeliveryChallans, // NEW: Delivery Challan
    Expenses,
    FileUploads,
    OcrTasks,
    VoiceTasks,
    SchemaVersions,
    Checksums,
    AuditLogs,
    ConflictLog, // NEW: Conflict audit trail
    DeadLetterQueue,
    BankAccounts,
    BankTransactions,
    Vendors,
    PurchaseOrders,
    PurchaseItems,
    // Customer Dashboard Tables
    CustomerConnections,
    CustomerLedger,
    CustomerNotifications,
    // Customer-Shop QR Linking (Multi-Tenant Isolation)
    CustomerProfiles, // Shop-scoped customer profiles
    ShopLinks, // Customer-shop associations
    UdharPeople,
    UdharTransactions,
    // Duplicate UdharTransactions removed
    Shops,
    Receipts,
    ReturnInwards,
    Proformas,
    Bookings,
    Dispatches,
    Users,
    // GST Compliance Tables
    GstSettings,
    GstInvoiceDetails,
    HsnMaster,
    // Accounting Tables
    JournalEntries,
    AccountingPeriods,
    LedgerAccounts,
    DayBook,
    // Reminder Tables
    ReminderSettings,
    ReminderLogs,
    PeriodLocks,
    StockMovements, // Phase 8: Golden Rule Inventory
    StockReservations,
    // Phase 12: e-Invoice & e-Way Bill
    EInvoices,
    EWayBills,
    // Phase 12: Marketing & CRM
    MarketingCampaigns,
    CampaignLogs,
    MessageTemplates,
    // AI
    CustomerBehaviors,
    // Phase 12: Staff Management
    StaffMembers,
    StaffAttendance,
    SalaryRecords,
    // Phase 13: Credit Network
    CreditProfiles,
    // Phase 14: Restaurant / Hotel Food Ordering
    FoodCategories,
    FoodMenuItems,
    RestaurantTables,
    RestaurantQrCodes,
    FoodOrders,
    FoodOrderItems,
    RestaurantBills,
    RestaurantInventoryItems,
    ItemRecipes,
    RestaurantKots,
    RestaurantFloors,
    // Phase 15: Invoice Number Safety
    InvoiceCounters,
    // Phase 16: Mobile/Computer Shop - Service Jobs & IMEI Tracking
    IMEISerials,
    ServiceJobs,
    ServiceJobParts,
    ServiceJobStatusHistory,
    WarrantyClaims,
    ProductVariants,
    Exchanges,
    // Phase 20: Security & Fraud Prevention
    SecuritySettingsTable,
    CashClosings,
    FraudAlerts,
    UserSessions,
    // Phase 22: Doctor Prescriptions
    Prescriptions,
    Visits,
    Patients,
    // Phase 23: Pharmacy Compliance (Audit Fix)
    ProductBatches,

    LockOverrideLogs,
    // Phase 30: Shortcut Panel
    ShortcutDefinitions,
    UserShortcuts,
    // Phase 31: Manufacturing Module
    BillOfMaterials,
    ProductionEntries,
    // Phase 32: Recurring Billing
    Subscriptions,
    SubscriptionItems,
    CustomerItemRequests,
    // Phase 35: Doctor / Clinic Module
    Patients,
    PatientAccessLogs, // PHI access audit log (clinic task 5.3)
    DoctorProfiles,
    PatientDoctorLinks,
    Appointments,
    // Prescriptions is already registered for v24, checking if we need re-declaration or extend
    // Assuming Prescriptions table definition in tables.dart was UPDATED to include more fields or used as is.
    // Ideally we should double check if Prescriptions was already in the list.
    // Looking at line 116: Prescriptions IS ALREADY REGISTERED.
    // We need to add others:
    MedicalRecords,
    PrescriptionItems,
    LabReports,
    MedicalTemplates, // Added
    Farmers,
    CommissionLedger,
    // Vegetable Broker (Mandi) — canonical Drift tables (RID + integer paise).
    // Created in v43 migration (task 3.1).
    VegetableLots,
    MandiSettlements,
    RateHistory,
    Buyers,
    // Petrol Pump Tables
    Shifts,
    Tanks,
    Nozzles,
    Dispensers,
    // Phase 12+: Enhanced Staff Management
    StaffNozzleAssignments,
    StaffSalesDetails,
    StaffCashSettlements,
    // Phase 38: Petrol Pump - Additional Tables
    CashDeposits,
    LubeStock,
    DensityRecords,
    LicenseCache,
    DunningRules,
    DunningLogs,
    KvStore,
    // Phase 5 School ERP — Offline cache tables (v52, Requirement 8.1, 8.6)
    SchoolStudentsCache,
    SchoolFeesCache,
    SchoolAttendanceCache,
    // Offline-license-activation v39: missing cloud-entity tables
    Roles,
    Permissions,
    Categories,
    Units,
    Inventory,
    BusinessSettings,
    TaxRates,
  ],
)
class AppDatabase extends _$AppDatabase implements SyncQueueLocalOperations {
  // Singleton instance
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  AppDatabase._() : super(_openConnection());

  // For testing
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 52; // v52: Phase 5 schoolErp — school_students_cache, school_fees_cache, school_attendance_cache

  // ==========================================================================
  // v46 SYSTEM-owner backfill resolver (clinic task 4.4)
  //
  // Optional hook returning the current authenticated owner/clinic id for the
  // legacy-'SYSTEM' backfill migration. Wired at startup (service_locator) from
  // the session-owning layer so THIS file needs no SessionManager / DI import
  // (which would be circular). Returns null when no owner is resolvable; the
  // backfill then SKIPS (fail-safe) and is retried on a later open via the
  // beforeOpen deferred net below. Never fabricates an owner id.
  // ==========================================================================
  static String? Function()? systemOwnerBackfillResolver;

  String? _resolveBackfillOwnerId() {
    try {
      return systemOwnerBackfillResolver?.call();
    } catch (_) {
      return null;
    }
  }

  /// Deletes every row from every table. Used on logout so a different user
  /// signing in on the same device never sees the previous tenant's cached
  /// data. Schema is preserved; only data is wiped.
  Future<void> wipeAllData() async {
    await transaction(() async {
      // Disable FK enforcement so delete order doesn't matter.
      await customStatement('PRAGMA foreign_keys = OFF');
      for (final table in allTables) {
        await delete(table).go();
      }
      await customStatement('PRAGMA foreign_keys = ON');
    });
  }

  /// Serializes every table's rows for backup. Schema-agnostic: keyed by table
  /// name, each value is the list of rows as column→value maps. Blob columns
  /// are base64-encoded so the result is JSON-safe.
  Future<Map<String, List<Map<String, dynamic>>>> exportAllData() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in allTables) {
      final name = table.actualTableName;
      final rows = await customSelect('SELECT * FROM "$name"').get();
      result[name] = rows.map((r) => _encodeRow(r.data)).toList();
    }
    return result;
  }

  /// Restores rows produced by [exportAllData] inside a single transaction.
  /// Each table is cleared then repopulated; FK enforcement is suspended so
  /// insertion order across tables does not matter. Atomic: any failure rolls
  /// the whole transaction back, so the DB is never left half-restored.
  Future<void> importAllData(
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    final tablesByName = {for (final t in allTables) t.actualTableName: t};
    await transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');
      // Clear existing data first so restore replaces, not merges.
      for (final table in allTables) {
        await delete(table).go();
      }
      for (final entry in data.entries) {
        if (!tablesByName.containsKey(entry.key)) continue; // unknown table
        for (final row in entry.value) {
          await _insertRawRow(entry.key, _decodeRow(row));
        }
      }
      await customStatement('PRAGMA foreign_keys = ON');
    });
  }

  Future<void> _insertRawRow(String table, Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    final cols = row.keys.toList();
    final colSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    final values = cols.map((c) => row[c]).toList();
    await customInsert(
      'INSERT INTO "$table" ($colSql) VALUES ($placeholders)',
      variables: values.map(Variable.new).toList(),
    );
  }

  // Blob columns arrive as Uint8List; encode to base64 with a marker so the
  // round-trip is lossless through JSON.
  static const _blobPrefix = '__b64__:';

  Map<String, dynamic> _encodeRow(Map<String, dynamic> row) {
    return row.map((k, v) {
      if (v is Uint8List) {
        return MapEntry(k, '$_blobPrefix${base64Encode(v)}');
      }
      return MapEntry(k, v);
    });
  }

  Map<String, dynamic> _decodeRow(Map<String, dynamic> row) {
    return row.map((k, v) {
      if (v is String && v.startsWith(_blobPrefix)) {
        return MapEntry(k, base64Decode(v.substring(_blobPrefix.length)));
      }
      return MapEntry(k, v);
    });
  }

  // ==========================================================================
  // Offline License Activation — task 7.2 (Requirements 8.5, 16.2)
  //
  // Cloud-entity tables that carry the universal System_Columns and therefore
  // require indexes on their high-frequency offline-query columns. The flag
  // records whether the table also has a `deleted_at` column (soft delete) so
  // the deleted_at index is only created where the column exists.
  //
  // Index names follow the existing `idx_<table>_<column>` convention. All
  // statements use CREATE INDEX IF NOT EXISTS so they are idempotent and safe
  // to run on both fresh installs (onCreate) and upgrades (onUpgrade v40).
  // ==========================================================================
  static const List<({String table, bool hasDeletedAt})>
  _systemColumnIndexTables = [
    (table: 'bills', hasDeletedAt: true),
    (table: 'bill_items', hasDeletedAt: false),
    (table: 'customers', hasDeletedAt: true),
    (table: 'products', hasDeletedAt: true),
    (table: 'payments', hasDeletedAt: true),
    (table: 'vendors', hasDeletedAt: true),
    (table: 'purchase_orders', hasDeletedAt: true),
    (table: 'purchase_items', hasDeletedAt: false),
    (table: 'stock_movements', hasDeletedAt: false),
    (table: 'users', hasDeletedAt: false),
    (table: 'user_sessions', hasDeletedAt: false),
    (table: 'roles', hasDeletedAt: true),
    (table: 'permissions', hasDeletedAt: true),
    (table: 'categories', hasDeletedAt: true),
    (table: 'units', hasDeletedAt: true),
    (table: 'inventory', hasDeletedAt: true),
    (table: 'business_settings', hasDeletedAt: true),
    (table: 'tax_rates', hasDeletedAt: true),
  ];

  /// Creates the per-table System_Columns indexes (Req 8.5, 16.2).
  ///
  /// Indexes tenant_id and sync_status on every System_Columns table, plus
  /// deleted_at where the table has that column. Idempotent (IF NOT EXISTS),
  /// so it is safe to invoke from both onCreate and the v40 upgrade step.
  Future<void> _createSystemColumnIndexes() async {
    for (final entry in _systemColumnIndexTables) {
      final t = entry.table;
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${t}_tenant_id ON $t (tenant_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${t}_sync_status ON $t (sync_status)',
      );
      if (entry.hasDeletedAt) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_${t}_deleted_at ON $t (deleted_at)',
        );
      }
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Fresh installs get the System_Columns indexes immediately (Req 8.5).
      await _createSystemColumnIndexes();
      debugPrint('AppDatabase: Created all tables');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      debugPrint('AppDatabase: Migrating from $from to $to');

      if (from < 4) {
        // Migration to version 4: Add new columns to bills table
        await m.addColumn(bills, bills.cashPaid);
        await m.addColumn(bills, bills.onlinePaid);
        await m.addColumn(bills, bills.businessType);
        await m.addColumn(bills, bills.serviceCharge);
      }

      if (from < 5) {
        // Migration to version 5: Add deviceId columns and ConflictLog table
        await m.addColumn(syncQueue, syncQueue.deviceId);
        await m.addColumn(bills, bills.deviceId);
        await m.addColumn(customers, customers.deviceId);
        await m.addColumn(products, products.deviceId);
        await m.createTable(conflictLog);
      }
      if (from < 6) {
        // Migration to version 6: Add Shops table
        await m.createTable(shops);
      }
      if (from < 7) {
        // Migration to version 7: Add Revenue tables
        await m.createTable(receipts);
        await m.createTable(returnInwards);
        await m.createTable(proformas);
        await m.createTable(bookings);
        await m.createTable(dispatches);
      }
      if (from < 8) {
        // Migration to version 8: Add Users table and Onboarding columns
        await m.createTable(users);
        await m.addColumn(shops, shops.businessType);
        await m.addColumn(shops, shops.appLanguage);
        await m.addColumn(shops, shops.onboardingCompleted);
      }
      if (from < 9) {
        // Migration to version 9: Add ifsc column to bank_accounts
        await m.addColumn(bankAccounts, bankAccounts.ifsc as GeneratedColumn);
      }
      if (from < 10) {
        // Migration to version 10: GST, Accounting, and Reminder modules
        // GST Tables
        await m.createTable(gstSettings);
        await m.createTable(gstInvoiceDetails);
        await m.createTable(hsnMaster);
        // Accounting Tables
        await m.createTable(journalEntries);
        await m.createTable(accountingPeriods);
        await m.createTable(ledgerAccounts);
        // Reminder Tables
        await m.createTable(reminderSettings);
        await m.createTable(reminderLogs);
        // Add GST columns to existing tables
        await m.addColumn(products, products.hsnCode);
        await m.addColumn(products, products.cgstRate);
        await m.addColumn(products, products.sgstRate);
        await m.addColumn(products, products.igstRate);
        await m.addColumn(billItems, billItems.hsnCode);
        await m.addColumn(billItems, billItems.cgstRate);
        await m.addColumn(billItems, billItems.cgstAmount);
        await m.addColumn(billItems, billItems.sgstRate);
        await m.addColumn(billItems, billItems.sgstAmount);
        await m.addColumn(billItems, billItems.igstRate);
        await m.addColumn(billItems, billItems.igstAmount);
        await m.addColumn(customers, customers.stateCode);
        await m.addColumn(customers, customers.creditPeriodDays);
        await m.addColumn(customers, customers.creditLimit);
        await m.addColumn(customers, customers.optInSmsReminders);
        await m.addColumn(customers, customers.optInWhatsAppReminders);
      }
      if (from < 11) {
        // Migration to version 11: Stock Automation
        await m.createTable(stockMovements);
      }
      if (from < 12) {
        // Migration to version 12: e-Invoice, Marketing, Staff Management
        // e-Invoice Tables
        await m.createTable(eInvoices);
        await m.createTable(eWayBills);
        // Marketing Tables
        await m.createTable(marketingCampaigns);
        await m.createTable(campaignLogs);
        await m.createTable(messageTemplates);
        // Staff Management Tables
        await m.createTable(staffMembers);
        await m.createTable(staffAttendance);
        await m.createTable(salaryRecords);
      }
      if (from < 15) {
        // Migration to version 15: Restaurant / Hotel Food Ordering System
        await m.createTable(foodCategories);
        await m.createTable(foodMenuItems);
        await m.createTable(restaurantTables);
        await m.createTable(restaurantQrCodes);
        await m.createTable(foodOrders);
        await m.createTable(foodOrderItems);
        await m.createTable(restaurantBills);
      }
      if (from < 16) {
        // Migration to version 16: Invoice Counter for collision-free invoice numbers
        await m.createTable(invoiceCounters);
      }
      if (from < 17) {
        // Migration to version 17: Delivery Challan
        await m.createTable(deliveryChallans);
        await m.addColumn(bills, bills.deliveryChallanId);
      }
      if (from < 18) {
        // Migration to version 18: Mobile/Computer Shop - Service Jobs & IMEI Tracking
        await m.createTable(iMEISerials);
        await m.createTable(serviceJobs);
        await m.createTable(serviceJobParts);
        await m.createTable(serviceJobStatusHistory);
        await m.createTable(productVariants);
        await m.createTable(productVariants);
        await m.createTable(exchanges);
      }
      if (from < 19) {
        // Migration to version 19: Fraud Prevention
        // 1. Audit Log Hash Chaining
        await m.addColumn(auditLogs, auditLogs.previousHash);
        await m.addColumn(auditLogs, auditLogs.currentHash);
        // 2. Bill Locking
        await m.addColumn(bills, bills.printCount);
      }
      if (from < 20) {
        // Migration to version 20: Security & Fraud Prevention Tables
        await m.createTable(securitySettingsTable);
        await m.createTable(cashClosings);
        await m.createTable(fraudAlerts);
        await m.createTable(userSessions);
      }
      if (from < 21) {
        // Migration to version 21: Customer Master Tab Enhancement
        await m.addColumn(customers, customers.customerType);
        await m.addColumn(customers, customers.openingBalance);
        await m.addColumn(customers, customers.priceLevel);
        await m.addColumn(customers, customers.gstPreference);
        await m.addColumn(customers, customers.isBlocked);
        await m.addColumn(customers, customers.blockReason);
        await m.addColumn(customers, customers.lastTransactionDate);
      }
      if (from < 22) {
        // Migration to version 22: Customer-Shop QR Linking System
        // 1. Create shop-scoped customer profiles table
        await m.createTable(customerProfiles);
        // 2. Create customer-shop links table
        await m.createTable(shopLinks);
        // 3. Add customerProfileId to bills for linked customer billing
        await m.addColumn(bills, bills.customerProfileId);
      }
      if (from < 23) {
        // Migration to version 23: Add altBarcodes to Products
        await m.addColumn(products, products.altBarcodes as GeneratedColumn);
      }
      if (from < 24) {
        await m.createTable(prescriptions);
        await m.addColumn(bills, bills.prescriptionId);
      }
      if (from < 25) {
        // Migration to version 25: Add drugSchedule to Products & BillItems
        await m.addColumn(products, products.drugSchedule as GeneratedColumn);
        await m.addColumn(billItems, billItems.drugSchedule as GeneratedColumn);
      }
      if (from < 26) {
        // Migration to version 26: Enhanced Sync Queue (Sync Engine 2.0)
        await m.addColumn(syncQueue, syncQueue.payloadHash as GeneratedColumn);
        await m.addColumn(
          syncQueue,
          syncQueue.dependencyGroup as GeneratedColumn,
        );
        await m.addColumn(syncQueue, syncQueue.ownerId as GeneratedColumn);

        // Backfill ownerId from userId (Best effort for pending items)
        await customStatement(
          'UPDATE sync_queue SET owner_id = user_id WHERE owner_id = "UNKNOWN"',
        );
      }
      if (from < 27) {
        // Migration to version 27: Pharmacy Compliance Upgrade
        await m.createTable(productBatches);
        await m.createTable(lockOverrideLogs);
        await m.addColumn(stockMovements, stockMovements.batchId);

        // Backfill batch info in PurchaseItems
        await m.addColumn(purchaseItems, purchaseItems.batchNumber);
        await m.addColumn(purchaseItems, purchaseItems.expiryDate);

        // Re-create stockMovements if needed for batchId, but addColumn is enough for SQLite
      }
      if (from < 28) {
        // Migration to version 28: Business Data Isolation & Inventory Rules
        await m.addColumn(bills, bills.businessId);
        await m.addColumn(shops, shops.allowNegativeStock);
      }
      if (from < 29) {
        // Migration to version 29: HIS Module (Patients, Visits)
        // Re-creating patients if not exists, though v29 says it did.
        // But we are adding refined Patients table now in v35 possibly replacing or extending?
        // The task implies we are adding NEW tables. If Patients existed in v29, we should check if we need to DROP and CREATE or just use it.
        // Since we defined `PatientEntity` in `tables.dart`, drift needs it.
        // Let's assume standard behavior: creation if not exists.
        await m.createTable(patients);
        await m.createTable(visits);
      }
      if (from < 30) {
        // Migration to version 30: Shortcut Panel
        await m.createTable(shortcutDefinitions);
        await m.createTable(userShortcuts);
      }
      if (from < 31) {
        // Migration to version 31: Manufacturing Module
        await m.createTable(billOfMaterials);
        await m.createTable(productionEntries);
      }
      if (from < 32) {
        // Migration to version 32: Recurring Billing
        await m.createTable(subscriptions);
      }
      if (from < 33) {
        await m.addColumn(customers, customers.linkStatus as GeneratedColumn);
      }
      if (from < 34) {
        // Migration to version 34: Customer Item Requests
        await m.createTable(customerItemRequests);
      }
      if (from < 35) {
        // Migration to version 35: Doctor / Clinic Module
        // Patients might have been created in v29, but let's ensure schema match or re-create if needed.
        // For safety in this environment, we'll try to create tables.
        // If they exist, we might need manual handling, but standard practice here is `createTable` which implies `IF NOT EXISTS` usually or we rely on Drift handling.
        // However, Drift's `createTable` throws if exists.
        // We'll proceed with creating the NEW tables.
        await m.createTable(doctorProfiles);
        await m.createTable(patientDoctorLinks);
        await m.createTable(appointments);
        await m.createTable(medicalRecords);
        await m.createTable(prescriptionItems);
        await m.createTable(labReports);
        // Patients, Prescriptions, Visits might already exist from v29/v24.
        // We should allow them to remain or safely update them.
        // For now, we assume they are compatible or this is a fresh setup for this module.
        // For now, we assume they are compatible or this is a fresh setup for this module.
      }
      if (from < 36) {
        // Migration to version 36: Garment Variants & Vegetable Broker
        await m.addColumn(products, products.groupId);
        await m.addColumn(products, products.variantAttributes);
        await m.createTable(farmers);
        await m.createTable(commissionLedger);
      }
      if (from < 37) {
        // Migration to version 37: Enhanced Staff Management (Petrol Pump)
        await m.createTable(staffNozzleAssignments);
        await m.createTable(staffSalesDetails);
        await m.createTable(staffCashSettlements);

        // Add columns to existing tables
        await m.addColumn(staffMembers, staffMembers.pumpId);
        await m.addColumn(staffAttendance, staffAttendance.method);
        await m.addColumn(bills, bills.attendantId);
      }
      if (from < 38) {
        // Migration to version 38: Petrol Pump Audit - Additional Tables
        await m.createTable(cashDeposits);
        await m.createTable(lubeStock);
        await m.createTable(densityRecords);
        await m.createTable(dayBook);

        // Add calibration fields to dispensers
        await m.addColumn(
          dispensers,
          dispensers.lastCalibrationDate as GeneratedColumn,
        );
        await m.addColumn(
          dispensers,
          dispensers.nextCalibrationDate as GeneratedColumn,
        );
        await m.addColumn(
          dispensers,
          dispensers.calibrationIntervalDays as GeneratedColumn,
        );
        await m.addColumn(
          dispensers,
          dispensers.calibrationCertificateNumber as GeneratedColumn,
        );
      }
      if (from < 39) {
        // ====================================================================
        // Migration to version 39: Offline License Activation
        // System_Columns (Req 8.1) + missing cloud-entity tables (Req 8.2).
        //
        // Purely additive: addColumn() for the four previously-missing
        // System_Columns on existing cloud-entity tables, and createTable()
        // for the cloud entities that had no table. No existing table
        // (including SyncQueue and LicenseCache) is dropped or redefined, so
        // all existing rows and column values are preserved (Req 8.7).
        // ====================================================================

        // --- System_Columns on existing cloud-entity tables (Req 8.1) ---
        // tenant_id, sync_status, server_id, local_version are added where
        // missing. The columns are nullable so the migration requires no
        // backfill and leaves legacy rows intact.
        await m.addColumn(bills, bills.tenantId as GeneratedColumn);
        await m.addColumn(bills, bills.syncStatus as GeneratedColumn);
        await m.addColumn(bills, bills.serverId as GeneratedColumn);
        await m.addColumn(bills, bills.localVersion as GeneratedColumn);

        await m.addColumn(billItems, billItems.tenantId as GeneratedColumn);
        await m.addColumn(billItems, billItems.syncStatus as GeneratedColumn);
        await m.addColumn(billItems, billItems.serverId as GeneratedColumn);
        await m.addColumn(billItems, billItems.localVersion as GeneratedColumn);

        await m.addColumn(customers, customers.tenantId as GeneratedColumn);
        await m.addColumn(customers, customers.syncStatus as GeneratedColumn);
        await m.addColumn(customers, customers.serverId as GeneratedColumn);
        await m.addColumn(customers, customers.localVersion as GeneratedColumn);

        await m.addColumn(products, products.tenantId as GeneratedColumn);
        await m.addColumn(products, products.syncStatus as GeneratedColumn);
        await m.addColumn(products, products.serverId as GeneratedColumn);
        await m.addColumn(products, products.localVersion as GeneratedColumn);

        await m.addColumn(payments, payments.tenantId as GeneratedColumn);
        await m.addColumn(payments, payments.syncStatus as GeneratedColumn);
        await m.addColumn(payments, payments.serverId as GeneratedColumn);
        await m.addColumn(payments, payments.localVersion as GeneratedColumn);

        await m.addColumn(vendors, vendors.tenantId as GeneratedColumn);
        await m.addColumn(vendors, vendors.syncStatus as GeneratedColumn);
        await m.addColumn(vendors, vendors.serverId as GeneratedColumn);
        await m.addColumn(vendors, vendors.localVersion as GeneratedColumn);

        await m.addColumn(
          purchaseOrders,
          purchaseOrders.tenantId as GeneratedColumn,
        );
        await m.addColumn(
          purchaseOrders,
          purchaseOrders.syncStatus as GeneratedColumn,
        );
        await m.addColumn(
          purchaseOrders,
          purchaseOrders.serverId as GeneratedColumn,
        );
        await m.addColumn(
          purchaseOrders,
          purchaseOrders.localVersion as GeneratedColumn,
        );

        await m.addColumn(
          purchaseItems,
          purchaseItems.tenantId as GeneratedColumn,
        );
        await m.addColumn(
          purchaseItems,
          purchaseItems.syncStatus as GeneratedColumn,
        );
        await m.addColumn(
          purchaseItems,
          purchaseItems.serverId as GeneratedColumn,
        );
        await m.addColumn(
          purchaseItems,
          purchaseItems.localVersion as GeneratedColumn,
        );

        await m.addColumn(
          stockMovements,
          stockMovements.tenantId as GeneratedColumn,
        );
        await m.addColumn(
          stockMovements,
          stockMovements.syncStatus as GeneratedColumn,
        );
        await m.addColumn(
          stockMovements,
          stockMovements.serverId as GeneratedColumn,
        );
        await m.addColumn(
          stockMovements,
          stockMovements.localVersion as GeneratedColumn,
        );

        await m.addColumn(users, users.tenantId as GeneratedColumn);
        await m.addColumn(users, users.syncStatus as GeneratedColumn);
        await m.addColumn(users, users.serverId as GeneratedColumn);
        await m.addColumn(users, users.localVersion as GeneratedColumn);

        await m.addColumn(
          userSessions,
          userSessions.tenantId as GeneratedColumn,
        );
        await m.addColumn(
          userSessions,
          userSessions.syncStatus as GeneratedColumn,
        );
        await m.addColumn(
          userSessions,
          userSessions.serverId as GeneratedColumn,
        );
        await m.addColumn(
          userSessions,
          userSessions.localVersion as GeneratedColumn,
        );

        // --- Missing cloud-entity tables (Req 8.2) ---
        await m.createTable(roles);
        await m.createTable(permissions);
        await m.createTable(categories);
        await m.createTable(units);
        await m.createTable(inventory);
        await m.createTable(businessSettings);
        await m.createTable(taxRates);
      }
      if (from < 40) {
        // ====================================================================
        // Migration to version 40: Offline License Activation indexes
        // (Requirements 8.5, 16.2).
        //
        // Define an index on tenant_id, sync_status and deleted_at for every
        // cloud-entity table that carries System_Columns. Purely additive:
        // creating indexes never drops/redefines a table or touches row data,
        // so all existing rows are preserved. CREATE INDEX IF NOT EXISTS keeps
        // the step idempotent even if a fresh install already created them in
        // onCreate.
        // ====================================================================
        await _createSystemColumnIndexes();
      }
      if (from < 41) {
        // ====================================================================
        // Migration to version 41: Accounting business isolation.
        //
        // Adds a nullable `business_id` column to the accounting tables
        // (journal_entries, accounting_periods, ledger_accounts). Previously
        // these tables were scoped only by user_id, so a user owning multiple
        // businesses would see cross-business Trial Balance / P&L / Balance
        // Sheet aggregates. The column is nullable so the migration is purely
        // additive: legacy rows keep NULL, no backfill is required, and the
        // generated Drift data classes keep businessId optional. The service
        // layer backfills new rows and the report queries filter on it when
        // present.
        // ====================================================================
        await m.addColumn(journalEntries, journalEntries.businessId);
        await m.addColumn(accountingPeriods, accountingPeriods.businessId);
        await m.addColumn(ledgerAccounts, ledgerAccounts.businessId);
      }
      if (from < 42) {
        // ====================================================================
        // Migration to version 42: Customer loyaltyPoints & Product book fields
        //
        // Adds loyaltyPoints (integer, default 0) to Customers, and nullable
        // text columns isbn, author, publisher to Products. Purely additive:
        // existing rows are unaffected (loyaltyPoints defaults to 0, text
        // columns default to NULL). Enables offline search for book-store
        // verticals and loyalty point tracking.
        // ====================================================================
        await m.addColumn(customers, customers.loyaltyPoints);
        await m.addColumn(products, products.isbn);
        await m.addColumn(products, products.author);
        await m.addColumn(products, products.publisher);
      }
      if (from < 43) {
        // ====================================================================
        // Migration to version 43: Phase 1 Mandi Remediation
        // (Requirements 3.1–3.6, 4.2)
        //
        // 1. Add sync-tracking columns (syncState, lastModifiedAt) to Farmers
        //    and CommissionLedger tables.
        // 2. Convert all monetary RealColumn values from rupee doubles to
        //    integer paise using round-half-away-from-zero:
        //      paise = CAST(ROUND(rupees * 100) AS INTEGER)
        //    SQLite's ROUND() uses banker's rounding for .5, but we use a
        //    manual formula for round-half-away-from-zero:
        //      CAST((ABS(val) * 100 + 0.5) AS INTEGER) * SIGN
        //    Null values map to null (CASE WHEN ... IS NULL THEN NULL).
        //
        // Atomic: entire migration runs in one transaction (Drift default).
        // If any statement fails, the transaction rolls back, data stays as
        // doubles, and schemaVersion does NOT advance to 43.
        //
        // Idempotency: guarded by `from < 43` — once the schema reaches 43,
        // this block is never re-entered.
        // ====================================================================

        // --- Step 1: Add sync-tracking columns ---
        await m.addColumn(farmers, farmers.syncState as GeneratedColumn);
        await m.addColumn(farmers, farmers.lastModifiedAt as GeneratedColumn);
        await m.addColumn(
          commissionLedger,
          commissionLedger.syncState as GeneratedColumn,
        );
        await m.addColumn(
          commissionLedger,
          commissionLedger.lastModifiedAt as GeneratedColumn,
        );

        // --- Step 2: Create new VegetableLots, MandiSettlements, RateHistory, Buyers tables ---
        await m.createTable(vegetableLots);
        await m.createTable(mandiSettlements);
        // RateHistory and Buyers don't have generated table accessors yet
        // (build_runner hasn't been re-run). Use raw DDL until regeneration.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS rate_history (
            id TEXT NOT NULL PRIMARY KEY,
            user_id TEXT NOT NULL,
            vegetable TEXT NOT NULL,
            rate_date INTEGER NOT NULL,
            min_rate INTEGER NOT NULL,
            max_rate INTEGER NOT NULL,
            avg_rate INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            UNIQUE (user_id, vegetable, rate_date)
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS buyers (
            id TEXT NOT NULL PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            credit_limit INTEGER NOT NULL,
            outstanding_dues INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        // --- Step 3: Convert Farmers monetary columns (rupee double → integer paise) ---
        // round-half-away-from-zero: sign(v) * floor(abs(v)*100 + 0.5)
        // For null: CASE WHEN col IS NULL THEN NULL ELSE ... END
        const farmersMoneyCols = [
          'total_sales',
          'total_commission_deducted',
          'total_expenses_deducted',
          'total_paid',
          'current_balance',
        ];
        for (final col in farmersMoneyCols) {
          await customStatement('''
            UPDATE farmers SET $col =
              CASE WHEN $col IS NULL THEN NULL
              ELSE CAST(
                CASE WHEN $col >= 0
                  THEN CAST(ABS($col) * 100.0 + 0.5 AS INTEGER)
                  ELSE -CAST(ABS($col) * 100.0 + 0.5 AS INTEGER)
                END
              AS INTEGER) END
          ''');
        }

        // --- Step 4: Convert CommissionLedger monetary columns ---
        const ledgerMoneyCols = [
          'sale_amount',
          'commission_amount',
          'labor_charges',
          'other_expenses',
          'net_payable_to_farmer',
        ];
        for (final col in ledgerMoneyCols) {
          await customStatement('''
            UPDATE commission_ledger SET $col =
              CASE WHEN $col IS NULL THEN NULL
              ELSE CAST(
                CASE WHEN $col >= 0
                  THEN CAST(ABS($col) * 100.0 + 0.5 AS INTEGER)
                  ELSE -CAST(ABS($col) * 100.0 + 0.5 AS INTEGER)
                END
              AS INTEGER) END
          ''');
        }
      }

      // ====================================================================
      // v44: Phase 2 — Add per-lot commission type column + make
      //      commission_rate nullable (was NOT NULL with default 0.0, now
      //      only populated for type='percentage').
      // ====================================================================
      if (from < 44) {
        // Add commission_type column (TEXT NOT NULL DEFAULT 'flat').
        // Existing rows get 'flat' — correct because prior code always stored
        // a computed flat amount derived from the % back-conversion.
        await customStatement('''
          ALTER TABLE commission_ledger
          ADD COLUMN commission_type TEXT NOT NULL DEFAULT 'flat'
        ''');

        // SQLite does not support ALTER COLUMN to make a column nullable.
        // The existing commission_rate column already allows negative/zero
        // values. For rows where commission_type = 'flat', commission_rate is
        // semantically ignored, so we leave the column as-is (still real with
        // default 0.0). New inserts will set it to null when type='flat' via
        // Drift's nullable annotation. Drift's generated code handles the
        // column as nullable from this version forward.
      }

      // ====================================================================
      // v45: Phase 2 — Add hamali_charges, weighing_charges, market_fee
      //      columns to commission_ledger (Requirements 6.1, 6.2).
      //
      // Previously only labor_charges and other_expenses existed. Now we
      // capture hamali, weighing, and market-fee as distinct integer paise
      // columns. Existing rows default to 0 (no deduction).
      // ====================================================================
      if (from < 45) {
        await customStatement('''
          ALTER TABLE commission_ledger
          ADD COLUMN hamali_charges INTEGER NOT NULL DEFAULT 0
        ''');
        await customStatement('''
          ALTER TABLE commission_ledger
          ADD COLUMN weighing_charges INTEGER NOT NULL DEFAULT 0
        ''');
        await customStatement('''
          ALTER TABLE commission_ledger
          ADD COLUMN market_fee INTEGER NOT NULL DEFAULT 0
        ''');
      }

      // ====================================================================
      // v46: Clinic task 4.4 — backfill legacy 'SYSTEM' owner attribution.
      //
      // Re-attributes EXISTING rows that the old clinic repos wrote with the
      // placeholder owner id 'SYSTEM' to the real authenticated owner:
      //   • patients.user_id == 'SYSTEM'                       → owner id
      //   • sync_queue rows (patients/appointments collections) attributed to
      //     'SYSTEM'                                           → owner id
      // The `appointments` table has NO owner column (scoped by doctorId/
      // patientId), so there is nothing to backfill there — its only 'SYSTEM'
      // attribution lived on the enqueued sync op, handled above.
      //
      // Rows already carrying a real owner id are left untouched (the UPDATEs
      // match `= 'SYSTEM'` exactly) — no data loss, explicit & versioned.
      //
      // SAFE WHEN OWNER UNAVAILABLE: at migration time a session may not be
      // restored yet. The shared backfill helper SKIPS (never fabricates an
      // owner, never re-buckets 'SYSTEM'); the beforeOpen deferred net retries
      // on a later open once a session exists.
      //
      // ⚠️ Multi-owner-on-one-device caveat (sign-off): all legacy 'SYSTEM'
      // rows are attributed to whichever owner is signed in when the backfill
      // runs. Correct for the common single-owner-per-device case; flagged.
      // ====================================================================
      if (from < 46) {
        final ownerId = _resolveBackfillOwnerId();
        final result = await backfillSystemOwnerRows(this, ownerId: ownerId);
        debugPrint('AppDatabase: v46 SYSTEM-owner backfill ${result.summary}');
      }

      // ====================================================================
      // v47 — PHI consent flag + access logging table (clinic task 5.3)
      //
      // 1. Add nullable `consent` column to `patients` — NULL = unconsented,
      //    so existing rows are preserved without data loss (Req 3.10).
      // 2. Create append-only `patient_access_logs` table for PHI access
      //    auditing (Req 2.11).
      // ====================================================================
      if (from < 47) {
        // Add consent column (nullable, so existing rows get NULL).
        await customStatement('''
          ALTER TABLE patients ADD COLUMN consent INTEGER
        ''');

        // Create the PHI access log table.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS patient_access_logs (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            patient_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            access_type TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            description TEXT
          )
        ''');

        // Indexes for efficient querying of access logs.
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_patient_access_log_patient_id
          ON patient_access_logs (patient_id)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_patient_access_log_user_id
          ON patient_access_logs (user_id)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_patient_access_log_timestamp
          ON patient_access_logs (timestamp)
        ''');

        debugPrint(
          'AppDatabase: v47 migration complete — consent column + '
          'patient_access_logs table created',
        );
      }

      // ====================================================================
      // v48: Appointment slot duration (clinic task 6.3)
      //
      // Adds a nullable INTEGER column `slot_duration_minutes` to the
      // `appointments` table. Existing rows get NULL (preserved); the
      // application layer defaults to 15 minutes when reading NULL. This
      // supports the double-booking guard which needs slot boundaries.
      // ====================================================================
      if (from < 48) {
        await customStatement('''
          ALTER TABLE patients ADD COLUMN slot_duration_minutes INTEGER
        ''');

        debugPrint(
          'AppDatabase: v48 migration complete — slot_duration_minutes '
          'column added to appointments',
        );
      }

      // ====================================================================
      // v49: clinic task 6.4 — UHID / MRN column (Req 2.19, 3.10)
      //
      // Adds a nullable TEXT column `uhid` to the `patients` table.
      // Existing rows get NULL (preserved — no data loss). The application
      // layer generates a human-readable MRN on patient create and backfills
      // existing NULL rows on-read or via a batch backfill in beforeOpen.
      // Format: "MRN-{YYYYMMDD}-{4-char-hex}" — short and clinic-friendly.
      // ====================================================================
      if (from < 49) {
        await customStatement('''
          ALTER TABLE patients ADD COLUMN uhid TEXT
        ''');

        // Backfill existing patients with NULL uhid — generate retroactive MRNs.
        // Uses the row's createdAt date + a hex suffix derived from the row id
        // to produce a unique, human-readable MRN for each existing patient.
        final existingPatients = await customSelect(
          "SELECT id, created_at FROM patients WHERE uhid IS NULL",
        ).get();

        for (final row in existingPatients) {
          final id = row.read<String>('id');
          // Derive a 4-char hex from the patient UUID for uniqueness.
          final hexSuffix = id
              .replaceAll('-', '')
              .substring(0, 4)
              .toUpperCase();
          final createdAtRaw = row.read<int>('created_at');
          final createdAt = DateTime.fromMillisecondsSinceEpoch(
            createdAtRaw * 1000,
          );
          final dateStr =
              '${createdAt.year}'
              '${createdAt.month.toString().padLeft(2, '0')}'
              '${createdAt.day.toString().padLeft(2, '0')}';
          final mrn = 'MRN-$dateStr-$hexSuffix';

          await customStatement("UPDATE patients SET uhid = ? WHERE id = ?", [
            mrn,
            id,
          ]);
        }

        debugPrint(
          'AppDatabase: v49 migration complete — uhid column added to '
          'patients; ${existingPatients.length} existing rows backfilled',
        );
      }

      // ====================================================================
      // v50: clinic task 9.1 — Date of Birth column (Req 2.30, 3.10)
      //
      // Adds a nullable INTEGER column `date_of_birth` to the `patients` table.
      // Drift stores DateTimeColumn as INTEGER (seconds since epoch).
      // Existing rows get NULL (preserved — no data loss). The application
      // derives current age from DOB when present, falling back to the static
      // `age` column for legacy patients without DOB.
      // ====================================================================
      if (from < 50) {
        await customStatement('''
          ALTER TABLE patients ADD COLUMN date_of_birth INTEGER
        ''');

        debugPrint(
          'AppDatabase: v50 migration complete — date_of_birth column added '
          'to patients (nullable, existing rows preserved with NULL)',
        );
      }

      // ====================================================================
      // v51: Phase 6 mobileShop — Second-hand intake fields on IMEISerials
      // (Requirements 9.4, 9.5, 9.6, 1.6)
      //
      // Adds three nullable columns to i_m_e_i_serials for second-hand device
      // intake: condition (TEXT), grade (TEXT), valuation_paise (INTEGER).
      // Purely additive: existing rows get NULL, no data loss. The 'demo'
      // enum value is a code-only change (status column is TEXT — no DDL
      // needed). Idempotent via the version guard.
      // ====================================================================
      if (from < 51) {
        await customStatement('''
          ALTER TABLE i_m_e_i_serials ADD COLUMN condition TEXT
        ''');
        await customStatement('''
          ALTER TABLE i_m_e_i_serials ADD COLUMN grade TEXT
        ''');
        await customStatement('''
          ALTER TABLE i_m_e_i_serials ADD COLUMN valuation_paise INTEGER
        ''');

        debugPrint(
          'AppDatabase: v51 migration complete — condition, grade, '
          'valuation_paise columns added to i_m_e_i_serials (nullable, '
          'existing rows preserved with NULL)',
        );
      }

      // ====================================================================
      // v52: Phase 5 School ERP — Offline cache tables (Requirement 8.1, 8.6)
      // ====================================================================
      // Adds three new tables: school_students_cache, school_fees_cache,
      // school_attendance_cache. Purely additive: no existing data affected.
      // Every row carries tenantId (non-nullable) for tenant isolation.
      // Currency columns are integer Paise. IDs follow the RID pattern.
      // Idempotent via the version guard.
      // ====================================================================
      if (from < 52) {
        // Using raw SQL because build_runner has not been re-run and the
        // generated table accessors (schoolStudentsCache, etc.) do not exist.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS school_students_cache (
            id TEXT NOT NULL PRIMARY KEY,
            tenant_id TEXT NOT NULL,
            name TEXT NOT NULL,
            class_section TEXT NOT NULL DEFAULT '',
            enrollment_date INTEGER,
            total_fees_paise INTEGER NOT NULL DEFAULT 0,
            total_paid_paise INTEGER NOT NULL DEFAULT 0,
            balance_paise INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'active',
            sync_version INTEGER NOT NULL DEFAULT 0,
            last_modified INTEGER
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS school_fees_cache (
            id TEXT NOT NULL PRIMARY KEY,
            tenant_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            invoice_id TEXT NOT NULL DEFAULT '',
            amount_paise INTEGER NOT NULL DEFAULT 0,
            paid_amount_paise INTEGER NOT NULL DEFAULT 0,
            balance_paise INTEGER NOT NULL DEFAULT 0,
            due_date INTEGER,
            status TEXT NOT NULL DEFAULT 'pending',
            sync_version INTEGER NOT NULL DEFAULT 0,
            last_modified INTEGER
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS school_attendance_cache (
            id TEXT NOT NULL PRIMARY KEY,
            tenant_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            date INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'absent', 'late')),
            marked_by TEXT NOT NULL DEFAULT '',
            sync_version INTEGER NOT NULL DEFAULT 0,
            last_modified INTEGER
          )
        ''');

        debugPrint(
          'AppDatabase: v52 migration complete — school_students_cache, '
          'school_fees_cache, school_attendance_cache tables created '
          '(Phase 5 schoolErp offline cache)',
        );
      }
    },
    beforeOpen: (details) async {
      // Enable foreign keys.
      await customStatement('PRAGMA foreign_keys = ON');

      // Offline License Activation — task 7.2 (Requirement 8.4):
      // Operate the Local_Store in write-ahead logging (WAL) mode. WAL allows
      // concurrent readers during a write and improves offline write latency.
      // Applied on every open (idempotent) so existing databases are upgraded
      // to WAL the next time they are opened. Guarded so a failure here (e.g.
      // an unsupported platform/VFS) never blocks database startup.
      try {
        await customStatement('PRAGMA journal_mode = WAL');
      } catch (e) {
        debugPrint('AppDatabase: could not enable WAL mode: $e');
      }

      // v46 deferred safety net (clinic task 4.4): if the legacy-'SYSTEM'
      // backfill could not run at migration time because no authenticated owner
      // was available yet, retry it here once a session exists. Guarded by a
      // cheap existence check (a no-op once the backfill has completed) and
      // wrapped so a failure NEVER blocks database startup. Skips silently when
      // the owner id is still unavailable.
      try {
        final ownerId = _resolveBackfillOwnerId();
        final resolved = ownerId?.trim() ?? '';
        if (resolved.isNotEmpty && resolved != kSystemOwnerSentinel) {
          if (await hasPendingSystemOwnerRows(this)) {
            final result = await backfillSystemOwnerRows(
              this,
              ownerId: resolved,
            );
            debugPrint(
              'AppDatabase: deferred SYSTEM-owner backfill ${result.summary}',
            );
          }
        }
      } catch (e) {
        debugPrint('AppDatabase: deferred SYSTEM-owner backfill skipped: $e');
      }

      debugPrint('AppDatabase: Opened (version: ${details.versionNow})');
    },
  );

  // ============================================================================
  // SYNC QUEUE OPERATIONS
  // ============================================================================

  // ============================================================================
  // SYNC QUEUE OPERATIONS (SyncQueueLocalOperations Implementation)
  // ============================================================================

  @override
  Future<void> insertSyncQueueItem(SyncQueueItem item) {
    return into(syncQueue).insert(
      SyncQueueCompanion(
        operationId: Value(item.operationId),
        operationType: Value(item.operationType.value),
        targetCollection: Value(item.targetCollection),
        documentId: Value(item.documentId),
        payload: Value(jsonEncode(item.payload)),
        status: Value(item.status.value),
        retryCount: Value(item.retryCount),
        lastError: Value(item.lastError),
        createdAt: Value(item.createdAt),
        lastAttemptAt: Value(item.lastAttemptAt),
        syncedAt: Value(item.syncedAt),
        priority: Value(item.priority),
        parentOperationId: Value(item.parentOperationId),
        stepNumber: Value(item.stepNumber),
        totalSteps: Value(item.totalSteps),
        userId: Value(item.userId),
        deviceId: Value(item.deviceId),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  @override
  Future<void> updateSyncQueueItem(SyncQueueItem item) {
    return (update(
      syncQueue,
    )..where((t) => t.operationId.equals(item.operationId))).write(
      SyncQueueCompanion(
        status: Value(item.status.value),
        retryCount: Value(item.retryCount),
        lastError: Value(item.lastError),
        lastAttemptAt: Value(item.lastAttemptAt),
        syncedAt: Value(item.syncedAt),
      ),
    );
  }

  @override
  Future<void> deleteSyncQueueItem(String operationId) {
    return (delete(
      syncQueue,
    )..where((t) => t.operationId.equals(operationId))).go();
  }

  @override
  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final rows =
        await (select(syncQueue)
              ..where(
                (t) => t.status.isIn(['PENDING', 'RETRY', 'IN_PROGRESS']),
              ) // Include IN_PROGRESS to resume
              ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
            .get();

    return rows.map((row) {
      return SyncQueueItem(
        operationId: row.operationId,
        operationType: SyncOperationType.fromString(row.operationType),
        targetCollection: row.targetCollection,
        documentId: row.documentId,
        payload: jsonDecode(row.payload),
        status: SyncStatus.fromString(row.status),
        retryCount: row.retryCount,
        lastError: row.lastError,
        createdAt: row.createdAt,
        lastAttemptAt: row.lastAttemptAt,
        syncedAt: row.syncedAt,
        priority: row.priority,
        parentOperationId: row.parentOperationId,
        stepNumber: row.stepNumber,
        totalSteps: row.totalSteps,
        userId: row.userId,
        deviceId: row.deviceId,
        payloadHash: row.payloadHash,
        dependencyGroup: row.dependencyGroup,
        ownerId: row.ownerId,
      );
    }).toList();
  }

  @override
  Future<void> markDocumentSynced(String collection, String documentId) async {
    // Mark the entity as synced in its respective table
    // This reduces the need for a switch statement if we are generic,
    // but Drift tables are strongly typed.
    switch (collection) {
      case 'bills':
        await (update(bills)..where((t) => t.id.equals(documentId))).write(
          const BillsCompanion(isSynced: Value(true)),
        );
        break;
      case 'customers':
        await (update(customers)..where((t) => t.id.equals(documentId))).write(
          const CustomersCompanion(isSynced: Value(true)),
        );
        break;
      case 'products':
        await (update(products)..where((t) => t.id.equals(documentId))).write(
          const ProductsCompanion(isSynced: Value(true)),
        );
        break;
      case 'payments':
        await (update(payments)..where((t) => t.id.equals(documentId))).write(
          const PaymentsCompanion(isSynced: Value(true)),
        );
        break;
      case 'expenses':
        await (update(expenses)..where((t) => t.id.equals(documentId))).write(
          const ExpensesCompanion(isSynced: Value(true)),
        );
        break;
      case 'receipts':
        await (update(receipts)..where((t) => t.id.equals(documentId))).write(
          const ReceiptsCompanion(isSynced: Value(true)),
        );
        break;
      case 'returnInwards':
        await (update(returnInwards)..where((t) => t.id.equals(documentId)))
            .write(const ReturnInwardsCompanion(isSynced: Value(true)));
        break;
      case 'proformas':
        await (update(proformas)..where((t) => t.id.equals(documentId))).write(
          const ProformasCompanion(isSynced: Value(true)),
        );
        break;
      case 'bookings':
        await (update(bookings)..where((t) => t.id.equals(documentId))).write(
          const BookingsCompanion(isSynced: Value(true)),
        );
        break;
      case 'dispatches':
        await (update(dispatches)..where((t) => t.id.equals(documentId))).write(
          const DispatchesCompanion(isSynced: Value(true)),
        );
        break;
      // Add other tables as needed
    }
  }

  @override
  Future<void> moveToDeadLetter(SyncQueueItem item, String error) async {
    await transaction(() async {
      // 1. Insert into Dead Letter Queue
      await into(deadLetterQueue).insert(
        DeadLetterQueueCompanion.insert(
          id: const Uuid().v4(),
          originalOperationId: item.operationId,
          userId: item.userId,
          operationType: item.operationType.value,
          targetCollection: item.targetCollection,
          documentId: item.documentId,
          payload: jsonEncode(item.payload),
          failureReason: error,
          totalAttempts: item.retryCount,
          firstAttemptAt: item.createdAt,
          lastAttemptAt: DateTime.now(),
          movedToDeadLetterAt: DateTime.now(),
        ),
      );

      // 2. Remove from active sync queue
      await deleteSyncQueueItem(item.operationId);
    });
  }

  @override
  Future<int> getDeadLetterCount() {
    return select(deadLetterQueue).get().then((l) => l.length);
  }

  @override
  Future<void> updateLocalFromServer({
    required String collection,
    required String documentId,
    required Map<String, dynamic> serverData,
  }) async {
    switch (collection) {
      case 'bills':
        await updateBillFromServer(documentId, serverData);
        break;
      case 'customers':
        await updateCustomerFromServer(documentId, serverData);
        break;
      case 'products':
        await updateProductFromServer(documentId, serverData);
        break;
      // Add others as needed
    }
  }

  // ============================================================================
  // LEGACY HELPER METHODS (Can be deprecated later)
  // ============================================================================
  // Kept for backward compatibility if needed during migration, or aliases.

  Future<void> insertSyncQueueEntry(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateSyncQueueEntry(SyncQueueEntry entry) {
    return (update(
      syncQueue,
    )..where((t) => t.operationId.equals(entry.operationId))).write(
      SyncQueueCompanion(
        status: Value(entry.status),
        retryCount: Value(entry.retryCount),
        lastError: Value(entry.lastError),
        lastAttemptAt: Value(entry.lastAttemptAt),
        syncedAt: Value(entry.syncedAt),
      ),
    );
  }

  Future<List<SyncQueueEntry>> getPendingSyncEntries() {
    return (select(syncQueue)
          ..where((t) => t.status.isIn(['PENDING', 'RETRY']))
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .get();
  }

  Future<void> deleteSyncQueueEntry(String operationId) {
    return (delete(
      syncQueue,
    )..where((t) => t.operationId.equals(operationId))).go();
  }

  Stream<List<SyncQueueEntry>> watchPendingSyncEntries() {
    return (select(syncQueue)
          ..where((t) => t.status.isIn(['PENDING', 'RETRY', 'IN_PROGRESS']))
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .watch();
  }

  // ============================================================================
  // BILLS OPERATIONS
  // ============================================================================

  Future<void> insertBill(BillsCompanion bill) {
    return into(bills).insert(bill, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateBill(BillEntity bill) {
    return (update(bills)..where((t) => t.id.equals(bill.id))).write(
      BillsCompanion(
        customerName: Value(bill.customerName),
        subtotal: Value(bill.subtotal),
        taxAmount: Value(bill.taxAmount),
        grandTotal: Value(bill.grandTotal),
        paidAmount: Value(bill.paidAmount),
        status: Value(bill.status),
        paymentMode: Value(bill.paymentMode),
        notes: Value(bill.notes),
        itemsJson: Value(bill.itemsJson),
        updatedAt: Value(DateTime.now()),
        isSynced: Value(bill.isSynced),
        version: Value(bill.version + 1),
      ),
    );
  }

  Future<BillEntity?> getBillById(String id) {
    return (select(bills)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<BillEntity>> getAllBills(String userId) {
    return (select(bills)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Stream<List<BillEntity>> watchAllBills(String userId) {
    return (select(bills)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<void> softDeleteBill(String id) {
    return (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markBillSynced(String id, String? operationId) {
    return (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        isSynced: const Value(true),
        syncOperationId: Value(operationId),
      ),
    );
  }

  // ============================================================================
  // KV STORE OPERATIONS
  // ============================================================================

  Future<String?> getKv(String key) async {
    final row = await (select(
      kvStore,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> upsertKv(String key, String value) async {
    await into(kvStore).insert(
      KvStoreCompanion(key: Value(key), value: Value(value)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteKv(String key) async {
    await (delete(kvStore)..where((t) => t.key.equals(key))).go();
  }

  Future<List<String>> kvByPrefix(String prefix) async {
    final rows = await (select(
      kvStore,
    )..where((t) => t.key.like('$prefix%'))).get();
    return rows.map((r) => r.value).toList();
  }

  // ============================================================================
  // CUSTOMERS OPERATIONS
  // ============================================================================

  Future<void> insertCustomer(CustomersCompanion customer) {
    return into(customers).insert(customer, mode: InsertMode.insertOrReplace);
  }

  Future<CustomerEntity?> getCustomerById(String id) {
    return (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<CustomerEntity>> getAllCustomers(String userId) {
    return (select(customers)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.isActive.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Stream<List<CustomerEntity>> watchAllCustomers(String userId) {
    return (select(customers)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.isActive.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> markCustomerSynced(String id, String? operationId) {
    return (update(customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        isSynced: const Value(true),
        syncOperationId: Value(operationId),
      ),
    );
  }

  /// Soft-delete a customer: sets isActive=false and deletedAt timestamp.
  /// Historical bills and payments remain intact.
  Future<void> softDeleteCustomer(String id) {
    return (update(customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        isActive: const Value(false),
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  // ============================================================================
  // PRODUCTS OPERATIONS
  // ============================================================================

  Future<void> insertProduct(ProductsCompanion product) {
    return into(products).insert(product, mode: InsertMode.insertOrReplace);
  }

  Future<ProductEntity?> getProductById(String id) {
    return (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<ProductEntity>> getAllProducts(String userId) {
    return (select(products)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.isActive.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Stream<List<ProductEntity>> watchAllProducts(String userId) {
    return (select(products)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.isActive.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<ProductEntity>> getLowStockProducts(String userId) {
    return (select(products)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.isActive.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.stockQuantity)]))
        .get()
        .then(
          (list) => list
              .where((p) => p.stockQuantity <= p.lowStockThreshold)
              .toList(),
        );
  }

  Future<List<ProductEntity>> getDeadStockProducts(
    String userId,
    DateTime cutoffDate,
  ) async {
    // 1. Get all active products with stock > 0 created before cutoff
    final candidateProducts =
        await (select(products)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.isActive.equals(true) &
                  t.stockQuantity.isBiggerThanValue(0) &
                  t.createdAt.isSmallerThanValue(cutoffDate),
            ))
            .get();

    if (candidateProducts.isEmpty) return [];

    // 2. Find products sold AFTER the cutoff date
    // We strictly link to bills to ensure we look at valid sales for this user
    final query =
        select(
          billItems,
        ).join([innerJoin(bills, bills.id.equalsExp(billItems.billId))])..where(
          bills.userId.equals(userId) &
              bills.createdAt.isBiggerOrEqualValue(cutoffDate) &
              bills.status.isNotIn(['DRAFT', 'CANCELLED']),
        );

    final activeProductIds = await query
        .map((row) => row.readTable(billItems).productId)
        .get();
    final activeIdsSet = activeProductIds.toSet();

    // 3. Filter candidates: Keep those NOT in the active set
    return candidateProducts
        .where((p) => !activeIdsSet.contains(p.id))
        .toList();
  }

  /// Get sales history for velocity calculation
  /// Returns Map&lt;ProductId, TotalQuantitySold&gt;
  Future<Map<String, double>> getProductSalesHistory(
    String userId,
    DateTime cutoffDate,
  ) async {
    final query =
        select(
          billItems,
        ).join([innerJoin(bills, bills.id.equalsExp(billItems.billId))])..where(
          bills.userId.equals(userId) &
              bills.createdAt.isBiggerOrEqualValue(cutoffDate) &
              bills.status.isNotIn(['DRAFT', 'CANCELLED']),
        );

    final rows = await query.get();

    final usageMap = <String, double>{};

    for (final row in rows) {
      final item = row.readTable(billItems);
      // Ensure we handle potential nulls, though quantity should be non-null
      final qty = item.quantity;
      final pid = item.productId;

      if (pid != null) {
        usageMap[pid] = (usageMap[pid] ?? 0) + qty;
      }
    }

    return usageMap;
  }

  // ============================================================================
  // PAYMENTS OPERATIONS
  // ============================================================================

  Future<void> insertPayment(PaymentsCompanion payment) {
    return into(payments).insert(payment, mode: InsertMode.insertOrReplace);
  }

  Future<List<PaymentEntity>> getPaymentsForBill(String billId) {
    return (select(payments)
          ..where((t) => t.billId.equals(billId))
          ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
        .get();
  }

  Future<List<PaymentEntity>> getAllPayments(
    String userId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var query = select(payments)..where((t) => t.userId.equals(userId));
    if (fromDate != null) {
      query = query..where((t) => t.paymentDate.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query = query..where((t) => t.paymentDate.isSmallerOrEqualValue(toDate));
    }
    return (query..orderBy([(t) => OrderingTerm.desc(t.paymentDate)])).get();
  }

  // ============================================================================
  // EXPENSES OPERATIONS
  // ============================================================================

  Future<void> insertExpense(ExpensesCompanion expense) {
    return into(expenses).insert(expense, mode: InsertMode.insertOrReplace);
  }

  Future<List<ExpenseEntity>> getAllExpenses(
    String userId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var query = select(expenses)..where((t) => t.userId.equals(userId));
    if (fromDate != null) {
      query = query..where((t) => t.expenseDate.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query = query..where((t) => t.expenseDate.isSmallerOrEqualValue(toDate));
    }
    return (query..orderBy([(t) => OrderingTerm.desc(t.expenseDate)])).get();
  }

  // ============================================================================
  // DEAD LETTER QUEUE OPERATIONS
  // ============================================================================

  Future<void> insertDeadLetter(DeadLetterQueueCompanion entry) {
    return into(deadLetterQueue).insert(entry);
  }

  Future<List<DeadLetterEntity>> getUnresolvedDeadLetters(String userId) {
    return (select(deadLetterQueue)
          ..where((t) => t.userId.equals(userId) & t.isResolved.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.movedToDeadLetterAt)]))
        .get();
  }

  Future<void> resolveDeadLetter(String id, String notes) {
    return (update(deadLetterQueue)..where((t) => t.id.equals(id))).write(
      DeadLetterQueueCompanion(
        isResolved: const Value(true),
        resolutionNotes: Value(notes),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  // ============================================================================
  // AUDIT LOG OPERATIONS
  // ============================================================================

  Future<void> insertAuditLog({
    required String userId,
    required String targetTableName,
    required String recordId,
    required String action,
    String? oldValueJson,
    String? newValueJson,
    String? deviceId,
    String? appVersion,
  }) {
    return into(auditLogs).insert(
      AuditLogsCompanion.insert(
        userId: userId,
        targetTableName: targetTableName,
        recordId: recordId,
        action: action,
        oldValueJson: Value(oldValueJson),
        newValueJson: Value(newValueJson),
        timestamp: DateTime.now(),
        deviceId: Value(deviceId),
        appVersion: Value(appVersion),
      ),
    );
  }

  // ============================================================================
  // ANALYTICS QUERIES
  // ============================================================================

  Future<Map<String, dynamic>> getDashboardStats(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month, 1);

    // Today's sales
    final todayBills =
        await (select(bills)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.createdAt.isBiggerOrEqualValue(today) &
                  t.status.isNotIn(['DRAFT', 'CANCELLED']),
            ))
            .get();
    final todaySales = todayBills.fold<double>(
      0,
      (sum, b) => sum + b.grandTotal,
    );
    final todayCollections = todayBills.fold<double>(
      0,
      (sum, b) => sum + b.paidAmount,
    );

    // Monthly sales
    final monthBills =
        await (select(bills)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.createdAt.isBiggerOrEqualValue(thisMonth) &
                  t.status.isNotIn(['DRAFT', 'CANCELLED']),
            ))
            .get();
    final monthlySales = monthBills.fold<double>(
      0,
      (sum, b) => sum + b.grandTotal,
    );
    final monthlyCollections = monthBills.fold<double>(
      0,
      (sum, b) => sum + b.paidAmount,
    );

    // Total dues
    final allBills =
        await (select(bills)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.status.isNotIn(['DRAFT', 'CANCELLED', 'PAID']),
            ))
            .get();
    final totalDues = allBills.fold<double>(
      0,
      (sum, b) => sum + (b.grandTotal - b.paidAmount),
    );

    // Customer count
    final customerCount =
        await (select(customers)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.isActive.equals(true),
            ))
            .get()
            .then((list) => list.length);

    // Low stock count
    final lowStockProducts = await getLowStockProducts(userId);

    // Pending sync count
    final pendingSync = await getPendingSyncEntries().then(
      (list) => list.length,
    );

    // Monthly purchases
    final monthPurchases =
        await (select(purchaseOrders)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.purchaseDate.isBiggerOrEqualValue(thisMonth) &
                  t.status.isNotIn(['CANCELLED']),
            ))
            .get();
    final monthlyPurchaseAmount = monthPurchases.fold<double>(
      0,
      (sum, p) => sum + p.totalAmount,
    );

    return {
      'todaySales': todaySales,
      'todayCollections': todayCollections,
      'todayBillCount': todayBills.length,
      'monthlySales': monthlySales,
      'monthlyCollections': monthlyCollections,
      'monthlyPurchaseAmount': monthlyPurchaseAmount, // ADDED
      'monthlyBillCount': monthBills.length,
      'totalDues': totalDues,
      'customerCount': customerCount,
      'lowStockCount': lowStockProducts.length,
      'pendingSyncCount': pendingSync,
    };
  }

  /// Calculate real profit for today (Sales - COGS)
  /// Uses current Product Cost Price as approximation for COGS
  Future<double> getTodayProfit(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Join Bills, BillItems, and Products to calc profit
    // Profit = Sum(Item.qty * (Item.unitPrice - Product.costPrice))

    final query =
        select(billItems).join([
          innerJoin(bills, bills.id.equalsExp(billItems.billId)),
          innerJoin(products, products.id.equalsExp(billItems.productId)),
        ])..where(
          bills.userId.equals(userId) &
              bills.createdAt.isBiggerOrEqualValue(today) &
              bills.status.isNotIn(['DRAFT', 'CANCELLED']),
        );

    final rows = await query.map((row) {
      final item = row.readTable(billItems);
      final product = row.readTable(products);

      final qty = item.quantity;
      final sellPrice = item.unitPrice; // Or totalAmount/qty
      final cost = product.costPrice;

      return qty * (sellPrice - cost);
    }).get();

    // Sum up the profits
    return rows.fold<double>(0.0, (sum, profit) => sum + profit);
  }

  /// Get count of items sold today
  /// Returns total quantity of all items in today's bills
  Future<int?> getTodayItemsSoldCount(String userId, DateTime today) async {
    final query =
        select(
          billItems,
        ).join([innerJoin(bills, bills.id.equalsExp(billItems.billId))])..where(
          bills.userId.equals(userId) &
              bills.createdAt.isBiggerOrEqualValue(today) &
              bills.status.isNotIn(['DRAFT', 'CANCELLED']),
        );

    final rows = await query.map((row) {
      final item = row.readTable(billItems);
      return item.quantity.toInt();
    }).get();
    return rows.fold<int>(0, (sum, qty) => sum + qty);
  }

  // ============================================================================
  // HEALTH CHECK
  // ============================================================================

  Future<Map<String, dynamic>> performHealthCheck(String userId) async {
    try {
      // Count records
      final billCount = await (select(
        bills,
      )..where((t) => t.userId.equals(userId))).get().then((l) => l.length);
      final customerCount = await (select(
        customers,
      )..where((t) => t.userId.equals(userId))).get().then((l) => l.length);
      final productCount = await (select(
        products,
      )..where((t) => t.userId.equals(userId))).get().then((l) => l.length);
      final pendingSync = await getPendingSyncEntries().then((l) => l.length);
      final deadLetters = await getUnresolvedDeadLetters(
        userId,
      ).then((l) => l.length);

      return {
        'healthy': deadLetters == 0 && pendingSync < 100,
        'billCount': billCount,
        'customerCount': customerCount,
        'productCount': productCount,
        'pendingSyncCount': pendingSync,
        'deadLetterCount': deadLetters,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'healthy': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // ============================================================================
  // DEAD LETTER QUEUE OPERATIONS
  // ============================================================================

  /// Get all dead letter items (for sync health metrics)
  Future<List<DeadLetterEntity>> getDeadLetterItems() {
    return select(deadLetterQueue).get();
  }

  // ============================================================================
  // SERVER RECONCILIATION (for conflict resolution)
  // ============================================================================

  /// Update a bill record with server data after conflict resolution
  Future<void> updateBillFromServer(
    String id,
    Map<String, dynamic> serverData,
  ) async {
    await (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        customerName: Value(serverData['customerName'] ?? ''),
        subtotal: Value((serverData['subtotal'] as num?)?.toDouble() ?? 0),
        taxAmount: Value((serverData['taxAmount'] as num?)?.toDouble() ?? 0),
        grandTotal: Value((serverData['grandTotal'] as num?)?.toDouble() ?? 0),
        paidAmount: Value((serverData['paidAmount'] as num?)?.toDouble() ?? 0),
        status: Value(serverData['status'] ?? 'PENDING'),
        paymentMode: Value(serverData['paymentMode'] ?? 'CASH'),
        isSynced: const Value(true),
        version: Value((serverData['_version'] as int?) ?? 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
    debugPrint('AppDatabase: Reconciled bill $id with server');
  }

  /// Update a customer record with server data after conflict resolution
  Future<void> updateCustomerFromServer(
    String id,
    Map<String, dynamic> serverData,
  ) async {
    await (update(customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        name: Value(serverData['name'] ?? ''),
        phone: Value(serverData['phone']),
        email: Value(serverData['email']),
        address: Value(serverData['address']),
        gstin: Value(serverData['gstin']),
        totalBilled: Value(
          (serverData['totalBilled'] as num?)?.toDouble() ?? 0,
        ),
        totalPaid: Value((serverData['totalPaid'] as num?)?.toDouble() ?? 0),
        totalDues: Value((serverData['totalDues'] as num?)?.toDouble() ?? 0),
        isSynced: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    debugPrint('AppDatabase: Reconciled customer $id with server');
  }

  /// Update a product record with server data after conflict resolution
  Future<void> updateProductFromServer(
    String id,
    Map<String, dynamic> serverData,
  ) async {
    await (update(products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        name: Value(serverData['name'] ?? ''),
        sku: Value(serverData['sku']),
        category: Value(serverData['category']),
        sellingPrice: Value((serverData['price'] as num?)?.toDouble() ?? 0),
        costPrice: Value((serverData['costPrice'] as num?)?.toDouble() ?? 0),
        stockQuantity: Value((serverData['quantity'] as num?)?.toDouble() ?? 0),
        unit: Value(serverData['unit'] ?? 'pcs'),
        lowStockThreshold: Value(
          (serverData['lowStockThreshold'] as num?)?.toDouble() ?? 10,
        ),
        isSynced: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    debugPrint('AppDatabase: Reconciled product $id with server');
  }
}

// ============================================================================
// DATABASE CONNECTION
// ============================================================================

QueryExecutor _openConnection() {
  return openConnection();
}
