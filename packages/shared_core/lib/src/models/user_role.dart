enum UserRole {
  admin,
  manager,
  billingStaff,
  viewOnly;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.billingStaff:
        return 'Billing Staff';
      case UserRole.viewOnly:
        return 'View Only';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'billing_staff':
      case 'billingstaff':
        return UserRole.billingStaff;
      default:
        return UserRole.viewOnly;
    }
  }
}
