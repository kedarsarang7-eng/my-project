import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../../providers/app_state_providers.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Supplier Bills Screen
///
/// Shows supplier bills (purchase payables):
/// - Outstanding bills
/// - Payment tracking
/// - Vendor-wise breakdown
class SupplierBillsScreen extends ConsumerStatefulWidget {
  const SupplierBillsScreen({super.key});

  @override
  ConsumerState<SupplierBillsScreen> createState() =>
      _SupplierBillsScreenState();
}

class _SupplierBillsScreenState extends ConsumerState<SupplierBillsScreen> {
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
      _purchases.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<PurchaseOrder> get _filtered {
    switch (_filterStatus) {
      case 'Unpaid':
        return _purchases.where((p) => p.paidAmount == 0).toList();
      case 'Partial':
        return _purchases
            .where((p) => p.paidAmount > 0 && p.paidAmount < p.totalAmount)
            .toList();
      case 'Paid':
        return _purchases.where((p) => p.paidAmount >= p.totalAmount).toList();
      default:
        return _purchases;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Supplier Bills',
      subtitle: '${_filtered.length} bills',
      actions: [
        // Status Filter
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
                'Unpaid',
                'Partial',
                'Paid',
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
          _buildList(isDark),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final totalBills = _purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalPaid = _purchases.fold(0.0, (sum, p) => sum + p.paidAmount);
    final totalDue = totalBills - totalPaid;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Bills',
              '₹${_formatAmount(totalBills)}',
              const Color(0xFF8B5CF6),
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Paid',
              '₹${_formatAmount(totalPaid)}',
              const Color(0xFF10B981),
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Due',
              '₹${_formatAmount(totalDue)}',
              const Color(0xFFEF4444),
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.request_quote_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No supplier bills',
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
      itemCount: _filtered.length,
      itemBuilder: (context, index) => _buildBillCard(_filtered[index], isDark),
    );
  }

  Widget _buildBillCard(PurchaseOrder purchase, bool isDark) {
    final due = purchase.totalAmount - purchase.paidAmount;
    final isPaid = due <= 0;
    final isPartial = purchase.paidAmount > 0 && !isPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.vendorName ?? 'Unknown Vendor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        purchase.invoiceNumber ?? 'Bill',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPaymentStatus(isPaid, isPartial),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '₹${purchase.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paid',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '₹${purchase.paidAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '₹${due.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: due > 0
                              ? const Color(0xFFEF4444)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPaid)
                  ElevatedButton(
                    onPressed: () {
                      // Record payment logic
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Pay'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM yyyy').format(purchase.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatus(bool isPaid, bool isPartial) {
    if (isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'PAID',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF10B981),
          ),
        ),
      );
    } else if (isPartial) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'PARTIAL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF59E0B),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'UNPAID',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF4444),
          ),
        ),
      );
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(2)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}
