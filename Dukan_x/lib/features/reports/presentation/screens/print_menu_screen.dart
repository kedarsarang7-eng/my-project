import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../screens/billing_reports_screen.dart';
import '../../../purchase/screens/purchase_dashboard_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PrintMenuScreen extends ConsumerWidget {
  const PrintMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ignore: unused_local_variable
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: "Print Center",
      subtitle: "Manage and print invoices for sales and purchases",
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMenuCard(
              context,
              "Print Sale Bills",
              "View and print customer invoices",
              Icons.receipt_long_rounded,
              Colors.blue,
              isDark,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingReportsScreen()),
              ),
            ),
            const SizedBox(width: 24),
            _buildMenuCard(
              context,
              "Print Purchase Bills",
              "View and print vendor invoices",
              Icons.shopping_bag_outlined,
              Colors.orange,
              isDark,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PurchaseDashboardScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 350,
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
