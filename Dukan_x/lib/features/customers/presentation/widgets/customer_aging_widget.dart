// ============================================================================
// CUSTOMER AGING WIDGET
// ============================================================================
// Visual display of customer receivable aging buckets.
// Shows outstanding amounts in 0-30, 31-60, 61-90, and 90+ day buckets.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';

/// Aging bucket data
class AgingBucket {
  final String label;
  final int minDays;
  final int? maxDays;
  final double amount;
  final Color color;
  final int billCount;

  const AgingBucket({
    required this.label,
    required this.minDays,
    this.maxDays,
    required this.amount,
    required this.color,
    required this.billCount,
  });

  bool get isEmpty => amount <= 0;
}

/// Aging analysis data for a customer
class CustomerAgingData {
  final double current; // 0-30 days
  final double due31to60;
  final double due61to90;
  final double overdue90Plus;
  final int currentCount;
  final int due31to60Count;
  final int due61to90Count;
  final int overdue90PlusCount;
  final double totalOutstanding;

  const CustomerAgingData({
    this.current = 0,
    this.due31to60 = 0,
    this.due61to90 = 0,
    this.overdue90Plus = 0,
    this.currentCount = 0,
    this.due31to60Count = 0,
    this.due61to90Count = 0,
    this.overdue90PlusCount = 0,
    this.totalOutstanding = 0,
  });

  List<AgingBucket> get buckets => [
    AgingBucket(
      label: '0-30 Days',
      minDays: 0,
      maxDays: 30,
      amount: current,
      color: Colors.green,
      billCount: currentCount,
    ),
    AgingBucket(
      label: '31-60 Days',
      minDays: 31,
      maxDays: 60,
      amount: due31to60,
      color: Colors.amber,
      billCount: due31to60Count,
    ),
    AgingBucket(
      label: '61-90 Days',
      minDays: 61,
      maxDays: 90,
      amount: due61to90,
      color: Colors.orange,
      billCount: due61to90Count,
    ),
    AgingBucket(
      label: '90+ Days',
      minDays: 91,
      maxDays: null,
      amount: overdue90Plus,
      color: Colors.red,
      billCount: overdue90PlusCount,
    ),
  ];

  factory CustomerAgingData.empty() => const CustomerAgingData();
}

/// Customer Aging Widget
///
/// Displays aging analysis for customer receivables.
class CustomerAgingWidget extends StatelessWidget {
  final CustomerAgingData agingData;
  final VoidCallback? onBucketTap;

  const CustomerAgingWidget({
    super.key,
    required this.agingData,
    this.onBucketTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aging Analysis',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${_formatAmount(agingData.totalOutstanding)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: agingData.overdue90Plus > 0
                      ? Colors.red
                      : theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Aging bar
          _buildAgingBar(context),
          const SizedBox(height: 16),
          // Bucket details
          ...agingData.buckets.map((bucket) => _buildBucketRow(bucket, isDark)),
        ],
      ),
    );
  }

  Widget _buildAgingBar(BuildContext context) {
    if (agingData.totalOutstanding <= 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text('No Outstanding', style: TextStyle(fontSize: 10)),
        ),
      );
    }

    return Container(
      height: 8,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: agingData.buckets.map((bucket) {
            final percentage = bucket.amount / agingData.totalOutstanding;
            if (percentage <= 0) return const SizedBox.shrink();
            return Expanded(
              flex: (percentage * 100).round().clamp(1, 100),
              child: Container(color: bucket.color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBucketRow(AgingBucket bucket, bool isDark) {
    if (bucket.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: bucket.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bucket.label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          Text(
            '${bucket.billCount} bill${bucket.billCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '₹${_formatAmount(bucket.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: bucket.color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
