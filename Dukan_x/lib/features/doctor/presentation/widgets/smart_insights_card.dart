import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartInsightsCard extends StatelessWidget {
  final Map<String, String> insights;

  const SmartInsightsCard({super.key, required this.insights});

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
            "Insights",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildInsightRow(
            Icons.timer,
            'Avg. Time',
            insights['avgTime'] ?? '--',
          ),
          Divider(color: FuturisticColors.divider),
          _buildInsightRow(
            Icons.trending_up,
            'Workload',
            insights['workload'] ?? '--',
          ),
          Divider(color: FuturisticColors.divider),
          _buildInsightRow(
            Icons.medical_services,
            'Common',
            insights['common'] ?? '--',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FuturisticColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: FuturisticColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
