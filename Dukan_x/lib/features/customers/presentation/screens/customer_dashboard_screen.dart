import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';

import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../data/customer_dashboard_repository.dart';
import 'customer_invoice_list_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerDashboardScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDashboardScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState
    extends ConsumerState<CustomerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Start real-time sync for this customer
    // We defer slightly to ensure provider is ready
    Future.microtask(() {
      final repo = ref.read(customerDashboardRepositoryProvider);
      // Assuming the repository has the method we added
      // We rely on the implementation we just validated
      repo.startRealtimeSync(widget.customerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(
      customerDashboardStatsProvider(widget.customerId),
    );

    return DesktopContentContainer(
      title: "My Dashboard",
      subtitle: "Overview of your shops and outstanding payments",
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: () =>
              ref.refresh(customerDashboardStatsProvider(widget.customerId)),
        ),
      ],
      child: statsAsync.when(
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(stats),
              const SizedBox(height: 24),
              Text(
                "My Shops",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildConnectedShopsList(ref),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSummaryCard(CustomerDashboardStats stats) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total Outstanding",
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "${sl<CurrencyService>().symbol}${stats.totalOutstanding.toStringAsFixed(2)}",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                "Total Paid",
                "${sl<CurrencyService>().symbol}${stats.totalPaid.toStringAsFixed(0)}",
              ),
              _buildStatItem("Unpaid Bills", "${stats.unpaidInvoiceCount}"),
              _buildStatItem("Shops", "${stats.vendorCount}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildConnectedShopsList(WidgetRef ref) {
    final vendorsAsync = ref.watch(connectedVendorsProvider(widget.customerId));

    return vendorsAsync.when(
      data: (vendors) {
        if (vendors.isEmpty) {
          return const Center(child: Text("No linked shops yet."));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vendors.length,
          itemBuilder: (context, index) {
            final vendor = vendors[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue,
                  child: Text(vendor.vendorName[0].toUpperCase()),
                ),
                title: Text(
                  vendor.vendorName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Balance: ₹${vendor.outstandingBalance.toStringAsFixed(0)}",
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  // Navigate to Vendor Detail View (Invoices from this vendor)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerInvoiceListScreen(
                        customerId: widget.customerId,
                        vendorId: vendor.vendorId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
