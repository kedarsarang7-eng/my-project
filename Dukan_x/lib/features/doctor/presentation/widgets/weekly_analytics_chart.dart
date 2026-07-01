import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class WeeklyAnalyticsChart extends StatelessWidget {
  final Map<String, int> weeklyData;

  const WeeklyAnalyticsChart({super.key, required this.weeklyData});

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
            "Weekly Analytics",
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
              children: weeklyData.entries.map((entry) {
                // Normalize height. Max usually 50 for visualization.
                final heightFactor = (entry.value / 50).clamp(0.1, 1.0);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 20,
                      height: 160 * heightFactor,
                      decoration: BoxDecoration(
                        color: FuturisticColors.primary,
                        borderRadius: BorderRadius.circular(4),
                        gradient: FuturisticColors.primaryGradient,
                        boxShadow: FuturisticColors.neonShadow(
                          FuturisticColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getDayName(int.parse(entry.key)),
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary,
                        fontSize: 12,
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

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // DateTime.weekday returns 1 for Mon, 7 for Sun
    if (weekday >= 1 && weekday <= 7) return days[weekday - 1];
    return '';
  }
}
