import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_state_providers.dart';
import '../../../utils/app_styles.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/neo_gradient_card.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../../models/daily_stats.dart';
import 'add_purchase_screen.dart';
import 'purchase_history_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PurchaseDashboardScreen extends ConsumerStatefulWidget {
  const PurchaseDashboardScreen({super.key});

  @override
  ConsumerState<PurchaseDashboardScreen> createState() =>
      _PurchaseDashboardScreenState();
}

class _PurchaseDashboardScreenState
    extends ConsumerState<PurchaseDashboardScreen> {
  final _session = sl<SessionManager>();

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final ownerId = _session.ownerId ?? '';

    return Scaffold(
      // Match the active theme's scaffold background instead of forcing a dark
      // navy (palette.mutedGray) that rendered dark even in light theme.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<PurchaseOrder>>(
        stream: sl<PurchaseRepository>().watchAll(userId: ownerId),
        builder: (context, snapshot) {
          final purchases = snapshot.data ?? [];

          // Compute stats from purchases
          double totalInvoiceValue = 0;
          double paidAmount = 0;
          double unpaidAmount = 0;
          double todayPurchase = 0;
          int activeOrders = 0;
          final today = DateTime.now();

          for (var p in purchases) {
            totalInvoiceValue += p.totalAmount;
            paidAmount += p.paidAmount;
            final unpaid = (p.totalAmount - p.paidAmount).clamp(
              0,
              double.infinity,
            );
            unpaidAmount += unpaid;

            // Today's purchases
            if (p.purchaseDate.year == today.year &&
                p.purchaseDate.month == today.month &&
                p.purchaseDate.day == today.day) {
              todayPurchase += p.totalAmount;
            }

            // Active (unpaid) orders
            if (p.status != 'Paid') {
              activeOrders++;
            }
          }

          final stats = VendorStats(
            totalInvoiceValue: totalInvoiceValue,
            paidAmount: paidAmount,
            unpaidAmount: unpaidAmount,
            todayPurchase: todayPurchase,
            activeOrders: activeOrders,
          );

          final hasData = totalInvoiceValue > 0;

          return Stack(
            children: [
              // Background soft gradients
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        palette.leafGreen.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        palette.tomatoRed.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: BoundedBox(
                    maxWidth: 1000,
                    child: CustomScrollView(
                      slivers: [
                        _buildAppBar(context, palette),
                        if (hasData) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildGraphSection(context, palette, stats),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: _buildStatGrid(context, palette, stats),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Recent Procurement",
                                    style: GoogleFonts.inter(
                                      fontSize: responsiveValue<double>(context,
                                        mobile: 14.0,
                                        tablet: 16.0,
                                        desktop: 18.0,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PurchaseHistoryScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "View All",
                                      style: TextStyle(color: palette.leafGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _buildRecentList(context, palette, purchases),
                          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                        ] else ...[
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No purchases yet",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Add your first vendor invoice to see insights",
                                    style: GoogleFonts.inter(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildSmartFab(palette),
    );
  }

  Widget _buildAppBar(BuildContext context, AppColorPalette palette) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 80,
      floating: true,
      flexibleSpace: GlassContainer(
        borderRadius: BorderRadius.zero,
        opacity: 0.1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Procurement Overview",
                      style: GoogleFonts.outfit(
                        fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Business Overview",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              GlassContainer(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphSection(
    BuildContext context,
    AppColorPalette palette,
    VendorStats stats,
  ) {
    final chartWidget = SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 70,
              sections: [
                PieChartSectionData(
                  color: palette.leafGreen,
                  value: stats.paidAmount,
                  title: '',
                  radius: 20,
                  showTitle: false,
                ),
                PieChartSectionData(
                  color: palette.tomatoRed,
                  value: stats.unpaidAmount,
                  title: '',
                  radius: 20,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Total Invoice Value",
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              Text(
                "${sl<CurrencyService>().symbol}${stats.totalInvoiceValue.toStringAsFixed(0)}",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: responsiveValue<double>(context, mobile: 20, tablet: 22, desktop: 24),
                  fontWeight: FontWeight.bold,
                  shadows: AppShadows.neonBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final legendWidget = context.isMobile
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                palette.leafGreen,
                "Paid",
                "${sl<CurrencyService>().symbol}${stats.paidAmount.toStringAsFixed(0)}",
              ),
              _buildLegendItem(
                palette.tomatoRed,
                "Unpaid",
                "${sl<CurrencyService>().symbol}${stats.unpaidAmount.toStringAsFixed(0)}",
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(
                palette.leafGreen,
                "Paid",
                "${sl<CurrencyService>().symbol}${stats.paidAmount.toStringAsFixed(0)}",
              ),
              const SizedBox(height: 16),
              _buildLegendItem(
                palette.tomatoRed,
                "Unpaid",
                "${sl<CurrencyService>().symbol}${stats.unpaidAmount.toStringAsFixed(0)}",
              ),
            ],
          );

    return NeoGradientCard(
      gradient: AppGradients.darkGlass,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: context.isMobile
            ? Column(
                children: [
                  chartWidget,
                  const SizedBox(height: 16),
                  legendWidget,
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  chartWidget,
                  legendWidget,
                ],
              ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatGrid(
    BuildContext context,
    AppColorPalette palette,
    VendorStats stats,
  ) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveValue<int>(context, mobile: 2, tablet: 2, desktop: 2),
        childAspectRatio: responsiveValue<double>(context, mobile: 1.1, tablet: 1.5, desktop: 2.0),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      delegate: SliverChildListDelegate([
        NeoGradientCard(
          gradient: AppGradients.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              const Spacer(),
              Text(
                "Today's Procurement",
                style: GoogleFonts.inter(color: Colors.white70, fontSize: responsiveValue<double>(context, mobile: 10, tablet: 12, desktop: 14)),
              ),
              Text(
                "${sl<CurrencyService>().symbol}${stats.todayPurchase.toStringAsFixed(0)}",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: responsiveValue<double>(context, mobile: 14, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        NeoGradientCard(
          gradient: AppGradients.violet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, color: Colors.white),
              const Spacer(),
              Text(
                "Vendor Orders",
                style: GoogleFonts.inter(color: Colors.white70, fontSize: responsiveValue<double>(context, mobile: 10, tablet: 12, desktop: 14)),
              ),
              Text(
                "${stats.activeOrders} Active",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: responsiveValue<double>(context, mobile: 14, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildRecentList(
    BuildContext context,
    AppColorPalette palette,
    List<PurchaseOrder> purchases,
  ) {
    final recent = purchases.take(5).toList();

    if (recent.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final bill = recent[index];
        final isPaid = bill.status == 'Paid';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GlassContainer(
            opacity: 0.05,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPaid
                      ? palette.leafGreen.withOpacity(0.1)
                      : palette.tomatoRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle_outline : Icons.pending_outlined,
                  color: isPaid ? palette.leafGreen : palette.tomatoRed,
                ),
              ),
              title: Text(
                bill.vendorName ?? 'Unknown Vendor',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                "Bill #${bill.invoiceNumber} • ${bill.purchaseDate.day}/${bill.purchaseDate.month}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${sl<CurrencyService>().symbol}${bill.totalAmount.toStringAsFixed(0)}",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    bill.status,
                    style: TextStyle(
                      color: isPaid ? palette.leafGreen : palette.tomatoRed,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }, childCount: recent.length),
    );
  }

  Widget _buildSmartFab(AppColorPalette palette) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppShadows.neonGreen,
        gradient: AppGradients.emerald,
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Add Invoice",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
