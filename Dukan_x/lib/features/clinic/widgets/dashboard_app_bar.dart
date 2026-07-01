// ============================================================================
// DASHBOARD APP BAR
// ============================================================================
// Top header matching reference image:
// - Clinic logo
// - Search bar
// - Notification icon with badge
// - User avatar + name + role
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';

class DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onToggleSidebar;
  final bool sidebarCollapsed;

  const DashboardAppBar({
    super.key,
    this.onToggleSidebar,
    this.sidebarCollapsed = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = sl<SessionManager>().currentSession;
    final userName = session.displayName ?? 'User';
    const userRole = 'Staff';

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sidebar Toggle Button (Desktop only)
          if (onToggleSidebar != null)
            IconButton(
              onPressed: onToggleSidebar,
              icon: Icon(
                sidebarCollapsed ? Icons.menu_open : Icons.menu,
                color: FuturisticColors.textSecondary,
              ),
              tooltip: sidebarCollapsed ? 'Expand Sidebar (Ctrl+B)' : 'Collapse Sidebar (Ctrl+B)',
            ),
          if (onToggleSidebar != null)
            const SizedBox(width: 8),

          // Clinic Logo
          Row(
            children: [
              Icon(
                Icons.local_hospital,
                color: FuturisticColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                'MEDCARE CLINIC',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(width: 48),

          // Search Bar
          Expanded(
            child: Container(
              height: 44,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.search,
                    color: FuturisticColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search patients, appointments...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: FuturisticColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Date & Time
          Text(
            _formatCurrentDate(),
            style: TextStyle(
              fontSize: 14,
              color: FuturisticColors.textSecondary,
            ),
          ),

          const SizedBox(width: 24),

          // Keyboard Shortcuts Help
          IconButton(
            onPressed: () => _showShortcutsHelp(context),
            icon: Icon(
              Icons.keyboard_outlined,
              color: FuturisticColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Keyboard Shortcuts',
          ),
          const SizedBox(width: 8),

          // Notifications
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  // Show notifications
                },
                icon: Icon(
                  Icons.notifications_outlined,
                  color: FuturisticColors.textPrimary,
                  size: 24,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: FuturisticColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // User Profile
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: FuturisticColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  color: FuturisticColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: FuturisticColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: FuturisticColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      userRole,
                      style: TextStyle(
                        fontSize: 10,
                        color: FuturisticColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$dayName, $monthName ${now.day}, ${now.year} | $hour:$minute';
  }

  void _showShortcutsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Color(0xFF1565C0)),
            SizedBox(width: 12),
            Text('Keyboard Shortcuts'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShortcutItem('F5 or Ctrl+R', 'Refresh Dashboard'),
            SizedBox(height: 8),
            _ShortcutItem('Ctrl+B', 'Toggle Sidebar'),
            SizedBox(height: 8),
            _ShortcutItem('Esc', 'Close Dialogs'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutItem(this.shortcut, this.description);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            shortcut,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
