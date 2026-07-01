import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../screens/billing_reports_screen.dart';
import '../../../daybook/presentation/screens/day_book_screen.dart';
import 'pnl_screen.dart';
import 'balance_screen.dart';
import 'purchase_report_screen.dart';
import 'all_transactions_screen.dart';
import 'bill_wise_profit_screen.dart';
import 'cashflow_screen.dart';
import 'trial_balance_screen.dart';
import '../../../../features/petrol_pump/presentation/screens/reports/nozzle_sales_report_screen.dart';
import '../../../../features/petrol_pump/presentation/screens/reports/shift_report_screen.dart';
import '../../../../features/petrol_pump/presentation/screens/reports/tank_stock_report_screen.dart';
import '../../../../features/petrol_pump/presentation/screens/reports/fuel_profit_report_screen.dart';
import 'tax_report_screen.dart';
import 'product_sales_breakdown_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeStateProvider);
    final businessState = ref.watch(businessTypeProvider);
    final isDark = theme.isDark;
    final isPetrolPump = businessState.isPetrolPump;

    return DesktopContentContainer(
      title: "Business Intelligence",
      subtitle: "Comprehensive reports and analytics",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPetrolPump) ...[
                _buildSection(
                  context,
                  "Petrol Pump Reports",
                  [
                    _ReportItem(
                      icon: Icons.local_gas_station_rounded,
                      title: "Nozzle Sales Analysis",
                      subtitle: "Sales by dispenser/nozzle",
                      color: Colors.redAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NozzleSalesReportScreen(),
                        ),
                      ),
                    ),
                    _ReportItem(
                      icon: Icons.access_time_filled_rounded,
                      title: "Shift Summary",
                      subtitle: "Daily shift collections",
                      color: Colors.blueGrey,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShiftReportScreen(),
                        ),
                      ),
                    ),
                    _ReportItem(
                      icon: Icons.water_drop_rounded,
                      title: "Tank Stock Logs",
                      subtitle: "Orifice/Dip readings history",
                      color: Colors.orangeAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TankStockReportScreen(),
                        ),
                      ),
                    ),
                    _ReportItem(
                      icon: Icons.currency_rupee_rounded,
                      title: "Fuel Profitability",
                      subtitle: "Margins per fuel type",
                      color: FuturisticColors.success,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FuelProfitReportScreen(),
                        ),
                      ),
                    ),
                  ],
                  isDark,
                  true,
                ), // Force desktop layout for grid
                const SizedBox(height: 32),
              ],
              _buildSection(
                context,
                "Transaction Reports",
                [
                  _ReportItem(
                    icon: Icons.receipt_long_rounded,
                    title: "Turnover Analysis",
                    subtitle: "Detailed revenue breakdown",
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BillingReportsScreen(),
                      ),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.shopping_cart_rounded,
                    title: "Procurement Log",
                    subtitle: "Track procurement history",
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PurchaseReportScreen(),
                      ),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.history_edu_rounded,
                    title: "Daily Activity Register",
                    subtitle: "Chronological activity log",
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DayBookScreen()),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.list_alt_rounded,
                    title: "Master Ledger History",
                    subtitle: "Complete financial timeline",
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllTransactionsScreen(),
                      ),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.inventory_rounded,
                    title: "Product Performance",
                    subtitle: "Sales by Item & Variant",
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductSalesBreakdownScreen(),
                      ),
                    ),
                  ),
                ],
                isDark,
                true,
              ),
              const SizedBox(height: 32),
              _buildSection(
                context,
                "Financial Reports",
                [
                  _ReportItem(
                    icon: Icons.trending_up_rounded,
                    title: "Invoice Margin View",
                    subtitle: "Margin per transaction",
                    color: FuturisticColors.success,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BillWiseProfitScreen(),
                      ),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.pie_chart_rounded,
                    title: "Income Statement",
                    subtitle: "Net income analysis",
                    color: Colors.pinkAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PnlScreen()),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.sync_alt_rounded,
                    title: "Funds Flow Analysis",
                    subtitle: "Inflow vs Outflow analysis",
                    color: Colors.indigo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CashflowScreen()),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.account_balance_rounded,
                    title: "Financial Position",
                    subtitle: "Assets & Obligations",
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BalanceScreen()),
                    ),
                  ),
                  _ReportItem(
                    icon: Icons.balance_rounded,
                    title: "Ledger Abstract",
                    subtitle: "Account balances summary",
                    color: Colors.brown,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrialBalanceScreen(),
                      ),
                    ), // Uses AccountingReportsScreen usually
                  ),
                ],
                isDark,
                true,
              ),
              const SizedBox(height: 32),
              _buildSection(
                context,
                "Tax & Compliance",
                [
                  _ReportItem(
                    icon: Icons.description_rounded,
                    title: "GSTR-1 Reports",
                    subtitle: "B2B, B2C, HSN Summaries",
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TaxReportScreen(),
                      ),
                    ),
                  ),
                ],
                isDark,
                true,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_ReportItem> items,
    bool isDark,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            title,
            style: isDesktop
                ? AppTypography.headlineMedium.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  )
                : TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
          ),
        ),
        isDesktop
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 3),
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? FuturisticColors.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item.icon, color: item.color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    color: FuturisticColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  return GlassCard(
                    onTap: item.onTap,
                    borderRadius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, color: item.color, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: isDark ? Colors.white24 : Colors.grey,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}

class _ReportItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _ReportItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
