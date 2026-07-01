
// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.
// ============================================================================
// SYNC TABLE REGISTRY
// ============================================================================
// Central registry mapping local Drift/SQLite tables to remote PostgreSQL
// tables. Used by RestSyncEngine to know which tables to push/pull and how
// to convert between local and remote column names.
// ============================================================================

/// Configuration for a single syncable table.
class SyncTableConfig {
  /// Local Drift table name (snake_case, matching SyncQueue.targetCollection).
  final String localTableName;

  /// Remote PostgreSQL table name.
  final String remoteTableName;

  /// Primary key column name (usually 'id').
  final String primaryKey;

  /// Whether sync is currently enabled for this table.
  final bool syncEnabled;

  /// Priority (lower = synced first). Bills/Customers should be high priority.
  final int priority;

  /// Business types that use this table. Empty = all business types.
  final Set<String> businessTypes;

  const SyncTableConfig({
    required this.localTableName,
    required this.remoteTableName,
    this.primaryKey = 'id',
    this.syncEnabled = true,
    this.priority = 50,
    this.businessTypes = const {},
  });
}

/// Central registry of all syncable tables in the DukanX system.
///
/// This is the single source of truth for which tables participate in
/// cloud sync, their mapping between local and remote names, and their
/// sync priority. When a new table needs to sync, add it here.
class SyncTableRegistry {
  SyncTableRegistry._();

  /// All syncable tables, sorted by priority (low = first).
  static final List<SyncTableConfig> allTables = List.unmodifiable([
    // ── Core Tables (All Business Types) ────────────────────────────────
    const SyncTableConfig(
      localTableName: 'customers',
      remoteTableName: 'customers',
      priority: 10,
    ),
    const SyncTableConfig(
      localTableName: 'products',
      remoteTableName: 'inventory',
      priority: 10,
    ),
    const SyncTableConfig(
      localTableName: 'bills',
      remoteTableName: 'transactions',
      priority: 15,
    ),
    const SyncTableConfig(
      localTableName: 'bill_items',
      remoteTableName: 'transaction_items',
      priority: 16,
    ),
    const SyncTableConfig(
      localTableName: 'payments',
      remoteTableName: 'payments',
      priority: 20,
    ),
    const SyncTableConfig(
      localTableName: 'expenses',
      remoteTableName: 'expenses',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'vendors',
      remoteTableName: 'vendors',
      priority: 15,
    ),
    const SyncTableConfig(
      localTableName: 'purchase_orders',
      remoteTableName: 'purchase_orders',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'purchase_items',
      remoteTableName: 'purchase_items',
      priority: 26,
    ),
    const SyncTableConfig(
      localTableName: 'book_returns',
      remoteTableName: 'book_returns',
      priority: 30,
      businessTypes: {'bookStore'},
    ),
    const SyncTableConfig(
      localTableName: 'delivery_challans',
      remoteTableName: 'delivery_challans',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'stock_movements',
      remoteTableName: 'stock_movements',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'product_batches',
      remoteTableName: 'product_batches',
      priority: 25,
      businessTypes: {'pharmacy'},
    ),

    // ── Financial Tables ─────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'bank_accounts',
      remoteTableName: 'bank_accounts',
      priority: 20,
    ),
    const SyncTableConfig(
      localTableName: 'bank_transactions',
      remoteTableName: 'bank_transactions',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'journal_entries',
      remoteTableName: 'journal_entries',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'ledger_accounts',
      remoteTableName: 'ledger_accounts',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'accounting_periods',
      remoteTableName: 'accounting_periods',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'day_book',
      remoteTableName: 'day_book',
      priority: 35,
    ),
    const SyncTableConfig(
      localTableName: 'invoice_counters',
      remoteTableName: 'invoice_counters',
      priority: 5, // CRITICAL: highest priority to prevent duplicate invoices
    ),

    // ── Customer & Linking Tables ────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'customer_profiles',
      remoteTableName: 'customer_profiles',
      priority: 20,
    ),
    const SyncTableConfig(
      localTableName: 'customer_ledger',
      remoteTableName: 'customer_ledger',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'udhar_people',
      remoteTableName: 'udhar_people',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'udhar_transactions',
      remoteTableName: 'udhar_transactions',
      priority: 30,
    ),

    // ── GST / Tax ────────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'gst_settings',
      remoteTableName: 'gst_settings',
      priority: 20,
    ),
    const SyncTableConfig(
      localTableName: 'gst_invoice_details',
      remoteTableName: 'gst_invoice_details',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'e_invoices',
      remoteTableName: 'e_invoices',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'e_way_bills',
      remoteTableName: 'e_way_bills',
      priority: 30,
    ),

    // ── Staff / HR ───────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'staff_members',
      remoteTableName: 'staff_members',
      priority: 20,
    ),
    const SyncTableConfig(
      localTableName: 'staff_attendance',
      remoteTableName: 'staff_attendance',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'salary_records',
      remoteTableName: 'salary_records',
      priority: 35,
    ),

    // ── Reminder / Period ────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'reminder_settings',
      remoteTableName: 'reminder_settings',
      priority: 35,
    ),
    const SyncTableConfig(
      localTableName: 'period_locks',
      remoteTableName: 'period_locks',
      priority: 30,
    ),

    // ── Marketing ────────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'marketing_campaigns',
      remoteTableName: 'marketing_campaigns',
      priority: 40,
    ),
    const SyncTableConfig(
      localTableName: 'message_templates',
      remoteTableName: 'message_templates',
      priority: 40,
    ),

    // ── Security ─────────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'security_settings_table',
      remoteTableName: 'security_settings',
      priority: 15,
    ),
    const SyncTableConfig(
      localTableName: 'cash_closings',
      remoteTableName: 'cash_closings',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'user_sessions',
      remoteTableName: 'user_sessions',
      priority: 15,
    ),

    // ── Petrol Pump ──────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'shifts',
      remoteTableName: 'shifts',
      priority: 15,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'dispensers',
      remoteTableName: 'dispensers',
      priority: 20,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'nozzles',
      remoteTableName: 'nozzles',
      priority: 20,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'tanks',
      remoteTableName: 'fuel_tanks',
      priority: 20,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'staff_nozzle_assignments',
      remoteTableName: 'staff_nozzle_assignments',
      priority: 25,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'staff_sales_details',
      remoteTableName: 'staff_sales_details',
      priority: 30,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'staff_cash_settlements',
      remoteTableName: 'staff_cash_settlements',
      priority: 30,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'cash_deposits',
      remoteTableName: 'cash_deposits',
      priority: 30,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'lube_stock',
      remoteTableName: 'lube_stock',
      priority: 30,
      businessTypes: {'petrolPump'},
    ),
    const SyncTableConfig(
      localTableName: 'density_records',
      remoteTableName: 'density_records',
      priority: 35,
      businessTypes: {'petrolPump'},
    ),

    // ── Restaurant / Hotel ───────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'food_categories',
      remoteTableName: 'food_categories',
      priority: 15,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'food_menu_items',
      remoteTableName: 'food_menu_items',
      priority: 20,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'food_item_variations',
      remoteTableName: 'food_item_variations',
      priority: 25,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'food_addons',
      remoteTableName: 'food_addons',
      priority: 25,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'food_item_addon_links',
      remoteTableName: 'food_item_addon_links',
      priority: 26,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'restaurant_tables',
      remoteTableName: 'restaurant_tables',
      priority: 20,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'restaurant_floors',
      remoteTableName: 'restaurant_floors',
      priority: 20,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'food_orders',
      remoteTableName: 'food_orders',
      priority: 15,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'food_order_items',
      remoteTableName: 'food_order_items',
      priority: 16,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'restaurant_bills',
      remoteTableName: 'restaurant_bills',
      priority: 15,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'restaurant_kots',
      remoteTableName: 'restaurant_kots',
      priority: 20,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'restaurant_inventory_items',
      remoteTableName: 'restaurant_inventory_items',
      priority: 25,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'item_recipes',
      remoteTableName: 'item_recipes',
      priority: 30,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'restaurant_loyalty_transactions',
      remoteTableName: 'restaurant_loyalty_transactions',
      priority: 35,
      businessTypes: {'restaurant'},
    ),
    const SyncTableConfig(
      localTableName: 'restaurant_bill_splits',
      remoteTableName: 'restaurant_bill_splits',
      priority: 30,
      businessTypes: {'restaurant'},
    ),

    // ── Mobile / Computer / Electronics ──────────────────────────────────
    const SyncTableConfig(
      localTableName: 'i_m_e_i_serials',
      remoteTableName: 'imei_serials',
      priority: 20,
      businessTypes: {'electronics', 'mobileShop', 'computerShop'},
    ),
    const SyncTableConfig(
      localTableName: 'service_jobs',
      remoteTableName: 'service_jobs',
      priority: 15,
      businessTypes: {'electronics', 'mobileShop', 'computerShop', 'service'},
    ),
    const SyncTableConfig(
      localTableName: 'service_job_parts',
      remoteTableName: 'service_job_parts',
      priority: 25,
      businessTypes: {'electronics', 'mobileShop', 'computerShop', 'service'},
    ),
    const SyncTableConfig(
      localTableName: 'service_job_status_history',
      remoteTableName: 'service_job_status_history',
      priority: 30,
      businessTypes: {'electronics', 'mobileShop', 'computerShop', 'service'},
    ),
    const SyncTableConfig(
      localTableName: 'product_variants',
      remoteTableName: 'product_variants',
      priority: 25,
      businessTypes: {'electronics', 'mobileShop', 'computerShop'},
    ),
    const SyncTableConfig(
      localTableName: 'exchanges',
      remoteTableName: 'exchanges',
      priority: 30,
      businessTypes: {'electronics', 'mobileShop', 'computerShop'},
    ),

    // ── Clinic / Doctor ──────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'patients',
      remoteTableName: 'patients',
      priority: 15,
      businessTypes: {'clinic', 'pharmacy'},
    ),
    const SyncTableConfig(
      localTableName: 'visits',
      remoteTableName: 'visits',
      priority: 20,
      businessTypes: {'clinic'},
    ),
    const SyncTableConfig(
      localTableName: 'prescriptions',
      remoteTableName: 'prescriptions',
      priority: 20,
      businessTypes: {'clinic', 'pharmacy'},
    ),
    const SyncTableConfig(
      localTableName: 'doctor_profiles',
      remoteTableName: 'doctor_profiles',
      priority: 15,
      businessTypes: {'clinic'},
    ),
    const SyncTableConfig(
      localTableName: 'patient_doctor_links',
      remoteTableName: 'patient_doctor_links',
      priority: 20,
      businessTypes: {'clinic'},
    ),
    const SyncTableConfig(
      localTableName: 'appointments',
      remoteTableName: 'appointments',
      priority: 15,
      businessTypes: {'clinic'},
    ),
    const SyncTableConfig(
      localTableName: 'prescription_items',
      remoteTableName: 'prescription_items',
      priority: 25,
      businessTypes: {'clinic', 'pharmacy'},
    ),
    const SyncTableConfig(
      localTableName: 'medical_records',
      remoteTableName: 'medical_records',
      priority: 25,
      businessTypes: {'clinic'},
    ),
    const SyncTableConfig(
      localTableName: 'lab_reports',
      remoteTableName: 'lab_reports',
      priority: 30,
      businessTypes: {'clinic'},
    ),
    const SyncTableConfig(
      localTableName: 'medical_templates',
      remoteTableName: 'medical_templates',
      priority: 30,
      businessTypes: {'clinic'},
    ),

    // ── Vegetable Broker (Mandi) ─────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'farmers',
      remoteTableName: 'farmers',
      priority: 15,
      businessTypes: {'vegetablesBroker'},
    ),
    const SyncTableConfig(
      localTableName: 'commission_ledger',
      remoteTableName: 'commission_ledger',
      priority: 25,
      businessTypes: {'vegetablesBroker'},
    ),

    // ── Manufacturing ────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'bill_of_materials',
      remoteTableName: 'bill_of_materials',
      priority: 25,
    ),
    const SyncTableConfig(
      localTableName: 'production_entries',
      remoteTableName: 'production_entries',
      priority: 30,
    ),

    // ── Subscriptions ────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'subscriptions',
      remoteTableName: 'subscriptions',
      priority: 30,
    ),

    // ── Miscellaneous ────────────────────────────────────────────────────
    const SyncTableConfig(
      localTableName: 'return_inwards',
      remoteTableName: 'return_inwards',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'proformas',
      remoteTableName: 'proformas',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'bookings',
      remoteTableName: 'bookings',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'receipts',
      remoteTableName: 'receipts',
      priority: 30,
    ),
    const SyncTableConfig(
      localTableName: 'dispatches',
      remoteTableName: 'dispatches',
      priority: 35,
    ),
    const SyncTableConfig(
      localTableName: 'user_shortcuts',
      remoteTableName: 'user_shortcuts',
      priority: 50,
    ),
  ]);

  /// Get syncable tables sorted by priority.
  static List<SyncTableConfig> get sortedByPriority {
    final sorted = List<SyncTableConfig>.from(allTables);
    sorted.sort((a, b) => a.priority.compareTo(b.priority));
    return sorted;
  }

  /// Get tables for a specific business type.
  static List<SyncTableConfig> forBusinessType(String businessType) {
    return allTables.where((t) {
      if (t.businessTypes.isEmpty) return true; // Universal table
      return t.businessTypes.contains(businessType);
    }).toList()..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Get the remote table name for a given local table name.
  static String? remoteNameFor(String localTableName) {
    for (final t in allTables) {
      if (t.localTableName == localTableName) return t.remoteTableName;
    }
    return null;
  }

  /// Get the local table name for a given remote table name.
  static String? localNameFor(String remoteTableName) {
    for (final t in allTables) {
      if (t.remoteTableName == remoteTableName) return t.localTableName;
    }
    return null;
  }

  /// Check if a table is syncable.
  static bool isSyncable(String localTableName) {
    return allTables.any(
      (t) => t.localTableName == localTableName && t.syncEnabled,
    );
  }

  /// Get all remote table names (for backend SYNCABLE_TABLES expansion).
  static Set<String> get allRemoteTableNames {
    return allTables
        .where((t) => t.syncEnabled)
        .map((t) => t.remoteTableName)
        .toSet();
  }

  /// Get all local table names (for pull filtering).
  static Set<String> get allLocalTableNames {
    return allTables
        .where((t) => t.syncEnabled)
        .map((t) => t.localTableName)
        .toSet();
  }
}
