import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../../providers/app_state_providers.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Procurement Log Screen
///
/// Shows history of all procurement activities:
/// - Purchase orders
/// - Stock entries
/// - Vendor deliveries
class ProcurementLogScreen extends ConsumerStatefulWidget {
  const ProcurementLogScreen({super.key});

  @override
  ConsumerState<ProcurementLogScreen> createState() =>
      _ProcurementLogScreenState();
}

class _ProcurementLogScreenState extends ConsumerState<ProcurementLogScreen> {
  bool _loading = true;
  List<PurchaseOrder> _purchases = [];
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final repo = sl<PurchaseRepository>();
      final result = await repo.getAll(userId: userId);
      _purchases = result.data ?? [];

      // Sort by date descending
      _purchases.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<PurchaseOrder> get _filteredPurchases {
    if (_filterStatus == 'All') return _purchases;
    return _purchases
        .where((p) => p.status == _filterStatus.toUpperCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Procurement Log',
      subtitle: '${_filteredPurchases.length} records',
      actions: [
        // Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              items: [
                'All',
                'Completed',
                'Pending',
                'Cancelled',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) =>
                  setState(() => _filterStatus = value ?? 'All'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: Column(
        children: [
          _buildSummary(isDark),
          const SizedBox(height: 24),
          Expanded(child: _buildList(isDark)),
        ],
      ),
    );
  }

  // Header removed as DesktopContentContainer handles it

  Widget _buildSummary(bool isDark) {
    final totalAmount = _purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalPaid = _purchases.fold(0.0, (sum, p) => sum + p.paidAmount);
    final completed = _purchases.where((p) => p.status == 'COMPLETED').length;
    final pending = _purchases.where((p) => p.status == 'PENDING').length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      child: Row(
        children: [
          _buildSummaryChip(
            'Total',
            '₹${_formatAmount(totalAmount)}',
            const Color(0xFF8B5CF6),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryChip(
            'Paid',
            '₹${_formatAmount(totalPaid)}',
            const Color(0xFF10B981),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryChip(
            'Completed',
            '$completed',
            const Color(0xFF06B6D4),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryChip(
            'Pending',
            '$pending',
            const Color(0xFFF59E0B),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredPurchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No procurement records',
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPurchases.length,
      itemBuilder: (context, index) =>
          _buildPurchaseCard(_filteredPurchases[index], isDark),
    );
  }

  Widget _buildPurchaseCard(PurchaseOrder purchase, bool isDark) {
    final isPaid = purchase.paidAmount >= purchase.totalAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.shopping_cart, color: Color(0xFF8B5CF6)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                purchase.invoiceNumber ?? 'Purchase Order',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            _buildStatusBadge(purchase.status, isDark),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              purchase.vendorName ?? 'Unknown Vendor',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(purchase.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${purchase.totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (!isPaid)
              Text(
                'Due: ₹${(purchase.totalAmount - purchase.paidAmount).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color color;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        color = const Color(0xFF10B981);
        break;
      case 'PENDING':
        color = const Color(0xFFF59E0B);
        break;
      case 'CANCELLED':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(2)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}
