import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class MonthlyAnalyticsChart extends StatelessWidget {
  final Map<String, int> monthlyData;

  const MonthlyAnalyticsChart({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: FuturisticColors.glassShadow,
        border: Border.all(color: FuturisticColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Growth",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: monthlyData.entries.map((entry) {
                // Skip if no data for compactness? Or show 0 bars.
                // Showing only non-zero or all 12
                // Assuming map has 1-12

                final heightFactor = (entry.value / 100).clamp(
                  0.1,
                  1.0,
                ); // Assuming scale of 100 max

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 16,
                      height: 160 * heightFactor,
                      decoration: BoxDecoration(
                        color: FuturisticColors.accent1,
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            FuturisticColors.accent1,
                            FuturisticColors.accent2,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: FuturisticColors.neonShadow(
                          FuturisticColors.accent1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getMonthName(int.parse(entry.key)),
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
