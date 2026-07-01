import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/glass_morphism.dart';
import '../../../../providers/app_state_providers.dart';

// Screens
import '../../../../screens/sale/sale_home_screen.dart';
import '../../../../screens/billing_reports_screen.dart'; // Sale Report
import '../../../../services/connection_service.dart';
// ignore: unused_import
import '../../../../models/customer.dart';

// BuyFlow Features
import '../../../buy_flow/screens/buy_flow_dashboard.dart';
import '../../../buy_flow/screens/stock_entry_screen.dart';
import '../../../buy_flow/screens/vendor_payouts_screen.dart';
import '../../../buy_flow/screens/stock_reversal_screen.dart';
import '../../../buy_flow/screens/buy_orders_screen.dart';

import '../../../customers/presentation/screens/customers_list_screen.dart';

// Reports Features
import '../../../reports/presentation/screens/reports_hub_screen.dart';
import '../../../reports/presentation/screens/pnl_screen.dart';
import '../../../reports/presentation/screens/balance_screen.dart';
import '../../../reports/presentation/screens/print_menu_screen.dart';

// Other Features
import '../../../bank/presentation/screens/bank_screen.dart';
import '../../../backup/screens/backup_screen.dart';

// Revenue Features (NEW - Replacing Coming Soon)
import '../../../revenue/screens/receipt_entry_screen.dart';
import '../../../revenue/screens/return_inwards_screen.dart';
import '../../../revenue/screens/proforma_screen.dart';
import '../../../revenue/screens/booking_order_screen.dart';
import '../../../revenue/screens/dispatch_note_screen.dart';

import '../../../petrol_pump/presentation/screens/petrol_pump_management_screen.dart';

// Restaurant Features
import '../../../restaurant/presentation/screens/table_management_screen.dart';
import '../../../restaurant/presentation/screens/kitchen_display_screen.dart';
import '../../../restaurant/presentation/screens/food_menu_management_screen.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';

// Clinic Features
import '../../../doctor/presentation/screens/doctor_dashboard_screen.dart';
import '../../../doctor/presentation/screens/appointment_screen.dart';
import '../../../doctor/presentation/screens/patient_list_screen.dart';
import '../../../doctor/presentation/screens/prescriptions_list_screen.dart';
import 'business_profile_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ManageBusinessDashboard extends ConsumerStatefulWidget {
  const ManageBusinessDashboard({super.key});

  @override
  ConsumerState<ManageBusinessDashboard> createState() =>
      _ManageBusinessDashboardState();
}

class _ManageBusinessDashboardState
    extends ConsumerState<ManageBusinessDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  // Expansion States
  bool _isSaleExpanded = true;
  bool _isPurchaseExpanded = false;
  bool _isReportsExpanded = true; // Default expanded for visibility
  bool _isUtilitiesExpanded = false;
  bool _isPartiesExpanded = true; // Default expanded for visibility
  bool _isPetrolPumpExpanded = true;
  bool _isRestaurantExpanded = true; // New
  bool _isClinicExpanded = true; // New

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final businessState = ref.watch(businessTypeProvider);
    final isDark = theme.isDark;

    // Defined text styles for reusability
    final headingStyle = TextStyle(
      fontSize: responsiveValue<double>(
        context,
        mobile: 18,
        tablet: 20,
        desktop: 24,
      ),
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black87,
    );
    final subHeadingStyle = TextStyle(
      fontSize: 14,
      color: isDark ? Colors.white70 : Colors.black54,
    );

    return Scaffold(
      backgroundColor: Colors.transparent, // Uses global background
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Manage Business", style: headingStyle),
                          _buildRequestsIcon(context, isDark),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tools to grow and manage your store",
                        style: subHeadingStyle,
                      ),
                    ],
                  ),
                ),
              ),

              // My Business Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          "Management Console",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      // Business Profile (New)
                      GlassCard(
                        borderRadius: 16,
                        child: _buildListItem(
                          title: "Business Profile",
                          isDark: isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BusinessProfileScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Parties Section (New)
                      GlassCard(
                        borderRadius: 16,
                        child: _buildExpandableSection(
                          title: "Parties (Ledger)",
                          icon: Icons.people_alt_rounded,
                          color: Colors.orangeAccent,
                          isDark: isDark,
                          isExpanded: _isPartiesExpanded,
                          onToggle: () {
                            setState(() {
                              _isPartiesExpanded = !_isPartiesExpanded;
                            });
                          },
                          children: [
                            _buildListItem(
                              title: "My Customers",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CustomersListScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "My Suppliers",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VendorPayoutsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          "Operations",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),

                      // Sale Section
                      GlassCard(
                        borderRadius: 16,
                        child: _buildExpandableSection(
                          title: "Revenue Desk",
                          icon: Icons.currency_rupee_rounded,
                          color: Colors.blueAccent,
                          isDark: isDark,
                          isExpanded: _isSaleExpanded,
                          onToggle: () {
                            setState(() {
                              _isSaleExpanded = !_isSaleExpanded;
                            });
                          },
                          children: [
                            _buildListItem(
                              title: "Revenue Overview",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SaleHomeScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Receipt Entry",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReceiptEntryScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Return Inwards",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReturnInwardsScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Proforma & Bids",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProformaScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Booking Order",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BookingOrderScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Dispatch Note",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DispatchNoteScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // BuyFlow Section
                      GlassCard(
                        borderRadius: 16,
                        child: _buildExpandableSection(
                          title: "BuyFlow",
                          icon: Icons.input_rounded, // Box arrow inward concept
                          color: Colors.green, // Soft Green for 'Inflow'
                          isDark: isDark,
                          isExpanded: _isPurchaseExpanded,
                          onToggle: () {
                            setState(() {
                              _isPurchaseExpanded = !_isPurchaseExpanded;
                            });
                          },
                          children: [
                            _buildListItem(
                              title: "BuyFlow Dashboard",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BuyFlowDashboard(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Stock Entry",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StockEntryScreen(),
                                ),
                              ),
                            ),
                            // Vendor Payouts moved to Parties Section as 'My Suppliers'
                            _buildListItem(
                              title: "Stock Reversal",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StockReversalScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Buy Orders",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BuyOrdersScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (businessState.isPetrolPump) ...[
                        GlassCard(
                          borderRadius: 16,
                          child: _buildExpandableSection(
                            title: "Petrol Pump Management",
                            icon: Icons.local_gas_station,
                            color: Colors.redAccent,
                            isDark: isDark,
                            isExpanded: _isPetrolPumpExpanded,
                            onToggle: () {
                              setState(() {
                                _isPetrolPumpExpanded = !_isPetrolPumpExpanded;
                              });
                            },
                            children: [
                              _buildListItem(
                                title: "Manage Pump",
                                isDark: isDark,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PetrolPumpManagementScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Restaurant Section
                      if (businessState.type.name == 'restaurant') ...[
                        GlassCard(
                          borderRadius: 16,
                          child: _buildExpandableSection(
                            title: "Restaurant Operations",
                            icon: Icons.restaurant_menu_rounded,
                            color: Colors.pinkAccent,
                            isDark: isDark,
                            isExpanded: _isRestaurantExpanded,
                            onToggle: () {
                              setState(() {
                                _isRestaurantExpanded = !_isRestaurantExpanded;
                              });
                            },
                            children: [
                              _buildListItem(
                                title: "Table Management",
                                isDark: isDark,
                                onTap: () {
                                  final vendorId =
                                      sl<SessionManager>().currentBusinessId ??
                                      sl<SessionManager>().userId ??
                                      'SYSTEM';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TableManagementScreen(
                                        vendorId: vendorId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildListItem(
                                title: "Kitchen Display (KDS)",
                                isDark: isDark,
                                onTap: () {
                                  final vendorId =
                                      sl<SessionManager>().currentBusinessId ??
                                      sl<SessionManager>().userId ??
                                      'SYSTEM';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => KitchenDisplayScreen(
                                        vendorId: vendorId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildListItem(
                                title: "Menu Management",
                                isDark: isDark,
                                onTap: () {
                                  final vendorId =
                                      sl<SessionManager>().currentBusinessId ??
                                      sl<SessionManager>().userId ??
                                      'SYSTEM';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FoodMenuManagementScreen(
                                        vendorId: vendorId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Clinic / Doctor Section
                      if (businessState.isClinic) ...[
                        GlassCard(
                          borderRadius: 16,
                          child: _buildExpandableSection(
                            title: "Clinic Management",
                            icon: Icons.medical_services_rounded,
                            color: Colors.cyan,
                            isDark: isDark,
                            isExpanded: _isClinicExpanded,
                            onToggle: () {
                              setState(() {
                                _isClinicExpanded = !_isClinicExpanded;
                              });
                            },
                            children: [
                              _buildListItem(
                                title: "Doctor Dashboard",
                                isDark: isDark,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DoctorDashboardScreen(),
                                  ),
                                ),
                              ),
                              _buildListItem(
                                title: "Appointments",
                                isDark: isDark,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AppointmentScreen(),
                                  ),
                                ),
                              ),
                              _buildListItem(
                                title: "Patients Registry",
                                isDark: isDark,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PatientListScreen(),
                                  ),
                                ),
                              ),
                              _buildListItem(
                                title: "Prescriptions",
                                isDark: isDark,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SafePrescriptionListScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Reports Section (Updated)
                      GlassCard(
                        borderRadius: 16,
                        child: _buildExpandableSection(
                          title: "Business Intelligence",
                          icon: Icons.bar_chart_rounded,
                          color: Colors.purple,
                          isDark: isDark,
                          isExpanded: _isReportsExpanded,
                          onToggle: () {
                            setState(() {
                              _isReportsExpanded = !_isReportsExpanded;
                            });
                          },
                          children: [
                            _buildListItem(
                              title: "Analytics Hub",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportsHubScreen(),
                                ),
                              ),
                              isHighlight: true,
                            ),
                            _buildListItem(
                              title: "Turnover Analysis",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BillingReportsScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Income Statement",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PnlScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Financial Position",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BalanceScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Print Settings",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PrintMenuScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Utilities & Other
                      GlassCard(
                        borderRadius: 16,
                        child: _buildExpandableSection(
                          title: "Utilities & Other",
                          icon: Icons.category_rounded,
                          color: Colors.teal,
                          isDark: isDark,
                          isExpanded: _isUtilitiesExpanded,
                          onToggle: () {
                            setState(() {
                              _isUtilitiesExpanded = !_isUtilitiesExpanded;
                            });
                          },
                          children: [
                            _buildListItem(
                              title: "Bank Accounts",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BankScreen(),
                                ),
                              ),
                            ),
                            _buildListItem(
                              title: "Backup & Restore",
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BackupScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100), // Bottom spacing
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: isExpanded ? Radius.zero : const Radius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                // Arrow
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white54 : Colors.grey,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        // Expanded Content
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: Column(
            children: [const Divider(height: 1, thickness: 0.5), ...children],
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOutQuart,
        ),
      ],
    );
  }

  Widget _buildListItem({
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 60,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                  color: isHighlight
                      ? Colors.blueAccent
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isHighlight
                  ? Colors.blueAccent
                  : (isDark ? Colors.white24 : Colors.black26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsIcon(BuildContext context, bool isDark) {
    return StreamBuilder<List<ConnectionRequest>>(
      stream: ConnectionService().streamRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final count = requests.length;

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_active_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              onPressed: () => _showRequestsSheet(context, requests),
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showRequestsSheet(
    BuildContext context,
    List<ConnectionRequest> requests,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connection Requests',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No pending requests',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      req.customerName.isEmpty ? 'Unknown' : req.customerName,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    subtitle: Text(
                      req.customerPhone,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx); // Close first
                            try {
                              await ConnectionService().acceptRequest(req);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Accepted!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await ConnectionService().rejectRequest(req.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
