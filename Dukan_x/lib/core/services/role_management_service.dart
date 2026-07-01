import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/models/user_role.dart';

export 'package:dukanx/core/models/user_role.dart';

/// Extension helpers for [UserRole] — shared across the codebase.
extension UserRoleExtension on UserRole {
  /// Parse a role string from backend/metadata into [UserRole].
  /// Falls back to [UserRole.unknown] for unknown strings.
  static UserRole fromString(String raw) {
    final normalized = raw.toLowerCase().trim();
    for (final role in UserRole.values) {
      if (role.name == normalized) return role;
    }
    // Common aliases from legacy role names or backend variants
    switch (normalized) {
      case 'admin':
        return UserRole.owner;
      case 'salesman':
      case 'billing_staff':
      case 'billingstaff':
      case 'cashier':
        return UserRole.staff;
      case 'ca':
      case 'read_only':
      case 'readonly':
      case 'viewer':
        return UserRole.accountant;
      case 'cook':
        return UserRole.chef;
      default:
        return UserRole.unknown;
    }
  }
}

/// Permission types for granular access control.
enum Permission {
  // Bill Operations
  createBill,
  editBill,
  deleteBill,
  reverseBill,
  printBill,

  // Customer Operations
  createCustomer,
  editCustomer,
  deleteCustomer,
  viewCustomerBalance,

  // Supplier Operations
  createSupplier,
  editSupplier,
  deleteSupplier,
  createPurchase,
  editPurchase,

  // Stock Operations
  viewStock,
  editStock,
  adjustStock,

  // Financial Operations
  viewReports,
  viewCashBook,
  viewLedger,
  makePayment,
  receivePayment,
  journalEntry,

  // Admin Operations
  lockPeriod,
  unlockPeriod,
  closeFinancialYear,
  manageUsers,
  manageSettings,
  viewAuditLog,

  // GST Operations
  viewGstReports,
  fileGstReturns,

  // Pharmacy Operations (additive — pharmacist least-privilege set)
  capturePrescription, // Capture a prescription at dispensing (R10.2)
  registerEntry, // Narcotic / H1 compliance register entry (R10.2)
  // Fraud Prevention (New)
  viewProfit,
  viewMargins,
  applyHighDiscount,
  processRefund,
  acceptCashMismatch,
  closeCashDay,
  viewSecurityDashboard,
  manageFraudAlerts,
}

/// Role-based permission mapping.
class RolePermissions {
  static const Map<UserRole, Set<Permission>> _permissions = {
    UserRole.owner: {
      // All permissions
      Permission.createBill, Permission.editBill, Permission.deleteBill,
      Permission.reverseBill, Permission.printBill,
      Permission.createCustomer, Permission.editCustomer,
      Permission.deleteCustomer,
      Permission.viewCustomerBalance,
      Permission.createSupplier, Permission.editSupplier,
      Permission.deleteSupplier,
      Permission.createPurchase, Permission.editPurchase,
      Permission.viewStock, Permission.editStock, Permission.adjustStock,
      Permission.viewReports, Permission.viewCashBook, Permission.viewLedger,
      Permission.makePayment, Permission.receivePayment,
      Permission.journalEntry,
      Permission.lockPeriod, Permission.unlockPeriod,
      Permission.closeFinancialYear,
      Permission.manageUsers, Permission.manageSettings,
      Permission.viewAuditLog,
      Permission.viewGstReports, Permission.fileGstReturns,
      // Fraud Prevention (Owner-only)
      Permission.viewProfit, Permission.viewMargins,
      Permission.applyHighDiscount, Permission.processRefund,
      Permission.acceptCashMismatch, Permission.closeCashDay,
      Permission.viewSecurityDashboard, Permission.manageFraudAlerts,
    },
    UserRole.accountant: {
      Permission.createBill, Permission.editBill, Permission.reverseBill,
      Permission.printBill,
      Permission.createCustomer, Permission.editCustomer,
      Permission.viewCustomerBalance,
      Permission.createSupplier, Permission.editSupplier,
      Permission.createPurchase, Permission.editPurchase,
      Permission.viewStock, Permission.adjustStock,
      Permission.viewReports, Permission.viewCashBook, Permission.viewLedger,
      Permission.makePayment, Permission.receivePayment,
      Permission.journalEntry,
      Permission.lockPeriod,
      Permission.viewAuditLog,
      Permission.viewGstReports, Permission.fileGstReturns,
      // NOT: deleteBill, deleteCustomer, deleteSupplier, unlockPeriod,
      //      closeFinancialYear, manageUsers, manageSettings
    },
    UserRole.manager: {
      Permission.createBill, Permission.editBill, Permission.printBill,
      Permission.createCustomer, Permission.editCustomer,
      Permission.viewCustomerBalance,
      Permission.createSupplier, Permission.editSupplier,
      Permission.createPurchase,
      Permission.viewStock, Permission.adjustStock,
      Permission.viewReports, Permission.viewCashBook,
      Permission.makePayment, Permission.receivePayment,
      // NOT: deleteBill, reverseBill, journalEntry, lockPeriod
    },
    UserRole.staff: {
      Permission.createBill, Permission.printBill,
      Permission.createCustomer, Permission.viewCustomerBalance,
      Permission.viewStock,
      Permission.receivePayment,
      Permission.closeCashDay,
      // Staff: General staff access — billing, basic operations
    },
    // Pharmacist: least-privilege dispensing role (R10.2/R10.3).
    // GRANTS exactly: dispensing (createBill+printBill), prescription capture
    // (capturePrescription), batch/expiry view (viewStock), narcotic/H1
    // register entry (registerEntry) — and nothing else.
    // DENIES (by omission): pricing override, business settings
    // (manageSettings), financial reports (viewReports), user management
    // (manageUsers), and every other permission.
    UserRole.pharmacist: {
      Permission.createBill, Permission.printBill, // dispensing operations
      Permission.capturePrescription, // prescription capture
      Permission.viewStock, // batch and expiry view
      Permission.registerEntry, // narcotic / H1 register entry
    },
    // Restaurant roles (R2.14) — additive, least-privilege per function.
    // Waiter: front-of-house — create orders and view tables.
    UserRole.waiter: {
      Permission.createBill, Permission.printBill, // create/print orders
      Permission.viewStock, // view tables (reuses viewStock semantics)
    },
    // Chef: kitchen staff — view KDS and update order status.
    UserRole.chef: {
      Permission.viewStock, // view KDS (kitchen display)
      Permission.editBill, // update order status
    },
    // Captain: floor captain — all waiter + assign tables + view reports.
    UserRole.captain: {
      Permission.createBill, Permission.printBill, // create/print orders
      Permission.editBill, // assign tables / modify orders
      Permission.viewStock, // view tables
      Permission.viewReports, // view reports
      Permission.createCustomer, // assign tables to customers
      Permission.viewCustomerBalance, // view customer info
    },
    // Clinic roles — additive, least-privilege per clinical function.
    // Doctor: full clinical access — diagnosis, prescriptions, patient mgmt,
    // billing, reports.
    UserRole.doctor: {
      Permission.createBill, Permission.editBill, Permission.printBill,
      Permission.createCustomer, Permission.editCustomer, // patient management
      Permission.viewCustomerBalance,
      Permission.viewStock, // view medicine stock
      Permission.viewReports, Permission.viewCashBook,
      Permission.makePayment, Permission.receivePayment,
      Permission.capturePrescription, // prescribe
    },
    // Receptionist: front-desk — appointments, patient registration, billing.
    // CANNOT access diagnosis/private notes (widget-level gate via ClinicRole).
    UserRole.receptionist: {
      Permission.createBill, Permission.printBill, // billing/invoicing
      Permission.createCustomer, Permission.editCustomer, // register patients
      Permission.viewCustomerBalance,
      Permission.viewStock, // view medicine availability
      Permission.receivePayment,
    },
    // Nurse: clinical support — vitals, patient prep, medication admin.
    // Cannot write diagnosis/private notes (widget-level gate via ClinicRole).
    UserRole.nurse: {
      Permission.viewStock, // view medicines/supplies
      Permission.createCustomer, // register patients in emergencies
      Permission.viewCustomerBalance,
    },
  };

  /// Check if a role has a specific permission.
  static bool hasPermission(UserRole role, Permission permission) {
    return _permissions[role]?.contains(permission) ?? false;
  }

  /// Get all permissions for a role.
  static Set<Permission> getPermissions(UserRole role) {
    return _permissions[role] ?? {};
  }

  /// Check if a role can perform a sensitive action.
  static bool canPerformSensitiveAction(UserRole role) {
    return role == UserRole.owner || role == UserRole.accountant;
  }
}

/// Business User - Links a user to a business with a role.
class BusinessUser {
  final String id;
  final String businessId;
  final String userId;
  final String email;
  final String name;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? lastLoginAt;

  const BusinessUser({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.createdBy,
    this.lastLoginAt,
  });

  factory BusinessUser.fromMap(String id, Map<String, dynamic> map) {
    return BusinessUser(
      id: id,
      businessId: map['businessId'] ?? '',
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.unknown,
      ),
      isActive: map['isActive'] ?? true,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      createdBy: map['createdBy'],
      lastLoginAt: _parseDate(map['lastLoginAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'userId': userId,
      'email': email,
      'name': name,
      'role': role.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
    };
  }

  bool hasPermission(Permission permission) {
    return RolePermissions.hasPermission(role, permission);
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Role Management Service
class RoleManagementService {
  ApiClient get _api => sl<ApiClient>();
  RoleManagementService();

  /// Add a user to a business with a specific role.
  Future<BusinessUser> addUserToBusiness({
    required String businessId,
    required String userId,
    required String email,
    required String name,
    required UserRole role,
    required String addedBy,
  }) async {
    final id = '${businessId}_$userId';
    final user = BusinessUser(
      id: id,
      businessId: businessId,
      userId: userId,
      email: email,
      name: name,
      role: role,
      createdAt: DateTime.now(),
      createdBy: addedBy,
    );

    await _api.collection('business_users').doc(id).set(user.toFirestore());

    return user;
  }

  /// Get a user's role and permissions for a business.
  Future<BusinessUser?> getBusinessUser(
    String businessId,
    String userId,
  ) async {
    final doc = await _api
        .collection('business_users')
        .doc('${businessId}_$userId')
        .get();

    if (!doc.exists) return null;
    return BusinessUser.fromMap(doc.id, doc.data()!);
  }

  /// Check if user has permission for an action.
  Future<bool> checkPermission(
    String businessId,
    String userId,
    Permission permission,
  ) async {
    final user = await getBusinessUser(businessId, userId);
    if (user == null) return false;
    return user.hasPermission(permission);
  }

  /// Update a user's role.
  Future<void> updateRole(
    String businessId,
    String userId,
    UserRole newRole, {
    required String updatedBy,
  }) async {
    await _api
        .collection('business_users')
        .doc('${businessId}_$userId')
        .update({
          'role': newRole.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        });
  }

  /// Get all users for a business.
  Future<List<BusinessUser>> getBusinessUsers(String businessId) async {
    final snapshot = await _api
        .collection('business_users')
        .where('businessId', isEqualTo: businessId)
        .get();

    return snapshot.docs
        .map((doc) => BusinessUser.fromMap(doc.id, doc.data()))
        .toList();
  }
}
