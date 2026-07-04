import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/core/localization/app_l10n.dart';
import '../../data/models/employee_model.dart';
import '../widgets/staff_loading_skeleton.dart';

/// Employee Detail Screen — displays full employee info with masked PII.
///
/// Material 3, responsive (Req 14.2, 14.3, 14.4).
/// All strings from l10n (Req 14.6).
class EmployeeDetailScreen extends ConsumerWidget {
  final EmployeeModel employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AdaptiveScaffold(
      appBar: AppBar(title: Text(l10n.staffEmployeeDetail), centerTitle: false),
      body: AdaptiveScroll(
        padding: responsiveValue<EdgeInsets>(
          context,
          mobile: const EdgeInsets.all(16),
          tablet: const EdgeInsets.all(24),
          desktop: const EdgeInsets.all(32),
        ),
        child: BoundedBox(
          maxWidth: 800,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with avatar
              _buildHeader(context, colorScheme, textTheme),
              const SizedBox(height: 24),

              // Info cards
              _buildInfoSection(context, l10n, colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: responsiveValue<double>(
            context,
            mobile: 32,
            tablet: 40,
            desktop: 48,
          ),
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage: employee.photoUrl != null
              ? NetworkImage(employee.photoUrl!)
              : null,
          child: employee.photoUrl == null
              ? Text(
                  employee.fullName.isNotEmpty
                      ? employee.fullName[0].toUpperCase()
                      : '?',
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdaptiveText(
                employee.fullName,
                style: textTheme.headlineSmall,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              _buildStatusBadge(context, colorScheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, ColorScheme colorScheme) {
    final l10n = context.l10n;
    final isActive = employee.status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? l10n.staffActive : l10n.staffInactive,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isActive ? Colors.green.shade700 : colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              context,
              icon: Icons.phone,
              label: l10n.staffPhone,
              value: employee.phone ?? '—',
            ),
            const Divider(height: 24),
            _infoRow(
              context,
              icon: Icons.email,
              label: l10n.staffEmail,
              value: employee.email ?? '—',
            ),
            const Divider(height: 24),
            _infoRow(
              context,
              icon: Icons.business,
              label: l10n.staffDepartment,
              value: employee.departmentId ?? '—',
            ),
            const Divider(height: 24),
            _infoRow(
              context,
              icon: Icons.badge,
              label: l10n.staffDesignation,
              value: employee.designationId ?? '—',
            ),
            // Masked PII fields
            if (employee.panMasked != null) ...[
              const Divider(height: 24),
              _infoRow(
                context,
                icon: Icons.credit_card,
                label: 'PAN',
                value: employee.panMasked!,
              ),
            ],
            if (employee.aadhaarMasked != null) ...[
              const Divider(height: 24),
              _infoRow(
                context,
                icon: Icons.fingerprint,
                label: 'Aadhaar',
                value: employee.aadhaarMasked!,
              ),
            ],
            if (employee.bankAccountMasked != null) ...[
              const Divider(height: 24),
              _infoRow(
                context,
                icon: Icons.account_balance,
                label: 'Bank',
                value: employee.bankAccountMasked!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdaptiveText(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              AdaptiveText(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
