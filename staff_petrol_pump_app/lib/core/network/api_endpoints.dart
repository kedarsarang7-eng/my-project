class ApiEndpoints {
  static const String v1AuthLogin = '/auth/login';
  static const String v1AuthLogout = '/auth/logout';
  static const String v1AuthRefresh = '/auth/refresh';
  static const String availableRoles = '/users/available-roles';
  static const String validateLicense = '/license/validate';
  static const String activateLicense = '/license/activate';
  // Auth endpoints
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Tenant endpoints
  static const String tenants = '/tenants';
  static String tenant(String tenantId) => '/tenants/$tenantId';

  // Admin tenant endpoints
  static const String adminTenants = '/admin/tenants';
  static String adminTenant(String tenantId) => '/admin/tenants/$tenantId';

  // User endpoints
  static const String users = '/users';
  static const String inviteUser = '/users/invite';
  static String user(String userId) => '/users/$userId';
  static String userRole(String userId) => '/users/$userId/role';

  // Admin user endpoints
  static const String adminUsers = '/admin/users';

  // Billing endpoints
  static const String billingPlans = '/billing/plans';
  static const String subscribe = '/billing/subscribe';
  static const String invoices = '/billing/invoices';
  static String invoice(String invoiceId) => '/billing/invoices/$invoiceId';
  static const String cancelSubscription = '/billing/cancel';

  // Audit endpoints
  static const String auditLogs = '/audit/logs';
  static const String auditExport = '/audit/export';

  // FuelPOS Dashboard endpoints
  static const String fuelposDashboardSummary = '/dashboard/summary';
  static const String fuelposFuelChart = '/dashboard/fuel-chart';
  static const String fuelposRevenueBreakdown = '/dashboard/revenue-breakdown';
  static const String fuelposAlerts = '/dashboard/alerts';
  static const String fuelposTransactions = '/transactions';
}