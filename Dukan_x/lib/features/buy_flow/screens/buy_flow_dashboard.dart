import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_state_providers.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../core/database/app_database.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/reports_repository.dart';
import '../../../../models/daily_stats.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import '../../../../core/responsive/responsive_layout.dart';
import 'stock_entry_screen.dart';
import 'vendor_payouts_screen.dart';
import 'stock_reversal_screen.dart';
import 'buy_orders_screen.dart';

class BuyFlowDashboard extends ConsumerStatefulWidget {
  const BuyFlowDashboard({super.key});

  @override
  ConsumerState<BuyFlowDashboard> createState() => _BuyFlowDashboardState();
}

class _BuyFlowDashboardState extends ConsumerState<BuyFlowDashboard> {
  final _session = sl<SessionManager>();
  final _reportsRepository = sl<ReportsRepository>();

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final ownerId = _session.ownerId ?? '';

    return DesktopContentContainer(
      title: "BuyFlow Dashboard",
      child: StreamBuilder<VendorStats>(
        stream: _reportsRepository.watchVendorStats(ownerId),
        initialData: VendorStats.empty(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? VendorStats.empty();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Summary Cards
                context.isMobile
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  context,
                                  "Total Purchased",
                                  "${sl<CurrencyService>().symbol}${stats.totalInvoiceValue.toStringAsFixed(0)}",
                                  Icons.inventory_2_rounded,
                                  Colors.blue,
                                  isDark,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  context,
                                  "Pending Payments",
                                  "${sl<CurrencyService>().symbol}${stats.unpaidAmount.toStringAsFixed(0)}",
                                  Icons.pending_actions_rounded,
                                  Colors.orange,
                                  isDark,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  context,
                                  "Active Orders",
                                  "${stats.activeOrders}",
                                  Icons.local_shipping_rounded,
                                  Colors.purple,
                                  isDark,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: StreamBuilder<double>(
                                  stream: _watchReturnsAmount(ownerId),
                                  initialData: 0.0,
                                  builder: (context, snapshot) {
                                    final returns = snapshot.data ?? 0.0;
                                    return _buildSummaryCard(
                                      context,
                                      "Recent Returns",
                                      "${sl<CurrencyService>().symbol}${returns.toStringAsFixed(0)}",
                                      Icons.keyboard_return_rounded,
                                      Colors.redAccent,
                                      isDark,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              "Total Purchased",
                              "${sl<CurrencyService>().symbol}${stats.totalInvoiceValue.toStringAsFixed(0)}",
                              Icons.inventory_2_rounded,
                              Colors.blue,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              "Pending Payments",
                              "${sl<CurrencyService>().symbol}${stats.unpaidAmount.toStringAsFixed(0)}",
                              Icons.pending_actions_rounded,
                              Colors.orange,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              "Active Orders",
                              "${stats.activeOrders}",
                              Icons.local_shipping_rounded,
                              Colors.purple,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StreamBuilder<double>(
                              stream: _watchReturnsAmount(ownerId),
                              initialData: 0.0,
                              builder: (context, snapshot) {
                                final returns = snapshot.data ?? 0.0;
                                return _buildSummaryCard(
                                  context,
                                  "Recent Returns",
                                  "${sl<CurrencyService>().symbol}${returns.toStringAsFixed(0)}",
                                  Icons.keyboard_return_rounded,
                                  Colors.redAccent,
                                  isDark,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 32),

                // 2. Quick Actions
                Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.count(
                      crossAxisCount: constraints.maxWidth > 900 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildActionCard(
                          context,
                          "Stock Entry",
                          "Add new inventory",
                          Icons.add_box_rounded,
                          Colors.green,
                          isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StockEntryScreen(),
                            ),
                          ),
                        ),
                        _buildActionCard(
                          context,
                          "Pay Vendor",
                          "Clear dues",
                          Icons.payment_rounded,
                          Colors.blue,
                          isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VendorPayoutsScreen(),
                            ),
                          ),
                        ),
                        _buildActionCard(
                          context,
                          "Create Order",
                          "Request stock",
                          Icons.shopping_cart_checkout_rounded,
                          Colors.purple,
                          isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BuyOrdersScreen(),
                            ),
                          ),
                        ),
                        _buildActionCard(
                          context,
                          "Stock Reversal",
                          "Return items",
                          Icons.assignment_return_rounded,
                          Colors.orange,
                          isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StockReversalScreen(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // 3. Recent Activity (Loaded dynamically from database)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Activity",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BuyOrdersScreen(),
                        ),
                      ),
                      child: const Text("View All"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<PurchaseOrder>>(
                  stream: sl<PurchaseRepository>().watchAll(userId: ownerId),
                  initialData: const [],
                  builder: (context, snapshot) {
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            "No recent activity",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }
                    final recentOrders = orders.take(3).toList();
                    return Column(
                      children: recentOrders.map((order) {
                        final vendor = order.vendorName ?? 'Cash Purchase';
                        final timeAgo = _formatDateTime(order.purchaseDate);
                        return _buildActivityItem(
                          order.status == 'COMPLETED'
                              ? "Stock Added"
                              : "Order Created",
                          "Invoice #${order.invoiceNumber ?? order.id.substring(0, 8)} from $vendor",
                          timeAgo,
                          isDark,
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.isMobile ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [color.withOpacity(0.15), color.withOpacity(0.05)]
                : [color.withOpacity(0.1), color.withOpacity(0.01)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: 20,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Stream<double> _watchReturnsAmount(String ownerId) {
    final db = sl<AppDatabase>();
    return (db.select(db.purchaseOrders)
          ..where((t) => t.deletedAt.isNotNull() & t.userId.equals(ownerId)))
        .watch()
        .map((rows) {
          double sum = 0;
          for (final r in rows) {
            sum += r.totalAmount;
          }
          return sum;
        });
  }

  String _formatDateTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
