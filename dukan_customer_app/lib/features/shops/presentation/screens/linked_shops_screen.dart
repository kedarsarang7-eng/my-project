import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../../core/navigation/app_router.dart';
import '../../data/shops_repository.dart';

class LinkedShopsScreen extends ConsumerWidget {
  const LinkedShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(linkedShopsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Shops')),
      body: shops.when(
        data: (list) => list.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.storefront_outlined,
                title: 'No shops linked',
                subtitle:
                    'Ask your vendor to send you a link request, or scan their QR code.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(linkedShopsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ShopCard(connection: list[i]),
                ),
              ),
        loading: () => const ListLoadingShimmer(itemCount: 5, itemHeight: 100),
        error: (e, _) => ErrorStateWidget(
          message: 'Could not load shops',
          onRetry: () => ref.invalidate(linkedShopsProvider),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final VendorConnection connection;
  const _ShopCard({required this.connection});

  @override
  Widget build(BuildContext context) {
    final (icon, bgColor) = _businessStyle(connection.businessType);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          AppRoutes.ledger,
          extra: connection.vendorId,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: bgColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.vendorBusinessName ?? connection.vendorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (connection.vendorPhone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        connection.vendorPhone!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusBadge(status: connection.status),
                        const Spacer(),
                        if (connection.outstandingBalance != 0)
                          AmountDisplay(
                            amount: connection.outstandingBalance,
                            colored: true,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _businessStyle(String? type) {
    switch (type?.toLowerCase()) {
      case 'grocery':
        return (Icons.shopping_basket_rounded, const Color(0xFF43A047));
      case 'pharmacy':
      case 'medical':
        return (Icons.medical_services_rounded, const Color(0xFFE53935));
      case 'restaurant':
      case 'food':
        return (Icons.restaurant_rounded, const Color(0xFFE91E63));
      case 'electronics':
      case 'mobile':
        return (Icons.phone_android_rounded, const Color(0xFF1565C0));
      case 'clothing':
      case 'cloth':
        return (Icons.checkroom_rounded, const Color(0xFF9C27B0));
      case 'hardware':
        return (Icons.hardware_rounded, const Color(0xFF795548));
      case 'petrol_pump':
      case 'fuel':
        return (Icons.local_gas_station_rounded, const Color(0xFFFF6F00));
      default:
        return (Icons.store_rounded, const Color(0xFF1565C0));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ConnectionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConnectionStatus.active => ('Active', const Color(0xFF43A047)),
      ConnectionStatus.pending => ('Pending', const Color(0xFFFB8C00)),
      ConnectionStatus.rejected => ('Rejected', const Color(0xFFE53935)),
      ConnectionStatus.suspended => ('Suspended', const Color(0xFF9E9E9E)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
