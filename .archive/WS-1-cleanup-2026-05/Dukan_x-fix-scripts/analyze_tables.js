const fs = require('fs');

const tablesString = `
 - access_logs
 - accounting_periods
 - active_sessions
 - admin_audit_logs
 - admin_login_history
 - admins
 - appointments
 - audit_log
 - bank_accounts
 - bank_transactions
 - bill_of_materials
 - billing_events
 - book_returns
 - bookings
 - cash_closings
 - cash_deposits
 - commission_ledger
 - customer_ledger
 - customer_shop_links
 - customers
 - day_book
 - delivery_challans
 - density_records
 - device_sessions
 - dispatches
 - dispensers
 - doctor_profiles
 - e_invoices
 - e_way_bills
 - exchanges
 - expenses
 - farmers
 - feature_flag_configs
 - five_litre_tests
 - food_addons
 - food_categories
 - food_item_addon_links
 - food_item_variations
 - food_menu_items
 - food_order_items
 - food_orders
 - fuel_prices
 - fuel_sales_gst_view
 - fuel_tanks
 - gst_invoice_details
 - gst_settings
 - hwid_bindings
 - imei_serials
 - inventory
 - invoice_counters
 - item_recipes
 - journal_entries
 - lab_reports
 - ledger_accounts
 - licenses
 - linking_tokens
 - loss_entries
 - lube_stock
 - marketing_campaigns
 - medical_records
 - medical_templates
 - medicine_batches
 - message_templates
 - nozzle_readings
 - nozzles
 - offline_activations
 - patient_doctor_links
 - patients
 - payments
 - period_locks
 - permissions
 - prescription_items
 - prescriptions
 - product_batches
 - product_variants
 - production_entries
 - proformas
 - pump_daily_readings
 - purchase_orders
 - receipts
 - reminder_settings
 - request_nonces
 - resellers
 - restaurant_bill_splits
 - restaurant_bills
 - restaurant_floors
 - restaurant_inventory_items
 - restaurant_kots
 - restaurant_loyalty_transactions
 - restaurant_tables
 - return_inwards
 - returns
 - role_permissions
 - roles
 - salary_records
 - schema_migrations
 - security_settings
 - service_job_parts
 - service_job_status_history
 - service_jobs
 - shared_prescriptions
 - shifts
 - staff_attendance
 - staff_cash_settlements
 - staff_members
 - staff_nozzle_assignments
 - staff_permission_overrides
 - staff_sales_details
 - stock_movements
 - subscriptions
 - system_config
 - tamper_detection_logs
 - tenants
 - transaction_items
 - transactions
 - udhar_people
 - udhar_transactions
 - user_sessions
 - user_shortcuts
 - users
 - v_effective_permissions
 - vendors
 - visits
`;

const existingTables = tablesString.split('\n').filter(l => l.trim().startsWith('-')).map(l => l.replace('-', '').trim());

// List of expected tables from migrations
const expectedTables = [
    // 001_multi_tenant_schema.sql
    'tenants', 'licenses', 'users', 'roles', 'permissions', 'role_permissions', 'user_sessions',
    'customers', 'vendors', 'inventory', 'categories', 'transactions', 'transaction_items', 'audit_log',
    // 003_customer_shop_links.sql 
    'customer_shop_links',
    // 005_linking_tokens.sql
    'linking_tokens',
    // 006_book_store.sql
    'book_returns', 'exchanges', 'library_members', 'rental_transactions',
    // 007_full_sync_schema.sql
    'products', 'sales', 'sale_items', 'purchases', 'purchase_items', 'expenses',
    // 008_device_sessions.sql
    'device_sessions',
    // 010_payment_gateway_config.sql
    'subscriptions', 'payments', 'gst_invoice_details',
    // 011_security_hardening.sql
    'security_settings', 'admin_audit_logs', 'tamper_detection_logs', 'request_nonces',
    // 012_admin_architecture.sql
    'admin_login_history', 'feature_flag_configs', 'system_config', 'billing_events'
];

console.log('--- Missing Tables Analysis ---');
let missingCount = 0;
expectedTables.forEach(table => {
    if (!existingTables.includes(table)) {
        console.log(`MISSING: ${table}`);
        missingCount++;
    } else {
        // console.log(`FOUND: ${table}`);
    }
});

console.log(`\nTotal Expected Tables: ${expectedTables.length}`);
console.log(`Missing Tables: ${missingCount}`);
