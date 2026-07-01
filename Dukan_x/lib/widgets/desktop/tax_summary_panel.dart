import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/currency_service.dart';
import '../../models/bill.dart';

/// Premium Tax Summary Panel with glassmorphism effects.
/// Calculates and displays tax data from real monthly bills.
class TaxSummaryPanel extends StatelessWidget {
  final List<Bill> monthlyBills;

  const TaxSummaryPanel({super.key, required this.monthlyBills});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final successColor = const Color(0xFF22C55E); // Green 500

    // Calculate tax metrics from real data
    double totalTax = 0;
    double taxableValue = 0;
    double nonTaxableValue = 0;

    for (var bill in monthlyBills) {
      if (bill.totalTax > 0) {
        totalTax += bill.totalTax;
        taxableValue += bill.subtotal;
      } else {
        nonTaxableValue += bill.subtotal;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardColor,
            theme.cardColor.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? primaryColor.withOpacity(0.2) : theme.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? primaryColor.withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDark
                ? successColor.withOpacity(0.05)
                : Colors.black.withOpacity(0.01),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tax Summary",
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: successColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  "This Month",
                  style: TextStyle(
                    color: successColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Total Output Tax - Large primary metric
          _buildPrimaryMetric(
            context: context,
            label: "Total Output Tax",
            value: totalTax,
            color: successColor,
          ),

          const SizedBox(height: 24),

          // Divider with subtle styling
          Container(
            height: 1,
            color: theme.dividerColor,
          ),

          const SizedBox(height: 20),

          // Secondary metrics
          _buildSecondaryMetric(
            context: context,
            label: "Taxable Sales",
            value: taxableValue,
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 16),
          _buildSecondaryMetric(
            context: context,
            label: "Non-Taxable Sales",
            value: nonTaxableValue,
            icon: Icons.receipt_outlined,
          ),

          const Spacer(),

          // Info footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: primaryColor.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${monthlyBills.length} invoices this month",
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryMetric({
    required BuildContext context,
    required String label,
    required double value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${sl<CurrencyService>().symbol}${_formatNumber(value)}",
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                shadows: isDark
                    ? [
                        Shadow(color: color.withOpacity(0.3), blurRadius: 10),
                      ]
                    : null,
              ),
            ),
            if (value > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Icon(
                  Icons.trending_up,
                  color: color.withOpacity(0.7),
                  size: 20,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryMetric({
    required BuildContext context,
    required String label,
    required double value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: primaryColor.withOpacity(0.8),
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          "${sl<CurrencyService>().symbol}${_formatNumber(value)}",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return value
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return value.toStringAsFixed(2);
  }
}
