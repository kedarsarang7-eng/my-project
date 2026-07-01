// ============================================================================
// ROLE PICKER SCREEN
// ============================================================================
// Shown after authentication when a user has multiple role/business assignments.
// Allows the user to select which business+role to use for this session.
//
// - Lists all available BusinessUser assignments
// - Shows business name, role, and a role icon
// - On tap, calls SessionManager.selectRole(selected) and proceeds to dashboard
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';
import '../../services/role_management_service.dart';

/// Full-screen picker shown when user has multiple role/business assignments.
class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final roles = session.availableRoles ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  // Header
                  Icon(
                    Icons.switch_account_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Role',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have access to multiple businesses. '
                    'Choose which one to use for this session.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Role list
                  Expanded(
                    child: ListView.separated(
                      itemCount: roles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final bu = roles[index];
                        return _RoleTile(
                          businessUser: bu,
                          onTap: () => _onRoleSelected(context, session, bu),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onRoleSelected(
    BuildContext context,
    SessionManager session,
    BusinessUser selected,
  ) {
    session.selectRole(selected);
    // SessionManager notifies listeners → AuthGate rebuilds → routes to vendor flow
  }
}

/// A single tile in the role picker list.
class _RoleTile extends StatelessWidget {
  final BusinessUser businessUser;
  final VoidCallback onTap;

  const _RoleTile({required this.businessUser, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Role icon
              CircleAvatar(
                backgroundColor: _roleColor(
                  businessUser.role,
                  colorScheme,
                ).withOpacity(0.15),
                child: Icon(
                  _roleIcon(businessUser.role),
                  color: _roleColor(businessUser.role, colorScheme),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Business name + role label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessUser.businessId,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleDisplayName(businessUser.role),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _roleColor(businessUser.role, colorScheme),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(Icons.chevron_right_rounded, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Icons.admin_panel_settings_rounded;
      case UserRole.manager:
        return Icons.manage_accounts_rounded;
      case UserRole.accountant:
        return Icons.account_balance_rounded;
      case UserRole.staff:
        return Icons.badge_rounded;
      case UserRole.pharmacist:
        return Icons.medication_rounded;
      case UserRole.waiter:
        return Icons.restaurant_rounded;
      case UserRole.chef:
        return Icons.soup_kitchen_rounded;
      case UserRole.captain:
        return Icons.supervisor_account_rounded;
      case UserRole.doctor:
        return Icons.medical_services_rounded;
      case UserRole.receptionist:
        return Icons.assignment_ind_rounded;
      case UserRole.nurse:
        return Icons.health_and_safety_rounded;
      case UserRole.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color _roleColor(UserRole role, ColorScheme colorScheme) {
    switch (role) {
      case UserRole.owner:
        return colorScheme.primary;
      case UserRole.manager:
        return Colors.teal;
      case UserRole.accountant:
        return Colors.indigo;
      case UserRole.staff:
        return Colors.orange;
      case UserRole.pharmacist:
        return Colors.green;
      case UserRole.waiter:
        return Colors.amber;
      case UserRole.chef:
        return Colors.deepOrange;
      case UserRole.captain:
        return Colors.blueGrey;
      case UserRole.doctor:
        return Colors.blue;
      case UserRole.receptionist:
        return Colors.purple;
      case UserRole.nurse:
        return Colors.pink;
      case UserRole.unknown:
        return Colors.grey;
    }
  }

  String _roleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.manager:
        return 'Manager';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.staff:
        return 'Staff';
      case UserRole.pharmacist:
        return 'Pharmacist';
      case UserRole.waiter:
        return 'Waiter';
      case UserRole.chef:
        return 'Chef';
      case UserRole.captain:
        return 'Captain';
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.receptionist:
        return 'Receptionist';
      case UserRole.nurse:
        return 'Nurse';
      case UserRole.unknown:
        return 'Unknown';
    }
  }
}
