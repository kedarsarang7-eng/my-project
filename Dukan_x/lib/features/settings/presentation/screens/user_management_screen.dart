// ============================================================================
// USER MANAGEMENT SCREEN (RBAC UI)
// ============================================================================
// Manage shop staff and their roles (Admin, Manager, Cashier).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/staff/data/repositories/staff_repository.dart';
import 'package:dukanx/features/staff/data/models/staff_model.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  List<StaffModel> _staffList = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      _userId = sl<SessionManager>().ownerId;
      if (_userId != null) {
        final result = await sl<StaffRepository>().getAllStaff(userId: _userId!, activeOnly: false);
        if (result.isSuccess && result.data != null) {
          if (mounted) {
            setState(() {
              _staffList = result.data!;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading staff: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _roleToString(StaffRole role) {
    switch (role) {
      case StaffRole.admin:
        return 'Admin';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.cashier:
        return 'Cashier';
      case StaffRole.salesperson:
        return 'Salesperson';
      case StaffRole.stockKeeper:
        return 'Stock Keeper';
      case StaffRole.accountant:
        return 'Accountant';
      case StaffRole.delivery:
        return 'Delivery';
      case StaffRole.caterer:
        return 'Caterer';
    }
  }

  StaffRole _stringToRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return StaffRole.admin;
      case 'manager':
        return StaffRole.manager;
      case 'cashier':
        return StaffRole.cashier;
      case 'salesperson':
        return StaffRole.salesperson;
      case 'stock keeper':
      case 'stockkeeper':
        return StaffRole.stockKeeper;
      case 'accountant':
        return StaffRole.accountant;
      case 'delivery':
        return StaffRole.delivery;
      case 'caterer':
        return StaffRole.caterer;
      default:
        return StaffRole.salesperson;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: "Team & Access",
      subtitle: "Manage roles and permissions",
      actions: [
        DesktopIconButton(
          icon: Icons.person_add,
          tooltip: 'Add Staff',
          onPressed: () => _showAddUserDialog(),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryStats(),
            const SizedBox(height: 24),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    final activeCount = _staffList.where((u) => u.isActive).length;
    return Row(
      children: [
        _buildStatCard(
          "Total Staff",
          "${_staffList.length}",
          Icons.people_outline,
          Colors.blue,
        ),
        const SizedBox(width: 16),
        _buildStatCard("Active Now", "$activeCount", Icons.circle, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: FuturisticColors.primary),
      );
    }
    return _buildUserList();
  }

  void _showAddUserDialog({StaffModel? editingUser}) {
    final nameController = TextEditingController(text: editingUser?.name ?? '');
    String selectedRole = editingUser != null ? _roleToString(editingUser.role) : 'Cashier';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FuturisticColors.surface,
        title: Text(
          editingUser != null ? 'Edit Staff Details' : 'Add New Staff',
          style: TextStyle(color: FuturisticColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: FuturisticColors.textSecondary),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRole,
              dropdownColor: FuturisticColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Role',
                labelStyle: TextStyle(color: FuturisticColors.textSecondary),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['Admin', 'Manager', 'Cashier', 'Salesperson', 'Stock Keeper', 'Accountant', 'Delivery', 'Caterer']
                  .map(
                    (role) => DropdownMenuItem(value: role, child: Text(role)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) selectedRole = val;
              },
            ),
          ],
        ),
        actions: [
          if (editingUser != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (confirmCtx) => AlertDialog(
                    backgroundColor: FuturisticColors.surface,
                    title: const Text('Delete Staff', style: TextStyle(color: Colors.white)),
                    content: Text('Are you sure you want to delete ${editingUser.name}?', style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await sl<StaffRepository>().deleteStaff(editingUser.id);
                  _loadStaff();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${editingUser.name} deleted')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: FuturisticColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                if (editingUser != null) {
                  await sl<StaffRepository>().updateStaff(
                    id: editingUser.id,
                    name: name,
                    role: _stringToRole(selectedRole).toString().split('.').last.toUpperCase(),
                  );
                  _loadStaff();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Updated details for $name')),
                    );
                  }
                } else {
                  final uId = _userId ?? 'SYSTEM';
                  await sl<StaffRepository>().addStaffMember(
                    userId: uId,
                    name: name,
                    phone: '',
                    role: _stringToRole(selectedRole).toString().split('.').last.toUpperCase(),
                  );
                  _loadStaff();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name added as $selectedRole')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FuturisticColors.primary,
            ),
            child: Text(editingUser != null ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_staffList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              "No staff members added yet",
              style: TextStyle(color: FuturisticColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemCount: _staffList.length,
      itemBuilder: (context, index) {
        final user = _staffList[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(StaffModel user) {
    final roleName = _roleToString(user.role);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: _getRoleColor(user.role),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        color: FuturisticColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      roleName,
                      style: TextStyle(
                        color: _getRoleColor(user.role),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: user.isActive,
                onChanged: (val) async {
                  await sl<StaffRepository>().updateStaff(
                    id: user.id,
                    isActive: val,
                  );
                  _loadStaff();
                },
                activeColor: FuturisticColors.success,
              ),
            ],
          ),
          const Spacer(),
          const Divider(color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Joined: ${user.joinedAt.day}/${user.joinedAt.month}/${user.joinedAt.year}",
                style: TextStyle(
                  color: FuturisticColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: FuturisticColors.textSecondary,
                ),
                onPressed: () => _showAddUserDialog(editingUser: user),
                tooltip: "Edit Permissions",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(StaffRole role) {
    switch (role) {
      case StaffRole.admin:
        return FuturisticColors.error;
      case StaffRole.manager:
        return FuturisticColors.accent1;
      default:
        return FuturisticColors.success;
    }
  }
}
