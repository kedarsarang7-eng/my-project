// ============================================================================
// ROLE GUARD WIDGET
// ============================================================================
// Protects widgets based on clinic role
// Shows fallback widget if role doesn't have permission
// Supports conditional rendering based on multiple roles
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/clinic_dashboard_models.dart';
import '../providers/clinic_dashboard_providers.dart';

/// A widget that conditionally renders its child based on the user's clinic role.
class RoleGuard extends ConsumerWidget {
  final Widget child;
  final List<ClinicRole> allowedRoles;
  final Widget? fallback;
  final bool showError;

  const RoleGuard({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.fallback,
    this.showError = false,
  });

  /// Factory constructor for admin-only widgets
  factory RoleGuard.admin({
    Key? key,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const [ClinicRole.admin],
      fallback: fallback,
      child: child,
    );
  }

  /// Factory constructor for doctor-only widgets
  factory RoleGuard.doctor({
    Key? key,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const [ClinicRole.doctor, ClinicRole.admin],
      fallback: fallback,
      child: child,
    );
  }

  /// Factory constructor for clinical staff (doctor + nurse)
  factory RoleGuard.clinical({
    Key? key,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const [ClinicRole.doctor, ClinicRole.nurse, ClinicRole.admin],
      fallback: fallback,
      child: child,
    );
  }

  /// Factory constructor for front desk (receptionist + admin)
  factory RoleGuard.frontDesk({
    Key? key,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const [ClinicRole.receptionist, ClinicRole.admin],
      fallback: fallback,
      child: child,
    );
  }

  /// Factory constructor for billing access
  factory RoleGuard.billing({
    Key? key,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const [ClinicRole.admin, ClinicRole.receptionist],
      fallback: fallback,
      child: child,
    );
  }

  /// Factory constructor for inventory access
  factory RoleGuard.inventory({
    Key? key,
    required Widget child,
    Widget? fallback,
  }) {
    return RoleGuard(
      key: key,
      allowedRoles: const [ClinicRole.admin, ClinicRole.nurse, ClinicRole.pharmacist],
      fallback: fallback,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicRole? userRole = ref.watch(clinicRoleProvider);

    // Check if user has required role
    final hasPermission = userRole != null && allowedRoles.contains(userRole);

    if (hasPermission) {
      return child;
    }

    // Return fallback or empty container
    if (fallback != null) {
      return fallback!;
    }

    if (showError) {
      return _AccessDeniedWidget(
        requiredRoles: allowedRoles,
      );
    }

    return const SizedBox.shrink();
  }
}

/// Widget shown when access is denied
class _AccessDeniedWidget extends StatelessWidget {
  final List<ClinicRole> requiredRoles;

  const _AccessDeniedWidget({
    required this.requiredRoles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Access Denied',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need ${_formatRoles(requiredRoles)} permissions to view this.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRoles(List<ClinicRole> roles) {
    if (roles.length == 1) {
      return roles.first.displayName;
    }
    final roleNames = roles.map((r) => r.displayName).toList();
    return '${roleNames.sublist(0, roleNames.length - 1).join(', ')} or ${roleNames.last}';
  }
}

/// A widget that shows different content based on the user's role
class RoleBasedWidget extends ConsumerWidget {
  final Widget admin;
  final Widget doctor;
  final Widget? nurse;
  final Widget? receptionist;
  final Widget? fallback;

  const RoleBasedWidget({
    super.key,
    required this.admin,
    required this.doctor,
    this.nurse,
    this.receptionist,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicRole? userRole = ref.watch(clinicRoleProvider);

    switch (userRole) {
      case ClinicRole.admin:
        return admin;
      case ClinicRole.doctor:
        return doctor;
      case ClinicRole.nurse:
        return nurse ?? fallback ?? const SizedBox.shrink();
      case ClinicRole.receptionist:
        return receptionist ?? fallback ?? const SizedBox.shrink();
      default:
        return fallback ?? const SizedBox.shrink();
    }
  }
}

/// Extension to check role permissions easily
extension RoleCheckExtension on WidgetRef {
  ClinicRole? get currentClinicRole {
    return read(clinicRoleProvider);
  }

  bool hasClinicRole(ClinicRole role) {
    return currentClinicRole == role;
  }

  bool hasAnyClinicRole(List<ClinicRole> roles) {
    return currentClinicRole != null && roles.contains(currentClinicRole);
  }
}
