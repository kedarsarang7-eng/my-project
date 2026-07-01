import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/navigation/navigation_controller.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HardwareCommandCenterScreen extends ConsumerWidget {
  const HardwareCommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hardware Command Center')),
      body: SingleChildScrollView(
        child: DesktopContentContainer(
          maxWidth: 1600,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Ops',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _ActionGrid(
                cards: [
                  const _ActionCardData(
                    title: 'Projects, Indents, Deposits',
                    subtitle: 'Contractor workflow and returnable deposits',
                    icon: Icons.engineering_outlined,
                    route: '/hardware/operations',
                    navId: 'hardware_operations',
                  ),
                  const _ActionCardData(
                    title: 'Delivery Challans',
                    subtitle: 'Dispatch, convert to invoice, track status',
                    icon: Icons.local_shipping_outlined,
                    route: '/delivery_challans',
                    navId: 'delivery_challans',
                  ),
                  const _ActionCardData(
                    title: 'Estimates / Proforma',
                    subtitle: 'Quotation flow for contractor and site supply',
                    icon: Icons.request_quote_outlined,
                    route: '/proforma',
                    navId: 'proforma_bids',
                  ),
                  const _ActionCardData(
                    title: 'Billing Desk',
                    subtitle: 'Create GST invoice with hardware-specific units',
                    icon: Icons.point_of_sale_outlined,
                    route: '/hardware/fast-billing',
                    navId: 'new_sale',
                  ),
                  const _ActionCardData(
                    title: 'Contractor Credit Control',
                    subtitle: 'Overdue ageing and outstanding risk watch',
                    icon: Icons.account_balance_wallet_outlined,
                    route: '/hardware/credit-control',
                    navId: 'hardware_credit_control',
                  ),
                  const _ActionCardData(
                    title: 'Supplier Management',
                    subtitle: 'Supplier master and payable overview',
                    icon: Icons.storefront_outlined,
                    route: '/app/suppliers',
                    navId: 'suppliers',
                  ),
                  const _ActionCardData(
                    title: 'Invoice Formats',
                    subtitle: 'Logo and field visibility profiles',
                    icon: Icons.tune_outlined,
                    route: '/hardware/invoice-profiles',
                    navId: 'hardware_invoice_profiles',
                  ),
                ],
                defaultColor: cs.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Compliance & Control',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _ActionGrid(
                cards: [
                  const _ActionCardData(
                    title: 'GST Reports',
                    subtitle:
                        'GSTR, HSN summary, liability and filing readiness',
                    icon: Icons.receipt_long_outlined,
                    route: '/gst-reports',
                    navId: 'gstr1',
                  ),
                  const _ActionCardData(
                    title: 'Inventory Control',
                    subtitle: 'Stock summary, reorder alerts, valuation',
                    icon: Icons.inventory_2_outlined,
                    route: '/inventory',
                    navId: 'stock_summary',
                  ),
                  const _ActionCardData(
                    title: 'Party Ledger',
                    subtitle: 'Customer/supplier outstanding tracking',
                    icon: Icons.account_balance_wallet_outlined,
                    route: '/party_ledger',
                    navId: 'party_ledger',
                  ),
                  const _ActionCardData(
                    title: 'Analytics',
                    subtitle: 'Project outstanding and revenue trends',
                    icon: Icons.analytics_outlined,
                    route: '/analytics',
                    navId: 'analytics_hub',
                  ),
                ],
                defaultColor: cs.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.cards, required this.defaultColor});

  final List<_ActionCardData> cards;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return _ActionCard(card: card, defaultColor: defaultColor);
          },
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.card, required this.defaultColor});

  final _ActionCardData card;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final navId = card.navId;
          if (navId != null && navId.isNotEmpty) {
            final controller = ProviderScope.containerOf(
              context,
              listen: false,
            ).read(navigationControllerProvider.notifier);
            controller.navigateById(navId);
            return;
          }
          // AD-5/AD-7: dynamic runtime route string pushed via GoRouter.
          context.push(card.route);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(card.icon, color: card.color ?? defaultColor),
              const SizedBox(height: 10),
              Text(
                card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                card.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCardData {
  // ignore: unused_element_parameter
  const _ActionCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    // ignore: unused_element_parameter
    this.color,
    this.navId,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final String route;
  final String? navId;
}
