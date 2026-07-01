/// Role-Based Access Control (RBAC) Layer for DukanX
///
/// Combines business type capabilities with user role restrictions.
/// Enforces security policies: Owner (full), Manager (limited delete),
/// Staff (billing only), Accountant (reports only)
library;

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/models/user_role.dart';

export 'package:dukanx/core/models/user_role.dart';

extension IsolationUserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.owner:
        return 'OWNER';
      case UserRole.manager:
        return 'MANAGER';
      case UserRole.staff:
        return 'STAFF';
      case UserRole.accountant:
        return 'ACCOUNTANT';
      case UserRole.pharmacist:
        return 'PHARMACIST';
      case UserRole.waiter:
        return 'WAITER';
      case UserRole.chef:
        return 'CHEF';
      case UserRole.captain:
        return 'CAPTAIN';
      case UserRole.doctor:
        return 'DOCTOR';
      case UserRole.receptionist:
        return 'RECEPTIONIST';
      case UserRole.nurse:
        return 'NURSE';
      case UserRole.unknown:
        return 'UNKNOWN';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'OWNER':
        return UserRole.owner;
      case 'MANAGER':
        return UserRole.manager;
      case 'SALESMAN':
      case 'SALES':
      case 'STAFF':
      case 'CASHIER':
        return UserRole.staff;
      case 'ACCOUNTANT':
        return UserRole.accountant;
      case 'PHARMACIST':
        return UserRole.pharmacist;
      case 'WAITER':
        return UserRole.waiter;
      case 'CHEF':
      case 'COOK':
        return UserRole.chef;
      case 'CAPTAIN':
        return UserRole.captain;
      case 'DOCTOR':
      case 'DR':
        return UserRole.doctor;
      case 'RECEPTIONIST':
      case 'FRONT_DESK':
        return UserRole.receptionist;
      case 'NURSE':
        return UserRole.nurse;
      case 'VIEWER':
      case 'READONLY':
      case 'TECHNICIAN':
        return UserRole.staff; // Map legacy roles to staff
      default:
        return UserRole.unknown;
    }
  }
}

/// Operation types for CRUD actions
enum OperationType {
  create,
  read,
  update,
  delete,
  print,
  export,
  approve, // For approvals (estimates, POs)
}

/// RBAC Configuration per role
class RolePermissions {
  /// Capabilities that are READ-ONLY for this role (cannot create/update/delete)
  final Set<BusinessCapability> readOnlyCapabilities;

  /// Capabilities that are DENIED entirely for this role
  final Set<BusinessCapability> deniedCapabilities;

  /// Operations denied globally for this role (across all capabilities)
  final Set<OperationType> deniedOperations;

  /// Specific capability + operation combinations that are denied
  final Map<BusinessCapability, Set<OperationType>> deniedCapabilityOperations;

  const RolePermissions({
    this.readOnlyCapabilities = const {},
    this.deniedCapabilities = const {},
    this.deniedOperations = const {},
    this.deniedCapabilityOperations = const {},
  });
}

/// RBAC Registry - Defines permissions per role
final Map<UserRole, RolePermissions> rolePermissionsRegistry = {
  UserRole.owner: const RolePermissions(
    // Owner has no restrictions - full access
  ),

  UserRole.manager: const RolePermissions(
    // Manager cannot delete critical business records
    deniedOperations: {OperationType.delete},
    // Manager can do everything else
  ),

  UserRole.staff: const RolePermissions(
    // Staff can do basic billing/invoicing operations
    deniedCapabilities: {
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
    },
    // Cannot delete anything
    deniedOperations: {OperationType.delete},
    // Read-only on inventory and reports
    readOnlyCapabilities: {
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useInventorySearch,
      BusinessCapability.useDeadStock,
      BusinessCapability.useLowStockAlert,
      BusinessCapability.useGeneralAlerts,
      BusinessCapability.useDailySnapshot,
      BusinessCapability.useRevenueOverview,
    },
  ),

  UserRole.accountant: const RolePermissions(
    // Accountant can only view financial data and reports
    deniedCapabilities: {
      BusinessCapability.useProductAdd,
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBarcodeScanner,
    },
    // Read-only everything
    deniedOperations: {
      OperationType.create,
      OperationType.update,
      OperationType.delete,
    },
    // Explicit read-only on these financial capabilities
    readOnlyCapabilities: {
      BusinessCapability.useInvoiceList,
      BusinessCapability.useInvoiceSearch,
      BusinessCapability.useDailySnapshot,
      BusinessCapability.useRevenueOverview,
      BusinessCapability.usePurchaseRegister,
    },
  ),

  // Restaurant roles — scoped to restaurant operations only.
  UserRole.waiter: const RolePermissions(
    // Waiter: create orders and view tables — no delete, no reports, no admin.
    deniedOperations: {OperationType.delete},
    deniedCapabilities: {
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
    },
    readOnlyCapabilities: {
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useInventorySearch,
    },
  ),

  UserRole.chef: const RolePermissions(
    // Chef: view KDS and update order status — no billing, no admin.
    deniedOperations: {OperationType.delete, OperationType.create},
    deniedCapabilities: {
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
      BusinessCapability.useInvoiceCreate,
    },
    readOnlyCapabilities: {
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useDailySnapshot,
    },
  ),

  UserRole.captain: const RolePermissions(
    // Captain: all waiter + assign tables + view reports — no delete, no admin.
    deniedOperations: {OperationType.delete},
    deniedCapabilities: {
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
    },
    readOnlyCapabilities: {
      BusinessCapability.useRevenueOverview,
      BusinessCapability.useDailySnapshot,
    },
  ),

  // Clinic roles — scoped to clinic/OPD operations.
  // Doctor: full clinical access — diagnosis, private notes, prescriptions,
  // vitals, patient management, revenue view.
  UserRole.doctor: const RolePermissions(
    // Doctor cannot delete business records but has full clinical access.
    deniedOperations: {OperationType.delete},
    deniedCapabilities: {
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
    },
    readOnlyCapabilities: {
      BusinessCapability.useRevenueOverview,
      BusinessCapability.useDailySnapshot,
    },
  ),

  // Receptionist: front-desk — book appointments, register patients, billing.
  // CANNOT access diagnosis or private clinical notes (enforced at widget level
  // via ClinicRole integration).
  UserRole.receptionist: const RolePermissions(
    deniedOperations: {OperationType.delete},
    deniedCapabilities: {
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
    },
    readOnlyCapabilities: {
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useRevenueOverview,
      BusinessCapability.useDailySnapshot,
    },
  ),

  // Nurse: clinical support — vitals capture, patient prep, medication admin.
  // Cannot write diagnosis/private notes (enforced at widget level via
  // ClinicRole integration). No billing, no admin.
  UserRole.nurse: const RolePermissions(
    deniedOperations: {OperationType.delete, OperationType.create},
    deniedCapabilities: {
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useJobSheets,
      BusinessCapability.useRepairStatus,
      BusinessCapability.useBuyback,
      BusinessCapability.useExchange,
      BusinessCapability.useInvoiceCreate,
    },
    readOnlyCapabilities: {
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useDailySnapshot,
    },
  ),
};

/// Enhanced Feature Resolver with RBAC
class RBACResolver {
  /// Check if user can access a capability with their role
  static bool canAccess({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
    OperationType operation = OperationType.read,
  }) {
    // First check business type capability
    if (!FeatureResolver.canAccess(businessType, capability)) {
      return false;
    }

    // Owner has full access
    if (userRole == UserRole.owner) {
      return true;
    }

    final permissions = rolePermissionsRegistry[userRole];
    if (permissions == null) {
      return false; // Unknown role = deny
    }

    // Check if capability is entirely denied
    if (permissions.deniedCapabilities.contains(capability)) {
      return false;
    }

    // Check if operation is globally denied
    if (permissions.deniedOperations.contains(operation)) {
      return false;
    }

    // Check specific capability + operation denial
    final deniedOps = permissions.deniedCapabilityOperations[capability];
    if (deniedOps != null && deniedOps.contains(operation)) {
      return false;
    }

    // Check read-only restriction
    if (permissions.readOnlyCapabilities.contains(capability)) {
      // Read-only means only READ is allowed
      return operation == OperationType.read ||
          operation == OperationType.print;
    }

    return true;
  }

  /// Enforce access - throws SecurityException if denied
  static void enforceAccess({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
    OperationType operation = OperationType.read,
  }) {
    if (!canAccess(
      businessType: businessType,
      userRole: userRole,
      capability: capability,
      operation: operation,
    )) {
      throw SecurityException(
        'Access Denied: Role [${userRole.value}] cannot perform [$operation] '
        'on [${capability.name}] for business type [$businessType]',
      );
    }
  }

  /// Check if user can delete an entity
  static bool canDelete({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
  }) {
    return canAccess(
      businessType: businessType,
      userRole: userRole,
      capability: capability,
      operation: OperationType.delete,
    );
  }

  /// Check if user can create an entity
  static bool canCreate({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
  }) {
    return canAccess(
      businessType: businessType,
      userRole: userRole,
      capability: capability,
      operation: OperationType.create,
    );
  }

  /// Check if user can update an entity
  static bool canUpdate({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
  }) {
    return canAccess(
      businessType: businessType,
      userRole: userRole,
      capability: capability,
      operation: OperationType.update,
    );
  }

  /// Get all accessible capabilities for a role
  static Set<BusinessCapability> getAccessibleCapabilities({
    required String businessType,
    required UserRole userRole,
    OperationType operation = OperationType.read,
  }) {
    final allCapabilities = FeatureResolver.getCapabilities(businessType);
    return allCapabilities
        .where(
          (cap) => canAccess(
            businessType: businessType,
            userRole: userRole,
            capability: cap,
            operation: operation,
          ),
        )
        .toSet();
  }

  /// Get UI visibility configuration for a role
  static Map<String, bool> getUIVisibility({
    required String businessType,
    required UserRole userRole,
  }) {
    return {
      'canDeleteInvoices': canDelete(
        businessType: businessType,
        userRole: userRole,
        capability: BusinessCapability.useInvoiceCreate,
      ),
      'canDeleteIMEI': canDelete(
        businessType: businessType,
        userRole: userRole,
        capability: BusinessCapability.useIMEI,
      ),
      'canDeleteServiceJobs': canDelete(
        businessType: businessType,
        userRole: userRole,
        capability: BusinessCapability.useJobSheets,
      ),
      'canAccessPurchase': canAccess(
        businessType: businessType,
        userRole: userRole,
        capability: BusinessCapability.usePurchaseOrder,
        operation: OperationType.read,
      ),
      'canAccessReports': canAccess(
        businessType: businessType,
        userRole: userRole,
        capability: BusinessCapability.useRevenueOverview,
        operation: OperationType.read,
      ),
      'canCreateInvoices': canCreate(
        businessType: businessType,
        userRole: userRole,
        capability: BusinessCapability.useInvoiceCreate,
      ),
      'canModifyInventory': canUpdate(
        businessType: businessType,
        userRole: userRole,
        capability: BusinessCapability.useStockEntry,
      ),
    };
  }
}

/// Mixin for repositories to enforce RBAC
mixin RBACEnforcementMixin {
  void enforceDeletePermission({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
    String? entityId,
  }) {
    RBACResolver.enforceAccess(
      businessType: businessType,
      userRole: userRole,
      capability: capability,
      operation: OperationType.delete,
    );
  }

  void enforceCreatePermission({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
  }) {
    RBACResolver.enforceAccess(
      businessType: businessType,
      userRole: userRole,
      capability: capability,
      operation: OperationType.create,
    );
  }

  void enforceUpdatePermission({
    required String businessType,
    required UserRole userRole,
    required BusinessCapability capability,
    String? entityId,
  }) {
    RBACResolver.enforceAccess(
      businessType: businessType,
      userRole: userRole,
      capability: capability,
      operation: OperationType.update,
    );
  }
}
