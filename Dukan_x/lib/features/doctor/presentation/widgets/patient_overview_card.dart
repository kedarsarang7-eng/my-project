import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientOverviewCard extends StatelessWidget {
  final Map<String, int> data;

  const PatientOverviewCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(
          'Total Patients',
          data['total'].toString(),
          Icons.people,
          FuturisticColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'New Patients',
          data['new'].toString(),
          Icons.person_add,
          FuturisticColors.success,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Returning',
          data['returning'].toString(),
          Icons.loop,
          FuturisticColors.warning,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Inactive',
          data['inactive'].toString(),
          Icons.person_off,
          FuturisticColors.textDisabled,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FuturisticColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: FuturisticColors.neonShadow(color),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FuturisticColors.textPrimary,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
