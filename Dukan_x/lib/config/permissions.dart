class Permissions {
  static const viewInvoices = 'view_invoices';
  static const createInvoices = 'create_invoices';
  static const viewReports = 'view_reports';
  static const exportReports = 'export_reports';
  static const viewClients = 'view_clients';
  static const viewCustomers = 'view_customers';
  static const viewProducts = 'view_products';
  static const manageStaff = 'manage_staff';
  static const viewAnalytics = 'view_analytics';
  static const systemSettings = 'system_settings';
  static const userManagement = 'user_management';

  // Decoration & Catering (DC) fine-grained permissions (additive).
  // Requirement 3.7: replaces borrowed viewInvoices/createInvoices on DC
  // booking routes so event access can be granted independently of invoice
  // access. See legacy_routes.dart's /dc/bookings and /dc/bookings/new.
  static const viewEvents = 'view_events';
  static const createEvents = 'create_events';

  static const all = <String>[
    viewInvoices,
    createInvoices,
    viewReports,
    exportReports,
    viewClients,
    viewCustomers,
    viewProducts,
    manageStaff,
    viewAnalytics,
    systemSettings,
    userManagement,
    viewEvents,
    createEvents,
  ];
}
