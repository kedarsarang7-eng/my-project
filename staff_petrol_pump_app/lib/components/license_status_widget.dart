import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/petrol_pump/providers/license_provider.dart';

/// License Status Widget - Shows license warnings and expiry information
class LicenseStatusWidget extends ConsumerWidget {
  const LicenseStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseState = ref.watch(licenseStateProvider);
    final license = licenseState.profile;

    if (license == null) {
      return const SizedBox.shrink();
    }

    // Check for license issues
    final issues = <LicenseIssue>[];
    
    if (license.isExpired) {
      issues.add(LicenseIssue(
        type: LicenseIssueType.expired,
        message: 'Your license has expired. Please renew to continue using the service.',
        severity: LicenseIssueSeverity.critical,
      ));
    } else if (license.expiresAt != null) {
      final expiryDate = DateTime.parse(license.expiresAt!);
      final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
      
      if (daysUntilExpiry <= 0) {
        issues.add(LicenseIssue(
          type: LicenseIssueType.expired,
          message: 'Your license has expired today. Please renew immediately.',
          severity: LicenseIssueSeverity.critical,
        ));
      } else if (daysUntilExpiry <= 7) {
        issues.add(LicenseIssue(
          type: LicenseIssueType.expiringSoon,
          message: 'Your license expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}. Please renew soon.',
          severity: LicenseIssueSeverity.warning,
        ));
      } else if (daysUntilExpiry <= 30) {
        issues.add(LicenseIssue(
          type: LicenseIssueType.expiringSoon,
          message: 'Your license expires in $daysUntilExpiry days.',
          severity: LicenseIssueSeverity.info,
        ));
      }
    }

    if (!license.isActive) {
      issues.add(LicenseIssue(
        type: LicenseIssueType.inactive,
        message: 'Your license is inactive. Please contact support.',
        severity: LicenseIssueSeverity.critical,
      ));
    }

    if (issues.isEmpty) {
      return _LicenseInfoCard(license: license);
    }

    return Column(
      children: [
        ...issues.map((issue) => _LicenseIssueCard(issue: issue)),
        const SizedBox(height: 8),
        _LicenseInfoCard(license: license),
      ],
    );
  }
}

class _LicenseIssueCard extends StatelessWidget {
  final LicenseIssue issue;

  const _LicenseIssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color iconColor;
    IconData icon;
    Color textColor;

    switch (issue.severity) {
      case LicenseIssueSeverity.critical:
        backgroundColor = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        icon = Icons.error;
        textColor = Colors.red.shade700;
        break;
      case LicenseIssueSeverity.warning:
        backgroundColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade700;
        icon = Icons.warning;
        textColor = Colors.orange.shade700;
        break;
      case LicenseIssueSeverity.info:
        backgroundColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade700;
        icon = Icons.info;
        textColor = Colors.blue.shade700;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getIssueTitle(issue.type),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  issue.message,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (issue.type == LicenseIssueType.expired || 
              issue.type == LicenseIssueType.inactive)
            TextButton(
              onPressed: () => _showRenewalDialog(context),
              style: TextButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Renew', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  String _getIssueTitle(LicenseIssueType type) {
    switch (type) {
      case LicenseIssueType.expired:
        return 'License Expired';
      case LicenseIssueType.expiringSoon:
        return 'License Expiring Soon';
      case LicenseIssueType.inactive:
        return 'License Inactive';
    }
  }

  void _showRenewalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('License Renewal'),
        content: const Text(
          'Please contact your administrator or support to renew your license.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LicenseInfoCard extends StatelessWidget {
  final LicenseProfile license;

  const _LicenseInfoCard({required this.license});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'License Active',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Plan',
            value: license.plan.toUpperCase(),
          ),
          _InfoRow(
            label: 'Business Types',
            value: license.availableBusinessTypes
                .map((type) => _formatBusinessType(type))
                .join(', '),
          ),
          if (license.expiresAt != null)
            _InfoRow(
              label: 'Expires',
              value: _formatDate(license.expiresAt!),
            ),
          _InfoRow(
            label: 'Max Users',
            value: license.maxUsers?.toString() ?? 'Unlimited',
          ),
          _InfoRow(
            label: 'Max Devices',
            value: license.maxDevices?.toString() ?? 'Unlimited',
          ),
        ],
      ),
    );
  }

  String _formatBusinessType(String businessType) {
    switch (businessType) {
      case 'petrol_pump':
        return 'Fuel POS';
      case 'pharmacy':
        return 'Pharmacy';
      case 'restaurant':
        return 'Restaurant';
      case 'clinic':
        return 'Clinic';
      case 'grocery':
        return 'Grocery';
      case 'retail':
        return 'Retail';
      default:
        return businessType.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LicenseIssue {
  final LicenseIssueType type;
  final String message;
  final LicenseIssueSeverity severity;

  LicenseIssue({
    required this.type,
    required this.message,
    required this.severity,
  });
}

enum LicenseIssueType {
  expired,
  expiringSoon,
  inactive,
}

enum LicenseIssueSeverity {
  critical,
  warning,
  info,
}
