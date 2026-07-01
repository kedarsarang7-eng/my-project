// ============================================================================
// SECURITY DASHBOARD WIDGET
// ============================================================================
// Owner dashboard displaying fraud alerts, sessions, and security status.
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/security/services/fraud_detection_service.dart';
import '../../core/services/session_management_service.dart';
import '../../models/accounting_period.dart';

/// Security Dashboard Widget - Owner's security overview.
///
/// Displays:
/// - Fraud alert summary
/// - Active sessions
/// - Period lock status
/// - Quick actions
class SecurityDashboardWidget extends StatelessWidget {
  final List<FraudAlert> pendingAlerts;
  final List<UserSession> activeSessions;
  final List<AccountingPeriod> recentPeriods;
  final VoidCallback? onViewAllAlerts;
  final VoidCallback? onViewAllSessions;
  final VoidCallback? onManageLocks;
  final void Function(FraudAlert)? onAlertTap;
  final void Function(UserSession)? onSessionTap;

  const SecurityDashboardWidget({
    super.key,
    required this.pendingAlerts,
    required this.activeSessions,
    required this.recentPeriods,
    this.onViewAllAlerts,
    this.onViewAllSessions,
    this.onManageLocks,
    this.onAlertTap,
    this.onSessionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.security, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Security Dashboard',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Alert Summary Cards
          _buildAlertSummary(context),
          const SizedBox(height: 24),

          // Fraud Alerts Section
          _buildFraudAlertsSection(context),
          const SizedBox(height: 24),

          // Active Sessions Section
          _buildActiveSessionsSection(context),
          const SizedBox(height: 24),

          // Period Lock Status
          _buildPeriodLockSection(context),
        ],
      ),
    );
  }

  Widget _buildAlertSummary(BuildContext context) {
    final theme = Theme.of(context);

    final criticalCount = pendingAlerts
        .where((a) => a.severity == FraudSeverity.critical)
        .length;
    final highCount = pendingAlerts
        .where((a) => a.severity == FraudSeverity.high)
        .length;
    final mediumCount = pendingAlerts
        .where((a) => a.severity == FraudSeverity.medium)
        .length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Critical',
            count: criticalCount,
            color: Colors.red,
            icon: Icons.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'High',
            count: highCount,
            color: Colors.orange,
            icon: Icons.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Medium',
            count: mediumCount,
            color: Colors.amber,
            icon: Icons.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Sessions',
            count: activeSessions.length,
            color: theme.colorScheme.primary,
            icon: Icons.devices,
          ),
        ),
      ],
    );
  }

  Widget _buildFraudAlertsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Alerts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onViewAllAlerts != null)
              TextButton(
                onPressed: onViewAllAlerts,
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingAlerts.isEmpty)
          _EmptyStateCard(
            icon: Icons.check_circle,
            message: 'No pending alerts',
            color: Colors.green,
          )
        else
          ...pendingAlerts
              .take(5)
              .map(
                (alert) => _FraudAlertTile(
                  alert: alert,
                  onTap: () => onAlertTap?.call(alert),
                ),
              ),
      ],
    );
  }

  Widget _buildActiveSessionsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Sessions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onViewAllSessions != null)
              TextButton(
                onPressed: onViewAllSessions,
                child: const Text('Manage'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeSessions.isEmpty)
          _EmptyStateCard(
            icon: Icons.devices_other,
            message: 'No active sessions',
            color: Colors.grey,
          )
        else
          ...activeSessions
              .take(3)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => _SessionTile(
                  session: entry.value,
                  onTap: () => onSessionTap?.call(entry.value),
                  // First session is typically the current device
                  isCurrentDevice: entry.key == 0,
                ),
              ),
      ],
    );
  }

  Widget _buildPeriodLockSection(BuildContext context) {
    final theme = Theme.of(context);
    final lockedPeriods = recentPeriods.where((p) => p.isLocked).toList();
    final unlockedPeriods = recentPeriods.where((p) => !p.isLocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Period Locks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onManageLocks != null)
              TextButton(onPressed: onManageLocks, child: const Text('Manage')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PeriodChip(
              label: '${lockedPeriods.length} Locked',
              icon: Icons.lock,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: '${unlockedPeriods.length} Open',
              icon: Icons.lock_open,
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

class _FraudAlertTile extends StatelessWidget {
  final FraudAlert alert;
  final VoidCallback? onTap;

  const _FraudAlertTile({required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _getSeverityColor(alert.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(_getAlertIcon(alert.type), color: color, size: 20),
        ),
        title: Text(
          alert.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(alert.createdAt),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            alert.severity.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(FraudSeverity severity) {
    switch (severity) {
      case FraudSeverity.critical:
        return Colors.red;
      case FraudSeverity.high:
        return Colors.orange;
      case FraudSeverity.medium:
        return Colors.amber;
      case FraudSeverity.low:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon(FraudAlertType type) {
    switch (type) {
      case FraudAlertType.highDiscount:
        return Icons.percent;
      case FraudAlertType.repeatedBillEdits:
        return Icons.edit;
      case FraudAlertType.lateNightBilling:
        return Icons.nights_stay;
      case FraudAlertType.cashVariance:
        return Icons.account_balance_wallet;
      case FraudAlertType.stockMismatch:
        return Icons.inventory;
      case FraudAlertType.roleAbuseAttempt:
        return Icons.admin_panel_settings;
      default:
        return Icons.warning;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SessionTile extends StatelessWidget {
  final UserSession session;
  final VoidCallback? onTap;
  final bool isCurrentDevice;

  const _SessionTile({
    required this.session,
    this.onTap,
    this.isCurrentDevice = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isCurrentDevice
              ? Colors.green.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          child: Icon(
            _getPlatformIcon(session.platform),
            color: isCurrentDevice ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(session.deviceName ?? 'Unknown Device'),
        subtitle: Text(
          'Active ${_formatDate(session.lastActiveAt)}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: isCurrentDevice
            ? const Chip(
                label: Text('This Device'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
              )
            : const Icon(Icons.logout, color: Colors.red),
      ),
    );
  }

  IconData _getPlatformIcon(String? platform) {
    switch (platform) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.web;
      case 'windows':
        return Icons.desktop_windows;
      default:
        return Icons.device_unknown;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _EmptyStateCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _PeriodChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
