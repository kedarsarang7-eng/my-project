import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/currency_service.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Payment Method Breakdown Pie Chart with glassmorphism.
class PaymentMethodChart extends StatefulWidget {
  final Map<String, double>
  data; // e.g. {"CASH": 5000, "UPI": 12000, "CARD": 3000}

  const PaymentMethodChart({super.key, required this.data});

  @override
  State<PaymentMethodChart> createState() => _PaymentMethodChartState();
}

class _PaymentMethodChartState extends State<PaymentMethodChart> {
  int touchedIndex = -1;

  // Premium color palette mapped to standard payment methods
  Color getColorForMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return const Color(0xFF10B981); // Emerald Green
      case 'UPI':
        return const Color(0xFF3B82F6); // Blue
      case 'CARD':
        return const Color(0xFF8B5CF6); // Purple
      case 'CREDIT':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFFEC4899); // Pink for others
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Data",
                style: GoogleFonts.inter(
                  color: FuturisticColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = widget.data.values.fold(0.0, (sum, item) => sum + item);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Methods",
            style: GoogleFonts.outfit(
              color: FuturisticColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection ==
                                            null) {
                                      touchedIndex = -1;
                                      return;
                                    }
                                    touchedIndex = pieTouchResponse
                                        .touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 3,
                          centerSpaceRadius: 50,
                          sections: List.generate(widget.data.length, (i) {
                            final isTouched = i == touchedIndex;
                            final fontSize = isTouched ? 16.0 : 12.0;
                            final radius = isTouched ? 60.0 : 50.0;

                            final key = widget.data.keys.elementAt(i);
                            final value = widget.data.values.elementAt(i);
                            final percentage = (value / total) * 100;
                            final color = getColorForMethod(key);

                            return PieChartSectionData(
                              color: color,
                              value: value,
                              title: '${percentage.toStringAsFixed(0)}%',
                              radius: radius,
                              titleStyle: GoogleFonts.inter(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(color: Colors.black45, blurRadius: 4),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                      // Center label
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: FuturisticColors.surface.withValues(alpha: 0.9),
                          border: Border.all(
                            color: FuturisticColors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${sl<CurrencyService>().symbol}${_formatNumber(total)}",
                              style: GoogleFonts.outfit(
                                color: FuturisticColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(widget.data.length, (i) {
                        final key = widget.data.keys.elementAt(i);
                        final value = widget.data.values.elementAt(i);
                        final color = getColorForMethod(key);
                        final isTouched = i == touchedIndex;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isTouched
                                ? color.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isTouched
                                ? Border.all(color: color.withValues(alpha: 0.3))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      key,
                                      style: GoogleFonts.inter(
                                        color: isTouched
                                            ? Colors.white
                                            : FuturisticColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: isTouched
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      '${sl<CurrencyService>().symbol}${_formatNumber(value)}',
                                      style: GoogleFonts.inter(
                                        color: isTouched
                                            ? color
                                            : FuturisticColors.textSecondary
                                                  .withValues(alpha: 0.7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          FuturisticColors.surface,
          FuturisticColors.surface.withValues(alpha: 0.85),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FuturisticColors.premiumBlue.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
          color: FuturisticColors.premiumBlue.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
