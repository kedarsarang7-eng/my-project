import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

class CustomerBalanceCard extends StatelessWidget {
  final double totalDue;
  final double totalPaid;
  final String? vendorName;
  final VoidCallback? onPayNow;

  const CustomerBalanceCard({
    super.key,
    required this.totalDue,
    required this.totalPaid,
    this.vendorName,
    this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final net = totalDue - totalPaid;
    final isOwed = net > 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isOwed
          ? const Color(0xFFFFF3F3)
          : const Color(0xFFF3FFF6),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vendorName != null)
              Text(
                vendorName!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            const SizedBox(height: 6),
            Text(
              isOwed ? 'You owe' : net < 0 ? 'You are owed' : 'Settled',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(net.abs()),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOwed
                        ? const Color(0xFFE53935)
                        : const Color(0xFF43A047),
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: 'Billed',
                  value: CurrencyFormatter.compact(totalDue),
                  color: const Color(0xFFE53935),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Paid',
                  value: CurrencyFormatter.compact(totalPaid),
                  color: const Color(0xFF43A047),
                ),
                if (onPayNow != null && isOwed) ...[
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: onPayNow,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Pay Now'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
