import 'package:flutter/material.dart';

/// Visual indicator for batch expiry status in product search results.
/// Red = expired, Amber = ≤90 days, Green = safe.
class BatchExpiryIndicator extends StatelessWidget {
  final DateTime? expiryDate;
  final String? batchNumber;
  final bool showLabel;
  final double size;

  const BatchExpiryIndicator({
    super.key,
    required this.expiryDate,
    this.batchNumber,
    this.showLabel = true,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (expiryDate == null) {
      return _buildIndicator(
        color: Colors.grey,
        label: 'No Expiry',
        icon: Icons.help_outline,
      );
    }

    final now = DateTime.now();
    final daysToExpiry = expiryDate!.difference(now).inDays;

    if (daysToExpiry < 0) {
      return _buildIndicator(
        color: Colors.red,
        label: 'EXPIRED (${-daysToExpiry}d ago)',
        icon: Icons.block,
        isBold: true,
      );
    }

    if (daysToExpiry <= 30) {
      return _buildIndicator(
        color: Colors.red.shade700,
        label: '${daysToExpiry}d left ⚠️',
        icon: Icons.warning,
        isBold: true,
      );
    }

    if (daysToExpiry <= 90) {
      return _buildIndicator(
        color: Colors.amber.shade700,
        label: '${daysToExpiry}d left',
        icon: Icons.schedule,
      );
    }

    return _buildIndicator(
      color: Colors.green,
      label: '${daysToExpiry}d',
      icon: Icons.check_circle,
    );
  }

  Widget _buildIndicator({
    required Color color,
    required String label,
    required IconData icon,
    bool isBold = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            '${batchNumber != null ? "$batchNumber · " : ""}$label',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shows expiry indicators for ALL batches of a product in search results
class ProductBatchExpiryRow extends StatelessWidget {
  final List<BatchExpiryInfo> batches;

  const ProductBatchExpiryRow({super.key, required this.batches});

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return const Text(
        'No batches',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      );
    }

    // Show up to 3 batches inline
    final displayed = batches.take(3).toList();
    final remaining = batches.length - 3;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ...displayed.map((b) => BatchExpiryIndicator(
              expiryDate: b.expiryDate,
              batchNumber: b.batchNumber,
              showLabel: true,
              size: 8,
            )),
        if (remaining > 0)
          Text(
            '+$remaining more',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }
}

class BatchExpiryInfo {
  final String? batchNumber;
  final DateTime? expiryDate;
  final double stockQuantity;
  final String? rackLocation;

  BatchExpiryInfo({
    this.batchNumber,
    this.expiryDate,
    this.stockQuantity = 0,
    this.rackLocation,
  });
}
