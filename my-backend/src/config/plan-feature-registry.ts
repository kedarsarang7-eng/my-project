// ============================================================================
// Plan Feature Registry — Authoritative Feature → Plan → BusinessType Mapping
// ============================================================================
// SINGLE SOURCE OF TRUTH: This file defines exactly which features are
// available for each plan tier and business type. All feature gating in the
// system derives from this registry.
//
// ⚠️  DO NOT modify this file without a corresponding migration and
//     admin-panel update. Changing feature mappings here instantly affects
//     all tenants.
// ============================================================================

import { BusinessType } from '../types/tenant.types';

// ── Plan Tiers ──────────────────────────────────────────────────────────────

export enum PlanTier {
    BASIC = 'basic',
    PRO = 'pro',
    PREMIUM = 'premium',
    ENTERPRISE = 'enterprise',
}

// ── Feature Keys ────────────────────────────────────────────────────────────
// Every gatable feature in the system. Names are self-documenting.

export enum FeatureKey {
    // ── Basic Core ──────────────────────────────────────────────────────
    DASHBOARD = 'dashboard',
    GENERAL_SETTINGS = 'general_settings',
    BASIC_USER_ROLES = 'basic_user_roles',
    ACCOUNTING_KHATA = 'accounting_khata',
    BASIC_REPORTING = 'basic_reporting',
    STANDARD_POS = 'standard_pos',
    BASIC_INVENTORY = 'basic_inventory',
    CUSTOMER_LEDGER = 'customer_ledger',
    EXPENSE_TRACKER = 'expense_tracker',
    BASIC_REORDER_ALERTS = 'basic_reorder_alerts',

    // ── Pro Core ─────────────────────────────────────────────────────────
    ADVANCED_REPORTS = 'advanced_reports',
    BARCODE_TAG_PRINTING = 'barcode_tag_printing',
    STOCK_VALUATION = 'stock_valuation',

    // ── Premium Core ────────────────────────────────────────────────────
    // NOTE: CLOUD_BACKUP and AUDIT_LOGS are Premium+, NOT Enterprise.
    // See dukanx_feature_tier_spec.md §Implementation Notes items 6 & 7.
    ADVANCED_ROLE_PERMISSIONS = 'advanced_role_permissions',
    VENDOR_PO_AUTOMATION = 'vendor_po_automation',
    AGING_REPORTS = 'aging_reports',
    AUDIT_LOGS = 'audit_logs',
    CLOUD_BACKUP = 'cloud_backup',
    ADVANCED_ANALYTICS = 'advanced_analytics',
    GST_REPORTS = 'gst_reports',

    // ── Enterprise Core ─────────────────────────────────────────────────
    MULTI_BRANCH = 'multi_branch',
    CENTRALIZED_INVENTORY_SYNC = 'centralized_inventory_sync',
    API_ACCESS = 'api_access',
    FINANCIAL_RECONCILIATION_ENGINE = 'financial_reconciliation_engine',
    HIERARCHICAL_ROLE_CONTROL = 'hierarchical_role_control',

    // ── Grocery ─────────────────────────────────────────────────────────
    GROCERY_FAST_BILLING_POS = 'grocery_fast_billing_pos',
    GROCERY_WEIGHING_SCALE = 'grocery_weighing_scale',
    GROCERY_ADVANCED_BATCH = 'grocery_advanced_batch',

    // ── Pharmacy ────────────────────────────────────────────────────────
    PHARMACY_BASIC_BATCH_EXPIRY = 'pharmacy_basic_batch_expiry',
    PHARMACY_PRESCRIPTION = 'pharmacy_prescription',
    PHARMACY_ALTERNATIVE_MEDICINE = 'pharmacy_alternative_medicine',
    PHARMACY_RETURNS = 'pharmacy_returns',
    PHARMACY_SCHEDULE_H = 'pharmacy_schedule_h',
    PHARMACY_RACK_TRACKING = 'pharmacy_rack_tracking',

    // ── Restaurant ──────────────────────────────────────────────────────
    RESTAURANT_BASIC_TABLE_MGMT = 'restaurant_basic_table_mgmt',
    RESTAURANT_KOT = 'restaurant_kot',
    RESTAURANT_SPLIT_BILLING = 'restaurant_split_billing',
    RESTAURANT_BOM = 'restaurant_bom',
    RESTAURANT_WAITER_APP = 'restaurant_waiter_app',
    RESTAURANT_MULTI_KITCHEN = 'restaurant_multi_kitchen',

    // ── Clothing ────────────────────────────────────────────────────────
    CLOTHING_BASIC_MATRIX = 'clothing_basic_matrix',
    CLOTHING_FULL_MATRIX = 'clothing_full_matrix',
    CLOTHING_SEASONAL_OFFERS = 'clothing_seasonal_offers',

    // ── Electronics ─────────────────────────────────────────────────────
    ELECTRONICS_MANUAL_SERIAL = 'electronics_manual_serial',
    ELECTRONICS_WARRANTY = 'electronics_warranty',
    ELECTRONICS_REPAIR_TICKET = 'electronics_repair_ticket',
    ELECTRONICS_EMI_INTEGRATION = 'electronics_emi_integration',
    ELECTRONICS_IMEI_API = 'electronics_imei_api',

    // ── Mobile Shop ─────────────────────────────────────────────────────
    MOBILE_IMEI_ENTRY = 'mobile_imei_entry',
    MOBILE_EXCHANGE = 'mobile_exchange',
    MOBILE_REPAIR = 'mobile_repair',
    MOBILE_EMI_INTEGRATION = 'mobile_emi_integration',
    MOBILE_IMEI_API = 'mobile_imei_api',

    // ── Computer Shop ───────────────────────────────────────────────────
    COMPUTER_PC_BUILDER = 'computer_pc_builder',
    COMPUTER_COMPONENT_TRACKING = 'computer_component_tracking',
    COMPUTER_AMC = 'computer_amc',
    COMPUTER_SERVICE_DESK = 'computer_service_desk',

    // ── Hardware ────────────────────────────────────────────────────────
    HARDWARE_ESTIMATE_TO_INVOICE = 'hardware_estimate_to_invoice',
    HARDWARE_MULTI_UOM = 'hardware_multi_uom',
    HARDWARE_DELIVERY_CHALLAN = 'hardware_delivery_challan',
    HARDWARE_CONTRACTOR_CREDIT = 'hardware_contractor_credit',
    HARDWARE_GATE_PASS = 'hardware_gate_pass',

    // ── Service ─────────────────────────────────────────────────────────
    SERVICE_BASIC_APPOINTMENT = 'service_basic_appointment',
    SERVICE_TECHNICIAN_ASSIGNMENT = 'service_technician_assignment',
    SERVICE_SUBSCRIPTION_BILLING = 'service_subscription_billing',
    SERVICE_SLA = 'service_sla',

    // ── Wholesale ───────────────────────────────────────────────────────
    WHOLESALE_BASIC_BULK_ENTRY = 'wholesale_basic_bulk_entry',
    WHOLESALE_TIERED_PRICING = 'wholesale_tiered_pricing',
    WHOLESALE_LOGISTICS = 'wholesale_logistics',
    WHOLESALE_EWAY_BILL = 'wholesale_eway_bill',
    WHOLESALE_ADVANCED_AR = 'wholesale_advanced_ar',

    // ── Petrol Pump ─────────────────────────────────────────────────────
    PETROL_BASIC_SHIFT_ENTRY = 'petrol_basic_shift_entry',
    PETROL_DIP_READING = 'petrol_dip_reading',
    PETROL_NOZZLE_SETTLEMENT = 'petrol_nozzle_settlement',
    PETROL_DENSITY_LOSS = 'petrol_density_loss',

    // ── Vegetables Broker ───────────────────────────────────────────────
    VEGBROKER_BASIC_RATE_ENTRY = 'vegbroker_basic_rate_entry',
    VEGBROKER_COMMISSION_AUTOMATION = 'vegbroker_commission_automation',
    VEGBROKER_FARMER_SETTLEMENT = 'vegbroker_farmer_settlement',

    // ── Clinic ──────────────────────────────────────────────────────────
    CLINIC_TOKEN_SCREEN = 'clinic_token_screen',
    CLINIC_BASIC_EMR = 'clinic_basic_emr',
    CLINIC_E_PRESCRIPTION = 'clinic_e_prescription',
    CLINIC_FULL_EMR = 'clinic_full_emr',
    CLINIC_AUTO_FOLLOWUP = 'clinic_auto_followup',
    CLINIC_PATIENT_MGMT = 'clinic_patient_mgmt',
    CLINIC_APPOINTMENT_MGMT = 'clinic_appointment_mgmt',
    CLINIC_DOCTOR_PROFILE = 'clinic_doctor_profile',

    // ── Book Store ──────────────────────────────────────────────────────
    BOOKSTORE_ISBN_MANUAL = 'bookstore_isbn_manual',
    BOOKSTORE_ISBN_AUTOFILL = 'bookstore_isbn_autofill',
    BOOKSTORE_PUBLISHER_FILTERS = 'bookstore_publisher_filters',
    BOOKSTORE_INSTITUTIONAL_SALES = 'bookstore_institutional_sales',
    BOOKSTORE_CONSIGNMENT_SETTLEMENT = 'bookstore_consignment_settlement',
    BOOKSTORE_USED_BOOK_ENGINE = 'bookstore_used_book_engine',
    BOOKSTORE_ACADEMIC_CRM = 'bookstore_academic_crm',

    // ── Jewellery (HIGH-001 FIX) ────────────────────────────────────────
    JEWELLERY_PURITY_TRACKING = 'jewellery_purity_tracking',
    JEWELLERY_MAKING_CHARGES = 'jewellery_making_charges',
    JEWELLERY_HALLMARK = 'jewellery_hallmark',
    JEWELLERY_OLD_GOLD_EXCHANGE = 'jewellery_old_gold_exchange',
    JEWELLERY_DAILY_RATE_CARD = 'jewellery_daily_rate_card',
    JEWELLERY_CUSTOM_ORDERS = 'jewellery_custom_orders',
    
    // ── Jewellery Extended Features ───────────────────────────────────────
    JEWELLERY_GOLD_RATE_ALERTS = 'jewellery_gold_rate_alerts',
    JEWELLERY_REPAIR_MANAGEMENT = 'jewellery_repair_management',
    JEWELLERY_GOLD_SCHEMES = 'jewellery_gold_schemes',

    // ── Auto Parts (HIGH-001 FIX) ───────────────────────────────────────
    AUTOPARTS_VEHICLE_LOOKUP = 'autoparts_vehicle_lookup',
    AUTOPARTS_OEM_CROSS_REF = 'autoparts_oem_cross_ref',
    AUTOPARTS_FITMENT_GUIDE = 'autoparts_fitment_guide',
    AUTOPARTS_RETURN_WARRANTY = 'autoparts_return_warranty',
    AUTOPARTS_JOB_CARD = 'autoparts_job_card',

    // ── Decoration & Catering ───────────────────────────────────────────
    DC_EVENT_BOOKING = 'dc_event_booking',
    DC_DECORATION_THEMES = 'dc_decoration_themes',
    DC_CATERING_MENU = 'dc_catering_menu',
    DC_STAFF_MANAGEMENT = 'dc_staff_management',
    DC_VENDOR_MANAGEMENT = 'dc_vendor_management',
    DC_INVENTORY = 'dc_inventory',
    DC_BILLING = 'dc_billing',
    DC_REPORTS = 'dc_reports',
    DC_MEAL_PLANNER = 'dc_meal_planner',
    DC_EXPENSE_TRACKING = 'dc_expense_tracking',

    // ── Academic Coaching ───────────────────────────────────────────────
    AC_STUDENT_MANAGEMENT = 'ac_student_management',
    AC_BATCH_MANAGEMENT = 'ac_batch_management',
    AC_COURSE_MANAGEMENT = 'ac_course_management',
    AC_FEE_MANAGEMENT = 'ac_fee_management',
    AC_ATTENDANCE_MANAGEMENT = 'ac_attendance_management',
    AC_FACULTY_MANAGEMENT = 'ac_faculty_management',
    AC_EXAM_MANAGEMENT = 'ac_exam_management',
    AC_TIMETABLE_MANAGEMENT = 'ac_timetable_management',
    AC_MATERIAL_MANAGEMENT = 'ac_material_management',
    AC_COMMUNICATION = 'ac_communication',
    AC_REPORTS_ANALYTICS = 'ac_reports_analytics',
    AC_PARENT_PORTAL = 'ac_parent_portal',
    AC_STUDENT_PORTAL = 'ac_student_portal',
    AC_NOTIFICATIONS = 'ac_notifications',
    AC_BULK_OPERATIONS = 'ac_bulk_operations',
    AC_FINANCIAL_REPORTS = 'ac_financial_reports',
    AC_CERTIFICATES = 'ac_certificates',

    // ── School ERP (new) ────────────────────────────────────────────────
    AC_CLASS_SECTION_MANAGEMENT = 'ac_class_section_management',
    AC_ACADEMIC_YEAR_MANAGEMENT = 'ac_academic_year_management',
    AC_LIBRARY_MANAGEMENT = 'ac_library_management',
    AC_TRANSPORT_MANAGEMENT = 'ac_transport_management',
    AC_REPORT_CARDS = 'ac_report_cards',
    AC_CLASSWISE_FEE = 'ac_classwise_fee',
    AC_INSTITUTION_CONFIG = 'ac_institution_config',
}

// ── Core Features per Plan ──────────────────────────────────────────────────
// These features are available regardless of business type.

const BASIC_CORE_FEATURES: FeatureKey[] = [
    FeatureKey.DASHBOARD,
    FeatureKey.GENERAL_SETTINGS,
    FeatureKey.BASIC_USER_ROLES,
    FeatureKey.ACCOUNTING_KHATA,
    FeatureKey.BASIC_REPORTING,
    FeatureKey.STANDARD_POS,
    FeatureKey.BASIC_INVENTORY,
    FeatureKey.CUSTOMER_LEDGER,
    FeatureKey.EXPENSE_TRACKER,
    FeatureKey.BASIC_REORDER_ALERTS,
];

// PRO = Basic + advanced reports + barcode printing (additive)
const PRO_CORE_FEATURES: FeatureKey[] = [
    ...BASIC_CORE_FEATURES,
    FeatureKey.ADVANCED_REPORTS,
    FeatureKey.BARCODE_TAG_PRINTING,
    FeatureKey.STOCK_VALUATION,
];

const PREMIUM_CORE_FEATURES: FeatureKey[] = [
    ...PRO_CORE_FEATURES,
    FeatureKey.ADVANCED_ROLE_PERMISSIONS,
    FeatureKey.VENDOR_PO_AUTOMATION,
    FeatureKey.AGING_REPORTS,
    // Per spec §6 & §7: Cloud Backup and Audit Trail are Premium+, NOT Enterprise
    FeatureKey.AUDIT_LOGS,
    FeatureKey.CLOUD_BACKUP,
    FeatureKey.ADVANCED_ANALYTICS,
    FeatureKey.GST_REPORTS,
];

const ENTERPRISE_CORE_FEATURES: FeatureKey[] = [
    ...PREMIUM_CORE_FEATURES,
    FeatureKey.MULTI_BRANCH,
    FeatureKey.CENTRALIZED_INVENTORY_SYNC,
    FeatureKey.API_ACCESS,
    FeatureKey.FINANCIAL_RECONCILIATION_ENGINE,
    FeatureKey.HIERARCHICAL_ROLE_CONTROL,
];

export const PLAN_CORE_FEATURES: Record<PlanTier, FeatureKey[]> = {
    [PlanTier.BASIC]: BASIC_CORE_FEATURES,
    [PlanTier.PRO]: PRO_CORE_FEATURES,
    [PlanTier.PREMIUM]: PREMIUM_CORE_FEATURES,
    [PlanTier.ENTERPRISE]: ENTERPRISE_CORE_FEATURES,
};

// ── Business-Specific Features per Plan ─────────────────────────────────────
// Nested: PlanTier → BusinessType → FeatureKey[]

type BusinessFeatureMap = Partial<Record<BusinessType, FeatureKey[]>>;

const BASIC_BUSINESS_FEATURES: BusinessFeatureMap = {
    [BusinessType.GROCERY]: [
        FeatureKey.GROCERY_FAST_BILLING_POS,
    ],
    [BusinessType.PHARMACY]: [
        FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY,
    ],
    [BusinessType.RESTAURANT]: [
        FeatureKey.RESTAURANT_BASIC_TABLE_MGMT,
    ],
    [BusinessType.CLOTHING]: [
        FeatureKey.CLOTHING_BASIC_MATRIX,
    ],
    [BusinessType.ELECTRONICS]: [
        FeatureKey.ELECTRONICS_MANUAL_SERIAL,
    ],
    [BusinessType.MOBILE_SHOP]: [
        FeatureKey.MOBILE_IMEI_ENTRY,
    ],
    [BusinessType.HARDWARE]: [
        FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE,
    ],
    [BusinessType.SERVICE]: [
        FeatureKey.SERVICE_BASIC_APPOINTMENT,
    ],
    [BusinessType.WHOLESALE]: [
        FeatureKey.WHOLESALE_BASIC_BULK_ENTRY,
    ],
    [BusinessType.PETROL_PUMP]: [
        FeatureKey.PETROL_BASIC_SHIFT_ENTRY,
    ],
    [BusinessType.VEGETABLES_BROKER]: [
        FeatureKey.VEGBROKER_BASIC_RATE_ENTRY,
    ],
    [BusinessType.CLINIC]: [
        FeatureKey.CLINIC_TOKEN_SCREEN,
        FeatureKey.CLINIC_PATIENT_MGMT,
        FeatureKey.CLINIC_APPOINTMENT_MGMT,
        FeatureKey.CLINIC_DOCTOR_PROFILE,
    ],
    [BusinessType.BOOK_STORE]: [
        FeatureKey.BOOKSTORE_ISBN_MANUAL,
    ],
    // HIGH-001 FIX: Added jewellery + auto_parts
    [BusinessType.JEWELLERY]: [
        FeatureKey.JEWELLERY_PURITY_TRACKING,
        FeatureKey.JEWELLERY_GOLD_RATE_ALERTS,
    ],
    [BusinessType.AUTO_PARTS]: [
        FeatureKey.AUTOPARTS_VEHICLE_LOOKUP,
    ],
    // §18 School ERP — BASIC: student registry + fee collection
    [BusinessType.SCHOOL_ERP]: [
        FeatureKey.AC_STUDENT_MANAGEMENT,
        FeatureKey.AC_FEE_MANAGEMENT,
        FeatureKey.AC_ATTENDANCE_MANAGEMENT,
    ],
};

const PREMIUM_BUSINESS_FEATURES: BusinessFeatureMap = {
    [BusinessType.GROCERY]: [
        FeatureKey.GROCERY_FAST_BILLING_POS,
        FeatureKey.GROCERY_WEIGHING_SCALE,
        FeatureKey.GROCERY_ADVANCED_BATCH,
    ],
    // §3 Pharmacy Premium: narcotic register (Schedule X) + H1 register
    [BusinessType.PHARMACY]: [
        FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY,
        FeatureKey.PHARMACY_PRESCRIPTION,
        FeatureKey.PHARMACY_ALTERNATIVE_MEDICINE,
        FeatureKey.PHARMACY_RETURNS,
        FeatureKey.PHARMACY_SCHEDULE_H,
    ],
    [BusinessType.RESTAURANT]: [
        FeatureKey.RESTAURANT_BASIC_TABLE_MGMT,
        FeatureKey.RESTAURANT_KOT,
        FeatureKey.RESTAURANT_SPLIT_BILLING,
        FeatureKey.RESTAURANT_BOM,
        FeatureKey.RESTAURANT_WAITER_APP,
    ],
    [BusinessType.CLOTHING]: [
        FeatureKey.CLOTHING_BASIC_MATRIX,
        FeatureKey.CLOTHING_FULL_MATRIX,
        FeatureKey.CLOTHING_SEASONAL_OFFERS,
    ],
    [BusinessType.ELECTRONICS]: [
        FeatureKey.ELECTRONICS_MANUAL_SERIAL,
        FeatureKey.ELECTRONICS_WARRANTY,
        FeatureKey.ELECTRONICS_REPAIR_TICKET,
    ],
    [BusinessType.MOBILE_SHOP]: [
        FeatureKey.MOBILE_IMEI_ENTRY,
        FeatureKey.MOBILE_EXCHANGE,
        FeatureKey.MOBILE_REPAIR,
    ],
    // §7 Computer Premium: HSN-wise GST report (served via GST_REPORTS core)
    [BusinessType.COMPUTER_SHOP]: [
        FeatureKey.COMPUTER_PC_BUILDER,
        FeatureKey.COMPUTER_COMPONENT_TRACKING,
        FeatureKey.COMPUTER_AMC,
        FeatureKey.COMPUTER_SERVICE_DESK,
    ],
    // §8 Hardware Premium: purchase register, stock reversal, CSV export, aging reports
    [BusinessType.HARDWARE]: [
        FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE,
        FeatureKey.HARDWARE_MULTI_UOM,
        FeatureKey.HARDWARE_DELIVERY_CHALLAN,
        FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
        FeatureKey.HARDWARE_GATE_PASS,
    ],
    [BusinessType.SERVICE]: [
        FeatureKey.SERVICE_BASIC_APPOINTMENT,
        FeatureKey.SERVICE_TECHNICIAN_ASSIGNMENT,
        FeatureKey.SERVICE_SUBSCRIPTION_BILLING,
    ],
    // §10 Wholesale Premium: aging reports, GST, vendor PO automation
    [BusinessType.WHOLESALE]: [
        FeatureKey.WHOLESALE_BASIC_BULK_ENTRY,
        FeatureKey.WHOLESALE_TIERED_PRICING,
        FeatureKey.WHOLESALE_LOGISTICS,
        FeatureKey.WHOLESALE_EWAY_BILL,
        FeatureKey.WHOLESALE_ADVANCED_AR,
    ],
    // §11 Petrol Premium: GST reports + DU calibration logs (via GST_REPORTS core)
    [BusinessType.PETROL_PUMP]: [
        FeatureKey.PETROL_BASIC_SHIFT_ENTRY,
        FeatureKey.PETROL_DIP_READING,
        FeatureKey.PETROL_DENSITY_LOSS,
    ],
    [BusinessType.VEGETABLES_BROKER]: [
        FeatureKey.VEGBROKER_BASIC_RATE_ENTRY,
        FeatureKey.VEGBROKER_COMMISSION_AUTOMATION,
        FeatureKey.VEGBROKER_FARMER_SETTLEMENT,
    ],
    [BusinessType.CLINIC]: [
        FeatureKey.CLINIC_TOKEN_SCREEN,
        FeatureKey.CLINIC_BASIC_EMR,
        FeatureKey.CLINIC_E_PRESCRIPTION,
        FeatureKey.CLINIC_FULL_EMR,
        FeatureKey.CLINIC_PATIENT_MGMT,
        FeatureKey.CLINIC_APPOINTMENT_MGMT,
        FeatureKey.CLINIC_DOCTOR_PROFILE,
    ],
    [BusinessType.BOOK_STORE]: [
        FeatureKey.BOOKSTORE_ISBN_MANUAL,
        FeatureKey.BOOKSTORE_ISBN_AUTOFILL,
        FeatureKey.BOOKSTORE_PUBLISHER_FILTERS,
        FeatureKey.BOOKSTORE_INSTITUTIONAL_SALES,
        FeatureKey.BOOKSTORE_CONSIGNMENT_SETTLEMENT,
    ],
    // §15 Jewellery Premium: GSTR-1 + high-value transaction reporting (PML Act)
    [BusinessType.JEWELLERY]: [
        FeatureKey.JEWELLERY_PURITY_TRACKING,
        FeatureKey.JEWELLERY_MAKING_CHARGES,
        FeatureKey.JEWELLERY_HALLMARK,
        FeatureKey.JEWELLERY_OLD_GOLD_EXCHANGE,
        FeatureKey.JEWELLERY_DAILY_RATE_CARD,
        FeatureKey.JEWELLERY_CUSTOM_ORDERS,
        FeatureKey.JEWELLERY_GOLD_RATE_ALERTS,
        FeatureKey.JEWELLERY_REPAIR_MANAGEMENT,
    ],
    // §16 Auto Parts Premium: mechanic performance reports + GST (via GST_REPORTS core)
    [BusinessType.AUTO_PARTS]: [
        FeatureKey.AUTOPARTS_VEHICLE_LOOKUP,
        FeatureKey.AUTOPARTS_OEM_CROSS_REF,
        FeatureKey.AUTOPARTS_FITMENT_GUIDE,
        FeatureKey.AUTOPARTS_RETURN_WARRANTY,
        FeatureKey.AUTOPARTS_JOB_CARD,
    ],
    // §18 School ERP — Premium: all features + portals
    [BusinessType.SCHOOL_ERP]: [
        FeatureKey.AC_STUDENT_MANAGEMENT,
        FeatureKey.AC_BATCH_MANAGEMENT,
        FeatureKey.AC_COURSE_MANAGEMENT,
        FeatureKey.AC_FEE_MANAGEMENT,
        FeatureKey.AC_ATTENDANCE_MANAGEMENT,
        FeatureKey.AC_FACULTY_MANAGEMENT,
        FeatureKey.AC_EXAM_MANAGEMENT,
        FeatureKey.AC_TIMETABLE_MANAGEMENT,
        FeatureKey.AC_MATERIAL_MANAGEMENT,
        FeatureKey.AC_COMMUNICATION,
        FeatureKey.AC_REPORTS_ANALYTICS,
        FeatureKey.AC_PARENT_PORTAL,
        FeatureKey.AC_STUDENT_PORTAL,
        FeatureKey.AC_CLASS_SECTION_MANAGEMENT,
        FeatureKey.AC_ACADEMIC_YEAR_MANAGEMENT,
        FeatureKey.AC_LIBRARY_MANAGEMENT,
        FeatureKey.AC_TRANSPORT_MANAGEMENT,
        FeatureKey.AC_REPORT_CARDS,
        FeatureKey.AC_CLASSWISE_FEE,
        FeatureKey.AC_INSTITUTION_CONFIG,
    ],
    [BusinessType.DECORATION_CATERING]: [
        FeatureKey.DC_EVENT_BOOKING,
        FeatureKey.DC_DECORATION_THEMES,
        FeatureKey.DC_CATERING_MENU,
        FeatureKey.DC_STAFF_MANAGEMENT,
        FeatureKey.DC_VENDOR_MANAGEMENT,
        FeatureKey.DC_INVENTORY,
        FeatureKey.DC_BILLING,
        FeatureKey.DC_REPORTS,
        FeatureKey.DC_MEAL_PLANNER,
        FeatureKey.DC_EXPENSE_TRACKING,
    ],
};

const ENTERPRISE_BUSINESS_FEATURES: BusinessFeatureMap = {
    [BusinessType.GROCERY]: [
        FeatureKey.GROCERY_FAST_BILLING_POS,
        FeatureKey.GROCERY_WEIGHING_SCALE,
        FeatureKey.GROCERY_ADVANCED_BATCH,
    ],
    [BusinessType.PHARMACY]: [
        FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY,
        FeatureKey.PHARMACY_PRESCRIPTION,
        FeatureKey.PHARMACY_ALTERNATIVE_MEDICINE,
        FeatureKey.PHARMACY_RETURNS,
        FeatureKey.PHARMACY_SCHEDULE_H,
        FeatureKey.PHARMACY_RACK_TRACKING,
    ],
    [BusinessType.RESTAURANT]: [
        FeatureKey.RESTAURANT_BASIC_TABLE_MGMT,
        FeatureKey.RESTAURANT_KOT,
        FeatureKey.RESTAURANT_SPLIT_BILLING,
        FeatureKey.RESTAURANT_BOM,
        FeatureKey.RESTAURANT_WAITER_APP,
        FeatureKey.RESTAURANT_MULTI_KITCHEN,
    ],
    [BusinessType.CLOTHING]: [
        FeatureKey.CLOTHING_BASIC_MATRIX,
        FeatureKey.CLOTHING_FULL_MATRIX,
        FeatureKey.CLOTHING_SEASONAL_OFFERS,
    ],
    [BusinessType.ELECTRONICS]: [
        FeatureKey.ELECTRONICS_MANUAL_SERIAL,
        FeatureKey.ELECTRONICS_WARRANTY,
        FeatureKey.ELECTRONICS_REPAIR_TICKET,
        FeatureKey.ELECTRONICS_EMI_INTEGRATION,
        FeatureKey.ELECTRONICS_IMEI_API,
    ],
    [BusinessType.MOBILE_SHOP]: [
        FeatureKey.MOBILE_IMEI_ENTRY,
        FeatureKey.MOBILE_EXCHANGE,
        FeatureKey.MOBILE_REPAIR,
        FeatureKey.MOBILE_EMI_INTEGRATION,
        FeatureKey.MOBILE_IMEI_API,
    ],
    [BusinessType.COMPUTER_SHOP]: [
        FeatureKey.COMPUTER_PC_BUILDER,
        FeatureKey.COMPUTER_COMPONENT_TRACKING,
        FeatureKey.COMPUTER_AMC,
        FeatureKey.COMPUTER_SERVICE_DESK,
    ],
    [BusinessType.HARDWARE]: [
        FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE,
        FeatureKey.HARDWARE_MULTI_UOM,
        FeatureKey.HARDWARE_DELIVERY_CHALLAN,
        FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
        FeatureKey.HARDWARE_GATE_PASS,
    ],
    [BusinessType.SERVICE]: [
        FeatureKey.SERVICE_BASIC_APPOINTMENT,
        FeatureKey.SERVICE_TECHNICIAN_ASSIGNMENT,
        FeatureKey.SERVICE_SUBSCRIPTION_BILLING,
        FeatureKey.SERVICE_SLA,
    ],
    [BusinessType.WHOLESALE]: [
        FeatureKey.WHOLESALE_BASIC_BULK_ENTRY,
        FeatureKey.WHOLESALE_TIERED_PRICING,
        FeatureKey.WHOLESALE_LOGISTICS,
        FeatureKey.WHOLESALE_EWAY_BILL,
        FeatureKey.WHOLESALE_ADVANCED_AR,
    ],
    [BusinessType.PETROL_PUMP]: [
        FeatureKey.PETROL_BASIC_SHIFT_ENTRY,
        FeatureKey.PETROL_DIP_READING,
        FeatureKey.PETROL_NOZZLE_SETTLEMENT,
        FeatureKey.PETROL_DENSITY_LOSS,
    ],
    [BusinessType.VEGETABLES_BROKER]: [
        FeatureKey.VEGBROKER_BASIC_RATE_ENTRY,
        FeatureKey.VEGBROKER_COMMISSION_AUTOMATION,
        FeatureKey.VEGBROKER_FARMER_SETTLEMENT,
    ],
    [BusinessType.CLINIC]: [
        FeatureKey.CLINIC_TOKEN_SCREEN,
        FeatureKey.CLINIC_BASIC_EMR,
        FeatureKey.CLINIC_E_PRESCRIPTION,
        FeatureKey.CLINIC_FULL_EMR,
        FeatureKey.CLINIC_AUTO_FOLLOWUP,
        FeatureKey.CLINIC_PATIENT_MGMT,
        FeatureKey.CLINIC_APPOINTMENT_MGMT,
        FeatureKey.CLINIC_DOCTOR_PROFILE,
    ],
    [BusinessType.BOOK_STORE]: [
        FeatureKey.BOOKSTORE_ISBN_MANUAL,
        FeatureKey.BOOKSTORE_ISBN_AUTOFILL,
        FeatureKey.BOOKSTORE_PUBLISHER_FILTERS,
        FeatureKey.BOOKSTORE_INSTITUTIONAL_SALES,
        FeatureKey.BOOKSTORE_CONSIGNMENT_SETTLEMENT,
        FeatureKey.BOOKSTORE_USED_BOOK_ENGINE,
        FeatureKey.BOOKSTORE_ACADEMIC_CRM,
    ],
    // HIGH-001 FIX: Added jewellery + auto_parts
    [BusinessType.JEWELLERY]: [
        FeatureKey.JEWELLERY_PURITY_TRACKING,
        FeatureKey.JEWELLERY_MAKING_CHARGES,
        FeatureKey.JEWELLERY_HALLMARK,
        FeatureKey.JEWELLERY_OLD_GOLD_EXCHANGE,
        FeatureKey.JEWELLERY_DAILY_RATE_CARD,
        FeatureKey.JEWELLERY_CUSTOM_ORDERS,
        FeatureKey.JEWELLERY_GOLD_RATE_ALERTS,
        FeatureKey.JEWELLERY_REPAIR_MANAGEMENT,
        FeatureKey.JEWELLERY_GOLD_SCHEMES,
    ],
    [BusinessType.AUTO_PARTS]: [
        FeatureKey.AUTOPARTS_VEHICLE_LOOKUP,
        FeatureKey.AUTOPARTS_OEM_CROSS_REF,
        FeatureKey.AUTOPARTS_FITMENT_GUIDE,
        FeatureKey.AUTOPARTS_RETURN_WARRANTY,
        FeatureKey.AUTOPARTS_JOB_CARD,
    ],
    [BusinessType.DECORATION_CATERING]: [
        FeatureKey.DC_EVENT_BOOKING,
        FeatureKey.DC_DECORATION_THEMES,
        FeatureKey.DC_CATERING_MENU,
        FeatureKey.DC_STAFF_MANAGEMENT,
        FeatureKey.DC_VENDOR_MANAGEMENT,
        FeatureKey.DC_INVENTORY,
        FeatureKey.DC_BILLING,
        FeatureKey.DC_REPORTS,
        FeatureKey.DC_MEAL_PLANNER,
        FeatureKey.DC_EXPENSE_TRACKING,
    ],
    [BusinessType.SCHOOL_ERP]: [
        FeatureKey.AC_STUDENT_MANAGEMENT,
        FeatureKey.AC_BATCH_MANAGEMENT,
        FeatureKey.AC_COURSE_MANAGEMENT,
        FeatureKey.AC_FEE_MANAGEMENT,
        FeatureKey.AC_ATTENDANCE_MANAGEMENT,
        FeatureKey.AC_FACULTY_MANAGEMENT,
        FeatureKey.AC_EXAM_MANAGEMENT,
        FeatureKey.AC_TIMETABLE_MANAGEMENT,
        FeatureKey.AC_MATERIAL_MANAGEMENT,
        FeatureKey.AC_COMMUNICATION,
        FeatureKey.AC_REPORTS_ANALYTICS,
        FeatureKey.AC_PARENT_PORTAL,
        FeatureKey.AC_STUDENT_PORTAL,
        FeatureKey.AC_CLASS_SECTION_MANAGEMENT,
        FeatureKey.AC_ACADEMIC_YEAR_MANAGEMENT,
        FeatureKey.AC_LIBRARY_MANAGEMENT,
        FeatureKey.AC_TRANSPORT_MANAGEMENT,
        FeatureKey.AC_REPORT_CARDS,
        FeatureKey.AC_CLASSWISE_FEE,
        FeatureKey.AC_INSTITUTION_CONFIG,
    ],
};

// PRO business features: Basic features + 1-2 mid-tier additions per vertical
// SPEC-ALIGNED: PRO tier per dukanx_feature_tier_spec.md §§2-16
// Rule: PRO = Basic features + mid-tier growth tools unlocked
const PRO_BUSINESS_FEATURES: BusinessFeatureMap = {
    // §2 Grocery: batch tracking, PO, supplier bill, OCR, voice, stock valuation, barcode label
    [BusinessType.GROCERY]: [
        FeatureKey.GROCERY_FAST_BILLING_POS,
        FeatureKey.GROCERY_WEIGHING_SCALE,
        FeatureKey.GROCERY_ADVANCED_BATCH,
    ],
    // §3 Pharmacy: batch tracking, PO, purchase register, stock reversal, OCR, valuation
    [BusinessType.PHARMACY]: [
        FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY,
        FeatureKey.PHARMACY_PRESCRIPTION,
        FeatureKey.PHARMACY_ALTERNATIVE_MEDICINE,
        FeatureKey.PHARMACY_RETURNS,
    ],
    // §4 Restaurant: KDS (KOT), dish profitability, sales by category/waiter report
    [BusinessType.RESTAURANT]: [
        FeatureKey.RESTAURANT_BASIC_TABLE_MGMT,
        FeatureKey.RESTAURANT_KOT,
        FeatureKey.RESTAURANT_SPLIT_BILLING,
        FeatureKey.RESTAURANT_BOM,
    ],
    // §5 Clothing: OCR smart import, barcode label printing, stock valuation, season analytics
    [BusinessType.CLOTHING]: [
        FeatureKey.CLOTHING_BASIC_MATRIX,
        FeatureKey.CLOTHING_FULL_MATRIX,
        FeatureKey.CLOTHING_SEASONAL_OFFERS,
    ],
    // §6 Electronics: IMEI-wise sales audit, barcode label, stock valuation
    [BusinessType.ELECTRONICS]: [
        FeatureKey.ELECTRONICS_MANUAL_SERIAL,
        FeatureKey.ELECTRONICS_WARRANTY,
        FeatureKey.ELECTRONICS_REPAIR_TICKET,
    ],
    // §6 Mobile: IMEI audit, buyback/exchange, repair job sheet, repair tracking
    [BusinessType.MOBILE_SHOP]: [
        FeatureKey.MOBILE_IMEI_ENTRY,
        FeatureKey.MOBILE_EXCHANGE,
        FeatureKey.MOBILE_REPAIR,
    ],
    // §7 Computer: stock valuation, barcode label, AMC contract tracking
    [BusinessType.COMPUTER_SHOP]: [
        FeatureKey.COMPUTER_PC_BUILDER,
        FeatureKey.COMPUTER_COMPONENT_TRACKING,
        FeatureKey.COMPUTER_AMC,
    ],
    // §8 Hardware: PO, supplier bill, barcode label, stock valuation, part compatibility
    [BusinessType.HARDWARE]: [
        FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE,
        FeatureKey.HARDWARE_MULTI_UOM,
        FeatureKey.HARDWARE_DELIVERY_CHALLAN,
    ],
    // §9 Service: advanced revenue reports, recurring invoices, technician performance
    [BusinessType.SERVICE]: [
        FeatureKey.SERVICE_BASIC_APPOINTMENT,
        FeatureKey.SERVICE_TECHNICIAN_ASSIGNMENT,
        FeatureKey.SERVICE_SUBSCRIPTION_BILLING,
    ],
    // §10 Wholesale: batch/expiry, purchase register, stock reversal, export, valuation, label, margin
    [BusinessType.WHOLESALE]: [
        FeatureKey.WHOLESALE_BASIC_BULK_ENTRY,
        FeatureKey.WHOLESALE_TIERED_PRICING,
        FeatureKey.WHOLESALE_LOGISTICS,
    ],
    // §11 Petrol: shift-wise profitability, nozzle-wise analytics, fleet credit management
    [BusinessType.PETROL_PUMP]: [
        FeatureKey.PETROL_BASIC_SHIFT_ENTRY,
        FeatureKey.PETROL_DIP_READING,
    ],
    // §12 VegBroker: commodity profitability, farmer history, APMC levy
    [BusinessType.VEGETABLES_BROKER]: [
        FeatureKey.VEGBROKER_BASIC_RATE_ENTRY,
        FeatureKey.VEGBROKER_COMMISSION_AUTOMATION,
        FeatureKey.VEGBROKER_FARMER_SETTLEMENT,
    ],
    // §13 Clinic: doctor revenue analytics, patient visit history, referral tracking
    [BusinessType.CLINIC]: [
        FeatureKey.CLINIC_TOKEN_SCREEN,
        FeatureKey.CLINIC_BASIC_EMR,
        FeatureKey.CLINIC_E_PRESCRIPTION,
        FeatureKey.CLINIC_PATIENT_MGMT,
        FeatureKey.CLINIC_APPOINTMENT_MGMT,
        FeatureKey.CLINIC_DOCTOR_PROFILE,
    ],
    // §14 Bookstore: OCR, stock valuation, label, title analytics, purchase register, export
    [BusinessType.BOOK_STORE]: [
        FeatureKey.BOOKSTORE_ISBN_MANUAL,
        FeatureKey.BOOKSTORE_ISBN_AUTOFILL,
        FeatureKey.BOOKSTORE_PUBLISHER_FILTERS,
        FeatureKey.BOOKSTORE_CONSIGNMENT_SETTLEMENT,
    ],
    // §15 Jewellery: customer KYC, live gold rate API, metal stock valuation, karigar profitability
    [BusinessType.JEWELLERY]: [
        FeatureKey.JEWELLERY_PURITY_TRACKING,
        FeatureKey.JEWELLERY_MAKING_CHARGES,
        FeatureKey.JEWELLERY_HALLMARK,
        FeatureKey.JEWELLERY_DAILY_RATE_CARD,
        FeatureKey.JEWELLERY_GOLD_RATE_ALERTS,
    ],
    // §16 Auto Parts: stock valuation, barcode label, vehicle-wise revenue
    [BusinessType.AUTO_PARTS]: [
        FeatureKey.AUTOPARTS_VEHICLE_LOOKUP,
        FeatureKey.AUTOPARTS_OEM_CROSS_REF,
        FeatureKey.AUTOPARTS_FITMENT_GUIDE,
        FeatureKey.AUTOPARTS_RETURN_WARRANTY,
    ],
    // §17 Decoration & Catering
    [BusinessType.DECORATION_CATERING]: [
        FeatureKey.DC_EVENT_BOOKING,
        FeatureKey.DC_DECORATION_THEMES,
        FeatureKey.DC_CATERING_MENU,
        FeatureKey.DC_STAFF_MANAGEMENT,
        FeatureKey.DC_VENDOR_MANAGEMENT,
        FeatureKey.DC_INVENTORY,
        FeatureKey.DC_BILLING,
        FeatureKey.DC_REPORTS,
        FeatureKey.DC_MEAL_PLANNER,
        FeatureKey.DC_EXPENSE_TRACKING,
    ],
    // §18 School ERP — PRO: + course, faculty, exam management
    [BusinessType.SCHOOL_ERP]: [
        FeatureKey.AC_STUDENT_MANAGEMENT,
        FeatureKey.AC_BATCH_MANAGEMENT,
        FeatureKey.AC_COURSE_MANAGEMENT,
        FeatureKey.AC_FEE_MANAGEMENT,
        FeatureKey.AC_ATTENDANCE_MANAGEMENT,
        FeatureKey.AC_FACULTY_MANAGEMENT,
        FeatureKey.AC_EXAM_MANAGEMENT,
        FeatureKey.AC_CLASS_SECTION_MANAGEMENT,
        FeatureKey.AC_ACADEMIC_YEAR_MANAGEMENT,
        FeatureKey.AC_LIBRARY_MANAGEMENT,
        FeatureKey.AC_TRANSPORT_MANAGEMENT,
        FeatureKey.AC_REPORT_CARDS,
    ],
};

export const PLAN_BUSINESS_FEATURES: Record<PlanTier, BusinessFeatureMap> = {
    [PlanTier.BASIC]: BASIC_BUSINESS_FEATURES,
    [PlanTier.PRO]: PRO_BUSINESS_FEATURES,
    [PlanTier.PREMIUM]: PREMIUM_BUSINESS_FEATURES,
    [PlanTier.ENTERPRISE]: ENTERPRISE_BUSINESS_FEATURES,
};

// ── Plan Limits ─────────────────────────────────────────────────────────────

export interface PlanLimits {
    maxUsers: number | null;
    maxProducts: number | null;
    maxBranches: number;
    maxDevices: number;
    maxBusinessTypes: number;
    /** Per-month invoice limit (null = unlimited) */
    maxInvoicesPerMonth?: number | null;
    /** Per-license storage quota in GB (null = use plan default) */
    storageLimitGB?: number | null;
    /** Per-license API rate limit in requests per minute (null = use plan default) */
    apiRateLimit?: number | null;
}

export const PLAN_LIMITS: Record<PlanTier, PlanLimits> = {
    [PlanTier.BASIC]: { maxUsers: 1, maxProducts: 500, maxBranches: 1, maxDevices: 1, maxBusinessTypes: 1, maxInvoicesPerMonth: 100 },
    [PlanTier.PRO]: { maxUsers: 3, maxProducts: null, maxBranches: 1, maxDevices: 3, maxBusinessTypes: 2, maxInvoicesPerMonth: null },
    [PlanTier.PREMIUM]: { maxUsers: 5, maxProducts: null, maxBranches: 3, maxDevices: 5, maxBusinessTypes: 5, maxInvoicesPerMonth: null },
    [PlanTier.ENTERPRISE]: { maxUsers: null, maxProducts: null, maxBranches: 50, maxDevices: 999, maxBusinessTypes: 17, maxInvoicesPerMonth: null },
};

// ── Plan Hierarchy (for upgrade/downgrade validation) ───────────────────────

export const PLAN_HIERARCHY: Record<PlanTier, number> = {
    [PlanTier.BASIC]: 1,
    [PlanTier.PRO]: 2,
    [PlanTier.PREMIUM]: 3,
    [PlanTier.ENTERPRISE]: 4,
};

// ── Helper Functions ────────────────────────────────────────────────────────

/**
 * Get the full list of allowed features for a plan + business type.
 * Returns core features + business-specific features for the given plan.
 */
export function getAllowedFeatures(
    plan: PlanTier,
    businessType: BusinessType,
): FeatureKey[] {
    const core = PLAN_CORE_FEATURES[plan] || [];
    const businessMap = PLAN_BUSINESS_FEATURES[plan] || {};
    const business = businessMap[businessType] || [];
    // Deduplicate (shouldn't happen, but defensive)
    return Array.from(new Set([...core, ...business]));
}

/**
 * Check if a specific feature is allowed for a plan + business type.
 * O(n) lookup — for hot paths, use the cached manifest instead.
 */
export function isFeatureAllowed(
    plan: PlanTier,
    businessType: BusinessType,
    feature: FeatureKey,
): boolean {
    return getAllowedFeatures(plan, businessType).includes(feature);
}

/**
 * Validate that a plan upgrade is allowed.
 * Returns true if newPlan is higher than currentPlan.
 */
export function isValidUpgrade(currentPlan: PlanTier, newPlan: PlanTier): boolean {
    return PLAN_HIERARCHY[newPlan] > PLAN_HIERARCHY[currentPlan];
}

/**
 * Validate that a plan downgrade is allowed.
 * Returns true if newPlan is lower than currentPlan.
 */
export function isValidDowngrade(currentPlan: PlanTier, newPlan: PlanTier): boolean {
    return PLAN_HIERARCHY[newPlan] < PLAN_HIERARCHY[currentPlan];
}

/**
 * Map legacy subscription plan names to PlanTier.
 * Handles backward compatibility with existing free/starter/professional plans.
 */
export function mapToPlanTier(plan: string): PlanTier {
    const normalized = plan.toLowerCase().trim();
    switch (normalized) {
        case 'free':
        case 'starter':
        case 'basic':
            return PlanTier.BASIC;
        case 'pro':
            return PlanTier.PRO;
        case 'professional':
        case 'premium':
            return PlanTier.PREMIUM;
        case 'enterprise':
            return PlanTier.ENTERPRISE;
        default:
            return PlanTier.BASIC; // Fail-safe: default to most restrictive
    }
}
