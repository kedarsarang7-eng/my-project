import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/purchase/screens/purchase_detail_screen.dart';

import '../../../providers/app_state_providers.dart';
import '../../../utils/app_styles.dart';

import '../../../widgets/neo_gradient_card.dart';
import '../../../widgets/neo_text_field.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/purchase_repository.dart' as repo;
import 'package:dukanx/core/responsive/responsive_layout.dart';

class PurchaseHistoryScreen extends ConsumerStatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  ConsumerState<PurchaseHistoryScreen> createState() =>
      _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends ConsumerState<PurchaseHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    return Scaffold(
      // Match the active theme's scaffold background instead of forcing a dark
      // navy (palette.mutedGray) that rendered dark even in light theme.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background — themed so it matches the rest of the app in light/dark.
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),

          SafeArea(
            child: ResponsiveContainer(
              child: Column(
                children: [
                  _buildHeader(context, palette),
                  _buildSearchBar(palette),
                  Expanded(child: _buildTimelineList(palette)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          Text(
            "Vendor Invoice History",
            style: GoogleFonts.outfit(
              fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: () => _showFilterDialog(context),
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeoTextField(
        controller: _searchController,
        label: "Search Supplier, Bill No...",
        icon: Icons.search,
      ),
    );
  }

  Widget _buildTimelineList(AppColorPalette palette) {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      return Center(
        child: Text(
          "Please login first",
          style: GoogleFonts.inter(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<List<repo.PurchaseOrder>>(
      stream: sl<repo.PurchaseRepository>().watchAll(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final orders = snapshot.data ?? [];

        // Filter based on search
        final query = _searchController.text.toLowerCase();
        final filteredOrders = orders.where((o) {
          if (query.isEmpty) return true;
          return (o.vendorName?.toLowerCase().contains(query) ?? false) ||
              (o.invoiceNumber?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  "No purchase history found",
                  style: GoogleFonts.inter(color: Colors.white54),
                ),
              ],
            ),
          );
        }

        // Group by Date
        final Map<String, List<repo.PurchaseOrder>> grouped = {};
        for (var order in filteredOrders) {
          final dateKey = _getDateKey(order.purchaseDate);
          if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
          grouped[dateKey]!.add(order);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: grouped.keys.length,
          itemBuilder: (context, index) {
            final dateKey = grouped.keys.elementAt(index);
            final dayOrders = grouped[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette.leafGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateKey,
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ...dayOrders.map<Widget>((order) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 16),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PurchaseDetailScreen(order: order),
                            ),
                          );
                        },
                        child: NeoGradientCard(
                          gradient: AppGradients.darkGlass,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.vendorName ?? 'Unknown Vendor',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Inv #${order.invoiceNumber ?? 'N/A'}",
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${sl<CurrencyService>().symbol}${order.totalAmount.toStringAsFixed(2)}",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (order.status == 'COMPLETED' ||
                                              order.status == 'PAID')
                                          ? palette.leafGreen.withOpacity(0.2)
                                          : palette.tomatoRed.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      order.status,
                                      style: TextStyle(
                                        color:
                                            (order.status == 'COMPLETED' ||
                                                order.status == 'PAID')
                                            ? palette.leafGreen
                                            : palette.tomatoRed,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(date.year, date.month, date.day);

    if (check == today) return 'Today';
    if (check == yesterday) return 'Yesterday';
    return "${check.day}/${check.month}/${check.year}";
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Invoices',
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                  mobile: 14.0,
                  tablet: 16.0,
                  desktop: 18.0,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All'),
              leading: const Icon(Icons.all_inclusive),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Paid'),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Unpaid'),
              leading: const Icon(Icons.warning, color: Colors.red),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
