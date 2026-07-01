import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/vendor_notification_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../alerts/data/datasources/alert_service.dart';
import '../../../alerts/domain/entities/alert.dart';
import '../../../billing/domain/repositories/billing_repository.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/repository/bills_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Alerts & Notifications Screen
///
/// Displays all system alerts including:
/// - Low stock alerts
/// - Expiry warnings
/// - System notifications
/// - Payment alerts
class AlertsNotificationsScreen extends ConsumerStatefulWidget {
  const AlertsNotificationsScreen({super.key});

  @override
  ConsumerState<AlertsNotificationsScreen> createState() =>
      _AlertsNotificationsScreenState();
}

class _AlertsNotificationsScreenState
    extends ConsumerState<AlertsNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Alert> _alerts = [];
  List<VendorNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Load alerts from AlertService
      // Using lazy locator for repositories when creating AlertService
      final alertService = AlertService(
        sl<BillingRepository>(),
        sl<ProductsRepository>(),
        sl<BillsRepository>(),
      );
      final alerts = await alertService.checkAlerts(userId);

      // Load notifications
      final notificationRepo = sl<VendorNotificationRepository>();
      final notificationsStream = notificationRepo.watchNotifications(userId);

      notificationsStream.listen((notifications) {
        if (mounted) {
          setState(() {
            _notifications = notifications;
          });
        }
      });

      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Tab Bar
            _buildTabBar(isDark),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAllTab(isDark),
                        _buildLowStockTab(isDark),
                        _buildExpiryTab(isDark),
                        _buildNotificationsTab(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final isMobile = context.isMobile;

    final info = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_active,
            color: Color(0xFFF59E0B),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alerts & Notifications',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_alerts.length} alerts • ${_notifications.where((n) => !n.isRead).length} unread',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final userId = ref.read(authStateProvider).userId ?? '';
              await VendorNotificationRepository().markAllAsRead(userId);
            },
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Mark All Read', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF06B6D4),
              side: const BorderSide(color: Color(0xFF06B6D4)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _loadData,
          icon: Icon(
            Icons.refresh,
            color: isDark ? Colors.white70 : Colors.grey[600],
            size: 20,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
          ),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 12), actions],
            )
          : Row(
              children: [
                Expanded(child: info),
                TextButton.icon(
                  onPressed: () async {
                    final userId = ref.read(authStateProvider).userId ?? '';
                    await VendorNotificationRepository().markAllAsRead(userId);
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark All Read'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF06B6D4),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadData,
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: context.isMobile,
        indicatorColor: const Color(0xFF06B6D4),
        labelColor: const Color(0xFF06B6D4),
        unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[600],
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.all_inbox, size: 18),
                const SizedBox(width: 8),
                const Text('All'),
                if (_alerts.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildBadge(
                    _alerts.length.toString(),
                    const Color(0xFF06B6D4),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2, size: 18),
                const SizedBox(width: 8),
                const Text('Low Stock'),
                if (_alerts
                    .where((a) => a.type == AlertType.lowStock)
                    .isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildBadge(
                    _alerts
                        .where((a) => a.type == AlertType.lowStock)
                        .length
                        .toString(),
                    const Color(0xFFF59E0B),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 8),
                const Text('Expiry'),
                if (_alerts
                    .where((a) => a.type == AlertType.expiry)
                    .isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildBadge(
                    _alerts
                        .where((a) => a.type == AlertType.expiry)
                        .length
                        .toString(),
                    const Color(0xFFEF4444),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications, size: 18),
                const SizedBox(width: 8),
                const Text('Notifications'),
                if (_notifications.where((n) => !n.isRead).isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildBadge(
                    _notifications.where((n) => !n.isRead).length.toString(),
                    const Color(0xFF10B981),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAllTab(bool isDark) {
    if (_alerts.isEmpty) {
      return _buildEmptyState(
        isDark,
        'No alerts',
        'Your business is running smoothly!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) => _buildAlertCard(_alerts[index], isDark),
    );
  }

  Widget _buildLowStockTab(bool isDark) {
    final lowStockAlerts = _alerts
        .where((a) => a.type == AlertType.lowStock)
        .toList();

    if (lowStockAlerts.isEmpty) {
      return _buildEmptyState(
        isDark,
        'No low stock alerts',
        'All products have sufficient stock',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lowStockAlerts.length,
      itemBuilder: (context, index) =>
          _buildAlertCard(lowStockAlerts[index], isDark),
    );
  }

  Widget _buildExpiryTab(bool isDark) {
    final expiryAlerts = _alerts
        .where((a) => a.type == AlertType.expiry)
        .toList();

    if (expiryAlerts.isEmpty) {
      return _buildEmptyState(
        isDark,
        'No expiry alerts',
        'All products are within expiry date',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expiryAlerts.length,
      itemBuilder: (context, index) =>
          _buildAlertCard(expiryAlerts[index], isDark),
    );
  }

  Widget _buildNotificationsTab(bool isDark) {
    if (_notifications.isEmpty) {
      return _buildEmptyState(
        isDark,
        'No notifications',
        'You\'re all caught up!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) =>
          _buildNotificationCard(_notifications[index], isDark),
    );
  }

  Widget _buildAlertCard(Alert alert, bool isDark) {
    Color alertColor;
    IconData alertIcon;

    switch (alert.type) {
      case AlertType.lowStock:
        alertColor = const Color(0xFFF59E0B);
        alertIcon = Icons.inventory_2_outlined;
        break;
      case AlertType.expiry:
        alertColor = const Color(0xFFEF4444);
        alertIcon = Icons.schedule;
        break;
      case AlertType.abnormalBill:
        alertColor = const Color(0xFF8B5CF6);
        alertIcon = Icons.warning_amber;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate based on alert type
            _handleAlertTap(alert);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Alert Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(alertIcon, color: alertColor, size: 24),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.message,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(alert.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Indicator
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(VendorNotification notification, bool isDark) {
    final color = Color(notification.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? (notification.isRead
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF1E293B).withOpacity(0.8))
            : (notification.isRead ? Colors.white : Colors.blue.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead
              ? (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!)
              : color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Mark as read
            if (!notification.isRead) {
              await VendorNotificationRepository().markAsRead(notification.id);
            }
            // Navigate based on action
            _handleNotificationTap(notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Notification Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForType(notification.type),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(VendorNotificationType type) {
    switch (type) {
      case VendorNotificationType.lowStock:
        return Icons.inventory_2_outlined;
      case VendorNotificationType.expiryWarning:
        return Icons.schedule;
      case VendorNotificationType.paymentReceived:
        return Icons.payments_outlined;
      case VendorNotificationType.newOrder:
        return Icons.shopping_cart_outlined;
      case VendorNotificationType.returnRequest:
        return Icons.assignment_return_outlined;
      case VendorNotificationType.syncIssue:
        return Icons.cloud_off_outlined;
      case VendorNotificationType.systemAlert:
        return Icons.info_outline;
      case VendorNotificationType.dailySummary:
        return Icons.summarize_outlined;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  void _handleAlertTap(Alert alert) {
    // Navigate based on alert type
    switch (alert.type) {
      case AlertType.lowStock:
        // Navigate to inventory
        context.push('/app/low_stock');
        break;
      case AlertType.expiry:
        // Navigate to batch tracking
        context.push('/app/inventory');
        break;
      case AlertType.abnormalBill:
        // Navigate to bills
        context.push('/app/revenue_overview');
        break;
    }
  }

  void _handleNotificationTap(VendorNotification notification) {
    if (notification.actionType == null || notification.actionId == null) {
      return;
    }

    switch (notification.actionType) {
      case 'VIEW_PRODUCT':
        // Navigate to product detail
        break;
      case 'VIEW_BILL':
        // Navigate to bill detail
        break;
      case 'VIEW_CUSTOMER':
        // Navigate to customer detail
        break;
    }
  }
}
