import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/futuristic_colors.dart';
import '../core/di/service_locator.dart';
import '../core/services/currency_service.dart';
import '../utils/app_styles.dart';

import 'neo_gradient_card.dart';

import 'ui/skeleton_loader.dart';

class DailySummaryCard extends StatelessWidget {
  final double sales;
  final double spend;
  final double pending;
  final int lowStock;
  final bool isDark;
  final bool isLoading;
  final String? briefingText;

  const DailySummaryCard({
    super.key,
    required this.sales,
    required this.spend,
    required this.pending,
    this.lowStock = 0,
    required this.isDark,
    this.isLoading = false,
    this.briefingText,
  });

  @override
  Widget build(BuildContext context) {
    bool hasActivity = sales > 0 || spend > 0;

    return NeoGradientCard(
      gradient: isDark ? AppGradients.darkGlass : AppGradients.glass,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                "Daily AI Summary",
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isLoading
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(height: 14, width: 250),
                    const SizedBox(height: 8),
                    const SkeletonLoader(height: 14, width: 200),
                  ],
                )
              : briefingText != null
              ? Text(
                  briefingText!,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                    height: 1.5,
                  ),
                )
              : hasActivity
              ? RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: "Today you made "),
                      TextSpan(
                        text: "${sl<CurrencyService>().symbol}${sales.toStringAsFixed(0)} sales",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FuturisticColors.success,
                        ),
                      ),
                      const TextSpan(text: ", spent "),
                      TextSpan(
                        text: "${sl<CurrencyService>().symbol}${spend.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FuturisticColors.error,
                        ),
                      ),
                      const TextSpan(text: ", and have "),
                      TextSpan(
                        text: "${sl<CurrencyService>().symbol}${pending.toStringAsFixed(0)} pending",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const TextSpan(text: " from customers."),
                    ],
                  ),
                )
              : Text(
                  "No activity today. Add a sale or purchase to get AI insights.",
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontSize: 14,
                  ),
                ),
          const SizedBox(height: 12),
          isLoading
              ? Row(
                  children: const [
                    SkeletonLoader(height: 20, width: 80, borderRadius: 20),
                    SizedBox(width: 8),
                    SkeletonLoader(height: 20, width: 80, borderRadius: 20),
                  ],
                )
              : Row(
                  children: [
                    if (sales > 5000)
                      _buildMiniChip(
                        "High Sales 🚀",
                        FuturisticColors.success.withOpacity(0.1),
                        FuturisticColors.success,
                      ),
                    if (sales > 5000) const SizedBox(width: 8),
                    if (lowStock > 0)
                      _buildMiniChip(
                        "Low Stock ($lowStock) ⚠️",
                        FuturisticColors.warning.withOpacity(0.1),
                        FuturisticColors.warning,
                      )
                    else
                      _buildMiniChip(
                        "Stock OK ✅",
                        FuturisticColors.accent3.withOpacity(0.1),
                        FuturisticColors.accent3,
                      ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
