import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repository/vendors_repository.dart' as repo;
import '../../../../providers/app_state_providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../services/buy_flow_service.dart';
// Using repo.Vendor instead of legacy model
import '../../../../widgets/glass_morphism.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class VendorPayoutsScreen extends ConsumerStatefulWidget {
  const VendorPayoutsScreen({super.key});

  @override
  ConsumerState<VendorPayoutsScreen> createState() =>
      _VendorPayoutsScreenState();
}

class _VendorPayoutsScreenState extends ConsumerState<VendorPayoutsScreen> {
  final _buyFlowService = BuyFlowService();
  final _session = sl<SessionManager>();

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final ownerId = _session.ownerId ?? '';

    return DesktopContentContainer(
      title: "Suppliers & Payouts",
      actions: [
        DesktopActionButton(
          icon: Icons.add,
          label: 'Add Supplier',
          onPressed: () => _showAddVendorSheet(context, ownerId, isDark),
        ),
      ],
      child: StreamBuilder<List<repo.Vendor>>(
        stream: _buyFlowService.streamVendors(ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final vendors = snapshot.data ?? [];
          if (vendors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No Suppliers Found",
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: vendors.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return _buildVendorCard(vendor, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildVendorCard(repo.Vendor vendor, bool isDark) {
    // Balance Interpretation:
    // BuyFlowService subtraction (-amount) means:
    // Negative Balance = WE OWE THEM (Payable/Credit) -> RED
    // Positive Balance = THEY OWE US (Advance) -> GREEN

    final balance = vendor.totalOutstanding;
    final isPayable = balance > 0;
    final absBalance = balance.abs();

    return GlassCard(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isPayable
                  ? Colors.redAccent.withOpacity(0.1)
                  : Colors.greenAccent.withOpacity(0.1),
              child: Text(
                vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPayable ? Colors.redAccent : Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (vendor.phone?.isNotEmpty ?? false)
                    Text(
                      vendor.phone ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${absBalance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                    fontWeight: FontWeight.bold,
                    color: isPayable ? Colors.redAccent : Colors.green,
                  ),
                ),
                Text(
                  isPayable ? 'To Pay' : 'Advance',
                  style: TextStyle(
                    fontSize: 10,
                    color: isPayable ? Colors.redAccent : Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                if (isPayable)
                  InkWell(
                    onTap: () => _showPaySheet(vendor, absBalance, isDark),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "PAY NOW",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

  void _showAddVendorSheet(BuildContext context, String ownerId, bool isDark) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          "Add New Supplier",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Supplier Name",
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Phone Number",
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final v = repo.Vendor(
                  id: 'v_${DateTime.now().millisecondsSinceEpoch}',
                  userId: ownerId,
                  name: nameCtrl.text,
                  phone: phoneCtrl.text,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                _buyFlowService.saveVendor({
                  'vendorId': v.id,
                  'ownerId': v.userId,
                  'name': v.name,
                  'phone': v.phone,
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Save Supplier",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaySheet(repo.Vendor vendor, double dueAmount, bool isDark) {
    final amtCtrl = TextEditingController(text: dueAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          "Pay ${vendor.name}",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Amount (₹)",
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text);
              if (amt != null && amt > 0) {
                await _buyFlowService.recordVendorPayment(
                  vendor.userId,
                  vendor.id,
                  amt,
                  "CASH",
                  [],
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Confirm Payment",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
