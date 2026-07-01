/// RBAC Manager
/// Fulfills Phase 3 Granular Role-Based Access Control
/// Replaces simple route-level guards with detailed action permissions per module.
class RbacManager {
  
  // Define granular permissions
  static const String viewSales = 'sales:view';
  static const String createSales = 'sales:create';
  static const String editSales = 'sales:edit';
  static const String deleteSales = 'sales:delete';
  
  static const String viewInventory = 'inventory:view';
  static const String editStock = 'inventory:edit';
  
  static const String viewReports = 'reports:view';
  static const String exportData = 'reports:export';

  static const String approvePurchaseOrders = 'purchase:approve';

  /// Roles mapped to permissions
  static final Map<String, List<String>> _rolePermissions = {
    'OWNER': [
      viewSales, createSales, editSales, deleteSales, 
      viewInventory, editStock, 
      viewReports, exportData, 
      approvePurchaseOrders
    ],
    'MANAGER': [
      viewSales, createSales, editSales, 
      viewInventory, editStock, 
      viewReports
    ],
    'CASHIER': [
      viewSales, createSales, 
      viewInventory
    ],
    'ACCOUNTANT': [
      viewSales, viewReports, exportData
    ]
  };

  /// Check if a user role has a specific permission
  static bool hasPermission(String role, String permission) {
    if (role == 'SUPERADMIN') return true;
    final perms = _rolePermissions[role.toUpperCase()] ?? [];
    return perms.contains(permission);
  }
}
