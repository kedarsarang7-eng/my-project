import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../models/dashboard_v2_models.dart';
import '../providers/dashboard_v2_providers.dart';
import '../utils/indian_number_formatter.dart';

class RecentInvoicesTable extends ConsumerStatefulWidget {
  const RecentInvoicesTable({super.key});

  @override
  ConsumerState<RecentInvoicesTable> createState() =>
      _RecentInvoicesTableState();
}

class _RecentInvoicesTableState extends ConsumerState<RecentInvoicesTable> {
  String _activeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final invoicesAsync =
        ref.watch(dashboardV2RecentInvoicesProvider(_activeFilter));
    final config = ref.watch(dashboardBusinessConfigProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FuturisticColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: FuturisticColors.accent1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: FuturisticColors.accent1, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent ${config.invoiceTableName}s',
                style: TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              // Filter chips
              _FilterChip(
                label: 'All',
                active: _activeFilter == 'all',
                onTap: () { if (mounted) setState(() => _activeFilter = 'all'); },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Today',
                active: _activeFilter == 'today',
                onTap: () { if (mounted) setState(() => _activeFilter = 'today'); },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'This Week',
                active: _activeFilter == 'this_week',
                onTap: () { if (mounted) setState(() => _activeFilter = 'this_week'); },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(flex: 2, child: _TableHeader('${config.invoiceTableName} #')),
                Expanded(flex: 3, child: _TableHeader('Customer')),
                Expanded(flex: 2, child: _TableHeader('Date')),
                Expanded(flex: 2, child: _TableHeader('Due Date')),
                Expanded(flex: 2, child: _TableHeader('Amount')),
                Expanded(flex: 2, child: _TableHeader('Status')),
              ],
            ),
          ),
          Divider(color: FuturisticColors.border, height: 1),
          const SizedBox(height: 8),

          // Table body
          invoicesAsync.when(
            data: (data) {
              if (data.isEmpty || data.invoices.isEmpty) {
                return _buildEmpty();
              }
              return Column(
                children: data.invoices
                    .map((inv) => _InvoiceRow(invoice: inv))
                    .toList(),
              );
            },
            loading: () => Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Shimmer.fromColors(
                    baseColor: FuturisticColors.surface,
                    highlightColor: FuturisticColors.border.withValues(alpha: 0.6),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: FuturisticColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // AUDIT FIX #4: Show error state with retry
            error: (_, _) => _buildErrorState(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.3),
                size: 36),
            const SizedBox(height: 8),
            Text(
              'No transactions in this period',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AUDIT FIX #4: Error state with retry
  Widget _buildErrorState() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: FuturisticColors.error.withValues(alpha: 0.4), size: 28),
            const SizedBox(height: 8),
            Text(
              'Failed to load invoices',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(
                dashboardV2RecentInvoicesProvider(_activeFilter),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: FuturisticColors.primary,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final RecentInvoice invoice;

  const _InvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FuturisticColors.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              invoice.invoiceNumber.isEmpty ? '—' : invoice.invoiceNumber,
              style: const TextStyle(
                color: FuturisticColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              invoice.customerName,
              style: TextStyle(
                color: FuturisticColors.textPrimary,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(invoice.date),
              style: TextStyle(
                color: FuturisticColors.textSecondary,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(invoice.dueDate),
              style: TextStyle(
                color: FuturisticColors.textSecondary,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              IndianNumberFormatter.formatCentsToInr(invoice.amountCents),
              style: TextStyle(
                color: FuturisticColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _StatusBadge(status: invoice.status),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '—';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'paid':
        bgColor = FuturisticColors.success.withValues(alpha: 0.15);
        textColor = FuturisticColors.success;
        label = 'Paid';
        break;
      case 'overdue':
        bgColor = FuturisticColors.error.withValues(alpha: 0.15);
        textColor = FuturisticColors.error;
        label = 'Overdue';
        break;
      case 'partial':
        bgColor = FuturisticColors.warning.withValues(alpha: 0.15);
        textColor = FuturisticColors.warning;
        label = 'Partial';
        break;
      case 'pending':
      case 'unpaid':
      default:
        bgColor = FuturisticColors.textSecondary.withValues(alpha: 0.12);
        textColor = FuturisticColors.textSecondary;
        label = 'Pending';
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? FuturisticColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? FuturisticColors.primary.withValues(alpha: 0.4)
                  : FuturisticColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? FuturisticColors.primary
                  : FuturisticColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
