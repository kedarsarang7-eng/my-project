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
  ];
}
