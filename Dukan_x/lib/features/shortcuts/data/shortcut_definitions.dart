import '../domain/models/shortcut_definition.dart';
import '../../../../services/role_management_service.dart';

/// Default shortcuts organized by category
/// These follow Tally/Vyapar professional standards for keyboard-first operation
final List<ShortcutDefinition> defaultShortcuts = [
  // ============================================================================
  // FUNCTION KEYS (F1-F12) - TALLY STANDARD
  // ============================================================================

  // F1 → Help / Keyboard Shortcut Overlay
  ShortcutDefinition(
    id: 'HELP_OVERLAY',
    label: 'Keyboard Help',
    iconName: 'help_outline',
    route: null,
    actionType: ActionType.modal,
    category: 'SYSTEM',
    defaultKeyBinding: 'F1',
    isDefault: true,
    defaultSortOrder: 0,
  ),

  // F2 → Edit Selected Record
  ShortcutDefinition(
    id: 'EDIT_SELECTED',
    label: 'Edit Selected',
    iconName: 'edit',
    route: null,
    actionType: ActionType.function,
    category: 'SYSTEM',
    requiredPermission: Permission.editBill,
    defaultKeyBinding: 'F2',
    isDefault: true,
    defaultSortOrder: 1,
  ),

  // F3 → Change Company / Business
  ShortcutDefinition(
    id: 'CHANGE_BUSINESS',
    label: 'Change Business',
    iconName: 'business',
    route: '/change_business',
    actionType: ActionType.navigate,
    category: 'SYSTEM',
    requiredPermission: Permission.manageSettings,
    defaultKeyBinding: 'F3',
    isDefault: true,
    defaultSortOrder: 2,
  ),

  // F4 → Inventory / Stock
  ShortcutDefinition(
    id: 'INVENTORY',
    label: 'Inventory / Stock',
    iconName: 'inventory_2',
    route: '/inventory',
    actionType: ActionType.navigate,
    category: 'NAVIGATION',
    requiredPermission: Permission.viewStock,
    defaultKeyBinding: 'F4',
    isDefault: true,
    defaultSortOrder: 3,
  ),

  // F5 → Payments
  ShortcutDefinition(
    id: 'PAYMENTS',
    label: 'Payments',
    iconName: 'payments',
    route: '/payment-history',
    actionType: ActionType.navigate,
    category: 'NAVIGATION',
    requiredPermission: Permission.receivePayment,
    defaultKeyBinding: 'F5',
    isDefault: true,
    defaultSortOrder: 4,
  ),

  // F6 → Receipts
  ShortcutDefinition(
    id: 'RECEIPTS',
    label: 'Receipts',
    iconName: 'receipt_long',
    route: '/receipts',
    actionType: ActionType.navigate,
    category: 'NAVIGATION',
    requiredPermission: Permission.viewReports,
    defaultKeyBinding: 'F6',
    isDefault: true,
    defaultSortOrder: 5,
  ),

  // F7 → Journal / Day Book
  ShortcutDefinition(
    id: 'JOURNAL',
    label: 'Journal / Day Book',
    iconName: 'menu_book',
    route: '/daybook',
    actionType: ActionType.navigate,
    category: 'NAVIGATION',
    requiredPermission: Permission.viewCashBook,
    defaultKeyBinding: 'F7',
    isDefault: true,
    defaultSortOrder: 6,
  ),

  // F8 → Sales Invoice (PRIMARY BILLING KEY)
  ShortcutDefinition(
    id: 'SALES_INVOICE',
    label: 'Sales Invoice',
    iconName: 'point_of_sale',
    route: '/billing_flow',
    actionType: ActionType.navigate,
    category: 'BILLING',
    requiredPermission: Permission.createBill,
    defaultKeyBinding: 'F8',
    isDefault: true,
    defaultSortOrder: 7,
  ),

  // F9 → Purchase
  ShortcutDefinition(
    id: 'PURCHASE',
    label: 'Purchase Entry',
    iconName: 'shopping_cart',
    route: '/purchase',
    actionType: ActionType.navigate,
    category: 'NAVIGATION',
    requiredPermission: Permission.createPurchase,
    defaultKeyBinding: 'F9',
    isDefault: true,
    defaultSortOrder: 8,
  ),

  // F10 → Reports
  ShortcutDefinition(
    id: 'REPORTS',
    label: 'Reports',
    iconName: 'analytics',
    route: '/reports',
    actionType: ActionType.navigate,
    category: 'NAVIGATION',
    requiredPermission: Permission.viewReports,
    defaultKeyBinding: 'F10',
    isDefault: true,
    defaultSortOrder: 9,
  ),

  // F11 → Settings
  ShortcutDefinition(
    id: 'SETTINGS',
    label: 'Settings',
    iconName: 'settings',
    route: '/settings',
    actionType: ActionType.navigate,
    category: 'SYSTEM',
    requiredPermission: Permission.manageSettings,
    defaultKeyBinding: 'F11',
    isDefault: true,
    defaultSortOrder: 10,
  ),

  // F12 → Configuration
  ShortcutDefinition(
    id: 'CONFIGURATION',
    label: 'Configuration',
    iconName: 'tune',
    route: '/configuration',
    actionType: ActionType.navigate,
    category: 'SYSTEM',
    requiredPermission: Permission.manageSettings,
    defaultKeyBinding: 'F12',
    isDefault: true,
    defaultSortOrder: 11,
  ),

  // ============================================================================
  // COMMON SHORTCUTS (CTRL+KEY) - EXPECTED BY ACCOUNTANTS
  // ============================================================================

  // Ctrl+N → New Record
  ShortcutDefinition(
    id: 'NEW_RECORD',
    label: 'New Record',
    iconName: 'add',
    route: null,
    actionType: ActionType.function,
    category: 'COMMON',
    requiredPermission: Permission.createBill,
    defaultKeyBinding: 'Ctrl+N',
    isDefault: true,
    defaultSortOrder: 20,
  ),

  // Ctrl+S → Save
  ShortcutDefinition(
    id: 'SAVE',
    label: 'Save',
    iconName: 'save',
    route: null,
    actionType: ActionType.function,
    category: 'COMMON',
    defaultKeyBinding: 'Ctrl+S',
    isDefault: true,
    defaultSortOrder: 21,
  ),

  // Ctrl+D → Delete
  ShortcutDefinition(
    id: 'DELETE',
    label: 'Delete',
    iconName: 'delete',
    route: null,
    actionType: ActionType.function,
    category: 'COMMON',
    requiredPermission: Permission.deleteBill,
    defaultKeyBinding: 'Ctrl+D',
    isDefault: true,
    defaultSortOrder: 22,
  ),

  // Ctrl+P → Print
  ShortcutDefinition(
    id: 'PRINT',
    label: 'Print',
    iconName: 'print',
    route: null,
    actionType: ActionType.function,
    category: 'COMMON',
    defaultKeyBinding: 'Ctrl+P',
    isDefault: true,
    defaultSortOrder: 23,
  ),

  // Ctrl+F → Search
  ShortcutDefinition(
    id: 'SEARCH',
    label: 'Search',
    iconName: 'search',
    route: null,
    actionType: ActionType.function,
    category: 'COMMON',
    defaultKeyBinding: 'Ctrl+F',
    isDefault: true,
    defaultSortOrder: 24,
  ),

  // Ctrl+E → Edit
  ShortcutDefinition(
    id: 'EDIT',
    label: 'Edit',
    iconName: 'edit',
    route: null,
    actionType: ActionType.function,
    category: 'COMMON',
    requiredPermission: Permission.editBill,
    defaultKeyBinding: 'Ctrl+E',
    isDefault: true,
    defaultSortOrder: 25,
  ),

  // Ctrl+L → Ledger
  ShortcutDefinition(
    id: 'LEDGER',
    label: 'Ledger',
    iconName: 'account_balance',
    route: '/party_ledger',
    actionType: ActionType.navigate,
    category: 'COMMON',
    requiredPermission: Permission.viewLedger,
    defaultKeyBinding: 'Ctrl+L',
    isDefault: true,
    defaultSortOrder: 26,
  ),

  // Ctrl+B → Backup
  ShortcutDefinition(
    id: 'BACKUP',
    label: 'Backup',
    iconName: 'cloud_upload',
    route: '/backup',
    actionType: ActionType.navigate,
    category: 'SYSTEM',
    requiredPermission: Permission.manageSettings,
    defaultKeyBinding: 'Ctrl+B',
    isDefault: true,
    defaultSortOrder: 27,
  ),

  // Ctrl+Q → Quit App
  ShortcutDefinition(
    id: 'QUIT',
    label: 'Quit App',
    iconName: 'exit_to_app',
    route: null,
    actionType: ActionType.function,
    category: 'SYSTEM',
    defaultKeyBinding: 'Ctrl+Q',
    isDefault: true,
    defaultSortOrder: 28,
  ),

  // Ctrl+A → Add Item (in billing context)
  ShortcutDefinition(
    id: 'ADD_ITEM',
    label: 'Add Item Row',
    iconName: 'add_circle',
    route: null,
    actionType: ActionType.function,
    category: 'BILLING',
    defaultKeyBinding: 'Ctrl+A',
    isDefault: true,
    defaultSortOrder: 29,
  ),

  // Alt+M → Focus Menu
  ShortcutDefinition(
    id: 'FOCUS_MENU',
    label: 'Focus Menu',
    iconName: 'menu',
    route: null,
    actionType: ActionType.function,
    category: 'NAVIGATION',
    defaultKeyBinding: 'Alt+M',
    isDefault: true,
    defaultSortOrder: 30,
  ),

  // ============================================================================
  // DAILY WORK SHORTCUTS (Original definitions preserved)
  // ============================================================================
  ShortcutDefinition(
    id: 'NEW_BILL',
    label: 'New Bill / Invoice',
    iconName: 'add_shopping_cart',
    route: '/billing_flow',
    actionType: ActionType.navigate,
    category: 'DAILY_WORK',
    requiredPermission: Permission.createBill,
    defaultKeyBinding: 'Ctrl+N',
    isDefault: true,
    defaultSortOrder: 1,
  ),
  ShortcutDefinition(
    id: 'LAST_TRANSACTION',
    label: 'Last Transaction',
    iconName: 'history',
    route: null, // Opens latest bill logic
    actionType: ActionType.function,
    category: 'DAILY_WORK',
    requiredPermission: Permission.viewReports,
    isDefault: true,
    defaultSortOrder: 2,
  ),
  ShortcutDefinition(
    id: 'RECEIVE_PAYMENT',
    label: 'Receive Payment',
    iconName: 'attach_money',
    route: '/payment-history',
    actionType: ActionType.navigate,
    category: 'DAILY_WORK',
    requiredPermission: Permission.receivePayment,
    defaultKeyBinding: 'Ctrl+P',
    isDefault: true,
    defaultSortOrder: 3,
  ),
  ShortcutDefinition(
    id: 'ADD_CUSTOMER',
    label: 'Add Customer',
    iconName: 'person_add',
    route: '/add_customer',
    actionType: ActionType.navigate,
    category: 'DAILY_WORK',
    requiredPermission: Permission.createCustomer,
    defaultKeyBinding: 'Ctrl+Shift+C',
    isDefault: true,
    defaultSortOrder: 4,
  ),
  ShortcutDefinition(
    id: 'CUSTOMER_LEDGER',
    label: 'Customer Ledger',
    iconName: 'account_balance',
    route: '/party_ledger',
    actionType: ActionType.navigate,
    category: 'DAILY_WORK',
    requiredPermission: Permission.viewLedger,
    isDefault: true,
    defaultSortOrder: 5,
  ),

  // INVENTORY
  ShortcutDefinition(
    id: 'LOW_STOCK',
    label: 'Low Stock Items',
    iconName: 'warning_amber',
    route: '/inventory',
    actionType: ActionType.navigate,
    category: 'INVENTORY',
    requiredPermission: Permission.viewStock,
    hasBadge: true, // Shows count of low stock items
    isDefault: true,
    defaultSortOrder: 10,
  ),

  // REPORTS
  ShortcutDefinition(
    id: 'TODAY_SALES',
    label: 'Today Sales',
    iconName: 'today',
    route: '/reports',
    actionType: ActionType.navigate,
    category: 'REPORTS',
    requiredPermission: Permission.viewReports,
    hasBadge: true, // Shows today's total
    isDefault: true,
    defaultSortOrder: 20,
  ),
  ShortcutDefinition(
    id: 'DAY_BOOK',
    label: 'Day Book',
    iconName: 'menu_book',
    route: '/daybook',
    actionType: ActionType.navigate,
    category: 'REPORTS',
    requiredPermission: Permission.viewCashBook,
    isDefault: true,
    defaultSortOrder: 21,
  ),

  // SYSTEM
  ShortcutDefinition(
    id: 'BACKUP_NOW',
    label: 'Backup Now',
    iconName: 'cloud_upload',
    route: '/backup',
    actionType: ActionType.navigate,
    category: 'SYSTEM',
    requiredPermission: Permission.manageSettings,
    isDefault: true,
    defaultSortOrder: 30,
  ),
  ShortcutDefinition(
    id: 'SYNC_STATUS',
    label: 'Sync Status',
    iconName: 'sync_problem',
    route: '/dev_health',
    actionType: ActionType.navigate,
    category: 'SYSTEM',
    requiredPermission: Permission.viewAuditLog,
    hasBadge: true, // Shows failed sync count
    isDefault: true,
    defaultSortOrder: 31,
  ),

  // BUSINESS-TYPE SPECIFIC: CLINIC
  ShortcutDefinition(
    id: 'NEW_PATIENT',
    label: 'New Patient',
    iconName: 'personal_injury',
    route: '/patients', // Navigate to patients with add mode
    actionType: ActionType.navigate,
    category: 'DAILY_WORK',
    allowedBusinessTypes: ['clinic'],
    requiredPermission: Permission.createCustomer,
    defaultSortOrder: 2,
    isDefault: true,
  ),
  ShortcutDefinition(
    id: 'NEW_PRESCRIPTION',
    label: 'New Prescription',
    iconName: 'medication',
    route: '/prescriptions',
    actionType: ActionType.navigate,
    category: 'DAILY_WORK',
    allowedBusinessTypes: ['clinic'],
    requiredPermission: Permission.createBill,
    defaultSortOrder: 3,
    isDefault: true,
  ),

  // BUSINESS-TYPE SPECIFIC: GROCERY
  ShortcutDefinition(
    id: 'POS_MODE',
    label: 'POS Mode',
    iconName: 'point_of_sale',
    route: '/billing_flow',
    actionType: ActionType.navigate,
    category: 'DAILY_WORK',
    allowedBusinessTypes: ['grocery'],
    requiredPermission: Permission.createBill,
    defaultKeyBinding: 'F1',
    defaultSortOrder: 1,
    isDefault: true,
  ),
];
