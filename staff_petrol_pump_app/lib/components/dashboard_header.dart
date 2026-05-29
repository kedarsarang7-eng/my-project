import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../context/permission_context.dart';
import '../core/auth/auth_provider.dart';

class DashboardHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String userName;

  const DashboardHeader({super.key, required this.userName});

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.amber;
      case 'staff':
        return Colors.blue;
      case 'ca':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionProvider);

    return AppBar(
      title: Text('${permission.businessName} (${permission.businessType})'),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(child: Text(userName)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _roleColor(permission.role),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(child: Text(permission.role.toUpperCase())),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(authStateProvider.notifier).signOut();
            await ref.read(permissionProvider.notifier).clear();
            if (context.mounted) {
              context.go('/login?message=Logged out. Please login with your new role.');
            }
          },
          child: const Text('Switch Role / Logout'),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
