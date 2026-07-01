import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';
import '../providers/app_state_providers.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/glass_morphism.dart';
import '../widgets/modern_ui_components.dart';

class PendingDuesScreen extends ConsumerStatefulWidget {
  const PendingDuesScreen({super.key});

  @override
  ConsumerState<PendingDuesScreen> createState() => _PendingDuesScreenState();
}

class _PendingDuesScreenState extends ConsumerState<PendingDuesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Udhar Dashboard',
          style: AppTypography.headlineMedium.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FuturisticColors.darkBackgroundGradient
              : FuturisticColors.lightBackgroundGradient,
        ),
        child: SafeArea(
          child: StreamBuilder<List<Bill>>(
            stream: sl<BillsRepository>().watchAll(
              userId: sl<SessionManager>().ownerId ?? '',
            ),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: TextStyle(color: FuturisticColors.error),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var bills = snap.data ?? [];

              // Filter only pending items
              bills = bills.where((b) {
                final pending = b.grandTotal - b.paidAmount;
                return pending > 1 && b.status.toLowerCase() != 'paid';
              }).toList();

              // Calculate stats
              double totalUdhar = 0;
              double overdueTotal = 0; // Bills older than 30 days
              for (var b in bills) {
                final p = b.grandTotal - b.paidAmount;
                totalUdhar += p;
                if (DateTime.now().difference(b.date).inDays > 30) {
                  overdueTotal += p;
                }
              }

              // Search filter
              final q = _searchCtrl.text.trim().toLowerCase();
              if (q.isNotEmpty) {
                bills = bills
                    .where((b) => b.invoiceNumber.toLowerCase().contains(q))
                    .toList();
              }

              bills.sort((a, b) => b.date.compareTo(a.date));

              final isMobile = context.isMobile;
              return ResponsiveContainer(
                child: Column(
                  children: [
                    // Dashboard Stats
                    _buildDashboardStats(totalUdhar, overdueTotal, isDark),

                    // Search
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search invoice #...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                            icon: Icon(
                              Icons.search,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),

                    // List
                    Expanded(
                      child: bills.isEmpty
                          ? EmptyStateWidget(
                              icon: Icons.check_circle_outline,
                              title: 'No Pending Udhar!',
                              description: 'Great job collecting payments.',
                            )
                          : isMobile
                              ? ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: bills.length,
                                  itemBuilder: (context, index) {
                                    return _buildUdharCard(bills[index], isDark);
                                  },
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 450,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 140,
                                  ),
                                  itemCount: bills.length,
                                  itemBuilder: (context, index) {
                                    return _buildUdharCard(bills[index], isDark);
                                  },
                                ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardStats(double total, double overdue, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ModernCard(
        backgroundColor: Colors.transparent, // Use gradient
        gradient: FuturisticColors.errorGradient,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Total Outstanding Udhar',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${total.toStringAsFixed(0)}',
              style: AppTypography.displayMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Overdue (>30d)',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${overdue.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Recent',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${(total - overdue).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUdharCard(Bill bill, bool isDark) {
    final pending = bill.grandTotal - bill.paidAmount;
    final isOverdue = DateTime.now().difference(bill.date).inDays > 30;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        showGlow: isOverdue,
        glowColor: FuturisticColors.error,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.customerName.isNotEmpty
                            ? bill.customerName
                            : 'Unknown Customer',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Invoice #${bill.invoiceNumber}',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? FuturisticColors.error.withOpacity(0.1)
                        : FuturisticColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOverdue
                          ? FuturisticColors.error.withOpacity(0.3)
                          : FuturisticColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '₹${pending.toStringAsFixed(0)} Left',
                    style: TextStyle(
                      color: isOverdue
                          ? FuturisticColors.error
                          : FuturisticColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Divider(
              height: 24,
              color: isDark ? Colors.white10 : FuturisticColors.divider,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isOverdue
                          ? FuturisticColors.error
                          : (isDark ? Colors.white54 : Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(bill.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue
                            ? FuturisticColors.error
                            : (isDark ? Colors.white54 : Colors.grey),
                        fontWeight: isOverdue
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _markAsPaid(bill),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: FuturisticColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Mark Paid',
                      style: TextStyle(
                        color: FuturisticColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsPaid(Bill bill) async {
    try {
      final ownerId = sl<SessionManager>().ownerId;
      if (ownerId == null) return;

      final pending = bill.grandTotal - bill.paidAmount;
      if (pending > 0) {
        await sl<BillsRepository>().recordPayment(
          userId: ownerId,
          billId: bill.id,
          amount: pending,
          paymentMode: 'Cash', // Default to cash for quick mark paid
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marked as Paid!')));
      }
    } catch (e) {
      debugPrint('Error marking paid: $e');
    }
  }
}
